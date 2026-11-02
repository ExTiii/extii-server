# fictional "State of San Andreas" bank notes, engraved look (guilloche, microtext, serials) -> tex/bill_<v>.png
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
SER = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'
SERR = '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'
SANS = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'
MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
W, H = 1560, 660
DEN = {10: ((170, 140, 92), (84, 54, 24), 'TEN'), 20: ((138, 166, 118), (30, 66, 34), 'TWENTY'),
       50: ((186, 132, 118), (108, 34, 30), 'FIFTY'), 100: ((122, 154, 172), (22, 54, 84), 'ONE HUNDRED')}
def F(p, s): return ImageFont.truetype(p, s)
def rosette(d, cx, cy, R, r, k, col, w=1, n=1400):
    for j in range(3):
        pts = []
        for i in range(n + 1):
            t = 2 * math.pi * i / n
            rr = R + r * math.sin(k * t + j * 0.7)
            pts.append((cx + rr * math.cos(t + j * 0.05), cy + rr * math.sin(t + j * 0.05) * 0.92))
        d.line(pts, fill=col, width=w)
def wave_band(d, x0, x1, y, amp, col, lines=9, per=38):
    for j in range(lines):
        pts = [(x, y + j * 3 + amp * math.sin((x + j * 9) / per)) for x in range(x0, x1, 3)]
        d.line(pts, fill=col, width=1)
