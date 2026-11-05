using System.Net;
using System.Text.RegularExpressions;
using VosNet.Core.Services;
using VosNet.Core.Storage;

namespace VosNet.Tests;

/// <summary>§9 Web: the administration with WebApplicationFactory and a
/// temporary database.</summary>
public partial class WebTests : IAsyncLifetime
{
    readonly VosNetFactory _f = new();
    int _port;

    public async Task InitializeAsync() => _port = await _f.TelnetPortAsync();

    public async Task DisposeAsync()
    {
        await _f.DisposeAsync();
        _f.DeleteDir();
    }

    [GeneratedRegex("name=\"__RequestVerificationToken\" type=\"hidden\" value=\"([^\"]+)\"")]
    private static partial Regex TokenRule();

    static async Task<string> TokenAsync(HttpClient c, string url)
    {
        var html = await c.GetStringAsync(url);
        return TokenRule().Match(html).Groups[1].Value;
    }

    async Task<(HttpClient Client, HttpResponseMessage Response)> LoginAsync(string name, string pw)
    {
        var c = _f.Https();
        var token = await TokenAsync(c, "/admin/login");
        var r = await c.PostAsync("/admin/login", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Name"] = name, ["Password"] = pw, ["__RequestVerificationToken"] = token,
        }));
        return (c, r);
    }

    static Task<HttpResponseMessage> PostAsync(HttpClient c, string url, string token, Dictionary<string, string> form)
    {
        form["__RequestVerificationToken"] = token;
        return c.PostAsync(url, new FormUrlEncodedContent(form));
    }

    [Fact]
    public async Task AdminIsClosedWithoutLogin()
    {
        var c = _f.Https();
        foreach (var url in new[] { "/admin", "/admin/users", "/admin/bans", "/admin/audit" })
        {
            var r = await c.GetAsync(url);
            Assert.Equal(HttpStatusCode.Redirect, r.StatusCode);
            Assert.StartsWith("https://localhost/admin/login", r.Headers.Location!.ToString());
        }
        var pub = await c.GetStringAsync("/");
        Assert.Contains("HOW TO CONNECT", pub);
        Assert.Contains("telnet vos.revive8bit.com", pub);
    }

    [Theory]
    [InlineData(Role.User)]
    [InlineData(Role.Moderator)]
    public async Task UsersAndModeratorsDoNotEnter(Role role)
    {
        _f.AddUser("SOMEONE", "some-password", role);
        var (c, r) = await LoginAsync("SOMEONE", "some-password");
        Assert.Equal(HttpStatusCode.Unauthorized, r.StatusCode);
        Assert.Contains("NOT AN ADMINISTRATOR", await r.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.Redirect, (await c.GetAsync("/admin")).StatusCode);
    }

    [Fact]
    public async Task AFormWithoutAntiforgeryIsRefused()
    {
        _f.AddUser("VASILHS", "owner-password", Role.Owner);
        var c = _f.Https();
        var r = await c.PostAsync("/admin/login", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Name"] = "VASILHS", ["Password"] = "owner-password",
        }));
        Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);
        var (admin, ok) = await LoginAsync("VASILHS", "owner-password");
        Assert.Equal(HttpStatusCode.Redirect, ok.StatusCode);
        var u = _f.AddUser("NIKOS", "nikos-password");
        var bad = await admin.PostAsync("/admin/users?handler=Role", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["id"] = u.Id.ToString(), ["role"] = "Moderator",
        }));
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        Assert.Equal(Role.User, _f.Get<UserStore>().ById(u.Id)!.RoleValue);
    }

    [Fact]
    public async Task TheCookieIsHttpOnlySecureStrict()
    {
        _f.AddUser("VASILHS", "owner-password", Role.Owner);
        var (_, r) = await LoginAsync("VASILHS", "owner-password");
        var cookie = r.Headers.GetValues("Set-Cookie").Single(x => x.StartsWith("vosnet.admin="));
        Assert.Contains("httponly", cookie.ToLowerInvariant());
        Assert.Contains("secure", cookie.ToLowerInvariant());
        Assert.Contains("samesite=strict", cookie.ToLowerInvariant());
    }

    [Fact]
    public async Task TheOwnerMakesAnAdminAndAModerator()
    {
        _f.AddUser("VASILHS", "owner-password", Role.Owner);
        var anna = _f.AddUser("ANNA", "anna-password");
        var nikos = _f.AddUser("NIKOS", "nikos-password");
        var maria = _f.AddUser("MARIA", "maria-password");
        var (owner, _) = await LoginAsync("VASILHS", "owner-password");
        var token = await TokenAsync(owner, "/admin/users");
        await PostAsync(owner, "/admin/users?handler=Role", token, new() { ["id"] = anna.Id.ToString(), ["role"] = "Admin" });
        await PostAsync(owner, "/admin/users?handler=Role", token, new() { ["id"] = nikos.Id.ToString(), ["role"] = "Moderator" });
        var users = _f.Get<UserStore>();
        Assert.Equal(Role.Admin, users.ById(anna.Id)!.RoleValue);
        Assert.Equal(Role.Moderator, users.ById(nikos.Id)!.RoleValue);

        // the new ADMIN gets in, but does not give ADMIN
        var (admin, r) = await LoginAsync("ANNA", "anna-password");
        Assert.Equal(HttpStatusCode.Redirect, r.StatusCode);
        var t2 = await TokenAsync(admin, "/admin/users");
        await PostAsync(admin, "/admin/users?handler=Role", t2, new() { ["id"] = maria.Id.ToString(), ["role"] = "Admin" });
        Assert.Equal(Role.User, users.ById(maria.Id)!.RoleValue);
        await PostAsync(admin, "/admin/users?handler=Role", t2, new() { ["id"] = maria.Id.ToString(), ["role"] = "Moderator" });
        Assert.Equal(Role.Moderator, users.ById(maria.Id)!.RoleValue);
        var log = await admin.GetStringAsync("/admin/audit");
        Assert.Contains("VASILHS", log);
        Assert.Contains("USER -&gt; ADMIN", log);

        // the OWNER takes ADMIN back: ANNA's cookie stops working
        await PostAsync(owner, "/admin/users?handler=Role", token, new() { ["id"] = anna.Id.ToString(), ["role"] = "User" });
        Assert.Equal(HttpStatusCode.Redirect, (await admin.GetAsync("/admin")).StatusCode);
    }

    [Fact]
    public async Task DisconnectingFromTheWebClosesTheTelnet()
    {
        _f.AddUser("VASILHS", "owner-password", Role.Owner);
        _f.AddUser("NIKOS", "nikos-password");
        await using var t = await new ScenarioLogin(_port).LoginAsync("NIKOS", "nikos-password");
        var (owner, _) = await LoginAsync("VASILHS", "owner-password");
        var html = await owner.GetStringAsync("/admin");
        Assert.Contains("NIKOS", html);
        Assert.Contains("V-OS 48×20", html);
        var id = Regex.Match(html, "name=\"id\" value=\"([0-9a-f-]{36})\"").Groups[1].Value;
        var token = TokenRule().Match(html).Groups[1].Value;
        var r = await PostAsync(owner, "/admin?handler=Kick", token, new() { ["id"] = id });
        Assert.Equal(HttpStatusCode.Redirect, r.StatusCode);
        await t.WaitAsync("Ο ΔΙΑΧΕΙΡΙΣΤΗΣ ΕΚΛΕΙΣΕ ΤΗ ΣΥΝΔΕΣΗ ΣΟΥ");
        await t.WaitClosedAsync();
        Assert.Contains("DISCONNECTED", await owner.GetStringAsync("/admin"));
    }

    [Fact]
    public async Task ABanFromTheWebIsKept()
    {
        _f.AddUser("VASILHS", "owner-password", Role.Owner);
        var (owner, _) = await LoginAsync("VASILHS", "owner-password");
        var token = await TokenAsync(owner, "/admin/bans");
        await PostAsync(owner, "/admin/bans?handler=Add", token, new() { ["ip"] = "192.0.2.0/24", ["hours"] = "2", ["reason"] = "spam" });
        Assert.NotNull(_f.Get<BanList>().Find(IPAddress.Parse("192.0.2.77")));
        Assert.Contains("192.0.2.0/24", await owner.GetStringAsync("/admin/bans"));
    }
}
