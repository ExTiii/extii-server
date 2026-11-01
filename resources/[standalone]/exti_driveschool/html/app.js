// EX_Tii Driving School — the screen at the instructor (pick a licence, pay, the theory test), the
// card during the practical test, and the pass / fail card
(() => {
    const $ = (id) => document.getElementById(id);
    const inGame = typeof GetParentResourceName === 'function';
    const RES = inGame ? GetParentResourceName() : 'exti_driveschool';
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.max(0, Math.floor(n || 0)).toLocaleString('en-US');
    const iso = (t) => `⁦${t}⁩`;
    const clock = (s) => { s = Math.max(0, Math.floor(s)); return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };
    const post = (name, data) => {
        if (!inGame) return Promise.resolve(fake(name, data));
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}) })
            .then((r) => r.json()).catch(() => ({ ok: false, text: 'حدث خطأ' }));
    };
    const I = {
        car: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11"/><path d="M3 11h18v6h-2.5a2 2 0 0 1-4 0h-5a2 2 0 0 1-4 0H3z"/></svg>',
        truck: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h11v10H3z"/><path d="M14 9h4l3 3v4h-7z"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>',
        boat: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 15l2 3h14l2-3z"/><path d="M5 15V9h14v6"/><path d="M12 9V4l5 5"/><path d="M2 20c2 1.5 4 1.5 6 0s4-1.5 6 0 4 1.5 6 0"/></svg>',
        heli: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5h16"/><path d="M11 5v3"/><path d="M6 11a5 3 0 0 1 10 0v3H6z"/><path d="M16 12h5l-2 3h-3"/><path d="M5 19h12"/><path d="M8 14v5M14 14v5"/></svg>',
    };
    const X = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>';
    const CHECK = '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg>';

    let root, data = null, open = false, busy = false, picked = null;
    let theory = null; // { licence, questions, i, answers, left, timer }

    function shell(inner, sub) {
        root.innerHTML = `<div class="ds-shade"></div><div class="ds-panel">
            <header class="ds-top"><div class="ds-badge">${I[(picked && picked.key) || 'car']}</div><div class="ds-title"><h1>${esc(data && data.school || 'مدرسة تعليم القيادة')}</h1><p>${esc(sub || (data && data.name ? `أهلًا ${data.name}` : ''))}</p></div><button class="ds-x" data-close>${X}</button></header>
            <div class="ds-body">${inner}</div></div>`;
    }

    // the licence this school offers, and where you stand with each
    function stateOf(l) {
        if (l.has) return { cls: 'ok', text: 'عندك هذه الرخصة ✓' };
        if (l.suspended) return { cls: 'bad', text: 'مسحوبة من الشرطة · راجع المركز لإرجاعها' };
        if (l.locked) return { cls: 'warn', text: `تحتاج رخصة ${l.requires} أولًا` };
        if (l.wait > 0) return { cls: 'warn', text: `رسبت قبل قليل · المحاولة التالية بعد ${iso(clock(l.wait))}` };
        return null;
    }
    const canTake = (l) => !l.has && !l.suspended && !l.locked && l.wait <= 0 && !data.busy;

    function list() {
        picked = null;
        shell(`<div class="ds-lic">${data.licences.map((l) => {
            const st = stateOf(l);
            return `<button class="ds-licard ${canTake(l) ? '' : 'off'}" data-pick="${l.key}">
                <i>${I[l.key] || I.car}</i>
                <div><b>${esc(l.label)}</b><small>${l.theory.count} أسئلة · ${l.test.landing ? 'طيران وهبوط' : l.test.limit ? `قيادة · الحد ${l.test.limit} كم/س` : 'مسار في الماء'} · ${l.test.minutes} دقيقة</small>
                ${st ? `<em class="ds-chip ${st.cls}">${st.text}</em>` : ''}</div>
                <span class="ds-pr">${money(l.price)}</span></button>`;
        }).join('')}</div>
        <p class="ds-note">${data.busy ? 'اختبارك جارٍ بالفعل.' : 'اختر الرخصة لترى تفاصيلها وتدفع رسومها.'}</p>`);
    }

    function offer(l) {
        picked = l;
        const st = stateOf(l);
        const can = canTake(l);
        const practical = l.test.landing
            ? `مروحية المدرسة: مرّ بنقاط في الجوّ ثم اهبط وتوقّف على المهبط، بلا اصطدام، في ${l.test.minutes} دقائق.`
            : l.test.limit
                ? `مركبة المدرسة، مسار من نقاط على الخريطة، الحد ${l.test.limit} كم/س (${l.test.faults} مخالفات مسموحة)، بلا حوادث، في ${l.test.minutes} دقيقة.`
                : `قارب المدرسة، مسار من نقاط على الماء، بلا اصطدام، في ${l.test.minutes} دقائق.`;
        shell(`${st ? `<div class="ds-state ${st.cls}">${st.text}</div>` : ''}
            <div class="ds-steps">
                <div class="ds-step"><i>1</i><div><b>الاختبار النظري</b><small>${l.theory.count} أسئلة، تحتاج ${l.theory.pass} إجابات صحيحة في ${Math.round(l.theory.seconds / 60)} دقائق.</small></div></div>
                <div class="ds-step"><i>2</i><div><b>الاختبار العملي</b><small>${practical}</small></div></div>
            </div>
            <div class="ds-price"><div><small>الرسوم (الاختبارين معًا)</small><b>${money(l.price)}</b></div>
                <div class="ds-pay"><button class="kit-btn primary" data-start="cash" ${can && data.cash >= l.price ? '' : 'disabled'}>ادفع نقدًا</button><button class="kit-btn" data-start="bank" ${can && data.bank >= l.price ? '' : 'disabled'}>ادفع من الحساب</button></div></div>
            <p class="ds-note">تنجح = الرخصة في سجلك والبطاقة في حقيبتك. ترسب = تدفع مرة أخرى بعد انتظار قصير. أثناء الاختبار: /giveup للانسحاب.</p>
            <div class="ds-nav"><button class="kit-btn" data-back>رجوع</button></div>`, l.label);
    }

    function question() {
        const t = theory;
        const q = t.questions[t.i];
        shell(`<div class="ds-qtop"><b>السؤال ${t.i + 1} من ${t.questions.length}</b><div class="ds-dots">${t.questions.map((_, k) => `<i class="${k === t.i ? 'now' : t.answers[k] ? 'done' : ''}"></i>`).join('')}</div><span class="ds-timer ${t.left < 30 ? 'low' : ''}" id="dsTimer">${clock(t.left)}</span></div>
            <div class="ds-q">${esc(q.text)}</div>
            <div class="ds-answers">${(Array.isArray(q.answers) ? q.answers : Object.values(q.answers)).map((a, k) => `<button class="ds-a ${t.answers[t.i] === k + 1 ? 'on' : ''}" data-answer="${k + 1}"><i>${['أ', 'ب', 'ج', 'د'][k]}</i>${esc(a)}</button>`).join('')}</div>
            <div class="ds-nav"><button class="kit-btn" data-prev ${t.i === 0 ? 'disabled' : ''}>السابق</button>
                ${t.i < t.questions.length - 1 ? '<button class="kit-btn primary" data-next>التالي</button>' : `<button class="kit-btn primary" data-finish ${t.answers.filter(Boolean).length === t.questions.length ? '' : 'disabled'}>تسليم الإجابات</button>`}</div>`, picked ? `النظري · ${picked.label}` : 'الاختبار النظري');
    }

    function score(r) {
        const ok = r.passed;
        const l = picked || { test: {}, theory: {} };
        const next = l.test.landing ? 'اذهب إلى المروحية: النقاط في الجوّ على الخريطة، وفي النهاية اهبط على المهبط.'
            : l.test.limit ? `اذهب إلى مركبة المدرسة: النقاط على الخريطة، الحد ${l.test.limit} كم/س، ولا تصدم.`
                : 'اذهب إلى القارب: اتبع النقاط على الماء ولا تصطدم.';
        shell(`<div class="ds-score ${ok ? '' : 'bad'}"><div class="ring">${r.right}/${r.total}</div><b>${ok ? 'نجحت في النظري!' : 'لم تنجح في النظري'}</b>
            <span>${ok ? next : `تحتاج ${r.need || l.theory.pass} إجابات صحيحة. راجع القواعد وحاول بعد قليل.`}</span>
            ${ok ? '' : '<button class="kit-btn" data-close>إغلاق</button>'}</div>`, picked ? picked.label : '');
    }

    async function start(account) {
        if (busy || !picked) return;
        busy = true;
        const res = await post('start', { licence: picked.key, account });
        busy = false;
        if (!res || !res.ok) { toast(res && res.text); return; }
        theory = { licence: res.licence, questions: Array.isArray(res.questions) ? res.questions : Object.values(res.questions), i: 0, answers: [], left: res.seconds || 300 };
        question();
        clearInterval(theory.timer);
        theory.timer = setInterval(() => {
            if (!theory) return;
            theory.left -= 1;
            const el = $('dsTimer');
            if (el) { el.textContent = clock(theory.left); el.classList.toggle('low', theory.left < 30); }
            if (theory.left <= 0) finish();
        }, 1000);
    }

    async function finish() {
        if (!theory || busy) return;
        busy = true;
        clearInterval(theory.timer);
        const res = await post('theory', { answers: theory.answers });
        busy = false;
        theory = null;
        if (!res || !res.ok) { toast(res && res.text); close(false); return; }
        score(res);
    }

    function toast(text) {
        const p = root.querySelector('.ds-body');
        if (p) { const t = document.createElement('div'); t.className = 'ds-state bad'; t.textContent = text || 'حدث خطأ'; p.prepend(t); setTimeout(() => t.remove(), 2500); }
    }

    function onClick(e) {
        if (e.target.closest('[data-close]')) return close(true);
        const pk = e.target.closest('[data-pick]');
        if (pk && data) { const l = data.licences.find((x) => x.key === pk.dataset.pick); if (l) offer(l); return; }
        if (e.target.closest('[data-back]') && !theory) return list();
        const s = e.target.closest('[data-start]');
        if (s && !s.disabled) return start(s.dataset.start);
        const a = e.target.closest('[data-answer]');
        if (a && theory) { theory.answers[theory.i] = Number(a.dataset.answer); question(); return; }
        if (e.target.closest('[data-prev]') && theory) { theory.i = Math.max(0, theory.i - 1); question(); return; }
        if (e.target.closest('[data-next]') && theory) { theory.i = Math.min(theory.questions.length - 1, theory.i + 1); question(); return; }
        if (e.target.closest('[data-finish]') && theory) return finish();
    }

    function show(d) {
        data = d; open = true; theory = null; busy = false;
        data.licences = Array.isArray(d.licences) ? d.licences : Object.values(d.licences || {});
        root.classList.remove('hidden');
        if (data.licences.length === 1) offer(data.licences[0]); else list();
    }
    function close(tellGame) {
        if (!open) return;
        open = false;
        if (theory) clearInterval(theory.timer);
        theory = null;
        root.classList.add('hidden');
        root.innerHTML = '';
        if (tellGame) post('close');
    }

    // ---------- the card during the practical test ----------
    const hud = () => $('hud');
    let drive = null;
    function driveShow(d) {
        drive = d;
        hud().innerHTML = `<div class="hd-card">
            <div class="hd-box speed" id="hdSpeed"><small>السرعة</small><b>0<em>كم/س</em></b></div>
            ${d.limit ? `<div class="hd-sign">${d.limit}</div>` : `<div class="hd-box"><small>الارتفاع</small><b id="hdAlt">0<em>م</em></b></div>`}
            <div class="hd-box"><small>النقطة</small><b id="hdPoint">1 / ${d.total}</b></div>
            <div class="hd-box"><small>الوقت</small><b id="hdTime">--:--</b></div>
            <div class="hd-box"><small>الضرر</small><b id="hdDamage">0</b></div>
            ${d.limit ? `<div class="hd-box hd-faults"><small>مخالفات السرعة</small><b id="hdFaults">${'<i></i>'.repeat(d.faults || 0)}</b></div>` : ''}
        </div><div class="hd-hint" id="hdHint">${d.limit ? `اتبع النقطة الصفراء على الخريطة · الحد ${d.limit} كم/س · لا تصدم` : 'اتبع النقاط الصفراء · لا تصطدم'}</div>`;
        hud().classList.remove('hidden');
    }
    function driveHud(h) {
        if (!drive) return;
        const sp = $('hdSpeed');
        if (sp) { sp.querySelector('b').innerHTML = `${h.kmh}<em>كم/س</em>`; sp.classList.toggle('over', !!h.over); }
        const al = $('hdAlt'); if (al) al.innerHTML = `${h.alt}<em>م</em>`;
        const pt = $('hdPoint'); if (pt) pt.textContent = `${h.index} / ${h.total}`;
        const tm = $('hdTime'); if (tm) tm.textContent = clock(h.left);
        const dm = $('hdDamage'); if (dm) { dm.textContent = `${h.damage} / ${h.maxDamage}`; dm.style.color = h.damage > h.maxDamage * 0.6 ? 'var(--bad)' : ''; }
        const f = $('hdFaults'); if (f) f.innerHTML = Array.from({ length: drive.faults || 0 }, (_, k) => `<i class="${k < h.faults ? 'on' : ''}"></i>`).join('');
        const hint = $('hdHint');
        if (hint) {
            hint.textContent = h.hint === 'landing' ? `النقطة الأخيرة: اهبط على المهبط وتوقّف تمامًا · على بعد ${h.dist} م`
                : h.over ? `⚠ أبطئ! تجاوزت الحد ${drive.limit} كم/س` : drive.limit ? `النقطة التالية على بعد ${h.dist} م · الحد ${drive.limit} كم/س` : `النقطة التالية على بعد ${h.dist} م`;
            hint.classList.toggle('warn', !!h.over);
        }
    }
    function driveHide() { drive = null; hud().classList.add('hidden'); hud().innerHTML = ''; }

    function result(r) {
        const el = $('result');
        const why = { speed: 'تجاوزت السرعة كثيرًا', damage: 'صدمت المركبة', left: 'تركت المركبة', time: 'انتهى الوقت', cancel: 'انسحبت من الاختبار' }[r.why] || '';
        el.innerHTML = `<div class="rs-card ${r.passed ? '' : 'bad'}"><div class="rs-check">${r.passed ? CHECK : X}</div><b>${r.passed ? `مبروك! حصلت على ${esc(r.label || 'الرخصة')}` : 'لم تنجح هذه المرة'}</b><span>${r.passed ? 'الرخصة في سجلك والبطاقة في حقيبتك' : why + ' · حاول مرة أخرى بعد قليل'}</span></div>`;
        el.classList.remove('hidden');
        setTimeout(() => { el.classList.add('hidden'); el.innerHTML = ''; }, 4500);
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'open') show(m.data || {});
        else if (m.action === 'close') close(false);
        else if (m.action === 'drive') { if (m.open) driveShow(m.data || {}); else driveHide(); }
        else if (m.action === 'hud') driveHud(m.data || {});
        else if (m.action === 'result') result(m);
    });
    document.addEventListener('keydown', (e) => { if (open && e.key === 'Escape') close(true); });

    // ---------- the browser preview ----------
    const Q = [
        { id: 1, text: 'عند الاقتراب من إشارة مرور صفراء ثابتة، ما التصرّف الصحيح؟', answers: ['أزيد السرعة لأعبر قبل أن تصبح حمراء', 'أستعدّ للتوقّف إن كان التوقّف آمنًا', 'أتوقّف فجأة مهما كانت المسافة', 'أتجاهلها لأنها ليست حمراء'] },
        { id: 2, text: 'ما الحدّ الأقصى للسرعة داخل مدينة لوس سانتوس؟', answers: ['50 كم/س', '70 كم/س', '90 كم/س', '120 كم/س'] },
        { id: 3, text: 'تسمع صفّارة سيارة إسعاف خلفك وترى أضواءها، ماذا تفعل؟', answers: ['أزيد السرعة لأبتعد عنها', 'أتوقّف في منتصف الطريق', 'أنحرف إلى اليمين وأبطئ أو أتوقّف لأفسح لها', 'أكمل سيري بشكل طبيعي'] },
    ];
    function fake(name, d) {
        if (name === 'start') return { ok: true, questions: Q, seconds: 300, licence: d.licence };
        if (name === 'theory') return { ok: true, passed: true, right: 11, total: 12, need: 10 };
        return { ok: true };
    }
    document.addEventListener('DOMContentLoaded', () => {
        root = $('app');
        root.addEventListener('click', onClick);
        if (!inGame) {
            document.body.style.background = 'radial-gradient(circle at 30% 20%, #3b4252, #12151b)';
            const p = new URLSearchParams(location.search);
            if (p.get('view') === 'drive') { driveShow({ limit: 70, faults: 3, total: 12 }); driveHud({ kmh: 76, over: true, faults: 1, index: 4, total: 12, dist: 230, damage: 40, maxDamage: 180, left: 512, hint: 'road' }); return; }
            if (p.get('view') === 'heli') { driveShow({ limit: null, faults: 0, total: 6, landing: true }); driveHud({ kmh: 140, over: false, faults: 0, index: 6, total: 6, dist: 80, damage: 10, maxDamage: 150, left: 300, alt: 120, hint: 'landing' }); return; }
            if (p.get('view') === 'result') { result({ passed: p.get('fail') ? false : true, why: 'damage', label: 'رخصة قيادة السيارات' }); return; }
            const L = [
                { key: 'car', label: 'رخصة قيادة السيارات', short: 'السيارات', price: 250, order: 1, theory: { count: 12, pass: 10, seconds: 300 }, test: { limit: 70, faults: 3, minutes: 12 }, has: false, suspended: false, wait: 0, locked: false },
                { key: 'truck', label: 'رخصة قيادة الشاحنات', short: 'الشاحنات', price: 500, order: 2, requires: 'السيارات', theory: { count: 10, pass: 8, seconds: 300 }, test: { limit: 60, faults: 3, minutes: 15 }, has: false, suspended: false, wait: 0, locked: true },
            ];
            show({ school: 'مدرسة تعليم القيادة', name: 'محمد الهاشمي', cash: 500, bank: 5000, busy: false, licences: p.get('view') === 'one' ? [{ key: 'heli', label: 'رخصة الطيران (مروحية)', short: 'الطيران', price: 2000, order: 4, theory: { count: 10, pass: 8, seconds: 300 }, test: { limit: null, faults: 0, minutes: 10, landing: true }, has: false, suspended: false, wait: 0, locked: false }] : L });
            if (p.get('view') === 'theory') { offer(L[0]); start('cash'); }
            if (p.get('view') === 'offer') offer(L[0]);
        }
    });
})();
