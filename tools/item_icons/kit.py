# EX_Tii icon kit: materials, shapes, printed labels (all procedural / CC0)
import bpy, math, os, random
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_C = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'
FONT_R = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
os.makedirs(os.path.join(HERE, 'labels'), exist_ok=True)

def _p(m): return m.node_tree.nodes['Principled BSDF']

def mat(name, color=(0.5, 0.5, 0.5), rough=0.5, metal=0.0, coat=0.0, trans=0.0, ior=1.45, emit=None, emit_k=0.0, sss=0.0, aniso=0.0, noise_rough=0.0, bump=0.0, bump_scale=60.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = _p(m)
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    b.inputs['Coat Weight'].default_value = coat; b.inputs['Transmission Weight'].default_value = trans; b.inputs['IOR'].default_value = ior
    if aniso: b.inputs['Anisotropic'].default_value = aniso
    if sss:
        b.inputs['Subsurface Weight'].default_value = sss
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = emit_k
    if noise_rough or bump:
        tc = nt.nodes.new('ShaderNodeTexCoord'); nz = nt.nodes.new('ShaderNodeTexNoise')
        nz.inputs['Scale'].default_value = bump_scale; nz.inputs['Detail'].default_value = 8
        nt.links.new(tc.outputs['Object'], nz.inputs['Vector'])
        if noise_rough:
            mr = nt.nodes.new('ShaderNodeMapRange'); mr.inputs[3].default_value = max(0, rough - noise_rough); mr.inputs[4].default_value = min(1, rough + noise_rough)
            nt.links.new(nz.outputs['Fac'], mr.inputs[0]); nt.links.new(mr.outputs[0], b.inputs['Roughness'])
        if bump:
            bm = nt.nodes.new('ShaderNodeBump'); bm.inputs['Strength'].default_value = bump; bm.inputs['Distance'].default_value = 0.02
            nt.links.new(nz.outputs['Fac'], bm.inputs['Height']); nt.links.new(bm.outputs['Normal'], b.inputs['Normal'])
    return m

# a few ready materials
def chrome(): return mat('chrome', (0.9, 0.9, 0.92), rough=0.08, metal=1)
def steel(): return mat('steel', (0.62, 0.63, 0.65), rough=0.32, metal=1, noise_rough=0.08)
def dark_steel(): return mat('dsteel', (0.18, 0.18, 0.19), rough=0.38, metal=1, noise_rough=0.1)
def alu(): return mat('alu', (0.8, 0.8, 0.82), rough=0.25, metal=1, noise_rough=0.05)
def rubber(): return mat('rubber', (0.025, 0.025, 0.027), rough=0.82, bump=0.15)
def plastic(c, r=0.35): return mat('plastic', c, rough=r, coat=0.1)
def cardboard(): return mat('card', (0.48, 0.33, 0.18), rough=0.85, bump=0.12, bump_scale=200)
def gold(): return mat('gold', (1.0, 0.71, 0.29), rough=0.15, metal=1)
def copper(): return mat('copper', (0.95, 0.55, 0.38), rough=0.25, metal=1, noise_rough=0.08)
def glass(c=(0.95, 0.97, 1.0), r=0.02): return mat('glass', c, rough=r, trans=1.0, ior=1.5)

def assign(o, m):
    o.data.materials.clear(); o.data.materials.append(m); return o

def smooth(o, bevel=0.0, seg=3, sub=0):
    if bevel:
        md = o.modifiers.new('bv', 'BEVEL'); md.width = bevel; md.segments = seg; md.limit_method = 'ANGLE'
    if sub:
        md = o.modifiers.new('sub', 'SUBSURF'); md.levels = md.render_levels = sub
    bpy.context.view_layer.objects.active = o
    with bpy.context.temp_override(object=o, selected_editable_objects=[o]):
        bpy.ops.object.shade_smooth()
    try: o.data.set_sharp_from_angle(angle=math.radians(35))
    except Exception: pass
    return o

def box(size, loc=(0, 0, 0), m=None, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot); o = bpy.context.object
    o.scale = size; bpy.ops.object.transform_apply(scale=True)
    smooth(o, bevel)
    if m: assign(o, m)
    return o

def cyl(r, h, loc=(0, 0, 0), m=None, bevel=0.0, rot=(0, 0, 0), verts=64):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=verts); o = bpy.context.object
    smooth(o, bevel)
    if m: assign(o, m)
    return o

