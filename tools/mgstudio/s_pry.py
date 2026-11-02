# pry: close-up of a car's door edge, a crowbar wedged in the gap (backdrop + crowbar layer with the same camera)
import sys, json; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
from mathutils import Quaternion
PX, PY = 1200, 690

def car_paint(color):
    m = mat('paint', color, 0.3, 0.5, coat=1.0, coat_rough=0.03)
    nt = m.node_tree; b = P(m)
    # road dust: more at the bottom, in soft patches; dust kills the gloss
    tc = nt.nodes.new('ShaderNodeTexCoord')
    n = nt.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = 34; n.inputs['Detail'].default_value = 15; n.inputs['Roughness'].default_value = 0.72
    nt.links.new(tc.outputs['Object'], n.inputs['Vector'])
    sep = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(tc.outputs['Object'], sep.inputs[0])
    gz = nt.nodes.new('ShaderNodeMapRange'); gz.inputs['From Min'].default_value = 0.35; gz.inputs['From Max'].default_value = -0.05
    nt.links.new(sep.outputs['Z'], gz.inputs['Value'])
    mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    nt.links.new(n.outputs['Fac'], mul.inputs[0]); nt.links.new(gz.outputs['Result'], mul.inputs[1])
    ramp = nt.nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position = 0.3; ramp.color_ramp.elements[1].position = 0.62
    nt.links.new(mul.outputs[0], ramp.inputs[0])
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    ins = [i for i in mix.inputs if i.type == 'RGBA']; ins[0].default_value = (*color, 1); ins[1].default_value = (0.16, 0.13, 0.1, 1)
    nt.links.new(ramp.outputs[0], mix.inputs[0])
    out = [o for o in mix.outputs if o.type == 'RGBA'][0]
    nt.links.new(out, b.inputs['Base Color'])
    cw = nt.nodes.new('ShaderNodeMath'); cw.operation = 'SUBTRACT'; cw.inputs[0].default_value = 1.0
    nt.links.new(ramp.outputs[0], cw.inputs[1]); nt.links.new(cw.outputs[0], b.inputs['Coat Weight'])
    rr = nt.nodes.new('ShaderNodeMapRange'); rr.inputs['To Min'].default_value = 0.3; rr.inputs['To Max'].default_value = 0.85
    nt.links.new(ramp.outputs[0], rr.inputs['Value']); nt.links.new(rr.outputs['Result'], b.inputs['Roughness'])
    return m

def build():
    reset('autoshop_01', 0.9, rot=0.6)
    paint = car_paint((0.11, 0.006, 0.008))
    # the door (right) and the rear quarter / B-pillar (left), standing up, a 6 mm gap between
    body = box((0.30, 0.03, 0.50), (-0.153, 0, 0.25), paint, bevel=0.008)
    door = box((0.36, 0.03, 0.50), (0.183, 0, 0.25), paint, bevel=0.008)
    gapv = box((0.02, 0.02, 0.6), (0.0, 0.02, 0.25), mat('void', (0.003, 0.003, 0.003), 0.9))
    # handle + lock on the door
    ch = mat('chrome', (0.86, 0.86, 0.88), 0.08, 1.0)
    rec = box((0.14, 0.012, 0.045), (0.12, -0.012, 0.33), mat('rec', (0.012, 0.012, 0.012), 0.55), bevel=0.006)
    hd = box((0.12, 0.016, 0.022), (0.12, -0.022, 0.33), ch, bevel=0.007)
    lk = cyl(0.011, 0.01, (0.035, -0.017, 0.33), ch, rot=(math.radians(90), 0, 0), bevel=0.0015)
    box((0.0024, 0.006, 0.0095), (0.035, -0.022, 0.33), mat('slot', (0.01, 0.01, 0.01), 0.6))
    # the crowbar: claw in the gap, the bar comes out at the camera
    # the pry bar (made here along +Z, chisel end at the top, then aimed into the gap)
    tip = Vector((0.006, 0.012, 0.255))
    out = Vector((-0.24, -0.30, 0.10))
    d = (tip - out); L = d.length; d.normalize()
    blk = mat('barpaint', (0.02, 0.02, 0.022), 0.42, 0.3, noise=0.15, noise_scale=120)
    steel = mat('barsteel', (0.6, 0.6, 0.62), 0.3, 1.0, noise=0.12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.0095, depth=L - 0.045, location=(0, 0, (L - 0.045) / 2))
    bar = bpy.context.object; assign(bar, blk); smooth(bar, 0.0012, 2)
    # the chisel: flat, tapering to an edge at the tip (a wedge from a box)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, L - 0.03)); ch = bpy.context.object
    ch.scale = (0.022, 0.010, 0.06); bpy.ops.object.transform_apply(scale=True)
    for v in ch.data.vertices:
        if v.co.z > 0: v.co.y *= 0.12; v.co.x *= 0.85
    assign(ch, steel); smooth(ch, 0.0008, 2)
    aim = bpy.data.objects.new('aim', None); bpy.context.scene.collection.objects.link(aim)
    bar.parent = aim; ch.parent = aim
    aim.rotation_mode = 'QUATERNION'
    # the flat of the chisel goes along the gap (vertical)
    q = Vector((0, 0, 1)).rotation_difference(d)
    side = q @ Vector((1, 0, 0))
    roll = side.angle(Vector((0, 0, 1)))
    aim.rotation_quaternion = q @ Quaternion((0, 0, 1), math.radians(35))
    aim.location = out
    objs = [bar, ch]
    floor = plane(4, 4, (0, -0.5, 0.0), pbr('conc', 'concrete_floor_worn_001', 1.2, tint=(0.4, 0.4, 0.4)))
    light('AREA', (-0.9, -0.5, 1.0), 90, 0.6, (0, 0, 0.3), (1.0, 0.92, 0.82))
    light('AREA', (0.7, -0.6, 0.4), 25, 1.5, (0, 0, 0.3), (0.8, 0.88, 1.0))
    cam = persp_cam((-0.16, -0.55, 0.42), (0.03, 0, 0.27), 60, PX, PY)
    return objs, [body, door, gapv, rec, hd, lk, floor]

objs, rest = build()
allo = list(bpy.data.objects)
if sys.argv[-1] == 'bg':
    hide(objs); render('out/pry_bg.png'); hide(objs, False)
else:
    layer('out/pry_bar.png', objs, allo)
    json.dump({'pivot': project((0.0, 0.006, 0.255))}, open('out/pry_bar.json', 'w'))
