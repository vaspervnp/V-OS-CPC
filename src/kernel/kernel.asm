; =====================================================================
; kernel.asm - kernel entry and main loop
;
; Sets up the screen, the disc and the language pack, then starts the
; first view and hands it every event. Views are overlays
; (kernel/view.asm); F1-F4 switch between Desktop, Launcher, Commander
; and Setup.
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
        call snd_init
        call lang_init              ; GREEK.LNG from the disc
        call cfg_load               ; SETUP.CFG, if there is one
        ld a,1                      ; a plain desk until the view is up
        call ui_set_mode
        ld hl,palette_mode1
        call ga_set_palette
        ld a,UIP_DESK
        call ui_pen
        call gfx_cls
        call ptr_show

.main:
        call wait_frame
.events:
        call view_poll
        call ev_get
        jr z,.idle
        call view_keys
        jr c,.events
        call .event
        jr .events
.idle:
        ld a,(view_ticks)           ; frame events for animation
        or a
        jr z,.no_ticks
        ld hl,ev_cur
        ld (hl),EV_FRAME
.no_ticks:
        call nz,.event
        call ptr_update
        jr .main
.event:
        ld a,(view_cur)
        cp VIEW_NONE
        ret z
        ld hl,ev_cur
        jp OV_EVENT

palette_black:  ds 17, 0
palette_mode1:                      ; Desktop / Commander palette
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 0                        ; border
palette_mode0:                      ; Launcher palette
        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
        db 0
