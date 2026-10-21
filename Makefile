COPRO ?= 0
AUDIO ?= 1
PASTEL ?= 0
NAME ?= medschool
all: build/$(NAME).nes
build/chr.bin: tools/mkassets.py
	python3 tools/mkassets.py build
build/audio.o: music/engine/med_school_audio.s
	mkdir -p build && cd music/engine && ca65 med_school_audio.s -o ../../build/audio.o
build/$(NAME).nes: src/main.s src/audio.inc src/nrom.cfg build/chr.bin $(if $(filter 1,$(AUDIO)),build/audio.o)
	ca65 -g -I src -I . -D COPRO=$(COPRO) -D PASTEL=$(PASTEL) -D AUDIO=$(AUDIO) src/main.s -o build/$(NAME).o
	ld65 -C src/nrom.cfg build/$(NAME).o $(if $(filter 1,$(AUDIO)),build/audio.o) -o $@ -Ln build/$(NAME).labels -m build/$(NAME).map
	md5sum $@
variants:
	$(MAKE) NAME=medschool
	$(MAKE) NAME=medschool_pastel PASTEL=1
	$(MAKE) NAME=medschool_copro COPRO=1
	$(MAKE) NAME=medschool_silent AUDIO=0
clean:
	rm -rf build
.PHONY: all variants clean
