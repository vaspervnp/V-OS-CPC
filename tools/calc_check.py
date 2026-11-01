#!/usr/bin/env python3
"""Check the formula engine (make test-calc-sys).

usage: calc_check.py calc.bin calc.sym [formulas [seed]]

Runs src/calc/calc.asm, built with -DCALC_HARNESS (with its symbols),
in a Z80 emulator (the z80 package); a program's memory is plain RAM.
A model in Python reads formulas the same way, left to right, and every
call is checked against it: fixed cases first (numbers, rounding,
functions, ranges, errors), then random formulas over a random grid of
numbers, empty cells and cells with errors, random texts for
CALC_NUMBER, CALC_TEXT and CALC_CELL. Exits 1 on the first difference.
"""
import random
import sys

CALL = 0x0100                   # calc_call is called from here
CB = 0x8F00                     # the program's block, text, room, grid
TEXT = 0x8E00
ROOM = 0x8D00
GRID = 0x9000
EVAL, NUMBER, TEXTC, CELL = 0, 1, 2, 3
SYNTAX, DIV0, BIG, REF, VALUE, BAD_CALL = 30, 31, 32, 33, 34, 26
LIMIT = 2147483646
NONE, BADV = -0x80000000, -0x7FFFFFFF
DEPTH = 8


class Engine:
    def __init__(self, prog, sym):
        import z80
        self.m = z80.Z80Machine()
        mem = bytearray(65536)
        a = sym['CALC_START']
        mem[a:a + len(prog)] = prog
        mem[CALL:CALL + 5] = bytes([0xCD, a & 255, a >> 8, 0x18, 0xFE])
        self.m.set_memory_block(0, bytes(mem))
        self.m.set_breakpoint(CALL + 3)

    def call(self, c, de=CB, hl=TEXT):
        m = self.m
        m.sp, m.pc, m.bc, m.de, m.hl = 0xBF00, CALL, c, de, hl
        for _ in range(100):
            m.ticks_to_stop = 50000000
            m.run()
            if m.pc == CALL + 3:
                if m.sp != 0xBF00:
                    fail('call %d: the stack at %04X' % (c, m.sp))
                return (m.f & 1) == 1, m.a, m.de, m.hl
        fail('call %d did not return' % c)

    def poke(self, a, data):
        self.m.set_memory_block(a, bytes(data))

    def peek(self, a, n):
        return bytes(self.m.memory[a:a + n])


def fail(msg):
    sys.exit('calc_check: ' + msg)


def u32(v):
    return v & 0xFFFFFFFF


def s32(v):
    return v - (1 << 32) if v & 0x80000000 else v


class Err(Exception):
    pass


