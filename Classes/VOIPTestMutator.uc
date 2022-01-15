class VOIPTestMutator extends ROMutator
    config(Mutator_VOIPTest);

enum EPacketID
{
    EPID_NONE,
    EPID_PLAYER_META,
    EPID_PLAYER_STOPPED_SPEAKING,
    EPID_PLAYER_SPEAKING,
    EPID_PLAYER_SPEAKING_SPATIALIZED,
    EPID_PLAYER_DISCONNECTED,
    EPID_PLAYER_SPAWNED,
    EPID_PLAYER_DIED,
    EPID_PLAYER_SQUAD_CHANGED,
    EPID_PLAYER_TEAM_CHANGED,
};

// Essentially the packet header. 2 bytes.
struct Packet
{
    // Final serialized packet size.
    var byte Size;
    var EPacketID ID;

    StructDefaultProperties
    {
        ID=EPID_NONE
    }
};

// Should be sent when a player joins or their PlayerID changes.
// TODO: is Team and Squad needed here?
struct PlayerMeta extends Packet
{
    // var byte Num; // TODO: Do we need this? Send multi player data as array? SendBinary only accepts 255 bytes.
    var byte Team;
    var byte Squad;
    var int PlayerID;
    var int UniqueNetIDHi;
    var int UniqueNetIDLo;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_META
    }
};

// Sent when player stops speaking to immediately end current voice transmission.
struct PlayerStoppedSpeaking extends Packet
{
    var int PlayerID;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_STOPPED_SPEAKING
    }
};

// Player speaking "beacon" update. Sent every X milliseconds while a player is speaking.
// NOTE: probably not wise to send every tick.
struct PlayerSpeaking extends Packet
{
    var int PlayerID;
    var byte Channel;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_SPEAKING
    }
};

// Same as PlayerSpeaking but with location and rotation data.
// TODO: mumble needs camera location/rotation too?
struct PlayerSpeakingSpatialized extends PlayerSpeaking
{
    var vector Location;
    var rotator Rotation;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_SPEAKING_SPATIALIZED
    }
};

struct PlayerDisconnected extends Packet
{
    var int PlayerID;
    var int UniqueNetIDHi;
    var int UniqueNetIDLo;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_DISCONNECTED
    }
};

struct PlayerSpawned extends Packet
{
    var int PlayerID;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_SPAWNED
    }
};

struct PlayerDied extends Packet
{
    var int PlayerID;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_DIED
    }
};

struct PlayerSquadChanged extends Packet
{
    var int PlayerID;
    var byte NewSquad;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_SQUAD_CHANGED
    }
};

struct PlayerTeamChanged extends Packet
{
    var int PlayerID;
    var byte NewTeam;

    StructDefaultProperties
    {
        ID=EPID_PLAYER_TEAM_CHANGED
    }
};

var MurmurTcpLink Link;

