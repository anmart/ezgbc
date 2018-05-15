; rst vectors
section "rst $00", rom0 [$00]
section "rst $08", rom0 [$08]
section "rst $10", rom0 [$10]
section "rst $18", rom0 [$18]
section "rst $20", rom0 [$20]
section "rst $28", rom0 [$28]
section "rst $30", rom0 [Bankswitch]
	jp _Bankswitch
section "rst $38", rom0 [$38]

; Hardware interrupts. None used at the moment
section "vblank int", rom0 [$40]
	jp VBlank
section "hblank int", rom0 [$48]
	reti
section "timer int",  rom0 [$50]
	reti ;jp SoundTimer
section "serial int", rom0 [$58]
	reti
section "joypad int", rom0 [$60]
	reti

section "Entry", rom0 [$100]
	; This is the entry point to the program.
	nop
	jp Init

section "Header", rom0 [$104]
	;GB header inserted by rgbfix.
	ds $150 - $104

section "Init", rom0
Init:
	di
	xor a
	ld [rIF], a
	ld [rIE], a
	ld [rRP], a
	ld [rSCX], a
	ld [rSCY], a
	ld [rSB], a
	ld [rSC], a
	ld [rWX], a
	ld [rWY], a
	ld [rBGP], a
	ld [rOBP0], a
	ld [rOBP1], a
	ld [rTMA], a
	ld [rTAC], a

.waitForVBlank
	ld a, [rLY]
	cp $90
	jr nz, .waitForVBlank

	;turn off the LCD
	xor a
	ld [rLCDC], a

	ld sp, wStack
	; establish our arbitrary stack location

	fill $c000, $1000, 0

	ld d, 7
.clear_wram_banks
	ld a, d
	ld [rSVBK], a
	fill $d000, $1000, 0
	dec d
	jr nz, .clear_wram_banks

		; clear hram
	fill $ff80, $7f, 0

	fill $8000, $2000, 0 ; zero vram
	fill $fe00, $a0,   0 ; zero OAM

	ld a, 1
	ld [hCurrentBank], a


	call LoadFontToVRAM
	ld hl, gfx_SamplePalettes
	call LoadBGPaletteData

	; set up the LCDC
	ld a, %01010011 ; Screen off, See docs for rest
	ld [rLCDC], a

	; load interrupt flag with no requests
	xor a
	ld [rIF], a

	; for now we only want V-blank enable
	inc a
	ld [rIE], a
	ei

	call StartGame
	jp Init

section "Standard Library Routines", rom0
; Copies BC bytes from HL to DE
CopyData:
	inc b
	inc c
	jr .startLoop
.loop
	ld a, [hli]
	ld [de], a
	inc de
.startLoop
	dec c
	jr nz, .loop
	dec b
	jr nz, .loop
	ret

; multiplies h * l and puts the result in hl
HTimesL:
	push bc
	ld b, 0
	ld c, h
	ld a, l
	ld hl, 00
	jr .startLoop
.add
	add hl, bc
.loop
	sla c
	rl b
.startLoop
	srl a
	jr c, .add
	jr nz, .loop
	pop bc
	ret

; returns joypad readout in a and hJoypadData
ReadJoypad:
	push bc
	ld a, $20 ; select direction keys
	ld [rJOYP], a
	ld a, [rJOYP]
	ld a, [rJOYP]
	and $0f
	ld b, a
	swap b
	ld a, $10 ; select button keys
	ld [rJOYP], a
	ld a, [rJOYP]
	ld a, [rJOYP]
	ld a, [rJOYP]
	and $0f
	add a, b
	pop bc
	cpl
	ld [hJoypadData], a
	ret

TurnScreenOff:
	di
.waitForVBlank
	ld a, [rLY]
	cp $90
	jr nz, .waitForVBlank

	ld a, [rLCDC]
	res 7, a
	ld [rLCDC], a
	ei
	ret

TurnScreenOn:
	ld a, [rLCDC]
	set 7, a
	ld [rLCDC], a
	ret

