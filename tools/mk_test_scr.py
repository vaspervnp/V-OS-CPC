#!/usr/bin/env python3
"""mk_test_scr.py out.scr - a 16K mode 0 CPC screen as PAINT saves it
(its 16 inks and the border at #07D0), for make test-wall: the 16 pens
in stripes of 10 pixels on the top half, pen 1 (white) below with a box
of pen 0 (black) in the middle.
"""
import sys

PALETTE = [0, 26, 2, 6, 18, 24, 20, 8, 15, 13, 3, 9, 1, 12, 17, 11, 13]


def byte(left, right):
    """two mode 0 pixels -> their byte"""
    b = 0
    for i, bit in enumerate((7, 3, 5, 1)):
        if left >> i & 1:
            b |= 1 << bit
    for i, bit in enumerate((6, 2, 4, 0)):
        if right >> i & 1:
            b |= 1 << bit
    return b


def pen(x, y):
    if y < 100:
        return x // 10
    return 0 if 50 <= x < 110 and 130 <= y < 170 else 1


scr = bytearray(16384)
for y in range(200):
    at = (y & 7) * 0x800 + (y >> 3) * 80
    for xb in range(80):
        scr[at + xb] = byte(pen(xb * 2, y), pen(xb * 2 + 1, y))
scr[0x7D0:0x7D0 + 17] = bytes(PALETTE)
open(sys.argv[1], 'wb').write(scr)
