import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
reset('autoshop_01', 0.6, transparent=True)
for mid in ['bench_vice_01', 'brass_pot_01', 'bunsen_burner', 'ammo_box']:
    root, objs = imp(mid); lo, hi = bounds(objs); print('B', mid, tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))
    for o in objs: o.hide_render = True
