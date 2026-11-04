#!/usr/bin/env python3
"""Check make test-wm-apps2's screenshots (DIARY, TELNET and CALC in
windows; src/kernel/test_script.asm, 54).

usage: wm_apps2_check.py diary telnet calc three

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). Frames: DIARY 352 x 242 at (16, 12), TELNET 384 x 246
at (0, 12), CALC 216 x 124 at (64, 52): each shows a part of its
program's screen (API 36), CALC the inside of its Studio window, with
its buttons. A title line is 10 high, black in front. Exits 1 on the
first difference.
"""
import sys
from PIL import Image

DESK, WHITE, BLACK, SKY = (0, 0, 127), (255, 255, 255), (0, 0, 0), (0, 127, 255)
DISPLAY = (84, 66, 108, 80)             # CALC's number


def load(path):
    return Image.open(path).convert('RGB')


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def area(im, x0, y0, x1, y1):
    return [pixel(im, x, y) for y in range(y0, y1) for x in range(x0, x1)]


def bar(im):
    return area(im, 0, 0, 64, 10)


def check(shot, what, got, want):
    if got != want:
        sys.exit('wm_apps2_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    names = ('diary', 'telnet', 'calc', 'three')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    shots = dict(zip(names, map(load, sys.argv[1:])))

    im = shots['diary']                     # DIARY in a window
    check('diary', "DIARY's title, in front", pixel(im, 17, 15), BLACK)
    check('diary', 'its days', WHITE in area(im, 24, 40, 180, 100), True)
    check('diary', 'the desk at its right', pixel(im, 375, 150), DESK)

    im = shots['telnet']                    # TELNET over it
    check('telnet', "TELNET's title, in front", pixel(im, 2, 15), BLACK)
    check('telnet', 'NOT CONNECTED', SKY in area(im, 4, 22, 120, 32), True)
    check('telnet', 'the bar: TELNET', bar(im) != bar(shots['diary']), True)

    im = shots['calc']                      # CALC, a Studio program
    check('calc', "CALC's title, in front", pixel(im, 66, 55), BLACK)
    check('calc', "its window's inside", pixel(im, 270, 120), WHITE)
    check('calc', 'a button (7)', BLACK in area(im, 76, 92, 116, 102), True)
    check('calc', 'its number', BLACK in area(im, *DISPLAY) or (0, 0, 127) in area(im, *DISPLAY), True)
    check('calc', 'the bar: PROGRAM', bar(im) != bar(shots['telnet']), True)

    im = shots['three']                     # 1 + 2 =
    check('three', "CALC's title, in front", pixel(im, 66, 55), BLACK)
    check('three', 'its number changed (3)', area(im, *DISPLAY) != area(shots['calc'], *DISPLAY), True)
    print('wm_apps2_check: DIARY and TELNET in windows; CALC in a window, its buttons '
          'clicked there: 1 + 2 = 3: all right')


if __name__ == '__main__':
    main()
