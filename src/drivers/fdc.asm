; =====================================================================
; fdc.asm - uPD765A floppy disc controller, polled
;
; The CPC has no DMA and no FDC interrupt: every byte is moved by the
; CPU while the controller sets RQM in its status register. During a
; sector transfer (one byte every 32 us) interrupts are off, so the
; input drivers skip a few ticks. There is no terminal count line
; either: each read or write names one sector as both R and EOT, and
; the "end of cylinder" flag the FDC then reports is expected.
;
; fdc_init          motor off, SPECIFY, track unknown
; fdc_read          D = track, E = sector ID, HL = 512-byte buffer
; fdc_write         same, writes the buffer
; fdc_format        D = track, E = first sector ID: 9 sectors of 512
;                   bytes filled with #E5, interleaved as AMSDOS does
; fdc_read_id       A = ID of the first sector found on the current track
; fdc_recalibrate   head to track 0
; fdc_select        A = drive for the calls above
; All return carry set and A = FDC_ERR_* on failure. Reads and writes
; retry FDC_RETRIES times, recalibrating between tries.
; fdc_tick (50 Hz, interrupt) switches the motor off after FDC_IDLE_FRAMES
; frames without disc access.
;
; Nothing waits forever (lessons from the TerraCPC driver on real CPCs):
; every poll loop is bounded, and a timeout sets the sticky fdc_abort, so
; the rest of the command is skipped and the call fails with
; FDC_ERR_NOT_READY. The result phase is read while the controller says
; it is busy (CB), not as a fixed number of bytes: some emulators return
; fewer. Before each retry the controller is drained and set up again.
; =====================================================================

FDC_CMD_SPECIFY equ #03
FDC_CMD_RECAL   equ #07
FDC_CMD_SENSE   equ #08             ; sense interrupt status
FDC_CMD_SEEK    equ #0F
FDC_CMD_WRITE   equ #45             ; MFM, one side
FDC_CMD_READ    equ #46
FDC_CMD_READ_ID equ #4A
FDC_CMD_FORMAT  equ #4D             ; MFM format track

FDC_ERR_NOT_READY equ 1
FDC_ERR_PROTECTED equ 2
FDC_ERR_NO_SECTOR equ 3
FDC_ERR_DATA      equ 4
FDC_ERR_OTHER     equ 5

FDC_RETRIES     equ 3
FDC_SPINUP      equ 50              ; frames: one second
FDC_IDLE_FRAMES equ 150             ; frames before the motor stops

; A = drive (0 = A:, 1 = B:). The head position is per drive, so a
; change makes the next access recalibrate.
fdc_select:
        ld hl,fdc_drive
        cp (hl)
        ret z
        ld (hl),a
        ld a,#FF
        ld (fdc_track),a
        ret

; ---------------------------------------------------------------------
fdc_init:
        xor a
        ld (fdc_motor_on_flag),a
        ld bc,FDC_MOTOR
        out (c),a
        ld (fdc_abort),a
        ld a,#FF
        ld (fdc_track),a
fdc_specify:
        ld a,FDC_CMD_SPECIFY
        call fdc_send
        ld a,#A1                    ; step rate, head unload time
        call fdc_send
        ld a,#03                    ; head load time, no DMA
        jp fdc_send

; motor on, waiting for the disc to reach speed if it was off
fdc_motor_on:
        xor a
        ld (fdc_idle_count),a
        ld a,(fdc_motor_on_flag)
        or a
        ret nz
        inc a
        ld (fdc_motor_on_flag),a
        ld bc,FDC_MOTOR
        out (c),a
        ld b,FDC_SPINUP
.spin:
        push bc
        call wait_frame
        pop bc
        djnz .spin
        ret

; interrupt, slice 0. Destroys: AF, BC, HL
fdc_tick:
        ld a,(fdc_motor_on_flag)
        or a
        ret z
        ld a,(fdc_busy)
        or a
        ret nz
        ld hl,fdc_idle_count
        inc (hl)
        ld a,(hl)
        cp FDC_IDLE_FRAMES
        ret c
        xor a
        ld (fdc_motor_on_flag),a
        ld bc,FDC_MOTOR
        out (c),a
        ret

; ---------------------------------------------------------------------
; A = byte for the FDC. Preserves BC, DE, HL.
fdc_send:
        push bc
        push de
        push af
        ld a,(fdc_abort)
        or a
        jr nz,.done
        ld de,0                     ; 65536 polls
        ld bc,FDC_STATUS
.wait:
        in a,(c)
        add a,a                     ; carry = RQM, sign = DIO
        jr nc,.busy
        jp p,.ready
.busy:
        dec de
        ld a,d
        or e
        jr nz,.wait
        ld a,1
        ld (fdc_abort),a
        jr .done
.ready:
        pop af
        push af
        inc c
        out (c),a
.done:
        pop af
        pop de
        pop bc
        ret

