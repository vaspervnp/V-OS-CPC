; =====================================================================
; interrupts.asm - 300 Hz interrupt handler and frame timing
;
; The Gate Array raises an interrupt every 52 HSYNCs: six per 312-line
; frame. The first one after VSYNC starts is slice 0; it is detected by
; reading the VSYNC bit on PPI port B. Slices drive raster effects and
; the frame counter drives everything that runs at 50 Hz.
;
; Input: the AMX mouse is sampled on every interrupt; the keyboard and
; the pointer are polled once a frame (50 Hz), on slice 0, or with the
; mixed screen on a slice where it does not wait (split.asm).
; =====================================================================

int_handler:
        push af
        push bc
        push de
        push hl
        push ix

        ld hl,(int_ticks)           ; 300 Hz tick counter
        inc hl
        ld (int_ticks),hl

        ld b,PPI_B >> 8
        in a,(c)
        rra                         ; carry = VSYNC
        ld a,(int_slice)
        jr nc,.not_vsync
        ld hl,(int_frames)          ; new frame
        inc hl
        ld (int_frames),hl
        xor a                       ; slice 0
        jr .slice_set
.not_vsync:
        inc a
        cp 6
        jr c,.slice_set
        xor a                       ; never past 5, even if VSYNC was missed
.slice_set:
        ld (int_slice),a
        ld b,a                      ; the mixed screen first: fixed timing
        ld a,(split_on)
        or a
        ld a,b
        call nz,split_irq

        call amx_tick
        ld a,(int_input)            ; once a frame
        ld hl,int_slice
        cp (hl)
        jr nz,.no_input
        call kbd_scan
        call ptr_poll
        call fdc_tick
        call snd_tick
.no_input:
        ld a,(int_slice)

        ; per-slice hook (raster effects); A = slice
        ld hl,(int_slice_hook)
        ld b,a
        ld a,h
        or l
        ld a,b
        call nz,.call_hl

        pop ix
        pop hl
        pop de
        pop bc
        pop af
        ei
        ret
.call_hl:
        jp (hl)

; ---------------------------------------------------------------------
; wait_frame - block until the next frame starts (slice 0)
; Destroys: A, HL
; ---------------------------------------------------------------------
wait_frame:
        ld hl,int_frames
        ld a,(hl)
.wait:
        halt
        cp (hl)
        jr z,.wait
        ret

; ---- state ----------------------------------------------------------
int_ticks:      dw 0
int_frames:     dw 0
int_slice:      db 0
int_slice_hook: dw 0                ; 0 = none; called with A = slice 0..5
int_input:      db 0                ; the slice for keyboard, pointer, disc, sound
