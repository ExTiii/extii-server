import bpy, math, random
from mathutils import Vector
import studio as S, kit as K
R = {}
def item(f): R[f.__name__] = f; return f
rad = math.radians

def tint(objs, color, k=1.0):
    # multiply the scanned colour texture by a colour (recolour a white bottle)
    for o in objs:
        if o.type != 'MESH': continue
        for sl in o.material_slots:
            m = sl.material; nt = m.node_tree; b = nt.nodes.get('Principled BSDF')
            if not b: continue
            src = b.inputs['Base Color'].links[0].from_socket if b.inputs['Base Color'].links else None
            mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'; mx.inputs['Factor'].default_value = k
            mx.inputs[7].default_value = (*color, 1)
            if src: nt.links.new(src, mx.inputs[6])
            else: mx.inputs[6].default_value = b.inputs['Base Color'].default_value
            nt.links.new(mx.outputs[2], b.inputs['Base Color'])

def _label(name, bg, fg, title, sub, accent=None):
    def dr(d, im):
        d.rounded_rectangle((0, 0, 799, 599), 30, fill=bg)
        if accent: d.rectangle((0, 430, 799, 470), fill=accent)
        K.center_text(d, 800, 70, title, K.font(118 if len(title) < 9 else 92, K.FONT_C), fg)
        K.center_text(d, 800, 260, sub, K.font(56, K.FONT_B), fg)
        K.center_text(d, 800, 500, 'EX AUTO PARTS', K.font(40, K.FONT_R), fg)
    return K.label_img(name, 800, 600, (0, 0, 0, 0), dr)

def jug(name, color, bg, fg, title, sub, accent=None, rot=0):
    j = S.imp('plastic_bottle_gallon'); S.normalize(j, 1.0)
    for o in j:
        if o.parent is None: pass
    root = j[0].parent; root.rotation_euler = (0, 0, rad(rot)); bpy.context.view_layer.update()
    tint(j, color)
    lo, hi = S.bounds(j)
    st = K.sticker(_label(name, bg, fg, title, sub, accent), (hi.x - lo.x) * 0.62, (hi.z - lo.z) * 0.38,
                   ((lo.x + hi.x) / 2, lo.y - 0.006, lo.z + (hi.z - lo.z) * 0.36), (rad(90), 0, 0))
    return j + [st]

@item
def engine_oil(): return jug('engine_oil', (0.05, 0.05, 0.055), (240, 190, 20, 255), (20, 20, 20, 255), 'MOTOR OIL', 'FULL SYNTHETIC 5W-30', (20, 20, 20, 255)), {}
@item
def coolant(): return jug('coolant', (0.25, 0.75, 0.3), (250, 250, 250, 255), (20, 110, 40, 255), 'COOLANT', 'ANTIFREEZE  -37°C', (20, 110, 40, 255)), {}
@item
def brake_fluid(): return jug('brake_fluid', (0.95, 0.85, 0.4), (30, 60, 140, 255), (255, 255, 255, 255), 'BRAKE FLUID', 'DOT 4  ·  1 L', (240, 190, 20, 255)), {}
@item
def transmission_fluid(): return jug('transmission_fluid', (0.6, 0.06, 0.05), (245, 245, 245, 255), (160, 20, 20, 255), 'ATF', 'TRANSMISSION FLUID', (160, 20, 20, 255)), {}

@item
def car_soap():
    o = S.imp('multi_cleaner_bottle'); S.normalize(o, 1.0); return o, {}
@item
def car_wax():
    o = S.imp('leather_cleaner_can'); S.normalize(o, 1.0); return o, {'el': 30}
@item
def paint_can():
    o = S.imp('spray_paint_bottles_02'); S.normalize(o, 1.0); return o, {}
@item
def car_tire():
    o = S.imp('old_tyre'); S.normalize(o, 1.0); return o, {'el': 22}
@item
def repairkit():
    o = S.imp('metal_toolbox'); S.normalize(o, 1.0); return o, {}
@item
def advancedrepairkit():
    o = S.imp('metal_tool_chest'); S.normalize(o, 1.0); return o, {}
@item
def engine_crate():
    o = S.imp('wooden_military_crate'); S.normalize(o, 1.0); return o, {}

