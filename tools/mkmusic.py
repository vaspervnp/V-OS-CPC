#!/usr/bin/env python3
"""mkmusic - songs of Arkos Tracker as .MUS files for MUSIC (myapps/music).

usage: mkmusic.py path/to/SongToAkm song.aks|folder [...] -o outdir

A folder stands for its .aks songs.

Each song is exported by Arkos Tracker's SongToAkm as an AKM binary
twice, at #4000 and at #4100; the words that differ by #100 are its
pointers, listed so that MUSIC can move the song to where it loads it.
The name: the song's file name, its letters and digits, 8 at most.
.MUS format (little endian):
   0  "VM", db 1 (format), db 0
   4  dw n: the song's bytes (AKM, as encoded at #4000)
   6  dw r: its pointers
   8  the song, then r x dw: the offsets of the pointers in it
"""
import glob
import os
import re
import subprocess
import sys
import tempfile

SONG_MAX = 6144                     # myapps/music/music.asm


def akm(tool, song, address, out):
    r = subprocess.run([tool, "-bin", "-adr", hex(address), song, out],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        sys.exit(f"mkmusic: {song}: {r.stdout}{r.stderr}")
    return open(out, "rb").read()


def name_of(song, used):
    base = os.path.splitext(os.path.basename(song))[0]
    base = base.split(" - ")[-1]                  # "Author - Title": the title
    name = re.sub(r"[^A-Z0-9]", "", base.upper())[:8] or "SONG"
    n, k = name, 1
    while n in used:
        k += 1
        n = name[:8 - len(str(k))] + str(k)
    used.add(n)
    return n


def main():
    args = sys.argv[1:]
    if "-o" not in args or len(args) < 4:
        sys.exit(__doc__.split("\n")[2])
    i = args.index("-o")
    outdir = args[i + 1]
    tool, songs = args[0], []
    for a in args[1:i] + args[i + 2:]:
        songs += sorted(glob.glob(os.path.join(a, "*.aks"))) if os.path.isdir(a) else [a]
    os.makedirs(outdir, exist_ok=True)
    used = set()
    with tempfile.TemporaryDirectory() as tmp:
        for song in songs:
            lo = akm(tool, song, 0x4000, os.path.join(tmp, "lo.bin"))
            hi = akm(tool, song, 0x4100, os.path.join(tmp, "hi.bin"))
            if len(lo) != len(hi):
                sys.exit(f"mkmusic: {song}: the two exports differ in size")
            if len(lo) > SONG_MAX:
                print(f"mkmusic: {song}: {len(lo)} bytes, more than {SONG_MAX}: left out")
                continue
            offsets = []
            k = 0
            while k < len(lo):
                if lo[k] != hi[k]:
                    if k == 0 or hi[k] != (lo[k] + 1) & 255 or lo[k - 1] != hi[k - 1]:
                        sys.exit(f"mkmusic: {song}: byte {k} is not a pointer's")
                    offsets.append(k - 1)
                k += 1
            name = name_of(song, used)
            data = (b"VM\x01\x00" + len(lo).to_bytes(2, "little")
                    + len(offsets).to_bytes(2, "little") + lo
                    + b"".join(o.to_bytes(2, "little") for o in offsets))
            open(os.path.join(outdir, name + ".MUS"), "wb").write(data)
            print(f"{name}.MUS: {len(lo)} bytes, {len(offsets)} pointers  ({os.path.basename(song)})")


if __name__ == "__main__":
    main()
