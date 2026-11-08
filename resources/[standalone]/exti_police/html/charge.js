// =====================================================================
// The charge sheet: the officer ticks the offences of the person next to him, writes a note,
// and issues the fine (a bill in the person's bank). Jail comes with the prison.
// =====================================================================
const Charge = (() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => {
        if (!RES) return Promise.resolve(Charge.fake ? Charge.fake(name, data) : { ok: true, r: { fine: 0 } });
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
            .then((r) => r.json()).catch(() => ({ ok: false, e: 'failed' }));
    };
    const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.max(0, Math.floor(n || 0)).toLocaleString('en-US');
    const iso = (t) => `⁦${t}⁩`;
    const minutes = (n) => (n > 0 ? `${n} دقيقة` : '—');

    const SHIELD = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l8 4v5c0 5-3.5 8.5-8 9-4.5-.5-8-4-8-9V7z"/><path d="M9.5 12l1.8 1.8L15 10"/></svg>';
    const CHECK = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg>';
    const X = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>';

    let root, open = false, data = null, picked = [], cat = 'all', search = '', note = '', err = '', busy = false;

    const offences = () => arr(data && data.offences);
    const byId = (id) => offences().find((o) => o.id === id);
    const cats = () => { const out = []; offences().forEach((o) => { if (!out.includes(o.category)) out.push(o.category); }); return out; };
    const totals = () => picked.reduce((t, id) => { const o = byId(id); if (o) { t.fine += o.fine || 0; t.jail += o.jail || 0; } return t; }, { fine: 0, jail: 0 });
    const stamp = () => { const d = new Date(); return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };

    function build() {
        root = document.getElementById('charge');
        root.addEventListener('click', onClick);
        root.addEventListener('input', (e) => {
            if (e.target.classList.contains('ch-q')) { search = e.target.value; renderRows(); }
            if (e.target.classList.contains('ch-note')) { note = e.target.value; }
        });
    }

    function shell() {
        const t = data.target || {};
        root.innerHTML = `<div class="ch-shade"></div>
            <div class="ch-panel">
                <header class="ch-top">
                    <div class="ch-badge">${SHIELD}</div>
                    <div class="ch-title">
                        <h1>محضر مخالفة</h1>
                        <p>المواطن: <b>${esc(t.name || '')}</b> · رقم ${esc(t.id || '')}${t.previous ? ` · <b>${t.previous}</b> محاضر سابقة` : ' · لا سوابق'}</p>
                    </div>
                    <div class="ch-meta">
                        <div class="ch-chip"><small>الضابط</small><b>${esc(data.officer || '')}</b></div>
                        <div class="ch-chip"><small>التاريخ</small><b dir="ltr">${stamp()}</b></div>
                    </div>
                    <button class="ch-x" data-close>${X}</button>
                </header>
                <div class="ch-body">
                    <section class="ch-list">
                        <div class="ch-tools">
                            <div class="ch-search"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg><input class="ch-q" placeholder="ابحث عن مخالفة…" value="${esc(search)}"></div>
                            <div class="ch-cats" id="chCats"></div>
                        </div>
                        <div class="ch-rows" id="chRows"></div>
                    </section>
                    <aside class="ch-side">
                        <h3>المحضر</h3>
                        <div class="ch-picked" id="chPicked"></div>
                        <div class="ch-totals" id="chTotals"></div>
                        <textarea class="ch-note" maxlength="${data.noteLength || 160}" placeholder="ملاحظة (اختياري): المكان، المركبة، ما حدث…">${esc(note)}</textarea>
                        <div class="ch-err" id="chErr"></div>
                        <div class="ch-actions ${data.atPrison ? 'prison' : ''}" id="chActions"></div>
                        <div class="ch-foot" id="chFoot"></div>
                    </aside>
                </div>
                <div class="ch-done" id="chDone"><div class="ch-done-card"><div class="ch-done-check"><svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg></div><b id="chDoneTitle">تم تحرير المخالفة</b><span id="chDoneText"></span></div></div>
            </div>`;
        renderCats();
        renderRows();
        renderSide();
    }

    function renderCats() {
        const el = root.querySelector('#chCats');
        if (!el) return;
        el.innerHTML = [['all', 'الكل'], ...cats().map((c) => [c, c])]
            .map(([id, label]) => `<button class="ch-cat ${cat === id ? 'on' : ''}" data-cat="${esc(id)}">${esc(label)}</button>`).join('');
    }

    function renderRows() {
        const el = root.querySelector('#chRows');
        if (!el) return;
        const q = search.trim().toLowerCase();
        const list = offences().filter((o) => (cat === 'all' || o.category === cat) && (!q || String(o.label).toLowerCase().includes(q)));
        if (!list.length) { el.innerHTML = '<div class="ch-empty">لا توجد مخالفة بهذا الاسم</div>'; return; }
        let last = null, html = '';
        list.forEach((o) => {
            if (cat === 'all' && o.category !== last) { html += `<div class="ch-group">${esc(o.category)}</div>`; last = o.category; }
            const on = picked.includes(o.id);
            // away from the prison gate only offences without jail time can be written
            const locked = !data.atPrison && o.jail > 0;
            html += `<div class="ch-row ${on ? 'on' : ''} ${locked ? 'locked' : ''}" ${locked ? 'title="عند بوابة السجن فقط"' : `data-pick="${o.id}"`}>
                <span class="ch-box">${CHECK}</span>
                <span class="ch-label">${esc(o.label)}</span>
                <span class="ch-fine">${money(o.fine)}</span>
                <span class="ch-jail ${o.jail > 0 ? '' : 'none'}">${o.jail > 0 ? `سجن ${o.jail} د${locked ? ' · عند البوابة' : ''}` : 'بلا سجن'}</span>
            </div>`;
        });
        el.innerHTML = html;
    }

    function renderSide() {
        const pickedEl = root.querySelector('#chPicked');
        const totalsEl = root.querySelector('#chTotals');
        if (!pickedEl || !totalsEl) return;
        const t = totals();
        pickedEl.innerHTML = picked.length
            ? picked.map((id) => { const o = byId(id); return o ? `<div class="ch-pick"><span>${esc(o.label)}</span><b>${money(o.fine)}</b><i data-unpick="${o.id}">${X}</i></div>` : ''; }).join('')
            : '<div class="ch-none">اختر المخالفات من القائمة</div>';
        totalsEl.innerHTML = `<div class="ch-total fine"><small>الغرامة</small><b>${money(t.fine)}</b></div>
            <div class="ch-total jail"><small>السجن${data.atPrison ? '' : ' <em>· عند بوابة السجن</em>'}</small><b>${minutes(t.jail)}</b></div>`;
        const actions = root.querySelector('#chActions');
        const foot = root.querySelector('#chFoot');
        const canFine = !busy && picked.length > 0 && t.fine >= 1 && data.bank !== false && t.jail < 1;   // (an offence with jail time is never "fine only")
        const canJail = !busy && picked.length > 0 && t.jail >= 1 && data.atPrison && data.target && data.target.cuffed;
        if (actions) {
            if (data.atPrison) {
                actions.innerHTML = `<button class="ch-btn primary" data-issue="jail" ${canJail && (t.fine < 1 || data.bank !== false) ? '' : 'disabled'}>سجن ${t.jail > 0 ? t.jail + ' د' : ''}${t.fine > 0 ? ' + غرامة' : ''}</button>
                    <button class="ch-btn" data-issue="jailonly" ${canJail && t.fine > 0 ? '' : 'disabled'}>سجن فقط</button>
                    <button class="ch-btn" data-issue="fine" ${canFine ? '' : 'disabled'}>غرامة فقط</button>
                    <button class="ch-btn" data-close>إلغاء</button>`;
            } else {
                actions.innerHTML = `<button class="ch-btn primary" data-issue="fine" ${canFine ? '' : 'disabled'}>تحرير الغرامة</button>
                    <button class="ch-btn" data-close>إلغاء</button>`;
            }
        }
        if (foot) {
            if (data.bank === false) foot.textContent = 'البنك لا يعمل الآن: لا يمكن تحرير غرامة';
            else if (data.atPrison && !(data.target && data.target.cuffed)) foot.textContent = 'للسجن: قيّده أولًا (Z → الشرطة → تقييد)';
            else if (data.atPrison) foot.textContent = '"سجن فقط" إذا حرّرت الغرامة في الشارع من قبل. الغرامة تصل إلى حساب المواطن في البنك';
            else foot.textContent = 'هنا تُحرَّر الغرامات التي بلا سجن فقط. المخالفات التي عليها سجن: قيّده وخذه إلى بوابة بولينغبروك';
        }
        const errEl = root.querySelector('#chErr');
        if (errEl) errEl.textContent = err;
    }

    function toggle(id) {
        const i = picked.indexOf(id);
        if (i >= 0) picked.splice(i, 1);
        else {
            if (picked.length >= (data.maxPicks || 12)) { err = `أقصى عدد في المحضر الواحد ${data.maxPicks || 12}`; renderSide(); return; }
            picked.push(id);
        }
        err = '';
        renderRows();
        renderSide();
    }

    async function issue(mode) {
        if (busy || !picked.length) return;
        busy = true; err = '';
        renderSide();
        const res = await post('chargeIssue', { ids: picked.slice(), note: note.trim(), mode });
        busy = false;
        if (!res || !res.ok) { err = (res && res.text) || 'حدث خطأ، حاول مرة أخرى'; renderSide(); return; }
        const r = res.r || {};
        const n = `${picked.length} ${picked.length === 1 ? 'مخالفة' : 'مخالفات'}`;
        root.querySelector('#chDoneTitle').textContent = r.jailed ? 'تم السجن' : 'تم تحرير المخالفة';
        root.querySelector('#chDoneText').textContent = r.jailed
            ? `${r.jail} دقيقة في بولينغبروك${r.fine > 0 ? ` · غرامة ${iso(money(r.fine))}` : ''} · ${n}`
            : `${iso(money(r.fine || totals().fine))} · ${n} · وصلت إلى بنك ${data.target ? data.target.name : ''}`;
        root.querySelector('#chDone').classList.add('show');
        setTimeout(() => close(true), 1600);
    }

    function onClick(e) {
        const closeBtn = e.target.closest('[data-close]');
        if (closeBtn) return close(true);
        const c = e.target.closest('[data-cat]');
        if (c) { cat = c.dataset.cat; renderCats(); renderRows(); return; }
        const un = e.target.closest('[data-unpick]');
        if (un) return toggle(Number(un.dataset.unpick));
        const row = e.target.closest('[data-pick]');
        if (row) return toggle(Number(row.dataset.pick));
        const btn = e.target.closest('[data-issue]');
        if (btn && !btn.disabled) return issue(btn.dataset.issue);
    }

    function show(d) {
        if (!root) build();
        data = d || {};
        picked = []; cat = 'all'; search = ''; note = ''; err = ''; busy = false;
        open = true;
        root.classList.remove('hidden');
        shell();
    }

    function close(tellGame) {
        if (!open) return;
        open = false;
        root.classList.add('hidden');
        root.innerHTML = '';
        if (tellGame) post('chargeClose');
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'charge') return;
        if (m.open) show(m.data); else close(false);
    });
    document.addEventListener('keydown', (e) => { if (open && e.key === 'Escape') close(true); });

    return { show, close, fake: null, get open() { return open; } };
})();