@item
def air_filter():
    frame_m = K.mat('frame', (0.03, 0.03, 0.035), rough=0.6); paper = K.mat('paper', (0.95, 0.42, 0.08), rough=0.85, bump=0.15, bump_scale=120)
    objs = [K.box((1.0, 0.62, 0.05), (0, 0, 0.025), frame_m, bevel=0.012)]
    n = 26
    for i in range(n):
        x = -0.44 + i * (0.88 / (n - 1))
        p = K.box((0.012, 0.52, 0.11), (x, 0, 0.1), paper); p.rotation_euler = (0, rad(18 if i % 2 else -18), 0); objs.append(p)
    rim = K.box((1.0, 0.62, 0.025), (0, 0, 0.15), frame_m, bevel=0.01); hole = K.box((0.9, 0.52, 0.1), (0, 0, 0.15)); K.boolean(rim, hole); objs.append(rim)
    return objs, {'el': 40}

def _plug(x, y, rz=0):
    cer = K.mat('ceramic', (0.93, 0.93, 0.9), rough=0.12, coat=0.8)
    hexm = K.mat('hexm', (0.55, 0.56, 0.6), rough=0.25, metal=1)
    objs = [K.cyl(0.05, 0.26, (x, y, 0.47), cer, bevel=0.01),
            K.cyl(0.03, 0.09, (x, y, 0.64), hexm),
            K.cyl(0.085, 0.1, (x, y, 0.28), hexm, verts=6, bevel=0.006),
            K.cyl(0.06, 0.04, (x, y, 0.35), hexm),
            K.cyl(0.055, 0.17, (x, y, 0.14), K.mat('thread', (0.78, 0.7, 0.5), rough=0.3, metal=1, bump=1.0, bump_scale=700)),
            K.box((0.025, 0.02, 0.035), (x + 0.025, y, 0.04), hexm)]
    return objs

@item
def spark_plugs():
    objs = []
    for x, y in ((-0.13, 0), (0.13, 0.05)): objs += _plug(x, y)
    return objs, {'el': 20}

@item
def brake_pads():
    back = K.mat('backing', (0.08, 0.08, 0.09), rough=0.35, metal=1); fr = K.mat('friction', (0.16, 0.15, 0.14), rough=0.95, bump=0.4, bump_scale=500)
    objs = []
    for i, (x, rz) in enumerate(((-0.12, 10), (0.18, -8))):
        b = K.box((0.62, 0.05, 0.3), (x, i * 0.18, 0.15), back, bevel=0.03); b.rotation_euler = (0, 0, rad(rz))
        f = K.box((0.56, 0.05, 0.25), (x, i * 0.18 - 0.05, 0.15), fr, bevel=0.03); f.rotation_euler = (0, 0, rad(rz))
        objs += [b, f]
    return objs, {'el': 20}

@item
def clutch_kit():
    fr = K.mat('clutchfric', (0.28, 0.22, 0.17), rough=0.9, bump=0.4, bump_scale=300)
    disc = K.cyl(0.5, 0.04, (0, 0, 0.03), fr); hole = K.cyl(0.18, 0.2, (0, 0, 0.03)); K.boolean(disc, hole)
    plate = K.cyl(0.36, 0.05, (0, 0, 0.07), K.steel()); h2 = K.cyl(0.12, 0.2, (0, 0, 0.07)); K.boolean(plate, h2)
    hub = K.cyl(0.12, 0.12, (0, 0, 0.1), K.dark_steel(), verts=24)
    objs = [disc, plate, hub]
    for i in range(6):
        a = i * math.pi / 3
        s = K.cyl(0.035, 0.11, (0.24 * math.cos(a), 0.24 * math.sin(a), 0.11), K.mat('spring', (0.2, 0.35, 0.6), rough=0.3, metal=1)); s.rotation_euler = (0, rad(90), a + math.pi / 2); objs.append(s)
    for i in range(18):
        a = i * 2 * math.pi / 18
        objs.append(K.cyl(0.018, 0.045, (0.42 * math.cos(a), 0.42 * math.sin(a), 0.035), K.copper()))
    return objs, {'el': 45}

