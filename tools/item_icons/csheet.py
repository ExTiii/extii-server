import sys, json, os
from PIL import Image, ImageDraw
tag = sys.argv[1]; d0 = f'photos/cand/{tag}'
fs = sorted(f for f in os.listdir(d0) if f.endswith('.jpg'))
cell = 200; cols = 8; rows = (len(fs) + cols - 1) // cols
sh = Image.new('RGB', (cols * cell, max(1, rows) * (cell + 14)), (30, 30, 36)); d = ImageDraw.Draw(sh)
for i, f in enumerate(fs):
    im = Image.open(f'{d0}/{f}').convert('RGB'); im.thumbnail((cell, cell))
    x, y = (i % cols) * cell, (i // cols) * (cell + 14); sh.paste(im, (x, y)); d.text((x + 3, y + cell), f, fill=(255, 255, 0))
sh.save(sys.argv[2])
