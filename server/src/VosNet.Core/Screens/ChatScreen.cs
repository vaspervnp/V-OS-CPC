using VosNet.Core.Services;

namespace VosNet.Core.Screens;

/// <summary>The live chat (§2.6): one room, the last 20 lines on the way
/// in, /who, /me, /quit; for moderators /kick, /mute, /del. On V-OS the
/// line typed is apart from the window, so lines that come do not spoil
/// it.</summary>
public sealed class ChatScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.Where = "where.chat";
        var hub = s.Ctx.Chat;
        await s.OutAsync();
        await s.TitleAsync(s.T("chat.title"));
        await s.OutAsync(s.T(s.IsModerator ? "chat.help.mod" : "chat.help"));
        await s.RuleAsync();
        var (box, last) = hub.Join(s);
        foreach (var m in last) await s.OutAsync(Format(s, m));
        using var stop = CancellationTokenSource.CreateLinkedTokenSource(s.Token);
        var pump = Task.Run(async () =>
        {
            try
            {
                await foreach (var m in box.ReadAllAsync(stop.Token))
                    await s.OutAsync(Format(s, m));
            }
            catch (OperationCanceledException) { }
        });
        try
        {
            while (true)
            {
                var line = await s.ReadAsync();
                if (line == null) return null;
                if (line.Length == 0) continue;
                if (line.StartsWith('/'))
                {
                    if (await CommandAsync(s, line)) return new MainMenuScreen();
                    continue;
                }
                if (!s.CanWrite) { await s.OutAsync(s.T("guest.readonly")); continue; }
                if (hub.IsMuted(s.Name)) { await s.OutAsync(s.T("chat.youremuted")); continue; }
                if (!hub.Say(s, line)) await s.OutAsync(s.T("chat.slow"));
            }
        }
        finally
        {
            hub.Leave(s);
            stop.Cancel();
            await pump;
        }
    }

    static string Format(Session s, ChatMessage m) => m.Kind switch
    {
        ChatKind.Me => $"* {m.From} {m.Text}",
        ChatKind.System => "-- " + s.T(m.Text, m.Args ?? []),
        _ => s.IsModerator ? $"{m.Id}<{m.From}> {m.Text}" : $"<{m.From}> {m.Text}",
    };

    /// <summary>true: out of the chat.</summary>
    static async Task<bool> CommandAsync(Session s, string line)
    {
        var hub = s.Ctx.Chat;
        var w = line.Split(' ', 3, StringSplitOptions.RemoveEmptyEntries);
        var cmd = w[0].ToLowerInvariant();
        switch (cmd)
        {
            case "/quit" or "/q":
                return true;
            case "/who":
                await s.OutAsync("-- " + string.Join(", ", hub.Members.Select(m => m.Name)));
                return false;
            case "/me" when w.Length > 1:
                if (!s.CanWrite) await s.OutAsync(s.T("guest.readonly"));
                else if (hub.IsMuted(s.Name)) await s.OutAsync(s.T("chat.youremuted"));
                else if (!hub.Say(s, line[3..].Trim(), me: true)) await s.OutAsync(s.T("chat.slow"));
                return false;
        }
        if (s.IsModerator)
        {
            var now = s.Ctx.Time.Unix();
            switch (cmd)
            {
                case "/kick" when w.Length > 1:
                    var who = s.Ctx.Sessions.ByName(w[1]);
                    if (who == null || who.Role >= s.Role) { await s.OutAsync(s.T("chat.nosuch", w[1])); return false; }
                    hub.System("chat.kicked", who.Name);
                    s.Ctx.Admin.Audit(now, s.User!.Id, s.User.Name, "KICK", who.Name);
                    await who.KickAsync("kicked");
                    return false;
                case "/mute" when w.Length > 1:
                    var target = s.Ctx.Sessions.ByName(w[1]);
                    if (target == null || target.Role >= s.Role) { await s.OutAsync(s.T("chat.nosuch", w[1])); return false; }
                    var minutes = w.Length > 2 && int.TryParse(w[2], out var m) ? Math.Clamp(m, 1, 1440) : 10;
                    hub.Mute(target.Name, TimeSpan.FromMinutes(minutes));
                    s.Ctx.Admin.Audit(now, s.User!.Id, s.User.Name, "MUTE", target.Name, $"{minutes} min");
                    return false;
                case "/del" when w.Length > 1 && long.TryParse(w[1], out var id):
                    if (!hub.Delete(id)) await s.OutAsync(s.T("chat.nosuchline", id));
                    else s.Ctx.Admin.Audit(now, s.User!.Id, s.User.Name, "DELETE CHAT", id.ToString());
                    return false;
            }
        }
        await s.OutAsync(s.T(s.IsModerator ? "chat.help.mod" : "chat.help"));
        return false;
    }
}