def _rim_and_tyre(R=0.5, w=0.32, spokes=5, rim_m=None):
    rim_m = rim_m or K.mat('rimm', (0.75, 0.76, 0.78), rough=0.18, metal=1)
    t = K.cyl(R, w, (0, 0, R), K.rubber(), rot=(rad(90), 0, 0), verts=96); K.smooth(t, bevel=0.09, seg=6)
    hole = K.cyl(R * 0.7, w * 2, (0, 0, R), rot=(rad(90), 0, 0), verts=96); K.boolean(t, hole)
    barrel = K.cyl(R * 0.7, w * 0.9, (0, 0, R), rim_m, rot=(rad(90), 0, 0), verts=96); h2 = K.cyl(R * 0.64, w * 2, (0, 0, R), rot=(rad(90), 0, 0), verts=96); K.boolean(barrel, h2)
    objs = [t, barrel, K.cyl(0.1, 0.1, (0, -w * 0.3, R), rim_m, rot=(rad(90), 0, 0))]
    for i in range(spokes):
        piv = bpy.data.objects.new('sp', None); bpy.context.scene.collection.objects.link(piv); piv.location = (0, -w * 0.3, R)
        sp = K.box((0.09, 0.06, R * 0.56), (0, 0, R * 0.36), rim_m, bevel=0.015); sp.parent = piv
        piv.rotation_euler = (0, i * 2 * math.pi / spokes, 0); objs.append(sp)
    for i in range(5):
        a = i * 2 * math.pi / 5
        objs.append(K.cyl(0.014, 0.04, (0.06 * math.sin(a), -w * 0.37, R + 0.06 * math.cos(a)), K.chrome(), rot=(rad(90), 0, 0)))
    return objs

@item
def wheel_set():
    return _rim_and_tyre(), {'az': 25, 'el': 15}

@item
def ev_battery():
    case = K.mat('evcase', (0.2, 0.22, 0.25), rough=0.4, metal=0.6)
    objs = [K.box((1.0, 0.6, 0.18), (0, 0, 0.09), case, bevel=0.03)]
    for i in range(5): objs.append(K.box((0.96, 0.02, 0.012), (0, -0.24 + i * 0.12, 0.185), K.mat('rib', (0.15, 0.16, 0.18), rough=0.4, metal=0.6)))
    orange = K.mat('hv', (0.95, 0.35, 0.02), rough=0.4)
    c = K.box((0.12, 0.1, 0.07), (0.38, -0.3, 0.13), orange, bevel=0.01); objs.append(c)
    def dr(d, im):
        d.rectangle((0, 0, 499, 199), fill=(240, 190, 20, 255)); d.polygon([(40, 160), (100, 40), (160, 160)], outline=(20, 20, 20, 255), width=10)
        d.text((80, 80), '!', font=K.font(70), fill=(20, 20, 20, 255)); d.text((190, 50), 'HIGH VOLTAGE', font=K.font(40, K.FONT_C), fill=(20, 20, 20, 255)); d.text((190, 110), '400 V  ·  75 kWh', font=K.font(34, K.FONT_R), fill=(20, 20, 20, 255))
    objs.append(K.sticker(K.label_img('evbat', 500, 200, (0, 0, 0, 0), dr), 0.42, 0.17, (-0.15, 0.0, 0.1805), (0, 0, 0)))
    return objs, {'el': 38}

@item
def ev_motor():
    body = K.mat('motor', (0.55, 0.57, 0.6), rough=0.3, metal=1)
    objs = [K.cyl(0.32, 0.7, (0, 0, 0.32), body, rot=(0, rad(90), 0))]
    for i in range(12): objs.append(K.torus(0.325, 0.012, (-0.3 + i * 0.055, 0, 0.32), body, rot=(0, rad(90), 0)))
    objs.append(K.cyl(0.33, 0.06, (0.36, 0, 0.32), K.dark_steel(), rot=(0, rad(90), 0)))
    objs.append(K.cyl(0.05, 0.22, (0.48, 0, 0.32), K.steel(), rot=(0, rad(90), 0)))
    orange = K.mat('hv', (0.95, 0.35, 0.02), rough=0.4)
    objs.append(K.box((0.18, 0.14, 0.1), (-0.05, 0, 0.66), orange, bevel=0.02))
    for k in (-0.04, 0.04):
        cb = K.cyl(0.022, 0.4, (-0.05 + k, -0.18, 0.62), orange, rot=(rad(70), 0, 0)); objs.append(cb)
    return objs, {}

