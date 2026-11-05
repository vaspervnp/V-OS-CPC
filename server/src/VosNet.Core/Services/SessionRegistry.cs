using System.Collections.Concurrent;
using VosNet.Core.Screens;

namespace VosNet.Core.Services;

/// <summary>Who is connected now: for WHO, the chat, one connection a
/// user and the web's overview (where a connection can be closed).</summary>
public sealed class SessionRegistry
{
    readonly ConcurrentDictionary<Guid, Session> _sessions = new();
    readonly object _claim = new();

    public void Add(Session s) => _sessions[s.Id] = s;
    public void Remove(Session s) => _sessions.TryRemove(s.Id, out _);

    public int Count => _sessions.Count;
    public IReadOnlyList<Session> All => _sessions.Values.OrderBy(s => s.Since).ToList();
    public Session? Get(Guid id) => _sessions.GetValueOrDefault(id);

    public Session? ByUser(long userId) =>
        _sessions.Values.FirstOrDefault(s => s.User?.Id == userId);

    public Session? ByName(string name) =>
        _sessions.Values.FirstOrDefault(s => s.User != null && string.Equals(s.User.Name, name, StringComparison.OrdinalIgnoreCase));

    /// <summary>A user logged in on <paramref name="s"/>: their other
    /// connection, if any, closes with "LOGGED IN FROM ELSEWHERE".</summary>
    public async Task ClaimAsync(Session s, long userId)
    {
        Session? old;
        lock (_claim) old = _sessions.Values.FirstOrDefault(x => x != s && x.User?.Id == userId);
        if (old != null) await old.KickAsync("login.elsewhere");
    }

    /// <summary>A message to all (the server restarting).</summary>
    public Task NotifyAllAsync(string key) =>
        Task.WhenAll(_sessions.Values.Select(s => s.NoticeAsync(key)));
}
