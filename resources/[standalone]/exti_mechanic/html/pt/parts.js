// EX_Tii Mechanic tablet — متجر القطع (the parts shop), like the video: pick the parts, pay with the
// workshop account, the order is on its way (a countdown) and arrives at the delivery spot near the
// workshop; a mechanic carries it to the parts shelf.
(() => {
    const { S, I, esc, call, render, toast, fail, money, fmtStamp, now } = PT;

    S.parts = { r: null, cart: {}, cat: 'all', tab: 'shop', busy: false };
    const P = () => S.parts;
    const img = (item) => `items/${encodeURIComponent(item)}.png`;

    function load() {
        call('partsView').then((res) => {
            if (res.ok) P().r = res.r; else { P().r = { list: [], orders: [] }; fail(res); }
            render();
        });
    }

    const cats = () => { const out = []; PT.list(P().r && P().r.list).forEach((x) => { if (!out.includes(x.category)) out.push(x.category); }); return out; };
    const cartCount = () => Object.values(P().cart).reduce((a, b) => a + b, 0);
    const cartTotal = () => PT.list(P().r && P().r.list).reduce((sum, x) => sum + (P().cart[x.item] || 0) * x.price, 0);

    function shop() {
        const p = P(), r = p.r;
        const list = PT.list(r.list).filter((x) => p.cat === 'all' || x.category === p.cat);
        const cards = list.map((x) => {
            const n = p.cart[x.item] || 0;
            return `<div class="ps-card ${n ? 'in' : ''}">
                <div class="ps-img"><img src="${img(x.item)}" onerror="this.style.opacity=.25" alt=""></div>
                <b>${esc(x.label)}</b><span class="ps-price">${money(x.price)}</span>
                <div class="ps-qty"><button data-act="psMinus" data-item="${esc(x.item)}" ${n ? '' : 'disabled'}>${I('minus', 14, 2.4)}</button><em>${n}</em><button data-act="psPlus" data-item="${esc(x.item)}">${I('plus', 14, 2.4)}</button></div>
            </div>`;
        }).join('');
        const lines = PT.list(r.list).filter((x) => p.cart[x.item]).map((x) => `<div class="ps-line"><span>${p.cart[x.item]}× ${esc(x.label)}</span><b>${money(p.cart[x.item] * x.price)}</b></div>`).join('');
        const total = cartTotal();
        const short = r.balance != null && total > r.balance;
        return `<div class="ps">
            <section class="ps-main">
                <div class="pt-fchips">${[['all', 'الكل'], ...cats().map((c) => [c, c])].map(([id, label]) => `<button class="${p.cat === id ? 'on' : ''}" data-act="psCat" data-c="${esc(id)}">${esc(label)}</button>`).join('')}</div>
                <div class="ps-grid">${cards}</div>
            </section>
            <aside class="ps-side">
                <h3>${I('receipt', 16, 2)} الطلبية</h3>
                <div class="ps-lines">${lines || '<p class="pt-mute">اختر القطع من القائمة.</p>'}</div>
                <div class="ps-total"><span>المجموع (${cartCount()})</span><b>${money(total)}</b></div>
                <div class="ps-bal"><span>رصيد حساب الورشة</span><b class="${short ? 'bad' : ''}">${r.balance != null ? money(r.balance) : '—'}</b></div>
                <button class="pt-btn primary" data-act="psOrder" ${!cartCount() || short || !r.canOrder || p.busy ? 'disabled' : ''}>${I('send', 15, 2)} ${p.busy ? 'جارٍ الطلب…' : 'اطلب الآن'}</button>
                <p class="pt-hint">${r.canOrder ? `تصل الطلبية خلال ${r.eta} دقائق إلى نقطة الاستلام بجانب الورشة، والمبلغ يُدفع من حساب الورشة.` : 'الطلب من رتبة ميكانيكي فما فوق.'}</p>
            </aside>
        </div>`;
    }

    function status(o) {
        if (o.status === 'collected') return `<em class="pt-tag grey">استُلمت${o.collectedBy ? ` · ${esc(o.collectedBy)}` : ''}</em>`;
        if (o.status === 'ready') return '<em class="pt-tag green">جاهزة للاستلام</em>';
        const left = Math.max(0, (o.eta || 0) - now());
        return `<em class="pt-tag amber">في الطريق · <bdi class="ltr">${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}</bdi></em>`;
    }

    function orders() {
        const list = PT.list(P().r.orders);
        if (!list.length) return '<div class="pt-empty"><p>لا توجد طلبيات بعد.</p></div>';
        return `<div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>#</th><th>القطع</th><th>المبلغ</th><th>طلبها</th><th>التاريخ</th><th>الحالة</th></tr></thead><tbody>
            ${list.map((o) => `<tr><td class="ltr">${o.id}</td><td>${PT.list(o.items).map((it) => `${it.count}× ${esc(it.label)}`).join('، ')}</td><td class="ltr">${money(o.total)}</td>
                <td>${esc(o.name || '')}</td><td class="ltr">${esc(fmtStamp(o.created))}</td><td>${status(o)}</td></tr>`).join('')}
        </tbody></table></div>`;
    }

    function view() {
        const p = P();
        const r = p.r;
        const tabs = `<div class="pt-fchips ps-tabs"><button class="${p.tab === 'shop' ? 'on' : ''}" data-act="psTab" data-t="shop">المتجر</button><button class="${p.tab === 'orders' ? 'on' : ''}" data-act="psTab" data-t="orders">الطلبيات${r && PT.list(r.orders).some((o) => o.status === 'ready') ? ' •' : ''}</button></div>`;
        const body = !r ? '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>' : (p.tab === 'shop' ? shop() : orders());
        return `<div class="pt-appwin">${PT.head('الورشة', 'متجر القطع', r && r.balance != null ? PT.metaBox('حساب الورشة', `$${Number(r.balance).toLocaleString('en-US')}`) : '')}
            <div class="pt-abody pad">${tabs}${body}</div></div>`;
    }

    // the countdown on the orders tab
    let ticker = null;
    const tick = () => { if (S.app === 'parts' && P().tab === 'orders') render(); };

    const act = {
        psTab: (el) => { P().tab = el.dataset.t; if (P().tab === 'orders') load(); render(); },
        psCat: (el) => { P().cat = el.dataset.c; render(); },
        psPlus: (el) => {
            const p = P();
            const max = (p.r && p.r.max) || 40;
            if (cartCount() >= max) return toast(`حدّ الطلبية ${max} قطعة`, 'error');
            p.cart[el.dataset.item] = (p.cart[el.dataset.item] || 0) + 1; render();
        },
        psMinus: (el) => { const p = P(); const n = (p.cart[el.dataset.item] || 0) - 1; if (n > 0) p.cart[el.dataset.item] = n; else delete p.cart[el.dataset.item]; render(); },
        psOrder: () => {
            const p = P();
            if (!cartCount() || p.busy) return;
            p.busy = true; render();
            call('partsOrder', p.cart).then((res) => {
                p.busy = false;
                if (!res.ok) { render(); return fail(res); }
                p.r = res.r; p.cart = {}; p.tab = 'orders';
                toast('أُرسلت الطلبية، تصل إلى نقطة الاستلام قريبًا', 'success');
                render();
            });
        },
    };

    PT.app('parts', {
        view,
        enter() { P().tab = 'shop'; load(); if (!ticker) ticker = setInterval(tick, 1000); },
        act,
    });
})();
