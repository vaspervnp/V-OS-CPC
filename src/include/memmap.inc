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
; what is listed next to GAP0..GAP7 below), and in the 32-byte ones of
; the #8000 page buffers that are always written before they are read
; (kernel space is short):
;   #8000  TXT_EXPAND (16 bytes)
;   #8800  app_self, app_parent (kernel/view.asm), then acc_ctx
;   #9000  bank_buf (kernel/lang.asm)
;   #9800, #A000, #A800, #B000  the program slots (below)
; The loader clears video RAM, so they start empty.

KERNEL_BASE     equ #0000
API_TABLE       equ #0100
KERNEL_LIMIT    equ #3E00
STACK_TOP       equ #4000

LOADER_ADDR     equ #4000           ; where AMSDOS loads VOS.BIN

TXT_EXPAND      equ #8000           ; 16 bytes, page aligned (gfx.asm)
SCREEN_TOP      equ #8020           ; char row 0, pixel line 0
SCREEN_LOW      equ #C000           ; char row 21, pixel line 0
SCREEN_SPLIT    equ 21              ; first char row in the #C000 page
SCREEN_ROWS     equ 34
SCREEN_H        equ 272             ; pixel lines in video RAM
SCREEN_BPL      equ 96              ; bytes per pixel line

; The 64K of extra RAM, seen one 16K bank at a time at #4000-#7FFF:
;   bank 4 (#C4)  file buffer: info and copy (kernel/files.asm)
;   bank 5 (#C5)  the running view, an overlay file (kernel/view.asm)
;   bank 6 (#C6)  what menus and dialogs cover (ui/ui.asm), up to
;                 ACC_ADDR; from there the desk accessory (view.asm)
;   bank 7 (#C7)  the language pack, the Commander's file lists, the
;                 English texts
; Kernel code that maps another bank maps the view's bank back
; (ram_home), never plain RAM, so a view can call it from #4000.
; The language pack: the kernel loads GREEK.LNG from disc into bank 7
; (for the messages) and keeps its font, case and keyboard tables in
; GAP0-2.
LANG_BANK_CFG   equ #C7             ; RAM config: bank 7 at #4000
LANG_BANK_ADDR  equ #4000
LANG_MAX        equ #2000           ; tools/mklng.py MAX_PACK
LISTS_CFG       equ #C7             ; Commander lists after the pack
LISTS_ADDR      equ #6000
EN_MSG_ADDR     equ #6800           ; ENGLISH.MSG, up to 6K
BUF_CFG         equ #C4
BUF_ADDR        equ #4000
VIEW_BANK_CFG   equ #C5
VIEW_ADDR       equ #4000
; Bank 5 holds the view at VIEW_ADDR, up to PROG_ADDR, and above it the
; programs that have a relocation table, as many as fit, each where
; kernel/view.asm finds room (slot_alloc). A program without one takes
; the whole bank from VIEW_ADDR, alone.
PROG_ADDR       equ #5000
; The program slots, one in each of four hidden 32-byte gaps: high byte
; SLOT_FIRST, then + SLOT_STEP. +0 first page (0: free), +1 pages,
; +2 drive, +3 name (11).
SLOT_FIRST      equ #98
SLOT_STEP       equ #08
SLOT_END        equ #B8
SLOT_PAGE       equ 0
SLOT_PAGES      equ 1
SLOT_DRIVE      equ 2
SLOT_NAME       equ 3
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
