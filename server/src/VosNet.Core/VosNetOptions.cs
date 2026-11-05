namespace VosNet.Core;

/// <summary>The settings (appsettings.json, section "VosNet", or the
/// variables VOSNET__...).</summary>
public sealed class VosNetOptions
{
    public const string Section = "VosNet";

    /// <summary>The telnet ports, "23,2323"; 0 a free one (the tests).</summary>
    public string TelnetPorts { get; set; } = "23,2323";
    /// <summary>Where the web listens: only 127.0.0.1 (Caddy in front).</summary>
    public string Web { get; set; } = "http://127.0.0.1:5080";
    public string Database { get; set; } = "vosnet.db";
    /// <summary>Data Protection's keys (the web's cookies); by default
    /// "keys" next to the database.</summary>
    public string? Keys { get; set; }
    public string Texts { get; set; } = "texts";
    public string GitHubRepo { get; set; } = "vaspervnp/V-OS-CPC";
    public bool FetchReleases { get; set; } = true;
    public string HostName { get; set; } = "vos.revive8bit.com";
    /// <summary>V-OS's version on the welcome until GitHub's is known.</summary>
    public string VosVersion { get; set; } = "0.53";

    public int MaxConnections { get; set; } = 200;
    public int MaxPerIp { get; set; } = 4;
    public int NewPerMinutePerIp { get; set; } = 10;
    /// <summary>How long to wait for the answers to DO TTYPE, DO NAWS
    /// (§5 says 2 seconds; the M4 board in the 1984 emulator took 3.4). A
    /// later answer still changes a plain profile.</summary>
    public TimeSpan DetectWait { get; set; } = TimeSpan.FromSeconds(4);
    public TimeSpan ChoiceTimeout { get; set; } = TimeSpan.FromSeconds(60);
    public TimeSpan IdleWarning { get; set; } = TimeSpan.FromMinutes(13);
    public TimeSpan IdleClose { get; set; } = TimeSpan.FromMinutes(15);
    /// <summary>Connections an hour from an IP that never reach the menu
    /// before it is banned for <see cref="RobotBan"/>.</summary>
    public int RobotConnectionsPerHour { get; set; } = 20;
    public TimeSpan RobotBan { get; set; } = TimeSpan.FromHours(24);
    public int ChatLines { get; set; } = 5;
    public TimeSpan ChatWindow { get; set; } = TimeSpan.FromSeconds(10);
    public TimeSpan PostInterval { get; set; } = TimeSpan.FromMinutes(1);
    public int RegistrationsPerDay { get; set; } = 3;
    public int LoginFailuresToLock { get; set; } = 5;
    public TimeSpan LockTime { get; set; } = TimeSpan.FromMinutes(15);
    public int IpFailuresPerHour { get; set; } = 20;
    public TimeSpan IpFailureBan { get; set; } = TimeSpan.FromHours(24);

    public IEnumerable<int> Ports() =>
        TelnetPorts.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(int.Parse).Distinct();
}
