// EX_Tii Police tablet — Prison: who is inside, how long is left, who escaped; release one early.
(() => {
    const { S, I, esc, call, render, toast, fail, ask, fmtStamp, post } = PT;

    S.prison = { list: null, q: '' };
    const R = () => S.prison;

    const clock = (s) => { s = Math.max(0, Math.floor(s || 0)); const m = Math.floor(s / 60); return `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };

    function load() {
        call('prisonList').then((res) => {
            if (res.ok) R().list = PT.list(res.r.inmates); else { R().list = []; fail(res); }
            render();
        });
    }

    function view() {
        const r = R();
        const q = (r.q || '').trim().toLowerCase();
        const all = PT.list(r.list);
        const rows = all.filter((x) => !q || String(x.name).toLowerCase().includes(q) || String(x.officer || '').toLowerCase().includes(q));
        const escaped = all.filter((x) => x.escaped).length;
        let body;
        if (r.list == null) body = '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
        else if (!rows.length) body = `<div class="pt-empty big"><i class="pt-ic dark lg">${I('lock', 34, 1.8)}</i><h3>${all.length ? 'لا نتيجة' : 'السجن فارغ'}</h3><p>${all.length ? 'لا سجين بهذا الاسم.' : 'لا يوجد أحد في بولينغبروك الآن. يُسجن الشخص من محضر المخالفة عند بوابة السجن.'}</p></div>`;
        else body = `<div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>السجين</th><th>الحكم</th><th>الباقي</th><th>الحالة</th><th>الضابط</th><th>منذ</th><th>إجراءات</th></tr></thead><tbody>
            ${rows.map((x) => `<tr><td><b>${esc(x.name)}</b></td><td class="ltr">${x.minutes} د</td><td class="ltr">${clock(x.remaining)}</td>
                <td>${x.escaped ? '<em class="pt-tag red">هارب</em>' : x.online ? '<em class="pt-tag green">في السجن</em>' : '<em class="pt-tag grey">خارج المدينة</em>'}</td>
                <td>${esc(x.officer || '')}</td><td class="ltr">${esc(fmtStamp(x.started))}</td>
                <td class="pt-acts"><button class="pt-mini green" data-act="prisonRelease" data-cid="${esc(x.cid)}" data-name="${esc(x.name)}">${I('check', 13, 2.4)} إطلاق سراح</button><button class="pt-mini" data-act="prisonLocker" data-cid="${esc(x.cid)}" title="أغراضه">${I('archive', 13, 2)}</button></td></tr>`).join('')}
            </tbody></table></div>`;
        return `<div class="pt-appwin">${PT.head('السجن', 'بولينغبروك', PT.metaBox('السجناء', String(all.length)), escaped ? `<em class="pt-tag red">${escaped} هارب</em>` : '')}
            <div class="pt-abody pad">
                <div class="pt-logtop"><h2 class="pt-bh">السجناء</h2>
                    <div class="pt-logf"><button class="pt-btn ghost xs" data-act="prisonReload">تحديث</button>
                    <div class="pt-search sm">${I('search', 14, 2)}<input class="pt-in bare" data-model="prison.q" data-live="1" value="${esc(r.q)}" placeholder="بحث"></div></div></div>
                ${body}
                <p class="pt-hint">المدة تنقص فقط وهو في المدينة. الأعمال في ساحة السجن تنقص دقائق. من يخرج من أرض السجن يُسجّل هاربًا ويُبلَّغ كل من في الخدمة.</p>
            </div></div>`;
    }

    PT.app('prison', {
        view,
        enter() { R().q = ''; load(); },
        act: {
            prisonReload: () => load(),
            prisonLocker: (el) => { if (PT.inGame) post('ptPrisonLocker', { cid: el.dataset.cid }); else toast('في اللعبة: يفتح خزانة أغراضه'); },
            prisonRelease: (el) => {
                ask({ title: 'إطلاق سراح', sub: 'السجن', text: `يخرج ${el.dataset.name} الآن ويأخذ أغراضه.`, ok: 'إطلاق سراح' }, () => {
                    call('prisonRelease', el.dataset.cid).then((res) => {
                        if (!res.ok) return fail(res);
                        R().list = PT.list(res.r.inmates);
                        toast('أُطلق سراحه', 'success');
                        render();
                    });
                });
            },
        },
    });
})();
