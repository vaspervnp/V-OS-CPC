using System.Net.Sockets;
using System.Text;
using VosNet.Telnet;
using T = VosNet.Telnet.Telnet;

namespace VosNet.Tests;

/// <summary>A telnet client for the scenarios. As V-OS's TELNET
/// (<see cref="Vos"/>): it refuses every option (DO: WONT, WILL: DONT),
/// sends lines of at most 45 characters with CR LF, reads the V-OS set,
/// and checks what V-OS would see: no row over 48 columns (as its window
/// counts them: CR to the start, LF a new row), no ANSI, no echo. As a
/// common client: WILL TTYPE and NAWS (100×30), DO ECHO when the server
/// offers it, UTF-8.</summary>
public sealed class TestClient : IAsyncDisposable
{
    readonly TcpClient _tcp = new();
    NetworkStream _s = null!;
    readonly StringBuilder _text = new();
    readonly object _lock = new();
    readonly SemaphoreSlim _more = new(0);
    Task _reader = Task.CompletedTask;
    int _col, _seen;
    readonly List<(string Line, int At)> _sent = [];

    public bool Vos { get; }
    public int MaxColumns { get; private set; }
    public bool SawEsc { get; private set; }
    public bool ServerEcho { get; private set; }      // the server's WILL ECHO accepted
    public List<(byte Verb, byte Option)> Negotiations { get; } = [];
    public string Text { get { lock (_lock) return _text.ToString(); } }
    public bool Closed { get; private set; }

    TestClient(bool vos) => Vos = vos;

    /// <summary>The answers to the options this late (the M4 board's are
    /// seconds late).</summary>
    public int AnswerDelayMs { get; init; }

    /// <summary>V-OS's TELNET from 0.54: WILL TTYPE, IS "V-OS", and the
    /// server's ECHO taken (DO), the other options still refused.</summary>
    public bool Ttype { get; init; }

    public static async Task<TestClient> ConnectAsync(int port, bool vos = true, int answerDelayMs = 0, bool ttype = false)
    {
        var c = new TestClient(vos) { AnswerDelayMs = answerDelayMs, Ttype = ttype };
        await c._tcp.ConnectAsync("127.0.0.1", port);
        c._s = c._tcp.GetStream();
        c._reader = Task.Run(c.ReadLoop);
        return c;
    }

    async Task ReadLoop()
    {
        var buf = new byte[4096];
        var data = new List<byte>();
        int state = 0;
        byte verb = 0;
        try
        {
            while (true)
            {
                int n = await _s.ReadAsync(buf);
                if (n == 0) break;
                data.Clear();
                for (int i = 0; i < n; i++)
                {
                    var b = buf[i];
                    switch (state)
                    {
                        case 0:
                            if (b == T.IAC) state = 1; else data.Add(b);
                            break;
                        case 1:
                            if (b == T.IAC) { data.Add(b); state = 0; }
                            else if (b is T.WILL or T.WONT or T.DO or T.DONT) { verb = b; state = 2; }
                            else if (b == T.SB) state = 3;
                            else state = 0;
                            break;
                        case 2:
                            state = 0;
                            await NegotiateAsync(verb, b);
                            break;
                        case 3:                         // SB ... IAC SE
                            if (b == T.IAC) state = 4;
                            break;
                        case 4:
                            state = b == T.SE ? 0 : 3;
                            if (b == T.SE && !Vos) await SendRaw([T.IAC, T.SB, T.TTYPE, T.IS, .. "XTERM"u8, T.IAC, T.SE]);
                            if (b == T.SE && Ttype) await SendRaw([T.IAC, T.SB, T.TTYPE, T.IS, .. "V-OS"u8, T.IAC, T.SE]);
                            break;
                    }
                }
                var text = Vos ? VosEncoding.Instance.GetString(data.ToArray()) : Encoding.UTF8.GetString(data.ToArray());
                foreach (var ch in text)
                {
                    if (ch == '\x1b') SawEsc = true;
                    if (ch == '\r') _col = 0;
                    else if (ch == '\n') _col = 0;
                    else if (ch == '\b') _col = Math.Max(0, _col - 1);
                    else if (ch >= ' ') { _col++; MaxColumns = Math.Max(MaxColumns, _col); }
                }
                lock (_lock) _text.Append(text);
                _more.Release();
            }
        }
        catch (Exception) { }
        Closed = true;
        _more.Release();
    }

