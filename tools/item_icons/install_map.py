# where each finished icon goes on the server (device paths) — same names the items already use
import re, json, os
BASE = r'C:\FXServer\txData\Qbox_DE8D98.base\resources'
s = open('/home/claude/extii-server/resources/[ox]/ox_inventory/data/items.lua', encoding='utf-8').read()
items = re.findall(r"\n    \['([^']+)'\]\s*=\s*\{(.*?)\n    \},", s, re.S)
out = []
for name, body in items:
    src = f'final/{name}.png'
    m = re.search(r"image\s*=\s*'([^']+)'", body)
    img = m.group(1) if m else f'{name}.png'
    if img.startswith('nui://'):
        res, rest = img[len('nui://'):].split('/', 1)
        grp = '[standalone]'
        dev = BASE + '\\' + grp + '\\' + res + '\\' + rest.replace('/', '\\')
    else:
        dev = BASE + r'\[ox]\ox_inventory\web\images' + '\\' + img
    out.append({'name': name, 'src': src, 'dev': dev, 'exists': os.path.exists(src)})
# the mechanic tablet also shows its own copies of these two
for n in ('repairkit', 'advancedrepairkit'):
    out.append({'name': n, 'src': f'final/{n}.png', 'dev': BASE + r'\[standalone]\exti_mechanic\html\items' + '\\' + n + '.png', 'exists': True})
json.dump(out, open('install.json', 'w'), indent=1)
print(len(out), 'targets'); print(sum(1 for o in out if not o['exists']), 'not rendered yet')
from collections import Counter
print(Counter(o['dev'].split('\\')[-3] if 'items' in o['dev'] else 'ox' for o in out))
