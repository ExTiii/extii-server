// EX_Tii Mechanic tablet — الداينو: the car on the dyno circle at the workshop, someone in the driver
// seat; "ابدأ القياس" revs the car and measures it: horsepower, torque, top speed, 0-100. The
// chart shows the power and torque curves, the last run dashed (before / after tuning).
(() => {
    const { S, I, esc, call, render, toast, fail, fmtStamp } = PT;

    S.dyno = { r: null, run: false, last: null };
    const Dy = () => S.dyno;

    function load() {
        call('dynoView').then((res) => {
            if (res.ok) Dy().r = res.r; else { Dy().r = { far: true }; fail(res); }
            render();
        });
    }

    // the curves from the peak numbers (rpm 1000 → 8000)
    function curves(hp, nm) {
        const pts = [];
        for (let r = 1000; r <= 8000; r += 250) {
            const t = Math.max(0.4, 1 - Math.pow((r - 4500) / 5000, 2) * 1.2);
            pts.push({ r, t: nm * t, raw: t * r });
        }
        const peak = Math.max(...pts.map((p) => p.raw));
        pts.forEach((p) => { p.h = hp * p.raw / peak; });
        return pts;
    }

    function chart(cur, prev) {
        const W = 560, H = 210, L = 38, B = 24, R = 12, T = 10;
        const max = Math.max(cur ? cur.nm : 0, prev ? prev.nm : 0, cur ? cur.hp : 0, prev ? prev.hp : 0, 100) * 1.1;
        const x = (r) => L + (r - 1000) / 7000 * (W - L - R);
        const y = (v) => H - B - v / max * (H - B - T);
        const path = (pts, key) => pts.map((p, i) => `${i ? 'L' : 'M'}${x(p.r).toFixed(1)} ${y(p[key]).toFixed(1)}`).join(' ');
        let g = '';
        for (let i = 0; i <= 4; i++) {
            const v = max / 4 * i;
            g += `<line x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}" class="dy-grid"/><text x="${L - 6}" y="${y(v) + 4}" class="dy-ax" text-anchor="end">${Math.round(v)}</text>`;
        }
        for (let r = 1000; r <= 8000; r += 1000) g += `<text x="${x(r)}" y="${H - 6}" class="dy-ax" text-anchor="middle">${r / 1000}k</text>`;
        let lines = '';
        if (prev) { const p = curves(prev.hp, prev.nm); lines += `<path d="${path(p, 'h')}" class="dy-hp old"/><path d="${path(p, 't')}" class="dy-nm old"/>`; }
        if (cur) { const c = curves(cur.hp, cur.nm); lines += `<path d="${path(c, 'h')}" class="dy-hp"/><path d="${path(c, 't')}" class="dy-nm"/>`; }
        return `<svg viewBox="0 0 ${W} ${H}" class="dy-chart" dir="ltr">${g}${lines}</svg>
            <div class="dy-legend"><span><i class="hp"></i>القوة (حصان)</span><span><i class="nm"></i>العزم (نيوتن·متر)</span>${prev ? '<span><i class="old"></i>القياس السابق</span>' : ''}<span class="dy-rpm">دورات المحرك</span></div>`;
    }

    const delta = (a, b, unit, lowerBetter) => {
        if (b == null) return '';
        const d = Math.round((a - b) * 10) / 10;
        if (!d) return '';
        const good = lowerBetter ? d < 0 : d > 0;
        return `<em class="${good ? 'up' : 'down'}">${d > 0 ? '+' : ''}${d}${unit}</em>`;
    };

    function view() {
        const d = Dy();
        const r = d.r;
        let body;
        if (!r) body = '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
        else if (r.far) body = `<div class="pt-empty big"><i class="pt-ic violet lg">${I('calc', 34, 1.8)}</i><h3>الداينو في الورشة</h3><p>اقترب من دائرة الداينو في ورشة بيني لتستعمله.</p><button class="pt-btn ghost xs" data-act="dyRefresh">${I('refresh', 14, 2)} تحديث</button></div>`;
        else if (r.empty) body = `<div class="pt-empty big"><i class="pt-ic violet lg">${I('calc', 34, 1.8)}</i><h3>لا توجد سيارة على الداينو</h3><p>ادخل بالسيارة إلى دائرة الداينو، واجعل أحدًا يجلس مكان السائق، ثم اضغط تحديث.</p><button class="pt-btn ghost xs" data-act="dyRefresh">${I('refresh', 14, 2)} تحديث</button></div>`;
        else {
            const hist = PT.list(r.history);
            const cur = hist[0] || null;
            const prev = hist[1] || null;
            const stat = (label, v, unit, key, lower) => `<div class="dy-stat"><small>${label}</small><b>${cur ? v(cur) : '—'}<span>${unit}</span></b>${cur && prev ? delta(cur[key], prev[key], '', lower) : ''}</div>`;
            body = `<div class="dy">
                <div class="dy-top">
                    <div class="dy-car"><span class="to-plate">${esc(r.plate || '')}</span><small>${r.driver ? 'السائق جاهز' : 'لا يوجد سائق'}</small></div>
                    <div class="dy-stats">
                        ${stat('القوة', (x) => x.hp, ' حصان', 'hp')}
                        ${stat('العزم', (x) => x.nm, ' ن·م', 'nm')}
                        ${stat('السرعة القصوى', (x) => x.top, ' كم/س', 'top')}
                        ${stat('0 إلى 100', (x) => x.zero.toFixed(1), ' ث', 'zero', true)}
                    </div>
                    <button class="pt-btn primary" data-act="dyRun" ${!r.driver || d.run ? 'disabled' : ''}>${d.run ? 'جارٍ القياس…' : `${I('refresh', 15, 2)} ابدأ القياس`}</button>
                </div>
                ${!r.driver ? '<p class="pt-hint">يجب أن يجلس أحد (الزبون أو أنت) مكان السائق والسيارة على الدائرة.</p>' : ''}
                <div class="dy-box">${cur ? chart(cur, prev) : '<p class="pt-mute">لم تُقَس هذه السيارة بعد. اضغط ابدأ القياس.</p>'}</div>
                ${hist.length ? `<h3 class="dg-h">القياسات</h3><div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>التاريخ</th><th>الميكانيكي</th><th>القوة</th><th>العزم</th><th>القصوى</th><th>0-100</th></tr></thead><tbody>
                    ${hist.map((h) => `<tr><td class="ltr">${esc(fmtStamp(h.at))}</td><td>${esc(h.name || '')}</td><td class="ltr">${h.hp}</td><td class="ltr">${h.nm}</td><td class="ltr">${h.top}</td><td class="ltr">${Number(h.zero).toFixed(1)}s</td></tr>`).join('')}</tbody></table></div>` : ''}
                ${d.run ? '<div class="dy-running"><span class="pt-spin"></span><p>السيارة على الداينو… 8 ثوانٍ</p></div>' : ''}
            </div>`;
        }
        return `<div class="pt-appwin">${PT.head('الورشة', 'الداينو', r && r.plate ? PT.metaBox('اللوحة', r.plate) : '')}
            <div class="pt-abody pad" data-scroll="dyno">${body}</div></div>`;
    }

    const act = {
        dyRefresh: load,
        dyRun: () => {
            const d = Dy();
            if (d.run) return;
            d.run = true;
            render();
            call('dynoRun').then((res) => {
                d.run = false;
                if (!res.ok) { render(); return fail(res); }
                d.r = Object.assign({}, d.r, { history: res.r.history, plate: res.r.plate });
                toast(`${res.r.result.hp} حصان · ${res.r.result.top} كم/س`, 'success');
                render();
            });
        },
    };

    PT.app('dyno', { view, enter() { Dy().r = null; Dy().run = false; load(); }, act });
})();
