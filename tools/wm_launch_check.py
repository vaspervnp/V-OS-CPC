#!/usr/bin/env python3
"""Check make test-wm-launch's screenshots (NOTEPAD from the Launcher in
a window; src/kernel/test_script.asm, 64).

usage: wm_launch_check.py window typed

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). NOTEPAD's window is 376 x 232 at the top left, its X at (378, 16), its
inside black, the status at its bottom; from the Launcher
(mode 0) it was cut to 160 pixels. Exits 1 on the first difference.
"""
import sys
from PIL import Image

WHITE, BLACK = (255, 255, 255), (0, 0, 0)


def load(path):
    return Image.open(path).convert('RGB')


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def area(im, x0, y0, x1, y1):
    return [pixel(im, x, y) for y in range(y0, y1) for x in range(x0, x1)]


def check(shot, what, got, want):
    if got != want:
        sys.exit('wm_launch_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    window, typed = map(load, sys.argv[1:])
    check('window', 'its X, at the right of the screen', (pixel(window, 378, 16), pixel(window, 372, 16)), (WHITE, BLACK))
    check('window', "NOTEPAD's title, in front", pixel(window, 18, 15), BLACK)
    check('window', 'its inside, past mode 0\'s 160 pixels', area(window, 200, 60, 300, 200).count(BLACK), 100 * 140)
    check('window', 'its status (LINE, COL), past 192 pixels', WHITE in area(window, 180, 236, 330, 246), True)
    check('typed', 'the letters typed', WHITE in area(typed, 8, 22, 40, 40), True)
    check('typed', 'still a window: its inside', pixel(typed, 250, 150), BLACK)
    print('wm_launch_check: NOTEPAD from the Launcher in a window of its size, typed into: all right')


if __name__ == '__main__':
    main()
