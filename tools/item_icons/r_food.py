import bpy, math, random
from mathutils import Vector
import studio as S, kit as K, grapes as G
R = {}
def item(f): R[f.__name__] = f; return f
rad = math.radians
W = (255, 255, 255, 255); BLK = (25, 25, 28, 255)

def wrap_lbl(name, w, h, bg, lines, stripe=None):
    def dr(d, im):
        d.rectangle((0, 0, w - 1, h - 1), fill=bg)
        if stripe: d.rectangle((0, int(h * stripe[0]), w - 1, int(h * stripe[1])), fill=stripe[2])
        y = int(h * 0.12)
        for t, s, c, f in lines:
            K.center_text(d, w, y, t, K.font(s, f), c); y += int(s * 1.2)
    return K.label_img(name, w, h, (0, 0, 0, 0), dr)

def can(name, bg, lines, stripe=None):
    al = K.mat('canal', (0.85, 0.86, 0.88), rough=0.18, metal=1)
    prof = [(0, 0), (0.17, 0), (0.2, 0.03), (0.21, 0.07), (0.21, 0.66), (0.18, 0.72), (0.175, 0.74), (0, 0.74)]
    body = K.lathe(prof, al)
    lab = K.wrap(wrap_lbl(name, 1200, 600, bg, lines, stripe), 0.2115, 0.58, 0.365, rough=0.25, coat=0.6)
    tab = K.box((0.08, 0.04, 0.008), (0.03, 0, 0.745), al, bevel=0.005)
    return [body, lab, tab]

def bottle(prof, glass_m, liq_c=None, fill=0.7, liq_prof=None):
    objs = [K.lathe(prof, glass_m)]
    if liq_c:
        top = max(z for r, z in prof) * fill
        lp = liq_prof or [(0, 0.02), (max(r for r, z in prof) * 0.93, 0.02), (max(r for r, z in prof) * 0.93, top), (0, top)]
        objs.append(K.lathe(lp, K.liquid(liq_c)))
    return objs

@item
def burger():
    buns = S.imp('hamburger_buns'); buns = K.keep(buns, 'hamburger_buns_01'); S.normalize(buns, 1.0); bpy.context.view_layer.update()
    lo, hi = S.bounds(buns); h = hi.z - lo.z; mid = lo.z + h * 0.45
    # cut the bun: the top half goes up, a copy's bottom half stays
    mesh = [o for o in buns if o.type == 'MESH'][0]
    bot = mesh.copy(); bot.data = mesh.data.copy(); bpy.context.scene.collection.objects.link(bot); bot.parent = mesh.parent; bot.matrix_world = mesh.matrix_world.copy()
    K.boolean(mesh, K.box((3, 3, 2), (0, 0, mid - 1)))
    K.boolean(bot, K.box((3, 3, 2), (0, 0, mid + 1)))
    for p in mesh.data.polygons: p.use_smooth = True
    for p in bot.data.polygons: p.use_smooth = True
    lift = 0.3
    mesh.location.z += lift * (1 / mesh.parent.scale.z if mesh.parent else 1)
    patty = K.cyl(0.47, 0.11, (0, 0, mid + 0.07), K.mat('patty', (0.12, 0.05, 0.025), rough=0.8, bump=1.2, bump_scale=260), bevel=0.04)
    cheese = K.box((0.86, 0.86, 0.02), (0, 0, mid + 0.14), K.mat('cheese', (1.0, 0.6, 0.05), rough=0.35, sss=0.3), bevel=0.01); cheese.rotation_euler = (0, 0, rad(20))
    lett = K.cyl(0.5, 0.03, (0, 0, mid + 0.02), K.mat('lettuce', (0.25, 0.6, 0.1), rough=0.4, sss=0.3, bump=1.0, bump_scale=60))
    md = lett.modifiers.new('d', 'DISPLACE'); tx = bpy.data.textures.new('t', 'CLOUDS'); tx.noise_scale = 0.12; md.texture = tx; md.strength = 0.06
    tom = K.cyl(0.38, 0.04, (0, 0, mid + 0.2), K.mat('tomato', (0.75, 0.05, 0.02), rough=0.25, sss=0.4, coat=0.4))
    return buns + [bot, patty, cheese, lett, tom], {'el': 22}

@item
def testburger(): return burger()

