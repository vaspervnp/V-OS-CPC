; =====================================================================
; psg.asm - sound: the AY-3-8912, three channels, timed notes
;
; snd_play starts a tone or noise on a channel for a number of frames;
; snd_tick (interrupt, 50 Hz) silences it when the time is up. The AY is
; reached through the PPI, as the keyboard scan does (register 14), so
; the main program writes with interrupts off. The AY's port A stays an
; input (mixer bit 6 = 0) for the keyboard.
; =====================================================================

SND_CLOSED      equ %00111111       ; mixer: tone and noise off, port A in

; ---------------------------------------------------------------------
; snd_play (VOS_SOUND) - A = channel 0..2, HL = tone period (1..4095;
; bit 15 set: noise, L = noise period 0..31), C = volume 0..15 (0:
; stop), B = frames (0: until stopped)
; Destroys: AF, BC, DE, HL
; ---------------------------------------------------------------------
snd_play:
        cp 3
        ret nc
        di
        ld e,a                      ; channel
        ld d,0
        push hl
        ld hl,snd_time
        add hl,de
        ld (hl),b
        pop hl
        ld a,c
        and 15
        ld c,a
        jr z,.volume                ; stop: the volume only
        ld b,e                      ; mixer bits of this channel
        inc b
        ld a,#84                    ; %00001001 rotated right
.bit:
        rlca
        djnz .bit                   ; A = tone bit | noise bit
        ld b,a
        ld a,(snd_mix)
        or b                        ; both off first
        bit 7,h
        jr nz,.noise
        push af                     ; tone: the period
        ld a,e
        add a,a
        push bc
        ld c,l
        call psg_write
        inc a
        ld c,h
        call psg_write
        pop bc
        pop af
        ld d,%00000111
        jr .mix
.noise:
        push af
        push bc
        ld a,6
        ld c,l
        call psg_write
        pop bc
        pop af
        ld d,%00111000
.mix:
        push af                     ; A = mixer with both off
        ld a,b
        and d                       ; this channel's tone or noise bit
        cpl
        ld b,a
        pop af
        and b                       ; on
        ld (snd_mix),a
        push bc
        ld c,a
        ld a,7
        call psg_write
        pop bc
.volume:
        ld a,e
        add a,8
        call psg_write
        ei
        ret

; ---------------------------------------------------------------------
; snd_init - the mixer closed, every channel silent (boot)
; snd_off - every channel silent (a program ends)
; Destroys: AF, BC, DE, HL
; ---------------------------------------------------------------------
snd_init:
        ld a,7
        ld c,SND_CLOSED
        di
        call psg_write
        ei
snd_off:
        xor a
.channel:
        push af
        ld bc,0
        call snd_play
        pop af
        inc a
        cp 3
        jr c,.channel
        ret

; ---------------------------------------------------------------------
; snd_tick - interrupt, once a frame: notes whose time is up stop
; Destroys: AF, BC, HL
; ---------------------------------------------------------------------
snd_tick:
        ld hl,snd_time
        ld a,8                      ; volume register of channel 0
.channel:
        inc (hl)
        dec (hl)
        jr z,.next
        dec (hl)
        jr nz,.next
        ld c,0
        call psg_write
.next:
        inc hl
        inc a
        cp 11
        jr c,.channel
        ret

; ---------------------------------------------------------------------
; psg_write - AY register A = C. Preserves A, C. Destroys: B
; ---------------------------------------------------------------------
psg_write:
        ld b,PPI_A >> 8
        out (c),a                   ; register number
        push af
        ld b,PPI_C >> 8
        ld a,#C0                    ; select
        out (c),a
        xor a                       ; inactive
        out (c),a
        ld b,PPI_A >> 8
        out (c),c                   ; value
        ld b,PPI_C >> 8
        ld a,#80                    ; write
        out (c),a
        xor a
        out (c),a
        pop af
        ret

snd_mix:        db SND_CLOSED
snd_time:       db 0, 0, 0
