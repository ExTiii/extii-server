# the shooting range: looking down an indoor lane from the booth (the target is drawn by the page)
import sys, json; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
PX, PY = 1200, 690
def scene():
    reset('autoshop_01', 0.02, rot=0.4)
    conc = pbr('conc', 'concrete_floor_worn_001', 0.6, tint=(0.4, 0.4, 0.4))
    plane(4, 30, (0, 12, 0), conc)
    panel = mat('panel', (0.07, 0.072, 0.075), 0.85, spec=0.2, noise=0.1)
    for side in (-1, 1):
        w = box((0.1, 30, 3), (side * 2.0, 12, 1.5), panel)
        for k in range(14):  # acoustic panels: soft grey blocks along the walls
            box((0.06, 1.6, 1.4), (side * 1.94, 1.5 + k * 1.9, 1.3), mat(f'ac{k}{side}', (0.12, 0.12, 0.13), 0.95, spec=0.1), bevel=0.04)
    plane(4.2, 30, (0, 12, 3.0), mat('ceil', (0.05, 0.05, 0.05), 0.8), rot=(math.pi, 0, 0))
    # steel baffles hanging across, a strip light under each
    for k in range(9):
        box((4.0, 0.04, 0.5), (0, 2 + k * 2.6, 2.7), mat(f'baf{k}', (0.14, 0.14, 0.15), 0.6, 0.6), rot=(math.radians(-30), 0, 0))
        box((1.6, 0.08, 0.03), (0, 2.2 + k * 2.6, 2.4), mat(f'lt{k}', (1, 1, 1), 0.5, emit=(1.0, 0.97, 0.9), emit_k=8))
    # the berm at the end: black rubber blocks
    for i in range(20):
        box((0.5, 0.4, 0.4), (-1.9 + i * 0.2, 24.5 + (i % 2) * 0.1, 0.2 + (i % 3) * 0.35), mat(f'r{i}', (0.02, 0.02, 0.02), 0.8), rot=(0.2, 0.1 * i, 0.3 * i))
    box((4, 0.5, 3), (0, 25, 1.5), mat('back', (0.015, 0.015, 0.015), 0.9))
    # the target carrier wire
    cyl(0.006, 30, (0, 12, 2.2), mat('wire', (0.3, 0.3, 0.3), 0.4, 1.0), rot=(math.radians(90), 0, 0))
    # the booth's shelf right in front, a pair of ear muffs and a box of rounds on it
    box((2.4, 0.5, 0.04), (0, 0.05, 1.0), pbr('shelf', 'wood_table_worn', 1.0, tint=(0.5, 0.45, 0.4)), bevel=0.01)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.09, minor_radius=0.04, location=(-0.55, 0.12, 1.06)); assign(bpy.context.object, mat('muff', (0.02, 0.02, 0.02), 0.6))
    box((0.16, 0.09, 0.05), (0.55, 0.12, 1.045), mat('ammobox', (0.35, 0.05, 0.03), 0.6), bevel=0.004)
    for k in range(5): light('POINT', (0, 2.2 + k * 5.2, 2.3), 120, 0.3, (0, 2.2 + k * 5.2, 0), (1.0, 0.95, 0.88))
    persp_cam((0, -0.4, 1.55), (0, 12, 1.25), 35, PX, PY)
    render('out/range_bg.png')
    # where a target hung 10 m out sits on screen, and its size
    a = project((0, 10, 2.15)); b = project((0, 10, 1.45))
    json.dump({'tx': a[0], 'ty': a[1], 'th': round(b[1] - a[1], 1)}, open('out/range_bg.json', 'w'))
scene()
