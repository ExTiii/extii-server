'use strict';

/* ======================================================================
   EX_Tii Roleplay — dealership panel.
   Same look as the garage panel: categories, car cards, details with
   performance, paint colour, test drive and buy. The 3D car is drawn by
   the game on the free side of the screen (left), turning slowly.
   ====================================================================== */

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_vehicleshop';
const IMAGE_URL = (model) => `https://docs.fivem.net/vehicles/${encodeURIComponent(String(model || '').toLowerCase())}.webp`;

// ---------------------------------------------------------------- icons
const svg = (d, size = 18, extra = '') =>
    `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" ${extra}>${d}</svg>`;
const ICON = {
    close: (s) => svg('<path d="M6 6l12 12M18 6L6 18"/>', s),
    search: (s) => svg('<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>', s),
    list: (s) => svg('<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1" fill="currentColor"/><circle cx="4.5" cy="12" r="1" fill="currentColor"/><circle cx="4.5" cy="18" r="1" fill="currentColor"/>', s),
    grid: (s) => svg('<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><rect x="13" y="13" width="7" height="7" rx="2"/>', s),
    forward: (s) => svg('<path d="M15 18l-6-6 6-6"/>', s),
    back: (s) => svg('<path d="M5 12h14M13 6l6 6-6 6"/>', s),
    shop: (s) => svg('<path d="M3.5 10l1.6-5h13.8l1.6 5"/><path d="M4.5 10v9.5h15V10"/><path d="M3.5 10h17"/><path d="M9.5 19.5v-5h5v5"/>', s),
    car: (s) => svg('<path d="M5 16.5V12l2-5h10l2 5v4.5"/><path d="M3.5 12h17"/><circle cx="7.5" cy="16.5" r="1.8"/><circle cx="16.5" cy="16.5" r="1.8"/><path d="M9.5 16.5h5"/>', s),
    suv: (s) => svg('<path d="M4 16.5V9.5l1.5-3h10l3 4 1.5.5v5.5"/><path d="M4 11h16"/><circle cx="8" cy="16.5" r="1.8"/><circle cx="16.5" cy="16.5" r="1.8"/>', s),
    speed: (s) => svg('<path d="M4.5 17a8 8 0 1 1 15 0"/><path d="M12 13l4-4"/><circle cx="12" cy="13" r="1.2" fill="currentColor"/>', s),
    crown: (s) => svg('<path d="M4 18h16M5 15l-1-8 4.5 3.5L12 5l3.5 5.5L20 7l-1 8z"/>', s),
    tuner: (s) => svg('<path d="M3.5 15.5l2.5-4.5h9l4 2.5 1.5.5v1.5"/><path d="M3 15.5h18"/><circle cx="7.5" cy="16" r="1.8"/><circle cx="17" cy="16" r="1.8"/><path d="M17 8.5h3.5"/>', s),
    truck: (s) => svg('<path d="M3 16V6.5h11V16"/><path d="M14 10h4l3 3.5V16h-7"/><circle cx="7" cy="16.5" r="1.8"/><circle cx="17" cy="16.5" r="1.8"/>', s),
    moto: (s) => svg('<circle cx="5.5" cy="16" r="3"/><circle cx="18.5" cy="16" r="3"/><path d="M5.5 16l4-6h5l4 6M14.5 10l-1.5-3h-2.5"/>', s),
    bike: (s) => svg('<circle cx="5.5" cy="16" r="3.5"/><circle cx="18.5" cy="16" r="3.5"/><path d="M5.5 16L9 9h6l3.5 7M9 9l3 7h-1M14 6.5h2.5"/>', s),
    mount: (s) => svg('<path d="M3 19l6-10 4 6 2.5-3.5L21 19z"/><circle cx="16.5" cy="6.5" r="1.6"/>', s),
    star: (s) => svg('<path d="M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>', s),
    boat: (s) => svg('<path d="M3 17c1.5 1.3 3 1.3 4.5 0s3-1.3 4.5 0 3 1.3 4.5 0 3-1.3 4.5 0"/><path d="M5 14l-1-4h16l-2 4M8 10V6h6l2 4"/>', s),
    heli: (s) => svg('<path d="M3 5h14M10 5v3"/><path d="M6 13a4 4 0 0 1 4-5h3.5a4.5 4.5 0 0 1 0 9H10a4 4 0 0 1-4-4z"/><path d="M18 12h3M8 20h8M10 17v3M14 17v3"/>', s),
    wheel: (s) => svg('<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="2"/><path d="M12 3.5V10M4.2 15.5L10.2 13M19.8 15.5L13.8 13"/>', s),
    bag: (s) => svg('<path d="M5 8h14l-1 12H6z"/><path d="M9 8V6.5a3 3 0 0 1 6 0V8"/>', s),
    lock: (s) => svg('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>', s),
    box: (s) => svg('<path d="M3 8l9-4 9 4-9 4z"/><path d="M3 8v8l9 4 9-4V8"/><path d="M12 12v8"/>', s),
    cash: (s) => svg('<rect x="3" y="6.5" width="18" height="11" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6.5 9.5v5M17.5 9.5v5"/>', s),
    bank: (s) => svg('<path d="M3.5 9.5L12 4.5l8.5 5"/><path d="M5.5 10v7M10 10v7M14 10v7M18.5 10v7M3.5 19.5h17"/>', s),
    rotate: (s) => svg('<path d="M20 12a8 8 0 1 1-2.3-5.6"/><path d="M20 4v4.5h-4.5"/>', s),
    seat: (s) => svg('<path d="M7 4h5l1 9h5l1 5H8z"/><path d="M8 18v2.5M18 18v2.5"/>', s),
    info: (s) => svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>', s),
    flag: (s) => svg('<path d="M5 21V4"/><path d="M5 4h13l-2.5 4 2.5 4H5"/><path d="M8 4v8M11 4v8M14 4v8"/>', s),
    bolt: (s) => svg('<path d="M13 3L5 13.5h6L10 21l8-10.5h-6z"/>', s),
    muscle: (s) => svg('<path d="M3 13.5h3l2-4h8l2 4h3v3h-2.2a2.3 2.3 0 0 1-4.6 0H9.8a2.3 2.3 0 0 1-4.6 0H3z"/><path d="M9 9.5l1-3h4l1 3"/>', s),
    paint: (s) => svg('<path d="M4 14.5c3-.5 4.5 1 4.5 3.5 0 1.5-1 2.5-2.5 2.5H4z"/><path d="M8.5 16L19 5.5a1.6 1.6 0 0 1 2.3 2.3L10.8 18.3"/>', s),
};
const catIcon = (name, s) => (ICON[name] || ICON.car)(s);

