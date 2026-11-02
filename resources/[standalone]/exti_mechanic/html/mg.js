// =====================================================================
// EX_Tii Mechanic — the repair mini-games (the game opens one, the answer goes back with mgDone):
//   hold   : hold SPACE until the bar is full (let go and it slips back)
//   keys   : press the keys shown, one after another, before the time runs out
//   torque : stop the needle in the green, once per bolt
//   pour   : hold SPACE to pour, let go inside the green band (too much = spilled, try again)
//   scrub  : wash / wax: rub the car with the mouse until it is clean
// Three mistakes and the job fails (no part is used). Esc gives up.
// =====================================================================
const MG = (() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => (RES
        ? fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) }).catch(() => null)
        : Promise.resolve(MG.onDone && MG.onDone(data)));
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const ICON = {
        wrench: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><path d="M14.7 6.3a4 4 0 0 0 5 5L11 20a2.1 2.1 0 0 1-3-3l8.7-8.7a4 4 0 0 0-2-2z"/></svg>',
        drop: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><path d="M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11z"/></svg>',
        key: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 10h.01M11 10h.01M15 10h.01M7 14h10"/></svg>',
        sponge: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><rect x="3" y="8" width="18" height="10" rx="3"/><path d="M7 5h.01M12 4h.01M17 5h.01"/></svg>',
    };

    let root, kind, open = false, lives = 3, stop = null, keysDown = {};

    function build() {
        root = document.getElementById('mg');
        if (!root) { root = document.createElement('div'); root.id = 'mg'; document.body.appendChild(root); }
        root.classList.add('hidden');
    }

    function finish(ok) {
        if (!open) return;
        open = false;
        if (stop) { stop(); stop = null; }
        const r = root.querySelector('.mg-result');
        if (r) { r.className = 'mg-result ' + (ok ? 'ok' : 'bad'); r.textContent = ok ? 'تم ✓' : 'فشلت'; }
        setTimeout(() => { root.classList.add('hidden'); root.innerHTML = ''; post('mgDone', { ok }); }, ok ? 450 : 650);
    }

    function card(icon, title, sub, body, hint) {
        root.innerHTML = `<div class="mg-card"><div class="mg-top"><i class="mg-ic">${ICON[icon] || ICON.wrench}</i>
            <div style="flex:1"><div class="mg-title">${esc(title)}</div><div class="mg-sub">${esc(sub)}</div></div>
            <div class="mg-lives">${[0, 1, 2].map((i) => `<i class="${i < lives ? '' : 'off'}"></i>`).join('')}</div></div>
            ${body}<div class="mg-result"></div><div class="mg-hint">${hint}</div></div>`;
    }
    function miss() {
        lives -= 1;
        const c = root.querySelector('.mg-card');
        if (c) { c.classList.remove('shake'); void c.offsetWidth; c.classList.add('shake'); }
        root.querySelectorAll('.mg-lives i').forEach((el, i) => el.classList.toggle('off', i >= lives));
        if (lives <= 0) finish(false);
        return lives > 0;
    }
    const loop = (fn) => { let on = true, last = performance.now(); const f = (t) => { if (!on) return; const dt = Math.min(0.05, (t - last) / 1000); last = t; fn(dt); requestAnimationFrame(f); }; requestAnimationFrame(f); return () => { on = false; }; };

    // -------------------------------------------------- hold
    function hold(label) {
        card('wrench', label, 'اضغط مطوّلًا', '<div class="mg-bar"><s></s></div>', '<kbd>SPACE</kbd> اضغط باستمرار حتى يمتلئ الشريط');
        let v = 0;
        const bar = root.querySelector('.mg-bar s');
        stop = loop((dt) => {
            v += keysDown[' '] ? dt * 38 : -dt * 55;
            v = Math.max(0, v);
            bar.style.width = Math.min(100, v) + '%';
            if (v >= 100) finish(true);
        });
    }

    // -------------------------------------------------- keys
    function keys(label, n) {
        const KEYS = ['W', 'A', 'S', 'D'];
        const seq = Array.from({ length: Math.max(2, n || 4) }, () => KEYS[Math.floor(Math.random() * 4)]);
        let i = 0, t = 0;
        const per = 2.4;
        const draw = () => {
            root.querySelector('.mg-keys').innerHTML = seq.map((k, j) => `<span class="mg-key ${j < i ? 'done' : j === i ? 'now' : ''}">${k}</span>`).join('');
        };
        card('key', label, `${seq.length} مفاتيح`, '<div class="mg-keys"></div><div class="mg-timer"><s></s></div>', 'اضغط المفتاح المضيء قبل انتهاء الوقت');
        draw();
        const timer = root.querySelector('.mg-timer s');
        MG._key = (k) => {
            if (!open || kind !== 'keys') return;
            if (k.toUpperCase() === seq[i]) { i += 1; t = 0; draw(); if (i >= seq.length) finish(true); }
            else if (KEYS.includes(k.toUpperCase())) { t = 0; if (!miss()) return; }
        };
        stop = loop((dt) => {
            t += dt;
            timer.style.width = Math.max(0, 100 - (t / per) * 100) + '%';
            if (t >= per) { t = 0; miss(); }
        });
    }

    // -------------------------------------------------- torque
    function torque(label, n) {
        const bolts = Math.max(1, n || 1);
        let done = 0, a = 0, dir = 1, speed = 210;
        let zone = 0;
        const newZone = () => { zone = 40 + Math.random() * 230; };
        newZone();
        const R = 80, C = 95;
        const pt = (deg, r) => { const rad = (deg - 225) * Math.PI / 180; return [C + r * Math.cos(rad), C + r * Math.sin(rad)]; };
        const arc = (from, to, r) => { const [x1, y1] = pt(from, r), [x2, y2] = pt(to, r); return `M${x1} ${y1} A${r} ${r} 0 ${to - from > 180 ? 1 : 0} 1 ${x2} ${y2}`; };
        card('wrench', label, `${bolts} ${bolts === 1 ? 'برغي' : 'براغي'}`,
            `<div class="mg-dial"><svg viewBox="0 0 190 190"><path d="${arc(0, 270, R)}" stroke="rgba(255,255,255,.1)" stroke-width="14" fill="none" stroke-linecap="round"/>
             <path class="z" stroke="#34d58f" stroke-width="14" fill="none" stroke-linecap="round"/>
             <line class="n" x1="95" y1="95" stroke="#f2c230" stroke-width="4" stroke-linecap="round"/><circle cx="95" cy="95" r="9" fill="#f2c230"/></svg></div>
             <div class="mg-bolts">${Array.from({ length: bolts }, (_, i) => `<i class="${i === 0 ? 'now' : ''}"></i>`).join('')}</div>`,
            '<kbd>SPACE</kbd> عندما يكون المؤشر داخل المنطقة الخضراء');
        const z = root.querySelector('.z'), needle = root.querySelector('.n');
        const W = 34;
        const drawZone = () => z.setAttribute('d', arc(zone, zone + W, R));
        drawZone();
        MG._space = () => {
            if (!open || kind !== 'torque') return;
            if (a >= zone - 3 && a <= zone + W + 3) {
                done += 1;
                root.querySelectorAll('.mg-bolts i').forEach((el, i) => { el.className = i < done ? 'done' : i === done ? 'now' : ''; });
                if (done >= bolts) return finish(true);
                newZone(); drawZone(); speed += 25;
            } else miss();
        };
        stop = loop((dt) => {
            a += dir * speed * dt;
            if (a >= 270) { a = 270; dir = -1; } else if (a <= 0) { a = 0; dir = 1; }
            const [x, y] = pt(a, R - 4);
            needle.setAttribute('x2', x); needle.setAttribute('y2', y);
        });
    }

    // -------------------------------------------------- pour
    function pour(label) {
        let lvl = 0, rate = 0, poured = false;
        const lo = 64 + Math.random() * 14, hi = lo + 9;
        const color = /زيت/.test(label) ? 'oil' : /تبريد|فرامل/.test(label) ? 'blue' : '';
        card('drop', label, 'حتى الخط الأخضر', `<div class="mg-pour"><div class="mg-tank"><div class="zone" style="bottom:${lo}%;height:${hi - lo}%"></div><div class="liq ${color}"></div></div>
            <div class="mg-pourtxt"><b class="pv">0%</b>اسكب بهدوء: السائل يتباطأ قرب الامتلاء. إذا تجاوزت الخط ينسكب وتعيد.</div></div>`,
            '<kbd>SPACE</kbd> اضغط للسكب، اترك عند الخط الأخضر');
        const liq = root.querySelector('.liq'), pv = root.querySelector('.pv');
        stop = loop((dt) => {
            if (keysDown[' ']) { rate = Math.min(26, rate + dt * 40); poured = true; } else { rate = Math.max(0, rate - dt * 90); }
            lvl = Math.min(100, lvl + rate * dt);
            liq.style.height = lvl + '%';
            pv.textContent = Math.floor(lvl) + '%';
            if (lvl > hi + 1.5) {
                lvl = 0; rate = 0; poured = false;
                if (!miss()) return;
            } else if (poured && !keysDown[' '] && rate === 0) {
                if (lvl >= lo && lvl <= hi + 1.5) finish(true);
                else if (lvl > 4) { poured = false; } // keep pouring until the line
            }
        });
    }

    // -------------------------------------------------- scrub (wash / wax)
    function scrub(label) {
        const wax = /واكس/.test(label);
        card('sponge', label, wax ? 'وزّع الواكس على كل السيارة' : 'نظّف كل الأوساخ',
            `<div class="mg-scrub"><div class="car"><svg width="360" height="150" viewBox="0 0 360 150"><path d="M20 112V84l46-8 40-40h120l52 40 54 10v26z" fill="#c9d3e6" stroke="#8e9bb5" stroke-width="3"/><path d="M112 42h52v34H86zM172 42h48l40 34h-88z" fill="#5d6f91"/><circle cx="90" cy="116" r="22" fill="#222"/><circle cx="270" cy="116" r="22" fill="#222"/></svg></div><canvas width="460" height="250"></canvas></div>
             <div class="mg-clean"><span>اسحب بالفأرة مع الضغط</span><span>${wax ? 'التلميع' : 'النظافة'}: <b class="cv">0%</b></span></div>`,
            '<kbd>زر الفأرة</kbd> اضغط واسحب فوق السيارة');
        const cv = root.querySelector('canvas'), ctx = cv.getContext('2d'), out = root.querySelector('.cv');
        // the dirt (or the dull layer before wax)
        ctx.fillStyle = wax ? 'rgba(210,200,170,0.55)' : 'rgba(92,70,38,0.82)';
        ctx.fillRect(0, 0, cv.width, cv.height);
        for (let i = 0; i < 140; i++) {
            ctx.fillStyle = wax ? `rgba(255,250,230,${0.15 + Math.random() * 0.2})` : `rgba(${60 + Math.random() * 40},${45 + Math.random() * 25},${20 + Math.random() * 15},${0.5 + Math.random() * 0.4})`;
            ctx.beginPath(); ctx.arc(Math.random() * cv.width, Math.random() * cv.height, 6 + Math.random() * 26, 0, Math.PI * 2); ctx.fill();
        }
        let down = false;
        const rub = (e) => {
            const r = cv.getBoundingClientRect();
            const x = (e.clientX - r.left) * (cv.width / r.width), y = (e.clientY - r.top) * (cv.height / r.height);
            ctx.globalCompositeOperation = 'destination-out';
            ctx.beginPath(); ctx.arc(x, y, 30, 0, Math.PI * 2); ctx.fill();
            ctx.globalCompositeOperation = 'source-over';
        };
        cv.addEventListener('mousedown', (e) => { down = true; rub(e); });
        cv.addEventListener('mousemove', (e) => { if (down) rub(e); });
        window.addEventListener('mouseup', () => { down = false; });
        let tick = 0;
        stop = loop((dt) => {
            tick += dt;
            if (tick < 0.25) return;
            tick = 0;
            const d = ctx.getImageData(0, 0, cv.width, cv.height).data;
            let left = 0, total = 0;
            for (let i = 3; i < d.length; i += 64) { total++; if (d[i] > 30) left++; }
            const clean = Math.floor((1 - left / total) * 100);
            out.textContent = clean + '%';
            if (clean >= 88) finish(true);
        });
    }

    function start(m) {
        if (!root) build();
        kind = m.kind; lives = 3; open = true; keysDown = {};
        MG._space = null; MG._key = null;
        root.classList.remove('hidden');
        if (kind === 'hold') hold(m.label);
        else if (kind === 'keys') keys(m.label, m.n);
        else if (kind === 'torque') torque(m.label, m.n);
        else if (kind === 'pour') pour(m.label);
        else if (kind === 'scrub') scrub(m.label);
        else finish(true);
    }

    window.addEventListener('keydown', (e) => {
        if (!open) return;
        if (e.key === 'Escape') { e.preventDefault(); return finish(false); }
        if (e.key === ' ') { e.preventDefault(); if (!keysDown[' '] && MG._space) MG._space(); }
        keysDown[e.key] = true;
        if (MG._key && kind === 'keys' && !e.repeat) MG._key(e.key);
    });
    window.addEventListener('keyup', (e) => { keysDown[e.key] = false; });
    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || m.action !== 'mg') return;
        if (m.open) start(m);
    });

    return { start, onDone: null, _space: null, _key: null };
})();
