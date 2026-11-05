using Microsoft.AspNetCore.Mvc;
using VosNet.Core;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

public sealed class GuestbookModel(ServerContext ctx) : AdminPage(ctx)
{
    public List<GuestbookRow> Lines { get; private set; } = [];

    public void OnGet() => Lines = Ctx.Content.Guestbook(500);

    public IActionResult OnPostDelete(long id)
    {
        var g = Ctx.Content.Guestbook(500).FirstOrDefault(x => x.Id == id);
        Ctx.Content.DeleteGuestbook(id);
        Audit("DELETE GUEST BOOK", g?.Author, g?.Text);
        return RedirectToPage();
    }
}
