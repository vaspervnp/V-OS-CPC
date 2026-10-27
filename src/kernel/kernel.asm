; =====================================================================
; kernel.asm - kernel entry and M0 boot test
;
; M0 proves the boot chain: firmware off, kernel at #0000, own IM 1
; handler synced to VSYNC. The test screen shows:
;   - four vertical bands (pens 0..3 of the Desktop palette),
;   - six horizontal border stripes, one per interrupt slice; they stay
;     still only if slice 0 is locked to VSYNC,
;   - pen 3 toggling every 50 frames, driven by the frame counter.
; =====================================================================

kernel_entry:
        di
        ld sp,STACK_TOP
        im 1

        ld a,1
        call ga_set_mode
        ld hl,palette_desktop
        call ga_set_palette
        ld hl,crtc_standard
        call crtc_load

        call screen_clear
        call draw_bands

        ld hl,border_slices
        ld (int_slice_hook),hl
        ei

.main:
        call wait_frame
        ld hl,blink_timer
        dec (hl)
        jr nz,.main
        ld (hl),50
        ld a,(blink_state)
        xor 1
        ld (blink_state),a
        ld a,11                     ; sky blue
        jr z,.set
        ld a,24                     ; bright yellow
.set:
        ld c,3
        di                          ; the slice hook also writes the Gate Array
        call ga_set_ink
        ei
        jr .main

; ---------------------------------------------------------------------
; border_slices - slice hook: A = slice 0..5
; ---------------------------------------------------------------------
border_slices:
        ld hl,border_colours
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ld c,GA_BORDER
        jp ga_set_ink

; ---------------------------------------------------------------------
; screen_clear - fill the 16K M0 screen with pen 0
; ---------------------------------------------------------------------
screen_clear:
        ld hl,SCREEN_M0
        ld de,SCREEN_M0 + 1
        ld bc,#3FFF
        ld (hl),0
        ldir
        ret

; ---------------------------------------------------------------------
; draw_bands - four vertical bands, pens 0..3, on every pixel line
; ---------------------------------------------------------------------
draw_bands:
        ld hl,SCREEN_M0
        ld d,8                      ; 8 blocks of 2K, one per pixel line in a char row
.block:
        ld e,25                     ; 25 char rows of 80 bytes
.row:
        ld a,#00                    ; mode 1: 4 pixels of pen 0
        call .fill20
        ld a,#F0                    ; pen 1
        call .fill20
        ld a,#0F                    ; pen 2
        call .fill20
        ld a,#FF                    ; pen 3
        call .fill20
        dec e
        jr nz,.row
        ld bc,#800 - 25 * 80
        add hl,bc
        dec d
        jr nz,.block
        ret
.fill20:
        ld b,20
.fill:
        ld (hl),a
        inc hl
        djnz .fill
        ret

; ---- data -----------------------------------------------------------
; Desktop palette (template A): pens 0..3, unused pens, border
palette_desktop:
        db 1, 26, 0, 11
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db 1

border_colours:
        db 6, 15, 24, 18, 20, 5      ; red, orange, yellow, green, cyan, mauve

blink_timer:    db 50
blink_state:    db 0
