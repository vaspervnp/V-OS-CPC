using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Core;

/// <summary>All the services a screen may need, in one.</summary>
public sealed class ServerContext(
    IOptions<VosNetOptions> options, Texts texts, TimeProvider time,
    UserStore users, ContentStore content, AdminStore admin, BanList bans,
    AccountService accounts, SessionRegistry sessions, ChatHub chat, ReleasesCache releases,
    ConnectionLimiter limiter, ILoggerFactory logs)
{
    public VosNetOptions Options { get; } = options.Value;
    public Texts Texts { get; } = texts;
    public TimeProvider Time { get; } = time;
    public UserStore Users { get; } = users;
    public ContentStore Content { get; } = content;
    public AdminStore Admin { get; } = admin;
    public BanList Bans { get; } = bans;
    public AccountService Accounts { get; } = accounts;
    public SessionRegistry Sessions { get; } = sessions;
    public ChatHub Chat { get; } = chat;
    public ReleasesCache Releases { get; } = releases;
    public ConnectionLimiter Limiter { get; } = limiter;
    public ILogger Log { get; } = logs.CreateLogger("VosNet.Telnet");

    /// <summary>The counts of the hour, for the summary in the log.</summary>
    public readonly Dictionary<string, int> Profiles = new();
    public int Connections;

    /// <summary>A time as the screens show it (Greece's time).</summary>
    public string Date(long unix, bool time = false)
    {
        var t = Services.Clock.FromUnix(unix);
        try { t = TimeZoneInfo.ConvertTime(t, TimeZoneInfo.FindSystemTimeZoneById("Europe/Athens")); } catch (Exception) { }
        return t.ToString(time ? "dd.MM.yy HH:mm" : "dd.MM.yy");
    }
}
