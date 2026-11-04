#!/usr/bin/env python3
"""Check CLOCK's time from the M4 board (make test-clock).

usage: clock_check.py clock.bin clock.sym

Runs CLOCK (apps/clock, assembled at #4000, with its symbols) in a Z80
emulator (the z80 package) with the V-OS calls stubbed: VOS_FRAMES is a
counter set here, VOS_PRINT writes into a screen of text, and VX_M4
answers C_TIME with a time and a date, or carry (no M4 board). With
the M4 the program must show its time and date and count on from them,
ask again when the day ends (the next date); without, the time since
V-OS started. Exits 1 on the first difference.
"""
import sys

API = 0x0108
CALLS = 43
FRAMES, PRINT, MSG, EXT = 2, 12, 14, 42
VX_M4 = 4
VX_WINDOW = 16                                  # no windows here: carry
C_TIME = 0x4324
VE_FRAME = 8


class Clock:
    def __init__(self, prog, sym, answers):
        import z80
        self.sym = sym
        self.m = z80.Z80Machine()
        mem = bytearray(65536)
        mem[0x4000:0x4000 + len(prog)] = prog
        for i in range(CALLS):
            mem[API + i * 3] = 0xAF              # xor a: A = 0, Z
            mem[API + i * 3 + 1] = 0xC9          # ret
        mem[0x0100:0x0102] = b'\x18\xfe'
        mem[0x9000] = 0                          # VOS_MSG: an empty text
        self.m.set_memory_block(0, bytes(mem))
        for i in range(CALLS):
            self.m.set_breakpoint(API + i * 3)
        self.m.set_breakpoint(0x0100)
        self.frames = 0
        self.answers = answers                   # C_TIME's, in turn (None: no M4)
        self.screen = {}

    def call(self, name, a=0, hl=0):
        m = self.m
        m.set_memory_block(0xBEFE, bytes([0x00, 0x01]))
        m.sp, m.pc, m.a, m.hl = 0xBEFE, self.sym[name], a, hl
        for _ in range(100000):
            m.ticks_to_stop = 5000000
            m.run()
            if m.pc == 0x0100:
                return
            if not API <= m.pc < API + CALLS * 3:
                continue
            n = (m.pc - API) // 3
            m.f &= ~1
            if n == FRAMES:
                m.hl, m.a = self.frames & 0xFFFF, self.frames >> 16
            elif n == PRINT:
                s, a = b'', m.bc
                while m.memory[a]:
                    s += bytes([m.memory[a]])
                    a += 1
                self.screen[m.de] = s.decode('latin-1')
            elif n == MSG:
                m.hl = 0x9000
            elif n == EXT and m.a == VX_WINDOW:
                m.f |= 1
            elif n == EXT and m.a == VX_M4:
                cmd = m.memory[m.hl + 1] | m.memory[m.hl + 2] << 8
                assert cmd == C_TIME, hex(cmd)
                ans = self.answers.pop(0)
                if ans is None:
                    m.f |= 1
                else:
                    data = ans.encode() + b'\0'
                    resp = bytes([2 + len(data)]) + C_TIME.to_bytes(2, 'little') + data
                    m.set_memory_block(m.de, resp[:m.bc])
            else:
                m.a = 0
            m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
            m.sp += 2
        sys.exit('clock_check: %s did not return' % name)

    def tick(self, frames):
        self.frames += frames
        self.m.set_memory_block(0xBF00, bytes([VE_FRAME, 0, 0, 0]))
        self.call('EVENT', hl=0xBF00)


def check(what, got, want):
    if got != want:
        sys.exit('clock_check: %s: got %r, want %r' % (what, got, want))


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    TIME_Y = 120
    c = Clock(prog, sym, ['23:58:50 2026-11-03', '00:00:01 2026-11-04'])
    c.frames = 123456                            # V-OS has run a while
    c.call('INIT', a=0)
    check('the M4\'s time', c.screen.get(TIME_Y), '23:58:50')
    check('its date', c.screen.get(TIME_Y - 20), '2026-11-03')
    c.tick(50 * 65)
    check('65 seconds on', c.screen.get(TIME_Y), '23:59:55')
    c.tick(50 * 6)                               # past midnight: asked again
    check('the next day', (c.screen.get(TIME_Y), c.screen.get(TIME_Y - 20)),
          ('00:00:01', '2026-11-04'))
    c.tick(50 * 3600)
    check('an hour on', c.screen.get(TIME_Y), '01:00:01')
    c = Clock(prog, sym, [None])                 # no M4 board
    c.frames = 50 * 3725
    c.call('INIT', a=0)
    check('without an M4: since V-OS started', c.screen.get(TIME_Y), '01:02:05')
    print('clock_check: the M4\'s time and date, counted on, the next day asked again; '
          'without an M4 the time since V-OS started: all right')


if __name__ == '__main__':
    main()
