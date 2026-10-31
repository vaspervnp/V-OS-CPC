#!/usr/bin/env python3
"""Check NOTEPAD's text window (make test-notepad-big).

usage: notepad_check.py notepad.bin notepad.sym

Runs NOTEPAD (assembled at #4000, with its symbols) in a Z80 emulator
(the z80 package) with the V-OS calls stubbed: a 16K data bank for
VOS_BANK_GET, VOS_BANK_PUT, VOS_LOAD and VOS_SAVE with VOS_DATA, and
VX_DATA saying whether the bank is its own. With one (a RAM expansion)
a 12K file is loaded, the cursor moved down and up across it and text
typed, and after every key the whole text (before the window, the
window, after it), the cursor's place and its line number must be
what they should; then SAVE must write the file with the change. A new
text of 6K is typed, which makes the window move as it fills. On a
6128 (no bank of its own) the same file is too big, and a small one is
loaded, edited and saved. Files in UTF-8 (12K, and 3K on a 6128), in
many languages, must come into the V-OS character set (VX_UTF8, as
tools/voscs.py; the kernel's own code is checked by make test-utf8),
and be saved so. Exits 1 on the first
difference.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voscs  # noqa: E402,F401  (the codec "vos")

API = 0x0108
CALLS = 43
LOAD, SAVE, BANK_GET, BANK_PUT, EXT = 25, 26, 37, 38, 42
VX_DATA, VX_UTF8 = 7, 9
VE_KEY_DOWN = 1
VK_UP, VK_DOWN, VK_RETURN = 0, 2, 18
CMD_SAVE = 32 + 3
KEY_X = 63                      # a letter's key (not an arrow, DEL, RETURN)


class Notepad:
    def __init__(self, prog, sym, big):
        import z80
        self.sym, self.big = sym, big
        self.m = z80.Z80Machine()
        mem = bytearray(65536)
        mem[0x4000:0x4000 + len(prog)] = prog
        for i in range(CALLS):
            mem[API + i * 3] = 0xAF              # xor a: A = 0, Z
            mem[API + i * 3 + 1] = 0xC9          # ret
        mem[0x0100:0x0102] = b'\x18\xfe'      # jr $: returned (not HALT,
                                                 # which would stop the next call)
        self.m.set_memory_block(0, bytes(mem))
        for i in range(CALLS):
            self.m.set_breakpoint(API + i * 3)
        self.m.set_breakpoint(0x0100)
        self.bank = bytearray(0x4000)
        self.disc = {}
        self.saved = None

    def w(self, name):
        a = self.sym[name]
        return self.m.memory[a] | self.m.memory[a + 1] << 8

    def call(self, name, a=0, hl=0):
        m = self.m
        m.set_memory_block(0xBEFE, bytes([0x00, 0x01]))
        m.sp, m.pc, m.a, m.hl = 0xBEFE, self.sym[name], a, hl
        for _ in range(200000):
            m.ticks_to_stop = 5000000
            m.run()
            if m.pc == 0x0100:
                return
            if not API <= m.pc < API + CALLS * 3:
                continue
            n = (m.pc - API) // 3
            if n == BANK_GET:
                assert 0x4000 <= m.hl and m.hl + m.bc <= 0x8000, 'BANK_GET %x %x' % (m.hl, m.bc)
                m.set_memory_block(m.de, bytes(self.bank[m.hl - 0x4000:m.hl - 0x4000 + m.bc]))
            elif n == BANK_PUT:
                assert 0x4000 <= m.de and m.de + m.bc <= 0x8000, 'BANK_PUT %x %x' % (m.de, m.bc)
                self.bank[m.de - 0x4000:m.de - 0x4000 + m.bc] = m.memory[m.hl:m.hl + m.bc]
            elif n == LOAD:
                data = self.disc[bytes(m.memory[m.hl:m.hl + 11])]
                assert m.a & 0x80 and m.de == 0x4000
                self.bank[:len(data)] = data
                m.bc = len(data)
                m.a = 0
                m.f &= ~1
            elif n == SAVE:
                assert m.a & 0x80 and m.de == 0x4000
                self.saved = bytes(self.bank[:m.bc])
                m.a = 0
                m.f &= ~1
            elif n == EXT and m.a == VX_UTF8:      # as kernel/utf8.asm does
                assert m.e & 0x80 and m.hl == 0x4000
                data = bytes(self.bank[:m.bc])
                try:
                    text = data.decode('utf-8') if max(data, default=0) > 127 else None
                except UnicodeDecodeError:
                    text = None
                m.a = 0
                if text is not None:
                    out = text.replace('\ufeff', '').encode('vos', errors='replace')
                    self.bank[:len(out)] = out
                    m.bc, m.a = len(out), 1
                m.f &= ~1
            elif n == EXT:
                m.a = self.big if m.a == VX_DATA else 0
                m.f &= ~1
            else:
                m.a = 0
                m.f = (m.f | 0x40) & ~1           # Z, no carry
            m.pc = m.memory[m.sp] | m.memory[m.sp + 1] << 8
            m.sp += 2
        sys.exit('notepad_check: %s did not return' % name)

    def key(self, code, char=0):
        self.m.set_memory_block(0xBF00, bytes([VE_KEY_DOWN, code, char, 0]))
        self.call('EVENT', hl=0xBF00)

    def text(self):
        """-> all of the text, the cursor's place in it."""
        plen, slen = self.w('PLEN'), self.w('SLEN')
        t, tend, cur = self.sym['TEXT'], self.w('TEND'), self.w('CUR')
        assert t <= cur <= tend <= t + 4096, (hex(cur), hex(tend))
        assert plen + slen + tend - t <= 0x4000
        win = bytes(self.m.memory[t:tend])
        return bytes(self.bank[:plen]) + win + bytes(self.bank[0x4000 - slen:]), plen + cur - t


