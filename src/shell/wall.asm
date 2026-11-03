; =====================================================================
; wall.asm - the desk's picture (Setup's BACKGROUND: CFG_WALL,
; CFG_WALL_NAME), part of the Desktop (shell/desktop.asm): a .SCR kept
; in wall_bank (kernel/ext.asm: the last bank of a RAM expansion,
; boot/expand.asm), its pixels in the Desktop's four pens, drawn in the
; middle of the desk, the desk's colour around it. Kernel code that
; maps wall_bank maps the Desktop's bank back.
; A PAINT .SCR (mode 0, its 16 inks at #07D0) becomes mode 1, each ink
; the nearest of the four; another .SCR stays as it is (mode 1).
WALL_X          equ 8                   ; bytes from the left
WALL_Y          equ 36                  ; lines from the top
wall_state      equ GAP0 + 793          ; 0 to load, 1 there, 2 none
                                        ; (Setup: 0 after a change)

; -> A = wall_bank's RAM config, Z: none (no RAM expansion)
wall_has:
        ld a,LANG_BANK_CFG
        ld hl,wall_bank
        ld de,bank_buf
        ld bc,1
        call bank_get
        ld a,(bank_buf)
        ld (wl_cfg),a
        or a
        ret

; after the desk is cleared
wall_draw:
        ld a,(cfg_data + CFG_WALL)
        inc a
        ret z
        call wall_has
        ret z
        ld a,(wall_state)
        or a
        call z,wall_load
        ld a,(wall_state)
        dec a
        ret nz
        ld (wl_y),a
.line:
        ld a,(wl_y)                 ; from #4000 + (y & 7) * #800 +
        rrca                        ; (y / 8) * 80, as on the CPC's screen
        rrca
        rrca
        and #1F
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        ld a,(wl_y)
        and 7
        add a,a
        add a,a
        add a,a
        add a,#40
        add a,h
        ld h,a
        push hl
        ld a,(wl_y)                 ; to its line, WALL_X bytes in
        add a,WALL_Y
        ld l,a
        ld h,0
        add hl,hl
        ld de,gfx_lines_all
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,WALL_X
        add hl,de
        ex de,hl
        pop hl
        ld bc,80
        ld a,(wl_cfg)
        call bank_get
        ld hl,wl_y
        inc (hl)
        ld a,(hl)
        cp 200
        jr c,.line
        ret

; the file into wall_bank, in the Desktop's pens -> wall_state 1 (2: it
; could not be read)
wall_load:
        ld a,2
        ld (wall_state),a
        ld a,(cfg_data + CFG_WALL)
        call fdc_select
        ld hl,cfg_data + CFG_WALL_NAME
        ld de,#4000
        ld a,(wl_cfg)
        ld c,a
        call fs_load
        ret c
        ld hl,#47D0                 ; PAINT's inks?
        ld de,fs_buf
        ld bc,16
        ld a,(wl_cfg)
        call bank_get
        ld hl,fs_buf
        ld de,wl_map
        ld bc,16 * 256
.ink:
        ld a,(hl)
        cp 27
        jr nc,.done                 ; not inks: mode 1, as it is
        or c
        ld c,a
        push bc
        push hl
        push de
        ld a,(hl)
        call wl_near
        pop de
        ld (de),a
        inc de
        pop hl
        pop bc
        inc hl
        djnz .ink
        ld a,c
        or a
        jr z,.done                  ; all 0: not inks
        ld hl,#4000
.piece:
        ld (wl_at),hl               ; 512 bytes at a time through fs_buf
        ld de,fs_buf
        ld bc,512
        ld a,(wl_cfg)
        call bank_get
        ld hl,fs_buf
.byte:
        ld c,(hl)
        call wl_pixel               ; the left pixel
        and #CC
        ld b,a
        sla c
        call wl_pixel               ; the right one
        and #33
        or b
        ld (hl),a
        inc hl
        ld a,h
        cp (fs_buf + 512) >> 8
        jr nz,.byte
        ld a,l
        cp (fs_buf + 512) & #FF
        jr nz,.byte
        ld hl,fs_buf
        ld de,(wl_at)
        ld bc,512
        ld a,(wl_cfg)
        call bank_put
        ld hl,(wl_at)
        ld de,512
        add hl,de
        ld a,h
        cp #80
        jr c,.piece
.done:
        ld a,1
        ld (wall_state),a
        ret

; C = a mode 0 byte (its left pixel in bits 7, 3, 5, 1) -> A = a mode 1
; byte of four pixels in that pixel's pen (wl_map). B, C, HL kept
wl_pixel:
        push hl
        xor a
        bit 1,c
        jr z,.b2
        or 8
.b2:
        bit 5,c
        jr z,.b1
        or 4
.b1:
        bit 3,c
        jr z,.b0
        or 2
.b0:
        bit 7,c
        jr z,.pen
        or 1
.pen:
        ld e,a
        ld d,0
        ld hl,wl_map
        add hl,de
        ld a,(hl)
        ld e,0                      ; pen bit 0: #F0, bit 1: #0F
        rra
        jr nc,.hi
        ld e,#F0
.hi:
        rra
        ld a,e
        jr nc,.end
        or #0F
.end:
        pop hl
        ret

; A = ink (0-26) -> A = the Desktop's pen (palette_mode1 0-3) nearest
; to it, by its levels of green, red and blue
wl_near:
        call wl_levels
        ld (wl_ink),hl
        ld a,c
        ld (wl_ink + 2),a
        ld a,#FF
        ld (wl_best),a
        ld b,4
.pen:
        push bc
        ld a,4
        sub b
        ld e,a
        ld d,0
        ld hl,palette_mode1
        add hl,de
        ld a,(hl)
        call wl_levels
        ld de,wl_ink                ; |g - g'| + |r - r'| + |b - b'|
        ld a,(de)
        sub l
        call wl_abs
        ld b,a
        inc de
        ld a,(de)
        sub h
        call wl_abs
        add a,b
        ld b,a
        inc de
        ld a,(de)
        sub c
        call wl_abs
        add a,b
        ld hl,wl_best
        cp (hl)
        jr nc,.next
        ld (hl),a
        pop bc
        push bc
        ld a,4
        sub b
        ld (wl_pen),a
.next:
        pop bc
        djnz .pen
        ld a,(wl_pen)
        ret
; A = ink -> L green, H red, C blue (0-2)
wl_levels:
        ld l,0
.g:
        sub 9
        jr c,.r
        inc l
        jr .g
.r:
        add a,9
        ld h,0
.r3:
        sub 3
        jr c,.b
        inc h
        jr .r3
.b:
        add a,3
        ld c,a
        ret
wl_abs:
        ret p
        neg
        ret

wl_cfg:         db 0
wl_y:           db 0
wl_at:          dw 0
wl_map:         ds 16
wl_ink:         ds 3
wl_best:        db 0
wl_pen:         db 0
; =====================================================================
