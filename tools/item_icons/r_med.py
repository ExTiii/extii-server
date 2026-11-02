import bpy, math, random
from mathutils import Vector
import studio as S, kit as K
R = {}
def item(f): R[f.__name__] = f; return f
rad = math.radians
W = (255, 255, 255, 255); BLK = (25, 25, 28, 255); RED = (200, 25, 35, 255)

def lbl(name, w, h, bg, lines, band=None):
    """lines: [(text, size, colour, font)] centred, top to bottom"""
    def dr(d, im):
        d.rectangle((0, 0, w - 1, h - 1), fill=bg)
        if band: d.rectangle((0, 0, w - 1, int(h * band[0])), fill=band[1])
        y = int(h * 0.08)
        for t, s, c, f in lines:
            K.center_text(d, w, y, t, K.font(s, f), c); y += int(s * 1.25)
    return K.label_img(name, w, h, (0, 0, 0, 0), dr)

def pill_bottle(name, body_c, cap_c, lines, trans=0.6):
    body = K.mat('pb', body_c, rough=0.2, trans=trans, coat=0.3)
    prof = [(0, 0), (0.17, 0), (0.2, 0.02), (0.2, 0.5), (0.18, 0.53), (0.17, 0.55), (0, 0.55)]
    objs = [K.lathe(prof, body)]
    pills = K.mat('pills', (0.95, 0.95, 0.92), rough=0.4)
    objs.append(K.cyl(0.17, 0.3, (0, 0, 0.17), pills))
    objs.append(K.cyl(0.215, 0.13, (0, 0, 0.6), K.mat('cap', cap_c, rough=0.45, bump=0.3, bump_scale=120)))
    objs.append(K.wrap(lbl(name, 1100, 380, W, lines, (0.22, RED)), 0.203, 0.3, 0.27))
    return objs

def iv_bag(name, fluid_c, lines, fluid_trans=0.6):
    film = K.mat('ivfilm', (0.95, 0.97, 1.0), rough=0.08, trans=0.9, ior=1.3)
    bag = K.box((0.55, 0.06, 0.8), (0, 0, 0.5), film, bevel=0.03); K.smooth(bag, sub=2)
    fl = K.box((0.5, 0.045, 0.62), (0, 0, 0.44), K.mat('fluid', fluid_c, rough=0.1, trans=fluid_trans, ior=1.34, sss=0.2), bevel=0.02); K.smooth(fl, sub=2)
    port = K.cyl(0.03, 0.14, (0, 0, 0.04), K.mat('port', (0.95, 0.95, 0.95), rough=0.3))
    tube = K.cyl(0.012, 0.35, (0.12, 0, -0.08), K.mat('tube', (0.9, 0.95, 1.0), rough=0.1, trans=0.7)); tube.rotation_euler = (0, rad(40), 0)
    st = K.sticker(lbl(name, 600, 420, W, lines), 0.34, 0.24, (0, -0.042, 0.55), (rad(90), 0, 0))
    hang = K.box((0.16, 0.02, 0.06), (0, 0, 0.93), film); K.boolean(hang, K.box((0.08, 0.1, 0.03), (0, 0, 0.93)))
    return [bag, fl, port, tube, st, hang]

@item
def blood_bag(): return iv_bag('blood_bag', (0.35, 0.0, 0.01), [('BLOOD', 90, RED, K.FONT_C), ('O NEG', 70, BLK, K.FONT_B), ('450 mL  ·  CPDA-1', 36, BLK, K.FONT_R)], 0.2), {'el': 15}
@item
def saline(): return iv_bag('saline', (0.92, 0.96, 1.0), [('0.9% NaCl', 80, (20, 60, 150, 255), K.FONT_C), ('SALINE', 70, BLK, K.FONT_B), ('1000 mL  IV', 40, BLK, K.FONT_R)], 0.95), {'el': 15}

