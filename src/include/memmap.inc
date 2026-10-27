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
; Unused video RAM, never displayed: #8000-#801F and #C4E0-#C7FF in
; each of the eight 2K blocks (+ line * #800). The kernel keeps tables
; and buffers in the eight 800-byte gaps of the #C000 page (who uses
; what is listed next to GAP0..GAP7 below).

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

; Language pack: the kernel loads GREEK.LNG from disc into bank 7 (for
; the messages) and keeps its font, case and keyboard tables in GAP0-2.
LANG_BANK_CFG   equ #C7             ; RAM config: bank 7 at #4000
LANG_BANK_ADDR  equ #4000
LANG_MAX        equ #4000           ; a pack fills at most the bank
; Bank 6 (#C6) holds what menus and dialogs cover (ui/ui.asm).
; Bank 4 (#C4) is where the M4 test loads files to show them.
RAM_BASE_CFG    equ #C0             ; RAM config: plain 64K

; Drawable area. The monitor shows 271 lines; the top 6 and the bottom
; 6 of them are not used, so graphics y = 0 is physical line 6 and the
; last drawable line is physical line 264.
GFX_TOP         equ 6
GFX_H           equ 259

; ---- video RAM gaps (800 bytes each) ---------------------------------
GAP_SIZE        equ 800
GAP0            equ #C4E0           ; pack font 128..191, lang_msg_buf
GAP1            equ #CCE0           ; pack font 192..255, dlg_text
GAP2            equ #D4E0           ; pack case, keymap, combos; fs block list
GAP3            equ #DCE0           ; disc sector buffer, free block map
GAP4            equ #E4E0           ; directory entries 0..24
GAP5            equ #ECE0           ; directory entries 25..49
GAP6            equ #F4E0           ; directory entries 50..63, text to save
GAP7            equ #FCE0           ; file list for the UI (50 x 16 bytes)
