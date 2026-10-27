#!/bin/bash
# Boot build/vos.dsk headless in Caprice32 (CPC 6128, 128K), take one
# screenshot after a delay, and exit.
# Runs inside the snap:
#   snap run --shell caprice32.launcher -c "bash tools/cap32_shot.sh [delay]"
# delay = number of typed keys before the shot (default 400).
# The screenshot lands in sdump_dir of the snap's cap32.cfg.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DELAY=$(printf 'z%.0s' $(seq 1 "${1:-400}"))
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
exec timeout 60 "$SNAP/usr/bin/cap32" --cfg_file="$SNAP_USER_DATA/etc/cap32.cfg" \
  -O system.limit_speed=0 -O system.model=2 -O system.ram_size=128 -O video.scr_fps=0 \
  -a "run\"vos
${DELAY}\(CAP32_SCRNSHOT)\(CAP32_EXIT)" "$ROOT/build/vos.dsk"
