#!/usr/bin/env python3
"""Check make test-view's screenshots (VIEWT, apps/viewt: VX_VIEW).

usage: view_check.py shot576.png shot128.png

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). At 576K VIEWT drew through a view of 160 x 96 at
(40, 40); at 128K VX_VIEW gave carry and nothing was drawn but the
result line. Exits 1 on the first difference.
"""
import sys
from PIL import Image

DESK, PEN1, PEN2, PEN3 = (0, 0, 127), (255, 255, 255), (0, 0, 0), (0, 127, 255)
POINTER = (184, 118, 199, 134)          # where the pointer may be: not looked at


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def check(what, got, want):
    if got != want:
        sys.exit('view_check: %s: got %r, want %r' % (what, got, want))


def area(im, x0, y0, x1, y1):
    """the colours in screen pixels x0..x1-1, y0..y1-1, but the pointer's"""
    out = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not (POINTER[0] <= x <= POINTER[2] and POINTER[1] <= y <= POINTER[3]):
                out.add(pixel(im, x, y))
    return out


def main():
    im = Image.open(sys.argv[1]).convert('RGB')
    # the view's edges: inside filled (VOS_CLS), outside the desk
    check('left of the view', area(im, 39, 40, 40, 136), {DESK})
    check('above the view', area(im, 40, 39, 200, 40), {DESK})
    check('right of the view', area(im, 200, 40, 201, 136), {DESK})
    check('below the view', area(im, 40, 136, 200, 137), {DESK})
    check('the view filled', area(im, 40, 60, 140, 72), {PEN2})
    # VOS_RECT (100, 50, 200, 100) cut to screen (140, 90)-(199, 135)
    check('the rectangle, cut', area(im, 140, 90, 200, 136) - {PEN1}, {PEN3})
    check('left of the rectangle', area(im, 139, 90, 140, 136), {PEN2})
    check('above the rectangle', area(im, 140, 89, 200, 90), {PEN2})
    # VOS_PLOT: the view's last pixel, and none past it
    check('the last pixel', pixel(im, 199, 135), PEN1)
    check('past the last pixel', pixel(im, 200, 135), DESK)
    # VOS_PRINT at (8, 8): 19 characters, the 20th (J) cut
    text = area(im, 48, 48, 200, 56)
    check('the text', PEN1 in text and PEN2 in text, True)
    for n in range(19):
        x = 48 + 8 * n
        check('character %d' % n, PEN1 in area(im, x, 48, x + 8, 56), True)
    check('J not drawn', area(im, 200, 48, 208, 56), {DESK})
    # VOS_BLIT: in at (0, 72) -> (40, 112), 16 x 8; out at (152, 0): none
    check('the image in', area(im, 40, 112, 56, 120), {PEN3})
    check('beside the image', area(im, 56, 112, 60, 120), {PEN2})
    check('the image out', area(im, 192, 40, 200, 48), {PEN2})
    check('the image out, past the view', area(im, 200, 40, 208, 48), {DESK})
    # no view again: "VIEW: OK" at (0, 200)
    check('VIEW: OK', PEN1 in area(im, 0, 200, 64, 208), True)
    # 128K: no view, nothing drawn there, "NO EXPANSION"
    im = Image.open(sys.argv[2]).convert('RGB')
    check('128K: nothing in the view', area(im, 40, 40, 200, 136), {DESK})
    check('128K: NO EXPANSION', PEN1 in area(im, 0, 200, 96, 208), True)
    print('view_check: the view filled, the rectangle cut, 19 characters, the last '
          'pixel, an image in and one out; 128K: no view: all right')


if __name__ == '__main__':
    main()
