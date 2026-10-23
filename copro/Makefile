# needs DRSTYLES (drm_style_decode, ms_search_s)
CPORT ?= $(HOME)/projects/grok-pushes/copro-styles-wt/c_port
libmscopro.so: ms_copro_shim.c $(CPORT)/drm_copro.c $(CPORT)/drm_copro.h
	cc -O2 -fPIC -shared -I$(CPORT) ms_copro_shim.c $(CPORT)/drm_copro.c -o $@
