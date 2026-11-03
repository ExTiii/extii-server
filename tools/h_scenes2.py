# EX_Tii heist minigames, set 2 (M3): the C4 wiring, the alarm panel (cut the right wires), the keypad.
# Straight-on views (el = 0): X = 600 + (x - cx) * ppm,   Y = 345 - (z - cz) * ppm   (front faces at y < 0)
import sys, math, os
sys.path.insert(0, '/home/claude/mgstudio'); sys.path.insert(0, '/home/claude/icons')
from h_scenes import *
import kit as K
import bpy

def label(name, w, h, draw, bg=(0, 0, 0, 0)):
    return K.label_img(name, w, h, bg, draw)

def front_sticker(path, w, h, x, y, z, rough=0.45):
    """a printed label facing the camera (-y), centre at x, z, sitting at depth y"""
    return K.sticker(path, w, h, (x, y, z), (math.radians(90), 0, 0), rough=rough)

def screw(x, y, z, r=0.012, m=None):
    m = m or brass()
    h = cyl(r, 0.01, (x, y, z), m, bevel=0.002, rot=(math.radians(90), 0, 0), verts=48)
    slot = box((r * 1.6, 0.004, r * 0.28), (x, y - 0.006, z), mat('slot', (0.05, 0.04, 0.03), 0.6), rot=(0, math.radians(35), 0))
    return [h, slot]

def wall_light(k=1.0):
    bpy.context.scene.view_settings.exposure = -0.7
    reflector(0.7)
    light('AREA', (-1.2, -1.8, 1.0), 55 * k, 1.0, (0, 0, 0), (1.0, 0.92, 0.82))
    light('AREA', (1.3, -1.2, -0.4), 16 * k, 0.8, (0, 0, 0), (0.72, 0.84, 1.0))

# ---------------------------------------------------------------- the C4 on an armored door
C4_TERM = [(-0.005 + i * 0.07, -0.175) for i in range(4)]      # the detonator's 4 screw posts (x, z)
C4_LEAD = [(-0.40, -0.095 + i * 0.045) for i in range(4)]       # where the 4 leads come out of the blasting cap (x, z)

