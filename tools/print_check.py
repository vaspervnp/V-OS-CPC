#!/usr/bin/env python3
"""print_check.py - make test-print: the text NOTEPAD prints, and what
the printer must get.

  print_check.py text PRINT.TXT T.VSH   NOTEPAD's text and SHEET's sheet
                                   for drive B: (CR LF, ^Z)
  print_check.py check printer.txt Caprice32's printer file against them:
                                   NOTEPAD's lines with CR LF, the letters
                                   over 127 as plain ASCII, a new page;
                                   then SHEET's cells as its page shows
                                   them, A-H and I-P, a new page; each
                                   page with its heading ("PRINT.TXT
                                   PAGE 1"), a new page after 60 lines
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voscs                        # noqa: E402

TEXT = ["Hello, printer!",
        "Καλημέρα κόσμε: ΘΞΨ θξψ ς",
        "Été, señor, Grüße, città «€»"] + [str(n) for n in range(4, 66)]
PAGE_LINES = 60                     # kernel/ext2.asm: PRT_LINES


# the sheet: a cell, its text, and what it shows (a number on the right)
CELLS = [("A1", "ΤΙΜΕΣ", "ΤΙΜΕΣ"), ("B1", "Été", "Été"),
         ("A2", "12", 12), ("A3", "30", 30), ("A4", "=SUM(A2:A3)", 42),
         ("B2", "=A2*2", 24), ("J2", "ok", "ok")]
NUM_W, CELL_W, PR_COLS = 3, 9, 8


def plain(text):
    return "".join(chr(c) if c < 128 else voscs.ascii_of(c)
                   for c in text.encode("vos")).encode()


def sheet():
    out = b""
    for left in (0, 8):
        shown = {}
        for name, _, value in CELLS:
            col, row = ord(name[0]) - 65, int(name[1:]) - 1
            if left <= col < left + PR_COLS:
                cell = (str(value).rjust(CELL_W - 1) if isinstance(value, int)
                        else value[:CELL_W - 1])
                shown[row, col - left] = cell
        if not shown:
            continue
        head = list(" " * (NUM_W + PR_COLS * CELL_W))
        for i in range(PR_COLS):
            head[NUM_W + 4 + i * CELL_W] = chr(65 + left + i)
        out += plain("".join(head).rstrip()) + b"\r\n"
        for row in range(max(r for r, _ in shown) + 1):
            line = list(str(row + 1).rjust(2).ljust(NUM_W + PR_COLS * CELL_W))
            for (r, c), cell in shown.items():
                if r == row:
                    at = NUM_W + c * CELL_W
                    line[at:at + len(cell)] = cell
            out += plain("".join(line).rstrip()) + b"\r\n"
    return out + b"\x0c"


def pages(title, data):
    """data as VX_PRINT sends it after a start with title: a heading
    before the first byte of each page, a form feed after its 60th line"""
    out, line, page, head = b"", 0, 1, True
    for c in data:
        if head and c != 12:
            out += title + b"  PAGE %d\r\n\r\n" % page
            line, head = 2, False
        out += bytes([c])
        if c == 10:
            line += 1
            if line >= PAGE_LINES:
                out += b"\x0c"
                c = 12
        if c == 12:
            line, page, head = 0, page + 1, True
    return out


def expected():
    out = b""
    for line in TEXT:
        out += plain(line) + b"\r\n"
    return pages(b"PRINT.TXT", out + b"\x0c") + pages(b"T.VSH", sheet())


if __name__ != "__main__":
    pass
elif sys.argv[1] == "text":
    data = "\r\n".join(TEXT).encode("vos") + b"\r\n\x1a"
    open(sys.argv[2], "wb").write(data)
    data = "".join("%s %s\r\n" % (n, t) for n, t, _ in CELLS)
    open(sys.argv[3], "wb").write(data.encode("vos") + b"\x1a")
else:
    got = open(sys.argv[2], "rb").read() if os.path.exists(sys.argv[2]) else b""
    want = expected()
    if got != want:
        print("printer: got\n%s\nwant\n%s" % (got.decode("latin-1"),
                                              want.decode("latin-1")))
        sys.exit(1)
    print("printer: %d bytes as expected:\n%s" % (len(got), got.decode()))
