// EX_Tii EMS — treatment mode (like the video): the camera over the patient, points on the body,
// the treatment plan, the item bar and the mini-games. The game (client/treat.lua) and the server
// (exti_medical) decide everything; this page only shows it and sends what the medic did.
(() => {
    const params = new URLSearchParams(location.search);
    if (params.get('mirror') === '1') return; // the screen on the held tablet never shows this

    const inGame = typeof GetParentResourceName === 'function';
    const resource = inGame ? GetParentResourceName() : 'exti_ems';
    const root = document.getElementById('treat');
    if (!root) return;

    const IMG = (item) => (inGame ? `nui://ox_inventory/web/images/${item}.png` : `img/${item}.png`);
    const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const list = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

    const ZONES = ['head', 'neck', 'chest', 'abdomen', 'back', 'r_arm', 'l_arm', 'r_leg', 'l_leg'];
    const ZONE = { head: 'الرأس', neck: 'الرقبة', chest: 'الصدر', abdomen: 'البطن', back: 'الظهر', r_arm: 'الذراع اليمنى', l_arm: 'الذراع اليسرى', r_leg: 'الرجل اليمنى', l_leg: 'الرجل اليسرى' };
    const ERR = {
        too_far: 'ابتعدت عن المريض', off_duty: 'سجّل دخولك للخدمة أولًا', no_item: 'ما عندك هذا الغرض — خذه من خزانة المستلزمات',
        not_needed: 'المريض ما يحتاج هذا الآن', busy: 'انتظر حتى تنتهي الخطوة الحالية', extract_first: 'أخرج الرصاصة أولًا',
        diag_first: 'أكمل الفحص أولًا: العلامات الحيوية وكل أجزاء الجسم', bleeding_first: 'أوقف النزيف أولًا', infuse_first: 'ابدأ نقل الدم أولًا',
        cpr_first: 'ابدأ الإنعاش القلبي أولًا (دورة واحدة على الأقل)', running: 'الكيس الحالي ما خلص بعد', not_open: 'العلاج مغلق',
        no_patient: 'المريض غير موجود', failed: 'تعذّر — حاول مرة ثانية', not_done: 'باقي مهام في الخطة', healthy: 'المريض بخير',
        declined: 'المريض رفض العلاج', ask_later: 'المريض رفض قبل قليل: انتظر ثم حاول', is_down: 'المريض على الأرض', not_down: 'المريض واقف',
    };
    const errText = (e) => ERR[e] || ERR.failed;

    const S = {
        on: false, data: null, sel: null, pick: null, busy: null, toast: null, done: null,
        seen: {},       // tasks seen during this treatment (so the done ones stay with a ✓)
        pts: {},        // [zone] = { x, y, on } (0..1 of the screen)
        game: null,     // a mini-game is open
    };

    function post(name, body) {
        if (!inGame) return Promise.resolve(previewPost(name, body));
        return fetch(`https://${resource}/${name}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body || {}),
        }).then((r) => r.json()).catch(() => null);
    }

    // ------------------------------------------------------------------
    // little icons for the check tools (the supplies use the inventory pictures)
    // ------------------------------------------------------------------
    const ICON = {
        pulse: '<svg viewBox="0 0 48 48" fill="none" stroke="#3ddc97" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6 26h8l4-10 6 20 5-14 3 4h10"/></svg>',
        bp: '<svg viewBox="0 0 48 48" fill="none" stroke-width="2.4" stroke-linecap="round"><circle cx="24" cy="25" r="15" stroke="#d9dde3"/><path d="M24 25l7-7" stroke="#ff6b6b"/><path d="M14 33h20" stroke="#8a9099"/></svg>',
        spo2: '<svg viewBox="0 0 48 48" fill="none" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><rect x="12" y="10" width="24" height="30" rx="8" stroke="#d9dde3"/><path d="M18 22h4l2-4 3 8 2-4h3" stroke="#46d6ff"/></svg>',
        ask: '<svg viewBox="0 0 48 48" fill="none" stroke="#d9dde3" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M10 12h28v18H22l-8 7v-7h-4z"/><path d="M20 19a4 4 0 1 1 5 4v2" stroke="#20c997"/></svg>',
        cpr: '<svg viewBox="0 0 48 48" fill="none" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M24 38s-13-8-13-18a7 7 0 0 1 13-4 7 7 0 0 1 13 4c0 10-13 18-13 18z" stroke="#ff6b6b"/><path d="M14 24h6l3-5 3 9 2-4h6" stroke="#f2f2f2"/></svg>',
    };

    // ------------------------------------------------------------------
    // the plan
    // ------------------------------------------------------------------
    function plan() { return (S.data && S.data.plan) || { zones: {}, tasks: [], later: [], diag: { zones: {}, vitals: {} } }; }
    function items() { const m = {}; list(S.data && S.data.items).forEach((it) => { m[it.key] = it; }); return m; }
    function itemOf(key) { return items()[key] || { key, label: key, count: 0 }; }

    // every action that can be done on a wound right now, by item
    function woundActions() {
        const out = [];
        const zones = plan().zones || {};
        ZONES.forEach((z) => {
            const zz = zones[z];
            if (!zz) return;
            list(zz.wounds).forEach((w) => list(w.actions).forEach((a) => out.push({ zone: z, wound: w, action: a })));
        });
        return out;
    }

    function taskRows() {
        const p = plan();
        const now = list(p.tasks);
        const ids = new Set(now.map((t) => t.id));
        now.forEach((t) => { S.seen[t.id] = { title: t.title, optional: t.optional }; });
        const rows = { treat: [], cpr: [] };
        let first = true;
        now.forEach((t) => {
            const state = t.running ? 'run' : t.blocked ? 'wait' : (first ? 'now' : 'todo');
            if (state === 'now') first = false;
            (t.kind === 'cpr' ? rows.cpr : rows.treat).push({ t, state });
        });
        Object.entries(S.seen).forEach(([id, t]) => {
            if (!ids.has(id)) (id === 'cpr' ? rows.cpr : rows.treat).push({ t: { id, title: t.title, optional: t.optional }, state: 'done' });
        });
        return rows;
    }

    function taskHtml(row) {
        const { t, state } = row;
        const cls = state === 'now' ? 'todo now' : state;
        const why = t.blocked ? `<small class="why">${esc(errText(t.blocked))}</small>` : '';
        const opt = t.optional ? ' <span style="font-size:10px;color:var(--faint)">(اختياري)</span>' : '';
        return `<div class="tk ${cls}" data-task="${esc(t.id)}"><i>${state === 'done' ? '✓' : ''}</i><div><b>${esc(t.title)}${opt}</b>${state === 'done' ? '' : (t.sub ? `<small>${esc(t.sub)}</small>` : '')}${state === 'done' ? '' : why}</div></div>`;
    }

    function planHtml() {
        const d = S.data;
        const p = plan();
        const dg = p.diag || { zones: {}, vitals: {} };
        const z = dg.zones || {}, v = dg.vitals || {};
        const status = p.death === 3 ? 'لا يوجد نبض' : p.death === 2 ? 'على الأرض' : (d.patient.female ? 'واعية' : 'واعٍ');
        const rows = taskRows();
        const vDone = (v.done || 0) >= (v.of || 3), zDone = (z.done || 0) >= (z.of || 9);
        let h = `<div class="tr-plan tx">
            <h1>ثبّت حالة المريض <span>خطة العلاج</span></h1>
            <div class="who">${esc(d.patient.name)} · ${status}${d.patient.fake ? ' · تجريبي' : ''}</div>
            <h2>التشخيص</h2>
            <div class="tk ${vDone ? 'done' : 'todo'}"><i>${vDone ? '✓' : ''}</i><div><b>قِس العلامات الحيوية</b>${vDone ? '' : `<small>النبض، الضغط، الأكسجين — ${v.done || 0} من ${v.of || 3} (من الأدوات تحت)</small>`}</div></div>
            <div class="tk ${zDone ? 'done' : 'todo'}"><i>${zDone ? '✓' : ''}</i><div><b>افحص كل أجزاء الجسم</b>${zDone ? '' : `<small>${z.done || 0} من ${z.of || 9} — اضغط على النقاط البيضاء${p.hidden ? ' · فيه إصابات ما اكتشفتها بعد' : ''}</small>`}</div></div>`;
        if (rows.treat.length) h += '<h2>العلاج</h2>' + rows.treat.map(taskHtml).join('');
        else if (vDone && zDone && !rows.cpr.length) h += '<h2>العلاج</h2><div class="tk done"><i>✓</i><div><b>لا يحتاج علاجًا في الميدان</b></div></div>';
        if (rows.cpr.length) h += '<h2>الإنعاش</h2>' + rows.cpr.map(taskHtml).join('');
        if (list(p.later).length) {
            h += '<h2>بعد الإسعاف</h2>' + list(p.later).map((l) => `<div class="tk later"><i></i><div><b>${esc(l.title)}</b><small>${esc(l.sub)}</small></div></div>`).join('');
        }
        if (p.complete) {
            h += `<button class="fin" data-complete>أنهِ العلاج — حالة المريض مستقرة</button>`;
        } else {
            h += '<div class="foot">أنهِ كل مهام العلاج حتى تستقر حالة المريض.</div>';
        }
        return h + '</div>';
    }

    function miniHtml() {
        const m = (S.data && S.data.mini) || {};
        const p = plan();
        let inf = '';
        if (p.infusion) {
            const left = Math.max(0, Math.round(p.infusion.left - (Date.now() - (S.infAt || Date.now())) / 1000));
            const pct = Math.round((1 - left / Math.max(1, p.infusion.total)) * 100);
            inf = `<div class="tr-inf"><span>${p.infusion.kind === 'blood' ? 'كيس الدم شغّال' : 'المحلول شغّال'}</span><div class="bar"><i style="width:${pct}%"></i></div><b style="direction:ltr">0:${String(left).padStart(2, '0')}</b></div>`;
        }
        const s = (v, cls, unit, label) => v != null ? `<span class="${cls}">${label}${v}${unit ? ` <em>${unit}</em>` : ''}</span>` : `<span class="none">${label}—</span>`;
        return `${inf}<div class="tr-mini">${s(m.hr, 'm-hr', 'bpm', '♥ ')}${s(m.spo2 != null ? m.spo2 + '%' : null, 'm-o2', '', 'O₂ ')}${s(m.bp, 'm-bp', 'mmHg', '')}</div>`;
    }

    // ------------------------------------------------------------------
    // the card next to a point
    // ------------------------------------------------------------------
    function chip(key, main) {
        const it = itemOf(key);
        const none = !it.count;
        return `<button class="tr-chip ${main ? 'main' : ''}" data-use="${esc(key)}" ${none ? 'disabled' : ''}><img src="${IMG(it.item || key)}" onerror="this.style.display='none'">${esc(it.label)}<small>${it.tool ? '' : '×' + (it.count || 0)}</small></button>`;
    }

    function popHtml() {
        const z = S.sel;
        if (!z) return '';
        const zz = (plan().zones || {})[z];
        const pt = S.pts[z];
        if (!zz || !pt || !pt.on) return '';
        const W = window.innerWidth, H = window.innerHeight;
        let x = pt.x * W + (z === 'back' ? 34 : 0) + 26;
        if (x + 330 > W) x = pt.x * W - 26 - 320;
        const y = clamp(pt.y * H - 40, 70, H - 420);
        let body;
        let chipTag;
        if (!zz.checked) {
            chipTag = '<span class="un">لم يُفحص</span>';
            body = `<p>ما فحصت ${ZONE[z]} بعد — افحصه لتعرف إذا فيه إصابة.</p><button class="probe" data-probe="${z}">افحص ${ZONE[z]}</button>`;
        } else if (!list(zz.wounds).length) {
            chipTag = '<span class="ok">سليم</span>';
            body = '<p>لا توجد إصابات ظاهرة في هذا الجزء.</p>';
        } else {
            chipTag = zz.todo ? '<span class="bad">إصابة</span>' : '<span class="ok">تمت المعالجة</span>';
            body = list(zz.wounds).map((w) => {
                const acts = list(w.actions).map((a) => {
                    const blocked = a.blocked ? `<div class="lab blk">${esc(errText(a.blocked))}</div>` : `<div class="lab">${esc(a.label)}${a.optional ? ' (اختياري)' : ''}</div>`;
                    const chips = a.blocked ? '' : list(a.items).map((k, i) => chip(k, i === 0).replace('data-use=', `data-wid="${w.id}" data-act="${a.kind}" data-use=`)).join('');
                    return `<div class="row">${blocked}${chips}</div>`;
                }).join('');
                return `<div class="tr-w"><div class="t">${esc(w.text)}</div>
                    ${list(w.tags).length ? `<div class="tr-tags">${list(w.tags).map((t) => `<span class="${esc(t[1])}">${esc(t[0])}</span>`).join('')}</div>` : ''}
                    ${acts ? `<div class="tr-act">${acts}</div>` : ''}</div>`;
            }).join('');
        }
        return `<div class="tr-pop tx" style="left:${x}px;top:${y}px"><div class="h"><b>${ZONE[z]}</b>${chipTag}</div>${body}<div class="close" data-unsel>إغلاق</div></div>`;
    }

    // ------------------------------------------------------------------
    // the item bar
    // ------------------------------------------------------------------
    function hotKeys() {
        const keys = new Set();
        list(plan().tasks).forEach((t) => { if (!t.blocked && !t.running) list(t.items).forEach((k) => keys.add(k)); });
        return keys;
    }

    function barHtml() {
        const hot = hotKeys();
        const p = plan();
        const v = (S.data && S.data.mini) || {};
        const cprTask = list(p.tasks).find((t) => t.kind === 'cpr');
        const tool = (key, icon, label, on) => `<div class="tr-slot ${on ? 'hot' : ''}" data-tool="${key}">${icon}<b>${label}</b></div>`;
        let h = '<div class="tr-bar tx"><div class="tr-group"><div class="gl">فحص</div>';
        h += tool('pulse', ICON.pulse, 'جسّ النبض', v.hr == null);
        h += tool('bp', ICON.bp, 'كُم الضغط', v.bp == null);
        h += tool('spo2', ICON.spo2, 'مقياس الأكسجين', v.spo2 == null);
        if (p.death !== 3) h += tool('ask', ICON.ask, 'اسأل المريض', false);
        if (cprTask) h += tool('cpr', ICON.cpr, 'إنعاش قلبي', !cprTask.blocked);
        h += '</div>';
        const all = list(S.data && S.data.items);
        const group = (label, filter) => {
            const its = all.filter(filter);
            if (!its.length) return '';
            return `<div class="tr-group"><div class="gl">${label}</div>${its.map((it) => `<div class="tr-slot ${hot.has(it.key) ? 'hot' : ''} ${S.pick === it.key ? 'on' : ''} ${!it.count ? 'none' : ''}" data-item="${esc(it.key)}">${it.tool ? '' : `<span class="n">${it.count}×</span>`}<img src="${IMG(it.item)}" onerror="this.style.visibility='hidden'"><b>${esc(it.label)}</b></div>`).join('')}</div>`;
        };
        h += group('أدوات', (it) => it.tool);
        h += group('مستلزمات', (it) => !it.tool);
        return h + '</div>';
    }

    // ------------------------------------------------------------------
    // drawing
    // ------------------------------------------------------------------
    let ptsEl, uiEl, gameEl;
    function ensureLayers() {
        if (uiEl) return;
        root.innerHTML = '<div class="vignette"></div><div id="tr-pts"></div><div id="tr-ui"></div><div id="tr-game"></div>';
        ptsEl = root.querySelector('#tr-pts');
        uiEl = root.querySelector('#tr-ui');
        gameEl = root.querySelector('#tr-game');
        ZONES.forEach((z) => {
            const el = document.createElement('div');
            el.className = 'tr-pt tx';
            el.dataset.zone = z;
            el.innerHTML = `<span class="lb">${ZONE[z]}</span>`;
            el.style.display = 'none';
            el.addEventListener('click', (e) => { e.stopPropagation(); pointClick(z); });
            ptsEl.appendChild(el);
        });
    }

    function placePoints() {
        if (!ptsEl) return;
        const W = window.innerWidth, H = window.innerHeight;
        const zones = plan().zones || {};
        const picks = S.pick ? new Set(woundActions().filter((a) => !a.action.blocked && list(a.action.items).includes(S.pick)).map((a) => a.zone)) : null;
        ptsEl.querySelectorAll('.tr-pt').forEach((el) => {
            const z = el.dataset.zone;
            const p = S.pts[z];
            if (!p || !p.on || S.game) { el.style.display = 'none'; return; }
            el.style.display = '';
            el.style.left = `${p.x * W + (z === 'back' ? 34 : 0)}px`;
            el.style.top = `${p.y * H}px`;
            const zz = zones[z] || {};
            let cls = 'tr-pt tx ';
            if (!zz.checked) cls += 'un';
            else if (zz.todo > 0) cls += 'todo';
            else if (zz.level > 0) cls += 'l' + Math.min(3, zz.level);
            else cls += 'ok';
            if (S.sel === z) cls += ' sel';
            if (picks && picks.has(z)) cls += ' pick';
            if (S.busy && S.busy.zone === z) cls += ' doing';
            el.className = cls;
        });
    }

    function render() {
        if (!S.on || !S.data) { root.classList.add('hidden'); return; }
        root.classList.remove('hidden');
        ensureLayers();
        let h = planHtml();
        h += `<div class="tr-top tx"><span class="tr-pill"><span class="dot"></span>وضع العلاج · ${esc(S.data.patient.name)}</span><span class="tr-pill btn" data-exit>خروج <kbd>Backspace</kbd></span></div>`;
        h += miniHtml();
        if (!S.game) {
            h += popHtml();
            h += barHtml();
            if (S.busy) {
                h += `<div class="tr-busy tx"><div class="l">${esc(S.busy.label)}</div><div class="bar"><i id="tr-busybar"></i></div></div>`;
            } else {
                h += `<div class="tr-hint">${S.pick ? `اختر الجرح: <b>النقاط الذهبية</b> · <kbd>Esc</kbd> للإلغاء` : 'اضغط على <b>نقطة</b> لتفحصها أو تعالجها · أو اختر أداة من الأسفل'}</div>`;
            }
        }
        if (S.toast) h += `<div class="tr-toast ${esc(S.toast.type || '')}">${esc(S.toast.text)}</div>`;
        if (S.done) {
            h += `<div class="tr-done tx"><div class="card"><h3>✓ حالة المريض مستقرة</h3><p>${S.done.paid ? `أجرك $${S.done.paid}` : 'أحسنت — العلاج اكتمل'}</p><button data-exit>خروج</button></div></div>`;
        }
        uiEl.innerHTML = h;
        placePoints();
        if (S.busy) {
            const bar = uiEl.querySelector('#tr-busybar');
            const total = S.busy.secs * 1000;
            const passed = Date.now() - S.busy.at;
            bar.style.transition = 'none';
            bar.style.width = `${clamp(passed / total * 100, 0, 100)}%`;
            requestAnimationFrame(() => { bar.style.transition = `width ${Math.max(0, total - passed)}ms linear`; bar.style.width = '100%'; });
        }
    }

    let toastTimer = null;
    function toast(text, type) {
        S.toast = { text, type };
        render();
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { S.toast = null; render(); }, 2800);
    }

    function setView(v) {
        if (!v) return;
        const hadInf = S.data && S.data.plan && S.data.plan.infusion;
        S.data = v;
        if (v.plan && v.plan.infusion && (!hadInf || hadInf.left !== v.plan.infusion.left)) S.infAt = Date.now();
        if (v.stable && !S.done) showDone(0);
    }

    // ------------------------------------------------------------------
    // what the medic does
    // ------------------------------------------------------------------
    function pointClick(z) {
        if (S.game || S.busy) return;
        if (S.pick) {
            const acts = woundActions().filter((a) => a.zone === z && !a.action.blocked && list(a.action.items).includes(S.pick));
            const key = S.pick;
            S.pick = null;
            if (acts.length === 1) return startAction(acts[0].action.kind, acts[0].wound.id, key);
        }
        S.sel = S.sel === z ? null : z;
        render();
    }

    async function timed(label, secs, zone, fn) {
        S.busy = { label, secs, at: Date.now(), zone };
        S.sel = null;
        render();
        const res = await fn();
        S.busy = null;
        if (!S.on) return null;
        if (res && res.ok) setView(res.data);
        else toast(errText(res && res.error), 'error');
        render();
        return res;
    }

    function probe(z) {
        const t = (S.data.times || {}).zone || 3;
        timed(`جارٍ فحص ${ZONE[z]}…`, t, z, () => post('treatProbe', { zone: z }));
    }

    function measure(tool) {
        const times = S.data.times || {};
        const map = { pulse: ['جارٍ جسّ النبض…', times.pulse || 6], spo2: ['جارٍ قياس الأكسجين…', times.spo2 || 4] };
        const m = map[tool];
        if (!m) return;
        timed(m[0], m[1], null, () => post('treatMeasure', { tool }));
    }

    function askPatient() {
        timed('تسأل المريض: وين يوجعك؟', (S.data.times || {}).ask || 2, null, async () => {
            const res = await post('treatAsk', {});
            if (res && res.ok && res.data && res.data.said) setTimeout(() => toast(res.data.said.quote || '', ''), 50);
            return res;
        });
    }

    function itemClick(key) {
        if (S.game || S.busy) return;
        const it = itemOf(key);
        if (!it.count) return toast(errText('no_item'), 'error');
        const p = plan();
        const task = list(p.tasks).find((t) => list(t.items).includes(key) && ['infuse', 'med', 'oxygen'].includes(t.kind));
        if (key === 'defib') {
            const cpr = list(p.tasks).find((t) => t.kind === 'cpr');
            if (!cpr) return toast(errText('not_needed'), 'error');
            return startAction('defib', null, 'defib');
        }
        if (task) {
            if (task.blocked) return toast(errText(task.blocked), 'error');
            if (task.running) return toast(errText('running'), 'error');
            return startAction(task.kind, null, key);
        }
        const acts = woundActions().filter((a) => !a.action.blocked && list(a.action.items).includes(key));
        if (!acts.length) return toast(errText('not_needed'), 'error');
        if (acts.length === 1) return startAction(acts[0].action.kind, acts[0].wound.id, key);
        S.pick = key;
        S.sel = null;
        render();
    }

    function taskClick(id) {
        if (S.game || S.busy) return;
        const t = list(plan().tasks).find((x) => x.id === id);
        if (!t) return;
        if (t.blocked) return toast(errText(t.blocked), 'error');
        if (t.zone) { S.sel = t.zone; return render(); }
        if (t.kind === 'cpr') return startAction('cpr', null, null);
        if (t.running) return toast(errText('running'), 'error');
        const key = list(t.items).find((k) => itemOf(k).count > 0);
        if (!key) return toast(errText('no_item'), 'error');
        startAction(t.kind, null, key);
    }

    async function startAction(action, wid, choice) {
        if (S.game || S.busy) return;
        S.sel = null; S.pick = null;
        S.game = 'wait'; // no second step while this one is starting
        const res = await post('treatStart', { action, wid, choice });
        S.game = null;
        if (!S.on) return;
        if (!res || !res.ok) { toast(errText(res && res.error), 'error'); render(); return; }
        const d = res.data || {};
        const done = async (result) => {
            closeGame();
            const fin = await post('treatFinish', { token: d.token, result });
            if (!S.on) return;
            if (!fin || !fin.ok) { toast(errText(fin && fin.error), 'error'); render(); return; }
            setView(fin.data);
            const x = fin.extra || {};
            if (x.failed) toast(action === 'extract' ? 'لمست جدار الجرح كثير — حاول مرة ثانية' : 'ما نجحت — حاول مرة ثانية', 'error');
            else if (x.stable) showDone(x.paid || 0);
            else if (x.pulse) toast('رجع النبض! كمّل باقي العلاج', 'success');
            else if (action === 'cpr') toast('دورة كاملة — كمّل حتى يرجع النبض', '');
            else if (x.notNeeded) toast(errText('not_needed'), 'error');
            render();
        };
        const cancel = () => { closeGame(); post('treatCancel', {}); render(); };
        openGame(d.game, d.params || {}, action, done, cancel);
    }

    function showDone(paid) {
        S.done = { paid };
        render();
        setTimeout(() => { if (S.done) exit(); }, 6000);
    }

    function exit() {
        if (!S.on) return;
        closeGame();
        S.on = false;
        S.done = null;
        render();
        post('treatExit', {});
    }

    // ------------------------------------------------------------------
    // the mini-games
    // ------------------------------------------------------------------
    let gameStop = null;
    function closeGame() {
        if (gameStop) { try { gameStop(); } catch (_) { /* gone */ } }
        gameStop = null;
        S.game = null;
        S.cancelGame = null;
        if (gameEl) gameEl.innerHTML = '';
    }

    function shell(title, sub, foot) {
        gameEl.innerHTML = `<div class="tr-game tx"><span class="ret" data-gcancel>↶ رجوع</span>
            <div class="gh"><h3>${title}</h3><p>${sub}</p></div><div class="area"></div><div class="gf">${foot || ''}</div></div>`;
        return gameEl.querySelector('.tr-game');
    }

    function openGame(kind, p, action, done, cancel) {
        S.game = kind;
        render();
        const g = { bullet: bulletGame, wrap: wrapGame, cpr: cprGame, breaths: breathsGame, defib: defibGame }[kind] || quickGame;
        gameStop = g(p, action, done, cancel);
        const ret = gameEl.querySelector('[data-gcancel]');
        if (ret) ret.addEventListener('click', cancel);
        S.cancelGame = cancel;
    }

    // 1) the bullet: drag it straight up between the glowing rails
    function bulletGame(p, action, done) {
        const probes = p.probes;
        const el = shell(probes ? 'انزع سهمي الصاعق' : 'أخرج الرصاصة', 'اسحبها للأعلى بالماوس بدون ما تلمس جدار الجرح',
            'ابقَ في المنتصف بين الخطين المضيئين · <b>3</b> لمسات = تفشل ويزيد النزيف');
        const gap = { 1: 34, 2: 29, 3: 25 }[p.power] || 29;
        const H = 380;
        el.querySelector('.area').innerHTML = `
            <svg width="200" height="${H + 40}" style="display:block;margin:auto;overflow:visible">
                <defs><filter id="tgl"><feGaussianBlur stdDeviation="4"/></filter>
                <linearGradient id="tcv" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#2a0f12"/><stop offset="1" stop-color="#140809"/></linearGradient></defs>
                <rect x="40" y="0" width="120" height="${H + 40}" rx="60" fill="url(#tcv)" stroke="rgba(255,255,255,.1)"/>
                <g id="trl"><line x1="${100 - gap}" y1="30" x2="${100 - gap}" y2="${H}" stroke="#20c997" stroke-width="6" filter="url(#tgl)"/><line x1="${100 + gap}" y1="30" x2="${100 + gap}" y2="${H}" stroke="#20c997" stroke-width="6" filter="url(#tgl)"/>
                <line x1="${100 - gap}" y1="30" x2="${100 - gap}" y2="${H}" stroke="#ffe3a3" stroke-width="2"/><line x1="${100 + gap}" y1="30" x2="${100 + gap}" y2="${H}" stroke="#ffe3a3" stroke-width="2"/></g>
                <g id="tbl" style="cursor:grab">${probes
                    ? '<rect x="-4" y="-16" width="8" height="30" rx="3" fill="#c9cdd2"/><path d="M-6 -16 l6 -10 l6 10z" fill="#20c997"/>'
                    : '<rect x="-9" y="-6" width="18" height="26" rx="2" fill="#b98a2f"/><path d="M-9 -4 Q0 -24 9 -4z" fill="#d9a945"/><rect x="-9" y="14" width="18" height="6" fill="#7d5b1e"/>'}</g>
            </svg><div class="tr-prog"><i id="tbp"></i></div><div class="tr-pv" id="tbt">0%</div>`;
        const svg = el.querySelector('svg');
        const bl = el.querySelector('#tbl');
        let prog = 0, touches = 0, drag = false, mx = 0, my = 0, t0 = performance.now(), last = t0, raf = 0, over = false, cool = 0;
        const top = 40, bottom = H - 10;
        const pos = (now) => {
            const t = (now - t0) / 1000;
            const drift = Math.sin(t * 1.9) * 9 + Math.sin(t * 0.7 + 1) * 7;
            return drift;
        };
        let bx = 100;
        const frame = (now) => {
            const dt = Math.min(0.05, (now - last) / 1000); last = now;
            const rect = svg.getBoundingClientRect();
            if (drag && now > cool) {
                const want = clamp((bottom - (my - rect.top)) / (bottom - top), 0, 1);
                if (want > prog) prog = Math.min(want, prog + dt / 3.6); // never faster than ~3.6 s
                bx = (mx - rect.left) + pos(now);
            } else {
                bx += (100 + pos(now) * 0.3 - bx) * Math.min(1, dt * 4);
            }
            const y = bottom - prog * (bottom - top);
            bl.setAttribute('transform', `translate(${bx} ${y})`);
            el.querySelector('#tbp').style.width = `${Math.round(prog * 100)}%`;
            el.querySelector('#tbt').textContent = `تقدّم الإخراج ${Math.round(prog * 100)}%`;
            if (drag && Math.abs(bx - 100) > gap - 7 && now > cool) {
                touches += 1;
                drag = false;
                cool = now + 600;
                prog = Math.max(0, prog - 0.15);
                el.classList.remove('tr-flash'); void el.offsetWidth; el.classList.add('tr-flash');
                if (touches >= 3) { over = true; done({ ok: false, touches }); return; }
            }
            if (prog >= 1) { over = true; done({ ok: true, touches }); return; }
            raf = requestAnimationFrame(frame);
        };
        const down = (e) => { mx = e.clientX; my = e.clientY; drag = true; };
        const move = (e) => { mx = e.clientX; my = e.clientY; };
        const up = () => { drag = false; };
        bl.addEventListener('pointerdown', down);
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', up);
        raf = requestAnimationFrame(frame);
        return () => { over = true; cancelAnimationFrame(raf); window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); };
    }

    // 2) gauze / pressure bandage / quickclot: follow the spiral around the limb
    function wrapGame(p, action, done) {
        const turns = p.turns || 3;
        const what = { gauze: 'لفّ الشاش', pressure: 'لفّ الضماد الضاغط', quickclot: 'ضع الكويك كلوت ولفّه' }[p.item] || 'لفّ الضماد';
        const el = shell(`${what} — ${esc(p.part || '')}`, 'اضغط على النقطة الذهبية ولفّ مع الخط حول الجرح', 'ابقَ قريبًا من الخط · كل لفّة تنزل شوي');
        const W = 420, H = 380, cx = W / 2, rx = 92, ry = 26;
        const limbTop = 20, limbBot = H - 10;
        el.querySelector('.area').innerHTML = `
            <div class="tr-prog" style="margin-bottom:10px"><i id="twp"></i></div><div class="tr-pv" id="twt" style="margin-bottom:6px">0%</div>
            <svg width="${W}" height="${H}" style="display:block;margin:auto;overflow:visible">
                <defs><linearGradient id="tsk" x1="0" x2="1"><stop offset="0" stop-color="#b47a57"/><stop offset=".5" stop-color="#e2ae8a"/><stop offset="1" stop-color="#a86f4e"/></linearGradient></defs>
                <circle cx="${cx}" cy="${H / 2}" r="${H / 2 - 4}" fill="none" stroke="rgba(255,255,255,.1)" stroke-width="2" stroke-dasharray="2 10"/>
                <path d="M${cx - 44} ${limbTop} C ${cx - 46} 120 ${cx - 48} 240 ${cx - 44} ${limbBot - 40} C ${cx - 42} ${limbBot} ${cx + 42} ${limbBot} ${cx + 44} ${limbBot - 40} C ${cx + 48} 240 ${cx + 46} 120 ${cx + 44} ${limbTop} Z" fill="url(#tsk)"/>
                <path d="M${cx - 30} ${H / 2 + 6} C ${cx - 10} ${H / 2 + 2} ${cx + 12} ${H / 2 + 2} ${cx + 30} ${H / 2 + 6}" stroke="#7a1f22" stroke-width="6" stroke-linecap="round"/>
                <g id="twr"></g>
                <ellipse id="twg" cx="${cx}" rx="${rx}" ry="${ry}" fill="none" stroke="#20c997" stroke-width="3" stroke-dasharray="7 7"/>
                <path id="twa" fill="none" stroke="#f1efe9" stroke-width="12" stroke-linecap="round"/>
                <circle id="twd" r="11" fill="#1a1c22" stroke="#20c997" stroke-width="3" style="cursor:grab"/>
            </svg>`;
        const svg = el.querySelector('svg');
        const startY = H / 2 - (turns - 1) * 22 / 2 - 10;
        let ang = 0, drag = false, mx = 0, my = 0, raf = 0, last = performance.now(), off = 0;
        const total = turns * Math.PI * 2;
        const maxSpeed = (Math.PI * 2) / 2.1; // one turn takes at least ~2 s
        const yOf = (a) => startY + Math.floor(a / (Math.PI * 2)) * 22;
        const pt = (a) => ({ x: cx + rx * Math.cos(a), y: yOf(a) + ry * Math.sin(a) });
        const frame = (now) => {
            const dt = Math.min(0.05, (now - last) / 1000); last = now;
            const rect = svg.getBoundingClientRect();
            const turn = Math.floor(ang / (Math.PI * 2));
            const cy = startY + Math.min(turn, turns - 1) * 22;
            if (drag) {
                const ux = (mx - rect.left - cx) / rx, uy = (my - rect.top - cy) / ry;
                const r = Math.hypot(ux, uy);
                if (r > 0.55 && r < 1.6) {
                    off = 0;
                    const ca = Math.atan2(uy, ux);
                    let d = ca - (ang % (Math.PI * 2));
                    while (d < -Math.PI) d += Math.PI * 2;
                    while (d > Math.PI) d -= Math.PI * 2;
                    if (d > 0 && d < 1.2) ang = Math.min(total, ang + Math.min(d, maxSpeed * dt));
                } else {
                    off += dt;
                }
            }
            const g = el.querySelector('#twg');
            g.setAttribute('cy', cy);
            g.style.opacity = ang >= total ? 0 : 1;
            // the bandage laid so far
            let dstr = '';
            const steps = Math.floor(ang / 0.12);
            for (let i = 0; i <= steps; i++) {
                const a = i * 0.12;
                const q = pt(a);
                const front = Math.sin(a % (Math.PI * 2)) > -0.15;
                dstr += `${i === 0 ? 'M' : (front ? 'L' : 'M')}${q.x.toFixed(1)} ${q.y.toFixed(1)} `;
            }
            el.querySelector('#twa').setAttribute('d', dstr);
            const d = pt(ang);
            el.querySelector('#twd').setAttribute('cx', d.x);
            el.querySelector('#twd').setAttribute('cy', Math.min(d.y, H));
            const pct = Math.round(ang / total * 100);
            el.querySelector('#twp').style.width = `${pct}%`;
            el.querySelector('#twt').textContent = off > 1.2 ? 'ارجع للخط!' : `${pct}%`;
            if (ang >= total) { done({ ok: true }); return; }
            raf = requestAnimationFrame(frame);
        };
        const dot = el.querySelector('#twd');
        const down = (e) => { mx = e.clientX; my = e.clientY; drag = true; };
        const move = (e) => { mx = e.clientX; my = e.clientY; };
        const up = () => { drag = false; };
        dot.addEventListener('pointerdown', down);
        svg.addEventListener('pointerdown', down);
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', up);
        raf = requestAnimationFrame(frame);
        return () => { cancelAnimationFrame(raf); window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); };
    }

    // breaths: trace the line so the bag sits on the mouth (used by CPR and the oxygen)
    function tracePart(container, onBreath) {
        const W = 440, H = 300;
        container.innerHTML = `<svg width="${W}" height="${H}" style="display:block;margin:auto;overflow:visible">
            <defs><radialGradient id="tfs" cx=".45" cy=".35" r=".7"><stop offset="0" stop-color="rgba(255,220,190,.25)"/><stop offset="1" stop-color="rgba(0,0,0,.35)"/></radialGradient></defs>
            <ellipse cx="170" cy="150" rx="66" ry="80" fill="#2a2420"/><ellipse cx="170" cy="160" rx="55" ry="66" fill="#9c6e52"/><ellipse cx="170" cy="160" rx="55" ry="66" fill="url(#tfs)"/>
            <path d="M152 186 q18 8 36 0" stroke="#5b2f24" stroke-width="5" stroke-linecap="round" fill="none"/>
            <path id="tbp2" d="M380 50 C 330 64 270 120 196 184" stroke="rgba(255,255,255,.28)" stroke-width="5" stroke-linecap="round" fill="none" stroke-dasharray="6 7"/>
            <path id="tbd" stroke="#fff" stroke-width="5" stroke-linecap="round" fill="none"/>
            <g id="tbm" style="cursor:grab"><ellipse rx="22" ry="16" fill="rgba(70,214,255,.25)" stroke="#46d6ff" stroke-width="2"/><circle r="9" fill="#1a1c22" stroke="#20c997" stroke-width="3"/></g>
        </svg>`;
        const svg = container.querySelector('svg');
        const path = container.querySelector('#tbp2');
        const len = path.getTotalLength();
        let at = 0, drag = false, mx = 0, my = 0, raf = 0, last = performance.now(), stopped = false;
        const frame = (now) => {
            if (stopped) return;
            const dt = Math.min(0.05, (now - last) / 1000); last = now;
            const rect = svg.getBoundingClientRect();
            if (drag) {
                // move forward along the line while the mouse stays near the next part of it
                const ahead = path.getPointAtLength(Math.min(len, at + 26));
                const dist = Math.hypot(mx - rect.left - ahead.x, my - rect.top - ahead.y);
                if (dist < 34) at = Math.min(len, at + Math.min(len / 1.1 * dt, 26));
            }
            const p = path.getPointAtLength(at);
            container.querySelector('#tbm').setAttribute('transform', `translate(${p.x} ${p.y})`);
            const p0 = path.getPointAtLength(0);
            let d = `M${p0.x} ${p0.y}`;
            for (let s = 8; s <= at; s += 8) { const q = path.getPointAtLength(s); d += ` L${q.x} ${q.y}`; }
            container.querySelector('#tbd').setAttribute('d', d);
            if (at >= len) { at = 0; drag = false; onBreath(); }
            raf = requestAnimationFrame(frame);
        };
        const down = (e) => { mx = e.clientX; my = e.clientY; drag = true; };
        const move = (e) => { mx = e.clientX; my = e.clientY; };
        const up = () => { drag = false; };
        container.querySelector('#tbm').addEventListener('pointerdown', down);
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', up);
        raf = requestAnimationFrame(frame);
        return () => { stopped = true; cancelAnimationFrame(raf); window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); };
    }

    function breathsGame(p, action, done) {
        const need = p.breaths || 3;
        const el = shell('أعطه أكسجين', 'تتبّع الخط بالماوس حتى يثبت كيس التنفس على الفم، واضغط الكيس', 'كل مرة توصل للفم = نفَس');
        const area = el.querySelector('.area');
        area.innerHTML = `<div class="tr-prog"><i id="tbr"></i></div><div class="tr-pv" id="tbrt">الأنفاس 0 من ${need}</div><div id="tbz" style="margin-top:8px"></div>`;
        let n = 0;
        const stop = tracePart(area.querySelector('#tbz'), () => {
            n += 1;
            area.querySelector('#tbr').style.width = `${n / need * 100}%`;
            area.querySelector('#tbrt').textContent = `الأنفاس ${n} من ${need}`;
            if (n >= need) { stop(); done({ ok: true }); }
        });
        return stop;
    }

    // 3) CPR: 30 presses with the rhythm, then 2 rescue breaths
    function cprGame(p, action, done) {
        const el = shell('الإنعاش القلبي (CPR)', `الدورة ${p.cycle || 1} من ${p.of || 3} · 30 ضغطة على الصدر ثم نفَسين`,
            'اضغط <kbd>Space</kbd> أو الماوس لما النقطة تكون داخل الدائرة · 3 أخطاء = أعد الدورة');
        const area = el.querySelector('.area');
        const marks = [0.12, 0.31, 0.5, 0.69, 0.88];
        area.innerHTML = `<div style="height:7vh"></div><div class="tr-track" id="tct">${marks.map((m, i) => `<span class="tg" data-i="${i}" style="left:${m * 100}%"></span>`).join('')}<span class="ball" id="tcb"></span></div>
            <div class="tr-stats"><span>الأخطاء <b id="tcm">0/3</b></span><span>ضغطة <b id="tch">0/30</b></span></div>
            <div style="text-align:center;margin-top:5vh"><svg width="320" height="60"><path d="M0 34 H100 L110 34 L118 10 L126 52 L134 34 H320" fill="none" stroke="rgba(255,95,95,.85)" stroke-width="2.5"/></svg>
            <div style="font-size:12.5px;color:#ff8a8a">لا يوجد نبض — استمر</div></div>`;
        const track = area.querySelector('#tct'), ball = area.querySelector('#tcb');
        const beat = 0.56; // seconds from one circle to the next (~107 a minute)
        const span = (marks[1] - marks[0]);
        let pos = 0.02, hits = 0, misses = 0, raf = 0, last = performance.now(), judged = new Set(), stopped = false;
        const goAt = performance.now() + 1800; // a short "get ready" before the rhythm starts
        let lapKey = 0;
        const flash = (i, cls) => { const tg = track.querySelector(`[data-i="${i}"]`); if (!tg) return; tg.classList.add(cls); setTimeout(() => tg.classList.remove(cls), 220); };
        const miss = () => {
            misses += 1;
            area.querySelector('#tcm').textContent = `${misses}/3`;
            el.classList.remove('tr-flash'); void el.offsetWidth; el.classList.add('tr-flash');
            if (misses >= 3) { finish(false); }
        };
        const finish = (ok) => { if (stopped) return; stopped = true; cancelAnimationFrame(raf); window.removeEventListener('keydown', key); if (!ok) done({ ok: false }); else breaths(); };
        const press = () => {
            if (stopped || performance.now() < goAt) return;
            let best = -1, bd = 1;
            marks.forEach((m, i) => { const d = Math.abs(pos - m); if (d < bd) { bd = d; best = i; } });
            if (bd < 0.04 && !judged.has(lapKey + ':' + best)) {
                judged.add(lapKey + ':' + best);
                hits += 1;
                flash(best, 'hit');
                area.querySelector('#tch').textContent = `${hits}/30`;
                if (hits >= 30) finish(true);
            } else {
                miss();
            }
        };
        const key = (e) => { if (e.code === 'Space') { e.preventDefault(); if (!e.repeat) press(); } };
        const frame = (now) => {
            if (stopped) return;
            const dt = Math.min(0.05, (now - last) / 1000); last = now;
            if (now < goAt) {
                area.querySelector('#tch').textContent = `استعد… ${Math.ceil((goAt - now) / 600)}`;
                raf = requestAnimationFrame(frame);
                return;
            }
            if (area.querySelector('#tch').textContent.indexOf('استعد') === 0) area.querySelector('#tch').textContent = '0/30';
            pos += dt * span / beat;
            marks.forEach((m, i) => {
                if (pos > m + 0.045 && !judged.has(lapKey + ':' + i)) { judged.add(lapKey + ':' + i); flash(i, 'miss'); miss(); }
            });
            if (pos >= 1) { pos = 0.02; lapKey += 1; }
            ball.style.left = `${pos * 100}%`;
            raf = requestAnimationFrame(frame);
        };
        const breaths = () => {
            el.querySelector('.gh h3').textContent = 'أنفاس الإنقاذ';
            el.querySelector('.gh p').textContent = 'تتبّع الخط بالماوس حتى يثبت كيس التنفس على الفم';
            el.querySelector('.gf').innerHTML = 'نفَسين ثم الدورة تكتمل';
            area.innerHTML = `<div class="tr-prog"><i id="tbr"></i></div><div class="tr-pv" id="tbrt">الأنفاس 0 من 2</div><div id="tbz" style="margin-top:8px"></div>`;
            let n = 0;
            stopTrace = tracePart(area.querySelector('#tbz'), () => {
                n += 1;
                area.querySelector('#tbr').style.width = `${n / 2 * 100}%`;
                area.querySelector('#tbrt').textContent = `الأنفاس ${n} من 2`;
                if (n >= 2) { stopTrace(); done({ ok: true }); }
            });
        };
        let stopTrace = null;
        track.addEventListener('pointerdown', press);
        window.addEventListener('keydown', key);
        raf = requestAnimationFrame(frame);
        return () => { stopped = true; cancelAnimationFrame(raf); window.removeEventListener('keydown', key); if (stopTrace) stopTrace(); };
    }

    // 4) the defibrillator: shock when the charge is in the green
    function defibGame(p, action, done) {
        const el = shell('الصدمة الكهربائية', 'اللاصقات على الصدر ← الجهاز يشحن ← ابتعدوا ← صدمة',
            'اضغط <kbd>Space</kbd> أو زر الصدمة لما الشحن يكون في المنطقة الخضراء · 3 محاولات');
        const area = el.querySelector('.area');
        area.innerHTML = `<div style="margin:3vh auto 0;width:420px;border-radius:16px;background:#04070a;border:1px solid rgba(255,255,255,.08);padding:12px 14px">
            <div style="display:flex;justify-content:space-between;font-size:11px;color:#5d6b72"><span style="color:#3ddc97">● جهاز الصدمات</span><span id="tds">يحلّل النبض…</span></div>
            <svg width="390" height="90"><path d="M0 45 q8 -26 16 0 t16 0 q8 -32 16 0 t16 0 q8 -20 16 0 t16 0 q8 -34 16 0 t16 0 q8 -24 16 0 t16 0 q8 -30 16 0 t16 0 q8 -18 16 0 t16 0 q8 -28 16 0 t16 0 q8 -22 16 0 t16 0 q8 -30 16 0 t16 0 q8 -24 16 0 t16 0 q8 -26 16 0 t16 0" fill="none" stroke="#3ddc97" stroke-width="2"/></svg>
            <div style="display:flex;gap:8px;align-items:center;direction:ltr"><div style="flex:1;height:12px;border-radius:6px;background:rgba(255,255,255,.08);position:relative;overflow:hidden">
            <i style="position:absolute;left:62%;width:14%;top:0;bottom:0;background:rgba(61,220,151,.5)"></i><i id="tdc" style="position:absolute;left:0;width:0;top:0;bottom:0;background:linear-gradient(90deg,#f6d34a,#ff9f3a)"></i></div><b style="font-size:13px;color:#f6d34a">200J</b></div></div>
            <div style="display:flex;gap:8px;justify-content:center;margin-top:18px"><button class="tr-chip" id="tdb" style="background:#ff5f5f;color:#2a0505;border:0;height:40px;padding:0 22px">⚡ صدمة!</button></div>
            <div class="tr-pv" id="tdt" style="margin-top:10px">المحاولات 0 من 3</div>`;
        let t0 = performance.now(), raf = 0, tries = 0, ready = false, stopped = false, v = 0;
        const frame = (now) => {
            if (stopped) return;
            const t = (now - t0) / 1000;
            if (t > 1.6 && !ready) { ready = true; area.querySelector('#tds').textContent = 'رجفان — ابتعدوا!'; }
            v = ready ? (Math.sin((t - 1.6) * 3.4 - Math.PI / 2) + 1) / 2 : Math.min(1, t / 1.6) * 0.3;
            area.querySelector('#tdc').style.width = `${v * 100}%`;
            raf = requestAnimationFrame(frame);
        };
        const shock = () => {
            if (stopped || !ready) return;
            tries += 1;
            area.querySelector('#tdt').textContent = `المحاولات ${tries} من 3`;
            if (v >= 0.62 && v <= 0.76) { stopped = true; cancelAnimationFrame(raf); window.removeEventListener('keydown', key); done({ ok: true }); return; }
            el.classList.remove('tr-flash'); void el.offsetWidth; el.classList.add('tr-flash');
            if (tries >= 3) { stopped = true; cancelAnimationFrame(raf); window.removeEventListener('keydown', key); done({ ok: false }); }
        };
        const key = (e) => { if (e.code === 'Space') { e.preventDefault(); if (!e.repeat) shock(); } };
        area.querySelector('#tdb').addEventListener('click', shock);
        window.addEventListener('keydown', key);
        raf = requestAnimationFrame(frame);
        return () => { stopped = true; cancelAnimationFrame(raf); window.removeEventListener('keydown', key); };
    }

    // tourniquet / a bag in the vein / a painkiller: a short progress bar
    function quickGame(p, action, done) {
        const label = {
            tourniquet: ['اربط العاصبة', 'شدّ العاصبة فوق الجرح ولفّ العصا حتى يوقف النزيف'],
            infuse: [p.item === 'blood' ? 'نقل الدم' : 'المحلول الملحي', 'علّق الكيس وأدخل الإبرة في الوريد — بعدها يشتغل لحاله'],
            med: [p.item === 'morphine' ? 'أعطه مورفين' : 'أعطه إيبوبروفين', p.item === 'morphine' ? 'حقنة في العضل — مسكّن قوي' : 'حبّة مع قليل ماء — مسكّن خفيف'],
        }[action] || ['جارٍ…', ''];
        const el = shell(label[0], label[1], '');
        const area = el.querySelector('.area');
        const it = itemOf(p.item);
        area.innerHTML = `<div style="text-align:center;margin-top:5vh"><img src="${IMG(it.item || p.item)}" style="width:120px;height:120px;object-fit:contain" onerror="this.style.visibility='hidden'"></div>
            <div class="tr-prog" style="width:320px;margin-top:3vh"><i id="tqp"></i></div>`;
        const secs = p.seconds || 3;
        const bar = area.querySelector('#tqp');
        bar.style.transition = `width ${secs}s linear`;
        requestAnimationFrame(() => { bar.style.width = '100%'; });
        const tm = setTimeout(() => done({ ok: true }), secs * 1000 + 100);
        return () => clearTimeout(tm);
    }

    // ------------------------------------------------------------------
    // blood pressure (the same cuff game as on the tablet)
    // ------------------------------------------------------------------
    let audio = null;
    function thump() {
        try {
            audio = audio || new (window.AudioContext || window.webkitAudioContext)();
            const o = audio.createOscillator(), g = audio.createGain();
            o.type = 'sine'; o.frequency.value = 62;
            const t = audio.currentTime;
            g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.6, t + 0.012); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.13);
            o.connect(g).connect(audio.destination); o.start(t); o.stop(t + 0.15);
        } catch (_) { /* no sound */ }
    }

    async function startBp() {
        if (S.game || S.busy) return;
        S.sel = null;
        S.game = 'bp-wait'; // no second cuff while the first one is starting
        const res = await post('treatBp', { stage: 'start' });
        if (!S.on) return;
        if (!res || !res.ok || !res.data) { S.game = null; toast(errText(res && res.error), 'error'); render(); return; }
        const truth = res.data;
        S.game = 'bp';
        render();
        const el = shell('قياس ضغط الدم', 'الكُم على ذراع المريض — انفخه ثم اسمع النبض وأنت تفرّغه',
            'اضغط <kbd>Space</kbd> مطوّل للنفخ · <kbd>E</kbd> عند أول نبضة (الانقباضي) و <kbd>E</kbd> لما تختفي النبضات (الانبساطي)');
        el.querySelector('.area').innerHTML = `<div class="tr-bp"><div class="gauge"><div class="bbeat" id="bbt">♥ نبض</div><div class="needle" id="bnd"></div><div class="val" id="bvl">0</div></div>
            <div class="side"><div class="box">الانقباضي<b id="bsy">—</b></div><div class="box">الانبساطي<b id="bdi">—</b></div><div class="msg" id="bms">انفخ الكُم إلى 180 تقريبًا.</div></div></div>`;
        const r = { p: 0, holding: false, max: 0, phase: 'ready', sys: null, dia: null, lastBeat: 0 };
        let raf = 0, last = performance.now(), stopped = false;
        const paint = (beat) => {
            el.querySelector('#bnd').style.transform = `rotate(${-130 + r.p / 300 * 260}deg)`;
            el.querySelector('#bvl').textContent = Math.round(r.p);
            el.querySelector('#bbt').classList.toggle('on', beat);
        };
        const finish = async () => {
            if (stopped) return;
            stopped = true;
            cancelAnimationFrame(raf);
            window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku);
            if (!truth.none && (r.sys == null || r.dia == null)) {
                closeGame(); post('treatBp', { stage: 'cancel' }); toast('ما سجّلت القراءة كاملة — أعد القياس', 'error'); render(); return;
            }
            const fin = await post('treatBp', { stage: 'finish', token: truth.token, sys: r.sys || 0, dia: r.dia || 0 });
            closeGame();
            if (fin && fin.ok) { setView(fin.data); if (truth.none) toast('لا يوجد نبض: لا يمكن قياس الضغط', 'error'); }
            else toast(errText(fin && fin.error), 'error');
            render();
        };
        const frame = (now) => {
            if (stopped) return;
            const dt = Math.min(0.05, (now - last) / 1000); last = now;
            if (r.holding) { r.p = Math.min(300, r.p + 95 * dt); r.max = Math.max(r.max, r.p); r.phase = 'pump'; }
            else if (r.p > 0 && r.phase === 'pump') {
                r.phase = 'deflate';
                if (!truth.none && r.max < truth.sys + 5) { const m = el.querySelector('#bms'); m.textContent = 'تسمع النبض من البداية؟ انفخ أكثر (180 تقريبًا).'; m.className = 'msg warn'; }
            }
            if (r.phase === 'deflate') r.p = Math.max(0, r.p - 6 * dt);
            let beat = false;
            if (r.phase === 'deflate' && !truth.none && r.p <= truth.sys && r.p >= truth.dia) {
                if (now - r.lastBeat >= 60000 / Math.max(40, truth.hr || 80)) { r.lastBeat = now; thump(); }
                beat = now - r.lastBeat < 150;
            }
            paint(beat);
            if (r.phase === 'deflate' && r.p <= 25) { finish(); return; }
            raf = requestAnimationFrame(frame);
        };
        const kd = (e) => {
            if (e.code === 'Space') { e.preventDefault(); if (!e.repeat && r.phase !== 'deflate') r.holding = true; }
            else if (e.code === 'KeyE' && !e.repeat && r.phase === 'deflate') {
                const v = Math.round(r.p / 2) * 2;
                if (r.sys == null) { r.sys = v; el.querySelector('#bsy').textContent = v; const m = el.querySelector('#bms'); m.textContent = 'الآن انتظر حتى تختفي النبضات تمامًا.'; m.className = 'msg'; }
                else if (r.dia == null && v < r.sys) { r.dia = v; el.querySelector('#bdi').textContent = v; finish(); }
            }
        };
        const ku = (e) => { if (e.code === 'Space') r.holding = false; };
        window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
        raf = requestAnimationFrame(frame);
        gameStop = () => { stopped = true; cancelAnimationFrame(raf); window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
        const cancel = () => { closeGame(); post('treatBp', { stage: 'cancel' }); render(); };
        S.cancelGame = cancel;
        el.querySelector('[data-gcancel]').addEventListener('click', cancel);
    }

    // ------------------------------------------------------------------
    // clicks and keys
    // ------------------------------------------------------------------
    root.addEventListener('click', (e) => {
        if (!S.on) return;
        const t = e.target.closest('[data-exit],[data-unsel],[data-probe],[data-use],[data-item],[data-tool],[data-task],[data-complete]');
        if (!t) return;
        if (t.hasAttribute('data-exit')) return exit();
        if (t.hasAttribute('data-unsel')) { S.sel = null; return render(); }
        if (t.dataset.probe) return probe(t.dataset.probe);
        if (t.dataset.use && t.dataset.act) return startAction(t.dataset.act, Number(t.dataset.wid), t.dataset.use);
        if (t.dataset.item) return itemClick(t.dataset.item);
        if (t.dataset.task) return taskClick(t.dataset.task);
        if (t.hasAttribute('data-complete')) {
            return timed('جارٍ إنهاء العلاج…', 1, null, async () => {
                const res = await post('treatComplete', {});
                if (res && res.ok) setTimeout(() => showDone((res.extra && res.extra.paid) || 0), 30);
                return res;
            });
        }
        if (t.dataset.tool) {
            const k = t.dataset.tool;
            if (S.game || S.busy) return;
            if (k === 'bp') return startBp();
            if (k === 'ask') return askPatient();
            if (k === 'cpr') return taskClick('cpr');
            return measure(k);
        }
    });

    window.addEventListener('keydown', (e) => {
        if (!S.on) return;
        if (e.key === 'Escape' || e.key === 'Backspace') {
            e.preventDefault();
            if (S.game) { if (S.cancelGame) S.cancelGame(); return; }
            if (S.pick) { S.pick = null; return render(); }
            if (S.sel) { S.sel = null; return render(); }
            if (!S.busy) exit();
        }
    });

    // the running bag: only its little bar changes every second (no full redraw)
    setInterval(() => {
        if (!S.on || !uiEl) return;
        const p = plan();
        const box = uiEl.querySelector('.tr-inf');
        if (!p.infusion || !box) return;
        const left = Math.max(0, Math.round(p.infusion.left - (Date.now() - (S.infAt || Date.now())) / 1000));
        const pct = Math.round((1 - left / Math.max(1, p.infusion.total)) * 100);
        const bar = box.querySelector('.bar i');
        const t = box.querySelector('b');
        if (bar) bar.style.width = `${pct}%`;
        if (t) t.textContent = `0:${String(left).padStart(2, '0')}`;
    }, 1000);

    // ------------------------------------------------------------------
    // messages from the game
    // ------------------------------------------------------------------
    window.addEventListener('message', (e) => {
        let msg = e.data;
        if (typeof msg === 'string') { try { msg = JSON.parse(msg); } catch (_) { return; } }
        if (!msg || typeof msg.action !== 'string' || msg.action.indexOf('treat') !== 0) return;
        if (msg.action === 'treatOpen') {
            closeGame();
            S.on = true; S.sel = null; S.pick = null; S.busy = null; S.done = null; S.seen = {}; S.pts = {};
            setView(msg.data);
            render();
        } else if (msg.action === 'treatView') {
            if (!S.on) return;
            setView(msg.data);
            if (!S.game) render(); else placePoints();
        } else if (msg.action === 'treatPoints') {
            if (!S.on) return;
            S.pts = msg.pts || {};
            placePoints();
            if (S.sel && !S.game) {
                const pop = uiEl && uiEl.querySelector('.tr-pop');
                const pt = S.pts[S.sel];
                if (pop && pt) {
                    const W = window.innerWidth, H = window.innerHeight;
                    let x = pt.x * W + (S.sel === 'back' ? 34 : 0) + 26;
                    if (x + 330 > W) x = pt.x * W - 26 - 320;
                    pop.style.left = `${x}px`;
                    pop.style.top = `${clamp(pt.y * H - 40, 70, H - 420)}px`;
                }
            }
        } else if (msg.action === 'treatClose') {
            closeGame();
            S.on = false; S.done = null;
            render();
        } else if (msg.action === 'treatToast') {
            toast(msg.text || '', msg.type);
        }
    });

    // ------------------------------------------------------------------
    // preview outside the game (open html/index.html?treat=1&game=bullet in a browser)
    // ------------------------------------------------------------------
    function previewPost(name, body) {
        if (name === 'treatBp' && body && body.stage === 'start') return { ok: true, data: { token: 1, sys: 98, dia: 62, hr: 116 } };
        if (name === 'treatStart') return { ok: true, data: { token: 1, game: params.get('game') || 'bullet', params: { power: 2, turns: 3, item: 'pressure', part: 'الصدر', cycle: 1, of: 3, breaths: 3, seconds: 4 } } };
        return { ok: true, data: S.data };
    }
    if (!inGame && params.get('treat') === '1') {
        const tab = document.getElementById('root');
        if (tab) tab.style.display = 'none';
        document.body.style.background = `#20242b url(${params.get('bg') || 'treat_bg.jpg'}) center/cover`;
        const items = [['forceps', 'ملقط جراحي', 1, true], ['bvm', 'كيس التنفس (أمبو)', 1, true], ['defib', 'جهاز الصدمات', 1, true],
            ['gauze', 'شاش معقّم', 20], ['pressure', 'ضماد ضاغط', 18], ['quickclot', 'كويك كلوت', 5], ['tourniquet', 'عاصبة', 5],
            ['blood', 'كيس دم', 2], ['saline', 'محلول ملحي', 3], ['ibuprofen', 'إيبوبروفين', 10], ['morphine', 'مورفين', 0]]
            .map(([key, label, count, tool]) => ({ key, item: { pressure: 'pressure_bandage', blood: 'blood_bag', defib: 'defibrillator' }[key] || key, label, count, tool }));
        const W = (id, text, tags, level, actions) => ({ id, text, tags, level, actions });
        const zones = {};
        ZONES.forEach((z) => { zones[z] = { checked: true, level: 0, todo: 0, wounds: [] }; });
        zones.back.checked = false; zones.l_arm.checked = false;
        zones.chest = { checked: true, level: 3, todo: 2, wounds: [W(1, 'جرح ناري بدون مخرج — الرصاصة ما زالت في الداخل', [['نزيف متوسط', 'r'], ['إخراج الرصاصة', 'g']], 3,
            [{ kind: 'extract', items: ['forceps'], label: 'أخرج الرصاصة', game: 'bullet' }, { kind: 'dress', items: ['pressure', 'quickclot'], label: 'أوقف النزيف بضماد ضاغط', blocked: 'extract_first' }])] };
        zones.r_arm = { checked: true, level: 2, todo: 1, wounds: [W(2, 'جرح قطعي، طوله 6 سم تقريبًا', [['نزيف خفيف', 'r'], ['تنظيف وخياطة', 'g']], 2,
            [{ kind: 'dress', items: ['gauze', 'pressure', 'quickclot'], label: 'لفّ الجرح بالشاش' }, { kind: 'tourniquet', items: ['tourniquet'], label: 'عاصبة (مؤقتة)', optional: true }])] };
        zones.r_leg = { checked: true, level: 3, todo: 0, wounds: [W(3, 'تورّم وتشوّه واضح — اشتباه كسر', [['يحتاج أشعة', 'o'], ['جبيرة', 'g']], 3, [])] };
        S.data = {
            target: -1001, patient: { name: 'خالد الحربي', fake: true },
            mini: { hr: 116, spo2: 89, bp: '98/62' },
            items,
            times: { zone: 3, pulse: 6, spo2: 4, ask: 2 },
            plan: {
                death: 2, hidden: 1,
                diag: { zones: { done: 7, of: 9 }, vitals: { done: 3, of: 3 } },
                zones,
                tasks: [
                    { id: 'extract:1', kind: 'extract', wid: 1, zone: 'chest', title: 'أخرج الرصاصة من الصدر', sub: 'جرح ناري بدون مخرج — الرصاصة ما زالت في الداخل', items: ['forceps'] },
                    { id: 'dress:1', kind: 'dress', wid: 1, zone: 'chest', title: 'أوقف النزيف بضماد ضاغط — الصدر', sub: 'بعد إخراج الرصاصة', items: ['pressure', 'quickclot'], blocked: 'extract_first' },
                    { id: 'dress:2', kind: 'dress', wid: 2, zone: 'r_arm', title: 'لفّ الجرح بالشاش — الذراع اليمنى', sub: 'جرح قطعي 6 سم — نزيف خفيف', items: ['gauze', 'pressure', 'quickclot'] },
                    { id: 'infuse', kind: 'infuse', title: 'ابدأ نقل الدم', sub: 'فقد دمًا كثيرًا — الضغط منخفض', items: ['blood'] },
                    { id: 'med', kind: 'med', optional: true, title: 'أعطه مسكّنًا مناسبًا', sub: 'الألم 8 من 10', items: ['morphine'] },
                ],
                later: [{ title: 'كسر في الرجل اليمنى', sub: 'يحتاج أشعة وجبس في المستشفى' }],
            },
        };
        S.seen = {};
        S.on = true;
        S.pts = { head: { x: 0.505, y: 0.31, on: true }, neck: { x: 0.528, y: 0.367, on: true }, chest: { x: 0.566, y: 0.467, on: true }, abdomen: { x: 0.581, y: 0.622, on: true },
            back: { x: 0.6, y: 0.62, on: true }, r_arm: { x: 0.4, y: 0.402, on: true }, l_arm: { x: 0.634, y: 0.522, on: true }, r_leg: { x: 0.387, y: 0.711, on: true }, l_leg: { x: 0.3, y: 0.82, on: true } };
        if (params.get('sel')) S.sel = params.get('sel');
        if (params.get('pick')) S.pick = params.get('pick');
        render();
        if (params.get('game')) {
            const g = params.get('game');
            if (g === 'bp') startBp(); else startAction({ bullet: 'extract', wrap: 'dress', cpr: 'cpr', breaths: 'oxygen', defib: 'defib', quick: 'infuse' }[g] || 'extract', 1, 'pressure');
        }
        if (params.get('done') === '1') showDone(300);
        window.__TS = S;
    }
})();
