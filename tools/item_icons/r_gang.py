import bpy, math, random
from mathutils import Vector
import studio as S, kit as K
R = {}
def item(f): R[f.__name__] = f; return f
rad = math.radians

@item
def chop_tools():
    # a canvas tool roll with a crowbar and wrenches lying on it
    canvas = K.mat('canvas', (0.32, 0.26, 0.17), rough=0.95, bump=0.5, bump_scale=500)
    roll = K.box((1.1, 0.7, 0.02), (0, 0, 0.01), canvas, bevel=0.01)
    rolled = K.cyl(0.08, 0.7, (0.55, 0, 0.08), canvas, rot=(rad(90), 0, 0))
    objs = [roll, rolled]
    for mid, sz, loc, rz in (('crowbar_01', 1.0, (-0.05, -0.12, 0.03), 8), ('adjustable_wrench', 0.6, (-0.1, 0.18, 0.03), -12), ('combination_wrench', 0.55, (0.15, 0.05, 0.03), 20)):
        o = S.imp(mid); root = S.normalize(o, sz); bpy.context.view_layer.update()
        lo, hi = S.bounds(o); dz, dx, dy = hi.z - lo.z, hi.x - lo.x, hi.y - lo.y
        # lay it flat on the cloth (the scans stand up)
        root.rotation_euler = (rad(90) if dz >= max(dx, dy) * 0.9 and dy <= dx else 0, rad(90) if dz >= max(dx, dy) * 0.9 and dy > dx else 0, 0)
        bpy.context.view_layer.update()
        root.rotation_euler.z = rad(rz); bpy.context.view_layer.update()
        lo, hi = S.bounds(o); root.location += Vector((loc[0], loc[1], 0.02 - lo.z + 0.0)); bpy.context.view_layer.update()
        objs += o
    return objs, {'el': 48}

@item
def c4():
    putty = K.mat('putty', (0.86, 0.83, 0.74), rough=0.7, bump=0.4, bump_scale=300)
    wrapm = K.mat('wrapc4', (0.25, 0.27, 0.18), rough=0.6)
    objs = []
    for i, x in enumerate((-0.2, 0.0, 0.2)):
        objs.append(K.box((0.18, 0.5, 0.12), (x, 0, 0.06), putty, bevel=0.015))
    for y in (-0.15, 0.15):
        objs.append(K.box((0.64, 0.05, 0.135), (0, y, 0.065), K.mat('tapec4', (0.12, 0.12, 0.12), rough=0.35, coat=0.3), bevel=0.005))
    det = K.box((0.16, 0.12, 0.06), (0.0, 0.02, 0.15), K.mat('det', (0.05, 0.05, 0.05), rough=0.4), bevel=0.01)
    led = K.sphere(0.012, (0.05, -0.03, 0.185), K.mat('ledc4', (1, 0.05, 0.05), emit=(1, 0.05, 0.05), emit_k=10))
    objs += [det, led]
    for i, c in enumerate(((0.8, 0.05, 0.05), (0.1, 0.2, 0.9), (0.9, 0.8, 0.1))):
        w = K.torus(0.12 + i * 0.02, 0.008, (-0.12, 0.05 + i * 0.03, 0.15), K.mat('wire', c, rough=0.4), rot=(rad(75), 0, rad(20 * i)))
        objs.append(w)
    def dr(d, im):
        K.center_text(d, 600, 10, 'C-4', K.font(120, K.FONT_C), (30, 30, 30, 255)); K.center_text(d, 600, 150, 'DEMOLITION CHARGE', K.font(44, K.FONT_B), (30, 30, 30, 255))
    objs.append(K.sticker(K.label_img('c4', 600, 220, (0, 0, 0, 0), dr), 0.34, 0.12, (0.2, -0.05, 0.1205), (0, 0, rad(90))))
    return objs, {'el': 42}

