// EX_Tii Mechanic tablet — الفحص (diagnostics), like the video: stand next to a car and scan it.
// The car's picture, plate, km, and every part on one screen (brake pads, spark plugs, clutch,
// engine oil, coolant, air filter, gearbox oil, tires; an electric car shows its battery and motor
// instead), the engine and body, the wax, and the car's service history.
(() => {
    const { S, I, esc, call, render, fail, fmtStamp } = PT;

    S.diag = { r: null, busy: false, err: null };
    const D = () => S.diag;

    const IMG = (model) => `https://docs.fivem.net/vehicles/${encodeURIComponent(String(model || '').toLowerCase())}.webp`;
    const FALLBACK = 'data:image/svg+xml;utf8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 150"><path d="M20 112V84l46-8 40-40h120l52 40 54 10v26z" fill="#3a3a40" stroke="#5b5b63" stroke-width="3"/><circle cx="90" cy="116" r="22" fill="#18181b"/><circle cx="250" cy="116" r="22" fill="#18181b"/></svg>');

    const tone = (p) => (p >= 50 ? 'good' : p >= 15 ? 'mid' : 'bad');
    const word = (p) => (p >= 75 ? 'ممتاز' : p >= 50 ? 'جيد' : p >= 15 ? 'يحتاج تغييرًا قريبًا' : p > 0 ? 'خطر: غيّره الآن' : 'تالف');

    function scan() {
        const d = D();
        d.busy = true; d.err = null;
        render();
        call('diagScan').then((res) => {
            d.busy = false;
            if (res.ok) { d.r = res.r; } else { d.r = null; d.err = res.e; if (res.e !== 'no_car') fail(res); }
            render();
        });
    }

    function partCard(p) {
        const t = tone(p.pct);
        return `<div class="dg-part ${t}">
            <div class="dg-ptop"><b>${esc(p.label)}</b><em>${p.pct}%</em></div>
            <div class="dg-bar"><s style="width:${Math.max(2, p.pct)}%"></s></div>
            <div class="dg-pbot"><span>${esc(word(p.pct))}</span><small>${esc(p.partLabel)}${p.count > 1 ? ` ×${p.count}` : ''} · معك ${p.have}</small></div>
        </div>`;
    }

    function view() {
        const d = D();
        const r = d.r;
        let body;
        if (d.busy && !r) body = '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ فحص المركبة…</p></div>';
        else if (!r) {
            body = `<div class="pt-empty big"><i class="pt-ic sky lg">${I('scale', 34, 1.8)}</i><h3>${d.err === 'no_car' ? 'لا توجد سيارة بجانبك' : 'افحص سيارة'}</h3>
                <p>قف بجانب السيارة (أقل من 6 أمتار) واضغط فحص. يقرأ الجهاز كل شيء: الفرامل، الشمعات، الكلتش، الزيت، التبريد، الفلتر والإطارات.</p>
                <button class="pt-btn primary" data-act="diagScan" style="margin-top:14px">${I('refresh', 15, 2)} فحص</button></div>`;
        } else {
            const worst = r.parts.reduce((m, p) => Math.min(m, p.pct), 100);
            const hist = (r.history || []).map((h) => `<tr><td>${esc(h.what)}</td><td>${esc(h.name || '')}</td><td class="ltr">${h.km != null ? `${h.km} كم` : '—'}</td><td class="ltr">${esc(fmtStamp(h.at))}</td></tr>`).join('');
            body = `<div class="dg">
                <aside class="dg-car">
                    <div class="dg-img"><img src="${IMG(r.modelName || r.model)}" onerror="this.onerror=null;this.src='${FALLBACK}'" alt=""></div>
                    <div class="dg-plate">${esc(r.plate)}</div>
                    <div class="dg-name">${esc(r.model || '')}${r.ev ? ' <em class="pt-tag green">كهربائية</em>' : ''}</div>
                    <div class="dg-stats">
                        <div><small>العدّاد</small><b class="ltr">${Number(r.km || 0).toLocaleString('en-US')} كم</b></div>
                        <div><small>الحالة العامة</small><b class="${tone(worst)}">${esc(word(worst))}</b></div>
                    </div>
                    <div class="dg-hp"><span>المحرك</span><div class="dg-bar"><s class="${tone(r.engine)}" style="width:${Math.max(2, r.engine)}%"></s></div><em>${Math.max(0, r.engine)}%</em></div>
                    <div class="dg-hp"><span>الهيكل</span><div class="dg-bar"><s class="${tone(r.body)}" style="width:${Math.max(2, r.body)}%"></s></div><em>${Math.max(0, r.body)}%</em></div>
                    <p class="dg-note">${r.wax ? `${I('check', 13, 2.4)} محميّة بالواكس حتى ${esc(fmtStamp(r.wax))}` : 'المحرك والهيكل يُصلحان بعُدة الإصلاح.'}</p>
                    <button class="pt-btn primary xs" data-act="diagScan">${I('refresh', 14, 2)} إعادة الفحص</button>
                </aside>
                <section class="dg-main">
                    <div class="dg-grid">${r.parts.map(partCard).join('')}</div>
                    <h3 class="dg-h">سجل الصيانة</h3>
                    ${hist ? `<div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>العمل</th><th>الميكانيكي</th><th>العدّاد</th><th>التاريخ</th></tr></thead><tbody>${hist}</tbody></table></div>`
                        : '<p class="pt-mute">لا يوجد سجل صيانة لهذه السيارة بعد.</p>'}
                </section>
            </div>`;
        }
        return `<div class="pt-appwin">${PT.head('الورشة', 'الفحص', r ? PT.metaBox('اللوحة', r.plate) : '')}
            <div class="pt-abody pad" data-scroll="diag">${body}</div></div>`;
    }

    PT.app('diagnostics', {
        view,
        enter() { scan(); },
        act: { diagScan: scan },
    });
})();
