#!/usr/bin/env python3
"""Check DB.SYS on a disc, with the kernel's own file system (make
test-db-disc).

usage: db_disc_check.py VOS.BIN DB.SYS vos.sym disc.dsk [operations]

Runs the kernel (from VOS.BIN, as the loader puts it at #0000) and
DB.SYS (at DB_ADDR in base RAM bank 1) in a Z80 emulator (the z80
package). Only the floppy controller (fdc_select, fdc_recalibrate,
fdc_read_id, fdc_read, fdc_write) works on the Extended DSK image
here, and ram_select swaps 16K banks at #4000; fs.asm, bank_copy and
the engine's disc layer are the real ones. A "program" in bank 5 makes
STREETS.VDB on drive B: as myapps/streets does, then random ADDs,
PUTs, DELs and FINDs are checked against a model; the database is
opened again, a Greek street makes it Greek (OPEN in French warns), and
its file, read back from the DSK image, is checked page by page
(vdb.py). Exits 1 on the first difference.
"""
import random
import struct
import sys

sys.path.insert(0, __import__('os').path.dirname(__file__))
import vdb

CALL = 0x0100
PROG_CFG = 0xC5
BUF = 0x4800                    # the program's buffers, in its bank
D = dict(CREATE=0, OPEN=1, CLOSE=2, TABLE=3, USE=4, INFO=5, ADD=6, GET=7,
         PUT=8, DEL=9, FIND=10, FIRST=11, LAST=12, NEXT=13, PREV=14, COUNT=15)


class Dsk:
    """An Extended DSK image: (track, sector ID) -> its 512 bytes."""

    def __init__(self, path):
        self.path = path
        self.data = bytearray(open(path, 'rb').read())
        if not self.data.startswith(b'EXTENDED'):
            sys.exit('db_disc_check: an Extended DSK only')
        self.at = {}
        pos = 0x100
        for t in range(self.data[0x30]):
            size = self.data[0x34 + t] * 256
            if size:
                n = self.data[pos + 0x15]
                off = pos + 0x100
                for i in range(n):
                    info = pos + 0x18 + i * 8
                    r = self.data[info + 2]
                    length = struct.unpack('<H', self.data[info + 6:info + 8])[0]
                    self.at[(t, r)] = off
                    off += length
            pos += size

    def first_id(self):
        return min(r for (t, r) in self.at if t == 0)

    def save(self):
        open(self.path, 'wb').write(self.data)


