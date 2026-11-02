# a chrome gauge bezel ring (top-down, transparent middle) for the HUD dials
import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
reset('autoshop_01', 0.5, rot=0.6, transparent=True)
ch = mat('bez', (0.86, 0.86, 0.88), 0.1, 1.0, noise=0.03)
# a lathe profile: flat outer lip, rounded crown, steps down to the glass
prof = [(0.0400, 0.0), (0.0500, 0.0), (0.0500, 0.004), (0.0488, 0.0075), (0.0462, 0.0092), (0.0432, 0.0088), (0.0412, 0.0070), (0.0402, 0.0045), (0.0400, 0.0)]
bm = bmesh.new()
segs = 160
rings = []
for i in range(segs):
    a = 2 * math.pi * i / segs
    rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in prof])
for i in range(segs):
    A, B = rings[i], rings[(i + 1) % segs]
    for j in range(len(prof) - 1):
        bm.faces.new((A[j], A[j + 1], B[j + 1], B[j]))
me = bpy.data.meshes.new('bez'); bm.to_mesh(me); o = bpy.data.objects.new('bez', me); bpy.context.scene.collection.objects.link(o)
assign(o, ch); smooth(o, 0, 0, 0, 80)
light('AREA', (-0.3, 0.3, 0.4), 30, 0.3, (0, 0, 0), (1.0, 0.92, 0.82))
light('AREA', (0.3, -0.25, 0.3), 8, 0.6, (0, 0, 0), (0.8, 0.88, 1.0))
top_cam(0.1, 0.1, 274 * 2, 274 * 2, height=1)
render('out/bezel.png')
