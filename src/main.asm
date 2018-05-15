include "constants.asm"

; sections are handled in home.
include "engine/home.asm"

section "text", romx
include "text/text.asm"

section "gfx", romx
include "gfx/gfx.asm"
