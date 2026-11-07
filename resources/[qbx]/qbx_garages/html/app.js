'use strict';

/* ======================================================================
   Garage screen — list / grid of vehicles, details, nickname, favourites,
   shared keys, move here, give to another player, finance payments.
   All text shown to players is Arabic. Player-made text (nicknames,
   names) is always escaped before it is shown.
   ====================================================================== */

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_garages';
const IMAGE_URL = (model) => `https://docs.fivem.net/vehicles/${encodeURIComponent(String(model || '').toLowerCase())}.webp`;

// ---------------------------------------------------------------- icons
const svg = (d, size = 18, extra = '') =>
    `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" ${extra}>${d}</svg>`;
const ICON = {
    close: (s) => svg('<path d="M6 6l12 12M18 6L6 18"/>', s),
    search: (s) => svg('<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>', s),
    list: (s) => svg('<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1" fill="currentColor"/><circle cx="4.5" cy="12" r="1" fill="currentColor"/><circle cx="4.5" cy="18" r="1" fill="currentColor"/>', s),
    grid: (s) => svg('<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><rect x="13" y="13" width="7" height="7" rx="2"/>', s),
    star: (s, on) => svg('<path d="M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>', s, on ? 'fill="currentColor"' : ''),
    forward: (s) => svg('<path d="M15 18l-6-6 6-6"/>', s),
    back: (s) => svg('<path d="M5 12h14M13 6l6 6-6 6"/>', s),
    garage: (s) => svg('<path d="M3 20V9.5L12 4l9 5.5V20"/><path d="M7 20v-7h10v7M7 16h10"/>', s),
    plane: (s) => svg('<path d="M10.5 13.5L4 11l1.5-1.5 7 1 3.6-3.6c.8-.8 2.2-.9 2.9-.2.7.7.6 2.1-.2 2.9L15.2 13.2l1 7L14.7 21.7 12.2 15.2l-2.7 2.7.3 2.6-1.3 1.3-1.4-3.2-3.2-1.4 1.3-1.3 2.6.3z"/>', s),
    boat: (s) => svg('<path d="M3 17c1.5 1.3 3 1.3 4.5 0s3-1.3 4.5 0 3 1.3 4.5 0 3-1.3 4.5 0"/><path d="M5 14l-1-4h16l-2 4M8 10V6h6l2 4"/>', s),
    car: (s) => svg('<path d="M5 16.5V12l2-5h10l2 5v4.5"/><path d="M3.5 12h17"/><circle cx="7.5" cy="16.5" r="1.8"/><circle cx="16.5" cy="16.5" r="1.8"/><path d="M9.5 16.5h5"/>', s),
    pencil: (s) => svg('<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>', s),
    key: (s) => svg('<circle cx="8" cy="15" r="4"/><path d="M10.8 12.2L19 4M16 7l2.5 2.5M14 9l2 2"/>', s),
    gift: (s) => svg('<rect x="3.5" y="9" width="17" height="11" rx="2"/><path d="M12 9v11M3.5 13h17"/><path d="M12 9c-1.5-3-5-3.5-5-1.2C7 9 9.5 9 12 9zm0 0c1.5-3 5-3.5 5-1.2C17 9 14.5 9 12 9z"/>', s),
    pin: (s) => svg('<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>', s),
    clock: (s) => svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', s),
    info: (s) => svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>', s),
    take: (s) => svg('<path d="M4 12h12M11 7l-5 5 5 5"/><path d="M20 5v14"/>', s),
    move: (s) => svg('<path d="M4 7h13l-3-3M20 17H7l3 3"/>', s),
    trash: (s) => svg('<path d="M5 7h14M10 11v6M14 11v6M7 7l1 12h8l1-12M9.5 7V4.5h5V7"/>', s),
    shared: (s) => svg('<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.6-3 2.8-4.6 5.5-4.6s4.9 1.6 5.5 4.6"/><path d="M16 5.2a3 3 0 0 1 0 5.6M18.2 14.6c1.4.7 2.2 2.2 2.4 4.4"/>', s),
};

// ---------------------------------------------------------------- helpers
const $ = (sel) => document.querySelector(sel);
const esc = (value) =>
    String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
// Wrapped in direction marks so "$1,200" never flips inside Arabic text
const money = (n) => '\u2066$' + Math.max(0, Math.round(Number(n) || 0)).toLocaleString('en-US') + '\u2069';

// Correct Arabic counting (1 / 2 / 3-10 / 11+)
const count = (n, one, two, few, many) => {
    n = Math.round(Number(n) || 0);
    if (n === 0) return `0 ${many}`;
    if (n === 1) return one;
    if (n === 2) return two;
    if (n >= 3 && n <= 10) return `${n} ${few}`;
    return `${n} ${many}`;
};
const vehiclesWord = (n) => count(n, 'مركبة واحدة', 'مركبتان', 'مركبات', 'مركبة');
const hoursWord = (n) => count(n, 'ساعة واحدة', 'ساعتين', 'ساعات', 'ساعة');
const minutesWord = (n) => count(n, 'دقيقة واحدة', 'دقيقتين', 'دقائق', 'دقيقة');
const paymentsWord = (n) => count(n, 'قسط واحد', 'قسطان', 'أقساط', 'قسطًا');

