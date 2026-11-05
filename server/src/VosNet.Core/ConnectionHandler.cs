using System.Net;
using System.Text;
using Microsoft.Extensions.Logging;
using VosNet.Core.Screens;
using VosNet.Core.Services;
using VosNet.Telnet;

namespace VosNet.Core;

/// <summary>A connection from its first byte to its end: the limits, the
/// profile (§5), the screens one after another.</summary>
public sealed class ConnectionHandler(ServerContext ctx)
{
    public async Task HandleAsync(Stream stream, IPAddress ip, int port, CancellationToken stopping)
    {
        var admission = ctx.Limiter.TryAdmit(ip);
        if (admission != Admission.Ok)
        {
            ctx.Log.LogInformation("Refused {Ip}: {Why}", ip, admission);
            var why = admission switch
            {
                Admission.Banned => "YOU ARE BANNED FROM V-OS NET.",
                Admission.Full => "V-OS NET IS FULL. TRY AGAIN LATER.",
                _ => "TOO MANY CONNECTIONS. TRY AGAIN LATER.",
            };
            try { await stream.WriteAsync(Encoding.ASCII.GetBytes(why + "\r\n"), stopping); } catch (Exception) { }
            await stream.DisposeAsync();
            return;
        }
        var conn = new TelnetConnection(stream, ctx.Time);
        var s = new Session(conn, ctx, ip, port);
        try
        {
            conn.Start();
            var profile = await conn.DetectAsync(ctx.Options.DetectWait, stopping);
            lock (ctx.Profiles)
            {
                ctx.Profiles[profile.Name] = ctx.Profiles.GetValueOrDefault(profile.Name) + 1;
                ctx.Connections++;
            }
            ctx.Log.LogInformation("Connection from {Ip}:{Port}: {Profile} {Type}", s.Ip, port, profile.Name, conn.TerminalType);
            ctx.Sessions.Add(s);
            IScreen? screen = new WelcomeScreen();
            while (screen != null && !s.Token.IsCancellationRequested)
                screen = await screen.RunAsync(s, s.Token);
        }
        catch (OperationCanceledException) { }
        catch (Exception e) { ctx.Log.LogWarning(e, "Session of {Ip}", s.Ip); }
        finally
        {
            ctx.Log.LogInformation("Closed {Ip}: {Name}, {Profile}, the menu {Menu}, the first answer to an option after {Answer} ms",
                s.Ip, s.Name, conn.Profile.Name, s.ReachedMenu, (int?)conn.FirstAnswer?.TotalMilliseconds);
            ctx.Sessions.Remove(s);
            ctx.Chat.Leave(s);
            ctx.Limiter.Release(ip, s.ReachedMenu);
            await conn.DisposeAsync();
        }
    }
}
