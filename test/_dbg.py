import sys; sys.path[:0]=["test","ref"]
import medsim as M
from plan_proto import plan
B=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 5, 6, 7, 0, 0, 0, 6, 0, 0, 0, 6, 0, 0, 0, 0, 6, 0, 0, 0, 3, 0, 0, 6, 5, 6, 0, 7, 1, 0, 0, 6, 0, 0, 0, 0, 7, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 5, 0, 7, 0, 5, 0, 0, 0, 6, 65, 50, 5, 65, 51, 0, 6, 0, 5, 0, 7, 0, 7, 0, 0, 7, 5, 6, 7, 5, 0, 3, 5, 5]
for r in range(16): print("".join(".#"[bool(B[r*8+c])] for c in range(8)))
class G: pass
g=M.MedGame(0,1,0x12,0x34)
for r in range(16):
    for c in range(8): g.b.color[r,c]= B[r*8+c]&3
g.x,g.y,g.o=3,0,0
print(plan(g,0,10,2))
