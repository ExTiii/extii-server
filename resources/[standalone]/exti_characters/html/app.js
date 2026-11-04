'use strict';

/* ======================================================================
   EX_Tii Roleplay — character screens.
   select: your character  ·  create: a new one  ·  cinema: arriving in the city
   ====================================================================== */

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'exti_characters';

const svg = (d, size = 18, extra = '') =>
    `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" ${extra}>${d}</svg>`;
const ICON = {
    play: (s) => svg('<path d="M8 5.5v13l10.5-6.5z" fill="currentColor"/>', s),
    plus: (s) => svg('<path d="M12 5v14M5 12h14"/>', s),
    back: (s) => svg('<path d="M5 12h14M13 6l6 6-6 6"/>', s),
    user: (s) => svg('<circle cx="12" cy="8.5" r="3.8"/><path d="M4.5 20c.8-3.8 3.8-5.8 7.5-5.8s6.7 2 7.5 5.8"/>', s),
    trash: (s) => svg('<path d="M5 7h14M10 11v6M14 11v6M7 7l1 12h8l1-12M9.5 7V4.5h5V7"/>', s),
    male: (s) => svg('<circle cx="10" cy="14" r="5.5"/><path d="M14 10l6-6M15 4h5v5"/>', s),
    female: (s) => svg('<circle cx="12" cy="9" r="5.5"/><path d="M12 14.5V21M9 18h6"/>', s),
    lock: (s) => svg('<rect x="5" y="10.5" width="14" height="9.5" rx="2.2"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>', s),
    brush: (s) => svg('<path d="M14.5 4.5l5 5-7.8 7.8-5-5z"/><path d="M6.7 12.3c-2 .3-3.2 1.9-3.2 4.2 0 1.5-.5 2.4-1 3 3.2.6 6.6-.2 7.9-2.4"/>', s),
    star: (s) => svg('<path d="M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>', s),
};

const $ = (sel) => document.querySelector(sel);
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '⁦$' + Math.max(0, Math.round(Number(n) || 0)).toLocaleString('en-US') + '⁩';
const MONTHS = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

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

const state = {
    screen: null,
    characters: [],
    allowed: 1,
    selected: null,
    create: null,
    form: { firstname: '', lastname: '', gender: 0, day: '', month: '', year: '', nationality: '' },
    busy: false,
};

// ---------------------------------------------------------------- toast
let toastTimer;
function toast(text) {
    const el = $('#toast');
    el.textContent = text;
    el.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), 3000);
}

// ---------------------------------------------------------------- caption over the game
function caption(chip, title, sub) {
    const el = $('#caption');
    if (!title) { el.classList.remove('show'); return; }
    el.innerHTML = `${chip ? `<span class="cap-chip">${chip}</span>` : ''}<div class="cap-title">${esc(title)}</div>${sub ? `<div class="cap-sub">${esc(sub)}</div>` : ''}`;
    el.classList.add('show');
}

function setScreen(html) {
    if (state.lastScreen !== state.screen) {
        // a new screen: forget messages from the previous one
        state.lastScreen = state.screen;
        clearTimeout(toastTimer);
        $('#toast').classList.remove('show');
    }
    const s = $('#screen');
    s.innerHTML = html;
    s.classList.remove('swap');
    void s.offsetWidth;
    s.classList.add('swap');
}

// ---------------------------------------------------------------- 1) choose
const fullName = (c) => `${c.firstname} ${c.lastname}`.trim();
const initials = (c) => ((c.firstname || '?').charAt(0) + (c.lastname || '').charAt(0)).toUpperCase();
const selectedChar = () => state.characters.find((c) => c.citizenid === state.selected) || null;

