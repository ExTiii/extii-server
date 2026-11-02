import bpy, math, random
from mathutils import Vector
import studio as S, kit as K
R = {}
def item(f): R[f.__name__] = f; return f
rad = math.radians
W = (255, 255, 255, 255); BLK = (25, 25, 28, 255)

# ------------------------------------------------------------------ cards
def card_tex(name, head, head_c, sub, accent, photo=True, chip=False, stripe=False):
    def dr(d, im):
        w, h = 1000, 630
        d.rounded_rectangle((0, 0, w - 1, h - 1), 48, fill=(244, 244, 240, 255))
        for i in range(0, w, 14): d.line([(i, 0), (i - 200, h)], fill=(*accent[:3], 22), width=3)
        d.rounded_rectangle((0, 0, w - 1, 130), 48, fill=head_c); d.rectangle((0, 70, w - 1, 130), fill=head_c)
        d.text((40, 30), head, font=K.font(64, K.FONT_C), fill=W)
        if photo:
            d.rounded_rectangle((40, 170, 300, 520), 16, fill=(205, 210, 220, 255))
            d.ellipse((110, 220, 230, 340), fill=(140, 148, 160, 255)); d.pieslice((70, 350, 270, 560), 180, 360, fill=(140, 148, 160, 255))
        x0 = 340 if photo else 60
        for i, t in enumerate(sub): d.text((x0, 180 + i * 78), t, font=K.font(40 if i == 0 else 34, K.FONT_B if i == 0 else K.FONT_R), fill=(40, 40, 50, 255))
        if chip:
            d.rounded_rectangle((60, 260, 210, 370), 18, fill=(214, 178, 90, 255)); d.line([(60, 315), (210, 315)], fill=(160, 120, 50, 255), width=4); d.line([(135, 260), (135, 370)], fill=(160, 120, 50, 255), width=4)
        if stripe: d.rectangle((0, h - 90, w - 1, h - 40), fill=(30, 30, 30, 255))
        d.ellipse((w - 190, h - 190, w - 50, h - 50), outline=accent, width=10)
    return K.label_img(name, 1000, 630, (0, 0, 0, 0), dr)

def card(name, *a, **k):
    tex = card_tex(name, *a, **k)
    base = K.box((0.856, 0.54, 0.012), (0, 0, 0.006), K.mat('cardcore', (0.95, 0.95, 0.94), rough=0.3, coat=0.6), bevel=0.04)
    face = K.sticker(tex, 0.85, 0.535, (0, 0, 0.0125), (0, 0, 0), rough=0.15)
    base.rotation_euler = face.rotation_euler = (0, 0, rad(28))
    return [base, face], {'el': 52}

SA_BLUE = (25, 60, 130, 255)
@item
def id_card(): return card('id_card', 'SAN ANDREAS  ID', SA_BLUE, ['IDENTIFICATION', 'NAME  ________', 'DOB  ________', 'ID  SA-000000'], (25, 60, 130, 255))
@item
def driver_license(): return card('driver_license', 'DRIVER LICENSE', (160, 30, 30, 255), ['CLASS  C', 'NAME  ________', 'EXP  ________', 'DL  D000000'], (160, 30, 30, 255))
@item
def truck_license(): return card('truck_license', 'COMMERCIAL  CDL', (200, 110, 20, 255), ['CLASS  A  TRUCK', 'NAME  ________', 'EXP  ________', 'CDL  T000000'], (200, 110, 20, 255))
@item
def boat_license(): return card('boat_license', 'BOATING LICENSE', (20, 120, 160, 255), ['VESSEL OPERATOR', 'NAME  ________', 'EXP  ________', 'BL  B000000'], (20, 120, 160, 255))
@item
def heli_license(): return card('heli_license', 'PILOT CERTIFICATE', (70, 70, 80, 255), ['ROTORCRAFT', 'NAME  ________', 'EXP  ________', 'FAA  H000000'], (70, 70, 80, 255))
@item
def weaponlicense(): return card('weaponlicense', 'FIREARMS PERMIT', (40, 40, 45, 255), ['CONCEALED CARRY', 'NAME  ________', 'EXP  ________', 'CCW  W000000'], (180, 140, 40, 255))
@item
def lawyerpass(): return card('lawyerpass', 'STATE BAR  ·  SA', (20, 30, 60, 255), ['ATTORNEY AT LAW', 'NAME  ________', 'BAR NO.  ______', 'LOS SANTOS'], (190, 150, 60, 255))
@item
def security_card_01(): return card('security_card_01', 'SECURITY  ·  A', (30, 30, 35, 255), ['ACCESS LEVEL A', 'AUTHORIZED', 'PERSONNEL ONLY'], (40, 160, 90, 255), photo=False, chip=True, stripe=True)
@item
def security_card_02(): return card('security_card_02', 'SECURITY  ·  B', (120, 20, 25, 255), ['ACCESS LEVEL B', 'AUTHORIZED', 'PERSONNEL ONLY'], (200, 40, 40, 255), photo=False, chip=True, stripe=True)