; result phase: read bytes while the FDC is busy (CB); the first 7 go to
; fdc_res, the rest are drained. Destroys: AF, BC, DE, HL
fdc_results:
        ld hl,fdc_res
        xor a
        ld (fdc_res_count),a
        ld (hl),a                   ; no stale ST0..ST2
        ld (fdc_res + 1),a
        ld (fdc_res + 2),a
        ld a,(fdc_abort)
        or a
        ret nz
.byte:
        ld de,0
.wait:
        ld bc,FDC_STATUS
        in a,(c)
        bit 4,a                     ; CB = 0: the result phase is over
        ret z
        and #C0
        cp #C0                      ; RQM and DIO: a byte is waiting
        jr z,.read
        dec de
        ld a,d
        or e
        jr nz,.wait
        jr .abort
.read:
        inc c
        in e,(c)
        ld a,(fdc_res_count)
        cp 12
        jr nc,.abort                ; runaway result stream
        inc a
        ld (fdc_res_count),a
        cp 8
        jr nc,.byte
        ld (hl),e
        inc hl
        jr .byte
.abort:
        ld a,1
        ld (fdc_abort),a
        ret

; wait for the end of a seek or recalibrate with SENSE INTERRUPT STATUS.
; Carry if it failed or timed out.
fdc_wait_seek:
        ld hl,0
        ld (fdc_count),hl
.again:
        ld a,FDC_CMD_SENSE
        call fdc_send
        call fdc_results
        ld a,(fdc_abort)
        or a
        jr nz,.failed
        ld a,(fdc_res)
        cp #80                      ; nothing to report yet
        jr z,.not_yet
        bit 5,a                     ; not a seek end (ready change): again
        jr z,.not_yet
        and #C0
        ret z
.failed:
        scf
        ret
.not_yet:
        ld hl,(fdc_count)
        dec hl
        ld (fdc_count),hl
        ld a,h
        or l
        jr nz,.again
        ld a,1
        ld (fdc_abort),a
        scf
        ret

; after a failure: drain a pending result, SPECIFY again, track unknown
fdc_reset:
        xor a
        ld (fdc_abort),a
        call fdc_results
        xor a
        ld (fdc_abort),a
        ld a,#FF
        ld (fdc_track),a
        jp fdc_specify

fdc_recalibrate:
        call fdc_motor_on
        xor a
        ld (fdc_abort),a
        ld a,2                      ; twice: one call steps at most 77 tracks
        ld (fdc_tries2),a
.again:
        xor a
        ld (fdc_abort),a
        ld a,FDC_CMD_RECAL
        call fdc_send
        ld a,(fdc_drive)
        call fdc_send
        call fdc_wait_seek
        jr nc,.done
        ld hl,fdc_tries2
        dec (hl)
        jr nz,.again
        ld a,#FF
        ld (fdc_track),a
        ld a,FDC_ERR_NOT_READY
        scf
        ret
.done:
        xor a
        ld (fdc_track),a
        ret

; D = track
fdc_seek:
        ld a,(fdc_track)
        cp d
        ret z
        ld a,FDC_CMD_SEEK
        call fdc_send
        ld a,(fdc_drive)
        call fdc_send
        ld a,d
        call fdc_send
        push de
        call fdc_wait_seek
        pop de
        ld a,#FF
        jr c,.failed
        ld a,d
.failed:
        ld (fdc_track),a
        ld a,FDC_ERR_NO_SECTOR
        ret

; -> A = sector ID under the head
fdc_read_id:
        call fdc_motor_on
        xor a
        ld (fdc_abort),a
        di
        ld a,FDC_CMD_READ_ID
        call fdc_send
        ld a,(fdc_drive)
        call fdc_send
        call fdc_results
        ei
        ld a,(fdc_abort)
        or a
        jr nz,.failed
        ld a,(fdc_res)
        and #C0
        jr nz,.failed
        ld a,(fdc_res + 5)          ; ST0 ST1 ST2 C H R N
        or a
        ret
.failed:
        call fdc_error
        scf
        ret

; ---------------------------------------------------------------------
; fdc_read / fdc_write - D = track, E = sector ID, HL = buffer
; ---------------------------------------------------------------------
fdc_format:
        ld a,FDC_CMD_FORMAT
        jr fdc_rw
fdc_read:
        ld a,FDC_CMD_READ
        jr fdc_rw
fdc_write:
        ld a,FDC_CMD_WRITE
fdc_rw:
        ld (fdc_cmd),a
        ld (fdc_buf),hl
        ld (fdc_sector),de          ; E = sector, D = track
        ld a,1
        ld (fdc_busy),a
        call fdc_motor_on
        ld a,FDC_RETRIES
        ld (fdc_tries),a
.try:
        xor a
        ld (fdc_abort),a
        ld a,(fdc_track)            ; unknown track: find track 0 first
        inc a
        jr nz,.known
        call fdc_recalibrate
        jr c,.retry
.known:
        ld de,(fdc_sector)
        call fdc_seek
        jr c,.retry
        call fdc_transfer
        jr nc,.ok
        cp FDC_ERR_PROTECTED
        jr z,.fail
