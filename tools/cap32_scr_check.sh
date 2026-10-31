#!/bin/bash
# Load a .SCR of PAINT in BASIC, as its manual says: MODE 0, LOAD at
# &C000, the 16 inks and the border from &C7D0; then a screenshot.
# Runs inside the snap, like cap32_shot.sh:
#   snap run --shell caprice32.launcher -c "bash tools/cap32_scr_check.sh disc.dsk shots-folder"
# The file on the disc is PICTURE.SCR. WHILE 1:WEND keeps BASIC from
# printing Ready over the picture; the Z keys are only a wait.
set -e
WAIT=$(printf 'z%.0s' $(seq 1 300))
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
mkdir -p "$2"
exec timeout "${VOS_TIMEOUT:-40}" "$SNAP/usr/bin/cap32" --cfg_file="$SNAP_USER_DATA/etc/cap32.cfg" \
  -O system.limit_speed=0 -O system.model=2 -O system.ram_size=128 -O video.scr_fps=0 -O "file.sdump_dir=$2" \
  -a "mode 0:load\"picture.scr\",&c000:for i=0 to 15:ink i,peek(&c7d0+i):next:border peek(&c7e0):while 1:wend
${WAIT}\(CAP32_SCRNSHOT)\(CAP32_EXIT)" "$1"
