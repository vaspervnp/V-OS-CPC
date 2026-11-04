#!/usr/bin/env python3
"""Check make test-wm-keys's screenshots (F5, F6, X and VOS_PALETTE
among windows; src/kernel/test_script.asm, 59).

usage: wm_keys_check.py front_a switcher closed clock clock_closed reds x

Caprice32's screenshot is 768 x 540: screen pixel (x, y) of mode 1 is
at (2x, 2y + 14). WINA's frame is at (16, 20) (WINB's, at (40, 36), is
inside it). Shots: WINA in front, chosen with the switcher (F6); the
switcher open over it; closed (ESC): the desk under it again; CLOCK, the
accessory, over the windows (F5); closed: WINA's frame and name as they
were; WINA's P (VOS_PALETTE, reds) quiet in a window: the desk's
colours; WINA's X: its ^Q ends it, WINB in front. Exits 1 on the first
difference.
"""
import sys
from wm_copies_check import load, pixel, area, check, DESK, BLACK

SWITCHER = (128, 108, 256, 150)
CLOCK = (8, 15, 104, 49)
WINA_TOP = (8, 15, 184, 42)             # its frame's top, its name


def bar(im):
    return area(im, 0, 0, 48, 10)


def main():
    names = ('front_a', 'switcher', 'closed', 'clock', 'clock_closed', 'reds', 'x')
    if len(sys.argv) != len(names) + 1:
        sys.exit(__doc__)
    s = dict(zip(names, map(load, sys.argv[1:])))
    check('front_a', "WINA's title, in front", pixel(s['front_a'], 18, 22), BLACK)
    check('front_a', 'the desk', pixel(s['front_a'], 250, 200), DESK)
    check('switcher', 'the switcher over the desk', area(s['switcher'], *SWITCHER) != area(s['front_a'], *SWITCHER), True)
    check('closed', 'the desk under it again', area(s['closed'], *SWITCHER), area(s['front_a'], *SWITCHER))
    check('clock', 'the clock over WINA', area(s['clock'], *CLOCK) != area(s['closed'], *CLOCK), True)
    check('clock_closed', "WINA's frame and name again", area(s['clock_closed'], *WINA_TOP), area(s['closed'], *WINA_TOP))
    check('reds', "the desk's colour (no reds)", pixel(s['reds'], 250, 200), DESK)
    check('reds', "WINA's title", pixel(s['reds'], 18, 22), BLACK)
    check('x', "WINB's title, in front", pixel(s['x'], 42, 38), BLACK)
    check('x', 'WINA gone', pixel(s['x'], 20, 100), DESK)
    check('x', 'the bar: WINB', bar(s['x']) != bar(s['front_a']), True)
    print('wm_keys_check: the switcher and the accessory over the windows, closed: drawn '
          'again; VOS_PALETTE quiet in a window; X asked WINA to end (^Q): WINB in front: all right')


if __name__ == '__main__':
    main()