def rdiv(a, b, rnd=True):
    """round(|a| / |b|) half up, with the sign; -> (q, remainder)"""
    if b == 0:
        raise Err(DIV0)
    sign = (a < 0) != (b < 0)
    a, b = abs(a), abs(b)
    q, r = divmod(a + (b // 2 if rnd else 0), b)
    if q > LIMIT:
        raise Err(BIG)
    return (-q if sign else q), r


def fit(v):
    if not -LIMIT <= v <= LIMIT:
        raise Err(BIG)
    return v


class Model:
    """the engine's reading of a formula, step by step"""

    FUNCS = ['SUM', 'AVG', 'MIN', 'MAX', 'COUNT', 'ABS', 'INT', 'ROUND']

    def __init__(self, cols, rows, grid):
        self.cols, self.rows, self.grid = cols, rows, grid

    def run(self, text, call=EVAL):
        self.t, self.i, self.depth = text, 0, 0
        try:
            if call == EVAL:
                if self.peek() == '=':
                    self.i += 1
                v = self.expr()
            else:
                c = self.peek()
                if c == '-':
                    self.i += 1
                    v = -self.lit()
                else:
                    if c == '+':
                        self.i += 1
                    v = self.lit()
            if self.peek() != '\0':
                raise Err(SYNTAX)
            return None, v
        except Err as e:
            return e.args[0], None

    def ch(self, i):
        return self.t[i] if i < len(self.t) else '\0'

    def peek(self):
        while self.ch(self.i) == ' ':
            self.i += 1
        return self.ch(self.i)

    def expr(self):
        v = self.term()
        while self.peek() in '+-':
            op = self.peek()
            self.i += 1
            w = self.term()
            v = fit(v + w if op == '+' else v - w)
        return v

    def term(self):
        v = self.unary()
        while self.peek() in '*/':
            op = self.peek()
            self.i += 1
            w = self.unary()
            v = rdiv(v * w, 100)[0] if op == '*' else rdiv(v * 100, w)[0]
        return v

    def unary(self):
        neg = False
        while self.peek() in '+-':
            neg ^= self.peek() == '-'
            self.i += 1
        v = self.primary()
        return -v if neg else v

    def deeper(self):
        self.depth += 1
        if self.depth > DEPTH:
            raise Err(SYNTAX)

    def primary(self):
        c = self.peek()
        if c == '(':
            self.i += 1
            self.deeper()
            v = self.expr()
            self.close()
            self.depth -= 1
            return v
        if c == '.' or c.isdigit():
            return self.lit()
        cell = self.cell_at()
        if cell is None:
            return self.func()
        v = self.fetch(*cell)
        if v == NONE:
            return 0
        if v == BADV:
            raise Err(VALUE)
        return v

    def close(self):
        if self.peek() != ')':
            raise Err(SYNTAX)
        self.i += 1

    def cell_at(self):
        i = self.i
        c = self.ch(i).upper()
        if not ('A' <= c <= 'Z') or not self.ch(i + 1).isdigit():
            return None
        i += 1
        row = 0
        while self.ch(i).isdigit():
            row = row * 10 + int(self.ch(i))
            if row > 255:
                return None
            i += 1
        if row == 0:
            return None
        self.i = i
        return ord(c) - 65, row - 1

    def fetch(self, col, row):
        if col >= self.cols or row >= self.rows:
            raise Err(REF)
        return self.grid[row * self.cols + col]

    def lit(self):
        v, dec, rnd, anyd = 0, None, 0, False
        while True:
            c = self.ch(self.i)
            self.i += 1
            if c == '.':
                if dec is not None:
                    break
                dec = 0
                continue
            if not c.isdigit():
                break
            anyd = True
            d = int(c)
            if dec is None or dec < 2:
                v = v * 10 + d
                if v >= 1 << 31:
                    raise Err(BIG)
                if dec is not None:
                    dec += 1
            elif dec == 2:
                dec = 3
                rnd = 1 if d >= 5 else 0
        self.i -= 1
        if not anyd:
            raise Err(SYNTAX)
        places = 0 if dec is None else min(dec, 2)
        for _ in range(2 - places):
            v *= 10
            if v >= 1 << 31:
                raise Err(BIG)
        return fit(v + rnd)

    def func(self):
        i = self.i
        name = ''
        while self.ch(i).upper().isalpha() and 'A' <= self.ch(i).upper() <= 'Z':
            name += self.ch(i).upper()
            i += 1
            if len(name) > 5:
                raise Err(SYNTAX)
        self.i = i
        if name not in self.FUNCS:
            raise Err(SYNTAX)
        if self.peek() != '(':
            raise Err(SYNTAX)
        self.i += 1
        self.deeper()
        f = self.FUNCS.index(name)
        if f >= 5:
            v = self.expr()
            if f == 5:
                v = abs(v)
            elif f == 6:
                q, r = rdiv(v, 100, False)
                if v < 0 and r:
                    q -= 1
                v = rdiv(q * 100, 1, False)[0]
            else:
                k = 100
                if self.peek() in ',;':
                    self.i += 1
                    p = self.expr()
                    if p < 0:
                        raise Err(SYNTAX)
                    if p >= 256 or p == 200:
                        k = None
                    elif p == 100:
                        k = 10
                    elif p != 0:
                        raise Err(SYNTAX)
                if k:
                    v = rdiv(rdiv(v, k)[0] * k, 1, False)[0]
            self.close()
            self.depth -= 1
            return v
        acc = [0, 0]                     # n, value

        def add(x):
            acc[0] += 1
            if f <= 1:
                acc[1] = fit(acc[1] + x)
            elif f in (2, 3):
                if acc[0] == 1 or (x < acc[1] if f == 2 else x > acc[1]):
                    acc[1] = x
        while True:
            self.arg(add)
            if self.peek() in ',;':
                self.i += 1
                continue
            break
        self.close()
        self.depth -= 1
        n, v = acc
        if f == 1:
            if n == 0:
                raise Err(DIV0)
            return rdiv(v, n)[0]
        if f == 4:
            return n * 100
        return v

    def arg(self, add):
        start = self.i
        self.peek()
        a = self.cell_at()
        if a is not None:
            c = self.peek()
            if c == ':':
                self.i += 1
                self.peek()
                b = self.cell_at()
                if b is None:
                    raise Err(SYNTAX)
            elif c in ',;)':
                b = a
            else:
                a = None
        if a is None:
            self.i = start
            add(self.expr())
            return
        for r in range(min(a[1], b[1]), max(a[1], b[1]) + 1):
            for c in range(min(a[0], b[0]), max(a[0], b[0]) + 1):
                v = self.fetch(c, r)
                if v == NONE:
                    continue
                if v == BADV:
                    raise Err(VALUE)
                add(v)


def text_of(v):
    if v == NONE:
        return ''
    if v == BADV:
        return '#ERR'
    s = '-' if v < 0 else ''
    w, f = divmod(abs(v), 100)
    s += str(w)
    if f:
        s += '.' + ('%02d' % f).rstrip('0')
    return s


class Checker:
    def __init__(self, eng):
        self.e = eng
        self.calls = 0

    def grid(self, cols, rows, values, bank=0):
        self.cols, self.rows, self.values = cols, rows, values
        self.e.poke(GRID, b''.join(u32(v).to_bytes(4, 'little') for v in values))
        self.e.poke(CB, bytes([0] * 4 + [cols, rows, GRID & 255, GRID >> 8, bank, 0]))

    def put_text(self, s):
        self.e.poke(TEXT, s.encode('latin-1') + b'\0')

    def result(self):
        return s32(int.from_bytes(self.e.peek(CB, 4), 'little'))

    def eval(self, s, call=EVAL):
        self.calls += 1
        self.put_text(s)
        err, a, de, hl = self.e.call(call)
        want_err, want = Model(self.cols, self.rows, self.values).run(s, call)
        got = self.result()
        if want_err is not None:
            if not err or a != want_err:
                fail('%r: error %s, not %d (%s)' % (s, a if err else 'none', want_err,
                                                  'value %d' % got if not err else ''))
            if got != BADV:
                fail('%r: CB_RESULT %d after an error' % (s, got))
            return None
        if err:
            fail('%r: error %d, not %d' % (s, a, want))
        if got != want or s32(de << 16 | hl) != want:
            fail('%r: %d (DE:HL %04X:%04X), not %d' % (s, got, de, hl, want))
        return want

    def text(self, v):
        self.calls += 1
        self.e.poke(CB, u32(v).to_bytes(4, 'little'))
        self.e.poke(ROOM, b'\xAA' * 16)
        err, a, _, _ = self.e.call(TEXTC, hl=ROOM)
        want = text_of(v)
        got = self.e.peek(ROOM, 14)
        if err or a != len(want) or got[:len(want) + 1] != want.encode() + b'\0':
            fail('TEXT %d: %r (A=%d), not %r' % (v, got, a, want))
        if got[len(want) + 1] != 0xAA:
            fail('TEXT %d: wrote past its end' % v)

    def cell(self, s):
        self.calls += 1
        self.put_text(s)
        err, a, de, _ = self.e.call(CELL, de=0x1234)
        m = Model(26, 255, [])
        m.t, m.i = s, 0
        m.peek()
        want = m.cell_at()
        if want is None:
            if not err:
                fail('CELL %r: a cell (%04X), not none' % (s, de))
            return
        if err or de != want[0] << 8 | want[1] or a != m.i:
            fail('CELL %r: %s %04X A=%d, not %s, %d' % (s, err, de, a, want, m.i))


FIXED = [
    ('1+2', 300), ('=1+2*3', 700), ('(1+2)*3', 900), ('10/4', 250),
    ('2/3', 67), ('-2/3', -67), ('1/3*3', 99), ('0.005', 1), ('0.004', 0),
    ('1.239', 124), ('1.2349', 123), ('.5', 50), ('5.', 500), ('--3', 300),
    ('-+-3', 300), ('2*-3', -600), ('  7  ', 700), ('1.25*1.25', 156),
    ('A1', 1000), ('a1+b1', 3050), ('SUM(A1:C1)', 2550), ('sum(a1:c2)', None),
    ('AVG(A1,B1)', 1525), ('MIN(A1:C1)', -500), ('MAX(A1:C1;7)', 2050),
    ('COUNT(A1:C3)', None), ('COUNT(A3:C3)', 0), ('SUM(A3:C3)', 0),
    ('AVG(A3:C3)', DIV0), ('MIN(A3:C3)', 0), ('ABS(-2.5)', 250),
    ('INT(2.7)', 200), ('INT(-2.7)', -300), ('INT(-3)', -300),
    ('ROUND(2.5)', 300), ('ROUND(-2.5)', -300), ('ROUND(2.45,1)', 250),
    ('ROUND(2.44, 1)', 240), ('ROUND(2.45;2)', 245), ('ROUND(2.45,3)', 245), ('ROUND(2.45,1.5)', SYNTAX),
    ('ROUND(2.45,-1)', SYNTAX), ('ROUND(2.45,9)', 245), ('1/0', DIV0),
    ('1/(A1-10)', DIV0), ('21474836.46', LIMIT), ('21474836.47', BIG),
    ('-21474836.46', -LIMIT), ('21474836.46+0.01', BIG),
    ('10000000*10000', BIG), ('A1/0.0001', None), ('Z9', REF), ('A99', REF),
    ('B2', VALUE), ('SUM(B2)', VALUE), ('SUM(A2)', 0), ('A2+1', 100),
    ('1+', SYNTAX), ('(1', SYNTAX), ('1)', SYNTAX), ('', SYNTAX), ('=', SYNTAX),
    ('SUMS(1)', SYNTAX), ('SUM 1', SYNTAX), ('SUM (A1:B1)', 3050),
    ('FOO(1)', SYNTAX), ('1..2', SYNTAX), ('1.2.3', SYNTAX), ('A0', SYNTAX),
    ('A256', SYNTAX), ('((((((((1))))))))', 100), ('(((((((((1)))))))))', SYNTAX),
    ('SUM(SUM(A1),MAX(B1:C1))', 3050), ('SUM(1,2)+AVG(4;6)', 800),
    ('MAX(A1:C1)-MIN(C1:A1)', 2550), ('COUNT(1,A1:C1,A2)', 400),
]


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0]] = int(p[1][1:], 16)
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 3000
    rng = random.Random(int(sys.argv[4]) if len(sys.argv) > 4 else 48)
    e = Engine(prog, sym)
    ck = Checker(e)
    err, a, _, _ = e.call(9)
    if not err or a != BAD_CALL:
        fail('call 9: not "no such call"')
    # A1 10, B1 20.50, C1 -5; A2 empty, B2 an error; row 3 empty
    ck.grid(3, 3, [1000, 2050, -500, NONE, BADV, NONE, NONE, NONE, NONE])
    for s, want in FIXED:
        ck.eval(s)
        m = Model(3, 3, ck.values).run(s)
        if want is not None:
            mw = m[0] if m[0] is not None else m[1]
            if mw != want:
                fail('the model: %r is %s, not %s' % (s, mw, want))
    print('calc_check: %d fixed formulas' % len(FIXED))
    # the grid in the data bank: the same RAM here
    ck.grid(3, 3, ck.values, bank=0x80)
    ck.eval('SUM(A1:C1)')

    # random grids and formulas
    def number():
        k = rng.random()
        if k < 0.3:
            return rng.randint(-1000, 1000) * 100
        if k < 0.6:
            return rng.randint(-99999, 99999)
        if k < 0.7:
            return rng.choice([0, 1, -1, LIMIT, -LIMIT, 50, -50])
        return rng.randint(-LIMIT // 1000, LIMIT // 1000)

    def lit():
        v = abs(number())
        w, f = divmod(v, 100)
        s = str(w)
        k = rng.random()
        if k < 0.3:
            s += '.' + '%02d' % f
        elif k < 0.4:
            s += '.%d' % (f // 10)
        elif k < 0.5:
            s += '.%02d%d' % (f, rng.randint(0, 9))
        elif k < 0.55:
            s = '.%d' % rng.randint(0, 99)
        return s

    def cellname(cols, rows):
        c = rng.randint(0, cols + (1 if rng.random() < 0.05 else -1))
        r = rng.randint(1, rows + (1 if rng.random() < 0.05 else 0))
        name = chr(65 + c) + str(r)
        return name.lower() if rng.random() < 0.2 else name

    def formula(cols, rows, d=0):
        k = rng.random()
        if d > 4 or k < 0.25:
            return lit()
        if k < 0.45:
            return cellname(cols, rows)
        if k < 0.65:
            return formula(cols, rows, d + 1) + rng.choice(['+', '-', '*', '/', ' + ', ' * ']) \
                + formula(cols, rows, d + 1)
        if k < 0.72:
            return '(' + formula(cols, rows, d + 1) + ')'
        if k < 0.76:
            return '-' + formula(cols, rows, d + 1)
        f = rng.choice(Model.FUNCS)
        if f in ('ABS', 'INT'):
            return '%s(%s)' % (f, formula(cols, rows, d + 1))
        if f == 'ROUND':
            p = rng.choice(['', ',0', ',1', ', 2', ';1', ',5'])
            return 'ROUND(%s%s)' % (formula(cols, rows, d + 1), p)
        args = []
        for _ in range(rng.randint(1, 3)):
            if rng.random() < 0.5:
                args.append(cellname(cols, rows) + ':' + cellname(cols, rows))
            else:
                args.append(formula(cols, rows, d + 1))
        return '%s(%s)' % (f.lower() if rng.random() < 0.1 else f,
                           rng.choice([',', ';', ', ']).join(args))

    def mangle(s):
        if not s or rng.random() > 0.1:
            return s
        i = rng.randrange(len(s) + 1)
        return s[:i] + rng.choice('()+-*/.,:x9 ') + s[i + 1:]

    errors = 0
    for i in range(n):
        if i % 500 == 0:
            cols, rows = rng.randint(1, 26), rng.randint(1, 12)
            vals = []
            for _ in range(cols * rows):
                k = rng.random()
                vals.append(NONE if k < 0.2 else BADV if k < 0.23 else number())
            ck.grid(cols, rows, vals)
        s = mangle(formula(cols, rows))
        if len(s) > 120:
            continue
        if ck.eval(s) is None:
            errors += 1
        t = rng.choice(['-', '+', '', ' ']) + lit() + rng.choice(['', ' ', 'x', '.5'])
        ck.eval(t, NUMBER)
        ck.text(rng.choice([number(), NONE, BADV, LIMIT, -LIMIT, 0]))
        ck.cell(rng.choice(['', ' ']) + cellname(26, 255) + rng.choice(['', '+1', 'x', '9']))
    print('calc_check: %d calls, %d formulas with an error: all as the model' % (ck.calls, errors))


if __name__ == '__main__':
    main()
