#!/usr/bin/env python3
"""mkvbs - a Studio program (.VBS, version 3) from text.

usage: mkvbs.py prog.vbt out.VBS [player out.VBN]

With the player (build/VBRUN.SYS) it also writes the program as Studio's
RUN does: the player, then the VBS record, as one .VBN (a V-OS program,
like a .BIN, of its own type).

The text, one line or block per line ("#" starts a comment, leading
spaces are ignored):
  BG pen                      the stage's background
  MODE 0 or 1                 the screen mode it runs in (mode 1: 384
                              pixels wide, pens 0..3)
  BEHIND PAUSE or RUN         behind other programs it pauses (as when
                              left out) or goes on
  SPRITE x y w h colour [n]   up to 6; n: its costume (1..), else none
  IMAGE                       a costume (1, 2, ... in order), then 16
                              lines of 16 pixels: a pen in hex, "."
                              none; at most 8
  OP slot slot slot           a block: its name in apps/studio/blocks.txt
                              without OP_ (START, IF, WINDOW, ...), then
                              its slots in slot order (not as shown)
Slots: 12 or -3 (a number), A..H or A1..H15 (one of the 128 variables:
the letter is the number mod 8, the digits the number / 8), "text", X,
Y, EDGE, BUTTON, COSTUME, RND:n, KEY:n, TOUCH:n (values); < = >
(comparisons; _ is none); STAGE or SPRITE:n (whose script); KEYN:n
(WHEN KEY's key); ALL, A-H or A1-H1..A15-H15 (SAVE_VARS and LOAD_VARS:
all the variables or those 8).
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voscs  # noqa: E402,F401  (the codec "vos")

SPR_MAX, TEXT_MAX, TEXT_SIZE, MAX_LINES, COS_MAX = 6, 32, 16, 240, 8
K = dict(NUM=1, VAR=2, X=3, Y=4, RND=5, KEY=6, TOUCH=7, EDGE=8, CMP=9,
         SPR=10, KEYN=11, BUTTON=12, TEXT=13, COSTUME=14, GROUP=15)


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
        raw = word[1:-1].encode("vos")
        if len(raw) > TEXT_SIZE - 2:
            raise Error(f"{word}: at most {TEXT_SIZE - 2} characters")
        if len(texts) == TEXT_MAX:
            raise Error(f"more than {TEXT_MAX} texts")
        texts.append(raw)
        return K["TEXT"], len(texts) - 1
    w = word.upper()
    if w.lstrip("-").isdigit():
        return K["NUM"], int(w)
    if "A" <= w[0] <= "H" and (len(w) == 1 or w[1:].isdigit() and 1 <= int(w[1:]) <= 15
                               and w[1] != "0"):
        return K["VAR"], ord(w[0]) - ord("A") + (8 * int(w[1:]) if len(w) > 1 else 0)
    if w == "ALL":
        return K["GROUP"], 16
    a, dash, h = w.partition("-")
    if dash and a[:1] == "A" and h[:1] == "H" and a[1:] == h[1:] and (
            a[1:] == "" or a[1:].isdigit() and a[1] != "0" and int(a[1:]) <= 15):
        return K["GROUP"], int(a[1:] or 0)
    if w in ("X", "Y", "EDGE", "BUTTON", "COSTUME"):
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
    bg, mode, runs, sprites, texts, code, images = 0, 0, 0, [], [], [], []
    rows = None                         # an IMAGE's lines still to come
    for n, line in enumerate(lines, 1):
        line = line.split("#", 1)[0] if '"' not in line else line
        w = words(line)
        if not w:
            continue
        try:
            if rows is not None:
                row = w[0]
                if len(w) > 1 or len(row) != 16:
                    raise Error("an IMAGE line: 16 pixels")
                for ch in row:
                    rows.append(0x80 if ch == "." else int(ch, 16))
                if len(rows) == 256:
                    rows = None
                continue
            head = w[0].upper()
            if head == "BG":
                bg = int(w[1]) & 15
            elif head == "BEHIND":
                if w[1:] not in (["PAUSE"], ["RUN"]):
                    raise Error("BEHIND PAUSE or BEHIND RUN")
                runs = int(w[1] == "RUN")
            elif head == "MODE":
                mode = int(w[1])
                if mode not in (0, 1):
                    raise Error("MODE 0 or MODE 1")
            elif head == "SPRITE" and len(w) in (6, 7):
                if len(sprites) == SPR_MAX:
                    raise Error(f"more than {SPR_MAX} sprites")
                sprites.append([int(v) for v in w[1:]] + [0] * (7 - len(w)))
            elif head == "IMAGE" and len(w) == 1:
                if len(images) == COS_MAX:
                    raise Error(f"more than {COS_MAX} images")
                rows = []
                images.append(rows)
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
    if rows is not None:
        raise Error("an IMAGE without its 16 lines")
    if len(code) > MAX_LINES:
        raise Error(f"more than {MAX_LINES} lines")
    out = bytearray(b"VBS\x03" + bytes([bg | runs << 6 | mode << 7, len(sprites)]))
    for x, y, wd, ht, colour, costume in sprites:
        if costume > len(images):
            raise Error(f"no costume {costume}")
        out += struct.pack("<hhBBBB", x, y, wd, ht, colour & 15, costume)
    out += bytes(8 * (SPR_MAX - len(sprites)))
    for t in texts:
        out += t + bytes(TEXT_SIZE - len(t))
    out += bytes(TEXT_SIZE * (TEXT_MAX - len(texts)))
    out += struct.pack("<H", len(code)) + b"".join(code)
    out.append(len(images))
    for image in images:
        out += bytes(2) + bytes(image)
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
