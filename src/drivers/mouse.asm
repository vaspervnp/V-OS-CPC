; =====================================================================
; mouse.asm - pointer input: AMX mouse and cursor keys
;
; Both sources move the same pointer and can be used together.
;
; AMX mouse: plugs into the joystick port, so it shows up on keyboard
; matrix line 9 (bits 0-3 up/down/left/right, 5 fire 1, 4 fire 2,
; 6 fire 3). Movement arrives as pulses on the direction lines; amx_tick
; samples line 9 on every interrupt (300 Hz) and counts rising edges.
; TO VERIFY ON HARDWARE: pulse width and whether counting edges (the
; default) or sampling levels (amx_levels = 1) gives the right speed.
;
; Cursor keys: move the pointer while held, accelerating from 1 to 6
; pixels per frame. COPY is the left button.
;
; ptr_poll (50 Hz, after kbd_scan) applies the movement, clamps to the
; drawable area, and posts EV_PTR_MOVE / EV_PTR_DOWN / EV_PTR_UP.
; Coordinates are in pixels of the current mode, y in drawable lines.
; =====================================================================

PTR_LEFT        equ %001
PTR_RIGHT       equ %010
PTR_MIDDLE      equ %100

; ---------------------------------------------------------------------
; amx_tick - every interrupt. Destroys: AF, BC
; ---------------------------------------------------------------------
amx_tick:
        ld a,(amx_enabled)
        or a
        ret z
        ld a,9
        call kbd_read_line
        ld b,a
        ld c,0                      ; buttons
        bit 5,b
        jr z,.no_left
        set 0,c
.no_left:
        bit 4,b
        jr z,.no_right
        set 1,c
.no_right:
        bit 6,b
        jr z,.no_middle
        set 2,c
.no_middle:
        ld a,c
        ld (amx_buttons),a
        ld a,b
        and #0F
        ld b,a                      ; directions now
        ld a,(amx_levels)
        or a
        jr nz,.count
        ld a,(amx_prev)
        cpl
        and b                       ; rising edges only
.count:
        ld c,a
        ld a,b
        ld (amx_prev),a
        bit 0,c
        jr z,.no_up
        ld a,(amx_dy)
        dec a
        ld (amx_dy),a
.no_up:
        bit 1,c
        jr z,.no_down
        ld a,(amx_dy)
        inc a
        ld (amx_dy),a
.no_down:
        bit 2,c
        jr z,.no_lft
        ld a,(amx_dx)
        dec a
        ld (amx_dx),a
.no_lft:
        bit 3,c
        ret z
        ld a,(amx_dx)
        inc a
        ld (amx_dx),a
        ret

; ---------------------------------------------------------------------
; ptr_poll - 50 Hz, interrupt context. Destroys: AF, BC, DE, HL
; ---------------------------------------------------------------------
ptr_poll:
        ld a,(amx_dx)               ; movement from the AMX mouse
        ld (pp_dx),a
        ld a,(amx_dy)
        ld (pp_dy),a
        xor a
        ld (amx_dx),a
        ld (amx_dy),a

        ld a,(ptr_keys_on)          ; movement from the cursor keys
        or a
        jr z,.no_keys
        ld a,(kbd_now)
        and %111                    ; up, right, down
        ld b,a
        ld a,(kbd_now + 1)
        and %1                      ; left
        ld c,a
        or b
        jr nz,.keys_held
.no_keys:
        xor a
        ld (ptr_accel),a
        jr .apply
.keys_held:
        ld hl,ptr_accel
        ld a,(hl)
        cp 60
        jr nc,.accel_max
        inc (hl)
.accel_max:
        ld a,(hl)
        ld e,1
        cp 10
        jr c,.step
        ld e,2
        cp 25
        jr c,.step
        ld e,4
        cp 45
        jr c,.step
        ld e,6
