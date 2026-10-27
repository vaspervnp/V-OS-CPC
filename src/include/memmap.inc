; =====================================================================
; memmap.inc - V-OS memory map (see docs/REQUIREMENTS.md, section 4.2)
; =====================================================================
;
;   #0000-#00FF  restart vectors, interrupt entry, API table
;   #0100-#3DFF  kernel code and data
;   #3E00-#3FFF  kernel stack (512 bytes)
;   #4000-#7FFF  bank window (applications, data)
;   #8000-#FFFF  video RAM, 32K overscan (see drivers/crtc.asm)
;
; Unused video RAM, free for buffers: #8000-#801F and #C4E0-#C7FF in
; each of the eight 2K blocks (#x000 + line*#800), 6656 bytes in all.

KERNEL_BASE     equ #0000
API_TABLE       equ #0100
KERNEL_LIMIT    equ #3E00
STACK_TOP       equ #4000

LOADER_ADDR     equ #4000           ; where AMSDOS loads VOS.BIN

SCREEN_TOP      equ #8020           ; char row 0, pixel line 0
SCREEN_LOW      equ #C000           ; char row 21, pixel line 0
SCREEN_SPLIT    equ 21              ; first char row in the #C000 page
SCREEN_ROWS     equ 34
SCREEN_H        equ 272             ; pixel lines in video RAM
SCREEN_BPL      equ 96              ; bytes per pixel line

; Drawable area. The monitor shows 271 lines; the top 6 and the bottom
; 6 of them are not used, so graphics y = 0 is physical line 6 and the
; last drawable line is physical line 264.
GFX_TOP         equ 6
GFX_H           equ 259