# ------------------------------------------------------------------ money
def note_tex(name, dirty=False):
    def dr(d, im):
        w, h = 1000, 430
        d.rectangle((0, 0, w - 1, h - 1), fill=(178, 196, 160, 255) if not dirty else (140, 150, 120, 255))
        d.rectangle((16, 16, w - 17, h - 17), outline=(60, 90, 60, 255), width=8)
        d.ellipse((380, 70, 620, 360), outline=(60, 90, 60, 255), width=10); K.center_text(d, w, 150, '$', K.font(140, K.FONT_B), (60, 90, 60, 255))
        d.text((40, 30), '100', font=K.font(90, K.FONT_C), fill=(40, 70, 40, 255)); d.text((w - 210, h - 130), '100', font=K.font(90, K.FONT_C), fill=(40, 70, 40, 255))
        K.center_text(d, w, 26, 'STATE OF SAN ANDREAS', K.font(36, K.FONT_B), (40, 70, 40, 255))
        if dirty:
            for i in range(60): x, y = random.randint(0, w), random.randint(0, h); d.ellipse((x, y, x + random.randint(10, 60), y + random.randint(10, 40)), fill=(70, 60, 40, 60))
    random.seed(3)
    return K.label_img(name, 1000, 430, (0, 0, 0, 0), dr)

def cash_stack(name, dirty=False, band=(0.75, 0.6, 0.2)):
    tex = note_tex(name, dirty); objs = []
    edge = K.mat('edge', (0.6, 0.66, 0.55) if not dirty else (0.45, 0.47, 0.38), rough=0.8, bump=0.6, bump_scale=900)
    for k in range(3):
        x, y, rz = (-0.06 + k * 0.08, -0.03 + k * 0.05, rad(-10 + k * 9))
        st = K.box((0.85, 0.37, 0.16), (x, y, 0.08 + k * 0.165), edge, bevel=0.004); st.rotation_euler = (0, 0, rz)
        top = K.sticker(tex, 0.85, 0.37, (x, y, 0.161 + k * 0.165), (0, 0, rz), rough=0.6)
        bd = K.box((0.12, 0.375, 0.165), (x, y, 0.08 + k * 0.165), K.mat('band', band, rough=0.5), bevel=0.002); bd.rotation_euler = (0, 0, rz)
        objs += [st, top, bd]
    return objs, {'el': 35}

@item
def money(): return cash_stack('money')
@item
def black_money(): return cash_stack('black_money', True, (0.7, 0.05, 0.05))

# ------------------------------------------------------------------ valuables
def diamond_mesh(r=0.3, loc=(0, 0, 0)):
    prof = [(0, 0), (r, r * 0.86), (r * 0.98, r * 0.92), (r * 0.55, r * 1.2), (0, r * 1.2)]
    o = K.lathe(prof, K.mat('dia', (1, 1, 1), rough=0.0, trans=1.0, ior=2.42), segs=16)
    for p in o.data.polygons: p.use_smooth = False
    o.location = loc; return o

@item
def diamond():
    d = diamond_mesh(0.42); d.rotation_euler = (rad(18), 0, 0)
    return [d], {'el': 25}

@item
def diamond_ring():
    g = K.gold()
    band = K.torus(0.36, 0.05, (0, 0, 0.4), g, rot=(rad(90), 0, 0)); band.scale = (1, 1, 1)
    objs = [band, K.cyl(0.11, 0.06, (0, 0, 0.8), g)]
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        p = K.cyl(0.012, 0.12, (0.09 * math.cos(a), 0.09 * math.sin(a), 0.86), g); objs.append(p)
    dmd = diamond_mesh(0.12, (0, 0, 0.94)); dmd.rotation_euler = (rad(180), 0, 0); dmd.location.z = 1.0; objs.append(dmd)
    return objs, {'el': 22}

