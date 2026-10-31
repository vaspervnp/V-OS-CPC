#!/usr/bin/env python3
"""Check DATABASE (make test-database-z80).

usage: database_check.py database.bin database.sym

Runs DATABASE (myapps/database, assembled at #4000, with its symbols) in
a Z80 emulator (the z80 package) with the V-OS calls stubbed: VOS_PRINT
writes into a screen of text (48 columns, a row each y), VOS_INPUT and
VOS_DIALOG answer from a script, and VX_DB is a model of the engine in
Python (the same order as DB.SYS: keys high byte first, DB_ALPHA keys
without case or accents, ties by rid; the cursor at the last record
returned). A database is made, a table with a DB_ALPHA key and a
number, records added in the form; then the list must show them in the
key's order without case, FIND must go to them, a change saved must be
there, a deletion gone, and the list must scroll over 40 records. A
second table without a key, TAB between them. Exits 1 on the first
difference.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voscs  # noqa: E402  (the codec "vos")
import vdb    # noqa: E402

API = 0x0108
CALLS = 43
(EXIT, TICKS, FRAMES, RANDOM, COMMAND, ERROR, MODE, PALETTE, CLS, PLOT, RECT,
 COLOURS, PRINT, CHAR, MSG, SET_BAR, DRAW_BAR, UI_EVENT, DIALOG, INPUT,
 SET_WIDGETS, DRAW_WIDGETS, MENU_VIEW, MENU_HELP, CATALOG, LOAD, SAVE, DELETE,
 FILE_PICK, TEXTS, MENU_OPEN) = range(31)
EXT = 42
VX_DB = 8
VE_KEY_DOWN = 1
VK = dict(UP=0, RIGHT=1, DOWN=2, LEFT=8, RETURN=18, TAB=68, DEL=79)
VC_APP = 32
CMD = dict(NEW_DB=1, OPEN_DB=2, NEW_TABLE=3, ADD=4, DELETE=5, SAVE=6, LIST=7,
           DRIVE=8, ABOUT=9, BACK=10)
DB = dict(CREATE=0, OPEN=1, CLOSE=2, TABLE=3, USE=4, INFO=5, ADD=6, GET=7,
          PUT=8, DEL=9, FIND=10, FIRST=11, LAST=12, NEXT=13, PREV=14, COUNT=15)
ERR_NO_FILE, ERR_EXISTS, ERR_TABLE, ERR_RID, ERR_END = 7, 10, 17, 20, 21


class Table:
    def __init__(self, d):
        self.name = d[:8]
        n, self.key = d[8], d[9]
        self.fields = [(d[10 + i * 10:18 + i * 10], d[18 + i * 10], d[19 + i * 10]) for i in range(n)]
        self.reclen = sum(f[2] for f in self.fields)
        self.recs = {}
        self.next_rid = 0x0100
        self.cursor = None

    def keyof(self, rec, rid):
        if not self.key:
            return (b'', rid)
        off = sum(f[2] for f in self.fields[:self.key - 1])
        _, typ, ln = self.fields[self.key - 1]
        k = rec[off:off + ln]
        if typ == 1:
            k = k[::-1]
        elif typ == 2:
            k = vdb.fold(k)
        return (k, rid)

    def order(self):
        return sorted(self.recs, key=lambda r: self.keyof(self.recs[r], r))

    def info(self):
        d = bytearray(124)
        d[0:8] = self.name
        d[8], d[9], d[10] = len(self.fields), self.key, self.reclen
        d[20:22] = len(self.recs).to_bytes(2, 'little')
        for i, (n, t, ln) in enumerate(self.fields):
            d[24 + i * 10:32 + i * 10] = n
            d[32 + i * 10], d[33 + i * 10] = t, ln
        return bytes(d)


class Model:
    """VX_DB, as DB.SYS does it, for one program."""
    def __init__(self):
        self.files = {}
        self.open = None
        self.cur = None

    def call(self, c, de, hl, mem):
        def ok(a=0, de=None, hl=None):
            return False, a, de, hl
        if c == DB['CREATE'] or c == DB['OPEN']:
            name = bytes(mem[de:de + 12])
            if c == DB['CREATE']:
                if name in self.files:
                    return True, ERR_EXISTS, None, None
                self.files[name] = []
            elif name not in self.files:
                return True, ERR_NO_FILE, None, None
            self.open, self.cur = self.files[name], None
            return ok()
        if c == DB['CLOSE']:
            self.open = None
            return ok()
        tabs = self.open
        if c == DB['TABLE']:
            tabs.append(Table(bytes(mem[de:de + 110])))
            self.cur = tabs[-1]
            return ok(len(tabs) - 1)
        if c == DB['USE']:
            if (de & 255) >= len(tabs):
                return True, ERR_TABLE, None, None
            self.cur = tabs[de & 255]
            return ok()
        if c == DB['INFO']:
            if (de & 255) >= len(tabs):
                return True, ERR_TABLE, None, None
            mem[hl:hl + 124] = tabs[de & 255].info()
            return ok(len(tabs))
        t = self.cur

        def give(rid):
            t.cursor = t.keyof(t.recs[rid], rid)
            if hl:
                mem[hl:hl + t.reclen] = t.recs[rid]
            return ok(0, rid)
        if c == DB['COUNT']:
            return ok(0, None, len(t.recs))
        if c == DB['ADD']:
            rid = t.next_rid
            t.next_rid += 1
            t.recs[rid] = bytes(mem[hl:hl + t.reclen])
            return ok(0, rid)
        if c in (DB['GET'], DB['PUT'], DB['DEL']):
            if de not in t.recs:
                return True, ERR_RID, None, None
            if c == DB['GET']:
                mem[hl:hl + t.reclen] = t.recs[de]
            elif c == DB['PUT']:
                t.recs[de] = bytes(mem[hl:hl + t.reclen])
            else:
                del t.recs[de]
            return ok()
        order = t.order()
        keys = [t.keyof(t.recs[r], r) for r in order]
        if c == DB['FIRST'] or c == DB['LAST']:
            if not order:
                return True, ERR_END, None, None
            return give(order[0] if c == DB['FIRST'] else order[-1])
        if c == DB['NEXT'] or c == DB['PREV']:
            if c == DB['NEXT']:
                later = [r for r, k in zip(order, keys) if k > t.cursor]
                return give(later[0]) if later else (True, ERR_END, None, None)
            before = [r for r, k in zip(order, keys) if k < t.cursor]
            return give(before[-1]) if before else (True, ERR_END, None, None)
        if c == DB['FIND']:
            off = sum(f[2] for f in t.fields[:t.key - 1])
            _, typ, ln = t.fields[t.key - 1]
            rec = bytearray(t.reclen)
            rec[off:off + ln] = mem[hl:hl + ln]
            n = (de & 255) or ln
            want = t.keyof(bytes(rec), 0)[0][:n]
            for r, k in zip(order, keys):
                if k[0][:n] >= want:
                    return give(r)
            return True, ERR_END, None, None
        raise AssertionError('DB call %d' % c)


class App:
    def __init__(self, prog, sym):
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
        self.db = Model()
        self.texts = None
        self.screen = {}
        self.inv = {}
        self.colours = (1, 2)
        self.inputs, self.buttons = [], []
        self.errors = []
        self.exited = False

    def text(self, n):
        if n < 0xC0:
            return 0x9000
        a = self.texts + 3 + (n - 0xC0) * 4
        return self.m.memory[a] | self.m.memory[a + 1] << 8

    def call(self, name, a=0, hl=0):
        m = self.m
        m.set_memory_block(0xBEFE, bytes([0x00, 0x01]))
        m.sp, m.pc, m.a, m.hl = 0xBEFE, self.sym[name], a, hl
        for _ in range(100000):
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
                row = self.screen.setdefault(m.de, [' '] * 48)
                inv = self.inv.setdefault(m.de, [False] * 48)
                for i, ch in enumerate(s.decode('vos')):
                    if 0 <= m.hl // 8 + i < 48:
                        row[m.hl // 8 + i] = ch
                        inv[m.hl // 8 + i] = self.colours[0] == 2
            elif n == CLS:
                self.screen, self.inv = {}, {}
            elif n == COLOURS:
                self.colours = (m.a & 15, m.c)
            elif n == TEXTS:
                self.texts = m.hl
            elif n == MSG:
                m.hl = self.text(m.a)
            elif n == INPUT:
                ans = self.inputs.pop(0)
                if ans is None:
                    m.f |= 1
                else:
                    m.set_memory_block(m.hl, ans.encode('vos') + b'\0')
            elif n == DIALOG:
                m.a = self.buttons.pop(0)
            elif n == ERROR:
                self.errors.append(m.a)
            elif n == EXIT:
                self.exited = True
            elif n == EXT and m.a == VX_DB:
                mem = bytearray(m.memory)
                carry, a, de, hl = self.db.call(m.c, m.de, m.hl, mem)
                m.set_memory_block(0, bytes(mem))
                m.a = a
                if de is not None:
                    m.de = de
                if hl is not None:
                    m.hl = hl
                if carry:
                    m.f |= 1
            m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
            m.sp += 2
        sys.exit('database_check: %s did not return' % name)

    def key(self, k, ch=0):
        self.m.set_memory_block(0xBF00, bytes([VE_KEY_DOWN, VK[k] if isinstance(k, str) else k, ch, 0]))
        self.call('EVENT', hl=0xBF00)

    def type(self, s):
        for ch in s.encode('vos'):
            self.key(63, ch)

    def command(self, c):
        self.call('COMMAND', a=VC_APP + CMD[c])

    def rows(self, y0=46, n=18):
        """The list's rows: text, and which one is inverted."""
        out = []
        for i in range(n):
            y = y0 + 10 * i
            row = ''.join(self.screen.get(y, [' '] * 48)).rstrip()
            out.append((row, any(self.inv.get(y, []))))
        return out

    def line(self, y):
        return ''.join(self.screen.get(y, [' '] * 48)).rstrip()


