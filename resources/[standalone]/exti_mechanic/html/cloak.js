// =====================================================================
// Cloakroom: your normal clothes, the uniforms for your rank, and (leaders) add / edit / delete
// =====================================================================
const Cloak = (() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => {
        if (!RES) return Promise.resolve(Cloak.fake ? Cloak.fake(name, data) : null);
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
            .then((r) => r.json()).catch(() => null);
    };
    const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    const ICON = {
        shirt: '<svg viewBox="0 0 24 24" fill="none" stroke="#6cb8ff" stroke-width="1.8" stroke-linejoin="round"><path d="M8 3l4 2 4-2 5 4-3 4-2-1v11H8V10l-2 1-3-4z"/></svg>',
        user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/></svg>',
        edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13 7l4 4"/></svg>',
        del: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/></svg>',
        plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
        tshirt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M8 3l4 2 4-2 5 4-3 4-2-1v11H8V10l-2 1-3-4z"/></svg>',
    };

    let root, panel, open = false, data = {}, view = 'list', form = null, sureId = null, busy = false;

    function ranksText(grades) {
        const all = (data.grades || []).map((g) => g.level);
        if (!grades || grades.length === 0 || all.every((l) => grades.includes(l))) return 'كل الرتب';
        const names = (data.grades || []).filter((g) => grades.includes(g.level)).map((g) => g.name);
        return names.join('، ');
    }

    function build() {
        root = document.getElementById('cloak');
        root.innerHTML = '<div class="ck-panel"></div><div class="ck-hint"><kbd>Esc</kbd>إغلاق</div>';
        panel = root.querySelector('.ck-panel');
        panel.addEventListener('click', onClick);
        panel.addEventListener('input', (e) => { if (e.target.classList.contains('ck-input') && form) form.label = e.target.value; });
    }

    function render() {
        if (view === 'form') return renderForm();
        const own = data.own !== false;
        const list = (data.outfits || []).filter((o) => data.boss || o.allowed);
        const rows = list.map((o) => `
            <div class="ck-row${data.wearing === o.id ? ' on' : ''}${own ? '' : ' other'}" ${own ? `data-wear="${o.id}"` : ''}>
                <span class="ck-ico">${ICON.shirt}</span>
                <span class="ck-name"><b>${esc(o.label)}</b><i>${data.boss ? esc(ranksText(o.grades)) : (data.wearing === o.id ? 'تلبسه الآن' : 'اضغط للبسه')}</i></span>
                ${data.boss ? `<button class="ck-act ck-edit" data-edit="${o.id}" title="تعديل">${ICON.edit}</button>
                <button class="ck-act ck-del${sureId === o.id ? ' sure' : ''}" data-del="${o.id}" title="حذف">${sureId === o.id ? 'متأكد؟' : ICON.del}</button>` : ''}
            </div>`).join('');
        panel.innerHTML = `
            <div class="ck-head"><div><div class="ck-title">غرفة الملابس</div><div class="ck-sub">${esc(data.station || '')}</div></div><button class="ck-x" data-close>✕</button></div>
            <button class="ck-btn ck-civ" data-civ>${ICON.user}ملابسك العادية</button>
            ${data.boss ? `<div class="ck-tabs"><button class="ck-tab${data.gender !== 'female' ? ' on' : ''}" data-gender="male">أزياء العمّال</button><button class="ck-tab${data.gender === 'female' ? ' on' : ''}" data-gender="female">أزياء الميكانيكيات</button></div>` : '<div class="ck-label">أزياء الورشة</div>'}
            <div class="ck-list">${rows || '<div class="ck-empty">لا يوجد زي لرتبتك بعد. اطلب من المدير إضافته.</div>'}</div>
            ${data.boss && !own ? '<div class="ck-note" style="margin-top:10px">تقدر تغيّر الاسم والرتب أو تحذف. ملابس هذه الأزياء تختارها شخصية من نفس الجنس.</div>' : ''}
            ${data.boss && own ? `<button class="ck-btn ck-new" data-new>${ICON.plus}زي جديد</button>` : ''}`;
    }

    function renderForm() {
        const f = form;
        const chips = (data.grades || []).map((g) => `<button class="ck-chip${f.grades.includes(g.level) ? ' on' : ''}" data-grade="${g.level}">${esc(g.name)}</button>`).join('');
        panel.innerHTML = `
            <div class="ck-head"><div><div class="ck-title">${f.mode === 'new' ? 'زي جديد' : 'تعديل الزي'}</div><div class="ck-sub">${data.gender === 'female' ? 'للضابطات' : 'للميكانيكيين'}</div></div><button class="ck-x" data-back>✕</button></div>
            <div class="ck-form">
                <label class="ck-field"><span>اسم الزي</span><input class="ck-input" maxlength="24" value="${esc(f.label)}" placeholder="مثلًا: زي الدورية"></label>
                <div class="ck-field"><span>من يقدر يلبسه</span><div class="ck-chips">${chips}</div></div>
                ${data.own !== false ? `<button class="ck-btn ck-civ" data-editor>${ICON.tshirt}${f.clothes ? 'غيّر الملابس في المحرر' : 'اختر الملابس في المحرر'}</button>
                <div class="ck-note">${f.clothes ? 'الملابس اللي تلبسها الآن هي اللي بتنحفظ في هذا الزي.' : f.mode === 'edit' ? 'الملابس تبقى كما هي، إلا إذا غيّرتها في المحرر.' : 'افتح المحرر واختر القميص والبنطلون والشارة، ثم احفظ هناك.'}</div>` : '<div class="ck-note">الملابس تبقى كما هي (تُختار بشخصية من نفس الجنس).</div>'}
                <div class="ck-err">${esc(f.err || '')}</div>
                <div class="ck-two"><button class="ck-btn ck-save" data-save>حفظ</button><button class="ck-btn ck-cancel" data-back>إلغاء</button></div>
            </div>`;
    }

    async function onClick(e) {
        const t = e.target.closest('[data-close],[data-civ],[data-wear],[data-edit],[data-del],[data-new],[data-grade],[data-editor],[data-save],[data-back],[data-gender]');
        if (!t || busy) return;
        if (t.dataset.gender !== undefined) {
            if (t.dataset.gender === data.gender) return;
            busy = true;
            const res = await post('cloakGender', { gender: t.dataset.gender });
            busy = false;
            if (res && res.outfits) {
                data.gender = res.gender; data.own = res.own;
                data.outfits = arr(res.outfits).map((o) => ({ ...o, grades: arr(o.grades) }));
                data.wearing = null; sureId = null;
            }
            return render();
        }
        if (t.dataset.close !== undefined) return closeUI(true);
        if (t.dataset.civ !== undefined) { data.wearing = null; sureId = null; render(); return post('cloakCivilian'); }
        if (t.dataset.del !== undefined) {
            e.stopPropagation();
            const id = +t.dataset.del;
            if (sureId !== id) { sureId = id; return render(); }
            busy = true;
            const res = await post('cloakDelete', { id });
            busy = false; sureId = null;
            if (res && res.outfits) data.outfits = arr(res.outfits).map((o) => ({ ...o, grades: arr(o.grades) }));
            return render();
        }
        if (t.dataset.edit !== undefined) {
            e.stopPropagation();
            const o = (data.outfits || []).find((x) => x.id === +t.dataset.edit);
            if (!o) return;
            sureId = null;
            form = { mode: 'edit', id: o.id, label: o.label, grades: [...(o.grades || [])], clothes: false };
            view = 'form';
            return render();
        }
        if (t.dataset.wear !== undefined) {
            sureId = null;
            data.wearing = +t.dataset.wear;
            render();
            return post('cloakWear', { id: +t.dataset.wear });
        }
        if (t.dataset.new !== undefined) {
            sureId = null;
            form = { mode: 'new', label: '', grades: (data.grades || []).map((g) => g.level), clothes: false };
            view = 'form';
            return render();
        }
        if (t.dataset.grade !== undefined) {
            const l = +t.dataset.grade;
            form.grades = form.grades.includes(l) ? form.grades.filter((x) => x !== l) : [...form.grades, l];
            return render();
        }
        if (t.dataset.editor !== undefined) {
            // the clothes editor opens in game; this panel comes back when you press save there
            return post('cloakEditor', { mode: form.mode, id: form.id });
        }
        if (t.dataset.back !== undefined) { view = 'list'; form = null; return render(); }
        if (t.dataset.save !== undefined) {
            const label = (form.label || '').trim();
            if (label.length < 2) { form.err = 'اكتب اسمًا للزي.'; return render(); }
            if (form.grades.length === 0) { form.err = 'اختر رتبة واحدة على الأقل.'; return render(); }
            if (form.mode === 'new' && !form.clothes) { form.err = 'اختر الملابس في المحرر أولًا.'; return render(); }
            busy = true;
            const res = await post('cloakSave', { mode: form.mode, id: form.id, label, grades: form.grades, clothes: form.clothes });
            busy = false;
            if (res && res.ok) { if (res.outfits) data.outfits = arr(res.outfits).map((o) => ({ ...o, grades: arr(o.grades) })); view = 'list'; form = null; }
            else form.err = (res && res.text) || 'ما انحفظ، حاول مرة أخرى.';
            return render();
        }
    }

    function openUI(d) {
        if (!root) build();
        const keep = d && d.keepForm && form;
        data = d || {};
        data.grades = arr(data.grades);
        data.outfits = arr(data.outfits).map((o) => ({ ...o, grades: arr(o.grades) }));
        if (!keep) { view = 'list'; form = null; }
        else { form.clothes = form.clothes || !!d.clothesChosen; form.err = ''; }
        sureId = null; busy = false; open = true;
        root.classList.remove('hidden');
        render();
    }
    function closeUI(tell) {
        if (!open) return;
        open = false;
        root.classList.add('hidden');
        if (tell) post('cloakClose');
    }

    window.addEventListener('keydown', (e) => {
        if (!open) return;
        if (e.key === 'Escape') { e.preventDefault(); if (view === 'form') { view = 'list'; form = null; render(); } else closeUI(true); }
        if (e.key === 'Backspace' && document.activeElement?.tagName !== 'INPUT') { e.preventDefault(); closeUI(true); }
    });
    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || m.action !== 'cloak') return;
        if (m.open) openUI(m.data);
        else closeUI(false);
    });

    return { open: openUI, close: closeUI, fake: null, _set: (v, f) => { view = v; form = f; render(); } };
})();
