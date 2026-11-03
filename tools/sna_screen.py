#!/usr/bin/env python3
"""sna_screen.py snapshot.sna out.png [vos.sym] - V-OS's screen drawn
from the memory of a .sna snapshot (the 1984 emulator's --save-sna-at),
with the inks of V-OS's own palette for the mode (palette_mode1 or
palette_mode0 from vos.sym), not the Gate Array's: 1984 sometimes sets
every ink to one colour from bytes it takes for the firmware's (#B1FC,
#B7F7), which in V-OS are screen memory.

The 32K screen: 34 character rows of 96 bytes, rows 0-20 from #8020
and rows 21-33 from #C000, pixel line l of a row #800 * l further on
(src/include/memmap.inc). Each line is drawn twice, as on the monitor.
"""
import sys
from PIL import Image

# the 27 firmware colours
RGB = [(0, 0, 0), (0, 0, 128), (0, 0, 255), (128, 0, 0), (128, 0, 128),
       (128, 0, 255), (255, 0, 0), (255, 0, 128), (255, 0, 255),
       (0, 128, 0), (0, 128, 128), (0, 128, 255), (128, 128, 0),
       (128, 128, 128), (128, 128, 255), (255, 128, 0), (255, 128, 128),
       (255, 128, 255), (0, 255, 0), (0, 255, 128), (0, 255, 255),
       (128, 255, 0), (128, 255, 128), (128, 255, 255), (255, 255, 0),
       (255, 255, 128), (255, 255, 255)]


def pixels(byte, mode):
    """-> the pens of one screen byte, left to right"""
    if mode == 2:
        return [(byte >> (7 - i)) & 1 for i in range(8)]
    if mode == 1:
        return [((byte >> (7 - i)) & 1) | (((byte >> (3 - i)) & 1) << 1)
                for i in range(4)]
    out = []
    for b in (byte, byte << 1):
        out.append(((b >> 7) & 1) | (((b >> 3) & 1) << 1) |
                   (((b >> 5) & 1) << 2) | (((b >> 1) & 1) << 3))
    return out


def main():
    sna = open(sys.argv[1], "rb").read()
    ram = sna[0x100:0x100 + 0x10000]
    mode = sna[0x40] & 3
    sym = {}
    if len(sys.argv) > 3:
        for line in open(sys.argv[3]):
            f = line.split()
            if len(f) >= 2 and f[1].startswith("#"):
                sym[f[0]] = int(f[1][1:], 16)
    name = "PALETTE_MODE0" if mode == 0 else "PALETTE_MODE1"
    if name in sym:
        inks = [RGB[c % 27] for c in ram[sym[name]:sym[name] + 16]]
    else:
        inks = [RGB[c] for c in (1, 24, 20, 6, 26, 0, 2, 8, 10, 12, 14,
                                  16, 18, 22, 25, 13)]
    if mode == 2:
        inks = [inks[0], inks[1]]
    width = {0: 2, 1: 4, 2: 8}[mode] * 96
    img = Image.new("RGB", (768, 272 * 2))
    for row in range(34):
        base = 0x8020 + row * 96 if row < 21 else 0xC000 + (row - 21) * 96
        for line in range(8):
            y = row * 8 + line
            addr = base + line * 0x800
            xs = []
            for b in ram[addr:addr + 96]:
                xs.extend(pixels(b, mode))
            scale = 768 // width
            for x, pen in enumerate(xs):
                c = inks[pen % len(inks)]
                for k in range(scale):
                    img.putpixel((x * scale + k, y * 2), c)
                    img.putpixel((x * scale + k, y * 2 + 1), c)
    img.save(sys.argv[2])


if __name__ == "__main__":
    main()
