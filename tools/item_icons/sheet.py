import sys
from PIL import Image, ImageDraw
names = sys.argv[2:]; out = sys.argv[1]; cell = 150; cols = 8
rows = (len(names) + cols - 1) // cols
sh = Image.new('RGBA', (cols * cell, rows * (cell + 16)), (24, 25, 30, 255)); d = ImageDraw.Draw(sh)
for i, n in enumerate(names):
    x, y = (i % cols) * cell, (i // cols) * (cell + 16)
    d.rounded_rectangle((x + 6, y + 6, x + cell - 6, y + cell - 6), 10, fill=(34, 36, 44, 255), outline=(60, 62, 72, 255))
    try: sh.alpha_composite(Image.open(f'final/{n}.png').resize((cell - 24, cell - 24), Image.LANCZOS), (x + 12, y + 12))
    except Exception: d.text((x + 20, y + 60), 'missing', fill=(255, 90, 90, 255))
    d.text((x + 8, y + cell), n, fill=(220, 220, 220, 255))
sh.convert('RGB').save(out)