def c4_bg():
    reset('studio_small_09', 0.3); m = cam3q(1.2, 0, cz=0.0)
    door = pbr('door', 'metal_plate_02', 3, (0.62, 0.63, 0.65), nor=0.6)
    plane(3, 2, (0, 0.06, 0), door, rot=(math.radians(90), 0, 0))
    for x in (-0.55, 0.55):
        for z in (-0.3, 0.3): cyl(0.016, 0.01, (x, 0.054, z), steel(), bevel=0.004, rot=(math.radians(90), 0, 0))
    # the charge: two olive bricks wrapped in tape
    od = mat('m112', (0.27, 0.27, 0.17), 0.7, 0.0, noise=0.25, noise_scale=60)
    for z in (0.045, -0.035):
        box((0.36, 0.06, 0.075), (-0.25, 0.02, z), od, bevel=0.008)
    tape = mat('tape', (0.12, 0.12, 0.10), 0.55, 0.0, coat=0.2, noise=0.15, noise_scale=200)
    for x in (-0.36, -0.14): box((0.035, 0.066, 0.17), (x, 0.02, 0.005), tape, bevel=0.004)
    def dr(d, im):
        d.rectangle((0, 0, 359, 89), fill=(214, 206, 170, 255))
        K.center_text(d, 360, 8, 'CHARGE, DEMOLITION', K.font(30, K.FONT_C), (30, 30, 28, 255))
        K.center_text(d, 360, 46, 'M112 · 1.25 LB · COMP C-4', K.font(24, K.FONT_C), (30, 30, 28, 255))
    front_sticker(label('c4lab', 360, 90, dr), 0.15, 0.037, -0.25, -0.0105, 0.045)
    # the blasting cap pushed into the charge, its plug where the leads come out
    cyl(0.009, 0.1, (-0.43, 0.0, 0.0), mat('cap', (0.65, 0.6, 0.5), 0.3, 1.0), rot=(0, math.radians(90), 0))
    box((0.05, 0.05, 0.16), (-0.40, -0.005, -0.03), mat('plug', (0.04, 0.04, 0.045), 0.45), bevel=0.008)
    for (x, z) in C4_LEAD: cyl(0.008, 0.012, (x, -0.034, z), mat('grommet', (0.15, 0.15, 0.16), 0.5), rot=(math.radians(90), 0, 0), verts=32)
    # the detonator: black box, LCD, LEDs, the 4 numbered posts
    abs_ = mat('abs', (0.03, 0.03, 0.035), 0.4, 0.0, coat=0.3, noise=0.1, noise_scale=150)
    box((0.36, 0.06, 0.30), (0.10, 0.02, -0.07), abs_, bevel=0.012)
    box((0.26, 0.004, 0.07), (0.10, -0.0115, 0.02), mat('lcd', (0.02, 0.05, 0.03), 0.08, emit=(0.05, 0.25, 0.1), emit_k=0.35))
    for x, c in ((-0.04, (1.0, 0.1, 0.05)), (0.24, (0.2, 1.0, 0.3))):
        cyl(0.008, 0.008, (x, -0.012, 0.035), mat('led', c, 0.2, emit=c, emit_k=0.4), rot=(math.radians(90), 0, 0), verts=32)
    def dt(d, im):
        f = K.font(30, K.FONT_C)
        for i in range(4): d.text((12 + i * 140, 0), str(i + 1), font=f, fill=(235, 235, 230, 255))
        d.text((10, 44), 'DET-4 · ARM ↓', font=K.font(20, K.FONT_C), fill=(160, 160, 160, 255))
    front_sticker(label('detnum', 560, 70, dt), 0.28, 0.035, 0.10, -0.0105, -0.12)
    for (x, z) in C4_TERM:
        cyl(0.017, 0.012, (x + 0.0, -0.016, z), mat('post', (0.12, 0.12, 0.13), 0.4), rot=(math.radians(90), 0, 0), verts=32)
        screw(x, -0.024, z, 0.011)
    wall_light(); H_bg('c4_bg')
    H_meta('c4_bg', {**m, 'terms': [scr(m, x, 0, z) for (x, z) in C4_TERM], 'leads': [scr(m, x, 0, z) for (x, z) in C4_LEAD],
                     'lcd': [scr(m, -0.03, 0, 0.055), scr(m, 0.23, 0, -0.015)], 'leds': [scr(m, -0.04, 0, 0.035), scr(m, 0.24, 0, 0.035)]})

# ---------------------------------------------------------------- the alarm junction box
PANEL_L = [(-0.20, 0.20 - i * 0.075) for i in range(6)]     # left strip: 1..6
PANEL_R = [(0.20, 0.20 - i * 0.075) for i in range(6)]      # right strip: what each line is
PANEL_LABELS = ['ALM+', 'TMP', 'PWR+', 'ALM-', 'COM', 'PWR-']

