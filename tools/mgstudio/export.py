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
    'sort_bg': ('sort_bg', 84, 1), 'note_10': ('note_10', 90, 1), 'note_20': ('note_20', 90, 1), 'note_50': ('note_50', 90, 1), 'note_100': ('note_100', 90, 1),
    'count_bg': ('count_bg', 84, 1), 'stack_band': ('stack_band', 90, 1),
    'drum_bg': ('drum_bg', 84, 1), 'drum_door': ('drum_door', 88, 1), 'drum_load': ('drum_load', 88, 1),
    'melt_bg': ('melt_bg', 84, 1), 'box_bg': ('box_bg', 84, 1), 'round_top': ('round_top', 92, 1 / 1.6),
    'round_side': ('round_side', 92, 1 / 2.2), 'case_side': ('case_side', 92, 1 / 2.2), 'press_bg': ('press_bg', 84, 1), 'press_die': ('press_die', 90, 1),
    'arms_bg': ('arms_bg', 84, 1), 'part_slide_a': ('part_slide', 90, 1), 'part_pistol_a': ('part_frame', 90, 1), 'part_magazine_loaded': ('part_mag', 90, 1),
    'part_trigger_a': ('part_trigger', 92, 1), 'part_hammer_a': ('part_hammer', 92, 1), 'part_spring': ('part_spring', 92, 1),
    'file_bg': ('file_bg', 84, 1), 'file': ('file', 90, 1), 'range_bg': ('range_bg', 84, 1),
    'trim_bg': ('trim_bg', 84, 1), 'fanleaf': ('fanleaf', 90, 1), 'nug': ('nug', 92, 1 / 1.2), 'scale_bg': ('scale_bg', 84, 1),
}
import shutil as _sh
if os.path.exists('tex/target.png'):
    Image.open('tex/target.png').save(f'{DST}/target.webp', 'WEBP', quality=88)
for src in sys.argv[1:] or MAP:
    name, q, k = MAP[src]
    if not os.path.exists(f'out/{src}.png'): print('missing', src); continue
    im = Image.open(f'out/{src}.png')
    if k != 1: im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    if src == 'pry_bar':   # a full-frame layer: crop to what's there, keep the offset in the page
        pass
    if name.endswith('_bg'): im = im.convert('RGB')
    im.save(f'{DST}/{name}.webp', 'WEBP', quality=q, method=6)
    print(name, im.size, os.path.getsize(f'{DST}/{name}.webp') // 1024, 'KB')
for f in os.listdir('sfx'):
    shutil.copy(f'sfx/{f}', f'{DST}/sfx/{f}')
