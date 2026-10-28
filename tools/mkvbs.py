#!/usr/bin/env python3
"""mkvbs - a Studio program (.VBS, version 2) from text.

usage: mkvbs.py prog.vbt out.VBS [player.BIN out.BIN]

With the player (build/VBRUN.BIN) it also writes the program as Studio's
RUN does: the player, then the VBS record, as one .BIN.

The text, one line or block per line ("#" starts a comment, leading
spaces are ignored):
  BG pen                      the stage's background
  MODE 0 or 1                 the screen mode it runs in (mode 1: 384
                              pixels wide, pens 0..3)
  SPRITE x y w h colour       up to 6
  OP slot slot slot           a block: its name in apps/studio/blocks.txt
                              without OP_ (START, IF, WINDOW, ...), then
                              its slots in slot order (not as shown)
Slots: 12 or -3 (a number), A..H (a variable), "text", X, Y, EDGE,
BUTTON, RND:n, KEY:n, TOUCH:n (values); < = > (comparisons; _ is
none); STAGE or SPRITE:n (whose script); KEYN:n (WHEN KEY's key).
"""
import os
import struct
import sys

SPR_MAX, TEXT_MAX, TEXT_SIZE, MAX_LINES = 6, 32, 16, 200
K = dict(NUM=1, VAR=2, X=3, Y=4, RND=5, KEY=6, TOUCH=7, EDGE=8, CMP=9,
         SPR=10, KEYN=11, BUTTON=12, TEXT=13)


class Error(Exception):
    pass


def op_names():
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "..", "apps", "studio", "blocks.txt")
    names = []
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.lstrip().startswith("#"):
            names.append(line.split("|")[0].strip()[3:])
    return {n: i for i, n in enumerate(names)}


def words(line):
    out, i = [], 0
    while i < len(line):
        if line[i].isspace():
            i += 1
        elif line[i] == '"':
            j = line.find('"', i + 1)
            if j < 0:
                raise Error("a text without its closing quote")
            out.append(line[i:j + 1])
            i = j + 1
        else:
            j = i
            while j < len(line) and not line[j].isspace():
                j += 1
            out.append(line[i:j])
            i = j
    return out


def slot(word, texts):
    if word.startswith('"'):
        raw = word[1:-1].encode("iso8859_7")
        if len(raw) > TEXT_SIZE - 2:
            raise Error(f"{word}: at most {TEXT_SIZE - 2} characters")
        if len(texts) == TEXT_MAX:
            raise Error(f"more than {TEXT_MAX} texts")
        texts.append(raw)
        return K["TEXT"], len(texts) - 1
    w = word.upper()
    if w.lstrip("-").isdigit():
        return K["NUM"], int(w)
    if len(w) == 1 and "A" <= w <= "H":
        return K["VAR"], ord(w) - ord("A")
    if w in ("X", "Y", "EDGE", "BUTTON"):
        return K[w], 0
    if w in "<=>":
        return K["CMP"], "<=>".index(w)
    if w == "_":
        return 0, 0
    if w == "STAGE":
        return K["SPR"], 0
    kind, _, n = w.partition(":")
    if kind == "SPRITE":
        kind = "SPR"
    if kind in ("RND", "KEY", "TOUCH", "SPR", "KEYN") and n.isdigit():
        return K[kind], int(n)
    raise Error(f"{word}: not a slot")


def compile_vbt(lines):
    ops = op_names()
    bg, mode, sprites, texts, code = 0, 0, [], [], []
    for n, line in enumerate(lines, 1):
        line = line.split("#", 1)[0] if '"' not in line else line
        w = words(line)
        if not w:
            continue
        try:
            head = w[0].upper()
            if head == "BG":
                bg = int(w[1]) & 15
            elif head == "MODE":
                mode = int(w[1])
                if mode not in (0, 1):
                    raise Error("MODE 0 or MODE 1")
            elif head == "SPRITE" and len(w) == 6:
                if len(sprites) == SPR_MAX:
                    raise Error(f"more than {SPR_MAX} sprites")
                sprites.append([int(v) for v in w[1:]])
            elif head in ops:
                if len(w) > 4:
                    raise Error("at most 3 slots")
                slots = [slot(v, texts) for v in w[1:]]
                slots += [(0, 0)] * (3 - len(slots))
                code.append(bytes([ops[head]]) + b"".join(
                    struct.pack("<Bh", k, v) for k, v in slots))
            else:
                raise Error(f"{w[0]}: no such block")
        except (Error, ValueError, IndexError) as e:
            raise Error(f"line {n}: {e}")
    if len(code) > MAX_LINES:
        raise Error(f"more than {MAX_LINES} lines")
    out = bytearray(b"VBS\x02" + bytes([bg | mode << 7, len(sprites)]))
    for x, y, wd, ht, colour in sprites:
        out += struct.pack("<hhBBBB", x, y, wd, ht, colour & 15, 0)
    out += bytes(8 * (SPR_MAX - len(sprites)))
    for t in texts:
        out += t + bytes(TEXT_SIZE - len(t))
    out += bytes(TEXT_SIZE * (TEXT_MAX - len(texts)))
    out += struct.pack("<H", len(code)) + b"".join(code)
    return bytes(out)


def main():
    if len(sys.argv) not in (3, 5):
        sys.exit(__doc__.split("\n")[2])
    try:
        vbs = compile_vbt(open(sys.argv[1], encoding="utf-8"))
    except Error as e:
        sys.exit(f"mkvbs: {sys.argv[1]}: {e}")
    open(sys.argv[2], "wb").write(vbs)
    if len(sys.argv) == 5:
        player = open(sys.argv[3], "rb").read()
        open(sys.argv[4], "wb").write(player + vbs)


if __name__ == "__main__":
    main()