def panel_bg():
    reset('studio_small_09', 0.12); m = cam3q(1.2, 0, cz=0.0)
    plane(3, 2, (0, 0.10, 0), pbr('wall', 'brushed_concrete', 2, (0.5, 0.49, 0.47), nor=0.6), rot=(math.radians(90), 0, 0))
    grey = mat('encl', (0.52, 0.53, 0.55), 0.45, 0.6, noise=0.12, noise_scale=80)
    encl = box((0.78, 0.12, 0.60), (0, 0.04, 0), grey, bevel=0.01)
    boolean(encl, box((0.72, 0.2, 0.54), (0, -0.04, 0)))
    box((0.72, 0.01, 0.54), (0, 0.075, 0), mat('back', (0.35, 0.36, 0.37), 0.5, 0.5))
    # the board behind the strips
    box((0.60, 0.006, 0.50), (0, 0.055, 0), mat('pcb', (0.04, 0.22, 0.10), 0.35, 0.0, coat=0.5))
    for i in range(14): box((0.004, 0.002, 0.42), (-0.22 + i * 0.034, 0.0515, 0), mat('trace', (0.75, 0.62, 0.3), 0.3, 1.0))
    term = mat('strip', (0.05, 0.25, 0.10), 0.4)
    for (xs, pts) in ((-0.20, PANEL_L), (0.20, PANEL_R)):
        box((0.06, 0.04, 0.47), (xs, 0.045, 0.012), term, bevel=0.004)
        for (x, z) in pts: screw(x, 0.022, z, 0.011, steel())
    def dl(d, im):
        f = K.font(30, K.FONT_C)
        for i in range(6): d.text((4, 6 + i * 75 * 1.0), str(i + 1), font=f, fill=(240, 240, 235, 255))
    front_sticker(label('pnl_l', 60, 460, dl), 0.024, 0.46, -0.25, 0.0505, 0.0)
    def dr(d, im):
        f = K.font(26, K.FONT_C)
        for i, t in enumerate(PANEL_LABELS):
            col = (255, 90, 80, 255) if t.startswith('ALM') else ((255, 210, 70, 255) if t.startswith('PWR') else (230, 230, 225, 255))
            d.text((4, 8 + i * 75), t, font=f, fill=col)
    front_sticker(label('pnl_r', 110, 460, dr), 0.044, 0.46, 0.265, 0.0505, 0.0)
    # the siren / strobe up in the corner and the tamper switch
    cyl(0.03, 0.03, (0.30, 0.0, 0.25), mat('strobe', (0.6, 0.05, 0.04), 0.1, 0.0, trans=0.6, ior=1.5), rot=(math.radians(90), 0, 0), verts=48)
    box((0.04, 0.03, 0.03), (-0.30, 0.03, 0.25), mat('tamper', (0.08, 0.08, 0.09), 0.4), bevel=0.004)
    def dw(d, im):
        d.rectangle((0, 0, 499, 79), fill=(236, 230, 200, 255))
        d.text((10, 6), 'ALARM LOOP · CUT ALM ONLY', font=K.font(26, K.FONT_C), fill=(160, 20, 20, 255))
        d.text((10, 42), 'PWR = TAMPER → SIREN', font=K.font(24, K.FONT_C), fill=(40, 40, 40, 255))
    front_sticker(label('pnl_w', 500, 80, dw), 0.2, 0.032, -0.05, 0.0505, 0.255)
    wall_light(1.1); H_bg('panel_bg')
    H_meta('panel_bg', {**m, 'left': [scr(m, x, 0, z) for (x, z) in PANEL_L], 'right': [scr(m, x, 0, z) for (x, z) in PANEL_R],
                        'labels': PANEL_LABELS, 'strobe': scr(m, 0.30, 0, 0.25)})

def snips_sprite():
    """the wire cutters (diagonal pliers), seen from the front, jaws up: the anchor is the cutting point"""
    reset('studio_small_09', 0.12, transparent=True); cam3q(1.2, 0)
    red = mat('grip', (0.72, 0.06, 0.05), 0.45, 0.0, coat=0.3)
    jaw = mat('jaw', (0.35, 0.36, 0.38), 0.3, 1.0, aniso=0.4)
    parts = []
    for s in (-1, 1):
        parts.append(box((0.022, 0.016, 0.15), (s * 0.03, 0, -0.12), red, bevel=0.008, rot=(0, math.radians(-s * 8), 0)))
        parts.append(box((0.016, 0.014, 0.05), (s * 0.008, 0, -0.022), jaw, bevel=0.004, rot=(0, math.radians(s * 14), 0)))
    parts.append(cyl(0.012, 0.02, (0, 0, -0.045), steel(), rot=(math.radians(90), 0, 0), verts=32))
    wall_light()
    J.sprite3q(parts, 'snips', 1000, 0, (0.0, 0.0, 0.0), pad=0.004)

