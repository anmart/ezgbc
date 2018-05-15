.POSIX:
.SUFFIXES: .asm

name = ezgbc
src  = src
obj  = src/main.o src/wram.o

all: clean $(name).gbc

clean:
	@rm -f $(obj) $(name).gbc $(name).sym
	@find . -name "*.2bpp" -type f -delete
	@find . -name "*.1bpp" -type f -delete
	@find . -name "*.o" -type f -delete

gfx:
	@find -iname "*.png" -exec sh -c 'rgbgfx -F -o $${1%.png}.2bpp $$1' _ {} \;

.asm.o:
	@rgbasm -i $(src)/ -o $@ $<

$(name).gbc: gfx $(obj)
	@rgblink -n $(name).sym -o $@ $(obj)
	@rgbfix -Cjsv -i "    " -k XX -l 0x33 -m 0x1b -p 0 -r 1 -t EZGBC $@
