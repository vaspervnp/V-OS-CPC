#!/bin/bash
# m4_shot.sh FRAME - V-OS in the 1984 emulator for Windows (VOS_1984, by
# default G:\Amstrad\1984\1984.exe) with an M4 board: 576K, A: build/
# vos_run.dsk (|DISC first: with the M4 the SD card is the drive
# AMSDOS starts on, and |A does not change that in 1984), B: a fresh
# copy of build/apps.dsk, the SD card a fresh copy of build/m4sd
# (HELLO.TXT, APPS/NOTEPAD.BIN; with M4_CARD=db STREETS.BIN alone, with
# M4_CARD=net TELNET.BIN alone: made here each time). A snapshot at
# emulator frame FRAME (50 a second, from power on), its screen drawn
# from memory with V-OS's palette (tools/sna_screen.py with M4_SYM, by
# default build/vos_m4.sym: 1984 may have spoilt the inks) -> build/
# shots/M4_SHOT.png (by default FRAME.png); the card as it was then ->
# build/m4run.
set -e
cd "$(dirname "$0")/.."
E1984=${VOS_1984:-/mnt/g/Amstrad/1984/1984.exe}
frame=$1
shot=${M4_SHOT:-$frame}
rm -rf build/m4sd
if [ "$M4_CARD" = db ]; then                # STREETS.BIN alone
    mkdir -p build/m4sd
    cp build/STREETS.BIN build/m4sd/
elif [ "$M4_CARD" = net ]; then             # TELNET.BIN alone
    mkdir -p build/m4sd
    cp build/TELNET.BIN build/m4sd/
else
    mkdir -p build/m4sd/APPS
    printf 'Hello from the SD card.\r\n' > build/m4sd/HELLO.TXT
    cp build/NOTEPAD.BIN build/m4sd/APPS/
fi
rm -rf build/m4run && cp -r build/m4sd build/m4run
cp build/apps.dsk build/vos_b.dsk
mkdir -p build/shots
printf '[machine]\r\nmodel=6128\r\nmemory=576\r\n[hardware]\r\nm4=true\r\nm4_path=%s\r\n' \
    "$(wslpath -w build/m4run)" > build/m4run.conf
win() { wslpath -w "$1"; }
(cd "$(dirname "$E1984")" && timeout 600 "./$(basename "$E1984")" --headless \
    --config="$(win "$OLDPWD/build/m4run.conf")" \
    --disk-a="$(win "$OLDPWD/build/vos_run.dsk")" \
    --disk-b="$(win "$OLDPWD/build/vos_b.dsk")" --paste='|disc
run"vos
' \
    --save-sna-at="$frame:$(win "$OLDPWD/build/shots/$shot.sna")" \
    --screenshot-at="$((frame + 1)):$(win "$OLDPWD/build/shots/$shot.ppm")" 2>&1 | grep -v Vulkan || true)
python3 tools/sna_screen.py "build/shots/$shot.sna" "build/shots/$shot.png" "${M4_SYM:-build/vos_m4.sym}"
[ -n "$KEEP_SNA" ] || rm -f "build/shots/$shot.sna"; rm -f "build/shots/$shot.ppm"
echo "build/shots/$shot.png"
