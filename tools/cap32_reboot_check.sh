#!/bin/bash
# cap32_amsdos_check.sh, but RUN"VOS" again in BASIC: the shot shows
# V-OS started with the SETUP.CFG the test script saved.
export VOS_REBOOT=1
exec bash "$(dirname "$0")/cap32_amsdos_check.sh" "$@"
