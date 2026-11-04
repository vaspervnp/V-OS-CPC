#!/usr/bin/env python3
"""Check make test-wm-apps's screenshots (CLOCK, SYSINFO and WINA in
windows; src/kernel/test_script.asm, 53).

usage: wm_apps_check.py three clock_front behind1 behind2 resized

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). Frames: CLOCK 184 x 70 at (16, 20), then moved down
to (16, 179); SYSINFO 256 x 118 at (40, 36); WINA 168 x 94 at (64, 52).
A title line is 10 high, black in front, white behind. Exits 1 on the
first difference.
"""
import sys
from PIL import Image

DESK, WHITE, BLACK = (0, 0, 127), (255, 255, 255), (0, 0, 0)
TIME = (76, 215, 140, 225)              # CLOCK's time, moved: x0, y0, x1, y1


def load(path):
    return Image.open(path).convert('RGB')


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def area(im, x0, y0, x1, y1):
    return [pixel(im, x, y) for y in range(y0, y1) for x in range(x0, x1)]


def check(shot, what, got, want):
    if got != want:
        sys.exit('wm_apps_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    names = ('three', 'clock_front', 'behind1', 'behind2', 'resized')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    shots = dict(zip(names, map(load, sys.argv[1:])))

    im = shots['three']                     # WINA over SYSINFO over CLOCK
    check('three', "WINA's title, in front", pixel(im, 66, 54), BLACK)
    check('three', "SYSINFO's title, behind", pixel(im, 270, 38), WHITE)
    check('three', "CLOCK's title, behind", pixel(im, 18, 22), WHITE)
    check('three', 'the desk', pixel(im, 250, 200), DESK)

    im = shots['clock_front']               # a click: CLOCK in front
    check('clock_front', "CLOCK's title, in front", pixel(im, 18, 22), BLACK)
    check('clock_front', 'its time', WHITE in area(im, 76, 54, 140, 64), True)

    for shot in ('behind1', 'behind2'):     # SYSINFO in front, CLOCK moved
        im = shots[shot]
        check(shot, "SYSINFO's title, in front", pixel(im, 42, 38), BLACK)
        check(shot, "SYSINFO's V-OS VERSION", WHITE in area(im, 48, 66, 140, 74), True)
        check(shot, "CLOCK's title, behind", pixel(im, 18, 181), WHITE)
        check(shot, 'where CLOCK was', pixel(im, 20, 100), DESK)
        check(shot, "CLOCK's time", WHITE in area(im, *TIME), True)
    check('behind2', 'CLOCK ticked behind SYSINFO',
          area(shots['behind1'], *TIME) != area(shots['behind2'], *TIME), True)

    im = shots['resized']                   # SYSINFO's corner dragged
    check('resized', "SYSINFO's title, in front", pixel(im, 42, 38), BLACK)
    check('resized', 'SYSINFO smaller: the desk at its old corner', pixel(im, 290, 150), DESK)
    check('resized', "WINA behind it, drawn again", pixel(im, 230, 140), WHITE)
    check('resized', "CLOCK's time, still there", WHITE in area(im, *TIME), True)
    print('wm_apps_check: three windows; CLOCK in front by a click, moved; SYSINFO in '
          'front and CLOCK ticking behind it; SYSINFO resized: all right')


if __name__ == '__main__':
    main()
