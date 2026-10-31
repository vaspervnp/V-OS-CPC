#!/usr/bin/env python3
"""V-OS database files (NAME.VDB), as src/db/db.asm writes them.

usage: vdb.py dump file.vdb      its tables and records
       vdb.py check file.vdb     its pages checked (exit 1 on a problem)

A file of 1K pages. Page 0: "VDB1", dw pages, db tables, db alphabet
(0 ASCII so far, 1 Latin-1, 7 Greek: ISO 8859-7), and from 16 a
descriptor of 124 bytes a table: name (8), fields, key field (0: none),
record length, key offset, key length, key type, dw first data page,
last data page, index root, records, a page with room; from 24 ten
fields of name (8), type (0 text, 1 a 2-byte number), length. Data
pages "D": table, dw next, db used, from 8 slots of a used byte and a
record; rid = page * 256 + slot. Index pages: "L" leaves (dw count,
prev, next; entries key + rid) and "I" inner pages (dw count, child 0;
entries key + rid + child). Keys in the index: numbers high byte
first, rids too (page, slot).
"""
import struct
import sys

PAGE = 1024


def tables(data):
    """-> the descriptors of the tables, as dicts."""
    out = []
    for t in range(data[6]):
        d = data[16 + t * 124:16 + (t + 1) * 124]
        first, last, root, count, hint = struct.unpack('<5H', d[14:24])
        fields = []
        for f in range(d[8]):
            fd = d[24 + f * 10:34 + f * 10]
            fields.append((fd[:8].decode('latin-1').rstrip(), fd[8], fd[9]))
        out.append(dict(name=d[:8].decode('latin-1').rstrip(), fields=fields,
                        key=d[9], reclen=d[10], keyoff=d[11], keylen=d[12],
                        keytype=d[13], first=first, last=last, root=root,
                        count=count, hint=hint))
    return out


def records(data, t, ti, problems):
    """-> {rid: record} of table t, walking its data pages."""
    recs = {}
    slots = min(255, (PAGE - 8) // (t['reclen'] + 1))
    page, last, seen = t['first'], 0, set()
    while page:
        if page in seen or page * PAGE >= len(data):
            problems.append('table %d: the data pages loop or end outside' % ti)
            break
        seen.add(page)
        p = data[page * PAGE:(page + 1) * PAGE]
        if p[0:1] != b'D' or p[1] != ti:
            problems.append('table %d: page %d is not its data page' % (ti, page))
            break
        used = 0
        for s in range(slots):
            at = 8 + s * (t['reclen'] + 1)
            if p[at]:
                used += 1
                recs[page * 256 + s] = p[at + 1:at + 1 + t['reclen']]
        if used != p[4]:
            problems.append('table %d: page %d says %d used, has %d' % (ti, page, p[4], used))
        last = page
        page = struct.unpack('<H', p[2:4])[0]
    if last != t['last']:
        problems.append('table %d: the last data page is %d, not %d' % (ti, last, t['last']))
    if len(recs) != t['count']:
        problems.append('table %d: %d records, the count says %d' % (ti, len(recs), t['count']))
    return recs


def entry(t, rec, rid):
    k = rec[t['keyoff']:t['keyoff'] + t['keylen']]
    if t['keytype'] == 1:
        k = k[::-1]
    return k + bytes([rid >> 8, rid & 255])


def index(data, t, ti, problems):
    """-> the entries of the index in leaf order, checked as a B+tree."""
    esz = t['keylen'] + 2
    leaves = []

    def walk(page, lo, hi, depth):
        p = data[page * PAGE:(page + 1) * PAGE]
        n = struct.unpack('<H', p[2:4])[0]
        if depth > 8 or p[1] != ti:
            problems.append('table %d: index page %d is wrong' % (ti, page))
            return
        if p[0:1] == b'L':
            es = [p[8 + i * esz:8 + (i + 1) * esz] for i in range(n)]
            for e in es:
                if (lo is not None and e < lo) or (hi is not None and e >= hi):
                    problems.append('table %d: leaf %d has an entry out of its range' % (ti, page))
            leaves.append((page, es))
        elif p[0:1] == b'I':
            isz = esz + 2
            seps = [p[8 + i * isz:8 + i * isz + esz] for i in range(n)]
            kids = [struct.unpack('<H', p[4:6])[0]] + [
                struct.unpack('<H', p[8 + i * isz + esz:8 + (i + 1) * isz])[0] for i in range(n)]
            if seps != sorted(seps):
                problems.append('table %d: inner page %d out of order' % (ti, page))
            bounds = [lo] + seps + [hi]
            for i, k in enumerate(kids):
                walk(k, bounds[i], bounds[i + 1], depth + 1)
        else:
            problems.append('table %d: page %d is not an index page' % (ti, page))

    walk(t['root'], None, None, 0)
    out = [e for _, es in leaves for e in es]
    if out != sorted(out) or len(set(out)) != len(out):
        problems.append('table %d: the leaves are out of order' % ti)
    pages = [pg for pg, _ in leaves]       # the links: the same order
    for i, pg in enumerate(pages):
        p = data[pg * PAGE:(pg + 1) * PAGE]
        prev, nxt = struct.unpack('<HH', p[4:8])
        if prev != (pages[i - 1] if i else 0) or nxt != (pages[i + 1] if i + 1 < len(pages) else 0):
            problems.append('table %d: leaf %d is linked wrongly' % (ti, pg))
            break
    return out


def levels(data, t):
    """-> the levels of a table's index (1: only the root leaf)."""
    page, n = t['root'], 1
    while data[page * PAGE:page * PAGE + 1] == b'I':
        page = struct.unpack('<H', data[page * PAGE + 4:page * PAGE + 6])[0]
        n += 1
    return n


def check(data):
    """-> a list of problems (empty: all right)."""
    problems = []
    if data[:4] != b'VDB1':
        return ['not a database']
    if struct.unpack('<H', data[4:6])[0] * PAGE != len(data):
        problems.append('page 0 says %d pages, the file has %d'
                        % (struct.unpack('<H', data[4:6])[0], len(data) // PAGE))
    for ti, t in enumerate(tables(data)):
        recs = records(data, t, ti, problems)
        if t['key']:
            got = index(data, t, ti, problems)
            want = sorted(entry(t, r, rid) for rid, r in recs.items())
            if got != want:
                problems.append('table %d: the index has %d entries, %d records'
                                % (ti, len(got), len(want)))
    return problems


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('dump', 'check'):
        sys.exit(__doc__)
    data = open(sys.argv[2], 'rb').read()
    if sys.argv[1] == 'check':
        problems = check(data)
        for p in problems:
            print(p)
        sys.exit(1 if problems else 0)
    print('alphabet: %s' % {0: 'ASCII so far', 1: 'Latin-1 (ISO 8859-1)', 7: 'Greek (ISO 8859-7)'}
          .get(data[7], 'unknown (%d)' % data[7]))
    for ti, t in enumerate(tables(data)):
        print('%d %s: %d records of %d bytes, key %s' % (
            ti, t['name'], t['count'], t['reclen'],
            t['fields'][t['key'] - 1][0] if t['key'] else 'none'))
        for rid, r in sorted(records(data, t, ti, []).items()):
            print('  %04x %r' % (rid, r))


if __name__ == '__main__':
    main()
