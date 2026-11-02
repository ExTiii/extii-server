import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
reset('autoshop_01', 0.6, transparent=True)
root, objs = imp('rusted_wheel_rim_01'); root.rotation_euler = (math.radians(90), 0, 0)
lo, hi = bounds(objs); print('RIM', tuple(lo), tuple(hi))
top_cam(0.44, 0.44, 880, 880, height=1)
render('out/rim_alpha.png')
r2, o2 = imp('old_tyre') if False else (None, None)