Random:
	push bc
	push hl
	ld hl, wRNG1
	ld c, [hl]
	inc hl
	ld b, [hl]
	ld a, b
	or c
	jr z, .initializeRNG
	; 1,5,2 16 bit xorshift rng
	ld h, b
	ld l, c
	sla l
	rl h
	;16 bit xor is a bit unwieldy, so it was made a macro
	random16bXor
	rept 5
	srl h
	rr l
	endr
	random16bXor
	rept 2
	sla l
	rl h
	endr
	random16bXor rand_LastRun ; arg allows for modification required by the final run
	pop hl
	pop bc
	ret


.initializeRNG
	ld a, $ff
	ld [wRNG1], a
	pop hl
	pop bc
	ret

section "bankswitch", rom0
; switches to the bank in a
_Bankswitch:
	ld [hCurrentBank], a
	ld [MBC5_ROMBank], a
	ret

section "VBlank", rom0
VBlank:
	push af
	push bc
	push de
	push hl

	call V_UpdateTileMapBuffer

	; end of Vblank-required routines


	call Random

	ld a, 1
	ld [hVBlankOccurred], a

	pop hl
	pop de
	pop bc
	pop af
	reti

WaitForVBlank:
	xor a
	ld [hVBlankOccurred], a

	ld a, [rLCDC]
	bit 7, a
	ret z

.wait
	halt
	ld a, [hVBlankOccurred]
	or a
	jr z, .wait
	ret

; VBlank routine to copy TileMapBuffer to vram if applicable
; Fast Copy takes priority over slow copy
V_UpdateTileMapBuffer:
	ld a, [wFastBufferControl]
	or a
	jr z, .skipFastCopy
	call FastCopyTileBuffersToVram
	xor a
	ld [wFastBufferControl], a
	ret

.skipFastCopy
	ld a, [wTileBufferSize]
	or a
	jr z, .skipTileMapWrite

	ld hl, wTileBufferDrawLocation
	ld e, [hl]
	inc hl
	ld d, [hl]
	call CopyTileBufferToVram

.skipTileMapWrite
	ret

section "home text", rom0
; copy Font to VRAM bank 2 and just let it chill there for the entirety of the game
LoadFontToVRAM:	
	ld a, 1
	ld [rVBK], a
	ld bc, gfx_EndFontTiles - gfx_FontTiles
	ld hl, gfx_FontTiles
	ld de, vChars0 + vTileDataSize
	call CopyData
	xor a
	ld [rVBK], a
	ret

; Writes text to TileMapBuffer in preparation for vblank
; bc - source of text
; de - buffer location offset ; usually something like which line to start on
; ret bc - stopping pos in source text
; ret de - last text value, amount of characters printed
; ret a - amount of characters printed
LoadTextToMapBuffer:
	push hl

	;set up our attr hram
	ld a, 8
	ld [hTextAttr], a

	; prepare hl and de for the load text loop
	ld hl, wTileAttrBuffer
	add hl, de
	push hl
	ld hl, wTileMapBuffer
	add hl, de
	ld d, h
	ld e, l
	pop hl
	push de
.loadText
	ld a, [bc]
	inc bc
	inc a
	jr z, .done

	ld [de], a
	inc de
	ld a, [hTextAttr]
	ldi [hl], a

	jr .loadText

.done
	pop hl
	ld d, a
	ld a, e
	sub l ; max of $20 chars/line, so this should be fine to tell me how many chars were used
	ld e, a
	pop hl
	ret

section "Drawing Routines", rom0

; Draws every tile of an image in order, in an arbitrary rectangular shape
; hl - where in vram to start writing
; bc - sprite height in tiles,
; de - sprite width in tiles, 32 - width (how much to add to get back to 0)
; a  - starting tile index	
LoadIncreasingTilesToVram:
	push de
.loopTile
	ldi [hl], a
	inc a

	dec d
	jr nz, .loopTile

	add hl, de
	pop de

	dec b
	jr nz, LoadIncreasingTilesToVram

	ret


; loads full set of palettes to gb memory from a location in hl
LoadBGPaletteData:
	push bc
	ld a, $80
	ld [rBGPI], a
	ld b, $40
.loop
	ldi a, [hl]
	ld [rBGPD], a
	dec b
	jr nz, .loop
	pop bc
	ret