.step:
        ld hl,pp_dx
        bit 1,b                     ; right
        jr z,.not_right
        ld a,(hl)
        add a,e
        ld (hl),a
.not_right:
        bit 0,c                     ; left
        jr z,.not_left
        ld a,(hl)
        sub e
        ld (hl),a
.not_left:
        ld hl,pp_dy
        bit 0,b                     ; up
        jr z,.not_up
        ld a,(hl)
        sub e
        ld (hl),a
.not_up:
        bit 2,b                     ; down
        jr z,.apply
        ld a,(hl)
        add a,e
        ld (hl),a

.apply:
        ld hl,(ptr_x)
        ld a,(pp_dx)
        ld de,(gfx_width)
        call ptr_add
        ld de,(ptr_x)
        ld (ptr_x),hl
        or a
        sbc hl,de
        ld a,h
        or l
        ld (pp_moved),a
        ld hl,(ptr_y)
        ld a,(pp_dy)
        ld de,GFX_H
        call ptr_add
        ld de,(ptr_y)
        ld (ptr_y),hl
        or a
        sbc hl,de
        ld a,h
        or l
        ld hl,pp_moved
        or (hl)
        jr z,.buttons
        ld a,1
        ld (ptr_moved),a
        ld a,(ptr_move_queued)
        or a
        jr nz,.buttons
        inc a
        ld (ptr_move_queued),a
        ld a,(ptr_buttons)
        ld b,a
        ld c,0
        ld a,EV_PTR_MOVE
        call ev_post

.buttons:
        ld a,(amx_buttons)
        ld b,a
        ld a,(ptr_keys_on)
        or a
        jr z,.no_copy
        ld a,(kbd_now + 1)
        and %10                     ; COPY
        jr z,.no_copy
        set 0,b
.no_copy:
        ld a,(ptr_buttons)
        xor b
        ret z
        ld c,a                      ; changed buttons
        ld a,b
        ld (ptr_buttons),a
        ld e,PTR_LEFT
.button:
        ld a,c
        and e
        jr z,.next_button
        push bc
        push de
        ld a,b
        and e
        ld b,e                      ; code = this button
        ld c,0
        ld a,EV_PTR_DOWN
        jr nz,.post
        ld a,EV_PTR_UP
.post:
        call ev_post
        pop de
        pop bc
.next_button:
        sla e
        ld a,e
        cp PTR_MIDDLE * 2
        jr c,.button
        ret

; HL = value, A = signed delta, DE = limit -> HL = clamp(value + delta,
; 0, limit - 1). Destroys: AF, BC
ptr_add:
        ld c,a
        add a,a
        sbc a,a
        ld b,a
        add hl,bc
        bit 7,h
        jr z,.not_negative
        ld hl,0
        ret
.not_negative:
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ld h,d
        ld l,e
        dec hl
        ret

; ---------------------------------------------------------------------
; ptr_clamp - keep the pointer inside the area after a mode change.
; Main context. Destroys: AF, DE, HL
; ---------------------------------------------------------------------
ptr_clamp:
        di
        ld hl,(ptr_x)
        ld de,(gfx_width)
        or a
        sbc hl,de
        jr c,.ok
        dec de
        ld (ptr_x),de
.ok:
        ei
        ret

; ---- state ----------------------------------------------------------
ptr_x:          dw 192
ptr_y:          dw 120
ptr_buttons:    db 0
ptr_moved:      db 1                ; set by ptr_poll, cleared by the sprite
ptr_move_queued: db 0               ; an EV_PTR_MOVE is waiting in the queue
ptr_keys_on:    db 1                ; cursor keys + COPY drive the pointer
ptr_accel:      db 0
pp_dx:          db 0
pp_dy:          db 0
pp_moved:       db 0

amx_enabled:    db 1
amx_levels:     db 0                ; 0 = count rising edges, 1 = levels
amx_prev:       db 0
amx_buttons:    db 0
amx_dx:         db 0
amx_dy:         db 0
