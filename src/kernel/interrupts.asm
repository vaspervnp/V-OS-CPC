; =====================================================================
; interrupts.asm - 300 Hz interrupt handler and frame timing
;
; The Gate Array raises an interrupt every 52 HSYNCs: six per 312-line
; frame. The first one after VSYNC starts is slice 0; it is detected by
; reading the VSYNC bit on PPI port B. Slices drive raster effects and
; the frame counter drives everything that runs at 50 Hz.
;
; VSYNC is seen only if the interrupt is taken within about 3 lines.
; After interrupts were lost (a disc transfer keeps them off for 16 ms
; a sector) the slices are counted wrong until it is seen again, and
; with the mixed screen a wrong slice can wait just before VSYNC every
; frame, so that it is never seen: the bands stay wrong and int_frames
; stops (wait_frame never returns). So after INT_BLIND_MAX interrupts
; without VSYNC the handler waits for it once, by polling, and counts
; from there (not while the disc is transferring: it would miss
; sectors).
;
; Input: the AMX mouse is sampled on every interrupt; the keyboard and
; the pointer are polled once a frame (50 Hz), on slice 0, or with the
; mixed screen on a slice where it does not wait (split.asm).
; =====================================================================

INT_BLIND_MAX   equ 12              ; two frames
INT_RESYNC_POLLS equ 1500

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
        jr nc,.not_vsync
.new_frame:
        ld hl,(int_frames)          ; new frame
        inc hl
        ld (int_frames),hl
        xor a                       ; slice 0
        ld (int_blind),a
        jr .slice_set
.not_vsync:
        ld hl,int_blind             ; VSYNC unseen for two frames: the
        inc (hl)                    ; count is lost, find VSYNC again
        ld a,(hl)
        cp INT_BLIND_MAX
        jr nc,.resync
.next:
        ld a,(int_slice)
        inc a
        cp 6
        jr c,.slice_set
        xor a                       ; never past 5, even if VSYNC was missed
        jr .slice_set
.resync:
        ld a,(fdc_motor_on_flag)    ; not between the sectors of a file:
        or a                        ; only when the disc has been idle
        jr z,.wait_vsync            ; for a few frames
        ld a,(fdc_idle_count)
        cp 3
        jr c,.next
.wait_vsync:
        ld de,INT_RESYNC_POLLS      ; up to a frame (14 us a poll)
.poll:
        in a,(c)
        rra
        jr c,.new_frame
        dec de
        ld a,d
        or e
        jr nz,.poll
        ld (hl),d                   ; none: try again later
        jr .next
.slice_set:
        ld (int_slice),a
        ld b,a                      ; the mixed screen first: fixed timing
        ld a,(split_on)
        or a
        ld a,b
        call nz,split_irq
        IFDEF TEST_TRACE
        call test_ring
        ENDIF

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
int_blind:      db 0                ; interrupts since VSYNC was seen
int_slice_hook: dw 0                ; 0 = none; called with A = slice 0..5
int_input:      db 0                ; the slice for keyboard, pointer, disc, sound