const ERRORS = {
    no_money: 'لا تملك مالًا كافيًا',
    too_far: 'اقترب أكثر من المرآب',
    not_owner: 'هذه المركبة ليست ملكك',
    not_parked: 'يجب أن تكون المركبة مركونة في مرآب',
    is_out: 'المركبة خارج المرآب الآن',
    wrong_type: 'لا يمكن ركن هذا النوع من المركبات هنا',
    no_access: 'لا يمكنك استخدام هذا المرآب',
    bad_player: 'لم نجد لاعبًا بهذا الرقم',
    too_many: 'وصلت إلى الحد الأقصى من الأشخاص لهذه المركبة',
    financed: 'لا يمكن إهداء مركبة عليها أقساط، سدّدها أولًا',
    declined: 'رفض اللاعب أو لم يرد في الوقت المحدد',
    busy: 'انتظر قليلًا ثم حاول مرة أخرى',
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

// ---------------------------------------------------------------- state
const store = {
    get(key, fallback) { try { return localStorage.getItem(key) ?? fallback; } catch (e) { return fallback; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch (e) { /* ignore */ } },
};

const state = {
    open: false,
    data: null,
    filter: 'all',
    view: store.get('garage:view', 'list') === 'grid' ? 'grid' : 'list',
    query: '',
    selectedId: null,
    sheet: null,
    busy: false,
};
const brokenImages = new Set();

const vehicles = () => (state.data && Array.isArray(state.data.vehicles) ? state.data.vehicles : []);
const selected = () => vehicles().find((v) => v.id === state.selectedId) || null;
const displayName = (v) => (v.nickname && v.nickname.trim()) || v.label || v.model;

const STATUS_RANK = { here: 0, other: 1, out: 2, impounded: 3 };
function sortVehicles(list) {
    return [...list].sort((a, b) =>
        (b.favourite === true) - (a.favourite === true) ||
        (STATUS_RANK[a.status] ?? 9) - (STATUS_RANK[b.status] ?? 9) ||
        displayName(a).localeCompare(displayName(b), 'ar'));
}

function statusInfo(v) {
    const d = state.data || {};
    if (d.isDepot) return { cls: 'impounded', text: 'محجوزة' };
    switch (v.status) {
        case 'here': return { cls: 'here', text: 'هنا' };
        case 'other': return { cls: 'other', text: v.garageLabel ? `في ${v.garageLabel}` : 'في مرآب آخر' };
        case 'out': return { cls: 'out', text: 'خارج المرآب' };
        default: return { cls: 'impounded', text: 'في الحجز' };
    }
}

// ---------------------------------------------------------------- images
// EX_Tii: real photo of the player's own car (their colour), when the game has taken one
const photoCache = new Map(); // vehicle id -> { version, data }
const realPhoto = (v) => {
    const p = v && v.photo ? photoCache.get(v.id) : null;
    return p && p.version === v.photo && /^data:image\/webp;base64,[A-Za-z0-9+/=]+$/.test(p.data) ? p.data : null;
};

function carImage(v, size = 34) {
    const real = realPhoto(v);
    if (real) return `<img class="real" src="${real}" alt="" draggable="false" />`;
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
    return sortVehicles(vehicles().filter((v) => {
        if (state.filter === 'here' && v.status !== 'here') return false;
        if (state.filter === 'fav' && !v.favourite) return false;
        if (state.filter === 'shared' && v.owner) return false;
        if (state.filter === 'impounded' && v.status !== 'impounded') return false;
        if (!q) return true;
        return [v.nickname, v.label, v.model, v.plate].some((s) => String(s || '').toLowerCase().includes(q));
    }));
}

function renderHeader() {
    const d = state.data || {};
    const all = vehicles();
    const icon = d.vehicleType === 'air' ? ICON.plane(22) : d.vehicleType === 'sea' ? ICON.boat(22) : ICON.garage(22);
    $('#garage-icon').innerHTML = icon;
    $('#garage-title').textContent = d.label || 'المرآب';
    let sub;
    if (d.isDepot) sub = all.length ? `${vehiclesWord(all.length)} بانتظار الاستلام` : 'لا توجد مركبات محجوزة';
    else if (d.isPublic) {
        const here = all.filter((v) => v.status === 'here').length;
        sub = `${here} هنا · ${vehiclesWord(all.length)} لديك`;
    } else sub = vehiclesWord(all.length);
    $('#garage-subtitle').textContent = sub;
}

function renderChips() {
    const d = state.data || {};
    const all = vehicles();
    const chips = [{ id: 'all', text: 'الكل', n: all.length }];
    if (!d.isDepot) {
        if (d.isPublic) chips.push({ id: 'here', text: 'هنا', n: all.filter((v) => v.status === 'here').length });
        chips.push({ id: 'fav', text: 'المفضلة', n: all.filter((v) => v.favourite).length });
        const shared = all.filter((v) => !v.owner).length;
        if (d.isPublic && shared) chips.push({ id: 'shared', text: 'مشتركة معي', n: shared });
        const pound = all.filter((v) => v.status === 'impounded').length;
        if (d.isPublic && pound) chips.push({ id: 'impounded', text: 'في الحجز', n: pound });
    }
    if (!chips.some((c) => c.id === state.filter)) state.filter = 'all';
    $('#chips').innerHTML = chips.map((c) =>
        `<button class="chip ${c.id === state.filter ? 'active' : ''}" data-filter="${c.id}">${c.text} <b>${c.n}</b></button>`).join('');

    document.querySelectorAll('.vt').forEach((b) => {
        b.classList.toggle('active', b.dataset.view === state.view);
        b.innerHTML = b.dataset.view === 'list' ? ICON.list(16) : ICON.grid(16);
    });
}

function rowHtml(v) {
    const st = statusInfo(v);
    const sub = v.nickname ? `<span class="row-sub">${esc(v.label)}</span>` : '';
    const sharedTag = !v.owner ? `<span class="tag">مشتركة</span>` : '';
    return `
    <div class="row" role="button" tabindex="0" data-open="${v.id}">
        <div class="thumb">${carImage(v, 30)}</div>
        <div class="row-main">
            <span class="row-title">${esc(displayName(v))}</span>
            ${sub}
            <div class="row-meta">
                <span class="plate">${esc(v.plate)}</span>
                <span class="status ${st.cls}">${esc(st.text)}</span>
                ${sharedTag}
            </div>
        </div>
        <div class="row-end">
            <button class="star ${v.favourite ? 'on' : ''}" data-fav="${v.id}" aria-label="مفضلة">${ICON.star(17, v.favourite)}</button>
            ${ICON.forward(18)}
        </div>
    </div>`;
}

function cardHtml(v) {
    const st = statusInfo(v);
    return `
    <div class="card" role="button" tabindex="0" data-open="${v.id}">
        <div class="thumb">${carImage(v, 40)}</div>
        <span class="status ${st.cls}">${esc(st.text)}</span>
        <button class="star ${v.favourite ? 'on' : ''}" data-fav="${v.id}" aria-label="مفضلة">${ICON.star(16, v.favourite)}</button>
        <div class="card-body">
            <span class="row-title">${esc(displayName(v))}</span>
            <div class="row-meta"><span class="plate">${esc(v.plate)}</span>${!v.owner ? '<span class="tag">مشتركة</span>' : ''}</div>
        </div>
    </div>`;
}

function emptyHtml() {
    const d = state.data || {};
    const nothing = vehicles().length === 0;
    let title = 'لا توجد نتائج';
    let text = 'جرّب كلمة بحث أخرى أو اختر عرض «الكل».';
    if (nothing && d.isDepot) { title = 'لا توجد مركبات محجوزة'; text = 'كل مركباتك في أمان.'; }
    else if (nothing) { title = 'لا توجد مركبات هنا'; text = 'اركن مركبتك عند علامة الركن وستظهر هنا.'; }
    else if (state.filter === 'fav' && !state.query) { title = 'لا توجد مفضلة بعد'; text = 'اضغط على النجمة بجانب أي مركبة لتظهر هنا.'; }
    return `<div class="empty"><div class="empty-icon">${ICON.car(30)}</div><h3>${title}</h3><p>${text}</p></div>`;
}

function renderList() {
    const list = $('#list');
    const items = filtered();
    list.className = state.view === 'grid' && items.length ? 'grid' : '';
    list.innerHTML = items.length ? items.map(state.view === 'grid' ? cardHtml : rowHtml).join('') : emptyHtml();
    $('#foot').innerHTML = `<span>${vehiclesWord(items.length)}</span><span><kbd>Esc</kbd> للإغلاق</span>`;
}

function renderAll() {
    renderHeader();
    renderChips();
    renderList();
    if (state.selectedId != null) {
        if (selected()) renderDetail();
        else closeDetail();
    }
    loadPhotos();
}

let photosLoading = false;
async function loadPhotos() {
    if (photosLoading) return;
    const missing = vehicles().filter((v) => v.photo && !realPhoto(v)).map((v) => v.id).slice(0, 40);
    if (!missing.length) return;
    photosLoading = true;
    const result = await post('photos', { ids: missing });
    photosLoading = false;
    if (!Array.isArray(result) || !state.open) return;
    let changed = false;
    for (const p of result) {
        if (p && Number.isInteger(p.id) && typeof p.photo === 'string') {
            photoCache.set(p.id, { version: p.version, data: p.photo });
            changed = true;
        }
    }
    if (changed) {
        renderList();
        if (state.selectedId != null && selected()) renderDetail();
    }
}

// ---------------------------------------------------------------- detail screen
function meter(label, value) {
    const v = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
    const cls = v >= 60 ? '' : v >= 30 ? 'mid' : 'low';
    return `<div>
        <div class="meter-top"><span>${label}</span><b>${v}<small>%</small></b></div>
        <div class="bar"><i class="${cls}" style="width:${v}%"></i></div>
    </div>`;
}

function dueText(minutes) {
    const m = Math.max(0, Math.round(Number(minutes) || 0));
    if (m < 60) return minutesWord(m);
    return hoursWord(Math.round(m / 60));
}

function financeHtml(v) {
    const f = v.finance;
    if (!f) return '';
    const lastOne = f.payment >= f.balance;
    const soon = f.minutes <= 60;
    return `<div class="box">
        <div class="box-title"><span>التقسيط</span><span>المتبقي: ${paymentsWord(f.left)}</span></div>
        <div class="fin-grid">
            <div><span>القسط</span><b>${money(f.payment)}</b></div>
            <div><span>المبلغ المتبقي</span><b>${money(f.balance)}</b></div>
            <div><span>الأقساط المتبقية</span><b>${f.left}</b></div>
        </div>
        <div class="fin-due ${soon ? 'warn' : ''}">${ICON.clock(15)} موعد القسط القادم بعد ${dueText(f.minutes)} من اللعب</div>
        <div class="fin-actions">
            ${lastOne ? '' : `<button class="btn small" data-act="pay">ادفع قسطًا · ${money(f.payment)}</button>`}
            <button class="btn small ${lastOne ? 'primary' : ''}" data-act="payfull">سدّد الكل · ${money(f.balance)}</button>
        </div>
    </div>`;
}

function primaryAction(v) {
    const d = state.data || {};
    if (d.isDepot) {
        if (!v.canTakeOut) return `<button class="btn info" disabled>${ICON.info(16)} المركبة موجودة في الشارع</button>`;
        return `<button class="btn primary" data-act="take">${ICON.take(18)} استلام المركبة${v.depotPrice > 0 ? ' · ' + money(v.depotPrice) : ''}</button>`;
    }
    switch (v.status) {
        case 'here':
            return v.canTakeOut
                ? `<button class="btn primary" data-act="take">${ICON.take(18)} إخراج المركبة</button>`
                : `<button class="btn info" disabled>${ICON.info(16)} المركبة في الشارع الآن</button>`;
        case 'other':
            // EX_Tii: a car parked in any garage comes out free here
            return v.canTakeOut
                ? `<button class="btn primary" data-act="take">${ICON.take(18)} إخراج المركبة · مجانًا</button>`
                : `<button class="btn info" disabled>${ICON.info(16)} المركبة في الشارع الآن</button>`;
        case 'out':
            return `<button class="btn info" disabled>${ICON.info(16)} المركبة خارج المرآب الآن</button>`;
        default:
            return `<button class="btn primary" data-act="route">${ICON.pin(18)} حدّد أقرب ساحة حجز على الخريطة</button>`;
    }
}

function renderDetail() {
    const v = selected();
    if (!v) return;
    const d = state.data || {};
    const st = statusInfo(v);
    const canManage = v.owner && d.isPublic && !d.isDepot;
    const sharedCount = Array.isArray(v.sharedWith) ? v.sharedWith.length : 0;
    const place = v.status === 'here' ? d.label : v.status === 'other' ? v.garageLabel : null;

    $('#screen-detail').innerHTML = `
        <div class="d-top">
            <button class="icon-btn" data-act="back" aria-label="رجوع">${ICON.back(18)}</button>
            <div class="d-actions">
                <button class="icon-btn star ${v.favourite ? 'on' : ''}" data-fav="${v.id}" aria-label="مفضلة">${ICON.star(18, v.favourite)}</button>
                <button class="icon-btn" data-action="close" aria-label="إغلاق">${ICON.close(18)}</button>
            </div>
        </div>
        <div class="d-scroll">
            <div class="hero">${carImage(v, 56)}</div>
            <div class="d-name">
                <h2>${esc(displayName(v))}</h2>
                ${v.owner ? `<button class="edit" data-act="rename" aria-label="تغيير الاسم">${ICON.pencil(15)}</button>` : ''}
            </div>
            ${v.nickname ? `<div class="d-model">${esc(v.label)}</div>` : ''}
            <div class="d-meta">
                <span class="plate">${esc(v.plate)}</span>
                <span class="status ${st.cls}">${esc(st.text)}</span>
                ${place ? `<span class="d-place">${ICON.pin(14)} ${esc(place)}</span>` : ''}
            </div>

            <div class="box">
                <div class="box-title"><span>حالة المركبة</span></div>
                <div class="meters">${meter('الوقود', v.fuel)}${meter('المحرك', v.engine)}${meter('الهيكل', v.body)}</div>
            </div>

            ${financeHtml(v)}

            ${!d.isDepot && v.status === 'impounded' ? `<div class="note warn">${ICON.info(16)} <span>هذه المركبة في الحجز. استلمها من أي ساحة حجز${v.depotPrice > 0 ? ' مقابل ' + money(v.depotPrice) : ''}.</span></div>` : ''}
            ${!d.isDepot && v.status === 'other' && v.canTakeOut ? `<div class="note">${ICON.pin(16)} <span>مركونة في ${esc(v.garageLabel || 'مرآب آخر')}، ويمكنك إخراجها من هنا مجانًا.</span></div>` : ''}

            ${!v.owner ? `<div class="note">${ICON.shared(16)} <span>مشتركة معك${v.ownerName ? ' من ' + esc(v.ownerName) : ''}. يمكنك قيادتها وإخراجها، والمالك وحده يستطيع تعديلها.</span></div>` : ''}
            ${canManage && sharedCount ? `<div class="note">${ICON.key(16)} <span>المفتاح مشترك مع ${sharedCount === 1 ? 'شخص واحد' : sharedCount === 2 ? 'شخصين' : sharedCount + ' أشخاص'}.</span></div>` : ''}
        </div>
        <div class="d-bottom">
            ${primaryAction(v)}
            ${canManage ? `<div class="d-secondary">
                <button class="btn small" data-act="share">${ICON.key(16)} مشاركة المفتاح</button>
                ${v.status === 'here' || v.status === 'other' ? `<button class="btn small" data-act="give">${ICON.gift(16)} إهداء المركبة</button>` : ''}
            </div>` : ''}
        </div>`;
}

function openDetail(id) {
    state.selectedId = id;
    renderDetail();
    $('.panel').classList.add('detail-open');
}

function closeDetail() {
    state.selectedId = null;
    $('.panel').classList.remove('detail-open');
}

// ---------------------------------------------------------------- sheets
function openSheet(kind) {
    const v = selected();
    if (!v) return;
    const d = state.data || {};
    state.sheet = kind;
    let html = '<div class="grabber"></div>';

    if (kind === 'rename') {
        html += `<h3>اسم المركبة</h3>
            <p class="sheet-text">اختر اسمًا يظهر لك بدل اسم الطراز. اتركه فارغًا لإرجاع الاسم الأصلي.</p>
            <div class="field"><label>الاسم</label><input id="sheet-input" maxlength="30" value="${esc(v.nickname || '')}" placeholder="${esc(v.label)}" /><div class="counter" id="counter"></div></div>
            <div class="sheet-actions"><button class="btn primary" data-act="rename-save">حفظ</button><button class="btn" data-action="sheet-close">إلغاء</button></div>`;
    } else if (kind === 'share') {
        const people = Array.isArray(v.sharedWith) ? v.sharedWith : [];
        const full = people.length >= (d.maxShares ?? 5);
        html += `<h3>مشاركة المفتاح</h3>
            <p class="sheet-text">من تشاركه المفتاح يستطيع قيادة المركبة وإخراجها من المرآب وركنها. يمكنك إلغاء المشاركة في أي وقت.</p>
            <div class="people">${people.length ? people.map((p) => `
                <div class="person"><span><i class="avatar">${esc((p.name || '؟').trim().charAt(0))}</i>${esc(p.name || 'لاعب')}</span>
                <button data-unshare="${esc(p.citizenid)}">إلغاء</button></div>`).join('') : '<p class="sheet-text">لم تشارك المفتاح مع أحد بعد.</p>'}</div>
            ${full ? `<div class="warn-box">وصلت إلى الحد الأقصى (${d.maxShares} أشخاص). ألغِ مشاركة أحدهم لإضافة غيره.</div>` : `
            <div class="field"><label>رقم اللاعب (ID)</label><input id="sheet-input" inputmode="numeric" maxlength="5" placeholder="مثال: 12" /></div>
            <div class="sheet-actions"><button class="btn primary" data-act="share-save">${ICON.key(16)} مشاركة</button><button class="btn" data-action="sheet-close">إغلاق</button></div>`}`;
    } else if (kind === 'give') {
        html += `<h3>إهداء المركبة</h3>
            <p class="sheet-text">ستصبح المركبة ملكًا للاعب آخر وتبقى مركونة في مكانها.</p>
            <div class="warn-box">هذه الخطوة نهائية ولا يمكن التراجع عنها. سيظهر للاعب طلب، وعليه قبوله خلال 30 ثانية.</div>
            <div class="field"><label>رقم اللاعب (ID)</label><input id="sheet-input" inputmode="numeric" maxlength="5" placeholder="مثال: 12" /></div>
            <div class="sheet-actions"><button class="btn danger" data-act="give-save">${ICON.gift(16)} إرسال الطلب</button><button class="btn" data-action="sheet-close">إلغاء</button></div>`;
    } else if (kind === 'move') {
        html += `<h3>نقل المركبة إلى هنا</h3>
            <p class="sheet-text">ستُنقل ${esc(displayName(v))} من ${esc(v.garageLabel || 'المرآب الآخر')} إلى ${esc(d.label)} مقابل <b>${money(d.moveFee)}</b>، تُدفع من النقد أولًا ثم من البنك.</p>
            <div class="sheet-actions"><button class="btn primary" data-act="move-save">${ICON.move(16)} انقل · ${money(d.moveFee)}</button><button class="btn" data-action="sheet-close">إلغاء</button></div>`;
    } else if (kind === 'pay' || kind === 'payfull') {
        const f = v.finance;
        const amount = kind === 'pay' ? f.payment : f.balance;
        html += `<h3>${kind === 'pay' ? 'دفع قسط' : 'تسديد كامل المبلغ'}</h3>
            <p class="sheet-text">سيُخصم <b>${money(amount)}</b> من النقد أولًا ثم من البنك.${kind === 'payfull' ? ' بعدها تصبح المركبة ملكك بالكامل.' : ''}</p>
            <div class="sheet-actions"><button class="btn primary" data-act="${kind}-save">ادفع ${money(amount)}</button><button class="btn" data-action="sheet-close">إلغاء</button></div>`;
    }

    $('#sheet').innerHTML = html;
    $('#sheet-layer').classList.add('open');
    const input = $('#sheet-input');
    if (input) {
        if (kind === 'rename') {
            const update = () => { $('#counter').textContent = `${[...input.value].length} / 30`; };
            input.addEventListener('input', update);
            update();
        } else {
            input.addEventListener('input', () => { input.value = input.value.replace(/[^0-9]/g, ''); });
        }
        setTimeout(() => input.focus(), 120);
    }
}

function closeSheet() {
    state.sheet = null;
    $('#sheet-layer').classList.remove('open');
}

function setBusy(button, busy, label) {
    if (!button) return;
    if (busy) {
        button.dataset.label = button.innerHTML;
        button.disabled = true;
        button.innerHTML = `<span class="spinner"></span>${label ? ' ' + label : ''}`;
    } else {
        button.disabled = false;
        if (button.dataset.label) button.innerHTML = button.dataset.label;
    }
}

// ---------------------------------------------------------------- toast
let toastTimer;
function toast(text, type) {
    const el = $('#toast');
    el.textContent = text;
    el.className = `toast show ${type || ''}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { el.className = 'toast'; }, 2800);
}

// ---------------------------------------------------------------- actions
async function refresh() {
    const data = await post('refresh');
    if (data && typeof data === 'object' && Array.isArray(data.vehicles)) {
        state.data = data;
        renderAll();
    }
}

async function toggleFavourite(id) {
    const v = vehicles().find((x) => x.id === id);
    if (!v || state.busy) return;
    const value = !v.favourite;
    v.favourite = value; // instant feedback
    renderAll();
    const ok = await post('favourite', { id, value });
    if (ok !== true) {
        v.favourite = !value;
        renderAll();
        toast(errorText('failed'), 'error');
    }
}

async function run(action, button) {
    const v = selected();
    if (!v || state.busy) return;
    const input = $('#sheet-input');

    if (action === 'take') {
        post('takeOut', { id: v.id });
        return;
    }
    if (action === 'route') {
        const ok = await post('routeImpound');
        toast(ok === true ? 'حُدّدت أقرب ساحة حجز على الخريطة' : errorText('failed'), ok === true ? 'success' : 'error');
        return;
    }

    state.busy = true;
    try {
        if (action === 'rename-save') {
            const name = (input ? input.value : '').trim();
            if ([...name].length > 30) return toast('الاسم طويل، الحد 30 حرفًا', 'error');
            setBusy(button, true);
            const ok = await post('rename', { id: v.id, name });
            setBusy(button, false);
            if (ok !== true) return toast(errorText('failed'), 'error');
            closeSheet();
            toast(name ? 'تم حفظ الاسم' : 'عاد الاسم الأصلي', 'success');
            await refresh();
        } else if (action === 'share-save') {
            const target = parseInt(input ? input.value : '', 10);
            if (!target) return toast('اكتب رقم اللاعب', 'error');
            setBusy(button, true);
            const res = await post('share', { id: v.id, target });
            setBusy(button, false);
            if (!res || !res.ok) return toast(errorText(res && res.error), 'error');
            toast('تمت مشاركة المفتاح', 'success');
            await refresh();
            if (state.sheet === 'share') openSheet('share');
        } else if (action === 'give-save') {
            const target = parseInt(input ? input.value : '', 10);
            if (!target) return toast('اكتب رقم اللاعب', 'error');
            setBusy(button, true, 'بانتظار موافقة اللاعب…');
            const res = await post('give', { id: v.id, target });
            setBusy(button, false);
            if (!res || !res.ok) return toast(errorText(res && res.error), 'error');
            closeSheet();
            closeDetail();
            toast('تم إهداء المركبة', 'success');
            await refresh();
        } else if (action === 'move-save') {
            setBusy(button, true);
            const res = await post('moveHere', { id: v.id });
            setBusy(button, false);
            if (!res || !res.ok) return toast(errorText(res && res.error), 'error');
            closeSheet();
            toast('وصلت المركبة إلى هذا المرآب', 'success');
            await refresh();
        } else if (action === 'pay-save' || action === 'payfull-save') {
            const full = action === 'payfull-save';
            const before = v.finance ? v.finance.balance : 0;
            setBusy(button, true);
            const data = await post('payFinance', { id: v.id, full, amount: v.finance ? v.finance.payment : 0 });
            setBusy(button, false);
            closeSheet();
            if (data && Array.isArray(data.vehicles)) {
                state.data = data;
                const after = (data.vehicles.find((x) => x.id === v.id) || {}).finance;
                const paid = !after || after.balance < before;
                renderAll();
                toast(paid ? (after ? 'تم دفع القسط' : 'تم التسديد، المركبة ملكك بالكامل') : 'لم يتم الدفع', paid ? 'success' : 'error');
            } else {
                toast(errorText('failed'), 'error');
            }
        }
    } finally {
        state.busy = false;
    }
}

async function unshare(citizenid) {
    const v = selected();
    if (!v || state.busy) return;
    state.busy = true;
    const ok = await post('unshare', { id: v.id, citizenid });
    state.busy = false;
    if (ok !== true) return toast(errorText('failed'), 'error');
    toast('أُلغيت المشاركة', 'success');
    await refresh();
    if (state.sheet === 'share') openSheet('share');
}

// ---------------------------------------------------------------- open / close
function openGarage(data) {
    state.data = data;
    state.open = true;
    state.filter = 'all';
    state.query = '';
    state.busy = false;
    $('#search').value = '';
    closeSheet();
    closeDetail();
    // EX_Tii: every garage gives out every car, so the full list is shown first (cars parked here come first)
    renderAll();
    const root = $('#garage');
    root.classList.add('open');
    root.setAttribute('aria-hidden', 'false');
    $('#list-wrap').scrollTop = 0;
}

function hideGarage() {
    state.open = false;
    closeSheet();
    closeDetail();
    const root = $('#garage');
    root.classList.remove('open');
    root.setAttribute('aria-hidden', 'true');
}

function requestClose() {
    hideGarage();
    post('close');
}

// ---------------------------------------------------------------- events
// ---------------------------------------------------------------- car photo studio
// The game sends a raw screenshot of the car in a magenta box. Here the magenta is removed,
// the car is cut out and made into a small see-through picture like the stock photos.
function loadImage(src) {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = () => reject(new Error('image'));
        img.src = src;
    });
}

async function processPhoto(src) {
    const img = await loadImage(src);
    const W = img.naturalWidth, H = img.naturalHeight;
    if (!W || !H) return { ok: false, reason: 'empty' };
    const canvas = document.createElement('canvas');
    canvas.width = W; canvas.height = H;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(img, 0, 0);
    const image = ctx.getImageData(0, 0, W, H);
    const px = image.data;

    // background colour = middle value of the edge pixels
    const rs = [], gs = [], bs = [];
    const sample = (x, y) => { const i = (y * W + x) * 4; rs.push(px[i]); gs.push(px[i + 1]); bs.push(px[i + 2]); };
    const step = Math.max(2, Math.floor(Math.min(W, H) / 120));
    const inset = Math.floor(Math.min(W, H) * 0.01);
    for (let x = inset; x < W - inset; x += step) { sample(x, inset); sample(x, H - 1 - inset); }
    for (let y = inset; y < H - inset; y += step) { sample(inset, y); sample(W - 1 - inset, y); }
    const median = (a) => { const c = [...a].sort((p, q) => p - q); return c[c.length >> 1]; };
    const bg = [median(rs), median(gs), median(bs)];
    if (!(bg[0] > 120 && bg[2] > 120 && bg[1] < Math.min(bg[0], bg[2]) - 60)) return { ok: false, reason: 'background' };
    let near = 0;
    for (let i = 0; i < rs.length; i++) {
        const d = Math.hypot(rs[i] - bg[0], gs[i] - bg[1], bs[i] - bg[2]);
        if (d < 48) near++;
    }
    if (near / rs.length < 0.8) return { ok: false, reason: 'background' };

    // cut out the car: soft edges, and remove the magenta tint at the edges
    const T0 = 38, T1 = 92;
    let minX = W, minY = H, maxX = -1, maxY = -1, solid = 0;
    for (let y = 0; y < H; y++) {
        for (let x = 0; x < W; x++) {
            const i = (y * W + x) * 4;
            const r = px[i], g = px[i + 1], b = px[i + 2];
            const d = Math.hypot(r - bg[0], g - bg[1], b - bg[2]);
            let a = (d - T0) / (T1 - T0);
            if (a <= 0) { px[i + 3] = 0; continue; }
            if (a >= 1) a = 1;
            else {
                px[i] = Math.max(0, Math.min(255, (r - (1 - a) * bg[0]) / a));
                px[i + 1] = Math.max(0, Math.min(255, (g - (1 - a) * bg[1]) / a));
                px[i + 2] = Math.max(0, Math.min(255, (b - (1 - a) * bg[2]) / a));
            }
            px[i + 3] = Math.round(a * 255);
            if (a > 0.5) {
                solid++;
                if (x < minX) minX = x; if (x > maxX) maxX = x;
                if (y < minY) minY = y; if (y > maxY) maxY = y;
            }
        }
    }
    const share = solid / (W * H);
    if (maxX < 0 || share < 0.01 || share > 0.85) return { ok: false, reason: 'car' };

    // edges: remove the leftover magenta glow on the outline of the car
    const A = new Uint8Array(W * H);
    for (let k = 0, i = 3; k < W * H; k++, i += 4) A[k] = px[i];
    const R = 2;
    for (let y = minY; y <= maxY; y++) {
        for (let x = minX; x <= maxX; x++) {
            const k = y * W + x;
            if (A[k] === 0) continue;
            let edge = false;
            for (let dy = -R; dy <= R && !edge; dy++) {
                const yy = y + dy;
                if (yy < 0 || yy >= H) { edge = true; break; }
                for (let dx = -R; dx <= R; dx++) {
                    const xx = x + dx;
                    if (xx < 0 || xx >= W || A[yy * W + xx] === 0) { edge = true; break; }
                }
            }
            if (!edge) continue;
            const i = k * 4;
            const excess = Math.min(px[i], px[i + 2]) - px[i + 1];
            if (excess > 0) {
                px[i] -= excess;
                px[i + 2] -= excess;
                px[i + 3] = Math.round(px[i + 3] * (1 - Math.min(1, excess / 255) * 0.5));
            }
        }
    }
    ctx.putImageData(image, 0, 0);

    // crop around the car and fit it into a 480 x 270 picture
    const bw = maxX - minX + 1, bh = maxY - minY + 1;
    const pad = Math.round(Math.max(bw, bh) * 0.03);
    const sx = Math.max(0, minX - pad), sy = Math.max(0, minY - pad);
    const sw = Math.min(W - sx, bw + pad * 2), sh = Math.min(H - sy, bh + pad * 2);
    const out = document.createElement('canvas');
    out.width = 480; out.height = 270;
    const octx = out.getContext('2d');
    const scale = Math.min(464 / sw, 258 / sh);
    const dw = sw * scale, dh = sh * scale;
    octx.imageSmoothingQuality = 'high';
    octx.drawImage(canvas, sx, sy, sw, sh, (480 - dw) / 2, (270 - dh) / 2, dw, dh);

    for (const q of [0.86, 0.74, 0.6]) {
        const data = out.toDataURL('image/webp', q);
        if (data.startsWith('data:image/webp') && data.length <= 150000) return { ok: true, data };
    }
    return { ok: false, reason: 'size' };
}

// ---------------------------------------------------------------- photo session animation
const PO = { timers: [], revealAt: 0, shownAt: 0, pending: false };
const poEl = () => $('#photo-overlay');
const poLater = (fn, ms) => PO.timers.push(setTimeout(fn, ms));

// aperture blades: 6 lines around the centre
(function buildIris() {
    const svgEl = document.getElementById('po-iris');
    if (!svgEl) return;
    const R = 40, r = 15, a = Math.acos(r / R);
    let html = `<circle cx="50" cy="50" r="${R}" />`;
    for (let i = 0; i < 6; i++) {
        const n = (i * Math.PI) / 3;
        const x1 = 50 + R * Math.cos(n - a), y1 = 50 + R * Math.sin(n - a);
        const x2 = 50 + R * Math.cos(n + a), y2 = 50 + R * Math.sin(n + a);
        html += `<line x1="${x1.toFixed(2)}" y1="${y1.toFixed(2)}" x2="${x2.toFixed(2)}" y2="${y2.toFixed(2)}" />`;
    }
    svgEl.innerHTML = html;
})();

// a soft camera shutter "click" made on the spot (no sound file needed)
let audioCtx;
function shutterSound() {
    try {
        audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
        if (audioCtx.state === 'suspended') audioCtx.resume();
        const click = (when, gainValue, duration) => {
            const length = Math.floor(audioCtx.sampleRate * duration);
            const buffer = audioCtx.createBuffer(1, length, audioCtx.sampleRate);
            const data = buffer.getChannelData(0);
            for (let i = 0; i < length; i++) data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / length, 4);
            const src = audioCtx.createBufferSource();
            src.buffer = buffer;
            const filter = audioCtx.createBiquadFilter();
            filter.type = 'bandpass'; filter.frequency.value = 2600; filter.Q.value = 0.8;
            const gain = audioCtx.createGain();
            gain.gain.value = gainValue;
            src.connect(filter).connect(gain).connect(audioCtx.destination);
            src.start(audioCtx.currentTime + when);
        };
        click(0, 0.35, 0.05);
        click(0.075, 0.22, 0.07);
    } catch (e) { /* sound is only a bonus */ }
}

function poReset() {
    PO.timers.forEach(clearTimeout);
    PO.timers = [];
    PO.revealAt = 0;
    PO.pending = false;
    const el = poEl();
    el.className = 'photo-overlay';
    $('#po-img').removeAttribute('src');
}

function photoSessionStart(label) {
    poReset();
    const el = poEl();
    $('#po-name').textContent = label || '';
    $('#po-label').textContent = label || '';
    $('#po-title').textContent = 'تم حفظ صورة مركبتك';
    PO.shownAt = Date.now();
    el.classList.add('show');
    void el.offsetWidth; // restart the animations
    el.classList.add('shooting');
    poLater(() => photoSessionEnd(true), 20000); // never stays stuck
}

function photoSnap() {
    const el = poEl();
    el.classList.remove('snap');
    void el.offsetWidth;
    el.classList.add('snap');
    shutterSound();
    poLater(() => el.classList.remove('snap'), 700);
}

function photoReveal(dataUrl) {
    const el = poEl();
    if (dataUrl) $('#po-img').src = dataUrl;
    else {
        el.classList.add('failed');
        $('#po-title').textContent = 'تعذّر التقاط الصورة هذه المرة';
    }
    el.classList.remove('shooting');
    el.classList.add('reveal');
    PO.revealAt = Date.now();
    PO.pending = false;
}

function photoSessionEnd(now) {
    const el = poEl();
    if (!el.classList.contains('show')) return;
    if (!now && PO.pending && !PO.revealAt) {
        // the finished photo is about to be shown: end after it
        poLater(() => photoSessionEnd(false), 150);
        return;
    }
    let wait = 0;
    if (!now) {
        if (PO.revealAt) wait = Math.max(0, PO.revealAt + (el.classList.contains('failed') ? 1300 : 2100) - Date.now());
        else wait = Math.max(0, PO.shownAt + 500 - Date.now());
    }
    poLater(() => {
        el.classList.add('leaving');
        poLater(poReset, 400);
    }, wait);
}

window.addEventListener('message', async (e) => {
    const msg = e.data || {};
    if (msg.action === 'photoOverlay') {
        if (msg.show === true) photoSessionStart(typeof msg.label === 'string' ? msg.label : '');
        else photoSessionEnd(false);
        return;
    }
    if (msg.action === 'photoProcess') {
        PO.pending = true;
        photoSnap();
        let result;
        try { result = typeof msg.image === 'string' ? await processPhoto(msg.image) : { ok: false, reason: 'empty' }; }
        catch (err) { result = { ok: false, reason: String(err && err.message || err) }; }
        poLater(() => photoReveal(result.ok ? result.data : null), 260);
        post('photoResult', Object.assign({ token: msg.token }, result));
    }
});

window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (msg.action === 'open' && msg.data) openGarage(msg.data);
    else if (msg.action === 'data' && msg.data) { state.data = msg.data; renderAll(); }
    else if (msg.action === 'close') hideGarage();
});

document.addEventListener('click', (e) => {
    const el = e.target.closest('button, [data-open]');
    if (!el) return;

    if (el.dataset.action === 'close') return requestClose();
    if (el.dataset.action === 'sheet-close') return closeSheet();
    if (el.dataset.fav) { e.stopPropagation(); return toggleFavourite(Number(el.dataset.fav)); }
    if (el.dataset.filter) { state.filter = el.dataset.filter; renderChips(); renderList(); $('#list-wrap').scrollTop = 0; return; }
    if (el.dataset.view) { state.view = el.dataset.view; store.set('garage:view', state.view); renderChips(); renderList(); return; }
    if (el.dataset.unshare) return unshare(el.dataset.unshare);
    if (el.dataset.open) return openDetail(Number(el.dataset.open));

    const act = el.dataset.act;
    if (!act) return;
    if (act === 'back') return closeDetail();
    if (['rename', 'share', 'give', 'move', 'pay', 'payfull'].includes(act)) return openSheet(act);
    run(act, el);
});

document.addEventListener('click', (e) => {
    // The backdrop is not a button, so it is handled here
    if (e.target.classList && e.target.classList.contains('sheet-backdrop')) closeSheet();
});

$('#search').addEventListener('input', (e) => {
    state.query = e.target.value;
    renderList();
});

document.addEventListener('keydown', (e) => {
    if (!state.open) return;
    if (e.key === 'Escape') {
        e.preventDefault();
        if (state.sheet) closeSheet();
        else if (state.selectedId != null) closeDetail();
        else requestClose();
    } else if (e.key === 'Enter' && state.sheet) {
        const primary = document.querySelector('#sheet .btn.primary, #sheet .btn.danger');
        if (primary && !primary.disabled) primary.click();
    } else if (e.key === 'Enter' && !state.sheet && document.activeElement && document.activeElement.dataset && document.activeElement.dataset.open) {
        openDetail(Number(document.activeElement.dataset.open));
    }
});

// Static icons
document.querySelector('.search-icon').innerHTML = ICON.search(17);
document.querySelectorAll('[data-action="close"]').forEach((b) => { if (!b.innerHTML.trim()) b.innerHTML = ICON.close(18); });
