import sys, os, random, math, bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import studio as S
from mathutils import Vector
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')

def grapes(at, scale=1.0, seed=1):
    random.seed(seed); objs = []
    g = S.mat('grape', (0.13, 0.03, 0.16), rough=0.38, sss=0.25, coat=0.3)
    rows = 9
    for i in range(rows):
        t = i / (rows - 1); rad = (0.22 * (1 - t) + 0.04) * scale; n = max(1, int(7 * (1 - t)) + 1)
        z = at.z - i * 0.07 * scale
        for j in range(n):
            ang = j / n * 2 * math.pi + random.random() * 0.6; rr = rad * (0.6 + random.random() * 0.4)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055 * scale * (0.9 + random.random() * 0.2), location=(at.x + rr * math.cos(ang), at.y + rr * math.sin(ang), z), segments=24, ring_count=16)
            o = bpy.context.object; o.scale = (1, 1, 1.12); bpy.ops.object.shade_smooth(); o.data.materials.append(g); objs.append(o)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.012 * scale, depth=0.16 * scale, location=(at.x, at.y, at.z + 0.08 * scale))
    st = bpy.context.object; st.rotation_euler = (0.3, 0, 0); st.data.materials.append(S.mat('stem', (0.22, 0.14, 0.06), rough=0.7)); objs.append(st)
    return objs

# 1) grape kit: a wicker harvest basket full of grapes
S.reset()
bk = S.imp('wicker_basket_01'); S.normalize(bk, 1.0); bpy.context.view_layer.update()
lo, hi = S.bounds(bk); top = hi.z
allg = []
for k, (dx, dy) in enumerate([(-0.18, 0.05), (0.15, -0.05), (0.0, 0.12), (0.02, -0.12)]):
    gs = grapes(Vector((dx, dy, top + 0.12)), scale=0.85, seed=k + 3)
    for o in gs: o.rotation_euler = (math.radians(70 + k * 15), 0, math.radians(k * 80))
    allg += gs
S.shoot(bk + allg, os.path.join(OUT, 'grape_kit.png'))

# 2) poultry kit: a taped cardboard box with a printed stencil
S.reset()
bx = S.imp('cardboard_box_01'); S.normalize(bx, 1.0)
S.shoot(bx, os.path.join(OUT, 'poultry_kit_box.png'))

# 3) engine oil: the oil can
S.reset()
oc = S.imp('small_oil_can_01'); S.normalize(oc, 1.0)
S.shoot(oc, os.path.join(OUT, 'engine_oil.png'), az=-30)