function charCard(c) {
    const on = c.citizenid === state.selected;
    const job = c.job ? `${c.job}${c.grade ? ' · ' + c.grade : ''}` : 'بلا عمل';
    return `
    <button class="char ${on ? 'on' : ''}" data-char="${esc(c.citizenid)}">
        <div class="char-head">
            <span class="avatar">${esc(initials(c))}</span>
            <div>
                <div class="char-name">${esc(fullName(c))}</div>
                <div class="char-sub"><span class="plate">${esc(c.citizenid)}</span></div>
            </div>
        </div>
        <div class="facts">
            <div class="fact"><span>الوظيفة</span><b>${esc(job)}</b></div>
            <div class="fact"><span>تاريخ الميلاد</span><b>${esc(c.birthdate)}</b></div>
            <div class="fact"><span>الجنسية</span><b>${esc(c.nationality)}</b></div>
            <div class="fact"><span>الهاتف</span><b>${esc(c.phone || '—')}</b></div>
            <div class="fact"><span>النقد</span><b class="money">${money(c.cash)}</b></div>
            <div class="fact"><span>البنك</span><b class="money">${money(c.bank)}</b></div>
        </div>
    </button>`;
}

function renderSelect() {
    const list = state.characters;
    const canCreate = list.length < state.allowed;
    const c = selectedChar();
    const body = list.length
        ? list.map(charCard).join('')
        : `<div class="empty">
               <div class="empty-icon">${ICON.user(34)}</div>
               <h3>لا توجد لديك شخصية بعد</h3>
               <p>أنشئ شخصيتك وابدأ قصتك في مدينة لوس سانتوس.</p>
           </div>`;
    const actions = [];
    if (c) actions.push(`<button class="btn primary" data-act="play">${ICON.play(16)} ادخل المدينة</button>`);
    if (canCreate) actions.push(`<button class="btn ${c ? '' : 'primary'}" data-act="new">${ICON.plus(18)} أنشئ شخصية جديدة</button>`);
    // EX_Tii: one character per player, so players can't delete it themselves (admins: /delcharacter)
    const note = state.allowed === 1 ? `<div class="foot-note">${ICON.lock(13)} شخصية واحدة لكل لاعب · لحذفها تواصل مع الإدارة</div>` : '';

    setScreen(`
        <header class="top">
            <div class="brand">
                <img class="brand-logo" src="logo.png" alt="" />
                <div class="brand-text"><h1>EX_Tii Roleplay</h1><p>${list.length ? 'مرحبًا بعودتك' : 'أهلًا بك في المدينة'}</p></div>
            </div>
        </header>
        <div class="body">${body}</div>
        <footer class="foot">${actions.join('')}${note}</footer>`);

    if (c) caption(`${ICON.star(14)} EX_Tii Roleplay`, fullName(c), c.job ? `${c.job} · ${c.nationality}` : c.nationality);
    else caption(`${ICON.star(14)} EX_Tii Roleplay`, 'مرحبًا بك', 'حياة واقعية بالعربي');
}

function openSelect(data) {
    state.screen = 'select';
    state.characters = Array.isArray(data.characters) ? data.characters : [];
    state.allowed = Number(data.allowed) || 1;
    state.selected = state.characters[0] ? state.characters[0].citizenid : null;
    state.busy = false;
    closeSheet();
    renderSelect();
}

function openDeleteSheet() {
    const c = selectedChar();
    if (!c) return;
    $('#sheet').innerHTML = `
        <div class="grabber"></div>
        <h3>حذف الشخصية</h3>
        <p class="sheet-text">سيتم حذف <b>${esc(fullName(c))}</b> نهائيًا مع أمواله ومركباته وكل ما يملك. لا يمكن التراجع عن ذلك.</p>
        <div class="field">
            <label>اكتب الاسم الأول للتأكيد: <small>${esc(c.firstname)}</small></label>
            <input class="input" id="del-confirm" maxlength="32" autocomplete="off" />
        </div>
        <div class="sheet-actions">
            <button class="btn" data-action="sheet-close">إلغاء</button>
            <button class="btn danger" data-act="delete-yes" disabled>${ICON.trash(16)} حذف نهائيًا</button>
        </div>`;
    $('#sheet-layer').classList.add('open');
    const input = $('#del-confirm');
    input.addEventListener('input', () => {
        $('[data-act="delete-yes"]').disabled = input.value.trim() !== c.firstname;
    });
    setTimeout(() => input.focus(), 250);
}

function closeSheet() {
    $('#sheet-layer').classList.remove('open');
}