# ---------------------------------------------------------------- the keypad (stainless, 12 keys)
KP_KEYS = []
for r, row in enumerate(('123', '456', '789', '*0#')):
    for c, ch in enumerate(row): KP_KEYS.append((ch, -0.085 + c * 0.085, 0.02 - r * 0.075))

def keypad_bg():
    reset('studio_small_09', 0.12); m = cam3q(1.0, 0, cz=0.03)
    plane(3, 2, (0, 0.05, 0), pbr('wall', 'painted_metal_shutter', 2, (0.30, 0.32, 0.34), nor=0.5), rot=(math.radians(90), 0, 0))
    ss = mat('ss', (0.80, 0.80, 0.82), 0.22, 1.0, aniso=0.6, noise=0.08, noise_scale=300)
    box((0.34, 0.04, 0.48), (0, 0.025, 0.03), ss, bevel=0.012)
    box((0.22, 0.004, 0.06), (0, 0.003, 0.215), mat('kplcd', (0.02, 0.04, 0.05), 0.08, emit=(0.05, 0.15, 0.25), emit_k=0.3))
    for x, c in ((-0.12, (1.0, 0.1, 0.05)), (0.12, (0.2, 1.0, 0.3))):
        cyl(0.007, 0.006, (x, 0.002, 0.215), mat('kled', c, 0.2, emit=c, emit_k=0.25), rot=(math.radians(90), 0, 0), verts=32)
    key = mat('key', (0.70, 0.71, 0.73), 0.3, 1.0, aniso=0.5)
    for (ch, x, z) in KP_KEYS:
        box((0.07, 0.012, 0.06), (x, 0.0, z), key, bevel=0.008)
        def dk(d, im, ch=ch):
            K.center_text(d, 100, 6, ch, K.font(82, K.FONT_C), (30, 30, 34, 255))
        front_sticker(label('kp_' + {'*': 'star', '#': 'hash'}.get(ch, ch), 100, 100, dk), 0.034, 0.034, x, -0.0065, z)
    for (x, z) in ((-0.15, 0.25), (0.15, 0.25), (-0.15, -0.19), (0.15, -0.19)): screw(x, 0.004, z, 0.008, steel())
    # the card reader window and the maker's plate in the gap
    box((0.2, 0.004, 0.08), (0, 0.003, 0.115), mat('reader', (0.03, 0.03, 0.035), 0.15, 0.0, coat=0.8))
    def dg(d, im):
        for i, r in enumerate((26, 44, 62)): d.arc((130 - r, 70 - r, 130 + r, 70 + r), -50, 50, fill=(200, 200, 205, 255), width=7)
        d.text((210, 38), 'G6 ACCESS', font=K.font(54, K.FONT_C), fill=(200, 200, 205, 255))
    front_sticker(label('kp_rfid', 560, 140, dg), 0.17, 0.042, 0, -0.0005, 0.115)
    wall_light(0.9); H_bg('keypad_bg')
    H_meta('keypad_bg', {**m, 'keys': [[ch] + scr(m, x, 0, z) for (ch, x, z) in KP_KEYS], 'lcd': [scr(m, -0.11, 0, 0.245), scr(m, 0.11, 0, 0.185)],
                         'leds': [scr(m, -0.12, 0, 0.215), scr(m, 0.12, 0, 0.215)], 'key': [round(0.07 * m['ppm'], 1), round(0.06 * m['ppm'], 1)]})

JOBS = {k: v for k, v in dict(globals()).items() if callable(v) and k in ('c4_bg', 'panel_bg', 'snips_sprite', 'keypad_bg')}
if __name__ == '__main__':
    for n in sys.argv[1:]: JOBS[n]()
