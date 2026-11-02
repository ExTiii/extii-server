# crop to the item (+ its shadow), square, padding, 256 px
from PIL import Image
import sys
def finish(src, dst, size=256, pad=0.08):
    im = Image.open(src).convert('RGBA')
    a = im.split()[3].point(lambda v: 255 if v > 160 else 0)
    l, t, r, b = a.getbbox()
    w, h = r - l, b - t; side = int(max(w, h) * (1 + 2 * pad))
    cx, cy = (l + r) // 2, (t + b) // 2
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(im.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)), (0, 0))
    canvas.resize((size, size), Image.LANCZOS).save(dst, optimize=True)
if __name__ == '__main__':
    finish(sys.argv[1], sys.argv[2])
