import bpy, math, random
from mathutils import Vector
import studio as S, kit as K
R = {}
def item(f): R[f.__name__] = f; return f
rad = math.radians
W = (255, 255, 255, 255); BLK = (25, 25, 28, 255)

def ph(mid, size=1.0, kw=None):
    def f():
        o = S.imp(mid); S.normalize(o, size); return o, (kw or {})
    return f
R['screwdriverset'] = ph('screwdrivers_02', kw={'el': 40})
R['gatecrack'] = ph('classic_laptop', kw={'el': 25})
R['small_tv'] = ph('Television_01', kw={'el': 15})
R['drill'] = ph('Drill_01', kw={'el': 20})
R['jerry_can'] = ph('metal_jerrycan')
R['lighter'] = ph('vintage_lighter', kw={'el': 20})
R['binoculars'] = ph('binoculars', kw={'el': 30})
R['garbage'] = ph('trashbag', kw={'el': 20})
R['electronickit'] = ph('circuit_board', kw={'el': 40})

def rusty():
    t = 'assets/tex/rusty_metal_02/'
    m = bpy.data.materials.new('rust'); m.use_nodes = True; nt = m.node_tree; b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (2, 2, 2)
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    import os
    for k, sock in (('Diffuse', 'Base Color'), ('Rough', 'Roughness')):
        for ext in ('jpg', 'png'):
            p = os.path.join(K.HERE, t + k + '.' + ext)
            if os.path.exists(p):
                im = nt.nodes.new('ShaderNodeTexImage'); im.image = bpy.data.images.load(p); im.projection = 'BOX'; im.projection_blend = 0.3
                if k != 'Diffuse': im.image.colorspace_settings.name = 'Non-Color'
                nt.links.new(mp.outputs[0], im.inputs['Vector']); nt.links.new(im.outputs['Color'], b.inputs[sock])
    b.inputs['Metallic'].default_value = 0.6
    return m

# ------------------------------------------------------------------ materials
def ingots(m, size=(0.6, 0.24, 0.13)):
    objs = []
    for y in (-0.14, 0.14): objs.append(K.box(size, (0, y, size[2] / 2), m, bevel=0.025))
    top = K.box(size, (0, 0, size[2] * 1.5 + 0.002), m, bevel=0.025); top.rotation_euler = (0, 0, rad(90)); objs.append(top)
    return objs, {'el': 30}

@item
def steel():
    m = K.mat('steelbar', (0.55, 0.56, 0.58), rough=0.35, metal=1, aniso=0.5, noise_rough=0.1)
    objs = []
    for i in range(4):
        o = K.box((1.0, 0.16, 0.05), (0, -0.25 + i * 0.17, 0.025), m, bevel=0.004); objs.append(o)
    for i in range(3):
        o = K.box((1.0, 0.16, 0.05), (0, -0.17 + i * 0.17, 0.075), m, bevel=0.004); o.rotation_euler = (0, 0, rad(3 * (i - 1))); objs.append(o)
    return objs, {'el': 35}
@item
def iron(): return ingots(K.mat('ironm', (0.2, 0.2, 0.21), rough=0.7, metal=1, bump=0.6, bump_scale=200))
@item
def copper():
    m = K.copper(); objs = []
    for i in range(18): objs.append(K.torus(0.32 - i * 0.004, 0.018, (0, 0, 0.02 + i * 0.03), m))
    objs.append(K.cyl(0.25, 0.6, (0, 0, 0.3), K.mat('spool', (0.12, 0.12, 0.13), rough=0.5)))
    for z in (0.0, 0.6): objs.append(K.cyl(0.4, 0.03, (0, 0, z), K.mat('spool', (0.12, 0.12, 0.13), rough=0.5)))
    return objs, {'el': 28}
@item
def aluminum(): return ingots(K.mat('alum', (0.85, 0.86, 0.88), rough=0.3, metal=1, noise_rough=0.1))
@item
def rubber():
    m = K.mat('rubs', (0.03, 0.03, 0.03), rough=0.75, bump=0.2, bump_scale=200)
    roll = K.cyl(0.25, 0.8, (0, 0, 0.25), m, rot=(0, rad(90), 0))
    sheet = K.box((0.8, 0.5, 0.025), (0, -0.4, 0.012), m, bevel=0.005)
    return [roll, sheet], {'el': 32}
