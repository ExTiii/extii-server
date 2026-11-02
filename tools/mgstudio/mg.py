# EX_Tii minigame studio: top-down / 3-4 renders of real objects for the NUI minigames
import bpy, math, os, sys, bmesh
from mathutils import Vector
ICONS = '/home/claude/icons'
sys.path.insert(0, ICONS)
QUICK = os.environ.get('QUICK') == '1'

def reset(hdri='autoshop_01', strength=1.0, rot=0.0, transparent=False, look='AgX - Medium High Contrast'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'; s.cycles.device = 'CPU'
    s.cycles.samples = 16 if QUICK else 96
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 6
    s.render.film_transparent = transparent
    s.render.image_settings.file_format = 'PNG'; s.render.image_settings.color_mode = 'RGBA'
    s.view_settings.view_transform = 'AgX'; s.view_settings.look = look
    w = bpy.data.worlds.new('w'); s.world = w; w.use_nodes = True
    nt = w.node_tree; bg = nt.nodes['Background']
    env = nt.nodes.new('ShaderNodeTexEnvironment')
    env.image = bpy.data.images.load(f'{ICONS}/hdri/{hdri}.hdr')
    mp = nt.nodes.new('ShaderNodeMapping'); tc = nt.nodes.new('ShaderNodeTexCoord')
    mp.inputs['Rotation'].default_value[2] = rot
    nt.links.new(tc.outputs['Generated'], mp.inputs[0]); nt.links.new(mp.outputs[0], env.inputs[0])
    nt.links.new(env.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = strength
    return s

def imp(mid):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f'{ICONS}/assets/{mid}/{mid}.gltf')
    objs = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new(mid, None); bpy.context.scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None: o.parent = root
    return root, objs

def bounds(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == 'MESH' for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi

def P(m): return m.node_tree.nodes['Principled BSDF']

def mat(name, color=(0.5, 0.5, 0.5), rough=0.5, metal=0.0, coat=0.0, coat_rough=0.03, emit=None, emit_k=0.0, aniso=0.0, flakes=0.0, trans=0.0, ior=1.45, noise=0.0, noise_scale=40.0, alpha=1.0, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = P(m); nt = m.node_tree
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Specular IOR Level'].default_value = spec
    b.inputs['Coat Roughness'].default_value = coat_rough
    if aniso: b.inputs['Anisotropic'].default_value = aniso
    if trans: b.inputs['Transmission Weight'].default_value = trans; b.inputs['IOR'].default_value = ior
    if alpha < 1: b.inputs['Alpha'].default_value = alpha
    if emit: b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = emit_k
    if noise or flakes:
        tx = nt.nodes.new('ShaderNodeTexNoise'); tx.inputs['Scale'].default_value = noise_scale; tx.inputs['Detail'].default_value = 8
        mr = nt.nodes.new('ShaderNodeMapRange')
        mr.inputs['To Min'].default_value = max(0, rough - noise); mr.inputs['To Max'].default_value = min(1, rough + noise)
        nt.links.new(tx.outputs['Fac'], mr.inputs['Value']); nt.links.new(mr.outputs['Result'], b.inputs['Roughness'])
        bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.08 + flakes
        fine = nt.nodes.new('ShaderNodeTexNoise'); fine.inputs['Scale'].default_value = noise_scale * 12
        nt.links.new(fine.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    return m

def pbr(name, tid, scale=1.0, tint=None, rough_mul=1.0, metal=None, disp=0.0, sat=1.0, nor=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = P(m); d = f'{ICONS}/assets/tex/{tid}'
    tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (scale, scale, scale)
    # object space (metres): the texture keeps its real size whatever the object's shape (scale = repeats per metre)
    nt.links.new(tc.outputs['Object'], mp.inputs[0])
    def img(fn, nonc=False):
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(f'{d}/{fn}'); t.projection = 'BOX'; t.projection_blend = 0.2
        if nonc: t.image.colorspace_settings.name = 'Non-Color'
        nt.links.new(mp.outputs[0], t.inputs[0]); return t
    dif = img('Diffuse.jpg')
    col = dif.outputs[0]
    if sat != 1.0:
        hs = nt.nodes.new('ShaderNodeHueSaturation'); hs.inputs['Saturation'].default_value = sat
        nt.links.new(col, hs.inputs['Color']); col = hs.outputs[0]
    if tint:
        vm = nt.nodes.new('ShaderNodeVectorMath'); vm.operation = 'MULTIPLY'; vm.inputs[1].default_value = tint
        nt.links.new(col, vm.inputs[0]); col = vm.outputs[0]
    nt.links.new(col, b.inputs['Base Color'])
    arm = img('arm.jpg', True); sep = nt.nodes.new('ShaderNodeSeparateColor'); nt.links.new(arm.outputs[0], sep.inputs[0])
    rm = nt.nodes.new('ShaderNodeMath'); rm.operation = 'MULTIPLY'; rm.inputs[1].default_value = rough_mul
    nt.links.new(sep.outputs[1], rm.inputs[0]); nt.links.new(rm.outputs[0], b.inputs['Roughness'])
    if metal is None: nt.links.new(sep.outputs[2], b.inputs['Metallic'])
    else: b.inputs['Metallic'].default_value = metal
    nor_t = img('nor_gl.jpg', True); nm = nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = nor; nt.links.new(nor_t.outputs[0], nm.inputs['Color'])
    nt.links.new(nm.outputs[0], b.inputs['Normal'])
    return m

def assign(o, m):
    o.data.materials.clear(); o.data.materials.append(m); return o

def smooth(o, bevel=0.0, seg=3, sub=0, angle=40):
    bpy.context.view_layer.objects.active = o
    if bevel:
        md = o.modifiers.new('b', 'BEVEL'); md.width = bevel; md.segments = seg; md.limit_method = 'ANGLE'
    if sub:
        md = o.modifiers.new('s', 'SUBSURF'); md.levels = md.render_levels = sub
    for p in o.data.polygons: p.use_smooth = True
    try: o.data.set_sharp_from_angle(angle=math.radians(angle))
    except Exception: pass
    return o

def box(size, loc=(0, 0, 0), m=None, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot); o = bpy.context.object
    o.scale = size; bpy.ops.object.transform_apply(scale=True)
    if m: assign(o, m)
    return smooth(o, bevel)

def cyl(r, h, loc=(0, 0, 0), m=None, bevel=0.0, rot=(0, 0, 0), verts=96):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=verts); o = bpy.context.object
    if m: assign(o, m)
    return smooth(o, bevel)

def plane(sx, sy, loc=(0, 0, 0), m=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot); o = bpy.context.object
    o.scale = (sx, sy, 1); bpy.ops.object.transform_apply(scale=True)
    if m: assign(o, m)
    return o

def boolean(t, c, op='DIFFERENCE'):
    md = t.modifiers.new('bo', 'BOOLEAN'); md.object = c; md.operation = op; md.solver = 'EXACT'
    bpy.context.view_layer.objects.active = t; bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.data.objects.remove(c, do_unlink=True); return t

def light(kind, loc, energy, size=1.0, target=(0, 0, 0), color=(1, 1, 1), spot=None):
    bpy.ops.object.light_add(type=kind, location=loc); L = bpy.context.object
    L.data.energy = energy; L.data.color = color
    if kind == 'AREA': L.data.size = size
    if kind in ('POINT', 'SPOT'): L.data.shadow_soft_size = size
    if spot: L.data.spot_size = spot
    L.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return L

def top_cam(w, h, px, py, height=5.0, center=(0, 0)):
    """orthographic, straight down: w x h metres -> px x py pixels"""
    s = bpy.context.scene
    cd = bpy.data.cameras.new('c'); cd.type = 'ORTHO'; cd.ortho_scale = max(w, h)
    cam = bpy.data.objects.new('cam', cd); s.collection.objects.link(cam); s.camera = cam
    cam.location = (center[0], center[1], height); cam.rotation_euler = (0, 0, 0)
    s.render.resolution_x = px; s.render.resolution_y = py
    return cam

def persp_cam(loc, target, lens, px, py):
    s = bpy.context.scene
    cd = bpy.data.cameras.new('c'); cd.lens = lens
    cam = bpy.data.objects.new('cam', cd); s.collection.objects.link(cam); s.camera = cam
    cam.location = loc; cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    s.render.resolution_x = px; s.render.resolution_y = py
    return cam

def render(path):
    s = bpy.context.scene; s.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)
    print('RENDERED', path, flush=True)

def hexprism(r, h, loc=(0, 0, 0), m=None, chamfer=True, bevel=0.0006):
    """a hex nut / bolt head (r = corner radius), with the cone chamfer real ones have on top"""
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, vertices=6); o = bpy.context.object
    if chamfer:
        bpy.ops.mesh.primitive_cone_add(radius1=r * 1.45, radius2=r * 0.9, depth=h * 1.002, location=loc, vertices=128)
        boolean(o, bpy.context.object, 'INTERSECT')
    if m: assign(o, m)
    return smooth(o, bevel, 2)

def meshes(objs): return [o for o in objs if o.type == 'MESH']

def lowest_xy(objs, band=0.004):
    """centre (x, y) of the lowest part of a model (the drive square of a ratchet...)"""
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in meshes(objs) for v in o.data.vertices]
    zmin = min(p.z for p in pts)
    sel = [p for p in pts if p.z < zmin + band]
    return sum(p.x for p in sel) / len(sel), sum(p.y for p in sel) / len(sel), zmin

def sprite(objs, path, px_per_m, pad=0.004, anchor=None, height=2.0):
    """render a model straight down on a transparent background; writes path + path.json with the pixel anchor"""
    import json
    lo, hi = bounds(objs)
    w, h = (hi.x - lo.x) + pad * 2, (hi.y - lo.y) + pad * 2
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    px, py = max(8, round(w * px_per_m)), max(8, round(h * px_per_m))
    cam = top_cam(w, h, px, py, height=hi.z + height, center=(cx, cy))
    cam.data.ortho_scale = max(w, h)
    bpy.context.scene.render.resolution_x = px; bpy.context.scene.render.resolution_y = py
    render(path)
    info = {'w': px, 'h': py}
    if anchor:
        ax, ay = anchor
        info['ax'] = round((ax - (cx - w / 2)) * px_per_m, 1); info['ay'] = round(((cy + h / 2) - ay) * px_per_m, 1)
    json.dump(info, open(path + '.json', 'w'))
    return info

def layer(path, show, all_objs):
    """render only `show` (everything else hides it like a cut-out), same camera: a moving layer that fits the backdrop"""
    keep = set(show)
    for o in all_objs:
        if o.type in ('MESH', 'CURVE', 'FONT'):
            o.is_holdout = o not in keep
    s = bpy.context.scene; old = s.render.film_transparent; s.render.film_transparent = True
    render(path)
    s.render.film_transparent = old
    for o in all_objs:
        if o.type in ('MESH', 'CURVE', 'FONT'): o.is_holdout = False

def hide(objs, v=True):
    for o in objs: o.hide_render = v

def project(pt):
    """world point -> pixel (x, y) in the current camera"""
    from bpy_extras.object_utils import world_to_camera_view
    s = bpy.context.scene
    co = world_to_camera_view(s, s.camera, Vector(pt))
    return round(co.x * s.render.resolution_x, 1), round((1 - co.y) * s.render.resolution_y, 1)

def img_mat(name, path, rough=0.72, spec=0.25, alpha=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = P(m)
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(path)
    vm = nt.nodes.new('ShaderNodeVectorMath'); vm.operation = 'MULTIPLY'; vm.inputs[1].default_value = (0.78, 0.78, 0.76)
    nt.links.new(t.outputs[0], vm.inputs[0]); nt.links.new(vm.outputs[0], b.inputs['Base Color'])
    if alpha: nt.links.new(t.outputs[1], b.inputs['Alpha'])
    b.inputs['Roughness'].default_value = rough
    b.inputs['Specular IOR Level'].default_value = spec
    # paper fibre bump
    n = nt.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = 400
    bu = nt.nodes.new('ShaderNodeBump'); bu.inputs['Strength'].default_value = 0.05
    nt.links.new(n.outputs['Fac'], bu.inputs['Height']); nt.links.new(bu.outputs['Normal'], b.inputs['Normal'])
    return m

def note(v, loc=(0, 0, 0), rot=0.0, curl=0.0, w=0.156, h=0.066):
    """a bank note (plane with the artwork), optionally curled a little"""
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=24, y_subdivisions=6, size=1, location=loc, rotation=(0, 0, rot))
    o = bpy.context.object; o.scale = (w, h, 1); bpy.ops.object.transform_apply(scale=True)
    for vv in o.data.vertices:
        x = vv.co.x / (w / 2)
        vv.co.z += curl * (x * x) * 0.006 + curl * 0.0015 * math.sin(vv.co.y * 60)
    assign(o, img_mat(f'note{v}', f'/home/claude/mgstudio/tex/bill_{v}.png'))
    return smooth(o)

def worklight(k=1.0, target=(0, 0, 0), warm=(1.0, 0.88, 0.74)):
    """one work lamp above-left with a soft pool of light (falls off to the corners), a weak cool fill"""
    L = light('SPOT', (target[0] - 0.35, target[1] + 0.32, target[2] + 0.85), 22 * k, 0.12, target, warm, spot=math.radians(75))
    L.data.spot_blend = 0.9
    light('AREA', (target[0] + 0.7, target[1] - 0.5, target[2] + 0.6), 4 * k, 1.5, target, (0.75, 0.85, 1.0))
    return L

def lathe(profile, m=None, segs=96, name='lathe'):
    """revolve (r, z) points around Z into a closed-ish surface"""
    bm = bmesh.new(); rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    for i in range(segs):
        A, B = rings[i], rings[(i + 1) % segs]
        for j in range(len(profile) - 1): bm.faces.new((A[j], A[j + 1], B[j + 1], B[j]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    if m: assign(o, m)
    return smooth(o, 0, 0, 0, 50)
