namespace VosNet.Telnet;

/// <summary>The bytes of RFC 854 and the options the server knows.</summary>
public static class Telnet
{
    public const byte IAC = 255, DONT = 254, DO = 253, WONT = 252, WILL = 251,
        SB = 250, GA = 249, EL = 248, EC = 247, AYT = 246, AO = 245, IP = 244,
        BRK = 243, DM = 242, NOP = 241, SE = 240;

    public const byte ECHO = 1, SGA = 3, TTYPE = 24, NAWS = 31;

    public const byte IS = 0, SEND = 1;     // TTYPE's subnegotiation
}
