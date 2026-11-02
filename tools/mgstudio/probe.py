import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
mid = sys.argv[-1]
reset('autoshop_01', 0.6, transparent=True)
root, objs = imp(mid)
root.rotation_euler = (math.radians(90), 0, 0)
lo, hi = bounds(objs); print('BOUNDS', mid, tuple(round(v,4) for v in lo), tuple(round(v,4) for v in hi))
c = (lo + hi) / 2; sz = max(hi.x - lo.x, hi.y - lo.y) * 1.05
top_cam(sz, sz, 400, 400, height=hi.z + 1, center=(c.x, c.y))
render(f'out/probe_{mid}.png')
