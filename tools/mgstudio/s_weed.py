# weed table: a cured bud with its fan leaves (trim), small nugs, a pocket scale (weigh)
import sys, json, random; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
PX, PY = 1200, 690
W, H = 0.40, 0.23
PPM = PX / W

def leaf_mat():
    m = mat('leaf', (0.03, 0.11, 0.025), 0.48, 0.0, spec=0.4)
    nt = m.node_tree; b = P(m)
    b.inputs['Subsurface Weight'].default_value = 0.25
    tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(tc.outputs['UV'], sep.inputs[0])
    d = nt.nodes.new('ShaderNodeMath'); d.operation = 'SUBTRACT'; d.inputs[1].default_value = 0.5; nt.links.new(sep.outputs['Y'], d.inputs[0])
    ab = nt.nodes.new('ShaderNodeMath'); ab.operation = 'ABSOLUTE'; nt.links.new(d.outputs[0], ab.inputs[0])
    mr = nt.nodes.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 0.0; mr.inputs['From Max'].default_value = 0.05
    nt.links.new(ab.outputs[0], mr.inputs['Value'])
    n = nt.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = 60
    cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].color = (0.16, 0.3, 0.08, 1); cr.color_ramp.elements[1].color = (0.03, 0.11, 0.025, 1)
    nt.links.new(mr.outputs['Result'], cr.inputs[0]); nt.links.new(cr.outputs[0], b.inputs['Base Color'])
    return m

def leaflet(L, Wd, serr=22):
    """one serrated leaflet along +X, base at the origin: narrow lance shape, teeth pointing to the tip"""
    bm = bmesh.new(); top, bot = [], []
    for i in range(serr + 1):
        t = i / serr
        w = Wd * (math.sin(math.pi * min(1, t * 1.05)) ** 1.15) * (1 - 0.25 * t)
        top.append((L * t, w))
        if i < serr:                       # the notch between two teeth, a little behind and inside
            tn = (i + 0.35) / serr; wn = Wd * (math.sin(math.pi * min(1, tn * 1.05)) ** 1.15) * (1 - 0.25 * tn) * 0.72
            top.append((L * tn, wn))
    bot = [(x, -y) for x, y in top]
    pts = top + bot[::-1][1:-1]
    vs = [bm.verts.new((x, y, 0.0009 * math.sin(x / L * 3) - 0.0004 * abs(y) / Wd)) for x, y in pts]
    bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new('lf'); bm.to_mesh(me); o = bpy.data.objects.new('lf', me); bpy.context.scene.collection.objects.link(o)
    me.uv_layers.new()
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co; me.uv_layers[0].data[li].uv = (v.x / L, v.y / Wd * 0.5 + 0.5)
    return o

def fan_leaf(scale=1.0):
    m = leaf_mat(); parts = []
    for i, (ang, L) in enumerate(((0, 0.06), (0.42, 0.054), (-0.42, 0.054), (0.85, 0.042), (-0.85, 0.042), (1.25, 0.026), (-1.25, 0.026))):
        o = leaflet(L * scale, 0.0052 * scale); o.rotation_euler = (0, 0, ang); assign(o, m); parts.append(o)
    st = cyl(0.0008 * scale, 0.03 * scale, (-0.015 * scale, 0, 0), mat('stem', (0.1, 0.2, 0.06), 0.5), rot=(0, math.radians(90), 0)); parts.append(st)
    return parts

