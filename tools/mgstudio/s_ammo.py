# ammo bench: the lead pot on its burner (melt), the reloading press (press), the 20-round box (boxfill), cartridges
import sys, json; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
PX, PY = 1200, 690
W, H = 0.40, 0.23
PPM = PX / W

def bench():
    return plane(3, 3, (0, 0, 0), pbr('wood', 'wood_table_worn', 1.6, tint=(0.55, 0.5, 0.46)))

# ------------------------------------------------------------- melt
def melt_scene(part):
    reset('autoshop_01', 0.05, rot=1.0, transparent=(part != 'bg'))
    bench()
    root, objs = imp('bunsen_burner'); root.scale = (1.1, 1.1, 1.1); root.location = (0, 0, 0)
    iron = pbr('ironp', 'rust_coarse_01', 10, tint=(0.16, 0.15, 0.14), metal=0.55, sat=0.4)
    Z0 = 0.19
    # a cast-iron lead pot: thick wall, a pouring lip, open top
    prof = [(0.0, Z0), (0.050, Z0), (0.058, Z0 + 0.01), (0.062, Z0 + 0.06), (0.066, Z0 + 0.072), (0.060, Z0 + 0.074), (0.055, Z0 + 0.062), (0.052, Z0 + 0.012), (0.0, Z0 + 0.012)]
    potm = lathe(prof, iron, name='pot')
    pobjs = [potm]
    # the lead inside (the page paints its heat on top); slag rim
    cyl(0.0535, 0.002, (0, 0, Z0 + 0.052), mat('leadsurf', (0.2, 0.2, 0.21), 0.3, 1.0, noise=0.05))
    # two handles
    for s_ in (-1, 1):
        box((0.03, 0.012, 0.008), (s_ * 0.075, 0, Z0 + 0.06), iron, bevel=0.002)
    # the flame under the pot
    bpy.ops.mesh.primitive_cone_add(radius1=0.011, radius2=0.002, depth=0.04, location=(0, 0, 0.17)); fl = bpy.context.object
    assign(fl, mat('flame', (0.1, 0.2, 1.0), 0.5, emit=(0.25, 0.45, 1.0), emit_k=40, trans=1.0))
    # ingots and a ladle on the bench
    lead = mat('leadbar', (0.32, 0.33, 0.35), 0.45, 1.0, noise=0.2)
    for i in range(3): box((0.09, 0.022, 0.016), (0.17 + i * 0.004, -0.06 + i * 0.03, 0.008 + i * 0.0), lead, bevel=0.003, rot=(0, 0, 0.15))
    lad = cyl(0.022, 0.016, (-0.17, -0.05, 0.008), iron, bevel=0.002)
    cyl(0.004, 0.16, (-0.24, -0.05, 0.012), mat('wood2', (0.25, 0.14, 0.07), 0.6), rot=(0, math.radians(90), 0), bevel=0.001)
    worklight(3.0, (0, 0, 0.2))
    persp_cam((0.0, -0.30, 0.60), (0.03, 0.0, 0.16), 38, PX, PY)
    bpy.context.view_layer.update()
    # where the pot's mouth is on screen (the page draws the molten lead there)
    top = Z0 + 0.053; r = 0.0535
    rim = [project((math.cos(a) * r, math.sin(a) * r, top)) for a in [i * math.pi / 18 for i in range(36)]]
    xs = [p[0] for p in rim]; ys = [p[1] for p in rim]
    json.dump({'lead': [round(min(xs)), round(min(ys)), round(max(xs) - min(xs)), round(max(ys) - min(ys))]}, open('out/melt_bg.json', 'w'))
    render('out/melt_bg.png')

