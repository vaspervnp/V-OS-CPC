namespace VosNet.Core.Services;

/// <summary>How many times something happened, by key, in the last
/// window of time (connections a minute, chat lines in 10 seconds...).</summary>
public sealed class SlidingWindow(TimeSpan window, TimeProvider time)
{
    readonly Dictionary<string, Queue<DateTimeOffset>> _hits = new();
    int _calls;

    /// <summary>Count it and say how many there are now.</summary>
    public int Hit(string key)
    {
        lock (_hits)
        {
            var q = Trim(key, create: true)!;
            q.Enqueue(time.GetUtcNow());
            if (++_calls % 1000 == 0) Sweep();
            return q.Count;
        }
    }

    public int Count(string key)
    {
        lock (_hits) return Trim(key, create: false)?.Count ?? 0;
    }

    public void Clear(string key)
    {
        lock (_hits) _hits.Remove(key);
    }

    Queue<DateTimeOffset>? Trim(string key, bool create)
    {
        if (!_hits.TryGetValue(key, out var q))
        {
            if (!create) return null;
            _hits[key] = q = new();
        }
        var from = time.GetUtcNow() - window;
        while (q.Count > 0 && q.Peek() <= from) q.Dequeue();
        return q;
    }

    void Sweep()
    {
        foreach (var k in _hits.Keys.ToList())
            if (Trim(k, false) is { Count: 0 }) _hits.Remove(k);
    }
}
