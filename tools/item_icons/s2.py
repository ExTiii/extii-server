import sys, os, math, bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import studio as S, grapes as G
from mathutils import Vector
S.reset()
bk = S.imp('wicker_basket_01'); S.normalize(bk, 1.0); bpy.context.view_layer.update()
lo, hi = S.bounds(bk); top = hi.z
objs = []
for k, (dx, dy, rx, rz) in enumerate([(-0.2, 0.06, 80, 20), (0.17, -0.02, 75, 200), (0.0, 0.14, 85, 110), (-0.02, -0.12, 70, 300)]):
    objs += G.bunch(Vector((dx, dy, top + 0.05)), scale=0.9, seed=k + 7, tilt=(math.radians(rx), 0, math.radians(rz)))
S.shoot(bk + objs, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out', 'grape_kit.png'))
