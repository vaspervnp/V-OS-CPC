namespace VosNet.Telnet;

/// <summary>The options of a connection by RFC 1143 (the Q method): for
/// each option our side ("us": WILL/WONT) and the other side ("him":
/// DO/DONT), each NO, YES, WANTNO or WANTYES with a queue bit, so that
/// the two ends never go round in a loop. The replies are written to the
/// output given.</summary>
public sealed class OptionNegotiator
{
    public enum Q : byte { No, Yes, WantNo, WantYes }

    sealed class Option
    {
        public Q Us, Him;
        public bool UsQueue, HimQueue;      // true: OPPOSITE
        public bool HimAnswered;            // a WILL or WONT came
    }

    readonly Option[] _options = new Option[256];
    readonly Func<byte, bool> _himMay;

    /// <summary><paramref name="himMay"/>: the options the other end may
    /// turn on when it offers them (WILL); ours are on only when we ask
    /// for them, every DO otherwise gets WONT.</summary>
    public OptionNegotiator(Func<byte, bool> himMay) => _himMay = himMay;

    Option O(byte opt) => _options[opt] ??= new Option();

    public Q Us(byte opt) => O(opt).Us;
    public Q Him(byte opt) => O(opt).Him;
    public bool IsUs(byte opt) => O(opt).Us == Q.Yes;
    public bool IsHim(byte opt) => O(opt).Him == Q.Yes;
    public bool HimAnswered(byte opt) => O(opt).HimAnswered;

    /// <summary>Raised when an option turns on or off: (option, us?, on).</summary>
    public event Action<byte, bool, bool>? Changed;

    static void Send(List<byte> output, byte verb, byte opt)
    {
        output.Add(Telnet.IAC);
        output.Add(verb);
        output.Add(opt);
    }

    /// <summary>A WILL, WONT, DO or DONT received.</summary>
    public void Receive(byte verb, byte opt, List<byte> output)
    {
        var o = O(opt);
        switch (verb)
        {
            case Telnet.WILL:
                o.HimAnswered = true;
                switch (o.Him)
                {
                    case Q.No:
                        if (_himMay(opt)) { o.Him = Q.Yes; Send(output, Telnet.DO, opt); Changed?.Invoke(opt, false, true); }
                        else Send(output, Telnet.DONT, opt);
                        break;
                    case Q.WantNo:
                        if (!o.HimQueue) o.Him = Q.No;       // DONT answered by WILL: an error
                        else { o.Him = Q.Yes; o.HimQueue = false; Changed?.Invoke(opt, false, true); }
                        break;
                    case Q.WantYes:
                        if (!o.HimQueue) { o.Him = Q.Yes; Changed?.Invoke(opt, false, true); }
                        else { o.Him = Q.WantNo; o.HimQueue = false; Send(output, Telnet.DONT, opt); }
                        break;
                }
                break;
            case Telnet.WONT:
                o.HimAnswered = true;
                switch (o.Him)
                {
                    case Q.Yes:
                        o.Him = Q.No; Send(output, Telnet.DONT, opt); Changed?.Invoke(opt, false, false);
                        break;
                    case Q.WantNo:
                        if (!o.HimQueue) { o.Him = Q.No; Changed?.Invoke(opt, false, false); }
                        else { o.Him = Q.WantYes; o.HimQueue = false; Send(output, Telnet.DO, opt); }
                        break;
                    case Q.WantYes:
                        o.Him = Q.No; o.HimQueue = false;
                        break;
                }
                break;
            case Telnet.DO:
                switch (o.Us)
                {
                    case Q.No:
                        Send(output, Telnet.WONT, opt);      // ours only when we ask
                        break;
                    case Q.WantNo:
                        if (!o.UsQueue) o.Us = Q.No;
                        else { o.Us = Q.Yes; o.UsQueue = false; Changed?.Invoke(opt, true, true); }
                        break;
                    case Q.WantYes:
                        if (!o.UsQueue) { o.Us = Q.Yes; Changed?.Invoke(opt, true, true); }
                        else { o.Us = Q.WantNo; o.UsQueue = false; Send(output, Telnet.WONT, opt); }
                        break;
                }
                break;
            case Telnet.DONT:
                switch (o.Us)
                {
                    case Q.Yes:
                        o.Us = Q.No; Send(output, Telnet.WONT, opt); Changed?.Invoke(opt, true, false);
                        break;
                    case Q.WantNo:
                        if (!o.UsQueue) { o.Us = Q.No; Changed?.Invoke(opt, true, false); }
                        else { o.Us = Q.WantYes; o.UsQueue = false; Send(output, Telnet.WILL, opt); }
                        break;
                    case Q.WantYes:
                        o.Us = Q.No; o.UsQueue = false;
                        break;
                }
                break;
        }
    }

    /// <summary>Ask the other end to turn an option on (DO) or off (DONT).</summary>
    public void AskHim(byte opt, bool on, List<byte> output)
    {
        var o = O(opt);
        if (on)
            switch (o.Him)
            {
                case Q.No: o.Him = Q.WantYes; Send(output, Telnet.DO, opt); break;
                case Q.WantNo: o.HimQueue = true; break;
                case Q.WantYes: o.HimQueue = false; break;
            }
        else
            switch (o.Him)
            {
                case Q.Yes: o.Him = Q.WantNo; Send(output, Telnet.DONT, opt); break;
                case Q.WantNo: o.HimQueue = false; break;
                case Q.WantYes: o.HimQueue = true; break;
            }
    }

    /// <summary>Offer an option of ours (WILL) or withdraw it (WONT).</summary>
    public void SetUs(byte opt, bool on, List<byte> output)
    {
        var o = O(opt);
        if (on)
            switch (o.Us)
            {
                case Q.No: o.Us = Q.WantYes; Send(output, Telnet.WILL, opt); break;
                case Q.WantNo: o.UsQueue = true; break;
                case Q.WantYes: o.UsQueue = false; break;
            }
        else
            switch (o.Us)
            {
                case Q.Yes: o.Us = Q.WantNo; Send(output, Telnet.WONT, opt); break;
                case Q.WantNo: o.UsQueue = false; break;
                case Q.WantYes: o.UsQueue = true; break;
            }
    }
}
