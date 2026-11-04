/* ======================================================================
   EX_Tii appearance screen. Talks to illenium-appearance's game code (game/nui.lua) with the same
   messages its own screen used, plus a few of ours (client/exti.lua): the shop, the cart, turning.
   Modes: clothing (cart, price per piece), barber, tattoo, surgeon, creator (steps), uniform (free),
   ped (admin), wardrobe (saved outfits).
   ====================================================================== */
'use strict';

const IN_GAME = typeof window.GetParentResourceName === 'function';
const RES = IN_GAME ? window.GetParentResourceName() : 'illenium-appearance';
const $ = (s, r = document) => r.querySelector(s);
const h = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
const icon = (n) => `<svg viewBox="0 0 24 24"><use href="#i-${n}"/></svg>`;
const money = (n) => '$' + Math.round(n || 0).toLocaleString('en-US');
const clone = (o) => JSON.parse(JSON.stringify(o));
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

async function post(name, data) {
    if (!IN_GAME) return Mock.handle(name, data);
    try {
        const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data === undefined ? {} : data) });
        const t = await r.text();
        return t ? JSON.parse(t) : null;
    } catch (e) { return null; }
}

/* ---------------- what is what ---------------- */
const COMP = {
    11: { label: 'السترات', icon: 'jacket', group: 'top', cfg: 'jackets' },
    8: { label: 'القمصان', icon: 'shirt', group: 'top', cfg: 'shirts' },
    3: { label: 'اليدان والقفازات', icon: 'hand', group: 'top', cfg: 'upperBody' },
    7: { label: 'الوشاح والسلاسل', icon: 'scarf', group: 'top', cfg: 'scarfAndChains' },
    5: { label: 'الحقائب', icon: 'bag', group: 'top', cfg: 'bags' },
    10: { label: 'الشارات', icon: 'badge', group: 'top', cfg: 'decals' },
    9: { label: 'الدروع', icon: 'vest', group: 'top', cfg: 'bodyArmor' },
    4: { label: 'البناطيل', icon: 'pants', group: 'bottom', cfg: 'lowerBody' },
    6: { label: 'الأحذية', icon: 'shoe', group: 'bottom', cfg: 'shoes' },
    1: { label: 'الأقنعة', icon: 'mask', group: 'head', cfg: 'masks' },
};
const PROP = {
    0: { label: 'القبعات', icon: 'cap', group: 'head', cfg: 'hats' },
    1: { label: 'النظارات', icon: 'glasses', group: 'head', cfg: 'glasses' },
    2: { label: 'الأقراط', icon: 'ear', group: 'head', cfg: 'ear' },
    6: { label: 'الساعات', icon: 'watch', group: 'acc', cfg: 'watches' },
    7: { label: 'الأساور', icon: 'bracelet', group: 'acc', cfg: 'bracelets' },
};
const ORDER = { top: ['c11', 'c8', 'c3', 'c7', 'c5', 'c10', 'c9'], bottom: ['c4', 'c6'], head: ['p0', 'p1', 'p2', 'c1'], acc: ['p6', 'p7'] };
const GROUPS = [['top', 'الجزء العلوي'], ['bottom', 'الأسفل'], ['head', 'الرأس'], ['acc', 'الإكسسوار']];

