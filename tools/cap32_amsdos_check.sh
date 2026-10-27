#!/bin/bash
# After the test script has restarted the CPC into BASIC, let AMSDOS read
# what V-OS wrote: on B: the renamed HELLO.DOC (OPENIN, LINE INPUT) and
# CAT; on A: BIG.BIN, copied from B: in two 16K passes (LOAD, then bytes
# 0, 16383, 16384 and 19999, which should be 0 62 64 109).
# Runs inside the snap, like cap32_shot.sh:
#   snap run --shell caprice32.launcher -c "VOS_DSK=... VOS_DSK_B=... bash tools/cap32_amsdos_check.sh [delay]"
# The spaces give the disc time before the next line or the screenshot.
P=$(printf ' %.0s' $(seq 1 80))
K=$'\n\n''|b'$'\n'"$P"
K+='openin"hello.doc":line input#9,a$:closein:print a$'$'\n'"$P"
K+='cat'$'\n'"$P"
K+='|a'$'\n'"$P"
K+='memory &3fff:load"big.bin",&4000:print peek(&4000);peek(&7fff);peek(&8000);peek(&8e1f)'$'\n'"$P$P"
export VOS_TIMEOUT="${VOS_TIMEOUT:-90}"
exec bash "$(dirname "$0")/cap32_shot.sh" "${1:-1000}" "$K"
