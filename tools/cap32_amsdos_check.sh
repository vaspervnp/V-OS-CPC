#!/bin/bash
# After the test script has restarted the CPC into BASIC, let AMSDOS read
# what V-OS wrote: CAT of A: (the copied HELLO.TXT, SETUP.CFG) and of
# B: (formatted by V-OS, so empty), then HELLO.TXT read with OPENIN.
# With VOS_REBOOT=1 it types RUN"VOS afterwards instead, and the shot
# shows V-OS started with the saved SETUP.CFG, VOS_REBOOT_WAIT Z keys
# (120) after RUN"VOS (the test script runs again from its start).
# Runs inside the snap, like cap32_shot.sh:
#   snap run --shell caprice32.launcher -c "VOS_DSK=... VOS_DSK_B=... bash tools/cap32_amsdos_check.sh [delay]"
# The spaces give the disc time before the next line or the screenshot.
P=$(printf ' %.0s' $(seq 1 80))
K=$'\n\n''cat'$'\n'"$P"
K+='|b'$'\n'"$P"
K+='cat'$'\n'"$P"
K+='|a'$'\n'"$P"
K+='openin"hello.txt":line input#9,a$:closein:print a$'$'\n'"$P"
if [ -n "$VOS_REBOOT" ]; then
  K=$'\n\n''run"vos'$'\n'"$(printf 'z%.0s' $(seq 1 ${VOS_REBOOT_WAIT:-120}))"
fi
export VOS_TIMEOUT="${VOS_TIMEOUT:-90}"
exec bash "$(dirname "$0")/cap32_shot.sh" "${1:-1000}" "$K"
