// EX_Tii Police tablet — CCTV: the cameras around the city; pick one and the tablet looks through it.
(() => {
    const { S, I, esc, call, render, fail, post } = PT;

    S.cctv = { list: null, q: '' };
    const V = () => S.cctv;

    function load() {
        call('cctv').then((res) => {
            if (res.ok) V().list = PT.list(res.r.cameras); else { V().list = []; fail(res); }
            render();
        });
    }

    function view() {
        const v = V();
        const q = (v.q || '').trim().toLowerCase();
        const all = PT.list(v.list);
        const rows = all.filter((c) => !q || String(c.label).toLowerCase().includes(q) || String(c.area || '').toLowerCase().includes(q));
        let body;
        if (v.list == null) body = '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
        else if (!rows.length) body = '<p class="pt-mute pad">لا توجد كاميرا بهذا الاسم.</p>';
        else {
            // grouped by kind: the city's own cameras, banks, shops, gas stations, the admins' extras
            const KIND = { city: ['المدينة', 'building'], bank: ['البنوك', 'landmark'], shop: ['المتاجر', 'store'], fuel: ['محطات الوقود', 'gas-pump'], custom: ['كاميرات إضافية', 'video'] };
            const order = ['city', 'bank', 'shop', 'fuel', 'custom'];
            body = order.map((k) => {
                const list = rows.filter((c) => (c.kind || 'city') === k);
                if (!list.length) return '';
                const [title, icon] = KIND[k];
                return `<h4 class="pt-h4">${title} <span class="pt-mute">(${list.length})</span></h4><div class="pt-cctvs">${list.map((c) => `<button class="pt-cctv" data-act="cctvOpen" data-id="${c.id}">
                    <i>${I(icon, 18, 2)}</i><span><b>${esc(c.label)}</b><small>CAM ${String(c.id).padStart(2, '0')}${c.area ? ' · ' + esc(c.area) : ''}</small></span>
                    <em class="pt-tag green">متصلة</em></button>`).join('')}</div>`;
            }).join('');
        }
        return `<div class="pt-appwin">${PT.head('المراقبة', 'الكاميرات', PT.metaBox('الكاميرات', String(all.length)))}
            <div class="pt-abody pad">
                <div class="pt-logtop"><h2 class="pt-bh">كاميرات المدينة</h2>
                    <div class="pt-logf"><div class="pt-search sm">${I('search', 14, 2)}<input class="pt-in bare" data-model="cctv.q" data-live="1" value="${esc(v.q)}" placeholder="بحث"></div></div></div>
                ${body}
                <p class="pt-hint">اضغط كاميرا لتنظر من خلالها: الفأرة تحرّكها، العجلة تقرّب، الأسهم تنقل بين الكاميرات، Esc يرجعك إلى التابلت.</p>
            </div></div>`;
    }

    PT.app('cctv', {
        view,
        enter() { V().q = ''; load(); },
        act: {
            cctvOpen: (el) => {
                const id = Number(el.dataset.id);
                if (!PT.inGame) { PT.toast('في اللعبة: التابلت يختفي وتنظر من الكاميرا'); return; }
                post('ptCctv', { index: id });
            },
        },
    });
})();
