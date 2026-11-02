import bpy, math, random
from mathutils import Vector
import studio as S, kit as K, grapes as G
R = {}
def item(f): R[f.__name__] = f; return f

def _box_with(label_path, w=0.62, h=0.36, stencil=False, up=0.0):
    bx = S.imp('cardboard_box_01'); S.normalize(bx, 1.0); bpy.context.view_layer.update()
    lo, hi = S.bounds(bx); cz = (lo.z + hi.z) / 2 - 0.02 + up
    st = K.sticker(label_path, w, h, ((lo.x + hi.x) / 2, lo.y - 0.012, cz), (math.radians(90), 0, 0), rough=0.6 if stencil else 0.35)
    return bx + [st]

@item
def poultry_kit():
    def dr(d, im):
        ink = (28, 22, 16, 225)
        K.center_text(d, 1024, 70, 'POULTRY KIT', K.font(150, K.FONT_C), ink)
        K.center_text(d, 1024, 260, 'FEED  ·  TAGS  ·  GLOVES', K.font(62, K.FONT_B), ink)
        d.rectangle((90, 380, 934, 392), fill=ink)
        K.center_text(d, 1024, 420, 'EX FARMS  —  GRAPESEED', K.font(54, K.FONT_R), ink)
    p = K.label_img('poultry_kit', 1024, 520, (0, 0, 0, 0), dr)
    return _box_with(p, 0.42, 0.21, stencil=True, up=0.15), {}

@item
def raisin_box():
    def dr(d, im):
        d.rounded_rectangle((0, 0, 1023, 579), 40, fill=(250, 244, 230, 255))
        d.rounded_rectangle((20, 20, 1003, 559), 30, outline=(120, 40, 90, 255), width=10)
        K.center_text(d, 1024, 70, 'MARLOWE', K.font(70, K.FONT_B), (120, 40, 90, 255))
        K.center_text(d, 1024, 170, 'RAISINS', K.font(190, K.FONT_C), (90, 30, 70, 255))
        K.center_text(d, 1024, 400, 'SUN-DRIED  ·  2 KG', K.font(64, K.FONT_B), (200, 120, 30, 255))
    p = K.label_img('raisin_box', 1024, 580, (0, 0, 0, 0), dr)
    return _box_with(p, 0.56, 0.32), {}

@item
def empty_carton():
    m = K.cardboard(); objs = []; W, D, H, t = 1.0, 0.75, 0.6, 0.012
    objs.append(K.box((W, D, t), (0, 0, t / 2), m))
    for sx in (-1, 1):
        objs.append(K.box((t, D, H), (sx * W / 2, 0, H / 2), m))
    for sy in (-1, 1):
        objs.append(K.box((W, t, H), (0, sy * D / 2, H / 2), m))
    # the flaps, open (hinged on the top edges)
    def flap(w, l, hinge, axis, ang):
        f = K.box((w, l, t) if axis == 'x' else (l, w, t), (0, 0, 0), m)
        piv = bpy.data.objects.new('hinge', None); bpy.context.scene.collection.objects.link(piv); piv.location = hinge
        f.parent = piv
        if axis == 'x': f.location = (0, math.copysign(l / 2, hinge[1]), 0); piv.rotation_euler = (math.radians(ang * (1 if hinge[1] > 0 else -1)), 0, 0)
        else: f.location = (math.copysign(l / 2, hinge[0]), 0, 0); piv.rotation_euler = (0, math.radians(-ang * (1 if hinge[0] > 0 else -1)), 0)
        return f
    for sy in (-1, 1): objs.append(flap(W * 0.98, D * 0.48, (0, sy * D / 2, H), 'x', 125))
    for sx in (-1, 1): objs.append(flap(D * 0.96, W * 0.4, (sx * W / 2, 0, H), 'y', 110))
    tape = K.mat('tape', (0.75, 0.62, 0.42), rough=0.25)
    objs.append(K.box((0.12, t * 1.2, H * 0.45), (0, -D / 2 - t * 0.7, H * 0.78), tape))
    return objs, {'el': 30}

