# EX_Tii icon studio: every item is shot the same way (3/4 view, soft studio light, transparent, contact shadow)
import bpy, math, os, mathutils
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__))

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = 96
    s.cycles.use_denoising = True
    s.render.film_transparent = True
    s.render.resolution_x = s.render.resolution_y = 512
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.view_settings.view_transform = 'AgX'
    s.view_settings.look = os.environ.get('LOOK', 'AgX - Punchy')
    w = bpy.data.worlds.new('w'); s.world = w; w.use_nodes = True
    nt = w.node_tree; bg = nt.nodes['Background']
    env = nt.nodes.new('ShaderNodeTexEnvironment')
    env.image = bpy.data.images.load(os.path.join(HERE, 'hdri/studio_small_09.hdr'))
    nt.links.new(env.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = 0.9
    return s

def imp(mid):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, f'assets/{mid}/{mid}.gltf'))
    return [o for o in bpy.data.objects if o not in before]

def mat(name, color, rough=0.5, metal=0.0, sss=0.0, coat=0.0, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if sss:
        b.inputs['Subsurface Weight'].default_value = sss
        b.inputs['Subsurface Radius'].default_value = (0.4, 0.1, 0.3)
    if coat: b.inputs['Coat Weight'].default_value = coat
    return m

def bounds(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == 'MESH' for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi

def group(objs):
    root = bpy.data.objects.new('item', None); bpy.context.scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None: o.parent = root
    return root

def normalize(objs, size=1.0):
    root = group(objs)
    bpy.context.view_layer.update()
    lo, hi = bounds(objs)
    k = size / max(hi - lo)
    root.scale = (k, k, k); bpy.context.view_layer.update()
    lo, hi = bounds(objs)
    root.location -= Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)); bpy.context.view_layer.update()
    return root

def shoot(objs, out, az=35, el=28, lens=70, margin=1.18):
    s = bpy.context.scene
    # floor that only catches the shadow
    bpy.ops.mesh.primitive_plane_add(size=40); fl = bpy.context.object; fl.is_shadow_catcher = True
    # a soft key light from the upper left, a rim from behind
    for loc, e, sz in (((-2.5, -2.0, 3.2), 260, 2.5), ((2.5, 3.0, 2.0), 120, 3.0)):
        bpy.ops.object.light_add(type='AREA', location=loc); L = bpy.context.object
        L.data.energy = e; L.data.size = sz
        L.rotation_euler = (Vector((0, 0, 0.4)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    lo, hi = bounds(objs); c = (lo + hi) / 2; r = (hi - lo).length / 2
    cam_d = bpy.data.cameras.new('c'); cam_d.lens = lens
    cam = bpy.data.objects.new('cam', cam_d); s.collection.objects.link(cam); s.camera = cam
    fov = 2 * math.atan(18 / lens)
    dist = r * margin / math.sin(fov / 2)
    a, e = math.radians(az), math.radians(el)
    cam.location = c + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    s.render.filepath = out
    bpy.ops.render.render(write_still=True)
