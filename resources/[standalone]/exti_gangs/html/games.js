/* =====================================================================
   EX_Tii gangs — the minigames, workshop look.
   Every scene is a real 3D render (html/mg/*.webp, 1200 x 690 scene pixels); the moving parts are
   renders too, placed in the same pixels. Sounds: html/mg/sfx/*.ogg.
   None can be lost: a mistake costs time. ESC stops (the work is lost, as before).
   start(game, title, extra, done)  ->  done(true | false)
   ===================================================================== */
(() => {
    const SW = 1200, SH = 690;
    const box = document.getElementById('game');

    // ------------------------------------------------------------- sounds
    const SFX_VOL = 0.55;
    const pool = {};
    function sfx(name, vol = 1, rate = 1) {
        try {
            const list = pool[name] || (pool[name] = []);
            let a = list.find((x) => x.paused || x.ended);
            if (!a) { a = new Audio(`mg/sfx/${name}.ogg`); list.push(a); }
            a.currentTime = 0; a.volume = Math.min(1, SFX_VOL * vol); a.playbackRate = rate;
            a.play().catch(() => {});
            return a;
        } catch (e) { return null; }
    }
    function loop(name, vol = 1) {
        const a = new Audio(`mg/sfx/${name}.ogg`); a.loop = true; a.volume = 0;
        let want = 0, t = null;
        const tick = () => { a.volume = Math.max(0, Math.min(1, a.volume + (want - a.volume) * 0.25)); if (Math.abs(a.volume - want) < 0.01) { a.volume = want; if (!want) a.pause(); clearInterval(t); t = null; } };
        return {
            on() { want = SFX_VOL * vol; if (a.paused) a.play().catch(() => {}); if (!t) t = setInterval(tick, 30); },
            off() { want = 0; if (!t) t = setInterval(tick, 30); },
            kill() { clearInterval(t); a.pause(); },
        };
    }

    // ------------------------------------------------------------- shell
    let G = null;
    const scale = () => Math.min(1, (innerWidth * 0.64) / SW, (innerHeight * 0.66) / SH);
    function shell(game, title, where, hint, keys) {
        const k = scale();
        box.className = 'mg';
        box.style.setProperty('--k', k);
        box.innerHTML = `<div class="mg-wrap">
            <div class="mg-top"><h3>${title}</h3><span class="where">${where || ''}</span><span class="cnt" id="mgc"></span></div>
            <div class="mg-stage-box"><div class="mg-stage g2-${game}" id="mgs"><img class="bg" id="mgbg" alt=""></div><div class="mg-flash" id="mgf"></div></div>
            <div class="mg-prog"><i id="mgp"></i></div>
            <div class="mg-bar"><span class="hint">${hint}</span><span class="keys">${keys.map(([kb, label, mouse]) => `<span class="mg-key">${label}<kbd class="${mouse ? 'mouse' : ''}">${mouse ? '' : kb}</kbd></span>`).join('')}<span class="mg-key">إيقاف<kbd>ESC</kbd></span></span></div>
        </div>`;
        const stage = document.getElementById('mgs');
        const ctx = {
            k, stage,
            bg(src) { document.getElementById('mgbg').src = `mg/${src}`; },
            img(src, cls) { const i = document.createElement('img'); i.src = `mg/${src}`; i.className = 'spr ' + (cls || ''); i.alt = ''; stage.appendChild(i); return i; },
            el(tag, cls, html) { const e = document.createElement(tag); if (cls) e.className = cls; if (html) e.innerHTML = html; stage.appendChild(e); return e; },
            count(t) { document.getElementById('mgc').textContent = t; },
            prog(p) { document.getElementById('mgp').style.width = `${Math.max(0, Math.min(1, p)) * 100}%`; },
            flash(kind) { const f = document.getElementById('mgf'); f.className = 'mg-flash'; void f.offsetWidth; f.className = `mg-flash ${kind}`; },
            jolt() { stage.classList.remove('jolt'); void stage.offsetWidth; stage.classList.add('jolt'); },
            // mouse -> scene pixels
            at(e) { const r = stage.getBoundingClientRect(); return [(e.clientX - r.left) / k, (e.clientY - r.top) / k]; },
            on(target, ev, fn, opt) { target.addEventListener(ev, fn, opt); G.off.push(() => target.removeEventListener(ev, fn, opt)); },
            raf(fn) { let id, last = performance.now(); const step = (t) => { const dt = Math.min(0.05, (t - last) / 1000); last = t; if (fn(dt, t) !== false && G) id = requestAnimationFrame(step); }; id = requestAnimationFrame(step); G.off.push(() => cancelAnimationFrame(id)); },
            later(fn, ms) { const id = setTimeout(() => { if (G) fn(); }, ms); G.off.push(() => clearTimeout(id)); },
            loop(name, vol) { const l = loop(name, vol); G.off.push(() => l.kill()); return l; },
            sfx,
        };
        return ctx;
    }
    // place a sprite: its anchor (ax, ay) goes to scene point (x, y)
    function put(el, x, y, ax, ay, rot = 0, s = 1) {
        el.style.transformOrigin = `${ax}px ${ay}px`;
        el.style.transform = `translate(${x - ax}px, ${y - ay}px) rotate(${rot}rad) scale(${s})`;
    }
    function finish(done) {
        if (!G) return;
        const g = G; G = null;
        g.off.forEach((f) => { try { f(); } catch (e) {} });
        setTimeout(() => { if (!G) { box.className = 'game hidden'; box.innerHTML = ''; } g.cb(done); }, done ? 650 : 0);
    }
    const M = 3000;                                  // scene pixels per metre (top-down scenes)
    const P = (x, y) => [SW / 2 + x * M, SH / 2 - y * M];

    // ===================================================================== CHOP SHOP
    // ------------------------------------------------------------- bolts: hold the ratchet on each bolt
    function bolts(c) {
        c.bg('bolts_bg.webp');
        const HOLES = [[-0.104, 0.050], [-0.104, -0.050], [0.104, 0.050], [0.104, -0.050]].map(([x, y]) => P(x, y));
        const BA = [48.6, 48.6], RA = [685.6, 75.9];
        const ring = c.el('div', '', '');
        ring.innerHTML = '<svg class="ring" width="1" height="1"><circle r="62" cx="0" cy="0" stroke-dasharray="390" stroke-dashoffset="390" transform="rotate(-90)"/></svg>';
        const ringSvg = ring.firstChild, circ = ringSvg.firstChild;
        const list = HOLES.map(([x, y]) => {
            const img = c.img('bolt.webp', 'm-bolt'); put(img, x, y, ...BA);
            const hit = c.el('div', 'hit'); Object.assign(hit.style, { left: `${x - 46}px`, top: `${y - 46}px`, width: '92px', height: '92px' });
            return { x, y, img, hit, p: 0, done: false };
        });
        const rat = c.img('ratchet.webp', 'm-ratchet');
        let held = null, left = list.length, swing = 0, lastStroke = 0;
        c.count(`0/${list.length}`);
        list.forEach((b) => {
            c.on(b.hit, 'mousedown', (e) => { if (e.button === 0 && !b.done) { held = b; rat.classList.add('on'); } });
            c.on(b.hit, 'mouseleave', () => { if (held === b) { held = null; rat.classList.remove('on'); } });
        });
        c.on(window, 'mouseup', () => { held = null; rat.classList.remove('on'); });
        c.raf((dt) => {
            ringSvg.style.display = held ? '' : 'none';
            if (!held) return;
            const b = held;
            swing += dt * 8.5;
            const s = Math.sin(swing);
            // the bolt only turns on the pull stroke; the pawl clicks on the way back
            if (s > 0) b.p = Math.min(1, b.p + dt * s * 2.1);     // ~1.5 s a bolt
            if (Math.cos(swing) < 0 && s < 0 && performance.now() - lastStroke > 500) { lastStroke = performance.now(); sfx('ratchet', 0.8, 0.95 + Math.random() * 0.1); }
            const out = Math.atan2(-(b.y - SH / 2), -(b.x - SW / 2));
            put(rat, b.x, b.y, ...RA, out + s * 0.32, 1 + b.p * 0.05);
            put(b.img, b.x, b.y, ...BA, -b.p * 9 + s * 0.05, 1 + b.p * 0.12);
            b.img.style.filter = `drop-shadow(${3 + b.p * 6}px ${5 + b.p * 9}px ${3 + b.p * 4}px rgba(0,0,0,.55))`;
            ringSvg.style.transform = `translate(${b.x}px, ${b.y}px)`;
            circ.setAttribute('stroke-dashoffset', String(390 * (1 - b.p)));
            c.prog((list.length - left + b.p) / list.length);
            if (b.p >= 1) {
                b.done = true; held = null; rat.classList.remove('on'); left -= 1;
                sfx('bolt_out', 0.9);
                const dx = (b.x - SW / 2) * 0.25, dy = (b.y - SH / 2) * 0.25 + 40;
                b.img.classList.add('out');
                b.img.style.transform = `translate(${b.x - BA[0] + dx}px, ${b.y - BA[1] + dy}px) rotate(-14rad) scale(1.25)`;
                b.hit.remove();
                c.count(`${list.length - left}/${list.length}`); c.prog((list.length - left) / list.length);
                if (left === 0) { c.flash('ok'); finish(true); return false; }
            }
        });
    }

    // ------------------------------------------------------------- lug nuts: star order with the impact gun
    function lugnuts(c) {
        c.bg('lugs_bg.webp');
        const STUDS = [[-0.0329, 0.0452], [0.0324, 0.0452], [0.0526, -0.0169], [-0.0003, -0.0553], [-0.0531, -0.0169]].map(([x, y]) => P(x, y));
        const NA = [0, 0];
        const order = [0, 2, 4, 1, 3];
        let k = 0, busy = false;
        const mark = c.el('div', 'm-mark');
        const nuts = STUDS.map(([x, y], i) => {
            const img = c.img('lugnut.webp', 'm-nut');
            img.onload = () => { NA[0] = img.naturalWidth / 2; NA[1] = img.naturalHeight / 2; put(img, x, y, NA[0], NA[1], i * 0.4); };
            const hit = c.el('div', 'hit'); Object.assign(hit.style, { left: `${x - 52}px`, top: `${y - 52}px`, width: '104px', height: '104px' });
            return { x, y, img, hit, i };
        });
        const showMark = () => { const n = nuts[order[k]]; mark.style.left = `${n.x}px`; mark.style.top = `${n.y}px`; };
        showMark(); c.count('0/5');
        nuts.forEach((n) => c.on(n.hit, 'mousedown', (e) => {
            if (e.button !== 0 || busy || n.gone || !NA[0]) return;
            if (n.i === order[k]) {
                busy = true; n.gone = true; mark.style.display = 'none';
                sfx('impact', 0.9, 0.96 + Math.random() * 0.08);
                n.img.classList.add('spin');
                n.img.style.transform = `translate(${n.x - NA[0]}px, ${n.y - NA[1]}px) rotate(-16rad) scale(1.28)`;
                c.later(() => {
                    n.img.classList.remove('spin'); n.img.classList.add('drop');
                    n.img.style.transform = `translate(${n.x - NA[0] + 40}px, ${n.y - NA[1] + 330}px) rotate(-19rad) scale(1.4)`;
                    sfx('nut_drop', 0.7);
                    k += 1; c.count(`${k}/5`); c.prog(k / 5);
                    if (k === 5) { c.flash('ok'); finish(true); return; }
                    busy = false; mark.style.display = ''; showMark();
                }, 520);
            } else {
                busy = true; sfx('slip', 0.8); c.jolt(); c.flash('bad');
                n.hit.classList.add('bad');
                c.later(() => { n.hit.classList.remove('bad'); busy = false; }, 900);
            }
        }));
    }

    // ------------------------------------------------------------- a real gauge (face drawn here, chrome bezel render on top)
    // v: 0..1 across the scale. zone(lo, hi) paints the green band.
    function gauge(c, cls, { max = 100, step = 10, unit = '', brand = 'EX·TII TOOL', size = 250 } = {}) {
        const d = c.el('div', 'm-dial ' + (cls || ''));
        d.style.width = d.style.height = `${size}px`;
        const R = 108, CX = 125, CY = 125, SPAN = 243;          // degrees of sweep
        const pol = (deg, r) => { const a = (deg - 90) * Math.PI / 180; return [CX + Math.cos(a) * r, CY + Math.sin(a) * r]; };
        const degOf = (v) => (v - 0.5) * SPAN;
        let ticks = '';
        const minor = step / 5;
        for (let x = 0; x <= max + 1e-6; x += minor) {
            const deg = degOf(x / max), major = Math.abs(x / step - Math.round(x / step)) < 1e-6;
            const [x1, y1] = pol(deg, R - 6), [x2, y2] = pol(deg, R - (major ? 20 : 12));
            ticks += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#1b1a18" stroke-width="${major ? 2.4 : 1.1}"/>`;
            if (major) { const [tx, ty] = pol(deg, R - 34); ticks += `<text x="${tx}" y="${ty + 4}" text-anchor="middle" font-size="${max >= 1000 ? 10 : 12}" font-weight="600" fill="#1b1a18" font-family="Kit Plex">${Math.round(x)}</text>`; }
        }
        d.innerHTML = `<svg viewBox="0 0 250 250">
            <defs><radialGradient id="fc${cls}" cx="50%" cy="45%" r="60%"><stop offset="0" stop-color="#f1ede2"/><stop offset="1" stop-color="#d6d0c1"/></radialGradient></defs>
            <circle cx="${CX}" cy="${CY}" r="${R + 4}" fill="url(#fc${cls})"/>
            <path class="zone" fill="none" stroke="#2f7d45" stroke-width="13" opacity=".9"/>
            ${ticks}
            <text x="${CX}" y="${CY + 44}" text-anchor="middle" font-size="11" fill="#55514a" font-family="Kit Plex" letter-spacing="1" style="direction:ltr;unicode-bidi:bidi-override">${unit}</text>
            <text x="${CX}" y="${CY + 60}" text-anchor="middle" font-size="9" fill="#77716a" font-family="Kit Plex" letter-spacing="2" style="direction:ltr;unicode-bidi:bidi-override">${brand}</text>
            <g class="ndl"><path d="M ${CX - 4} ${CY + 16} L ${CX - 1.6} ${CY - R + 14} L ${CX + 1.6} ${CY - R + 14} L ${CX + 4} ${CY + 16} Z" fill="#c4231c"/></g>
            <circle cx="${CX}" cy="${CY}" r="9" fill="#2a2826"/><circle cx="${CX}" cy="${CY}" r="3.5" fill="#6a6560"/>
        </svg><img class="m-bez" src="mg/bezel.webp" alt=""><div class="m-glass"></div>`;
        const zone = d.querySelector('.zone'), ndl = d.querySelector('.ndl');
        const arc = (a1, a2, r) => { const [x1, y1] = pol(a1, r), [x2, y2] = pol(a2, r); return `M ${x1} ${y1} A ${r} ${r} 0 ${a2 - a1 > 180 ? 1 : 0} 1 ${x2} ${y2}`; };
        return {
            el: d,
            needle(v) { ndl.setAttribute('transform', `rotate(${degOf(Math.max(-0.02, Math.min(1.02, v)))} ${CX} ${CY})`); },
            zone(lo, hi) { zone.setAttribute('d', arc(degOf(lo), degOf(hi), R - 2)); },
        };
    }

    // ------------------------------------------------------------- pry: lever when the needle is in the green
    function pry(c, extra, meta) {
        c.bg('pry_bg.webp');
        const bar = c.img('pry_bar.webp', 'm-bar');
        const pv = (meta && meta.pivot) || [499, 397];
        bar.style.setProperty('--px', `${pv[0]}px`); bar.style.setProperty('--py', `${pv[1]}px`);
        const dial = gauge(c, 'pryg', { max: 100, step: 10, unit: 'LEVER  ×10 N' });
        let ang = -90, dir = 1, speed = 150, hits = 0, zoneAt = 0, wait = false, lever = 0;
        const newZone = () => { zoneAt = -60 + Math.random() * 120; dial.zone((zoneAt - 14 + 90) / 180, (zoneAt + 14 + 90) / 180); };
        newZone(); c.count('0/3');
        c.raf((dt) => {
            ang += dir * speed * dt;
            if (ang > 90) { ang = 90; dir = -1; } if (ang < -90) { ang = -90; dir = 1; }
            dial.needle((ang + 90) / 180);
            bar.style.transform = `rotate(${lever + ang * 0.012}deg)`;
        });
        c.on(window, 'keydown', (e) => {
            if (e.code !== 'Space' || wait) return; e.preventDefault();
            if (Math.abs(ang - zoneAt) <= 14) {
                hits += 1; c.count(`${hits}/3`); c.prog(hits / 3); speed += 40; lever -= 2.6;
                if (hits >= 3) { sfx('pop', 1); c.jolt(); c.flash('ok'); finish(true); return; }
                sfx('strain', 0.9, 0.9 + hits * 0.1); newZone();
            } else {
                wait = true; sfx('slip', 0.9); c.jolt(); c.flash('bad'); lever += 1.5;
                c.later(() => { wait = false; }, 700);
            }
        });
    }

    // ------------------------------------------------------------- torch: follow the chalk line
    function torch(c) {
        c.bg('torch_bg.webp');
        const chalk = c.el('canvas'); chalk.width = SW; chalk.height = SH;
        const cv = c.el('canvas'); cv.width = SW; cv.height = SH;
        const heatEl = c.el('div', 'm-heat', '<i></i><b>حرارة</b>').firstChild;
        const warn = c.el('div', 'm-warn');
        const g = cv.getContext('2d'), ch = chalk.getContext('2d');
        // the cut line, sketched on in soapstone
        const pts = [];
        for (let i = 0; i <= 120; i++) { const x = 150 + 900 * i / 120; pts.push([x, SH / 2 + Math.sin(i / 120 * Math.PI * 2.2) * 165 + Math.sin(i / 14) * 16]); }
        ch.lineCap = 'round';
        for (let pass = 0; pass < 3; pass++) {
            for (let i = 1; i < pts.length; i++) {
                const [x0, y0] = pts[i - 1], [x1, y1] = pts[i];
                for (let s = 0; s < 6; s++) {
                    const t = s / 6, x = x0 + (x1 - x0) * t + (Math.random() - 0.5) * 3, y = y0 + (y1 - y0) * t + (Math.random() - 0.5) * 3;
                    ch.fillStyle = `rgba(236,232,220,${0.08 + Math.random() * 0.16})`;
                    ch.beginPath(); ch.ellipse(x, y, 2 + Math.random() * 2.5, 1.2 + Math.random() * 1.5, Math.random() * 3, 0, 7); ch.fill();
                }
            }
        }
        // start mark
        ch.strokeStyle = 'rgba(236,232,220,.7)'; ch.lineWidth = 3; ch.beginPath(); ch.arc(pts[0][0], pts[0][1], 16, 0, 7); ch.stroke();
        const hiss = c.loop('torch_loop', 0.8);
        let idx = 0, down = false, heat = 0, tip = null, lastCrackle = 0;
        const cut = [];          // { x, y, t }
        const sparks = [];
        warn.textContent = 'اضغط على الدائرة وتتبّع الخط';
        c.count('0%');
        c.on(c.stage, 'mousedown', (e) => {
            if (e.button !== 0 || heat >= 70) return;
            const [x, y] = c.at(e);
            if (Math.hypot(x - pts[idx][0], y - pts[idx][1]) < 52) { down = true; warn.textContent = ''; hiss.on(); }
        });
        c.on(window, 'mouseup', () => { down = false; tip = null; hiss.off(); });
        c.on(window, 'mousemove', (e) => {
            if (!down) return;
            const [x, y] = c.at(e); tip = [x, y];
            const [cx, cy] = pts[idx], [nx, ny] = pts[Math.min(idx + 1, pts.length - 1)];
            if (Math.hypot(x - cx, y - cy) > 54) { heat = Math.min(100, heat + 4); warn.textContent = 'ابقَ على الخط!'; return; }
            warn.textContent = '';
            while (idx < pts.length - 1 && Math.hypot(x - pts[idx + 1][0], y - pts[idx + 1][1]) < 40) {
                idx += 1; cut.push({ x: pts[idx][0], y: pts[idx][1], t: performance.now() });
                c.count(`${Math.round(idx / (pts.length - 1) * 100)}%`); c.prog(idx / (pts.length - 1));
            }
            if (idx >= pts.length - 1) { hiss.off(); sfx('sheet_drop', 1); c.flash('ok'); finish(true); }
        });
        c.raf((dt, now) => {
            heat = Math.max(0, heat - 0.6); heatEl.style.height = `${heat}%`;
            if (heat >= 100 && down) { down = false; tip = null; hiss.off(); warn.textContent = 'الشعلة ساخنة جدًا! انتظر لحظة'; }
            g.clearRect(0, 0, SW, SH);
            if (cut.length) {
                const all = [[pts[0][0], pts[0][1]], ...cut.map((p) => [p.x, p.y])];
                const line = (w, col, from = 0) => { g.strokeStyle = col; g.lineWidth = w; g.lineCap = 'round'; g.lineJoin = 'round'; g.beginPath(); all.slice(from).forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y))); g.stroke(); };
                // heat tint on the steel around the cut (straw -> blue), then the black kerf
                line(46, 'rgba(70,90,140,.10)'); line(28, 'rgba(150,110,60,.16)'); line(13, 'rgba(40,28,20,.75)'); line(6, 'rgba(8,6,5,.95)');
                // the fresh end still glowing, cooling as it goes
                for (let i = Math.max(1, cut.length - 26); i < cut.length; i++) {
                    const age = (now - cut[i].t) / 1000, k = Math.max(0, 1 - age / 1.6);
                    if (k <= 0) continue;
                    const [x0, y0] = i === 0 ? all[0] : [cut[i - 1].x, cut[i - 1].y];
                    g.strokeStyle = `rgba(255,${Math.round(90 + 150 * k)},${Math.round(30 + 120 * k * k)},${0.25 + 0.7 * k})`;
                    g.lineWidth = 3 + 6 * k; g.beginPath(); g.moveTo(x0, y0); g.lineTo(cut[i].x, cut[i].y); g.stroke();
                }
            }
            if (down && tip) {
                const [x, y] = [pts[idx][0], pts[idx][1]];
                // molten puddle + the flame cone
                let gr = g.createRadialGradient(x, y, 0, x, y, 34); gr.addColorStop(0, 'rgba(255,250,220,1)'); gr.addColorStop(0.25, 'rgba(255,190,80,.9)'); gr.addColorStop(1, 'rgba(255,90,20,0)');
                g.fillStyle = gr; g.beginPath(); g.arc(x, y, 34, 0, 7); g.fill();
                gr = g.createRadialGradient(x - 10, y + 10, 0, x - 10, y + 10, 70); gr.addColorStop(0, 'rgba(120,170,255,.45)'); gr.addColorStop(1, 'rgba(60,110,255,0)');
                g.fillStyle = gr; g.beginPath(); g.arc(x - 10, y + 10, 70, 0, 7); g.fill();
                for (let s = 0; s < 6; s++) {
                    const a = Math.random() * Math.PI * 2, v = 250 + Math.random() * 650;
                    sparks.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 0.25 + Math.random() * 0.45, age: 0 });
                }
                if (now - lastCrackle > 950) { lastCrackle = now; sfx('crackle', 0.6); }
            }
            g.lineCap = 'round';
            for (let i = sparks.length - 1; i >= 0; i--) {
                const s = sparks[i]; s.age += dt;
                if (s.age > s.life) { sparks.splice(i, 1); continue; }
                const k = 1 - s.age / s.life, x0 = s.x, y0 = s.y;
                s.vx *= 0.93; s.vy *= 0.93; s.x += s.vx * dt; s.y += s.vy * dt;
                g.strokeStyle = `rgba(255,${Math.round(150 + 100 * k)},${Math.round(60 * k)},${k})`; g.lineWidth = 1.6;
                g.beginPath(); g.moveTo(x0, y0); g.lineTo(s.x, s.y); g.stroke();
            }
        });
    }

    // ===================================================================== MONEY WASH
    // 7-segment digits for the machines' displays
    const SEG = { a: 'M10 4 L50 4 L44 12 L16 12 Z', b: 'M52 6 L52 46 L46 42 L46 14 Z', c: 'M52 54 L52 94 L46 86 L46 58 Z', d: 'M10 96 L50 96 L44 88 L16 88 Z',
        e: 'M8 54 L8 94 L14 86 L14 58 Z', f: 'M8 6 L8 46 L14 42 L14 14 Z', g: 'M10 50 L16 45 L44 45 L50 50 L44 55 L16 55 Z' };
    const DIG = { 0: 'abcdef', 1: 'bc', 2: 'abged', 3: 'abgcd', 4: 'fgbc', 5: 'afgcd', 6: 'afgedc', 7: 'abc', 8: 'abcdefg', 9: 'abcdfg', E: 'afged', r: 'eg', '-': 'g', ' ': '' };
    function seg7(el, n) {
        const chars = ' '.repeat(n);
        el.innerHTML = `<svg viewBox="0 0 ${n * 66} 100">${[...chars].map((ch, i) => Object.keys(SEG).map((k) => `<path transform="translate(${i * 66} 0) skewX(-6)" d="${SEG[k]}" class="${(DIG[ch] || '').includes(k) ? '' : 'off'}" data-i="${i}" data-s="${k}"/>`).join('')).join('')}</svg>`;
        const paths = [...el.querySelectorAll('path')];
        return (val) => {
            const v = String(val).padStart(n, ' ').slice(-n);
            paths.forEach((p) => p.classList.toggle('off', !(DIG[v[Number(p.dataset.i)]] || '').includes(p.dataset.s)));
        };
    }

    // ------------------------------------------------------------- sort: each note into its tray
    function sort(c, extra, meta) {
        c.bg('sort_bg.webp');
        const DEN = [10, 20, 50, 100];
        const TR = (meta && meta.trays) || [[195, 570], [465, 570], [735, 570], [1005, 570]];
        const N = 14;
        const counts = [0, 0, 0, 0];
        const trays = TR.map(([x, y], i) => {
            const t = c.el('div', 'm-tray'); t.style.left = `${x}px`; t.style.top = `${y}px`;
            const tape = c.el('div', 'm-tape', `$${DEN[i]}<kbd>${i + 1}</kbd>`); tape.style.left = `${x}px`; tape.style.top = `${y - 132}px`;
            const tc = c.el('div', 'm-tc'); tc.style.left = `${x}px`; tc.style.top = `${y + 70}px`;
            return { x, y, t, tc, pile: [] };
        });
        let cur = -1, el = null, done = 0, locked = false;
        const next = () => {
            cur = Math.floor(Math.random() * 4);
            el = c.img(`note_${DEN[cur]}.webp`, 'm-note fly');
            const go = () => {
                const ax = el.naturalWidth / 2, ay = el.naturalHeight / 2;
                el.dataset.ax = ax; el.dataset.ay = ay;
                put(el, 230, 130, ax, ay, -0.6, 0.9);          // off the pile, top left
                void el.offsetWidth;
                put(el, 640, 250, ax, ay, (Math.random() - 0.5) * 0.12, 1);
                sfx('note_flick', 0.7, 0.9 + Math.random() * 0.2);
            };
            if (el.complete && el.naturalWidth) go(); else el.onload = go;
        };
        const pick = (i) => {
            if (locked || cur < 0 || !el || !el.dataset.ax) return;     // (the note is still loading)
            if (i === cur) {
                const tr = trays[i], n = el;
                n.classList.remove('fly'); n.classList.add('m-in');
                put(n, tr.x + (Math.random() - 0.5) * 14, tr.y - 6 + (Math.random() - 0.5) * 10, Number(n.dataset.ax), Number(n.dataset.ay), (Math.random() - 0.5) * 0.15 + (i % 2 ? 1.5708 : -1.5708), 0.55);
                sfx('note_drop', 0.8, 0.9 + Math.random() * 0.2);
                tr.pile.push(n); if (tr.pile.length > 4) tr.pile.shift().remove();
                counts[i] += 1; tr.tc.textContent = counts[i];
                done += 1; c.count(`${done}/${N}`); c.prog(done / N); el = null;
                if (done >= N) { c.flash('ok'); finish(true); return; }
                c.later(next, 160);
            } else {
                locked = true; sfx('slip', 0.5, 1.6); c.flash('bad');
                trays[i].t.classList.add('bad');
                put(el, 640 + 18, 250, Number(el.dataset.ax), Number(el.dataset.ay), 0.06, 1);
                c.later(() => { trays[i].t.classList.remove('bad'); if (el) put(el, 640, 250, Number(el.dataset.ax), Number(el.dataset.ay), 0, 1); locked = false; }, 800);
            }
        };
        trays.forEach((t, i) => c.on(t.t, 'mousedown', (e) => { if (e.button === 0) pick(i); }));
        c.on(window, 'keydown', (e) => { const i = ['Digit1', 'Digit2', 'Digit3', 'Digit4', 'Numpad1', 'Numpad2', 'Numpad3', 'Numpad4'].indexOf(e.code); if (i >= 0) pick(i % 4); });
        c.count(`0/${N}`); next();
    }

    // ------------------------------------------------------------- drum: keep the spin speed in the green
    function drum(c, extra, meta) {
        c.bg('drum_bg.webp');
        const [dx, dy, dr] = (meta && meta.door) || [467, 392, 220];
        const load = c.el('div', 'm-load', '<img src="mg/drum_load.webp" alt="">');
        Object.assign(load.style, { left: `${dx - dr}px`, top: `${dy - dr}px`, width: `${dr * 2}px`, height: `${dr * 2}px` });
        const li = load.firstChild;
        c.img('drum_door.webp');
        const dial = gauge(c, 'rpm', { max: 1400, step: 200, unit: 'RPM', brand: 'AQUAMAX' });
        const lcd = c.el('div', 'm-lcd'); Object.assign(lcd.style, { left: '621px', top: '48px', width: '93px', height: '35px' });
        const hum = c.loop('drum_loop', 0.9); hum.on();
        let v = 0.15, held = false, prog = 0, drift = 0, rot = 0, lo = 0.45, hi = 0.65;
        c.raf((dt) => {
            v = Math.max(0, Math.min(1, v + (held ? 0.55 : -0.42) * dt));
            drift += dt; const mid = 0.55 + Math.sin(drift * 0.9) * 0.2; lo = mid - 0.1; hi = mid + 0.1;
            const ok = v >= lo && v <= hi;
            prog = Math.max(0, Math.min(1, prog + (ok ? dt / 7 : -dt / 14)));
            G.dbg = { v, lo, hi };
            dial.needle(v); dial.zone(lo, hi);
            rot += v * 900 * dt;
            li.style.transform = `translate(-50%, -50%) rotate(${rot}deg)`;
            li.style.filter = v > 0.55 ? `blur(${Math.min(3, (v - 0.55) * 7)}px)` : '';
            lcd.textContent = String(Math.round(v * 1400)).padStart(4, ' ');
            c.count(`${Math.round(prog * 100)}%`); c.prog(prog);
            if (prog >= 1) { hum.off(); sfx('beep', 0.8); setTimeout(() => sfx('beep', 0.8), 180); c.flash('ok'); finish(true); return false; }
        });
        c.on(window, 'keydown', (e) => { if (e.code === 'Space') { e.preventDefault(); held = true; } });
        c.on(window, 'keyup', (e) => { if (e.code === 'Space') held = false; });
    }

    // ------------------------------------------------------------- band: count 50 notes, band the stack
    function band(c, extra, meta) {
        c.bg('count_bg.webp');
        const stacks = Math.max(1, Math.min(5, (extra && extra.stacks) || 3));
        const L = (meta && meta.lcd) || [858, 180, 234, 102];
        const lcd = c.el('div', 'm-lcd'); Object.assign(lcd.style, { left: `${L[0]}px`, top: `${L[1]}px`, width: `${L[2]}px`, height: `${L[3]}px` });
        const show = seg7(lcd, 3); show('0');
        const hit = c.el('div', 'm-hit');
        const whirr = c.loop('counter_loop', 0.9);
        const SX = 430, SY = 350;
        let k = 0, down = false, n = 0, speed = 9, locked = false, layers = [], shownN = 0;
        const clearStack = () => { layers.forEach((l) => l.remove()); layers = []; shownN = 0; };
        const addLayer = () => {
            const i = c.img('note_100.webp', 'm-note');
            const go = () => put(i, SX + (Math.random() - 0.5) * 8, SY - layers.length * 1.2 + (Math.random() - 0.5) * 6, i.naturalWidth / 2, i.naturalHeight / 2, (Math.random() - 0.5) * 0.06, 1);
            if (i.complete && i.naturalWidth) go(); else i.onload = go;
            layers.push(i);
        };
        c.count(`0/${stacks}`);
        c.raf((dt) => {
            if (down && !locked) {
                n += speed * dt; speed = Math.min(26, speed + 9 * dt);
                const f = Math.floor(n); show(f); G.dbg = { n: f };
                while (shownN < Math.min(12, Math.floor(f / 5) + 1)) { shownN += 1; addLayer(); }
            }
        });
        c.on(hit, 'mousedown', (e) => { if (e.button !== 0 || locked) return; down = true; n = 0; speed = 9; G.dbg = { n: 0 }; clearStack(); whirr.on(); });
        c.on(window, 'mouseup', () => {
            if (!down || locked) return; down = false; whirr.off();
            const f = Math.floor(n);
            if (Math.abs(f - 50) <= 2) {
                sfx('beep', 0.8); setTimeout(() => sfx('strap', 0.9), 140);
                clearStack();
                const st = c.img('stack_band.webp', 'm-stack');
                const place = () => {
                    const ax = st.naturalWidth / 2, ay = st.naturalHeight / 2;
                    put(st, SX, SY, ax, ay, 0, 1); void st.offsetWidth; st.classList.add('go');
                    put(st, 150 + (k % 3) * 18, 520 - k * 14, ax, ay, -1.5708 + (Math.random() - 0.5) * 0.1, 0.62);
                };
                if (st.complete && st.naturalWidth) place(); else st.onload = place;
                k += 1; c.count(`${k}/${stacks}`); c.prog(k / stacks); show('0');
                if (k >= stacks) { c.flash('ok'); finish(true); }
            } else {
                locked = true; sfx('beep_err', 0.8); c.jolt(); c.flash('bad'); show(f < 50 ? '-  ' : 'Err');
                c.later(() => { locked = false; show('0'); clearStack(); }, 900);
            }
        });
    }

    // ===================================================================== AMMO
    // helper: an image whose anchor is set once it has loaded
    function sprite(c, src, cls, place) {
        const i = c.img(src, cls);
        const go = () => place(i, i.naturalWidth, i.naturalHeight);
        if (i.complete && i.naturalWidth) go(); else i.onload = go;
        return i;
    }

    // ------------------------------------------------------------- melt: hold to heat, keep the lead in the band
    function melt(c, extra, meta) {
        c.bg('melt_bg.webp');
        const [lx, ly, lw, lh] = (meta && meta.lead) || [371, 118, 293, 226];
        const cv = c.el('canvas', 'm-lead'); cv.width = lw; cv.height = lh; Object.assign(cv.style, { left: `${lx}px`, top: `${ly}px` });
        const flame = c.el('div', 'm-flame');
        const g = cv.getContext('2d');
        const dial = gauge(c, 'temp', { max: 500, step: 50, unit: '°C', brand: 'LEAD POT' });
        const roar = c.loop('melt_loop', 0.9); roar.on();
        let heat = 0.1, held = false, prog = 0, t0 = 0;
        const dross = Array.from({ length: 26 }, () => [Math.random(), Math.random(), 4 + Math.random() * 14]);
        c.raf((dt) => {
            t0 += dt;
            heat = Math.max(0, Math.min(1, heat + (held ? 0.42 : -0.3) * dt));
            const mid = 0.6 + Math.sin(t0 * 0.7) * 0.12, lo = mid - 0.09, hi = mid + 0.09;
            const ok = heat >= lo && heat <= hi;
            prog = Math.max(0, Math.min(1, prog + (ok ? dt / 6 : (heat > hi ? -dt / 8 : 0))));
            dial.needle(heat); dial.zone(lo, hi);
            flame.style.opacity = String(0.35 + heat * 0.65); flame.style.transform = `scale(${0.7 + heat * 0.5 + Math.random() * 0.05}, ${0.55 + heat * 0.6 + Math.random() * 0.08})`;
            // the lead: dull and crusted when cold, a liquid mirror when right, smoking orange when too hot
            g.clearRect(0, 0, lw, lh);
            g.save(); g.beginPath(); g.ellipse(lw / 2, lh / 2, lw / 2 - 2, lh / 2 - 2, 0, 0, 7); g.clip();
            const m = Math.max(0, Math.min(1, (heat - 0.25) / 0.3));        // 0 solid .. 1 fully molten
            // solid: a matte grey block; molten: a dark liquid mirror with the lamp's streak sliding on it
            const solid = [104, 104, 108], liquid = [40, 42, 47];
            const col = solid.map((v, i) => Math.round(v + (liquid[i] - v) * m));
            let gr = g.createLinearGradient(0, 0, lw, lh);
            gr.addColorStop(0, `rgb(${col.map((v) => Math.round(v * 1.15)).join(',')})`); gr.addColorStop(1, `rgb(${col.map((v) => Math.round(v * 0.7)).join(',')})`);
            g.fillStyle = gr; g.fillRect(0, 0, lw, lh);
            if (m > 0.05) {
                const sx = lw * (0.38 + Math.sin(t0 * 0.6) * 0.06), sy = lh * (0.36 + Math.cos(t0 * 0.5) * 0.04);
                const hl = g.createRadialGradient(sx, sy, 0, sx, sy, lw * 0.32);
                hl.addColorStop(0, `rgba(235,238,245,${0.75 * m})`); hl.addColorStop(0.35, `rgba(200,205,215,${0.35 * m})`); hl.addColorStop(1, 'rgba(200,205,215,0)');
                g.save(); g.translate(sx, sy); g.scale(1.9, 0.55); g.translate(-sx, -sy); g.fillStyle = hl; g.fillRect(0, 0, lw, lh); g.restore();
                // ripples from the heat
                g.strokeStyle = `rgba(255,255,255,${0.02 + 0.025 * m})`; g.lineWidth = 1;
                for (let k = 0; k < 2; k++) { const rr = ((t0 * 18 + k * 30) % 90) / 90; g.beginPath(); g.ellipse(lw * 0.55, lh * 0.55, lw * 0.45 * rr, lh * 0.45 * rr, 0, 0, 7); g.stroke(); }
            }
            // dross: crust when solid, a few grey skins drifting when molten
            dross.forEach(([u, v, r], k) => {
                const x = (u + Math.sin(t0 * 0.2 + k) * 0.03 * m) * lw, y = (v + Math.cos(t0 * 0.17 + k) * 0.03 * m) * lh;
                g.fillStyle = `rgba(${m > 0.5 ? '120,116,108' : '72,70,66'},${0.8 - m * 0.5})`; g.beginPath(); g.ellipse(x, y, r * (1.7 - m), r * 0.55 * (1.7 - m), k, 0, 7); g.fill();
            });
            // too hot: the gold-blue oxide film real lead gets, and it starts to smoke
            if (heat > hi) {
                const k = Math.min(1, (heat - hi) * 6);
                const ox = g.createLinearGradient(0, lh, lw, 0);
                ox.addColorStop(0, `rgba(200,150,40,${0.45 * k})`); ox.addColorStop(0.5, `rgba(150,60,140,${0.35 * k})`); ox.addColorStop(1, `rgba(40,90,200,${0.45 * k})`);
                g.fillStyle = ox; g.fillRect(0, 0, lw, lh);
            }
            g.restore();
            c.count(`${Math.round(prog * 100)}%`); c.prog(prog);
            if (prog >= 1) { roar.off(); sfx('brass1', 0.6); c.flash('ok'); finish(true); return false; }
        });
        c.on(c.stage, 'mousedown', (e) => { if (e.button === 0) held = true; });
        c.on(window, 'mouseup', () => { held = false; });
    }

    // ------------------------------------------------------------- press: seat each case under the die
    function press(c, extra, meta) {
        c.bg('press_bg.webp');
        const rail = (meta && meta.rail) || 555, DX = (meta && meta.x) || 600;
        const die = c.img('press_die.webp', 'm-die');
        let x = -60, speed = 210, done = 0, jam = false, pressed = false, cw = 45;
        const cas = sprite(c, 'case_side.webp', 'm-case', (i, w, h) => { cw = w; i.dataset.h = h; });
        const N = 8; c.count(`0/${N}`);
        const place = () => { cas.style.transform = `translate(${x - cw / 2}px, ${rail - Number(cas.dataset.h || 80)}px)`; };
        c.raf((dt) => { if (!jam && !pressed) { x += speed * dt; if (x > SW + 60) x = -60; } place(); G.dbg = { x, pressed, jam }; });
        c.on(window, 'keydown', (e) => {
            if (e.code !== 'Space' || jam || pressed) return; e.preventDefault();
            die.classList.add('down'); c.later(() => die.classList.remove('down'), 180);
            if (Math.abs(x - DX) <= 22) {
                pressed = true; sfx('press_thump', 1); done += 1; c.count(`${done}/${N}`); c.prog(done / N); speed += 25;
                c.later(() => { cas.src = 'mg/round_side.webp'; cas.onload = () => { cas.dataset.h = cas.naturalHeight; place(); }; }, 90);
                c.later(() => {
                    sfx(`brass${done % 3}`, 0.7);
                    if (done >= N) { c.flash('ok'); finish(true); return; }
                    cas.src = 'mg/case_side.webp'; cas.onload = () => { cas.dataset.h = cas.naturalHeight; }; x = -60; pressed = false;
                }, 420);
            } else {
                jam = true; sfx('press_jam', 0.9); c.jolt(); c.flash('bad');
                c.later(() => { jam = false; }, 900);
            }
        });
    }

    // ------------------------------------------------------------- boxfill: each round into the lit hole
    function boxfill(c, extra, meta) {
        c.bg('box_bg.webp');
        const CELLS = (meta && meta.cells) || [];
        const glow = c.el('div', 'm-glow');
        const holes = CELLS.map(([x, y], i) => {
            const h = c.el('div', 'hit'); Object.assign(h.style, { left: `${x - 40}px`, top: `${y - 40}px`, width: '80px', height: '80px' });
            return { x, y, h, full: false, i };
        });
        let lit = null, filled = 0;
        const N = holes.length; c.count(`0/${N}`);
        const next = () => {
            const free = holes.filter((h) => !h.full);
            if (!free.length) return;
            lit = free[Math.floor(Math.random() * free.length)];
            glow.style.left = `${lit.x}px`; glow.style.top = `${lit.y}px`; glow.style.display = '';
            const me = lit;
            c.later(() => { if (lit === me) { lit = null; glow.style.display = 'none'; c.flash('bad'); c.later(next, 500); } }, 1100);
        };
        holes.forEach((h) => c.on(h.h, 'mousedown', (e) => {
            if (e.button !== 0 || h !== lit || h.full) return;
            h.full = true; lit = null; glow.style.display = 'none';
            sprite(c, 'round_top.webp', 'm-round', (i, w, hh) => put(i, h.x, h.y, w / 2, hh / 2, Math.random() * 6.28, 1));
            sfx('round_in', 0.8, 0.9 + Math.random() * 0.2);
            filled += 1; c.count(`${filled}/${N}`); c.prog(filled / N);
            if (filled >= N) { c.flash('ok'); finish(true); return; }
            c.later(next, 150);
        }));
        next();
    }

    // ===================================================================== WEAPONS
    // ------------------------------------------------------------- file: A / D in a steady rhythm
    function file(c, extra, meta) {
        c.bg('file_bg.webp');
        const [ex0, ex1, ey] = (meta && meta.edge) || [267, 933, 182];
        const shine = c.el('div', 'm-shine'); Object.assign(shine.style, { left: `${ex0 + 250}px`, top: `${ey + 30}px`, width: `${ex1 - ex0 - 330}px` });
        const cv = c.el('canvas'); cv.width = SW; cv.height = SH; const g = cv.getContext('2d');
        let fw = 1029, fh = 102, side = 0;
        const cx = (ex0 + ex1) / 2 + 60;
        let fl = null;
        const pos = () => { if (fl) put(fl, cx + (side ? 60 : -60), ey + 20, fw / 2, fh / 2, -0.03, 0.72); };
        fl = sprite(c, 'file.webp', 'm-file', (i, w, h) => { fw = w; fh = h; fl = i; pos(); });
        let want = 'KeyA', prog = 0, lastHit = 0;
        const chips = [];
        const keys = document.querySelectorAll('.mg-key kbd');
        const light = () => keys.forEach((k) => k.classList.toggle('on', k.textContent === (want === 'KeyA' ? 'A' : 'D')));
        light(); c.count('0%');
        c.on(window, 'keydown', (e) => {
            if (e.code !== 'KeyA' && e.code !== 'KeyD') return;
            const now = performance.now(), gap = now - lastHit;
            if (e.code !== want) { prog = Math.max(0, prog - 0.04); c.flash('bad'); return; }
            lastHit = now;
            if (gap < 120) { prog = Math.max(0, prog - 0.03); c.flash('bad'); }
            else prog = Math.min(1, prog + 0.035);
            side = 1 - side; pos(); sfx('file_stroke', 0.8, 0.9 + Math.random() * 0.2);
            for (let k = 0; k < 10; k++) chips.push({ x: cx - 120 + Math.random() * 240, y: ey + 30, vx: (Math.random() - 0.5) * 80, vy: 60 + Math.random() * 120, a: 1 });
            want = want === 'KeyA' ? 'KeyD' : 'KeyA'; light();
            shine.style.opacity = String(prog); c.count(`${Math.round(prog * 100)}%`); c.prog(prog);
            if (prog >= 1) { sfx('part_click', 0.8); c.flash('ok'); finish(true); }
        });
        c.raf((dt) => {
            g.clearRect(0, 0, SW, SH);
            for (let i = chips.length - 1; i >= 0; i--) {
                const p = chips[i]; p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 300 * dt; p.a -= dt * 1.2;
                if (p.a <= 0) { chips.splice(i, 1); continue; }
                g.fillStyle = `rgba(200,200,205,${p.a})`; g.fillRect(p.x, p.y, 2, 1.4);
            }
        });
    }

    // ------------------------------------------------------------- assemble: remember the order
    function assemble(c) {
        c.bg('arms_bg.webp');
        const PARTS = [['part_spring', 'نابض الإرجاع'], ['part_hammer', 'المطرقة'], ['part_slide', 'المنزلق'], ['part_trigger', 'الزناد'], ['part_frame', 'الهيكل'], ['part_mag', 'المخزن']];
        const SPOT = [[260, 210], [600, 200], [940, 210], [260, 470], [600, 480], [940, 470]];
        const seqEl = c.el('div', 'm-seq');
        const items = PARTS.map(([src, label], i) => {
            const [x, y] = SPOT[i];
            const img = sprite(c, `${src}.webp`, 'm-part', (el, w, h) => { const k = Math.min(1, 260 / w, 170 / h); el.dataset.k = k; put(el, x, y, w / 2, h / 2, 0, k); el.dataset.ax = w / 2; el.dataset.ay = h / 2; });
            const tag = c.el('div', 'm-ptag', label); tag.style.left = `${x}px`; tag.style.top = `${y + 92}px`;
            const hit = c.el('div', 'hit m-phit'); Object.assign(hit.style, { left: `${x - 140}px`, top: `${y - 100}px`, width: '280px', height: '200px' });
            return { img, hit, x, y };
        });
        const lift = (it, on) => { if (!it.img.dataset.ax) return; it.img.classList.toggle('show', on); put(it.img, it.x, it.y - (on ? 10 : 0), Number(it.img.dataset.ax), Number(it.img.dataset.ay), 0, Number(it.img.dataset.k || 1) * (on ? 1.07 : 1)); };
        let round = 0, order = [], k = 0, showing = true;
        const ROUNDS = [4, 5];
        const show = () => {
            showing = true; k = 0;
            order = Array.from({ length: ROUNDS[round] }, () => Math.floor(Math.random() * PARTS.length));
            seqEl.textContent = 'احفظ الترتيب...';
            order.forEach((p, i) => c.later(() => { lift(items[p], true); sfx('part_click', 0.5, 1.2); c.later(() => lift(items[p], false), 420); }, 600 + i * 650));
            c.later(() => { showing = false; seqEl.textContent = 'الآن أنت: نفس الترتيب'; }, 600 + order.length * 650);
        };
        items.forEach((it, i) => c.on(it.hit, 'mousedown', (e) => {
            if (e.button !== 0 || showing) return;
            if (i === order[k]) {
                lift(it, true); c.later(() => lift(it, false), 200); sfx('part_click', 0.8); k += 1;
                if (k >= order.length) {
                    showing = true; round += 1; c.count(`${round}/${ROUNDS.length}`); c.prog(round / ROUNDS.length); sfx('slide_rack', 0.9);
                    if (round >= ROUNDS.length) { c.flash('ok'); finish(true); return; }
                    c.later(show, 900);
                }
            } else {
                showing = true; c.flash('bad'); c.jolt(); seqEl.textContent = 'خطأ! من جديد...'; c.later(show, 1000);
            }
        }));
        c.count(`0/${ROUNDS.length}`); show();
    }

    // ------------------------------------------------------------- range: hit the moving target 5 times
    function range(c) {
        c.bg('range_bg.webp');
        const tg = c.el('div', 'm-target', '<img src="mg/target.webp" alt=""><i class="rod"></i>');
        const dot = c.el('div', 'm-dot');
        let hits = 0, t0 = 0, cool = false, cur = { x: 600, y: 300, h: 150 };
        c.count('0/5');
        c.raf((dt) => {
            t0 += dt * (1 + hits * 0.25);
            const depth = 0.5 + 0.5 * Math.sin(t0 * 0.9);                  // the carrier runs the target in and out
            const h = 120 + depth * 120, x = 600 + Math.sin(t0 * 1.3) * 380, y = 250 - depth * 40;
            cur = { x, y, h };
            tg.style.transform = `translate(${x - h * 0.38}px, ${y}px)`; tg.style.height = `${h}px`; tg.style.width = `${h * 0.765}px`;
        });
        c.on(c.stage, 'mousemove', (e) => { const [x, y] = c.at(e); dot.style.transform = `translate(${x}px, ${y}px)`; });
        c.on(c.stage, 'mousedown', (e) => {
            if (e.button !== 0 || cool) return; cool = true; c.later(() => { cool = false; }, 350);
            sfx('shot', 1, 0.95 + Math.random() * 0.1); c.jolt();
            const [x, y] = c.at(e);
            const bx = cur.x, by = cur.y + cur.h * (300 / 680), r = cur.h * (230 / 680);
            if (Math.hypot(x - bx, y - by) < r) {
                hits += 1; c.count(`${hits}/5`); c.prog(hits / 5); setTimeout(() => sfx('paper_hit', 0.8), 60);
                const hole = document.createElement('b'); hole.className = 'hole';
                hole.style.left = `${((x - (cur.x - cur.h * 0.38)) / (cur.h * 0.765)) * 100}%`; hole.style.top = `${((y - cur.y) / cur.h) * 100}%`;
                tg.appendChild(hole);
                if (hits >= 5) { c.flash('ok'); finish(true); }
            } else c.flash('bad');
        });
    }

    // ===================================================================== WEED
    // ------------------------------------------------------------- trim: cut the fan leaves, not the buds
    function trim(c) {
        c.bg('trim_bg.webp');
        const N = 12, NUGS = 5, LA = [10.8, 104.2];
        let left = N;
        for (let i = 0; i < N; i++) {
            const a = (i / N) * Math.PI * 2 + (Math.random() - 0.5) * 0.25;
            const r = 70 + Math.random() * 18;
            const x = 600 + Math.cos(a) * r, y = 345 + Math.sin(a) * r * 0.75;
            const leaf = sprite(c, 'fanleaf.webp', 'm-leaf', (el) => put(el, x, y, LA[0], LA[1], a, 0.9 + Math.random() * 0.2));
            const hx = 600 + Math.cos(a) * (r + 120), hy = 345 + Math.sin(a) * (r + 120) * 0.75;
            const hit = c.el('div', 'hit'); Object.assign(hit.style, { left: `${hx - 55}px`, top: `${hy - 55}px`, width: '110px', height: '110px' });
            c.on(hit, 'mousedown', (e) => {
                if (e.button !== 0) return;
                hit.remove(); sfx('snip', 0.9, 0.9 + Math.random() * 0.2); setTimeout(() => sfx('leaf_fall', 0.6), 120);
                leaf.classList.add('cut');
                leaf.style.transform = `translate(${x - LA[0] + Math.cos(a) * 60}px, ${y - LA[1] + 260}px) rotate(${a + 1.2}rad) scale(0.9)`;
                left -= 1; c.count(`${N - left}/${N}`); c.prog((N - left) / N);
                if (left <= 0) { c.flash('ok'); finish(true); }
            });
        }
        for (let i = 0; i < NUGS; i++) {
            const a = (i / NUGS) * Math.PI * 2 + 0.3, x = 600 + Math.cos(a) * 46, y = 345 + Math.sin(a) * 34;
            sprite(c, 'nug.webp', 'm-nug', (el, w, h) => put(el, x, y, w / 2, h / 2, a, 0.7));
            const hit = c.el('div', 'hit'); Object.assign(hit.style, { left: `${x - 30}px`, top: `${y - 30}px`, width: '60px', height: '60px' });
            c.on(hit, 'mousedown', (e) => { if (e.button === 0) { sfx('snip', 0.6, 0.7); c.jolt(); c.flash('bad'); } });
        }
        c.count(`0/${N}`);
    }

    // ------------------------------------------------------------- weigh: 2.00 g on the pocket scale
    function weigh(c, extra, meta) {
        c.bg('scale_bg.webp');
        const bags = Math.max(1, Math.min(4, Math.ceil(((extra && extra.bags) || 3) / 3)));
        const [px, py] = (meta && meta.plate) || [600, 285];
        const L = (meta && meta.lcd) || [525, 471, 150, 48];
        const lcd = c.el('div', 'm-slcd'); Object.assign(lcd.style, { left: `${L[0]}px`, top: `${L[1]}px`, width: `${L[2]}px`, height: `${L[3]}px` });
        const pile = [];
        let g = 0, done = 0;
        c.count(`0/${bags}`);
        const show = () => {
            const shownG = g <= 0 ? 0 : Math.max(0, g + (Math.random() - 0.5) * 0.02);
            lcd.textContent = shownG.toFixed(2);
            const want = Math.round(Math.min(2.6, g) / 0.35);
            while (pile.length < want) { const k = pile.length; pile.push(sprite(c, 'nug.webp', 'm-nug', (el, w, h) => put(el, px + Math.cos(k * 2.4) * 24 * Math.sqrt(k), py + Math.sin(k * 2.4) * 22 * Math.sqrt(k), w / 2, h / 2, k * 1.7, 0.62))); }
            while (pile.length > want) pile.pop().remove();
        };
        const add = (d) => { g = Math.max(0, g + d * (0.85 + Math.random() * 0.3)); sfx('beep', 0.25, 1.6); show(); };
        const seal = () => {
            if (Math.abs(g - 2.0) <= 0.1) {
                done += 1; c.count(`${done}/${bags}`); c.prog(done / bags); sfx('bag_seal', 0.9); g = 0; show();
                if (done >= bags) { c.flash('ok'); finish(true); }
            } else { sfx('beep_err', 0.8); c.flash('bad'); lcd.textContent = g < 2 ? 'Lo' : 'Hi'; }
        };
        c.on(window, 'keydown', (e) => {
            if (e.code === 'KeyQ') add(-0.3); else if (e.code === 'KeyE') add(0.7); else if (e.code === 'KeyW') add(0.2); else if (e.code === 'Space') { e.preventDefault(); seal(); }
        });
        document.querySelectorAll('.mg-key').forEach((k) => {
            const kb = k.querySelector('kbd'); if (!kb) return;
            const map = { Q: () => add(-0.3), E: () => add(0.7), W: () => add(0.2), SPACE: seal };
            if (map[kb.textContent]) { k.style.cursor = 'pointer'; c.on(k, 'mousedown', map[kb.textContent]); }
        });
        show();
    }

    // ===================================================================== start
    const GAMES = { bolts, lugnuts, pry, torch, sort, drum, band, melt, press, boxfill, file, assemble, range, trim, weigh };
    const META = {     // positions measured in the renders (mgstudio out/*.json)
        pry: { pivot: [499, 397] },
        sort: { trays: [[195, 570], [465, 570], [735, 570], [1005, 570]] },
        drum: { door: [467, 392, 220] },
        band: { lcd: [858, 180, 234, 102] },
        melt: { lead: [371, 118, 293, 226] },
        press: { rail: 567, x: 600 },
        boxfill: { cells: [[384, 300], [492, 300], [600, 300], [708, 300], [816, 300], [384, 390], [492, 390], [600, 390], [708, 390], [816, 390], [384, 480], [492, 480], [600, 480], [708, 480], [816, 480], [384, 570], [492, 570], [600, 570], [708, 570], [816, 570]] },
        file: { edge: [267, 933, 182] },
        weigh: { plate: [600, 285], lcd: [525, 471, 150, 48] },
    };
    const TEXT = {
        bolts: ['اضغط مع الاستمرار على كل برغي حتى يخرج', [['', 'اضغط مع الاستمرار', true]]],
        lugnuts: ['فكّ الصواميل بترتيب النجمة: الصامولة المحدّدة أولًا', [['', 'فكّ', true]]],
        pry: ['اضغط المسافة عندما تكون الإبرة في المنطقة الخضراء (3 مرات)', [['SPACE', 'اضغط العتلة']]],
        torch: ['اضغط على بداية الخط وتتبّعه بالشعلة حتى النهاية', [['', 'اضغط مع الاستمرار', true]]],
        sort: ['ضع كل ورقة في درجها: اضغط الدرج أو رقمه (1 = 10$ · 2 = 20$ · 3 = 50$ · 4 = 100$)', [['1-4', 'الدرج'], ['', 'الدرج', true]]],
        drum: ['أبقِ سرعة الغسالة في المنطقة الخضراء حتى تكتمل الدورة', [['SPACE', 'اضغط مع الاستمرار: أسرع']]],
        band: ['اضغط مع الاستمرار ليعدّ الجهاز، وأفلت عند 50 بالضبط (±2) لتربط الرزمة', [['', 'اضغط مع الاستمرار', true]]],
        melt: ['اضغط مع الاستمرار لتسخّن، أفلت لتبرد: أبقِ الحرارة في المنطقة الخضراء حتى يذوب كل الرصاص', [['', 'سخّن', true]]],
        press: ['اضغط المسافة عندما يكون الظرف تحت المكبس تمامًا (8 أظرف). الخطأ يعلّق الآلة', [['SPACE', 'اضغط']]],
        boxfill: ['اضغط على الخانة المضيئة لتضع الطلقة قبل أن تنطفئ', [['', 'ضع الطلقة', true]]],
        file: ['اضغط A ثم D بالتناوب بإيقاع ثابت لتبرد الهيكل. السرعة الزائدة تُتلفه', [['A', 'يسار'], ['D', 'يمين']]],
        assemble: ['احفظ ترتيب القطع ثم اضغطها بنفس الترتيب', [['', 'اختر القطعة', true]]],
        range: ['أصب الهدف المتحرك 5 مرات', [['', 'أطلق', true]]],
        trim: ['قصّ كل الأوراق الكبيرة، ولا تقصّ البراعم', [['', 'قصّ', true]]],
        weigh: ['زِد أو أنقص حتى يصير الكيس 2.00 غرام بالضبط (±0.1) ثم اختم', [['E', 'قبصة'], ['W', 'قليل'], ['Q', 'أنقص'], ['SPACE', 'اختم الكيس']]],
    };
    function start(game, title, extra, cb) {
        if (G || !GAMES[game]) return false;
        const [hint, keys] = TEXT[game];
        G = { off: [], cb };
        const c = shell(game, title || '', (extra && extra.label) || 'ورشة التفكيك', hint, keys);
        try { GAMES[game](c, extra || {}, META[game]); } catch (e) { console.error('[minigame]', game, e); finish(false); }
        return true;
    }
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && G) finish(false); });
    window.EXG_GAME2 = { start, has: (g) => !!GAMES[g], state: () => (G && G.dbg) || null };   // state(): read-only numbers for the browser tests
})();
