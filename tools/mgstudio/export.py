# out/*.png -> the resource's html/mg/*.webp (backdrops lossy, sprites with alpha) + sfx
import sys, os, shutil, json
from PIL import Image
DST = '/home/claude/extii-server/resources/[standalone]/exti_gangs/html/mg'
os.makedirs(DST + '/sfx', exist_ok=True)
MAP = {  # source -> (name, quality, scale)
    'bolts_bg': ('bolts_bg', 84, 1), 'bolt': ('bolt', 92, 1), 'ratchet': ('ratchet', 90, 1),
    'lugs_bg': ('lugs_bg', 84, 1), 'lugnut': ('lugnut', 92, 1),
    'pry_bg': ('pry_bg', 84, 1), 'pry_bar': ('pry_bar', 90, 1), 'bezel': ('bezel', 92, 0.5),
    'torch_bg': ('torch_bg', 84, 1),
}
for src in sys.argv[1:] or MAP:
    name, q, k = MAP[src]
    im = Image.open(f'out/{src}.png')
    if k != 1: im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    if src == 'pry_bar':   # a full-frame layer: crop to what's there, keep the offset in the page
        pass
    if name.endswith('_bg'): im = im.convert('RGB')
    im.save(f'{DST}/{name}.webp', 'WEBP', quality=q, method=6)
    print(name, im.size, os.path.getsize(f'{DST}/{name}.webp') // 1024, 'KB')
for f in os.listdir('sfx'):
    shutil.copy(f'sfx/{f}', f'{DST}/sfx/{f}')