@item
def sandwich():
    bread = K.mat('bread', (0.93, 0.82, 0.62), rough=0.85, bump=0.6, bump_scale=300); crust = K.mat('crust', (0.55, 0.32, 0.12), rough=0.7)
    objs = []
    for k, dx in enumerate((-0.12, 0.25)):
        for z, mm in ((0.04, bread), (0.24, bread)):
            o = K.cyl(0.42, 0.07, (dx, k * 0.12, z), mm, verts=3, bevel=0.02); o.rotation_euler = (0, 0, rad(30 + k * 180)); objs.append(o)
        for z, col, rr in ((0.1, (0.25, 0.6, 0.1), 0.44), (0.14, (0.85, 0.45, 0.4), 0.41), (0.18, (1.0, 0.75, 0.2), 0.42)):
            f = K.cyl(rr, 0.04, (dx, k * 0.12, z), K.mat('fill', col, rough=0.5, sss=0.3), verts=3, bevel=0.01); f.rotation_euler = (0, 0, rad(30 + k * 180)); objs.append(f)
    return objs, {'el': 30}

@item
def coffee():
    cup = K.lathe([(0, 0), (0.18, 0), (0.25, 0.75), (0, 0.75)], K.mat('cup', (0.95, 0.94, 0.9), rough=0.6))
    lid = K.lathe([(0, 0.74), (0.27, 0.74), (0.27, 0.79), (0.24, 0.81), (0.22, 0.86), (0, 0.86)], K.mat('lid', (0.05, 0.05, 0.05), rough=0.35))
    def dr(d, im):
        d.rectangle((0, 0, 1199, 299), fill=(120, 70, 35, 255))
        K.center_text(d, 1200, 100, 'BEAN MACHINE', K.font(52, K.FONT_C), (250, 235, 210, 255))
    sl = K.lathe([(0.205, 0.22), (0.233, 0.58)], None)
    sleeve = K.wrap(K.label_img('coffee', 1200, 300, (0, 0, 0, 0), dr), 0.226, 0.32, 0.4, rough=0.8, coat=0)
    sleeve.scale = (1.0, 1.0, 1.0); bpy.data.objects.remove(sl)
    return [cup, lid, sleeve], {'el': 22}

@item
def mustard():
    y = K.mat('mus', (0.95, 0.72, 0.02), rough=0.25, coat=0.4)
    body = K.lathe([(0, 0), (0.17, 0), (0.2, 0.05), (0.2, 0.6), (0.14, 0.68), (0.07, 0.72), (0, 0.72)], y)
    cap = K.lathe([(0, 0.7), (0.08, 0.7), (0.08, 0.8), (0.02, 0.92), (0, 0.93)], K.mat('mcap', (0.75, 0.05, 0.03), rough=0.3))
    lab = K.wrap(wrap_lbl('mustard', 1200, 400, (250, 245, 230, 255), [('MUSTARD', 70, (160, 20, 20, 255), K.FONT_C), ('CLASSIC YELLOW', 34, BLK, K.FONT_B)]), 0.203, 0.3, 0.32)
    return [body, cap, lab], {'el': 18}

@item
def water():
    pet = K.mat('pet', (0.85, 0.93, 1.0), rough=0.03, trans=1.0, ior=1.4)
    prof = [(0, 0), (0.15, 0), (0.17, 0.03), (0.17, 0.15), (0.155, 0.18), (0.17, 0.21), (0.17, 0.5), (0.155, 0.53), (0.17, 0.56), (0.17, 0.66), (0.12, 0.78), (0.06, 0.86), (0.06, 0.92), (0, 0.92)]
    objs = bottle(prof, pet, (0.85, 0.93, 1.0), 0.8, [(0, 0.02), (0.155, 0.02), (0.155, 0.7), (0, 0.7)])
    objs.append(K.cyl(0.065, 0.07, (0, 0, 0.95), K.mat('wcap', (0.1, 0.35, 0.85), rough=0.35)))
    objs.append(K.wrap(wrap_lbl('water', 1200, 300, (30, 110, 200, 255), [('SPRING WATER', 60, W, K.FONT_C), ('500 mL', 40, W, K.FONT_B)]), 0.172, 0.18, 0.36, coat=0.5))
    return objs, {'el': 18}

@item
def redbull(): return can('energy', (25, 40, 120, 255), [('REDLINE', 80, (230, 30, 40, 255), K.FONT_C), ('ENERGY', 60, (250, 200, 30, 255), K.FONT_C), ('250 mL', 34, W, K.FONT_B)], (0.6, 0.66, (230, 30, 40, 255))), {'el': 18}
@item
def sprunk(): return can('sprunk', (20, 140, 50, 255), [('Sprunk', 96, W, K.FONT_C), ('LEMON-LIME SODA', 36, (230, 255, 120, 255), K.FONT_B)], (0.62, 0.7, (240, 245, 240, 255))), {'el': 18}

