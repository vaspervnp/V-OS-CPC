#!/usr/bin/env python3
"""mk_promo_scr.py out.scr [night] - a mode 0 picture for make promo, in
PAINT's 16 inks and its border at #07D0: a sunset over the sea, or
with "night" the moon over it in the Desktop's four inks (blue, bright
white, black, sky blue), for the desk's picture.
"""
import math
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


# PAINT's pens: 0 black, 1 bright white, 2 bright blue, 3 bright red,
# 4 bright green, 5 bright yellow, 6 bright cyan, 7 bright magenta,
# 8 orange, 9 white, 10 red, 11 green, 12 blue, 13 yellow,
# 14 pastel magenta, 15 sky blue
SKY = [12, 12, 2, 2, 15, 14, 14, 7, 8, 8, 13]
HORIZON = 128
SUN_X, SUN_Y, SUN_R = 80, 118, 26


def dither(bands, t, x, y):
    """t from 0 to 1 over the bands, a checker between two of them"""
    f = t * (len(bands) - 1)
    i = int(f)
    if i >= len(bands) - 1:
        return bands[-1]
    return bands[i + 1] if (f - i) * 4 > ((x + y) & 1) * 2 + (y & 1) + 0.5 else bands[i]


def hills(x):
    return HORIZON - 14 - 10 * math.sin(x / 13) - 6 * math.sin(x / 5 + 1)


def pen(x, y):
    d = math.hypot((x - SUN_X) * 2, y - SUN_Y)
    if y < HORIZON:
        if x < 50 and y > hills(x) or x > 112 and y > hills(x + 40):
            return 0
        if d < SUN_R - 4:
            return 5
        if d < SUN_R:
            return 8
        return dither(SKY, y / HORIZON, x, y)
    # the sea: the sun's path in broken lines, the rest darker below
    depth = (y - HORIZON) / (200 - HORIZON)
    wave = (x + int(6 * math.sin(y * 1.7))) % 24
    width = 18 + depth * 40
    if abs(x - SUN_X) < width and wave < 10 - depth * 6 and y % 3:
        return 5 if abs(x - SUN_X) < width / 2 else 8
    return dither([14, 15, 2, 12, 12, 0], depth, x, y)


# 5 x 7 letters for "V-OS" in the night sky
FONT = {
    'V': ["X...X", "X...X", "X...X", ".X.X.", ".X.X.", ".X.X.", "..X.."],
    '-': [".....", ".....", ".....", "XXXX.", ".....", ".....", "....."],
    'O': [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    'S': [".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."],
}
TITLE_X, TITLE_Y, TITLE_S = 14, 20, 3
MOON_X, MOON_Y, MOON_R = 122, 46, 18


def title(x, y):
    cx, cy = (x - TITLE_X) // TITLE_S, (y - TITLE_Y) // (TITLE_S * 2)
    if x < TITLE_X or y < TITLE_Y or cy >= 7:
        return False
    i, col = divmod(cx, 6)
    if i >= 4 or col == 5:
        return False
    return FONT["V-OS"[i]][cy][col] == 'X'


def night(x, y):
    if y < HORIZON:
        if x < 50 and y > hills(x) or x > 112 and y > hills(x + 40):
            return 0
        d = math.hypot((x - MOON_X) * 2, y - MOON_Y)
        if d < MOON_R:
            crater = math.hypot((x - MOON_X - 3) * 2, y - MOON_Y + 5) < 4 \
                or math.hypot((x - MOON_X + 4) * 2, y - MOON_Y - 6) < 3
            return 15 if crater else 1
        if title(x, y):
            return 15
        if (x * 7 + y * 13) % 97 == 0 and (x * y) % 5 == 1:
            return 1
        return dither([0, 0, 12, 12], y / HORIZON, x, y)
    depth = (y - HORIZON) / (200 - HORIZON)
    wave = (x + int(6 * math.sin(y * 1.7))) % 24
    width = 8 + depth * 30
    if abs(x - MOON_X) < width and wave < 10 - depth * 6 and y % 3:
        return 1 if abs(x - MOON_X) < width / 2 else 15
    return dither([15, 12, 12, 0], depth, x, y)


if len(sys.argv) > 2 and sys.argv[2] == 'night':
    pen = night
scr = bytearray(16384)
for y in range(200):
    at = (y & 7) * 0x800 + (y >> 3) * 80
    for xb in range(80):
        scr[at + xb] = byte(pen(xb * 2, y), pen(xb * 2 + 1, y))
scr[0x7D0:0x7D0 + 17] = bytes(PALETTE)
open(sys.argv[1], 'wb').write(scr)
