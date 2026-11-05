using Dapper;

namespace VosNet.Core.Storage;

/// <summary>The boards, their threads and posts, the guest book and the
/// announcements.</summary>
public sealed class ContentStore(Db db)
{
    public List<BoardRow> Boards()
    {
        using var c = db.Open();
        return c.Query<BoardRow>("""
            SELECT b.*, (SELECT COUNT(*) FROM threads t WHERE t.board_id = b.id) AS threads
            FROM boards b ORDER BY sort, id
            """).ToList();
    }

    public long AddBoard(string en, string el)
    {
        using var c = db.Open();
        return c.ExecuteScalar<long>("""
            INSERT INTO boards(name_en, name_el, sort) VALUES (@en, @el, (SELECT IFNULL(MAX(sort), 0) + 1 FROM boards));
            SELECT last_insert_rowid();
            """, new { en, el });
    }

    public void RenameBoard(long id, string en, string el)
    {
        using var c = db.Open();
        c.Execute("UPDATE boards SET name_en = @en, name_el = @el WHERE id = @id", new { id, en, el });
    }

    /// <summary>A board a place up (-1) or down (+1).</summary>
    public void MoveBoard(long id, int by)
    {
        var list = Boards();
        int i = list.FindIndex(b => b.Id == id), j = i + by;
        if (i < 0 || j < 0 || j >= list.Count) return;
        (list[i], list[j]) = (list[j], list[i]);
        using var c = db.Open();
        for (int k = 0; k < list.Count; k++)
            c.Execute("UPDATE boards SET sort = @s WHERE id = @id", new { s = k + 1, id = list[k].Id });
    }

    public void DeleteBoard(long id)
    {
        using var c = db.Open();
        c.Execute("DELETE FROM boards WHERE id = @id", new { id });
    }

    public List<ThreadRow> Threads(long boardId)
    {
        using var c = db.Open();
        return c.Query<ThreadRow>("""
            SELECT t.*, (SELECT COUNT(*) FROM posts p WHERE p.thread_id = t.id) AS posts
            FROM threads t WHERE board_id = @boardId ORDER BY last_post DESC, id DESC
            """, new { boardId }).ToList();
    }

    public ThreadRow? Thread(long id)
    {
        using var c = db.Open();
        return c.QuerySingleOrDefault<ThreadRow>("SELECT * FROM threads WHERE id = @id", new { id });
    }

    public long AddThread(long boardId, string title, long? userId, string author, string body, long now)
    {
        using var c = db.Open();
        using var tx = c.BeginTransaction();
        var id = c.ExecuteScalar<long>("""
            INSERT INTO threads(board_id, title, user_id, author, created, last_post) VALUES (@boardId, @title, @userId, @author, @now, @now);
            SELECT last_insert_rowid();
            """, new { boardId, title, userId, author, now }, tx);
        c.Execute("INSERT INTO posts(thread_id, user_id, author, body, created) VALUES (@id, @userId, @author, @body, @now)",
            new { id, userId, author, body, now }, tx);
        tx.Commit();
        return id;
    }

    public long AddPost(long threadId, long? userId, string author, string body, long now)
    {
        using var c = db.Open();
        return c.ExecuteScalar<long>("""
            INSERT INTO posts(thread_id, user_id, author, body, created) VALUES (@threadId, @userId, @author, @body, @now);
            UPDATE threads SET last_post = @now WHERE id = @threadId;
            SELECT MAX(id) FROM posts WHERE thread_id = @threadId;
            """, new { threadId, userId, author, body, now });
    }

    public List<PostRow> Posts(long threadId)
    {
        using var c = db.Open();
        return c.Query<PostRow>("SELECT * FROM posts WHERE thread_id = @threadId ORDER BY id", new { threadId }).ToList();
    }

    public long? LastPostBy(long userId)
    {
        using var c = db.Open();
        return c.ExecuteScalar<long?>("SELECT MAX(created) FROM posts WHERE user_id = @userId", new { userId });
    }

    /// <summary>A post away; the first of a thread takes the thread.</summary>
    public void DeletePost(long id)
    {
        using var c = db.Open();
        var p = c.QuerySingleOrDefault<PostRow>("SELECT * FROM posts WHERE id = @id", new { id });
        if (p == null) return;
        var first = c.ExecuteScalar<long>("SELECT MIN(id) FROM posts WHERE thread_id = @t", new { t = p.ThreadId });
        if (first == id) c.Execute("DELETE FROM threads WHERE id = @t", new { t = p.ThreadId });
        else c.Execute("DELETE FROM posts WHERE id = @id", new { id });
    }

    public void DeleteThread(long id)
    {
        using var c = db.Open();
        c.Execute("DELETE FROM threads WHERE id = @id", new { id });
    }

    public void LockThread(long id, bool locked)
    {
        using var c = db.Open();
        c.Execute("UPDATE threads SET locked = @l WHERE id = @id", new { id, l = locked ? 1 : 0 });
    }

    public List<GuestbookRow> Guestbook(int limit = 200)
    {
        using var c = db.Open();
        return c.Query<GuestbookRow>("SELECT * FROM guestbook ORDER BY id DESC LIMIT @limit", new { limit }).ToList();
    }

    public void Sign(long? userId, string author, string text, long now)
    {
        using var c = db.Open();
        c.Execute("INSERT INTO guestbook(user_id, author, text, created) VALUES (@userId, @author, @text, @now)", new { userId, author, text, now });
    }

    public void DeleteGuestbook(long id)
    {
        using var c = db.Open();
        c.Execute("DELETE FROM guestbook WHERE id = @id", new { id });
    }

    public List<NewsRow> News(int limit = 50)
    {
        using var c = db.Open();
        return c.Query<NewsRow>("SELECT * FROM news ORDER BY created DESC, id DESC LIMIT @limit", new { limit }).ToList();
    }

    public long AddNews(string title, string body, string author, long now)
    {
        using var c = db.Open();
        return c.ExecuteScalar<long>("INSERT INTO news(title, body, author, created) VALUES (@title, @body, @author, @now); SELECT last_insert_rowid();",
            new { title, body, author, now });
    }

    public void DeleteNews(long id)
    {
        using var c = db.Open();
        c.Execute("DELETE FROM news WHERE id = @id", new { id });
    }
}
