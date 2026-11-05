using System.Buffers;
using System.IO.Pipelines;
using System.Text;
using System.Threading.Channels;

namespace VosNet.Telnet;

/// <summary>One telnet connection over a stream (a socket's, or a pipe's
/// in the tests): the bytes read by System.IO.Pipelines through the
/// <see cref="TelnetParser"/>, the options by the
/// <see cref="OptionNegotiator"/>, the data by the
/// <see cref="LineReader"/> into lines. Text goes out in the
/// <see cref="Profile"/>'s encoding, IAC doubled. Writes may come from
/// several tasks (the chat); they go one at a time.</summary>
public sealed class TelnetConnection : IAsyncDisposable
{
    readonly Stream _stream;
    readonly TimeProvider _time;
    readonly TelnetParser _parser = new();
    readonly OptionNegotiator _options;
    readonly LineReader _reader = new();
    readonly Channel<byte[]> _lines = Channel.CreateBounded<byte[]>(new BoundedChannelOptions(16) { SingleWriter = true });
    readonly SemaphoreSlim _writeLock = new(1, 1);
    readonly SemaphoreSlim _negotiated = new(0);
    readonly CancellationTokenSource _closed = new();
    Task _readLoop = Task.CompletedTask;

    public TelnetConnection(Stream stream, TimeProvider? time = null)
    {
        _stream = stream;
        _time = time ?? TimeProvider.System;
        _options = new OptionNegotiator(opt => opt is Telnet.TTYPE or Telnet.NAWS);
        _options.Changed += OnChanged;
        LastInput = _start = _time.GetUtcNow();
    }

    public TerminalProfile Profile { get; set; } = TerminalProfile.Ascii;
    public OptionNegotiator Options => _options;
    public string? TerminalType { get; private set; }
    public int NawsWidth { get; private set; }
    public int NawsHeight { get; private set; }
    public bool Password { get; private set; }
    /// <summary>A WILL, WONT, DO or DONT has come: a telnet client.</summary>
    public bool Negotiated { get; private set; }
    public DateTimeOffset LastInput { get; private set; }
    /// <summary>When the first answer to an option came, from the start.</summary>
    public TimeSpan? FirstAnswer { get; private set; }
    /// <summary>The profile set by the user (TERM): no more guessing.</summary>
    public bool ProfileFixed { get; set; }
    /// <summary>Raised when an answer late for <see cref="DetectAsync"/>
    /// changes a plain profile (the M4 may answer seconds late).</summary>
    public event Action? ProfileChanged;
    bool _detected;
    readonly DateTimeOffset _start;
    public long BytesIn { get; private set; }
    public long BytesOut { get; private set; }
    public CancellationToken Closed => _closed.Token;
    public bool IsClosed => _closed.IsCancellationRequested;

    public void Start() => _readLoop = Task.Run(ReadLoopAsync);

    async Task ReadLoopAsync()
    {
        var pipe = PipeReader.Create(_stream, new StreamPipeReaderOptions(bufferSize: 1024));
        var events = new List<TelnetEvent>();
        try
        {
            while (true)
            {
                var r = await pipe.ReadAsync(_closed.Token);
                foreach (var seg in r.Buffer)
                {
                    events.Clear();
                    BytesIn += seg.Length;
                    _parser.Parse(seg.Span, events);
                    await HandleAsync(events);
                }
                pipe.AdvanceTo(r.Buffer.End);
                if (r.IsCompleted) break;
            }
        }
        catch (Exception) { }
        finally
        {
            _lines.Writer.TryComplete();
            _closed.Cancel();
            await pipe.CompleteAsync();
        }
    }

    async Task HandleAsync(List<TelnetEvent> events)
    {
        var output = new List<byte>();
        bool late = false;
        foreach (var e in events)
        {
            switch (e.Kind)
            {
                case TelnetEventKind.Data:
                    LastInput = _time.GetUtcNow();
                    foreach (var b in e.Data)
                    {
                        switch (_reader.Feed(b))
                        {
                            case LineResult.Added when EchoStars:
                                output.Add((byte)'*');
                                break;
                            case LineResult.Erased when EchoStars:
                                output.AddRange("\b \b"u8.ToArray());
                                break;
                            case LineResult.Line:
                                if (EchoStars) output.AddRange("\r\n"u8.ToArray());
                                await FlushAsync(output);
                                await _lines.Writer.WriteAsync(_reader.Last, _closed.Token);
                                break;
                        }
                    }
                    break;
                case TelnetEventKind.Negotiation:
                    Negotiated = true;
                    FirstAnswer ??= _time.GetUtcNow() - _start;
                    _options.Receive(e.Verb, e.Option, output);
                    _negotiated.Release();
                    if (_detected && !ProfileFixed && Profile.Kind == TerminalKind.Ascii && e.Option is Telnet.TTYPE or Telnet.NAWS)
                    {
                        if (e.Verb == Telnet.WILL) Profile = TerminalProfile.Utf8(NawsWidth, NawsHeight);
                        else if (e.Verb == Telnet.WONT) Profile = TerminalProfile.Vos;
                        if (Profile.Kind != TerminalKind.Ascii) late = true;
                    }
                    break;
                case TelnetEventKind.Subnegotiation:
                    Subnegotiation(e.Option, e.Data);
                    _negotiated.Release();
                    break;
                case TelnetEventKind.Command when e.Verb == Telnet.AYT:
                    output.AddRange("\r\n[YES]\r\n"u8.ToArray());
                    break;
            }
        }
        await FlushAsync(output);
        if (late) ProfileChanged?.Invoke();
    }

