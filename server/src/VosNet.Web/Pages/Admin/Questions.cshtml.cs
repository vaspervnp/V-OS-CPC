using Microsoft.AspNetCore.Mvc;
using VosNet.Core;
using VosNet.Core.Storage;

namespace VosNet.Web.Pages.Admin;

public sealed class QuestionsModel(ServerContext ctx) : AdminPage(ctx)
{
    public List<QuestionRow> Questions { get; private set; } = [];

    public void OnGet() => Questions = Ctx.Admin.Questions();

    public IActionResult OnPostAdd(string en, string el, string answer)
    {
        if (!string.IsNullOrWhiteSpace(en) && !string.IsNullOrWhiteSpace(el) && !string.IsNullOrWhiteSpace(answer))
        {
            Ctx.Admin.AddQuestion(en.Trim(), el.Trim(), answer.Trim());
            Audit("ADD QUESTION", en);
        }
        return RedirectToPage();
    }

    public IActionResult OnPostDelete(long id)
    {
        Ctx.Admin.DeleteQuestion(id);
        Audit("DELETE QUESTION", id.ToString());
        return RedirectToPage();
    }
}