def sphere(r, loc=(0, 0, 0), m=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=48, ring_count=24); o = bpy.context.object
    o.scale = scale; smooth(o)
    if m: assign(o, m)
    return o

def torus(R, r, loc=(0, 0, 0), m=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=72, minor_segments=24); o = bpy.context.object
    smooth(o)
    if m: assign(o, m)
    return o

def boolean(target, cutter, op='DIFFERENCE'):
    md = target.modifiers.new('b', 'BOOLEAN'); md.operation = op; md.object = cutter; md.solver = 'EXACT'
    bpy.context.view_layer.objects.active = target
    with bpy.context.temp_override(object=target):
        bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.data.objects.remove(cutter)
    for p in target.data.polygons: p.use_smooth = False
    return target

# ---- printed labels: an image drawn with PIL, put on a plane (a sticker) or wrapped on a cylinder
def label_img(name, w, h, bg, draw):
    im = Image.new('RGBA', (w, h), bg); d = ImageDraw.Draw(im); draw(d, im)
    p = os.path.join(HERE, 'labels', name + '.png'); im.save(p); return p

def img_mat(name, path, rough=0.4, alpha=True, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = _p(m)
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(path); t.extension = 'CLIP'
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    if alpha: nt.links.new(t.outputs['Alpha'], b.inputs['Alpha'])
    b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
    return m

def sticker(path, w, h, loc, rot, rough=0.45):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot); o = bpy.context.object
    o.scale = (w, h, 1); bpy.ops.object.transform_apply(scale=True)
    return assign(o, img_mat('stk', path, rough))

def wrap_label(path, r, h, z, m_rough=0.35, coat=0.2):
    # a label around a cylinder (UVs of a cylinder side)
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=(0, 0, z), vertices=96, end_fill_type='NOTHING'); o = bpy.context.object
    uv = o.data.uv_layers.active.data
    us = [d.uv.x for d in uv]; vs = [d.uv.y for d in uv]; u0, u1, v0, v1 = min(us), max(us), min(vs), max(vs)
    for d in uv: d.uv.x = (d.uv.x - u0) / max(1e-6, u1 - u0); d.uv.y = (d.uv.y - v0) / max(1e-6, v1 - v0)
    smooth(o)
    return assign(o, img_mat('wrap', path, m_rough, coat=coat))

def font(size, f=FONT_B): return ImageFont.truetype(f, size)

def center_text(d, W, y, text, f, fill):
    tw = d.textlength(text, font=f); d.text(((W - tw) / 2, y), text, font=f, fill=fill)

# ---- more shapes
import bmesh
def lathe(profile, m=None, segs=96, name='lathe'):
    """profile: [(r, z), ...] from bottom centre to top centre; spun around Z"""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    for p in o.data.polygons: p.use_smooth = True
    if m: o.data.materials.append(m)
    return o

def keep(objs, name):
    """keep only one node (and its children) of an imported model"""
    keepers = [o for o in objs if o.name.startswith(name)]
    def under(o):
        while o:
            if o in keepers: return True
            o = o.parent
        return False
    out = []
    for o in objs:
        if under(o): out.append(o)
        else: bpy.data.objects.remove(o)
    return out

def liquid(c, trans=0.95, rough=0.02):
    return mat('liquid', c, rough=rough, trans=trans, ior=1.34)

WRAP_FACE = 35  # turns a wrapped label so its middle faces the camera
def wrap(path, r, h, z, x=0.0, y=0.0, rough=0.35, coat=0.2, face=WRAP_FACE):
    o = wrap_label(path, r, h, z, rough, coat); o.location.x = x; o.location.y = y; o.rotation_euler = (0, 0, math.radians(face)); return o

def cross_label(name, bg=(200, 20, 30, 255), fg=(255, 255, 255, 255), size=400):
    def dr(d, im):
        d.rounded_rectangle((0, 0, size - 1, size - 1), size // 8, fill=bg)
        a, b = size * 0.38, size * 0.62; t1, t2 = size * 0.16, size * 0.84
        d.rectangle((a, t1, b, t2), fill=fg); d.rectangle((t1, a, t2, b), fill=fg)
    return label_img(name, size, size, (0, 0, 0, 0), dr)
