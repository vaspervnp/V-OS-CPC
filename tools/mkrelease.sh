#!/bin/bash
# mkrelease - V-OS to hand out: build/V-OS-<version>.zip with the discs,
# the manual's PDFs, the promo's pictures, the demo videos (those that
# were made, tools/video) and LICENSE, for a GitHub Release. make release
# builds the discs and the PDFs first.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BCD=$(sed -n 's/^VOS_VERSION *equ *#\([0-9]\{4\}\).*/\1/p' "$ROOT/src/version.inc")
V=$((10#${BCD:0:2})).${BCD:2:2}         # #0029 is 0.29
OUT="$ROOT/build/release/V-OS-$V"
rm -rf "$ROOT/build/release"
mkdir -p "$OUT/discs" "$OUT/manual" "$OUT/pictures" "$OUT/videos"

cp "$ROOT/LICENSE" "$OUT/LICENSE.txt"
sed "s/{VERSION}/$V/" "$ROOT/tools/release/README.txt" > "$OUT/README.txt"
cp "$ROOT/build/vos.dsk" "$ROOT/build/apps.dsk" "$OUT/discs/"
for d in "$@"; do cp "$ROOT/$d" "$OUT/discs/"; done
cp "$ROOT"/docs/V-OS*.pdf "$OUT/manual/"
cp "$ROOT"/docs/promo/*.png "$OUT/pictures/"
ls "$ROOT"/build/V-OS-demo-*.mp4 > /dev/null 2>&1 \
    && cp "$ROOT"/build/V-OS-demo-*.mp4 "$OUT/videos/" || rmdir "$OUT/videos"
# CRLF for Windows' Notepad
for t in "$OUT"/*.txt; do sed -i 's/$/\r/' "$t"; done

rm -f "$ROOT/build/V-OS-$V.zip"
( cd "$ROOT/build/release" && zip -q -r -9 "$ROOT/build/V-OS-$V.zip" "V-OS-$V" )
echo "build/V-OS-$V.zip: $(du -h "$ROOT/build/V-OS-$V.zip" | cut -f1)"
for b in V-OS-linux.tar.gz V-OS-windows.zip; do
    [ -f "$ROOT/build/$b" ] && echo "build/$b: beside it in the release (make linux, make windows)"
done
true
