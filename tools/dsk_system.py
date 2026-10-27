#!/usr/bin/env python3
"""Turn an AMSDOS DATA disc image into a SYSTEM format one, for tests.

usage: dsk_system.py in.dsk out.dsk

DATA:   sector IDs #C1-#C9, the directory starts on track 0.
SYSTEM: sector IDs #41-#49, two reserved tracks, the directory on track 2.
Data track t becomes track t + 2 with renumbered sectors, so block numbers
stay valid; the last two data tracks (blocks 171-179) are dropped. The
reserved tracks are left empty (#E5), so the image is not bootable with
|CPM, only readable. Input and output are Extended DSK, one side.
"""
import sys

TRACKS = 40


def main():
    src, dst = sys.argv[1], sys.argv[2]
    d = open(src, 'rb').read()
    if not d.startswith(b'EXTENDED CPC DSK File'):
        sys.exit('dsk_system: need an Extended DSK image')
    if d[0x31] != 1:
        sys.exit('dsk_system: one side only')
    sizes = d[0x34:0x34 + d[0x30]]
    tracks, pos = [], 0x100
    for s in sizes:
        tracks.append(d[pos:pos + s * 256])
        pos += s * 256

    def renumber(track, number):
        t = bytearray(track)
        t[0x10] = number
        for i in range(t[0x15]):
            o = 0x18 + i * 8
            t[o] = number
            t[o + 2] = (t[o + 2] - 0xC1) + 0x41
        return bytes(t)

    def empty(number):
        t = bytearray(tracks[0])
        t[0x100:] = b'\xE5' * (len(t) - 0x100)
        return renumber(bytes(t), number)

    out = [empty(0), empty(1)]
    out += [renumber(tracks[t], t + 2) for t in range(TRACKS - 2)]
    head = bytearray(d[:0x100])
    head[0x30] = TRACKS
    head[0x34:0x100] = bytes(0x100 - 0x34)
    for i, t in enumerate(out):
        head[0x34 + i] = len(t) // 256
    open(dst, 'wb').write(bytes(head) + b''.join(out))


if __name__ == '__main__':
    main()
