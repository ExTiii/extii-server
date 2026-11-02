# money wash: the sorting table (4 trays), single notes, the counting table, the washer porthole
import sys, json; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
W, H = 0.40, 0.23
PX, PY = 1200, 690
PPM = PX / W

def lamps(k=1.0):
    worklight(k * 1.7)

def table():
    return plane(1.6, 1.6, (0, 0, -0.002), pbr('wood', 'wood_table_worn', 2.0, tint=(0.8, 0.75, 0.7)))

TRAYS = [(-0.135, -0.075), (-0.045, -0.075), (0.045, -0.075), (0.135, -0.075)]   # trays $100 .. $10 (left to right in RTL order handled by the page)
def sort_bg():
    reset('autoshop_01', 0.06, rot=0.4)
    table()
    blk = mat('tray', (0.012, 0.012, 0.013), 0.55, 0.0, noise=0.1, spec=0.25)
    # a cash drawer insert: one black moulded tray, 4 bill wells
    t = box((0.37, 0.085, 0.022), (0, -0.075, 0.011), blk, bevel=0.004)
    for x, y in TRAYS:
        boolean(t, box((0.082, 0.07, 0.03), (x, y, 0.024), bevel=0.006))
    # a loose pile of notes waiting top-left, a rubber band, a pen
    import random; random.seed(3)
    for i in range(14):
        note(random.choice([10, 20, 50, 100]), (-0.13 + random.uniform(-0.02, 0.02), 0.07 + random.uniform(-0.015, 0.015), 0.001 + i * 0.0016), random.uniform(-0.5, 0.5), curl=random.uniform(0.2, 0.6))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.016, minor_radius=0.0012, location=(0.16, 0.07, 0.0012)); assign(bpy.context.object, mat('band', (0.55, 0.18, 0.08), 0.6))
    pen = cyl(0.0045, 0.14, (0.14, 0.02, 0.0045), mat('pen', (0.05, 0.08, 0.25), 0.35, coat=0.6), rot=(0, math.radians(90), math.radians(28)), bevel=0.001)
    lamps(0.65)
    top_cam(W, H, PX, PY)
    render('out/sort_bg.png')
    json.dump({'trays': [[round(PX / 2 + x * PPM), round(PY / 2 - y * PPM)] for x, y in TRAYS]}, open('out/sort_bg.json', 'w'))

def note_sprites():
    for v in (10, 20, 50, 100):
        reset('autoshop_01', 0.06, rot=0.4, transparent=True)
        o = note(v, (0, 0, 0.002), 0, curl=0.6)
        lamps(0.65)
        sprite([o], f'out/note_{v}.png', PPM * 0.9)

def count_bg():
    """the counting table: a digital counter (top-down) on the right, the stack goes in the middle"""
    reset('autoshop_01', 0.06, rot=0.4)
    table()
    body = box((0.11, 0.15, 0.05), (0.125, 0.0, 0.025), mat('ctr', (0.028, 0.029, 0.031), 0.5, 0.0, coat=0.15, noise=0.08, spec=0.35), bevel=0.006)
    lcd = box((0.078, 0.034, 0.003), (0.125, 0.038, 0.0505), mat('lcdw', (0.006, 0.012, 0.008), 0.12, 0.0, coat=1.0), bevel=0.0012)
    for i, (x, c) in enumerate(((0.100, (0.03, 0.22, 0.06)), (0.125, (0.35, 0.03, 0.02)), (0.150, (0.2, 0.2, 0.21)))):
        cyl(0.008, 0.004, (x, -0.025, 0.051), mat(f'btn{i}', c, 0.55, coat=0.1, spec=0.3), bevel=0.0012)
    bpy.ops.object.text_add(location=(0.125, 0.065, 0.0502)); tx = bpy.context.object
    tx.data.body = 'CASH COUNTER  MC-300'; tx.data.size = 0.0055; tx.data.align_x = 'CENTER'; tx.data.extrude = 0.0001
    assign(tx, mat('lbl', (0.6, 0.6, 0.6), 0.5))
    # finished, banded stacks waiting left
    lamps()
    top_cam(W, H, PX, PY)
    render('out/count_bg.png')
    json.dump({'lcd': [round(PX / 2 + (0.125 - 0.039) * PPM), round(PY / 2 - (0.038 + 0.017) * PPM), round(0.078 * PPM), round(0.034 * PPM)]}, open('out/count_bg.json', 'w'))

