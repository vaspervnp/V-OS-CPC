#!/bin/bash
# mkwindows - V-OS for Windows: build/V-OS-windows.zip, a folder with
# V-OS.exe (tools/windows/launcher.cs) and CPCEMU for Windows (cpc-emu.org,
# freeware, (C) Marco Vieth & Rainer Loritz), set up by vos.cfg as a
# CPC 6128 with a 512K RAM expansion (576K), an AMX mouse and an M4
# board, vos.dsk in A: and vrouves.dsk in B:. CPCEMU runs the DISC.BAS
# of drive A: at the start; the package's vos.dsk has one: RUN"VOS".
# The emulator's sample discs are left out.
# usage: tools/mkwindows.sh path/to/cpcemu_portable-win32-x86-3.0.2.zip
# Needs WSL: it builds the .exe with Windows' own C# compiler (.NET 4).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$(realpath "${1:?usage: mkwindows.sh cpcemu_portable-win32-x86-3.0.2.zip}")"
CSC=/mnt/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe
WIN="$ROOT/build/win"
OUT="$WIN/V-OS"
rm -rf "$OUT" "$WIN/unzip"
mkdir -p "$OUT" "$WIN/unzip"
unzip -q "$ZIP" -d "$WIN/unzip"
mv "$WIN/unzip/"cpcemu-* "$OUT/cpcemu"
rm -rf "$OUT/cpcemu/DISC/"* "$OUT/cpcemu/DISC/".??*
find "$OUT" -name .DS_Store -delete
CFG="$OUT/cpcemu/vos.cfg"
sed -e 's|^DRIVE_A = .*|DRIVE_A = "./DISC/VOS.DSK"\t;V-OS|' \
    -e 's|^DRIVE_B = .*|DRIVE_B = "./DISC/VROUVES.DSK"\t;VROUVES|' \
    -e 's|^MOUSE_ENABLED = .*|MOUSE_ENABLED = 1\t\t;the mouse in the menus\r\nMOUSE_TYPE = 1\t\t\t;and an AMX mouse for the CPC|' \
    -e 's|^RAM_SIZE = 128\t\t\t;128 KB RAM (up to 576 possible)|RAM_SIZE = 576\t\t\t;a 512K RAM expansion|' \
    "$OUT/cpcemu/cpcemu0.cfg" > "$CFG"
sed -i "s/\r\$//; s/\$/\r/" "$CFG"       # CRLF, as CPCEMU writes it
grep -q "^RAM_SIZE = 576" "$CFG" && grep -q "^MOUSE_TYPE = 1" "$CFG" && grep -q "VOS.DSK" "$CFG"
cp "$ROOT/build/vos.dsk" "$OUT/cpcemu/DISC/VOS.DSK"
cp "$ROOT/build/vrouves.dsk" "$OUT/cpcemu/DISC/VROUVES.DSK"
printf '10 RUN"VOS"\r\n\032' > "$WIN/DISC.BAS"
iDSK "$OUT/cpcemu/DISC/VOS.DSK" -i "$WIN/DISC.BAS" -t 0 > /dev/null
cp "$ROOT/tools/windows/launcher.cs" "$WIN/launcher.cs"
( cd "$WIN" && "$CSC" /nologo /target:winexe /out:V-OS/V-OS.exe \
    /reference:System.Windows.Forms.dll launcher.cs )
cp "$ROOT/tools/windows/README.txt" "$OUT/"
rm -f "$ROOT/build/V-OS-windows.zip"
( cd "$WIN" && zip -q -r "$ROOT/build/V-OS-windows.zip" V-OS )
echo "build/V-OS-windows.zip: $(du -h "$ROOT/build/V-OS-windows.zip" | cut -f1)"
