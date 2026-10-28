#!/usr/bin/env python3
"""mkicon - a program's icon for the Launcher, from text.

usage: mkicon.py icon.txt out.asm

16 lines of 16 characters: a pen in hex (mode 0, Launcher palette) or
"." for transparent; "#" starts a comment line. Writes the 258 bytes a
program puts at +12 (VOS_ICON): "IC", then per row 8 (mask, pixels)
pairs, as VOS_BLIT draws them. blocks/vbc.py uses icon_lines too.
"""
import sys

SIZE = 16


class Error(Exception):
    pass


def read_rows(path):
    return [l.rstrip("\n") for l in open(path, encoding="utf-8")
            if not l.startswith("#") and l.strip()]


def icon_lines(rows, where):
    """16 rows of 16 pens -> assembly lines (db "IC", then the pairs)"""
    if len(rows) != SIZE or any(len(r) != SIZE for r in rows):
        raise Error(f"{where}: an icon is {SIZE} lines of {SIZE} characters")
    out = ['        db "IC"']
    for r in rows:
        data = []
        for b in range(SIZE // 2):
            mask = pix = 0
            for p in range(2):
                ch = r[b * 2 + p]
                if ch == ".":
                    continue
                try:
                    pen = int(ch, 16)
                except ValueError:
                    raise Error(f"{where}: {ch!r} is not a pen")
                for k, bit in enumerate([7, 3, 5, 1] if p == 0 else [6, 2, 4, 0]):
                    mask |= 1 << bit
                    if pen >> k & 1:
                        pix |= 1 << bit
            data += [mask, pix]
        out.append("        db " + ", ".join(f"#{v:02X}" for v in data) + f"   ; {r}")
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__.split("\n")[2])
    try:
        lines = icon_lines(read_rows(sys.argv[1]), sys.argv[1])
    except Error as e:
        sys.exit(f"mkicon: {e}")
    out = [f"; made by tools/mkicon.py from {sys.argv[1]}: do not edit"] + lines
    open(sys.argv[2], "w", encoding="ascii").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
