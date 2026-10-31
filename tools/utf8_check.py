#!/usr/bin/env python3
"""utf8_check - src/kernel/utf8.asm (VX_UTF8) in a Z80 emulator (the z80 package).

usage: utf8_check.py prog.bin prog.sym

prog is src/kernel/utf8.asm alone, at #4000 (the Makefile's test-utf8).
Texts in many languages, as UTF-8 from a PC (and the web's signs, the
byte order mark, characters V-OS has not), go through u8_check, u8_cut
and u8_conv in pieces of every size, as NOTEPAD does it; each result
must be what tools/voscs.py makes of the same text. Texts that are not
UTF-8 (ISO 8859-7, Latin-1, cut short) must be found so.
"""
import random
import sys

sys.path.insert(0, __import__('os').path.dirname(__file__))
import voscs  # noqa: E402,F401  (the codec "vos")

CALL = 0x0100
BUF = 0x8000

TEXTS = [
    'Hello, world: plain ASCII.\r\n',
    'ΕΛΛΗΝΙΚΑ: Γειά σου, κόσμε! άέήίόύώ ϊϋΐΰ ς «εισαγωγικά» €5 ‘ναι’\r\n',
    'FRANÇAIS: À bientôt, ça va? être élève, Noël, cœur\r\n',
    'ESPAÑOL: ¿Qué tal? ¡Olé! niño, pingüino\r\n',
    'DEUTSCH: Grüße aus Köln. Straße, Äpfel, Öl, Übung\r\n',
    'ITALIANO: È così, perché? città, più\r\n',
    '\ufeffWith a byte order mark, “quotes” – dashes — and\u00a0spaces\r\n',
    'Not in V-OS: 日本 😀 ŷ Ω≈ç Ł\r\n',
    'µ 5´ £ § ° ± ½\r\n',
]


def want(text):
    return text.replace('\ufeff', '').encode('vos', errors='replace')


def main():
    import z80
    prog = open(sys.argv[1], 'rb').read()
    sym = {}
    for line in open(sys.argv[2]):
        p = line.split()
        if len(p) >= 2 and p[1].startswith('#'):
            sym[p[0].upper()] = int(p[1][1:], 16)
    m = z80.Z80Machine()
    mem = bytearray(65536)
    mem[0x4000:0x4000 + len(prog)] = prog
    m.set_memory_block(0, bytes(mem))
    m.set_breakpoint(CALL + 3)

    def call(name, hl=0, bc=0):
        a = sym[name]
        m.set_memory_block(CALL, bytes([0xCD, a & 255, a >> 8, 0x18, 0xFE]))
        m.sp, m.pc, m.hl, m.bc = 0xBF00, CALL, hl, bc
        for _ in range(1000):
            m.ticks_to_stop = 1000000
            m.run()
            if m.pc == CALL + 3:
                return m.a, m.bc
        sys.exit('utf8_check: %s did not return' % name)

    def convert(data, piece):
        """As NOTEPAD: check all of it in pieces, then convert piece by
        piece, each cut at a whole character, the result packed."""
        call('U8_START')
        for i in range(0, len(data), piece):
            p = data[i:i + piece]
            m.set_memory_block(BUF, p)
            call('U8_CHECK', BUF, len(p))
        is_utf8 = call('U8_IS')[0]
        if not is_utf8:
            return None
        out, at = b'', 0
        while at < len(data):
            p = data[at:at + piece]
            m.set_memory_block(BUF, p)
            n = len(p)
            if at + n < len(data):
                n = call('U8_CUT', BUF, n)[1]
            _, got = call('U8_CONV', BUF, n)
            out += bytes(m.memory[BUF:BUF + got])
            at += n
        return out

    rnd = random.Random(45)
    whole = ''.join(TEXTS)
    checks = 0
    for text in TEXTS + [whole]:
        data = text.encode('utf-8')
        for piece in sorted({4, 5, 7, 16, 61, 512, len(data)} | {rnd.randrange(4, 80) for _ in range(5)}):
            got = convert(data, piece)
            ascii_only = all(b < 128 for b in data)
            if ascii_only:
                if got is not None:
                    fail('ASCII taken for UTF-8')
                continue
            if got != want(text):
                fail('%r in pieces of %d:\n got  %r\n want %r' % (text[:30], piece, got, want(text)))
            checks += 1
    for name, data in (('ISO 8859-7', TEXTS[1].encode('iso8859_7')),
                       ('Latin-1', TEXTS[2].replace('œ', 'oe').encode('latin-1')),
                       ('V-OS', TEXTS[3].encode('vos')),
                       ('cut short', TEXTS[1].encode('utf-8')[:-3] + 'Γ'.encode('utf-8')[:1])):
        if convert(data, 512) is not None:
            fail('%s taken for UTF-8' % name)
        checks += 1
    print('utf8_check: %d texts and pieces into the V-OS set, 4 that are not UTF-8: all right' % checks)


def fail(msg):
    sys.exit('utf8_check: ' + msg)


if __name__ == '__main__':
    main()
