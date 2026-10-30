#!/bin/bash
# mklinux - V-OS for Linux: build/V-OS-linux.tar.gz, a folder with the
# V-OS script (tools/linux/V-OS) and CPCEMU 2.5 for Linux x86_64
# (cpc-emu.org, freeware, (C) Marco Vieth & Rainer Loritz; 3.0.2 has no
# Linux build out), set up by vos.cfg as a CPC 6128 with a 512K RAM
# expansion (576K), an AMX mouse and an M4 board, vos.dsk in A: and
# vrouves.dsk in B:. CPCEMU runs the DISC.BAS of drive A: at the start;
# the package's vos.dsk has one: RUN"VOS". The sample discs are left out.
# usage: tools/mklinux.sh path/to/cpcemu-linux-x86_64-2.5.tar.gz
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TGZ="$(realpath "${1:?usage: mklinux.sh cpcemu-linux-x86_64-2.5.tar.gz}")"
LIN="$ROOT/build/linux"
OUT="$LIN/V-OS"
rm -rf "$OUT" "$LIN/untar"
mkdir -p "$OUT" "$LIN/untar"
tar xzf "$TGZ" -C "$LIN/untar"
mv "$LIN/untar/"cpcemu-* "$OUT/cpcemu"
rm -rf "$OUT/cpcemu/DISC/"* "$OUT/cpcemu/DISC/".??*
CFG="$OUT/cpcemu/vos.cfg"
tr -d '\r' < "$OUT/cpcemu/cpcemu0.cfg" |
    sed -e 's|^DRIVE_A = .*|DRIVE_A = "./DISC/VOS.DSK"\t;V-OS|' \
    -e 's|^DRIVE_B = .*|DRIVE_B = "./DISC/VROUVES.DSK"\t;VROUVES|' \
    -e 's|^MOUSE_ENABLED = .*|MOUSE_ENABLED = 1\t\t;the mouse in the menus\r\nMOUSE_TYPE = 1\t\t\t;and an AMX mouse for the CPC|' \
    -e 's|^\(KBD_LANGUAGE = .*\)|\1\r\nVKBD_LANGUAGE = 0\t\t;the virtual keyboard: English, so CPCEMU does not ask|' \
    -e 's|^RAM_SIZE = 128\t\t\t;128 KB RAM (up to 576 possible)|RAM_SIZE = 576\t\t\t;a 512K RAM expansion|' \
    > "$CFG"
sed -i "s/\r\$//; s/\$/\r/" "$CFG"       # CRLF, as CPCEMU writes it
grep -q "^RAM_SIZE = 576" "$CFG" && grep -q "^MOUSE_TYPE = 1" "$CFG" && grep -q "VOS.DSK" "$CFG" && grep -q "^VKBD_LANGUAGE" "$CFG"
cp "$ROOT/build/vos.dsk" "$OUT/cpcemu/DISC/VOS.DSK"
cp "$ROOT/build/vrouves.dsk" "$OUT/cpcemu/DISC/VROUVES.DSK"
printf '10 RUN"VOS"\r\n\032' > "$LIN/DISC.BAS"
iDSK "$OUT/cpcemu/DISC/VOS.DSK" -i "$LIN/DISC.BAS" -t 0 > /dev/null
install -m 755 "$ROOT/tools/linux/V-OS" "$OUT/V-OS"
cp "$ROOT/tools/linux/README.txt" "$OUT/"
rm -f "$ROOT/build/V-OS-linux.tar.gz"
tar czf "$ROOT/build/V-OS-linux.tar.gz" -C "$LIN" V-OS
echo "build/V-OS-linux.tar.gz: $(du -h "$ROOT/build/V-OS-linux.tar.gz" | cut -f1)"