const OVERLAY = {
    beard: { label: 'اللحية', icon: 'beard', color: true },
    eyebrows: { label: 'الحاجبان', icon: 'brow', color: true },
    chestHair: { label: 'شعر الصدر', icon: 'skin', color: true },
    makeUp: { label: 'المكياج', icon: 'eye', color: true },
    blush: { label: 'أحمر الخدود', icon: 'face', color: true },
    lipstick: { label: 'أحمر الشفاه', icon: 'lips', color: true },
    blemishes: { label: 'شوائب البشرة', icon: 'skin' },
    ageing: { label: 'علامات العمر', icon: 'face' },
    complexion: { label: 'لون البشرة', icon: 'skin' },
    sunDamage: { label: 'أثر الشمس', icon: 'skin' },
    moleAndFreckles: { label: 'الشامات والنمش', icon: 'face' },
    bodyBlemishes: { label: 'شوائب الجسم', icon: 'skin' },
};
const FACE = [
    ['الأنف', [['noseWidth', 'العرض', 'ضيّق', 'عريض'], ['nosePeakHigh', 'الارتفاع', 'منخفض', 'مرتفع'], ['nosePeakSize', 'الطول', 'قصير', 'طويل'], ['noseBoneHigh', 'ارتفاع العظم', 'منخفض', 'بارز'], ['nosePeakLowering', 'انخفاض الأرنبة', 'مرفوعة', 'منخفضة'], ['noseBoneTwist', 'انحراف العظم', 'يسار', 'يمين']]],
    ['الحاجبان', [['eyeBrownHigh', 'الارتفاع', 'منخفض', 'مرتفع'], ['eyeBrownForward', 'البروز', 'غائر', 'بارز']]],
    ['الوجنتان', [['cheeksBoneHigh', 'ارتفاع العظم', 'منخفض', 'مرتفع'], ['cheeksBoneWidth', 'عرض العظم', 'ضيّق', 'عريض'], ['cheeksWidth', 'الامتلاء', 'نحيف', 'ممتلئ']]],
    ['العينان والشفتان', [['eyesOpening', 'اتساع العينين', 'واسعتان', 'ضيّقتان'], ['lipsThickness', 'سماكة الشفتين', 'رقيقتان', 'ممتلئتان']]],
    ['الفك والذقن', [['jawBoneWidth', 'عرض الفك', 'ضيّق', 'عريض'], ['jawBoneBackSize', 'خلف الفك', 'مستدير', 'حاد'], ['chinBoneLowering', 'ارتفاع الذقن', 'مرتفع', 'منخفض'], ['chinBoneLenght', 'طول الذقن', 'قصير', 'طويل'], ['chinBoneSize', 'عرض الذقن', 'ضيّق', 'عريض'], ['chinHole', 'الغمازة', 'بلا', 'عميقة']]],
    ['الرقبة', [['neckThickness', 'السماكة', 'نحيفة', 'عريضة']]],
];
const EYES = ['أخضر', 'زمرّدي', 'أزرق فاتح', 'أزرق المحيط', 'بني فاتح', 'بني غامق', 'عسلي', 'رمادي غامق', 'رمادي فاتح', 'وردي', 'أصفر', 'بنفسجي', 'أسود', 'رمادي داكن', 'أصفر شاحب', 'أصفر غامق', 'أحمر', 'أزرق نيون', 'أخضر نيون', 'أبيض', 'أحمر قانٍ', 'برتقالي', 'رمادي فضي', 'بني محمر', 'أخضر داكن', 'زيتوني', 'رمادي أزرق', 'كهرماني', 'أبيض حليبي', 'أزرق جليدي', 'أسود فاحم'];
const ZONES = [['ZONE_TORSO', 'الجذع'], ['ZONE_LEFT_ARM', 'الذراع اليسرى'], ['ZONE_RIGHT_ARM', 'الذراع اليمنى'], ['ZONE_HEAD', 'الرأس'], ['ZONE_LEFT_LEG', 'الساق اليسرى'], ['ZONE_RIGHT_LEG', 'الساق اليمنى']];

const MODE = {
    clothing: { title: 'متجر الملابس', sub: 'اختر ما يعجبك، وادفع عند الخروج', icon: 'hanger' },
    barber: { title: 'الحلاق', sub: 'الشعر واللحية والمكياج', icon: 'hair' },
    tattoo: { title: 'محل الوشم', sub: 'جرّب الوشم على جسمك، وادفع لكل وشم تختاره', icon: 'needle' },
    surgeon: { title: 'عيادة التجميل', sub: 'ملامح الوجه والوراثة', icon: 'face' },
    creator: { title: 'شخصيتك الجديدة', sub: 'خمس خطوات، ثم تبدأ حياتك في المدينة', icon: 'user' },
    uniform: { title: 'تعديل الزي', sub: 'اختر قطع الزي ثم احفظه', icon: 'hanger' },
    ped: { title: 'تعديل المظهر', sub: 'كل الأقسام مفتوحة', icon: 'user' },
    wardrobe: { title: 'خزانة الملابس', sub: 'أزياؤك المحفوظة', icon: 'hanger' },
};
const STEPS = [['origin', 'الأصل'], ['face', 'الوجه'], ['hair', 'الشعر'], ['skin', 'البشرة'], ['clothes', 'الملابس']];

