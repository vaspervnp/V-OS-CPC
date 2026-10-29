#!/usr/bin/env python3
"""mkreloc - a program with its relocation table (src/api/vos_api.inc).

usage: mkreloc.py prog.bin prog_hi.bin out.bin

prog.bin is the program assembled for #4000, prog_hi.bin the same
assembled for #4100 (-DVOS_RELOC_PASS=1). The bytes that differ by one
are the high bytes of the program's own addresses: out.bin is prog.bin,
then their offsets (dw each), dw their count and "RL". Any other
difference is an error: the program uses its addresses in a way that a
move by whole pages does not keep.
"""
import struct
import sys


class Error(Exception):
    pass


def relocate(lo, hi):
    """lo, hi: the builds at #4000 and #4100 -> lo with its table"""
    if len(lo) != len(hi):
        raise Error("the two builds differ in length")
    offsets = []
    for i, (a, b) in enumerate(zip(lo, hi)):
        if a == b:
            continue
        if (b - a) & 255 != 1:
            raise Error(f"byte {i} (#{0x4000 + i:04X}) differs by "
                        f"{(b - a) & 255}, not by one page")
        offsets.append(i)
    table = b"".join(struct.pack("<H", o) for o in offsets)
    return lo + table + struct.pack("<H", len(offsets)) + b"RL"


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__.split("\n")[2])
    lo = open(sys.argv[1], "rb").read()
    hi = open(sys.argv[2], "rb").read()
    try:
        out = relocate(lo, hi)
    except Error as e:
        sys.exit(f"mkreloc: {sys.argv[1]}: {e}")
    open(sys.argv[3], "wb").write(out)


if __name__ == "__main__":
    main()