@item
def grape():
    return G.bunch(Vector((0, 0, 0.7)), scale=1.0, seed=21, tilt=(rad(12), 0, 0), pal=((0.18, 0.32, 0.03), (0.42, 0.55, 0.08))), {'el': 20}

def _wine_like(name, glass_c, liq, lines, prof=None, cap_c=(0.15, 0.03, 0.03), lab_bg=(245, 238, 220, 255), z=0.36, h=0.26, r=0.165):
    prof = prof or [(0, 0), (0.16, 0), (0.165, 0.03), (0.165, 0.6), (0.14, 0.7), (0.06, 0.8), (0.05, 0.98), (0, 0.98)]
    objs = bottle(prof, K.glass(glass_c, 0.02), liq, 0.62)
    objs.append(K.cyl(0.054, 0.16, (0, 0, 0.93), K.mat('foilcap', cap_c, rough=0.25, metal=0.6)))
    objs.append(K.wrap(wrap_lbl(name, 1200, 420, lab_bg, lines), r + 0.002, h, z))
    return objs

@item
def wine(): return _wine_like('wine', (0.12, 0.25, 0.1), (0.25, 0.01, 0.02), [('CHÂTEAU', 40, BLK, K.FONT_R), ('MARLOWE', 68, (110, 20, 30, 255), K.FONT_C), ('ROUGE  2019', 34, BLK, K.FONT_B)]), {'el': 15}
@item
def grapejuice(): return _wine_like('grapejuice', (0.95, 0.97, 1.0), (0.18, 0.02, 0.12), [('GRAPE', 70, (110, 30, 120, 255), K.FONT_C), ('JUICE', 70, (110, 30, 120, 255), K.FONT_C), ('100% PRESSED', 30, BLK, K.FONT_B)], cap_c=(0.3, 0.1, 0.4), lab_bg=(250, 250, 245, 255)), {'el': 15}
@item
def vodka():
    prof = [(0, 0), (0.15, 0), (0.155, 0.03), (0.155, 0.7), (0.13, 0.78), (0.06, 0.84), (0.05, 1.0), (0, 1.0)]
    return _wine_like('vodka', (0.97, 0.98, 1.0), (0.97, 0.98, 1.0), [('NOGO', 74, (20, 40, 110, 255), K.FONT_C), ('VODKA', 50, BLK, K.FONT_B), ('40% vol', 30, BLK, K.FONT_R)], prof, cap_c=(0.75, 0.75, 0.78), lab_bg=(250, 250, 250, 255), z=0.4, r=0.155), {'el': 15}
@item
def beer():
    prof = [(0, 0), (0.13, 0), (0.135, 0.02), (0.135, 0.5), (0.12, 0.58), (0.06, 0.72), (0.045, 0.88), (0, 0.88)]
    objs = _wine_like('beer', (0.35, 0.15, 0.03), (0.6, 0.3, 0.02), [('PISSWASSER', 52, (200, 30, 30, 255), K.FONT_C), ('LAGER', 46, BLK, K.FONT_B)], prof, cap_c=(0.75, 0.62, 0.15), lab_bg=(245, 230, 190, 255), z=0.28, h=0.22, r=0.135)
    return objs, {'el': 15}
@item
def whiskey():
    glass = K.glass((0.97, 0.98, 1.0)); objs = []
    b = K.box((0.42, 0.24, 0.62), (0, 0, 0.31), glass, bevel=0.04); objs.append(b)
    objs.append(K.box((0.38, 0.2, 0.42), (0, 0, 0.23), K.liquid((0.55, 0.22, 0.03)), bevel=0.03))
    objs.append(K.lathe([(0, 0.62), (0.1, 0.62), (0.06, 0.68), (0.05, 0.78), (0, 0.78)], glass))
    objs.append(K.cyl(0.06, 0.1, (0, 0, 0.82), K.mat('wcap', (0.06, 0.05, 0.04), rough=0.4)))
    def dr(d, im):
        d.rectangle((0, 0, 599, 499), fill=(20, 20, 20, 255)); d.rectangle((14, 14, 585, 485), outline=(200, 160, 70, 255), width=6)
        K.center_text(d, 600, 70, "McKENZIE'S", K.font(64, K.FONT_C), (220, 180, 90, 255)); K.center_text(d, 600, 200, 'OLD NO. 7', K.font(48, K.FONT_B), W)
        K.center_text(d, 600, 330, 'SOUR MASH WHISKEY', K.font(32, K.FONT_B), (220, 180, 90, 255))
    objs.append(K.sticker(K.label_img('whiskey', 600, 500, (0, 0, 0, 0), dr), 0.34, 0.28, (0, -0.122, 0.3), (rad(90), 0, 0)))
    return objs, {'el': 15}
