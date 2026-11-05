using System.Net;
using Microsoft.Extensions.Options;

namespace VosNet.Core.Services;

public enum Admission { Ok, Banned, Full, TooManyFromIp, TooFast }

/// <summary>§7's limits on connections: 200 in all, 4 from an IP, 10 new
/// a minute from an IP; and the robots: an IP whose connections end more
/// than 20 times an hour without reaching the menu is banned for a day.</summary>
public sealed class ConnectionLimiter
{
    readonly VosNetOptions _o;
    readonly BanList _bans;
    readonly SlidingWindow _new, _robots;
    readonly Dictionary<string, int> _open = new();
    int _total;

    public ConnectionLimiter(IOptions<VosNetOptions> o, BanList bans, TimeProvider time)
    {
        _o = o.Value;
        _bans = bans;
        _new = new(TimeSpan.FromMinutes(1), time);
        _robots = new(TimeSpan.FromHours(1), time);
    }

    public int Open { get { lock (_open) return _total; } }

    /// <summary>Counts of the hour (for the summary in the log).</summary>
    public int Refused;

    public Admission TryAdmit(IPAddress ip)
    {
        var key = BanList.Normal(ip).ToString();
        Admission a;
        if (_bans.Find(ip) != null) a = Admission.Banned;
        else lock (_open)
        {
            if (_total >= _o.MaxConnections) a = Admission.Full;
            else if (_new.Hit(key) > _o.NewPerMinutePerIp) a = Admission.TooFast;
            else if (_open.GetValueOrDefault(key) >= _o.MaxPerIp) a = Admission.TooManyFromIp;
            else
            {
                _open[key] = _open.GetValueOrDefault(key) + 1;
                _total++;
                return Admission.Ok;
            }
        }
        Interlocked.Increment(ref Refused);
        return a;
    }

    /// <summary>A connection ended; <paramref name="reachedMenu"/>: it got
    /// past the welcome and the login.</summary>
    public void Release(IPAddress ip, bool reachedMenu)
    {
        var key = BanList.Normal(ip).ToString();
        lock (_open)
        {
            if (_open.TryGetValue(key, out var n))
            {
                if (n <= 1) _open.Remove(key); else _open[key] = n - 1;
                _total--;
            }
        }
        if (!reachedMenu && _robots.Hit(key) > _o.RobotConnectionsPerHour)
        {
            _robots.Clear(key);
            _bans.Add(key, _o.RobotBan, "ROBOT: CONNECTIONS WITHOUT THE MENU", "SERVER");
        }
    }
}