def strap_sprite():
    """a $ band (paper strap) around a stack: the finished stack"""
    reset('autoshop_01', 0.06, rot=0.4, transparent=True)
    objs = []
    import random; random.seed(9)
    for i in range(10):
        o = note(100, (random.uniform(-0.001, 0.001), random.uniform(-0.001, 0.001), i * 0.0011), random.uniform(-0.02, 0.02), curl=0.2); objs.append(o)
    s = box((0.03, 0.0675, 0.0128), (0, 0, 0.0055), mat('strap', (0.62, 0.42, 0.16), 0.55)); objs.append(s)
    lamps()
    sprite(objs, 'out/stack_band.png', PPM * 0.9)

JOBS = {'sort': sort_bg, 'notes': note_sprites, 'count': count_bg, 'strap': strap_sprite}

# ------------------------------------------------------------- the washer (front-loader, seen straight on)
DW, DH = 0.90, 0.5175
DPX = 1200 / DW
DOOR = (-0.10, -0.035)     # porthole centre
def washer_scene(part):
    reset('autoshop_01', 0.07, rot=0.4, transparent=(part != 'bg'))
    s = bpy.context.scene; s.cycles.film_transparent_glass = True
    enamel = mat('enamel', (0.62, 0.62, 0.6), 0.3, 0.0, coat=0.5, noise=0.06, spec=0.5)
    front = box((0.60, 0.62, 0.02), (0, 0, -0.01), enamel, bevel=0.012)
    plane(3, 3, (0, 0, -0.3), pbr('tile', 'concrete_floor_worn_001', 1.0, tint=(0.25, 0.25, 0.25)))
    boolean(front, cyl(0.175, 0.1, (DOOR[0], DOOR[1], 0), verts=128))
    # control strip: a programme knob, a small display, two buttons
    strip = box((0.58, 0.07, 0.006), (0, 0.21, 0.003), mat('strip', (0.86, 0.86, 0.85), 0.35, coat=0.3), bevel=0.003)
    knob = cyl(0.026, 0.02, (0.17, 0.21, 0.012), mat('knob', (0.7, 0.71, 0.73), 0.2, 1.0, noise=0.05), bevel=0.004)
    cyl(0.003, 0.0204, (0.17, 0.228, 0.012), mat('kmark', (0.1, 0.1, 0.1), 0.5))
    disp = box((0.07, 0.026, 0.002), (0.05, 0.21, 0.006), mat('disp', (0.02, 0.025, 0.03), 0.1, coat=1.0), bevel=0.001)
    for i, x in enumerate((-0.04, -0.075)):
        cyl(0.009, 0.006, (x, 0.21, 0.007), mat(f'b{i}', (0.8, 0.8, 0.8), 0.35, coat=0.3), bevel=0.002)
    bpy.ops.object.text_add(location=(-0.26, 0.205, 0.0062)); t = bpy.context.object
    t.data.body = 'AQUAMAX  1400'; t.data.size = 0.014; t.data.extrude = 0.0002; assign(t, mat('logo', (0.25, 0.27, 0.3), 0.4, 0.6))
    # the drum behind the door: perforated stainless, darker deeper in
    drum = cyl(0.172, 0.24, (DOOR[0], DOOR[1], -0.13), verts=128)
    boolean(drum, cyl(0.165, 0.24, (DOOR[0], DOOR[1], -0.12), verts=128))
    dm = mat('drum', (0.3, 0.3, 0.32), 0.4, 1.0)
    nt = dm.node_tree; tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = bpy.data.images.load('/home/claude/mgstudio/tex/perf.png'); tx.image.colorspace_settings.name = 'Non-Color'
    tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (9, 9, 9)
    nt.links.new(tc.outputs['Object'], mp.inputs[0]); nt.links.new(mp.outputs[0], tx.inputs[0]); tx.projection = 'BOX'
    mix = nt.nodes.new('ShaderNodeVectorMath'); mix.operation = 'MULTIPLY'; mix.inputs[1].default_value = (0.3, 0.3, 0.32)
    nt.links.new(tx.outputs[0], mix.inputs[0]); nt.links.new(mix.outputs[0], P(dm).inputs['Base Color'])
    assign(drum, dm)
    back = cyl(0.17, 0.004, (DOOR[0], DOOR[1], -0.24), dm)
    # the door: a thick grey ring and the domed glass
    ringm = mat('ring', (0.55, 0.56, 0.58), 0.25, 0.6, coat=0.4)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.19, minor_radius=0.028, location=(DOOR[0], DOOR[1], 0.012)); ring = bpy.context.object
    ring.scale = (1, 1, 0.6); bpy.ops.object.transform_apply(scale=True); assign(ring, ringm); smooth(ring)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2, location=(DOOR[0], DOOR[1], -0.12), segments=96, ring_count=48); gl = bpy.context.object
    boolean(gl, box((0.6, 0.6, 0.4), (DOOR[0], DOOR[1], -0.2 - 0.12 + 0.12 - 0.0)))
    glm = mat('glass', (0.92, 0.94, 0.95), 0.03, trans=1.0, ior=1.5)
    assign(gl, glm); smooth(gl)
    hinge = box((0.03, 0.08, 0.02), (DOOR[0] - 0.205, DOOR[1], 0.005), ringm, bevel=0.006)
    worklight(2.2)
    allo = list(bpy.data.objects)
    top_cam(DW, DH, 1200, 690, height=1.0)
    if part == 'bg':
        hide([ring, gl, hinge]); render('out/drum_bg.png')
        json.dump({'door': [round(600 + DOOR[0] * DPX), round(345 - DOOR[1] * DPX), round(0.165 * DPX)]}, open('out/drum_bg.json', 'w'))
    elif part == 'door':
        layer('out/drum_door.png', [ring, gl, hinge], allo)

