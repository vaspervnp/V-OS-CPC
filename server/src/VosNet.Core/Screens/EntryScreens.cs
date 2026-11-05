using VosNet.Core.Services;
using VosNet.Core.Storage;
using VosNet.Telnet;

namespace VosNet.Core.Screens;

/// <summary>The logo, V-OS's version, how many are here and the choice
/// of language. A valid choice must come within 60 seconds of the
/// connection (the robots of port 23).</summary>
public sealed class WelcomeScreen : IScreen
{
    public static readonly string[] Logo =
    [
        @" __     __      ___  ____    _   _ _____ _____",
        @" \ \   / /     / _ \/ ___|  | \ | | ____|_   _|",
        @"  \ \ / /_____| | | \___ \  |  \| |  _|   | |",
        @"   \ V /______| |_| |___) | | |\  | |___  | |",
        @"    \_/        \___/|____/  |_| \_|_____| |_|",
    ];

    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        var deadline = s.Since + s.Ctx.Options.ChoiceTimeout;
        while (true)
        {
            // the profile may change while we wait (a late answer): then
            // the welcome again, in its letters
            using var changed = new CancellationTokenSource();
            void OnChanged() => changed.Cancel();
            s.Conn.ProfileChanged += OnChanged;
            try
            {
                var choice = await ChooseAsync(s, deadline, changed.Token);
                if (choice != null || s.Token.IsCancellationRequested || !changed.IsCancellationRequested)
                    return choice;
            }
            catch (OperationCanceledException) when (changed.IsCancellationRequested && !s.Token.IsCancellationRequested) { }
            finally { s.Conn.ProfileChanged -= OnChanged; }
        }
    }

    static async Task<IScreen?> ChooseAsync(Session s, DateTimeOffset deadline, CancellationToken changed)
    {
        var ctx = s.Ctx;
        var langs = ctx.Texts.Languages;
        var version = ctx.Releases.Latest?.Tag ?? "v" + ctx.Options.VosVersion;
        await s.OutAsync();
        foreach (var l in Logo) await s.OutAsync(l);
        await s.OutAsync();
        foreach (var l in langs) await s.OutAsync(ctx.Texts.Get(l, "welcome.line"));
        await s.OutAsync(ctx.Texts.Get("en", "welcome.status", version, ctx.Sessions.Count));
        await s.OutAsync();
        var choice = string.Join("  ", langs.Select((l, i) => $"{i + 1} {ctx.Texts.Get(l, "lang.name")}"));
        while (true)
        {
            await s.OutAsync(choice);
            await s.PromptAsync("> ");
            var a = await s.ReadAsync(deadline, changed);
            changed.ThrowIfCancellationRequested();
            if (a == null) return null;
            if (a.Equals("Q", StringComparison.OrdinalIgnoreCase)) return new GoodbyeScreen();
            if (int.TryParse(a, out var n) && n >= 1 && n <= langs.Count)
            {
                s.Lang = langs[n - 1];
                return new EntryScreen();
            }
        }
    }
}

/// <summary>1 LOGIN  2 REGISTER  3 GUEST.</summary>
public sealed class EntryScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        s.Where = "where.login";
        while (true)
        {
            await s.OutAsync();
            await s.OutAsync(s.T("entry.choice"));
            var a = await s.AskAsync(s.T("prompt"));
            switch (a?.ToUpperInvariant())
            {
                case null: return null;
                case "1" or "LOGIN": return new LoginScreen();
                case "2" or "REGISTER": return new RegisterScreen();
                case "3" or "GUEST":
                    s.Guest = true;
                    return new MainMenuScreen();
                case "Q" or "QUIT": return new GoodbyeScreen();
            }
        }
    }
}

/// <summary>The name, then the password (§3); 3 tries, then back.</summary>
public sealed class LoginScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        for (int tries = 0; tries < 3; tries++)
        {
            await s.OutAsync();
            var name = await s.AskAsync(s.T("login.name"), 12);
            if (name == null) return null;
            if (name.Length == 0) return new EntryScreen();
            var pw = await s.AskPasswordAsync(s.T("login.password"));
            if (pw == null) return null;
            var r = s.Ctx.Accounts.Login(name, pw, s.Ip, s.Profile.Name);
            switch (r.Result)
            {
                case LoginResult.Ok:
                    s.User = r.User;
                    await s.Ctx.Sessions.ClaimAsync(s, r.User!.Id);
                    s.Ctx.Log.LogLogin(s);
                    if (r.User.MustChangePw != 0) return new ChangePasswordScreen(mustChange: true);
                    return new MainMenuScreen();
                case LoginResult.Locked:
                    await s.OutAsync(s.T("login.locked", r.LockedMinutes));
                    return new EntryScreen();
                case LoginResult.Banned:
                    await s.OutAsync(s.T("login.banned"));
                    return null;
                default:
                    await s.OutAsync(s.T("login.wrong"));
                    break;
            }
        }
        return new EntryScreen();
    }
}

