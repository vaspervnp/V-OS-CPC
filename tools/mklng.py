#!/usr/bin/env python3
"""Build V-OS language data from the text sources in lang/.

  mklng.py kernel lang/en src/lang
      English, built into the kernel:
        src/lang/msg_ids.inc   MSG_<ID> equates and MSG_COUNT
        src/lang/lang_en.asm   msg_en_table + strings, kbd_map, kbd_map_shift

  mklng.py pack lang/el build/GREEK.LNG --master lang/en
      A language pack file (.LNG), format below.

.LNG format (little endian, offsets from the start of the file):
   0  "VLNG"            magic
   4  db 1              format version
   5  db "EL"           language code
   7  db 0
   8  dw font           128 glyphs for codes 128..255, 8 bytes each,
                        bit 7 = leftmost pixel
  10  dw case           128 x (db flags, db other case); flags bit 0 = letter
  12  dw keymap         80 bytes normal + 80 bytes SHIFT, key number order
  14  dw combos         (db dead, base, result) ..., db 0
  16  dw messages       dw count, dw offset[count] (0 = not translated),
                        zero-terminated strings
  18  dw size           whole file
  20  db name[12]       language name in the pack's charset, zero padded
  32  data

Keymap codes 1..7 are dead keys (numbered in order of first use).
The pack is loaded at #8000 with an AMSDOS buffer at #9800, so it must
not exceed 6144 bytes.
"""
import argparse
import os
import re
import sys

MAX_PACK = 6144
DEAD_FIRST = 1
DEAD_LAST = 7


def fail(msg):
    sys.exit(f"mklng: {msg}")


def lines(path):
    """Non-blank, non-comment lines as (number, text). A comment line
    starts with "# " (or is just "#"); glyph rows may start with '#'."""
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            text = line.rstrip("\n")
            s = text.strip()
            if not s or s == "#" or s.startswith("# "):
                continue
            yield n, text


class Charset:
    def __init__(self, name):
        self.name = name

    def byte(self, ch, where):
        try:
            b = ch.encode(self.name)
        except UnicodeEncodeError:
            fail(f"{where}: {ch!r} is not in {self.name}")
        if len(b) != 1:
            fail(f"{where}: {ch!r} is not one byte in {self.name}")
        return b[0]

    def text(self, s, where):
        return bytes(self.byte(c, where) for c in s)


def token(tok, charset, dead, where):
    """Keymap token -> byte."""
    if tok == "none":
        return 0
    if tok == "space":
        return 32
    if len(tok) == 3 and tok[0] == "#":
        return int(tok[1:], 16)
    if tok.startswith("dead:"):
        name = tok[5:]
        if name not in dead:
            if len(dead) > DEAD_LAST - DEAD_FIRST:
                fail(f"{where}: too many dead keys")
            dead[name] = DEAD_FIRST + len(dead)
        return dead[name]
    if len(tok) != 1:
        fail(f"{where}: bad key token {tok!r}")
    return charset.byte(tok, where)


def read_keymap(path, charset, base=None):
    """Returns (normal[80], shift[80], combos[(dead, base, result)])."""
    normal = list(base[0]) if base else [None] * 80
    shift = list(base[1]) if base else [None] * 80
    dead = {}
    combos = []
    for n, text in lines(path):
        where = f"{path}:{n}"
        parts = text.split()
        if parts[0] == "key":
            if len(parts) < 4:
                fail(f"{where}: key <number> <normal> <shift>")
            key = int(parts[1])
            if not 0 <= key < 80:
                fail(f"{where}: key number out of range")
            normal[key] = token(parts[2], charset, dead, where)
            shift[key] = token(parts[3], charset, dead, where)
        elif parts[0] == "combo":
            if len(parts) < 4:
                fail(f"{where}: combo <dead> <base> <result>")
            if parts[1] not in dead:
                fail(f"{where}: dead key {parts[1]!r} is not on any key above")
            combos.append((dead[parts[1]],
                           token(parts[2], charset, dead, where),
                           token(parts[3], charset, dead, where)))
        else:
            fail(f"{where}: expected key or combo")
    missing = [k for k in range(80) if normal[k] is None]
    if missing:
        fail(f"{path}: keys without a mapping: {missing}")
    return normal, shift, combos


def read_messages(path):
    """Ordered dict ID -> text."""
    msgs = {}
    for n, text in lines(path):
        m = re.match(r"(\S+)\s+(.*)$", text)
        if not m:
            fail(f"{path}:{n}: <ID> <text>")
        ident, body = m.group(1), m.group(2).rstrip()
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", ident):
            fail(f"{path}:{n}: ID must be upper case")
        if ident in msgs:
            fail(f"{path}:{n}: {ident} defined twice")
        msgs[ident] = body
    return msgs


def read_font(path):
    """{code: 8 bytes} for codes 128..255."""
    glyphs = {}
    rows = None
    code = None
    for n, text in lines(path):
        m = re.match(r"([0-9A-Fa-f]{2})(\s.*)?$", text)
        if m and len(text.split()[0]) == 2 and not set(text.split()[0]) <= set("#."):
            if rows is not None and len(rows) != 8:
                fail(f"{path}: glyph {code:02X} has {len(rows)} rows")
            code = int(m.group(1), 16)
            if code < 128:
                fail(f"{path}:{n}: codes below 128 come from the kernel font")
            rows = []
            glyphs[code] = rows
            continue
        if rows is None or not re.fullmatch(r"[#.]{8}", text.strip()):
            fail(f"{path}:{n}: expected 8 characters of '#' and '.'")
        rows.append(int(text.strip().replace("#", "1").replace(".", "0"), 2))
    if rows is not None and len(rows) != 8:
        fail(f"{path}: glyph {code:02X} has {len(rows)} rows")
    return glyphs