/* ---------------- state ---------------- */
const S = {
    open: false, mode: 'clothing', config: {}, settings: null, cur: null, orig: null, shop: {},
    group: 'top', cat: 'c11', step: 0, shown: {}, stripped: {}, tatZone: 'ZONE_TORSO', tatPreview: null, outfits: [], busy: false,
};

function gender() { return (S.cur && S.cur.model === 'mp_f_freemode_01') ? 'f' : 'm'; }
function isFreemode() { return S.cur && (S.cur.model === 'mp_m_freemode_01' || S.cur.model === 'mp_f_freemode_01'); }
function compOf(app, id) { return (app.components || []).find((c) => c.component_id === id); }
function propOf(app, id) { return (app.props || []).find((p) => p.prop_id === id); }
function compSet(id) { return (S.settings.components || []).find((c) => c.component_id === id); }
function propSet(id) { return (S.settings.props || []).find((p) => p.prop_id === id); }
function catInfo(cat) { return cat[0] === 'c' ? COMP[+cat.slice(1)] : PROP[+cat.slice(1)]; }
function catEnabled(cat) {
    const info = catInfo(cat); if (!info) return false;
    const c = S.config;
    if (cat[0] === 'c') return c.components !== false && (!c.componentConfig || c.componentConfig[info.cfg] !== false);
    return c.props !== false && (!c.propConfig || c.propConfig[info.cfg] !== false);
}
function priceOf(cat) { return S.mode === 'clothing' ? ((S.shop.prices || {})[cat] || 0) : 0; }

/* ---------------- opening / closing ---------------- */
function fit() { document.documentElement.style.zoom = String(clamp(window.innerHeight / 1080, 0.62, 1.6)); }
window.addEventListener('resize', fit);

async function open() {
    fit();
    const [st, dt, shop] = await Promise.all([post('appearance_get_settings'), post('appearance_get_data'), post('exti_get_shop')]);
    if (!st || !dt) return;
    S.settings = st.appearanceSettings;
    S.config = dt.config || {};
    S.cur = dt.appearanceData;
    S.orig = clone(dt.appearanceData);
    S.shop = shop || {};
    S.mode = pickMode();
    S.step = 0; S.shown = {}; S.stripped = {}; S.tatPreview = null; S.busy = false;
    if (S.mode === 'wardrobe') S.outfits = (S.shop.outfits || []);
    firstTab();
    S.open = true;
    const app = $('#app');
    app.classList.remove('hidden'); app.setAttribute('aria-hidden', 'false');
    app.classList.remove('enter'); void app.offsetWidth; app.classList.add('enter');
    render();
}
function close() {
    S.open = false;
    const app = $('#app');
    app.classList.add('hidden'); app.setAttribute('aria-hidden', 'true');
    $('#modal').classList.add('hidden');
}
function pickMode() {
    const c = S.config, t = S.shop.shopType;
    if (S.shop.wardrobe) return 'wardrobe';
    if (c.enableExit === false) return 'creator';
    if (t === 'clothing' && !c.ped) return 'clothing';
    if (t === 'barber') return 'barber';
    if (t === 'tattoo') return 'tattoo';
    if (t === 'surgeon') return 'surgeon';
    if (c.ped) return 'ped';
    if (c.tattoos && !c.components) return 'tattoo';
    if (c.headOverlays && !c.components) return 'barber';
    if ((c.headBlend || c.faceFeatures) && !c.components) return 'surgeon';
    return 'uniform';
}
function firstTab() {
    if (S.mode === 'clothing' || S.mode === 'uniform') { S.group = 'top'; S.cat = firstCatOf('top'); }
    else if (S.mode === 'barber') S.cat = 'hair';
    else if (S.mode === 'surgeon') S.cat = 'origin';
    else if (S.mode === 'tattoo') S.cat = ZONES[0][0];
    else if (S.mode === 'creator') { S.step = 0; S.cat = 'origin'; }
    else if (S.mode === 'ped') S.cat = 'model';
    camFor();
}
function firstCatOf(g) { return (ORDER[g] || []).find(catEnabled) || ORDER[g][0]; }

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type === 'appearance_display') open();
    else if (m.type === 'appearance_hide') close();
    else if (m.type === 'exti_outfits' && S.mode === 'wardrobe') { S.outfits = m.outfits || []; render(); }
});
