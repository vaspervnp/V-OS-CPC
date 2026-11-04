#!/usr/bin/env python3
"""Check PAINT's UNDO (make test-paint-undo).

usage: paint_check.py paint.bin paint.sym

Runs PAINT (assembled at #4000, with its symbols) in a Z80 emulator (the
z80 package) with the V-OS calls stubbed: a 16K data bank for
VOS_BANK_GET and VOS_BANK_PUT, VX_DATA saying whether it is PAINT's own
(the whole screen) or not (a picture of 128 x 128 in PAINT's memory).
BOX, LINE and PENCIL draw with the pointer; then UNDO must give the
picture as it was before the last tool, UNDO again as it was after it,
and on the whole screen in a window scrolled away too. FILL must be
taken back on a small picture; on the whole screen it leaves nothing
to undo. Exits 1 on the first difference.
"""
import os
import sys

API = 0x0108
CALLS = 43
BANK_GET, BANK_PUT, EXT = 37, 38, 42
VX_DATA = 7
VE_KEY_DOWN, VE_PTR_DOWN, VE_PTR_UP = 1, 5, 6
VK_TAB = 68
CMD_UNDO = 32 + 11
CY = 16                         # the window on the screen (paint.asm)


class Paint:
    def __init__(self, prog, sym, big):
        import z80
        self.sym, self.big = sym, big
        self.m = z80.Z80Machine()
        mem = bytearray(65536)
        mem[0x4000:0x4000 + len(prog)] = prog
        for i in range(CALLS):
            mem[API + i * 3] = 0xAF              # xor a: A = 0, Z
            mem[API + i * 3 + 1] = 0xC9          # ret
        mem[0x0100:0x0102] = b'\x18\xfe'
        self.m.set_memory_block(0, bytes(mem))
        for i in range(CALLS):
            self.m.set_breakpoint(API + i * 3)
        self.m.set_breakpoint(0x0100)
        self.bank = bytearray(0x4000)

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
            if n == BANK_GET:
                assert 0x4000 <= m.hl and m.hl + m.bc <= 0x8000, 'BANK_GET %x %x' % (m.hl, m.bc)
                m.set_memory_block(m.de, bytes(self.bank[m.hl - 0x4000:m.hl - 0x4000 + m.bc]))
            elif n == BANK_PUT:
                assert 0x4000 <= m.de and m.de + m.bc <= 0x8000, 'BANK_PUT %x %x' % (m.de, m.bc)
                self.bank[m.de - 0x4000:m.de - 0x4000 + m.bc] = m.memory[m.hl:m.hl + m.bc]
            elif n == EXT and m.a == VX_DATA:
                m.a = self.big
                m.f &= ~1
            else:
                m.a = 0
                m.f = (m.f | 0x40) & ~1           # Z, no carry
            m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
            m.sp += 2
        sys.exit('paint_check: %s did not return' % name)

    def event(self, kind, code=0, char=0, x=0, y=0):
        self.m.set_memory_block(0xBF00, bytes([kind, code, char, 0, x & 255, x >> 8,
                                               y & 255, y >> 8]))
        self.call('EVENT', hl=0xBF00)

    def tool(self, letter):
        self.event(VE_KEY_DOWN, 63, ord(letter))

    def drag(self, x0, y0, x1, y1):
        """the button down at x0, y0 of the window, up at x1, y1"""
        self.event(VE_PTR_DOWN, x=x0, y=CY + y0)
        self.event(VE_PTR_UP, x=x1, y=CY + y1)

    def picture(self):
        """the picture, with the row PAINT has in rbuf, if it changed"""
        mem, sym = self.m.memory, self.sym
        if self.big:
            pic = bytearray(self.bank)
        else:
            pic = bytearray(mem[sym['CANVAS']:sym['CANVAS'] + 8192])
        y = mem[sym['RC_Y']]
        if mem[sym['RC_DIRTY']] and y != 0xFF:
            if self.big:
                at, n = (y & 7) * 0x800 + (y >> 3) * 80, 80
            else:
                at, n = y * 64, 64
            pic[at:at + n] = mem[sym['RBUF']:sym['RBUF'] + n]
        return bytes(pic)


def check(what, got, want):
    if got != want:
        sys.exit('paint_check: %s' % what)


def run(prog, sym, big):
    p = Paint(prog, sym, big)
    p.call('INIT', a=0)
    white = p.picture()
    p.event(VE_KEY_DOWN, VK_TAB)                 # a colour: blue, not
    p.event(VE_KEY_DOWN, VK_TAB)                 # the white of the paper
    p.tool('x')                                  # BOX
    p.drag(10, 10, 40, 30)
    box = p.picture()
    check('BOX drew nothing', box != white, True)
    p.tool('l')                                  # LINE
    p.drag(5, 60, 100, 70)
    line = p.picture()
    check('LINE drew nothing', line != box, True)
    p.call('COMMAND', a=CMD_UNDO)
    check('UNDO: the LINE taken back', p.picture(), box)
    p.call('COMMAND', a=CMD_UNDO)
    check('UNDO again: the LINE again', p.picture(), line)
    p.tool('p')                                  # PENCIL: a dot
    p.drag(70, 20, 70, 20)
    dot = p.picture()
    check('PENCIL drew nothing', dot != line, True)
    p.call('COMMAND', a=CMD_UNDO)
    check('UNDO: the dot taken back', p.picture(), line)
    p.call('COMMAND', a=CMD_UNDO)
    if big:                                      # scrolled away, then UNDO
        p.m.set_memory_block(sym['VX'], bytes([32, 72]))
        p.call('COMMAND', a=CMD_UNDO)
        check('UNDO, scrolled: the dot taken back', p.picture(), line)
        p.call('COMMAND', a=CMD_UNDO)
        p.m.set_memory_block(sym['VX'], bytes([0, 0]))
    check('the dot again', p.picture(), dot)
    p.tool('f')                                  # FILL the white around
    p.event(VE_PTR_DOWN, x=120, y=CY + 120)
    filled = p.picture()
    check('FILL filled nothing', filled != dot, True)
    p.call('COMMAND', a=CMD_UNDO)
    if big:
        check('FILL on the whole screen: nothing to undo', p.picture(), filled)
    else:
        check('UNDO: the FILL taken back', p.picture(), dot)
    print('paint_check: %s: BOX, LINE, PENCIL%s and FILL, UNDO and UNDO again: all right'
          % ('the whole screen' if big else 'a picture', ', scrolled away,' if big else ''))


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    run(prog, sym, 0)
    run(prog, sym, 1)


if __name__ == '__main__':
    main()
