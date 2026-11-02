# render items: python3 render.py <recipes module> [names...]   (QUICK=1 for fast previews)
import sys, os, importlib, traceback
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, studio as S, post
QUICK = os.environ.get('QUICK') == '1'
mod = importlib.import_module(sys.argv[1])
names = sys.argv[2:] or list(mod.R.keys())
os.makedirs('out', exist_ok=True); os.makedirs('final', exist_ok=True)
for n in names:
    try:
        sc = S.reset()
        if QUICK: sc.cycles.samples = 20; sc.render.resolution_x = sc.render.resolution_y = 320
        else: sc.cycles.samples = 64; sc.render.resolution_x = sc.render.resolution_y = 400
        r = mod.R[n](); objs, kw = (r if isinstance(r, tuple) else (r, {}))
        bpy.context.view_layer.update()
        S.shoot(objs, os.path.abspath(f'out/{n}.png'), **kw)
        post.finish(f'out/{n}.png', f'final/{n}.png')
        print('DONE', n, flush=True)
    except Exception:
        print('FAIL', n); traceback.print_exc()
