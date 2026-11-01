// EX_Tii Police tablet — the records: Citizens, Vehicles, Reports, Warrants, BOLOs, Cases.
// One file: they share the list + detail layout, the search box and the small forms.
(() => {
    const { S, I, esc, call, render, toast, fail, ask, money, fmtStamp, fmtDate, ago } = PT;

    const loading = '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
    const peopleText = (list) => PT.list(list).map((p) => p.name).join('، ');
    const pills = (list) => PT.list(list).map((p) => `<button class="pt-pill" data-act="recCitizen" data-cid="${esc(p.cid)}">${I('user', 12, 2.2)} ${esc(p.name)}</button>`).join('') || '<span class="pt-mute">—</span>';
    const ta = (model, value, placeholder, max = 4000) => `<textarea class="pt-ta" data-model="${model}" maxlength="${max}" placeholder="${esc(placeholder)}">${esc(value || '')}</textarea>`;
    const listSide = (title, count, chips, body) => `<aside class="pt-flist"><div class="pt-fchips">${chips || ''}</div><div class="pt-fitems" data-scroll="reclist">${body}</div></aside>`;

    // ------------------------------------------------------------------
    // Citizens
    // ------------------------------------------------------------------
    S.cit = { q: '', list: null, cur: null, note: '', busy: false };
    const C = () => S.cit;

    function citList() {
        const c = C();
        if (c.list == null) return `<div class="pt-cempty"><b>ابحث عن مواطن</b><small>بالاسم أو رقم الهوية أو رقم الهاتف.</small></div>`;
        if (!c.list.length) return '<p class="pt-mute pad">لا نتيجة.</p>';
        return c.list.map((p) => `<button class="pt-frow2 ${c.cur && c.cur.citizen.cid === p.cid ? 'on' : ''}" data-act="recCitizen" data-cid="${esc(p.cid)}">
            <i class="pt-fic amber">${I('user', 17, 2)}</i><span><b>${esc(p.name)}</b><small><bdi class="ltr">${esc(p.cid)}</bdi>${p.phone ? ` · <bdi class="ltr">${esc(p.phone)}</bdi>` : ''}</small></span></button>`).join('');
    }

    function citDetail() {
        const c = C();
        const d = c.cur;
        if (c.busy && !d) return loading;
        if (!d) return `<div class="pt-cempty center"><b>اختر مواطنًا من القائمة.</b><small>الهوية، الرخص، المركبات، السوابق، الملاحظات.</small></div>`;
        const z = d.citizen;
        const openWarrant = PT.list(d.warrants).find((w) => !w.closed);
        const lic = (on, label) => `<em class="pt-tag ${on ? 'green' : 'grey'}">${label}${on ? ' ✓' : ' ✗'}</em>`;
        return `<div class="pt-fdetail" data-scroll="recdetail">
            <div class="pt-fhead">
                <i class="pt-fic big amber">${I('user', 22, 2)}</i>
                <div><small><bdi class="ltr">${esc(z.cid)}</bdi> · ${z.online ? '<em class="pt-tag green">في المدينة</em>' : '<em class="pt-tag grey">خارج المدينة</em>'}</small><h2>${esc(z.name)}</h2>
                    <span>${esc(z.gender)} · ${esc(z.dob || '—')} · ${esc(z.nationality || '')}${z.phone ? ` · <bdi class="ltr">${esc(z.phone)}</bdi>` : ''}</span></div>
                <div class="pt-factions">
                    ${openWarrant ? `<em class="pt-tag red">أمر قبض: ${esc(openWarrant.reason)}</em>` : ''}
                    ${d.prison ? `<em class="pt-tag red">${d.prison.escaped ? 'هارب من السجن' : 'في السجن'}</em>` : ''}
                    ${d.bills && d.bills.count ? `<em class="pt-tag amber">${d.bills.count} فاتورة غير مدفوعة · ${money(d.bills.total)}</em>` : ''}
                </div>
            </div>
            <div class="pt-ffields">
                <div class="pt-ffield"><small>العمل</small><p>${esc(z.job || '—')}${z.jobGrade ? ` · ${esc(z.jobGrade)}` : ''}</p></div>
                <div class="pt-ffield"><small>الرخص</small><p class="pt-tags">${lic(d.citizen.licences.weapon, 'سلاح')}
                    ${PT.list(d.citizen.driving).map((l) => `<span class="pt-licrow">${lic(l.has, l.short)}${l.suspended ? '<em class="pt-tag red">مسحوبة</em>' : ''}
                        <button class="pt-mini ${l.has ? 'danger' : 'green'}" data-act="recLicence" data-key="${esc(l.key)}" data-on="${l.has ? '0' : '1'}" title="${esc(l.label)}">${l.has ? 'سحب' : 'إرجاع'}</button></span>`).join('')}</p></div>
            </div>
            <h4 class="pt-h4">المركبات (${PT.list(d.vehicles).length})</h4>
            ${PT.list(d.vehicles).length ? `<div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>اللوحة</th><th>المركبة</th><th>أين</th></tr></thead><tbody>
                ${PT.list(d.vehicles).map((v) => `<tr><td class="ltr"><b>${esc(v.plate)}</b></td><td>${esc(v.label)}</td><td>${esc(v.state)}${v.garage ? ` · ${esc(v.garage)}` : ''}</td></tr>`).join('')}</tbody></table></div>` : '<p class="pt-mute">لا مركبات مسجلة باسمه.</p>'}
            <h4 class="pt-h4">السوابق (${PT.list(d.charges).length})</h4>
            ${PT.list(d.charges).length ? `<div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>التاريخ</th><th>المخالفات</th><th>الغرامة</th><th>السجن</th><th>الضابط</th></tr></thead><tbody>
                ${PT.list(d.charges).map((ch) => `<tr><td class="ltr">${esc(fmtDate(ch.created))}</td><td>${esc(ch.offences)}${ch.note ? `<br><small class="pt-mute">${esc(ch.note)}</small>` : ''}</td><td class="ltr">${ch.fine ? money(ch.fine) : '—'}</td><td class="ltr">${ch.jail ? ch.jail + ' د' : '—'}</td><td>${esc(ch.officer)}</td></tr>`).join('')}</tbody></table></div>` : '<p class="pt-mute">سجله نظيف.</p>'}
            ${PT.list(d.warrants).length ? `<h4 class="pt-h4">أوامر القبض</h4><div class="pt-notes">${PT.list(d.warrants).map((w) => `<div class="pt-note"><b>${esc(w.reason)}</b><span class="ltr">${esc(fmtStamp(w.created))}</span><p>${esc(w.officer)}${w.closed ? ` · أُغلق (${esc(w.closed_by || '')})` : ' · <em class="pt-tag red">مفتوح</em>'}</p></div>`).join('')}</div>` : ''}
            ${PT.list(d.reports).length || PT.list(d.cases).length ? `<h4 class="pt-h4">ورد اسمه في</h4><div class="pt-links">
                ${PT.list(d.reports).map((r) => `<button class="pt-pill" data-act="recOpenReport" data-id="${r.id}">${I('doc', 12, 2)} تقرير: ${esc(r.title)}</button>`).join('')}
                ${PT.list(d.cases).map((r) => `<button class="pt-pill" data-act="recOpenCase" data-id="${r.id}">${I('folder', 12, 2)} قضية: ${esc(r.title)}</button>`).join('')}</div>` : ''}
            <h4 class="pt-h4">ملاحظات الضباط (${PT.list(d.notes).length})</h4>
            <div class="pt-notes">${PT.list(d.notes).length ? PT.list(d.notes).map((n) => `<div class="pt-note"><b>${esc(n.officer)}</b><span class="ltr">${esc(fmtStamp(n.created))}</span>${n.officer_cid === d.me || d.isBoss ? `<button class="pt-mini danger pt-note-x" data-act="recNoteDelete" data-id="${n.id}">${I('trash', 12, 2)}</button>` : ''}<p>${esc(n.text)}</p></div>`).join('') : '<p class="pt-mute">لا توجد ملاحظات بعد.</p>'}</div>
            <div class="pt-inrow"><input class="pt-in" data-model="cit.note" data-enter="recNote" maxlength="500" value="${esc(c.note)}" placeholder="أضف ملاحظة عن هذا المواطن…"><button class="pt-btn ghost sm" data-act="recNote">إضافة</button></div>
        </div>`;
    }

    function citView() {
        const c = C();
        return `<div class="pt-appwin">${PT.head('السجلات', 'المواطنون', PT.metaBox('النتائج', String(PT.list(c.list).length)))}
            <div class="pt-abody split">
                ${listSide('', 0, `<div class="pt-search sm grow">${I('search', 14, 2)}<input class="pt-in bare" data-model="cit.q" data-enter="recCitSearch" value="${esc(c.q)}" placeholder="الاسم، رقم الهوية، الهاتف…"></div><button class="pt-btn primary xs" data-act="recCitSearch">بحث</button>`, citList())}
                <section class="pt-fmain">${citDetail()}</section>
            </div></div>`;
    }

    function openCitizen(cid) {
        const c = C();
        c.busy = true; c.note = '';
        render();
        call('citizenGet', cid).then((res) => {
            c.busy = false;
            if (!res.ok) { fail(res); render(); return; }
            c.cur = res.r;
            if (!PT.list(c.list).some((p) => p.cid === cid)) c.list = [{ cid, name: res.r.citizen.name, phone: res.r.citizen.phone }].concat(PT.list(c.list));
            S.scrolls.recdetail = 0;
            render();
        });
    }

    PT.app('citizens', {
        view: citView,
        enter() { if (!C().pending) { C().cur = null; } const p = C().pending; C().pending = null; if (p) openCitizen(p); else render(); },
        act: {
            recCitSearch: () => {
                const q = (C().q || '').trim();
                if (q.length < 2) return toast('اكتب حرفين على الأقل', 'error');
                call('citizenSearch', q).then((res) => { if (!res.ok) return fail(res); C().list = PT.list(res.r.list); render(); });
            },
            recCitizen: (el) => { if (S.app !== 'citizens') { C().pending = el.dataset.cid; PT.openApp('citizens'); } else openCitizen(el.dataset.cid); },
            recNote: () => {
                const c = C();
                const text = (c.note || '').trim();
                if (!c.cur || !text) return;
                call('citizenNote', c.cur.citizen.cid, text).then((res) => { if (!res.ok) return fail(res); c.cur.notes = PT.list(res.r.notes); c.note = ''; render(); });
            },
            recNoteDelete: (el) => {
                const c = C();
                call('citizenNoteDelete', Number(el.dataset.id)).then((res) => { if (!res.ok) return fail(res); if (c.cur) c.cur.notes = PT.list(res.r.notes); render(); });
            },
            recLicence: (el) => {
                const c = C();
                if (!c.cur) return;
                const on = el.dataset.on === '1';
                const key = el.dataset.key || 'car';
                const l = PT.list(c.cur.citizen.driving).find((x) => x.key === key) || { label: 'الرخصة' };
                ask({ title: on ? `إرجاع ${l.label}` : `سحب ${l.label}`, sub: 'المواطنون', text: on ? `${c.cur.citizen.name} يستعيد ${l.label}.` : `${c.cur.citizen.name} لن يستطيع استعمال ${l.label} قانونيًا حتى تُرجعها الشرطة، ولا يستطيع إعادة الاختبار.`, ok: on ? 'إرجاع' : 'سحب', danger: !on }, () => {
                    call('licenceSet', c.cur.citizen.cid, key, on).then((res) => { if (!res.ok) return fail(res); l.has = !!res.r.has; l.suspended = !on && l.passed; toast(on ? 'أُرجعت الرخصة' : 'سُحبت الرخصة', 'success'); render(); });
                });
            },
            recOpenReport: (el) => { S.rep.pending = Number(el.dataset.id); PT.openApp('reports'); },
            recOpenCase: (el) => { S.cas.pending = Number(el.dataset.id); PT.openApp('cases'); },
        },
    });

    // ------------------------------------------------------------------
    // Vehicles
    // ------------------------------------------------------------------
    S.veh = { q: '', list: null, cur: null };
    const V = () => S.veh;

    function vehView() {
        const v = V();
        const list = v.list == null ? `<div class="pt-cempty"><b>ابحث عن مركبة</b><small>برقم اللوحة أو اسم الموديل.</small></div>`
            : !v.list.length ? '<p class="pt-mute pad">لا نتيجة.</p>'
            : v.list.map((x, i) => `<button class="pt-frow2 ${v.cur === i ? 'on' : ''}" data-act="recVehSel" data-i="${i}">
                <i class="pt-fic ${x.bolo ? 'red' : 'amber'}">${I('car', 17, 2)}</i><span><b class="ltr">${esc(x.plate)}</b><small>${esc(x.label)} · ${esc(x.owner || 'بلا مالك')}</small></span>${x.bolo ? '<em class="pt-tag red">تعميم</em>' : ''}</button>`).join('');
        const x = v.cur != null ? v.list[v.cur] : null;
        const detail = !x ? `<div class="pt-cempty center"><b>اختر مركبة من القائمة.</b><small>المالك، مكانها، التعاميم عليها.</small></div>`
            : `<div class="pt-fdetail">
                <div class="pt-fhead"><i class="pt-fic big ${x.bolo ? 'red' : 'amber'}">${I('car', 22, 2)}</i>
                    <div><small>${esc(x.label)} · <bdi class="ltr">${esc(x.model)}</bdi></small><h2 class="ltr">${esc(x.plate)}</h2><span>${esc(x.state)}${x.garage ? ` · ${esc(x.garage)}` : ''}</span></div>
                    <div class="pt-factions">${x.bolo ? `<em class="pt-tag red">تعميم: ${esc(x.bolo)}</em>` : '<em class="pt-tag green">لا تعاميم</em>'}</div></div>
                <div class="pt-ffields">
                    <div class="pt-ffield"><small>المالك</small><p>${x.ownerCid ? `<button class="pt-pill" data-act="recCitizen" data-cid="${esc(x.ownerCid)}">${I('user', 12, 2.2)} ${esc(x.owner || x.ownerCid)}</button>` : '—'}</p></div>
                    <div class="pt-ffield"><small>الحالة</small><p>${esc(x.state)}</p></div>
                </div>
                <div class="pt-drow"><button class="pt-btn ghost sm" data-act="recBoloForPlate" data-plate="${esc(x.plate)}" data-label="${esc(x.label)}">${I('alert', 15, 2)} تعميم على هذه المركبة</button></div>
            </div>`;
        return `<div class="pt-appwin">${PT.head('السجلات', 'المركبات', PT.metaBox('النتائج', String(PT.list(v.list).length)))}
            <div class="pt-abody split">
                ${listSide('', 0, `<div class="pt-search sm grow">${I('search', 14, 2)}<input class="pt-in bare ltr" data-model="veh.q" data-enter="recVehSearch" value="${esc(v.q)}" placeholder="ABC 123 / sultan"></div><button class="pt-btn primary xs" data-act="recVehSearch">بحث</button>`, list)}
                <section class="pt-fmain">${detail}</section>
            </div></div>`;
    }

    PT.app('vehicles', {
        view: vehView,
        enter() { V().cur = null; render(); },
        act: {
            recVehSearch: () => {
                const q = (V().q || '').trim();
                if (q.length < 2) return toast('اكتب حرفين على الأقل', 'error');
                call('vehicleSearch', q).then((res) => { if (!res.ok) return fail(res); V().list = PT.list(res.r.list); V().cur = null; render(); });
            },
            recVehSel: (el) => { V().cur = Number(el.dataset.i); render(); },
            recCitizen: (el) => { C().pending = el.dataset.cid; PT.openApp('citizens'); },
            recBoloForPlate: (el) => { S.bolo.modal = { kind: 'vehicle', title: `${el.dataset.label} ${el.dataset.plate}`, text: '', plate: el.dataset.plate }; PT.openApp('bolos'); },
        },
    });

    // ------------------------------------------------------------------
    // Reports
    // ------------------------------------------------------------------
    S.rep = { q: '', list: null, cur: null, modal: null, pending: null };
    const R = () => S.rep;

    function repModal() {
        const m = R().modal;
        if (!m) return '';
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="recRepCancel"></div>
            <div class="pt-modal tall">
                <div class="pt-mhead"><div><small>${m.id ? 'تعديل التقرير' : 'تقرير جديد'}</small><h2>${esc(m.id ? m.title : 'تقرير حادثة / اعتقال')}</h2></div><button class="pt-x" data-act="recRepCancel">${I('x', 16, 2.2)}</button></div>
                <label class="pt-field"><span>العنوان</span><input class="pt-in" data-model="rep.modal.title" maxlength="120" value="${esc(m.title)}" placeholder="سطو على متجر 24/7 في ستروبيري"></label>
                <label class="pt-field"><span>المواطنون المعنيون (أسماء أو أرقام هوية، بينها فاصلة)</span><input class="pt-in" data-model="rep.modal.people" maxlength="300" value="${esc(m.people)}" placeholder="محمد الهاشمي، IQ7KLCTG"></label>
                <label class="pt-field grow"><span>التقرير</span>${ta('rep.modal.text', m.text, 'ماذا حدث، متى، أين، من كان هناك، ما الذي اتُّخذ…')}</label>
                <div class="pt-mfoot"><button class="pt-btn ghost" data-act="recRepCancel">إلغاء</button><button class="pt-btn primary" data-act="recRepSave">${I('check', 15, 2.2)} حفظ</button></div>
            </div></div>`;
    }

    function repView() {
        const r = R();
        const list = r.list == null ? loading : !r.list.length ? '<p class="pt-mute pad">لا توجد تقارير بعد.</p>'
            : r.list.map((x) => `<button class="pt-frow2 ${r.cur && r.cur.id === x.id ? 'on' : ''}" data-act="recRepOpen" data-id="${x.id}">
                <i class="pt-fic amber">${I('doc', 17, 2)}</i><span><b>${esc(x.title)}</b><small>${esc(x.officer)} · ${esc(fmtDate(x.created))}${x.people && x.people.length ? ` · ${esc(peopleText(x.people))}` : ''}</small></span></button>`).join('');
        const x = r.cur;
        const mine = x && S.me && (x.officerCid === S.me.cid || S.me.isBoss);
        const detail = !x ? `<div class="pt-cempty center"><b>اختر تقريرًا، أو اكتب تقريرًا جديدًا.</b><small>تقارير الحوادث والاعتقالات، مرتبطة بالمواطنين.</small></div>`
            : `<div class="pt-fdetail" data-scroll="recdetail">
                <div class="pt-fhead"><i class="pt-fic big amber">${I('doc', 22, 2)}</i>
                    <div><small>تقرير رقم <bdi class="ltr">${x.id}</bdi> · ${esc(x.officer)}</small><h2>${esc(x.title)}</h2><span class="ltr">${esc(fmtStamp(x.created))}${x.updated && x.updated !== x.created ? ` · عُدّل ${esc(fmtStamp(x.updated))}` : ''}</span></div>
                    <div class="pt-factions">${mine ? `<button class="pt-btn ghost sm" data-act="recRepEdit">${I('edit', 15, 2)} تعديل</button><button class="pt-btn danger sm" data-act="recRepDelete">${I('trash', 15, 2)} حذف</button>` : ''}</div></div>
                <div class="pt-ffields"><div class="pt-ffield area"><small>المواطنون</small><p class="pt-tags">${pills(x.people)}</p></div><div class="pt-ffield area"><small>التقرير</small><p>${esc(x.text)}</p></div></div>
            </div>`;
        return `<div class="pt-appwin">${PT.head('السجلات', 'التقارير', PT.metaBox('التقارير', String(PT.list(r.list).length)))}
            <div class="pt-abody split">
                ${listSide('', 0, `<div class="pt-search sm grow">${I('search', 14, 2)}<input class="pt-in bare" data-model="rep.q" data-enter="recRepSearch" value="${esc(r.q)}" placeholder="بحث"></div><button class="pt-btn primary xs" data-act="recRepNew">${I('plus', 13, 2.4)} جديد</button>`, list)}
                <section class="pt-fmain">${detail}</section>
            </div>${repModal()}</div>`;
    }

    function repLoad(q) { call('reports', q || '').then((res) => { if (res.ok) R().list = PT.list(res.r.list); else { R().list = []; fail(res); } render(); }); }
    function repOpen(id) { call('reportGet', id).then((res) => { if (!res.ok) return fail(res); R().cur = res.r; S.scrolls.recdetail = 0; render(); }); }

    PT.app('reports', {
        view: repView,
        enter() { const r = R(); r.q = ''; r.modal = null; if (!r.pending) r.cur = null; const p = r.pending; r.pending = null; repLoad(); if (p) repOpen(p); },
        back() { if (R().modal) { R().modal = null; render(); return true; } return false; },
        act: {
            recRepSearch: () => repLoad((R().q || '').trim()),
            recRepOpen: (el) => repOpen(Number(el.dataset.id)),
            recRepNew: () => { R().modal = { id: null, title: '', text: '', people: '' }; render(); },
            recRepEdit: () => { const x = R().cur; if (x) { R().modal = { id: x.id, title: x.title, text: x.text, people: peopleText(x.people) }; render(); } },
            recRepCancel: () => { R().modal = null; render(); },
            recRepSave: () => {
                const m = R().modal;
                if (!m) return;
                if ((m.title || '').trim().length < 2) return toast('اكتب عنوانًا', 'error');
                if (!(m.text || '').trim()) return toast('اكتب التقرير', 'error');
                call('reportSave', m.id, m.title.trim(), m.text.trim(), m.people || '').then((res) => {
                    if (!res.ok) return fail(res);
                    R().modal = null; R().cur = res.r.item; R().list = PT.list(res.r.list);
                    toast('حُفظ التقرير', 'success'); render();
                });
            },
            recRepDelete: () => {
                const x = R().cur;
                if (!x) return;
                ask({ title: 'حذف التقرير', sub: 'التقارير', text: `يُحذف "${x.title}" نهائيًا.`, ok: 'حذف', danger: true }, () => {
                    call('reportDelete', x.id).then((res) => { if (!res.ok) return fail(res); R().cur = null; R().list = PT.list(res.r.list); render(); });
                });
            },
            recCitizen: (el) => { C().pending = el.dataset.cid; PT.openApp('citizens'); },
        },
    });

    // ------------------------------------------------------------------
    // Warrants
    // ------------------------------------------------------------------
    S.war = { list: null, all: false, modal: null };
    const W = () => S.war;

    function warView() {
        const w = W();
        const rows = PT.list(w.list);
        const body = w.list == null ? loading : !rows.length ? `<div class="pt-empty big"><i class="pt-ic dark lg">${I('gavel', 34, 1.8)}</i><h3>لا أوامر قبض ${w.all ? '' : 'مفتوحة'}</h3><p>أمر القبض يظهر على سجل المواطن، ويبقى حتى يغلقه ضابط.</p></div>`
            : `<div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>المواطن</th><th>السبب</th><th>الضابط</th><th>منذ</th><th>الحالة</th><th></th></tr></thead><tbody>
                ${rows.map((x) => `<tr class="${x.closed ? 'locked' : ''}"><td><button class="pt-pill" data-act="recCitizen" data-cid="${esc(x.citizenid)}">${I('user', 12, 2.2)} ${esc(x.name)}</button></td><td>${esc(x.reason)}</td><td>${esc(x.officer)}</td><td class="ltr">${esc(fmtStamp(x.created))}</td>
                <td>${x.closed ? `<em class="pt-tag grey">أُغلق · ${esc(x.closed_by || '')}</em>` : '<em class="pt-tag red">مفتوح</em>'}</td>
                <td class="pt-acts">${x.closed ? '' : `<button class="pt-mini green" data-act="recWarClose" data-id="${x.id}" data-name="${esc(x.name)}">${I('check', 13, 2.4)} إغلاق</button>`}</td></tr>`).join('')}</tbody></table></div>`;
        const m = w.modal;
        const modal = !m ? '' : `<div class="pt-layer"><div class="pt-backdrop" data-act="recWarCancel"></div><div class="pt-modal small">
            <div class="pt-mhead"><div><small>أمر قبض</small><h2>أمر قبض جديد</h2></div><button class="pt-x" data-act="recWarCancel">${I('x', 16, 2.2)}</button></div>
            <label class="pt-field"><span>المواطن (الاسم أو رقم الهوية)</span><input class="pt-in" data-model="war.modal.who" maxlength="60" value="${esc(m.who)}" placeholder="محمد الهاشمي"></label>
            <label class="pt-field"><span>السبب</span><input class="pt-in" data-model="war.modal.reason" data-enter="recWarSave" maxlength="255" value="${esc(m.reason)}" placeholder="مطلوب للتحقيق في سطو مسلح"></label>
            <div class="pt-mfoot"><button class="pt-btn ghost" data-act="recWarCancel">إلغاء</button><button class="pt-btn primary" data-act="recWarSave">${I('plus', 15, 2.2)} إصدار</button></div></div></div>`;
        return `<div class="pt-appwin">${PT.head('السجلات', 'أوامر القبض', PT.metaBox('مفتوحة', String(rows.filter((x) => !x.closed).length)))}
            <div class="pt-abody pad">
                <div class="pt-logtop"><h2 class="pt-bh">أوامر القبض</h2><div class="pt-logf">
                    <button class="pt-btn ghost xs ${w.all ? 'on' : ''}" data-act="recWarAll">${w.all ? 'المفتوحة فقط' : 'إظهار المغلقة'}</button>
                    <button class="pt-btn primary xs" data-act="recWarNew">${I('plus', 13, 2.4)} أمر قبض جديد</button></div></div>
                ${body}
            </div>${modal}</div>`;
    }

    function warLoad() { call('warrants', W().all).then((res) => { if (res.ok) W().list = PT.list(res.r.list); else { W().list = []; fail(res); } render(); }); }

    PT.app('warrants', {
        view: warView,
        enter() { W().modal = null; W().all = false; warLoad(); },
        back() { if (W().modal) { W().modal = null; render(); return true; } return false; },
        act: {
            recWarAll: () => { W().all = !W().all; warLoad(); },
            recWarNew: () => { W().modal = { who: '', reason: '' }; render(); },
            recWarCancel: () => { W().modal = null; render(); },
            recWarSave: () => {
                const m = W().modal;
                if (!m) return;
                if (!(m.who || '').trim()) return toast('اكتب اسم المواطن', 'error');
                if (!(m.reason || '').trim()) return toast('اكتب السبب', 'error');
                call('warrantAdd', m.who.trim(), m.reason.trim()).then((res) => {
                    if (!res.ok) return fail(res);
                    W().modal = null; W().all = false; W().list = PT.list(res.r.list);
                    toast('صدر أمر القبض', 'success'); render();
                });
            },
            recWarClose: (el) => {
                ask({ title: 'إغلاق أمر القبض', sub: 'أوامر القبض', text: `${el.dataset.name}: لم يعد مطلوبًا.`, ok: 'إغلاق' }, () => {
                    call('warrantClose', Number(el.dataset.id)).then((res) => { if (!res.ok) return fail(res); W().list = PT.list(res.r.list); render(); });
                });
            },
            recCitizen: (el) => { C().pending = el.dataset.cid; PT.openApp('citizens'); },
        },
    });

    // ------------------------------------------------------------------
    // BOLOs
    // ------------------------------------------------------------------
    S.bolo = { list: null, all: false, modal: null };
    const B = () => S.bolo;

    function boloView() {
        const b = B();
        const rows = PT.list(b.list);
        const body = b.list == null ? loading : !rows.length ? `<div class="pt-empty big"><i class="pt-ic dark lg">${I('alert', 34, 1.8)}</i><h3>لا تعاميم ${b.all ? '' : 'مفتوحة'}</h3><p>التعميم يصل لكل من في الخدمة، ويظهر على المركبة عند البحث عنها.</p></div>`
            : `<div class="pt-bolos">${rows.map((x) => `<div class="pt-bolo ${x.closed ? 'off' : ''}">
                <i class="pt-fic ${x.kind === 'person' ? 'amber' : 'red'}">${I(x.kind === 'person' ? 'user' : 'car', 18, 2)}</i>
                <div><b>${esc(x.title)}</b>${x.plate ? ` <bdi class="pt-tag blue ltr">${esc(x.plate)}</bdi>` : ''}<p>${esc(x.text || '')}</p><small>${esc(x.officer)} · ${esc(fmtStamp(x.created))}${x.closed ? ` · أُغلق (${esc(x.closed_by || '')})` : ''}</small></div>
                ${x.closed ? '<em class="pt-tag grey">مغلق</em>' : `<button class="pt-mini green" data-act="recBoloClose" data-id="${x.id}" data-title="${esc(x.title)}">${I('check', 13, 2.4)} إغلاق</button>`}
            </div>`).join('')}</div>`;
        const m = b.modal;
        const modal = !m ? '' : `<div class="pt-layer"><div class="pt-backdrop" data-act="recBoloCancel"></div><div class="pt-modal">
            <div class="pt-mhead"><div><small>تعميم</small><h2>تعميم جديد</h2></div><button class="pt-x" data-act="recBoloCancel">${I('x', 16, 2.2)}</button></div>
            <div class="pt-field"><span>النوع</span><div class="pt-fchips inline"><button class="${m.kind === 'vehicle' ? 'on' : ''}" data-act="recBoloKind" data-k="vehicle">مركبة</button><button class="${m.kind === 'person' ? 'on' : ''}" data-act="recBoloKind" data-k="person">شخص</button></div></div>
            <label class="pt-field"><span>العنوان</span><input class="pt-in" data-model="bolo.modal.title" maxlength="120" value="${esc(m.title)}" placeholder="${m.kind === 'person' ? 'رجل بسترة حمراء هرب من موقع الحادث' : 'سلطان أسود، زجاج مظلل'}"></label>
            ${m.kind === 'vehicle' ? `<label class="pt-field"><span>اللوحة (إن عُرفت)</span><input class="pt-in ltr" data-model="bolo.modal.plate" maxlength="12" value="${esc(m.plate)}" placeholder="ABC 123"></label>` : ''}
            <label class="pt-field"><span>التفاصيل</span>${ta('bolo.modal.text', m.text, 'آخر مكان شوهد فيه، الاتجاه، ما فعل…', 500)}</label>
            <div class="pt-mfoot"><button class="pt-btn ghost" data-act="recBoloCancel">إلغاء</button><button class="pt-btn primary" data-act="recBoloSave">${I('plus', 15, 2.2)} نشر التعميم</button></div></div></div>`;
        return `<div class="pt-appwin">${PT.head('السجلات', 'التعاميم', PT.metaBox('مفتوحة', String(rows.filter((x) => !x.closed).length)))}
            <div class="pt-abody pad">
                <div class="pt-logtop"><h2 class="pt-bh">التعاميم</h2><div class="pt-logf">
                    <button class="pt-btn ghost xs ${b.all ? 'on' : ''}" data-act="recBoloAll">${b.all ? 'المفتوحة فقط' : 'إظهار المغلقة'}</button>
                    <button class="pt-btn primary xs" data-act="recBoloNew">${I('plus', 13, 2.4)} تعميم جديد</button></div></div>
                ${body}
            </div>${modal}</div>`;
    }

    function boloLoad() { call('bolos', B().all).then((res) => { if (res.ok) B().list = PT.list(res.r.list); else { B().list = []; fail(res); } render(); }); }

    PT.app('bolos', {
        view: boloView,
        enter() { B().all = false; boloLoad(); },
        back() { if (B().modal) { B().modal = null; render(); return true; } return false; },
        act: {
            recBoloAll: () => { B().all = !B().all; boloLoad(); },
            recBoloNew: () => { B().modal = { kind: 'vehicle', title: '', text: '', plate: '' }; render(); },
            recBoloKind: (el) => { if (B().modal) { B().modal.kind = el.dataset.k; render(); } },
            recBoloCancel: () => { B().modal = null; render(); },
            recBoloSave: () => {
                const m = B().modal;
                if (!m) return;
                if ((m.title || '').trim().length < 2) return toast('اكتب عنوانًا', 'error');
                call('boloAdd', m.kind, m.title.trim(), (m.text || '').trim(), (m.plate || '').trim()).then((res) => {
                    if (!res.ok) return fail(res);
                    B().modal = null; B().all = false; B().list = PT.list(res.r.list);
                    toast('نُشر التعميم', 'success'); render();
                });
            },
            recBoloClose: (el) => {
                ask({ title: 'إغلاق التعميم', sub: 'التعاميم', text: el.dataset.title, ok: 'إغلاق' }, () => {
                    call('boloClose', Number(el.dataset.id)).then((res) => { if (!res.ok) return fail(res); B().list = PT.list(res.r.list); render(); });
                });
            },
        },
    });

    // ------------------------------------------------------------------
    // Cases
    // ------------------------------------------------------------------
    S.cas = { q: '', all: false, list: null, cur: null, modal: null, note: '', photo: null, pending: null };
    const K = () => S.cas;

    function casModal() {
        const m = K().modal;
        if (!m) return '';
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="recCasCancel"></div>
            <div class="pt-modal tall">
                <div class="pt-mhead"><div><small>${m.id ? 'تعديل القضية' : 'قضية جديدة'}</small><h2>${esc(m.id ? m.title : 'ملف قضية')}</h2></div><button class="pt-x" data-act="recCasCancel">${I('x', 16, 2.2)}</button></div>
                <label class="pt-field"><span>العنوان</span><input class="pt-in" data-model="cas.modal.title" maxlength="120" value="${esc(m.title)}" placeholder="سرقة بنك باسيفيك"></label>
                <div class="pt-frow">
                    <label class="pt-field"><span>المشتبه بهم / المعنيون</span><input class="pt-in" data-model="cas.modal.people" maxlength="300" value="${esc(m.people)}" placeholder="أسماء أو أرقام هوية، بينها فاصلة"></label>
                    <label class="pt-field"><span>الضباط المكلّفون</span><input class="pt-in" data-model="cas.modal.officers" maxlength="300" value="${esc(m.officers)}" placeholder="أسماء الزملاء، بينها فاصلة"></label>
                </div>
                ${m.id ? `<div class="pt-field"><span>الحالة</span><div class="pt-fchips inline"><button class="${m.status === 'open' ? 'on' : ''}" data-act="recCasStatus" data-s="open">مفتوحة</button><button class="${m.status === 'closed' ? 'on' : ''}" data-act="recCasStatus" data-s="closed">مغلقة</button></div></div>` : ''}
                <label class="pt-field grow"><span>الملخص</span>${ta('cas.modal.text', m.text, 'ما القضية، ما لدينا، ما التالي…')}</label>
                <div class="pt-mfoot"><button class="pt-btn ghost" data-act="recCasCancel">إلغاء</button><button class="pt-btn primary" data-act="recCasSave">${I('check', 15, 2.2)} حفظ</button></div>
            </div></div>`;
    }

    function photoPicker() {
        const k = K();
        if (!k.photo) return '';
        const photos = PT.list(k.photo.list);
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="recCasPhotoCancel"></div>
            <div class="pt-modal wide">
                <div class="pt-mhead"><div><small>الأدلة</small><h2>صورة من المعرض</h2></div><button class="pt-x" data-act="recCasPhotoCancel">${I('x', 16, 2.2)}</button></div>
                <label class="pt-field"><span>وصف (اختياري)</span><input class="pt-in" data-model="cas.photo.text" maxlength="200" value="${esc(k.photo.text)}" placeholder="سيارة الهروب، آثار على الباب…"></label>
                <div class="pt-gpick">${photos.length ? photos.map((p) => `<button class="pt-gcell ${k.photo.url === p.url ? 'on' : ''}" data-act="recCasPhotoPick" data-url="${esc(p.url)}"><img src="${esc(p.url)}" alt=""></button>`).join('') : '<p class="pt-mute">لا صور في معرض الكاميرا بعد. صوّر بكاميرا التابلت أولًا.</p>'}</div>
                <div class="pt-mfoot"><button class="pt-btn ghost" data-act="recCasPhotoCancel">إلغاء</button><button class="pt-btn primary" data-act="recCasPhotoSave" ${k.photo.url ? '' : 'disabled'}>${I('plus', 15, 2.2)} إضافة إلى القضية</button></div>
            </div></div>`;
    }

    function casView() {
        const k = K();
        const list = k.list == null ? loading : !k.list.length ? '<p class="pt-mute pad">لا توجد قضايا.</p>'
            : k.list.map((x) => `<button class="pt-frow2 ${k.cur && k.cur.id === x.id ? 'on' : ''}" data-act="recCasOpen" data-id="${x.id}">
                <i class="pt-fic ${x.status === 'open' ? 'amber' : ''}">${I('folder', 17, 2)}</i><span><b>${esc(x.title)}</b><small>${esc(x.officer)} · ${esc(fmtDate(x.updated || x.created))}${x.people && x.people.length ? ` · ${esc(peopleText(x.people))}` : ''}</small></span>${x.status === 'open' ? '<em class="pt-tag amber">مفتوحة</em>' : '<em class="pt-tag grey">مغلقة</em>'}</button>`).join('');
        const x = k.cur;
        const mine = x && S.me && (x.officerCid === S.me.cid || S.me.isBoss);
        const items = x ? PT.list(x.items) : [];
        const detail = !x ? `<div class="pt-cempty center"><b>اختر قضية، أو افتح قضية جديدة.</b><small>الأدلة، المشتبه بهم، الضباط المكلّفون وحالة القضية.</small></div>`
            : `<div class="pt-fdetail" data-scroll="recdetail">
                <div class="pt-fhead"><i class="pt-fic big ${x.status === 'open' ? 'amber' : ''}">${I('folder', 22, 2)}</i>
                    <div><small>قضية رقم <bdi class="ltr">${x.id}</bdi> · فتحها ${esc(x.officer)}</small><h2>${esc(x.title)}</h2><span class="ltr">${esc(fmtStamp(x.created))}</span></div>
                    <div class="pt-factions">${x.status === 'open' ? '<em class="pt-tag amber">مفتوحة</em>' : '<em class="pt-tag grey">مغلقة</em>'}<div class="pt-drow"><button class="pt-btn ghost sm" data-act="recCasEdit">${I('edit', 15, 2)} تعديل</button>${mine ? `<button class="pt-btn danger sm" data-act="recCasDelete">${I('trash', 15, 2)}</button>` : ''}</div></div></div>
                <div class="pt-ffields">
                    <div class="pt-ffield"><small>المشتبه بهم / المعنيون</small><p class="pt-tags">${pills(x.people)}</p></div>
                    <div class="pt-ffield"><small>الضباط المكلّفون</small><p class="pt-tags">${PT.list(x.officers).map((o) => `<em class="pt-tag blue">${esc(o.name)}</em>`).join(' ') || '<span class="pt-mute">—</span>'}</p></div>
                    <div class="pt-ffield area"><small>الملخص</small><p>${esc(x.text || '—')}</p></div>
                </div>
                <h4 class="pt-h4">الأدلة والملاحظات (${items.length})</h4>
                <div class="pt-notes">${items.length ? items.map((it) => it.kind === 'photo'
                    ? `<div class="pt-note photo"><button class="pt-evid" data-act="view" data-url="${esc(it.url)}"><img src="${esc(it.url)}" alt=""></button><div><b>${esc(it.officer)}</b><span class="ltr">${esc(fmtStamp(it.created))}</span>${it.officer_cid === (S.me && S.me.cid) || (S.me && S.me.isBoss) ? `<button class="pt-mini danger pt-note-x" data-act="recCasItemDelete" data-id="${it.id}">${I('trash', 12, 2)}</button>` : ''}<p>${esc(it.text || 'صورة')}</p></div></div>`
                    : `<div class="pt-note"><b>${esc(it.officer)}</b><span class="ltr">${esc(fmtStamp(it.created))}</span>${it.officer_cid === (S.me && S.me.cid) || (S.me && S.me.isBoss) ? `<button class="pt-mini danger pt-note-x" data-act="recCasItemDelete" data-id="${it.id}">${I('trash', 12, 2)}</button>` : ''}<p>${esc(it.text)}</p></div>`).join('') : '<p class="pt-mute">لا شيء بعد.</p>'}</div>
                <div class="pt-inrow"><input class="pt-in" data-model="cas.note" data-enter="recCasNote" maxlength="500" value="${esc(k.note)}" placeholder="أضف ملاحظة…"><button class="pt-btn ghost sm" data-act="recCasNote">إضافة</button><button class="pt-btn ghost sm" data-act="recCasPhoto">${I('camera', 15, 2)} صورة</button></div>
            </div>`;
        return `<div class="pt-appwin">${PT.head('السجلات', 'القضايا', PT.metaBox('القضايا', String(PT.list(k.list).length)))}
            <div class="pt-abody split">
                ${listSide('', 0, `<div class="pt-search sm grow">${I('search', 14, 2)}<input class="pt-in bare" data-model="cas.q" data-enter="recCasSearch" value="${esc(k.q)}" placeholder="بحث"></div><button class="pt-btn ghost xs ${k.all ? 'on' : ''}" data-act="recCasAll" title="المغلقة أيضًا">${I('archive', 13, 2)}</button><button class="pt-btn primary xs" data-act="recCasNew">${I('plus', 13, 2.4)} جديدة</button>`, list)}
                <section class="pt-fmain">${detail}</section>
            </div>${casModal()}${photoPicker()}</div>`;
    }

    function casLoad() { call('cases', (K().q || '').trim(), K().all).then((res) => { if (res.ok) K().list = PT.list(res.r.list); else { K().list = []; fail(res); } render(); }); }
    function casOpen(id) { K().note = ''; call('caseGet', id).then((res) => { if (!res.ok) return fail(res); K().cur = res.r; S.scrolls.recdetail = 0; render(); }); }

    PT.app('cases', {
        view: casView,
        enter() { const k = K(); k.q = ''; k.modal = null; k.photo = null; if (!k.pending) k.cur = null; const p = k.pending; k.pending = null; casLoad(); if (p) casOpen(p); },
        back() { const k = K(); if (k.modal || k.photo) { k.modal = null; k.photo = null; render(); return true; } return false; },
        act: {
            recCasSearch: () => casLoad(),
            recCasAll: () => { K().all = !K().all; casLoad(); },
            recCasOpen: (el) => casOpen(Number(el.dataset.id)),
            recCasNew: () => { K().modal = { id: null, title: '', text: '', people: '', officers: '', status: 'open' }; render(); },
            recCasEdit: () => { const x = K().cur; if (x) { K().modal = { id: x.id, title: x.title, text: x.text || '', people: peopleText(x.people), officers: peopleText(x.officers), status: x.status }; render(); } },
            recCasStatus: (el) => { if (K().modal) { K().modal.status = el.dataset.s; render(); } },
            recCasCancel: () => { K().modal = null; render(); },
            recCasSave: () => {
                const m = K().modal;
                if (!m) return;
                if ((m.title || '').trim().length < 2) return toast('اكتب عنوانًا', 'error');
                call('caseSave', m.id, m.title.trim(), (m.text || '').trim(), m.people || '', m.officers || '', m.status).then((res) => {
                    if (!res.ok) return fail(res);
                    K().modal = null; K().cur = res.r.item; K().list = PT.list(res.r.list);
                    toast('حُفظت القضية', 'success'); render();
                });
            },
            recCasDelete: () => {
                const x = K().cur;
                if (!x) return;
                ask({ title: 'حذف القضية', sub: 'القضايا', text: `تُحذف "${x.title}" مع أدلتها نهائيًا.`, ok: 'حذف', danger: true }, () => {
                    call('caseDelete', x.id).then((res) => { if (!res.ok) return fail(res); K().cur = null; K().list = PT.list(res.r.list); render(); });
                });
            },
            recCasNote: () => {
                const k = K();
                const text = (k.note || '').trim();
                if (!k.cur || !text) return;
                call('caseItem', k.cur.id, 'note', text).then((res) => { if (!res.ok) return fail(res); k.cur.items = PT.list(res.r.items); k.note = ''; render(); });
            },
            recCasPhoto: () => {
                const k = K();
                if (!k.cur) return;
                k.photo = { list: null, url: '', text: '' };
                render();
                call('gallery').then((res) => { k.photo.list = res.ok ? PT.list(res.r) : []; render(); });
            },
            recCasPhotoPick: (el) => { if (K().photo) { K().photo.url = el.dataset.url; render(); } },
            recCasPhotoCancel: () => { K().photo = null; render(); },
            recCasPhotoSave: () => {
                const k = K();
                if (!k.cur || !k.photo || !k.photo.url) return;
                call('caseItem', k.cur.id, 'photo', (k.photo.text || '').trim(), k.photo.url).then((res) => { if (!res.ok) return fail(res); k.cur.items = PT.list(res.r.items); k.photo = null; render(); });
            },
            recCasItemDelete: (el) => {
                const k = K();
                call('caseItemDelete', Number(el.dataset.id)).then((res) => { if (!res.ok) return fail(res); if (k.cur) k.cur.items = PT.list(res.r.items); render(); });
            },
            recCitizen: (el) => { C().pending = el.dataset.cid; PT.openApp('citizens'); },
        },
    });
})();