// ---------------------------------------------------------------- 2) create
const NAME_RE = /^[A-Za-zء-يٱ-ۓـ][A-Za-zء-يٱ-ۓـ' -]*$/;

function nameError(value) {
    const v = value.trim().replace(/\s+/g, ' ');
    const c = state.create || {};
    if (!v) return 'هذا الحقل مطلوب';
    if ([...v].length < (c.nameMin || 2)) return `حرفان على الأقل`;
    if ([...v].length > (c.nameMax || 16)) return `${c.nameMax || 16} حرفًا كحد أقصى`;
    if (!NAME_RE.test(v)) return 'حروف عربية أو إنجليزية فقط';
    return '';
}

function formErrors() {
    const f = state.form;
    return {
        firstname: nameError(f.firstname),
        lastname: nameError(f.lastname),
        dob: f.day && f.month && f.year ? '' : 'اختر تاريخ ميلادك',
        nationality: f.nationality && (state.create.nationalities || []).includes(f.nationality) ? '' : 'اختر جنسيتك',
    };
}

function daysIn(month, year) {
    if (!month) return 31;
    return new Date(Number(year) || 2000, Number(month), 0).getDate();
}

function renderCreate(showErrors) {
    const f = state.form;
    const c = state.create;
    const err = showErrors ? formErrors() : {};
    const years = [];
    for (let y = c.yearMax; y >= c.yearMin; y--) years.push(y);
    const dmax = daysIn(f.month, f.year);
    if (Number(f.day) > dmax) f.day = '';
    const opt = (v, label, cur) => `<option value="${v}" ${String(cur) === String(v) ? 'selected' : ''}>${label}</option>`;

    setScreen(`
        <header class="top">
            <div class="brand">
                <span class="brand-icon">${ICON.user(22)}</span>
                <div class="brand-text"><h1>أنشئ شخصيتك</h1><p>هذه هويتك في المدينة، اخترها بعناية</p></div>
            </div>
            ${c.canGoBack ? `<button class="icon-btn" data-act="back" aria-label="رجوع">${ICON.back(18)}</button>` : ''}
        </header>
        <div class="body">
            <div class="field">
                <label>الاسم الأول <small>عربي أو إنجليزي</small></label>
                <input class="input ${err.firstname ? 'bad' : ''}" id="f-first" maxlength="${c.nameMax}" value="${esc(f.firstname)}" autocomplete="off" />
                ${err.firstname ? `<div class="err">${err.firstname}</div>` : ''}
            </div>
            <div class="field">
                <label>اسم العائلة</label>
                <input class="input ${err.lastname ? 'bad' : ''}" id="f-last" maxlength="${c.nameMax}" value="${esc(f.lastname)}" autocomplete="off" />
                ${err.lastname ? `<div class="err">${err.lastname}</div>` : ''}
            </div>
            <div class="field">
                <label>الجنس</label>
                <div class="genders">
                    <button class="gender ${f.gender === 0 ? 'on' : ''}" data-gender="0">${ICON.male(20)} ذكر</button>
                    <button class="gender ${f.gender === 1 ? 'on' : ''}" data-gender="1">${ICON.female(20)} أنثى</button>
                </div>
            </div>
            <div class="field">
                <label>تاريخ الميلاد</label>
                <div class="dob">
                    <select class="select" id="f-day"><option value="">اليوم</option>${Array.from({ length: dmax }, (_, i) => opt(i + 1, i + 1, f.day)).join('')}</select>
                    <select class="select" id="f-month"><option value="">الشهر</option>${MONTHS.map((m, i) => opt(i + 1, m, f.month)).join('')}</select>
                    <select class="select" id="f-year"><option value="">السنة</option>${years.map((y) => opt(y, y, f.year)).join('')}</select>
                </div>
                ${err.dob ? `<div class="err">${err.dob}</div>` : ''}
            </div>
            <div class="field">
                <label>الجنسية</label>
                <div class="combo" id="combo">
                    <input class="input ${err.nationality ? 'bad' : ''}" id="f-nat" placeholder="ابحث عن جنسيتك" value="${esc(f.nationality)}" autocomplete="off" />
                    <div class="combo-list" id="combo-list"></div>
                </div>
                ${err.nationality ? `<div class="err">${err.nationality}</div>` : ''}
            </div>
        </div>
        <footer class="foot">
            <button class="btn primary" data-act="create" ${state.busy ? 'disabled' : ''}>${state.busy ? '<span class="spinner"></span>' : ICON.brush(18)} أنشئ الشخصية وصمّم مظهرك</button>
            <div class="foot-note">${ICON.lock(13)} لا يمكن تغيير الاسم لاحقًا</div>
        </footer>`);

    bindCreate();
    updateCreateCaption();
}

function updateCreateCaption() {
    const f = state.form;
    const name = `${f.firstname} ${f.lastname}`.trim();
    caption(`${ICON.plus(14)} شخصية جديدة`, name || 'شخصيتك الجديدة', f.nationality || 'لوس سانتوس بانتظارك');
}

function renderComboList(filter) {
    const list = state.create.nationalities || [];
    const q = (filter || '').trim();
    const items = q ? list.filter((n) => n.includes(q)) : list;
    $('#combo-list').innerHTML = items.length
        ? items.map((n) => `<button class="combo-item ${n === state.form.nationality ? 'on' : ''}" data-nat="${esc(n)}">${esc(n)}</button>`).join('')
        : `<div class="combo-none">لا توجد نتائج</div>`;
}

function bindCreate() {
    const f = state.form;
    $('#f-first').addEventListener('input', (e) => { f.firstname = e.target.value; updateCreateCaption(); });
    $('#f-last').addEventListener('input', (e) => { f.lastname = e.target.value; updateCreateCaption(); });
    $('#f-day').addEventListener('change', (e) => { f.day = e.target.value; });
    $('#f-month').addEventListener('change', (e) => { f.month = e.target.value; renderCreateKeepFocus(); });
    $('#f-year').addEventListener('change', (e) => { f.year = e.target.value; renderCreateKeepFocus(); });
    const nat = $('#f-nat');
    nat.addEventListener('focus', () => { renderComboList(''); $('#combo').classList.add('open'); });
    nat.addEventListener('input', (e) => { f.nationality = ''; renderComboList(e.target.value); $('#combo').classList.add('open'); updateCreateCaption(); });
    nat.addEventListener('blur', () => setTimeout(() => {
        const combo = $('#combo');
        if (combo) combo.classList.remove('open');
        if (!f.nationality && $('#f-nat')) $('#f-nat').value = '';
    }, 180));
}

function renderCreateKeepFocus() {
    const scroll = $('.body') ? $('.body').scrollTop : 0;
    renderCreate(false);
    $('.screen').classList.remove('swap');
    if ($('.body')) $('.body').scrollTop = scroll;
}

function openCreate(data) {
    state.screen = 'create';
    state.create = data;
    state.form = { firstname: '', lastname: '', gender: 0, day: '', month: '', year: '', nationality: '' };
    state.busy = false;
    closeSheet();
    renderCreate(false);
    setTimeout(() => { const el = $('#f-first'); if (el) el.focus(); }, 350);
}

async function submitCreate() {
    if (state.busy) return;
    const errors = formErrors();
    if (Object.values(errors).some(Boolean)) {
        renderCreate(true);
        $('.screen').classList.remove('swap');
        return;
    }
    const f = state.form;
    state.busy = true;
    renderCreateKeepFocus();
    const res = await post('create', {
        firstname: f.firstname.trim().replace(/\s+/g, ' '),
        lastname: f.lastname.trim().replace(/\s+/g, ' '),
        gender: f.gender,
        birthdate: `${f.year}-${String(f.month).padStart(2, '0')}-${String(f.day).padStart(2, '0')}`,
        nationality: f.nationality,
    });
    if (res && res.ok) return; // the game takes over (design the look, then arrive in the city)
    state.busy = false;
    renderCreateKeepFocus();
    const msg = {
        name: 'تحقق من الاسم: حروف عربية أو إنجليزية فقط',
        nationality: 'اختر جنسيتك من القائمة',
        birthdate: 'تاريخ الميلاد غير صحيح',
    };
    toast((res && msg[res.error]) || 'تعذّر إنشاء الشخصية، حاول مرة أخرى');
}

// ---------------------------------------------------------------- show / hide
function show() { $('#root').classList.add('open'); }
function hide() {
    $('#root').classList.remove('open');
    $('#caption').classList.remove('show');
    closeSheet();
}

// ---------------------------------------------------------------- cinema (arriving in the city)
let cineTimer;
let cineToken = 0;
function cinema(msg) {
    const el = $('#cinema');
    clearTimeout(cineTimer);
    cineToken++;
    $('#cine-h1').textContent = msg.title || '';
    $('#cine-sub').textContent = msg.sub || '';
    el.className = 'cinema show';
    void el.offsetWidth;
    el.classList.add('in');
    cineTimer = setTimeout(cinemaEnd, 20000); // never stays stuck
}
function cinemaCard(msg) {
    const el = $('#cinema');
    if (!el.classList.contains('show')) return;
    $('#cine-card-title').textContent = msg.title || '';
    $('#cine-card-sub').textContent = msg.sub || '';
    el.classList.add('card');
}
function cinemaEnd() {
    const el = $('#cinema');
    clearTimeout(cineTimer);
    if (!el.classList.contains('show')) return;
    const token = cineToken;
    el.classList.add('out');
    setTimeout(() => { if (token === cineToken) el.className = 'cinema'; }, 1100);
}

function cinemaReset() {
    clearTimeout(cineTimer);
    cineToken++;
    $('#cinema').className = 'cinema';
}

// ---------------------------------------------------------------- events
window.addEventListener('message', (e) => {
    const msg = e.data || {};
    switch (msg.action) {
        case 'select': cinemaReset(); show(); openSelect(msg); break;
        case 'create': cinemaReset(); show(); openCreate(msg); break;
        case 'hide': hide(); break;
        case 'cinema': hide(); cinema(msg); break;
        case 'cinemaCard': cinemaCard(msg); break;
        case 'cinemaEnd': cinemaEnd(); break;
    }
});

document.addEventListener('mousedown', (e) => {
    // pick a nationality before the input loses focus
    const item = e.target.closest('[data-nat]');
    if (!item) return;
    e.preventDefault();
    state.form.nationality = item.dataset.nat;
    $('#f-nat').value = item.dataset.nat;
    $('#combo').classList.remove('open');
    updateCreateCaption();
});

document.addEventListener('click', async (e) => {
    const t = e.target.closest('[data-act],[data-action],[data-char],[data-gender]');
    if (!t) return;

    if (t.dataset.action === 'sheet-close') return closeSheet();

    if (t.dataset.char) {
        if (state.selected !== t.dataset.char) {
            state.selected = t.dataset.char;
            renderSelect();
            post('preview', { citizenid: state.selected });
        }
        return;
    }
    if (t.dataset.gender != null) {
        const g = t.dataset.gender === '1' ? 1 : 0;
        if (state.form.gender !== g) {
            state.form.gender = g;
            document.querySelectorAll('.gender').forEach((b) => b.classList.toggle('on', b.dataset.gender === String(g)));
            post('gender', { gender: g });
        }
        return;
    }
    switch (t.dataset.act) {
        case 'play': {
            const c = selectedChar();
            if (!c || state.busy) return;
            state.busy = true;
            t.disabled = true;
            t.innerHTML = '<span class="spinner"></span> جارٍ الدخول…';
            const res = await post('play', { citizenid: c.citizenid });
            if (!res || !res.ok) { state.busy = false; renderSelect(); toast('تعذّر الدخول، حاول مرة أخرى'); }
            return;
        }
        case 'new': {
            const res = await post('newCharacter');
            if (!res || !res.ok) toast('لا يمكنك إنشاء شخصية أخرى');
            return;
        }
        case 'delete': return openDeleteSheet();
        case 'delete-yes': {
            const c = selectedChar();
            if (!c) return;
            t.disabled = true;
            t.innerHTML = '<span class="spinner"></span> جارٍ الحذف…';
            const res = await post('delete', { citizenid: c.citizenid });
            if (!res || !res.ok) toast('تعذّر حذف الشخصية');
            return;
        }
        case 'back': post('back'); return;
        case 'create': return submitCreate();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && state.screen === 'create' && !$('#combo')?.classList.contains('open')) {
        e.preventDefault();
        submitCreate();
    } else if (e.key === 'Escape') {
        if ($('#sheet-layer').classList.contains('open')) closeSheet();
        else if ($('#combo')?.classList.contains('open')) $('#combo').classList.remove('open');
    }
});
