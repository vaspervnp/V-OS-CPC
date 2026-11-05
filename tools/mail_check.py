#!/usr/bin/env python3
"""Check MAIL (make test-mail).

usage: mail_check.py mail.bin mail.sym

Runs MAIL (myapps/mail, assembled at #4000, with its symbols) in a Z80
emulator with the V-OS calls stubbed as tools/database_check.py does
them (a screen of text, VOS_INPUT and VOS_DIALOG from a script, files
in a dict, the data bank) and the M4 board of tools/m4net.py, with a
POP3 and an SMTP server in Python. The account is asked for at the
first GET MAIL and kept in MAIL.CFG; the POP3 server, found by its
name, has 22 messages: the list must show the newest 20, the newest
first, who from and the subject (=?UTF-8?B?..?= and
=?ISO-8859-7?Q?..?= decoded); READ must show a plain one (a line
starting with "." and one of 200 characters, wrapped), one in
quoted-printable UTF-8 (its soft breaks joined) and one in parts
(its base64 UTF-8 text, not its HTML), scroll, and SAVE AS TEXT write
what it shows. DELETE must be DELE, done at the QUIT of the next GET
MAIL. WRITE must send a NOTEPAD .TXT through the SMTP server (EHLO,
AUTH LOGIN in base64, a "." line doubled, the Greek subject in
=?ISO-8859-7?Q?..?=), REPLY to the sender with "Re: ", and a recipient
the server refuses must say NOT SENT with its reply. A wrong password,
a server that answers nothing and no board. Exits 1 on the first
difference.
"""
import base64
import os
import quopri
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database_check as dc  # noqa: E402
import m4net                 # noqa: E402

CMD = dict(GET=1, READ=2, WRITE=3, REPLY=4, DELETE=5, SAVE=6, ACCOUNT=7,
           DRIVE=8, ABOUT=9, BACK=10)
TOP_Y, TEXT_Y, ROWS, INFO = 14, 28, 20, 26
CATALOG, LOAD, SAVE, INPUT, BANK_PUT, EXT, VX_UTF8 = 24, 25, 26, 19, 38, 42, 9
POP_IP, SMTP_IP = m4net.ip('10.0.0.1'), m4net.ip('10.0.0.2')
LONG = ' '.join('word%02d' % i for i in range(30))       # 209 characters


def msg(head, body):
    return ('\r\n'.join(head) + '\r\n\r\n').encode('latin-1') + body


def messages():
    out = []
    for i in range(1, 20):
        out.append(msg(['From: User %d <user%d@test>' % (i, i), 'Subject: Note %d' % i],
                       b'Text %d\r\n' % i))
    out.append(msg(['Return-Path: <alice@test>', 'From: "Alice Smith" <alice@test>',
                    'Date: Wed, 4 Nov 2026 10:00:00 +0200', 'Subject: Hello there'],
                   b'Hi,\r\n.hidden dot\r\n' + LONG.encode() + b'\r\nBye\r\n' +
                   b''.join(b'Line %d\r\n' % i for i in range(1, 26))))
    greek = 'Καλημέρα κόσμε, αυτό είναι ένα μήνυμα με πολλά ελληνικά γράμματα.'
    qp = quopri.encodestring(greek.encode('utf-8'))
    subj = base64.b64encode('Ελληνικά'.encode('utf-8')).decode()
    out.append(msg(['From: Maria <maria@test>', 'Subject: =?UTF-8?B?%s?=' % subj,
                    'Content-Type: text/plain;', ' charset="UTF-8"',
                    'Content-Transfer-Encoding: quoted-printable'],
                   qp.replace(b'\n', b'\r\n') + b'\r\nEnd\r\n'))
    text = base64.encodebytes('Γεια σας από το V-OS.\r\nΔεύτερη γραμμή.\r\n'.encode('utf-8'))
    subj = ''.join('=%02X' % b if b > 127 else ('_' if b == 32 else chr(b))
                   for b in 'Νέα έκδοση'.encode('iso-8859-7'))
    out.append(msg(['From: Nikos P <nikos@test>', 'Subject: =?ISO-8859-7?Q?%s?=' % subj,
                    'MIME-Version: 1.0',
                    'Content-Type: multipart/alternative; boundary="b1=_x"'],
                   b'This is a message in parts.\r\n\r\n--b1=_x\r\n'
                   b'Content-Type: text/plain; charset="utf-8"\r\n'
                   b'Content-Transfer-Encoding: base64\r\n\r\n' +
                   text.replace(b'\n', b'\r\n') +
                   b'\r\n--b1=_x\r\nContent-Type: text/html\r\n\r\n<p>HTML</p>\r\n'
                   b'--b1=_x--\r\n'))
    return out


