#!/usr/bin/env python3
"""mktexts - a program's texts (VOS_TEXTS) from a text file.

usage: mktexts.py texts.txt out.asm [label]

Lines: NAME | English | Greek (the table says "EL"), "#" starts a
comment. A "|" between spaces parts the columns; one inside a text
(no spaces around it) starts a line in a dialog. Writes T_NAME equ VT_FIRST + n for each, and the table
"texts:" (or "label:") for VOS_TEXTS, both columns in the V-OS character
set (tools/voscs.py: ASCII, Greek and the Latin letters). An empty
third column uses the English text. A program with more than 64 texts
keeps a second table and switches to it with VOS_TEXTS.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voscs  # noqa: E402,F401  (the codec "vos")


def data(label, text, codec):
    try:
        raw = text.encode(codec)
    except UnicodeEncodeError:
        sys.exit(f"mktexts: {text!r} is not in the V-OS character set")
    return f"{label}: db " + ", ".join(str(b) for b in raw + b"\0") + f"   ; {text}"


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__.split("\n")[2])
    label = sys.argv[3] if len(sys.argv) == 4 else "texts"
    pre = "t" if label == "texts" else label + "_"
    rows = []
    for n, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        part = [p.strip() for p in re.split(r"\s+\|(?:\s+|$)", line, maxsplit=2)]
        if len(part) != 3 or not part[0].isidentifier():
            sys.exit(f"mktexts: {sys.argv[1]}:{n}: NAME | English | Greek")
        rows.append(part)
    if len(rows) > 64:
        sys.exit(f"mktexts: {len(rows)} texts, at most 64 (#C0..#FF)")
    out = [f"; made by tools/mktexts.py from {sys.argv[1]}: do not edit", ""]
    for i, (name, _, _) in enumerate(rows):
        out.append(f"T_{name:<14} equ VT_FIRST + {i}")
    out += ["", f'{label}:  db {len(rows)}, "EL"']
    for i, (name, _, el) in enumerate(rows):
        out.append(f"        dw {pre}e_{i}, {pre + 'g_' + str(i) if el else 0}")
    for i, (name, en, el) in enumerate(rows):
        out.append(data(f"{pre}e_{i}", en, "vos"))
        if el:
            out.append(data(f"{pre}g_{i}", el, "vos"))
    open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
