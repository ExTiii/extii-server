# lug nuts: a rusty steel wheel seen straight on, 5 chrome lug nuts (separate sprites)
import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
W, H = 0.40, 0.23
PX, PY = 1200, 690
PPM = PX / W
STUDS = [(-0.0329, 0.0452), (0.0324, 0.0452), (0.0526, -0.0169), (-0.0003, -0.0553), (-0.0531, -0.0169)]

def lamps():
    light('AREA', (-0.5, 0.45, 0.55), 70, 0.4, (0, 0, 0), (1.0, 0.9, 0.78))
    light('AREA', (0.6, -0.4, 0.6), 8, 1.0, (0, 0, 0), (0.8, 0.88, 1.0))

def face_z(objs):
    bpy.context.view_layer.update()
    zs = [ (o.matrix_world @ v.co).z for o in meshes(objs) for v in o.data.vertices
           if 0.035 < math.hypot(*(o.matrix_world @ v.co).xy) < 0.075 ]
    return max(zs)

def scene_bg():
    reset('autoshop_01', 0.15, rot=2.2)
    root, objs = imp('rusted_wheel_rim_01'); root.rotation_euler = (math.radians(90), 0, 0)
    fz = face_z(objs)
    # behind the wheel: the rusty brake disc, the hub, the dark wheel well
    plane(1.5, 1.5, (0, 0, fz - 0.16), mat('well', (0.012, 0.012, 0.012), 0.8))
    disc = cyl(0.135, 0.022, (0, 0, fz - 0.05), pbr('disc', 'rust_coarse_01', 6.0, tint=(0.75, 0.7, 0.68), metal=0.6), bevel=0.001)
    cyl(0.045, 0.03, (0, 0, fz - 0.02), pbr('hubm', 'rust_coarse_01', 9.0, tint=(0.35, 0.33, 0.32), metal=0.5), bevel=0.002)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.024, location=(0, 0, fz - 0.012)); cap = bpy.context.object
    cap.scale = (1, 1, 0.45); assign(cap, mat('cap', (0.07, 0.068, 0.065), 0.62, 0.9, noise=0.2)); smooth(cap)
    # the wheel studs (you see them once a nut is off)
    stud = mat('stud', (0.55, 0.52, 0.45), 0.35, 1.0, noise=0.2)
    for x, y in STUDS:
        cyl(0.0060, 0.024, (x, y, fz + 0.006), stud, bevel=0.0006)
        for k in range(5):  # thread ridges
            bpy.ops.mesh.primitive_torus_add(major_radius=0.0060, minor_radius=0.0006, location=(x, y, fz + 0.002 + k * 0.0022))
            assign(bpy.context.object, stud)
    lamps()
    top_cam(W, H, PX, PY, height=fz + 1.0)
    render('out/lugs_bg.png')

def nut_sprite():
    reset('autoshop_01', 0.15, rot=2.2, transparent=True)
    chrome = mat('chrome', (0.78, 0.78, 0.8), 0.2, 1.0, noise=0.06)
    n = hexprism(0.0110, 0.016, (0, 0, 0.008), chrome)
    # open-ended nut: the stud's end shows through
    boolean(n, cyl(0.0062, 0.05, (0, 0, 0.008), verts=64))
    s = cyl(0.0058, 0.016, (0, 0, 0.007), mat('stud', (0.55, 0.52, 0.45), 0.35, 1.0, noise=0.2), bevel=0.0006)
    lamps()
    sprite([n, s], 'out/lugnut.png', PPM, anchor=(0, 0))

{'bg': scene_bg, 'nut': nut_sprite}[sys.argv[-1]]()
