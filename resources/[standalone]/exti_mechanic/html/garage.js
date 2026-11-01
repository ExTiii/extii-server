// =====================================================================
// Garage: the team's vehicles (park out, the trunk, the leader changes a plate) and the vehicle shop
// =====================================================================
const Garage = (() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => {
        if (!RES) return Promise.resolve(Garage.fake ? Garage.fake(name, data) : null);
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
            .then((r) => r.json()).catch(() => null);
    };
    const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
    const fix = (d) => { if (d) { d.vehicles = arr(d.vehicles); d.shop = arr(d.shop); } return d; };
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => `<bdi dir="ltr">$${Math.round(n || 0).toLocaleString('en-US')}</bdi>`;

    const ICON = {
        box: '<svg viewBox="0 0 24 24" fill="none" stroke="#f2c230" stroke-width="2" stroke-linejoin="round"><path d="M3 7l9-4 9 4v10l-9 4-9-4z"/><path d="M3 7l9 4 9-4M12 11v10"/></svg>',
        seat: '<svg viewBox="0 0 24 24" fill="none" stroke="#ff8a8f" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="6" r="3"/><path d="M6 21v-3a6 6 0 0 1 12 0v3"/></svg>',
        speed: '<svg viewBox="0 0 24 24" fill="none" stroke="#c88cff" stroke-width="2" stroke-linecap="round"><path d="M4 16a8 8 0 1 1 16 0"/><path d="M12 16l4-5"/></svg>',
        fuel: '<svg viewBox="0 0 24 24" fill="none" stroke="#8fd0ff" stroke-width="2" stroke-linejoin="round"><path d="M5 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16H5zM8 8h4"/><path d="M15 9h2a2 2 0 0 1 2 2v6a1.5 1.5 0 0 0 3 0v-7l-3-3"/></svg>',
        tag: '<svg viewBox="0 0 24 24" fill="none" stroke="#f5c27b" stroke-width="2" stroke-linecap="round"><path d="M4 6h16M4 12h16M4 18h16"/></svg>',
        wrench: '<svg viewBox="0 0 24 24" fill="none" stroke="#9fe0b8" stroke-width="2" stroke-linejoin="round"><path d="M14 6a4 4 0 0 0 5 5l-8 8a2 2 0 0 1-3-3l8-8a4 4 0 0 0-2-2z"/></svg>',
        out: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
        sell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="9" cy="9" r="5"/><path d="M14 14l6 6M17 14h3v3"/></svg>',
        trunk: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><rect x="3" y="7" width="18" height="12" rx="2"/><path d="M3 11h18M10 11v3h4v-3"/></svg>',
        cart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
        plate: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 10h4M7 14h10"/></svg>',
        back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M19 12H5M11 6l-6 6 6 6"/></svg>',
    };
    const FALLBACK = 'data:image/svg+xml;utf8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 80"><path d="M10 54V30h86l26 12h24v12z" fill="#f1eeee" stroke="#b9aaab" stroke-width="2"/><rect x="10" y="44" width="136" height="5" fill="#d9363e"/><circle cx="38" cy="58" r="10" fill="#2b2b2b"/><circle cx="122" cy="58" r="10" fill="#2b2b2b"/></svg>');
    const img = (model) => `<img src="https://docs.fivem.net/vehicles/${encodeURIComponent(model)}.webp" onerror="this.onerror=null;this.src='${FALLBACK}'" alt="">`;

    let root, panel, open = false, data = null, sel = null, view = 'list', sure = null, note = '', noteErr = false, busy = false, plateEdit = null;

    function build() {
        root = document.getElementById('garage');
        root.innerHTML = '<div class="gr-panel"></div><div class="gr-hint"><kbd>Esc</kbd>إغلاق</div>';
        panel = root.querySelector('.gr-panel');
        panel.addEventListener('click', onClick);
    }

    const cars = () => data && data.kind === 'car';
    function bar(label, value, max, color) {
        const p = Math.max(4, Math.min(100, Math.round((value || 0) / max * 100)));
        return `<div class="gr-bar"><i>${label}</i><u><s style="width:${p}%;background:${color}"></s></u></div>`;
    }

    function detail(v) {
        if (!v) return '<div class="gr-detail"><div class="gr-empty">اختر مركبة</div></div>';
        const s = v.stats || {};
        const tag = v.mine ? 'معك الآن' : v.out ? (v.outBy ? `مع ${esc(v.outBy)}` : 'بالخارج') : 'جاهزة';
        const btns = [];
        const cantOut = v.out || data.hasOne;
        btns.push(`<button class="gr-btn go" data-out="${v.id}" ${cantOut ? 'disabled' : ''}>${ICON.out}أخرج المركبة</button>`);
        if (data.boss) btns.push(`<button class="gr-btn sell${sure === v.id ? ' sure' : ''}" data-sell="${v.id}" ${v.out ? 'disabled' : ''}>${ICON.sell}${sure === v.id ? `متأكد؟ +${money(v.sell)}` : 'بيع المركبة'}</button>`);
        btns.push(`<button class="gr-btn dark" data-trunk="${v.id}">${ICON.trunk}افتح الصندوق</button>`);
        if (data.boss) btns.push(`<button class="gr-btn dark" data-plate="${v.id}" ${v.out ? 'disabled' : ''}>${ICON.plate}تعديل اللوحة</button>`);
        if (btns.length % 2 === 1) btns[btns.length - 1] = btns[btns.length - 1].replace('class="gr-btn', 'class="gr-btn wide');
        const why = v.out ? '' : data.hasOne ? 'معك مركبة بالفعل، أدخلها للمرآب أولًا' : '';
        return `<div class="gr-detail">
            <div class="hd"><span class="pl">${esc(v.plate)}</span><span class="st${v.out ? ' out' : ''}">${tag}</span></div>
            <div class="nm">${esc(v.label)}</div>
            <div class="big">${img(v.model)}</div>
            <div class="gr-icons">
                <span>${ICON.box}${data.trunk} خانة</span><span>${ICON.seat}${s.seats || '—'}</span>
                <span>${ICON.speed}${s.speed || '—'} كم/س</span><span>${ICON.fuel}${v.fuel}%</span>
                <span>${ICON.wrench}${Math.min(v.engine, v.body)}%</span><span>${ICON.tag}${esc(s.class || '')}</span>
            </div>
            <div class="gr-bars">
                ${bar('السرعة القصوى', s.speed, cars() ? 300 : 220, '#b44ce0')}${bar('التسارع', s.accel, cars() ? 0.6 : 0.4, '#e0424b')}
                ${bar('الكبح', s.brake, 1.4, '#4cc3e0')}${bar('الثبات', s.traction, 3.2, '#e0b43c')}
            </div>
            <div class="gr-btns">${btns.join('')}</div>
            ${plateEdit === v.id ? `<div class="gr-plate"><input class="gr-plate-in" maxlength="8" value="${esc(v.plate)}" spellcheck="false"><button class="gr-btn go" data-platesave="${v.id}">حفظ</button><button class="gr-btn dark" data-platecancel>إلغاء</button></div>` : ''}
            <div class="gr-note${noteErr ? ' err' : ''}">${esc(note || why)}</div>
        </div>`;
    }

    function renderList() {
        const list = data.vehicles || [];
        if (!list.find((v) => v.id === sel)) sel = list.length ? list[0].id : null;
        const cards = list.map((v) => `
            <div class="gr-card${v.id === sel ? ' sel' : ''}" data-sel="${v.id}">
                <div class="top"><b>${esc(v.label)}</b><span class="gr-tag${v.mine ? ' mine' : v.out ? ' out' : ''}">${v.mine ? 'معك' : v.out ? 'بالخارج' : 'جاهزة'}</span></div>
                <div class="img">${img(v.model)}</div>
                <div class="plate">${esc(v.plate)}</div>
            </div>`).join('') || `<div class="gr-empty">${cars() ? 'لا توجد سيارات للورشة بعد.' : 'لا توجد مركبات خدمة للورشة بعد.'}${data.boss ? ' اشترِ من متجر المركبات.' : ''}</div>`;
        panel.innerHTML = `
            <div class="gr-head">
                <div class="gr-title">${cars() ? 'مرآب السيارات' : 'مرآب مركبات الخدمة'}<small>${(data.vehicles || []).length} ${cars() ? 'سيارة' : 'مركبة'} · كل مركبة بصندوقها، وما تتركه فيه يبقى للمناوبة القادمة</small></div>
                ${data.boss ? `<button class="gr-shopbtn" data-shop>${ICON.cart}متجر المركبات</button>` : ''}
                <button class="gr-x" data-close>✕</button>
            </div>
            <div class="gr-body"><div class="gr-list">${cards}</div>${detail(list.find((v) => v.id === sel))}</div>`;
    }

    function renderShop() {
        const items = (data.shop || []).map((m) => {
            const s = m.stats || {};
            return `<div class="gr-item"><b>${esc(m.label)}</b><div class="img">${img(m.model)}</div>
                <div class="mini">${s.speed || '—'} كم/س · ${s.seats || '—'} مقاعد · ${esc(s.class || '')}</div>
                <div class="price">${money(m.price)}</div>
                <button class="gr-btn go" data-buy="${esc(m.model)}" ${data.balance != null && data.balance < m.price ? 'disabled' : ''}>${ICON.cart}اشترِ للفريق</button></div>`;
        }).join('');
        panel.innerHTML = `
            <div class="gr-head">
                <div class="gr-title">متجر المركبات<small>تدفع من حساب الورشة في البنك · ${data.count}/${data.max} مركبة للفريق</small></div>
                <button class="gr-shopbtn" data-list style="background:rgba(255,255,255,.1)">${ICON.back}رجوع</button>
                <button class="gr-x" data-close>✕</button>
            </div>
            <div class="gr-bal">رصيد حساب الورشة: <b>${data.balance != null ? money(data.balance) : '—'}</b></div>
            <div class="gr-shop">${items}</div>
            <div class="gr-note${noteErr ? ' err' : ''}">${esc(note)}</div>`;
    }

    function render() { if (view === 'shop') renderShop(); else renderList(); }
    function say(text, err) { note = text || ''; noteErr = !!err; render(); }

    async function onClick(e) {
        const t = e.target.closest('[data-close],[data-sel],[data-out],[data-sell],[data-trunk],[data-shop],[data-list],[data-buy],[data-plate],[data-platesave],[data-platecancel]');
        if (!t || busy || t.disabled) return;
        const d = t.dataset;
        if (d.close !== undefined) return closeUI(true);
        if (d.sel !== undefined) { sel = +d.sel; sure = null; plateEdit = null; note = ''; return render(); }
        if (d.shop !== undefined) { view = 'shop'; note = ''; return render(); }
        if (d.list !== undefined) { view = 'list'; note = ''; return render(); }
        if (d.plate !== undefined) { plateEdit = +d.plate; note = 'حروف إنجليزية وأرقام، حتى 8'; noteErr = false; render(); const i = panel.querySelector('.gr-plate-in'); if (i) { i.focus(); i.select(); } return; }
        if (d.platecancel !== undefined) { plateEdit = null; note = ''; return render(); }
        if (d.platesave !== undefined) {
            const i = panel.querySelector('.gr-plate-in');
            const plate = (i ? i.value : '').toUpperCase().replace(/[^A-Z0-9]/g, '').trim();
            if (plate.length < 2) return say('اللوحة قصيرة جدًا', true);
            busy = true;
            const res = await post('garagePlate', { id: +d.platesave, plate });
            busy = false;
            if (res && res.ok) { data = fix(res.data); plateEdit = null; say('تم تغيير اللوحة'); }
            else say((res && res.error) || 'حدث خطأ', true);
            return;
        }
        if (d.out !== undefined) {
            busy = true; say('جارٍ إخراج المركبة…');
            const res = await post('garageOut', { id: +d.out });
            busy = false;
            if (!res || !res.ok) say((res && res.error) || 'حدث خطأ', true);
            return;
        }
        if (d.trunk !== undefined) {
            busy = true;
            const res = await post('garageTrunk', { id: +d.trunk });
            busy = false;
            if (!res || !res.ok) say((res && res.error) || 'حدث خطأ', true);
            return;
        }
        if (d.sell !== undefined) {
            const id = +d.sell;
            if (sure !== id) { sure = id; note = ''; return render(); }
            busy = true;
            const res = await post('garageSell', { id });
            busy = false; sure = null;
            if (res && res.ok) { data = fix(res.data); say('بيعت المركبة ورجع المبلغ لحساب الورشة'); }
            else say((res && res.error) || 'حدث خطأ', true);
            return;
        }
        if (d.buy !== undefined) {
            busy = true; say('جارٍ الشراء…');
            const res = await post('garageBuy', { model: d.buy });
            busy = false;
            if (res && res.ok) { data = fix(res.data); view = 'list'; const v = data.vehicles; sel = v.length ? Math.max(...v.map((x) => x.id)) : null; say('اشتريت مركبة جديدة للفريق'); }
            else say((res && res.error) || 'حدث خطأ', true);
        }
    }

    function openUI(d) {
        if (!root) build();
        data = fix(d || {}); view = 'list'; sure = null; plateEdit = null; note = ''; noteErr = false; busy = false; open = true;
        root.classList.remove('hidden');
        render();
    }
    function closeUI(tell) {
        if (!open) return;
        open = false;
        root.classList.add('hidden');
        if (tell) post('garageClose');
    }

    window.addEventListener('keydown', (e) => {
        if (!open) return;
        const typing = document.activeElement && document.activeElement.tagName === 'INPUT';
        if (typing && e.key === 'Enter') { const b = panel.querySelector('[data-platesave]'); if (b) b.click(); return; }
        if (e.key === 'Escape' || (e.key === 'Backspace' && !typing)) {
            e.preventDefault();
            if (plateEdit) { plateEdit = null; note = ''; render(); }
            else if (view === 'shop') { view = 'list'; note = ''; render(); } else closeUI(true);
        }
    });
    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || m.action !== 'garage') return;
        if (m.open) openUI(m.data); else closeUI(false);
    });

    return { open: openUI, close: closeUI, fake: null, _view: (v) => { view = v; render(); } };
})();