for v, (paper, ink, word) in DEN.items():
    random.seed(v)
    im = Image.new('RGB', (W, H), paper); d = ImageDraw.Draw(im)
    lite = tuple(int(c * 0.6 + p * 0.4) for c, p in zip(ink, paper))
    faint = tuple(int(c * 0.25 + p * 0.75) for c, p in zip(ink, paper))
    # fine background lines everywhere (the paper never looks flat on a real note)
    for y in range(0, H, 6):
        d.line([(x, y + 2 * math.sin(x / 23 + y / 40)) for x in range(0, W, 6)], fill=faint, width=1)
    # border frame with a guilloche band
    d.rectangle([22, 22, W - 22, H - 22], outline=ink, width=5)
    d.rectangle([40, 40, W - 40, H - 40], outline=lite, width=2)
    wave_band(d, 46, W - 46, 48, 4, lite, 5, 21); wave_band(d, 46, W - 46, H - 64, 4, lite, 5, 21)
    # the big rosettes left and right, a portrait-oval with a palm and the hills
    rosette(d, 250, H // 2, 150, 28, 24, lite, 1); rosette(d, 250, H // 2, 105, 18, 18, ink, 1); rosette(d, 250, H // 2, 62, 10, 12, lite, 1)
    rosette(d, W - 250, H // 2, 150, 28, 24, lite, 1); rosette(d, W - 250, H // 2, 105, 18, 18, ink, 1)
    d.ellipse([W // 2 - 190, 110, W // 2 + 190, H - 110], outline=ink, width=4)
    d.ellipse([W // 2 - 176, 124, W // 2 + 176, H - 124], outline=lite, width=1)
    cx, cy = W // 2, H // 2 + 40
    # the vignette, drawn on its own layer and kept inside the oval
    vg = Image.new('RGBA', (W, H), (0, 0, 0, 0)); vd = ImageDraw.Draw(vg)
    for i in range(70):  # sun rays
        a = math.pi + i / 69 * math.pi
        vd.line([(cx - 70 + math.cos(a) * 34, cy - 30 + math.sin(a) * 34), (cx - 70 + math.cos(a) * 160, cy - 30 + math.sin(a) * 160)], fill=(*faint, 255), width=1)
    vd.ellipse([cx - 104, cy - 64, cx - 36, cy + 4], outline=(*lite, 255), width=2)
    for i in range(46):   # engraved hills (hatch lines)
        y = cy + 10 + i * 2.6
        vd.line([(x, y + 26 * math.sin((x - cx + 60) / 90) * (1 - i / 46)) for x in range(cx - 200, cx + 200, 3)], fill=(*(lite if i % 2 else ink), 255), width=1)
    # a palm: curved trunk, drooping fronds with leaflets
    tr = [(cx + 60 + 10 * math.sin(k / 9), cy + 70 - k * 4.6) for k in range(36)]
    vd.line(tr, fill=(*ink, 255), width=8)
    for k in range(0, 36, 3): vd.line([(tr[k][0] - 5, tr[k][1]), (tr[k][0] + 5, tr[k][1] - 2)], fill=(*paper, 255), width=1)
    top = tr[-1]
    for a in range(9):
        t = -math.pi / 2 + (a - 4) * 0.5
        L = 13 + (4 - abs(a - 4)) * 1.5
        fr = [(top[0] + math.cos(t) * s * 7, top[1] + math.sin(t) * s * 7 + (s * s) * 0.55 * abs(math.cos(t)) + s * 0.4) for s in range(int(L))]
        vd.line(fr, fill=(*ink, 255), width=3)
        for s in range(2, len(fr) - 1):
            x, y = fr[s]; vd.line([(x, y), (x + math.cos(t + 1.2) * 9, y + math.sin(t + 1.2) * 9 + 4)], fill=(*ink, 255), width=1)
            vd.line([(x, y), (x + math.cos(t - 1.2) * 9, y + math.sin(t - 1.2) * 9 + 4)], fill=(*ink, 255), width=1)
    m = Image.new('L', (W, H), 0); ImageDraw.Draw(m).ellipse([W // 2 - 176, 124, W // 2 + 176, H - 124], fill=255)
    vg.putalpha(Image.composite(vg.getchannel('A'), Image.new('L', (W, H), 0), m))
    im.paste(vg, (0, 0), vg); d = ImageDraw.Draw(im)
    # texts
    d.text((W // 2, 80), 'THE STATE OF SAN ANDREAS', fill=ink, font=F(SER, 46), anchor='mm')
    d.text((W // 2, H - 90), f'{word} DOLLARS', fill=ink, font=F(SER, 40), anchor='mm')
    for (x, y) in ((92, 96), (W - 92, 96), (92, H - 96), (W - 92, H - 96)):
        d.text((x, y), str(v), fill=ink, font=F(SER, 64 if v < 100 else 52), anchor='mm')
    d.text((250, H // 2), str(v), fill=ink, font=F(SER, 120 if v < 100 else 92), anchor='mm')
    d.text((W - 250, H // 2), str(v), fill=ink, font=F(SER, 120 if v < 100 else 92), anchor='mm')
    # serials (one red/green each side) and the treasurer's signature
    ser = f"LS {random.randint(10000000, 99999999)} {chr(65 + random.randint(0, 25))}"
    d.text((470, 160), ser, fill=(150, 40, 30) if v != 20 else (40, 100, 50), font=F(MONO, 30), anchor='lm')
    d.text((W - 330, H - 150), ser, fill=(150, 40, 30) if v != 20 else (40, 100, 50), font=F(MONO, 30), anchor='rm')
    sig = [(W - 560 + i * 4, H // 2 + 70 + 14 * math.sin(i / 3.1) * math.cos(i / 7.3)) for i in range(60)]
    d.line(sig, fill=ink, width=3); d.line([(W - 570, H // 2 + 90), (W - 330, H // 2 + 86)], fill=ink, width=1)
    d.text((W - 450, H // 2 + 108), 'TREASURER', fill=lite, font=F(SANS, 18), anchor='mm')
    d.text((470, H - 160), 'LEGAL TENDER · ALL DEBTS', fill=lite, font=F(SANS, 18), anchor='lm')
    # microtext line
    d.text((W // 2, 132), ('SANANDREAS' * 30)[:120], fill=lite, font=F(SANS, 9), anchor='mm')
    # wear: soft grime, a fold line
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    g = Image.new('L', (W, H), 0); gd = ImageDraw.Draw(g)
    for i in range(90):
        x, y, r = random.randint(0, W), random.randint(0, H), random.randint(30, 160)
        gd.ellipse([x - r, y - r, x + r, y + r], fill=random.randint(4, 16))
    g = g.filter(ImageFilter.GaussianBlur(40))
    dirt = Image.new('RGB', (W, H), (70, 60, 45)); im = Image.composite(dirt, im, g)
    fd = ImageDraw.Draw(im); fd.line([(W * 0.52, 0), (W * 0.5, H)], fill=tuple(int(p * 0.86) for p in paper), width=3)
    im.save(f'tex/bill_{v}.png')
    print('bill', v)
