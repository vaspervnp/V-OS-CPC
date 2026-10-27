; =====================================================================
; kernel.asm - kernel entry and main loop
;
; Sets up the screen, the disc and the language pack, then hands every
; event to the shell. The shell so far is the Commander view
; (src/shell/commander.asm); the Desktop and the Launcher come next.
; =====================================================================

kernel_entry:
        di
        ld sp,STACK_TOP
        im 1
        call gfx_init
        ld hl,palette_black         ; nothing to see while the disc loads
        call ga_set_palette
        ei
        call fdc_init
        call lang_init              ; GREEK.LNG from the disc
        call cm_init
        call ptr_show

.main:
        call wait_frame
.events:
        call ev_get
        jr z,.idle
        call cm_event
        jr .events
.idle:
        call ptr_update
        jr .main

palette_black:  ds 17, 0
palette_mode1:                      ; Desktop / Commander palette
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 0                        ; border
palette_mode0:                      ; Launcher palette
        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
        db 0
