// EX_Tii Mechanic tablet — Services: the price list every mechanic bills from, the manager
// adds, edits and removes lines. The Management → قوالب الفواتير tab shows the same editor.
(() => {
    const { S, I, esc, call, render, toast, fail, ask, money } = PT;

    S.off = { list: null, q: '', cat: 'all', edit: null, isBoss: false, maxFine: 100000, maxJail: 120, busy: false };
    const O = () => S.off;

    const cats = () => { const out = []; PT.list(O().list).forEach((o) => { if (!out.includes(o.category)) out.push(o.category); }); return out; };
    const minutes = (n) => (n > 0 ? `${n} د` : '—');

    function load() {
        call('offences').then((res) => {
            if (res.ok) { O().list = PT.list(res.r.list); O().isBoss = !!res.r.isBoss; O().maxFine = res.r.maxFine || 100000; O().maxJail = res.r.maxJail || 120; }
            else { O().list = []; fail(res); }
            render();
        });
    }

    function shown() {
        const o = O();
        const q = (o.q || '').trim().toLowerCase();
        return PT.list(o.list).filter((x) => (o.cat === 'all' || x.category === o.cat) && (!q || String(x.label).toLowerCase().includes(q) || String(x.category).toLowerCase().includes(q)));
    }

    // one line being edited (or a new one when id is null)
    function editRow(e) {
        return `<tr class="edit">
            <td><input class="pt-in sm" data-model="off.edit.label" maxlength="80" value="${esc(e.label)}" placeholder="اسم الخدمة"></td>
            <td><input class="pt-in sm" data-model="off.edit.category" maxlength="40" value="${esc(e.category)}" placeholder="الفئة" list="offCats"></td>
            <td><input class="pt-in sm ltr" inputmode="numeric" data-model="off.edit.fine" data-enter="offSave" value="${esc(e.fine)}" placeholder="0"></td>
            <td class="pt-acts"><button class="pt-mini green" data-act="offSave">${I('check', 13, 2.4)} حفظ</button><button class="pt-mini" data-act="offCancel">إلغاء</button></td>
        </tr>`;
    }

    // the table: editable when the chief looks at it (edit = true)
    function table(edit) {
        const o = O();
        if (!o.list) return '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
        const rows = shown();
        const canEdit = edit && o.isBoss;
        const e = o.edit;
        let body = rows.map((x) => {
            if (canEdit && e && e.id === x.id) return editRow(e);
            return `<tr><td>${esc(x.label)}</td><td><em class="pt-tag grey">${esc(x.category)}</em></td><td class="ltr">${money(x.fine)}</td>
                ${canEdit ? `<td class="pt-acts"><button class="pt-mini green" data-act="offEdit" data-id="${x.id}">${I('edit', 13, 2)} تعديل</button><button class="pt-mini" data-act="offDelete" data-id="${x.id}">${I('trash', 13, 2)}</button></td>` : ''}</tr>`;
        }).join('');
        if (canEdit && e && e.id == null) body = editRow(e) + body;
        if (!body) body = `<tr><td colspan="${canEdit ? 4 : 3}" class="pt-mute">لا توجد خدمة بهذا الاسم.</td></tr>`;
        const head = `<tr><th>الخدمة</th><th>الفئة</th><th>السعر</th>${canEdit ? '<th>إجراءات</th>' : ''}</tr>`;
        return `<div class="pt-logtop">
                <div class="pt-fchips off-chips">${[['all', 'الكل'], ...cats().map((c) => [c, c])].map(([id, label]) => `<button class="${o.cat === id ? 'on' : ''}" data-act="offCat" data-c="${esc(id)}">${esc(label)}</button>`).join('')}</div>
                <div class="pt-logf">
                    ${canEdit ? `<button class="pt-btn primary xs" data-act="offNew" ${e ? 'disabled' : ''}>${I('plus', 13, 2.4)} خدمة جديدة</button>` : ''}
                    <div class="pt-search sm">${I('search', 14, 2)}<input class="pt-in bare" data-model="off.q" data-live="1" value="${esc(o.q)}" placeholder="بحث"></div>
                </div></div>
            <datalist id="offCats">${cats().map((c) => `<option value="${esc(c)}">`).join('')}</datalist>
            <div class="pt-tablewrap"><table class="pt-table"><thead>${head}</thead><tbody>${body}</tbody></table></div>
            ${canEdit ? `<p class="pt-hint">الميكانيكي يختار من هذه القائمة عند كتابة الفاتورة. الفاتورة تصل إلى بنك الزبون ويدفعها من الفرع أو الصراف أو الهاتف إلى حساب الورشة. حد السعر $${o.maxFine} للخدمة الواحدة.` : ''}`;
    }

    function view() {
        const n = PT.list(O().list).length;
        return `<div class="pt-appwin">${PT.head('الفواتير', 'قوالب الفواتير', PT.metaBox('العدد', String(n)))}
            <div class="pt-abody pad" data-scroll="offences">${table(false)}</div></div>`;
    }

    const num = (v) => { const s = String(v == null ? '' : v).replace(/[^\d]/g, ''); return s ? Number(s) : 0; };

    function save() {
        const o = O();
        const e = o.edit;
        if (!e || o.busy) return;
        const label = String(e.label || '').trim();
        if (label.length < 2) return toast('اكتب اسم الخدمة', 'error');
        if (!String(e.category || '').trim()) return toast('اكتب الفئة (مرور، عنف…)', 'error');
        o.busy = true;
        call('offenceSave', e.id, label, String(e.category).trim(), num(e.fine), 0).then((res) => {
            o.busy = false;
            if (!res.ok) return fail(res);
            o.list = PT.list(res.r.list);
            o.edit = null;
            toast(e.id == null ? 'أُضيفت الخدمة' : 'تم الحفظ', 'success');
            render();
        });
    }

    const act = {
        offCat: (el) => { O().cat = el.dataset.c; render(); },
        offNew: () => { O().edit = { id: null, label: '', category: O().cat !== 'all' ? O().cat : '', fine: '', jail: '' }; render(); },
        offEdit: (el) => {
            const x = PT.list(O().list).find((y) => y.id === Number(el.dataset.id));
            if (!x) return;
            O().edit = { id: x.id, label: x.label, category: x.category, fine: String(x.fine), jail: String(x.jail) };
            render();
        },
        offCancel: () => { O().edit = null; render(); },
        offSave: save,
        offDelete: (el) => {
            const x = PT.list(O().list).find((y) => y.id === Number(el.dataset.id));
            if (!x) return;
            ask({ title: 'حذف الخدمة', sub: 'القائمة', text: `تُحذف "${x.label}" من القائمة. الفواتير القديمة تبقى كما هي.`, ok: 'حذف', danger: true }, () => {
                call('offenceDelete', x.id).then((res) => {
                    if (!res.ok) return fail(res);
                    O().list = PT.list(res.r.list);
                    toast('حُذفت الخدمة', 'success');
                    render();
                });
            });
        },
    };

    PT.app('offences', {
        view,
        enter() { O().q = ''; O().cat = 'all'; O().edit = null; load(); },
        back() { if (O().edit) { O().edit = null; render(); return true; } return false; },
        act,
    });

    // the chief's editor inside Management (boss.js asks for it)
    PT.offencesEditor = { table: () => table(true), load, act };
})();
