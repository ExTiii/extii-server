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
    function finish(passed) {
        if (!G) return;
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
        c.bg('safe_bg.webp');
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
            put(dial, cx, cy, da.ax, da.ay, angle * Math.PI / 180);
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

    // ===================================================================== registry
    const GAMES = { lockpick, safedial };
    const TEXT = {
        lockpick: ['اضغط الشدّ مع الاستمرار، ضع المفتاح تحت كل مسمار وارفعه حتى تسمع النقرة. المسمار العالق: خفّف الشدّ وأعد', [['', 'ارفع', true], ['SPACE', 'الشدّ (أو الزر الأيمن)']]],
        safedial: ['أدر القرص بالاتجاه المطلوب، استمع للنقرة الأقوى، توقّف عليها واضغط المسافة. الخطأ يعيد الأقراص', [['A', 'يسار'], ['D', 'يمين'], ['SHIFT', 'ببطء'], ['SPACE', 'ثبّت الرقم']]],
    };
    function start(game, title, params, cb) {
        if (G || !GAMES[game]) return false;
        const [hint, keys] = TEXT[game];
        G = { off: [], cb };
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
