#!/usr/bin/env python3
"""Check the database engine (make test-db).

usage: db_check.py db.bin db.sym [operations [seed]]

Runs src/db/db.asm, built with -DDB_HARNESS (at DB_ADDR, with its
symbols), in a Z80 emulator (the z80 package). Its disc calls are
traps here: a database file is a list of 1K pages, on a disc of 178
blocks. A program's memory is plain RAM. Four tables (a text key, a
number key, none, a 64-byte text key) get thousands of random ADDs, PUTs, DELs, GETs,
FINDs, and walks with FIRST/NEXT and LAST/PREV, each checked against a
model in Python; the database is opened again on the way and at the
end, its file checked page by page (vdb.py), then filled with 64-byte
keys until it is full (an index of several levels). Exits 1 on the first difference.
"""
import random
import sys

sys.path.insert(0, __import__('os').path.dirname(__file__))
import vdb
import voscs  # noqa: F401  (the codec "vos")

TRAP = 0x0040
CALL = 0x0100                   # db_call is called from here
BUF = 0x9000                    # the "program's" buffers
DISC_BLOCKS = 178               # a DATA disc: 180 blocks, 2 for the directory
ERR = dict(EXISTS=10, NOT_FOUND=7, FULL=8)
D = dict(CREATE=0, OPEN=1, CLOSE=2, TABLE=3, USE=4, INFO=5, ADD=6, GET=7,
         PUT=8, DEL=9, FIND=10, FIRST=11, LAST=12, NEXT=13, PREV=14, COUNT=15)
END, RIDERR, DBFULL = 21, 20, 23


