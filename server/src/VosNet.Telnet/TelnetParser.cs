namespace VosNet.Telnet;

public enum TelnetEventKind { Data, Command, Negotiation, Subnegotiation }

/// <summary>One thing the parser found: data bytes, a command (NOP,
/// AYT...), a negotiation (WILL/WONT/DO/DONT + option) or a
/// subnegotiation (option + its bytes, IAC IAC undone).</summary>
public readonly record struct TelnetEvent(TelnetEventKind Kind, byte Verb, byte Option, byte[] Data)
{
    public static TelnetEvent Bytes(byte[] d) => new(TelnetEventKind.Data, 0, 0, d);
}

/// <summary>Bytes from the network → events. It keeps its state between
/// calls, so a command or a subnegotiation may come in pieces. IAC IAC is
/// the byte 255; a subnegotiation over <see cref="MaxSubnegotiation"/>
/// bytes is dropped up to its IAC SE.</summary>
public sealed class TelnetParser
{
    public const int MaxSubnegotiation = 64;

    enum State { Data, Iac, Verb, SbOption, SbData, SbIac }

    State _state;
    byte _verb, _sbOption;
    bool _sbTooLong;
    readonly List<byte> _sb = new(MaxSubnegotiation);
    readonly List<byte> _data = new(256);

    /// <summary>How many subnegotiations were dropped for their size.</summary>
    public int Dropped { get; private set; }

    public void Parse(ReadOnlySpan<byte> input, List<TelnetEvent> events)
    {
        foreach (var b in input)
        {
            switch (_state)
            {
                case State.Data:
                    if (b == Telnet.IAC) _state = State.Iac;
                    else _data.Add(b);
                    break;
                case State.Iac:
                    switch (b)
                    {
                        case Telnet.IAC:
                            _data.Add(b);
                            _state = State.Data;
                            break;
                        case Telnet.WILL or Telnet.WONT or Telnet.DO or Telnet.DONT:
                            _verb = b;
                            _state = State.Verb;
                            break;
                        case Telnet.SB:
                            _state = State.SbOption;
                            break;
                        default:
                            Flush(events);
                            events.Add(new(TelnetEventKind.Command, b, 0, []));
                            _state = State.Data;
                            break;
                    }
                    break;
                case State.Verb:
                    Flush(events);
                    events.Add(new(TelnetEventKind.Negotiation, _verb, b, []));
                    _state = State.Data;
                    break;
                case State.SbOption:
                    _sbOption = b;
                    _sb.Clear();
                    _sbTooLong = false;
                    _state = State.SbData;
                    break;
                case State.SbData:
                    if (b == Telnet.IAC) _state = State.SbIac;
                    else AddSb(b);
                    break;
                case State.SbIac:
                    if (b == Telnet.IAC)
                    {
                        AddSb(b);
                        _state = State.SbData;
                    }
                    else if (b == Telnet.SE)
                    {
                        if (_sbTooLong) Dropped++;
                        else
                        {
                            Flush(events);
                            events.Add(new(TelnetEventKind.Subnegotiation, Telnet.SB, _sbOption, _sb.ToArray()));
                        }
                        _state = State.Data;
                    }
                    else
                    {
                        // IAC and something else inside SB: the SB was cut
                        // short (RFC 1143's robustness); the command counts
                        Dropped++;
                        _state = State.Iac;
                        Parse([b], events);
                        continue;
                    }
                    break;
            }
        }
        Flush(events);
    }

    void AddSb(byte b)
    {
        if (_sb.Count < MaxSubnegotiation) _sb.Add(b);
        else _sbTooLong = true;
    }

    void Flush(List<TelnetEvent> events)
    {
        if (_data.Count == 0) return;
        events.Add(TelnetEvent.Bytes(_data.ToArray()));
        _data.Clear();
    }
}