@item
def rolex():
    g = K.gold(); objs = []
    objs.append(K.cyl(0.3, 0.12, (0, 0, 0.3), g, rot=(rad(90), 0, 0), bevel=0.02))
    def dr(d, im):
        d.ellipse((0, 0, 599, 599), fill=(18, 40, 30, 255))
        for i in range(12):
            a = i * math.pi / 6; x, y = 300 + 240 * math.sin(a), 300 - 240 * math.cos(a)
            d.rectangle((x - 10, y - 24, x + 10, y + 24), fill=(230, 200, 120, 255)) if i % 3 else d.rectangle((x - 16, y - 30, x + 16, y + 30), fill=(240, 220, 150, 255))
        d.line([(300, 300), (300, 120)], fill=(240, 220, 150, 255), width=14); d.line([(300, 300), (420, 360)], fill=(240, 220, 150, 255), width=18)
        K.center_text(d, 600, 180, 'PROLAPS', K.font(38, K.FONT_B), (230, 200, 120, 255))
    dial = K.sticker(K.label_img('watchdial', 600, 600, (0, 0, 0, 0), dr), 0.48, 0.48, (0, -0.061, 0.3), (rad(90), 0, 0), rough=0.1)
    crystal = K.cyl(0.255, 0.01, (0, -0.064, 0.3), K.glass(), rot=(rad(90), 0, 0))
    bez = K.torus(0.27, 0.035, (0, -0.06, 0.3), g, rot=(rad(90), 0, 0))
    objs += [dial, crystal, bez, K.cyl(0.035, 0.06, (0.33, 0, 0.3), g, rot=(0, rad(90), 0))]
    for s in (-1, 1):
        for i in range(5):
            z = 0.3 + s * (0.3 + i * 0.075)
            objs.append(K.box((0.36, 0.08, 0.065), (0, 0.02 + i * 0.02, z), g, bevel=0.012))
    return objs, {'el': 12, 'az': 20}

@item
def goldbar():
    g = K.mat('goldbar', (1.0, 0.72, 0.3), rough=0.12, metal=1)
    bpy.ops.mesh.primitive_cube_add(size=1); o = bpy.context.object; o.scale = (1.0, 0.5, 0.22); bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:
        if v.co.z > 0: v.co.x *= 0.85; v.co.y *= 0.75
    o.location.z = 0.11; K.smooth(o, bevel=0.02); K.assign(o, g)
    def dr(d, im):
        K.center_text(d, 800, 20, 'FINE GOLD', K.font(90, K.FONT_C), (120, 80, 20, 255)); K.center_text(d, 800, 150, '999.9', K.font(110, K.FONT_C), (120, 80, 20, 255)); K.center_text(d, 800, 300, '1 KG', K.font(70, K.FONT_B), (120, 80, 20, 255))
    st = K.sticker(K.label_img('goldbar', 800, 400, (0, 0, 0, 0), dr), 0.7, 0.3, (0, 0, 0.222), (0, 0, 0), rough=0.2)
    return [o, st], {'el': 40}

def chain(n, R=0.36, r_link=0.055, t=0.014):
    g = K.gold(); objs = []
    for i in range(n):
        a = i * 2 * math.pi / n
        l = K.torus(r_link, t, (R * math.cos(a), R * math.sin(a), 0.03), g); l.scale = (1.6, 1, 1)
        l.rotation_euler = (rad(90) if i % 2 else 0, 0, a + math.pi / 2); objs.append(l)
    return objs

@item
def goldchain(): return chain(42), {'el': 45}
@item
def tenkgoldchain():
    objs = chain(30, R=0.36, r_link=0.07, t=0.026)
    pend = K.box((0.2, 0.04, 0.26), (0, -0.46, 0.03), K.gold(), bevel=0.02); pend.rotation_euler = (rad(90), 0, 0)
    return objs + [pend], {'el': 45}
R['10kgoldchain'] = R.pop('tenkgoldchain')