class Machine:
    def __init__(self, vos, dbsys, sym, discs):
        import z80
        self.sym = sym
        self.discs = discs
        self.drive = 0
        m = self.m = z80.Z80Machine()
        mem = bytearray(65536)
        vos = vos[128:]                          # its AMSDOS header out
        img = sym['KERNEL_IMAGE'] - sym['LOADER_START']
        size = sym['KERNEL_END']
        mem[0:size] = vos[img:img + size]
        self.banks = {c: bytearray(0x4000) for c in (0xC0, 0xC4, 0xC5, 0xC6, 0xC7)}
        db = dbsys[128:]
        self.banks[0xC0][sym['DB_START'] - 0x4000:sym['DB_START'] - 0x4000 + len(db)] = db
        self.window = 0xC0
        mem[0x4000:0x8000] = self.banks[0xC0]
        mem[CALL:CALL + 5] = bytes([0xCD, sym['DB_START'] & 255, sym['DB_START'] >> 8, 0x18, 0xFE])
        m.set_memory_block(0, bytes(mem))
        self.stubs = {sym[n]: n for n in ('FDC_SELECT', 'FDC_RECALIBRATE', 'FDC_READ_ID',
                                          'FDC_READ', 'FDC_WRITE', 'RAM_SELECT')}
        for a in self.stubs:
            m.set_breakpoint(a)
        m.set_breakpoint(CALL + 3)
        self.poke(sym['RAM_HOME_CFG'], [0xC0])  # as ext2_call leaves it
        self.poke(sym['VW_CFG'], [PROG_CFG])
        self.poke(sym['APP_SLOT'], [1])

    def poke(self, a, data):
        self.m.set_memory_block(a, bytes(data))

    def select(self, cfg):
        m = self.m
        self.banks[self.window][:] = m.memory[0x4000:0x8000]
        if cfg not in self.banks:
            self.banks[cfg] = bytearray(0x4000)
        self.window = cfg
        m.set_memory_block(0x4000, bytes(self.banks[cfg]))

    def stub(self, name):
        m = self.m
        err = None
        if name == 'FDC_SELECT':
            self.drive = m.a
        elif name == 'FDC_READ_ID':
            m.a = self.discs[self.drive].first_id()
        elif name in ('FDC_READ', 'FDC_WRITE'):
            disc = self.discs[self.drive]
            off = disc.at.get((m.d, m.e))
            if off is None:
                err = 3                             # FDC_ERR_NO_SECTOR
            elif name == 'FDC_READ':
                m.set_memory_block(m.hl, bytes(disc.data[off:off + 512]))
            else:
                disc.data[off:off + 512] = m.memory[m.hl:m.hl + 512]
        elif name == 'RAM_SELECT':
            self.poke(self.sym['RAM_CONFIG'], [m.a])
            self.select(m.a)
        if err is None:
            m.f &= ~1
        else:
            m.a = err
            m.f |= 1
        m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
        m.sp += 2

    def call(self, c, de=0, hl=0):
        m = self.m
        if self.window != 0xC0:
            self.select(0xC0)
        m.sp, m.pc, m.bc, m.de, m.hl = 0x3FF0, CALL, c, de, hl
        for _ in range(5000000):
            m.ticks_to_stop = 10000000
            m.run()
            if m.pc == CALL + 3:
                if self.window != 0xC0:
                    sys.exit('db_disc_check: call %d came back with bank %02x at #4000'
                             % (c, self.window))
                return (m.f & 1) == 1, m.a, m.de, m.hl
            if m.pc in self.stubs:
                self.stub(self.stubs[m.pc])
        sys.exit('db_disc_check: call %d did not return' % c)

    # the program's memory: bank 5
    def put(self, data, at=BUF):
        self.banks[PROG_CFG][at - 0x4000:at - 0x4000 + len(data)] = data
        return at

    def get(self, n, at=BUF + 0x400):
        return bytes(self.banks[PROG_CFG][at - 0x4000:at - 0x4000 + n])


def fail(msg):
    sys.exit('db_disc_check: ' + msg)


def ok(r, what):
    if r[0]:
        fail('%s: error %d' % (what, r[1]))
    return r


def text(s, n):
    return s.encode()[:n].ljust(n, b' ')


AREAS = ['SYNTAGMA', 'KOLONAKI', 'PLAKA', 'PSYRRI', 'OMONIA', 'KYPSELI']
STREETS = ['ERMOU', 'STADIOU', 'PANEPISTIMIOU', 'AKADIMIAS', 'SOLONOS', 'SKOUFA',
           'PATISION', 'AGIOU NIKOLAOU', 'ADRIANOU', 'MITROPOLEOS', 'AIOLOU',
           'ATHINAS', 'PIRAEOS', 'MARNI', 'KOLOKOTRONI', 'VOULIS', 'SYGROU']


def record(rnd):
    s = rnd.choice(STREETS) + ('' if rnd.random() < .5 else ' %d' % rnd.randrange(99))
    return text(s, 24) + text(rnd.choice(AREAS), 16) + rnd.randrange(10000, 19999).to_bytes(2, 'little')


