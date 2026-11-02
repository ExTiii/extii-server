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
        melt: 'اضغط مع الاستمرار لتسخّن، أفلت لتبرد. أبقِ الحرارة في المنطقة الخضراء حتى يمتلئ القالب',
        press: 'اضغط المسافة عندما يكون الظرف تحت المكبس تمامًا (8 أظرف). الخطأ يعلّق الآلة',
        boxfill: 'اضغط على الخانة المضيئة لتضع الطلقة قبل أن تنطفئ',
        file: 'اضغط A ثم D بالتناوب بإيقاع ثابت لتبرد الهيكل. السرعة الزائدة تُتلفه',
        assemble: 'احفظ ترتيب القطع ثم اضغطها بنفس الترتيب',
        range: 'أصب الهدف المتحرك 5 مرات (الطلقة الفاشلة تضيّع وقتًا)',
        trim: 'اضغط على كل الأوراق الخضراء الكبيرة لتقصّها، ولا تقصّ البراعم',
        weigh: 'زِد أو أنقص بالأزرار حتى يصير الكيس 2.0 غرام ثم اضغط اختم',
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

    // ---------------------------------------------------------------- melt: hold to heat, keep it in the band
    function melt(area) {
        area.innerHTML = `<div class="crucible"><div class="pot" id="pot"><i id="lead"></i></div><div class="therm"><div class="band" id="band"></div><div class="mercury" id="merc"></div></div>
            <div class="mould"><i id="mould"></i></div></div><div class="key">اضغط بالفأرة مع الاستمرار</div>`;
        const merc = document.getElementById('merc'), band = document.getElementById('band'), mould = document.getElementById('mould'), lead = document.getElementById('lead');
        let heat = 0.1, held = false, prog = 0, t0 = 0, raf, last = performance.now();
        const tick = (t) => {
            const dt = Math.min(0.05, (t - last) / 1000); last = t; t0 += dt;
            heat = Math.max(0, Math.min(1, heat + (held ? 0.42 : -0.3) * dt));
            const mid = 0.6 + Math.sin(t0 * 0.7) * 0.12, lo = mid - 0.09, hi = mid + 0.09;
            band.style.bottom = (lo * 100) + '%'; band.style.height = ((hi - lo) * 100) + '%';
            const ok = heat >= lo && heat <= hi;
            prog = Math.max(0, Math.min(1, prog + (ok ? dt / 6 : (heat > hi ? -dt / 8 : 0))));
            merc.style.height = (heat * 100) + '%'; merc.classList.toggle('hot', heat > hi);
            lead.style.background = `rgb(${120 + heat * 135},${110 + heat * 60},${100 - heat * 60})`;
            mould.style.width = (prog * 100) + '%'; cnt(`${Math.round(prog * 100)}%`);
            if (prog >= 1) return end(true);
            raf = requestAnimationFrame(tick);
        };
        const down = () => { held = true; }, up = () => { held = false; };
        area.addEventListener('mousedown', down); window.addEventListener('mouseup', up);
        raf = requestAnimationFrame(tick);
        G.cleanup = () => { cancelAnimationFrame(raf); window.removeEventListener('mouseup', up); };
    }

    // ---------------------------------------------------------------- press: a casing on a belt under the die
    function press(area) {
        area.innerHTML = `<div class="belt"><div class="die" id="die"></div><div class="slot"></div><div class="casing" id="cas"></div></div><div class="key">[ مسافة ]</div>`;
        const cas = document.getElementById('cas'), die = document.getElementById('die');
        const W = area.clientWidth;
        let x = -40, speed = 210, done = 0, jam = false, raf, last = performance.now();
        const N = 8;
        cnt(`0/${N}`);
        const tick = (t) => {
            const dt = Math.min(0.05, (t - last) / 1000); last = t;
            if (!jam) { x += speed * dt; if (x > W + 40) x = -40; }
            cas.style.left = x + 'px';
            raf = requestAnimationFrame(tick);
        };
        const key = (e) => {
            if (e.code !== 'Space' || jam || cas.classList.contains('pressed')) return; e.preventDefault();
            die.classList.add('down'); setTimeout(() => die.classList.remove('down'), 160);
            if (Math.abs(x - W / 2) <= 22) {
                done += 1; cnt(`${done}/${N}`); cas.classList.add('pressed'); speed += 25;
                setTimeout(() => { cas.classList.remove('pressed'); x = -40; }, 200);
                if (done >= N) return end(true);
            } else {
                jam = true; area.classList.add('shake');
                setTimeout(() => { area.classList.remove('shake'); jam = false; }, 900);
            }
        };
        window.addEventListener('keydown', key);
        raf = requestAnimationFrame(tick);
        G.cleanup = () => { cancelAnimationFrame(raf); window.removeEventListener('keydown', key); };
    }

    // ---------------------------------------------------------------- boxfill: put each round in the lit slot
    function boxfill(area) {
        area.innerHTML = `<div class="ammobox" id="box">${Array.from({ length: 20 }, (_, i) => `<button class="cell" data-i="${i}"></button>`).join('')}</div>`;
        const cells = [...area.querySelectorAll('.cell')];
        let lit = -1, filled = 0, timer = null;
        const N = 20;
        cnt(`0/${N}`);
        const next = () => {
            const free = cells.filter((c) => !c.classList.contains('full'));
            if (!free.length) return end(true);
            cells.forEach((c) => c.classList.remove('lit'));
            const c = free[Math.floor(Math.random() * free.length)]; lit = Number(c.dataset.i); c.classList.add('lit');
            clearTimeout(timer); timer = setTimeout(() => { c.classList.remove('lit'); lit = -1; area.classList.add('shake'); setTimeout(() => area.classList.remove('shake'), 300); timer = setTimeout(next, 500); }, 1100);
        };
        cells.forEach((c) => c.addEventListener('click', () => {
            if (Number(c.dataset.i) !== lit || c.classList.contains('full')) return;
            clearTimeout(timer); c.classList.remove('lit'); c.classList.add('full'); filled += 1; cnt(`${filled}/${N}`); lit = -1;
            if (filled >= N) return end(true);
            setTimeout(next, 150);
        }));
        next();
        G.cleanup = () => clearTimeout(timer);
    }

    // ---------------------------------------------------------------- file: A / D in a steady rhythm
    function file(area) {
        area.innerHTML = `<div class="frame"><div class="gunframe"></div><div class="rasp" id="rasp"></div><div class="sparks" id="sp"></div></div>
            <div class="fill"><i id="fill"></i></div><div class="keys"><b id="ka">A</b><b id="kd">D</b></div>`;
        const rasp = document.getElementById('rasp'), fill = document.getElementById('fill'), ka = document.getElementById('ka'), kd = document.getElementById('kd');
        let want = 'KeyA', prog = 0, lastHit = 0, side = 0;
        const light = () => { ka.classList.toggle('on', want === 'KeyA'); kd.classList.toggle('on', want === 'KeyD'); };
        light();
        const key = (e) => {
            if (e.code !== 'KeyA' && e.code !== 'KeyD') return;
            const now = performance.now(), gap = now - lastHit;
            if (e.code !== want) { prog = Math.max(0, prog - 0.04); area.classList.add('shake'); setTimeout(() => area.classList.remove('shake'), 250); return; }
            lastHit = now;
            if (gap < 120) { prog = Math.max(0, prog - 0.03); document.getElementById('sp').classList.add('bad'); setTimeout(() => document.getElementById('sp').classList.remove('bad'), 200); }
            else prog = Math.min(1, prog + 0.035);
            side = 1 - side; rasp.style.transform = `translateX(${side ? 60 : -60}px)`;
            want = want === 'KeyA' ? 'KeyD' : 'KeyA'; light();
            fill.style.width = (prog * 100) + '%'; cnt(`${Math.round(prog * 100)}%`);
            if (prog >= 1) end(true);
        };
        window.addEventListener('keydown', key);
        cnt('0%');
        G.cleanup = () => window.removeEventListener('keydown', key);
    }

    // ---------------------------------------------------------------- assemble: remember the order
    function assemble(area) {
        const PARTS = [['spring', 'نابض'], ['pin', 'مسمار'], ['slide', 'منزلق'], ['barrel', 'سبطانة'], ['trigger', 'زناد'], ['mag', 'مخزن']];
        area.innerHTML = `<div class="seq" id="seq"></div><div class="parts">${PARTS.map(([k, l], i) => `<button class="part p-${k}" data-i="${i}"><i></i><span>${l}</span></button>`).join('')}</div>`;
        const seqEl = document.getElementById('seq'), btns = [...area.querySelectorAll('.part')];
        let round = 0, order = [], k = 0, showing = true;
        const ROUNDS = [4, 5];
        const show = () => {
            showing = true; k = 0;
            order = Array.from({ length: ROUNDS[round] }, () => Math.floor(Math.random() * PARTS.length));
            seqEl.textContent = 'احفظ الترتيب...';
            order.forEach((p, i) => setTimeout(() => { btns[p].classList.add('show'); setTimeout(() => btns[p].classList.remove('show'), 420); }, 600 + i * 650));
            setTimeout(() => { showing = false; seqEl.textContent = 'الآن أنت: اضغطها بنفس الترتيب'; }, 600 + order.length * 650);
        };
        btns.forEach((b) => b.addEventListener('click', () => {
            if (showing) return;
            const i = Number(b.dataset.i);
            if (i === order[k]) {
                b.classList.add('ok'); setTimeout(() => b.classList.remove('ok'), 200); k += 1;
                if (k >= order.length) { showing = true; round += 1; cnt(`${round}/${ROUNDS.length}`); if (round >= ROUNDS.length) return end(true); setTimeout(show, 700); }
            } else {
                showing = true; area.classList.add('shake'); setTimeout(() => area.classList.remove('shake'), 300); seqEl.textContent = 'خطأ! من جديد...'; setTimeout(show, 1000);
            }
        }));
        cnt(`0/${ROUNDS.length}`); show();
    }

    // ---------------------------------------------------------------- range: hit the moving target 5 times
    function range(area) {
        area.innerHTML = `<div class="target" id="tg"><i></i><i></i><i></i></div><div class="cross" id="cr"></div>`;
        const tg = document.getElementById('tg'), cr = document.getElementById('cr');
        const W = area.clientWidth, H = area.clientHeight;
        let hits = 0, t0 = 0, raf, last = performance.now(), recoil = 0, cool = false;
        cnt('0/5');
        const tick = (t) => {
            const dt = Math.min(0.05, (t - last) / 1000); last = t; t0 += dt * (1 + hits * 0.25);
            const x = W / 2 + Math.sin(t0 * 1.3) * (W / 2 - 70), y = H / 2 + Math.sin(t0 * 2.1) * (H / 2 - 70);
            tg.style.left = x + 'px'; tg.style.top = y + 'px';
            recoil = Math.max(0, recoil - dt * 3); cr.style.transform = `translate(-50%, calc(-50% - ${recoil * 30}px))`;
            raf = requestAnimationFrame(tick);
        };
        const move = (e) => { const r = area.getBoundingClientRect(); cr.style.left = (e.clientX - r.left) + 'px'; cr.style.top = (e.clientY - r.top) + 'px'; };
        const shoot = (e) => {
            if (cool) return; cool = true; setTimeout(() => { cool = false; }, 350);
            recoil = 1;
            const r = area.getBoundingClientRect(), tr = tg.getBoundingClientRect();
            const cx = tr.left + tr.width / 2, cy = tr.top + tr.height / 2;
            if (Math.hypot(e.clientX - cx, e.clientY - cy) < tr.width / 2) {
                hits += 1; cnt(`${hits}/5`); tg.classList.add('hit'); setTimeout(() => tg.classList.remove('hit'), 150);
                if (hits >= 5) return end(true);
            } else { area.classList.add('shake'); setTimeout(() => area.classList.remove('shake'), 200); }
        };
        area.addEventListener('mousemove', move); area.addEventListener('mousedown', shoot);
        raf = requestAnimationFrame(tick);
        G.cleanup = () => cancelAnimationFrame(raf);
    }

    // ---------------------------------------------------------------- trim: cut the fan leaves, not the buds
    function trim(area) {
        const W = area.clientWidth, H = area.clientHeight;
        area.innerHTML = '<div class="bud"></div>';
        let left = 0, bad = 0;
        const N = 12;
        for (let i = 0; i < N + 5; i++) {
            const leaf = i < N;
            const el = document.createElement('button');
            el.className = leaf ? 'leaf' : 'nug';
            const a = (i / (N + 5)) * Math.PI * 2 + Math.random() * 0.3, rr = leaf ? 110 + Math.random() * 30 : 45 + Math.random() * 30;
            el.style.left = (W / 2 + Math.cos(a) * rr) + 'px'; el.style.top = (H / 2 + Math.sin(a) * rr * 0.8) + 'px';
            el.style.transform = `translate(-50%,-50%) rotate(${(a * 180 / Math.PI) + 90}deg)`;
            if (leaf) left += 1;
            el.addEventListener('click', () => {
                if (leaf) { el.classList.add('cut'); el.disabled = true; left -= 1; cnt(`${N - left}/${N}`); if (left <= 0) end(true); }
                else { bad += 1; area.classList.add('shake'); setTimeout(() => area.classList.remove('shake'), 300); }
            });
            area.appendChild(el);
        }
        cnt(`0/${N}`);
    }

    // ---------------------------------------------------------------- weigh: 2.0 g on the scale
    function weigh(area, extra) {
        const bags = Math.max(1, Math.min(4, Math.ceil(((extra && extra.bags) || 3) / 3)));
        area.innerHTML = `<div class="scale"><div class="screen"><b id="g">0.0</b><span>g</span></div><div class="plate"><i id="pile"></i></div></div>
            <div class="wbtns"><button data-d="-0.3">− قليل</button><button data-d="0.7">+ قبصة</button><button data-d="0.2">+ قليل</button><button class="seal" id="seal">اختم الكيس</button></div>`;
        const gEl = document.getElementById('g'), pile = document.getElementById('pile');
        let g = 0, done = 0;
        cnt(`0/${bags}`);
        const show = () => { gEl.textContent = g <= 0 ? '0.0' : Math.max(0, g + (Math.random() - 0.5) * 0.02).toFixed(1); pile.style.transform = `scale(${0.3 + Math.min(1.5, g / 2) * 0.6})`; };
        area.querySelectorAll('.wbtns button[data-d]').forEach((b) => b.addEventListener('click', () => { g = Math.max(0, g + Number(b.dataset.d) * (0.85 + Math.random() * 0.3)); show(); }));
        document.getElementById('seal').addEventListener('click', () => {
            if (Math.abs(g - 2.0) <= 0.1) { done += 1; cnt(`${done}/${bags}`); g = 0; show(); if (done >= bags) end(true); }
            else { area.classList.add('shake'); setTimeout(() => area.classList.remove('shake'), 300); gEl.textContent = g < 2 ? 'ناقص' : 'زائد'; }
        });
        show();
    }

    const GAMES = { bolts, lugnuts, pry, torch, sort, drum, band, melt, press, boxfill, file, assemble, range, trim, weigh };
    function start(game, title, extra) {
        if (G) return;
        // the rebuilt (workshop look) games live in games.js
        if (window.EXG_GAME2 && window.EXG_GAME2.has(game)) { if (!window.EXG_GAME2.start(game, title, extra, (done) => post(done))) post(false); return; }
        const area = frame(game, title || '', extra && extra.label);
        G = { cleanup: null };
        (GAMES[game] || bolts)(area, extra || {});
    }
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && G) end(false); });
    window.addEventListener('message', (e) => { const m = e.data || {}; if (m.action === 'chopgame') start(m.game, m.title, m.extra); });
    window.EXG_GAME = { start };
})();
