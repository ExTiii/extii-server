// EX_Tii Mechanic tablet — Form Inbox: the forms citizens fill at the front desk (job applications,
// complaints). Read them, add notes, mark them reviewed, archive them.
(() => {
    const { S, I, esc, call, render, toast, ago, fmtStamp } = PT;

    S.forms = { types: [], items: [], filter: 'new', cur: null, note: '', loaded: false };
    const F = () => S.forms;

    const FILTERS = [['new', 'جديدة'], ['seen', 'تمت مراجعتها'], ['archived', 'مؤرشفة'], ['all', 'الكل']];
    const typeOf = (id) => PT.list(F().types).find((t) => t.id === id);
    const iconOf = (id) => (id === 'complaint' ? 'alert' : 'doc');

    function shown() {
        const f = F().filter;
        return PT.list(F().items).filter((x) => (f === 'all') || (f === 'new' && !x.reviewed && !x.archived) || (f === 'seen' && x.reviewed && !x.archived) || (f === 'archived' && x.archived));
    }

    function listView() {
        const items = shown();
        if (!items.length) return `<p class="pt-mute pad">${F().loaded ? 'لا توجد نماذج هنا.' : 'جارٍ التحميل…'}</p>`;
        return items.map((x) => `<button class="pt-frow2 ${F().cur && F().cur.id === x.id ? 'on' : ''}" data-act="formOpen" data-id="${x.id}">
            <i class="pt-fic ${x.type === 'complaint' ? 'red' : 'amber'}">${I(iconOf(x.type), 17, 2)}</i>
            <span><b>${esc(x.name)}</b><small>${esc(x.typeLabel)} · <bdi class="ltr">${esc(x.ref)}</bdi></small></span>
            <span class="pt-fside"><small>${esc(ago(x.time))}</small>${x.archived ? '<em class="pt-tag grey">مؤرشف</em>' : x.reviewed ? '<em class="pt-tag green">تمت المراجعة</em>' : '<em class="pt-tag amber">جديد</em>'}</span>
        </button>`).join('');
    }

    function detailView() {
        const x = F().cur;
        if (!x) return `<div class="pt-cempty center"><b>اختر نموذجًا من القائمة لقراءته.</b><small>النماذج يملؤها المواطنون في مكتب الاستقبال بالمركز.</small></div>`;
        const t = typeOf(x.type);
        const fields = (t ? PT.list(t.fields) : []).map((f) => {
            const v = x.fields && x.fields[f.id];
            return `<div class="pt-ffield ${f.type === 'area' ? 'area' : ''}"><small>${esc(f.label)}</small><p>${v ? esc(v) : '<i class="pt-mute">—</i>'}</p></div>`;
        }).join('');
        const notes = PT.list(x.notes);
        const archGrade = S.me && S.me.grade;
        return `<div class="pt-fdetail" data-scroll="fdetail">
            <div class="pt-fhead">
                <i class="pt-fic big ${x.type === 'complaint' ? 'red' : 'amber'}">${I(iconOf(x.type), 22, 2)}</i>
                <div><small>${esc(x.typeLabel)} · <bdi class="ltr">${esc(x.ref)}</bdi></small><h2>${esc(x.name)}</h2><span class="ltr">${esc(fmtStamp(x.time))}</span></div>
                <div class="pt-factions">
                    ${!x.reviewed ? `<button class="pt-btn primary sm" data-act="formDo" data-a="review">${I('check', 15, 2.2)} تمت المراجعة</button>` : `<em class="pt-tag green">راجعه ${esc(x.reviewedBy || '')}</em>`}
                    <button class="pt-btn ghost sm" data-act="formDo" data-a="${x.archived ? 'unarchive' : 'archive'}" ${archGrade == null ? 'disabled' : ''}>${I('archive', 15, 2)} ${x.archived ? 'إرجاع من الأرشيف' : 'أرشفة'}</button>
                </div>
            </div>
            <div class="pt-ffields">${fields}</div>
            <h4 class="pt-h4">الملاحظات (${notes.length})</h4>
            <div class="pt-notes">${notes.length ? notes.map((n) => `<div class="pt-note"><b>${esc(n.by)}</b><span class="ltr">${esc(fmtStamp(n.time))}</span><p>${esc(n.text)}</p></div>`).join('') : '<p class="pt-mute">لا توجد ملاحظات بعد.</p>'}</div>
            <div class="pt-inrow"><input class="pt-in" data-model="forms.note" data-enter="formNote" maxlength="300" value="${esc(F().note)}" placeholder="أضف ملاحظة للزملاء…"><button class="pt-btn ghost sm" data-act="formNote">إضافة</button></div>
        </div>`;
    }

    function view() {
        const f = F();
        const fresh = PT.list(f.items).filter((x) => !x.reviewed && !x.archived).length;
        return `<div class="pt-appwin">${PT.head('الاستقبال', 'صندوق النماذج', PT.metaBox('جديدة', String(fresh)))}
            <div class="pt-abody split">
                <aside class="pt-flist">
                    <div class="pt-fchips">${FILTERS.map(([id, label]) => `<button class="${f.filter === id ? 'on' : ''}" data-act="formFilter" data-f="${id}">${esc(label)}</button>`).join('')}</div>
                    <div class="pt-fitems" data-scroll="flist">${listView()}</div>
                </aside>
                <section class="pt-fmain">${detailView()}</section>
            </div></div>`;
    }

    function load() {
        call('formsList').then((res) => {
            if (res.ok) {
                F().types = PT.list(res.r.types);
                F().items = PT.list(res.r.items);
                F().loaded = true;
                S.badges.forms = PT.list(res.r.items).filter((x) => !x.reviewed && !x.archived).length;
            } else PT.fail(res);
            render();
        });
    }

    function apply(res) {
        if (!res.ok) return PT.fail(res);
        const r = res.r || {};
        if (r.items) F().items = PT.list(r.items);
        if (r.item) F().cur = r.item;
        S.badges.forms = PT.list(F().items).filter((x) => !x.reviewed && !x.archived).length;
        if (r.text) toast(PT.ERR[r.text] || r.text, 'error');
        render();
        return true;
    }

    PT.app('forms', {
        view,
        enter() { F().cur = null; F().note = ''; load(); },
        act: {
            formFilter: (el) => { F().filter = el.dataset.f; render(); },
            formOpen: (el) => {
                F().note = '';
                call('formGet', Number(el.dataset.id)).then((res) => {
                    if (!res.ok) return PT.fail(res);
                    F().cur = res.r;
                    S.scrolls.fdetail = 0;
                    render();
                });
            },
            formDo: (el) => {
                const x = F().cur;
                if (x) call('formAction', x.id, el.dataset.a, '').then(apply);
            },
            formNote: () => {
                const x = F().cur;
                const text = (F().note || '').trim();
                if (!x || !text) return;
                call('formAction', x.id, 'note', text).then((res) => {
                    if (res.ok && !(res.r && res.r.text)) F().note = '';
                    apply(res);
                });
            },
        },
    });
})();
