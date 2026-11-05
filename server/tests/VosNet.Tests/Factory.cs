using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;
using VosNet.Server;

namespace VosNet.Tests;

/// <summary>The whole server (web and telnet) on a database of its own
/// in a temporary folder, the telnet on a free port, the releases from a
/// fake GitHub.</summary>
public sealed class VosNetFactory : WebApplicationFactory<Program>
{
    public string Dir { get; }
    public string DbPath => Path.Combine(Dir, "vosnet.db");
    public Action<IServiceCollection>? Services_ { get; init; }
    public Dictionary<string, string> Settings { get; } = new();

    public VosNetFactory(string? dir = null)
    {
        Dir = dir ?? Path.Combine(Path.GetTempPath(), "vosnet-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Dir);
    }

    protected override void ConfigureWebHost(IWebHostBuilder b)
    {
        b.UseSetting("VosNet:TelnetPorts", "0");
        b.UseSetting("VosNet:Database", DbPath);
        b.UseSetting("VosNet:Keys", Path.Combine(Dir, "keys"));
        b.UseSetting("VosNet:FetchReleases", "false");
        b.UseSetting("VosNet:DetectWait", "00:00:02");
        foreach (var (k, v) in Settings) b.UseSetting(k, v);
        b.ConfigureTestServices(s =>
        {
            s.AddHttpClient(ReleasesCache.Client).ConfigurePrimaryHttpMessageHandler(() => new FakeGitHub());
            Services_?.Invoke(s);
        });
    }

    public HttpClient Https() => CreateClient(new WebApplicationFactoryClientOptions
    {
        BaseAddress = new Uri("https://localhost"),
        AllowAutoRedirect = false,
    });

    public async Task<int> TelnetPortAsync()
    {
        _ = Server;
        var eps = Services.GetRequiredService<TelnetEndpoints>();
        await eps.Ready.WaitAsync(TimeSpan.FromSeconds(10));
        return eps.Ports.First();
    }

    public T Get<T>() where T : notnull => Services.GetRequiredService<T>();

    /// <summary>A user straight into the database, with a role.</summary>
    public UserRow AddUser(string name, string password, Role role = Role.User)
    {
        _ = Server;
        var (e, u) = Get<AccountService>().Register(name, password, null, IPAddress.Parse("10.9.9." + Random.Shared.Next(1, 250)));
        Assert.Equal(RegisterError.None, e);
        if (role != Role.User) Get<UserStore>().SetRole(u!.Id, role);
        return Get<UserStore>().ById(u!.Id)!;
    }

    /// <summary>The registration's question made known: 2+2.</summary>
    public void OneQuestion()
    {
        _ = Server;
        var a = Get<AdminStore>();
        foreach (var q in a.Questions()) a.DeleteQuestion(q.Id);
        a.AddQuestion("2+2?", "2+2;", "4");
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        SqliteConnection.ClearAllPools();
    }

    public void DeleteDir()
    {
        SqliteConnection.ClearAllPools();
        try { Directory.Delete(Dir, true); } catch (IOException) { }
    }
}

/// <summary>GitHub's /releases, as it answers for V-OS-CPC.</summary>
sealed class FakeGitHub : HttpMessageHandler
{
    public const string Json = """
        [
          {"tag_name": "v0.53", "name": "V-OS 0.53", "draft": false, "published_at": "2026-11-05T10:00:00Z",
           "html_url": "https://github.com/vaspervnp/V-OS-CPC/releases/tag/v0.53",
           "body": "## MAIL and FTP\n\n- **MAIL**: POP3, SMTP over the M4\n- FTP: [PASV](https://x), LIST, GET"},
          {"tag_name": "v0.43", "name": "V-OS 0.43", "draft": false, "published_at": "2026-10-01T10:00:00Z", "body": "Older."}
        ]
        """;

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
        Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(Json, System.Text.Encoding.UTF8, "application/json"),
        });
}
