#!/usr/bin/env python3
"""Check make test-wm-net's screenshots (MAIL and FTP in windows;
src/kernel/test_script.asm, 63).

usage: wm_net_check.py mail ftp back commander

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). MAIL's and FTP's frames are at the same place, at the
top of the screen, their X at (378, 16): a title line black in front,
NOT CONNECTED in sky blue under it. Exits 1 on the first difference.
"""
import sys
from PIL import Image

WHITE, BLACK, SKY = (255, 255, 255), (0, 0, 0), (0, 127, 255)


def load(path):
    return Image.open(path).convert('RGB')


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def area(im, x0, y0, x1, y1):
    return [pixel(im, x, y) for y in range(y0, y1) for x in range(x0, x1)]


def bar(im):
    return area(im, 0, 0, 64, 10)


def title(im):
    return area(im, 0, 12, 120, 21)


def check(shot, what, got, want):
    if got != want:
        if isinstance(got, list):           # an area: not all of it
            got, want = 'other pixels', 'the same'
        sys.exit('wm_net_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    names = ('mail', 'ftp', 'back', 'commander')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    shots = dict(zip(names, map(load, sys.argv[1:])))

    im = shots['mail']                      # MAIL in a window
    check('mail', "MAIL's title, in front", pixel(im, 2, 15), BLACK)
    check('mail', 'its X', (pixel(im, 378, 16), pixel(im, 372, 16)), ((255, 255, 255), BLACK))
    check('mail', 'NOT CONNECTED', SKY in area(im, 4, 22, 160, 40), True)

    im = shots['ftp']                       # FTP over it
    check('ftp', "FTP's title, in front", pixel(im, 2, 15), BLACK)
    check('ftp', 'the title: FTP', title(im) != title(shots['mail']), True)
    check('ftp', 'the bar: FTP', bar(im) != bar(shots['mail']), True)
    check('ftp', 'NOT CONNECTED', SKY in area(im, 4, 22, 160, 40), True)

    im = shots['back']                      # FTP's X: MAIL again
    check('back', "MAIL's title, in front", title(im), title(shots['mail']))
    check('back', 'the bar: MAIL', bar(im), bar(shots['mail']))

    im = shots['commander']                 # MAIL's X: no windows
    check('commander', 'the bar: FILE', bar(im) != bar(shots['mail']), True)
    check('commander', 'no NOT CONNECTED', SKY in area(im, 4, 22, 160, 40), False)
    check('commander', 'its files', pixel(im, 300, 100), WHITE)
    print('wm_net_check: MAIL and FTP in windows; FTP ended by its X, MAIL in '
          'front; MAIL ended by its X, the Commander: all right')


if __name__ == '__main__':
    main()
