using Microsoft.Extensions.Options;
using VosNet.Core;
using VosNet.Core.Services;

namespace VosNet.Server;

/// <summary>Each hour a summary in the log (connections, profiles,
/// refusals); at the end "THE SERVER IS RESTARTING" to all connected,
/// before the connections close.</summary>
public sealed class Housekeeping(ServerContext ctx, IHostApplicationLifetime life, ILogger<Housekeeping> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        life.ApplicationStopping.Register(() =>
        {
            ctx.Sessions.NotifyAllAsync("server.restart").Wait(TimeSpan.FromSeconds(2));
            foreach (var s in ctx.Sessions.All) s.Conn.Close();
        });
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1), ctx.Time);
        try
        {
            while (await timer.WaitForNextTickAsync(ct))
            {
                string profiles;
                int n;
                lock (ctx.Profiles)
                {
                    profiles = string.Join(", ", ctx.Profiles.Select(p => $"{p.Key} {p.Value}"));
                    n = ctx.Connections;
                    ctx.Profiles.Clear();
                    ctx.Connections = 0;
                }
                var refused = Interlocked.Exchange(ref ctx.Limiter.Refused, 0);
                log.LogInformation("The hour: {Connections} connections ({Profiles}), {Refused} refused, {Online} online",
                    n, profiles, refused, ctx.Sessions.Count);
            }
        }
        catch (OperationCanceledException) { }
    }
}
