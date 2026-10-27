#!/bin/bash
# After the test script has restarted the CPC into BASIC, let AMSDOS read
# what V-OS wrote: on A: the text file copied without a header (OPENIN,
# LINE INPUT), on B: the binary copied with its header (LOAD, first
# bytes), then CAT of B:. Runs inside the snap, like cap32_shot.sh:
#   snap run --shell caprice32.launcher -c "VOS_DSK=... VOS_DSK_B=... bash tools/cap32_amsdos_check.sh [delay]"
# The spaces give the disc time before the next line or the screenshot.
P=$(printf ' %.0s' $(seq 1 80))
K=$'\n\n''openin"hello.txt":line input#9,a$:closein:print a$'$'\n'"$P"
K+='|b'$'\n'"$P"
K+='memory &3fff:load"greek.lng",&4000:for i=0 to 3:print chr$(peek(&4000+i));:next'$'\n'"$P"
K+='cat'$'\n'"$P"
exec bash "$(dirname "$0")/cap32_shot.sh" "${1:-700}" "$K"