def check(np, want, pos, what):
    got, at = np.text()
    if got != want or at != pos:
        sys.exit('notepad_check: %s: text %s, cursor %d (want %d)'
                 % (what, 'right' if got == want else 'wrong', at, pos))
    lines = np.w('PLINES') + bytes(np.m.memory[np.sym['TEXT']:np.w('CUR')]).count(10)
    if lines != want[:pos].count(10):
        sys.exit('notepad_check: %s: %d lines before the cursor, not %d'
                 % (what, lines, want[:pos].count(10)))


def line_starts(t):
    return [0] + [i + 1 for i, c in enumerate(t) if c == 10]


def run(prog, sym, big, n_lines):
    np = Notepad(prog, sym, big)
    np.call('INIT', a=0)
    lines = [b'LINE %04d: THE QUICK BROWN FOX\tJUMPS %s' % (i, b'.' * (i % 23))
             for i in range(n_lines)]
    file = b'\r\n'.join(lines) + b'\r\n\x1aJUNK AFTER THE END'
    np.disc[b'BIG     TXT'] = file
    np.m.set_memory_block(np.sym['NAME_TMP'], b'BIG     TXT')
    np.call('LOAD_FILE')
    text = b'\n'.join(l.replace(b'\t', b' ') for l in lines) + b'\n'
    if not big and len(file) > 4096:
        got, _ = np.text()
        if got:
            sys.exit('notepad_check: a 6128 took a file of %d bytes' % len(file))
        print('notepad_check: 6128: %d bytes too big, as it should be' % len(file))
        return
    check(np, text, 0, 'loaded')
    row = 0
    moves = 0
    for down in range(min(n_lines, 280)):
        np.key(VK_DOWN)
        row = min(row + 1, n_lines)
        check(np, text, line_starts(text)[row], 'down to line %d' % row)
        moves += 1
    np.key(KEY_X, ord('X'))                      # typing
    for c in b'YZ':
        np.key(KEY_X, c)
    pos = line_starts(text)[row]
    text = text[:pos] + b'XYZ' + text[pos:]
    pos += 3
    check(np, text, pos, 'typed')
    np.key(VK_RETURN)
    text = text[:pos] + b'\n' + text[pos:]
    pos += 1
    row += 1
    check(np, text, pos, 'RETURN')
    for up in range(min(row, 250)):
        np.key(VK_UP)
        row -= 1
        check(np, text, line_starts(text)[row], 'up to line %d' % row)
    np.call('COMMAND', a=CMD_SAVE)
    want = text.replace(b'\n', b'\r\n')
    if np.saved != want:
        sys.exit('notepad_check: saved %d bytes, not the %d expected'
                 % (len(np.saved or b''), len(want)))
    check(np, text, line_starts(text)[row], 'after SAVE')
    print('notepad_check: %s: %d bytes of text, %d moves, typing, SAVE: all right'
          % ('own data bank' if big else '6128', len(text), moves * 2))