@item
def ibuprofen(): return pill_bottle('ibuprofen', (0.9, 0.42, 0.05), (0.95, 0.95, 0.95), [('IBUPROFEN', 52, W, K.FONT_C), ('400 mg', 60, BLK, K.FONT_B), ('100 TABLETS', 36, BLK, K.FONT_R)]), {'el': 22}
@item
def painkillers():
    foil = K.mat('foil', (0.85, 0.86, 0.88), rough=0.2, metal=1, bump=0.2, bump_scale=60)
    card = K.box((0.8, 0.45, 0.012), (0, 0, 0.1), foil, bevel=0.004); objs = [card]
    pvc = K.mat('pvc', (0.98, 0.98, 1.0), rough=0.05, trans=0.95, ior=1.4)
    for i in range(5):
        for j in range(2):
            x, y = -0.3 + i * 0.15, -0.09 + j * 0.18
            b = K.sphere(0.055, (x, y, 0.11), pvc, scale=(1, 1, 0.55)); objs.append(b)
            if not (i == 4 and j == 0): objs.append(K.sphere(0.04, (x, y, 0.115), K.mat('tab', (0.95, 0.95, 0.95), rough=0.5), scale=(1, 1, 0.4)))
    card.rotation_euler = (0, 0, 0)
    pk = K.box((0.85, 0.18, 0.5), (0.05, 0.32, 0.25), K.mat('pack', (0.95, 0.95, 0.96), rough=0.4), bevel=0.01)
    st = K.sticker(lbl('painkillers', 900, 520, W, [('PAINKILLERS', 110, RED, K.FONT_C), ('PARACETAMOL 500 mg', 54, BLK, K.FONT_B), ('20 TABLETS', 44, BLK, K.FONT_R)], (0.05, RED)), 0.8, 0.46, (0.05, 0.229, 0.25), (rad(90), 0, 0))
    return objs + [pk, st], {'el': 32}

@item
def morphine():
    glass = K.glass(); objs = []
    prof = [(0, 0), (0.13, 0), (0.14, 0.02), (0.14, 0.42), (0.1, 0.48), (0.07, 0.5), (0.07, 0.55), (0, 0.55)]
    objs.append(K.lathe(prof, glass)); objs.append(K.lathe([(0, 0.01), (0.125, 0.01), (0.125, 0.3), (0, 0.3)], K.liquid((0.97, 0.98, 1.0))))
    objs.append(K.cyl(0.09, 0.08, (0, 0, 0.58), K.mat('al', (0.75, 0.75, 0.78), rough=0.3, metal=1)))
    objs.append(K.cyl(0.075, 0.03, (0, 0, 0.63), K.mat('flip', (0.1, 0.3, 0.8), rough=0.4)))
    objs.append(K.wrap(lbl('morphine', 900, 300, W, [('MORPHINE', 56, BLK, K.FONT_C), ('10 mg/mL', 46, (20, 60, 150, 255), K.FONT_B)], (0.12, (20, 60, 150, 255))), 0.142, 0.22, 0.2))
    syr = K.cyl(0.04, 0.6, (0.3, 0.05, 0.05), K.mat('syr', (0.98, 0.98, 1.0), rough=0.05, trans=0.9)); syr.rotation_euler = (0, rad(90), rad(20))
    plg = K.cyl(0.035, 0.2, (0.62, 0.17, 0.05), K.mat('plg', (0.95, 0.95, 0.95), rough=0.3)); plg.rotation_euler = (0, rad(90), rad(20))
    ndl = K.cyl(0.006, 0.18, (-0.04, -0.07, 0.05), K.chrome()); ndl.rotation_euler = (0, rad(90), rad(20))
    return objs + [syr, plg, ndl], {'el': 25}

@item
def forceps():
    st = K.chrome(); objs = []
    for s in (-1, 1):
        a = K.box((0.9, 0.035, 0.012), (0, s * 0.035, 0.03), st, bevel=0.004); a.rotation_euler = (0, 0, rad(s * 2.5)); objs.append(a)
        objs.append(K.torus(0.07, 0.014, (0.5, s * 0.11, 0.03), st))
    objs.append(K.cyl(0.02, 0.03, (0.05, 0, 0.03), st))
    return objs, {'el': 45}

@item
def gauze():
    o = S.imp('medical_tape'); S.normalize(o, 0.7)
    pad = K.box((0.6, 0.6, 0.04), (0.45, 0.2, 0.02), K.mat('gz', (0.97, 0.97, 0.95), rough=0.95, bump=0.6, bump_scale=600), bevel=0.01)
    return o + [pad], {'el': 32}

@item
def bandage():
    o = S.imp('medical_tape'); S.normalize(o, 1.0)
    from r_mech import tint
    tint(o, (0.95, 0.78, 0.6))
    return o, {'el': 30}

