#!/bin/bash
# Boot build/vos.dsk headless in Caprice32 (CPC 6128, 128K), wait, type
# optional keys, take one screenshot, and exit.
# Runs inside the snap:
#   snap run --shell caprice32.launcher -c "bash tools/cap32_shot.sh [delay] [keys]"
# delay = number of Z keys typed as a wait (default 400). The test build
#         (make test-input) ignores Z; a normal build sees them.
# keys  = Caprice32 autotype text typed after the wait, e.g.
#         'Hello'. Only \(CAP32_...) escapes work; CPC keys such as
#         cursor or COPY cannot be typed (see src/kernel/test_script.asm).
# VOS_DSK overrides the disk image (default build/vos.dsk).
# The screenshot lands in sdump_dir of the snap's cap32.cfg.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DELAY=$(printf 'z%.0s' $(seq 1 "${1:-400}"))
KEYS="${2:-}"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
exec timeout 90 "$SNAP/usr/bin/cap32" --cfg_file="$SNAP_USER_DATA/etc/cap32.cfg" \
  -O system.limit_speed=0 -O system.model=2 -O system.ram_size=128 -O video.scr_fps=0 \
  -a "run\"vos
${DELAY}${KEYS}\(CAP32_SCRNSHOT)\(CAP32_EXIT)" "${VOS_DSK:-$ROOT/build/vos.dsk}"