@item
def plastic():
    film = K.mat('pbag', (0.97, 0.98, 1.0), rough=0.15, trans=0.9, ior=1.3)
    bag = K.sphere(0.4, (0, 0, 0.32), film, scale=(1.1, 0.8, 0.8))
    random.seed(4); objs = [bag]; cols = [(0.9, 0.9, 0.9), (0.15, 0.4, 0.85), (0.9, 0.2, 0.15), (0.95, 0.8, 0.1)]
    for i in range(70):
        a = random.random() * 2 * math.pi; r = math.sqrt(random.random()) * 0.3
        objs.append(K.cyl(0.025, 0.03, (r * math.cos(a) * 1.1, r * math.sin(a) * 0.8, 0.12 + random.random() * 0.3), K.mat('pel', cols[i % 4], rough=0.3), verts=16))
    return objs, {'el': 25}
@item
def glass():
    g = K.glass((0.85, 0.95, 0.92)); objs = []
    for i in range(4):
        o = K.box((0.9, 0.6, 0.02), (0.02 * i, 0.02 * i, 0.01 + i * 0.022), g, bevel=0.002); o.rotation_euler = (0, 0, rad(i * 4)); objs.append(o)
    return objs, {'el': 30}
@item
def metalscrap():
    m = rusty(); random.seed(6); objs = []
    for i in range(14):
        if i % 3 == 0: o = K.cyl(0.04 + random.random() * 0.05, 0.3 + random.random() * 0.4, (0, 0, 0), m)
        else: o = K.box((0.2 + random.random() * 0.4, 0.05 + random.random() * 0.15, 0.02 + random.random() * 0.06), (0, 0, 0), m, bevel=0.005)
        o.location = ((random.random() - 0.5) * 0.6, (random.random() - 0.5) * 0.5, 0.05 + random.random() * 0.25)
        o.rotation_euler = (random.random() * 3, random.random() * 3, random.random() * 3); objs.append(o)
    return objs, {'el': 30}

# ------------------------------------------------------------------ tools & gadgets
@item
def lockpick():
    pouch = K.box((0.9, 0.5, 0.025), (0, 0, 0.012), K.mat('leather', (0.25, 0.12, 0.05), rough=0.6, bump=0.3, bump_scale=300), bevel=0.01)
    st = K.steel(); objs = [pouch]
    for i in range(6):
        p = K.box((0.6, 0.018, 0.006), (0.05, -0.18 + i * 0.07, 0.03), st, bevel=0.002); p.rotation_euler = (0, 0, rad(-6 + i * 2)); objs.append(p)
        h = K.box((0.2, 0.04, 0.012), (-0.32, -0.18 + i * 0.07, 0.03), K.mat('hd', (0.05, 0.05, 0.05), rough=0.5), bevel=0.006); objs.append(h)
        tip = K.box((0.03, 0.018, 0.006), (0.36, -0.18 + i * 0.07 + 0.012 * (i % 2), 0.03), st); tip.rotation_euler = (0, 0, rad(30 + i * 10)); objs.append(tip)
    return objs, {'el': 50}

@item
def advancedlockpick():
    body = K.mat('gun', (0.05, 0.05, 0.06), rough=0.4)
    objs = [K.box((0.55, 0.14, 0.22), (0, 0, 0.45), body, bevel=0.04)]
    g = K.box((0.14, 0.12, 0.4), (-0.12, 0, 0.2), body, bevel=0.04); g.rotation_euler = (0, rad(-12), 0); objs.append(g)
    objs.append(K.cyl(0.025, 0.4, (0.45, 0, 0.47), K.chrome(), rot=(0, rad(90), 0)))
    objs.append(K.box((0.12, 0.06, 0.06), (0.05, 0, 0.6), K.mat('trig', (0.85, 0.1, 0.05), rough=0.4), bevel=0.01))
    return objs, {'el': 15}

