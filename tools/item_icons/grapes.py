import bpy, random, math
from mathutils import Vector
_M = {}
def grape_mat(pal=None):
    key = 'g' + str(pal)
    if key in _M:
        try:
            _M[key].name; return _M[key]
        except ReferenceError: pass
    m = bpy.data.materials.new('grape'); m.use_nodes = True; nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    info = nt.nodes.new('ShaderNodeObjectInfo')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    lo_c, hi_c = pal or ((0.045, 0.012, 0.055), (0.12, 0.025, 0.09))
    ramp.color_ramp.elements[0].color = (*lo_c, 1)
    ramp.color_ramp.elements[1].color = (*hi_c, 1)
    nt.links.new(info.outputs['Random'], ramp.inputs[0]); nt.links.new(ramp.outputs[0], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.42
    b.inputs['Sheen Weight'].default_value = 0.4
    b.inputs['Sheen Roughness'].default_value = 0.35
    b.inputs['Sheen Tint'].default_value = (0.55, 0.58, 0.72, 1)
    b.inputs['Subsurface Weight'].default_value = 0.12
    b.inputs['Subsurface Radius'].default_value = (0.5, 0.05, 0.3)
    _M[key] = m; return m

def bunch(at, scale=1.0, seed=1, tilt=(0, 0, 0), pal=None):
    random.seed(seed); objs = []
    piv = bpy.data.objects.new('bunch', None); bpy.context.scene.collection.objects.link(piv); piv.location = at
    g = grape_mat(pal); rows = 10
    for i in range(rows):
        t = i / (rows - 1); rad = (0.19 * (1 - t) ** 0.8 + 0.02); n = max(1, int(9 * (1 - t)) + 1)
        for j in range(n):
            ang = j / n * 2 * math.pi + random.random() * 0.8; rr = rad * (0.55 + random.random() * 0.45)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.052 * (0.88 + random.random() * 0.22), segments=32, ring_count=20,
                location=(rr * math.cos(ang), rr * math.sin(ang), -i * 0.062 + random.random() * 0.02))
            o = bpy.context.object; o.scale = (1, 1, 1.15); o.rotation_euler = (random.random(), random.random(), 0)
            bpy.ops.object.shade_smooth(); o.data.materials.append(g); o.parent = piv; objs.append(o)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.011, depth=0.12, location=(0, 0, 0.07))
    st = bpy.context.object; st.parent = piv
    sm = bpy.data.materials.new('stem'); sm.use_nodes = True; sm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.18, 0.13, 0.05, 1)
    sm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.8; st.data.materials.append(sm); objs.append(st)
    piv.scale = (scale,) * 3; piv.rotation_euler = tilt
    return objs
