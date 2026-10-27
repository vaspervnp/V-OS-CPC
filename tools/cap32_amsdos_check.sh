#!/bin/bash
# After the test script has saved VOSTEST.TXT and restarted the CPC into
# BASIC, let AMSDOS read the file V-OS wrote: LOAD (header, length, data),
# print its first bytes, then CAT. Runs inside the snap, like cap32_shot.sh:
#   snap run --shell caprice32.launcher -c "VOS_DSK=... bash tools/cap32_amsdos_check.sh [delay]"
# The spaces give the disc time before the next line or the screenshot.
P=$(printf ' %.0s' $(seq 1 80))
K=$'\n\n''memory &3fff:load"vostest.txt",&4000:for i=0 to 9:print chr$(peek(&4000+i));:next'$'\n'"$P"'cat'$'\n'"$P"
exec bash "$(dirname "$0")/cap32_shot.sh" "${1:-1000}" "$K"
