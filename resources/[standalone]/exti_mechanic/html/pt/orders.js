// EX_Tii Mechanic tablet — الطلبات (the tuning orders): what the customers picked at the tuning
// bay and paid for. Take an order, see the parts it needs, follow what is installed; cancel and
// pay back what is not installed (the one who took it, or the manager). The manager sets the prices.
(() => {
    const { S, I, esc, call, render, toast, fail, ask, money, fmtStamp, ago } = PT;

    S.tune = { r: null, tab: 'open', open: null, prices: null, pricesBoss: false, max: 250000, edit: {}, busy: false };
    const O = () => S.tune;

    function load() {
        call('tuneOrders').then((res) => {
            if (res.ok) O().r = res.r; else { O().r = { open: [], done: [] }; fail(res); }
            render();
        });
    }

    function loadPrices() {
        call('tunePrices').then((res) => {
            if (!res.ok) { O().prices = []; return fail(res); }
            O().prices = PT.list(res.r.list);
            O().pricesBoss = !!res.r.isBoss;
            O().max = res.r.max || 250000;
            O().edit = {};
            O().prices.forEach((p) => { O().edit[p.key] = String(p.price); });
            render();
        });
    }

    function lineRow(l) {
        return `<div class="to-line ${l.done ? 'done' : ''}">
            <span>${l.done ? I('check', 13, 2.6) : '<i class="to-dot"></i>'}${l.color ? `<u style="--c:rgb(${PT.list(l.color).join(',')})"></u>` : ''}${esc(l.label)}</span>
            <small>${l.done ? `ركّبه ${esc(l.by || '')}` : l.item && l.count ? `${l.count}× ${esc(l.itemLabel || l.item)}` : 'بدون قطع'}</small>
            <b class="ltr">${money(l.price)}</b>
        </div>`;
    }

    function card(o, openList) {
        const r = O().r;
        const lines = PT.list(o.lines);
        const done = lines.filter((l) => l.done).length;
        const isOpen = O().open === o.id;
        const mine = o.mcid && o.mcid === r.me;
        let state;
        if (o.status === 'cancelled') state = '<em class="pt-tag grey">أُلغي</em>';
        else if (o.status === 'done') state = `<em class="pt-tag green">انتهى${o.refunded ? ' (أُلغي جزء)' : ''}</em>`;
        else if (!o.mcid) state = '<em class="pt-tag amber">ينتظر ميكانيكي</em>';
        else state = `<em class="pt-tag ${mine ? 'green' : 'blue'}">${mine ? 'طلبك' : `مع ${esc(o.mname || '')}`}</em>`;
        let body = '';
        if (isOpen) {
            const need = PT.list(o.need);
            body = `<div class="to-body">
                <div class="to-lines">${lines.map(lineRow).join('')}</div>
                ${openList && need.length ? `<div class="to-need"><h4>القطع المطلوبة لما بقي</h4>${need.map((n) => `<div><span>${esc(n.label)}</span><b class="${n.have >= n.count ? 'ok' : 'bad'}">${n.count} · معك ${n.have}</b></div>`).join('')}
                    <p class="pt-hint">ما ينقصك: اطلبه من متجر القطع أو خذه من رفّ القطع.</p></div>` : ''}
                ${openList ? `<p class="pt-hint">التركيب: قف بجانب السيارة داخل الورشة واضغط E ← تختار التعديل وتلعب خطوات التركيب.</p>
                <div class="to-acts">
                    ${!o.mcid || (r.isBoss && !mine) ? `<button class="pt-btn primary xs" data-act="toClaim" data-id="${o.id}">${I('check', 14, 2.4)} ${o.mcid ? 'خذ الطلب لك' : 'استلم الطلب'}</button>` : ''}
                    ${mine || r.isBoss ? `<button class="pt-btn danger xs" data-act="toCancel" data-id="${o.id}">${I('trash', 14, 2)} إلغاء وإرجاع ${money(o.left)}</button>` : ''}
                </div>` : ''}
            </div>`;
        }
        return `<div class="to-card ${isOpen ? 'open' : ''}">
            <button class="to-head" data-act="toOpen" data-id="${o.id}">
                <b class="ltr">#${o.id}</b>
                <div class="to-car"><strong>${esc(o.model || 'سيارة')}</strong><span class="to-plate">${esc(o.plate)}</span></div>
                <div class="to-who"><span>${esc(o.name || '')}</span><small>${esc(o.created ? ago(o.created) : '')}</small></div>
                <div class="to-prog"><small>${done}/${lines.length}</small><u><s style="width:${lines.length ? Math.round(done / lines.length * 100) : 0}%"></s></u></div>
                ${state}
                <b class="to-total ltr">${money(o.total)}</b>
            </button>${body}</div>`;
    }

    function pricesView() {
        const o = O();
        if (!o.prices) return '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
        const rows = o.prices.map((p) => `<tr><td>${esc(p.label)}</td>
            <td class="ltr">${o.pricesBoss ? `<input class="pt-in sm ltr" inputmode="numeric" data-model="tune.edit.${p.key}" data-enter="toPrice" data-k="${p.key}" value="${esc(o.edit[p.key])}">` : money(p.price)}</td>
            ${o.pricesBoss ? `<td class="pt-acts"><button class="pt-mini green" data-act="toPrice" data-k="${p.key}">${I('check', 13, 2.4)} حفظ</button></td>` : ''}</tr>`).join('');
        return `<div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>التعديل</th><th>السعر للزبون</th>${o.pricesBoss ? '<th></th>' : ''}</tr></thead><tbody>${rows}</tbody></table></div>
            <p class="pt-hint">${o.pricesBoss ? `هذا ما يدفعه الزبون عند المنصة (يذهب لحساب الورشة). القطع تُشترى من متجر القطع. الحد $${o.max.toLocaleString('en-US')}.` : 'الأسعار يحددها مدير الورشة.'}</p>`;
    }

    function view() {
        const o = O();
        const r = o.r;
        const openN = r ? PT.list(r.open).length : 0;
        const tabs = `<div class="pt-fchips ps-tabs">
            <button class="${o.tab === 'open' ? 'on' : ''}" data-act="toTab" data-t="open">المفتوحة${openN ? ` (${openN})` : ''}</button>
            <button class="${o.tab === 'done' ? 'on' : ''}" data-act="toTab" data-t="done">المنتهية</button>
            <button class="${o.tab === 'prices' ? 'on' : ''}" data-act="toTab" data-t="prices">الأسعار</button></div>`;
        let body;
        if (o.tab === 'prices') body = pricesView();
        else if (!r) body = '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
        else {
            const list = PT.list(o.tab === 'open' ? r.open : r.done);
            body = list.length ? `<div class="to-list">${list.map((x) => card(x, o.tab === 'open')).join('')}</div>`
                : `<div class="pt-empty"><p>${o.tab === 'open' ? 'لا توجد طلبات مفتوحة. الزبون يطلب من منصة التعديل في الورشة.' : 'لا توجد طلبات منتهية بعد.'}</p></div>`;
        }
        return `<div class="pt-appwin">${PT.head('الورشة', 'طلبات التعديل', PT.metaBox('مفتوحة', String(openN)))}
            <div class="pt-abody pad" data-scroll="orders-${o.tab}">${tabs}${body}</div></div>`;
    }

    const num = (v) => { const s = String(v == null ? '' : v).replace(/[^\d]/g, ''); return s ? Number(s) : null; };

    const act = {
        toTab: (el) => { O().tab = el.dataset.t; O().open = null; if (O().tab === 'prices') loadPrices(); else load(); render(); },
        toOpen: (el) => { const id = Number(el.dataset.id); O().open = O().open === id ? null : id; render(); },
        toClaim: (el) => {
            call('tuneClaim', Number(el.dataset.id)).then((res) => {
                if (!res.ok) return fail(res);
                O().r = res.r;
                toast('الطلب معك الآن', 'success');
                render();
            });
        },
        toCancel: (el) => {
            const o = PT.list(O().r && O().r.open).find((x) => x.id === Number(el.dataset.id));
            if (!o) return;
            ask({ title: 'إلغاء الطلب', sub: `#${o.id} · ${o.plate}`, text: `يرجع للزبون ${money(o.left)} من حساب الورشة (ما لم يُركّب). ما ركّبته يبقى على السيارة.`, ok: 'إلغاء الطلب', danger: true }, () => {
                call('tuneCancel', o.id).then((res) => {
                    if (!res.ok) return fail(res);
                    O().r = res.r;
                    O().open = null;
                    toast('أُلغي الطلب ورجع المبلغ للزبون', 'success');
                    render();
                });
            });
        },
        toPrice: (el) => {
            const o = O();
            const key = el.dataset.k;
            const price = num(o.edit[key]);
            if (price == null || price > o.max) return toast(`السعر من 0 إلى $${o.max.toLocaleString('en-US')}`, 'error');
            if (o.busy) return;
            o.busy = true;
            call('tunePriceSave', key, price).then((res) => {
                o.busy = false;
                if (!res.ok) return fail(res);
                o.prices = PT.list(res.r.list);
                o.prices.forEach((p) => { o.edit[p.key] = String(p.price); });
                toast('تم حفظ السعر', 'success');
                render();
            });
        },
    };

    PT.app('orders', {
        view,
        enter() { O().tab = 'open'; O().open = null; load(); },
        back() { if (O().open) { O().open = null; render(); return true; } return false; },
        act,
    });
})();