function PostBeginPlay()
{
    Link = Spawn(class'MurmurTcpLink');
    if (Link != None)
    {
        Link.Parent = self;
        Link.ResolveServer();
    }
    else
    {
        `log("error spawning MurmurTcpLink",, self.name);
    }

    // TODO: just for testing.
    SetTimer(1.0, True, 'PlayerMetaTimer');
}

function Set_CancelOpenAttempt_MurmurTcpLink(optional float Time = 5.0)
{
    SetTimer(Time, False, 'CancelOpenAttempt_MurmurTcpLink');
}

function Clear_CancelOpenAttempt_MurmurTcpLink()
{
    ClearTimer('CancelOpenAttempt_MurmurTcpLink');
}

function CancelOpenAttempt_MurmurTcpLink()
{
    if (Link != None && !Link.IsConnected())
    {
        Link.Close();
    }
}

function int MakePlayerMeta(ROPlayerReplicationInfo ROPRI, out byte Buffer[255])
{
    Buffer[1]  = EPID_PLAYER_META;
    Buffer[2]  = ROPRI.Team.TeamIndex;
    Buffer[3]  = ROPRI.SquadIndex;
    Buffer[4]  = byte(ROPRI.PlayerID);
    Buffer[5]  = byte(ROPRI.PlayerID >> 8);
    Buffer[6]  = byte(ROPRI.PlayerID >> 16);
    Buffer[7]  = byte(ROPRI.PlayerID >> 24);
    Buffer[8]  = byte(ROPRI.UniqueID.Uid.A);
    Buffer[9]  = byte(ROPRI.UniqueID.Uid.A >> 8);
    Buffer[10] = byte(ROPRI.UniqueID.Uid.A >> 16);
    Buffer[11] = byte(ROPRI.UniqueID.Uid.A >> 24);
    Buffer[12] = byte(ROPRI.UniqueID.Uid.B);
    Buffer[13] = byte(ROPRI.UniqueID.Uid.B >> 8);
    Buffer[14] = byte(ROPRI.UniqueID.Uid.B >> 16);
    Buffer[15] = byte(ROPRI.UniqueID.Uid.B >> 24);

    Buffer[0] = 16;
    return 16;
}

function int MakePlayerStoppedSpeaking(ROPlayerReplicationInfo ROPRI, out byte Buffer[255])
{
    Buffer[1] = EPID_PLAYER_STOPPED_SPEAKING;
    Buffer[2] = byte(ROPRI.PlayerID);
    Buffer[3] = byte(ROPRI.PlayerID >> 8);
    Buffer[4] = byte(ROPRI.PlayerID >> 16);
    Buffer[5] = byte(ROPRI.PlayerID >> 24);

    Buffer[0] = 6;
    return 6;
}

function int MakePlayerSpeaking(ROPlayerReplicationInfo ROPRI, out byte Buffer[255])
{
    Buffer[1] = EPID_PLAYER_SPEAKING;
    Buffer[2] = byte(ROPRI.PlayerID);
    Buffer[3] = byte(ROPRI.PlayerID >> 8);
    Buffer[4] = byte(ROPRI.PlayerID >> 16);
    Buffer[5] = byte(ROPRI.PlayerID >> 24);
    Buffer[6] = ROPRI.VOIPStatus;

    Buffer[0] = 7;
    return 7;
}

function int MakePlayerSpeakingSpatialized(ROPlayerReplicationInfo ROPRI, out byte Buffer[255])
{
    Buffer[1]  = EPID_PLAYER_SPEAKING_SPATIALIZED;
    Buffer[2]  = byte(ROPRI.PlayerID);
    Buffer[3]  = byte(ROPRI.PlayerID >> 8);
    Buffer[4]  = byte(ROPRI.PlayerID >> 16);
    Buffer[5]  = byte(ROPRI.PlayerID >> 24);
    Buffer[6]  = ROPRI.VOIPStatus;
    // Just drop fractional part for location. Close enough.
    Buffer[7]  = byte(int(ROPRI.Owner.Location.X));
    Buffer[8]  = byte(int(ROPRI.Owner.Location.X) >> 8);
    Buffer[9]  = byte(int(ROPRI.Owner.Location.X) >> 16);
    Buffer[10] = byte(int(ROPRI.Owner.Location.X) >> 24);
    Buffer[11] = byte(int(ROPRI.Owner.Location.Y));
    Buffer[12] = byte(int(ROPRI.Owner.Location.Y) >> 8);
    Buffer[13] = byte(int(ROPRI.Owner.Location.Y) >> 16);
    Buffer[14] = byte(int(ROPRI.Owner.Location.Y) >> 24);
    Buffer[15] = byte(int(ROPRI.Owner.Location.Z));
    Buffer[16] = byte(int(ROPRI.Owner.Location.Z) >> 8);
    Buffer[17] = byte(int(ROPRI.Owner.Location.Z) >> 16);
    Buffer[18] = byte(int(ROPRI.Owner.Location.Z) >> 24);
    Buffer[19] = byte(ROPRI.Owner.Rotation.Pitch);
    Buffer[20] = byte(ROPRI.Owner.Rotation.Pitch >> 8);
    Buffer[21] = byte(ROPRI.Owner.Rotation.Pitch >> 16);
    Buffer[22] = byte(ROPRI.Owner.Rotation.Pitch >> 24);
    Buffer[23] = byte(ROPRI.Owner.Rotation.Yaw);
    Buffer[24] = byte(ROPRI.Owner.Rotation.Yaw >> 8);
    Buffer[25] = byte(ROPRI.Owner.Rotation.Yaw >> 16);
    Buffer[26] = byte(ROPRI.Owner.Rotation.Yaw >> 24);
    Buffer[26] = byte(ROPRI.Owner.Rotation.Roll);
    Buffer[28] = byte(ROPRI.Owner.Rotation.Roll >> 8);
    Buffer[29] = byte(ROPRI.Owner.Rotation.Roll >> 16);
    Buffer[30] = byte(ROPRI.Owner.Rotation.Roll >> 24);

    Buffer[0] = 31;
    return 31;
}

function PlayerMetaTimer()
{
    local ROPlayerController ROPC;
    local byte Buffer[255];
    local int Count;

    if (WorldInfo.NetMode == NM_DedicatedServer && Link != None && Link.IsConnected())
    {
        ForEach WorldInfo.AllControllers(class'ROPlayerController', ROPC)
        {
            `log("PlayerMetaTimer():" @ ROPC @ "playerID="
                $ ROPC.PlayerReplicationInfo.PlayerID
                $ " A=" $ ROPC.PlayerReplicationInfo.UniqueID.Uid.A
                $ " B=" $ ROPC.PlayerReplicationInfo.UniqueID.Uid.B
                ,, self.name);
            Count = MakePlayerMeta(ROPlayerReplicationInfo(ROPC.PlayerReplicationInfo), Buffer);
            Link.SendBinary(Count, Buffer);
        }
    }
}

DefaultProperties
{

}