FACE = 43
@item
def wash_supplies():
    # a laundry detergent jug with a stack of paper money bands next to it
    jug_m = K.plastic((0.01, 0.12, 0.55), 0.25)
    prof = [(0, 0), (0.24, 0), (0.27, 0.03), (0.27, 0.62), (0.22, 0.72), (0.12, 0.78), (0.1, 0.84), (0, 0.84)]
    jug = K.lathe(prof, jug_m)
    cap = K.lathe([(0, 0.83), (0.105, 0.83), (0.105, 0.93), (0.09, 0.95), (0, 0.95)], K.plastic((0.95, 0.45, 0.05), 0.35))
    handle = K.torus(0.1, 0.03, (0.2, 0, 0.6), jug_m, rot=(rad(90), 0, 0))
    def dr(d, im):
        d.rectangle((0, 0, 1200, 420), fill=(250, 250, 250, 255))
        d.rectangle((0, 0, 1200, 70), fill=(255, 120, 10, 255))
        K.center_text(d, 1200, 95, 'WASH', K.font(135, K.FONT_C), (10, 60, 170, 255))
        K.center_text(d, 1200, 290, 'DEEP CLEAN', K.font(48, K.FONT_B), (40, 40, 40, 255))
    lab = K.wrap(K.label_img('washlab', 1200, 420, (0, 0, 0, 0), dr), 0.2715, 0.34, 0.33, rough=0.3, coat=0.4, face=FACE)
    objs = [jug, cap, handle, lab]
    # a stack of banded cash next to it
    note_m = K.mat('notes', (0.45, 0.6, 0.4), rough=0.8, bump=0.2, bump_scale=400)
    band_m = K.mat('band', (0.93, 0.86, 0.62), rough=0.7)
    for i in range(3):
        z = 0.035 + i * 0.072
        objs.append(K.box((0.36, 0.17, 0.07), (0.5, -0.2, z), note_m, bevel=0.004, rot=(0, 0, rad(-8 + i * 6))))
        objs.append(K.box((0.07, 0.175, 0.074), (0.5, -0.2, z), band_m, bevel=0.002, rot=(0, 0, rad(-8 + i * 6))))
    return objs, {'el': 22}

@item
def spray_can():
    # a spray paint can with a red cap and a little paint on the floor
    body_m = K.mat('can_body', (0.06, 0.06, 0.07), rough=0.25, metal=0.6, coat=0.5)
    prof = [(0, 0), (0.15, 0), (0.16, 0.015), (0.16, 0.6), (0.145, 0.66), (0.1, 0.7), (0.05, 0.72), (0, 0.72)]
    can = K.lathe(prof, body_m)
    rim = K.lathe([(0.0, 0.69), (0.065, 0.69), (0.065, 0.73), (0.0, 0.73)], K.steel())
    cap = K.lathe([(0, 0.72), (0.04, 0.72), (0.04, 0.8), (0, 0.8)], K.plastic((0.85, 0.06, 0.05), 0.3))
    nozzle = K.box((0.03, 0.03, 0.025), (0.035, 0.0, 0.79), K.plastic((0.9, 0.9, 0.9), 0.4))
    def dr(d, im):
        d.rectangle((0, 0, 1200, 360), fill=(230, 40, 40, 255))
        for i, c in enumerate([(255, 200, 0, 255), (30, 140, 255, 255), (40, 200, 90, 255)]):
            d.ellipse((160 + i * 330, 40, 420 + i * 330, 300), fill=c)
        K.center_text(d, 1200, 110, 'SPRAY', K.font(130, K.FONT_C), (255, 255, 255, 255))
    lab = K.wrap(K.label_img('spraylab', 1200, 360, (0, 0, 0, 0), dr), 0.1615, 0.3, 0.32, rough=0.3, coat=0.5, face=43)
    splat = K.cyl(0.13, 0.002, (0.25, -0.12, 0.001), K.mat('splat', (0.85, 0.06, 0.05), rough=0.2, coat=0.6))
    return [can, rim, cap, nozzle, lab, splat], {'el': 22}

