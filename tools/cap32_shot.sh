#!/bin/bash
# Boot build/vos.dsk headless in Caprice32 (CPC 6128, 128K), wait, type
# optional keys, take one screenshot, and exit.
# Runs inside the snap:
#   snap run --shell caprice32.launcher -c "bash tools/cap32_shot.sh [delay] [keys]"
# delay = number of Z keys typed as a wait (default 400). The test build
#         (make test-input) ignores Z; a normal build sees them. Several
#         delays, "120,200,350", take a screenshot after each, in one run
#         (each counted from the previous shot).
# keys  = Caprice32 autotype text typed after the wait, e.g.
#         'Hello'. Only \(CAP32_...) escapes work; CPC keys such as
#         cursor or COPY cannot be typed (see src/kernel/test_script.asm).
# VOS_TIMEOUT (seconds, default 40) ends the run. After V-OS has written
# to a disc, Caprice32 does not quit on CAP32_EXIT (it seems to wait for
# an answer about the changed disc), so such runs end here; the
# screenshot is taken before.
# VOS_RAM sets the memory in K (default 128; 576 = a 512K expansion).
# VOS_DSK overrides the disk image (default build/vos.dsk); VOS_DSK_B,
# if set, goes in drive B.
# The screenshot lands in build/shots (VOS_SHOTS overrides it), not in the
# snap's shared folder, where other projects' runs may write meanwhile.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IFS=, read -ra WAITS <<< "${1:-400}"
DELAY=""
for i in "${!WAITS[@]}"; do
  [ "$i" -gt 0 ] && DELAY+='\(CAP32_SCRNSHOT)'
  DELAY+=$(printf 'z%.0s' $(seq 1 "${WAITS[$i]}"))
done
KEYS="${2:-}"
SHOTS="${VOS_SHOTS:-$ROOT/build/shots}"
mkdir -p "$SHOTS"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
exec timeout "${VOS_TIMEOUT:-40}" "$SNAP/usr/bin/cap32" --cfg_file="$SNAP_USER_DATA/etc/cap32.cfg" \
  -O system.limit_speed=0 -O system.model=2 -O system.ram_size=${VOS_RAM:-128} -O video.scr_fps=0 -O "file.sdump_dir=$SHOTS" \
  -a "run\"vos
${DELAY}${KEYS}\(CAP32_SCRNSHOT)\(CAP32_EXIT)" "${VOS_DSK:-$ROOT/build/vos.dsk}" ${VOS_DSK_B:+"$VOS_DSK_B"}