class Engine:
    def __init__(self, prog, sym):
        import z80
        self.sym = sym
        self.m = z80.Z80Machine()
        mem = bytearray(65536)
        a = sym['DB_START']
        mem[a:a + len(prog)] = prog
        mem[CALL:CALL + 5] = bytes([0xCD, a & 255, a >> 8, 0x18, 0xFE])  # call; jr $
        for i in range(6):
            mem[TRAP + i * 3] = 0xC9
        self.m.set_memory_block(0, bytes(mem))
        for i in range(6):
            self.m.set_breakpoint(TRAP + i * 3)
        self.m.set_breakpoint(CALL + 3)
        self.files = {}
        self.cur = None

    def used_blocks(self):
        return sum(len(p) for p in self.files.values())

    def name(self):
        a = self.sym['DB_DRIVE']
        return bytes(self.m.memory[a:a + 12])

    def trap(self, n):
        m = self.m
        err = None
        if n == 0:                                  # dk_begin
            pass
        elif n == 1:                                # dk_create
            name = self.name()
            if name in self.files:
                err = ERR['EXISTS']
            elif self.used_blocks() >= DISC_BLOCKS:
                err = ERR['FULL']
            else:
                p0 = bytearray(1024)
                p0[0:5] = b'VDB1\x01'
                self.files[name] = [p0]
                self.cur = self.files[name]
        elif n == 2:                                # dk_open
            name = self.name()
            if name not in self.files:
                err = ERR['NOT_FOUND']
            else:
                self.cur = self.files[name]
        if n in (1, 2) and err is None:             # free blocks at OPEN
            self.m.set_memory_block(self.sym['DB_ROOM'],
                                    bytes([DISC_BLOCKS - self.used_blocks()]))
        if n == 3:                                # dk_read DE -> HL
            if m.de >= len(self.cur):
                err = ERR['NOT_FOUND']
            else:
                m.set_memory_block(m.hl, bytes(self.cur[m.de]))
        elif n == 4:                                # dk_write
            if m.de >= len(self.cur):
                err = ERR['NOT_FOUND']
            else:
                self.cur[m.de] = bytearray(m.memory[m.hl:m.hl + 1024])
        elif n == 5:                                # dk_append
            if self.used_blocks() >= DISC_BLOCKS:
                err = ERR['FULL']
            else:
                self.cur.append(bytearray(1024))
        if err is None:
            m.f &= ~1
        else:
            m.a = err
            m.f |= 1

    def call(self, c, de=0, hl=0):
        m = self.m
        m.set_memory_block(0xBEFE, bytes([0, 0]))
        m.sp, m.pc, m.bc, m.de, m.hl = 0xBF00, CALL, c, de, hl
        for _ in range(2000000):
            m.ticks_to_stop = 10000000
            m.run()
            if m.pc == CALL + 3:
                return (m.f & 1) == 1, m.a, m.de, m.hl
            if TRAP <= m.pc < TRAP + 18:
                self.trap((m.pc - TRAP) // 3)
                m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
                m.sp += 2
        sys.exit('db_check: call %d did not return' % c)

    def poke(self, a, data):
        self.m.set_memory_block(a, bytes(data))

    def put(self, data, at=BUF):
        self.m.set_memory_block(at, bytes(data))
        return at

    def get(self, n, at=BUF + 0x400):
        return bytes(self.m.memory[at:at + n])


def fail(msg):
    sys.exit('db_check: ' + msg)


def ok(r, what):
    if r[0]:
        fail('%s: error %d' % (what, r[1]))
    return r


class Table:
    def __init__(self, name, fields, key):
        self.name, self.fields, self.key = name, fields, key
        self.reclen = sum(f[2] for f in fields)
        self.keyoff = sum(f[2] for f in fields[:key - 1]) if key else 0
        self.keylen = fields[key - 1][2] if key else 0
        self.keytype = fields[key - 1][1] if key else 0
        self.recs = {}              # rid -> bytes
        self.cursor = None          # sort key of the last one returned

    def definition(self):
        d = self.name.ljust(8).encode() + bytes([len(self.fields), self.key])
        for n, t, l in self.fields:
            d += n.ljust(8).encode() + bytes([t, l])
        return d

    def order(self, rid):
        r = self.recs[rid]
        if not self.key:
            return (b'', rid)
        k = r[self.keyoff:self.keyoff + self.keylen]
        if self.keytype == 1:
            k = k[::-1]
        return (k, rid)

    def sorted(self):
        return sorted(self.recs, key=self.order)


def check_walks(e, t, ti):
    ok(e.call(D['USE'], de=ti), 'USE')
    want = t.sorted()
    got = []
    r = e.call(D['FIRST'], hl=BUF + 0x400)
    while not r[0]:
        got.append(r[2])
        if e.get(t.reclen) != t.recs[r[2]]:
            fail('table %d: FIRST/NEXT gave rid %04x with the wrong record' % (ti, r[2]))
        r = e.call(D['NEXT'], hl=BUF + 0x400)
        if len(got) > len(want) + 2:
            break
    if r[1] != END:
        fail('table %d: the walk ended with error %d' % (ti, r[1]))
    if got != want:
        fail('table %d: FIRST/NEXT gave %d records, %s' % (ti, len(got),
             'in the wrong order' if sorted(got) == sorted(want) else 'not the right ones'))
    got = []
    r = e.call(D['LAST'])
    while not r[0]:
        got.append(r[2])
        r = e.call(D['PREV'])
        if len(got) > len(want) + 2:
            break
    if got != want[::-1]:
        fail('table %d: LAST/PREV gave %d records of %d' % (ti, len(got), len(want)))
    r = ok(e.call(D['COUNT']), 'COUNT')
    if r[3] != len(want):
        fail('table %d: COUNT %d, not %d' % (ti, r[3], len(want)))
    t.cursor = None


STREETS = ['ERMOU', 'STADIOU', 'PANEPISTIMIOU', 'AKADIMIAS', 'SOLONOS',
           'PATISION', 'ATHINAS', 'PIRAEOS', 'SYGROU', 'VOULIS', 'MITROPOLEOS',
           'AIOLOU', 'KOLOKOTRONI', 'SKOUFA', 'VASILISSIS SOFIAS', 'IPPOKRATOUS']


def text(s, n):
    return s.encode()[:n].ljust(n, b' ')


def make_record(t, rnd):
    out = b''
    for n, typ, l in t.fields:
        if typ == 1:
            out += rnd.randrange(65536 if rnd.random() < .5 else 40).to_bytes(2, 'little')
        else:
            s = rnd.choice(STREETS) + ('' if rnd.random() < .6 else ' %d' % rnd.randrange(300))
            out += text(s, l)
    return out


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0]] = int(p[1][1:], 16)
    ops = int(sys.argv[3]) if len(sys.argv) > 3 else 3000
    rnd = random.Random(int(sys.argv[4]) if len(sys.argv) > 4 else 44)
    e = Engine(prog, sym)

    r = e.call(D['ADD'], hl=BUF)
    if not r[0] or r[1] != 16:
        fail('ADD with nothing open: not DB_ERR_NONE')
    name = e.put(b'\x00TEST    VDB')
    ok(e.call(D['CREATE'], de=name), 'CREATE')
    if not e.call(D['CREATE'], de=name)[0]:
        fail('CREATE of an existing file worked')
    ok(e.call(D['OPEN'], de=name), 'OPEN')

    tables = [Table('STREETS', [('NAME', 0, 24), ('AREA', 0, 16), ('ZIP', 1, 2)], 1),
              Table('NUMBERS', [('VALUE', 1, 2), ('TEXT', 0, 5)], 1),
              Table('LOG', [('LINE', 0, 30)], 0),
              Table('LONG', [('N', 1, 2), ('KEY', 0, 64)], 2)]
    for i, t in enumerate(tables):
        r = ok(e.call(D['TABLE'], de=e.put(t.definition())), 'TABLE %d' % i)
        if r[1] != i:
            fail('TABLE gave %d, not %d' % (r[1], i))
    bad = Table('BAD', [('X', 0, 0)], 0)
    if not e.call(D['TABLE'], de=e.put(bad.definition()))[0]:
        fail('a field of length 0 was taken')
    for i, t in enumerate(tables):
        ok(e.call(D['INFO'], de=i, hl=BUF + 0x400), 'INFO')
        info = e.get(124)
        if info[10] != t.reclen or info[9] != t.key:
            fail('INFO %d: record length %d, key %d' % (i, info[10], info[9]))

    counts = dict(add=0, put=0, delete=0, get=0, find=0, walk=0)
    for op in range(ops):
        ti = rnd.randrange(len(tables))
        t = tables[ti]
        ok(e.call(D['USE'], de=ti), 'USE')
        x = rnd.random()
        if x < .45 or len(t.recs) < 5:
            rec = make_record(t, rnd)
            r = ok(e.call(D['ADD'], hl=e.put(rec)), 'ADD')
            if r[2] in t.recs:
                fail('ADD gave rid %04x twice' % r[2])
            t.recs[r[2]] = rec
            counts['add'] += 1
        elif x < .6:
            rid = rnd.choice(list(t.recs))
            rec = make_record(t, rnd)
            ok(e.call(D['PUT'], de=rid, hl=e.put(rec)), 'PUT')
            t.recs[rid] = rec
            counts['put'] += 1
        elif x < .75:
            rid = rnd.choice(list(t.recs))
            ok(e.call(D['DEL'], de=rid), 'DEL')
            del t.recs[rid]
            r = e.call(D['GET'], de=rid, hl=BUF + 0x400)
            if not r[0] or r[1] != RIDERR:
                fail('GET of a deleted record worked')
            counts['delete'] += 1
        elif x < .88:
            rid = rnd.choice(list(t.recs))
            ok(e.call(D['GET'], de=rid, hl=BUF + 0x400), 'GET')
            if e.get(t.reclen) != t.recs[rid]:
                fail('GET %04x: the wrong record' % rid)
            counts['get'] += 1
        elif t.key:
            # FIND: a prefix (text) or a whole key, then a few NEXTs
            if t.keytype == 0:
                s = rnd.choice(STREETS)[:rnd.randrange(1, 6)]
                key, n = text(s, t.keylen), len(s)
                prefix = key[:n]
            else:
                v = rnd.randrange(65536 if rnd.random() < .3 else 40)
                key, n = v.to_bytes(2, 'little'), 0
                prefix = v.to_bytes(2, 'big')
            want = [rid for rid in t.sorted() if t.order(rid)[0][:len(prefix)] >= prefix]
            r = e.call(D['FIND'], de=n, hl=e.put(key + bytes(t.reclen)))
            got = []
            while not r[0] and len(got) < 4:
                got.append(r[2])
                r = e.call(D['NEXT'])
            if r[0] and r[1] != END:
                fail('FIND/NEXT: error %d' % r[1])
            if got != want[:len(got)] or (len(got) < 4 and len(want) != len(got)):
                fail('FIND %r in table %d: %s, not %s; %s' % (
                    prefix, ti, got, want[:4],
                    vdb.check(b''.join(e.files[b'\x00TEST    VDB'])) or 'the file is all right'))
            counts['find'] += 1
        if op % 500 == 499:
            for i, tt in enumerate(tables):
                check_walks(e, tt, i)
            counts['walk'] += 1
        if op == ops // 2:
            ok(e.call(D['CLOSE']), 'CLOSE')
            ok(e.call(D['OPEN'], de=e.put(b'\x00TEST    VDB')), 'OPEN again')
    for i, t in enumerate(tables):
        check_walks(e, t, i)
    pages = e.files[b'\x00TEST    VDB']
    problems = vdb.check(b''.join(pages))
    if problems:
        fail('the file: ' + '; '.join(problems[:5]))
    # the alphabet: ASCII text and numbers over 127 leave it 0; Greek or
    # Latin text makes it the V-OS character set (2), which opens without a
    # word; only a Latin-1 file of V-OS 0.15 (1) gives the warning
    def opened(what, want):
        r = ok(e.call(D['OPEN'], de=e.put(b'\x00TEST    VDB')), 'OPEN ' + what)
        if r[1] != want:
            fail('OPEN %s: A = %d, not %d' % (what, r[1], want))
    opened('in ASCII', 0)
    if pages[0][7] != 0:
        fail('ASCII so far, but the alphabet is %d' % pages[0][7])
    ok(e.call(D['USE'], de=2), 'USE')
    rec = 'ΑΘΗΝΑ ÇA GRÜß'.encode('vos').ljust(30, b' ')
    r = ok(e.call(D['ADD'], hl=e.put(rec)), 'ADD in Greek and Latin')
    tables[2].recs[r[2]] = rec
    if pages[0][7] != 2:
        fail('Greek and Latin text, but the alphabet is %d, not 2' % pages[0][7])
    opened('in the V-OS set', 0)
    for old, want in ((7, 0), (1, 1)):
        ok(e.call(D['CLOSE']), 'CLOSE')
        pages[0][7] = old
        opened('with alphabet %d' % old, want)
    ok(e.call(D['CLOSE']), 'CLOSE')
    pages[0][7] = 2
    ok(e.call(D['OPEN'], de=e.put(b'\x00TEST    VDB')), 'OPEN again')
    print('db_check: the alphabet: none for ASCII, the V-OS set after Greek and Latin text, a warning for Latin-1: all right')
    print('db_check: %d operations (%s), %d pages: all right' % (
        ops, ', '.join('%d %s' % (v, k) for k, v in counts.items()), len(pages)))

    # full: the disc's blocks or 255 pages, with 64-byte keys (an index
    # of several levels)
    t = tables[3]
    ok(e.call(D['USE'], de=3), 'USE')
    n = 0
    while True:
        rec = make_record(t, rnd)
        r = e.call(D['ADD'], hl=e.put(rec))
        if r[0]:
            if r[1] not in (ERR['FULL'], DBFULL):
                fail('filling: error %d' % r[1])
            break
        t.recs[r[2]] = rec
        n += 1
    for i, tt in enumerate(tables):
        check_walks(e, tt, i)
    problems = vdb.check(b''.join(e.files[b'\x00TEST    VDB']))
    if problems:
        fail('the full file: ' + '; '.join(problems[:5]))
    data = b''.join(e.files[b'\x00TEST    VDB'])
    print('db_check: %d more records until it was full (%d pages, index levels %s): all right' % (
        n, len(data) // 1024, ', '.join(str(vdb.levels(data, t)) for t in vdb.tables(data) if t['key'])))


if __name__ == '__main__':
    main()
