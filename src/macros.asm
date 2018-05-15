; 16bit fill, from bootstrap.gb
; fill loc, amt, val
fill: macro
	ld hl, \1
	ld bc, \2
.loop\@
	ld [hl], \3
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .loop\@
endm

; used only for the Random function
; note: pass literally anything as an argument
; to skip the extra loads into de
random16bXor: macro
	ld a, l
	xor c
	ld c, a
IF _NARG == 0
	ld l, a
ELSE
	ld [wRNG1], a
ENDC

	ld a, h
	xor b
	ld b, a
IF _NARG == 0
	ld h, a
ELSE
	ld [wRNG2], a
ENDC
endm
rand_LastRun EQU $0

setBufferDrawLocation: macro
IF _NARG == 1
	ld hl, wTileBufferDrawLocation
ELSE
	ld hl, \2
ENDC
	ld [hl], LOW(\1)
	inc hl
	ld [hl], HIGH(\1)
endm

