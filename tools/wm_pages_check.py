#!/usr/bin/env python3
"""Check make test-wm-pages's screenshots (MARKDOWN, READER and SHEET in
windows; src/kernel/test_script.asm, 56).

usage: wm_pages_check.py markdown preview reader sheet sheet_page sheet_back

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). Each window is 384 x 246 at (0, 12) and shows its
program's screen from (0, 12) (API 36): 47 columns, the status under
the rows. INDEX.MD's paragraph is longer than a line: MARKDOWN cuts it
at the window's edge, its preview and READER wrap it there. SHEET shows
4 of its columns (A-D) and 18 rows; then (CONTROL+M) its page, mode 2,
full screen, out of the windows, and its window again. Exits 1 on the first difference.
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
        sys.exit('wm_pages_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    names = ('markdown', 'preview', 'reader', 'sheet', 'sheet_page', 'sheet_back')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    shots = dict(zip(names, map(load, sys.argv[1:])))
    for name, im in shots.items():
        if name == 'sheet_page':
            continue
        check(name, 'the title, in front', pixel(im, 200, 15), BLACK)
        check(name, 'the desk under the window', pixel(im, 200, 262), DESK)

    im = shots['markdown']
    check('markdown', '# WINDOWS', WHITE in area(im, 0, 22, 80, 30), True)
    check('markdown', 'the paragraph, to the 47th column', WHITE in area(im, 360, 42, 376, 50), True)
    check('markdown', 'the status under 21 rows', SKY in area(im, 4, 238, 90, 246), True)
    check('markdown', 'the column number, inside', WHITE in area(im, 360, 238, 376, 246), True)

    im = shots['preview']
    check('preview', 'PREVIEW, under the rows', WHITE in area(im, 4, 238, 70, 246), True)
    check('preview', 'the paragraph wrapped', WHITE in area(im, 0, 52, 200, 60), True)
    check('preview', 'the page, not the text', area(im, 0, 42, 384, 50) != area(shots['markdown'], 0, 42, 384, 50), True)

    im = shots['reader']
    check('reader', 'the place, under the rows', SKY in area(im, 4, 238, 90, 246), True)
    check('reader', 'the paragraph wrapped', WHITE in area(im, 0, 52, 200, 60), True)

    im = shots['sheet']
    check('sheet', 'column D', SKY in area(im, 268, 40, 282, 48), True)
    check('sheet', 'no column E', SKY in area(im, 340, 40, 380, 48), False)
    check('sheet', 'row 18', SKY in area(im, 0, 222, 20, 230), True)
    check('sheet', 'no row 19', SKY in area(im, 0, 231, 20, 236), False)

    im = shots['sheet_page']
    check('sheet_page', 'no desk (mode 2, full screen)',
          DESK in [im.getpixel((x, y))[:3] for y in range(40, 500, 20) for x in range(0, 768, 8)], False)
    check('sheet_back', 'the window again: its columns',
          area(shots['sheet_back'], 0, 30, 384, 48), area(shots['sheet'], 0, 30, 384, 48))
    print('wm_pages_check: MARKDOWN, its preview, READER and SHEET in windows, laid out '
          'for their size; SHEET\'s page full screen and back: all right')


if __name__ == '__main__':
    main()
