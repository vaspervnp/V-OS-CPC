#!/usr/bin/env python3
"""The M4 board's network in Python, for the checkers of programs that
use src/api/vos_net.inc (tools/mail_check.py, tools/ftp_check.py).

Net is mixed into a database_check.App: its m4_call answers VX_M4 as
the ROM does (C_NETHOSTIP, C_NETSOCKET, C_NETCONNECT, C_NETSEND,
C_NETRECV, C_NETCLOSE, and sock_info for HL = 0), a few frames late as
the board is, and frame() moves the board on a frame and gives the
program its VE_FRAME. The servers are Python objects found by the
address connected to (self.servers: (ip, port) -> a Server, or a
function that makes one); a name looked up is in self.names. The ip is
as C_NETCONNECT has it, the last part first.
"""

VE_FRAME = 8
C_SOCKET, C_CONNECT, C_CLOSE, C_SEND, C_RECV, C_HOSTIP = (
    0x4331, 0x4332, 0x4333, 0x4334, 0x4335, 0x4336)


def ip(text):
    """'127.0.0.1' -> the 4 bytes of C_NETCONNECT"""
    return bytes(int(p) for p in text.split('.'))[::-1]


class Server:
    """the other end of a connection: what it sends waits in inbox"""
    def __init__(self):
        self.inbox, self.sent, self.closing, self.ended = b'', b'', False, False
        self.net = None

    def connected(self):
        pass

    def got(self, data):
        self.sent += data

    def closed(self):
        self.ended = True


class LineServer(Server):
    """a server of lines: line() for each one sent, say() to answer"""
    def __init__(self):
        super().__init__()
        self.part = b''
        self.lines = []

    def got(self, data):
        super().got(data)
        self.part += data
        while b'\r\n' in self.part:
            one, self.part = self.part.split(b'\r\n', 1)
            self.lines.append(one)
            self.line(one)

    def say(self, text):
        self.inbox += (text.encode('latin-1') if isinstance(text, str) else text) + b'\r\n'

    def line(self, one):
        pass


class Sock:
    def __init__(self):
        self.status, self.wait, self.server, self.addr = 0, 0, None, None


class Net:
    def net_init(self, board=True):
        self.board = board
        self.socks = {}
        self.lookup, self.looked = 0, None
        self.names = {}
        self.servers = {}
        self.log = []
        self.quiet = False                  # behind, covered: VOS_EXT quiet

    def info(self):
        out = bytearray(5 * 16)
        if self.lookup:
            out[0] = 5
        elif self.looked:
            out[4:8] = self.looked
        for n, s in self.socks.items():
            st = s.status
            inbox = s.server.inbox if s.server and not s.wait else b''
            if st == 0 and s.server and s.server.closing and not inbox:
                st = 3
            out[n * 16] = st
            out[n * 16 + 2:n * 16 + 4] = min(len(inbox), 65535).to_bytes(2, 'little')
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
        if cmd == C_HOSTIP:
            name = data.rstrip(b'\0')
            self.log.append(('lookup', name))
            if name in self.names:
                self.lookup, self.looked = 2, self.names[name]
                out = b'\x01'
            else:
                out = b'\x00'
        elif cmd == C_SOCKET:
            assert data == b'\x00\x00\x06', data
            n = next(i for i in range(1, 5) if i not in self.socks)
            self.socks[n] = Sock()
            out = bytes([n])
        elif cmd == C_CONNECT:
            port = data[5] | data[6] << 8
            self.log.append(('connect', data[0], data[1:5], port))
            s = self.socks[data[0]]
            s.addr, s.wait = (data[1:5], port), 3
            s.status = 1
            made = self.servers.get(s.addr)
            s.server = made() if callable(made) else made
            out = b'\x00'
        elif cmd == C_SEND:
            n = data[1] | data[2] << 8
            assert len(data) - 3 == n, (len(data), n)
            s = self.socks[data[0]]
            assert s.status == 0 and s.server, 'C_NETSEND before connected'
            s.server.got(data[3:])
            out = b'\x00'
        elif cmd == C_RECV:
            s = self.socks[data[0]]
            n = min(data[1] | data[2] << 8, len(s.server.inbox))
            got, s.server.inbox = s.server.inbox[:n], s.server.inbox[n:]
            out = b'\x00' + n.to_bytes(2, 'little') + got
        elif cmd == C_CLOSE:
            self.log.append(('close', data[0]))
            s = self.socks.pop(data[0])
            if s.server:
                s.server.closed()
            out = b'\x00'
        rsp = bytes([2 + len(out)]) + bytes([cmd & 255, cmd >> 8]) + out
        m.set_memory_block(m.de, rsp[:m.bc])

    def frame(self):
        """a frame: the board goes on, then the program's VE_FRAME"""
        if self.lookup:
            self.lookup -= 1
        for s in self.socks.values():
            if s.wait:
                s.wait -= 1
                if not s.wait:
                    if s.server is None:
                        s.status = 241
                    else:
                        s.status = 0
                        s.server.net = self
                        s.server.connected()
        self.m.set_memory_block(0xBF00, bytes([VE_FRAME, 0, 0, 0]))
        self.call('EVENT', hl=0xBF00)

    def frames(self, n):
        for _ in range(n):
            self.frame()
