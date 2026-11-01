// =====================================================================
// Public forms: citizens fill a paper form at the front desk (job application, complaint...);
// officers read, note, mark reviewed and archive them in the inbox
// =====================================================================
const Forms = (() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => {
        if (!RES) return Promise.resolve(Forms.fake ? Forms.fake(name, data) : null);
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
            .then((r) => r.json()).catch(() => null);
    };
    const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const SEAL = '<svg class="fm-seal" viewBox="0 0 100 110"><path d="M50 4 L88 16 V52 C88 78 70 96 50 106 C30 96 12 78 12 52 V16 Z" fill="#3a3226"/><path d="M50 30 l6.5 13.2 14.5 2.1 -10.5 10.2 2.5 14.5 L50 63.2 37 70 39.5 55.5 29 45.3 43.5 43.2z" fill="#fbf7ee"/></svg>';
    const ICON = {
        application: '<svg viewBox="0 0 24 24" fill="none" stroke="#6b4a1c" stroke-width="1.8" stroke-linejoin="round"><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h3"/></svg>',
        complaint: '<svg viewBox="0 0 24 24" fill="none" stroke="#b4503b" stroke-width="1.8" stroke-linejoin="round"><path d="M4 5h16v11H9l-5 4z"/><path d="M12 8v3M12 13.5v.5"/></svg>',
    };

    let root, open = false, mode = null, data = {}, view = 'pick', type = null, values = {}, err = '', busy = false;
    let sel = null, filter = 'all', search = '', details = {}, loading = null;

    const types = () => arr(data.types);
    const typeOf = (id) => types().find((t) => t.id === id);
    const fmtTime = (t) => { if (!t) return ''; const d = new Date(t * 1000); return d.toLocaleDateString('ar-EG-u-nu-latn') + ' ' + d.toLocaleTimeString('ar-EG-u-nu-latn', { hour: '2-digit', minute: '2-digit' }); };

    function build() {
        root = document.getElementById('forms');
        root.addEventListener('click', onClick);
        root.addEventListener('input', (e) => {
            if (e.target.dataset.f) values[e.target.dataset.f] = e.target.value;
            if (e.target.classList.contains('fx-search')) { search = e.target.value; renderList(); }
        });
    }

    // ---- the citizen's paper form ----
    function renderCitizen() {
        let inner;
        if (view === 'pick') {
            inner = `<div class="fm-h">نماذج الورشة</div><div class="fm-sub">اختر النموذج وعبّئه، ويوصل للورشة مباشرة.</div>
                <div class="fm-types">${types().map((t) => `<button class="fm-type" data-type="${esc(t.id)}">${ICON[t.icon] || ICON.application}<span><b>${esc(t.label)}</b><i>${esc(t.desc || '')}</i></span></button>`).join('')}</div>`;
        } else if (view === 'done') {
            inner = `<div class="fm-done"><b>وصل نموذجك ✓</b><i>رقمه ${esc(data.lastId || '')}. سيراجعه أحد عمّال الورشة.</i></div>
                <div class="fm-foot"><span></span><button class="fm-send" data-close>إغلاق</button></div>`;
        } else {
            const t = typeOf(type);
            const fields = arr(t && t.fields).map((f) => {
                const v = values[f.id] != null ? values[f.id] : '';
                const input = f.type === 'area'
                    ? `<textarea data-f="${esc(f.id)}" maxlength="${f.max || 600}" placeholder="${esc(f.placeholder || '')}">${esc(v)}</textarea>`
                    : `<input data-f="${esc(f.id)}" maxlength="${f.max || 60}" value="${esc(v)}" placeholder="${esc(f.placeholder || '')}">`;
                return `<div class="fm-f${f.type === 'area' || f.wide ? ' wide' : ''}"><label>${esc(f.label)}${f.required ? ' <b>*</b>' : ''}</label>${input}</div>`;
            }).join('');
            inner = `<div class="fm-h">${esc(t ? t.label : '')}</div><div class="fm-sub">${esc(t ? t.desc || '' : '')}</div>
                <div class="fm-grid">${fields}</div>
                <div class="fm-foot"><span class="fm-err">${esc(err)}</span><button class="fm-send" data-send>إرسال النموذج</button></div>`;
        }
        root.innerHTML = `<div class="fm-shade"></div><div class="fm-paper">${SEAL}<button class="fm-x" data-${view === 'fill' && types().length > 1 ? 'back' : 'close'}>✕</button>${inner}</div>`;
    }

    // ---- the workshop inbox ----
    function visible() {
        const q = search.trim().toLowerCase();
        return arr(data.items).filter((it) => {
            if (filter === 'archived') { if (!it.archived) return false; } else if (it.archived) return false;
            if (filter !== 'all' && filter !== 'archived' && it.type !== filter) return false;
            if (!q) return true;
            return [it.name, it.ref, it.typeLabel].some((x) => String(x || '').toLowerCase().includes(q));
        });
    }
    function tagsOf(it) {
        const t = `<span class="fx-tag ${it.type === 'complaint' ? 'cmp' : 'app'}">${esc(it.typeLabel)}</span>`;
        const s = it.archived ? '<span class="fx-tag arc">مؤرشف</span>' : it.reviewed ? '<span class="fx-tag ok">تمت المراجعة</span>' : '<span class="fx-tag new">جديد</span>';
        return t + s;
    }
    function renderList() {
        const list = root.querySelector('.fx-list');
        if (!list) return;
        const items = visible();
        if (!items.find((x) => x.id === sel)) sel = items.length ? items[0].id : null;
        list.innerHTML = items.map((it) => `<div class="fx-item${it.id === sel ? ' sel' : ''}" data-item="${it.id}"><div class="id">${esc(it.ref)}</div><b>${esc(it.name)}</b><i>${esc(fmtTime(it.time))}</i><div class="fx-tags">${tagsOf(it)}</div></div>`).join('') || '<div class="fx-empty">لا توجد نماذج هنا</div>';
        renderDetail();
        fetchDetail(sel);
    }
    // a form's boxes and notes are asked for when it is opened (the list only has short lines)
    async function fetchDetail(id) {
        if (id == null || details[id] || loading === id) return;
        loading = id;
        const res = await post('formGet', { id });
        if (loading === id) loading = null;
        if (!open || mode !== 'inbox') return;
        if (res && res.id === id) { details[id] = { ...res, notes: arr(res.notes) }; if (sel === id) renderDetail(); }
    }
    function renderDetail() {
        const box = root.querySelector('.fx-detail');
        const short = arr(data.items).find((x) => x.id === sel);
        if (!box) return;
        if (!short) { box.innerHTML = '<div class="fx-empty">اختر نموذجًا لقراءته</div>'; return; }
        const it = details[sel] ? { ...details[sel], ...short } : null;
        if (!it) { box.innerHTML = `<div class="fx-h"><b>${esc(short.typeLabel)} — ${esc(short.name)}</b><span><bdi>${esc(short.ref)}</bdi></span></div><div class="fx-empty">جارٍ التحميل…</div>`; return; }
        const t = typeOf(it.type);
        const fields = arr(t && t.fields).map((f) => `<div class="fx-field${f.type === 'area' ? ' wide' : ''}"><small>${esc(f.label)}</small><p>${esc((it.fields || {})[f.id] || '—')}</p></div>`).join('');
        const notes = arr(it.notes).map((n) => `<div class="fx-note"><i>${esc(n.by)} · ${esc(fmtTime(n.time))}</i>${esc(n.text)}</div>`).join('');
        box.innerHTML = `<div class="fx-h"><b>${esc(it.typeLabel)} — ${esc(it.name)}</b><span><bdi>${esc(it.ref)}</bdi> · <bdi>${esc(fmtTime(it.time))}</bdi></span></div>
            <div class="fx-tags" style="margin-top:6px">${tagsOf(it)}${it.reviewedBy ? `<span class="fx-tag">راجعه ${esc(it.reviewedBy)}</span>` : ''}</div>
            <div class="fx-fields">${fields}</div>
            <div class="fx-notes"><small>ملاحظات الورشة</small>${notes || '<div class="fx-note" style="background:transparent;padding-right:0;color:#90897a">لا توجد ملاحظات</div>'}
                <div class="fx-add"><input class="fx-note-in" maxlength="300" placeholder="اكتب ملاحظة…"><button class="fx-btn blue" data-act="note">أضف</button></div></div>
            <div class="fx-actions">
                ${it.archived ? '<button class="fx-btn" data-act="unarchive">أرجعه من الأرشيف</button>' : `${it.reviewed ? '' : '<button class="fx-btn green" data-act="review">تمت المراجعة</button>'}<button class="fx-btn" data-act="archive">أرشفة</button>`}
            </div>`;
    }
    function renderInbox() {
        const counts = arr(data.items).filter((x) => !x.archived && !x.reviewed).length;
        const btn = (id, label) => `<button class="${filter === id ? 'on' : ''}" data-filter="${id}">${label}</button>`;
        root.innerHTML = `<div class="fm-shade"></div><div class="fx-tab"><div class="fx-screen">
            <div class="fx-top"><div class="t"><small>PUBLIC FORMS</small><b>صندوق النماذج</b></div><span class="count">${counts} جديد</span><button class="fx-close" data-close>✕</button></div>
            <div class="fx-bar"><input class="fx-search" placeholder="ابحث بالاسم أو الرقم…" value="${esc(search)}">
                <div class="fx-filter">${btn('all', 'الكل')}${types().map((t) => btn(t.id, t.label)).join('')}${btn('archived', 'الأرشيف')}</div></div>
            <div class="fx-body"><div class="fx-list"></div><div class="fx-detail"></div></div>
        </div></div>`;
        renderList();
    }

    function render() { if (mode === 'inbox') renderInbox(); else renderCitizen(); }

    async function onClick(e) {
        const t = e.target.closest('[data-close],[data-type],[data-back],[data-send],[data-item],[data-filter],[data-act]');
        if (!t || busy) return;
        const d = t.dataset;
        if (d.close !== undefined) return closeUI(true);
        if (d.type !== undefined) { type = d.type; view = 'fill'; err = ''; values = Object.assign({}, data.me || {}); return render(); }
        if (d.back !== undefined) { view = 'pick'; type = null; err = ''; return render(); }
        if (d.send !== undefined) {
            const def = typeOf(type);
            for (const f of arr(def && def.fields)) {
                if (f.required && !String(values[f.id] || '').trim()) { err = `املأ: ${f.label}`; return render(); }
            }
            busy = true;
            const res = await post('formSubmit', { type, fields: values });
            busy = false;
            if (res && res.ok) { data.lastId = res.ref; view = 'done'; values = {}; }
            else err = (res && res.text) || 'ما وصل النموذج، حاول مرة أخرى.';
            return render();
        }
        if (d.item !== undefined) { sel = +d.item; root.querySelectorAll('.fx-item').forEach((x) => x.classList.toggle('sel', +x.dataset.item === sel)); renderDetail(); return fetchDetail(sel); }
        if (d.filter !== undefined) { filter = d.filter; return renderInbox(); }
        if (d.act !== undefined) {
            let note;
            if (d.act === 'note') { const i = root.querySelector('.fx-note-in'); note = i ? i.value.trim() : ''; if (!note) return; }
            busy = true;
            const res = await post('formAction', { id: sel, action: d.act, note });
            busy = false;
            if (res && res.items) data.items = arr(res.items);
            if (res && res.item && res.item.id != null) details[res.item.id] = { ...res.item, notes: arr(res.item.notes) };
            return renderInbox();
        }
    }

    function openUI(m, d) {
        if (!root) build();
        mode = m; data = d || {}; open = true; busy = false; err = '';
        data.items = arr(data.items).map((x) => ({ ...x, notes: arr(x.notes) }));
        if (m === 'citizen') { view = types().length === 1 ? 'fill' : 'pick'; type = view === 'fill' ? types()[0].id : null; values = Object.assign({}, data.me || {}); }
        else { sel = null; filter = 'all'; search = ''; details = {}; loading = null; }
        root.classList.remove('hidden');
        render();
    }
    function closeUI(tell) {
        if (!open) return;
        open = false;
        root.classList.add('hidden');
        if (tell) post('formClose');
    }

    window.addEventListener('keydown', (e) => {
        if (!open) return;
        const typing = document.activeElement && /INPUT|TEXTAREA/.test(document.activeElement.tagName);
        if (e.key === 'Escape') { e.preventDefault(); closeUI(true); }
        else if (e.key === 'Enter' && typing && document.activeElement.classList.contains('fx-note-in')) { const b = root.querySelector('[data-act="note"]'); if (b) b.click(); }
    });
    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || m.action !== 'forms') return;
        if (m.open) openUI(m.mode, m.data); else closeUI(false);
    });

    return { open: openUI, close: closeUI, fake: null };
})();