    bool EchoStars => Password && _options.IsUs(Telnet.ECHO);

    List<byte>? _pendingSb;

    void OnChanged(byte opt, bool us, bool on)
    {
        if (!us && on && opt == Telnet.TTYPE)       // what terminal are you?
            (_pendingSb ??= []).AddRange([Telnet.IAC, Telnet.SB, Telnet.TTYPE, Telnet.SEND, Telnet.IAC, Telnet.SE]);
    }

    void Subnegotiation(byte opt, byte[] data)
    {
        if (opt == Telnet.NAWS && data.Length == 4)
        {
            NawsWidth = data[0] << 8 | data[1];
            NawsHeight = data[2] << 8 | data[3];
            if (Profile.Kind == TerminalKind.Utf8) Profile = TerminalProfile.Utf8(NawsWidth, NawsHeight);
        }
        else if (opt == Telnet.TTYPE && data.Length > 1 && data[0] == Telnet.IS)
            TerminalType = Encoding.ASCII.GetString(data, 1, Math.Min(data.Length - 1, 40));
    }

    async Task FlushAsync(List<byte> output)
    {
        if (_pendingSb is { Count: > 0 }) { output.AddRange(_pendingSb); _pendingSb.Clear(); }
        if (output.Count == 0) return;
        var b = output.ToArray();
        output.Clear();
        await WriteRawAsync(b);
    }

    /// <summary>§5: DO TTYPE, DO NAWS, and up to <paramref name="wait"/>
    /// for the answers. WILL → a common client, WONT (V-OS refuses all) →
    /// V-OS, nothing → plain.</summary>
    public async Task<TerminalProfile> DetectAsync(TimeSpan wait, CancellationToken ct)
    {
        var output = new List<byte>();
        _options.AskHim(Telnet.TTYPE, true, output);
        _options.AskHim(Telnet.NAWS, true, output);
        await FlushAsync(output);
        var end = _time.GetUtcNow() + wait;
        while (!(_options.HimAnswered(Telnet.TTYPE) && _options.HimAnswered(Telnet.NAWS)))
        {
            var left = end - _time.GetUtcNow();
            if (left <= TimeSpan.Zero || IsClosed) break;
            await WaitNegotiationAsync(left, ct);
        }
        bool will = _options.IsHim(Telnet.TTYPE) || _options.IsHim(Telnet.NAWS);
        if (will)
        {
            // the size and the name come right after WILL
            var more = _time.GetUtcNow() + TimeSpan.FromMilliseconds(500);
            while ((_options.IsHim(Telnet.NAWS) && NawsWidth == 0 || _options.IsHim(Telnet.TTYPE) && TerminalType == null)
                   && _time.GetUtcNow() < more && !IsClosed)
                await WaitNegotiationAsync(more - _time.GetUtcNow(), ct);
            Profile = TerminalProfile.Utf8(NawsWidth, NawsHeight);
        }
        else if (_options.HimAnswered(Telnet.TTYPE) || _options.HimAnswered(Telnet.NAWS))
            Profile = TerminalProfile.Vos;
        else
            Profile = TerminalProfile.Ascii;
        _detected = true;
        return Profile;
    }

    async Task WaitNegotiationAsync(TimeSpan left, CancellationToken ct)
    {
        if (left <= TimeSpan.Zero) return;
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct, _closed.Token);
        var delay = Task.Delay(left, _time, cts.Token);
        var got = _negotiated.WaitAsync(cts.Token);
        await Task.WhenAny(delay, got);
        cts.Cancel();
        try { await got; } catch (OperationCanceledException) { }
        try { await delay; } catch (OperationCanceledException) { }
    }

    /// <summary>The next line, or null when the connection is closed.</summary>
    public async Task<string?> ReadLineAsync(CancellationToken ct)
    {
        try
        {
            var line = await _lines.Reader.ReadAsync(ct);
            return Profile.Decode(line);
        }
        catch (ChannelClosedException) { return null; }
    }

    /// <summary>The password asked: WILL ECHO (common clients then show
    /// nothing, we answer * for each character), WONT ECHO after it.</summary>
    public async Task SetPasswordAsync(bool on)
    {
        Password = on;
        var output = new List<byte>();
        _options.SetUs(Telnet.ECHO, on, output);
        await FlushAsync(output);
    }

    public Task WriteAsync(string text) => WriteRawAsync(Profile.Encode(text));

    public async Task WriteRawAsync(byte[] bytes)
    {
        if (IsClosed) return;
        await _writeLock.WaitAsync();
        try
        {
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(_closed.Token);
            cts.CancelAfter(TimeSpan.FromSeconds(30));          // a client that reads nothing
            await _stream.WriteAsync(bytes, cts.Token);
            await _stream.FlushAsync(cts.Token);
            BytesOut += bytes.Length;
        }
        catch (Exception) { _closed.Cancel(); }
        finally { _writeLock.Release(); }
    }

    public void Close() => _closed.Cancel();

    public async ValueTask DisposeAsync()
    {
        _closed.Cancel();
        try { await _stream.DisposeAsync(); } catch (Exception) { }
        try { await _readLoop; } catch (Exception) { }
    }
}