# ------------------------------------------------------------- cartridges
def case_mesh(loaded=True):
    """a 9 mm case (and bullet), along +Z, base at z=0"""
    brass = mat('brass', (0.85, 0.62, 0.3), 0.22, 1.0, noise=0.06)
    prof = [(0.0, 0.0), (0.0048, 0.0), (0.00495, 0.0006), (0.00495, 0.0012), (0.0042, 0.0016), (0.0042, 0.0021), (0.00495, 0.0026), (0.0048, 0.019), (0.00452, 0.0192), (0.0, 0.0192)]
    objs = []
    bm = bmesh.new(); segs = 64; rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in prof])
    for i in range(segs):
        A, B = rings[i], rings[(i + 1) % segs]
        for j in range(len(prof) - 1): bm.faces.new((A[j], A[j + 1], B[j + 1], B[j]))
    me = bpy.data.meshes.new('case'); bm.to_mesh(me); o = bpy.data.objects.new('case', me); bpy.context.scene.collection.objects.link(o)
    assign(o, brass); smooth(o, 0, 0, 0, 50); objs.append(o)
    cyl(0.0022, 0.0004, (0, 0, -0.0001), mat('primer', (0.75, 0.75, 0.76), 0.3, 1.0))  # primer (seen from the base)
    if loaded:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.00452, location=(0, 0, 0.0192 + 0.0025), segments=48, ring_count=24); b = bpy.context.object
        b.scale = (1, 1, 1.55); bpy.ops.object.transform_apply(scale=True)
        boolean(b, box((0.02, 0.02, 0.02), (0, 0, 0.0192 - 0.01)), 'DIFFERENCE')
        cyl(0.00452, 0.0026, (0, 0, 0.0192 + 0.0013), mat('cu', (0.82, 0.42, 0.25), 0.25, 1.0))
        assign(b, mat('cu2', (0.82, 0.42, 0.25), 0.25, 1.0)); smooth(b); objs.append(b)
    return [o for o in bpy.data.objects if o.type == 'MESH']

def headstamp():
    """the cartridge seen from its base (as it sits in the box, nose down)"""
    reset('autoshop_01', 0.05, rot=1.0, transparent=True)
    objs = case_mesh(True)
    g = bpy.data.objects.new('g', None); bpy.context.scene.collection.objects.link(g)
    for o in objs: o.parent = g
    g.rotation_euler = (math.pi, 0, 0); bpy.context.view_layer.update()
    bpy.ops.object.text_add(location=(0, 0, 0.0001), rotation=(0, 0, 0)); t = bpy.context.object
    t.data.body = 'EXT  9mm  LUGER'; t.data.size = 0.0011; t.data.align_x = 'CENTER'; t.data.extrude = 0.00004
    assign(t, mat('hs', (0.6, 0.42, 0.18), 0.4, 1.0))
    cu = bpy.data.curves['Text'] if 'Text' in bpy.data.curves else t.data
    t.location = (0, -0.0034, 0.00005)
    worklight(3.0)
    sprite(objs + [t], 'out/round_top.png', PPM * 1.6)

def side_case(loaded):
    reset('autoshop_01', 0.05, rot=1.0, transparent=True)
    objs = case_mesh(loaded)
    g = bpy.data.objects.new('g', None); bpy.context.scene.collection.objects.link(g)
    for o in objs: o.parent = g
    g.rotation_euler = (math.radians(-90), 0, 0); bpy.context.view_layer.update()   # lying with the nose to +Y: from above it reads as standing
    worklight(3.0)
    cam_objs = objs
    sprite(cam_objs, f'out/{"round_side" if loaded else "case_side"}.png', PPM * 2.2)

# ------------------------------------------------------------- the 20-round box
BOX = [(-0.072 + c * 0.036, 0.045 - r * 0.030) for r in range(4) for c in range(5)]
def box_bg():
    reset('autoshop_01', 0.05, rot=1.0)
    bench()
    pl = mat('mtm', (0.018, 0.03, 0.018), 0.5, 0.0, noise=0.08, spec=0.35)
    lid = box((0.21, 0.145, 0.032), (0, 0.0, 0.016), pl, bevel=0.0)
    for x, y in BOX: boolean(lid, cyl(0.0058, 0.03, (x, y, 0.03), verts=48))
    for p in lid.data.polygons: p.use_smooth = False
    # the rounded lip around the top (a separate frame so the holes stay crisp)
    fr = box((0.214, 0.149, 0.006), (0, 0, 0.031), pl, bevel=0.0025); boolean(fr, box((0.2, 0.135, 0.02), (0, 0, 0.031)))
    # the lid hinged open behind, a few loose rounds and a bag of cases
    box((0.21, 0.145, 0.006), (0, 0.15, 0.003), pl, bevel=0.003)
    bpy.ops.object.text_add(location=(0, 0.15, 0.0062)); t = bpy.context.object
    t.data.body = 'CASE-GARD  9MM  20'; t.data.size = 0.012; t.data.align_x = 'CENTER'; t.data.extrude = 0.0003; assign(t, pl)
    worklight(3.0)
    top_cam(W, H, PX, PY, height=1.0, center=(0, 0.03))
    render('out/box_bg.png')
    json.dump({'cells': [[round(PX / 2 + x * PPM), round(PY / 2 - (y - 0.03) * PPM)] for x, y in BOX]}, open('out/box_bg.json', 'w'))