// ---------------------------------------------------------------- helpers
const $ = (sel) => document.querySelector(sel);
const esc = (value) =>
    String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '⁦$' + Math.max(0, Math.round(Number(n) || 0)).toLocaleString('en-US') + '⁩';

const count = (n, one, two, few, many) => {
    n = Math.round(Number(n) || 0);
    if (n === 0) return `0 ${many}`;
    if (n === 1) return one;
    if (n === 2) return two;
    if (n >= 3 && n <= 10) return `${n} ${few}`;
    return `${n} ${many}`;
};
const vehiclesWord = (n) => count(n, 'مركبة واحدة', 'مركبتان', 'مركبات', 'مركبة');
const minutesWord = (m) => {
    const n = Number(m) || 0;
    if (n > 0 && n < 1) return `${Math.round(n * 60)} ثانية`;
    return count(n, 'دقيقة واحدة', 'دقيقتان', 'دقائق', 'دقيقة');
};
const seatsWord = (n) => count(n, 'مقعد واحد', 'مقعدان', 'مقاعد', 'مقعدًا');

const ERRORS = {
    no_money: 'لا تملك مالًا كافيًا',
    no_space: 'مكان التسليم مشغول، انتظر قليلًا ثم حاول مرة أخرى',
    not_here: 'يجب أن تكون داخل المعرض',
    not_sold: 'هذه المركبة غير معروضة للبيع هنا',
    in_test: 'أنت في تجربة قيادة الآن',
    busy: 'انتظر قليلًا ثم حاول مرة أخرى',
    load: 'تعذّر تحميل المركبة، جرّب مرة أخرى',
    failed: 'حدث خطأ، حاول مرة أخرى',
};
const errorText = (code) => ERRORS[code] || ERRORS.failed;

