#!/usr/bin/env python3
"""Check SHEET (make test-sheet-z80).

usage: sheet_check.py sheet.bin sheet.sym calc.bin calc.sym

Runs SHEET (myapps/sheet, assembled at #4000, with its symbols) in a
Z80 emulator (the z80 package) with the V-OS calls stubbed: VOS_PRINT
writes into a screen of text (48 columns, 96 in mode 2, a row each y), VOS_INPUT and
VOS_DIALOG answer from a script, the data bank is 16K of its own, files
are kept here. VX_CALC is CALC.SYS itself (src/calc/calc.asm built with
-DCALC_HARNESS) in a second emulator: each call gets the block, the
text and the grid from the data bank. Numbers, text and formulas are
typed into cells; then the screen must show their values (numbers on
the right, text on the left, "#ERR", "########"), a wrong formula must
be asked again, formulas that use later cells and each other must be
worked out, DEL must empty a cell, the columns and rows must scroll, a
page (^M, mode 2) must show 10 columns and scroll to P, then 5 again, a
sheet saved must be its lines, opened again the same, a UTF-8 file
must be read, the sample BUDGET.VSH must open with its values, CHART
must draw its costs (the bars on the screen and in the .SCR, the
labels, ^S, ESC), OPEN CSV must read a .CSV by semicolons or commas,
with quotes, and a
full sheet must say so. Exits 1 on the first
difference.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voscs        # noqa: E402,F401  (the codec "vos")
import calc_check   # noqa: E402

API = 0x0108
CALLS = 43
(EXIT, TICKS, FRAMES, RANDOM, COMMAND, ERROR, MODE, PALETTE, CLS, PLOT, RECT,
 COLOURS, PRINT, CHAR, MSG, SET_BAR, DRAW_BAR, UI_EVENT, DIALOG, INPUT,
 SET_WIDGETS, DRAW_WIDGETS, MENU_VIEW, MENU_HELP, CATALOG, LOAD, SAVE, DELETE,
 FILE_PICK, TEXTS, MENU_OPEN) = range(31)
BANK_GET, BANK_PUT, EXT = 37, 38, 42
VX_UTF8, VX_DATA, VX_CALC = 9, 7, 10
VE_KEY_DOWN = 1
VK = dict(UP=0, RIGHT=1, DOWN=2, LEFT=8, RETURN=18, DEL=79, ESC=66)
VC_APP = 32
CMD = dict(NEW=1, OPEN=2, SAVE=3, SAVE_AS=4, DRIVE=5, ABOUT=6, BACK=7, PAGE=8, PRINT=9, CHART=10,
           CSV=11)
CALC_TEXT = 2
CAT = 0xB800                     # where VOS_CATALOG's list is
SYNTAX = 30


class App:
    def __init__(self, prog, sym, calc):
        import z80
        self.sym = sym
        self.m = z80.Z80Machine()
        mem = bytearray(65536)
        mem[0x4000:0x4000 + len(prog)] = prog
        for i in range(CALLS):
            mem[API + i * 3] = 0xAF              # xor a: A = 0, Z
            mem[API + i * 3 + 1] = 0xC9          # ret
        mem[0x0100:0x0102] = b'\x18\xfe'      # jr $: returned
        mem[0x8800] = 1                       # VOS_SELF: drive B:
        mem[0x9000:0x9003] = b'OK\0'
        self.m.set_memory_block(0, bytes(mem))
        for i in range(CALLS):
            self.m.set_breakpoint(API + i * 3)
        self.m.set_breakpoint(0x0100)
        self.calc = calc
        self.bank = bytearray(16384)
        self.files = {}
        self.texts = None
        self.screen = {}
        self.inv = {}
        self.colours = (1, 2)
        self.width = 48                       # 96 in mode 2
        self.rects = []
        self.asked = []
        self.inputs, self.buttons, self.picks = [], [], []
        self.errors, self.dialogs = [], []
        self.calc_calls = 0

    def text(self, n):
        if n < 0xC0:
            return 0x9000
        a = self.texts + 3 + (n - 0xC0) * 4
        return self.m.memory[a] | self.m.memory[a + 1] << 8

    def msg(self, n):
        a = self.text(n)
        s = b''
        while self.m.memory[a]:
            s += bytes([self.m.memory[a]])
            a += 1
        return s.decode('vos')

    def vx_calc(self):
        m, e = self.m, self.calc
        self.calc_calls += 1
        e.poke(calc_check.CB, m.memory[m.de:m.de + 10])
        e.poke(calc_check.TEXT, m.memory[m.hl:m.hl + 128])
        e.poke(0x7000, self.bank[0x3000:0x4000])
        carry, a, de, hl = e.call(m.c)
        if m.c != 3:
            m.set_memory_block(m.de, e.peek(calc_check.CB, 10))
        if m.c == CALC_TEXT:
            m.set_memory_block(m.hl, e.peek(calc_check.TEXT, 14))
        m.a, m.de, m.hl = a, de, hl
        if carry:
            m.f |= 1

    def call(self, name, a=0, hl=0):
        m = self.m
        m.set_memory_block(0xBEFE, bytes([0x00, 0x01]))
        m.sp, m.pc, m.a, m.hl = 0xBEFE, self.sym[name], a, hl
        for _ in range(1000000):
            m.ticks_to_stop = 5000000
            m.run()
            if m.pc == 0x0100:
                return
            if not API <= m.pc < API + CALLS * 3:
                continue
            n = (m.pc - API) // 3
            m.f &= ~1
            if n == PRINT:
                s, a = b'', m.bc
                while m.memory[a]:
                    s += bytes([m.memory[a]])
                    a += 1
                w = self.width
                row = self.screen.setdefault(m.de, [' '] * w)
                inv = self.inv.setdefault(m.de, [False] * w)
                if m.hl % 8 or len(row) != w:
                    sys.exit('sheet_check: x %d, or a row of another mode' % m.hl)
                for i, ch in enumerate(s.decode('vos')):
                    if 0 <= m.hl // 8 + i < w:
                        row[m.hl // 8 + i] = ch
                        inv[m.hl // 8 + i] = self.colours[0] == 2
                    else:
                        sys.exit('sheet_check: printed past the screen: %r' % s)
            elif n == MODE:
                self.width = 96 if m.a == 2 else 48
                self.screen, self.inv = {}, {}
            elif n == RECT:
                b = m.memory[m.ix:m.ix + 9]
                self.rects.append(tuple(b[i] | b[i + 1] << 8 for i in range(0, 8, 2)) + (b[8],))
            elif n == CLS:
                self.screen, self.inv = {}, {}
            elif n == COLOURS:
                self.colours = (m.a & 15, m.c)
            elif n == TEXTS:
                self.texts = m.hl
            elif n == MSG:
                m.hl = self.text(m.a)
            elif n == INPUT:
                shown = bytes(m.memory[m.hl:m.hl + 40]).split(b'\0')[0]
                self.asked.append(shown.decode('vos'))
                ans = self.inputs.pop(0)
                if ans is None:
                    m.f |= 1
                elif ans != '':             # '': as it was shown
                    m.set_memory_block(m.hl, ans.encode('vos') + b'\0')
            elif n == DIALOG:
                d = m.hl
                self.dialogs.append(self.msg(m.memory[d + 1]))
                m.a = self.buttons.pop(0)
            elif n == ERROR:
                self.errors.append(m.a)
            elif n == BANK_GET:
                m.set_memory_block(m.de, bytes(self.bank[m.hl - 0x4000:m.hl - 0x4000 + m.bc]))
            elif n == BANK_PUT:
                self.bank[m.de - 0x4000:m.de - 0x4000 + m.bc] = m.memory[m.hl:m.hl + m.bc]
            elif n == CATALOG:
                names = sorted(k for k in self.files if k[0] == m.a & 3)
                if m.a & 0x40:                  # VOS_CAT_EXT: one extension
                    ext = bytes(m.memory[m.hl:m.hl + 3])
                    names = [k for k in names if k[1][8:] == ext]
                lst = b''.join(k[1] + bytes(5) for k in names)
                m.set_memory_block(CAT, lst or b'\0')
                self.cat = names
                m.a, m.hl = len(names), CAT
            elif n == FILE_PICK:
                m.a = self.picks.pop(0)
            elif n == LOAD:
                key = (m.a & 3, bytes(m.memory[m.hl:m.hl + 11]))
                if key not in self.files:
                    m.a = 7
                    m.f |= 1
                else:
                    data = self.files[key]
                    self.bank[m.de - 0x4000:m.de - 0x4000 + len(data)] = data
                    m.bc = len(data)
            elif n == SAVE:
                key = (m.a & 3, bytes(m.memory[m.hl:m.hl + 11]))
                self.files[key] = bytes(self.bank[m.de - 0x4000:m.de - 0x4000 + m.bc])
            elif n == EXT and m.a == VX_CALC:
                self.vx_calc()
            elif n == EXT and m.a == VX_DATA:
                m.a = 1
            elif n == EXT and m.a == VX_UTF8:
                at, ln = m.hl - 0x4000, m.bc
                data = bytes(self.bank[at:at + ln])
                try:
                    if all(b < 128 for b in data):
                        raise UnicodeError
                    out = data.decode('utf-8').encode('vos', errors='replace')
                    self.bank[at:at + len(out)] = out
                    m.bc, m.a = len(out), 1
                except UnicodeError:
                    m.a = 0
            elif n == EXIT:
                pass
            m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
            m.sp += 2
        sys.exit('sheet_check: %s did not return' % name)

    def key(self, k, ch=0):
        self.m.set_memory_block(0xBF00, bytes([VE_KEY_DOWN, VK[k] if isinstance(k, str) else k, ch, 0]))
        self.call('EVENT', hl=0xBF00)

    def command(self, c):
        self.call('COMMAND', a=VC_APP + CMD[c])

    def enter(self, *texts):
        """the cursor's cell: the first typed (RETURN), any more asked again"""
        self.inputs = list(texts)
        self.key('RETURN')
        if self.inputs:
            sys.exit('sheet_check: %r not asked for' % self.inputs)

    def go(self, cell):
        """the cursor to a cell such as "B3", with the arrows"""
        c, r = ord(cell[0]) - 65, int(cell[1:]) - 1
        for _ in range(20):
            self.key('LEFT')
        for _ in range(70):
            self.key('UP')
        for _ in range(c):
            self.key('RIGHT')
        for _ in range(r):
            self.key('DOWN')

    def line(self, y):
        return ''.join(self.screen.get(y, [' '] * self.width)).rstrip()

    def row(self, r):
        """row r on the screen (from 0): its number and its cells (5, or
        10 on the page)"""
        s = ''.join(self.screen.get(42 + 10 * r, [' '] * self.width))
        n = 10 if self.width == 96 else 5
        return s[:3].strip(), [s[3 + 9 * i:11 + 9 * i] for i in range(n)]

    def inverted(self):
        return [(y, i) for y, inv in self.inv.items() for i, v in enumerate(inv) if v]