    async Task NegotiateAsync(byte verb, byte opt)
    {
        lock (_lock) Negotiations.Add((verb, opt));
        if (Vos && Ttype)
        {
            if (verb == T.DO && opt == T.TTYPE) await SendRaw([T.IAC, T.WILL, opt]);
            else if (verb == T.WILL && opt == T.ECHO) { ServerEcho = true; await SendRaw([T.IAC, T.DO, opt]); }
            else if (verb == T.WONT && opt == T.ECHO) { if (ServerEcho) await SendRaw([T.IAC, T.DONT, opt]); ServerEcho = false; }
            else if (verb == T.DO) await SendRaw([T.IAC, T.WONT, opt]);
            else if (verb == T.WILL) await SendRaw([T.IAC, T.DONT, opt]);
            return;
        }
        if (Vos)
        {
            byte[] answer = verb == T.DO ? [T.IAC, T.WONT, opt] : verb == T.WILL ? [T.IAC, T.DONT, opt] : [];
            if (answer.Length == 0) return;
            if (AnswerDelayMs == 0) await SendRaw(answer);
            else _ = Task.Run(async () => { await Task.Delay(AnswerDelayMs); await SendRaw(answer); });
            return;
        }
        if (verb == T.DO && opt is T.TTYPE or T.NAWS)
        {
            await SendRaw([T.IAC, T.WILL, opt]);
            if (opt == T.NAWS) await SendRaw([T.IAC, T.SB, T.NAWS, 0, 100, 0, 30, T.IAC, T.SE]);
        }
        else if (verb == T.DO) await SendRaw([T.IAC, T.WONT, opt]);
        else if (verb == T.WILL && opt == T.ECHO) { ServerEcho = true; await SendRaw([T.IAC, T.DO, opt]); }
        else if (verb == T.WONT && opt == T.ECHO) { if (ServerEcho) await SendRaw([T.IAC, T.DONT, opt]); ServerEcho = false; }
        else if (verb == T.WILL) await SendRaw([T.IAC, T.DONT, opt]);
    }

    public async Task SendRaw(byte[] b)
    {
        await _s.WriteAsync(b);
        await _s.FlushAsync();
    }

    /// <summary>A line, as V-OS sends it: at most 45 characters, CR LF.</summary>
    public async Task SendAsync(string line)
    {
        if (Vos && line.Length > 45) throw new ArgumentException("V-OS sends at most 45 characters");
        lock (_lock) { _seen = _text.Length; _sent.Add((line, _text.Length)); }
        var enc = Vos ? (Encoding)VosEncoding.Instance : Encoding.UTF8;
        await SendRaw([.. enc.GetBytes(line), 13, 10]);
    }

    /// <summary>A character at a time, as PuTTY while the password is asked.</summary>
    public async Task TypeAsync(string line)
    {
        foreach (var ch in Encoding.UTF8.GetBytes(line)) await SendRaw([ch]);
        await SendRaw([13, 0]);
    }

    /// <summary>Waits for <paramref name="what"/> in what came after the last line sent.</summary>
    public async Task<string> WaitAsync(string what, int seconds = 10)
    {
        var end = DateTime.UtcNow.AddSeconds(seconds);
        while (true)
        {
            string after;
            lock (_lock) after = _text.ToString(_seen, _text.Length - _seen);
            if (after.Contains(what)) return after;
            if (Closed) throw new Xunit.Sdk.XunitException($"Closed before \"{what}\". Got:\n{after}");
            var left = end - DateTime.UtcNow;
            if (left <= TimeSpan.Zero) throw new Xunit.Sdk.XunitException($"No \"{what}\" in:\n{after}");
            await _more.WaitAsync(left);
        }
    }

    public async Task WaitClosedAsync(int seconds = 10)
    {
        var end = DateTime.UtcNow.AddSeconds(seconds);
        while (!Closed && DateTime.UtcNow < end) await _more.WaitAsync(TimeSpan.FromMilliseconds(200));
        if (!Closed) throw new Xunit.Sdk.XunitException("Still open");
    }

    /// <summary>Is a line sent written back, as an echo would be: what
    /// came right after it begins with it?</summary>
    public bool Echoed()
    {
        var t = Text;
        lock (_lock) return _sent.Any(s => s.Line.Length > 0 && t[s.At..].TrimStart('\r', '\n').StartsWith(s.Line));
    }

    /// <summary>What V-OS's window would show: in order, no row over 48, no ANSI, no echo.</summary>
    public void AssertVosScreen()
    {
        Xunit.Assert.True(MaxColumns <= 48, $"a row of {MaxColumns} columns");
        Xunit.Assert.False(SawEsc, "an ANSI sequence");
        Xunit.Assert.False(Echoed(), "a line echoed");
    }

    public async ValueTask DisposeAsync()
    {
        _tcp.Dispose();
        try { await _reader; } catch (Exception) { }
    }
}
