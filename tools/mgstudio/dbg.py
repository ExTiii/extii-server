import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
reset('autoshop_01', 0.15, rot=1.2)
w = cyl(0.0125, 0.0016, (0, 0, 0.0008), mat('washer', (0.3, 0.29, 0.28), 0.55, 1.0, noise=0.18), bevel=0.0004)
print('MATS before', [m.name for m in w.data.materials])
boolean(w, cyl(0.0064, 0.005, (0, 0, 0.0008), verts=48))
print('MATS after', [m.name if m else None for m in w.data.materials], set(p.material_index for p in w.data.polygons))