; quickly copies horizontal and vertical buffers to wram along with their attribute maps.
; Can not be variable width. If that's needed, use the slow version (CopyTileBuffersToVram)
FastCopyTileBuffersToVram:
	push hl
	push bc

	ld a, [wFastBufferControl]
	bit 1, a
	jr z, .skipHorizontalCopy		

	ld hl, wFastHorizontalBufferLoc
	ld e, [hl]
	inc hl
	ld d, [hl]
	ld bc, wFastHorizontalTileBuffer
	push de
	call FastCopyHorizontalBufferToVram
	pop de
	ld a, 1
	ld [rVBK], a
	ld bc, wFastHorizontalAttrBuffer
	call FastCopyHorizontalBufferToVram

	ld a, [wFastBufferControl]
	bit 0, a
	jr z, .skipVerticalCopy

.skipHorizontalCopy

	ld hl, wFastVerticalBufferLoc
	ld e, [hl]
	inc hl
	ld d, [hl]
	xor a
	ld [rVBK], a
	ld bc, wFastVerticalTileBuffer
	push de
	call FastCopyVerticalBufferToVram
	pop de
	ld a, 1
	ld [rVBK], a
	ld bc, wFastVerticalAttrBuffer
	call FastCopyVerticalBufferToVram	

.skipVerticalCopy
	xor a
	ld [rVBK], a
	ld [wFastBufferControl], a

	pop bc
	pop hl
	ret

; copies the tile map buffer at the beginning of wram to vram
; if the screen is off, it will copy the map and the attributes over at the same time.
; if the screen is on, it will set the buffer control to do attributes next frame
; de - vram location
CopyTileBufferToVram:

	push hl
	push bc

	ld hl, wTileBufferControl
	bit 1, [hl]
	res 1, [hl]
	jr nz, .doAttributes

	ld a, [wTileBufferSize]
	ld c, a
	bit 2, [hl] ; hl still control from above
	ld b, 1
	jr z, .onlyOneMapRow
	inc b

.onlyOneMapRow
	ld hl, wTileMapBuffer

	; check 0th bit to see if we want vertical instead of horizontal
	ld a, [wTileBufferControl]
	bit 0, a
	
	push de
	call z, CopyHorizontalBufferToVram
	call nz, CopyVerticalBufferToVram
	pop de

	; if it's only one row, do attr also
	ld a, [wTileBufferControl]
	bit 2, a
	jr z, .doAttributes

	ld a, [rLCDC]
	bit 7, a
	jr z, .doAttributes
	
	ld hl, wTileBufferControl
	set 1, [hl]
	pop bc
	pop hl
	ret
	

.doAttributes
	ld hl, wTileBufferControl
	ld a, [wTileBufferSize]
	ld c, a
	ld b, 1
	bit 2, [hl]
	jr z, .onlyOneAttrRow
	inc b

.onlyOneAttrRow
	ld a, 1
	ld [rVBK], a

	bit 0, [hl]

	ld hl, wTileAttrBuffer

	call z, CopyHorizontalBufferToVram
	call nz, CopyVerticalBufferToVram

	xor a
	ld [rVBK], a
	ld [wTileBufferControl], a
	ld [wTileBufferSize], a
	pop bc
	pop hl
	ret

; Buffer Copy used for scrolling. can only draw entire $14 tile buffer at once. for variable size, use slow copy.
; de - location in vram to start writing
; bc - location in wram to start reading
FastCopyHorizontalBufferToVram:
	ld hl, sp+$0
	ld a, l
	ldh [hStackStorage], a	
	ld a, h
	ldh [hStackStorage+1], a
	ld h, b
	ld l, c
	ld sp, hl

	ld h, d
	ld l, e

	REPT 10
	pop bc
	ld a, c
	ld [hli], a
	ld a, b
	ld [hli], a
	ENDR

	ldh a, [hStackStorage]
	ld l, a
	ldh a, [hStackStorage+1]
	ld h, a
	ld sp, hl
	ret


; copies a horizontal buffer with variable width to vram
; for use with text and other slow or small things
; de - where in vram to start writing
; bc - buffer height in tiles, buffer width in tiles
; hl - buffer location
; CAUTION:	Can only handle a limited size for copies
CopyHorizontalBufferToVram:
	push bc
