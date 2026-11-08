/* =====================================================================
   EX_Tii heists — the robbery minigames, workshop look (the same engine as the gang and job games).
   Every scene is a real 3D render (html/mg/*.webp, 1200 x 690 scene pixels); the moving parts are
   renders too, placed in the same pixels (hmeta.js). Sounds: html/mg/sfx/*.ogg.
   Random every run, active input only. ESC stops = a fail.
   The game (client/main.lua) sends { action: 'start', game, params, title }; we answer POST done { passed }.
   ===================================================================== */
(() => {
    const SW = 1200, SH = 690;
    const box = document.getElementById('game');
    const META = window.HG_META || {};
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'exti_heists';

    // ------------------------------------------------------------- sounds
    const SFX_VOL = 0.6;
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
            set(v) { want = SFX_VOL * vol * v; if (want > 0 && a.paused) a.play().catch(() => {}); if (!t) t = setInterval(tick, 30); },
            kill() { clearInterval(t); a.pause(); },
        };
    }

    // ------------------------------------------------------------- shell
    let G = null;
    const scale = () => Math.min(1, (innerWidth * 0.66) / SW, (innerHeight * 0.7) / SH);
    function shell(game, title, where, hint, keys) {
        const k = scale();
        box.className = 'mg';
        box.style.setProperty('--k', k);
        box.innerHTML = `<div class="mg-wrap">
            <div class="mg-top"><h3>${title}</h3><span class="where">${where || ''}</span><span class="cnt" id="mgc"></span></div>
            <div class="mg-stage-box"><div class="mg-stage h-${game}" id="mgs"><img class="bg" id="mgbg" alt=""></div><div class="mg-flash" id="mgf"></div></div>
            <div class="mg-prog"><i id="mgp"></i></div>
            <div class="mg-bar"><span class="hint">${hint}</span><span class="keys">${keys.map(([kb, label, mouse]) => `<span class="mg-key">${label}<kbd class="${mouse ? 'mouse' : ''}">${mouse ? '' : kb}</kbd></span>`).join('')}<span class="mg-key">إيقاف<kbd>ESC</kbd></span></span></div>
        </div>`;
        const stage = document.getElementById('mgs');
        const ctx = {
            k, stage,
            bg(src) { document.getElementById('mgbg').src = `mg/${src}`; },
            img(src, cls) { const i = document.createElement('img'); i.src = `mg/${src}`; i.className = 'spr ' + (cls || ''); i.alt = ''; i.draggable = false; stage.appendChild(i); return i; },
            el(tag, cls, html) { const e = document.createElement(tag); if (cls) e.className = cls; if (html) e.innerHTML = html; stage.appendChild(e); return e; },
            count(t) { const e = document.getElementById('mgc'); if (e) e.textContent = t; },
            prog(p) { const e = document.getElementById('mgp'); if (e) e.style.width = `${Math.max(0, Math.min(1, p)) * 100}%`; },
            flash(kind) { const f = document.getElementById('mgf'); if (!f) return; f.className = 'mg-flash'; void f.offsetWidth; f.className = `mg-flash ${kind}`; },
            jolt(small) { const c = small ? 'jolt-s' : 'jolt'; stage.classList.remove('jolt', 'jolt-s'); void stage.offsetWidth; stage.classList.add(c); },
            at(e) { const r = stage.getBoundingClientRect(); return [(e.clientX - r.left) / k, (e.clientY - r.top) / k]; },
            on(target, ev, fn, opt) { target.addEventListener(ev, fn, opt); G.off.push(() => target.removeEventListener(ev, fn, opt)); },
            raf(fn) { let id, last = performance.now(); const step = (t) => { const dt = Math.min(0.05, (t - last) / 1000); last = t; if (fn(dt, t) !== false && G) id = requestAnimationFrame(step); }; id = requestAnimationFrame(step); G.off.push(() => cancelAnimationFrame(id)); },
            later(fn, ms) { const id = setTimeout(() => { if (G) fn(); }, ms); G.off.push(() => clearTimeout(id)); },
            loop(name, vol) { const l = loop(name, vol); G.off.push(() => l.kill()); return l; },
            // a countdown in the corner: fails the game at 0
            timer(seconds, onOut) {
                let left = seconds;
                const fmt = () => `${Math.floor(left / 60)}:${String(Math.floor(left % 60)).padStart(2, '0')}`;
                this.count(fmt());
                const api = { left: () => left, take(s) { left = Math.max(0, left - s); } };
                this.raf((dt) => {
                    left -= dt; this.count(fmt());
                    if (left <= 8) { const e = document.getElementById('mgc'); if (e) e.style.color = '#ff6b6b'; }
                    if (left <= 0) { onOut(); return false; }
                });
                return api;
            },
            sfx,
        };
        return ctx;
    }
    function put(el, x, y, ax, ay, rot = 0, sx = 1, sy = sx) {
        el.style.transformOrigin = `${ax}px ${ay}px`;
        el.style.transform = `translate(${x - ax}px, ${y - ay}px) rotate(${rot}rad) scale(${sx}, ${sy})`;
    }
    const A = (name) => META[name] || { ax: 0, ay: 0, w: 0, h: 0 };
    // the server refuses a pass faster than this (config.lua Config.games): never send one sooner
    const MIN_S = { lockpick: 6.3, safedial: 12.3, drill: 8.3, glasscut: 4.3, hack: 6.3, c4: 4.3, wirecut: 3.3, keypad: 4.3 };
    function finish(passed) {
        if (!G) return;
        if (passed && G.game && G.t0) {
            const wait = (MIN_S[G.game] || 0) * 1000 - (performance.now() - G.t0);
            if (wait > 0) { const g0 = G; setTimeout(() => { if (G === g0) finish(true); }, wait); return; }
        }
        const g = G; G = null;
        g.off.forEach((f) => { try { f(); } catch (e) {} });
        setTimeout(() => {
            if (!G) { box.className = 'game hidden'; box.innerHTML = ''; }
            fetch(`https://${RES}/done`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ passed }) }).catch(() => {});
            if (g.cb) g.cb(passed);
        }, passed ? 900 : 120);
    }
    const rnd = (a, b) => a + Math.random() * (b - a);
    const shuffle = (a) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

    // ===================================================================== LOCKPICK (pin tumbler)
    // Hold tension (right mouse / SPACE), slide the pick under a pin (mouse), lift it (left mouse).
    // Only the binding pin sets: lift it to the shear line while holding tension -> click.
    // Push it too far and it jams: let go of the tension (every pin drops) and start again.
    function lockpick(c, p) {
        const m = META.lock_bg;
        c.bg('lock_bg.webp');
        const LEN = { kpin_s: 60, kpin_m: 80, kpin_l: 100 };
        const DRV = 75, SPR = 160;
        const kinds = Object.keys(LEN);
        const level = p.level || 1;
        const tol = 4.5 + (level - 1) * 1.2;        // scene pixels around the shear line
        const pins = m.pins.map((x) => {
            const kind = kinds[Math.floor(Math.random() * kinds.length)];
            const pin = { x, kind, len: LEN[kind], lift: 0, set: false, jam: false };
            pin.need = m.floor - pin.len - m.shear;   // lift that puts its top on the shear line
            pin.spring = c.img('spring.webp'); pin.drv = c.img('dpin.webp'); pin.key = c.img(`${kind}.webp`);
            return pin;
        });
        const order = shuffle(pins.slice());
        const tw = c.img('twrench.webp', 'm-tw');
        const pick = c.img('pick.webp', 'm-pick');
        const ten = c.el('div', 'm-ten', '<i></i><span>الشدّ</span>');
        const warn = c.el('div', 'm-warn', '');
        let tension = false, lifting = false, pickX = m.keyway_x + 60, pickLift = 0, jitter = 0, touching = null;
        const minX = m.keyway_x + 40, maxX = pins[pins.length - 1].x + 34;
        const scrape = c.loop('lp_scrape', 0.5);
        const say = (t) => { warn.textContent = t; warn.classList.toggle('on', !!t); };
        const binding = () => order.find((q) => !q.set);
        const setCount = () => pins.filter((q) => q.set).length;
        c.prog(0);
        const time = c.timer(Math.round(48 * (p.time || 1)), () => { sfx('lp_snap', 1); c.flash('bad'); finish(false); });

        const tensionOn = (v) => {
            if (v === tension) return;
            tension = v; ten.classList.toggle('on', v);
            if (v) { sfx('lp_tension', 0.7); }
            else {
                // every set pin falls back: the plug springs back
                if (pins.some((q) => q.set || q.jam)) sfx('lp_drop', 0.9);
                pins.forEach((q) => { q.set = false; q.jam = false; });
                say(''); c.prog(0);
            }
        };
        c.on(window, 'mousemove', (e) => { const [x] = c.at(e); pickX = Math.max(minX, Math.min(maxX, x)); });
        c.on(window, 'mousedown', (e) => { if (e.button === 0) lifting = true; if (e.button === 2) tensionOn(true); });
        c.on(window, 'mouseup', (e) => { if (e.button === 0) lifting = false; if (e.button === 2) tensionOn(false); });
        c.on(window, 'contextmenu', (e) => e.preventDefault());
        c.on(window, 'keydown', (e) => { if (e.code === 'Space') { e.preventDefault(); tensionOn(true); } });
        c.on(window, 'keyup', (e) => { if (e.code === 'Space') tensionOn(false); });

        let done = false;
        c.raf((dt) => {
            if (done) return false;
            // the pin under the pick
            const under = pins.reduce((best, q) => (Math.abs(q.x - pickX) < 22 && (!best || Math.abs(q.x - pickX) < Math.abs(best.x - pickX)) ? q : best), null);
            const b = binding();
            const feeling = tension && under && under === b && !under.set && !under.jam;
            // lifting: slower against the binding pin (you feel it)
            const speed = lifting ? (feeling ? 46 : 120) : (feeling ? -40 : -190);
            pickLift = Math.max(0, Math.min(70, pickLift + speed * dt));
            if (under !== touching) { if (under && pickLift > 2) sfx('lp_tick', 0.45, rnd(0.9, 1.15)); touching = under; }
            scrape.set(lifting || Math.abs(pickX - (c.lastX || pickX)) > 0.5 ? 0.6 : 0);
            c.lastX = pickX;
            pins.forEach((q) => {
                if (q.jam) return;                        // stuck until the tension is let go
                const want = q === under ? pickLift : 0;
                q.lift += (want - q.lift) * Math.min(1, dt * (want > q.lift ? 30 : 16));
            });
            // the binding pin under tension
            if (feeling) {
                const d = under.lift - under.need;
                jitter = Math.abs(d) < tol * 3 ? (Math.random() - 0.5) * 1.6 : 0;
                under.dwell = Math.abs(d) <= tol ? (under.dwell || 0) + dt : 0;
                if (under.dwell >= 0.12) {
                    under.set = true; under.dwell = 0; sfx('lp_set', 1, rnd(0.95, 1.05)); c.jolt(true); c.prog(setCount() / pins.length);
                    if (setCount() === pins.length) {
                        done = true; scrape.set(0);
                        sfx('lp_open', 1); c.flash('ok'); c.jolt();
                        put(tw, m.keyway_x + 20, m.keyway_y + 30, A('twrench').ax, A('twrench').ay, 0.35);
                        finish(true);
                        return false;
                    }
                } else if (d > tol + 6) {
                    under.jam = true; sfx('lp_jam', 0.9); c.jolt(true);
                    say('دفعته أكثر من اللازم: خفّف الشدّ لتعيد المحاولة');
                }
            } else jitter = 0;

            // draw: key pin, driver, spring
            pins.forEach((q) => {
                const kBot = m.floor - q.lift;
                const kTop = kBot - q.len;
                const dBot = q.set ? Math.min(m.shear, kTop) : kTop;
                const dTop = dBot - DRV;
                const ka = A(q.kind), da = A('dpin'), sa = A('spring');
                put(q.key, q.x, kBot, ka.ax, ka.ay);
                put(q.drv, q.x, dBot, da.ax, da.ay);
                const sy = Math.max(0.2, (dTop - m.top) / SPR);
                put(q.spring, q.x, dTop, sa.ax, sa.ay, 0, 1, sy);
            });
            const pa = A('pick');
            put(pick, pickX, m.floor - pickLift + jitter, pa.ax, pa.ay, -pickLift * 0.0016);
            const ta = A('twrench');
            put(tw, m.keyway_x + 20, m.keyway_y + 30, ta.ax, ta.ay, tension ? 0.06 : 0);
        });
        G.dbg = () => ({ pins: pins.map((q) => ({ x: q.x, need: q.need, lift: q.lift, set: q.set, jam: q.jam })), order: order.map((q) => pins.indexOf(q)), tension, pickX, pickLift, tol, left: time.left() });
    }

    // ===================================================================== SAFE DIAL
    // Turn the dial (drag it, or A / D, SHIFT = slow). Each number: turn the right way (right, left, right),
    // listen for the contact click, stop on it and press SPACE. Wrong = the wheels reset.
    function safedial(c, p) {
        const m = META.safe_bg;
        c.bg('safe_bg.webp?v=2');   // (v=2: thin red mark)
        const n = Math.max(2, Math.min(4, p.numbers || 3));
        const combo = [];
        while (combo.length < n) {
            const v = Math.floor(Math.random() * 100);
            if (combo.every((o) => Math.abs(o - v) > 12 && Math.abs(o - v) < 88) && Math.abs(v) > 6) combo.push(v);
        }
        const dial = c.img('dial.webp', 'm-dial');
        const da = A('dial');
        const [cx, cy] = m.dial;
        const lamps = c.el('div', 'm-lamps', Array.from({ length: n }, () => '<i></i>').join(''));
        lamps.style.left = `${cx + 176}px`; lamps.style.top = `${cy - 118}px`;
        const dirEl = c.el('div', 'm-dir', ''); dirEl.style.left = `${cx + 170}px`; dirEl.style.top = `${cy - 160}px`;
        const read = c.el('div', 'm-read', '00'); read.style.left = `${cx - 22}px`; read.style.top = `${cy + 175}px`;
        const steth = c.el('div', 'm-steth', '<canvas width="250" height="92"></canvas><b>CONTACT AMP</b>');
        const cv = steth.querySelector('canvas'), g2 = cv.getContext('2d');
        let angle = Math.random() * 360, k = 0, lastDir = 0, lastVal = null, heard = 0, wave = [], done = false;
        const valueOf = (a) => ((Math.round(-a / 3.6) % 100) + 100) % 100;
        const dirOf = (i) => (i % 2 === 0 ? 1 : -1);             // 1 = right (clockwise), -1 = left
        const showDir = () => { dirEl.textContent = dirOf(k) > 0 ? 'أدر يمينًا ⟳' : 'أدر يسارًا ⟲'; };
        showDir();
        const time = c.timer(Math.round(70 * (p.time || 1)), () => { c.flash('bad'); sfx('dial_wrong', 0.8); finish(false); });

        const turn = (deg) => {
            if (done || !deg) return;
            angle += deg;
            lastDir = deg > 0 ? 1 : -1;
            const v = valueOf(angle);
            if (v !== lastVal) {
                // every number you pass ticks; the right one, the right way, clicks
                if (v === combo[k] && lastDir === dirOf(k)) { sfx('dial_contact', 0.95, rnd(0.97, 1.03)); heard = 1; c.jolt(true); }
                else sfx('dial_tick', 0.35, rnd(0.92, 1.08));
                lastVal = v;
            }
        };
        let drag = null;
        c.on(dial, 'mousedown', (e) => { if (e.button === 0) { const [x, y] = c.at(e); drag = Math.atan2(y - cy, x - cx); } });
        c.on(window, 'mouseup', () => { drag = null; });
        c.on(window, 'mousemove', (e) => {
            if (drag === null) return;
            const [x, y] = c.at(e); const a = Math.atan2(y - cy, x - cx);
            let d = a - drag; if (d > Math.PI) d -= 2 * Math.PI; if (d < -Math.PI) d += 2 * Math.PI;
            drag = a;
            // one number at a time, so no tick is skipped
            let deg = d * 180 / Math.PI;
            while (Math.abs(deg) > 0.01) { const s = Math.sign(deg) * Math.min(3.6, Math.abs(deg)); turn(s); deg -= s; }
        });
        c.on(window, 'wheel', (e) => turn(e.deltaY > 0 ? 3.6 : -3.6));
        const keys = {};
        c.on(window, 'keydown', (e) => {
            keys[e.code] = true;
            if (e.code === 'Space' && !e.repeat) {
                e.preventDefault();
                const v = valueOf(angle);
                if (v === combo[k] && lastDir === dirOf(k)) {
                    lamps.children[k].classList.add('on'); sfx('dial_gate', 1); c.flash('ok');
                    k += 1; lastDir = 0;
                    if (k >= n) {
                        done = true; dirEl.textContent = '';
                        sfx('safe_open', 1); c.jolt();
                        finish(true);
                    } else showDir();
                } else {
                    sfx('dial_wrong', 0.9); c.flash('bad'); c.jolt();
                    [...lamps.children].forEach((l) => l.classList.remove('on'));
                    k = 0; lastDir = 0; showDir(); time.take(3);
                }
            }
        });
        c.on(window, 'keyup', (e) => { keys[e.code] = false; });
        c.raf((dt) => {
            const speed = keys.ShiftLeft || keys.ShiftRight ? 26 : 140;   // degrees a second
            if (keys.KeyD) turn(Math.min(3.6, speed * dt));
            if (keys.KeyA) turn(-Math.min(3.6, speed * dt));
            // EX_Tii (Moe): the dial always sits on a whole number, exactly under the red mark (never between two)
            const snapped = Math.round(angle / 3.6) * 3.6;
            put(dial, cx, cy, da.ax, da.ay, snapped * Math.PI / 180);
            read.textContent = String(valueOf(angle)).padStart(2, '0');
            // the contact amplifier: louder when you are close, the right way
            const v = valueOf(angle);
            let near = 0;
            if (!done && lastDir === dirOf(k)) { let d = Math.abs(v - combo[k]); d = Math.min(d, 100 - d); near = Math.max(0, 1 - d / 9); }
            heard = Math.max(0, heard - dt * 2.2);
            const amp = 4 + near * 16 + heard * 30;
            wave.push(amp * (Math.random() * 2 - 1)); if (wave.length > 125) wave.shift();
            g2.clearRect(0, 0, 250, 92);
            g2.strokeStyle = 'rgba(120,255,160,.12)'; g2.lineWidth = 1;
            for (let x = 0; x < 250; x += 25) { g2.beginPath(); g2.moveTo(x, 0); g2.lineTo(x, 92); g2.stroke(); }
            g2.beginPath(); g2.moveTo(0, 46); g2.lineTo(250, 46); g2.stroke();
            g2.strokeStyle = 'rgba(130,255,170,.9)'; g2.shadowColor = 'rgba(80,255,140,.8)'; g2.shadowBlur = 6; g2.lineWidth = 1.6;
            g2.beginPath(); wave.forEach((y, i) => (i ? g2.lineTo(i * 2, 46 + y) : g2.moveTo(0, 46 + y))); g2.stroke(); g2.shadowBlur = 0;
            c.prog(k / n);
        });
        G.dbg = () => ({ combo: combo.slice(), k, angle, value: valueOf(angle), lastDir, need: dirOf(k), left: time.left() });
    }


    // ===================================================================== DRILL (pressure and heat)
    // Hold the left mouse (or SPACE) to push the drill, let go to ease off. Every layer wants its own
    // pressure: too little and you barely move, too much and the bit heats up. At the red line it snaps.
    function drill(c, p) {
        const m = META.drill_bg;
        c.bg('drill_bg.webp');
        const level = p.level || 1;
        const heatMul = 1 - (level - 1) * 0.08;                  // breaching skill: the bit heats slower
        const L = [   // [from, to, sweet pressure, hardness, sparks]
            [m.skin, m.hard, 0.45, 0.8, true], [m.hard, m.fill, 0.82, 1.6, true], [m.fill, m.relock, 0.40, 0.7, false],
            [m.relock, m.case, 0.70, 1.3, true], [m.case, m.target, 0.55, 0.9, true],
        ].map((l) => ({ from: l[0], to: l[1], sweet: Math.min(0.92, Math.max(0.25, l[2] + rnd(-0.12, 0.12))), hard: l[3], sparks: l[4] }));
        const start = m.skin - 26;
        const bore = c.el('div', 'm-bore'); bore.style.top = `${m.bore_y - 9}px`; bore.style.left = `${m.skin}px`;
        const tool = c.img('drill.webp', 'm-drill');
        const dA = A('drill');
        const glow = c.el('div', 'm-glow');
        const sparks = c.el('div', 'm-sparks');
        // the gauges: heat (needle in a bezel) and pressure
        const gauge = c.el('div', 'm-gauge', '<img src="mg/bezel.webp"><i class="n"></i><b>HEAT</b><em class="red"></em>');
        const press = c.el('div', 'm-press', '<b>الضغط</b><div class="tr"><i class="sw"></i><i class="v"></i></div>');
        const layerTxt = c.el('div', 'm-layer', '');
        const NAMES = ['الغلاف', 'الصفيحة المقسّاة', 'الحشوة', 'قفل الأمان', 'علبة القفل'];
        const motor = c.loop('dr_motor', 0.9), grind = c.loop('dr_grind', 0.8);
        let pressure = 0, heat = 0, x = start, held = false, done = false, li = 0, hiss = 0;
        const down = (e) => { if (e.button === 0 || e.code === 'Space') { held = true; e.preventDefault(); } };
        const up = (e) => { if (e.button === 0 || e.code === 'Space') held = false; };
        c.on(window, 'mousedown', down); c.on(window, 'mouseup', up); c.on(window, 'keydown', down); c.on(window, 'keyup', up);
        c.on(window, 'contextmenu', (e) => e.preventDefault());
        const time = c.timer(Math.round(70 * (p.time || 1)), () => { if (!done) { done = true; motor.set(0); grind.set(0); c.flash('bad'); sfx('lp_drop', 0.6); finish(false); } });
        c.raf((dt) => {
            if (done) return false;
            pressure += ((held ? 1 : 0) - pressure) * Math.min(1, dt * (held ? 1.6 : 2.6));
            const touching = x >= m.skin - 1;
            while (li < L.length - 1 && x >= L[li].to) li++;
            const ly = L[li];
            let speed = 0;
            if (touching || held) {
                const off = pressure - ly.sweet;
                const good = Math.max(0, 1 - Math.abs(off) / 0.22);
                speed = touching ? (10 + 62 * good * pressure) / ly.hard : 60 * pressure;
                if (touching) heat += dt * (pressure * pressure * 26 * ly.hard + Math.max(0, off) * 120 * ly.hard) * heatMul;
            }
            heat -= dt * (held ? 6 : 22);
            heat = Math.max(0, heat);
            x = Math.min(m.target, x + speed * dt);
            motor.set(0.25 + pressure * 0.75);
            grind.set(touching && pressure > 0.08 ? (ly.sparks ? 0.4 + pressure * 0.6 : 0.25) : 0);
            put(tool, x, m.bore_y, dA.ax, dA.ay, 0, 1);
            const jitter = touching ? pressure * 1.4 : 0.4;
            tool.style.marginTop = `${(Math.random() - 0.5) * jitter * 2}px`;
            bore.style.width = `${Math.max(0, x - m.skin)}px`;
            const h = Math.min(1, heat / 100);
            glow.style.left = `${x - 30}px`; glow.style.top = `${m.bore_y - 30}px`; glow.style.opacity = touching ? (0.15 + h * 0.85).toFixed(2) : 0;
            glow.style.setProperty('--h', h.toFixed(2));
            sparks.style.left = `${x}px`; sparks.style.top = `${m.bore_y}px`;
            sparks.classList.toggle('on', touching && ly.sparks && pressure > 0.2);
            gauge.querySelector('.n').style.transform = `rotate(${-120 + h * 240}deg)`;
            press.querySelector('.v').style.height = `${pressure * 100}%`;
            press.querySelector('.sw').style.bottom = `${(ly.sweet - 0.11) * 100}%`;
            layerTxt.textContent = touching ? NAMES[li] : '';
            if (h > 0.8 && (hiss -= dt) < 0) { hiss = 0.6; sfx('dr_hiss', 0.4 + h * 0.4); c.jolt(true); }
            c.prog((x - start) / (m.target - start));
            if (heat >= 100) {
                done = true; motor.set(0); grind.set(0); sfx('dr_snap'); c.flash('bad'); c.jolt();
                c.later(() => finish(false), 500); return false;
            }
            if (x >= m.target) {
                done = true; motor.set(0); grind.set(0); sfx('dr_through'); c.flash('good');
                c.later(() => finish(true), 300); return false;
            }
        });
        G.dbg = () => ({ x, target: m.target, heat, pressure, sweet: L[li].sweet, li, left: time.left(), hold: (v) => { held = v; } });
    }

    // ===================================================================== GLASS CUTTING (a steady hand)
    // Hold the left mouse on the dashed circle and go once round it with the cutter. Off the line, or
    // too fast, and the glass is stressed; too much and it cracks loudly.
    function glasscut(c, p) {
        const m = META.glass_bg;
        c.bg('glass_bg.webp');
        const [cx, cy] = [m.center[0] + rnd(-120, 120), m.center[1] + rnd(-40, 40)];
        const R = 118, tol = 11 * (p.time || 1);
        const guide = c.el('div', 'm-guide'); guide.style.left = `${cx - R}px`; guide.style.top = `${cy - R}px`; guide.style.width = guide.style.height = `${R * 2}px`;
        const cv = c.el('canvas', 'm-score'); cv.width = SW; cv.height = SH; const g2 = cv.getContext('2d');
        const tool = c.img('cutter.webp', 'm-cutter'); const tA = A('cutter');
        const stressEl = c.el('div', 'm-stress', '<b>إجهاد الزجاج</b><div class="tr"><i></i></div>');
        const scoreLoop = c.loop('gl_score', 0.8);
        let held = false, last = null, ang = null, swept = 0, stress = 0, done = false, mx = cx + R, my = cy, rot = 0;
        c.on(c.stage, 'mousemove', (e) => { [mx, my] = c.at(e); });
        c.on(window, 'mousedown', (e) => { if (e.button === 0) held = true; });
        c.on(window, 'mouseup', (e) => { if (e.button === 0) { held = false; last = null; } });
        const time = c.timer(Math.round(35 * (p.time || 1)), () => { if (!done) { done = true; scoreLoop.set(0); finish(false); } });
        g2.strokeStyle = 'rgba(235,245,255,.85)'; g2.lineWidth = 1.6; g2.shadowColor = 'rgba(255,255,255,.7)'; g2.shadowBlur = 3; g2.lineCap = 'round';
        c.raf((dt) => {
            if (done) return false;
            const dx = mx - cx, dy = my - cy, r = Math.hypot(dx, dy), a = Math.atan2(dy, dx);
            let moving = 0;
            if (held && last) {
                const sp = Math.hypot(mx - last[0], my - last[1]) / Math.max(dt, 0.001);
                moving = sp;
                if (Math.abs(r - R) > tol) stress += dt * (60 + Math.abs(r - R) * 4);
                else if (sp > 520) stress += dt * (sp - 520) * 0.35;
                else {
                    if (ang !== null) {
                        let d = a - ang; if (d > Math.PI) d -= 2 * Math.PI; if (d < -Math.PI) d += 2 * Math.PI;
                        if (Math.abs(d) < 0.5) swept += d;
                    }
                    g2.beginPath(); g2.moveTo(last[0], last[1]); g2.lineTo(mx, my); g2.stroke();
                }
                if (sp > 4) rot = Math.atan2(my - last[1], mx - last[0]);
            }
            ang = a;
            if (held) last = [mx, my];
            stress = Math.max(0, stress - dt * 9);
            scoreLoop.set(held && moving > 15 && Math.abs(r - R) <= tol ? Math.min(1, moving / 300) : 0);
            put(tool, mx, my, tA.ax, tA.ay, rot + Math.PI / 2, 1);
            stressEl.querySelector('i').style.width = `${Math.min(100, stress)}%`;
            stressEl.classList.toggle('hot', stress > 65);
            c.prog(Math.abs(swept) / (2 * Math.PI));
            if (stress >= 100) {
                done = true; scoreLoop.set(0); sfx('gl_crack'); c.flash('bad'); c.jolt();
                c.el('div', 'm-crack').style.cssText = `left:${mx - 160}px;top:${my - 160}px`;
                c.later(() => finish(false), 700); return false;
            }
            if (Math.abs(swept) >= 2 * Math.PI - 0.08) {
                done = true; scoreLoop.set(0); sfx('gl_free'); c.flash('good');
                guide.classList.add('free');
                c.later(() => finish(true), 400); return false;
            }
        });
        G.dbg = () => ({ cx, cy, R, swept, stress, left: time.left(), move: (x, y) => { mx = x; my = y; }, hold: (v) => { held = v; if (!v) last = null; } });
    }

    // ===================================================================== LAPTOP HACK (route the signal)
    // Click the tiles on the board to turn them and make one unbroken line from the input on the left to
    // the output on the right before the clock runs out. Harder with each USB colour.
    function hack(c, p) {
        const m = META.laptop_bg;
        c.bg('laptop_bg.webp');
        const [[x0, y0], [x1, y1]] = m.screen;
        const tier = Math.max(1, Math.min(4, p.tier || 1));
        const COLS = [7, 8, 9, 10][tier - 1], ROWS = [4, 4, 5, 5][tier - 1];
        const scr = c.el('div', 'm-screen'); scr.style.cssText = `left:${x0}px;top:${y0}px;width:${x1 - x0}px;height:${y1 - y0}px`;
        const W = x1 - x0, H = y1 - y0, pad = 34;
        const cell = Math.floor(Math.min((W - 60) / COLS, (H - pad - 14) / ROWS));
        const ox = Math.floor((W - cell * COLS) / 2), oy = pad + Math.floor((H - pad - cell * ROWS) / 2);
        scr.innerHTML = `<div class="hd"><span>ICE // ${['GRN', 'BLU', 'RED', 'AU'][tier - 1]}-${tier}</span><span id="hkst">ROUTING…</span></div><div class="scan"></div>`;
        // a path from the left edge to the right edge, then the rest random; every tile scrambled
        const N = 1, E = 2, S = 4, Wd = 8;
        const grid = Array.from({ length: ROWS }, () => Array(COLS).fill(0));
        const sr = Math.floor(Math.random() * ROWS); let r = sr, col = 0, prev = Wd;
        const seen = new Set();
        while (col < COLS) {
            seen.add(`${r},${col}`);
            let next;
            const opts = [];
            if (col === COLS - 1) next = E;
            else {
                opts.push(E, E);
                if (r > 0 && !seen.has(`${r - 1},${col}`) && prev !== N) opts.push(N);
                if (r < ROWS - 1 && !seen.has(`${r + 1},${col}`) && prev !== S) opts.push(S);
                next = opts[Math.floor(Math.random() * opts.length)];
            }
            grid[r][col] = prev | next;
            if (next === E) { col++; prev = Wd; } else if (next === N) { r--; prev = S; } else { r++; prev = N; }
        }
        const tr = r;
        const SHAPES = [N | S, N | E, N | E | S];
        for (let i = 0; i < ROWS; i++) for (let j = 0; j < COLS; j++) if (!grid[i][j]) grid[i][j] = SHAPES[Math.floor(Math.random() * SHAPES.length)];
        const rotr = (v) => ((v << 1) | (v >> 3)) & 15;
        const solved = grid.map((row) => row.slice());
        for (let i = 0; i < ROWS; i++) for (let j = 0; j < COLS; j++) { const k = 1 + Math.floor(Math.random() * 3); for (let q = 0; q < k; q++) grid[i][j] = rotr(grid[i][j]); }
        const tiles = [];
        const svgOf = (v) => {
            const seg = [];
            if (v & N) seg.push('M50 50 L50 0'); if (v & E) seg.push('M50 50 L100 50'); if (v & S) seg.push('M50 50 L50 100'); if (v & Wd) seg.push('M50 50 L0 50');
            return `<svg viewBox="0 0 100 100"><path d="${seg.join(' ')}" /><circle cx="50" cy="50" r="7"/></svg>`;
        };
        for (let i = 0; i < ROWS; i++) {
            tiles[i] = [];
            for (let j = 0; j < COLS; j++) {
                const t = document.createElement('div'); t.className = 'tile';
                t.style.cssText = `left:${ox + j * cell}px;top:${oy + i * cell}px;width:${cell}px;height:${cell}px`;
                t.innerHTML = svgOf(grid[i][j]);
                t.onmousedown = (e) => { if (done || e.button !== 0) return; grid[i][j] = rotr(grid[i][j]); t.innerHTML = svgOf(grid[i][j]); sfx('lt_turn', 0.8); flow(); };
                scr.appendChild(t); tiles[i][j] = t;
            }
        }
        const port = (cls, row) => { const e = document.createElement('div'); e.className = `port ${cls}`; e.style.top = `${oy + row * cell + cell / 2 - 7}px`; scr.appendChild(e); };
        port('in', sr); port('out', tr);
        let done = false;
        function flow() {
            const lit = new Set(); const q = [];
            if (grid[sr][0] & Wd) { q.push([sr, 0]); lit.add(`${sr},0`); }
            while (q.length) {
                const [i, j] = q.shift(); const v = grid[i][j];
                for (const [d, di, dj, back] of [[N, -1, 0, S], [E, 0, 1, Wd], [S, 1, 0, N], [Wd, 0, -1, E]]) {
                    const ni = i + di, nj = j + dj;
                    if (!(v & d) || ni < 0 || nj < 0 || ni >= ROWS || nj >= COLS) continue;
                    if ((grid[ni][nj] & back) && !lit.has(`${ni},${nj}`)) { lit.add(`${ni},${nj}`); q.push([ni, nj]); }
                }
            }
            for (let i = 0; i < ROWS; i++) for (let j = 0; j < COLS; j++) tiles[i][j].classList.toggle('lit', lit.has(`${i},${j}`));
            c.prog(lit.size / (ROWS * COLS) * 1.4);
            if (lit.has(`${tr},${COLS - 1}`) && (grid[tr][COLS - 1] & E) && !done) {
                done = true; sfx('lt_ok'); c.flash('good');
                document.getElementById('hkst').textContent = 'ACCESS GRANTED';
                scr.classList.add('ok');
                c.later(() => finish(true), 700);
            }
        }
        flow();
        const time = c.timer(Math.round([50, 45, 40, 35][tier - 1] * (p.time || 1)), () => {
            if (done) return; done = true; sfx('lt_wrong'); c.flash('bad');
            document.getElementById('hkst').textContent = 'TRACE COMPLETE'; scr.classList.add('bad');
            c.later(() => finish(false), 700);
        });
        G.dbg = () => ({ grid: grid.map((row) => row.slice()), solved, sr, tr, left: time.left(), turn: (i, j) => tiles[i][j].onmousedown({ button: 0 }) });
    }


    // ------------------------------------------------------------- cables (C4 leads, panel wires): drawn like real insulated wire
    const WIRE = { red: ['#b3191a', '#e8463c'], blue: ['#1d4fa8', '#4f86e8'], yellow: ['#c9a10c', '#f5d54a'], green: ['#1d7a32', '#3fbf5f'],
                   white: ['#c9c9c4', '#f6f6f2'], black: ['#141416', '#45464b'], orange: ['#c4560e', '#f2873c'] };
    const WNAME = { red: 'أحمر', blue: 'أزرق', yellow: 'أصفر', green: 'أخضر', white: 'أبيض', black: 'أسود', orange: 'برتقالي' };
    function cable(g, pts, col, w = 7, cut = null) {
        const [dark, light] = WIRE[col] || WIRE.black;
        const path = () => { g.beginPath(); g.moveTo(pts[0][0], pts[0][1]); if (pts.length === 4) g.bezierCurveTo(pts[1][0], pts[1][1], pts[2][0], pts[2][1], pts[3][0], pts[3][1]); else g.quadraticCurveTo(pts[1][0], pts[1][1], pts[2][0], pts[2][1]); };
        g.save(); g.lineCap = 'round'; g.lineJoin = 'round';
        if (cut) { g.beginPath(); g.rect(0, 0, SW, SH); g.arc(cut[0], cut[1], 9, 0, Math.PI * 2, true); g.clip('evenodd'); }
        g.shadowColor = 'rgba(0,0,0,.55)'; g.shadowBlur = 6; g.shadowOffsetY = 3;
        path(); g.strokeStyle = 'rgba(0,0,0,.85)'; g.lineWidth = w + 2.5; g.stroke();
        g.shadowColor = 'transparent';
        path(); g.strokeStyle = dark; g.lineWidth = w; g.stroke();
        path(); g.strokeStyle = light; g.lineWidth = w * 0.32; g.globalAlpha = 0.75; g.translate(-w * 0.12, -w * 0.18); g.stroke();
        g.restore();
        if (cut) {   // the cut: two bright copper ends
            g.save(); g.fillStyle = '#d58a3c';
            g.beginPath(); g.arc(cut[0] - 7, cut[1], 2.4, 0, Math.PI * 2); g.arc(cut[0] + 7, cut[1], 2.4, 0, Math.PI * 2); g.fill(); g.restore();
        }
    }
    const bez = (p, t) => { const u = 1 - t; return p.length === 4
        ? [u * u * u * p[0][0] + 3 * u * u * t * p[1][0] + 3 * u * t * t * p[2][0] + t * t * t * p[3][0], u * u * u * p[0][1] + 3 * u * u * t * p[1][1] + 3 * u * t * t * p[2][1] + t * t * t * p[3][1]]
        : [u * u * p[0][0] + 2 * u * t * p[1][0] + t * t * p[2][0], u * u * p[0][1] + 2 * u * t * p[1][1] + t * t * p[2][1]]; };

    // ===================================================================== C4 (wire the detonator)
    // The detonator's screen says which coloured lead goes on which numbered post. Drag each lead from the
    // blasting cap to its post. A wrong post = an error beep (two and it's off). All four = armed.
    function c4(c, p) {
        const m = META.c4_bg;
        c.bg('c4_bg.webp');
        const n = Math.max(3, Math.min(4, p.leads || 4));
        const cols = shuffle(['red', 'blue', 'yellow', 'green', 'white', 'orange']).slice(0, n);
        const order = shuffle([0, 1, 2, 3]).slice(0, n);                        // lead k goes on post order[k]
        const cv = c.el('canvas', 'm-cables'); cv.width = SW; cv.height = SH; const g = cv.getContext('2d');
        const [[lx0, ly0], [lx1, ly1]] = m.lcd;
        const lcd = c.el('div', 'm-lcd'); lcd.style.cssText = `left:${lx0}px;top:${ly0}px;width:${lx1 - lx0}px;height:${ly1 - ly0}px`;
        const want = Array(4).fill(null); order.forEach((post, k) => { want[post] = k; });
        lcd.innerHTML = `<div class="l1">ARM SEQ · ${n} LEADS</div><div class="l2">${[0, 1, 2, 3].map((i) => want[i] === null ? `<span>${i + 1}·—</span>` : `<span>${i + 1}·${cols[want[i]].slice(0, 3).toUpperCase()}</span>`).join('')}</div>`;
        const leds = m.leds.map(([x, y], i) => { const e = c.el('div', `m-led ${i ? 'g' : 'r'}`); e.style.left = `${x - 9}px`; e.style.top = `${y - 9}px`; return e; });
        leds[0].classList.add('on');
        const leads = cols.map((col, k) => ({ col, from: m.leads[k], end: [m.leads[k][0] + 30 + k * 62, 545 + k * 24], post: null }));
        let drag = null, strikes = 0, done = false, mx = 0, my = 0;
        const dragLoop = c.loop('c4_drag', 0.6);
        function draw() {
            g.clearRect(0, 0, SW, SH);
            leads.forEach((L, k) => {
                const e = drag === k ? [mx, my] : (L.post !== null ? m.terms[L.post] : L.end);
                const sag = Math.min(110, Math.hypot(e[0] - L.from[0], e[1] - L.from[1]) * 0.35);
                cable(g, [L.from, [(L.from[0] + e[0]) / 2, Math.max(L.from[1], e[1]) + sag], e], L.col, 6.5);
                // the bare copper end (or the clamped end under the post)
                g.save(); g.fillStyle = L.post !== null ? '#9a7a3a' : '#d58a3c'; g.beginPath(); g.arc(e[0], e[1], L.post !== null ? 4 : 3.2, 0, Math.PI * 2); g.fill(); g.restore();
            });
        }
        draw();
        c.on(c.stage, 'mousemove', (e) => { [mx, my] = c.at(e); if (drag !== null) { draw(); dragLoop.set(0.5); } });
        c.on(window, 'mousedown', (e) => {
            if (done || e.button !== 0) return;
            const [x, y] = c.at(e);
            let best = null, bd = 30;
            leads.forEach((L, k) => { if (L.post !== null) return; const d = Math.hypot(L.end[0] - x, L.end[1] - y); if (d < bd) { bd = d; best = k; } });
            if (best !== null) { drag = best; mx = x; my = y; draw(); }
        });
        c.on(window, 'mouseup', () => {
            if (drag === null || done) return;
            const k = drag; drag = null; dragLoop.set(0);
            let post = null, bd = 26;
            m.terms.forEach(([tx, ty], i) => { const d = Math.hypot(tx - mx, ty - my); if (d < bd && !leads.some((L) => L.post === i)) { bd = d; post = i; } });
            if (post === null) { draw(); return; }
            if (order[k] === post) {
                leads[k].post = post; sfx('c4_clip'); c.flash('good'); draw();
                c.prog(leads.filter((L) => L.post !== null).length / n);
                if (leads.every((L) => L.post !== null)) {
                    done = true; sfx('c4_arm'); leds[0].classList.remove('on'); leds[1].classList.add('on', 'blink');
                    lcd.innerHTML = '<div class="l1">ARMED</div><div class="l2"><span>TIMER 00:30</span></div>'; lcd.classList.add('ok');
                    c.later(() => finish(true), 1100);
                }
            } else {
                strikes++; sfx('c4_err'); c.flash('bad'); c.jolt(true); draw();
                lcd.classList.add('err'); c.later(() => lcd.classList.remove('err'), 600);
                if (strikes >= 2) { done = true; lcd.innerHTML = '<div class="l1">FAULT</div><div class="l2"><span>CIRCUIT ERROR</span></div>'; c.later(() => finish(false), 900); }
            }
        });
        const time = c.timer(Math.round(35 * (p.time || 1)), () => { if (!done) { done = true; sfx('c4_err'); finish(false); } });
        G.dbg = () => ({ order, cols, terms: m.terms, leads: leads.map((L) => ({ end: L.end, post: L.post })), strikes, left: time.left(),
            wire: (k, post) => { drag = k; [mx, my] = m.terms[post]; window.dispatchEvent(new MouseEvent('mouseup')); } });
    }

    // ===================================================================== ALARM PANEL (cut the alarm loop)
    // Six wires run from the numbered posts on the left to the posts on the right, crossing on the way.
    // Follow them with your eye and cut ONLY the two that end on ALM. Cut a power or tamper line: the siren.
    function wirecut(c, p) {
        const m = META.panel_bg;
        c.bg('panel_bg.webp');
        const N = m.left.length;
        const perm = shuffle([...Array(N).keys()]);                                    // left i -> right perm[i]
        const palette = shuffle(['red', 'blue', 'yellow', 'green', 'white', 'black', 'orange']);
        // (two wires share a colour sometimes: you must follow them, not read them)
        const cols = Array.from({ length: N }, (_, i) => palette[i < 4 ? i : Math.floor(Math.random() * 4)]);
        const wires = perm.map((r, i) => {
            const a = [m.left[i][0] + 14, m.left[i][1]], b = [m.right[r][0] - 14, m.right[r][1]];
            const midY = () => rnd(Math.min(a[1], b[1]) - 60, Math.max(a[1], b[1]) + 60);
            return { i, r, col: cols[i], pts: [a, [a[0] + rnd(70, 150), midY()], [b[0] - rnd(70, 150), midY()], b], cut: null, alarm: m.labels[r].startsWith('ALM') };
        });
        const need = wires.filter((w) => w.alarm).length;
        const cv = c.el('canvas', 'm-cables'); cv.width = SW; cv.height = SH; const g = cv.getContext('2d');
        const snips = c.img('snips.webp', 'm-snips'); const sA = A('snips');
        const strobe = c.el('div', 'm-strobe'); strobe.style.left = `${m.strobe[0] - 40}px`; strobe.style.top = `${m.strobe[1] - 40}px`;
        let done = false, mx = 600, my = 345, cutN = 0;
        function draw() { g.clearRect(0, 0, SW, SH); wires.forEach((w) => cable(g, w.pts, w.col, 6, w.cut)); }
        draw();
        const near = (x, y) => {
            let best = null, bd = 9;
            wires.forEach((w) => { if (w.cut) return; for (let t = 0.04; t <= 0.96; t += 0.01) { const [px, py] = bez(w.pts, t); const d = Math.hypot(px - x, py - y); if (d < bd) { bd = d; best = w; } } });
            return best;
        };
        c.on(c.stage, 'mousemove', (e) => { [mx, my] = c.at(e); });
        c.on(window, 'mousedown', (e) => {
            if (done || e.button !== 0) return;
            const w = near(mx, my); if (!w) return;
            w.cut = [mx, my]; sfx('wc_snip'); draw(); c.jolt(true);
            if (!w.alarm) {
                done = true; c.later(() => { sfx('wc_alarm'); strobe.classList.add('on'); c.flash('bad'); }, 180);
                c.later(() => finish(false), 1500); return;
            }
            cutN++; c.prog(cutN / need);
            if (cutN >= need) { done = true; c.later(() => { sfx('wc_done'); c.flash('good'); }, 250); c.later(() => finish(true), 900); }
        });
        c.raf(() => { put(snips, mx, my, sA.ax, sA.ay, 0, 0.62); if (done && !G) return false; });
        const time = c.timer(Math.round(40 * (p.time || 1)), () => { if (!done) { done = true; sfx('wc_alarm'); strobe.classList.add('on'); finish(false); } });
        G.dbg = () => ({ wires: wires.map((w) => ({ i: w.i, r: w.r, label: m.labels[w.r], alarm: w.alarm, cut: !!w.cut, samples: Array.from({ length: 17 }, (_, q) => bez(w.pts, 0.1 + q * 0.05)) })), left: time.left(),
            snip: (x, y) => { mx = x; my = y; window.dispatchEvent(new MouseEvent('mousedown', { button: 0 })); } });
    }

    // ===================================================================== KEYPAD (worn keys)
    // Four keys are worn and greasy: the code is those four digits, in an order you have to find. After each
    // try the screen says how many are in the right place. Run out of tries and it locks you out.
    function keypad(c, p) {
        const m = META.keypad_bg;
        c.bg('keypad_bg.webp');
        const digits = shuffle(['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']).slice(0, 4);
        const code = digits.slice();                      // (already random order)
        const tries = Math.max(5, Math.min(8, p.tries || 6));   // (5 always solves it with good play)
        const [[x0, y0], [x1, y1]] = m.lcd;
        const lcd = c.el('div', 'm-lcd kp'); lcd.style.cssText = `left:${x0}px;top:${y0}px;width:${x1 - x0}px;height:${y1 - y0}px`;
        const leds = m.leds.map(([x, y], i) => { const e = c.el('div', `m-led ${i ? 'g' : 'r'}`); e.style.left = `${x - 8}px`; e.style.top = `${y - 8}px`; return e; });
        const [kw, kh] = m.key;
        const keyEls = {};
        m.keys.forEach(([ch, x, y]) => {
            if (digits.includes(ch)) {
                const s = c.el('div', 'm-smudge'); s.style.cssText = `left:${x - kw / 2}px;top:${y - kh / 2}px;width:${kw}px;height:${kh}px;--a:${rnd(-30, 30)}deg;--x:${rnd(30, 70)}%;--y:${rnd(30, 70)}%`;
            }
            const k = c.el('div', 'm-kpkey'); k.style.cssText = `left:${x - kw / 2}px;top:${y - kh / 2}px;width:${kw}px;height:${kh}px`; keyEls[ch] = k;
        });
        let typed = '', left = tries, done = false, log = [];
        if (p.hint) log.push(`${code[0]}___ (المخطط)`);
        const show = (msg) => {
            lcd.innerHTML = `<div class="l1">${msg || 'ENTER CODE'}</div><div class="l2">${'●'.repeat(typed.length)}${'○'.repeat(4 - typed.length)}<b>${left}</b></div>`;
        };
        show(p.hint ? `FIRST: ${code[0]}` : null);
        const hist = c.el('div', 'm-kplog');
        const renderLog = () => { hist.innerHTML = log.map((l) => `<div>${l}</div>`).join(''); };
        renderLog();
        function press(ch) {
            if (done) return;
            const k = keyEls[ch]; if (k) { k.classList.remove('down'); void k.offsetWidth; k.classList.add('down'); }
            sfx('kp_key');
            if (ch === '*') { typed = ''; show(); return; }
            if (ch === '#' || typed.length >= 4) return;
            typed += ch; show();
            if (typed.length < 4) return;
            const right = [...typed].filter((d, i) => code[i] === d).length;
            if (right === 4) {
                done = true; sfx('kp_ok'); leds[1].classList.add('on'); lcd.classList.add('ok'); show('ACCESS GRANTED'); c.flash('good');
                c.later(() => finish(true), 900); return;
            }
            left--; log.unshift(`${typed}  →  ${right} ✓`); if (log.length > 5) log.pop(); renderLog();
            sfx('kp_bad'); leds[0].classList.add('on', 'blink'); c.later(() => leds[0].classList.remove('on', 'blink'), 900);
            const t = typed; typed = '';
            if (left <= 0) {
                done = true; sfx('kp_lock'); lcd.classList.add('err'); show('LOCKED OUT'); c.flash('bad'); c.jolt();
                c.later(() => finish(false), 1300); return;
            }
            show(`${t}: ${right} OK`);
            c.prog(1 - left / tries);
        }
        m.keys.forEach(([ch]) => { keyEls[ch].onmousedown = (e) => { if (e.button === 0) press(ch); }; });
        c.on(window, 'keydown', (e) => { if (/^[0-9]$/.test(e.key)) press(e.key); else if (e.key === 'Backspace') press('*'); });
        const time = c.timer(Math.round(60 * (p.time || 1)), () => { if (!done) { done = true; sfx('kp_lock'); show('TIMEOUT'); finish(false); } });
        G.dbg = () => ({ digits, code, left, typed, time: time.left(), press });
    }

    // ===================================================================== registry
    const GAMES = { lockpick, safedial, drill, glasscut, hack, c4, wirecut, keypad };
    const TEXT = {
        lockpick: ['اضغط الشدّ مع الاستمرار، ضع المفتاح تحت كل مسمار وارفعه حتى تسمع النقرة. المسمار العالق: خفّف الشدّ وأعد', [['', 'ارفع', true], ['SPACE', 'الشدّ (أو الزر الأيمن)']]],
        safedial: ['أدر القرص بالاتجاه المطلوب، استمع للنقرة الأقوى، توقّف عليها واضغط المسافة. الخطأ يعيد الأقراص', [['A', 'يسار'], ['D', 'يمين'], ['SHIFT', 'ببطء'], ['SPACE', 'ثبّت الرقم']]],
        drill: ['اضغط لتدفع المثقاب وخفّف لتبرّده. كل طبقة تريد ضغطًا مختلفًا (الخط الأصفر). إن وصلت الحرارة للأحمر ينكسر الرأس', [['', 'ادفع', true], ['SPACE', 'أو المسافة']]],
        glasscut: ['اضغط مع الاستمرار على الدائرة ودُر بالقاطعة دورة كاملة ببطء. خارج الخط أو بسرعة = ينكسر الزجاج', [['', 'اقطع', true]]],
        hack: ['أدر القطع (انقر عليها) لتصل الإشارة من المدخل يسارًا إلى المخرج يمينًا قبل انتهاء الوقت', [['', 'أدر القطعة', true]]],
        c4: ['الشاشة تقول أي سلك على أي مسمار. اسحب كل سلك من الصاعق إلى مسماره. خطأ مرتين = عطل', [['', 'اسحب السلك', true]]],
        wirecut: ['تتبّع الأسلاك بعينك من اليسار إلى اليمين. اقطع فقط السلكين اللذين ينتهيان عند ALM. أي سلك آخر = صفارة الإنذار', [['', 'اقطع', true]]],
        keypad: ['الأزرار الأربعة المستعملة (عليها آثار أصابع) هي الرمز. جرّب ترتيبًا، والشاشة تقول كم رقمًا في مكانه الصحيح', [['0-9', 'رقم'], ['', 'أو انقر', true], ['⌫', 'امسح']]],
    };
    function start(game, title, params, cb) {
        if (G || !GAMES[game]) return false;
        const [hint, keys] = TEXT[game];
        G = { off: [], cb, game, t0: performance.now() };
        const c = shell(game, title || '', params && params.where, hint, keys);
        try { GAMES[game](c, params || {}); } catch (e) { console.error('[heist game]', game, e); finish(false); }
        return true;
    }
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && G) finish(false); });
    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'start') { if (!start(d.game, d.title, d.params)) fetch(`https://${RES}/done`, { method: 'POST', body: JSON.stringify({ passed: false }) }).catch(() => {}); }
    });
    window.EXH_GAMES = { start, state: () => (G && G.dbg && G.dbg()) || null };   // (the browser tests read this)
})();
