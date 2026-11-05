#!/usr/bin/env python3
"""Check TELNET (make test-telnet).

usage: telnet_check.py telnet.bin telnet.sym

Runs TELNET (myapps/telnet, assembled at #4000, with its symbols) in a
Z80 emulator with the V-OS calls stubbed as tools/database_check.py
does them (its screen of text, VOS_INPUT and VOS_DIALOG from a script),
and an M4 board in Python: C_NETHOSTIP, C_NETSOCKET, C_NETCONNECT,
C_NETSEND, C_NETRECV, C_NETCLOSE, and the ROM's sock_info (VX_M4 with
HL = 0), a few frames late as the board is. A server there greets,
asks telnet options (TTYPE: WILL, and IS "V-OS" to SB TTYPE SEND; the
others refused; each answered once), sends ANSI colours (left
out), Greek in ISO 8859-7, 30 lines (the window scrolls) and answers
each line sent in capitals; "BYE" closes it from its end, "PASSWORD"
offers ECHO (DO: the line typed shown as *) and takes it back after
the next line. The address
by number and by name, a port, an address that answers nothing, and no
board. Exits 1 on the first difference.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database_check as dc  # noqa: E402

VE_FRAME = 8
CMD = dict(CONNECT=1, CLOSE=2, CLEAR=3)
TOP_Y, TEXT_Y, ROWS, IN_Y = 14, 28, 20, 232
IP = bytes([1, 0, 0, 127])                   # 127.0.0.1, the last first
IAC, WILL, WONT, DO, DONT, SB, SE = 255, 251, 252, 253, 254, 250, 240
ASKED = (bytes([IAC, DO, 24, IAC, SB, 24, 1, IAC, SE, IAC, DO, 24, IAC, DO, 31,
                IAC, WILL, 3]))
ANSWERED = (bytes([IAC, WILL, 24, IAC, SB, 24, 0]) + b'V-OS' + bytes([IAC, SE,
            IAC, WONT, 31, IAC, DONT, 3]))


class Server:
    """a socket of the M4 board, with the server at its other end"""
    def __init__(self):
        self.status, self.wait, self.inbox, self.sent = 0, 0, b'', b''
        self.closing = False

    def connect(self):
        self.status, self.wait = 1, 3        # connecting, for 3 frames
        self.inbox = (b'Welcome\r\n' + ASKED +
                      b'\x1b[1;33mYELLOW\x1b[0m done\r\n' +
                      'Καλημέρα\r\n'.encode('iso-8859-7') +
                      b''.join(b'line %d\r\n' % i for i in range(30)))

    def got(self, data):
        self.sent += data
        for line in data.split(b'\r\n')[:-1]:
            if line == b'PASSWORD':
                self.inbox += bytes([IAC, WILL, 1]) + b'Password:\r\n'
                self.echo = True
                continue
            if getattr(self, 'echo', False):
                self.inbox += bytes([IAC, WONT, 1, IAC, WONT, 1]) + b'ok\r\n'
                self.echo = False
                continue
            if line == b'BYE':
                self.inbox += b'Bye!\r\n'
                self.closing = True
            elif line[:1] != b'\xff':
                self.inbox += b'> ' + line.upper() + b'\r\n'


class Telnet(dc.App):
    def __init__(self, prog, sym, board=True, answers=True):
        super().__init__(prog, sym)
        self.board, self.answers = board, answers
        self.socks = {}
        self.lookup = 0
        self.log = []
        self.quiet = False                  # behind, covered: VOS_EXT quiet

    def info(self):
        """the ROM's sock_info: socket 0 the name looked up, 1-4"""
        out = bytearray(5 * 16)
        if self.lookup:
            out[0] = 5
        else:
            out[4:8] = IP
        for n, s in self.socks.items():
            out[n * 16] = s.status
            out[n * 16 + 2:n * 16 + 4] = len(s.inbox).to_bytes(2, 'little')
        return out

    def m4_call(self, m):
        if self.quiet:                      # WM.SYS's api_quiet: xor a, ret
            m.a, m.f = 0, 0x44
            return
        if not self.board:
            m.f |= 1
            return
        if m.hl == 0:
            m.set_memory_block(m.de, bytes(self.info()[:m.bc]))
            return
        mem = m.memory
        size = mem[m.hl]
        cmd = mem[m.hl + 1] | mem[m.hl + 2] << 8
        data = bytes(mem[m.hl + 3:m.hl + 1 + size])
        out = b''
        if cmd == 0x4336:                    # C_NETHOSTIP
            self.log.append(('lookup', data))
            self.lookup = 2 if data == b'echo.test\0' else 0
            out = b'\x01'
        elif cmd == 0x4331:                  # C_NETSOCKET
            check('C_NETSOCKET', data, b'\x00\x00\x06')
            n = len(self.socks) + 1
            self.socks[n] = Server()
            out = bytes([n])
        elif cmd == 0x4332:                  # C_NETCONNECT
            self.log.append(('connect', data[1:5], data[5] | data[6] << 8))
            s = self.socks[data[0]]
            if data[1:5] == IP and self.answers:
                s.connect()
            else:
                s.status, s.wait = 1, 3
                s.fail = True
            out = b'\x00'
        elif cmd == 0x4334:                  # C_NETSEND
            n = data[1] | data[2] << 8
            check('C_NETSEND size', len(data) - 3, n)
            self.socks[data[0]].got(data[3:])
            out = b'\x00'
        elif cmd == 0x4335:                  # C_NETRECV
            s = self.socks[data[0]]
            n = min(data[1] | data[2] << 8, len(s.inbox))
            got, s.inbox = s.inbox[:n], s.inbox[n:]
            out = b'\x00' + n.to_bytes(2, 'little') + got
        elif cmd == 0x4333:                  # C_NETCLOSE
            self.log.append(('close', data[0]))
            self.socks[data[0]].status = 0
            out = b'\x00'
        rsp = bytes([2 + len(out)]) + bytes([cmd & 255, cmd >> 8]) + out
        m.set_memory_block(m.de, rsp[:m.bc])

    def frame(self):
        """a frame: the board goes on, then TELNET's VE_FRAME"""
        if self.lookup:
            self.lookup -= 1
        for s in self.socks.values():
            if s.wait:
                s.wait -= 1
                if not s.wait:
                    s.status = 241 if getattr(s, 'fail', False) else 0
            elif s.closing and not s.inbox:
                s.status = 3
        self.m.set_memory_block(0xBF00, bytes([VE_FRAME, 0, 0, 0]))
        self.call('EVENT', hl=0xBF00)

    def frames(self, n):
        for _ in range(n):
            self.frame()

    def window(self):
        return [self.line(TEXT_Y + 10 * r) for r in range(ROWS)]


