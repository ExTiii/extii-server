// EX_Tii Police tablet — Calendar (Staff Schedule, like the video): the month, the team's entries,
// add one with a title, a date and time and a colour.
(() => {
    const { S, I, esc, call, render, toast, fail, ask, pad, DAYS, MONTHS, fmtTime } = PT;

    const today = new Date();
    S.cal = { y: today.getFullYear(), m: today.getMonth(), items: [], modal: null, detail: null, loaded: false };
    const K = () => S.cal;

    // the 6 weeks shown for this month (weeks start on Sunday)
    function cells(y, m) {
        const first = new Date(y, m, 1);
        const start = new Date(y, m, 1 - first.getDay());
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
        return out;
    }
    const keyOf = (d) => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    const isoDate = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    const dayTitle = (d) => `${DAYS[d.getDay()]}، ${d.getDate()} ${MONTHS[d.getMonth()]}`;

    function load() {
        const c = K();
        const all = cells(c.y, c.m);
        const from = Math.floor(all[0].getTime() / 1000);
        const to = Math.floor(new Date(all[41].getFullYear(), all[41].getMonth(), all[41].getDate() + 1).getTime() / 1000);
        call('calendar', from, to).then((res) => {
            if (res.ok) { c.items = PT.list(res.r); c.loaded = true; }
            render();
        });
    }

    function monthView() {
        const c = K();
        const all = cells(c.y, c.m);
        const byDay = {};
        PT.list(c.items).forEach((e) => {
            const k = keyOf(PT.dateOf(e.at));
            (byDay[k] = byDay[k] || []).push(e);
        });
        const todayKey = keyOf(PT.dateOf(PT.now()));
        return `<div class="pt-calgrid">
            ${DAYS.map((d) => `<div class="pt-calday">${esc(d)}</div>`).join('')}
            ${all.map((d) => {
                const k = keyOf(d);
                const list = byDay[k] || [];
                const out = d.getMonth() !== c.m;
                return `<div class="pt-calcell ${out ? 'out' : ''} ${k === todayKey ? 'today' : ''}" data-act="calAddDay" data-d="${isoDate(d)}">
                    <b>${d.getDate()}</b>
                    ${list.slice(0, 3).map((e) => `<button class="pt-calev" style="--c:${esc(e.color)}" data-act="calOpen" data-id="${e.id}"><span class="ltr">${esc(fmtTime(e.at))}</span>${esc(e.title)}</button>`).join('')}
                    ${list.length > 3 ? `<small>+${list.length - 3} أخرى</small>` : ''}
                </div>`;
            }).join('')}
        </div>`;
    }

    function addModal() {
        const m = K().modal;
        if (!m) return '';
        const colors = S.cfg.colors && S.cfg.colors.length ? S.cfg.colors : ['#3b8cf0'];
        const d = m.date ? new Date(`${m.date}T00:00`) : new Date();
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="calClose"></div>
            <div class="pt-modal">
                <div class="pt-mhead"><div><small>إضافة موعد</small><h2>${esc(isNaN(d) ? 'موعد جديد' : dayTitle(d))}</h2></div><button class="pt-x" data-act="calClose">${I('x', 16, 2.2)}</button></div>
                <label class="pt-field"><span>العنوان</span><input class="pt-in" data-model="cal.modal.title" data-enter="calSave" maxlength="80" value="${esc(m.title)}" placeholder="اجتماع الدورية، تدريب، دورية مشتركة…"></label>
                <div class="pt-frow">
                    <label class="pt-field"><span>التاريخ</span><input class="pt-in ltr" type="date" data-model="cal.modal.date" data-live="1" value="${esc(m.date)}"></label>
                    <label class="pt-field"><span>الوقت</span><input class="pt-in ltr" type="time" data-model="cal.modal.time" value="${esc(m.time)}"></label>
                </div>
                <div class="pt-field"><span>اللون</span><div class="pt-swatches">
                    <i class="pt-swnow" style="background:${esc(m.color)}"></i>
                    ${colors.map((col) => `<button class="pt-sw ${col === m.color ? 'on' : ''}" style="background:${esc(col)}" data-act="calColor" data-c="${esc(col)}"></button>`).join('')}
                </div></div>
                <div class="pt-mfoot"><button class="pt-btn ghost" data-act="calClear">مسح</button><button class="pt-btn primary" data-act="calSave">${I('plus', 15, 2.2)} إضافة للتقويم</button></div>
            </div></div>`;
    }

    function detailModal() {
        const e = K().detail;
        if (!e) return '';
        const d = PT.dateOf(e.at);
        const canDelete = e.mine || (S.me && S.me.isBoss);
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="calClose"></div>
            <div class="pt-modal small">
                <div class="pt-mhead"><div><small>موعد</small><h2>${esc(e.title)}</h2></div><button class="pt-x" data-act="calClose">${I('x', 16, 2.2)}</button></div>
                <dl class="pt-dl wide">
                    <dt>اليوم</dt><dd>${esc(dayTitle(d))}</dd>
                    <dt>الوقت</dt><dd class="ltr">${esc(fmtTime(e.at))}</dd>
                    <dt>أضافه</dt><dd>${esc(e.name)}</dd>
                </dl>
                <div class="pt-mfoot">${canDelete ? `<button class="pt-btn danger" data-act="calDelete">${I('trash', 15, 2)} حذف</button>` : ''}<button class="pt-btn ghost" data-act="calClose">إغلاق</button></div>
            </div></div>`;
    }

    function view() {
        const c = K();
        const count = PT.list(c.items).filter((e) => PT.dateOf(e.at).getMonth() === c.m).length;
        return `<div class="pt-appwin">${PT.head('جدول الأفراد', 'التقويم', PT.metaBox('هذا الشهر', `${count} موعد`))}
            <div class="pt-abody pad">
                <div class="pt-caltop">
                    <div class="pt-calnav">
                        <button class="pt-iconbtn" data-act="calMove" data-d="-1" title="الشهر السابق">${I('back', 16, 2.2)}</button>
                        <h2>${esc(MONTHS[c.m])} <span class="ltr">${c.y}</span></h2>
                        <button class="pt-iconbtn" data-act="calMove" data-d="1" title="الشهر التالي">${I('next', 16, 2.2)}</button>
                        <button class="pt-btn ghost xs" data-act="calToday">اليوم</button>
                    </div>
                    <button class="pt-btn primary sm" data-act="calAdd">${I('plus', 15, 2.2)} إضافة موعد</button>
                </div>
                ${monthView()}
            </div>${addModal()}${detailModal()}</div>`;
    }

    function newEntry(date) {
        const colors = S.cfg.colors && S.cfg.colors.length ? S.cfg.colors : ['#3b8cf0'];
        K().modal = { title: '', date: date || isoDate(PT.dateOf(PT.now())), time: '20:00', color: colors[0] };
        render();
    }

    PT.app('calendar', {
        view,
        enter() {
            const d = PT.dateOf(PT.now());
            K().y = d.getFullYear();
            K().m = d.getMonth();
            K().modal = null;
            K().detail = null;
            load();
        },
        back() {
            if (K().modal || K().detail) { K().modal = null; K().detail = null; render(); return true; }
            return false;
        },
        act: {
            calMove: (el) => {
                const c = K();
                const d = new Date(c.y, c.m + Number(el.dataset.d), 1);
                c.y = d.getFullYear();
                c.m = d.getMonth();
                c.items = [];
                render();
                load();
            },
            calToday: () => { const d = PT.dateOf(PT.now()); K().y = d.getFullYear(); K().m = d.getMonth(); load(); },
            calAdd: () => newEntry(),
            calAddDay: (el, ev) => { if (ev && ev.target.closest('.pt-calev')) return; newEntry(el.dataset.d); },
            calOpen: (el, ev) => {
                if (ev) ev.stopPropagation();
                K().detail = PT.list(K().items).find((e) => e.id === Number(el.dataset.id)) || null;
                render();
            },
            calClose: () => { K().modal = null; K().detail = null; render(); },
            calColor: (el) => { if (K().modal) { K().modal.color = el.dataset.c; render(); } },
            calClear: () => { const m = K().modal; if (m) { m.title = ''; m.time = '20:00'; render(); } },
            calSave: () => {
                const m = K().modal;
                if (!m) return;
                const title = (m.title || '').trim();
                if (title.length < 2) return toast(PT.ERR.title, 'error');
                const at = new Date(`${m.date}T${m.time || '00:00'}`);
                if (isNaN(at)) return toast(PT.ERR.date, 'error');
                call('calendarAdd', { title, at: Math.floor(at.getTime() / 1000), color: m.color }).then((res) => {
                    if (!res.ok) return fail(res);
                    K().modal = null;
                    K().y = at.getFullYear();
                    K().m = at.getMonth();
                    toast('أُضيف الموعد');
                    load();
                });
            },
            calDelete: () => {
                const e = K().detail;
                if (!e) return;
                ask({ title: 'حذف الموعد؟', text: e.title, ok: 'حذف', danger: true }, () => {
                    call('calendarDelete', e.id).then((res) => {
                        if (!res.ok) return fail(res);
                        K().detail = null;
                        toast('حُذف الموعد');
                        load();
                    });
                });
            },
        },
    });
})();
