-- V-OS NET: the first schema. Times are Unix seconds (UTC).
CREATE TABLE users (
    id             INTEGER PRIMARY KEY,
    name           TEXT NOT NULL,
    name_upper     TEXT NOT NULL UNIQUE,
    email          TEXT,
    pw_hash        TEXT NOT NULL,
    role           TEXT NOT NULL DEFAULT 'USER',
    created        INTEGER NOT NULL,
    created_ip     TEXT,
    last_seen      INTEGER,
    failed         INTEGER NOT NULL DEFAULT 0,
    locked_until   INTEGER,
    must_change_pw INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX users_created_ip ON users(created_ip, created);

CREATE TABLE boards (
    id      INTEGER PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_el TEXT NOT NULL,
    sort    INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE threads (
    id        INTEGER PRIMARY KEY,
    board_id  INTEGER NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
    title     TEXT NOT NULL,
    user_id   INTEGER,
    author    TEXT NOT NULL,
    created   INTEGER NOT NULL,
    last_post INTEGER NOT NULL,
    locked    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX threads_board ON threads(board_id, last_post);
CREATE TABLE posts (
    id        INTEGER PRIMARY KEY,
    thread_id INTEGER NOT NULL REFERENCES threads(id) ON DELETE CASCADE,
    user_id   INTEGER,
    author    TEXT NOT NULL,
    body      TEXT NOT NULL,
    created   INTEGER NOT NULL
);
CREATE INDEX posts_thread ON posts(thread_id, id);

CREATE TABLE guestbook (
    id      INTEGER PRIMARY KEY,
    user_id INTEGER,
    author  TEXT NOT NULL,
    text    TEXT NOT NULL,
    created INTEGER NOT NULL
);
CREATE TABLE news (
    id      INTEGER PRIMARY KEY,
    title   TEXT NOT NULL,
    body    TEXT NOT NULL,
    author  TEXT NOT NULL,
    created INTEGER NOT NULL
);
CREATE TABLE bans (
    id         INTEGER PRIMARY KEY,
    ip_or_cidr TEXT NOT NULL,
    until      INTEGER,               -- NULL: for ever
    reason     TEXT NOT NULL,
    by         TEXT NOT NULL,         -- a user, or SERVER (§7)
    created    INTEGER NOT NULL
);
CREATE TABLE questions (
    id      INTEGER PRIMARY KEY,
    text_en TEXT NOT NULL,
    text_el TEXT NOT NULL,
    answer  TEXT NOT NULL             -- the answers accepted, a|b|c
);
CREATE TABLE audit (
    id      INTEGER PRIMARY KEY,
    at      INTEGER NOT NULL,
    user_id INTEGER,
    actor   TEXT NOT NULL,
    action  TEXT NOT NULL,
    target  TEXT,
    detail  TEXT
);
CREATE TABLE logins (                 -- for the logins a day
    id      INTEGER PRIMARY KEY,
    at      INTEGER NOT NULL,
    user_id INTEGER,
    ip      TEXT NOT NULL,
    via     TEXT NOT NULL             -- V-OS, UTF8, ASCII, WEB
);
CREATE INDEX logins_at ON logins(at);

INSERT INTO boards(name_en, name_el, sort) VALUES
    ('V-OS', 'V-OS', 1), ('PROGRAMS', 'ΠΡΟΓΡΑΜΜΑΤΑ', 2), ('CPC', 'CPC', 3), ('GENERAL', 'ΓΕΝΙΚΑ', 4);
INSERT INTO questions(text_en, text_el, answer) VALUES
    ('HOW MANY K OF MEMORY HAS THE CPC 6128?', 'ΠΟΣΑ K ΜΝΗΜΗ ΕΧΕΙ Ο CPC 6128;', '128|128K|128 K|128KB'),
    ('WHICH COMPANY MADE THE CPC?', 'ΠΟΙΑ ΕΤΑΙΡΕΙΑ ΕΦΤΙΑΞΕ ΤΟΝ CPC;', 'AMSTRAD|ΑΜΣΤΡΑΝΤ'),
    ('WHICH PROCESSOR HAS THE CPC (Z80 OR 6502)?', 'ΠΟΙΟΝ ΕΠΕΞΕΡΓΑΣΤΗ ΕΧΕΙ Ο CPC (Z80 Ή 6502);', 'Z80|Ζ80');
