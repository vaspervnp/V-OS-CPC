#!/usr/bin/env python3
"""Check make test-wm-desktop's screenshots (the Desktop among the
windows; src/kernel/test_script.asm, 58).

usage: wm_desktop_check.py start desk wina desk2

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). WINA's frame is at (16, 20), its count of drawings
(apps/wint, read with V-OS's font as wm_copies_check.py does) at
(28, 70). The Desktop's files window (SETUP.CFG) is at (100, 130), its
drive icons from (328, 28). Shots: WINA in front, the Desktop's window
and icons behind it from their copies (001); the Desktop in front with
WINA's window on its desk, from its copy (001); WINA in front by a
click (it draws: 002); the Desktop in front by a click in its window,
WINA as it was (002). Exits 1 on the first difference.
"""
import sys
from wm_copies_check import load, pixel, text, check, DESK, WHITE, BLACK

COUNT = (28, 70)


def bar(im):
    """the menu bar's first title (the program's name)"""
    return [pixel(im, x, y) for y in range(0, 10) for x in range(0, 48)]


def desktop_behind(name, im):
    check(name, "the Desktop's window: its title", pixel(im, 104, 133), BLACK)
    check(name, "the Desktop's window: its inside", pixel(im, 104, 150), WHITE)
    check(name, "the Desktop's drive icons", pixel(im, 340, 34) != DESK, True)
    check(name, 'the desk between them', pixel(im, 290, 200), DESK)


def main():
    names = ('start', 'desk', 'wina', 'desk2')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    shots = dict(zip(names, map(load, sys.argv[1:])))
    for name, want in (('start', '001'), ('desk', '001'), ('wina', '002'), ('desk2', '002')):
        im = shots[name]
        desktop_behind(name, im)
        check(name, "WINA's count", text(im, *COUNT, 3), want)
    for name in ('start', 'wina'):
        check(name, "WINA's title, in front", pixel(shots[name], 18, 22), BLACK)
    for name in ('desk', 'desk2'):
        check(name, "WINA's title, behind", pixel(shots[name], 18, 22), WHITE)
        check(name, "the Desktop's keys, below", WHITE in [pixel(shots[name], x, 252) for x in range(0, 100)], True)
    check('wina', 'the bar: WINA', bar(shots['wina']), bar(shots['start']))
    check('desk2', "the bar: the Desktop's", bar(shots['desk2']), bar(shots['desk']))
    check('desk', "the bar: the Desktop's, not WINA's", bar(shots['desk']) != bar(shots['start']), True)
    print("wm_desktop_check: WINA with the Desktop's window and icons behind it; the Desktop "
          "with WINA's window on its desk; each brought to the front with a click: all right")


if __name__ == '__main__':
    main()