def utf8(prog, sym, big, n_lines):
    """A UTF-8 file: loaded into the V-OS set, then saved so."""
    np = Notepad(prog, sym, big)
    np.call('INIT', a=0)
    words = ['Γειά σου κόσμε', 'À bientôt, ça va?', '¿Qué tal, niño?',
             'Grüße aus Köln', 'È così, città', '“quotes” – € £ ° «»']
    lines = ['%04d %s' % (i, words[i % len(words)] * (1 + i % 3)) for i in range(n_lines)]
    file = ('\ufeff' + '\r\n'.join(lines) + '\r\n').encode('utf-8')
    np.disc[b'UTF8    TXT'] = file
    np.m.set_memory_block(np.sym['NAME_TMP'], b'UTF8    TXT')
    np.call('LOAD_FILE')
    text = ('\n'.join(lines) + '\n').encode('vos')
    check(np, text, 0, 'UTF-8 loaded')
    np.call('COMMAND', a=CMD_SAVE)
    if np.saved != text.replace(b'\n', b'\r\n'):
        sys.exit('notepad_check: the UTF-8 file saved wrong')
    print('notepad_check: %s: a UTF-8 file of %d bytes, %d in the V-OS set, SAVE: all right'
          % ('own data bank' if big else '6128', len(file), len(text)))


def typing(prog, sym):
    """A new text typed, 6K: the window fills and moves as it goes."""
    np = Notepad(prog, sym, 1)
    np.call('INIT', a=0)
    text = b''
    for i in range(6000):
        if i % 50 == 49:
            np.key(VK_RETURN)
            text += b'\n'
        else:
            c = b'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[i % 26]
            np.key(KEY_X, c)
            text += bytes([c])
        if i % 250 == 0:
            check(np, text, len(text), 'typed %d' % i)
    check(np, text, len(text), 'typed')
    np.m.set_memory_block(np.sym['FNAME'], b'NEW     TXT')
    np.call('COMMAND', a=CMD_SAVE)
    if np.saved != text.replace(b'\n', b'\r\n'):
        sys.exit('notepad_check: the typed text saved wrong')
    check(np, text, len(text), 'typed, after SAVE')
    for i in range(6000, 16500):                # on to the end: 16K
        c = b'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[i % 26]
        np.key(KEY_X, c)
        if len(text) < 0x4000:
            text += bytes([c])
    check(np, text, len(text), 'typed to the end')
    np.saved = None
    np.call('COMMAND', a=CMD_SAVE)              # with CRs more than 16K
    if np.saved is not None:
        sys.exit('notepad_check: a file of more than 16K saved')
    check(np, text, len(text), 'too big to save')
    print('notepad_check: own data bank: %d bytes typed, SAVE: all right; '
          'the text stops at 16K, too big to save with CRs' % 6000)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0]] = int(p[1][1:], 16)
    run(prog, sym, 1, 300)          # 12K: the window moves
    run(prog, sym, 0, 300)          # too big on a 6128
    run(prog, sym, 0, 60)           # 3K on a 6128
    utf8(prog, sym, 1, 240)         # 12K of UTF-8: pieces of 4K
    utf8(prog, sym, 0, 60)          # 3K on a 6128
    typing(prog, sym)


if __name__ == '__main__':
    main()
