using System.Net;
using VosNet.Core.Storage;

namespace VosNet.Core.Services;

/// <summary>The bans of the table, kept in memory and matched against an
/// address: an IP or a CIDR range (IPv4 or IPv6).</summary>
public sealed class BanList
{
    readonly AdminStore _store;
    readonly TimeProvider _time;
    List<(BanRow Row, IPNetwork Net)> _bans = [];

    public BanList(AdminStore store, TimeProvider time)
    {
        _store = store;
        _time = time;
        Reload();
    }

    public void Reload()
    {
        var list = new List<(BanRow, IPNetwork)>();
        foreach (var b in _store.Bans(_time.Unix()))
            if (TryParse(b.IpOrCidr, out var net)) list.Add((b, net));
        _bans = list;
    }

    public static bool TryParse(string s, out IPNetwork net)
    {
        s = s.Trim();
        if (IPNetwork.TryParse(s, out net)) return true;
        if (IPAddress.TryParse(s, out var ip))
        {
            net = new IPNetwork(ip, ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork ? 32 : 128);
            return true;
        }
        return false;
    }

    public static IPAddress Normal(IPAddress ip) => ip.IsIPv4MappedToIPv6 ? ip.MapToIPv4() : ip;

    public BanRow? Find(IPAddress ip)
    {
        ip = Normal(ip);
        var now = _time.Unix();
        foreach (var (row, net) in _bans)
            if ((row.Until == null || row.Until > now) && net.Contains(ip)) return row;
        return null;
    }

    public void Add(string ipOrCidr, TimeSpan? time, string reason, string by)
    {
        var now = _time.Unix();
        _store.AddBan(ipOrCidr, time is { } t ? now + (long)t.TotalSeconds : null, reason, by, now);
        Reload();
    }

    public void Remove(long id)
    {
        _store.DeleteBan(id);
        Reload();
    }
}