# ------------------------------------------------------------------ bags & drugs
def baggy(contents=None, size=(0.62, 0.8), label=None):
    w, h = size
    film = K.mat('bag', (0.97, 0.98, 1.0), rough=0.12, trans=0.95, ior=1.3)
    bag = K.box((w, h, 0.05), (0, 0, 0.03), film, bevel=0.02); K.smooth(bag, sub=1)
    zip_ = K.box((w, 0.03, 0.05), (0, h / 2 - 0.06, 0.035), K.mat('zip', (0.85, 0.15, 0.15), rough=0.3, trans=0.4))
    objs = [bag, zip_]
    if contents: objs += contents(w, h)
    if label:
        objs.append(K.sticker(label, w * 0.62, h * 0.24, (0, -h * 0.27, 0.058), (0, 0, 0)))
    return objs, {'el': 55}

def powder(col, n=40, rocks=False):
    def f(w, h):
        m = K.mat('pw', col, rough=0.75, bump=0.5, bump_scale=900, sss=0.1); out = []
        random.seed(5)
        if not rocks:
            o = K.sphere(0.24, (0, -0.05, 0.03), m, scale=(1.0, 1.25, 0.12)); out.append(o)
        for i in range(n):
            x, y = (random.random() - 0.5) * w * 0.6, (random.random() - 0.6) * h * 0.6
            o = K.sphere(0.03 + random.random() * 0.03, (x, y, 0.035), m, scale=(1, 0.8, 0.6)); o.rotation_euler = (random.random() * 3, random.random() * 3, 0); out.append(o)
        return out
    return f

def pills(cols, n=12):
    def f(w, h):
        random.seed(8); out = []
        for i in range(n):
            c = cols[i % len(cols)]
            o = K.cyl(0.05, 0.025, ((random.random() - 0.5) * w * 0.6, (random.random() - 0.6) * h * 0.6, 0.035), K.mat('pill', c, rough=0.45), bevel=0.01)
            o.rotation_euler = (random.random() * 0.4, random.random() * 0.4, 0); out.append(o)
        return out
    return f

def crystals(col):
    def f(w, h):
        random.seed(9); out = []; m = K.mat('cry', col, rough=0.08, trans=0.35, ior=1.6, sss=0.2)
        for i in range(34):
            o = K.box((0.05 + random.random() * 0.07, 0.04 + random.random() * 0.05, 0.03 + random.random() * 0.05), ((random.random() - 0.5) * w * 0.5, (random.random() - 0.6) * h * 0.55, 0.04), m)
            o.rotation_euler = (random.random() * 3, random.random() * 3, random.random() * 3); out.append(o)
        return out
    return f

def buds(pal, n=5):
    def f(w, h):
        random.seed(12); out = []
        for i in range(n):
            out += _bud(((random.random() - 0.5) * w * 0.5, 0.05 + random.random() * h * 0.22, 0.05), 0.75, pal, i)
        return out
    return f

def _bud(at, s, pal, seed=0):
    random.seed(seed + 30); out = []
    m = bpy.data.materials.new('bud'); m.use_nodes = True; nt = m.node_tree; b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 90; nz.inputs['Detail'].default_value = 10
    rp = nt.nodes.new('ShaderNodeValToRGB'); rp.color_ramp.elements[0].color = (*pal[0], 1); rp.color_ramp.elements[1].color = (*pal[1], 1)
    rp.color_ramp.elements[1].position = 0.62
    e = rp.color_ramp.elements.new(0.93); e.color = (0.7, 0.32, 0.06, 1)
    nt.links.new(tc.outputs['Object'], nz.inputs['Vector']); nt.links.new(nz.outputs['Fac'], rp.inputs[0]); nt.links.new(rp.outputs[0], b.inputs['Base Color'])
    bm = nt.nodes.new('ShaderNodeBump'); bm.inputs['Strength'].default_value = 1.0; bm.inputs['Distance'].default_value = 0.02
    nt.links.new(nz.outputs['Fac'], bm.inputs['Height']); nt.links.new(bm.outputs['Normal'], b.inputs['Normal'])
    b.inputs['Roughness'].default_value = 0.55; b.inputs['Sheen Weight'].default_value = 0.35; b.inputs['Sheen Tint'].default_value = (0.9, 1, 0.85, 1)
    for i in range(14):
        o = K.sphere(0.045 * s, (at[0] + (random.random() - 0.5) * 0.09 * s, at[1] + (random.random() - 0.5) * 0.14 * s, at[2] + random.random() * 0.03 * s), None, scale=(1, 1.3, 0.9))
        K.assign(o, m); out.append(o)
    return out

