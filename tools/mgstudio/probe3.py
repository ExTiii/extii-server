import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
reset('autoshop_01', 0.6, transparent=True)
root, objs = imp('service_pistol')
for o in objs:
    if o.type == 'MESH':
        lo, hi = bounds([o]); print('PART', o.name, tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))