def bud(seed=1, size=1.0, loc=(0, 0, 0)):
    random.seed(seed); objs = []
    frost = mat('bud', (0.16, 0.24, 0.08), 0.6, 0.0, spec=0.45)
    b = P(frost); b.inputs['Subsurface Weight'].default_value = 0.2
    nt = frost.node_tree
    n = nt.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = 1400; n.inputs['Detail'].default_value = 1
    cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].position = 0.5; cr.color_ramp.elements[0].color = (0.11, 0.19, 0.05, 1)
    cr.color_ramp.elements[1].position = 0.72; cr.color_ramp.elements[1].color = (0.72, 0.76, 0.62, 1)
    nt.links.new(n.outputs['Fac'], cr.inputs[0])
    # a few purple-ish calyx tips, and darker deep in the gaps (from the voronoi)
    vo = nt.nodes.new('ShaderNodeTexVoronoi'); vo.inputs['Scale'].default_value = 260 / size
    gap = nt.nodes.new('ShaderNodeValToRGB'); gap.color_ramp.elements[0].position = 0.0; gap.color_ramp.elements[0].color = (0.25, 0.25, 0.25, 1); gap.color_ramp.elements[1].position = 0.35; gap.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(vo.outputs['Distance'], gap.inputs[0])
    mul = nt.nodes.new('ShaderNodeVectorMath'); mul.operation = 'MULTIPLY'
    nt.links.new(cr.outputs[0], mul.inputs[0]); nt.links.new(gap.outputs[0], mul.inputs[1]); nt.links.new(mul.outputs[0], b.inputs['Base Color'])
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=6, radius=0.016 * size, location=loc); c = bpy.context.object
    c.scale = (1.0, 0.72, 0.62); bpy.ops.object.transform_apply(scale=True)
    tx = bpy.data.textures.new(f'v{seed}', 'VORONOI'); tx.noise_scale = 0.0045 * size; tx.distance_metric = 'DISTANCE'
    d1 = c.modifiers.new('d1', 'DISPLACE'); d1.texture = tx; d1.strength = -0.004 * size; d1.mid_level = 1.0
    tx2 = bpy.data.textures.new(f'c{seed}', 'CLOUDS'); tx2.noise_scale = 0.012 * size
    d2 = c.modifiers.new('d2', 'DISPLACE'); d2.texture = tx2; d2.strength = 0.003 * size
    assign(c, frost)
    for p in c.data.polygons: p.use_smooth = True
    objs.append(c)
    # sugar leaves: small frosty serrated leaflets sticking out of the bud
    sl = mat('sugar', (0.2, 0.28, 0.12), 0.6, spec=0.45)
    for i in range(int(22 * size)):
        u = random.uniform(0, 6.28)
        o = leaflet(0.012 * size * random.uniform(0.7, 1.2), 0.0022 * size, 8); assign(o, sl)
        r = 0.013 * size
        o.location = (loc[0] + math.cos(u) * r * 0.8, loc[1] + math.sin(u) * r * 0.58, loc[2] + random.uniform(0.002, 0.008) * size)
        o.rotation_euler = (random.uniform(-0.3, 0.3), random.uniform(-0.5, 0.2), u); objs.append(o)
    # pistils: thin orange hairs, curled
    pist = mat('pist', (0.5, 0.2, 0.05), 0.65)
    for i in range(int(70 * size)):
        u = random.uniform(0, 6.28); r = 0.016 * size * random.uniform(0.2, 0.95)
        sx, sy = loc[0] + math.cos(u) * r, loc[1] + math.sin(u) * r * 0.7
        cd = bpy.data.curves.new('p', 'CURVE'); cd.dimensions = '3D'; cd.bevel_depth = 0.00012 * size
        sp = cd.splines.new('BEZIER'); sp.bezier_points.add(2)
        z0 = loc[2] + 0.009 * size * (1 - (r / (0.016 * size)) ** 2) ** 0.5
        for k, p in enumerate(sp.bezier_points):
            p.co = (sx + math.cos(u + k * 0.6) * 0.0018 * size * k, sy + math.sin(u + k * 0.6) * 0.0018 * size * k, z0 + 0.0012 * size * k)
            p.handle_left_type = p.handle_right_type = 'AUTO'
        o = bpy.data.objects.new('pist', cd); bpy.context.scene.collection.objects.link(o); o.data.materials.append(pist); objs.append(o)
    return objs

def lamps(): worklight(2.0)

def trim_bg():
    reset('autoshop_01', 0.05, rot=0.4)
    plane(1.6, 1.6, (0, 0, -0.002), pbr('wood', 'wood_table_worn', 2.0, tint=(0.55, 0.5, 0.46)))
    # a white trim tray, the bud in the middle (its leaves are sprites the page places)
    tray = box((0.34, 0.2, 0.012), (0, 0, 0.004), mat('tray', (0.6, 0.6, 0.58), 0.4, spec=0.4), bevel=0.004)
    boolean(tray, box((0.32, 0.18, 0.02), (0, 0, 0.014), bevel=0.0))
    # scissors left on the tray
    st = mat('sc', (0.7, 0.7, 0.72), 0.2, 1.0)
    box((0.07, 0.006, 0.0015), (0.12, -0.07, 0.007), st, rot=(0, 0, 0.35), bevel=0.0005)
    box((0.07, 0.006, 0.0015), (0.12, -0.07, 0.0085), st, rot=(0, 0, 0.55), bevel=0.0005)
    for a, c in ((0.35, (0.1, 0.3, 0.12)), (0.55, (0.1, 0.3, 0.12))):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.011, minor_radius=0.003, location=(0.12 - math.cos(a) * 0.05, -0.07 - math.sin(a) * 0.05, 0.008)); assign(bpy.context.object, mat('grip' + str(a), c, 0.5))
    bud(1, 2.0, (0, 0, 0.022))
    lamps()
    top_cam(W, H, PX, PY, height=1.0)
    render('out/trim_bg.png')