def read_pack_info(path):
    info = {}
    for n, text in lines(path):
        key, _, value = text.partition(" ")
        info[key] = value.strip()
    for key in ("code", "name", "charset"):
        if key not in info:
            fail(f"{path}: missing {key}")
    if len(info["code"]) != 2:
        fail(f"{path}: code must be two letters")
    return info


def case_table(charset):
    out = bytearray()
    for code in range(128, 256):
        try:
            ch = bytes([code]).decode(charset.name)
        except UnicodeDecodeError:
            out += bytes([0, code])
            continue
        other = code
        swapped = ch.swapcase()
        if ch.isalpha() and swapped != ch and len(swapped) == 1:
            try:
                other = swapped.encode(charset.name)[0]
            except UnicodeEncodeError:
                pass
        out += bytes([1 if ch.isalpha() else 0, other])
    return out


def build_pack(src, dst, master):
    info = read_pack_info(os.path.join(src, "pack.txt"))
    charset = Charset(info["charset"])
    ascii_cs = Charset("ascii")
    base = read_keymap(os.path.join(master, "keymap.txt"), ascii_cs)
    normal, shift, combos = read_keymap(os.path.join(src, "keymap.txt"), charset, base[:2])
    glyphs = read_font(os.path.join(src, "font.txt"))
    ids = list(read_messages(os.path.join(master, "messages.txt")))
    msgs = read_messages(os.path.join(src, "messages.txt"))
    for ident in msgs:
        if ident not in ids:
            fail(f"{src}/messages.txt: {ident} is not in {master}/messages.txt")

    font = bytearray()
    for code in range(128, 256):
        font += bytes(glyphs.get(code, [0] * 8))
    case = case_table(charset)
    keymap = bytes(normal) + bytes(shift)
    combo = b"".join(bytes(c) for c in combos) + b"\0"

    head = 32
    off_font = head
    off_case = off_font + len(font)
    off_keymap = off_case + len(case)
    off_combos = off_keymap + len(keymap)
    off_msgs = off_combos + len(combo)
    table = bytearray(len(ids).to_bytes(2, "little"))
    strings = bytearray()
    first_string = off_msgs + 2 + 2 * len(ids)
    for ident in ids:
        if ident in msgs:
            table += (first_string + len(strings)).to_bytes(2, "little")
            strings += charset.text(msgs[ident], f"{src}/messages.txt {ident}") + b"\0"
        else:
            table += b"\0\0"
    size = first_string + len(strings)
    if size > MAX_PACK:
        fail(f"{dst}: {size} bytes, the limit is {MAX_PACK}")

    name = charset.text(info["name"], f"{src}/pack.txt name")
    if len(name) > 12:
        fail(f"{src}/pack.txt: name longer than 12 characters")
    header = bytearray(b"VLNG")
    header += bytes([1]) + info["code"].encode("ascii") + b"\0"
    for value in (off_font, off_case, off_keymap, off_combos, off_msgs, size):
        header += value.to_bytes(2, "little")
    header += name.ljust(12, b"\0")
    assert len(header) == head
    data = header + font + case + keymap + combo + table + strings
    assert len(data) == size
    with open(dst, "wb") as f:
        f.write(data)
    print(f"mklng: {dst}: {size} bytes, {len(msgs)}/{len(ids)} messages, "
          f"{len(combos)} combos")


def asm_bytes(data, per_line=16):
    out = []
    for i in range(0, len(data), per_line):
        out.append("        db " + ",".join(f"#{b:02X}" for b in data[i:i + per_line]))
    return out


def build_kernel(src, outdir):
    ascii_cs = Charset("ascii")
    normal, shift, combos = read_keymap(os.path.join(src, "keymap.txt"), ascii_cs)
    if combos:
        fail(f"{src}/keymap.txt: the built-in map cannot have dead keys")
    msgs = read_messages(os.path.join(src, "messages.txt"))
    banner = ["; Generated by tools/mklng.py from lang/en/. Do not edit."]

    ids = banner + [""]
    for i, ident in enumerate(msgs):
        ids.append(f"MSG_{ident:<16} equ {i}")
    ids.append(f"MSG_COUNT{'':<12} equ {len(msgs)}")
    with open(os.path.join(outdir, "msg_ids.inc"), "w", encoding="ascii") as f:
        f.write("\n".join(ids) + "\n")

    out = banner + ["", "; English UI texts, indexed by MSG_<ID>", "msg_en_table:"]
    for ident in msgs:
        out.append(f"        dw msg_en_{ident.lower()}")
    for ident, text in msgs.items():
        out.append(f"msg_en_{ident.lower()}:              ; {text}")
        out += asm_bytes(ascii_cs.text(text, f"{src}/messages.txt {ident}") + b"\0")
    out += ["", "; English keyboard map: key number -> character (0 = none)", "kbd_map:"]
    out += asm_bytes(bytes(normal), 8)
    out.append("kbd_map_shift:")
    out += asm_bytes(bytes(shift), 8)
    with open(os.path.join(outdir, "lang_en.asm"), "w", encoding="ascii") as f:
        f.write("\n".join(out) + "\n")
    print(f"mklng: {outdir}/msg_ids.inc, {outdir}/lang_en.asm: {len(msgs)} messages")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    k = sub.add_parser("kernel")
    k.add_argument("src")
    k.add_argument("outdir")
    p = sub.add_parser("pack")
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--master", required=True)
    args = ap.parse_args()
    if args.cmd == "kernel":
        build_kernel(args.src, args.outdir)
    else:
        build_pack(args.src, args.dst, args.master)


if __name__ == "__main__":
    main()