def stuffed(data):
    lines = data.split(b'\r\n')
    return b''.join((b'.' + ln if ln.startswith(b'.') else ln) + b'\r\n' for ln in lines[:-1])


class Pop3(m4net.LineServer):
    def __init__(self, box, password='secret'):
        super().__init__()
        self.box, self.password = box, password
        self.deleted = set()
        self.user = None

    def connected(self):
        self.say('+OK POP3 ready')

    def line(self, one):
        word, _, arg = one.decode('latin-1').partition(' ')
        live = self.box['msgs']
        if word == 'USER':
            self.user = arg
            self.say('+OK')
        elif word == 'PASS':
            self.say('+OK logged in' if (self.user, arg) == ('vasilis', self.password)
                     else '-ERR wrong password')
        elif word == 'STAT':
            self.say('+OK %d %d' % (len(live), sum(map(len, live))))
        elif word == 'TOP':
            n = int(arg.split()[0])
            self.say('+OK')
            self.inbox += stuffed(live[n - 1].split(b'\r\n\r\n')[0] + b'\r\n') + b'.\r\n'
        elif word == 'RETR':
            n = int(arg)
            self.say('+OK %d octets' % len(live[n - 1]))
            self.inbox += stuffed(live[n - 1]) + b'.\r\n'
        elif word == 'DELE':
            self.deleted.add(int(arg))
            self.say('+OK deleted')
        elif word == 'QUIT':
            self.box['msgs'] = [m for i, m in enumerate(live, 1) if i not in self.deleted]
            self.say('+OK bye')
            self.closing = True
        else:
            self.say('-ERR what?')


class Smtp(m4net.LineServer):
    def __init__(self, mails):
        super().__init__()
        self.mails = mails
        self.state, self.data, self.rcpt = None, [], None

    def connected(self):
        self.say('220 smtp.test ESMTP')

    def line(self, one):
        if self.state == 'data':
            if one == b'.':
                self.mails.append((self.rcpt, self.data))
                self.state = None
                self.say('250 queued')
            else:
                self.data.append(one)
            return
        if self.state == 'user':
            self.auth = [base64.b64decode(one)]
            self.state = 'pass'
            self.say('334 UGFzc3dvcmQ6')
            return
        if self.state == 'pass':
            self.auth.append(base64.b64decode(one))
            self.state = None
            self.say('235 OK' if self.auth == [b'vasilis', b'secret'] else '535 no')
            return
        text = one.decode('latin-1')
        if text.startswith('EHLO'):
            self.say('250-smtp.test')
            self.say('250-AUTH LOGIN PLAIN')
            self.say('250 8BITMIME')
        elif text == 'AUTH LOGIN':
            self.state = 'user'
            self.say('334 VXNlcm5hbWU6')
        elif text.startswith('MAIL FROM:'):
            self.say('250 OK')
        elif text.startswith('RCPT TO:'):
            self.rcpt = text[8:]
            self.say('550 No such user' if 'nobody' in text else '250 OK')
        elif text == 'DATA':
            self.state, self.data = 'data', []
            self.say('354 go on')
        elif text == 'QUIT':
            self.say('221 bye')
            self.closing = True
        else:
            self.say('500 what?')


