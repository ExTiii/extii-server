// =====================================================================
// The bill sheet: the mechanic ticks the services done for the customer next to him, writes a
// note, and sends the bill (it lands in the customer's bank; the money goes to the workshop).
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

    const SHIELD = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.8-3.8a6 6 0 0 1-7.9 7.9l-6.9 6.9a2.1 2.1 0 1 1-3-3l6.9-6.9a6 6 0 0 1 7.9-7.9z"/></svg>';
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
                        <h1>فاتورة الورشة</h1>
                        <p>الزبون: <b>${esc(t.name || '')}</b> · رقم ${esc(t.id || '')}${t.previous ? ` · <b>${t.previous}</b> فواتير سابقة` : ' · زبون جديد'}</p>
                    </div>
                    <div class="ch-meta">
                        <div class="ch-chip"><small>الميكانيكي</small><b>${esc(data.officer || '')}</b></div>
                        <div class="ch-chip"><small>التاريخ</small><b dir="ltr">${stamp()}</b></div>
                    </div>
                    <button class="ch-x" data-close>${X}</button>
                </header>
                <div class="ch-body">
                    <section class="ch-list">
                        <div class="ch-tools">
                            <div class="ch-search"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg><input class="ch-q" placeholder="ابحث عن خدمة…" value="${esc(search)}"></div>
                            <div class="ch-cats" id="chCats"></div>
                        </div>
                        <div class="ch-rows" id="chRows"></div>
                    </section>
                    <aside class="ch-side">
                        <h3>الفاتورة</h3>
                        <div class="ch-picked" id="chPicked"></div>
                        <div class="ch-totals" id="chTotals"></div>
                        <textarea class="ch-note" maxlength="${data.noteLength || 160}" placeholder="ملاحظة (اختياري): المركبة، اللوحة، ما عُمل…">${esc(note)}</textarea>
                        <div class="ch-err" id="chErr"></div>
                        <div class="ch-actions" id="chActions"></div>
                        <div class="ch-foot" id="chFoot"></div>
                    </aside>
                </div>
                <div class="ch-done" id="chDone"><div class="ch-done-card"><div class="ch-done-check"><svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg></div><b id="chDoneTitle">أُرسلت الفاتورة</b><span id="chDoneText"></span></div></div>
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
        if (!list.length) { el.innerHTML = '<div class="ch-empty">لا توجد خدمة بهذا الاسم</div>'; return; }
        let last = null, html = '';
        list.forEach((o) => {
            if (cat === 'all' && o.category !== last) { html += `<div class="ch-group">${esc(o.category)}</div>`; last = o.category; }
            const on = picked.includes(o.id);
            html += `<div class="ch-row ${on ? 'on' : ''}" data-pick="${o.id}">
                <span class="ch-box">${CHECK}</span>
                <span class="ch-label">${esc(o.label)}</span>
                <span class="ch-fine">${money(o.fine)}</span>
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
            : '<div class="ch-none">اختر الخدمات من القائمة</div>';
        totalsEl.innerHTML = `<div class="ch-total fine"><small>المجموع</small><b>${money(t.fine)}</b></div>`;
        const actions = root.querySelector('#chActions');
        const foot = root.querySelector('#chFoot');
        const canFine = !busy && picked.length > 0 && t.fine >= 1 && data.bank !== false;
        if (actions) {
            actions.innerHTML = `<button class="ch-btn primary" data-issue="fine" ${canFine ? '' : 'disabled'}>إرسال الفاتورة</button>
                <button class="ch-btn" data-close>إلغاء</button>`;
        }
        if (foot) {
            if (data.bank === false) foot.textContent = 'البنك لا يعمل الآن: لا يمكن إرسال فاتورة';
            else foot.textContent = 'الفاتورة تصل إلى حساب الزبون في البنك، يدفعها من الفرع أو الصراف أو الهاتف والمبلغ يدخل حساب الورشة.';
        }
        const errEl = root.querySelector('#chErr');
        if (errEl) errEl.textContent = err;
    }

    function toggle(id) {
        const i = picked.indexOf(id);
        if (i >= 0) picked.splice(i, 1);
        else {
            if (picked.length >= (data.maxPicks || 12)) { err = `أقصى عدد في الفاتورة الواحدة ${data.maxPicks || 12}`; renderSide(); return; }
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
        const n = `${picked.length} ${picked.length === 1 ? 'خدمة' : 'خدمات'}`;
        root.querySelector('#chDoneTitle').textContent = 'أُرسلت الفاتورة';
        root.querySelector('#chDoneText').textContent = `${iso(money(r.fine || totals().fine))} · ${n} · وصلت إلى بنك ${data.target ? data.target.name : ''}`;
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