@item
def pressure_bandage():
    pk = K.box((0.75, 0.5, 0.14), (0, 0, 0.07), K.mat('olive', (0.2, 0.24, 0.12), rough=0.35, coat=0.4, bump=0.2, bump_scale=80), bevel=0.05)
    K.smooth(pk, sub=1)
    st = K.sticker(lbl('pbandage', 800, 500, (230, 225, 200, 255), [('EMERGENCY', 90, BLK, K.FONT_C), ('BANDAGE', 90, BLK, K.FONT_C), ('6" PRESSURE', 50, RED, K.FONT_B)]), 0.5, 0.31, (0, 0, 0.142), (0, 0, 0))
    return [pk, st], {'el': 45}

@item
def quickclot():
    pk = K.box((0.55, 0.8, 0.06), (0, 0, 0.03), K.mat('qfoil', (0.75, 0.78, 0.8), rough=0.25, metal=1, bump=0.3, bump_scale=40), bevel=0.02)
    K.smooth(pk, sub=1)
    st = K.sticker(lbl('qclot', 560, 820, (20, 110, 70, 255), [('HEMO', 110, W, K.FONT_C), ('STATIC', 110, W, K.FONT_C), ('GAUZE', 90, (240, 200, 40, 255), K.FONT_C), ('Z-FOLD  3" x 12\'', 40, W, K.FONT_R)]), 0.46, 0.68, (0, 0, 0.062), (0, 0, 0))
    return [pk, st], {'el': 50}

@item
def tourniquet():
    strap = K.mat('strap', (0.03, 0.03, 0.035), rough=0.85, bump=0.4, bump_scale=300)
    loop = K.torus(0.32, 0.06, (0, 0, 0.06), strap); loop.scale = (1, 1, 0.35)
    tail = K.box((0.5, 0.11, 0.02), (0.5, -0.15, 0.02), strap, bevel=0.005); tail.rotation_euler = (0, 0, rad(-20))
    rod = K.cyl(0.03, 0.42, (0, -0.3, 0.13), K.mat('rod', (0.05, 0.05, 0.05), rough=0.4), rot=(0, rad(90), rad(10)))
    tip = K.box((0.1, 0.06, 0.04), (0.38, 0.0, 0.12), K.mat('tip', (0.8, 0.05, 0.05), rough=0.4), bevel=0.01)
    clip = K.box((0.12, 0.12, 0.05), (-0.05, -0.3, 0.08), K.mat('clip', (0.08, 0.08, 0.08), rough=0.5), bevel=0.01)
    return [loop, tail, rod, tip, clip], {'el': 40}

@item
def bvm():
    bagm = K.mat('bvmbag', (0.8, 0.9, 0.85), rough=0.15, trans=0.75, coat=0.3)
    bag = K.sphere(0.25, (-0.25, 0, 0.25), bagm, scale=(1.6, 1, 1))
    valve = K.cyl(0.07, 0.18, (0.2, 0, 0.25), K.mat('valve', (0.15, 0.35, 0.8), rough=0.3), rot=(0, rad(90), 0))
    bpy.ops.mesh.primitive_cone_add(radius1=0.24, radius2=0.06, depth=0.22, location=(0.4, 0, 0.25), rotation=(0, rad(-90), 0)); mask = bpy.context.object
    K.smooth(mask); K.assign(mask, K.mat('mask', (0.9, 0.95, 1.0), rough=0.1, trans=0.8))
    cuff = K.torus(0.24, 0.03, (0.51, 0, 0.25), K.mat('cuff', (0.95, 0.95, 0.95), rough=0.4), rot=(0, rad(90), 0))
    return [bag, valve, mask, cuff], {'el': 20}

