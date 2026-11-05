using Dapper;

namespace VosNet.Core.Storage;

/// <summary>The bans, the registration questions, the audit log and the
/// counts a day.</summary>
public sealed class AdminStore(Db db)
{
    public List<BanRow> Bans(long now, bool all = false)
    {
        using var c = db.Open();
        return c.Query<BanRow>("SELECT * FROM bans WHERE @all OR until IS NULL OR until > @now ORDER BY created DESC",
            new { now, all }).ToList();
    }

    public long AddBan(string ipOrCidr, long? until, string reason, string by, long now)
    {
        using var c = db.Open();
        return c.ExecuteScalar<long>("""
            INSERT INTO bans(ip_or_cidr, until, reason, by, created) VALUES (@ipOrCidr, @until, @reason, @by, @now);
            SELECT last_insert_rowid();
            """, new { ipOrCidr, until, reason, by, now });
    }

    public void DeleteBan(long id)
    {
        using var c = db.Open();
        c.Execute("DELETE FROM bans WHERE id = @id", new { id });
    }

    public List<QuestionRow> Questions()
    {
        using var c = db.Open();
        return c.Query<QuestionRow>("SELECT * FROM questions ORDER BY id").ToList();
    }

    public long AddQuestion(string en, string el, string answer)
    {
        using var c = db.Open();
        return c.ExecuteScalar<long>("INSERT INTO questions(text_en, text_el, answer) VALUES (@en, @el, @answer); SELECT last_insert_rowid();",
            new { en, el, answer });
    }

    public void DeleteQuestion(long id)
    {
        using var c = db.Open();
        c.Execute("DELETE FROM questions WHERE id = @id", new { id });
    }

    public void Audit(long now, long? userId, string actor, string action, string? target, string? detail = null)
    {
        using var c = db.Open();
        c.Execute("INSERT INTO audit(at, user_id, actor, action, target, detail) VALUES (@now, @userId, @actor, @action, @target, @detail)",
            new { now, userId, actor, action, target, detail });
    }

    public List<AuditRow> AuditLog(int limit = 300)
    {
        using var c = db.Open();
        return c.Query<AuditRow>("SELECT * FROM audit ORDER BY id DESC LIMIT @limit", new { limit }).ToList();
    }

    /// <summary>Registrations and logins of the last <paramref name="days"/> days.</summary>
    public List<DayCount> Days(long now, int days = 14)
    {
        using var c = db.Open();
        var since = now - days * 86400L;
        return c.Query<DayCount>("""
            WITH d AS (
                SELECT date(created, 'unixepoch') AS day, 1 AS r, 0 AS l FROM users WHERE created >= @since
                UNION ALL SELECT date(at, 'unixepoch'), 0, 1 FROM logins WHERE at >= @since)
            SELECT day, SUM(r) AS registrations, SUM(l) AS logins FROM d GROUP BY day ORDER BY day DESC
            """, new { since }).ToList();
    }
}