def row(name, age):
    """A row of the list: NAME's column 12 wide, a space, AGE's 5."""
    return '%-13s%5d' % (name, age)


def check(what, got, want):
    if got != want:
        sys.exit('database_check: %s:\n  got  %r\n  want %r' % (what, got, want))


def main():
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    app = App(prog, sym)
    app.call('INIT', a=0)
    check('the start', app.line(120), 'NO DATABASE: ^N NEW ONE, ^O OPEN ONE')
    # a database, a table: NAME (text, 12, its key), AGE (a number)
    app.inputs = ['club', 'pals', 'name', '12', 'age', '']
    app.buttons = [0, 1, 0]                  # TEXT, NUMBER, the key: YES
    app.command('NEW_DB')
    check('the first line', app.line(14)[:22].rstrip(), 'B:CLUB.VDB    PALS')
    check('the heads', app.line(32), 'NAME         AGE')
    check('no records', app.rows()[0][0], 'NO RECORDS: ^A ADDS ONE')
    # three records in the form
    for name, age in (('ZOE', '31'), ('anna', '28'), ('bob', '40'), ('Ελένη', '25'), ('Élodie', '33')):
        app.command('ADD')
        check('the form', app.line(32), 'NEW RECORD')
        check('its fields', (app.line(44)[:9], app.line(60)[:9]), ('NAME    :', 'AGE     :'))
        app.inputs = [name, age]
        app.key('RETURN')
        app.key('DOWN')
        app.key('RETURN')
        check('the form filled', (app.line(44)[10:], app.line(60)[10:]),
              (name, '   ' + ('%2s' % age)))
        app.command('SAVE')
    check('the saved one first', app.rows()[0], (row('Élodie', 33), True))
    app.type('a')                            # from the first: a, DEL
    app.key('DEL')
    rows = [r for r, _ in app.rows() if r]
    want = [row(n, a) for n, a in (('anna', 28), ('bob', 40), ('Élodie', 33), ('ZOE', 31), ('Ελένη', 25))]
    check('the list, without case and accents', rows, want)
    app.call('REDRAW')
    check('the count', app.line(238), 'RECORDS:      5')
    # FIND: typing goes there, in any case
    app.type('EL')
    check('FIND EL', [r for r, _ in app.rows() if r][0], row('Élodie', 33))
    app.key('DEL')
    app.key('DEL')
    app.type('ελ')
    check('FIND ελ', [r for r, _ in app.rows() if r][0], row('Ελένη', 25))
    app.key('DEL')
    app.key('DEL')
    # bob's age changed in the form
    app.key('DOWN')
    check('the second chosen', [i for i, (_, inv) in enumerate(app.rows()) if inv], [1])
    app.key('RETURN')
    check('bob in the form', app.line(44)[10:], 'bob')
    app.key('DOWN')
    app.inputs = ['41']
    app.key('RETURN')
    app.command('SAVE')
    check('saved', [r for r, _ in app.rows() if r][0], row('bob', 41))
    # a wrong number: a dialog, nothing changed
    app.key('RETURN')
    app.key('DOWN')
    app.inputs = ['70000']
    app.buttons = [0]
    app.key('RETURN')
    check('70000 not taken', app.line(60)[10:], '   41')
    app.command('LIST')
    # DELETE: the chosen record
    app.buttons = [0]
    app.command('DELETE')
    check('bob deleted', [r for r, _ in app.rows() if r][:2], [row('anna', 28), row('Élodie', 33)])
    check('DELETED said', app.line(238), 'DELETED')
    app.call('REDRAW')
    check('the count', app.line(238), 'RECORDS:      4')
    # 40 more: the list scrolls and pages
    for i in range(40):
        app.command('ADD')
        app.inputs = ['m%02d' % i, str(i)]
        app.key('RETURN')
        app.key('DOWN')
        app.key('RETURN')
        app.command('SAVE')
    app.command('LIST')
    app.type('a')
    app.key('DEL')                           # from the first again
    names = ['anna', 'Élodie'] + ['m%02d' % i for i in range(40)] + ['ZOE', 'Ελένη']
    seen = []
    for step in range(len(names) - 1):
        rows = app.rows()
        sel = [i for i, (_, inv) in enumerate(rows) if inv]
        check('one chosen', len(sel), 1)
        seen.append(rows[sel[0]][0].split()[0])
        app.key('DOWN')
    seen.append(app.rows()[17][0].split()[0])
    check('DOWN through all of them', seen, names)
    app.key('DOWN')                          # past the last: nothing
    check('the last stays', app.rows()[17][0].split()[0], names[-1])
    for step in range(len(names) - 1):
        app.key('UP')
    rows = app.rows()
    check('UP back to the first', (rows[0][0].split()[0], rows[0][1]), ('anna', True))
    app.key('RIGHT')
    check('a screen on', app.rows()[0][0].split()[0], names[18])
    app.key('RIGHT')
    app.key('RIGHT')
    check('the last screen', app.rows()[17][0].split()[0], names[-1])
    app.key('LEFT')
    check('a screen back', app.rows()[0][0].split()[0], names[len(names) - 36])
    # a second table, no key: TAB between them
    app.inputs = ['notes', 'line', '30', '']
    app.buttons = [0, 1]                     # TEXT; the key: NO
    app.command('NEW_TABLE')
    check('the new table', app.line(14)[14:22].rstrip(), 'NOTES')
    for s in ('first', 'second'):
        app.command('ADD')
        app.inputs = [s]
        app.key('RETURN')
        app.command('SAVE')
    check('in the order added', [r for r, _ in app.rows() if r], ['first', 'second'])
    app.key('TAB')
    check('TAB: the first table', app.line(14)[14:22].rstrip(), 'PALS')
    app.key('TAB')
    check('TAB: the second again', app.line(14)[14:22].rstrip(), 'NOTES')
    # the database again, from OPEN
    if app.errors:
        sys.exit('database_check: errors %r' % app.errors)
    print('database_check: a database, two tables, %d records added in the form, the list in '
          'key order without case or accents, FIND, a change, a deletion, scrolling: all right'
          % (5 + 40 + 2))


if __name__ == '__main__':
    main()