@item
def defibrillator():
    case = K.mat('aed', (0.05, 0.45, 0.25), rough=0.35, coat=0.3)
    body = K.box((0.9, 0.3, 0.65), (0, 0, 0.33), case, bevel=0.07)
    handle = K.torus(0.16, 0.035, (0, 0, 0.7), case, rot=(rad(90), 0, 0)); handle.scale = (1.4, 1, 1)
    def dr(d, im):
        d.rounded_rectangle((0, 0, 799, 499), 40, fill=(245, 245, 240, 255))
        d.ellipse((60, 120, 200, 260), fill=RED); d.ellipse((160, 120, 300, 260), fill=RED); d.polygon([(65, 210), (295, 210), (180, 360)], fill=RED)
        d.line([(110, 230), (160, 230), (180, 180), (205, 290), (225, 230), (260, 230)], fill=W, width=12)
        d.text((340, 120), 'AED', font=K.font(150, K.FONT_C), fill=(20, 120, 60, 255)); d.text((345, 300), 'DEFIBRILLATOR', font=K.font(48, K.FONT_B), fill=BLK)
    st = K.sticker(K.label_img('aed', 800, 500, (0, 0, 0, 0), dr), 0.7, 0.44, (0, -0.152, 0.32), (rad(90), 0, 0))
    return [body, handle, st], {}

@item
def medikit():
    o = S.imp('medical_box'); S.normalize(o, 1.0); bpy.context.view_layer.update(); lo, hi = S.bounds(o)
    st = K.sticker(K.cross_label('mk'), 0.18, 0.18, ((lo.x + hi.x) / 2, lo.y - 0.006, lo.z + (hi.z - lo.z) * 0.45), (rad(90), 0, 0))
    return o + [st], {}

@item
def firstaid():
    case = K.mat('fa', (0.75, 0.04, 0.04), rough=0.3, coat=0.5)
    body = K.box((0.9, 0.35, 0.6), (0, 0, 0.3), case, bevel=0.06)
    lid = K.box((0.92, 0.37, 0.04), (0, 0, 0.45), K.mat('seam', (0.6, 0.03, 0.03), rough=0.3), bevel=0.01)
    hd = K.box((0.3, 0.06, 0.05), (0, 0, 0.64), K.mat('hd', (0.05, 0.05, 0.05), rough=0.5), bevel=0.02)
    st = K.sticker(K.cross_label('fa', (255, 255, 255, 255), (200, 25, 35, 255)), 0.24, 0.24, (0, -0.178, 0.25), (rad(90), 0, 0))
    return [body, lid, hd, st], {}

@item
def ifaks():
    fab = K.mat('cordura', (0.17, 0.19, 0.11), rough=0.9, bump=0.5, bump_scale=700)
    pouch = K.box((0.75, 0.35, 0.55), (0, 0, 0.28), fab, bevel=0.1); K.smooth(pouch, sub=1)
    objs = [pouch]
    for i in range(3): objs.append(K.box((0.76, 0.36, 0.035), (0, 0, 0.12 + i * 0.13), K.mat('webbing', (0.13, 0.15, 0.08), rough=0.95), bevel=0.005))
    objs.append(K.sticker(K.cross_label('ifak', (200, 25, 35, 255), (255, 255, 255, 255)), 0.16, 0.16, (0, -0.185, 0.38), (rad(90), 0, 0)))
    objs.append(K.box((0.3, 0.04, 0.03), (0, 0, 0.56), K.mat('zip', (0.05, 0.05, 0.05), rough=0.5)))
    return objs, {}

@item
def medreport():
    o = S.imp('clipboard'); S.normalize(o, 1.0); bpy.context.view_layer.update(); lo, hi = S.bounds(o)
    def dr(d, im):
        d.rectangle((0, 0, 849, 1099), fill=(250, 250, 248, 255)); d.rectangle((0, 0, 849, 120), fill=(20, 70, 140, 255))
        d.text((40, 30), 'MEDICAL REPORT', font=K.font(64, K.FONT_C), fill=W)
        for i, t in enumerate(['PATIENT', 'DOB', 'DIAGNOSIS', 'TREATMENT', 'DOCTOR']):
            y = 170 + i * 150; d.text((40, y), t, font=K.font(34, K.FONT_B), fill=(60, 60, 60, 255)); d.line([(40, y + 70), (810, y + 70)], fill=(160, 160, 160, 255), width=3)
        d.text((520, 960), 'PILLBOX', font=K.font(40, K.FONT_B), fill=RED)
    w = (hi.x - lo.x) * 0.84; h = (hi.y - lo.y) * 0.78
    st = K.sticker(K.label_img('medreport', 850, 1100, (0, 0, 0, 0), dr), w, h, ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2 - 0.03, hi.z + 0.004), (0, 0, 0))
    return o + [st], {'el': 55}