def leaf_sprite():
    reset('autoshop_01', 0.05, rot=0.4, transparent=True)
    parts = fan_leaf(1.0)
    lamps()
    sprite(parts, 'out/fanleaf.png', PPM * 0.9, anchor=(-0.03, 0))

def nug_sprite():
    reset('autoshop_01', 0.05, rot=0.4, transparent=True)
    objs = bud(7, 0.6, (0, 0, 0.004))
    lamps()
    sprite([o for o in objs if o.type == 'MESH'], 'out/nug.png', PPM * 1.2)

def scale_bg():
    reset('autoshop_01', 0.05, rot=0.4)
    plane(1.6, 1.6, (0, 0, -0.002), pbr('wood', 'wood_table_worn', 2.0, tint=(0.55, 0.5, 0.46)))
    body = box((0.11, 0.15, 0.018), (0, -0.005, 0.009), mat('sbody', (0.02, 0.02, 0.022), 0.45, coat=0.4, spec=0.4), bevel=0.004)
    plat = box((0.095, 0.095, 0.003), (0, 0.02, 0.0195), mat('splat', (0.75, 0.75, 0.77), 0.18, 1.0, noise=0.02), bevel=0.0008)
    lcd = box((0.05, 0.016, 0.001), (0, -0.05, 0.0185), mat('slcd', (0.05, 0.065, 0.05), 0.2, coat=1.0), bevel=0.0005)
    for i, x in enumerate((-0.03, 0.03)):
        cyl(0.005, 0.002, (x, -0.069, 0.019), mat(f'sb{i}', (0.08, 0.08, 0.085), 0.5), bevel=0.0007)
    for i, (x, txt) in enumerate(((-0.03, 'ON/OFF'), (0.03, 'TARE'))):
        bpy.ops.object.text_add(location=(x, -0.077, 0.01805)); t = bpy.context.object; t.data.body = txt; t.data.size = 0.0032; t.data.align_x = 'CENTER'
        assign(t, mat(f'st{i}', (0.6, 0.6, 0.6), 0.5))
    bpy.ops.object.text_add(location=(0, -0.0345, 0.01805)); t = bpy.context.object; t.data.body = 'POCKET SCALE  100 g x 0.01'; t.data.size = 0.0026; t.data.align_x = 'CENTER'
    assign(t, mat('sbrand', (0.55, 0.55, 0.55), 0.5))
    # a few empty bags and a jar of the rest
    for i in range(3):
        bx, by = -0.15 + i * 0.012, 0.03 - i * 0.02
        box((0.04, 0.05, 0.0006), (bx, by, 0.0004 + i * 0.0007), mat(f'bag{i}', (0.9, 0.92, 0.95), 0.12, trans=1.0, ior=1.3, spec=0.5), rot=(0, 0, 0.2 * i))
        box((0.04, 0.0025, 0.0009), (bx - math.sin(0.2 * i) * 0.021, by + math.cos(0.2 * i) * 0.021, 0.0008 + i * 0.0007), mat(f'zip{i}', (0.5, 0.04, 0.03), 0.4), rot=(0, 0, 0.2 * i))
    lamps()
    top_cam(W, H, PX, PY, height=1.0)
    render('out/scale_bg.png')
    json.dump({'plate': [round(PX / 2), round(PY / 2 - 0.02 * PPM)], 'lcd': [round(PX / 2 - 0.025 * PPM), round(PY / 2 + 0.042 * PPM), round(0.05 * PPM), round(0.016 * PPM)]}, open('out/scale_bg.json', 'w'))

{'trim_bg': trim_bg, 'leaf': leaf_sprite, 'nug': nug_sprite, 'scale_bg': scale_bg}[sys.argv[-1]]()