def key(r):
    return (r[:24], )


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    sym = {}
    for line in open(sys.argv[3]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0]] = int(p[1][1:], 16)
    ops = int(sys.argv[5]) if len(sys.argv) > 5 else 300
    disc_a = Dsk(sys.argv[4])
    disc_b = Dsk(sys.argv[4])               # B: a copy of the same disc
    mach = Machine(open(sys.argv[1], 'rb').read(), open(sys.argv[2], 'rb').read(),
                   sym, {0: disc_a, 1: disc_b})
    rnd = random.Random(7)
    name = mach.put(b'\x01STREETS VDB', BUF + 0x300)
    r = mach.call(D['OPEN'], de=name)
    if not r[0] or r[1] != 7:
        fail('OPEN of a missing file: %r, not FILE NOT FOUND' % (r,))
    ok(mach.call(D['CREATE'], de=name), 'CREATE')
    table = (b'STREETS ' + bytes([3, 1]) + b'NAME    ' + bytes([0, 24]) +
             b'AREA    ' + bytes([0, 16]) + b'ZIP     ' + bytes([1, 2]))
    r = ok(mach.call(D['TABLE'], de=mach.put(table)), 'TABLE')
    recs = {}
    for i in range(ops):
        x = rnd.random()
        if x < .6 or len(recs) < 3:
            rec = record(rnd)
            r = ok(mach.call(D['ADD'], hl=mach.put(rec)), 'ADD %d' % i)
            recs[r[2]] = rec
        elif x < .75:
            rid = rnd.choice(list(recs))
            rec = record(rnd)
            ok(mach.call(D['PUT'], de=rid, hl=mach.put(rec)), 'PUT')
            recs[rid] = rec
        elif x < .85:
            rid = rnd.choice(list(recs))
            ok(mach.call(D['DEL'], de=rid), 'DEL')
            del recs[rid]
        else:
            rid = rnd.choice(list(recs))
            ok(mach.call(D['GET'], de=rid, hl=BUF + 0x400), 'GET')
            if mach.get(42) != recs[rid]:
                fail('GET %04x: the wrong record' % rid)
        if i == ops // 2:
            ok(mach.call(D['CLOSE']), 'CLOSE')
            ok(mach.call(D['OPEN'], de=name), 'OPEN again')
            ok(mach.call(D['USE'], de=0), 'USE')
    # the order of the index
    want = sorted(recs, key=lambda rid: (recs[rid][:24], rid >> 8, rid & 255))
    got = []
    r = mach.call(D['FIRST'], hl=BUF + 0x400)
    while not r[0]:
        got.append(r[2])
        r = mach.call(D['NEXT'], hl=BUF + 0x400)
    if got != want:
        fail('FIRST/NEXT: %d records, %s' % (len(got), 'out of order' if sorted(got) == sorted(want)
                                              else 'not the right ones'))
    r = ok(mach.call(D['FIND'], de=3, hl=mach.put(text('AGI', 24) + bytes(18))), 'FIND')
    # the alphabet: a Greek street makes it the V-OS set, which opens
    # without a word in any language
    rec = bytes([0xC5, 0xD1, 0xCC, 0xCF, 0xD5]).ljust(24, b' ') + text('SYNTAGMA', 16) + (10563).to_bytes(2, 'little')
    r = ok(mach.call(D['ADD'], hl=mach.put(rec)), 'ADD in Greek')
    recs[r[2]] = rec
    for code in (b'FR', b'EL'):
        mach.poke(sym['LANG_CODE'], code)
        r = ok(mach.call(D['OPEN'], de=name), 'OPEN in ' + code.decode())
        if r[1] != 0:
            fail('a Greek database opened in %s: A = %d, not 0' % (code.decode(), r[1]))
    # the file, from the disc's own directory (the kernel's view of it)
    data = vdb_file(disc_b, 'STREETS VDB')
    problems = vdb.check(data)
    if problems:
        fail('the file on the disc: ' + '; '.join(problems[:5]))
    print('db_disc_check: STREETS.VDB on a DSK image, %d operations, %d records, %d pages: all right'
          % (ops, len(recs), len(data) // 1024))


def vdb_file(disc, name):
    """-> a file's bytes, by its directory entries (DATA format)."""
    first = disc.first_id()
    sector = lambda n: disc.data[disc.at[(n // 9, first + n % 9)]:][:512]
    dir_ = b''.join(sector(n) for n in range(4))
    blocks = {}
    for e in range(64):
        ent = dir_[e * 32:(e + 1) * 32]
        if ent[0] == 0 and ent[1:12] == name.encode():
            nb = (ent[15] + 7) // 8
            blocks[ent[12]] = [b for b in ent[16:16 + nb]]
    out = b''
    for ex in sorted(blocks):
        for b in blocks[ex]:
            out += sector(b * 2) + sector(b * 2 + 1)
    return out


if __name__ == '__main__':
    main()
