# weapons bench: the cleaning mat with the pistol parts (assemble), each part as its own sprite
import sys, json; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
W, H = 0.40, 0.23
PX, PY = 1200, 690
PPM = PX / W
PARTS = ['service_pistol_slide_a', 'service_pistol_pistol_a', 'service_pistol_magazine_loaded', 'service_pistol_trigger_a', 'service_pistol_hammer_a', 'spring']

def lamps(k=1.0): worklight(k * 1.8)

def mat_bg():
    reset('autoshop_01', 0.06, rot=0.4)
    plane(1.6, 1.6, (0, 0, -0.004), pbr('wood', 'wood_table_worn', 2.0, tint=(0.6, 0.55, 0.5)))
    m = plane(0.52, 0.30, (0, 0, 0.0), img_mat('matp', '/home/claude/mgstudio/tex/mat.png', rough=0.85, spec=0.2))
    # a cleaning rod and a little oil bottle at the edge, a few cotton patches
    cyl(0.003, 0.22, (0.05, 0.105, 0.003), mat('rod', (0.75, 0.62, 0.35), 0.3, 1.0), rot=(0, math.radians(90), math.radians(4)), bevel=0.0008)
    lamps()
    top_cam(W, H, PX, PY)
    render('out/arms_bg.png')

def spring():
    """a recoil spring: a helix of steel wire"""
    import bmesh
    bm = bmesh.new()
    turns, L, R, r = 14, 0.07, 0.0042, 0.0006
    pts = [(L * i / 400 - L / 2, R * math.cos(i / 400 * turns * 6.283), R * math.sin(i / 400 * turns * 6.283)) for i in range(401)]
    cd = bpy.data.curves.new('sp', 'CURVE'); cd.dimensions = '3D'; cd.bevel_depth = r; cd.bevel_resolution = 3
    sp = cd.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts): p.co = (*c, 1)
    o = bpy.data.objects.new('spring', cd); bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat('sprm', (0.5, 0.5, 0.52), 0.3, 1.0))
    bpy.context.view_layer.objects.active = o; o.select_set(True); bpy.ops.object.convert(target='MESH')
    return bpy.context.object

def part_sprite(name):
    reset('autoshop_01', 0.06, rot=0.4, transparent=True)
    if name == 'spring':
        objs = [spring()]
    else:
        root, all_ = imp('service_pistol')
        root.rotation_euler = (math.radians(-90), 0, 0)
        for o in all_:
            if o.type == 'MESH' and o.name != name: o.hide_render = True
        objs = [o for o in all_ if o.name == name]
    lamps()
    sprite(objs, f'out/part_{name.replace("service_pistol_", "")}.png', PPM * 0.85)

if sys.argv[-1] == 'bg': mat_bg()
else: part_sprite(sys.argv[-1])
