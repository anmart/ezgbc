; at $ff, I can add 1 to the text and if it's zero I can stop text.
endText EQU $ff

; ascii constants for certain text effects
SPACE_CHAR EQU $21

TEXT_VRAM_OFFSET EQU $80
ASCII_TO_TILE    EQU $01 + TEXT_VRAM_OFFSET