async function post(event, data) {
    try {
        const resp = await fetch(`https://${RESOURCE}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data ?? {}),
        });
        return await resp.json();
    } catch (e) {
        return null;
    }
}

const store = {
    get(key, fallback) { try { return localStorage.getItem(key) ?? fallback; } catch (e) { return fallback; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch (e) { /* ignore */ } },
};

// ---------------------------------------------------------------- state
const state = {
    open: false,
    data: null,
    filter: 'all',
    view: store.get('vshop:view', 'grid') === 'list' ? 'list' : 'grid',
    query: '',
    selected: null,
    detail: false,
    colour: 0,
    stats: {},
    loading: false,
    sheet: null,
    account: 'cash',
    busy: false,
};
const brokenImages = new Set();
const selectToken = { n: 0 };

const vehicles = () => (state.data && Array.isArray(state.data.vehicles) ? state.data.vehicles : []);
// EX_Tii: levels. Every vehicle has one; the player's own level comes with the open message.
const myLevel = () => Number(state.data && state.data.level) || 1;
const needLevel = (v) => Number(v && v.level) || 1;
const locked = (v) => needLevel(v) > myLevel();
const levelBadge = (v) => `<span class="lvl ${locked(v) ? 'lock' : ''}" title="المستوى المطلوب">${locked(v) ? ICON.lock(11) : ''}المستوى ${needLevel(v)}</span>`;
const kg = (n) => `${Number(n) || 0}<small> كغ</small>`;
const categories = () => (state.data && Array.isArray(state.data.categories) ? state.data.categories : []);
const colours = () => (state.data && Array.isArray(state.data.colours) ? state.data.colours : []);
const byModel = (model) => vehicles().find((v) => v.model === model) || null;
const category = (id) => categories().find((c) => c.id === id) || null;
const selected = () => byModel(state.selected);
const isWater = (v) => v && v.category === 'boats';
const isAir = (v) => v && v.category === 'air';

const colourName = (i) => (i > 0 && colours()[i - 1] ? colours()[i - 1].label : 'لون المصنع');

// ---------------------------------------------------------------- images
function carImage(v, size = 34) {
    if (!v.model || brokenImages.has(v.model)) return `<span class="car-fallback">${ICON.car(size)}</span>`;
    return `<img data-car="${esc(v.model)}" data-size="${size}" src="${IMAGE_URL(v.model)}" alt="" loading="lazy" draggable="false" />`;
}

document.addEventListener('error', (e) => {
    const img = e.target;
    if (!(img instanceof HTMLImageElement) || img.dataset.car == null) return;
    brokenImages.add(img.dataset.car);
    const span = document.createElement('span');
    span.className = 'car-fallback';
    span.innerHTML = ICON.car(Number(img.dataset.size) || 34);
    img.replaceWith(span);
}, true);

// ---------------------------------------------------------------- list screen
function filtered() {
    const q = state.query.trim().toLowerCase();
    return vehicles().filter((v) => {
        if (state.filter !== 'all' && v.category !== state.filter) return false;
        if (!q) return true;
        const cat = category(v.category);
        return [v.name, v.brand, v.model, cat && cat.label, cat && cat.en].some((s) => String(s || '').toLowerCase().includes(q));
    }).sort((a, b) => (needLevel(a) - needLevel(b)) || (a.price - b.price));   // lowest level first, then price
}

function renderHeader() {
    const d = state.data || {};
    const all = vehicles();
    const icon = d.shop && d.shop.id === 'boats' ? ICON.boat(22) : d.shop && d.shop.id === 'air' ? ICON.heli(22) : ICON.shop(22);
    $('#shop-icon').innerHTML = icon;
    $('#shop-title').textContent = (d.shop && d.shop.label) || 'المعرض';
    const prices = all.map((v) => v.price);
    const range = prices.length ? ` · من ${money(Math.min(...prices))} إلى ${money(Math.max(...prices))}` : '';
    $('#shop-subtitle').innerHTML = esc(vehiclesWord(all.length)) + range + ` · <b class="me-lvl">مستواك ${myLevel()}</b>`;
    document.querySelector('.search-icon').innerHTML = ICON.search(17);
    document.querySelector('[data-action="close"]').innerHTML = ICON.close(18);
}

function renderChips() {
    const all = vehicles();
    const chips = [{ id: 'all', text: 'الكل', n: all.length }];
    for (const c of categories()) {
        const n = all.filter((v) => v.category === c.id).length;
        if (n) chips.push({ id: c.id, text: c.label, en: c.en, n });
    }
    if (!chips.some((c) => c.id === state.filter)) state.filter = 'all';
    $('#chips').innerHTML = chips.map((c) =>
        `<button class="chip ${c.id === state.filter ? 'active' : ''}" data-filter="${esc(c.id)}">${esc(c.text)}${c.en ? ` <small>(${esc(c.en)})</small>` : ''} <b>${c.n}</b></button>`).join('');

    document.querySelectorAll('.vt').forEach((b) => {
        b.classList.toggle('active', b.dataset.view === state.view);
        b.innerHTML = b.dataset.view === 'list' ? ICON.list(16) : ICON.grid(16);
    });
}

function rowHtml(v) {
    const cat = category(v.category);
    return `
    <div class="row ${v.model === state.selected ? 'selected' : ''} ${locked(v) ? 'is-locked' : ''}" role="button" tabindex="0" data-open="${esc(v.model)}">
        <div class="thumb">${carImage(v, 30)}</div>
        <div class="row-main">
            <span class="row-title">${esc(v.name)}</span>
            ${v.brand ? `<span class="vbrand">${esc(v.brand)}</span>` : ''}
            <div class="row-meta"><span class="price">${money(v.price)}</span>${levelBadge(v)}${cat ? `<span class="tag">${esc(cat.label)}</span>` : ''}${v.category === 'storage' ? `<span class="tag store">${ICON.box(11)} ${kg(v.storage)}</span>` : ''}</div>
        </div>
        <div class="row-end">${ICON.forward(18)}</div>
    </div>`;
}

function cardHtml(v) {
    return `
    <div class="card ${v.model === state.selected ? 'selected' : ''} ${locked(v) ? 'is-locked' : ''}" role="button" tabindex="0" data-open="${esc(v.model)}">
        <div class="thumb">${carImage(v, 40)}${levelBadge(v)}</div>
        <div class="card-body">
            <span class="row-title">${esc(v.name)}</span>
            ${v.brand ? `<span class="vbrand">${esc(v.brand)}</span>` : ''}
            <span class="price">${money(v.price)}${v.category === 'storage' ? ` <span class="tag store">${ICON.box(11)} ${kg(v.storage)}</span>` : ''}</span>
        </div>
    </div>`;
}

function emptyHtml() {
    return `<div class="empty"><div class="empty-icon">${ICON.car(30)}</div><h3>لا توجد نتائج</h3><p>جرّب كلمة بحث أخرى أو اختر «الكل».</p></div>`;
}

function renderList() {
    const list = $('#list');
    const items = filtered();
    list.className = state.view === 'grid' && items.length ? 'grid' : '';
    list.innerHTML = items.length ? items.map(state.view === 'grid' ? cardHtml : rowHtml).join('') : emptyHtml();
    $('#foot').innerHTML = `<span>${esc(vehiclesWord(items.length))}</span><span><kbd>Esc</kbd> للإغلاق</span>`;
}

// ---------------------------------------------------------------- 3D caption
function renderStage() {
    const v = selected();
    const el = $('#stage');
    if (!v) { el.classList.remove('show'); return; }
    const cat = category(v.category);
    el.innerHTML = `
        ${cat ? `<span class="s-cat">${catIcon(cat.icon, 15)} ${esc(cat.label)}</span>` : ''}
        ${v.brand ? `<div class="s-brand">${esc(v.brand)}</div>` : ''}
        <div class="s-name">${esc(v.name)}</div>
        <div class="s-price">${money(v.price)}</div>
        ${state.data && state.data.shop && state.data.shop.spin === false
            ? `<div class="s-hint">${ICON.paint(15)} ${esc(colourName(state.colour))}</div>`
            : `<div class="s-hint">${ICON.rotate(15)} المركبة تدور ببطء · ${esc(colourName(state.colour))}</div>`}`;
    el.classList.add('show');
    $('#loading3d').classList.toggle('show', state.loading);
}

// ---------------------------------------------------------------- detail screen
function statBar(label, value, max) {
    const pct = Math.max(4, Math.min(100, Math.round((Number(value) || 0) / max * 100)));
    return `<div class="stat"><span>${label}</span><div class="bar"><i style="width:${pct}%"></i></div></div>`;
}

function statsHtml(v) {
    const s = state.stats[v.model];
    if (!s) return `<div class="stats-loading"><span class="spinner"></span> جارٍ قراءة الأداء…</div>`;
    const landOnly = !isWater(v) && !isAir(v);
    return `
        <div class="speed-line"><span>السرعة القصوى</span><b>${Math.round(s.speed)}<small>كم/س</small></b></div>
        ${statBar('السرعة', s.speed, isAir(v) ? 600 : 330)}
        ${landOnly ? statBar('التسارع', s.accel, 0.45) : ''}
        ${landOnly ? statBar('الفرامل', s.brake, 1.6) : ''}
        ${landOnly ? statBar('الثبات', s.grip, 3.2) : ''}
        <div class="seats">${ICON.seat(15)} <b>${esc(seatsWord(s.seats))}</b></div>
        ${landOnly ? `<div class="storage-line"><span>${ICON.box(15)} التخزين</span><b>الصندوق ${kg(v.storage)} · الدرج ${kg(4)}</b></div>` : ''}`;
}

function swatchesHtml() {
    const list = [`<button class="swatch factory ${state.colour === 0 ? 'on' : ''}" data-colour="0" title="لون المصنع" aria-label="لون المصنع"></button>`];
    colours().forEach((c, i) => {
        const rgb = Array.isArray(c.rgb) ? c.rgb : [0, 0, 0];
        list.push(`<button class="swatch ${state.colour === i + 1 ? 'on' : ''}" data-colour="${i + 1}" title="${esc(c.label)}" aria-label="${esc(c.label)}" style="background: rgb(${rgb.map((n) => Math.max(0, Math.min(255, Number(n) || 0))).join(',')})"></button>`);
    });
    return list.join('');
}

function renderDetail() {
    const v = selected();
    const el = $('#screen-detail');
    if (!v) { el.innerHTML = ''; return; }
    const d = state.data || {};
    const cat = category(v.category);
    const isLocked = locked(v);
    const test = d.testDrive && !isLocked
        ? `<button class="btn" data-act="test" ${state.busy ? 'disabled' : ''}>${ICON.wheel(18)} تجربة القيادة · ${esc(minutesWord(d.testDrive))}</button>`
        : '';
    const buy = isLocked
        ? `<button class="btn locked" disabled>${ICON.lock(18)} يفتح في المستوى ${needLevel(v)} · مستواك ${myLevel()}</button>`
        : d.canBuy !== false
        ? `<button class="btn primary" data-act="buy" ${state.busy ? 'disabled' : ''}>${ICON.bag(18)} شراء · ${money(v.price)}</button>`
        : '';

    el.innerHTML = `
        <div class="d-top">
            <button class="icon-btn" data-act="back" aria-label="رجوع">${ICON.back(18)}</button>
            <button class="icon-btn" data-action="close" aria-label="إغلاق">${ICON.close(18)}</button>
        </div>
        <div class="d-scroll">
            <div class="d-head">
                ${v.brand ? `<div class="d-brand">${esc(v.brand)}</div>` : ''}
                <h2 class="d-title">${esc(v.name)}</h2>
                <div class="d-row">
                    <span>${cat ? `<span class="tag">${esc(cat.label)} <span dir="ltr">(${esc(cat.en)})</span></span>` : ''} ${levelBadge(v)}</span>
                    <span class="d-price">${money(v.price)}</span>
                </div>
            </div>

            <div class="box">
                <div class="box-title"><span>الأداء</span></div>
                <div id="stats">${statsHtml(v)}</div>
            </div>

            <div class="box">
                <div class="box-title"><span>اللون</span><span class="colour-name" id="colour-name">${esc(colourName(state.colour))}</span></div>
                <div class="swatches" id="swatches">${swatchesHtml()}</div>
            </div>

            <div class="note">${ICON.info(15)}<span>تستلم المركبة أمام المعرض مع مفاتيحها، وتُحفظ في مرآبك.</span></div>
        </div>
        <div class="d-bottom">
            ${buy}
            ${test ? `<div class="d-secondary">${test}</div>` : ''}
        </div>`;
}

function openDetail() {
    state.detail = true;
    renderDetail();
    $('.panel').classList.add('detail-open');
}

function closeDetail() {
    state.detail = false;
    $('.panel').classList.remove('detail-open');
    renderList();
}

// ---------------------------------------------------------------- select / preview
async function select(model, showDetail) {
    const v = byModel(model);
    if (!v) return;
    const changed = state.selected !== model;
    state.selected = model;
    if (showDetail) openDetail(); else if (state.detail) renderDetail();
    renderStage();
    document.querySelectorAll('[data-open]').forEach((el) => el.classList.toggle('selected', el.dataset.open === model));
    if (!changed && !state.loading) return;

    const token = ++selectToken.n;
    state.loading = true;
    renderStage();
    const ok = await post('select', { model });
    if (token !== selectToken.n || !state.open) return;
    state.loading = false;
    renderStage();
    if (ok === false) toast(errorText('load'), 'error');
}

function setColour(index) {
    state.colour = index;
    post('colour', { index });
    document.querySelectorAll('.swatch').forEach((el) => el.classList.toggle('on', Number(el.dataset.colour) === index));
    const name = $('#colour-name');
    if (name) name.textContent = colourName(index);
    renderStage();
}

// ---------------------------------------------------------------- buy sheet
function openSheet(html) {
    $('#sheet').innerHTML = `<div class="grabber"></div>${html}`;
    $('#sheet-layer').classList.add('open');
}

function closeSheet() {
    state.sheet = null;
    $('#sheet-layer').classList.remove('open');
}

function renderBuySheet() {
    const v = selected();
    if (!v) return;
    const m = (state.data && state.data.money) || {};
    const cash = Number(m.cash) || 0;
    const bank = Number(m.bank) || 0;
    if (state.account === 'cash' && cash < v.price && bank >= v.price) state.account = 'bank';
    if (state.account === 'bank' && bank < v.price && cash >= v.price) state.account = 'cash';
    const canPay = (state.account === 'cash' ? cash : bank) >= v.price;

    const option = (id, label, icon, balance) => {
        const enough = balance >= v.price;
        return `<button class="pay ${state.account === id ? 'on' : ''}" data-pay="${id}" ${enough ? '' : 'disabled'}>
            <span class="pay-l"><i>${icon}</i>${label}</span>
            <span class="pay-r">الرصيد<b>${money(balance)}</b>${enough ? '' : '<em>الرصيد لا يكفي</em>'}</span>
        </button>`;
    };

    openSheet(`
        <h3>تأكيد الشراء</h3>
        <p class="sheet-text">ستشتري <b dir="ltr">${esc((v.brand ? v.brand + ' ' : '') + v.name)}</b> باللون: ${esc(colourName(state.colour))}. تجدها أمام المعرض مع المفاتيح.</p>
        <div class="pay-options">
            ${option('cash', 'نقدًا', ICON.cash(18), cash)}
            ${option('bank', 'من البنك', ICON.bank(18), bank)}
        </div>
        <div class="sum"><span>المبلغ</span><b>${money(v.price)}</b></div>
        <div class="sheet-actions">
            <button class="btn" data-action="sheet-close">إلغاء</button>
            <button class="btn primary" data-act="confirm-buy" ${canPay && !state.busy ? '' : 'disabled'}>${state.busy ? '<span class="spinner"></span>' : ''} ادفع ${money(v.price)}</button>
        </div>`);
    state.sheet = 'buy';
}

async function confirmBuy() {
    const v = selected();
    if (!v || state.busy) return;
    state.busy = true;
    renderBuySheet();
    const res = await post('buy', { model: v.model, colour: state.colour, account: state.account });
    state.busy = false;
    if (!state.open) return;
    if (res && res.ok) return; // the game closes the panel
    renderBuySheet();
    toast(errorText(res && res.error), 'error');
}

async function startTestDrive() {
    const v = selected();
    if (!v || state.busy) return;
    state.busy = true;
    renderDetail();
    const res = await post('testdrive', { model: v.model, colour: state.colour });
    state.busy = false;
    if (!state.open) return;
    if (res && res.ok) return;
    renderDetail();
    toast(errorText(res && res.error), 'error');
}

// ---------------------------------------------------------------- toast
let toastTimer;
function toast(text, type = '') {
    const el = $('#toast');
    el.className = `toast show ${type}`;
    el.textContent = text;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), 2800);
}

// ---------------------------------------------------------------- open / close
function open(data) {
    state.open = true;
    state.data = data || {};
    state.filter = 'all';
    state.query = '';
    state.selected = null;
    state.detail = false;
    state.colour = 0;
    state.stats = {};
    state.loading = false;
    state.busy = false;
    state.account = 'cash';
    closeSheet();
    $('#search').value = '';
    $('.panel').classList.remove('detail-open');
    $('#shop').classList.add('open');
    $('#shop').setAttribute('aria-hidden', 'false');

    renderHeader();
    renderChips();
    renderList();

    const focus = byModel(data && data.focus) ? data.focus : (vehicles()[0] && vehicles()[0].model);
    if (focus) {
        select(focus, false);
        const el = document.querySelector(`[data-open="${CSS.escape(focus)}"]`);
        if (el) el.scrollIntoView({ block: 'nearest' });
    }
}

function hide() {
    state.open = false;
    clearTimeout(toastTimer);
    $('#toast').className = 'toast';
    state.busy = false;
    selectToken.n++;
    closeSheet();
    $('#shop').classList.remove('open');
    $('#shop').setAttribute('aria-hidden', 'true');
    $('#stage').classList.remove('show');
    $('#loading3d').classList.remove('show');
}

function requestClose() {
    if (!state.open) return;
    post('close');
    hide();
}

// ---------------------------------------------------------------- events
window.addEventListener('message', (e) => {
    const msg = e.data || {};
    switch (msg.action) {
        case 'open': open(msg); break;
        case 'close': hide(); break;
        case 'stats':
            if (msg.model && msg.stats) {
                state.stats[msg.model] = msg.stats;
                if (state.selected === msg.model && state.detail) {
                    const box = $('#stats');
                    if (box) box.innerHTML = statsHtml(selected());
                }
            }
            break;
    }
});

document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-action],[data-act],[data-filter],[data-view],[data-open],[data-colour],[data-pay]');
    if (!t || !state.open) return;

    if (t.dataset.action === 'close') return requestClose();
    if (t.dataset.action === 'sheet-close') return closeSheet();

    if (t.dataset.filter) {
        state.filter = t.dataset.filter;
        renderChips();
        renderList();
        return;
    }
    if (t.dataset.view) {
        state.view = t.dataset.view === 'list' ? 'list' : 'grid';
        store.set('vshop:view', state.view);
        renderChips();
        renderList();
        return;
    }
    if (t.dataset.open) return select(t.dataset.open, true);
    if (t.dataset.colour != null) return setColour(Math.max(0, Math.min(colours().length, Number(t.dataset.colour) || 0)));
    if (t.dataset.pay) {
        if (t.disabled) return;
        state.account = t.dataset.pay === 'bank' ? 'bank' : 'cash';
        return renderBuySheet();
    }

    switch (t.dataset.act) {
        case 'back': return closeDetail();
        case 'buy': return renderBuySheet();
        case 'confirm-buy': return confirmBuy();
        case 'test': return startTestDrive();
    }
});

document.addEventListener('keydown', (e) => {
    if (!state.open) return;
    if (e.key === 'Escape') {
        e.preventDefault();
        if (state.sheet) closeSheet();
        else requestClose();
    } else if ((e.key === 'Enter' || e.key === ' ') && e.target && e.target.dataset && e.target.dataset.open) {
        e.preventDefault();
        select(e.target.dataset.open, true);
    }
});

// mouse wheel scrolls the category buttons sideways
$('#chips').addEventListener('wheel', (e) => {
    if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return;
    e.preventDefault();
    $('#chips').scrollBy({ left: -e.deltaY, behavior: 'smooth' });
}, { passive: false });

$('#search').addEventListener('input', (e) => {
    state.query = String(e.target.value || '').slice(0, 40);
    renderList();
});