@item
def cleaningkit():
    import r_mech as M
    o = S.imp('multi_cleaner_bottle'); S.normalize(o, 0.75)
    cloth = K.box((0.6, 0.5, 0.06), (0.45, 0.1, 0.03), K.mat('micro', (0.1, 0.4, 0.8), rough=0.95, bump=0.6, bump_scale=600), bevel=0.02)
    sp = K.box((0.35, 0.22, 0.12), (0.45, -0.3, 0.06), K.mat('sponge', (0.95, 0.8, 0.2), rough=0.95, bump=1.0, bump_scale=300), bevel=0.03)
    return o + [cloth, sp], {}

def phone_screen(name):
    def dr(d, im):
        d.rounded_rectangle((0, 0, 539, 1099), 60, fill=(10, 12, 20, 255))
        for y in range(0, 1100, 4): d.line([(0, y), (540, y)], fill=(30 + y // 30, 40, 90 + y // 20, 255))
        K.center_text(d, 540, 160, '12:45', K.font(130, K.FONT_R), W); K.center_text(d, 540, 320, 'Monday, 2 November', K.font(34, K.FONT_R), W)
        for r_ in range(2):
            for c in range(4): d.rounded_rectangle((50 + c * 115, 820 + r_ * 125, 140 + c * 115, 910 + r_ * 125), 24, fill=[(60, 180, 90, 255), (50, 130, 230, 255), (240, 160, 40, 255), (230, 60, 80, 255)][c])
    return K.label_img(name, 540, 1100, (0, 0, 0, 0), dr)

@item
def phone():
    body = K.box((0.48, 0.98, 0.05), (0, 0, 0.025), K.mat('ph', (0.08, 0.08, 0.09), rough=0.2, metal=0.8), bevel=0.06)
    scr = K.sticker(phone_screen('phone'), 0.45, 0.94, (0, 0, 0.0505), (0, 0, 0), rough=0.05)
    body.rotation_euler = scr.rotation_euler = (0, 0, rad(28))
    return [body, scr], {'el': 55}

@item
def radio():
    b = K.mat('rad', (0.06, 0.06, 0.065), rough=0.45)
    objs = [K.box((0.32, 0.16, 0.6), (0, 0, 0.3), b, bevel=0.04), K.cyl(0.025, 0.45, (0.09, 0, 0.82), b),
            K.cyl(0.04, 0.06, (-0.08, 0, 0.63), K.mat('knob', (0.15, 0.15, 0.15), rough=0.4)),
            K.box((0.2, 0.01, 0.12), (0, -0.081, 0.45), K.mat('lcd', (0.35, 0.55, 0.3), rough=0.1, emit=(0.4, 0.7, 0.35), emit_k=0.6)),
            K.box((0.22, 0.01, 0.18), (0, -0.081, 0.2), K.mat('grill', (0.03, 0.03, 0.03), rough=0.7, bump=0.8, bump_scale=200))]
    return objs, {'el': 15}

@item
def jammer():
    b = K.mat('jam', (0.08, 0.09, 0.09), rough=0.4, metal=0.5)
    objs = [K.box((0.7, 0.4, 0.14), (0, 0, 0.07), b, bevel=0.02)]
    for i in range(5):
        a = K.cyl(0.018, 0.55, (-0.26 + i * 0.13, 0.12, 0.4), K.mat('ant', (0.03, 0.03, 0.03), rough=0.5)); a.rotation_euler = (rad(-10 + i * 5), 0, 0); objs.append(a)
    for i in range(4): objs.append(K.sphere(0.018, (-0.2 + i * 0.07, -0.2, 0.1), K.mat('led', (0.1, 1, 0.2), emit=(0.1, 1, 0.2), emit_k=8)))
    return objs, {'el': 25}

@item
def radiocell():
    objs = []
    def dr(d, im):
        d.rectangle((0, 0, 999, 299), fill=(20, 20, 22, 255)); d.rectangle((0, 0, 330, 299), fill=(230, 150, 20, 255))
        K.center_text(d, 1000, 90, 'AAA  1.5V', K.font(80, K.FONT_C), W)
    p = K.label_img('aaa', 1000, 300, (0, 0, 0, 0), dr)
    for i in range(4):
        x = -0.27 + i * 0.18
        objs.append(K.cyl(0.08, 0.6, (x, 0, 0.08), K.steel(), rot=(rad(90), 0, 0)))
        lb = K.wrap(p, 0.082, 0.52, 0.0, rough=0.3, coat=0.5); lb.location = (x, 0, 0.08); lb.rotation_euler = (rad(90), 0, 0); objs.append(lb)
        objs.append(K.cyl(0.03, 0.04, (x, -0.31, 0.08), K.steel(), rot=(rad(90), 0, 0)))
    return objs, {'el': 40}

def usb(body_c, cap_c=None, gold=False):
    m = K.mat('usb', body_c, rough=0.3, metal=0.6 if gold else 0.1, coat=0.4)
    objs = [K.box((0.6, 0.2, 0.08), (0.05, 0, 0.04), m, bevel=0.03), K.box((0.18, 0.13, 0.05), (-0.34, 0, 0.04), K.steel(), bevel=0.003)]
    objs.append(K.torus(0.04, 0.012, (0.38, 0, 0.04), m))
    if cap_c: objs.append(K.sphere(0.012, (0.15, -0.101, 0.05), K.mat('l', cap_c, emit=cap_c, emit_k=8)))
    return objs, {'el': 40}
@item
def cryptostick(): return usb((0.85, 0.65, 0.2), (1.0, 0.7, 0.1), gold=True)
@item
def trojan_usb(): return usb((0.08, 0.08, 0.09), (1.0, 0.05, 0.05))

@item
def toaster():
    ch = K.mat('toastch', (0.85, 0.85, 0.88), rough=0.12, metal=1)
    body = K.box((0.8, 0.45, 0.5), (0, 0, 0.27), ch, bevel=0.12)
    for x in (-0.15, 0.15): K.boolean(body, K.box((0.4, 0.06, 0.3), (0, x, 0.52)))
    K.smooth(body)
    feet = [K.box((0.08, 0.08, 0.03), (x, y, 0.015), K.mat('ft', (0.05, 0.05, 0.05)), bevel=0.01) for x in (-0.3, 0.3) for y in (-0.15, 0.15)]
    lever = K.box((0.08, 0.05, 0.04), (0.42, 0, 0.35), K.mat('lev', (0.05, 0.05, 0.05), rough=0.4), bevel=0.01)
    return [body, lever] + feet, {'el': 25}

@item
def thermite():
    m = K.mat('therm', (0.25, 0.27, 0.22), rough=0.5, metal=0.3)
    objs = [K.cyl(0.18, 0.55, (0, 0, 0.28), m), K.cyl(0.19, 0.04, (0, 0, 0.56), K.dark_steel()), K.cyl(0.04, 0.12, (0, 0, 0.62), K.mat('fuse', (0.8, 0.1, 0.05), rough=0.4))]
    def dr(d, im):
        d.rectangle((0, 0, 999, 299), fill=(230, 180, 20, 255)); K.center_text(d, 1000, 50, 'THERMITE', K.font(64, K.FONT_C), BLK); K.center_text(d, 1000, 170, 'INCENDIARY', K.font(40, K.FONT_B), BLK)
    objs.append(K.wrap(K.label_img('thermite', 1000, 300, (0, 0, 0, 0), dr), 0.182, 0.2, 0.3))
    return objs, {'el': 18}

@item
def diving_fill():
    y = K.mat('tank', (0.95, 0.75, 0.05), rough=0.25, coat=0.8)
    return [K.cyl(0.17, 0.85, (0, 0, 0.43), y), K.sphere(0.17, (0, 0, 0.85), y), K.cyl(0.05, 0.1, (0, 0, 1.04), K.chrome()),
            K.box((0.14, 0.06, 0.05), (0.06, 0, 1.1), K.chrome(), bevel=0.01), K.cyl(0.04, 0.03, (0.14, 0, 1.1), K.mat('kn', (0.1, 0.1, 0.1)), rot=(0, rad(90), 0))], {'el': 15}

@item
def diving_gear():
    sil = K.mat('silicone', (0.05, 0.05, 0.06), rough=0.5)
    frame = K.box((0.6, 0.14, 0.3), (0, 0, 0.3), sil, bevel=0.08)
    lens = K.box((0.52, 0.02, 0.24), (0, -0.075, 0.3), K.glass((0.9, 0.95, 1.0)), bevel=0.05)
    strap = K.torus(0.3, 0.025, (0, 0.2, 0.3), sil, rot=(0, 0, 0)); strap.scale = (1.05, 0.7, 1)
    snork = K.cyl(0.035, 0.8, (0.34, 0.05, 0.5), K.mat('snork', (0.95, 0.75, 0.05), rough=0.3))
    fin = K.box((0.25, 0.6, 0.03), (-0.1, -0.35, 0.02), K.mat('fin', (0.05, 0.35, 0.8), rough=0.4), bevel=0.02)
    return [frame, lens, strap, snork, fin], {'el': 28}

@item
def nitrous():
    import r_mech as M
    return M._nos_bottle(), {'el': 18}

@item
def walking_stick():
    w = K.mat('cane', (0.25, 0.12, 0.05), rough=0.3, coat=0.6)
    shaft = K.cyl(0.03, 1.1, (0, 0, 0.55), w)
    hook = K.torus(0.12, 0.03, (0.12, 0, 1.1), w, rot=(rad(90), 0, 0))
    K.boolean(hook, K.box((0.4, 0.2, 0.2), (0.12, 0, 1.0)))
    tip = K.cyl(0.035, 0.05, (0, 0, 0.025), K.rubber())
    return [shaft, hook, tip], {'el': 15}

@item
def stickynote():
    objs = []
    for i in range(8):
        o = K.box((0.6, 0.6, 0.012), (0, 0, 0.006 + i * 0.012), K.mat('sn', (1.0, 0.85, 0.15), rough=0.8), bevel=0.002); o.rotation_euler = (0, 0, rad(i * 0.6)); objs.append(o)
    def dr(d, im):
        d.text((50, 80), 'pick up', font=K.font(70, K.FONT_R), fill=(30, 40, 120, 255)); d.text((50, 200), 'at 9 pm', font=K.font(70, K.FONT_R), fill=(30, 40, 120, 255))
    objs.append(K.sticker(K.label_img('note', 600, 600, (0, 0, 0, 0), dr), 0.58, 0.58, (0, 0, 0.103), (0, 0, rad(4))))
    curl = K.box((0.6, 0.15, 0.01), (0, -0.33, 0.12), K.mat('sn', (1.0, 0.85, 0.15), rough=0.8)); curl.rotation_euler = (rad(25), 0, 0); objs.append(curl)
    return objs, {'el': 45}

def evidence(filled):
    paper = K.mat('kraft', (0.6, 0.42, 0.25), rough=0.85, bump=0.15, bump_scale=200)
    bag = K.box((0.6, 0.12 if filled else 0.04, 0.85), (0, 0, 0.43), paper, bevel=0.02)
    if filled: K.smooth(bag, sub=1)
    def dr(d, im):
        d.rectangle((0, 0, 599, 799), fill=(250, 250, 250, 255)); d.rectangle((0, 0, 599, 150), fill=(200, 25, 30, 255))
        K.center_text(d, 600, 30, 'EVIDENCE', K.font(96, K.FONT_C), W)
        for i, t in enumerate(['CASE NO.', 'ITEM', 'COLLECTED BY', 'DATE']):
            y = 200 + i * 140; d.text((30, y), t, font=K.font(34, K.FONT_B), fill=BLK); d.line([(30, y + 80), (570, y + 80)], fill=(150, 150, 150, 255), width=3)
        if filled: d.text((250, 330), 'LSPD-2611', font=K.font(48, K.FONT_R), fill=(30, 40, 120, 255))
    st = K.sticker(K.label_img('evid' + str(filled), 600, 800, (0, 0, 0, 0), dr), 0.42, 0.56, (0, -(0.065 if filled else 0.024), 0.45), (rad(90), 0, 0))
    seal = K.box((0.6, 0.13 if filled else 0.05, 0.06), (0, 0, 0.8), K.mat('seal', (0.85, 0.1, 0.1), rough=0.3))
    return [bag, st, seal], {'el': 15}
R['empty_evidence_bag'] = lambda: evidence(False)
R['filled_evidence_bag'] = lambda: evidence(True)

@item
def harness():
    red = K.mat('belt', (0.75, 0.04, 0.04), rough=0.8, bump=0.5, bump_scale=500); objs = []
    for x in (-0.2, 0.2):
        s = K.box((0.12, 1.0, 0.012), (x, 0, 0.02), red, bevel=0.003); s.rotation_euler = (0, 0, rad(x * 40)); objs.append(s)
    lap = K.box((1.0, 0.12, 0.012), (0, -0.4, 0.03), red, bevel=0.003); objs.append(lap)
    objs.append(K.cyl(0.13, 0.04, (0, -0.4, 0.05), K.mat('cam', (0.75, 0.76, 0.78), rough=0.2, metal=1), bevel=0.01))
    for x in (-0.2, 0.2): objs.append(K.box((0.15, 0.05, 0.03), (x + x * 0.07, 0.47, 0.03), K.steel(), bevel=0.01))
    return objs, {'el': 50}

@item
def handcuffs():
    st = K.chrome(); objs = []
    for x in (-0.28, 0.28):
        r = K.torus(0.2, 0.03, (x, 0, 0.03), st); r.scale = (1, 1, 1.5); objs.append(r)
        objs.append(K.box((0.12, 0.08, 0.06), (x * 0.55, 0, 0.03), st, bevel=0.01))
    for i in range(3):
        l = K.torus(0.025, 0.008, (-0.05 + i * 0.05, 0, 0.03), st, rot=(rad(90) if i % 2 else 0, 0, 0)); l.scale = (1.4, 1, 1); objs.append(l)
    return objs, {'el': 45}

@item
def parachute():
    f = K.mat('chute', (0.1, 0.12, 0.08), rough=0.85, bump=0.5, bump_scale=500)
    pack = K.box((0.6, 0.3, 0.75), (0, 0, 0.38), f, bevel=0.08); K.smooth(pack, sub=1)
    objs = [pack]
    for x in (-0.18, 0.18):
        s = K.box((0.07, 0.03, 0.9), (x, -0.17, 0.42), K.mat('sh', (0.05, 0.05, 0.05), rough=0.8)); objs.append(s)
    objs.append(K.box((0.12, 0.04, 0.06), (0.25, -0.2, 0.55), K.mat('pull', (0.8, 0.2, 0.05), rough=0.4), bevel=0.01))
    return objs, {'el': 18}

@item
def armour():
    fab = K.mat('vest', (0.06, 0.07, 0.08), rough=0.85, bump=0.5, bump_scale=600)
    front = K.box((0.7, 0.16, 0.85), (0, 0, 0.43), fab, bevel=0.1); K.smooth(front, sub=1)
    objs = [front]
    for x in (-0.24, 0.24): objs.append(K.box((0.14, 0.2, 0.25), (x, 0.02, 0.92), fab, bevel=0.04))
    for i in range(3): objs.append(K.box((0.66, 0.03, 0.04), (0, -0.09, 0.22 + i * 0.1), K.mat('mol', (0.04, 0.04, 0.05), rough=0.9)))
    def dr(d, im):
        d.rectangle((0, 0, 599, 199), fill=(240, 240, 240, 255)); K.center_text(d, 600, 40, 'POLICE', K.font(110, K.FONT_C), BLK)
    objs.append(K.sticker(K.label_img('vest', 600, 200, (0, 0, 0, 0), dr), 0.42, 0.14, (0, -0.093, 0.62), (rad(90), 0, 0)))
    return objs, {'el': 15}

def folded(cols):
    objs = []
    for i, c in enumerate(cols):
        o = K.box((0.7, 0.55, 0.08), (0.02 * i, -0.02 * i, 0.04 + i * 0.085), K.mat('cloth', c, rough=0.95, bump=0.4, bump_scale=500), bevel=0.035)
        o.rotation_euler = (0, 0, rad(-5 + i * 5)); objs.append(o)
    return objs, {'el': 32}
@item
def clothing(): return folded([(0.05, 0.08, 0.2), (0.6, 0.6, 0.62), (0.5, 0.05, 0.05)])
@item
def panties(): return folded([(0.85, 0.85, 0.88)])

@item
def paperbag():
    paper = K.mat('pbagp', (0.58, 0.42, 0.25), rough=0.85, bump=0.25, bump_scale=150)
    b = K.box((0.6, 0.38, 0.85), (0, 0, 0.43), paper, bevel=0.01)
    K.boolean(b, K.box((0.56, 0.34, 0.85), (0, 0, 0.88)))
    fold = K.box((0.62, 0.4, 0.05), (0, 0, 0.82), paper, bevel=0.005)
    return [b, fold], {'el': 30}

def fw(cols, labels, tubes=4):
    objs = []
    for i in range(tubes):
        x, y = (i % 2) * 0.24 - 0.12, (i // 2) * 0.24 - 0.12
        c = cols[i % len(cols)]
        objs.append(K.cyl(0.11, 0.6 + (i % 3) * 0.08, (x, y, 0.3 + (i % 3) * 0.04), K.mat('fwp', c, rough=0.6)))
        objs.append(K.cyl(0.112, 0.06, (x, y, 0.55 + (i % 3) * 0.08), K.mat('fwb', (0.9, 0.85, 0.2), rough=0.4)))
    objs.append(K.cyl(0.012, 0.25, (0.1, -0.15, 0.08), K.mat('fuse', (0.1, 0.5, 0.1), rough=0.6), rot=(rad(60), 0, 0)))
    return objs, {'el': 25}
@item
def firework1(): return fw([(0.8, 0.05, 0.05), (0.1, 0.2, 0.7)], None)
@item
def firework2(): return fw([(0.95, 0.6, 0.05), (0.6, 0.1, 0.6)], None, 6)
@item
def firework3(): return fw([(0.05, 0.05, 0.05), (0.9, 0.9, 0.9)], None, 3)
@item
def firework4(): return fw([(0.1, 0.55, 0.2), (0.95, 0.85, 0.1)], None, 5)

def coral(col, pillars=False, seed=1):
    random.seed(seed); m = K.mat('coral', col, rough=0.75, bump=1.0, bump_scale=120, sss=0.2)
    base = K.sphere(0.25, (0, 0, 0.05), m, scale=(1.2, 1, 0.4)); objs = [base]
    if pillars:
        for i in range(7):
            a = random.random() * 6.28; r = random.random() * 0.2; h = 0.4 + random.random() * 0.5
            objs.append(K.cyl(0.05 + random.random() * 0.03, h, (r * math.cos(a), r * math.sin(a), h / 2), m)); objs.append(K.sphere(0.06, (r * math.cos(a), r * math.sin(a), h), m))
    else:
        def branch(p, d, l, depth):
            if depth == 0: return
            e = Vector(p) + d * l
            c = K.cyl(0.018 * depth / 3 + 0.006, l, tuple((Vector(p) + e) / 2), m); c.rotation_euler = d.to_track_quat('Z', 'Y').to_euler(); objs.append(c)
            for k in range(2):
                nd = (d + Vector(((random.random() - 0.5) * 1.2, (random.random() - 0.5) * 1.2, 0.3))).normalized()
                branch(e, nd, l * 0.72, depth - 1)
        branch((0, 0, 0.05), Vector((0, 0, 1)), 0.32, 5)
    return objs, {'el': 15}
@item
def antipatharia_coral(): return coral((0.05, 0.04, 0.035), seed=3)
@item
def dendrogyra_coral(): return coral((0.75, 0.6, 0.4), pillars=True, seed=5)
