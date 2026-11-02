/* =====================================================================
   EX_Tii gangs — the Chop Shop mini games. Each one can't be lost: mistakes cost time.
   { action: 'chopgame', game: 'bolts' | 'lugnuts' | 'pry' | 'torch', title }  ->  post chopgame { done }
   ===================================================================== */
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'exti_gangs';
    const post = (done) => fetch(`https://${RES}/chopgame`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ done }) }).catch(() => {});
    const box = document.getElementById('game');
    let G = null;
    const HINT = {
        bolts: 'اضغط مع الاستمرار على كل برغي حتى تمتلئ دائرته (لا تُفلت الفأرة)',
        lugnuts: 'فكّ الصواميل بترتيب النجمة: اضغط الصامولة المضيئة، الخطأ يضيّع وقتك',
        pry: 'اضغط المسافة عندما يكون المؤشر داخل المنطقة الخضراء (3 مرات)',
        torch: 'اضغط مع الاستمرار وتتبّع الخط المتقطّع بالشعلة من البداية للنهاية',
        sort: 'ضع كل ورقة في درجها: 1 = 10$ · 2 = 20$ · 3 = 50$ · 4 = 100$ (أو اضغط على الدرج). الخطأ يضيّع وقتك',
        drum: 'اضغط المسافة مع الاستمرار لترفع السرعة، أفلتها لتنزل. أبقِ المؤشر في المنطقة الخضراء حتى تمتلئ الدورة',
        band: 'اضغط مع الاستمرار لتعدّ الأوراق، وأفلت عند 50 بالضبط (±2) لتربط الرزمة',
    };

    function frame(game, title, foot) {
        box.innerHTML = `<div class="gcard"><div class="gh"><h3>${title}</h3><span class="cnt" id="gcnt"></span></div><p>${HINT[game]}</p>
            <div class="garea g-${game}" id="garea"></div><div class="gfoot"><span>ESC للإيقاف</span><span>${foot || 'ورشة التفكيك'}</span></div></div>`;
        box.classList.remove('hidden');
        return document.getElementById('garea');
    }
    function end(done) {
        if (!G) return;
        G.cleanup && G.cleanup();
        G = null;
        setTimeout(() => { box.classList.add('hidden'); box.innerHTML = ''; post(done); }, done ? 350 : 0);
    }
    const cnt = (t) => { const c = document.getElementById('gcnt'); if (c) c.textContent = t; };

    // ---------------------------------------------------------------- bolts: hold each one until its ring fills
    function bolts(area) {
        const pos = [[24, 22], [24, 78], [76, 30], [76, 70]];
        let left = pos.length, holding = null, raf;
        cnt(`0/${pos.length}`);
        const els = pos.map(([x, y]) => {
            const b = document.createElement('div'); b.className = 'bolt'; b.style.left = x + '%'; b.style.top = y + '%';
            b.innerHTML = '<svg viewBox="0 0 74 74"><circle cx="37" cy="37" r="33" stroke-dasharray="207" stroke-dashoffset="207"/></svg>';
            b.dataset.p = '0'; area.appendChild(b); return b;
        });
        const tick = () => {
            if (holding && !holding.classList.contains('done')) {
                let p = Number(holding.dataset.p) + 1 / 70;            // ~1.2 s per bolt
                holding.dataset.p = String(p);
                holding.querySelector('circle').setAttribute('stroke-dashoffset', String(207 * (1 - Math.min(1, p))));
                holding.style.transform = `rotate(${p * 540}deg)`;
                if (p >= 1) {
                    holding.classList.add('done'); left -= 1; cnt(`${pos.length - left}/${pos.length}`); holding = null;
                    if (left === 0) return end(true);
                }
            }
            raf = requestAnimationFrame(tick);
        };
        const reset = (b) => { if (b && !b.classList.contains('done')) { b.dataset.p = '0'; b.querySelector('circle').setAttribute('stroke-dashoffset', '207'); b.style.transform = ''; } };
        els.forEach((b) => {
            b.addEventListener('mousedown', () => { holding = b; });
            b.addEventListener('mouseleave', () => { if (holding === b) { reset(b); holding = null; } });
        });
        const up = () => { if (holding) { reset(holding); holding = null; } };
        window.addEventListener('mouseup', up);
        raf = requestAnimationFrame(tick);
        G.cleanup = () => { cancelAnimationFrame(raf); window.removeEventListener('mouseup', up); };
    }

    // ---------------------------------------------------------------- lug nuts: the star order
    function lugnuts(area) {
        area.innerHTML = '<div class="hub"></div>';
        const order = [0, 2, 4, 1, 3];  // star pattern on 5 nuts
        let k = 0, locked = false;
        const W = area.clientWidth, H = area.clientHeight;
        const nuts = [];
        for (let i = 0; i < 5; i++) {
            const a = -Math.PI / 2 + i * 2 * Math.PI / 5;
            const n = document.createElement('div'); n.className = 'nut'; n.textContent = '';
            n.style.left = (W / 2 + Math.cos(a) * 72) + 'px'; n.style.top = (H / 2 + Math.sin(a) * 72) + 'px';
            area.appendChild(n); nuts.push(n);
            n.addEventListener('click', () => {
                if (locked || n.classList.contains('done')) return;
                if (i === order[k]) {
                    n.classList.add('done'); n.classList.remove('next'); k += 1; cnt(`${k}/5`);
                    if (k === 5) return end(true);
                    nuts[order[k]].classList.add('next');
                } else {
                    locked = true; area.classList.add('shake');
                    setTimeout(() => { area.classList.remove('shake'); locked = false; }, 900); // a wrong nut costs time
                }
            });
        }
        nuts[order[0]].classList.add('next'); cnt('0/5');
    }

    // ---------------------------------------------------------------- pry: hit the green zone 3 times
    function pry(area) {
        area.innerHTML = '<div class="gauge"><div class="arc"></div><div class="zone" id="zone"></div><div class="cover"></div><div class="needle" id="needle"></div><div class="hits" id="hits">0/3</div></div><div class="key">[ مسافة ]</div>';
        let hits = 0, ang = -90, dir = 1, speed = 150, raf, last = performance.now(), zone = 0, wait = false;
        const zoneEl = document.getElementById('zone'), needle = document.getElementById('needle'), hitsEl = document.getElementById('hits');
        const newZone = () => {
            zone = -60 + Math.random() * 120;
            const a1 = 270 + 90 + zone - 14, a2 = a1 + 28;
            zoneEl.style.background = `conic-gradient(from 0deg at 50% 100%, transparent ${a1}deg, #3ddc97 ${a1}deg ${a2}deg, transparent ${a2}deg)`;
        };
        newZone(); cnt('0/3');
        const tick = (t) => {
            const dt = Math.min(0.05, (t - last) / 1000); last = t;
            ang += dir * speed * dt;
            if (ang > 90) { ang = 90; dir = -1; } if (ang < -90) { ang = -90; dir = 1; }
            needle.style.transform = `rotate(${ang}deg)`;
            raf = requestAnimationFrame(tick);
        };
        const key = (e) => {
            if (e.code !== 'Space' || wait) return; e.preventDefault();
            if (Math.abs(ang - zone) <= 14) {
                hits += 1; hitsEl.textContent = `${hits}/3`; cnt(`${hits}/3`); speed += 40;
                if (hits >= 3) return end(true);
                newZone();
            } else {
                wait = true; area.classList.add('miss');
                setTimeout(() => { area.classList.remove('miss'); wait = false; }, 700);
            }
        };
        window.addEventListener('keydown', key);
        raf = requestAnimationFrame(tick);
        G.cleanup = () => { cancelAnimationFrame(raf); window.removeEventListener('keydown', key); };
    }

    // ---------------------------------------------------------------- torch: follow the cut line
    function torch(area) {
        const W = area.clientWidth, H = area.clientHeight;
        const pts = [];
        for (let i = 0; i <= 60; i++) { const x = 40 + (W - 80) * i / 60; pts.push([x, H / 2 + Math.sin(i / 60 * Math.PI * 2.2) * 70 + Math.sin(i / 7) * 10]); }
        const d = 'M' + pts.map((p) => p.join(',')).join(' L');
        area.innerHTML = `<svg><path class="path" d="${d}"/><path class="cut" id="cut" d="M${pts[0].join(',')}"/><circle class="tip" id="tip" r="8" cx="${pts[0][0]}" cy="${pts[0][1]}"/></svg>
            <div class="heat"><i id="heat" style="height:0%"></i></div><div class="warn" id="warn"></div>`;
        const tipEl = document.getElementById('tip'), cutEl = document.getElementById('cut'), heatEl = document.getElementById('heat'), warn = document.getElementById('warn');
        warn.textContent = 'اضغط على النقطة المضيئة وتتبّع الخط';
        let idx = 0, down = false, heat = 0, raf;
        const rect = () => area.getBoundingClientRect();
        const move = (e) => {
            if (!down) return;
            const r = rect(), x = e.clientX - r.left, y = e.clientY - r.top;
            const [nx, ny] = pts[Math.min(idx + 1, pts.length - 1)];
            const [cx, cy] = pts[idx];
            const dist = Math.hypot(x - cx, y - cy);
            if (dist > 34) { heat = Math.min(100, heat + 4); warn.textContent = 'ابقَ على الخط!'; return; }
            if (Math.hypot(x - nx, y - ny) < 24) {
                idx += 1;
                cutEl.setAttribute('d', 'M' + pts.slice(0, idx + 1).map((p) => p.join(',')).join(' L'));
                tipEl.setAttribute('cx', pts[idx][0]); tipEl.setAttribute('cy', pts[idx][1]);
                cnt(`${Math.round(idx / (pts.length - 1) * 100)}%`);
                if (idx >= pts.length - 1) return end(true);
            }
        };
        const tick = () => { heat = Math.max(0, heat - 0.6); heatEl.style.height = heat + '%'; if (heat >= 100) { down = false; warn.textContent = 'الشعلة ساخنة جدًا! انتظر لحظة'; } raf = requestAnimationFrame(tick); };
        area.addEventListener('mousedown', (e) => {
            if (heat >= 70) return;
            const r = rect(); if (Math.hypot(e.clientX - r.left - pts[idx][0], e.clientY - r.top - pts[idx][1]) < 34) { down = true; warn.textContent = 'تتبّع الخط...'; }
        });
        const up = () => { down = false; };
        window.addEventListener('mousemove', move); window.addEventListener('mouseup', up);
        raf = requestAnimationFrame(tick); cnt('0%');
        G.cleanup = () => { cancelAnimationFrame(raf); window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
    }

    // ---------------------------------------------------------------- sort: every bill into its tray
    function sort(area) {
        const DEN = [{ v: 10, c: '#8a6d3b' }, { v: 20, c: '#4c7a4c' }, { v: 50, c: '#a0573a' }, { v: 100, c: '#3f6a8a' }];
        const N = 14;
        area.innerHTML = `<div class="pile" id="pile"></div><div class="trays">${DEN.map((d, i) => `<button class="tray" data-i="${i}"><b>${i + 1}</b><span class="ltr">$${d.v}</span><em id="tc${i}">0</em></button>`).join('')}</div>`;
        const pile = document.getElementById('pile');
        let done = 0, cur = -1, locked = false;
        const counts = [0, 0, 0, 0];
        const next = () => {
            cur = Math.floor(Math.random() * 4);
            const d = DEN[cur];
            pile.innerHTML = `<div class="note" style="--nc:${d.c};transform:rotate(${(Math.random() * 10 - 5).toFixed(1)}deg)"><i class="ltr">${d.v}</i><span>EX_Tii · ${d.v} DOLLARS</span><i class="ltr">${d.v}</i></div>`;
        };
        const pick = (i) => {
            if (locked || cur < 0) return;
            if (i === cur) {
                counts[i] += 1; document.getElementById('tc' + i).textContent = counts[i];
                done += 1; cnt(`${done}/${N}`);
                const n = pile.firstChild; if (n) n.classList.add('go');
                if (done >= N) return end(true);
                setTimeout(next, 120);
            } else {
                locked = true; area.classList.add('shake');
                setTimeout(() => { area.classList.remove('shake'); locked = false; }, 800);
            }
        };
        area.querySelectorAll('.tray').forEach((b) => b.addEventListener('click', () => pick(Number(b.dataset.i))));
        const key = (e) => { const i = ['Digit1', 'Digit2', 'Digit3', 'Digit4', 'Numpad1', 'Numpad2', 'Numpad3', 'Numpad4'].indexOf(e.code); if (i >= 0) pick(i % 4); };
        window.addEventListener('keydown', key);
        cnt(`0/${N}`); next();
        G.cleanup = () => window.removeEventListener('keydown', key);
    }

    // ---------------------------------------------------------------- drum: keep the spin speed in the green band
    function drum(area) {
        area.innerHTML = `<div class="machine"><div class="door"><div class="glass" id="glass"><i></i><i></i><i></i></div></div>
            <div class="meter"><div class="band" id="band"></div><div class="needle2" id="need"></div></div>
            <div class="fill"><i id="fill"></i></div></div><div class="key">[ مسافة ]</div>`;
        const band = document.getElementById('band'), need = document.getElementById('need'), fill = document.getElementById('fill'), glass = document.getElementById('glass');
        let v = 0.15, held = false, prog = 0, lo = 0.45, hi = 0.65, drift = 0, raf, last = performance.now(), rot = 0;
        const place = () => { band.style.bottom = (lo * 100) + '%'; band.style.height = ((hi - lo) * 100) + '%'; };
        place();
        const tick = (t) => {
            const dt = Math.min(0.05, (t - last) / 1000); last = t;
            v += (held ? 0.55 : -0.42) * dt;
            v = Math.max(0, Math.min(1, v));
            // the band moves slowly up and down: the load shifts in the drum
            drift += dt;
            const mid = 0.55 + Math.sin(drift * 0.9) * 0.2;
            lo = mid - 0.1; hi = mid + 0.1; place();
            const inBand = v >= lo && v <= hi;
            prog = Math.max(0, Math.min(1, prog + (inBand ? dt / 7 : -dt / 14)));
            need.style.bottom = (v * 100) + '%';
            need.classList.toggle('ok', inBand);
            fill.style.width = (prog * 100) + '%';
            rot += v * 900 * dt; glass.style.transform = `rotate(${rot}deg)`;
            cnt(`${Math.round(prog * 100)}%`);
            if (prog >= 1) return end(true);
            raf = requestAnimationFrame(tick);
        };
        const kd = (e) => { if (e.code === 'Space') { e.preventDefault(); held = true; } };
        const ku = (e) => { if (e.code === 'Space') held = false; };
        window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
        raf = requestAnimationFrame(tick);
        G.cleanup = () => { cancelAnimationFrame(raf); window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
    }

    // ---------------------------------------------------------------- band: count 50 notes and band the stack
    function band(area, extra) {
        const stacks = Math.max(1, Math.min(5, (extra && extra.stacks) || 3));
        area.innerHTML = `<div class="stacks" id="stacks">${Array.from({ length: stacks }, (_, i) => `<div class="stack" id="st${i}"><i></i></div>`).join('')}</div>
            <div class="counter"><b id="num">0</b><span>/ 50</span></div><div class="key">اضغط مع الاستمرار · أفلت عند 50</div>`;
        const num = document.getElementById('num');
        let k = 0, down = false, n = 0, speed = 9, raf, last = performance.now(), locked = false;
        document.getElementById('st0').classList.add('on');
        cnt(`0/${stacks}`);
        const tick = (t) => {
            const dt = Math.min(0.05, (t - last) / 1000); last = t;
            if (down && !locked) { n += speed * dt; speed = Math.min(26, speed + 9 * dt); num.textContent = Math.floor(n); num.classList.toggle('over', n > 52); }
            raf = requestAnimationFrame(tick);
        };
        const press = () => { if (!locked) { down = true; n = 0; speed = 9; num.classList.remove('over'); } };
        const release = () => {
            if (!down || locked) return; down = false;
            const c = Math.floor(n);
            if (Math.abs(c - 50) <= 2) {
                const st = document.getElementById('st' + k); st.classList.remove('on'); st.classList.add('done');
                k += 1; cnt(`${k}/${stacks}`);
                if (k >= stacks) return end(true);
                document.getElementById('st' + k).classList.add('on'); num.textContent = '0';
            } else {
                locked = true; area.classList.add('shake'); num.textContent = c < 50 ? 'ناقص' : 'زائد';
                setTimeout(() => { area.classList.remove('shake'); locked = false; num.textContent = '0'; }, 900);
            }
        };
        area.addEventListener('mousedown', press);
        window.addEventListener('mouseup', release);
        raf = requestAnimationFrame(tick);
        G.cleanup = () => { cancelAnimationFrame(raf); window.removeEventListener('mouseup', release); };
    }

    const GAMES = { bolts, lugnuts, pry, torch, sort, drum, band };
    function start(game, title, extra) {
        if (G) return;
        const area = frame(game, title || '', extra && extra.label);
        G = { cleanup: null };
        (GAMES[game] || bolts)(area, extra || {});
    }
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && G) end(false); });
    window.addEventListener('message', (e) => { const m = e.data || {}; if (m.action === 'chopgame') start(m.game, m.title, m.extra); });
    window.EXG_GAME = { start };
})();