@item
def engine_kit():
    al = K.alu(); objs = []
    for i, (x, y) in enumerate(((-0.2, 0), (0.18, 0.12))):
        objs.append(K.cyl(0.17, 0.2, (x, y, 0.5), al))
        for k in range(3): objs.append(K.torus(0.171, 0.006, (x, y, 0.56 - k * 0.03), K.dark_steel()))
        objs.append(K.cyl(0.035, 0.28, (x, y, 0.5), K.steel(), rot=(rad(90), 0, 0)))
        rod = K.box((0.06, 0.04, 0.42), (x, y, 0.22), K.steel(), bevel=0.012); objs.append(rod)
        objs.append(K.cyl(0.09, 0.05, (x, y, 0.02), K.steel(), rot=(rad(90), 0, 0)))
    return objs, {'el': 22}

@item
def brake_kit():
    rotor_m = K.mat('rotor', (0.5, 0.5, 0.52), rough=0.3, metal=1, aniso=0.6)
    rotor = K.cyl(0.5, 0.06, (0, 0, 0.5), rotor_m, rot=(rad(90), 0, 0), verts=128)
    for i in range(18):
        a = i * 2 * math.pi / 18; r = 0.33 + (i % 2) * 0.07
        K.boolean(rotor, K.cyl(0.018, 0.2, (r * math.sin(a), 0, 0.5 + r * math.cos(a)), rot=(rad(90), 0, 0), verts=16))
    K.boolean(rotor, K.cyl(0.16, 0.2, (0, 0, 0.5), rot=(rad(90), 0, 0)))
    hat = K.cyl(0.2, 0.12, (0, 0.03, 0.5), K.dark_steel(), rot=(rad(90), 0, 0))
    red = K.mat('caliper', (0.75, 0.03, 0.02), rough=0.25, coat=0.8)
    cal = K.box((0.4, 0.2, 0.17), (0.2, 0, 0.84), red, bevel=0.06); cal.rotation_euler = (0, rad(-26), 0)
    def dr(d, im): K.center_text(d, 400, 10, 'EX RACING', K.font(70, K.FONT_C), (255, 255, 255, 255))
    st = K.sticker(K.label_img('caliper', 400, 100, (0, 0, 0, 0), dr), 0.24, 0.06, (0.2, -0.102, 0.84), (rad(90), rad(-26), 0))
    return [rotor, hat, cal, st], {'az': 25, 'el': 15}

def _gear(r, w, teeth, loc, m, rot=(0, 0, 0)):
    g = K.cyl(r, w, (0, 0, 0), m, verts=teeth * 4)
    parts = [g]
    for i in range(teeth):
        a = i * 2 * math.pi / teeth
        t = K.box((r * 0.18, r * 0.16, w), ((r + r * 0.06) * math.cos(a), (r + r * 0.06) * math.sin(a), 0), m, bevel=0.004); t.rotation_euler = (0, 0, a); parts.append(t)
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = g; bpy.ops.object.join(); g = bpy.context.object
    K.boolean(g, K.cyl(r * 0.25, w * 3, (0, 0, 0), verts=32))
    g.location = loc; g.rotation_euler = rot
    return g

@item
def trans_kit():
    m = K.steel()
    return [_gear(0.36, 0.12, 30, (-0.18, 0, 0.42), m, (rad(90), 0, 0)), _gear(0.22, 0.12, 18, (0.4, -0.05, 0.28), m, (rad(90), 0, 0)),
            K.cyl(0.07, 0.6, (-0.18, 0, 0.42), K.dark_steel(), rot=(rad(90), 0, 0))], {'az': 25, 'el': 18}

