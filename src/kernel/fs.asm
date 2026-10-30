; =====================================================================
; fs.asm - AMSDOS compatible file system (CP/M 2.2 directory)
;
; Formats (found with READ ID on track 0):
;   DATA    sector IDs #C1-#C9, no reserved tracks, 180 blocks
;   SYSTEM  sector IDs #41-#49, 2 reserved tracks,   171 blocks
; 9 sectors of 512 bytes per track, 40 tracks, one side. Blocks are 1K
; (two sectors); blocks 0 and 1 hold the directory: 64 entries of
;   user (#E5 = free), name[8], ext[3] (bit 7 = attributes), EX, S1, S2,
;   RC (128-byte records in this extent), AL[16] (block numbers)
; One entry covers 16K. Binary files start with the 128-byte AMSDOS
; header (type, load and exec address, length, checksum); files
; without a valid header are read as text, records * 128 bytes.
;
; Names are 11 bytes, FCB style: "GREEK   LNG". Only user 0 is used.
;
; fs_mount      read the format and the directory (each call below
;               mounts again, so a changed disc is always seen)
; fs_catalog    -> A = files, list at FS_CAT (16 bytes per file: name[11],
;               0, size in K, 0, 0, 0)
; fs_load       HL = name, DE = destination, C = its RAM configuration
;               -> BC = length, fs_hdr_* from the header; at most
;               FS_LOAD_MAX bytes are copied
; fs_save       HL = name, DE = source, A = its RAM configuration,
;               BC = length, fs_hdr_type/load/exec set by the caller
;               (type #FF: no header, as fs_load reports text files)
; fs_copy       HL = name, B = source drive, C = target drive: the
;               whole file, sector by sector, header and all, 16K at
;               a time through bank 4; any size
; fs_rename     HL = name, DE = new name, on the drive selected
; fs_exists     HL = name, on the drive selected -> carry if it is not
;               there (or the disc cannot be read)
; fs_format     the drive selected: 40 tracks in DATA format, empty
; fs_delete     HL = name
; fs_free_k     -> A = free kilobytes (after a mount)
; All return carry set and A = FDC_ERR_* or FS_ERR_* on failure.
;
; The directory is cached in GAP4-GAP6, the sector buffer and the block
; map live in GAP3, the block list of a file in GAP2 (see memmap.inc).
; =====================================================================

FS_ERR_FORMAT   equ 6
FS_ERR_NOT_FOUND equ 7
FS_ERR_FULL     equ 8
FS_ERR_DIR_FULL equ 9
FS_ERR_EXISTS   equ 10              ; rename: the new name is taken
FS_ERR_BAD_NAME equ 11              ; for callers: not an AMSDOS name
FS_ERR_NOT_PROGRAM equ 12           ; for callers: not a V-OS program
FS_ERR_NO_ROOM  equ 13              ; for callers: no room for a program
FS_ERR_NO_APP   equ 14              ; for callers: no program for a file

FS_ENTRIES      equ 64
FS_FREE_ENTRY   equ #E5
FS_CAT_MAX      equ 50
FS_LOAD_MAX     equ #4000           ; one bank window

fs_buf          equ GAP3            ; 512-byte sector buffer
fs_map          equ GAP3 + 512      ; one bit per block, 24 bytes
fs_blist        equ GAP2 + 520      ; blocks of the current file, 180
FS_CAT          equ GAP7

; ---------------------------------------------------------------------
fs_mount:
        call fdc_recalibrate
        ret c
        call fdc_read_id
        ret c
        and #F0
        cp #C0
        ld bc,#C100                 ; DATA: first ID, reserved tracks
        ld d,180                    ; blocks
        jr z,.format
        cp #40
        ld bc,#4102                 ; SYSTEM
        ld d,171
        jr z,.format
        ld a,FS_ERR_FORMAT
        scf
        ret
.format:
        ld a,b
        ld (fs_first_id),a
        ld a,c
        ld (fs_reserved),a
        ld a,d
        ld (fs_blocks),a
        call fs_read_dir
        ret c
        jp fs_build_map

; ---------------------------------------------------------------------
; HL = sector number in the data area -> D = track, E = sector ID
fs_sector_pos:
        ld a,(fs_reserved)
        or a
        jr z,.counted
        ld b,a
        ld de,9
.reserved:
        add hl,de
        djnz .reserved
.counted:
        ld d,0
        ld bc,9
.divide:
        or a
        sbc hl,bc
        jr c,.done
        inc d
        jr .divide
.done:
        add hl,bc
        ld a,(fs_first_id)
        add a,l
        ld e,a
        ret

; HL = sector number: read it into / write it from fs_buf
fs_read_ls:
        call fs_sector_pos
        ld hl,fs_buf
        jp fdc_read
fs_write_ls:
        call fs_sector_pos
        ld hl,fs_buf
        jp fdc_write

; A = entry 0..63 -> HL = its 32 bytes in the cache (25 per gap)
fs_entry:
        ld hl,GAP4
        ld de,#800
.gap:
        cp 25
        jr c,.inside
        sub 25
        add hl,de
        jr .gap
.inside:
        ex de,hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ret

; directory sectors 0..3 <-> cache
fs_read_dir:
        xor a
.sector:
        ld (fs_s),a
        ld l,a
        ld h,0
        call fs_read_ls
        ret c
        ld hl,fs_buf
        ld (fs_p),hl
        call .entries
        ld a,(fs_s)
        inc a
        cp 4
        jr c,.sector
        or a
        ret
.entries:
        ld a,(fs_s)                 ; first entry = sector * 16
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,16
.entry:
        push af
        push bc
        call fs_entry
        ex de,hl
        ld hl,(fs_p)
        ld bc,32
        ldir
        ld (fs_p),hl
        pop bc
        pop af
        inc a
        djnz .entry
        ret

fs_write_dir:
        xor a
.sector:
        ld (fs_s),a
        add a,a
        add a,a
        add a,a
        add a,a
        ld hl,fs_buf
        ld (fs_p),hl
        ld b,16
.entry:
        push af
        push bc
        call fs_entry
        ld de,(fs_p)
        ld bc,32
        ldir
        ld (fs_p),de
        pop bc
        pop af
        inc a
        djnz .entry
        ld a,(fs_s)
        ld l,a
        ld h,0
        call fs_write_ls
        ret c
        ld a,(fs_s)
        inc a
        cp 4
        jr c,.sector
        or a
        ret

; ---------------------------------------------------------------------
; block map
; ---------------------------------------------------------------------
fs_build_map:
        ld hl,fs_map
        ld b,24
.clear:
        ld (hl),0
        inc hl
        djnz .clear
        xor a                       ; the directory's blocks
        call fs_mark
        ld a,1
        call fs_mark
        xor a
.entry:
        ld (fs_e),a
        call fs_entry
        ld a,(hl)
        cp 16                       ; users 0..15 own blocks
        jr nc,.next
        ld de,16
        add hl,de
        ld b,16
.block:
        ld a,(hl)
        or a
        jr z,.skip
        push hl
        push bc
        call fs_mark
        pop bc
        pop hl
.skip:
        inc hl
        djnz .block
.next:
        ld a,(fs_e)
        inc a
        cp FS_ENTRIES
        jr c,.entry
        or a
        ret

; A = block -> HL = its map byte, A = its bit mask.  Destroys: B
fs_bit:
        ld b,a
        srl a
        srl a
        srl a
        ld hl,fs_map
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,b
        and 7
        ld b,a
        ld a,1
        ret z
.shift:
        add a,a
        djnz .shift
        ret

fs_mark:
        call fs_bit
        or (hl)
        ld (hl),a
        ret

; A = block -> NZ if used
fs_used:
        call fs_bit
        and (hl)
        ret

; -> A = free blocks (= free kilobytes)
fs_free_k:
        ld c,0
        ld a,2
.block:
        push af
        call fs_used
        jr nz,.used
        inc c
.used:
        pop af
        inc a
        ld hl,fs_blocks
        cp (hl)
        jr c,.block
        ld a,c
        ret

; ---------------------------------------------------------------------
; names and extents
; ---------------------------------------------------------------------
; HL -> entry: Z if it is user 0 and its name is fs_name
fs_match:
        ld a,(hl)
        or a
        ret nz
        push hl
        inc hl
        ld de,fs_name
        ld b,11
.char:
        ld a,(hl)
        and #7F
        ex de,hl
        cp (hl)
        ex de,hl
        jr nz,.done
        inc hl
        inc de
        djnz .char
.done:
        pop hl
        ret

; A = extent number -> A = entry of fs_name with that EX, carry if none
fs_find:
        ld (ff_ex),a
        xor a
.entry:
        ld (ff_i),a
        call fs_entry
        call fs_match
        jr nz,.next
        ld de,12
        add hl,de
        ld a,(ff_ex)
        cp (hl)
        jr nz,.next
        ld a,(ff_i)
        or a
        ret
.next:
        ld a,(ff_i)
        inc a
        cp FS_ENTRIES
        jr c,.entry
        scf
        ret

; blocks of fs_name in order -> fs_blist, fs_nblocks, fs_records
fs_collect:
        ld hl,0
        ld (fs_records),hl
        xor a
        ld (fs_nblocks),a
        ld (fs_ex),a
.extent:
        ld a,(fs_ex)
        call fs_find
        jr c,.end
        call fs_entry
        ld de,15
        add hl,de
        ld a,(hl)                   ; RC
        inc hl                      ; -> AL
        push hl
        ld e,a
        ld d,0
        ld hl,(fs_records)
        add hl,de
        ld (fs_records),hl
        add a,7                     ; blocks = (RC + 7) / 8
        srl a
        srl a
        srl a
        pop hl
        or a
        jr z,.next
        ld c,a
        ld b,0
        ld a,(fs_nblocks)
        ld e,a
        ld d,0
        push hl
        ld hl,fs_blist
        add hl,de
        ex de,hl
        pop hl
        push bc
        ldir
        pop bc
        ld a,(fs_nblocks)
        add a,c
        ld (fs_nblocks),a
.next:
        ld hl,fs_ex
        inc (hl)
        jr .extent
.end:
        ld a,(fs_ex)
        or a
        ret nz
        ld a,FS_ERR_NOT_FOUND
        scf
        ret

; HL = name: copy it to fs_name
fs_set_name:
        ld de,fs_name
        ld bc,11
        ldir
        ret

; ---------------------------------------------------------------------
; fs_catalog
; ---------------------------------------------------------------------
fs_catalog:
        call fs_mount
        ret c
        xor a
        ld (fc_count),a
.entry:
        ld (fc_i),a
        call fs_entry
        ld a,(hl)
        or a                        ; user 0
        jr nz,.next
        push hl
        ld de,12
        add hl,de
        ld a,(hl)                   ; first extent only
        pop hl
        or a
        jr nz,.next
        inc hl
        ld de,fs_name
        ld b,11
.name:
        ld a,(hl)
        and #7F
        ld (de),a
        inc hl
        inc de
        djnz .name
        call fs_collect
        ld a,(fc_count)
        cp FS_CAT_MAX
        jr nc,.done
        ld l,a                      ; FS_CAT + count * 16
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        ex de,hl
        ld hl,fs_name
        ld bc,11
        ldir
        xor a
        ld (de),a
        inc de
        ld a,(fs_nblocks)
        ld (de),a
        ld hl,fc_count
        inc (hl)
.next:
        ld a,(fc_i)
        inc a
        cp FS_ENTRIES
        jr c,.entry
.done:
        ld a,(fc_count)
        or a
        ret

; ---------------------------------------------------------------------
; fs_load
; ---------------------------------------------------------------------
fs_load:
        ld (fl_ptr),de
        ld a,c
        ld (fl_cfg),a
        call fs_set_name
        call fs_mount
        ret c
        call fs_collect
        ret c
        xor a
        ld (fl_sector),a
        call fl_read_next
        ret c
        call fs_header_ok
        jr nz,.text
        ld hl,(fs_buf + #40)        ; real length (low 16 bits)
        ld (fs_length),hl
        ld (fl_left),hl
        ld a,(fs_buf + #12)
        ld (fs_hdr_type),a
        ld hl,(fs_buf + #15)
        ld (fs_hdr_load),hl
        ld hl,(fs_buf + #1A)
        ld (fs_hdr_exec),hl
        ld hl,fs_buf + 128
        ld bc,512 - 128
        jr .first
.text:
        ld hl,(fs_records)          ; no header: records * 128
        ld b,7
.times:
        add hl,hl
        djnz .times
        ld (fs_length),hl
        ld (fl_left),hl
        ld a,#FF
        ld (fs_hdr_type),a
        ld hl,0
        ld (fs_hdr_load),hl
        ld (fs_hdr_exec),hl
        ld hl,fs_buf
        ld bc,512
.first:
        push hl                     ; no more than FS_LOAD_MAX bytes
        ld hl,(fl_left)
        ld de,FS_LOAD_MAX + 1
        or a
        sbc hl,de
        jr c,.fits
        ld hl,FS_LOAD_MAX
        ld (fl_left),hl
.fits:
        pop hl
.copy:
        call fl_out
        ld hl,(fl_left)
        ld a,h
        or l
        jr z,.done
        call fl_read_next
        ret c
        ld hl,fs_buf
        ld bc,512
        jr .copy
.done:
        ld bc,(fs_length)
        or a
        ret

; next sector of the file -> fs_buf
fl_read_next:
        call fl_next_ls
        ret c
        jp fs_read_ls
fl_write_next:
        call fl_next_ls
        ret c
        jp fs_write_ls

; -> HL = data-area sector of file sector fl_sector, which advances
fl_next_ls:
        ld a,(fl_sector)
        ld c,a
        srl a                       ; block index
        ld hl,fs_nblocks
        cp (hl)
        jr c,.inside
        ld a,FS_ERR_NOT_FOUND       ; the file is shorter than it claims
        scf
        ret
.inside:
        ld hl,fs_blist
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld l,(hl)
        ld h,0
        add hl,hl                   ; block * 2
        ld a,c
        and 1
        ld e,a
        ld d,0
        add hl,de
        ld a,c
        inc a
        ld (fl_sector),a
        or a
        ret

; HL = source in fs_buf, BC = bytes: copy up to fl_left of them to
; fl_ptr in RAM configuration fl_cfg
fl_out:
        push hl
        ld hl,(fl_left)
        or a
        sbc hl,bc
        jr nc,.enough
        ld bc,(fl_left)
.enough:
        ld hl,(fl_left)
        or a
        sbc hl,bc
        ld (fl_left),hl
        pop hl
        ld a,b
        or c
        ret z
        push bc
        ld a,(fl_cfg)
        call ram_select
        pop bc
        ld de,(fl_ptr)
        ldir
        ld (fl_ptr),de
        jp ram_home

; HL = destination in fs_buf, BC = bytes: zero them, then copy up to
; fl_left bytes from fl_ptr in RAM configuration fl_cfg
fl_in:
        push hl
        push bc
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        dec bc
        ld a,b
        or c
        jr z,.zeroed
        ldir
.zeroed:
        pop bc
        ld hl,(fl_left)
        or a
        sbc hl,bc
        jr nc,.enough
        ld bc,(fl_left)
.enough:
        ld hl,(fl_left)
        or a
        sbc hl,bc
        ld (fl_left),hl
        pop de
        ld a,b
        or c
        ret z
        push bc
        ld a,(fl_cfg)
        call ram_select
        pop bc
        ld hl,(fl_ptr)
        ldir
        ld (fl_ptr),hl
        jp ram_home

; Z if fs_buf starts with a valid AMSDOS header
fs_header_ok:
        ld hl,fs_buf
        ld b,67
        ld de,0
.sum:
        ld a,(hl)
        add a,e
        ld e,a
        jr nc,.no_carry
        inc d
.no_carry:
        inc hl
        djnz .sum
        ld a,d
        or e
        jr z,.bad
        ld hl,(fs_buf + #43)
        or a
        sbc hl,de
        ret
.bad:
        inc a                       ; NZ
        ret

; ---------------------------------------------------------------------
; fs_delete
; ---------------------------------------------------------------------
fs_delete:
        call fs_set_name
        call fs_mount
        ret c
        call fs_unlink
        or a
        jr nz,.write
        ld a,FS_ERR_NOT_FOUND
        scf
        ret
.write:
        call fs_write_dir
        ret c
        jp fs_build_map

; ---------------------------------------------------------------------
fs_exists:
        call fs_set_name
        call fs_mount
        ret c
        xor a
        jp fs_find

fs_format:
        xor a
.track:
        ld (fs_e),a
        ld d,a
        ld e,#C1
        call fdc_format
        ret c
        ld a,(fs_e)
        inc a
        cp 40
        jr c,.track
        ret

; ---------------------------------------------------------------------
; fs_rename
; ---------------------------------------------------------------------
fs_rename:
        ld (fr_new),de
        push hl
        ex de,hl
        call fs_set_name            ; the new name must be free
        call fs_mount
        pop hl
        ret c
        push hl
        xor a
        call fs_find
        pop hl
        ld a,FS_ERR_EXISTS
        ccf
        ret c
        call fs_set_name
        xor a
        ld (fs_count),a
.entry:
        ld (fs_e),a
        call fs_entry
        call fs_match
        jr nz,.next
        inc hl                      ; every extent gets the new name
        ex de,hl
        ld hl,(fr_new)
        ld bc,11
        ldir
        ld hl,fs_count
        inc (hl)
.next:
        ld a,(fs_e)
        inc a
        cp FS_ENTRIES
        jr c,.entry
        ld a,(fs_count)
        or a
        ld a,FS_ERR_NOT_FOUND
        scf
        ret z
        jp fs_write_dir

; ---------------------------------------------------------------------
; fs_copy
; ---------------------------------------------------------------------
fs_copy:
        ld (fc_drives),bc           ; C = target, B = source
        call fs_set_name            ; (destroys BC)
        ld a,(fc_drives + 1)
        call fdc_select
        call fs_mount
        ret c
        call fs_collect             ; the source's blocks and records
        ret c
        ld hl,(fs_records)
        ld (fc_records),hl
        ld a,(fs_nblocks)
        ld (fc_nblocks),a
        ld hl,fs_blist
        ld de,fc_blist
        ld bc,180
        ldir
        ld hl,(fs_first_id)         ; and fs_reserved
        ld (fc_src_fmt),hl
        ld a,(fc_drives)            ; target: room for as many blocks
        call fdc_select
        call fs_mount
        ret c
        call fs_unlink              ; replace a file of the same name
        call fs_build_map
        ld a,(fc_nblocks)
        ld (fs_nblocks),a
        call fs_alloc
        ret c
        ld hl,(fs_first_id)
        ld (fc_dst_fmt),hl
        ld hl,(fc_records)          ; sectors with data
        ld de,3
        add hl,de
        srl h
        rr l
        srl h
        rr l
        ld (fc_left),hl
        ld hl,0
        ld (fc_done),hl
.chunk:
        ld hl,(fc_left)
        ld a,h
        or l
        jr z,.entries
        ld de,32                    ; up to 16K at a time
        or a
        sbc hl,de
        ld a,32
        jr nc,.size
        add hl,de
        ld a,l
.size:
        ld (fc_chunk),a
        ld a,(fc_drives + 1)        ; read from the source
        call fdc_select
        ld hl,(fc_src_fmt)
        ld (fs_first_id),hl
        ld hl,fc_blist
        ld a,FDC_CMD_READ
        call .pass
        ret c
        ld a,(fc_drives)            ; write to the target
        call fdc_select
        ld hl,(fc_dst_fmt)
        ld (fs_first_id),hl
        ld hl,fs_blist
        ld a,FDC_CMD_WRITE
        call .pass
        ret c
        ld a,(fc_chunk)
        ld e,a
        ld d,0
        ld hl,(fc_done)
        add hl,de
        ld (fc_done),hl
        ld hl,(fc_left)
        or a
        sbc hl,de
        ld (fc_left),hl
        jr .chunk
.entries:
        ld hl,(fc_records)          ; fs_nblocks, fs_blist, fs_extents
        ld (fs_records),hl          ; are the target's, from fs_alloc
        jp fs_write_entries
; HL = block list, A = FDC command: fc_chunk sectors from fc_done on,
; to or from bank 4
.pass:
        ld (fc_list),hl
        ld (fc_cmd),a
        xor a
        ld (fc_j),a
.sector:
        ld a,(fc_j)
        ld hl,fc_chunk
        cp (hl)
        ret nc
        ld hl,(fc_done)             ; sector of the file
        ld e,a
        ld d,0
        add hl,de
        ld a,l
        and 1
        ld c,a
        srl h
        rr l
        ld de,(fc_list)             ; its block
        add hl,de
        ld l,(hl)
        ld h,0
        add hl,hl
        ld b,0
        add hl,bc
        call fs_sector_pos          ; D = track, E = sector ID
        ld a,(fc_j)
        add a,a
        add a,BUF_ADDR >> 8
        ld h,a
        ld l,0
        push hl
        push de
        ld a,BUF_CFG
        call ram_select
        pop de
        pop hl
        ld a,(fc_cmd)
        call fdc_rw
        push af
        call ram_home
        pop af
        ret c
        ld hl,fc_j
        inc (hl)
        jr .sector

; free every entry of fs_name in the cache -> A = entries freed
fs_unlink:
        xor a
        ld (fs_count),a
.entry:
        ld (fs_e),a
        call fs_entry
        call fs_match
        jr nz,.next
        ld (hl),FS_FREE_ENTRY
        ld hl,fs_count
        inc (hl)
.next:
        ld a,(fs_e)
        inc a
        cp FS_ENTRIES
        jr c,.entry
        ld a,(fs_count)
        ret

; ---------------------------------------------------------------------
; fs_save
; ---------------------------------------------------------------------
fs_save:
        ld (fl_ptr),de
        ld (fl_cfg),a
        ld (fs_length),bc
        ld (fl_left),bc
        call fs_set_name
        call fs_mount
        ret c
        call fs_unlink              ; replace an older file
        call fs_build_map
        ; sizes: header + data (fs_hdr_type #FF: no header, as text files)
        ld hl,(fs_length)
        ld a,(fs_hdr_type)
        inc a
        jr z,.no_header
        ld de,128
        add hl,de
.no_header:
        ld (fs_total),hl
        ld de,127                   ; records = (total + 127) / 128
        add hl,de
        ld b,7
.records:
        srl h
        rr l
        djnz .records
        ld (fs_records),hl
        ld de,(fs_records)          ; sectors = (records + 3) / 4
        ld hl,3
        add hl,de
        srl h
        rr l
        srl h
        rr l
        inc hl                      ; blocks = (sectors + 1) / 2
        srl h
        rr l
        ld a,l
        or a                        ; an empty file still takes a block
        jr nz,.blocks
        inc a
.blocks:
        ld (fs_nblocks),a
        call fs_alloc
        ret c
        jr fs_save_data

; fs_nblocks -> room checked, blocks allocated in the map, listed in
; fs_blist. Carry and A = FS_ERR_* if the disc or directory is full.
fs_alloc:
        ld a,(fs_nblocks)
        add a,15                    ; entries = (blocks + 15) / 16
        srl a
        srl a
        srl a
        srl a
        ld (fs_extents),a
        ; room on the disc and in the directory?
        call fs_free_k
        ld hl,fs_nblocks
        cp (hl)
        jr nc,.room
        ld a,FS_ERR_FULL
        scf
        ret
.room:
        call fs_free_entries
        ld hl,fs_extents
        cp (hl)
        jr nc,.entries_ok
        ld a,FS_ERR_DIR_FULL
        scf
        ret
.entries_ok:
        ; allocate blocks, lowest first
        xor a
        ld (fs_count),a
        ld a,2
.alloc:
        push af
        call fs_used
        jr nz,.taken
        pop af
        push af
        call fs_mark
        ld a,(fs_count)
        ld hl,fs_blist
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        pop af
        push af
        ld (hl),a
        ld hl,fs_count
        inc (hl)
        ld a,(fs_nblocks)
        cp (hl)
        jr z,.allocated
.taken:
        pop af
        inc a
        jr .alloc
.allocated:
        pop af
        or a
        ret

fs_save_data:
        ; data: the header and the first 384 bytes, then 512 at a time
        xor a
        ld (fl_sector),a
        ld a,(fs_hdr_type)
        inc a
        ld hl,fs_buf
        ld bc,512
        jr z,.sector
        call fs_make_header
        ld hl,fs_buf + 128
        ld bc,512 - 128
.sector:
        call fl_in
        call fl_write_next
        ret c
        ld a,(fl_sector)            ; all sectors of the last block too
        ld b,a
        ld a,(fs_nblocks)
        add a,a
        cp b
        jr z,fs_write_entries
        ld hl,fs_buf
        ld bc,512
        jr .sector

; directory entries for fs_name: fs_records, fs_nblocks, fs_blist,
; fs_extents; then the directory goes to the disc
fs_write_entries:
        xor a
        ld (fs_ex),a
        ld (fs_bi),a
.extent:
        call fs_free_slot           ; HL -> free entry
        ld (hl),0                   ; user 0
        inc hl
        ex de,hl
        ld hl,fs_name
        ld bc,11
        ldir
        ld a,(fs_ex)                ; EX, S1, S2
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld hl,(fs_records)          ; RC = min(128, records left)
        ld bc,128
        or a
        sbc hl,bc
        jr nc,.full_extent
        add hl,bc
        ld a,l
        ld hl,0
        jr .rc
.full_extent:
        ld a,128
.rc:
        ld (fs_records),hl
        ld (de),a
        inc de
        ld b,16                     ; AL
.al:
        ld a,(fs_bi)
        ld hl,fs_nblocks
        cp (hl)
        ld a,0
        jr nc,.al_store
        ld a,(fs_bi)
        ld hl,fs_blist
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ld hl,fs_bi
        inc (hl)
.al_store:
        ld (de),a
        inc de
        djnz .al
        ld hl,fs_ex
        inc (hl)
        ld a,(fs_extents)
        cp (hl)
        jr nz,.extent
        call fs_write_dir
        ret c
        or a
        ret

; -> A = free directory entries
fs_free_entries:
        ld c,0
        xor a
.entry:
        push af
        call fs_entry
        ld a,(hl)
        cp FS_FREE_ENTRY
        jr nz,.used
        inc c
.used:
        pop af
        inc a
        cp FS_ENTRIES
        jr c,.entry
        ld a,c
        ret

; -> HL = first free entry (there is one: fs_save checked)
fs_free_slot:
        xor a
.entry:
        push af
        call fs_entry
        pop af
        ld b,a
        ld a,(hl)
        cp FS_FREE_ENTRY
        ret z
        ld a,b
        inc a
        jr .entry

; AMSDOS header for fs_name / fs_length / fs_hdr_* in fs_buf[0..127]
fs_make_header:
        ld hl,fs_buf
        ld b,128
.clear:
        ld (hl),0
        inc hl
        djnz .clear
        ld hl,fs_name
        ld de,fs_buf + 1
        ld bc,11
        ldir
        ld a,(fs_hdr_type)
        ld (fs_buf + #12),a
        ld hl,(fs_length)
        ld (fs_buf + #13),hl
        ld (fs_buf + #18),hl
        ld (fs_buf + #40),hl
        ld hl,(fs_hdr_load)
        ld (fs_buf + #15),hl
        ld hl,(fs_hdr_exec)
        ld (fs_buf + #1A),hl
        ld a,#FF
        ld (fs_buf + #17),a
        ld hl,fs_buf                ; checksum of bytes 0..66
        ld b,67
        ld de,0
.sum:
        ld a,(hl)
        add a,e
        ld e,a
        jr nc,.no_carry
        inc d
.no_carry:
        inc hl
        djnz .sum
        ld (fs_buf + #43),de
        ret

; ---- state ----------------------------------------------------------
fs_first_id:    db #C1
fs_reserved:    db 0
fs_blocks:      db 180
fs_name:        ds 11
fr_new:         dw 0
fc_drives:      dw 0                ; target, source
fc_records:     dw 0
fc_nblocks:     db 0
fc_src_fmt:     dw 0                ; fs_first_id, fs_reserved
fc_dst_fmt:     dw 0
fc_left:        dw 0                ; sectors still to copy
fc_done:        dw 0
fc_chunk:       db 0
fc_j:           db 0
fc_cmd:         db 0
fc_list:        dw 0
fc_blist        equ GAP6 + 448      ; the source's blocks, 180 bytes
fs_s:           db 0
fs_e:           db 0
fs_p:           dw 0
fs_ex:          db 0
fs_bi:          db 0
fs_count:       db 0
fs_extents:     db 0
fs_nblocks:     db 0
fs_records:     dw 0
fs_total:       dw 0
fs_length:      dw 0
fs_hdr_type:    db 2                ; 0 BASIC, 2 binary, #FF no header
fs_hdr_load:    dw 0
fs_hdr_exec:    dw 0
ff_ex:          db 0
ff_i:           db 0
fc_i:           db 0
fc_count:       db 0
fl_ptr:         dw 0
fl_cfg:         db RAM_BASE_CFG
fl_left:        dw 0
fl_sector:      db 0
