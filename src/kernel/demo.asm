; =====================================================================
; demo.asm - the demo build (-DDEMO): V-OS plays a recorded session by
; itself, for videos (tools/video). Its keys are the file DEMO.KEY on
; A:, loaded at boot into the last bank of a RAM expansion, which
; xb_detect keeps from the programs (demo_cfg; 0: none, no demo).
; Entries as the test script's (kernel/test_script.asm): dw first
; frame; db frames held, matrix line, bits (line #80: ptr_keys_on =
; bits; #81: the pointer's x = bits * 2; #82: its y = bits), in the
; order of their first frames, #FFFF at the end. Frames are scans of
; the keyboard, one a frame. dm_base is the first entry that may still
; be held, so a frame looks at a few entries only.
; =====================================================================

demo_load:
        ld a,(demo_cfg)
        or a
        ret z
        ld c,a
        ld hl,demo_file
        ld de,#4000
        call fs_load
        ret nc
        xor a                       ; no file: no demo
        ld (demo_cfg),a
        ret

; from the keyboard scan (drivers/kbd.asm), in the interrupt
demo_inject:
        ld a,(demo_cfg)
        or a
        ret z
        ld hl,kbd_now + 8           ; hide Z, SHIFT, \ and 8: Caprice32's
        res 7,(hl)                  ; screenshots type them (tools/
        ld hl,kbd_now + 2           ; cap32_shot.sh); the demo's own
        ld a,(hl)                   ; keys come after
        and %10011111
        ld (hl),a
        ld hl,kbd_now + 5
        res 0,(hl)
        ld a,(demo_cfg)
        ld b,GA_PORT >> 8
        out (c),a
        ld hl,(dm_frame)
        inc hl
        ld (dm_frame),hl
        ld ix,(dm_base)
.base:                              ; past those 256 frames old
        call .age
        jr z,.done
        jr c,.done                  ; the next is still to come
        or a
        jr z,.scan
        ld de,5
        add ix,de
        ld (dm_base),ix
        jr .base
.scan:
        call .age
        jr z,.done
        jr c,.done
        or a
        jr nz,.next                 ; long past
        ld a,c
        cp (ix+2)
        jr nc,.next                 ; past its last frame
        ld a,(ix+3)
        cp #80
        jr c,.key
        jr nz,.ptr_x
        ld a,(ix+4)
        ld (ptr_keys_on),a
        jr .next
.ptr_x:
        cp #81
        jr nz,.ptr_y
        ld e,(ix+4)
        ld d,0
        ex de,hl
        add hl,hl
        ld (ptr_x),hl
        ex de,hl
        jr .next
.ptr_y:
        ld a,(ix+4)
        ld (ptr_y),a
        xor a
        ld (ptr_y + 1),a
        jr .next
.key:
        push hl
        ld e,a
        ld d,0
        ld hl,kbd_now
        add hl,de
        ld a,(ix+4)
        or (hl)
        ld (hl),a
        pop hl
.next:
        ld de,5
        add ix,de
        jr .scan
.done:
        ld a,(ram_config)
        ld b,GA_PORT >> 8
        out (c),a
        ret
; HL = frame, IX -> an entry -> Z: the end; else carry: to come, or
; A = high byte of the frames since its first, C = the low byte
.age:
        ld e,(ix+0)
        ld d,(ix+1)
        ld a,d
        and e
        inc a
        ret z
        push hl
        or a
        sbc hl,de
        ld a,h
        ld c,l
        pop hl
        ret c
        inc d                       ; NZ (D is not #FF here: frames end
        ret                         ; before #FF00)

demo_file:      db "DEMO    KEY"
demo_cfg:       db 0
dm_frame:       dw 0
dm_base:        dw #4000
