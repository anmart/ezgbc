section "wram0", wram0 [$c000]

	ds $100
wStack::

; Slower Tile Buffer used for text or other things that don't need fast updating
; For quick updating, using FastBuffer below, which takes priority over this.
wTileBufferStart::
wTileMapBuffer::
	ds $20
wTileAttrBuffer::
	ds $20
wTileBufferDrawLocation::
	ds $2
wTileBufferSize::
	ds $1
; bitmap
; 0 - Vertical
; 1 - halfway pause
; 2 - double size - Requires halfway pause
wTileBufferControl::
	ds $1
wTileBufferEnd::

wFastHorizontalTileBuffer::
	ds $14
wFastHorizontalAttrBuffer::
	ds $14
wFastHorizontalBufferLoc::
	ds $2
wFastVerticalTileBuffer::
	ds $12
wFastVerticalAttrBuffer::
	ds $12
wFastVerticalBufferLoc::
	ds $2

; bitmap
; 0 - Vertical
; 1 - Horizontal
wFastBufferControl::
	ds $1

wRNG1::
	ds $1
wRNG2::
	ds $1

section "hram",  hram
;hMusicStepDivCount::
;	ds $1

hCurrentBank::
	ds $1

hTextAttr::
	ds $1

; direction keys in high nybble, button keys in low nybble
hJoypadData::
	ds $1

hVBlankOccurred::
	ds $1

hStackStorage::
	ds $2

; useful for when something requires 1 extra byte. 
; best if no function that might use hTempVar is called
; when storing important info
hTempVar::
	ds $1
