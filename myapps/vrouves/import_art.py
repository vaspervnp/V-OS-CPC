#!/usr/bin/env python3
"""import_art - VROUVES' art and stage data, from LET'S GO FOR VROUVES.

usage: import_art.py [path to VrouvesCPC]   (default ~/repos/VrouvesCPC)

Run by hand when the original's art changes; its outputs are kept in
the repo, so building V-OS does not need the original:
  art.asm             the palette and the sprites, as VOS_BLIT draws them:
                      db bytes, rows, then per row (mask, pixels) pairs
  disc/VROUV1.DAT     stage 1, the Kafenio, for the data bank:
     #000  the map: 20 x 14 cell numbers, row by row
     #118  the cell kinds: 0 grass (build), 1 road, 2 blocked (Psssst
           only), 3 the Kafenio and its yard
     #230  the road: db count, then (column, row) waypoints
     #258  the drones' way, the same
     #280  10 waves x 3 groups: db type (1 drone, 2 guard, 3 tank,
           0 none), count, interval (25 Hz ticks)
     #400  the cells: 48 bytes each (8 x 12 pixels, 4 bytes a row)
The original's pens are moved so that the V-OS menu bar (pen 1 white,
text pen 0 black) looks right; both blacks become pen 0.
"""
import os
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/repos/VrouvesCPC")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SRC, "tools"))
os.chdir(SRC)
import art                                  # noqa: E402
import gen_assets as g                      # noqa: E402

# original pen -> V-OS pen (k g o r e W B c y R l s t p h n)
PEN = [0, 2, 3, 4, 5, 1, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0]
PALETTE = [0] * 17
for old, new in enumerate(PEN):
    PALETTE[new] = art.PALETTE_FW[old]
PALETTE[15] = 1                             # spare: dark blue
PALETTE[16] = 0                             # border

SPRITES = [
    ("cretan", art.CRETAN), ("yiayia", art.YIAYIA), ("bride", art.BRIDE),
    ("psssst", art.PSSSST), ("cauldron", art.CAULDRON), ("baker", art.BAKER),
    ("drone_a", art.DRONE_A), ("drone_b", art.DRONE_B),
    ("guard_a", art.GUARD_A), ("guard_b", art.GUARD_B),          # faces right
    ("guard_la", art.mirror(art.GUARD_A)), ("guard_lb", art.mirror(art.GUARD_B)),
    ("tank_va", art.TANK_V_A), ("tank_vb", art.TANK_V_B),
    ("tank_la", art.TANK_L_A), ("tank_lb", art.TANK_L_B),        # faces left
    ("tank_ra", art.mirror(art.TANK_L_A)), ("tank_rb", art.mirror(art.TANK_L_B)),
    ("spark", art.SPARK), ("puff", art.PUFF_A), ("bash", art.BASH_A),
    ("poof", art.POOF_A), ("boom", art.BOOM_A), ("zap", art.ZAP_A),
    ("cursor_ok", art.CURSOR_OK), ("cursor_bad", art.CURSOR_BAD),
]


def pen_of(ch):
    return PEN[art.CH[ch]]


def sprite_lines(name, rows):
    w, h = len(rows[0]), len(rows)
    if w % 2:
        rows = [r + "." for r in rows]
        w += 1
    out = [f"spr_{name}:", f"        db {w // 2}, {h}"]
    for r in rows:
        b = []
        for x in range(0, w, 2):
            p, m = [], []
            for ch in r[x:x + 2]:
                m.append(0 if ch == "." else 15)
                p.append(0 if ch == "." else pen_of(ch))
            b += [g.enc_byte(m[0], m[1]), g.enc_byte(p[0], p[1])]
        out.append("        db " + ", ".join("#%02X" % v for v in b) + f"   ; {r}")
    return out


def stage_file(st, waves):
    grid = g.carve_path(st.map, st.ground)
    cv = g.render_background(st, grid)
    cells, index = [], {}
    cmap = []
    for r in range(g.MH):
        for c in range(g.MW):
            data = []
            for y in range(g.TH):
                for x in range(0, g.TW, 2):
                    p0 = PEN[cv.get(c * g.TW + x, r * g.TH + y)]
                    p1 = PEN[cv.get(c * g.TW + x + 1, r * g.TH + y)]
                    data.append(g.enc_byte(p0, p1))
            data = bytes(data)
            if data not in index:
                index[data] = len(cells)
                cells.append(data)
            cmap.append(index[data])
    assert len(cells) <= 256
    kinds = []
    for r in range(g.MH):
        for c in range(g.MW):
            t = grid[r][c]
            kinds.append(0 if t in ".F" else 1 if t == "#" else 3 if t in "KP" else 2)
    out = bytearray(0x400)
    out[0:280] = bytes(cmap)
    out[0x118:0x118 + 280] = bytes(kinds)

    def way(at, wps):
        out[at] = len(wps)
        for k, (c, r) in enumerate(wps):
            out[at + 1 + 2 * k] = c
            out[at + 2 + 2 * k] = r
        assert len(wps) <= 19
    way(0x230, st.ground)
    way(0x258, st.air)
    at = 0x280
    for w in waves:
        assert len(w) <= 3
        for k in range(3):
            t, n, i = w[k] if k < len(w) else (0, 0, 0)
            out[at:at + 3] = bytes([t, n, i])
            at += 3
    return bytes(out) + b"".join(cells), len(cells)


def main():
    lines = ["; made by myapps/vrouves/import_art.py from LET'S GO FOR VROUVES",
             "; (tools/art.py): do not edit",
             "palette:        db " + ", ".join(str(c) for c in PALETTE)]
    for name, rows in SPRITES:
        lines += sprite_lines(name, rows)
    open(os.path.join(HERE, "art.asm"), "w").write("\n".join(lines) + "\n")
    data, n = stage_file(g.STAGES[0], g.WAVES1)
    os.makedirs(os.path.join(HERE, "disc"), exist_ok=True)
    open(os.path.join(HERE, "disc", "VROUV1.DAT"), "wb").write(data)
    print(f"art.asm: {len(SPRITES)} sprites; VROUV1.DAT: {n} cells, {len(data)} bytes")


if __name__ == "__main__":
    main()
