CPORT ?= $(HOME)/projects/grok-cport-wt/c_port
libmscopro.so: ms_copro_shim.c $(CPORT)/drm_copro.c $(CPORT)/drm_copro.h
	cc -O2 -fPIC -shared -I$(CPORT) ms_copro_shim.c $(CPORT)/drm_copro.c -o $@