def strain_label(name, title, col):
    def dr(d, im):
        d.rounded_rectangle((0, 0, 799, 299), 30, fill=col); K.center_text(d, 800, 50, title, K.font(100 if len(title) < 10 else 76, K.FONT_C), W); K.center_text(d, 800, 200, '2 GRAMS', K.font(54, K.FONT_B), W)
    return K.label_img(name, 800, 300, (0, 0, 0, 0), dr)

STRAINS = {'ak47': ('AK-47', (40, 120, 50, 255), ((0.03, 0.12, 0.01), (0.16, 0.38, 0.04))),
           'skunk': ('SKUNK', (90, 110, 30, 255), ((0.05, 0.12, 0.01), (0.22, 0.34, 0.04))),
           'amnesia': ('AMNESIA', (30, 100, 120, 255), ((0.03, 0.1, 0.03), (0.14, 0.33, 0.08))),
           'og-kush': ('OG KUSH', (30, 70, 40, 255), ((0.02, 0.07, 0.01), (0.1, 0.24, 0.03))),
           'white-widow': ('WHITE WIDOW', (150, 150, 150, 255), ((0.08, 0.16, 0.04), (0.5, 0.58, 0.4))),
           'purple-haze': ('PURPLE HAZE', (110, 40, 140, 255), ((0.05, 0.02, 0.08), (0.24, 0.1, 0.3)))}
for key, (title, col, pal) in STRAINS.items():
    R[f'weed_{key}'] = (lambda key=key, title=title, col=col, pal=pal: baggy(buds(pal), label=strain_label('w_' + key, title, col)))
    def seed_item(key=key, title=title, col=col):
        def dr(d, im):
            d.rectangle((0, 0, 599, 799), fill=(235, 225, 200, 255)); d.rectangle((0, 0, 599, 220), fill=col)
            K.center_text(d, 600, 60, title, K.font(70 if len(title) < 10 else 54, K.FONT_C), W); K.center_text(d, 600, 300, 'SEEDS', K.font(110, K.FONT_C), BLK)
            K.center_text(d, 600, 480, 'FEMINIZED  ·  5 PCS', K.font(40, K.FONT_B), BLK)
        p = K.label_img('s_' + key, 600, 800, (0, 0, 0, 0), dr)
        env = K.box((0.6, 0.8, 0.03), (0, 0, 0.015), K.mat('env', (0.92, 0.88, 0.78), rough=0.8), bevel=0.01)
        st = K.sticker(p, 0.6, 0.8, (0, 0, 0.031), (0, 0, 0), rough=0.7)
        random.seed(2); seeds = []
        for i in range(6):
            s = K.sphere(0.03, (0.36 + random.random() * 0.15, -0.3 + random.random() * 0.25, 0.02), K.mat('seed', (0.3, 0.22, 0.12), rough=0.4, bump=0.5, bump_scale=400), scale=(1.3, 1, 0.8)); seeds.append(s)
        env.rotation_euler = st.rotation_euler = (0, 0, rad(-8))
        return [env, st] + seeds, {'el': 50}
    R[f'weed_{key}_seed'] = seed_item

@item
def cokebaggy(): return baggy(powder((0.95, 0.95, 0.93)), label=None)
@item
def crack_baggy(): return baggy(powder((0.92, 0.88, 0.75), 18, rocks=True))
@item
def xtcbaggy(): return baggy(pills([(0.95, 0.4, 0.7), (0.3, 0.7, 0.95), (0.95, 0.85, 0.3)]))
@item
def meth(): return baggy(crystals((0.25, 0.6, 0.95)))
@item
def empty_weed_bag(): return baggy(None)

