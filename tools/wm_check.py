#!/usr/bin/env python3
"""Check make test-wm's screenshots (WM.SYS; WINA and WINB, apps/wint).

usage: wm_check.py front_b front_a moved full back closed_a closed_b

Seven shots of one scenario (src/kernel/test_script.asm, 52), each from
a run of its own. Caprice32's screenshot is 768 x 540: screen pixel
(x, y) of mode 1 is at (2x, 2y + 14). Frames: WINA 168 x 94 at (16, 20),
then at (72, 83); WINB 144 x 78 at (40, 36). A title line is 10 high,
black in front, white behind; WINA's inside is pen 2 (black), WINB's
pen 3. Exits 1 on the first difference.
"""
import sys
from PIL import Image

DESK, WHITE, BLACK, PEN3 = (0, 0, 127), (255, 255, 255), (0, 0, 0), (0, 127, 255)


def load(path):
    return Image.open(path).convert('RGB')


def pixel(im, x, y):
    return im.getpixel((2 * x, 2 * y + 14))[:3]


def bar(im):
    """the menu bar's first title (the program's name)"""
    return [pixel(im, x, y) for y in range(0, 10) for x in range(0, 48)]


def check(shot, what, got, want):
    if got != want:
        sys.exit('wm_check: %s: %s: got %r, want %r' % (shot, what, got, want))


def main():
    names = ('front_b', 'front_a', 'moved', 'full', 'back', 'closed_a', 'closed_b')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    shots = dict(zip(names, map(load, sys.argv[1:])))

    im = shots['front_b']                   # WINB in front, WINA behind
    check('front_b', "WINB's inside", pixel(im, 100, 60), PEN3)
    check('front_b', "WINB's title, in front", pixel(im, 42, 37), BLACK)
    check('front_b', "WINA's title, behind", pixel(im, 18, 22), WHITE)
    check('front_b', "WINA's inside, behind", pixel(im, 24, 90), BLACK)
    check('front_b', 'the desk', pixel(im, 250, 150), DESK)

    im = shots['front_a']                   # a click: WINA in front
    check('front_a', "WINA's title, in front", pixel(im, 18, 22), BLACK)
    check('front_a', "WINA's inside over WINB", pixel(im, 100, 60), BLACK)
    check('front_a', '"080,040" (the pointer is on the mark)',
          any(pixel(im, x, y) == WHITE for x in range(28, 84) for y in range(54, 62)), True)
    check('front_a', 'WINB hidden', pixel(im, 190, 50), DESK)
    check('front_a', 'the bar: WINA', bar(im) != bar(shots['front_b']), True)

    for shot in ('moved', 'back'):          # WINA moved to (72, 83)
        im = shots[shot]
        check(shot, "WINA's title, in front", pixel(im, 74, 85), BLACK)
        check(shot, "WINA's inside", pixel(im, 200, 150), BLACK)
        check(shot, "WINA's border", pixel(im, 73, 150), WHITE)
        check(shot, 'the mark, moved with it', pixel(im, 159, 136), WHITE)
        check(shot, "WINB's inside, behind", pixel(im, 60, 60), PEN3)
        check(shot, "WINB's title, behind", pixel(im, 42, 37), WHITE)
        check(shot, 'where WINA was', pixel(im, 18, 100), DESK)
        check(shot, 'the bar: WINA', bar(im), bar(shots['front_a']))

    im = shots['full']                      # F7: WINA full screen
    check('full', 'the bar: WINA', bar(im), bar(shots['front_a']))
    check('full', 'no desk', pixel(im, 300, 200), BLACK)
    check('full', 'the mark, from under the bar', pixel(im, 83, 40 + 12 + 3), WHITE)

    im = shots['closed_a']                  # WINA's X: WINB alone
    check('closed_a', "WINB's title, in front", pixel(im, 42, 37), BLACK)
    check('closed_a', "WINB's inside", pixel(im, 100, 60), PEN3)
    check('closed_a', 'where WINA was', pixel(im, 200, 150), DESK)
    check('closed_a', 'the bar: WINB', bar(im), bar(shots['front_b']))

    im = shots['closed_b']                  # WINB's X: the Commander
    check('closed_b', 'no WINB', pixel(im, 100, 60) != PEN3, True)
    check('closed_b', "the Commander's panel", pixel(im, 300, 150), WHITE)
    print('wm_check: WINB in front of WINA, WINA in front by a click, its mark, moved, '
          'full screen and back, closed; WINB closed: the Commander: all right')


if __name__ == '__main__':
    main()