class Mail(dc.App, m4net.Net):
    def __init__(self, prog, sym, board=True):
        super().__init__(prog, sym)
        self.net_init(board)
        self.asked = []
        self.saved = []

    def api_hook(self, n, m):
        mem = m.memory
        if n == LOAD:
            key = (m.a & 3, bytes(mem[m.hl:m.hl + 11]))
            if key not in self.files:
                m.a = 7
                m.f |= 1
                return True
            data = self.files[key]
            if m.a & 0x80:
                self.bank[m.de - 0x4000:m.de - 0x4000 + len(data)] = data
            else:
                m.set_memory_block(m.de, data)
            m.bc = len(data)
            return True
        if n == SAVE:
            key = (m.a & 3, bytes(mem[m.hl:m.hl + 11]))
            if m.a & 0x80:
                data = bytes(self.bank[m.de - 0x4000:m.de - 0x4000 + m.bc])
            else:
                data = bytes(mem[m.de:m.de + m.bc])
            self.files[key] = data
            self.saved.append(key)
            return True
        if n == CATALOG:                    # VOS_CAT_EXT: one extension
            ext = bytes(mem[m.hl:m.hl + 3])
            names = sorted(k[1] for k in self.files if k[0] == m.a & 3 and
                           (not m.a & 0x40 or k[1][8:] == ext))
            m.set_memory_block(dc.CAT, b''.join(nm + bytes(5) for nm in names) or b'\0')
            m.a, m.hl = len(names), dc.CAT
            return True
        if n == BANK_PUT:
            self.bank[m.de - 0x4000:m.de - 0x4000 + m.bc] = bytes(mem[m.hl:m.hl + m.bc])
            return True
        if n == INPUT:
            now = bytes(mem[m.hl:m.hl + 64]).split(b'\0')[0].decode('vos')
            self.asked.append(now)
            ans = self.inputs.pop(0)
            if ans is None:
                m.f |= 1
            elif ans is not Ellipsis:
                m.set_memory_block(m.hl, ans.encode('vos') + b'\0')
            return True
        if n == EXT and m.a == VX_UTF8:
            if m.e & 0x80:
                data = bytes(self.bank[m.hl - 0x4000:m.hl - 0x4000 + m.bc])
            else:
                data = bytes(mem[m.hl:m.hl + m.bc])
            m.a = 0
            if max(data, default=0) > 127:
                try:
                    out = data.decode('utf-8').encode('vos')
                except UnicodeDecodeError:
                    return True
                if m.e & 0x80:
                    self.bank[m.hl - 0x4000:m.hl - 0x4000 + len(out)] = out
                else:
                    m.set_memory_block(m.hl, out)
                m.bc, m.a = len(out), 1
            return True
        return False

    def top(self):
        return self.line(TOP_Y)

    def rows(self):
        return [self.line(TEXT_Y + 10 * r) for r in range(ROWS)]

    def sel(self):
        return [r for r in range(ROWS) if any(self.inv.get(TEXT_Y + 10 * r, []))]


def check(what, got, want):
    if got != want:
        sys.exit('mail_check: %s:\n  got  %r\n  want %r' % (what, got, want))


def command(app, c):
    app.call('COMMAND', a=dc.VC_APP + CMD[c])


def key(app, k):
    app.key(dict(ESC=66).get(k, k))


def row(name, subject):
    return (' %-16s %-30s' % (name[:16], subject[:30])).rstrip()


def setup(prog, sym, board=True, password='secret'):
    app = Mail(prog, sym, board)
    box = {'msgs': messages()}
    app.box, app.mails = box, []
    app.pops = []

    def pop():
        s = Pop3(box, password)
        app.pops.append(s)
        return s
    app.servers[(POP_IP, 110)] = pop
    app.servers[(SMTP_IP, 2525)] = lambda: Smtp(app.mails)
    app.names[b'mail.test'] = POP_IP
    app.call('INIT', a=0)
    return app