def drum_load():
    """what tumbles inside: wet clothes and notes, as one disc that the page turns"""
    reset('autoshop_01', 0.07, rot=0.4, transparent=True)
    import random; random.seed(5)
    objs = []
    cols = [(0.08, 0.12, 0.25), (0.25, 0.25, 0.27), (0.4, 0.08, 0.06), (0.6, 0.6, 0.58)]
    for i in range(9):
        a = random.uniform(0, 6.28); r = random.uniform(0.03, 0.12)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=random.uniform(0.04, 0.07), location=(math.cos(a) * r, math.sin(a) * r * 0.4 - 0.07, random.uniform(-0.02, 0.02)))
        o = bpy.context.object; o.scale = (random.uniform(1, 1.8), random.uniform(0.6, 1), 0.5)
        dsp = o.modifiers.new('d', 'DISPLACE'); tx = bpy.data.textures.new(f'c{i}', 'CLOUDS'); tx.noise_scale = 0.03; dsp.texture = tx; dsp.strength = 0.02
        assign(o, mat(f'cloth{i}', random.choice(cols), 0.85, 0.0, noise=0.05, spec=0.2)); smooth(o); objs.append(o)
    for i in range(7):
        a = random.uniform(0, 6.28); r = random.uniform(0.02, 0.13)
        objs.append(note(random.choice([20, 50, 100]), (math.cos(a) * r, math.sin(a) * r, 0.04 + i * 0.002), random.uniform(0, 6.28), curl=1.5, w=0.1, h=0.042))
    worklight(2.2)
    top_cam(0.34, 0.34, round(0.34 * DPX), round(0.34 * DPX), height=1.0)
    render('out/drum_load.png')

if sys.argv[-1] in ('drum_bg', 'drum_door'): washer_scene(sys.argv[-1][5:])
elif sys.argv[-1] == 'load': drum_load()
if sys.argv[-1] in JOBS: JOBS[sys.argv[-1]]()
