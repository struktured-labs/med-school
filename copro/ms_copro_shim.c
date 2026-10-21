/* ms_copro_shim.c: thin C entry point over the unmodified C port (grok/c-port 785105c0).
 * in[0..127] = $5000-$507F as the cart wrote them, in[128..131] = $5080-$5083.
 * out: [0]=col [1]=o4 (search return) [2]=done_col [3]=done_o4 [4]=tuck_col [5]=tuck_row [6]=tuck_rest
 * (rest row of the committed tuck candidate, $FF if none)  -> returns nodes. */
#include "drm_copro.h"
#include <string.h>
static const unsigned char TUCK_O4[4] = { 2, 1, 3, 0 };
unsigned ms_search(const unsigned char *in, unsigned char *out)
{
	static drm_cfg cfg; static int init;
	if (!init) { drm_cfg_shipped(&cfg); init = 1; }
	drm_in di; drm_out o;
	memcpy(di.board, in, 128);
	di.ca = in[128]; di.cb = in[129]; di.na = in[130]; di.nb = in[131];
	drm_search(&cfg, &di, &o);
	out[0] = o.col; out[1] = o.o4; out[2] = o.done_col; out[3] = o.done_o4;
	out[4] = o.tuck_col; out[5] = o.tuck_row; out[6] = 0xFF;
	if (o.tuck_col != 0xFF)
		for (int k = 0; k < o.tcnt; k++)
			if (o.cand[k].approach == o.tuck_col && o.cand[k].trigger == o.tuck_row &&
			    o.cand[k].target == o.done_col && TUCK_O4[o.cand[k].orient] == o.done_o4) { out[6] = o.cand[k].rest; break; }
	return o.nodes;
}
