# bolts: an engine-bay steel bracket seen from above, 4 flange bolts (the bolts are separate sprites)
import sys, json; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
W, H = 0.40, 0.23          # metres in view
PX, PY = 1200, 690         # shown at 800 x 460 (1.5x for sharpness)
PPM = PX / W
HOLES = [(-0.104, 0.050), (-0.104, -0.050), (0.104, 0.050), (0.104, -0.050)]

def lamps():
    light('AREA', (-0.55, 0.4, 0.38), 40, 0.3, (0, 0, 0), (1.0, 0.9, 0.78))
    light('AREA', (0.6, -0.3, 0.6), 5, 1.0, (0, 0, 0), (0.8, 0.88, 1.0))

def scene_bg():
    reset('autoshop_01', 0.15, rot=1.2)
    plane(1.2, 1.2, (0, 0, -0.012), pbr('conc', 'concrete_floor_worn_001', 1.6, tint=(0.36, 0.35, 0.34)))
    pm = pbr('plate', 'green_metal_rust', 2.4, tint=(0.3, 0.3, 0.32), sat=0.1, metal=0.3, nor=1.6)
    plate = box((0.33, 0.19, 0.008), (0, 0, -0.004), pm, bevel=0.003)
    for x, y in HOLES:
        boolean(plate, cyl(0.0062, 0.03, (x, y, 0), verts=48))
        w = cyl(0.0125, 0.0016, (x, y, 0.0008), mat('washer', (0.13, 0.125, 0.12), 0.5, 0.85, noise=0.18), bevel=0.0004)
        boolean(w, cyl(0.0064, 0.005, (x, y, 0.0008), verts=48))
        # the threaded hole you see once the bolt is out
        cyl(0.0055, 0.0004, (x, y, -0.006), mat('dark', (0.01, 0.01, 0.01), 0.9))
    bpy.ops.object.text_add(location=(0.0, -0.075, 0.0002)); t = bpy.context.object
    t.data.body = '7L0 199 207 A'; t.data.size = 0.008; t.data.align_x = 'CENTER'; t.data.extrude = 0.00025
    assign(t, pm)
    # the ratchet left on the floor, a socket and a loose washer: it's a workshop
    root, objs = imp('ratchet_wrench'); root.rotation_euler = (math.radians(90), 0, math.radians(-25)); root.location = (0.172, -0.118, -0.012 + 0.0217)
    sock = cyl(0.0105, 0.026, (-0.175, 0.094, 0.001), mat('chrome', (0.85, 0.85, 0.87), 0.12, 1.0), rot=(math.radians(90), 0, math.radians(30)), bevel=0.0008)
    lw = cyl(0.0125, 0.0016, (-0.183, -0.103, -0.011), mat('w2', (0.14, 0.135, 0.13), 0.5, 0.85, noise=0.15), bevel=0.0004)
    boolean(lw, cyl(0.0064, 0.005, (-0.183, -0.103, -0.011), verts=48))
    lamps()
    top_cam(W, H, PX, PY)
    render('out/bolts_bg.png')

def bolt_sprite():
    reset('autoshop_01', 0.15, rot=1.2, transparent=True)
    zinc = mat('zinc', (0.82, 0.76, 0.6), 0.24, 1.0, noise=0.08)
    a = cyl(0.0122, 0.0016, (0, 0, 0.0008), zinc, bevel=0.0005)
    b = hexprism(0.0092, 0.0068, (0, 0, 0.0016 + 0.0034), zinc)
    for i, ang in enumerate((0.3, 2.39, 4.49)):
        box((0.0032, 0.0006, 0.0005), (math.cos(ang) * 0.0040, math.sin(ang) * 0.0040, 0.0084), mat('mark', (0.25, 0.24, 0.2), 0.6, 1.0), rot=(0, 0, ang))
    lamps()
    sprite([a, b], 'out/bolt.png', PPM, anchor=(0, 0))

def ratchet_sprite():
    reset('autoshop_01', 0.15, rot=1.2, transparent=True)
    root, objs = imp('ratchet_wrench')
    root.rotation_euler = (0, math.radians(90), 0)     # handle flat, the drive points down into the bolt
    bpy.context.view_layer.update()
    dx, dy, dz = lowest_xy(objs)
    root.location = (-dx, -dy, -dz + 0.012)            # drive centre over (0, 0), lifted onto a bolt head
    lamps()
    sprite(objs, 'out/ratchet.png', PPM, anchor=(0, 0))

{'bg': scene_bg, 'bolt': bolt_sprite, 'ratchet': ratchet_sprite}[sys.argv[-1]]()
