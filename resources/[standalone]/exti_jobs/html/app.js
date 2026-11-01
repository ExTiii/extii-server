'use strict';

/* ======================================================================
   EX_Tii Roleplay — job center tablet + HQ panel.
   center: every job with all you need to know (how it works, pay, level,
           vehicle, HQ) + the documents tab (ID card, driver's licence)
   hq:     the supervisor at the job's HQ: start / end the shift
   ====================================================================== */

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'exti_jobs';
const IMAGE_URL = (model) => `https://docs.fivem.net/vehicles/${encodeURIComponent(String(model || '').toLowerCase())}.webp`;

// ---------------------------------------------------------------- icons
const svg = (d, size = 18) =>
    `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const ICON = {
    close: (s) => svg('<path d="M6 6l12 12M18 6L6 18"/>', s),
    tow: (s) => svg('<path d="M2.5 16V10h7l2 3h3.5V16"/><path d="M15 13l5.5-6"/><path d="M20.5 7v3"/><circle cx="6" cy="16.5" r="1.8"/><circle cx="13.5" cy="16.5" r="1.8"/><path d="M15.5 16.5h5"/>', s),
    trash: (s) => svg('<path d="M3 16.5V8.5h11.5v8"/><path d="M14.5 11h3.5l3 3v2.5h-6.5"/><circle cx="7" cy="17" r="1.8"/><circle cx="17.5" cy="17" r="1.8"/><path d="M6 8.5V6.5h5.5v2M7.5 11v3M10.5 11v3"/>', s),
    box: (s) => svg('<path d="M3.5 7.5L12 3.5l8.5 4v9L12 20.5l-8.5-4z"/><path d="M3.5 7.5L12 11.5l8.5-4M12 11.5v9"/><path d="M7.8 5.5l8.4 4"/>', s),
    briefcase: (s) => svg('<rect x="3" y="7" width="18" height="12.5" rx="2.5"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M3 12.5h18"/><path d="M11 12.5v1.5h2v-1.5"/>', s),
    id: (s) => svg('<rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="8.5" cy="11" r="2.2"/><path d="M5.5 16c.6-1.6 1.7-2.4 3-2.4s2.4.8 3 2.4"/><path d="M14 9.5h4.5M14 12.5h4.5M14 15.5h3"/>', s),
    car: (s) => svg('<path d="M5 16.5V12l2-5h10l2 5v4.5"/><path d="M3.5 12h17"/><circle cx="7.5" cy="16.5" r="1.8"/><circle cx="16.5" cy="16.5" r="1.8"/><path d="M9.5 16.5h5"/>', s),
    shield: (s) => svg('<path d="M12 3.5l7.5 3v5.5c0 4.5-3.2 7.6-7.5 8.5-4.3-.9-7.5-4-7.5-8.5V6.5z"/><path d="M9 12l2 2 4-4.5"/>', s),
    pin: (s) => svg('<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.4"/>', s),
    cash: (s) => svg('<rect x="3" y="6.5" width="18" height="11" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6.5 9.5v5M17.5 9.5v5"/>', s),
    clock: (s) => svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', s),
    star: (s) => svg('<path d="M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>', s),
    check: (s) => svg('<path d="M5 12.5l4.5 4.5L19 7.5"/>', s),
    x: (s) => svg('<path d="M7 7l10 10M17 7L7 17"/>', s),
    info: (s) => svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>', s),
    list: (s) => svg('<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1" fill="currentColor"/><circle cx="4.5" cy="12" r="1" fill="currentColor"/><circle cx="4.5" cy="18" r="1" fill="currentColor"/>', s),
    key: (s) => svg('<circle cx="8" cy="15" r="4"/><path d="M11 12l8.5-8.5M16.5 6.5l2 2M14.5 8.5l1.5 1.5"/>', s),
    gift: (s) => svg('<rect x="3.5" y="8.5" width="17" height="4" rx="1"/><path d="M5 12.5v8h14v-8M12 8.5v12"/><path d="M12 8.5C10 5 7 5 7 7s2.5 1.5 5 1.5c2.5 0 5 .5 5-1.5s-3-2-5 1.5z"/>', s),
    route: (s) => svg('<circle cx="6" cy="18" r="2.2"/><circle cx="18" cy="6" r="2.2"/><path d="M8 18h7.5a3.5 3.5 0 0 0 0-7h-7a3.5 3.5 0 0 1 0-7H16"/>', s),
    user: (s) => svg('<circle cx="12" cy="8" r="4"/><path d="M4.5 20c1.2-3.6 4-5.5 7.5-5.5s6.3 1.9 7.5 5.5"/>', s),
    door: (s) => svg('<path d="M13 4h5.5v16H13"/><path d="M4 12h10M10 8l4 4-4 4"/>', s),
    warn: (s) => svg('<path d="M12 4l9 15.5H3z"/><path d="M12 10v4.5M12 17.5h.01"/>', s),
    medic: (s) => svg('<path d="M10 3.5h4v4.6l4-2.3 2 3.5-4 2.3 4 2.2-2 3.5-4-2.3v4.5h-4v-4.5l-4 2.3-2-3.5 4-2.2-4-2.3 2-3.5 4 2.3Z"/>', s),
};
const jobIcon = (name, s) => (ICON[name] || ICON.briefcase)(s);

// ---------------------------------------------------------------- helpers
const $ = (sel) => document.querySelector(sel);
const esc = (value) =>
    String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '⁦$' + Math.max(0, Math.round(Number(n) || 0)).toLocaleString('en-US') + '⁩';
const pct = (n) => `${Math.round((Number(n) || 0) * 100)}%`;

const count = (n, one, two, few, many) => {
    n = Math.round(Number(n) || 0);
    if (n === 0) return `0 ${many}`;
    if (n === 1) return one;
    if (n === 2) return two;
    if (n >= 3 && n <= 10) return `${n} ${few}`;
    return `${n} ${many}`;
};
const minutes = (m) => count(m, 'دقيقة واحدة', 'دقيقتان', 'دقائق', 'دقيقة');

async function post(name, data = {}) {
    try {
        const res = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await res.json();
    } catch (e) {
        return null;
    }
}

let toastTimer = null;
function toast(text, kind = '') {
    const el = $('#toast');
    el.className = `kit-toast ${kind}`;
    el.textContent = text;
    requestAnimationFrame(() => el.classList.add('show'));
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), 3200);
}

function openSheet(html) {
    $('#sheet').innerHTML = `<div class="kit-grabber"></div>${html}`;
    $('#sheet-layer').classList.add('open');
}
function closeSheet() {
    $('#sheet-layer').classList.remove('open');
}
const sheetOpen = () => $('#sheet-layer').classList.contains('open');

// the tablet is designed for 1080p; on bigger screens it grows with the screen
function fitScreen() {
    const ui = Math.min(1.6, Math.max(0.75, window.innerHeight / 1080));
    document.documentElement.style.setProperty('--ui', ui.toFixed(3));
}
fitScreen();
window.addEventListener('resize', fitScreen);

// ---------------------------------------------------------------- state
const state = { mode: null, data: null, selected: null, tab: 'jobs', busy: false };

const DOCS = [
    { key: 'id', label: 'بطاقة الهوية', icon: 'id', art: 'IDENTITY CARD', text: 'بطاقتك الشخصية في المدينة. تحتاجها عند الشرطة وفي البنك.' },
    { key: 'driver', label: 'رخصة القيادة', icon: 'car', art: 'DRIVER LICENCE', text: 'تسمح لك بالقيادة وبالعمل في وظائف القيادة.' },
    { key: 'weapon', label: 'رخصة السلاح', icon: 'shield', art: 'WEAPON LICENCE', text: 'تمنحها الشرطة فقط. إن كانت لديك وفقدتها، استخرج نسخة هنا.' },
];
const DOC_PRICE = 50;

// ---------------------------------------------------------------- the job center
function selectedJob() {
    const jobs = state.data.jobs || [];
    return jobs.find((j) => j.name === state.selected) || jobs[0];
}

function headerCenter() {
    const d = state.data;
    return `
    <header class="top">
        <div class="brand">
            <img class="brand-logo" src="logo.png" alt="" />
            <div class="brand-text">
                <h1>مركز التوظيف</h1>
                <p>مرحبًا ${esc(d.name.trim() || 'بك')} · وظيفتك الحالية: <b>${esc(d.currentLabel)}</b></p>
            </div>
        </div>
        <div class="top-side">
            <div class="tabs" role="tablist">
                <button class="tab ${state.tab === 'jobs' ? 'active' : ''}" data-act="tab" data-tab="jobs">${ICON.briefcase(16)} الوظائف</button>
                <button class="tab ${state.tab === 'docs' ? 'active' : ''}" data-act="tab" data-tab="docs">${ICON.id(16)} الوثائق</button>
            </div>
            <button class="icon-btn" data-act="close" aria-label="إغلاق">${ICON.close(18)}</button>
        </div>
    </header>`;
}

function jobCard(job) {
    const isCurrent = state.data.current === job.name;
    return `
    <button class="job-card ${job.name === selectedJob().name ? 'active' : ''}" data-act="select" data-job="${esc(job.name)}">
        <span class="job-icon">${jobIcon(job.icon, 24)}</span>
        <span class="job-main">
            <h3>${esc(job.label)} ${isCurrent ? '<span class="badge soft">وظيفتك</span>' : ''}</h3>
            <span>${esc(job.company)}</span>
            <span class="pay">${job.team ? esc(job.payText) : `${esc(job.hourText)} في الساعة`}</span>
        </span>
    </button>`;
}

function levelBox(job) {
    const lv = job.level;
    const isMax = !lv.nextAt;
    const span = isMax ? 1 : lv.nextAt - lv.from;
    const done = isMax ? 1 : (lv.tasks - lv.from) / span;
    const word = job.taskWord[1];
    const rungs = job.levelNames.map((name, i) => {
        const n = i + 1;
        const cls = n === lv.level ? 'now' : n < lv.level ? 'done' : '';
        return `<div class="rung ${cls}"><b>${esc(name)}</b><span>+${pct(job.levelBonus[i])}</span></div>`;
    }).join('');
    return `
    <div class="box">
        <div class="box-title"><span>${ICON.star(16)} مستواك في هذه الوظيفة</span><small>${lv.tasks} ${esc(word)} أنجزتها</small></div>
        <div class="level-row">
            <div class="level-now">
                <div class="level-num">${lv.level}</div>
                <div><h4>${esc(lv.name)}</h4><p>أجرك أعلى بنسبة ${pct(lv.bonus)}</p></div>
            </div>
        </div>
        <div class="level-bar"><i style="width:${Math.max(3, Math.min(100, done * 100))}%"></i></div>
        <div class="level-hint">
            <span>${isMax ? 'وصلت إلى أعلى مستوى' : `بقي ${lv.nextAt - lv.tasks} ${esc(word)} للمستوى التالي`}</span>
            <span>${isMax ? '' : `المستوى ${lv.level + 1}: +${pct(lv.nextBonus)}`}</span>
        </div>
        <div class="ladder">${rungs}</div>
    </div>`;
}

function jobActions(job) {
    const d = state.data;
    const isCurrent = d.current === job.name;
    if (isCurrent) {
        return `
            <button class="btn primary" data-act="gps" data-job="${esc(job.name)}">${ICON.pin(18)} حدّد ${esc(job.hq.label)} على الخريطة</button>
            <button class="btn link" data-act="resign">${ICON.door(16)} استقالة</button>`;
    }
    if (d.onShift) return `<div class="bottom-note">${ICON.warn(16)} أنهِ مناوبتك الحالية عند المشرف أولًا</div>`;
    if (!d.canSwitch) return `<div class="bottom-note">${ICON.warn(16)} أنت تعمل في ${esc(d.currentLabel)}، ولا يمكنك تغيير وظيفتك من هنا</div>`;
    if (!d.hasLicence && !job.team) {
        return `<div class="bottom-note">${ICON.warn(16)} تحتاج إلى رخصة قيادة لهذه الوظيفة</div>
            <button class="btn primary" disabled>${ICON.briefcase(18)} التقديم على الوظيفة</button>`;
    }
    return `<button class="btn primary" data-act="apply" data-job="${esc(job.name)}">${ICON.briefcase(18)} التقديم على وظيفة ${esc(job.label)}</button>`;
}

// EX_Tii: team jobs (EMS): ranks instead of levels, no deposit, no shift supervisor
function teamDetails(job) {
    const d = state.data;
    const steps = job.steps.map((s) => `<div class="step"><i></i><span>${esc(s)}</span></div>`).join('');
    const ranks = (job.ranks || []).map((r, i) => `<div class="rung ${i === 0 ? 'now' : ''}"><b>${esc(r.name)}</b><span>${money(r.payment)} / 10 د</span></div>`).join('');
    return `
    <div class="scroll">
        <div class="hero">
            <img src="${IMAGE_URL(job.vehicle.model)}" alt="" onerror="this.remove()" />
            ${d.current === job.name ? `<span class="badge">${ICON.check(14)} وظيفتك الحالية</span>` : ''}
            <div class="hero-text">
                <span class="company">${jobIcon(job.icon, 15)} ${esc(job.company)}</span>
                <h2>${esc(job.label)}</h2>
                <p>${esc(job.short)}</p>
            </div>
        </div>

        <div class="facts">
            <div class="fact"><span>${ICON.cash(14)} أجر المريض</span><b class="gold">${esc(job.payText)}</b><small>في حسابك البنكي فورًا</small></div>
            <div class="fact"><span>${ICON.clock(14)} الراتب</span><b>كل 10 دقائق</b><small>وأنت في الخدمة، ويرتفع مع الرتبة</small></div>
            <div class="fact"><span>${ICON.key(14)} المركبات</span><b>${esc(job.vehicle.label)}</b><small>مجانًا للمسعفين، بلا تأمين</small></div>
            <div class="fact"><span>${ICON.pin(14)} المقر</span><b>${esc(job.hq.label)}</b><small>${esc(job.hq.place)}</small></div>
        </div>

        <div class="box">
            <div class="box-title"><span>${ICON.route(16)} كيف تعمل</span><small>البلاغات تصلك على التابلت</small></div>
            <div class="steps">${steps}</div>
            ${job.extra ? `<div class="extra">${ICON.info(16)}<span>${esc(job.extra)}</span></div>` : ''}
        </div>

        <div class="box">
            <div class="box-title"><span>${ICON.star(16)} الرتب</span><small>تبدأ مستجدًا</small></div>
            <div class="ladder">${ranks}</div>
        </div>

        <div class="box">
            <div class="box-title"><span>${ICON.shield(16)} الشروط</span></div>
            <div class="reqs">
                <span class="req ok">${ICON.check(15)} لا تحتاج رخصة أو تأمينًا</span>
                <span class="req ok">${ICON.check(15)} الزي والمستلزمات مجانًا في المستشفى</span>
            </div>
        </div>
    </div>
    <footer class="bottom">${jobActions(job)}</footer>`;
}

function jobDetails(job) {
    if (job.team) return teamDetails(job);
    const d = state.data;
    const steps = job.steps.map((s) => `<div class="step"><i></i><span>${esc(s)}</span></div>`).join('');
    return `
    <div class="scroll">
        <div class="hero">
            <img src="${IMAGE_URL(job.vehicle.model)}" alt="" onerror="this.remove()" />
            ${d.current === job.name ? `<span class="badge">${ICON.check(14)} وظيفتك الحالية</span>` : ''}
            <div class="hero-text">
                <span class="company">${jobIcon(job.icon, 15)} ${esc(job.company)}</span>
                <h2>${esc(job.label)}</h2>
                <p>${esc(job.short)}</p>
            </div>
        </div>

        <div class="facts">
            <div class="fact"><span>${ICON.cash(14)} الدخل التقريبي</span><b class="gold">${esc(job.hourText)}</b><small>في الساعة، في المستوى الأول</small></div>
            <div class="fact"><span>${ICON.list(14)} أجر المهمة</span><b>${esc(job.payText)}</b><small>في حسابك البنكي فورًا</small></div>
            <div class="fact"><span>${ICON.key(14)} مركبة العمل</span><b>${esc(job.vehicle.label)}</b><small>تأمين ${money(job.deposit)} يُعاد إليك</small></div>
            <div class="fact"><span>${ICON.pin(14)} المقر</span><b>${esc(job.hq.label)}</b><small>${esc(job.hq.place)}</small></div>
        </div>

        <div class="box">
            <div class="box-title"><span>${ICON.route(16)} كيف تعمل</span><small>كل جولة ${job.perRound} ${esc(job.taskWord[job.perRound > 2 && job.perRound < 11 ? 1 : 0])} · حوالي 10 دقائق</small></div>
            <div class="steps">${steps}</div>
            ${job.extra ? `<div class="extra">${ICON.info(16)}<span>${esc(job.extra)}</span></div>` : ''}
        </div>

        ${levelBox(job)}

        <div class="box">
            <div class="box-title"><span>${ICON.gift(16)} المال والمكافآت</span></div>
            <div class="reqs">
                <span class="req ok">${ICON.check(15)} الأجر بعد كل مهمة مباشرة</span>
                <span class="req ok">${ICON.check(15)} مكافأة إرجاع المركبة حتى ${money(job.bonusMax)}</span>
                <span class="req ok">${ICON.check(15)} راتب الوظيفة كل 10 دقائق</span>
                <span class="req ok">${ICON.check(15)} زي العمل يُعطى لك في المقر</span>
            </div>
        </div>

        <div class="box">
            <div class="box-title"><span>${ICON.shield(16)} الشروط</span></div>
            <div class="reqs">
                <span class="req ${d.hasLicence ? 'ok' : 'bad'}">${d.hasLicence ? ICON.check(15) : ICON.x(15)} رخصة قيادة</span>
                <span class="req ok">${ICON.cash(15)} ${money(job.deposit)} تأمين للمركبة (نقدًا أو من البنك)</span>
            </div>
        </div>
    </div>
    <footer class="bottom">${jobActions(job)}</footer>`;
}

function docsView() {
    const d = state.data;
    const lic = d.licences || {};
    const cards = DOCS.map((doc) => {
        const allowed = lic[doc.key] === true;
        const canPay = (d.cash || 0) >= DOC_PRICE;
        return `
        <div class="doc">
            <div class="doc-art"><span class="doc-ico">${ICON[doc.icon](30)}</span><span class="chip"></span><span>${doc.art}</span></div>
            <h3>${esc(doc.label)}</h3>
            <p>${esc(doc.text)}</p>
            <div class="doc-foot">
                ${allowed ? `<span class="badge ok">${ICON.check(13)} لديك</span>` : `<span class="badge bad">${ICON.x(13)} ليست لديك</span>`}
                <b>${money(DOC_PRICE)}</b>
            </div>
            <button class="btn ${allowed ? 'primary' : ''}" data-act="doc" data-doc="${doc.key}" ${allowed && canPay ? '' : 'disabled'}>
                ${allowed ? (canPay ? 'استخرج نسخة جديدة' : 'تحتاج إلى نقد كافٍ') : 'غير متاحة لك'}
            </button>
        </div>`;
    }).join('');
    return `
    <div class="docs-wrap">
        <div class="docs-head">
            <div><h2>الوثائق الرسمية</h2><p>أضعت بطاقتك أو رخصتك؟ استخرج نسخة جديدة هنا. الدفع نقدًا.</p></div>
            <span class="badge soft">${ICON.cash(14)} معك ${money(d.cash)}</span>
        </div>
        <div class="docs">${cards}</div>
    </div>`;
}

function renderCenter() {
    const d = state.data;
    if (!state.selected) state.selected = (d.jobs.find((j) => j.name === d.current) || d.jobs[0]).name;
    const body = state.tab === 'docs'
        ? docsView()
        : `<div class="body">
               <aside class="side">
                   <div class="side-title">الوظائف المتاحة</div>
                   ${d.jobs.map(jobCard).join('')}
                   <div class="side-note">${ICON.info(16)}<span>بعد التقديم تظهر لك علامة المقر على الخريطة. اذهب إليه وتحدّث مع المشرف لتبدأ العمل.</span></div>
               </aside>
               <main class="main">${jobDetails(selectedJob())}</main>
           </div>`;
    $('#screen').innerHTML = headerCenter() + body;
}

// ---------------------------------------------------------------- the HQ panel
function stageText(job, r) {
    if (!r) return '';
    if (job.name === 'garbage') return r.stage === 'return' ? 'امتلأت الشاحنة: عد إلى المستودع لتفريغها' : `الحاوية ${r.index} من ${r.total}`;
    if (job.name === 'delivery') return r.stage === 'load' ? 'حمّل الطرود من دائرة التحميل الذهبية' : `الطرد ${r.index} من ${r.total}`;
    return `المركبة ${r.index} من ${r.total}`;
}

function dots(job, r) {
    if (!r) return '';
    const total = r.total || job.perRound;
    const finished = (job.name === 'garbage' && r.stage === 'return') ? total : (job.name === 'delivery' && r.stage === 'load') ? 0 : r.index - 1;
    let out = '';
    for (let i = 0; i < total; i++) out += `<i class="${i < finished ? 'done' : i === finished ? 'now' : ''}"></i>`;
    return `<div class="progress-dots">${out}</div>`;
}

function renderHq() {
    const job = state.data;
    const s = job.shift;
    const header = `
    <header class="top">
        <div class="brand">
            <span class="brand-icon">${jobIcon(job.icon, 24)}</span>
            <div class="brand-text"><h1>${esc(job.hq.label)}</h1><p>${esc(job.company)} · ${esc(job.hq.place)}</p></div>
        </div>
        <div class="top-side"><button class="icon-btn" data-act="close" aria-label="إغلاق">${ICON.close(18)}</button></div>
    </header>`;

    if (!job.isMine) {
        $('#screen').innerHTML = header + `<div class="empty">هذا المقر لموظفي ${esc(job.label)} فقط. قدّم على الوظيفة من مركز التوظيف.</div>`;
        return;
    }

    if (!s) {
        const canPay = (job.money.cash + job.money.bank) >= job.deposit;
        const word = job.taskWord[job.perRound > 2 && job.perRound < 11 ? 1 : 0];
        $('#screen').innerHTML = header + `
        <div class="scroll">
            <div class="hero hq-hero">
                <img src="${IMAGE_URL(job.vehicle.model)}" alt="" onerror="this.remove()" />
                <div class="hero-text">
                    <span class="company">${ICON.star(14)} المستوى ${job.level.level} · ${esc(job.level.name)}</span>
                    <h2>${esc(job.label)}</h2>
                    <p>${esc(job.vehicle.label)} بانتظارك في الساحة.</p>
                </div>
            </div>
            <div class="supervisor">
                <span class="avatar">${ICON.user(20)}</span>
                <p>أهلًا! أنا <b>${esc(job.supervisor)}</b>. ستستلم ${esc(job.vehicle.label)} وتلبس زي العمل، وكل جولة ${job.perRound} ${esc(word)} قريبة من بعضها. التأمين ${money(job.deposit)} يعود إليك حين تُرجع المركبة إلى هنا.</p>
            </div>
            <div class="facts">
                <div class="fact"><span>${ICON.list(14)} أجر المهمة</span><b>${esc(job.payText)}</b></div>
                <div class="fact"><span>${ICON.star(14)} زيادة مستواك</span><b class="gold">+${pct(job.level.bonus)}</b></div>
                <div class="fact"><span>${ICON.key(14)} التأمين</span><b>${money(job.deposit)}</b><small>يُعاد عند الإرجاع</small></div>
                <div class="fact"><span>${ICON.gift(14)} مكافأة الإرجاع</span><b>حتى ${money(job.bonusMax)}</b><small>حسب جولاتك وحالة المركبة</small></div>
            </div>
        </div>
        <footer class="bottom">
            ${!job.hasLicence ? `<div class="bottom-note">${ICON.warn(16)} تحتاج إلى رخصة قيادة</div>`
                : !canPay ? `<div class="bottom-note">${ICON.warn(16)} تحتاج إلى ${money(job.deposit)} للتأمين</div>` : ''}
            <button class="btn primary" data-act="start" ${job.hasLicence && canPay ? '' : 'disabled'}>${ICON.key(18)} ابدأ المناوبة</button>
        </footer>`;
        return;
    }

    const vehicleState = !s.hasVehicle ? `<b class="bad">مفقودة</b>` : s.vehicleHere ? `<b class="gold">في المقر ✓</b>` : `<b>بعيدة عن المقر</b>`;
    let actions;
    if (!s.hasVehicle) {
        actions = `<div class="bottom-note">${ICON.warn(16)} المركبة مفقودة، فلن يُعاد التأمين</div>
                   <button class="btn primary" data-act="end" data-without="1">${ICON.door(18)} إنهاء المناوبة</button>`;
    } else if (s.vehicleHere) {
        actions = `<button class="btn primary" data-act="end">${ICON.check(18)} إنهاء المناوبة وإرجاع المركبة</button>`;
    } else {
        actions = `<button class="btn link" data-act="end-without">إنهاء دون المركبة</button>
                   <button class="btn primary" disabled>${ICON.pin(18)} أحضر المركبة إلى المقر أولًا</button>`;
    }
    $('#screen').innerHTML = header + `
    <div class="scroll">
        <div class="stats">
            <div class="stat"><b>${s.rounds}</b><span>جولات مكتملة</span></div>
            <div class="stat"><b>${s.tasks}</b><span>مهام أنجزتها</span></div>
            <div class="stat"><b class="gold">${money(s.earned)}</b><span>كسبت في هذه المناوبة</span></div>
            <div class="stat"><b>${s.minutes}</b><span>دقيقة عمل</span></div>
        </div>
        <div class="box">
            <div class="box-title"><span>${ICON.route(16)} الجولة ${s.round ? s.round.n : 1}</span><small>${esc(stageText(job, s.round))}</small></div>
            ${dots(job, s.round)}
        </div>
        <div class="box">
            <div class="box-title"><span>${ICON.key(16)} إرجاع المركبة</span></div>
            <div class="return-row"><span>المركبة</span>${vehicleState}</div>
            <div class="return-row"><span>التأمين</span><b>${s.hasVehicle ? money(s.deposit) : money(0)}</b></div>
            <div class="return-row"><span>مكافأة الإرجاع الآن</span><b class="gold">${money(s.hasVehicle ? s.bonus : 0)}</b></div>
        </div>
        <div class="supervisor">
            <span class="avatar">${ICON.user(20)}</span>
            <p>${s.vehicleHere ? `عمل رائع! أوقفت المركبة في المقر، يمكنك إنهاء المناوبة واستلام التأمين والمكافأة.` : `تابع جولتك، وحين تنتهي أحضر المركبة إلى الساحة هنا لتستلم التأمين ومكافأة الإرجاع.`}</p>
        </div>
    </div>
    <footer class="bottom">${actions}</footer>`;
}

// ---------------------------------------------------------------- render + actions
function render() {
    if (!state.data) return;
    $('#tablet').classList.toggle('hq', state.mode === 'hq');
    if (state.mode === 'hq') renderHq();
    else renderCenter();
}

async function refresh() {
    const data = await post('refresh', { mode: state.mode, job: state.data && state.data.name });
    if (data) {
        state.data = data;
        render();
    }
}

function close() {
    closeSheet();
    $('#root').classList.remove('open');
    state.mode = null;
    post('close');
}

document.addEventListener('click', async (e) => {
    const el = e.target.closest('[data-act]');
    if (!el || el.disabled || state.busy) return;
    const act = el.dataset.act;

    if (act === 'close') return close();
    if (act === 'sheet-close') return closeSheet();
    if (act === 'tab') { state.tab = el.dataset.tab; return render(); }
    if (act === 'select') { state.selected = el.dataset.job; return render(); }

    if (act === 'gps') {
        post('gps', { job: el.dataset.job });
        toast('حدّدنا المقر على الخريطة', 'success');
        return;
    }

    if (act === 'apply') {
        const job = state.data.jobs.find((j) => j.name === el.dataset.job);
        const leaving = state.data.jobs.find((j) => j.name === state.data.current);
        if (leaving) {
            openSheet(`
                <h3>تغيير الوظيفة</h3>
                <p class="kit-sheet-text">ستترك وظيفة <b>${esc(leaving.label)}</b> وتصبح <b>${esc(job.label)}</b>. يبقى مستواك في كل وظيفة محفوظًا.</p>
                <div class="kit-sheet-actions">
                    <button class="btn" data-act="sheet-close">إلغاء</button>
                    <button class="btn primary" data-act="apply-yes" data-job="${esc(job.name)}">${ICON.check(16)} نعم، غيّر وظيفتي</button>
                </div>`);
            return;
        }
        return apply(job.name);
    }
    if (act === 'apply-yes') { closeSheet(); return apply(el.dataset.job); }

    if (act === 'resign') {
        openSheet(`
            <h3>الاستقالة</h3>
            <p class="kit-sheet-text">ستصبح بلا وظيفة، ويبقى مستواك محفوظًا إن عدت إليها لاحقًا.</p>
            <div class="kit-sheet-actions">
                <button class="btn" data-act="sheet-close">إلغاء</button>
                <button class="btn danger" data-act="resign-yes">${ICON.door(16)} نعم، أستقيل</button>
            </div>`);
        return;
    }
    if (act === 'resign-yes') {
        closeSheet();
        state.busy = true;
        const res = await post('resign');
        state.busy = false;
        if (res && res.ok) { toast('استقلت من وظيفتك'); await refresh(); }
        else toast((res && res.error) || 'حدث خطأ', 'error');
        return;
    }

    if (act === 'doc') {
        state.busy = true;
        el.innerHTML = '<span class="kit-spinner"></span>';
        const res = await post('document', { item: el.dataset.doc });
        state.busy = false;
        if (res && res.ok) toast('استلمت الوثيقة، تجدها في حقيبتك', 'success');
        else toast('تعذّر استخراج الوثيقة', 'error');
        await refresh();
        return;
    }

    if (act === 'start') {
        state.busy = true;
        el.innerHTML = '<span class="kit-spinner"></span> جارٍ التجهيز…';
        const res = await post('startShift', { job: state.data.name });
        state.busy = false;
        if (!res || !res.ok) {
            toast((res && res.error) || 'حدث خطأ', 'error');
            render();
        }
        return;
    }

    if (act === 'end') return endShift(el.dataset.without === '1');
    if (act === 'end-without') {
        openSheet(`
            <h3>إنهاء دون المركبة</h3>
            <p class="kit-sheet-text">المركبة ليست في المقر، فلن يُعاد إليك التأمين (${money(state.data.shift.deposit)}) ولن تحصل على مكافأة الإرجاع. ما كسبته من المهام يبقى لك.</p>
            <div class="kit-sheet-actions">
                <button class="btn" data-act="sheet-close">إلغاء</button>
                <button class="btn danger" data-act="end-without-yes">${ICON.door(16)} إنهاء المناوبة</button>
            </div>`);
        return;
    }
    if (act === 'end-without-yes') { closeSheet(); return endShift(true); }
});

async function apply(name) {
    state.busy = true;
    const res = await post('apply', { job: name });
    state.busy = false;
    if (res && res.ok) {
        const job = state.data.jobs.find((j) => j.name === name);
        toast(`مبروك! أصبحت ${job.label}`, 'success');
        state.selected = name;
        await refresh();
    } else {
        toast((res && res.error) || 'حدث خطأ', 'error');
    }
}

async function endShift(withoutVehicle) {
    state.busy = true;
    const res = await post('endShift', { withoutVehicle });
    state.busy = false;
    if (!res || !res.ok) {
        toast((res && res.error) || 'حدث خطأ', 'error');
        await refresh();
    }
}

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || !state.mode) return;
    if (sheetOpen()) closeSheet();
    else close();
});

window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (msg.action === 'open') {
        state.mode = msg.mode;
        state.data = msg.data;
        state.busy = false;
        if (msg.mode === 'center') { state.tab = 'jobs'; state.selected = null; }
        closeSheet();
        $('#root').classList.add('open');
        render();
    } else if (msg.action === 'close') {
        closeSheet();
        $('#root').classList.remove('open');
        state.mode = null;
    }
});