@item
def susp_kit():
    body = K.mat('damper', (0.85, 0.05, 0.05), rough=0.25, coat=0.7)
    objs = [K.cyl(0.08, 0.7, (0, 0, 0.45), K.dark_steel()), K.cyl(0.035, 0.4, (0, 0, 0.9), K.chrome()),
            K.cyl(0.16, 0.05, (0, 0, 0.22), body), K.cyl(0.16, 0.05, (0, 0, 1.02), body)]
    bpy.ops.curve.primitive_bezier_circle_add(radius=0.15)
    sp = bpy.context.object
    bpy.ops.mesh.primitive_circle_add(radius=0.15, vertices=48); c = bpy.context.object
    scr = c.modifiers.new('scr', 'SCREW'); scr.screw_offset = 0.105; scr.iterations = 7; scr.steps = 48; scr.render_steps = 48
    bpy.data.objects.remove(sp)
    c.location = (0, 0, 0.26)
    bpy.ops.object.convert(target='CURVE'); c = bpy.context.object; c.data.bevel_depth = 0.022; c.data.bevel_resolution = 6
    c.data.materials.append(K.mat('coil', (0.95, 0.75, 0.05), rough=0.25, coat=0.6)); objs.append(c)
    objs.append(K.torus(0.06, 0.02, (0, 0, 0.08), K.dark_steel(), rot=(rad(90), 0, 0)))
    return objs, {'el': 15}

@item
def turbo_kit():
    al = K.mat('turboal', (0.72, 0.73, 0.75), rough=0.3, metal=1); hot = K.mat('cast', (0.25, 0.22, 0.2), rough=0.65, metal=1, bump=0.3, bump_scale=200)
    objs = [K.torus(0.3, 0.16, (0, -0.22, 0.45), al, rot=(rad(90), 0, 0)), K.cyl(0.32, 0.18, (0, -0.22, 0.45), al, rot=(rad(90), 0, 0)),
            K.cyl(0.19, 0.3, (0, -0.48, 0.45), al, rot=(rad(90), 0, 0)),
            K.cyl(0.18, 0.22, (0, 0.05, 0.45), K.dark_steel(), rot=(rad(90), 0, 0)),
            K.torus(0.26, 0.15, (0, 0.3, 0.45), hot, rot=(rad(90), 0, 0)), K.cyl(0.27, 0.16, (0, 0.3, 0.45), hot, rot=(rad(90), 0, 0)),
            K.cyl(0.17, 0.24, (0.36, -0.22, 0.75), al, rot=(0, rad(90), 0))]
    inlet = K.cyl(0.16, 0.05, (0, -0.64, 0.45), al, rot=(rad(90), 0, 0)); K.boolean(inlet, K.cyl(0.12, 0.2, (0, -0.64, 0.45), rot=(rad(90), 0, 0))); objs.append(inlet)
    objs.append(K.cyl(0.05, 0.06, (0, -0.62, 0.45), K.alu(), rot=(rad(90), 0, 0)))
    return objs, {'az': -40, 'el': 22}

@item
def body_kit():
    cf = bpy.data.materials.new('carbon'); cf.use_nodes = True; nt = cf.node_tree; b = nt.nodes['Principled BSDF']
    ck = nt.nodes.new('ShaderNodeTexChecker'); ck.inputs['Scale'].default_value = 140; ck.inputs['Color1'].default_value = (0.02, 0.02, 0.022, 1); ck.inputs['Color2'].default_value = (0.07, 0.07, 0.08, 1)
    nt.links.new(ck.outputs['Color'], b.inputs['Base Color']); b.inputs['Roughness'].default_value = 0.3; b.inputs['Coat Weight'].default_value = 1.0
    wing = K.box((1.2, 0.3, 0.03), (0, 0, 0.5), cf, bevel=0.012); wing.rotation_euler = (rad(-8), 0, 0)
    objs = [wing]
    for s in (-1, 1):
        objs.append(K.box((0.025, 0.36, 0.14), (s * 0.6, 0, 0.53), cf, bevel=0.008))
        objs.append(K.box((0.05, 0.12, 0.42), (s * 0.35, 0.02, 0.25), K.dark_steel(), bevel=0.01))
    return objs, {'el': 30}

