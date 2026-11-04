#!/usr/bin/env python3
"""Check make test-wm-notepad's screenshots (NOTEPAD in a window;
src/kernel/test_script.asm, 55).

usage: wm_notepad_check.py full resized page back ask

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). NOTES.TXT's lines are 66 characters long. Its window
is 384 x 246 at (0, 12) first: 47 columns, 21 rows, the status under
them; then its corner dragged: about 256 x 170, fewer columns and rows,
the status under the rows still, its numbers at the window's right.
Then CONTROL+M: the page (mode 2) full screen, out of the windows, no
desk; CONTROL+M again: the window back, where and as large as it was.
Then a letter typed and a click on its X: NOTEPAD gets ^Q (BACK) and
asks about the change, in its dialog, before it ends.
Exits 1 on the first difference.
"""
import sys
from PIL import Image

DESK, WHITE, BLACK, SKY = (0, 0, 127), (255, 255, 255), (0, 0, 0), (0, 127, 255)


def load(path):
    return Image.open(path).convert('RGB')


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def area(im, x0, y0, x1, y1):
    return [pixel(im, x, y) for y in range(y0, y1) for x in range(x0, x1)]


def check(shot, what, got, want):
    if got != want:
        sys.exit('wm_notepad_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    names = ('full', 'resized', 'page', 'back', 'ask')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    full, resized, page, back, ask = map(load, sys.argv[1:])

    check('full', "NOTEPAD's title, in front", pixel(full, 200, 15), BLACK)
    check('full', 'the 47th column', WHITE in area(full, 360, 25, 376, 35), True)
    check('full', 'the 21st row', WHITE in area(full, 8, 226, 200, 234), True)
    check('full', 'the status under it: the name', SKY in area(full, 4, 238, 90, 246), True)
    check('full', 'the column number', WHITE in area(full, 360, 238, 376, 246), True)

    check('resized', "NOTEPAD's title, in front", pixel(resized, 100, 15), BLACK)
    check('resized', 'the desk at its right', set(area(resized, 262, 25, 320, 35)), {DESK})
    check('resized', 'the desk under it', pixel(resized, 100, 220), DESK)
    check('resized', 'its 13th row', WHITE in area(resized, 8, 146, 200, 154), True)
    check('resized', 'the status under it', SKY in area(resized, 4, 158, 40, 166), True)
    check('resized', 'the column number, inside', WHITE in area(resized, 230, 158, 252, 166), True)

    check('page', 'no desk (mode 2, full screen)',
          DESK in [page.getpixel((x, y))[:3] for y in range(40, 500, 20) for x in range(0, 768, 8)], False)
    check('page', 'the text', WHITE in area(page, 0, 20, 384, 200), True)

    check('back', 'the window again, where and as large as it was',
          area(back, 0, 12, 384, 200), area(resized, 0, 12, 384, 200))
    check('ask', "NOTEPAD's title, still in front", pixel(ask, 100, 15), BLACK)
    check('ask', 'its dialog over it', area(ask, 104, 104, 260, 165) != area(back, 104, 104, 260, 165), True)
    check('ask', 'the dialog white', WHITE in area(ask, 110, 110, 250, 125), True)
    print('wm_notepad_check: NOTEPAD in a window, 47 columns and 21 rows; made smaller: '
          'fewer columns and rows, the status under them; the page full screen, then the window back; X: NOTEPAD asks first: all right')


if __name__ == '__main__':
    main()
