#!/usr/bin/env python3
"""voscv - text files between a PC and the V-OS character set.

usage: voscv.py to-vos   [--from CODEC] [--crlf] in out
       voscv.py from-vos [--to CODEC] [--lf] in out
       voscv.py check    file...

to-vos    a PC file (UTF-8 by default; also latin-1, cp1252,
          iso8859-7, cp1253 or any Python codec) into the V-OS set
          (tools/voscs.py), for NOTEPAD, READER, MARKDOWN and the
          databases; --crlf ends its lines with CR LF, as NOTEPAD
          saves them. A character V-OS has not becomes "?", and each is
          listed.
from-vos  a file from V-OS into UTF-8 (or --to CODEC) for the PC; --lf
          ends its lines with LF alone.
check     each file: ASCII, UTF-8 (V-OS converts it, VX_UTF8), or 8
          bits (what it holds as V-OS: Greek, Latin letters).

Put a file on a disc image with iDSK: iDSK disc.dsk -i out -t 0.
A Greek file in ISO 8859-7 is V-OS already.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voscs  # noqa: E402  (the codec "vos")


def to_vos(data, codec, crlf):
    text = data.decode(codec).replace("﻿", "")
    missing = sorted({c for c in text if c not in voscs.ENCODE})
    if crlf:
        text = text.replace("\r\n", "\n").replace("\n", "\r\n")
    return text.encode("vos", errors="replace"), missing


def from_vos(data, codec, lf):
    text = data.decode("vos")
    if lf:
        text = text.replace("\r\n", "\n")
    return text.encode(codec)


def kind(data):
    if all(b < 128 for b in data):
        return "ASCII (the same in V-OS)"
    try:
        data.decode("utf-8")
        return "UTF-8 (V-OS converts it when it opens it)"
    except UnicodeDecodeError:
        pass
    text = data.decode("vos")
    greek = any("Ͱ" <= c <= "Ͽ" for c in text)
    latin = any("À" <= c <= "ÿ" for c in text)
    what = " and ".join(w for w, on in (("Greek", greek), ("Latin letters", latin)) if on)
    return ("8 bits: as V-OS it holds %s (a file in Latin-1 or cp1252 needs "
            "to-vos --from latin-1)" % (what or "signs only"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("to-vos")
    t.add_argument("--from", dest="codec", default="utf-8")
    t.add_argument("--crlf", action="store_true")
    t.add_argument("src")
    t.add_argument("dst")
    f = sub.add_parser("from-vos")
    f.add_argument("--to", dest="codec", default="utf-8")
    f.add_argument("--lf", action="store_true")
    f.add_argument("src")
    f.add_argument("dst")
    c = sub.add_parser("check")
    c.add_argument("files", nargs="+")
    a = ap.parse_args()
    if a.cmd == "check":
        for name in a.files:
            print("%s: %s" % (name, kind(open(name, "rb").read())))
        return
    data = open(a.src, "rb").read()
    try:
        if a.cmd == "to-vos":
            out, missing = to_vos(data, a.codec, a.crlf)
            for ch in missing:
                print("voscv: %r (U+%04X) is not in V-OS: ?" % (ch, ord(ch)), file=sys.stderr)
        else:
            out = from_vos(data, a.codec, a.lf)
    except (UnicodeDecodeError, UnicodeEncodeError, LookupError) as e:
        sys.exit("voscv: %s: %s" % (a.src, e))
    open(a.dst, "wb").write(out)
    print("voscv: %s -> %s, %d bytes" % (a.src, a.dst, len(out)))


if __name__ == "__main__":
    main()