# ------------------------------------------------------------- the press, seen from the front (y is up)
RAIL_Y = -0.045         # top of the rail the cases stand on
def press_scene(part):
    reset('autoshop_01', 0.05, rot=1.0, transparent=(part != 'bg'))
    peg = mat('peg', (0.22, 0.15, 0.09), 0.8, spec=0.3)
    nt = peg.node_tree; tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = bpy.data.images.load('/home/claude/mgstudio/tex/perf.png'); tx.image.colorspace_settings.name = 'Non-Color'
    tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (1.4, 1.4, 1.4)
    nt.links.new(tc.outputs['Object'], mp.inputs[0]); nt.links.new(mp.outputs[0], tx.inputs[0])
    vm = nt.nodes.new('ShaderNodeVectorMath'); vm.operation = 'MULTIPLY'; vm.inputs[1].default_value = (0.22, 0.15, 0.09)
    nt.links.new(tx.outputs[0], vm.inputs[0]); nt.links.new(vm.outputs[0], P(peg).inputs['Base Color'])
    wall = plane(2, 2, (0, 0, -0.08), peg)
    benchtop = box((1.2, 0.06, 0.12), (0, -0.115, -0.02), pbr('woodb', 'wood_table_worn', 1.6, tint=(0.55, 0.5, 0.46)), bevel=0.003)
    red = mat('red', (0.28, 0.02, 0.015), 0.4, 0.2, coat=0.4, noise=0.1)
    steel = mat('steel', (0.55, 0.55, 0.57), 0.3, 1.0, noise=0.1)
    dark = mat('dark', (0.05, 0.05, 0.055), 0.45, 0.8)
    # the C-frame: base on the bench, the column at the back (left), the head over the rail
    base = box((0.16, 0.022, 0.06), (-0.06, RAIL_Y - 0.023, 0), red, bevel=0.004)
    col = box((0.04, 0.17, 0.05), (-0.115, 0.02, 0), red, bevel=0.006)
    head = box((0.17, 0.045, 0.05), (-0.04, 0.11, 0), red, bevel=0.006)
    # the rail along the front
    rail = box((1.0, 0.012, 0.03), (0, RAIL_Y - 0.006, 0.02), steel, bevel=0.0015)
    box((1.0, 0.004, 0.032), (0, RAIL_Y - 0.014, 0.02), dark, bevel=0.0008)
    # the handle (lever) out to the right side, resting up
    lev = cyl(0.006, 0.2, (0.06, 0.12, 0.03), steel, rot=(0, math.radians(90), math.radians(28)), bevel=0.001)
    knob = bpy.ops.mesh.primitive_uv_sphere_add(radius=0.014, location=(0.148, 0.166, 0.03)); assign(bpy.context.object, mat('knob', (0.02, 0.02, 0.02), 0.35, coat=0.5))
    # the moving part: the die (threaded steel, knurled lock ring) and the ram rod above
    die = cyl(0.011, 0.06, (0.0, 0.055, 0.02), steel, bevel=0.001, rot=(math.radians(90), 0, 0))
    ring = cyl(0.017, 0.012, (0.0, 0.085, 0.02), dark, bevel=0.001, rot=(math.radians(90), 0, 0))
    for k in range(10):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.0112, minor_radius=0.0006, location=(0, 0.028 + k * 0.0042, 0.02), rotation=(math.radians(90), 0, 0)); assign(bpy.context.object, steel)
    threads = [o for o in bpy.data.objects if o.name.startswith('Torus')]
    moving = [die, ring] + threads
    worklight(3.0)
    allo = list(bpy.data.objects)
    top_cam(W, H, PX, PY, height=1.0, center=(0, 0.025))
    if part == 'bg':
        hide(moving); render('out/press_bg.png'); hide(moving, False)
        json.dump({'rail': round(PY / 2 - (RAIL_Y - 0.025) * PPM), 'x': round(PX / 2)}, open('out/press_bg.json', 'w'))
    else:
        layer('out/press_die.png', moving, allo)

JOBS = {'melt_bg': lambda: melt_scene('bg'), 'round_top': headstamp, 'round_side': lambda: side_case(True), 'case_side': lambda: side_case(False), 'box_bg': box_bg, 'press_bg': lambda: press_scene('bg'), 'press_die': lambda: press_scene('die')}
JOBS[sys.argv[-1]]()
