using System.Threading.Channels;
using Microsoft.Extensions.Options;
using VosNet.Core.Screens;

namespace VosNet.Core.Services;

public enum ChatKind { Say, Me, System }

/// <summary>A line of the chat. A system line is a text key and its
/// arguments, written in each one's language.</summary>
public sealed record ChatMessage(long Id, DateTimeOffset At, string From, string Text, ChatKind Kind, object?[]? Args = null);

/// <summary>The one chat room: a bounded channel for each one in it
/// (DropOldest, so a slow client does not hold the others), the last 20
/// lines for who comes in, 5 lines in 10 seconds each, the moderators'
/// /kick, /mute and /del.</summary>
public sealed class ChatHub
{
    public const int History = 20;

    sealed class Member(Session s)
    {
        public Session Session { get; } = s;
        public Channel<ChatMessage> Box { get; } = Channel.CreateBounded<ChatMessage>(
            new BoundedChannelOptions(50) { FullMode = BoundedChannelFullMode.DropOldest, SingleReader = true });
    }

    readonly List<Member> _members = [];
    readonly LinkedList<ChatMessage> _history = new();
    readonly Dictionary<string, DateTimeOffset> _muted = new(StringComparer.OrdinalIgnoreCase);
    readonly SlidingWindow _rate;
    readonly VosNetOptions _o;
    readonly TimeProvider _time;
    long _nextId;

    public ChatHub(IOptions<VosNetOptions> o, TimeProvider time)
    {
        _o = o.Value;
        _time = time;
        _rate = new(_o.ChatWindow, time);
    }

    public IReadOnlyList<Session> Members { get { lock (_members) return _members.Select(m => m.Session).ToList(); } }

    public (ChannelReader<ChatMessage> Box, List<ChatMessage> Last) Join(Session s)
    {
        var m = new Member(s);
        List<ChatMessage> last;
        lock (_members)
        {
            _members.Add(m);
            last = _history.ToList();
        }
        Post(new(0, default, s.Name, "chat.joined", ChatKind.System, [s.Name]), except: s);
        return (m.Box.Reader, last);
    }

    public void Leave(Session s)
    {
        bool was;
        lock (_members) was = _members.RemoveAll(m => m.Session == s) > 0;
        if (was) Post(new(0, default, s.Name, "chat.left", ChatKind.System, [s.Name]));
    }

    public bool IsMuted(string name)
    {
        lock (_muted) return _muted.TryGetValue(name, out var until) && until > _time.GetUtcNow();
    }

    /// <summary>false: too fast (5 lines in 10 seconds).</summary>
    public bool Say(Session s, string text, bool me = false)
    {
        if (_rate.Hit(s.Name) > _o.ChatLines) return false;
        Post(new(0, default, s.Name, text, me ? ChatKind.Me : ChatKind.Say));
        return true;
    }

    void Post(ChatMessage msg, Session? except = null)
    {
        List<Member> to;
        lock (_members)
        {
            msg = msg with { Id = ++_nextId, At = _time.GetUtcNow() };
            if (msg.Kind != ChatKind.System)
            {
                _history.AddLast(msg);
                while (_history.Count > History) _history.RemoveFirst();
            }
            to = _members.Where(m => m.Session != except).ToList();
        }
        foreach (var m in to) m.Box.Writer.TryWrite(msg);
    }

    public void System(string key, params object?[] args) => Post(new(0, default, "", key, ChatKind.System, args));

    /// <summary>/del: a line away from the history.</summary>
    public bool Delete(long id)
    {
        lock (_members)
        {
            var n = _history.First;
            while (n != null && n.Value.Id != id) n = n.Next;
            if (n == null) return false;
            _history.Remove(n);
        }
        System("chat.deleted", id);
        return true;
    }

    public void Mute(string name, TimeSpan time)
    {
        lock (_muted) _muted[name] = _time.GetUtcNow() + time;
        System("chat.muted", name.ToUpperInvariant(), (int)time.TotalMinutes);
    }

    public Session? Find(string name)
    {
        lock (_members) return _members.FirstOrDefault(m => string.Equals(m.Session.Name, name, StringComparison.OrdinalIgnoreCase))?.Session;
    }
}
