#!/bin/bash
# mkwindows - V-OS for Windows: build/V-OS-windows.zip, a folder with
# V-OS.exe (tools/windows/launcher.cs), Caprice32 for Windows set to a
# CPC 6128 with 576K, and the discs: vos.dsk in A:, vrouves.dsk in B:.
# usage: tools/mkwindows.sh path/to/cap32-win64.zip
# (github.com/ColinPitrat/caprice32/releases). Needs WSL: it builds the
# .exe with Windows' own C# compiler (.NET Framework 4).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$(realpath "${1:?usage: mkwindows.sh cap32-win64.zip}")"
CSC=/mnt/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe
OUT="$ROOT/build/win/V-OS"
rm -rf "$OUT" "$ROOT/build/win/unzip"
mkdir -p "$OUT/disks" "$ROOT/build/win/unzip"
unzip -q "$ZIP" -d "$ROOT/build/win/unzip"
mv "$ROOT/build/win/unzip/"* "$OUT/caprice32"
sed -i 's/^ram_size=.*/ram_size=576/; s/^model=.*/model=2/; s/^scr_fps=.*/scr_fps=0/' "$OUT/caprice32/cap32.cfg"
cp "$ROOT/build/vos.dsk" "$ROOT/build/vrouves.dsk" "$OUT/disks/"
cp "$ROOT/tools/windows/launcher.cs" "$OUT/../launcher.cs"
( cd "$OUT/.." && "$CSC" /nologo /target:winexe /out:V-OS/V-OS.exe \
    /reference:System.Windows.Forms.dll launcher.cs )
cp "$ROOT/tools/windows/README.txt" "$OUT/"
rm -f "$ROOT/build/V-OS-windows.zip"
( cd "$OUT/.." && zip -q -r "$ROOT/build/V-OS-windows.zip" V-OS )
echo "build/V-OS-windows.zip: $(du -h "$ROOT/build/V-OS-windows.zip" | cut -f1)"