def check(what, got, want):
    if got != want:
        sys.exit('telnet_check: %s:\n  got  %r\n  want %r' % (what, got, want))


def command(app, c):
    app.call('COMMAND', a=dc.VC_APP + CMD[c])


def typed(app, s):
    for ch in s.encode('vos'):
        app.key(63, ch)
    app.key('RETURN')


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    app = Telnet(prog, sym)
    app.call('INIT', a=0)
    check('at first', app.line(TOP_Y)[:13], 'NOT CONNECTED')
    check('the line typed', app.line(IN_Y), '> _')
    # by number, a port
    app.inputs = ['127.0.0.1:2323']
    command(app, 'CONNECT')
    check('connecting', app.line(TOP_Y)[:10], 'CONNECTING')
    check('the address', app.line(TOP_Y)[22:], '127.0.0.1:2323')
    check('C_NETCONNECT', app.log[-1], ('connect', IP, 2323))
    app.frames(3)
    check('connected', app.line(TOP_Y)[:9], 'CONNECTED')
    app.frames(6)
    win = app.window()
    check('the last lines', win[-3:], ['line 28', 'line 29', ''])
    app.call('REDRAW')
    rows = app.window()
    check('scrolled: line 11 at the top', rows[0], 'line 11')
    sock = app.socks[1]
    check('TTYPE: WILL, IS V-OS; NAWS and SGA refused; once each', sock.sent, ANSWERED)
    app2 = Telnet(prog, sym)                 # the start, before it scrolls
    app2.call('INIT', a=0)
    app2.inputs = ['127.0.0.1:2323']
    command(app2, 'CONNECT')
    app2.frames(3)
    app2.socks[1].inbox = app2.socks[1].inbox[:app2.socks[1].inbox.index(b'line 0')]
    app2.frames(2)
    check('greeting, ANSI out, Greek', app2.window()[-4:],
          ['Welcome', 'YELLOW done', 'Καλημέρα', ''])
    # a line sent, its answer
    typed(app, 'hello there')
    check('sent with CR LF', sock.sent[len(ANSWERED):], b'hello there\r\n')
    check('the line typed empty again', app.line(IN_Y), '> _')
    app.frames(2)
    check('the answer', app.window()[-2:], ['> HELLO THERE', ''])
    typed(app, 'behind')                    # received, then behind and
    app.frames(1)                           # covered (VOS_EXT quiet): the
    app.quiet = True                        # old socks and answer are not
    app.frames(4)                           # taken again
    want = ['> HELLO THERE', '> BEHIND', '']
    check('behind, covered: nothing more', app.window()[-3:], want)
    app.quiet = False
    app.frames(2)
    check('uncovered again', app.window()[-3:], want)
    # a password: the other end echoes, * for each character typed
    typed(app, 'PASSWORD')
    app.frames(2)
    check('WILL ECHO: DO ECHO', sock.sent[-3:], bytes([IAC, DO, 1]))
    for ch in b'abc12345':
        app.key(63, ch)
    check('the password as *', app.line(IN_Y), '> ********_')
    app.key('RETURN')
    check('the password sent as it is', sock.sent[-10:], b'abc12345\r\n')
    app.frames(2)
    check('WONT ECHO (twice): DONT ECHO once', sock.sent[-13:], b'abc12345\r\n' + bytes([IAC, DONT, 1]))
    for ch in b'xy':
        app.key(63, ch)
    check('the line typed shown again', app.line(IN_Y), '> xy_')
    app.key('RETURN')
    app.frames(2)
    check('after the password', app.window()[-4:], ['Password:', 'ok', '> XY', ''])
    # BYE: closed by the other end, after its last words
    typed(app, 'BYE')
    app.frames(4)
    check('Bye!', app.window()[-2:], ['Bye!', ''])
    check('closed by the other end', app.line(TOP_Y)[:13], 'NOT CONNECTED')
    check('C_NETCLOSE', app.log[-1], ('close', 1))
    # by name, the default port
    app.inputs = ['echo.test']
    command(app, 'CONNECT')
    check('looking up', (app.line(TOP_Y)[:19], app.log[-1]),
          ('LOOKING UP THE NAME', ('lookup', b'echo.test\0')))
    app.frames(3)
    check('then connecting', app.log[-1], ('connect', IP, 23))
    app.frames(4)
    check('connected by name', app.line(TOP_Y)[:9], 'CONNECTED')
    command(app, 'CLOSE')
    check('CLOSE', (app.line(TOP_Y)[:13], app.log[-1]), ('NOT CONNECTED', ('close', 2)))
    # an address that answers nothing
    app.inputs = ['10.1.2.3:80']
    command(app, 'CONNECT')
    check('C_NETCONNECT to 10.1.2.3', app.log[-1], ('connect', bytes([3, 2, 1, 10]), 80))
    app.frames(4)
    check('no connection', app.line(TOP_Y)[:13], 'NO CONNECTION')
    # no M4 board
    app3 = Telnet(prog, sym, board=False)
    app3.call('INIT', a=0)
    app3.inputs = ['127.0.0.1']
    command(app3, 'CONNECT')
    check('no M4 board', app3.line(TOP_Y)[:11], 'NO M4 BOARD')
    if app.errors or app2.errors or app3.errors:
        sys.exit('telnet_check: errors %r' % (app.errors + app2.errors + app3.errors))
    print('telnet_check: by number and by name, the greeting, TTYPE V-OS and options refused once, '
          'a password as *, '
          'ANSI left out, Greek, 30 lines scrolled, a line sent and answered, closed by '
          'the other end, CLOSE, no answer, no board: all right')


if __name__ == '__main__':
    main()
