#!/usr/bin/env python3
"""Check FTP (make test-ftp).

usage: ftp_check.py ftp.bin ftp.sym

Runs FTP (myapps/ftp, assembled at #4000, with its symbols) in a Z80
emulator with the V-OS calls stubbed as tools/mail_check.py does them,
and the M4 board of tools/m4net.py with an FTP server in Python, found
by its name. Anonymous at first (USER anonymous, a password made up),
TYPE I, PWD, PASV (its address not the server's: the control
connection's is used) and LIST in Unix's lines: the list must show the
folders as <DIR> and the files with their sizes. RETURN on a file must
RETR it and save it under its 8.3 name; on a folder CWD, whose LIST is
in DOS's lines; DEL CDUP. PUT must STOR a file of 600 bytes in pieces,
the list read again; DELETE must DELE it. A file over 16K must not be
saved on B:; on DISK it must be written to the card as it comes (the
M4's files of tools/m4net.py), and PUT from DISK read as it goes (70000
bytes; one with an AMSDOS header sent without it). A wrong password
must say LOGIN REFUSED, CLOSE QUIT; no board.
Exits 1 on the first difference.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database_check as dc  # noqa: E402
import m4net                 # noqa: E402
import mail_check as mc      # noqa: E402

CMD = dict(CONNECT=1, CLOSE=2, GET=3, PUT=4, DELETE=5, UP=6, DRIVE=7, ABOUT=8, BACK=9)
TOP_Y, TEXT_Y, ROWS = 14, 28, 20
FTP_IP = m4net.ip('10.0.0.3')
README = bytes(range(256)) * 4 + b'the end'
BIG = b'x' * 20000


class Data(m4net.Server):
    """the data connection of PASV"""
    def __init__(self, ctl):
        super().__init__()
        self.ctl, self.up = ctl, False

    def connected(self):
        self.up = True

    def closed(self):
        super().closed()
        self.ctl.data_closed(self)


class Ftp(m4net.LineServer):
    def __init__(self, fs, password='secret'):
        super().__init__()
        self.fs, self.password = fs, password
        self.cwd, self.user, self.data, self.port = [], None, None, 40000
        self.stored = {}

    def connected(self):
        self.say('220-Welcome')
        self.say('220 FTP ready')

    def folder(self):
        f = self.fs
        for p in self.cwd:
            f = f[p]
        return f

    def listing(self):
        f = self.folder()
        out = []
        for name, v in sorted(f.items()):
            if self.cwd:                    # DOS's lines in a folder
                out.append('11-01-26  10:00AM       %-14s %s' %
                           ('<DIR>' if isinstance(v, dict) else len(v), name))
            elif isinstance(v, dict):
                out.append('drwxr-xr-x    2 ftp      ftp          4096 Nov  1 10:00 %s' % name)
            else:
                out.append('-rw-r--r--    1 ftp      ftp      %8d Nov  1  2026 %s' % (len(v), name))
        return ''.join(x + '\r\n' for x in out).encode()

    def line(self, one):
        word, _, arg = one.decode('latin-1').partition(' ')
        if word == 'USER':
            self.user = arg
            self.say('331 password please')
        elif word == 'PASS':
            ok = self.user == 'anonymous' or (self.user, arg) == ('vasilis', self.password)
            self.say('230 in' if ok else '530 Login incorrect')
        elif word == 'TYPE':
            self.say('200 Type set to I')
        elif word == 'PWD':
            self.say('257 "/%s" is the folder' % '/'.join(self.cwd))
        elif word == 'CWD':
            if isinstance(self.folder().get(arg), dict):
                self.cwd.append(arg)
                self.say('250 OK')
            else:
                self.say('550 No such folder')
        elif word == 'CDUP':
            self.cwd = self.cwd[:-1]
            self.say('250 OK')
        elif word == 'PASV':
            self.port += 1
            self.data = Data(self)
            self.net.servers[(FTP_IP, self.port)] = self.data
            self.say('227 Entering Passive Mode (192,168,1,5,%d,%d)' % (self.port >> 8, self.port & 255))
        elif word in ('LIST', 'RETR', 'STOR'):
            if not self.data or not self.data.up:
                self.say('425 no data connection')
                return
            if word == 'STOR':
                self.say('150 send it')
                self.storing = arg
                return
            if word == 'LIST':
                body = self.listing()
            else:
                body = self.folder().get(arg)
                if not isinstance(body, bytes):
                    self.say('550 no such file')
                    return
            self.say('150 here it comes')
            self.data.inbox, self.data.closing = body, True
            self.after = '226 done'
        elif word == 'DELE':
            if isinstance(self.folder().get(arg), bytes):
                del self.folder()[arg]
                self.say('250 deleted')
            else:
                self.say('550 no')
        elif word == 'QUIT':
            self.say('221 bye')
            self.closing = True
        else:
            self.say('502 what?')

    def data_closed(self, data):
        if getattr(self, 'storing', None):
            self.folder()[self.storing.lower()] = data.sent
            self.stored[self.storing] = data.sent
            self.storing = None
            self.say('226 stored')
        elif getattr(self, 'after', None):
            self.say(self.after)
            self.after = None


class App(mc.Mail):
    def top(self):
        return self.line(TOP_Y)


def check(what, got, want):
    if got != want:
        sys.exit('ftp_check: %s:\n  got  %r\n  want %r' % (what, got, want))


def command(app, c):
    app.call('COMMAND', a=dc.VC_APP + CMD[c])


def row(name, size):
    return (' %-36s %9s' % (name, size)).rstrip()


def setup(prog, sym, board=True, password='secret'):
    app = App(prog, sym, board)
    app.fs = {'pub': {'linux.txt': b'Linux\r\n', 'old': {}}, 'readme.txt': README,
              'big.dat': BIG, 'a-very-long-name.backup.txt': b'long'}
    app.ftps = []

    def make():
        s = Ftp(app.fs, password)
        app.ftps.append(s)
        return s
    app.servers[(FTP_IP, 21)] = make
    app.names[b'ftp.test'] = FTP_IP
    app.call('INIT', a=0)
    return app


def wait(app, done, n=200):
    for _ in range(n):
        app.frame()
        if done():
            return
    sys.exit('ftp_check: waited in vain: %r' % app.top())


def choose(app, want):
    """UP to the first, then DOWN to the row that is want"""
    for _ in range(10):
        app.key('UP')
    for _ in range(10):
        if app.line(TEXT_Y + 10 * app.sel()[0]) == want:
            return
        app.key('DOWN')
    sys.exit('ftp_check: no %r in the list' % want)


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    app = setup(prog, sym)
    check('at first', app.top(), 'NOT CONNECTED')
    # anonymous
    app.inputs = ['ftp.test', '']
    command(app, 'CONNECT')
    wait(app, lambda: app.top().endswith('/') and app.line(TEXT_Y))
    ftp = app.ftps[0]
    check('logged in', ftp.lines[:6], [b'USER anonymous', b'PASS vos@cpc', b'TYPE I', b'PWD',
                                       b'PASV', b'LIST'])
    data = [x for x in app.log if x[0] == 'connect'][-1]
    check('to the control connection\'s ip', data[2:], (FTP_IP, 40001))
    check('connected', app.top(), 'CONNECTED' + ' ' * 17 + '/')
    want = [row('a-very-long-name.backup.txt', 4), row('big.dat', 20000), row('pub', '<DIR>'),
            row('readme.txt', len(README))]
    check('the list (Unix)', app.line(TEXT_Y), want[0])
    check('the list (Unix)', [app.line(TEXT_Y + 10 * r) for r in range(5)], want + [''])
    check('the first chosen', app.sel(), [0])
    # RETURN on a file: RETR, its 8.3 name
    app.inputs = [Ellipsis]
    app.key('RETURN')
    check('its name', app.asked[-1], 'a-very-l.txt')
    wait(app, lambda: app.top().startswith('SAVED'))
    check('RETR', ftp.lines[-1], b'RETR a-very-long-name.backup.txt')
    check('saved', app.files.get((1, b'A-VERY-LTXT')), b'long')
    check('SAVED', app.top(), 'SAVED, BYTES' + ' ' * 14 + '4')
    app.key('DOWN')
    app.key('DOWN')
    app.key('DOWN')
    app.inputs = ['readme.txt']
    command(app, 'GET')
    wait(app, lambda: app.top().startswith('SAVED') and app.top().endswith(' 1031'))
    check('a file of 1031 bytes', app.files.get((1, b'README  TXT')) == README, True)
    # a folder: CWD, DOS's lines
    app.key('UP')
    app.key('RETURN')
    wait(app, lambda: app.top().endswith('/pub'))
    check('CWD', ftp.lines[-4:-2], [b'CWD pub', b'PWD'])
    check('the list (DOS)', [app.line(TEXT_Y + 10 * r) for r in range(3)],
          [row('linux.txt', 7), row('old', '<DIR>'), ''])
    app.key('DEL')
    wait(app, lambda: app.top().endswith(' /'))
    check('CDUP', ftp.lines[-4], b'CDUP')
    # PUT: STOR in pieces, the list again
    note = bytes((i * 7) & 255 for i in range(600))
    app.files[(1, b'NOTE    TXT')] = note
    names = sorted(k[1] for k in app.files if k[0] == 1)
    app.picks = [names.index(b'NOTE    TXT')]
    command(app, 'PUT')
    wait(app, lambda: app.top().startswith('SENT'))
    check('STOR', ftp.stored.get('NOTE.TXT') == note, True)
    check('SENT', app.top(), 'SENT, BYTES' + ' ' * 15 + '600')
    rows = [app.line(TEXT_Y + 10 * r) for r in range(6)]
    check('in the list', row('note.txt', 600) in rows, True)
    # DELETE
    choose(app, row('note.txt', 600))
    app.buttons = [0]
    command(app, 'DELETE')
    wait(app, lambda: ftp.lines[-1] == b'LIST' and app.top().endswith(' /'))
    check('DELE', ftp.lines[-3], b'DELE note.txt')
    rows = [app.line(TEXT_Y + 10 * r) for r in range(6)]
    check('not in the list', row('note.txt', 600) in rows, False)
    # over 16K: not saved
    choose(app, row('big.dat', 20000))
    app.inputs = [Ellipsis]
    command(app, 'GET')
    wait(app, lambda: app.top().startswith('OVER 16K'))
    check('not saved', (1, b'BIG     DAT') in app.files, False)
    # DISK: big.dat written to the card as it comes; PUT from the card,
    # with and without an AMSDOS header
    app.m.memory[app.sym['F_DRIVE']] = 2
    app.inputs = [Ellipsis]
    command(app, 'GET')
    wait(app, lambda: app.top().startswith('SAVED'), 400)
    check('20000 bytes to the card', app.card.get('BIG.DAT') == BIG, True)
    check('SAVED, BYTES 20000', app.top(), 'SAVED, BYTES' + ' ' * 14 + '20000')
    check('the card closed', app.fds, {})
    big = bytes((i * 13 + (i >> 8)) & 255 for i in range(70000))
    app.card['HUGE.BIN'] = big
    hdr = bytearray(128)
    hdr[1:12] = b'NOTE    TXT'
    hdr[0x12], hdr[0x40], hdr[0x41] = 2, 300 & 255, 300 >> 8
    hdr[0x18:0x1A] = (300).to_bytes(2, 'little')
    hdr[0x43:0x45] = sum(hdr[:67]).to_bytes(2, 'little')
    app.card['NOTE.TXT'] = bytes(hdr) + bytes(range(256)) + bytes(44)
    app.files[(2, b'HUGE    BIN')] = b''
    app.files[(2, b'NOTE    TXT')] = b''
    for name, size in ((b'HUGE    BIN', '68K'), (b'NOTE    TXT', '300')):
        names = sorted(k[1] for k in app.files if k[0] == 2)
        app.picks = [names.index(name)]
        command(app, 'PUT')
        want = 'SENT, BYTES' + ' ' * 15 + size
        wait(app, lambda: app.top() == want, 800)
    check('70000 bytes from the card', ftp.stored.get('HUGE.BIN') == big, True)
    check('without its AMSDOS header', ftp.stored.get('NOTE.TXT') == bytes(range(256)) + bytes(44), True)
    check('the card closed again', app.fds, {})
    # CLOSE: QUIT
    command(app, 'CLOSE')
    check('QUIT', ftp.lines[-1], b'QUIT')
    check('closed', app.top(), 'NOT CONNECTED')
    # a wrong password
    app2 = setup(prog, sym, password='other')
    app2.inputs = ['ftp.test', 'vasilis', 'secret']
    command(app2, 'CONNECT')
    wait(app2, lambda: app2.top().startswith('LOGIN REFUSED'))
    check('refused', app2.top(), 'LOGIN REFUSED' + ' ' * 13 + '530 Login incorrect')
    # the right one
    app3 = setup(prog, sym)
    app3.inputs = ['10.0.0.3:21', 'vasilis', 'secret']
    command(app3, 'CONNECT')
    wait(app3, lambda: app3.top().endswith('/'))
    check('logged in as vasilis', app3.ftps[0].lines[:2], [b'USER vasilis', b'PASS secret'])
    # no board
    app4 = setup(prog, sym, board=False)
    app4.inputs = ['ftp.test', '']
    command(app4, 'CONNECT')
    check('no M4 board', app4.top(), 'NO M4 BOARD')
    for a in (app, app2, app3, app4):
        if a.errors:
            sys.exit('ftp_check: errors %r' % a.errors)
    print('ftp_check: anonymous, PASV to the control connection\'s ip, LIST in Unix\'s and '
          'DOS\'s lines, RETR into 8.3 names, CWD and CDUP, STOR in pieces, DELE, over 16K '
          'not saved on B:, any size to and from DISK, QUIT, a wrong password, a user, no board: all right')


if __name__ == '__main__':
    main()
