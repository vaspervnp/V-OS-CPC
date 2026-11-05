namespace VosNet.Core.Services;

public static class Clock
{
    public static long Unix(this TimeProvider t) => t.GetUtcNow().ToUnixTimeSeconds();
    public static DateTimeOffset FromUnix(long s) => DateTimeOffset.FromUnixTimeSeconds(s);
}
