#!/usr/bin/env python3
"""Check PAINT's EXPORT .SCR in BASIC (make test-scr).

usage: scr_check.py make paint.bin paint.sym out.scr
       scr_check.py check screenshot.png

make:  runs PAINT's own export code (paint.bin, assembled at #4000 with
       its symbols) in a Z80 emulator (the z80 package, pip install z80),
       with a test picture on the canvas and the V-OS calls stubbed.
       VOS_BANK_PUT writes into a 16K bank, VOS_SAVE is checked (the drive
       with VOS_LOAD_IX, 16K from #4000, IX = #C000), and the bank is
       written as out.scr.
check: the screenshot of Caprice32 after BASIC has loaded the file and
       set the inks from #C7D0: every pixel of the picture must show the
       colour of its pen in PAINT's palette, and the rest of the screen
       pen 0. Exits 1 if not.
"""
import sys

API = 0x0108                  # the V-OS call table, 3 bytes a call
CALLS = 43
BANK_PUT, SAVE = 38, 26       # their numbers in src/api/vos_api.inc
SCR_X, SCR_Y, SIZE = 16, 36, 128   # where the picture goes (mode 0 pixels)


def pen(x, y):
    """The test picture: diagonal bands of all 16 pens."""
    return (x // 8 + y // 16) % 16


def mode0_byte(left, right):
    b = 0
    for bit, (l, r) in enumerate(((7, 6), (3, 2), (5, 4), (1, 0))):
        b |= ((left >> bit) & 1) << l | ((right >> bit) & 1) << r
    return b


def make(binfile, symfile, out):
    import z80
    prog = open(binfile, 'rb').read()
    sym = {}
    for line in open(symfile):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0]] = int(p[1][1:], 16)
    mem = bytearray(65536)
    mem[0x4000:0x4000 + len(prog)] = prog
    for i in range(CALLS):
        mem[API + i * 3] = 0xC9
    canvas = bytearray(mode0_byte(pen(2 * x, y), pen(2 * x + 1, y))
                       for y in range(SIZE) for x in range(SIZE // 2))
    mem[sym['CANVAS']:sym['CANVAS'] + len(canvas)] = canvas
    mem[sym['LMODE']] = 0                    # no layers
    mem[0x0100] = 0x76                       # export returns here
    m = z80.Z80Machine()
    m.set_memory_block(0, bytes(mem))
    for i in range(CALLS):
        m.set_breakpoint(API + i * 3)
    m.set_breakpoint(0x0100)
    m.set_memory_block(0xBEFE, bytes([0x00, 0x01]))
    m.sp, m.pc = 0xBEFE, sym['EXPORT']
    bank, saves = bytearray(0x4000), []
    for _ in range(100000):
        m.ticks_to_stop = 5000000
        m.run()
        if m.pc in (0x0100, 0x0101):
            break
        if not API <= m.pc < API + CALLS * 3:
            continue
        n = (m.pc - API) // 3
        if n == BANK_PUT:
            bank[m.de - 0x4000:m.de - 0x4000 + m.bc] = m.memory[m.hl:m.hl + m.bc]
        elif n == SAVE:
            saves.append((m.a, bytes(m.memory[m.hl:m.hl + 11]), m.de, m.bc, m.ix))
            m.f &= ~1                        # no error
        m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
        m.sp += 2
    else:
        sys.exit('scr_check: the export did not return')
    if len(saves) != 1 or saves[0][0] & 0x40 == 0 or saves[0][2:] != (0x4000, 0x4000, 0xC000):
        sys.exit('scr_check: VOS_SAVE called wrongly: %r' % saves)
    open(out, 'wb').write(bank)
    print('scr_check: %s, saved as %s' % (out, saves[0][1].decode()))


# firmware colour -> (red, green, blue) levels 0..2
def levels(n):
    return ((n // 3) % 3, n // 9, n % 3)


def palette():
    """PAINT's palette, from its source."""
    import re
    src = open('myapps/paint/paint.asm').read()
    m = re.search(r'^palette:\s+db ([^\n]+)\n\s+db (\d+)', src, re.M)
    return [int(v) for v in m.group(1).split(',')] + [int(m.group(2))]


def check(png):
    from PIL import Image
    img = Image.open(png).convert('RGB')
    w, h = img.size
    pal = palette()

    def level(rgb):
        return tuple(0 if c < 0x40 else 2 if c > 0xC0 else 1 for c in rgb)
    border = level(img.getpixel((2, 2)))
    if border != levels(pal[16]):
        sys.exit('scr_check: the border is %r, not colour %d' % (border, pal[16]))
    # the screen: the box that is not border colour
    xs = [x for x in range(w) if level(img.getpixel((x, h // 2))) != border]
    ys = [y for y in range(h) if level(img.getpixel((w // 2, y))) != border]
    left, top = xs[0], ys[0]
    sx, sy = (xs[-1] - left + 1) / 160, (ys[-1] - top + 1) / 200
    bad = []
    for y in range(200):
        for x in range(160):
            inside = SCR_X <= x < SCR_X + SIZE and SCR_Y <= y < SCR_Y + SIZE
            p = pen(x - SCR_X, y - SCR_Y) if inside else 0
            got = level(img.getpixel((int(left + (x + .5) * sx), int(top + (y + .5) * sy))))
            if got != levels(pal[p]):
                bad.append((x, y, p, got))
    if bad:
        sys.exit('scr_check: %d pixels wrong, the first: %r' % (len(bad), bad[:5]))
    print('scr_check: all 160 x 200 pixels right (screen %d x %d at %d,%d)'
          % (xs[-1] - left + 1, ys[-1] - top + 1, left, top))


if __name__ == '__main__':
    if sys.argv[1:2] == ['make'] and len(sys.argv) == 5:
        make(*sys.argv[2:])
    elif sys.argv[1:2] == ['check'] and len(sys.argv) == 3:
        check(sys.argv[2])
    else:
        sys.exit(__doc__)
