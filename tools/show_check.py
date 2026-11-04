#!/usr/bin/env python3
"""Check SHOW (make test-show).

usage: show_check.py show.bin show.sym

Runs SHOW (myapps/show, assembled at #4000, with its symbols) in a Z80
emulator (the z80 package) with the V-OS calls stubbed: VOS_CATALOG
lists the .SCR files of a drive, VOS_LOAD puts one into a 16K data bank,
VOS_BLIT and VOS_PALETTE are recorded. Each picture must be drawn row
by row as the .SCR has it, with its inks when it has PAINT's at #07D0;
RIGHT, LEFT and the frames must go through them, SPACE stop them; a
drive without any must say so. Exits 1 on the first difference.
"""
import sys

API = 0x0108
CALLS = 43
(PALETTE, PRINT, MSG, CATALOG, LOAD, BLIT, BANK_GET, EXT) = 7, 12, 14, 24, 25, 32, 37, 42
VE_KEY_DOWN, VE_FRAME = 1, 8
VK_RIGHT, VK_LEFT, VK_SPACE = 1, 8, 47
CAT = 0x9100


def scr(seed, inks):
    data = bytearray((seed * 7 + i * 13) & 255 for i in range(0x4000))
    if inks:
        data[0x7D0:0x7D0 + 17] = bytes(inks)
    else:
        data[0x7D0:0x7D0 + 17] = bytes([0xFF] * 17)
    return bytes(data)


class Show:
    def __init__(self, prog, sym, files):
        import z80
        self.sym = sym
        self.m = z80.Z80Machine()
        mem = bytearray(65536)
        mem[0x4000:0x4000 + len(prog)] = prog
        for i in range(CALLS):
            mem[API + i * 3] = 0xAF              # xor a: A = 0, Z
            mem[API + i * 3 + 1] = 0xC9          # ret
        mem[0x0100:0x0102] = b'\x18\xfe'
        mem[0x9000] = 0
        self.m.set_memory_block(0, bytes(mem))
        for i in range(CALLS):
            self.m.set_breakpoint(API + i * 3)
        self.m.set_breakpoint(0x0100)
        self.files = files                       # (drive, name) -> data
        self.bank = bytearray(0x4000)
        self.rows = {}
        self.palette = None
        self.printed = []

    def call(self, name, a=0, hl=0):
        m = self.m
        m.set_memory_block(0xBEFE, bytes([0x00, 0x01]))
        m.sp, m.pc, m.a, m.hl = 0xBEFE, self.sym[name], a, hl
        for _ in range(400000):
            m.ticks_to_stop = 5000000
            m.run()
            if m.pc == 0x0100:
                return
            if not API <= m.pc < API + CALLS * 3:
                continue
            n = (m.pc - API) // 3
            m.f &= ~1
            if n == CATALOG:
                names = sorted(k[1] for k in self.files if k[0] == m.a & 3)
                m.set_memory_block(CAT, b''.join(nm + bytes(5) for nm in names) or b'\0')
                m.a, m.hl = len(names), CAT
            elif n == LOAD:
                data = self.files[(m.a & 3, bytes(m.memory[m.hl:m.hl + 11]))]
                self.bank[:len(data)] = data
                m.bc = len(data)
            elif n == BANK_GET:
                m.set_memory_block(m.de, bytes(self.bank[m.hl - 0x4000:m.hl - 0x4000 + m.bc]))
            elif n == BLIT:
                b = m.memory[m.ix:m.ix + 9]
                x, y, w, h = b[0] | b[1] << 8, b[2] | b[3] << 8, b[4], b[5]
                src = b[6] | b[7] << 8
                pairs = bytes(m.memory[src:src + 2 * w])
                assert (x, w, h) == (16, 80, 1) and pairs[0::2] == b'\xff' * 80
                self.rows[y] = pairs[1::2]
            elif n == PALETTE:
                self.palette = bytes(m.memory[m.hl:m.hl + 17])
            elif n == PRINT:
                s, a = b'', m.bc
                while m.memory[a]:
                    s += bytes([m.memory[a]])
                    a += 1
                self.printed.append(s.decode('latin-1'))
            elif n == MSG:
                m.hl = 0x9000
            else:
                m.a = 0
            m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
            m.sp += 2
        sys.exit('show_check: %s did not return' % name)

    def key(self, k):
        self.m.set_memory_block(0xBF00, bytes([VE_KEY_DOWN, k, 0, 0]))
        self.call('EVENT', hl=0xBF00)

    def frame(self):
        self.m.set_memory_block(0xBF00, bytes([VE_FRAME, 0, 0, 0]))
        self.call('EVENT', hl=0xBF00)

    def shown(self, data):
        """the rows drawn are the picture's (from y 30)"""
        for y in range(200):
            at = (y & 7) * 0x800 + (y >> 3) * 80
            if self.rows.get(30 + y) != data[at:at + 80]:
                return False
        return True


def check(what, got, want):
    if got != want:
        sys.exit('show_check: %s: got %r, want %r' % (what, got, want))


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    inks = [0, 26, 2, 6, 18, 24, 20, 8, 15, 13, 3, 9, 1, 12, 17, 11, 5]
    a, b = scr(1, inks), scr(2, None)
    files = {(1, b'NIGHT   SCR'): a, (1, b'SUNSET  SCR'): b}
    s = Show(prog, sym, files)
    s.m.set_memory_block(0x8800, b'\x01')        # VOS_SELF: started from B:
    s.call('INIT', a=0)
    check('the first picture', s.shown(a), True)
    check('its inks', s.palette, bytes(inks))
    check('its name', s.printed[-1], 'B:NIGHT.SCR  1/2')
    s.key(VK_RIGHT)
    check('RIGHT: the second', (s.shown(b), s.printed[-1]), (True, 'B:SUNSET.SCR  2/2'))
    s.key(VK_LEFT)
    check('LEFT: the first again', s.shown(a), True)
    s.key(VK_LEFT)
    check('LEFT past the first: the last', s.printed[-1], 'B:SUNSET.SCR  2/2')
    for _ in range(250):
        s.frame()
    check('5 seconds on: the next', s.printed[-1], 'B:NIGHT.SCR  1/2')
    s.key(VK_SPACE)
    for _ in range(300):
        s.frame()
    check('stopped', s.printed[-1], 'B:NIGHT.SCR  1/2')
    s = Show(prog, sym, {})
    s.call('INIT', a=0)
    check('no pictures: nothing drawn', s.rows, {})
    print('show_check: two pictures drawn row by row with their inks, RIGHT, LEFT, '
          'every 5 seconds, SPACE stops; none: said: all right')


if __name__ == '__main__':
    main()
