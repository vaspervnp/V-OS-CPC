#!/usr/bin/env python3
"""Make a disc image a complete Extended DSK, in place.

usage: dsk_ext.py [--fit] file.dsk

RASM writes an Extended DSK with 42 tracks whose last two are unformatted
(size 0). Some emulators write such images back badly (TerraCPC found that
WinAPE kept only the written track of a standard DSK), so every track is
formatted here: 9 sectors of 512 bytes filled with #E5, with the sector IDs
of track 0 (#C1-#C9 for DATA). A standard ("MV - CPC") image is converted
first. Per-sector lengths are set as the Extended format wants them.

A real 3" disc has 40 tracks: 180 blocks of 1K (DATA), 171 (SYSTEM).
iDSK puts files beyond them on the extra tracks, which work in an
emulator only. A file there is a warning; with --fit (the discs given
out) an error.
"""
import sys


def tracks_of(d):
    """-> header bytes, list of track blocks (b'' for unformatted)."""
    if d.startswith(b'EXTENDED'):
        sizes = [d[0x34 + t] * 256 for t in range(d[0x30])]
    elif d.startswith(b'MV - CPC'):
        size = d[0x32] | d[0x33] << 8
        sizes = [size] * d[0x30]
    else:
        sys.exit('dsk_ext: not a DSK image')
    if d[0x31] != 1:
        sys.exit('dsk_ext: one side only')
    out, pos = [], 0x100
    for size in sizes:
        out.append(d[pos:pos + size])
        pos += size
    return out


def formatted(template, number):
    t = bytearray(template)
    t[0x10] = number
    for i in range(t[0x15]):
        t[0x18 + i * 8] = number
    t[0x100:] = b'\xE5' * (len(t) - 0x100)
    return bytes(t)


def sector(track, sid):
    """-> the bytes of sector sid in a track block, or None."""
    pos = 0x100
    for i in range(track[0x15]):
        e = 0x18 + i * 8
        length = track[e + 6] | track[e + 7] << 8
        if track[e + 2] == sid:
            return track[pos:pos + length]
        pos += length
    return None


def beyond(tracks):
    """-> (names of the files with blocks past a real disc, its blocks)."""
    first = tracks[0][0x18 + 2]
    system = first == 0x41
    dtrack, base, last = (2, 0x41, 171) if system else (0, 0xC1, 180)
    if len(tracks) <= dtrack or not tracks[dtrack]:
        return [], last
    d = b''.join(sector(tracks[dtrack], base + i) or b'' for i in range(4))
    names = set()
    for e in range(0, len(d) - 31, 32):
        x = d[e:e + 32]
        if x[0] < 16 and any(b >= last for b in x[16:32] if b):
            n = bytes(c & 127 for c in x[1:12]).decode('ascii')
            names.add(n[:8].strip() + '.' + n[8:].strip())
    return sorted(names), last


def main():
    args = sys.argv[1:]
    fit = '--fit' in args
    path = [a for a in args if a != '--fit'][0]
    tracks = tracks_of(open(path, 'rb').read())
    names, last = beyond(tracks)
    if names:
        text = (f'dsk_ext: {path}: past block {last - 1}, the end of a '
                f'real disc: {", ".join(names)}')
        if fit:
            sys.exit(text)
        print('warning: ' + text, file=sys.stderr)
    template = tracks[0]
    if template[:10] != b'Track-Info':
        sys.exit('dsk_ext: track 0 is not formatted')
    blocks = []
    for n, t in enumerate(tracks):
        t = bytearray(t if t else formatted(template, n))
        for i in range(t[0x15]):
            e = 0x18 + i * 8
            length = 128 << t[e + 3]
            t[e + 6], t[e + 7] = length & 255, length >> 8
        blocks.append(bytes(t))
    head = bytearray(256)
    head[0:34] = b'EXTENDED CPC DSK File\r\nDisk-Info\r\n'
    head[0x22:0x30] = b'V-OS dsk_ext  '
    head[0x30], head[0x31] = len(blocks), 1
    for n, t in enumerate(blocks):
        head[0x34 + n] = len(t) // 256
    open(path, 'wb').write(bytes(head) + b''.join(blocks))


if __name__ == '__main__':
    main()
