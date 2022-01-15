class MurmurTcpLink extends TcpLink
    config(Mutator_VOIP_Config);

// Needed to cancel Open() if it fails to prevent log spam.
// Timers don't work inside this class while Open() call is "blocking".
var VOIPTestMutator Parent;

var config int ConfigVer;
var config bool bRetryOnClose;
var config float RetryDelay;
var config string MurmurHost;
var config int MurmurPort;

function PreBeginPlay()
{
    if (ConfigVer < `MURMURTCPLINK_CONFIG_VERSION)
    {
        `log("ConfigVer changed, old: " $ ConfigVer $ " new: " $ `MURMURTCPLINK_CONFIG_VERSION,, self.name);
        `log("Restoring default config values!",, self.name);
        bRetryOnClose = True;
        RetryDelay = 1.0;
        ConfigVer = `MURMURTCPLINK_CONFIG_VERSION;
        SaveConfig();
    }
    else if (RetryDelay < 1.0)
    {
        RetryDelay = 1.0;
        SaveConfig();
    }

    super.PreBeginPlay();
}

function ResolveServer()
{
    `log("attempting to resolve 'localhost'",, self.name);
    Parent.Set_CancelOpenAttempt_MurmurTcpLink(5.0);
    Resolve(MurmurHost);
}

event Resolved(IpAddr Addr)
{
    local int BoundPort;

    Addr.Port = MurmurPort;

    `log("resolved" @ IpAddrToString(Addr),, self.name);

    BoundPort = BindPort();
    if (BoundPort == 0)
    {
        `log("failed to bind port",, self.name);
        RetryResolve();
        return;
    }

    `log("bound to port: " $ BoundPort,, self.name);

    if (!Open(Addr))
    {
        `log("failed to open connection to" @ IpAddrToString(Addr),, self.name);
        RetryResolve();
        return;
    }
}

event Opened()
{
    Parent.Clear_CancelOpenAttempt_MurmurTcpLink();
}

event Closed()
{
    if (bRetryOnClose)
    {
        RetryResolve();
    }
}

event ResolveFailed()
{
    RetryResolve();
}

function RetryResolve()
{
    Parent.Clear_CancelOpenAttempt_MurmurTcpLink();
    Parent.CancelOpenAttempt_MurmurTcpLink();
    CheckError();
    `log("retrying resolve in " $ RetryDelay $ " second(s)",, self.name);
    SetTimer(RetryDelay, False, 'ResolveServer');
}

function bool CloseNoRetry()
{
    bRetryOnClose = False;
    return Close();
}

function CheckError()
{
    `log("last WinSock error:" @ GetLastError(),, self.Name);
}

DefaultProperties
{
    LinkMode=MODE_Binary
    ReceiveMode=RMODE_Event
}