.rowLoop
	ld a, [hli]
	ld [de], a
	inc de
	dec c
	jr nz, .rowLoop

	ld a, b
	pop bc
	dec a
	ld b, a
	ret z

	ld a, $20
	sub c
	add e
	ld e, a
	ld a, d
	adc 0
	ld d, a
	ld a, $20
	sub c
	add l
	ld l, a
	ld a, h
	adc 0
	ld h, a
	jr CopyHorizontalBufferToVram

; Buffer Copy used for scrolling. can only draw entire $14 tile buffer at once. for variable size, use slow copy.
; de - location in vram to start writing
; bc - location in wram to start reading
FastCopyVerticalBufferToVram:
	ld hl, sp+$0
	ld a, l
	ldh [hStackStorage], a	
	ld a, h
	ldh [hStackStorage+1], a
	ld h, b
	ld l, c
	ld sp, hl

	ld h, d
	ld l, e
	ld de, $20
	
REPT 9
	pop bc
	ld [hl], c
	add hl, de
	ld [hl], b
	add hl, de
ENDR

	ldh a, [hStackStorage]
	ld l, a
	ldh a, [hStackStorage+1]
	ld h, a
	ld sp, hl
	ret

; copies a vertical buffer with variable height to vram
; for use with text and other slow or small things
; de - where in vram to start writing
; bc - buffer width in tiles, buffer height in tiles
; hl - buffer location
; CAUTION:	Can only handle a limited size for copies.
CopyVerticalBufferToVram:
	push de
	push hl
	push bc
.colLoop
	ld a, [hli]
	ld [de], a

	ld a, $20
	add e
	ld e, a
	ld a, d
	adc 0
	ld d, a

	dec c
	jr nz, .colLoop

	ld a, b
	pop bc
	ld b, a
	
	ld de, $20
	pop hl
	add hl, de
	pop de
	inc de

	dec b
	jr nz, CopyVerticalBufferToVram

	ret
	
ClearBGMap:
	fill vBGMap0, $a000 - vBGMap0, 0
	ld a, 1
	ld [rVBK], a
	fill vBGMap0, $a000 - vBGMap0, 0
	xor a
	ld [rVBK], a
	ret

section "Game Home Routines", rom0

; Starts game with nothing loaded and screen off.
StartGame:


; TODO: Delete below. it's a (poorly coded) example of how things work
	call TurnScreenOn
	
	ld bc, SampleText
	ld de, 0
	call LoadTextToMapBuffer
	ld [wTileBufferSize], a
	setBufferDrawLocation vBGMap0
	ld hl, wTileBufferControl
	set 0, [hl]

	ld hl, wFastVerticalTileBuffer
	ld a, $66
	ld b, $14
.looplette
	ldi [hl], a
	dec b
	jr nz, .looplette
	ld hl, wFastVerticalAttrBuffer
	ld a, $08
	ld b, $14
.looplette2
	ldi [hl], a
	dec b
	jr nz, .looplette2


	ld hl, wFastHorizontalTileBuffer
	ld a, $60
	ld b, $14
.looplette3
	ldi [hl], a
	dec b
	jr nz, .looplette3
	ld hl, wFastHorizontalAttrBuffer
	ld a, $08
	ld b, $14
.looplette4
	ldi [hl], a
	dec b
	jr nz, .looplette4

	setBufferDrawLocation vBGMap0 + $20, wFastHorizontalBufferLoc
	setBufferDrawLocation vBGMap0 + $5, wFastVerticalBufferLoc
	ld a, 3
	ld [wFastBufferControl], a

	call WaitForVBlank
	call WaitForVBlank
	
	ld bc, SampleText2
	ld de, 0
	call LoadTextToMapBuffer
	ld [wTileBufferSize], a
	setBufferDrawLocation vBGMap0 + $20

	REPT 40
	call WaitForVBlank
	ENDR

; Copies BC bytes from HL to DE
.loop:
	ld a, [rSCY]
	add 8
	ld [rSCY], a
	ld a, [rSCX]
	add 8
	ld [rSCX], a
	call WaitForVBlank
	jr .loop