@item
def scrub_brush():
    # a wooden scrub brush with stiff bristles and a soapy sponge
    wood = K.mat('wood_b', (0.55, 0.36, 0.2), rough=0.6, bump=0.3, bump_scale=200)
    base = K.box((0.5, 0.2, 0.07), (0, 0, 0.12), wood, bevel=0.03)
    handle = K.box((0.34, 0.08, 0.06), (-0.02, 0, 0.2), wood, bevel=0.025)
    objs = [base, handle]
    br = K.mat('bristle', (0.92, 0.85, 0.6), rough=0.8)
    for ix in range(9):
        for iy in range(3):
            objs.append(K.cyl(0.012, 0.09, (-0.21 + ix * 0.052, -0.06 + iy * 0.06, 0.045), br, verts=12))
    sponge = K.box((0.26, 0.16, 0.09), (0.34, -0.2, 0.045), K.mat('sponge', (0.95, 0.85, 0.1), rough=0.95, bump=0.6, bump_scale=600), bevel=0.02)
    return objs + [sponge], {'el': 30}

@item
def ammo_materials():
    # lead ingots and a tray of empty brass casings
    lead = K.mat('lead', (0.42, 0.43, 0.46), rough=0.45, metal=1, noise_rough=0.1)
    objs = []
    for i, (x, y, z) in enumerate(((-0.28, 0.0, 0.05), (-0.28, 0.2, 0.05), (-0.28, 0.1, 0.15))):
        objs.append(K.box((0.34, 0.16, 0.1), (x, y, z), lead, bevel=0.02))
    brass = K.mat('brassc', (0.85, 0.62, 0.25), rough=0.25, metal=1)
    tray = K.box((0.42, 0.34, 0.04), (0.18, -0.05, 0.02), K.mat('trayg', (0.16, 0.2, 0.12), rough=0.6), bevel=0.01)
    objs.append(tray)
    for ix in range(5):
        for iy in range(4):
            objs.append(K.cyl(0.026, 0.12, (0.03 + ix * 0.075, -0.16 + iy * 0.075, 0.1), brass, verts=24))
    return objs, {'el': 40}

@item
def gun_parts():
    # a slide, a barrel, a spring and a few pins on a rag
    rag = K.mat('rag', (0.28, 0.3, 0.26), rough=0.95, bump=0.4, bump_scale=500)
    objs = [K.box((0.72, 0.5, 0.01), (0.03, 0, 0.005), rag, bevel=0.005)]
    dark = K.dark_steel()
    slide = K.box((0.55, 0.11, 0.09), (-0.05, 0.15, 0.055), dark, bevel=0.012)
    for i in range(7):
        objs.append(K.box((0.012, 0.115, 0.05), (0.08 + i * 0.022, 0.15, 0.08), K.mat('serr', (0.08, 0.08, 0.09), rough=0.4, metal=1)))
    barrel = K.cyl(0.03, 0.42, (-0.02, -0.05, 0.035), K.steel(), rot=(0, rad(90), rad(6)))
    spring = K.torus(0.025, 0.006, (0.3, -0.18, 0.03), K.steel(), rot=(0, rad(90), 0))
    objs += [slide, barrel, spring]
    for i in range(6):
        objs.append(K.torus(0.025, 0.006, (0.24 + i * 0.022, -0.18, 0.03), K.steel(), rot=(0, rad(90), 0)))
    for i in range(3):
        objs.append(K.cyl(0.008, 0.1, (0.3 + i * 0.04, 0.05, 0.012), K.chrome(), rot=(0, rad(90), rad(30))))
    return objs, {'el': 45}

@item
def weed_bud():
    import r_misc as Mi
    random.seed(5); out = []
    for i, (x, y) in enumerate(((0, 0), (0.15, 0.06), (-0.14, 0.07), (0.03, -0.13))):
        out += Mi._bud((x, y, 0.0), 0.9 if i == 0 else 0.7, ((0.02, 0.07, 0.01), (0.1, 0.24, 0.03)), i)
    return out, {'el': 35}