def check(what, got, want):
    if got != want:
        sys.exit('sheet_check: %s:\n  got  %r\n  want %r' % (what, got, want))


def num(s):
    return '%8s' % s


def txt(s):
    return '%-8s' % s


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    csym = {}
    for line in open(sys.argv[4]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            csym[p[0]] = int(p[1][1:], 16)
    calc = calc_check.Engine(open(sys.argv[3], 'rb').read(), csym)
    app = App(prog, sym, calc)
    app.call('INIT', a=0)
    check('the first line', app.line(14), 'A1' + ' ' * 33 + 'B:NONAME.VSH')
    check('the heads', app.line(30), '       A        B        C        D        E')
    check('row 1', app.row(0), ('1', [txt('')] * 5))
    check('row 19', app.row(18)[0], '19')
    check('the cursor at A1', sorted({y for y, _ in app.inverted()}), [42])
    # A1..A3 numbers, A4 their sum: RETURN goes down after each
    for s in ('10', '20.5', '-5', '=SUM(A1:A3)'):
        app.enter(s)
    check('the cursor below', app.line(14).split()[0], 'A5')
    check('column A', [app.row(r)[1][0] for r in range(4)],
          [num('10'), num('20.5'), num('-5'), num('25.5')])
    app.go('A4')
    check('the formula on top', app.line(14)[:35].rstrip(), 'A4  =SUM(A1:A3)')
    # text, a formula with an error, a wrong one asked again
    app.go('B1')
    app.enter('Total')
    app.enter('=A4*2')
    app.enter('=A1/0')
    app.enter('=A1+', '=a1 * 3')
    check('the wrong one: its error', app.errors, [SYNTAX])
    app.errors = []
    check('column B', [app.row(r)[1][1] for r in range(4)],
          [txt('Total'), num('51'), num('#ERR'), num('30')])
    # typing starts a new text: the first character is the input's
    app.go('C1')
    app.inputs = ['=E1+1']
    app.key(63, ord('='))
    app.enter('=C1*2')
    check('a later cell, still empty', [app.row(r)[1][2] for r in range(2)],
          [num('1'), num('2')])
    app.go('E1')
    app.enter('4.25')
    check('worked out again', [app.row(r)[1][2] for r in range(2)],
          [num('5.25'), num('10.5')])
    # cells that use each other; too long; MIN, MAX, AVG, ROUND, INT
    app.go('D1')
    app.enter('=D2+1')
    app.enter('=D1+1')
    app.enter('1234567.5')
    app.enter('=ROUND(AVG(A1:A3),1)')
    app.enter('=MAX(A1:A3)-MIN(A1:A3)+INT(-0.5)')
    check('column D', [app.row(r)[1][3] for r in range(5)],
          [num('#ERR'), num('#ERR'), '########', num('8.5'), num('24.5')])
    # DEL empties a cell: the sum without it
    app.go('A2')
    app.key('DEL')
    check('A2 empty', app.row(1)[1][0], txt(''))
    check('the sum again', app.row(3)[1][0], num('5'))
    check('B2 again', app.row(1)[1][1], num('10'))
    app.go('A2')
    app.enter('20.5')
    # the columns scroll: F.. after E; the rows after 19
    app.go('E1')
    app.key('RIGHT')
    check('scrolled right', app.line(30), '       B        C        D        E        F')
    check('the cursor at F1', app.line(14).split()[0], 'F1')
    for _ in range(12):
        app.key('RIGHT')
    check('the last column', app.line(30), '       L        M        N        O        P')
    app.key('RIGHT')
    check('no more', app.line(14).split()[0], 'P1')
    # the page (^M, mode 2): 10 columns, the last one P
    app.rects = []
    app.command('PAGE')
    check('the page: 96 columns', app.width, 96)
    check('the page: lines between the cells of row 1',
          [x for x, y, w, h, pen in app.rects if y == 42 and w == 1 and h == 10 and pen == 1],
          [20 + 72 * i for i in range(11)])

    def heads(first, n):
        return ' ' * 7 + (' ' * 8).join(chr(ord(first) + i) for i in range(n))
    check('the page: up to P', app.line(30), heads('G', 10))
    check('the page: the cursor at P1', app.inverted(), [(42, 3 + 9 * 9 + i) for i in range(8)])
    check('the page: the first line', (app.line(14).split()[0], app.line(14)[35:]),
          ('P1', 'B:NONAME.VSH'))
    check('the page: the hint', app.line(249)[:6], 'ARROWS')
    check('the page: 19 rows', (app.row(0)[0], app.row(18)[0]), ('1', '19'))
    app.go('A1')
    check('the page: A to J', app.line(30), heads('A', 10))
    app.go('H1')
    app.enter('=E1*2')
    check('the page: row 1', app.row(0)[1],
          [num('10'), txt('Total'), num('5.25'), num('#ERR'), num('4.25'), txt(''), txt(''),
           num('8.5'), txt(''), txt('')])
    check('the page: the cursor at H2', app.inverted(), [(52, 3 + 9 * 7 + i) for i in range(8)])
    app.go('H1')
    app.key('DEL')
    check('the page: H1 empty', app.row(0)[1][7], txt(''))
    app.go('J1')
    check('the page: J, not scrolled', app.line(30), heads('A', 10))
    app.key('RIGHT')
    check('the page: K, scrolled', app.line(30), heads('B', 10))
    for _ in range(6):
        app.key('RIGHT')
    check('the page: P at most', (app.line(30), app.line(14).split()[0]),
          (heads('G', 10), 'P1'))
    app.rects = []
    app.command('PAGE')
    check('mode 1: no lines', app.rects, [])
    check('mode 1 again', (app.width, app.line(30), app.row(0)[1][4], app.inverted()),
          (48, '       L        M        N        O        P', txt(''),
           [(42, 39 + i) for i in range(8)]))
    app.go('A19')
    check('row 19 on the screen', app.row(18)[0], '19')
    app.key('DOWN')
    check('scrolled down', (app.row(0)[0], app.row(18)[0]), ('2', '20'))
    app.go('A64')
    app.enter('=SUM(A1:A63)')
    check('the last row', (app.row(18)[0], app.line(14).split()[0]), ('64', 'A64'))
    check('its sum (A4 too)', app.row(18)[1][0], num('51'))
    for _ in range(3):
        app.key('DOWN')
    check('no row 65', app.line(14).split()[0], 'A64')
    # SAVE: a name, then its lines
    app.inputs = ['budget']
    app.command('SAVE')
    check('its name', app.line(14)[35:], 'B:BUDGET.VSH')
    check('SAVED', app.line(238), 'SAVED')
    data = app.files[(1, b'BUDGET  VSH')]
    want = ('A1 10\r\nB1 Total\r\nC1 =E1+1\r\nD1 =D2+1\r\nE1 4.25\r\nA2 20.5\r\n'
            'B2 =A4*2\r\nC2 =C1*2\r\nD2 =D1+1\r\nA3 -5\r\nB3 =A1/0\r\nD3 1234567.5\r\n'
            'A4 =SUM(A1:A3)\r\nB4 =a1 * 3\r\nD4 =ROUND(AVG(A1:A3),1)\r\n'
            'D5 =MAX(A1:A3)-MIN(A1:A3)+INT(-0.5)\r\nA64 =SUM(A1:A63)\r\n')
    check('the file', data.decode('vos'), want)
    # NEW, then OPEN it again
    app.command('NEW')
    check('a new sheet', (app.line(14), app.row(0)), ('A1' + ' ' * 33 + 'B:NONAME.VSH',
                                                      ('1', [txt('')] * 5)))
    app.picks = [0]
    app.command('OPEN')
    check('opened', app.line(14)[35:], 'B:BUDGET.VSH')
    check('row 1 again', app.row(0)[1], [num('10'), txt('Total'), num('5.25'), num('#ERR'),
                                         num('4.25')])
    check('row 4 again', app.row(3)[1][:4], [num('25.5'), num('30'), txt(''), num('8.5')])
    # changes, then NEW: asked first (NO: nothing lost)
    app.enter('7')
    app.buttons = [1]
    app.command('NEW')
    check('asked', app.dialogs[-1], 'DISCARD THE CHANGES?')
    check('kept', app.row(0)[1][0], num('7'))
    # a UTF-8 file from a PC: Greek text, lines with LF only, lines that
    # are no cells
    app.files[(1, b'GREEK   VSH')] = ('# made on a PC\nA1 Σύνολο\nB1 12\nZ9 far away\nC1 =B1*2\n'
                                      'x\n').encode('utf-8')
    app.buttons = [0]                        # the changes may go
    app.picks = [1]                          # (BUDGET, GREEK)
    app.command('OPEN')
    check('the Greek file', app.row(0)[1][:3], [txt('Σύνολο'), num('12'), num('24')])
    # the sample on SHEET's disc (myapps/sheet/owndisc)
    here = os.path.dirname(os.path.abspath(__file__))
    app.files[(1, b'BUDGET  VSH')] = open(os.path.join(here, '..', 'myapps', 'sheet', 'owndisc',
                                                    'BUDGET.VSH'), 'rb').read()
    app.picks = [0]                          # (BUDGET, GREEK)
    app.command('OPEN')
    check('BUDGET.VSH', [app.row(r)[1] for r in (1, 2, 3, 5, 6)],
          [[txt('Paper'), num('2.5'), num('4'), num('10'), txt('')],
           [txt('Pens'), num('1.2'), num('10'), num('12'), txt('')],
           [txt('Ink'), num('7.99'), num('2'), num('15.98'), txt('')],
           [txt('TOTAL'), txt(''), num('16'), num('37.98'), txt('')],
           [txt('AVERAGE'), txt(''), txt(''), num('12.7'), txt('')]])
    # CHART: D2 down to its last number, the bars as high as the costs
    # are to their MAX, Paper, Pens, Ink under them; the .SCR in the
    # data bank, saved with ^S; ESC back, the values worked out again
    app.go('D2')
    app.asked, app.rects = [], []
    app.inputs = ['']
    app.command('CHART')
    check('CHART: the range asked', app.asked, ['D2:D4'])
    bars = [r for r in app.rects if r[2] == 32]
    check('CHART: the bars', bars, [(28 + 48 * i, 30 + 180 - h, 32, h, (2, 3, 4)[i])
                                    for i, h in enumerate((100, 120, 160))])
    check('CHART: the labels', [app.line(214)[3:6], app.line(214)[9:12], app.line(214)[15:18]],
          ['Pap', 'Pen', 'Ink'])
    y = 180 - 100
    at = (y & 7) * 0x800 + (y >> 3) * 80 + (12 + 0) // 2
    check('CHART: the .SCR, the first bar', bytes(app.bank[at:at + 16]), bytes([0x0C] * 16))
    check('CHART: the .SCR, its inks', bytes(app.bank[0x7D0:0x7D0 + 17]),
          bytes([0, 26, 2, 6, 18, 24, 20, 8, 15, 13, 3, 9, 1, 12, 17, 11, 13]))
    app.inputs = ['costs']
    app.m.set_memory_block(0xBF00, bytes([VE_KEY_DOWN, 60, 19, 2]))   # CONTROL+S
    app.call('EVENT', hl=0xBF00)
    saved = [k for k in app.files if k[1] == b'COSTS   SCR']
    check('CHART: ^S, COSTS.SCR', [len(app.files[k]) for k in saved], [0x4000])
    if os.environ.get('SHEET_CHART_SCR'):        # to look at it
        open(os.environ['SHEET_CHART_SCR'], 'wb').write(app.files[saved[0]])
    app.key('ESC')
    check('BUDGET.VSH', [app.row(r)[1] for r in (1, 2, 3, 5, 6)],
          [[txt('Paper'), num('2.5'), num('4'), num('10'), txt('')],
           [txt('Pens'), num('1.2'), num('10'), num('12'), txt('')],
           [txt('Ink'), num('7.99'), num('2'), num('15.98'), txt('')],
           [txt('TOTAL'), txt(''), num('16'), num('37.98'), txt('')],
           [txt('AVERAGE'), txt(''), txt(''), num('12.7'), txt('')]])
    # OPEN CSV: by semicolons (the first line), quotes, "" a quote, 1,5
    # a number; saved as a .VSH
    app.files[(1, b'PRICES  CSV')] = ('Name;Price;Count\r\n"Pens; blue";1,5;10\r\n'
                                      'Ink;"7,99";2\r\n"Say ""hi""";;3\r\nΕλιά;0,5').encode('utf-8')
    app.picks = [0]
    app.command('CSV')
    check('CSV: its name', app.line(14)[35:], 'B:PRICES.VSH')
    check('CSV: the cells', [app.row(r)[1][:3] for r in range(5)],
          [[txt('Name'), txt('Price'), txt('Count')],
           [txt('Pens; bl'), num('1.5'), num('10')],
           [txt('Ink'), num('7.99'), num('2')],
           [txt('Say "hi"'), txt(''), num('3')],
           [txt('Ελιά'), num('0.5'), txt('')]])
    # by commas
    app.files[(1, b'PRICES  CSV')] = b'a,1.25,"x,y"\nb,2,\n'
    app.picks = [0]
    app.command('CSV')
    check('CSV with commas', [app.row(r)[1][:3] for r in range(2)],
          [[txt('a'), num('1.25'), txt('x,y')], [txt('b'), num('2'), txt('')]])
    # full: long texts until there is no room
    app.command('NEW')
    app.go('A1')
    app.dialogs = []
    n = 0
    while not app.dialogs and n < 400:
        app.buttons = [0]
        app.enter('=%s' % ('1+' * 19 + '1'))
        n += 1
        if n % 64 == 0:
            app.key('RIGHT')
            for _ in range(64):
                app.key('UP')
    check('full', app.dialogs, ['NO ROOM FOR|MORE CELLS'])
    check('the full one is empty', app.line(14)[4:35].strip(), '')
    if app.errors:
        sys.exit('sheet_check: errors %r' % app.errors)
    print('sheet_check: numbers, text, formulas (%d CALC.SYS calls), errors, scrolling, '
          'the page (^M), SAVE, OPEN, a UTF-8 file, CHART, OPEN CSV and a full sheet (%d cells): '
          'all right'
          % (app.calc_calls, n - 1))


if __name__ == '__main__':
    main()
