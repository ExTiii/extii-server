# torch: a car's floor-pan steel seen from above with a chalk line (drawn by the page), the propane torch sprite
import sys; sys.path.insert(0, '/home/claude/mgstudio')
from mg import *
W, H = 0.40, 0.23
PX, PY = 1200, 690
PPM = PX / W

def lamps():
    light('AREA', (-0.5, 0.4, 0.5), 30, 0.4, (0, 0, 0), (1.0, 0.92, 0.82))
    light('AREA', (0.6, -0.3, 0.6), 6, 1.0, (0, 0, 0), (0.8, 0.88, 1.0))

def scene_bg():
    reset('autoshop_01', 0.18, rot=2.6)
    plane(1.4, 1.4, (0, 0, -0.03), pbr('conc', 'concrete_floor_worn_001', 1.6, tint=(0.3, 0.3, 0.3)))
    st = pbr('sheet', 'rusty_metal_sheet', 2.2, tint=(0.34, 0.33, 0.32), sat=0.6, nor=1.6, metal=0.5)
    p = box((0.50, 0.30, 0.004), (0, 0.01, -0.002), st, bevel=0.0015)
    # two pressed ribs, the way a floor pan looks
    for y in (0.085, -0.09):
        r = box((0.52, 0.018, 0.006), (0, y, -0.002), st, bevel=0.0028)
    lamps()
    top_cam(W, H, PX, PY)
    render('out/torch_bg.png')

def torch_sprite():
    reset('autoshop_01', 0.3, rot=2.6, transparent=True)
    root, objs = imp('propane_torch')
    # lying, nozzle pointing down-left (that end is the cutting point)
    root.rotation_euler = (math.radians(90), 0, math.radians(-35))
    bpy.context.view_layer.update()
    # the nozzle tip: the lowest point of the original model is the tank base, the tip is the far end
    lo, hi = bounds(objs)
    lamps()
    import json
    info = sprite(objs, 'out/torch.png', PPM * 0.75)
    print('TB', tuple(lo), tuple(hi))

{'bg': scene_bg, 'torch': torch_sprite}[sys.argv[-1]]()
