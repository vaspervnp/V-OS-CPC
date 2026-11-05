using Microsoft.AspNetCore.Mvc;
using VosNet.Core;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

public sealed class NewsModel(ServerContext ctx) : AdminPage(ctx)
{
    public List<NewsRow> News { get; private set; } = [];

    public void OnGet() => News = Ctx.Content.News();

    public IActionResult OnPostAdd(string title, string body)
    {
        if (!string.IsNullOrWhiteSpace(title) && !string.IsNullOrWhiteSpace(body))
        {
            Ctx.Content.AddNews(title.Trim(), body.Trim(), Me.Name, Ctx.Time.GetUtcNow().ToUnixTimeSeconds());
            Audit("ANNOUNCE", title);
        }
        return RedirectToPage();
    }

    public IActionResult OnPostDelete(long id)
    {
        Ctx.Content.DeleteNews(id);
        Audit("REMOVE ANNOUNCEMENT", id.ToString());
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRefreshAsync()
    {
        await Ctx.Releases.RefreshAsync(HttpContext.RequestAborted);
        return RedirectToPage();
    }
}
