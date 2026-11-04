#!/usr/bin/env python3
"""Check make test-wm-copies's screenshots (windows copied back, not drawn
again; src/kernel/test_script.asm, 57).

usage: wm_copies_check.py three away over back

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). SYSINFO's frame is at (16, 20), WINA's at (40, 36)
(its inside 160 x 80 from (44, 46)), WINB's (136 x 64, pen 3) at
(64, 52) first, then dragged away, over them, and away again. WINA and
WINB write under their names how many times they have drawn their inside
(apps/wint), read here with V-OS's font (src/gfx/font_ascii.asm): 001
in every shot, as each drew once when it started and was copied back
since. The desk under them shows the Desktop's picture (TEST.SCR, white
in its bottom half). Exits 1 on the first difference.
"""
import re
import sys
from PIL import Image

DESK, WHITE, BLACK, SKY = (0, 0, 127), (255, 255, 255), (0, 0, 0), (0, 127, 255)
WINA_COUNT = (52, 86)                   # WINA's inside + (8, 40)


def load(path):
    return Image.open(path).convert('RGB')


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def area(im, x0, y0, x1, y1):
    return [pixel(im, x, y) for y in range(y0, y1) for x in range(x0, x1)]


def font():
    """the glyphs of '0'..'9', from the font's source"""
    rows = re.findall(r'db ((?:#[0-9A-F]{2},?){8})\s*;\s*(\d+)', open('src/gfx/font_ascii.asm').read())
    glyphs = {}
    for data, code in rows:
        if 48 <= int(code) <= 57:
            glyphs[tuple(int(b[1:], 16) for b in data.split(','))] = chr(int(code))
    return glyphs


GLYPHS = font()


def text(im, x, y, n):
    """n characters, white, from (x, y)"""
    out = ''
    for i in range(n):
        cell = tuple(sum((pixel(im, x + 8 * i + c, y + r) == WHITE) << (7 - c) for c in range(8))
                     for r in range(8))
        out += GLYPHS.get(cell, '?')
    return out


def winb(im):
    """WINB's frame's (x, y), from its inside's last line (64 lines high):
    the last with 100 pen 3 pixels in a row (the pointer is on its title)"""
    for y in range(258, 24, -1):
        run = 0
        for x in range(0, 384):
            run = run + 1 if pixel(im, x, y) == SKY else 0
            if run == 100:
                return x - 99 - 4, y - 63 - 10
    sys.exit('wm_copies_check: no WINB')


def check(shot, what, got, want):
    if got != want:
        sys.exit('wm_copies_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    names = ('three', 'away', 'over', 'back')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    shots = dict(zip(names, map(load, sys.argv[1:])))
    places = {}
    for name, im in shots.items():
        x, y = places[name] = winb(im)
        check(name, "WINB's title, in front", pixel(im, x + 2, y + 2), BLACK)
        check(name, "WINB's count", text(im, x + 4 + 8, y + 10 + 40, 3), '001')
        check(name, "SYSINFO's title, behind", pixel(im, 18, 22), WHITE)
    check('three', 'WINB where it started', places['three'], (64, 52))
    for name in ('away', 'back'):
        im = shots[name]
        x, y = places[name]
        check(name, 'WINB away from them', x > 210 or y > 140, True)
        check(name, "WINA's count", text(im, *WINA_COUNT, 3), '001')
        check(name, "WINA's inside where WINB was", pixel(im, 150, 100), BLACK)
        check(name, "the Desktop's picture on the desk", pixel(im, 320, 150), WHITE)
        check(name, 'the desk around it', pixel(im, 300, 25), DESK)
    check('over', 'WINB over WINA', places['over'][0] < 200 and places['over'][1] < 130, True)
    check('back', 'SYSINFO and WINA as they were',
          area(shots['back'], 16, 20, 272, 138), area(shots['away'], 16, 20, 272, 138))
    print('wm_copies_check: WINB moved away from SYSINFO and WINA, over them and away '
          'again; WINA and WINB drew once each (001), copied back since: all right')


if __name__ == '__main__':
    main()