def get_list(app):
    for _ in range(400):
        app.frame()
        if 'MESSAGES' in app.top():
            return
    sys.exit('mail_check: no list: %r' % app.top())


def read(app):
    key(app, 'RETURN')
    for _ in range(200):
        app.frame()
        if app.rows()[0].startswith('FROM:'):
            return app.rows()
    sys.exit('mail_check: not read: %r' % app.top())


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    app = setup(prog, sym)
    check('at first', app.top(), 'NOT CONNECTED')
    # GET MAIL: the account first
    app.inputs = ['mail.test', '10.0.0.2:2525', 'vasilis', 'secret', 'vasilis@test']
    command(app, 'GET')
    cfg = app.files.get((1, b'MAIL    CFG'))
    check('MAIL.CFG', cfg is not None and cfg[:9] + cfg[42:55], b'mail.test10.0.0.2:2525')
    check('looked up', app.log[0], ('lookup', b'mail.test'))
    get_list(app)
    check('connected', app.top(), 'CONNECTED' + ' ' * 17 + '22 MESSAGES')
    pop = app.pops[0]
    check('logged in', pop.lines[:3], [b'USER vasilis', b'PASS secret', b'STAT'])
    check('the newest 20 by TOP', [ln for ln in pop.lines if ln.startswith(b'TOP')][:2],
          [b'TOP 22 0', b'TOP 21 0'])
    rows = app.rows()
    check('the list', rows[:3], [row('Nikos P', 'Νέα έκδοση'), row('Maria', 'Ελληνικά'),
                                 row('Alice Smith', 'Hello there')])
    check('the oldest shown', rows[19], row('User 3', 'Note 3'))
    check('the first chosen', app.sel(), [0])
    # READ: a plain one
    key(app, 'DOWN')
    key(app, 'DOWN')
    check('DOWN twice', app.sel(), [2])
    rows = read(app)
    check('RETR 20', pop.lines[-1], b'RETR 20')
    want = ['FROM: "Alice Smith" <alice@test>', 'DATE: Wed, 4 Nov 2026 10:00:00 +0200',
            'SUBJECT: Hello there', '', 'Hi,', '.hidden dot',
            LONG[:48], LONG[48:96], LONG[96:144], LONG[144:192], LONG[192:], 'Bye']
    check('read', rows[:12], want)
    key(app, 'DOWN')
    check('DOWN: a line on', app.rows()[0], want[1])
    key(app, 'RIGHT')
    key(app, 'RIGHT')
    check('RIGHT: the last page', app.rows()[-2:], ['Line 25', ''])
    key(app, 'LEFT')
    check('LEFT: a page back, the start', app.rows()[0], want[0])
    key(app, 'RETURN')
    check('RETURN: the list', (app.rows()[2], app.sel()), (row('Alice Smith', 'Hello there'), [2]))
    # quoted-printable UTF-8
    key(app, 'UP')
    rows = read(app)
    greek = 'Καλημέρα κόσμε, αυτό είναι ένα μήνυμα με πολλά ελληνικά γράμματα.'
    check('quoted-printable', rows[2:7], ['SUBJECT: Ελληνικά', '', greek[:48], greek[48:], 'End'])
    key(app, 'RETURN')
    # in parts
    key(app, 'UP')
    rows = read(app)
    check('in parts', rows[2:7], ['SUBJECT: Νέα έκδοση', '', 'Γεια σας από το V-OS.',
                                  'Δεύτερη γραμμή.', ''])
    check('not the HTML', any('HTML' in r for r in rows), False)
    # SAVE AS TEXT
    app.inputs = ['greek.txt']
    command(app, 'SAVE')
    text = app.files.get((1, b'GREEK   TXT'), b'')
    check('saved', text.decode('vos').split('\r\n')[2:5],
          ['SUBJECT: Νέα έκδοση', '', 'Γεια σας από το V-OS.'])
    check('SAVED', app.top()[:5], 'SAVED')
    # DELETE: at the QUIT of the next GET MAIL
    app.buttons = [0]
    command(app, 'DELETE')
    app.frames(3)
    check('DELE 22', pop.lines[-1], b'DELE 22')
    check('marked', app.rows()[0][:1], 'X')
    # WRITE: a .TXT through SMTP
    app.files[(1, b'NOTE    TXT')] = b'Hello Bob,\r\n.a dot first\r\nbye'
    app.inputs = ['bob@test', 'Γεια σου']
    app.picks = [1]                          # GREEK, NOTE
    command(app, 'WRITE')
    check('sending', app.top(), 'SENDING')
    for _ in range(100):
        app.frame()
        if app.top() == 'SENT' and not app.socks:
            break
    check('SENT', app.top(), 'SENT')
    rcpt, data = app.mails[0]
    check('to', rcpt, '<bob@test>')
    subj = '=?ISO-8859-7?Q?' + ''.join('=%02X' % b if b > 127 else '_'
                                       for b in 'Γεια σου'.encode('iso-8859-7')) + '?='
    check('the headers', data[:4], [b'From: vasilis@test', b'To: bob@test',
                                    b'Subject: ' + subj.encode(), b'MIME-Version: 1.0'])
    i = data.index(b'')
    check('the text', data[i + 1:], [b'Hello Bob,', b'..a dot first', b'bye'])
    # GET MAIL again: QUIT, 22 gone
    command(app, 'GET')
    check('QUIT', pop.lines[-1], b'QUIT')
    get_list(app)
    check('deleted', (len(app.box['msgs']), app.rows()[0]), (21, row('Maria', 'Ελληνικά')))
    # REPLY
    read(app)
    app.inputs = [Ellipsis, Ellipsis]
    app.picks = [1]
    command(app, 'REPLY')
    check('REPLY asks', app.asked[-2:], ['maria@test', 'Re: Ελληνικά'])
    for _ in range(100):
        app.frame()
        if len(app.mails) == 2:
            break
    check('replied', app.mails[1][0], '<maria@test>')
    for _ in range(20):
        app.frame()
    # refused
    app.inputs = ['nobody@test', 'x']
    app.picks = [1]
    command(app, 'WRITE')
    for _ in range(100):
        app.frame()
        if app.top().startswith('NOT SENT'):
            break
    check('refused', app.top(), 'NOT SENT' + ' ' * 18 + '550 No such user')
    # a wrong password
    app2 = setup(prog, sym, password='other')
    app2.files[(1, b'MAIL    CFG')] = cfg
    app2.call('INIT', a=0)
    command(app2, 'GET')
    app2.frames(30)
    check('wrong password', app2.top(), 'LOGIN REFUSED' + ' ' * 13 + '-ERR wrong password')
    # a server that answers nothing
    app3 = setup(prog, sym)
    app3.files[(1, b'MAIL    CFG')] = cfg
    app3.call('INIT', a=0)
    app3.servers[(POP_IP, 110)] = lambda: m4net.Server()
    command(app3, 'GET')
    app3.frames(1600)
    check('no answer', app3.top(), 'NO ANSWER')
    # no board
    app4 = setup(prog, sym, board=False)
    app4.files[(1, b'MAIL    CFG')] = cfg
    app4.call('INIT', a=0)
    command(app4, 'GET')
    check('no M4 board', app4.top(), 'NO M4 BOARD')
    for a in (app, app2, app3, app4):
        if a.errors:
            sys.exit('mail_check: errors %r' % a.errors)
    print('mail_check: the account, the list (the newest 20, headers decoded), a plain '
          'message, quoted-printable UTF-8, one in parts, scrolling, SAVE AS TEXT, DELETE '
          'at QUIT, WRITE and REPLY through SMTP (AUTH LOGIN, "." doubled, the subject '
          'in Q), refused, a wrong password, no answer, no board: all right')


if __name__ == '__main__':
    main()
