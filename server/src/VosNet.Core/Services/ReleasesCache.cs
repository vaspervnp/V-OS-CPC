using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace VosNet.Core.Services;

public sealed record Release(string Tag, string Name, DateTimeOffset Published, string Text, string Url);

/// <summary>V-OS's releases from GitHub (/repos/OWNER/V-OS-CPC/releases),
/// their markdown as text, kept for an hour.</summary>
public sealed class ReleasesCache(IHttpClientFactory http, IOptions<VosNetOptions> o, ILogger<ReleasesCache> log)
{
    public const string Client = "github";

    sealed class Json
    {
        [JsonPropertyName("tag_name")] public string? Tag { get; set; }
        [JsonPropertyName("name")] public string? Name { get; set; }
        [JsonPropertyName("published_at")] public DateTimeOffset? Published { get; set; }
        [JsonPropertyName("body")] public string? Body { get; set; }
        [JsonPropertyName("html_url")] public string? Url { get; set; }
        [JsonPropertyName("draft")] public bool Draft { get; set; }
    }

    volatile IReadOnlyList<Release> _releases = [];

    public IReadOnlyList<Release> Releases => _releases;
    public Release? Latest => _releases.FirstOrDefault();
    public DateTimeOffset? Fetched { get; private set; }

    public async Task RefreshAsync(CancellationToken ct)
    {
        try
        {
            var c = http.CreateClient(Client);
            var list = await c.GetFromJsonAsync<List<Json>>($"repos/{o.Value.GitHubRepo}/releases?per_page=20", ct) ?? [];
            _releases = list.Where(r => !r.Draft && r.Tag != null)
                .Select(r => new Release(r.Tag!, string.IsNullOrWhiteSpace(r.Name) ? r.Tag! : r.Name!.Trim(),
                    r.Published ?? DateTimeOffset.MinValue, Markdown.ToText(r.Body ?? ""), r.Url ?? ""))
                .OrderByDescending(r => r.Published).ToList();
            Fetched = DateTimeOffset.UtcNow;
            log.LogInformation("Releases: {Count}, the latest {Tag}", _releases.Count, Latest?.Tag);
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            log.LogWarning("Releases not fetched: {Error}", e.Message);
        }
    }
}

/// <summary>Refreshes the <see cref="ReleasesCache"/> at the start and each hour.</summary>
public sealed class ReleasesRefresher(ReleasesCache cache, IOptions<VosNetOptions> o, TimeProvider time) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (!o.Value.FetchReleases) return;
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1), time);
        do await cache.RefreshAsync(ct);
        while (await timer.WaitForNextTickAsync(ct));
    }
}
