; =====================================================================
; memmap.inc - V-OS memory map (see docs/REQUIREMENTS.md, section 4.2)
; =====================================================================
;
;   #0000-#00FF  restart vectors, interrupt entry, API table
;   #0100-#3DFF  kernel code and data
;   #3E00-#3FFF  kernel stack (512 bytes)
;   #4000-#7FFF  bank window (applications, data)
;   #8000-#FFFF  video RAM (32K overscan from M1; M0 uses #C000-#FFFF)

KERNEL_BASE     equ #0000
API_TABLE       equ #0100
KERNEL_LIMIT    equ #3E00
STACK_TOP       equ #4000

LOADER_ADDR     equ #4000           ; where AMSDOS loads VOS.BIN

SCREEN_M0       equ #C000           ; standard 16K screen used in M0