def _tray(W=1.0, D=0.68, H=0.12):
    foam = K.mat('foam', (0.93, 0.93, 0.9), rough=0.9, bump=0.06, bump_scale=300)
    outer = K.box((W, D, H), (0, 0, H / 2), foam, bevel=0.03)
    inner = K.box((W - 0.1, D - 0.1, H), (0, 0, H / 2 + 0.03))
    K.boolean(outer, inner)
    K.smooth(outer, bevel=0.01)
    return outer

@item
def packing_tray():
    return [_tray()], {'el': 40}

def _skin():
    m = bpy.data.materials.new('skin'); m.use_nodes = True; nt = m.node_tree; bs = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 6; nz.inputs['Detail'].default_value = 6
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.93, 0.66, 0.5, 1); ramp.color_ramp.elements[1].color = (0.95, 0.78, 0.55, 1)
    nt.links.new(tc.outputs['Object'], nz.inputs['Vector']); nt.links.new(nz.outputs['Fac'], ramp.inputs[0]); nt.links.new(ramp.outputs[0], bs.inputs['Base Color'])
    vo = nt.nodes.new('ShaderNodeTexVoronoi'); vo.inputs['Scale'].default_value = 260
    bm = nt.nodes.new('ShaderNodeBump'); bm.inputs['Strength'].default_value = 0.35; bm.inputs['Distance'].default_value = 0.01
    nt.links.new(tc.outputs['Object'], vo.inputs['Vector']); nt.links.new(vo.outputs['Distance'], bm.inputs['Height']); nt.links.new(bm.outputs['Normal'], bs.inputs['Normal'])
    bs.inputs['Roughness'].default_value = 0.3; bs.inputs['Subsurface Weight'].default_value = 0.35; bs.inputs['Coat Weight'].default_value = 0.35
    bs.inputs['Subsurface Radius'].default_value = (0.6, 0.3, 0.2)
    return m

def _drumstick(loc, rotz, s=1.0):
    sk = _skin()
    a = K.sphere(0.11 * s, loc, sk, scale=(1.6, 1, 0.9)); a.rotation_euler = (0, 0, rotz)
    dx, dy = math.cos(rotz) * 0.2 * s, math.sin(rotz) * 0.2 * s
    b = K.cyl(0.035 * s, 0.16 * s, (loc[0] + dx, loc[1] + dy, loc[2]), K.mat('bone', (0.9, 0.85, 0.75), rough=0.5)); b.rotation_euler = (0, math.radians(90), rotz)
    return [a, b]

@item
def packed_chicken():
    objs = [_tray()]
    for i, (x, y, r) in enumerate([(-0.22, -0.1, 0.3), (0.05, 0.12, 3.4), (0.24, -0.08, 0.2), (-0.12, 0.14, 3.0)]):
        objs += _drumstick((x * 1.05, y * 1.05, 0.12), r, 1.25)
    film = K.mat('film', (0.98, 0.99, 1.0), rough=0.02, trans=1.0, ior=1.15)
    f = K.box((1.0, 0.68, 0.006), (0, 0, 0.245), film, bevel=0.003); objs.append(f)
    def dr(d, im):
        d.rectangle((0, 0, 599, 299), fill=(255, 255, 255, 255)); d.rectangle((0, 0, 599, 70), fill=(200, 30, 40, 255))
        K.center_text(d, 600, 8, 'FRESH CHICKEN', K.font(50, K.FONT_C), (255, 255, 255, 255))
        d.text((24, 100), 'DRUMSTICKS', font=K.font(44, K.FONT_B), fill=(30, 30, 30, 255))
        d.text((24, 170), 'EX FARMS', font=K.font(40, K.FONT_R), fill=(80, 80, 80, 255))
        d.text((380, 170), '1.2 kg', font=K.font(48, K.FONT_B), fill=(200, 30, 40, 255))
    p = K.label_img('packed_chicken', 600, 300, (0, 0, 0, 0), dr)
    objs.append(K.sticker(p, 0.34, 0.17, (0.22, -0.16, 0.25), (0, 0, math.radians(-6))))
    return objs, {'el': 42}

