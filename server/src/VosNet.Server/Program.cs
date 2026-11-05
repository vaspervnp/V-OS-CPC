using System.Net;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Options;
using VosNet.Core;
using VosNet.Core.Services;
using VosNet.Core.Storage;
using VosNet.Server;
using VosNet.Web;

// V-OS NET: the telnet BBS and its administration on the web, in one
// process (server/DESIGN.md). "set-owner NAME" makes a registered user
// the OWNER and ends.
var builder = WebApplication.CreateBuilder(args.Where(a => a != "set-owner").ToArray());
builder.Services.AddSystemd();
builder.Logging.AddSystemdConsole();

var section = builder.Configuration.GetSection(VosNetOptions.Section);
builder.Services.Configure<VosNetOptions>(section);
var o = section.Get<VosNetOptions>() ?? new VosNetOptions();
string Here(string p) => Path.IsPathRooted(p) ? p : Path.Combine(AppContext.BaseDirectory, p);

builder.WebHost.UseUrls(o.Web);
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton(sp => new Db(sp.GetRequiredService<IOptions<VosNetOptions>>().Value.Database));
builder.Services.AddSingleton(sp => new Texts(Here(sp.GetRequiredService<IOptions<VosNetOptions>>().Value.Texts)));
builder.Services.AddSingleton<UserStore>();
builder.Services.AddSingleton<ContentStore>();
builder.Services.AddSingleton<AdminStore>();
builder.Services.AddSingleton<BanList>();
builder.Services.AddSingleton<AccountService>();
builder.Services.AddSingleton<SessionRegistry>();
builder.Services.AddSingleton<ChatHub>();
builder.Services.AddSingleton<ReleasesCache>();
builder.Services.AddSingleton<ConnectionLimiter>();
builder.Services.AddSingleton<ServerContext>();
builder.Services.AddSingleton<ConnectionHandler>();
builder.Services.AddSingleton<TelnetEndpoints>();
builder.Services.AddHttpClient(ReleasesCache.Client, c =>
{
    c.BaseAddress = new Uri("https://api.github.com/");
    c.DefaultRequestHeaders.UserAgent.ParseAdd("VosNet/1.0 (+https://github.com/vaspervnp/V-OS-CPC)");
    c.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
    c.Timeout = TimeSpan.FromSeconds(20);
});
builder.Services.AddHostedService<ReleasesRefresher>();
builder.Services.AddHostedService<Housekeeping>();
builder.Services.AddSingleton<IHostedService>(sp =>
{
    var ports = sp.GetRequiredService<IOptions<VosNetOptions>>().Value.Ports().ToList();
    sp.GetRequiredService<TelnetEndpoints>().Expect(ports.Count);
    return new TelnetListeners(ports.Select(p => new TelnetListener(p, sp.GetRequiredService<ConnectionHandler>(),
        sp.GetRequiredService<TelnetEndpoints>(), sp.GetRequiredService<ILogger<TelnetListener>>())).ToList());
});

builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(o.Keys ?? Path.Combine(Path.GetDirectoryName(Path.GetFullPath(o.Database)) ?? ".", "keys")))
    .SetApplicationName("VosNet");
builder.Services.Configure<ForwardedHeadersOptions>(f =>
{
    f.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    f.KnownProxies.Clear();
    f.KnownIPNetworks.Clear();
    f.KnownProxies.Add(IPAddress.Loopback);
    f.KnownProxies.Add(IPAddress.IPv6Loopback);
});
builder.Services.AddVosNetWeb();

var app = builder.Build();
app.Services.GetRequiredService<Db>().Migrate();

if (args.Contains("set-owner"))
{
    var name = args.SkipWhile(a => a != "set-owner").Skip(1).FirstOrDefault();
    if (name == null) { Console.Error.WriteLine("set-owner NAME"); return 2; }
    if (!app.Services.GetRequiredService<AccountService>().SetOwner(name))
    {
        Console.Error.WriteLine($"No user {name}: register from telnet first.");
        return 1;
    }
    Console.WriteLine($"{name.ToUpperInvariant()} is the OWNER.");
    return 0;
}

app.UseForwardedHeaders();
app.UseVosNetWeb();
app.Run();
return 0;

/// <summary>The listeners of all the ports, as one hosted service.</summary>
sealed class TelnetListeners(List<TelnetListener> listeners) : IHostedService
{
    public Task StartAsync(CancellationToken ct) => Task.WhenAll(listeners.Select(l => l.StartAsync(ct)));
    public Task StopAsync(CancellationToken ct) => Task.WhenAll(listeners.Select(l => l.StopAsync(ct)));
}

public partial class Program;
