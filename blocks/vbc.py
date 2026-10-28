#!/usr/bin/env python3
"""vbc - the V-OS block compiler: a block program (.vbp, JSON) to Z80.

usage: vbc.py program.vbp [-o build] [--asm-only] [--dsk build/vos.dsk]

Writes <o>/<NAME>.ASM, a readable program for the V-OS API (one comment
per block), assembles it with RASM into <o>/<NAME>.BIN and, with --dsk,
puts it on that disc image with iDSK. The program runs blocks/runtime.asm:
scripts are coroutines, sprites are coloured rectangles.

Program (JSON):
  {"name": "PONG", "mode": 0, "background": 0, "ink": 1,
   "sprites": [{"name": "ball", "x": 90, "y": 100, "w": 6, "h": 6,
                "colour": 8, "vx": 2, "vy": 2, "visible": true}],
   "variables": {"score": 0},
   "scripts": [{"sprite": "ball", "when": {"event": "start"},
                "do": [statement, ...]}]}

Events: start; key (with "key": a letter, digit, or up down left right
space return enter copy tab del any); click (the script's sprite, or the
stage for a stage script); receive (with "message").

Statements ({"block": ...}): forever {do}, repeat {times, do},
if {cond, then, else}, wait {frames}, wait_until {cond}, stop, stop_all,
set {var, to}, change {var, by}, broadcast {message},
go_to {x, y}, set_x {to}, set_y {to}, change_x {by}, change_y {by},
set_velocity {vx, vy}, move, bounce, set_colour {to}, set_size {w, h},
show, hide, print {text or value, x, y}, text_colour {to}, clear.

Expressions: a number; {"var": name}; {"op": + - * / mod < > = and or,
"a": E, "b": E}; {"not": E}; {"random": [E, E]}; {"key_held": key};
{"touching": sprite}; {"at_edge": true}; {"prop": x y vx vy w h colour
visible, "of": sprite (default: the script's)}; {"frames": true}.
Numbers are 16-bit signed; comparisons give 1 or 0. Text is written in
ISO 8859-7, so Greek works with the Greek pack.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
STACK_SIZE = 128
SP_SIZE = 18
PROPS = {"x": (0, 2), "y": (2, 2), "vx": (4, 2), "vy": (6, 2), "w": (8, 1),
         "h": (9, 1), "colour": (10, 1), "visible": (11, 1)}
EVENTS = {"start": 0, "key": 1, "click": 2, "receive": 3}
NAMED_KEYS = {"up": 0, "right": 1, "down": 2, "enter": 6, "left": 8,
              "copy": 9, "return": 18, "space": 47, "tab": 68, "del": 79,
              "any": 0xFF}
OPS = {"+": ["add hl,de"], "-": ["ex de,hl", "or a", "sbc hl,de"],
       "*": ["call rt_mul"], "/": ["call rt_div"], "mod": ["call rt_mod"],
       "<": ["call rt_lt"], ">": ["call rt_gt"], "=": ["call rt_eq"],
       "and": ["call rt_and"], "or": ["call rt_or"]}
PALETTE = {0: [0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16, 0],
           1: [1, 26, 0, 11] + [0] * 12 + [0]}


class Error(Exception):
    pass


def char_keys():
    """characters -> key numbers, from lang/en/keymap.txt"""
    keys = {}
    path = os.path.join(ROOT, "lang", "en", "keymap.txt")
    for line in open(path, encoding="utf-8"):
        part = line.split("#", 1)[0].split() if not line.startswith("#") else []
        if len(part) >= 3 and part[0] == "key" and len(part[2]) == 1:
            keys.setdefault(part[2].lower(), int(part[1]))
    return keys


class Compiler:
    def __init__(self, prog):
        self.prog = prog
        self.name = re.sub(r"[^A-Z0-9]", "", str(prog.get("name", "PROGRAM")).upper())[:8]
        if not self.name:
            raise Error("the program needs a name (letters and digits)")
        self.mode = prog.get("mode", 0)
        if self.mode not in (0, 1):
            raise Error("mode must be 0 or 1")
        self.sprites = prog.get("sprites", [])
        self.sprite_index = {}
        for i, s in enumerate(self.sprites):
            if s.get("name") in self.sprite_index:
                raise Error(f"two sprites called {s.get('name')}")
            self.sprite_index[s.get("name")] = i
        self.vars = {}
        for i, (name, value) in enumerate(prog.get("variables", {}).items()):
            self.vars[name] = (f"var_{i}", int(value))
        self.messages = {}
        self.keys = char_keys()
        self.code = []
        self.labels = 0
        self.counters = 0
        self.strings = []

    # ---- helpers -----------------------------------------------------
    def emit(self, *lines):
        self.code += ["        " + l for l in lines]

    def label(self):
        self.labels += 1
        return f"l{self.labels}"

    def put_label(self, name):
        self.code.append(f"{name}:")

    def key(self, name):
        name = str(name).lower()
        if name in NAMED_KEYS:
            return NAMED_KEYS[name]
        if name in self.keys:
            return self.keys[name]
        raise Error(f"unknown key: {name}")

    def message(self, name):
        if name not in self.messages:
            self.messages[name] = len(self.messages)
        return self.messages[name]

    def sprite(self, name, own):
        if name is None:
            if own is None:
                raise Error("a stage script has no sprite of its own")
            return own
        if name not in self.sprite_index:
            raise Error(f"unknown sprite: {name}")
        return self.sprite_index[name]

    def var(self, name):
        if name not in self.vars:
            raise Error(f"unknown variable: {name}")
        return self.vars[name][0]

    def string(self, text):
        self.strings.append(text)
        return f"str_{len(self.strings) - 1}"

    # ---- expressions: the value in HL --------------------------------
    def expr(self, e, own):
        if isinstance(e, bool):
            e = int(e)
        if isinstance(e, int):
            if not -32768 <= e <= 65535:
                raise Error(f"number out of range: {e}")
            self.emit(f"ld hl,{e & 0xFFFF}")
        elif not isinstance(e, dict):
            raise Error(f"not an expression: {e!r}")
        elif "var" in e:
            self.emit(f"ld hl,({self.var(e['var'])})")
        elif "op" in e:
            if e["op"] not in OPS:
                raise Error(f"unknown operator: {e['op']}")
            self.expr(e["a"], own)
            self.emit("push hl")
            self.expr(e["b"], own)
            self.emit("pop de", *OPS[e["op"]])
        elif "not" in e:
            self.expr(e["not"], own)
            self.emit("call rt_not")
        elif "random" in e:
            low, high = e["random"]
            self.expr(low, own)
            self.emit("push hl")
            self.expr(high, own)
            self.emit("ex de,hl", "pop hl", "call rt_random")
        elif "key_held" in e:
            self.emit(f"ld a,{self.key(e['key_held'])}", "call rt_key_held")
        elif "touching" in e:
            a = self.sprite(None, own)
            b = self.sprite(e["touching"], own)
            self.emit(f"ld ix,spr_{a}", f"ld iy,spr_{b}", "call rt_touching")
        elif "at_edge" in e:
            self.emit(f"ld ix,spr_{self.sprite(None, own)}", "call rt_at_edge")
        elif "prop" in e:
            if e["prop"] not in PROPS:
                raise Error(f"unknown property: {e['prop']}")
            off, size = PROPS[e["prop"]]
            s = self.sprite(e.get("of"), own)
            if size == 2:
                self.emit(f"ld hl,(spr_{s} + {off})")
            else:
                self.emit(f"ld a,(spr_{s} + {off})", "ld l,a", "ld h,0")
        elif "frames" in e:
            self.emit("call VOS_FRAMES")
        else:
            raise Error(f"unknown expression: {json.dumps(e)}")

    def cond(self, e, own, false_label):
        self.expr(e, own)
        self.emit("ld a,h", "or l", f"jp z,{false_label}")

    # ---- statements --------------------------------------------------
    def body(self, statements, own):
        for st in statements or []:
            self.stmt(st, own)

    def stmt(self, st, own):
        b = st.get("block")
        self.code.append(f"; {b} {json.dumps({k: v for k, v in st.items() if k not in ('block', 'do', 'then', 'else')}, ensure_ascii=False)}")
        if b == "forever":
            top = self.label()
            self.put_label(top)
            self.body(st.get("do"), own)
            self.emit("call rt_yield", f"jp {top}")
        elif b == "repeat":
            self.counters += 1
            counter = f"cnt_{self.counters}"
            top, end = self.label(), self.label()
            self.expr(st["times"], own)
            self.emit(f"ld ({counter}),hl")
            self.put_label(top)
            self.emit(f"ld hl,({counter})", "ld a,h", "or l", f"jp z,{end}",
                      "dec hl", f"ld ({counter}),hl")
            self.body(st.get("do"), own)
            self.emit("call rt_yield", f"jp {top}")
            self.put_label(end)
        elif b == "if":
            other, end = self.label(), self.label()
            self.cond(st["cond"], own, other)
            self.body(st.get("then"), own)
            self.emit(f"jp {end}")
            self.put_label(other)
            self.body(st.get("else"), own)
            self.put_label(end)
        elif b == "wait":
            self.expr(st["frames"], own)
            self.emit("call rt_wait")
        elif b == "wait_until":
            top, end = self.label(), self.label()
            self.put_label(top)
            self.expr(st["cond"], own)
            self.emit("ld a,h", "or l", f"jp nz,{end}", "call rt_yield", f"jp {top}")
            self.put_label(end)
        elif b == "stop":
            self.emit("jp rt_end")
        elif b == "stop_all":
            self.emit("call VOS_EXIT", "jp rt_end")
        elif b == "set":
            self.expr(st["to"], own)
            self.emit(f"ld ({self.var(st['var'])}),hl")
        elif b == "change":
            self.expr(st["by"], own)
            v = self.var(st["var"])
            self.emit(f"ld de,({v})", "add hl,de", f"ld ({v}),hl")
        elif b == "broadcast":
            self.emit(f"ld a,{self.message(st['message'])}", "call rt_broadcast")
        elif b in ("go_to", "set_velocity"):
            s = self.sprite(None, own)
            first, second = ("x", "y") if b == "go_to" else ("vx", "vy")
            self.expr(st[first], own)
            self.emit(f"ld (spr_{s} + {PROPS[first][0]}),hl")
            self.expr(st[second], own)
            self.emit(f"ld (spr_{s} + {PROPS[second][0]}),hl")
        elif b in ("set_x", "set_y"):
            s = self.sprite(None, own)
            self.expr(st["to"], own)
            self.emit(f"ld (spr_{s} + {PROPS[b[-1]][0]}),hl")
        elif b in ("change_x", "change_y"):
            s = self.sprite(None, own)
            off = PROPS[b[-1]][0]
            self.expr(st["by"], own)
            self.emit(f"ld de,(spr_{s} + {off})", "add hl,de", f"ld (spr_{s} + {off}),hl")
        elif b in ("move", "bounce"):
            self.emit(f"ld ix,spr_{self.sprite(None, own)}", f"call rt_{b}")
        elif b in ("set_colour", "show", "hide"):
            s = self.sprite(None, own)
            if b == "set_colour":
                self.expr(st["to"], own)
                self.emit("ld a,l", f"ld (spr_{s} + {PROPS['colour'][0]}),a")
            else:
                self.emit(f"ld a,{int(b == 'show')}", f"ld (spr_{s} + {PROPS['visible'][0]}),a")
        elif b == "set_size":
            s = self.sprite(None, own)
            self.emit(f"ld ix,spr_{s}", "call rt_erase")
            for p in ("w", "h"):
                self.expr(st[p], own)
                self.emit("ld a,l", f"ld (spr_{s} + {PROPS[p][0]}),a")
        elif b == "print":
            if "text" in st:
                self.expr(st["x"], own)
                self.emit("push hl")
                self.expr(st["y"], own)
                self.emit("ex de,hl", "pop hl", f"ld bc,{self.string(str(st['text']))}",
                          "call rt_print")
            else:
                self.expr(st["x"], own)
                self.emit("ld (rt_px),hl")
                self.expr(st["y"], own)
                self.emit("ld (rt_py),hl")
                self.expr(st["value"], own)
                self.emit("call rt_print_number")
        elif b == "text_colour":
            self.expr(st["to"], own)
            self.emit("ld a,l", "ld (rt_ink),a")
        elif b == "clear":
            self.emit("call rt_clear")
        else:
            raise Error(f"unknown block: {b}")

    # ---- the program -------------------------------------------------
    def compile(self):
        scripts = self.prog.get("scripts", [])
        if not scripts:
            raise Error("the program has no scripts")
        table = []
        for n, sc in enumerate(scripts):
            own = None
            if sc.get("sprite") is not None:
                own = self.sprite(sc["sprite"], None)
            when = sc.get("when", {"event": "start"})
            event = when.get("event")
            if event not in EVENTS:
                raise Error(f"unknown event: {event}")
            param = 0
            if event == "key":
                param = self.key(when.get("key"))
            elif event == "click":
                param = 0xFF if own is None else own
            elif event == "receive":
                param = self.message(when.get("message"))
            table.append((n, 0xFF if own is None else own, EVENTS[event], param, event))
            self.code.append("")
            self.code.append(f"; ---- script {n}: when {event}"
                             f"{' ' + str(when.get('key') or when.get('message') or '') if event in ('key', 'receive') else ''}"
                             f", {'stage' if own is None else 'sprite ' + self.sprites[own]['name']}")
            self.code.append(f"script_{n}:")
            self.body(sc.get("do"), own)
            self.emit("jp rt_end")
        return self.listing(table)

    def listing(self, table):
        p = self.prog
        palette = p.get("palette", PALETTE[self.mode])
        if len(palette) != 17:
            raise Error("the palette needs 17 colours (16 pens and the border)")
        out = [
            f"; {self.name}.ASM - made by blocks/vbc.py from a block program.",
            "; Do not edit: change the program and compile it again.",
            "",
            '        include "api/vos_api.inc"',
            "",
            f"PROG_MODE       equ {self.mode}",
            f"PROG_BG         equ {int(p.get('background', 0))}",
            f"PROG_WIDTH      equ {192 if self.mode == 0 else 384}",
            f"SCRIPT_COUNT    equ {len(table)}",
            f"SPRITE_COUNT    equ {len(self.sprites)}",
            "",
            "        org VOS_APP_ADDR",
            "        jp rt_init",
            "        jp rt_event",
            "        jp rt_redraw",
            '        db "VA", VOS_API_VERSION',
            "",
            '        include "runtime.asm"',
            "",
            "rt_and:                             ; DE and HL -> 1 or 0",
            "        ld a,h",
            "        or l",
            "        jp z,rt_false",
            "rt_bool:",
            "        ld a,d",
            "        or e",
            "        jp z,rt_false",
            "        jp rt_true",
            "rt_or:",
            "        ld a,h",
            "        or l",
            "        jp nz,rt_true",
            "        jr rt_bool",
            "rt_not:",
            "        ld a,h",
            "        or l",
            "        jp z,rt_true",
            "        jp rt_false",
        ]
        out += self.code
        out += ["", "; ---- tables", "prog_palette:    db " + ", ".join(map(str, palette)),
                "prog_scripts:                       ; code, stack top, sprite, event, parameter"]
        for n, sprite, event, param, name in table:
            out.append(f"        dw script_{n}, rt_stacks + {n + 1} * {STACK_SIZE}"
                       f" : db {sprite}, {event}, {param}  ; {name}")
        out.append("prog_sprites:")
        for i, s in enumerate(self.sprites):
            vals = [int(s.get(k, d)) for k, d in (("x", 0), ("y", 100), ("vx", 0), ("vy", 0))]
            out.append(f"spr_{i}:                             ; {s.get('name')}")
            out.append("        dw " + ", ".join(str(v & 0xFFFF) for v in vals))
            out.append(f"        db {int(s.get('w', 8))}, {int(s.get('h', 8))}, "
                       f"{int(s.get('colour', 1))}, {int(bool(s.get('visible', True)))}")
            out.append("        dw 0, 0 : db 0, 0")
        if not self.sprites:
            out.append("        db 0")
        for name, (label, value) in self.vars.items():
            out.append(f"{label}:          dw {value & 0xFFFF}   ; {name}")
        for i in range(1, self.counters + 1):
            out.append(f"cnt_{i}:          dw 0")
        for i, text in enumerate(self.strings):
            try:
                data = text.upper().encode("iso8859_7")
            except UnicodeEncodeError:
                raise Error(f"text outside ISO 8859-7: {text}")
            out.append(f"str_{i}:          db " + ", ".join(str(c) for c in data + b"\0")
                       + f"   ; {text}")
        out += [f"rt_state:        ds SCRIPT_COUNT * ST_SIZE",
                f"rt_stacks:       ds SCRIPT_COUNT * STACK_SIZE",
                "prog_end:",
                "        assert prog_end <= VOS_APP_ADDR + #4000",
                f'        save "{self.out_bin}", VOS_APP_ADDR, prog_end - VOS_APP_ADDR']
        return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("program")
    ap.add_argument("-o", "--out", default=os.path.join(ROOT, "build"))
    ap.add_argument("--asm-only", action="store_true")
    ap.add_argument("--dsk")
    args = ap.parse_args()
    try:
        prog = json.load(open(args.program, encoding="utf-8"))
        c = Compiler(prog)
        os.makedirs(args.out, exist_ok=True)
        asm_path = os.path.join(args.out, c.name + ".ASM")
        c.out_bin = os.path.join(args.out, c.name + ".BIN")
        text = c.compile()
    except (Error, KeyError, ValueError, TypeError) as e:
        sys.exit(f"vbc: {args.program}: {e}")
    with open(asm_path, "w", encoding="ascii", errors="replace") as f:
        f.write(text)
    print(f"vbc: {asm_path}")
    if args.asm_only:
        return
    rasm = shutil.which("rasm")
    if not rasm:
        sys.exit("vbc: rasm not found (use --asm-only)")
    r = subprocess.run([rasm, asm_path, "-I", os.path.join(ROOT, "src"), "-I", HERE,
                        "-o", os.path.join(args.out, c.name.lower())],
                       capture_output=True, text=True)
    if r.returncode or not os.path.exists(c.out_bin):
        sys.exit("vbc: rasm failed:\n" + r.stdout + r.stderr)
    print(f"vbc: {c.out_bin}, {os.path.getsize(c.out_bin)} bytes")
    if args.dsk:
        idsk = shutil.which("iDSK")
        if not idsk:
            sys.exit("vbc: iDSK not found")
        subprocess.run([idsk, args.dsk, "-r", c.name + ".BIN"], capture_output=True)
        r = subprocess.run([idsk, args.dsk, "-i", c.out_bin, "-t", "1", "-c", "4000",
                            "-e", "4000"], capture_output=True, text=True)
        if r.returncode:
            sys.exit("vbc: iDSK failed:\n" + r.stdout + r.stderr)
        print(f"vbc: {c.name}.BIN on {args.dsk}")


if __name__ == "__main__":
    main()
