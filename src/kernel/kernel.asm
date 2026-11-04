; =====================================================================
; kernel.asm - kernel entry and main loop
;
; Sets up the screen, the disc and the language pack, then starts the
; first view and hands it every event. Views are overlays
; (kernel/view.asm); F1-F4 switch between Desktop, Launcher, Commander
; and Setup. Programs that go on in the background get their frames
; after it (bg_frame).
; =====================================================================

kernel_entry:
        di                          ; (the loader set up the screen:
        ld sp,STACK_TOP             ; gfx_init, a black palette)
        im 1
        ei
        call fdc_init
        call snd_init
        ld hl,boot_x                ; (kernel/ext2.asm) SETUP.CFG, if
        call ext2_call              ; there is one, then
        IFDEF DEMO
        call demo_load
        ENDIF
        ld hl,lang_init             ; the pack it names from the disc
        call ext_call
        call cfg_apply
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
        ld a,(wm_on)                ; a program in a window: its frame,
        or a                        ; the others, F7 (wm/wm.asm)
        ld hl,wm_event
        call nz,wm_call
        jr c,.events
        call view_keys
        jr c,.events
        call .event
        jr .events
.idle:
        ld a,(bh_req)               ; a program to start behind
        or a                        ; (VX_BEHIND)
        ld hl,behind_run
        call nz,ext2_call
        call c,sys_error
        ld a,(view_ticks)           ; frame events for animation
        or a
        jr z,.no_ticks
        ld hl,ev_cur
        ld (hl),EV_FRAME
.no_ticks:
        call nz,.event
        call bg_frame
        ld hl,clk_frame             ; the clock on the bar (ext2.asm)
        call ext2_call
        call ptr_update
        jr .main
.event:
        ld a,(view_cur)
        cp VIEW_NONE
        ret z
        ld de,3                     ; event: the view's or the accessory's
        jp cur_call

; every frame: a VE_FRAME event to each program that goes on in the
; background (VOS_BACKGROUND), in its bank and as the kernel's program,
; with the calls not for it there quiet (kernel/ext.asm)
bg_frame:
        ld hl,bg_first
.next:
        call ext_call
        ret c
        ld hl,ev_cur
        ld (hl),EV_FRAME
        ld de,3
        call cur_call
        ld hl,bg_next
        jr .next

palette_mode1:                      ; Desktop / Commander palette
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 0                        ; border
palette_mode0:                      ; Launcher palette
        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
        db 0
