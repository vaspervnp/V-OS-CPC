using Microsoft.AspNetCore.Mvc.RazorPages;
using VosNet.Core;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages;

/// <summary>The public page: how to connect, how many are here, the news.</summary>
public sealed class IndexModel(ServerContext ctx) : PageModel
{
    public ServerContext Ctx { get; } = ctx;
    public List<NewsRow> News { get; private set; } = [];

    public void OnGet() => News = Ctx.Content.News(5);
}
