#!/usr/bin/env python3
"""mkbricks - writes blocks/examples/bricks.vbp, the BRICKS game for
blocks/vbc.py: 32 bricks are 32 sprites, each with the same script,
which is long to write out by hand.

usage: mkbricks.py blocks/examples/bricks.vbp
"""
import json, sys
V = lambda n: {"var": n}
P = lambda p, of=None: dict({"prop": p}, **({"of": of} if of else {}))
op = lambda o, a, b: {"op": o, "a": a, "b": b}
B = lambda name, **kw: dict({"block": name}, **kw)
IF = lambda c, t, e=None: dict({"block": "if", "cond": c, "then": t}, **({"else": e} if e else {}))

ROWS = [(10, 4), (9, 3), (8, 2), (6, 1)]       # pen, points
sprites = [
    {"name": "ball", "x": 94, "y": 200, "w": 4, "h": 4, "colour": 1, "visible": False},
    {"name": "bat", "x": 80, "y": 236, "w": 32, "h": 6, "colour": 4},
]
scripts = []
for r, (pen, pts) in enumerate(ROWS):
    for c in range(8):
        name = f"b{r}{c}"
        sprites.append({"name": name, "x": 1 + 24 * c, "y": 40 + 12 * r,
                        "w": 22, "h": 8, "colour": pen, "visible": False})
        scripts.append({"sprite": name, "when": {"event": "receive", "message": "level"}, "do": [
            B("show"),
            B("wait_until", cond={"touching": "ball"}),
            B("hide"),
            B("change", var="score", by=pts),
            B("change", var="left", by=-1),
            B("broadcast", message="hit"),
        ]})

stage = [
    {"when": {"event": "start"}, "do": [
        B("print", text="SCORE", x=4, y=16),
        B("print", text="LIVES", x=116, y=16),
        B("broadcast", message="new"),
    ]},
    {"when": {"event": "receive", "message": "new"}, "do": [
        B("set", var="score", to=0),
        B("set", var="lives", to=3),
        B("set", var="level", to=0),
        B("print", text="         ", x=60, y=140),
        B("print", text="            ", x=48, y=156),
        B("broadcast", message="level"),
    ]},
    {"when": {"event": "receive", "message": "level"}, "do": [
        B("set", var="left", to=32),
        B("change", var="level", by=1),
        B("broadcast", message="show"),
    ]},
    {"when": {"event": "receive", "message": "show"}, "do": [
        B("print", value=V("score"), x=60, y=16),
        B("print", text="  ", x=176, y=16),
        B("print", value=V("lives"), x=176, y=16),
    ]},
    {"when": {"event": "key", "key": "space"}, "do": [
        IF(op("=", V("lives"), 0), [B("broadcast", message="new")]),
    ]},
]

ball = [
    # a new level: the ball served from the bat, again after each life
    # lost (a script may not send itself a message: it would start again)
    {"sprite": "ball", "when": {"event": "receive", "message": "level"}, "do": [
        B("set", var="serve", to=1),
        B("forever", do=[
            IF(op("=", V("serve"), 1), [
                B("hide"),
                B("go_to", x=op("+", P("x", "bat"), 14), y=228),
                B("wait", frames=40),
                B("go_to", x=op("+", P("x", "bat"), 14), y=228),
                B("set_velocity", vx={"random": [-2, 2]},
                  vy=op("-", 0, op("+", 2, V("level")))),
                IF(op("=", P("vx"), 0), [B("set_velocity", vx=1, vy=P("vy"))]),
                IF(op("<", P("vy"), -5), [B("set_velocity", vx=P("vx"), vy=-5)]),
                B("show"),
                B("set", var="serve", to=0),
            ]),
            B("move"),
            B("bounce"),
            IF(op("and", {"touching": "bat"}, op(">", P("vy"), 0)), [
                B("set_velocity",
                  vx=op("/", op("-", P("x"), op("+", P("x", "bat"), 14)), 4),
                  vy=op("-", 0, P("vy"))),
                IF(op("=", P("vx"), 0), [B("set_velocity", vx=1, vy=P("vy"))]),
                B("start_note", note=72, frames=2, channel=0),
            ]),
            IF(op(">", P("y"), 244), [
                B("hide"),
                B("change", var="lives", by=-1),
                B("broadcast", message="show"),
                B("noise", pitch=20, frames=10, channel=1),
                IF(op("=", V("lives"), 0), [
                    B("print", text="GAME OVER", x=60, y=140),
                    B("print", text="SPACE: AGAIN", x=48, y=156),
                    B("stop"),
                ]),
                B("set", var="serve", to=1),
            ]),
        ]),
    ]},
    # a brick: back the way it came, and the next level when none is left
    {"sprite": "ball", "when": {"event": "receive", "message": "hit"}, "do": [
        B("set_velocity", vx=P("vx"), vy=op("-", 0, P("vy"))),
        B("broadcast", message="show"),
        B("start_note", note=84, frames=2, channel=2),
        IF(op("=", V("left"), 0), [
            B("hide"),
            B("wait", frames=50),
            B("broadcast", message="level"),
        ]),
    ]},
    {"sprite": "bat", "when": {"event": "start"}, "do": [
        B("forever", do=[
            IF({"key_held": "left"}, [B("change_x", by=-4)]),
            IF({"key_held": "right"}, [B("change_x", by=4)]),
            IF(op("<", P("x"), 0), [B("set_x", to=0)]),
            IF(op(">", P("x"), 160), [B("set_x", to=160)]),
        ]),
    ]},
]

prog = {"format": "vbp", "version": 1, "name": "BRICKS", "mode": 0, "background": 0,
        "sprites": sprites,
        "variables": {"score": 0, "lives": 3, "level": 0, "left": 32, "serve": 0},
        "scripts": stage + ball + scripts}
json.dump(prog, open(sys.argv[1], "w"), ensure_ascii=False, indent=1)