def brick(col, wrap_c, size=(0.8, 0.5, 0.2), tape=True, label=None):
    o = K.box(size, (0, 0, size[2] / 2), K.mat('brickin', col, rough=0.8), bevel=0.04)
    wr = K.box((size[0] + 0.01, size[1] + 0.01, size[2] + 0.01), (0, 0, size[2] / 2), K.mat('wrapf', wrap_c, rough=0.15, trans=0.75, coat=0.6), bevel=0.045)
    objs = [o, wr]
    if tape:
        tm = K.mat('tapeb', (0.55, 0.38, 0.18), rough=0.3, coat=0.4)
        for x in (-0.22, 0.22): objs.append(K.box((0.1, size[1] + 0.02, size[2] + 0.02), (x, 0, size[2] / 2), tm, bevel=0.01))
    if label: objs.append(K.sticker(label, 0.22, 0.22, (0, 0, size[2] + 0.012), (0, 0, 0)))
    return objs, {'el': 38}

def stamp(name, txt, col):
    def dr(d, im):
        d.ellipse((10, 10, 389, 389), outline=col, width=24); K.center_text(d, 400, 140, txt, K.font(110, K.FONT_C), col)
    return K.label_img(name, 400, 400, (0, 0, 0, 0), dr)

@item
def coke_brick(): return brick((0.95, 0.95, 0.93), (0.95, 0.97, 1.0), label=stamp('coke', 'EX', (180, 20, 20, 255)))
@item
def coke_small_brick(): return brick((0.95, 0.95, 0.93), (0.95, 0.97, 1.0), (0.5, 0.36, 0.14), label=stamp('cokes', '★', (180, 20, 20, 255)))
@item
def weed_brick(): return brick((0.18, 0.28, 0.06), (0.95, 0.97, 1.0), label=stamp('weedb', '420', (30, 30, 30, 255)))

@item
def oxy():
    import r_med as M
    return M.pill_bottle('oxy', (0.95, 0.95, 0.96), (0.95, 0.95, 0.95), [('OXYCODONE', 50, W, K.FONT_C), ('30 mg', 60, BLK, K.FONT_B), ('Rx ONLY', 36, BLK, K.FONT_R)], trans=0.0), {'el': 22}

@item
def joint():
    paper = K.mat('rp', (0.95, 0.93, 0.88), rough=0.75, sss=0.3, bump=0.3, bump_scale=400)
    bpy.ops.mesh.primitive_cone_add(radius1=0.045, radius2=0.075, depth=0.9, vertices=48, location=(0, 0, 0.06), rotation=(0, rad(90), rad(-20))); j = bpy.context.object
    K.smooth(j); K.assign(j, paper)
    tip = K.cyl(0.044, 0.15, (-0.42 * math.cos(rad(20)), 0.42 * math.sin(rad(20)), 0.06), K.mat('crutch', (0.85, 0.75, 0.55), rough=0.8), rot=(0, rad(90), rad(-20)))
    tw = K.sphere(0.06, (0.47 * math.cos(rad(20)), -0.47 * math.sin(rad(20)), 0.07), paper, scale=(1.4, 0.8, 0.8)); tw.rotation_euler = (0, 0, rad(-20))
    return [j, tip, tw], {'el': 40}

@item
def rolling_paper():
    def dr(d, im):
        d.rectangle((0, 0, 799, 499), fill=(30, 30, 32, 255)); d.rectangle((0, 380, 799, 499), fill=(220, 160, 30, 255))
        K.center_text(d, 800, 80, 'KING SIZE', K.font(90, K.FONT_C), (220, 160, 30, 255)); K.center_text(d, 800, 230, 'ROLLING PAPERS', K.font(54, K.FONT_B), W)
    b = K.box((0.8, 0.45, 0.06), (0, 0, 0.03), K.mat('rpb', (0.12, 0.12, 0.13), rough=0.5), bevel=0.01)
    st = K.sticker(K.label_img('rolling', 800, 500, (0, 0, 0, 0), dr), 0.79, 0.44, (0, 0, 0.061), (0, 0, 0))
    sh = K.box((0.7, 0.3, 0.004), (0.05, 0.32, 0.07), K.mat('sheet', (0.96, 0.95, 0.9), rough=0.8, sss=0.4)); sh.rotation_euler = (rad(-20), 0, rad(5))
    return [b, st, sh], {'el': 45}

@item
def weed_nutrition():
    import r_mech as Mm
    return Mm.jug('weed_nutrition', (0.2, 0.55, 0.15), (250, 250, 245, 255), (30, 110, 40, 255), 'GROW+', 'PLANT FERTILIZER', (30, 110, 40, 255)), {}