@item
def tint_film():
    film = K.mat('tint', (0.02, 0.02, 0.025), rough=0.08, coat=0.5)
    core = K.mat('core', (0.6, 0.45, 0.25), rough=0.8)
    roll = K.cyl(0.13, 0.9, (0, 0, 0.13), film, rot=(0, rad(90), 0))
    end = K.cyl(0.04, 0.92, (0, 0, 0.13), core, rot=(0, rad(90), 0))
    sheet = K.box((0.88, 0.55, 0.004), (0, -0.33, 0.004), K.mat('sheet', (0.03, 0.03, 0.035), rough=0.05, trans=0.6, coat=0.6))
    return [roll, end, sheet], {'el': 32}

@item
def neon_kit():
    objs = []
    cols = [(0.1, 0.4, 1.0), (1.0, 0.1, 0.6)]
    for i, c in enumerate(cols):
        tube = K.mat(f'neon{i}', (*c,), rough=0.2, emit=c, emit_k=6.0)
        objs.append(K.cyl(0.025, 1.0, (0, -0.1 + i * 0.16, 0.05 + i * 0.03), tube, rot=(0, rad(90), rad(6 * (1 - 2 * i)))))
        for s in (-1, 1): objs.append(K.cyl(0.03, 0.06, (s * 0.5, -0.1 + i * 0.16, 0.05 + i * 0.03), K.dark_steel(), rot=(0, rad(90), 0)))
    objs.append(K.box((0.18, 0.12, 0.06), (0.15, 0.35, 0.03), K.mat('ctrl', (0.03, 0.03, 0.035), rough=0.4), bevel=0.01))
    return objs, {'el': 34}

@item
def xenon_kit():
    objs = []
    for i, x in enumerate((-0.15, 0.15)):
        objs.append(K.cyl(0.11, 0.12, (x, 0, 0.06), K.mat('base', (0.03, 0.03, 0.035), rough=0.4), verts=6))
        objs.append(K.cyl(0.06, 0.08, (x, 0, 0.16), K.steel()))
        objs.append(K.cyl(0.025, 0.4, (x, 0, 0.4), K.glass((0.85, 0.9, 1.0))))
        objs.append(K.sphere(0.03, (x, 0, 0.42), K.mat('arc', (0.6, 0.75, 1.0), emit=(0.6, 0.75, 1.0), emit_k=12)))
    return objs, {'el': 15}

def _nos_bottle(x=0.0, h=0.95, r=0.16, rot=(0, 0, 0)):
    blue = K.mat('nos', (0.03, 0.12, 0.7), rough=0.18, coat=1.0, metal=0.2)
    objs = [K.cyl(r, h, (x, 0, h / 2), blue), K.sphere(r, (x, 0, h), blue), K.cyl(0.035, 0.12, (x, 0, h + r + 0.04), K.chrome()),
            K.cyl(0.05, 0.05, (x, 0, h + r + 0.12), K.mat('valve', (0.9, 0.05, 0.05), rough=0.3))]
    def dr(d, im):
        d.rectangle((0, 0, 999, 299), fill=(250, 250, 250, 255)); K.center_text(d, 1000, 50, 'NITROUS', K.font(72, K.FONT_C), (200, 20, 20, 255))
        K.center_text(d, 1000, 170, 'EX RACING', K.font(44, K.FONT_B), (20, 40, 120, 255))
    objs.append(K.wrap_label(K.label_img('nos', 1000, 300, (0, 0, 0, 0), dr), r + 0.004, 0.24, 0.5))
    objs[-1].location.x = x; objs[-1].rotation_euler = (0, 0, rad(48))
    return objs

@item
def nitro_bottle(): return _nos_bottle(), {'el': 18}

@item
def nitro_kit():
    objs = _nos_bottle(-0.15)
    hose = K.mat('hose', (0.02, 0.02, 0.02), rough=0.6)
    objs.append(K.torus(0.28, 0.02, (0.2, 0, 0.3), hose, rot=(rad(90), 0, 0)))
    objs.append(K.box((0.14, 0.1, 0.1), (0.32, -0.05, 0.08), K.mat('sol', (0.85, 0.85, 0.88), rough=0.2, metal=1), bevel=0.015))
    objs.append(K.box((0.12, 0.08, 0.05), (0.42, 0.15, 0.03), K.mat('btn', (0.8, 0.02, 0.02), rough=0.3, coat=0.8), bevel=0.012))
    return objs, {'el': 20}