def _bird_body(skin=True):
    parts = []
    def ell(co, r, s):
        parts.append(K.sphere(r, co, None, scale=s))
    if skin:
        ell((0, 0, 0.26), 0.34, (1.15, 0.82, 0.6))       # body (on its back)
        ell((0.18, 0, 0.36), 0.22, (0.85, 0.95, 0.55))   # breast on top
        for s in (-1, 1):
            ell((0.02, s * 0.25, 0.32), 0.15, (1.0, 0.7, 0.8))     # thighs
            ell((0.2, s * 0.17, 0.5), 0.085, (1.6, 0.8, 0.8))      # drumsticks up, forward
            ell((-0.12, s * 0.3, 0.2), 0.09, (1.5, 0.45, 0.5))     # wings tucked
    else:
        ell((0, 0, 0.32), 0.3, (1.1, 0.78, 0.8))         # body
        ell((0.18, 0, 0.36), 0.24, (0.8, 0.85, 0.85))    # chest
        ell((0.3, 0, 0.6), 0.12, (0.9, 0.85, 1.1))       # neck
        ell((0.34, 0, 0.72), 0.1, (1.1, 0.8, 0.95))      # head
        ell((-0.3, 0, 0.5), 0.17, (0.75, 0.45, 1.05))    # tail
        for s in (-1, 1): ell((-0.02, s * 0.22, 0.38), 0.18, (1.3, 0.35, 0.65))  # wings
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join(); o = bpy.context.object
    md = o.modifiers.new('rm', 'REMESH'); md.mode = 'VOXEL'; md.voxel_size = 0.012
    sm = o.modifiers.new('sm', 'SMOOTH'); sm.iterations = 5; sm.factor = 0.6
    with bpy.context.temp_override(object=o):
        bpy.ops.object.modifier_apply(modifier='rm'); bpy.ops.object.modifier_apply(modifier='sm')
    K.smooth(o)
    return o

@item
def slaughtered_chicken():
    o = _bird_body(True); K.assign(o, _skin())
    objs = [o]
    for s in (-1, 1):
        b = K.cyl(0.026, 0.1, (0.33, s * 0.17, 0.57), K.mat('bone', (0.92, 0.86, 0.74), rough=0.5)); b.rotation_euler = (0, math.radians(70), 0); objs.append(b)
    return objs, {'az': 40}

