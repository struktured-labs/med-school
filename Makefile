COPRO ?= 0
AUDIO ?= 1
PASTEL ?= 0
NAME ?= medschool
all: build/$(NAME).nes
build/chr.bin: tools/mkassets.py
	python3 tools/mkassets.py build
build/audio.o: music/engine/med_school_audio.s music/export/med_school_sfx.s music/export/med_school_music.s
	mkdir -p build && cd music/engine && ca65 med_school_audio.s -o ../../build/audio.o
build/$(NAME).nes: src/main.s src/player.inc src/demo_data.inc src/throw_tab.inc src/audio.inc src/nrom.cfg build/chr.bin $(if $(filter 1,$(AUDIO)),build/audio.o)
	ca65 -g -I src -I . -D PASTEL=$(PASTEL) -D AUDIO=$(AUDIO) src/main.s -o build/$(NAME).o
	ld65 -C src/nrom.cfg build/$(NAME).o $(if $(filter 1,$(AUDIO)),build/audio.o) -o $@ -Ln build/$(NAME).labels -m build/$(NAME).map
	md5sum $@
variants:
	$(MAKE) NAME=medschool
	$(MAKE) NAME=medschool_pastel PASTEL=1
	$(MAKE) NAME=medschool_silent AUDIO=0
	$(MAKE) copro
# same PRG/CHR, iNES mapper 100 (MMC1 + Dr. Mario copro window, e.g. the DRDANGER core)
copro: build/medschool.nes
	python3 -c "b=bytearray(open('build/medschool.nes','rb').read()); b[6]=0x41; b[7]=0x60; open('build/medschool_copro.nes','wb').write(b)"
	md5sum build/medschool_copro.nes
clean:
	rm -rf build
.PHONY: all variants clean copro
