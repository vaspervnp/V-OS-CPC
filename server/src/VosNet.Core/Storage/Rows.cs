namespace VosNet.Core.Storage;

// The rows of the tables, as Dapper fills them (snake_case → these by
// DefaultTypeMap.MatchNamesWithUnderscores). Times: Unix seconds.

public enum Role { User, Moderator, Admin, Owner }

public sealed class UserRow
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string NameUpper { get; set; } = "";
    public string? Email { get; set; }
    public string PwHash { get; set; } = "";
    public string Role { get; set; } = "USER";
    public long Created { get; set; }
    public string? CreatedIp { get; set; }
    public long? LastSeen { get; set; }
    public long Failed { get; set; }
    public long? LockedUntil { get; set; }
    public long MustChangePw { get; set; }

    public Role RoleValue => Roles.Parse(Role);
}

public static class Roles
{
    public static Role Parse(string s) => Enum.TryParse<Role>(s, true, out var r) ? r : Storage.Role.User;
    public static string Name(Role r) => r.ToString().ToUpperInvariant();
}

public sealed class BoardRow
{
    public long Id { get; set; }
    public string NameEn { get; set; } = "";
    public string NameEl { get; set; } = "";
    public long Sort { get; set; }
    public long Threads { get; set; }       // counted in the queries
    public string Name(string lang) => lang == "el" ? NameEl : NameEn;
}

public sealed class ThreadRow
{
    public long Id { get; set; }
    public long BoardId { get; set; }
    public string Title { get; set; } = "";
    public long? UserId { get; set; }
    public string Author { get; set; } = "";
    public long Created { get; set; }
    public long LastPost { get; set; }
    public long Locked { get; set; }
    public long Posts { get; set; }
}

public sealed class PostRow
{
    public long Id { get; set; }
    public long ThreadId { get; set; }
    public long? UserId { get; set; }
    public string Author { get; set; } = "";
    public string Body { get; set; } = "";
    public long Created { get; set; }
}

public sealed class GuestbookRow
{
    public long Id { get; set; }
    public string Author { get; set; } = "";
    public string Text { get; set; } = "";
    public long Created { get; set; }
}

public sealed class NewsRow
{
    public long Id { get; set; }
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string Author { get; set; } = "";
    public long Created { get; set; }
}

public sealed class BanRow
{
    public long Id { get; set; }
    public string IpOrCidr { get; set; } = "";
    public long? Until { get; set; }
    public string Reason { get; set; } = "";
    public string By { get; set; } = "";
    public long Created { get; set; }
}

public sealed class QuestionRow
{
    public long Id { get; set; }
    public string TextEn { get; set; } = "";
    public string TextEl { get; set; } = "";
    public string Answer { get; set; } = "";
    public string Text(string lang) => lang == "el" ? TextEl : TextEn;
}

public sealed class AuditRow
{
    public long Id { get; set; }
    public long At { get; set; }
    public long? UserId { get; set; }
    public string Actor { get; set; } = "";
    public string Action { get; set; } = "";
    public string? Target { get; set; }
    public string? Detail { get; set; }
}

public sealed class DayCount
{
    public string Day { get; set; } = "";
    public long Registrations { get; set; }
    public long Logins { get; set; }
}