.retry:
        push af
        call fdc_reset              ; recalibrates before the next try
        pop af
        ld hl,fdc_tries
        dec (hl)
        jr nz,.try
.fail:
        push af
        xor a
        ld (fdc_busy),a
        pop af
        scf
        ret
.ok:
        xor a
        ld (fdc_busy),a
        ret

; one sector, the transfer itself (or a whole track for FORMAT)
fdc_transfer:
        di
        ld a,(fdc_cmd)
        cp FDC_CMD_FORMAT
        jr z,.format
        call fdc_send
        ld a,(fdc_drive)            ; head 0
        call fdc_send
        ld a,(fdc_sector + 1)       ; C
        call fdc_send
        xor a                       ; H
        call fdc_send
        ld a,(fdc_sector)           ; R
        call fdc_send
        ld a,2                      ; N: 512 bytes
        call fdc_send
        ld a,(fdc_sector)           ; EOT = R: this sector only
        call fdc_send
        ld a,#2A                    ; GPL
        call fdc_send
        ld a,#FF                    ; DTL; execution starts after it
        call fdc_send
        ld a,(fdc_abort)            ; a command byte timed out
        or a
        jp nz,.done
        ld hl,(fdc_buf)
        ld de,0                     ; bounds the waits of the whole sector
        ld bc,FDC_STATUS
        ld a,(fdc_cmd)
        cp FDC_CMD_WRITE
        jr z,.write
.read:                              ; 79 T-states per byte, 128 available
        in a,(c)
        jp m,.read_ready            ; RQM
        dec de
        ld a,d
        or e
        jr nz,.read
        jr .timeout
.read_ready:
        and #20                     ; still in the execution phase?
        jr z,.done
        inc c
        in a,(c)
        ld (hl),a
        inc hl
        dec c
        jp .read
.write:
        in a,(c)
        jp m,.write_ready
        dec de
        ld a,d
        or e
        jr nz,.write
        jr .timeout
.write_ready:
        and #20
        jr z,.done
        inc c
        ld a,(hl)
        out (c),a
        inc hl
        dec c
        jp .write
.format:
        call fdc_send               ; #4D, drive, N, sectors, gap, filler
        ld a,(fdc_drive)
        call fdc_send
        ld a,2
        call fdc_send
        ld a,9
        call fdc_send
        ld a,#52
        call fdc_send
        ld a,#E5
        call fdc_send
        ld hl,fdc_interleave        ; then C, H, R, N of each sector
.id:
        ld a,(fdc_sector + 1)
        call fdc_send
        xor a
        call fdc_send
        ld a,(fdc_sector)
        add a,(hl)
        call fdc_send
        ld a,2
        call fdc_send
        inc hl
        ld a,(hl)
        inc a
        jr nz,.id
        jp .done
.timeout:
        ld a,1
        ld (fdc_abort),a
.done:
        call fdc_results
        ei
        ld a,(fdc_abort)
        or a
        jr nz,.error
        ld a,(fdc_res + 1)          ; ST1 errors, not "end of cylinder"
        and #37
        ld b,a
        ld a,(fdc_res + 2)          ; ST2 errors
        and #77
        or b
        jr nz,.error
        ld a,(fdc_res)              ; ST0: only "abnormal" from the EN flag
        and #08                     ; not ready?
        ret z
.error:
        call fdc_error
        scf
        ret

; fdc_res -> A = FDC_ERR_*
fdc_error:
        ld a,(fdc_abort)            ; timed out: no drive or no disc
        or a
        ld a,FDC_ERR_NOT_READY
        ret nz
        ld a,(fdc_res)
        bit 3,a
        ld a,FDC_ERR_NOT_READY
        ret nz
        ld a,(fdc_res + 1)
        bit 1,a
        ld a,FDC_ERR_PROTECTED
        ret nz
        ld a,(fdc_res + 1)
        and %00000101               ; no data, missing address mark
        ld a,FDC_ERR_NO_SECTOR
        ret nz
        ld a,(fdc_res + 1)
        bit 5,a
        ld a,FDC_ERR_DATA
        ret nz
        ld a,(fdc_res + 2)
        bit 5,a
        ld a,FDC_ERR_DATA
        ret nz
        ld a,FDC_ERR_OTHER
        ret

fdc_interleave: db 0, 5, 1, 6, 2, 7, 3, 8, 4, #FF

; ---- state ----------------------------------------------------------
fdc_drive:      db 0                ; 0 = A:, 1 = B:
fdc_track:      db #FF              ; #FF = unknown
fdc_motor_on_flag: db 0
fdc_busy:       db 0
fdc_idle_count: db 0
fdc_cmd:        db 0
fdc_buf:        dw 0
fdc_sector:     db 0                ; sector ID
                db 0                ; track
fdc_tries:      db 0
fdc_tries2:     db 0
fdc_res:        ds 7
fdc_res_count:  db 0
fdc_abort:      db 0                ; a wait timed out: skip the rest
fdc_count:      dw 0