@item
def live_chicken():
    body = _bird_body(False)
    feather = bpy.data.materials.new('feather'); feather.use_nodes = True; nt = feather.node_tree; bs = nt.nodes['Principled BSDF']
    bs.inputs['Roughness'].default_value = 0.7
    cn = nt.nodes.new('ShaderNodeTexNoise'); cn.inputs['Scale'].default_value = 9; cn.inputs['Detail'].default_value = 8
    cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].color = (0.08, 0.025, 0.008, 1); cr.color_ramp.elements[1].color = (0.3, 0.09, 0.025, 1)
    bs.inputs['Sheen Weight'].default_value = 1.0; bs.inputs['Sheen Roughness'].default_value = 0.4; bs.inputs['Subsurface Weight'].default_value = 0.15
    tc = nt.nodes.new('ShaderNodeTexCoord'); vo = nt.nodes.new('ShaderNodeTexVoronoi'); vo.inputs['Scale'].default_value = 55
    vo.feature = 'F1'; mp = nt.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (1.0, 1.0, 2.2)
    nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 400; nz.inputs['Detail'].default_value = 10
    mx = nt.nodes.new('ShaderNodeMath'); mx.operation = 'ADD'
    bm = nt.nodes.new('ShaderNodeBump'); bm.inputs['Strength'].default_value = 0.8; bm.inputs['Distance'].default_value = 0.04
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector']); nt.links.new(mp.outputs[0], vo.inputs['Vector'])
    nt.links.new(tc.outputs['Object'], cn.inputs['Vector']); nt.links.new(cn.outputs['Fac'], cr.inputs[0]); nt.links.new(cr.outputs[0], bs.inputs['Base Color'])
    bs.inputs['Sheen Tint'].default_value = (1.0, 0.75, 0.5, 1)
    nt.links.new(vo.outputs['Distance'], mx.inputs[0]); nt.links.new(nz.outputs['Fac'], mx.inputs[1])
    nt.links.new(mx.outputs[0], bm.inputs['Height']); nt.links.new(bm.outputs['Normal'], bs.inputs['Normal'])
    K.assign(body, feather)
    red = K.mat('comb', (0.6, 0.04, 0.03), rough=0.45, sss=0.4)
    beak = K.mat('beak', (0.85, 0.6, 0.15), rough=0.35)
    eye = K.mat('eye', (0.02, 0.01, 0.0), rough=0.05, coat=1)
    objs = [body]
    for i in range(4):
        objs.append(K.sphere(0.035 - i * 0.003, (0.3 + i * 0.035, 0, 0.82 + (0.012 if i in (1, 2) else 0)), red, scale=(0.8, 0.45, 1.3)))
    objs.append(K.sphere(0.03, (0.43, 0, 0.64), red, scale=(0.7, 0.5, 1.4)))
    bpy.ops.mesh.primitive_cone_add(radius1=0.03, depth=0.08, location=(0.46, 0, 0.71), rotation=(0, math.radians(100), 0)); bk = bpy.context.object; K.assign(bk, beak); objs.append(bk)
    for s in (-1, 1): objs.append(K.sphere(0.014, (0.41, s * 0.06, 0.75), eye))
    legm = K.mat('leg', (0.75, 0.55, 0.18), rough=0.55, bump=0.4, bump_scale=300)
    for s in (-1, 1):
        objs.append(K.cyl(0.024, 0.16, (0.02, s * 0.1, 0.0), legm))
        for a in (-30, 0, 30):
            t = K.cyl(0.012, 0.09, (0.06, s * 0.1, -0.075), legm); t.rotation_euler = (0, math.radians(90), math.radians(a)); objs.append(t)
    return objs, {'az': 50, 'el': 18}

@item
def grape_bunch():
    return G.bunch(Vector((0, 0, 0.7)), scale=1.0, seed=11, tilt=(math.radians(15), 0, 0)), {'el': 20}

@item
def raisins():
    bw = S.imp('wooden_bowl_01'); S.normalize(bw, 1.0); bpy.context.view_layer.update()
    lo, hi = S.bounds(bw); rim = hi.z
    rm = K.mat('raisin', (0.2, 0.07, 0.03), rough=0.4, bump=1.0, bump_scale=1400, coat=0.35)
    random.seed(4); objs = list(bw)
    for i in range(260):
        a = random.random() * 2 * math.pi; rr = math.sqrt(random.random()) * 0.4
        z = rim - 0.06 + (0.4 - rr) * 0.25 + random.random() * 0.04
        o = K.sphere(0.028, (rr * math.cos(a), rr * math.sin(a), z), rm, scale=(1.35, 0.85, 0.65)); o.rotation_euler = (random.random() * 3, random.random() * 3, random.random() * 3)
        objs.append(o)
    return objs, {'el': 36}

@item
def grape_kit():
    bk = S.imp('wicker_basket_01'); S.normalize(bk, 1.0); bpy.context.view_layer.update()
    lo, hi = S.bounds(bk); top = hi.z; objs = list(bk)
    for k, (dx, dy, rx, rz) in enumerate([(-0.2, 0.06, 80, 20), (0.17, -0.02, 75, 200), (0.0, 0.14, 85, 110), (-0.02, -0.12, 70, 300)]):
        objs += G.bunch(Vector((dx, dy, top + 0.05)), scale=0.9, seed=k + 7, tilt=(math.radians(rx), 0, math.radians(rz)))
    return objs, {}