/// <summary>A new password twice: after a temporary one (the admin gave
/// it), or when the user asks.</summary>
public sealed class ChangePasswordScreen(bool mustChange) : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        if (mustChange) await s.OutAsync(s.T("password.must"));
        await s.OutAsync(s.T("register.warning"));
        while (true)
        {
            var a = await s.AskPasswordAsync(s.T("register.password"));
            if (a == null) return null;
            if (a.Length == 0 && !mustChange) return new MainMenuScreen();
            if (!AccountService.GoodPassword(a))
            {
                await s.OutAsync(s.T("register.badpassword", AccountService.MinPassword, AccountService.MaxPassword));
                continue;
            }
            var b = await s.AskPasswordAsync(s.T("register.again"));
            if (b == null) return null;
            if (a != b) { await s.OutAsync(s.T("register.mismatch")); continue; }
            s.Ctx.Accounts.ChangePassword(s.User!.Id, a);
            s.User = s.Ctx.Users.ById(s.User.Id);
            await s.OutAsync(s.T("password.changed"));
            return new MainMenuScreen();
        }
    }
}

/// <summary>§3: a name, the warning, the password twice, an email (or
/// nothing), the question against robots; 3 a day from an IP.</summary>
public sealed class RegisterScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        var acc = s.Ctx.Accounts;
        s.Where = "where.register";
        await s.OutAsync();
        if (!acc.MayRegister(s.Ip))
        {
            await s.OutAsync(s.T("register.toomany"));
            return new EntryScreen();
        }
        await s.OutAsync(s.T("register.rules"));
        string name;
        while (true)
        {
            var n = await s.AskAsync(s.T("register.name"), 45);
            if (n == null) return null;
            if (n.Length == 0) return new EntryScreen();
            var e = acc.CheckName(n);
            if (e == RegisterError.None) { name = n; break; }
            await s.OutAsync(s.T(e switch
            {
                RegisterError.Reserved => "register.reserved",
                RegisterError.Taken => "register.taken",
                _ => "register.badname",
            }));
        }
        await s.OutAsync();
        await s.OutAsync(s.T("register.warning"));
        string pw;
        while (true)
        {
            var a = await s.AskPasswordAsync(s.T("register.password"));
            if (a == null) return null;
            if (!AccountService.GoodPassword(a))
            {
                await s.OutAsync(s.T("register.badpassword", AccountService.MinPassword, AccountService.MaxPassword));
                continue;
            }
            var b = await s.AskPasswordAsync(s.T("register.again"));
            if (b == null) return null;
            if (a == b) { pw = a; break; }
            await s.OutAsync(s.T("register.mismatch"));
        }
        string? email;
        while (true)
        {
            email = await s.AskAsync(s.T("register.email"), 45);
            if (email == null) return null;
            if (email.Length == 0 || AccountService.GoodEmail(email)) break;
            await s.OutAsync(s.T("register.bademail"));
        }
        var questions = s.Ctx.Admin.Questions();
        if (questions.Count > 0)
        {
            var q = questions[Random.Shared.Next(questions.Count)];
            await s.OutAsync(q.Text(s.Lang));
            var answer = await s.AskAsync(s.T("prompt"));
            if (answer == null) return null;
            if (!AccountService.Answers(q, answer))
            {
                await s.OutAsync(s.T("register.wronganswer"));
                return new EntryScreen();
            }
        }
        var (err, user) = acc.Register(name, pw, email, s.Ip);
        if (err != RegisterError.None)
        {
            await s.OutAsync(s.T(err == RegisterError.TooMany ? "register.toomany" : "register.taken"));
            return new EntryScreen();
        }
        s.User = acc.Login(name, pw, s.Ip, s.Profile.Name).User ?? user;
        s.Ctx.Log.LogLogin(s);
        await s.OutAsync(s.T("register.done", user!.Name));
        return new MainMenuScreen();
    }
}

public sealed class GoodbyeScreen : IScreen
{
    public async Task<IScreen?> RunAsync(Session s, CancellationToken ct)
    {
        await s.OutAsync();
        await s.OutAsync(s.T("goodbye"));
        return null;
    }
}

static class LogExtensions
{
    public static void LogLogin(this Microsoft.Extensions.Logging.ILogger log, Session s) =>
        Microsoft.Extensions.Logging.LoggerExtensions.LogInformation(log, "Login {User} from {Ip} ({Profile})", s.Name, s.Ip, s.Profile.Name);
}
