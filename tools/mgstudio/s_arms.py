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


# ------------------------------------------------------------- the frame in the vise, a hand file
def file_bg(part='bg'):
    reset('autoshop_01', 0.06, rot=0.4)
    plane(1.6, 1.6, (0, 0, -0.004), pbr('wood', 'wood_table_worn', 2.0, tint=(0.6, 0.55, 0.5)))
    plane(0.52, 0.30, (0, 0, 0.0), img_mat('matp', '/home/claude/mgstudio/tex/mat.png', rough=0.85, spec=0.2))
    # the frame on its side, a couple of steel filings already around it
    root, all_ = imp('service_pistol'); root.rotation_euler = (math.radians(-90), 0, 0)
    keep = 'service_pistol_pistol_a'
    for o in all_:
        if o.type == 'MESH' and o.name != keep: o.hide_render = True
    bpy.context.view_layer.update()
    fr = [o for o in all_ if o.name == keep]
    lo, hi = bounds(fr); root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2 - 0.01, -lo.z + 0.0005)
    bpy.context.view_layer.update(); lo, hi = bounds(fr)
    import random; random.seed(2)
    fil = mat('filings', (0.6, 0.6, 0.62), 0.35, 1.0)
    for i in range(40):
        box((0.0012, 0.0004, 0.0003), (random.uniform(lo.x, hi.x), hi.y + random.uniform(0.002, 0.02), 0.0003), fil, rot=(0, 0, random.uniform(0, 3)))
    worklight(1.8)
    top_cam(W, H, PX, PY, height=1.0)
    render('out/file_bg.png')
    json.dump({'edge': [round(PX / 2 + lo.x * PPM), round(PX / 2 + hi.x * PPM), round(PY / 2 - hi.y * PPM)]}, open('out/file_bg.json', 'w'))

def file_sprite():
    reset('autoshop_01', 0.06, rot=0.4, transparent=True)
    # a flat bastard file: hatched steel blade, tang into a wooden handle
    steel = mat('fs', (0.16, 0.16, 0.17), 0.5, 1.0)
    nt = steel.node_tree; b = P(steel)
    wv = nt.nodes.new('ShaderNodeTexWave'); wv.inputs['Scale'].default_value = 420; wv.wave_type = 'BANDS'; wv.bands_direction = 'DIAGONAL'
    bu = nt.nodes.new('ShaderNodeBump'); bu.inputs['Strength'].default_value = 1.0
    nt.links.new(wv.outputs['Fac'], bu.inputs['Height']); nt.links.new(bu.outputs['Normal'], b.inputs['Normal'])
    wv2 = nt.nodes.new('ShaderNodeTexWave'); wv2.inputs['Scale'].default_value = 420; wv2.wave_type = 'BANDS'; wv2.bands_direction = 'DIAGONAL'; wv2.inputs['Distortion'].default_value = 0.5
    cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].color = (0.05, 0.05, 0.055, 1); cr.color_ramp.elements[1].color = (0.42, 0.42, 0.44, 1)
    nt.links.new(wv2.outputs['Fac'], cr.inputs[0]); nt.links.new(cr.outputs[0], b.inputs['Base Color'])
    blade = box((0.2, 0.02, 0.005), (0, 0, 0.0025), steel, bevel=0.0008)
    for v in blade.data.vertices:
        if v.co.x > 0.05: v.co.y *= 1 - (v.co.x - 0.05) / 0.16
    tang = box((0.03, 0.008, 0.004), (-0.115, 0, 0.0025), steel)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.013, depth=0.11, location=(-0.18, 0, 0.013), rotation=(0, math.radians(90), 0)); h = bpy.context.object
    for v in h.data.vertices: v.co.x *= 1.0; 
    for v in h.data.vertices:
        t = (v.co.z + 0.055) / 0.11
        k = 0.8 + 0.35 * math.sin(t * math.pi) if True else 1
        v.co.x *= k; v.co.y *= k
    assign(h, pbr('hdlw', 'wood_table_worn', 14, tint=(1.0, 0.85, 0.7))); smooth(h, 0.002, 3)
    cyl(0.0105, 0.012, (-0.128, 0, 0.013), mat('ferrule', (0.8, 0.6, 0.3), 0.25, 1.0), rot=(0, math.radians(90), 0), bevel=0.001)
    h.location.z = 0.013
    worklight(3.0)
    sprite([o for o in bpy.data.objects if o.type == 'MESH'], 'out/file.png', PPM)

JOBS2 = {'file_bg': file_bg, 'file': file_sprite}

if sys.argv[-1] == 'bg': mat_bg()
elif sys.argv[-1] in JOBS2: JOBS2[sys.argv[-1]]()
else: part_sprite(sys.argv[-1])
