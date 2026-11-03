/* =====================================================================
   EX_Tii jobs — the mini games of the level jobs, workshop look.
   Every scene is a real 3D render (html/mg/*.webp, 1200 x 690 scene pixels); the moving parts are
   renders too, placed in the same pixels (their anchors are in jmeta.js). Sounds: html/mg/sfx/*.ogg.
   { action: 'game', game, count, seconds }: every game lasts the whole `seconds` (at least 25),
   then sends { score: 0..1 } to 'gameDone'. The score decides how many of the items come out good.
   ===================================================================== */
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'exti_jobs';
    const send = (score) => fetch(`https://${RES}/gameDone`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ score }) }).catch(() => {});
    const SW = 1200, SH = 690;
    const META = window.JG_META || {};
    const rnd = (a, b) => a + Math.random() * (b - a);
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    const pick = (a) => a[Math.floor(Math.random() * a.length)];

    // ------------------------------------------------------------- sounds
    const VOL = 0.55, pool = {};
    function sfx(name, vol = 1, rate = 1) {
        try {
            const list = pool[name] || (pool[name] = []);
            let a = list.find((x) => x.paused || x.ended);
            if (!a) { a = new Audio(`mg/sfx/${name}.ogg`); list.push(a); }
            a.currentTime = 0; a.volume = Math.min(1, VOL * vol); a.playbackRate = rate;
            a.play().catch(() => {});
        } catch (e) { /* no sound is fine */ }
    }
    function loop(name, vol = 1) {
        const a = new Audio(`mg/sfx/${name}.ogg`); a.loop = true; a.volume = 0;
        let want = 0, t = null;
        const step = () => { a.volume = clamp(a.volume + (want - a.volume) * 0.25, 0, 1); if (Math.abs(a.volume - want) < 0.01) { a.volume = want; if (!want) a.pause(); clearInterval(t); t = null; } };
        return {
            set(v) { want = clamp(VOL * vol * v, 0, 1); if (want && a.paused) a.play().catch(() => {}); if (!t) t = setInterval(step, 30); },
            on() { this.set(1); }, off() { this.set(0); },
            rate(r) { a.playbackRate = r; },
            kill() { clearInterval(t); a.pause(); },
        };
    }

    // ------------------------------------------------------------- the stage
    const TEXT = {
        catch: ['اصطد الدجاج', 'اضغط على كل دجاجة قبل أن تخرج من الحظيرة', [['', 'أمسك', 1]], 'دجاجة'],
        slaughter: ['خط الذبح', 'اضغط مسافة حين تكون الدجاجة تحت الشفرة (بين الخطين)', [['SPACE', 'اقطع']], 'دجاجة'],
        pack: ['تعبئة الدجاج', 'اسحب كل قطعة من اللوح إلى الصينية قبل أن تفسد', [['', 'اسحب', 1]], 'قطعة'],
        pick: ['قطف العنب', 'اضغط الحرف الظاهر على العنقود قبل أن تنتهي دائرته', [['W', ''], ['A', ''], ['S', ''], ['D', 'اقطف']], 'عنقود'],
        dry: ['تجفيف العنب', 'اضغط مع الاستمرار على مسافة للتسخين، وأبقِ المؤشر داخل المنطقة الخضراء', [['SPACE', 'سخّن']], 'عنقود'],
        box: ['تعبئة الكراتين', 'اسحب المغرفة إلى الكرتونة 3 مرات، اضغط لتغلقها، ثم اسحب الشريط من طرف إلى طرف', [['', 'اسحب / اضغط', 1]], 'كرتونة'],
        harvest: ['حصاد القمح', 'اضغط واسحب المنجل بسرعة عبر كل حزمة قمح قبل أن تذبل', [['', 'احصد', 1]], 'حزمة'],
        mill: ['المطحنة', 'اضغط مسافة حين يمرّ مجرى الحجر تحت فتحة القمح', [['SPACE', 'صبّ القمح']], 'كيس'],
        bake: ['الفرن', 'اضغط على الرغيف حين يصبح ذهبيًا، لا قبل ولا بعد', [['', 'أخرج', 1]], 'رغيف'],
        fish: ['الصيد من الرصيف', 'حين تغوص العوامة اضغط مسافة، ثم اضغط مع الاستمرار لتبقي المؤشر على السمكة', [['SPACE', 'اسحب']], 'سمكة'],
        fillet: ['تنظيف السمك', 'اسحب السكين على الخط من الرأس إلى الذيل دون أن تخرج عنه', [['', 'اقطع', 1]], 'سمكة'],
        icepack: ['التعبئة بالثلج', 'ضع السمك في الصينية، غطّه بمغرفتي ثلج، ثم اختم الصينية', [['', 'اسحب / اضغط', 1]], 'علبة'],
        mine: ['المنجم', 'حرّك ضوء الخوذة وابحث عن الخام اللامع، واضربه 3 مرات', [['', 'اضرب', 1]], 'صخرة'],
        sort_ore: ['فرز الخام', 'اضغط على الحجارة الرمادية (بدون معدن) لترميها، واترك الخام يمرّ', [['', 'ارمِ', 1]], 'صخرة'],
        smelt: ['المسبك', 'اضغط مع الاستمرار لتصب، واترك حين يمتلئ القالب حتى الخط دون أن يفيض', [['', 'صبّ', 1]], 'سبيكة'],
        shear: ['جزّ الصوف', 'اضغط واسحب آلة الجزّ على كل الصوف حتى يصبح الخروف نظيفًا', [['', 'جزّ', 1]], 'خروف'],
        weave: ['النول', 'حين يصل المكوك إلى طرف اضغط حرف ذلك الطرف لترميه إلى الطرف الآخر', [['A', 'يسار'], ['D', 'يمين']], 'لفة'],
        sew: ['الخياطة', 'اضغط مع الاستمرار لتخيط، وحرّك الفأرة يمينًا ويسارًا لتبقي الإبرة على خط الطباشير', [['', 'خيّط', 1]], 'قطعة'],
    };
    const root = () => document.getElementById('jg') || Object.assign(document.body.appendChild(document.createElement('div')), { id: 'jg' });
    let G = null;

    function shell(game, count) {
        const [title, hint, keys, word] = TEXT[game];
        const k = Math.min(1, (innerWidth * 0.66) / SW, (innerHeight * 0.68) / SH);
        const box = root();
        box.className = 'jg on'; box.style.setProperty('--k', k);
        box.innerHTML = `<div class="jg-wrap">
            <div class="jg-top"><h3>${title}</h3><span class="jg-where">${count ? `تتعامل مع ${count} ${word}` : ''}</span><span class="jg-cnt" id="jgc"></span></div>
            <div class="jg-box"><div class="jg-stage jg-${game}" id="jgs"><img class="bg" id="jgbg" alt=""></div><div class="jg-flash" id="jgf"></div></div>
            <div class="jg-time"><i id="jgt"></i></div>
            <div class="jg-bar"><span class="hint">${hint}</span><span class="keys">${keys.map(([kb, label, mouse]) => `<span class="jg-key">${label}<kbd class="${mouse ? 'mouse' : ''}">${mouse ? '' : kb}</kbd></span>`).join('')}</span></div>
        </div>`;
        const stage = document.getElementById('jgs');
        const off = [];
        const c = {
            k, stage, off, meta: (n) => META[n] || {},
            bg(n) { document.getElementById('jgbg').src = `mg/${n}.webp`; },
            spr(n, cls, parent) {
                const i = document.createElement('img'); i.src = `mg/${n}.webp`; i.className = 'spr ' + (cls || ''); i.alt = ''; i.draggable = false;
                const m = META[n] || {}; i._a = [m.ax || 0, m.ay || 0]; i._wh = [m.w || 0, m.h || 0];
                (parent || stage).appendChild(i); return i;
            },
            layer(n, cls) { const i = c.spr(n, 'layer ' + (cls || '')); i._a = [0, 0]; return i; },
            el(tag, cls, html, parent) { const e = document.createElement(tag); if (cls) e.className = cls; if (html) e.innerHTML = html; (parent || stage).appendChild(e); return e; },
            count(a, b) { document.getElementById('jgc').textContent = b ? `${a} / ${b}` : String(a); },
            flash(kind) { const f = document.getElementById('jgf'); f.className = 'jg-flash'; void f.offsetWidth; f.className = `jg-flash ${kind}`; },
            jolt() { stage.classList.remove('jolt'); void stage.offsetWidth; stage.classList.add('jolt'); },
            at(e) { const r = stage.getBoundingClientRect(); return [(e.clientX - r.left) / k, (e.clientY - r.top) / k]; },
            on(t, ev, fn, opt) { t.addEventListener(ev, fn, opt); off.push(() => t.removeEventListener(ev, fn, opt)); },
            later(fn, ms) { const id = setTimeout(() => { if (G && !G.over) fn(); }, ms); off.push(() => clearTimeout(id)); },
            loop(n, v) { const l = loop(n, v); off.push(() => l.kill()); return l; },
            key(e) { return (e.code || '').replace('Key', ''); },
            sfx,
        };
        return c;
    }
    // place a sprite so its anchor lands on (x, y)
    function put(el, x, y, rot = 0, s = 1, flip = false) {
        const [ax, ay] = el._a || [0, 0];
        el.style.transformOrigin = `${ax}px ${ay}px`;
        el.style.transform = `translate(${x - ax}px, ${y - ay}px) rotate(${rot}rad) scale(${flip ? -s : s}, ${s})`;
    }
    // things that happen at moments spread over the game, the last one with time left to be done
    const schedule = (n, seconds, lead = 0.6, tail = 3) => Array.from({ length: n }, (_, i) => lead + i * ((seconds - lead - tail) / Math.max(1, n - 1)));
    // a small countdown ring (svg) drawn round a point
    function ring(c, r = 40) {
        const e = c.el('div', 'jg-ring', `<svg width="${r * 2 + 8}" height="${r * 2 + 8}"><circle cx="${r + 4}" cy="${r + 4}" r="${r}" pathLength="100"/></svg>`);
        const ci = e.querySelector('circle'); e.style.marginLeft = e.style.marginTop = `${-(r + 4)}px`;
        return { e, at(x, y) { e.style.left = `${x}px`; e.style.top = `${y}px`; }, set(p) { ci.style.strokeDashoffset = String(100 - clamp(p, 0, 1) * 100); ci.style.stroke = p < 0.3 ? '#ff6b4a' : '#fff'; }, kill() { e.remove(); } };
    }

    function finish() {
        if (!G || G.over) return;
        G.over = true;
        G.c.off.forEach((f) => { try { f(); } catch (e) { /* */ } });
        const score = clamp(Number(G.score()) || 0, 0, 1), pct = Math.round(score * 100);
        const end = G.c.el('div', 'jg-end', `<b>${pct}%</b><span>${pct >= 90 ? 'ممتاز!' : pct >= 65 ? 'شغل جيد' : pct >= 35 ? 'مقبول' : 'حاول أن تكون أدق'}</span>`, document.querySelector('#jg .jg-box'));
        sfx(pct >= 35 ? 'ok' : 'miss', 0.8);
        const box = root(); G = null;
        setTimeout(() => { send(score); if (G) return; box.classList.add('out'); setTimeout(() => { if (!G) { box.className = 'jg'; box.innerHTML = ''; } }, 260); }, 1500);
        return end;
    }

    // ===================================================================== CHICKEN
    function gCatch(c, T) {
        c.bg('pen_bg');
        const m = c.meta('pen_bg'), [[x0, y0], [x1, y1]] = m.area || [[60, 150], [1140, 680]];
        const Y1 = Math.min(y1, 660), N = 18, LIFE = 3.6, times = schedule(N, T, 0.4, LIFE);
        let next = 0, got = 0; const hens = [];
        c.count(0, N); G.score = () => got / N;
        return (dt, t) => {
            while (next < N && t >= times[next]) {
                const el = c.spr('hen', 'hen hit');
                const side = Math.random() < 0.5;
                const h = { el, x: side ? x0 + 20 : x1 - 20, y: rnd(y0 + 120, Y1 - 10), vx: (side ? 1 : -1) * rnd(150, 230), vy: rnd(-90, 90), born: t, done: false, ph: rnd(0, 6), turn: rnd(0.6, 1.4) };
                el.onpointerdown = (e) => {
                    e.preventDefault(); if (h.done || !G) return;
                    h.done = true; got += 1; c.count(got, N);
                    sfx('flap', 0.9, rnd(0.9, 1.1)); sfx('squawk', 0.7, rnd(0.9, 1.15));
                    el.classList.add('got'); put(el, h.x, h.y - 40, 0, 1.15, h.vx < 0);
                    c.later(() => el.remove(), 420);
                };
                if (Math.random() < 0.6) sfx('cluck', 0.45, rnd(0.85, 1.2));
                hens.push(h); next += 1;
            }
            for (const h of hens) {
                if (h.done) continue;
                const age = t - h.born;
                h.turn -= dt;
                if (h.turn <= 0) { h.turn = rnd(0.5, 1.2); h.vx = Math.sign(h.vx || 1) * (Math.random() < 0.25 ? -1 : 1) * rnd(140, 260); h.vy = rnd(-110, 110); if (Math.random() < 0.3) sfx('cluck', 0.3, rnd(0.9, 1.25)); }
                if (age > LIFE) { h.vx = Math.sign(h.vx || 1) * 420; h.vy = 0; }   // off through the gap in the fence
                h.x += h.vx * dt; h.y += h.vy * dt;
                if (age <= LIFE) {
                    if (h.x < x0 + 40 || h.x > x1 - 40) { h.vx = -h.vx; h.x = clamp(h.x, x0 + 40, x1 - 40); }
                    if (h.y < y0 + 110 || h.y > Y1) { h.vy = -h.vy; h.y = clamp(h.y, y0 + 110, Y1); }
                }
                const bob = Math.abs(Math.sin((t + h.ph) * 14)) * 5;
                put(h.el, h.x, h.y - bob, Math.sin((t + h.ph) * 14) * 0.05, 1, h.vx < 0);
                if (h.x < -120 || h.x > SW + 120) { h.done = true; h.el.remove(); }
            }
        };
    }

    function gSlaughter(c, T) {
        c.bg('line_bg');
        const m = c.meta('line_bg'), RY = m.rail ?? 55, CX = (m.cut || [600])[0], ZONE = 55, N = 14;
        const z = c.el('div', 'jg-zone'); Object.assign(z.style, { left: `${CX - ZONE}px`, width: `${ZONE * 2}px`, top: `${RY - 6}px`, height: `${Math.max(40, (m.cut || [0, 300])[1] - RY + 40)}px` });
        const times = schedule(N, T, 0.2, 2.2), birds = [];
        let next = 0, cut = 0, judged = 0;
        const speed = (SW + 200) / 3.6;
        c.count(0, N); G.score = () => cut / N;
        const hit = () => {
            const b = birds.filter((x) => !x.done).sort((a, b2) => Math.abs(a.x - CX) - Math.abs(b2.x - CX))[0];
            if (b && Math.abs(b.x - CX) <= ZONE) {
                b.done = true; cut += 1; judged += 1; c.count(cut, N);
                sfx('chop', 0.9, rnd(0.95, 1.05)); c.flash('ok');
                b.fall = 0;
            } else { sfx('miss', 0.8); c.jolt(); c.flash('bad'); }
        };
        c.on(window, 'keydown', (e) => { if (e.code === 'Space' || e.code === 'KeyE') { e.preventDefault(); if (!e.repeat) hit(); } });
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); hit(); });
        return (dt, t) => {
            while (next < N && t >= times[next]) { birds.push({ el: c.spr('bird', 'bird'), x: SW + 90, done: false, ph: rnd(0, 6) }); sfx('clank', 0.35, rnd(0.9, 1.1)); next += 1; }
            for (const b of birds) {
                if (b.gone) continue;
                if (b.fall !== undefined) {           // cut: it drops into the trough
                    b.fall += dt; const f = b.fall;
                    put(b.el, b.x, RY + 600 * f * f, 0.3 * f, 1); b.el.style.opacity = String(clamp(1 - f * 2.2, 0, 1));
                    if (f > 0.5) { b.gone = true; b.el.remove(); sfx('thud', 0.5); }
                    continue;
                }
                b.x -= speed * dt;
                put(b.el, b.x, RY, Math.sin((t + b.ph) * 5) * 0.06, 1);
                if (b.x < CX - ZONE && !b.late) { b.late = true; b.el.classList.add('late'); }
                if (b.x < -120) { b.gone = true; b.el.remove(); }
            }
        };
    }

    function gPack(c, T) {
        c.bg('pack_bg');
        const m = c.meta('pack_bg'), [bx, by] = m.board || [300, 325], [tx, ty] = m.tray || [900, 345], [tw, th] = m.tray_wh || [270, 400];
        const slots = m.slots || [], N = 16, LIFE = 6.5, times = schedule(N, T, 0.3, 3.2);
        let next = 0, packed = 0, held = null, fill = [];
        c.count(0, N); G.score = () => packed / N;
        const pieces = [];
        const inTray = (x, y) => Math.abs(x - tx) < tw / 2 && Math.abs(y - ty) < th / 2;
        c.on(window, 'pointermove', (e) => { if (!held) return; const [x, y] = c.at(e); held.x = x; held.y = y; });
        c.on(window, 'pointerup', (e) => {
            if (!held) return; const p = held; held = null; p.el.classList.remove('held');
            const [x, y] = c.at(e);
            if (inTray(x, y) && !p.spoiled) {
                p.done = true; packed += 1; c.count(packed, N); p.ring.kill(); sfx('tray', 0.8, rnd(0.95, 1.1));
                const s = slots[fill.length % slots.length] || [tx, ty]; fill.push(p);
                p.x = s[0]; p.y = s[1]; put(p.el, p.x, p.y, p.r, 0.95); p.el.classList.add('in');
                if (fill.length >= slots.length) {          // a full tray: wrap it and start the next
                    const full = fill; fill = [];
                    c.later(() => { sfx('tape', 0.5); full.forEach((q) => q.el.classList.add('wrapped')); }, 300);
                    c.later(() => full.forEach((q) => q.el.remove()), 900);
                }
            } else { p.x = p.hx; p.y = p.hy; put(p.el, p.x, p.y, p.r); }
        });
        return (dt, t) => {
            while (next < N && t >= times[next]) {
                const el = c.spr('piece', 'piece hit');
                const p = { el, hx: bx + rnd(-70, 70), hy: by + rnd(-150, 150), r: rnd(-1.4, 1.4), born: t, done: false, ring: ring(c, 34) };
                p.x = p.hx; p.y = p.hy; put(el, p.x, p.y, p.r);
                el.onpointerdown = (e) => { e.preventDefault(); if (p.done || p.spoiled || !G) return; held = p; el.classList.add('held'); sfx('thud', 0.3, 1.4); };
                pieces.push(p); next += 1;
            }
            for (const p of pieces) {
                if (p.done || p.spoiled) continue;
                const left = 1 - (t - p.born) / LIFE;
                if (held === p) put(p.el, p.x, p.y, p.r, 1.08);
                p.ring.at(p.x, p.y); p.ring.set(left);
                if (left <= 0) { p.spoiled = true; if (held === p) held = null; p.ring.kill(); p.el.classList.add('spoil'); sfx('miss', 0.5); c.later(() => p.el.remove(), 700); }
            }
        };
    }

    // ===================================================================== RAISINS
    function gPick(c, T) {
        c.bg('vine_bg');
        const m = c.meta('vine_bg'), spots = m.hang || [], [cx, cy] = m.crate || [600, 640];
        const KEYS = ['W', 'A', 'S', 'D'], N = 16, WIN = 1.75, times = schedule(N, T, 0.5, WIN + 0.3);
        const b = spots.map(([x, y]) => { const el = c.spr('bunch', 'bunch'); put(el, x, y); return { el, x, y, ripe: false, away: false }; });
        let next = 0, got = 0, act = null;
        c.count(0, N); G.score = () => got / N;
        const tag = c.el('div', 'jg-tag'); tag.style.display = 'none';
        const rg = ring(c, 46); rg.e.style.display = 'none';
        const drop = (s, good) => {
            s.away = true; s.el.classList.add(good ? 'picked' : 'fall');
            const dx = cx - s.x, dy = cy - s.y;
            put(s.el, s.x + (good ? dx : 0), s.y + (good ? dy : 160), good ? rnd(-0.4, 0.4) : 0.6, good ? 0.8 : 1);
            c.later(() => { s.el.classList.remove('picked', 'fall'); s.el.classList.add('grow'); put(s.el, s.x, s.y); s.away = false; c.later(() => s.el.classList.remove('grow'), 600); }, 1100);
        };
        c.on(window, 'keydown', (e) => {
            const k = c.key(e); if (!KEYS.includes(k) || e.repeat || !act) return;
            if (k === act.k) { got += 1; c.count(got, N); sfx('snip', 0.9, rnd(0.95, 1.1)); c.later(() => sfx('crate', 0.6), 380); drop(act.s, true); }
            else { sfx('miss', 0.7); c.flash('bad'); c.jolt(); drop(act.s, false); }
            act = null; tag.style.display = 'none'; rg.e.style.display = 'none';
        });
        return (dt, t) => {
            if (!act && next < N && t >= times[next]) {
                const free = b.filter((s) => !s.away);
                if (free.length) { const s = pick(free); act = { s, k: pick(KEYS), t0: t }; tag.textContent = act.k; tag.style.display = rg.e.style.display = ''; tag.style.left = `${s.x}px`; tag.style.top = `${s.y + 20}px`; rg.at(s.x, s.y + 62); }
                next += 1;
            }
            if (act) {
                const left = 1 - (t - act.t0) / WIN; rg.set(left);
                if (left <= 0) { sfx('miss', 0.5); drop(act.s, false); act = null; tag.style.display = 'none'; rg.e.style.display = 'none'; }
            }
        };
    }

    // a real dial (svg face) with the chrome bezel render on top
    function gauge(c, cls, { unit = '', brand = 'EX·TII', size = 220 } = {}) {
        const d = c.el('div', 'jg-dial ' + cls); d.style.width = d.style.height = `${size}px`;
        const R = 108, CX = 125, CY = 125, SPAN = 243;
        const pol = (deg, r) => { const a = (deg - 90) * Math.PI / 180; return [CX + Math.cos(a) * r, CY + Math.sin(a) * r]; };
        const degOf = (v) => (v - 0.5) * SPAN;
        let ticks = '';
        for (let i = 0; i <= 50; i++) {
            const v = i / 50, deg = degOf(v), major = i % 10 === 0;
            const [x1, y1] = pol(deg, R - 6), [x2, y2] = pol(deg, R - (major ? 20 : 12));
            ticks += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#1b1a18" stroke-width="${major ? 2.4 : 1.1}"/>`;
            if (major) { const [tx, ty] = pol(deg, R - 34); ticks += `<text x="${tx}" y="${ty + 4}" text-anchor="middle" font-size="12" font-weight="600" fill="#1b1a18">${i * 2}</text>`; }
        }
        d.innerHTML = `<svg viewBox="0 0 250 250"><defs><radialGradient id="jf${cls}" cx="50%" cy="45%" r="60%"><stop offset="0" stop-color="#f1ede2"/><stop offset="1" stop-color="#d6d0c1"/></radialGradient></defs>
            <circle cx="${CX}" cy="${CY}" r="${R + 4}" fill="url(#jf${cls})"/><path class="zone" fill="none" stroke="#2f7d45" stroke-width="13" opacity=".9"/>${ticks}
            <text x="${CX}" y="${CY + 44}" text-anchor="middle" font-size="11" fill="#55514a" style="direction:ltr;unicode-bidi:bidi-override">${unit}</text>
            <text x="${CX}" y="${CY + 60}" text-anchor="middle" font-size="9" fill="#77716a" letter-spacing="2" style="direction:ltr;unicode-bidi:bidi-override">${brand}</text>
            <g class="ndl"><path d="M ${CX - 4} ${CY + 16} L ${CX - 1.6} ${CY - R + 14} L ${CX + 1.6} ${CY - R + 14} L ${CX + 4} ${CY + 16} Z" fill="#c4231c"/></g>
            <circle cx="${CX}" cy="${CY}" r="9" fill="#2a2826"/><circle cx="${CX}" cy="${CY}" r="3.5" fill="#6a6560"/></svg><img class="bez" src="mg/bezel.webp" alt=""><div class="glass"></div>`;
        const zone = d.querySelector('.zone'), ndl = d.querySelector('.ndl');
        const arc = (a1, a2, r) => { const [x1, y1] = pol(a1, r), [x2, y2] = pol(a2, r); return `M ${x1} ${y1} A ${r} ${r} 0 ${a2 - a1 > 180 ? 1 : 0} 1 ${x2} ${y2}`; };
        return { el: d, needle(v) { ndl.setAttribute('transform', `rotate(${degOf(clamp(v, -0.02, 1.02))} ${CX} ${CY})`); }, zone(lo, hi) { zone.setAttribute('d', arc(degOf(lo), degOf(hi), R - 2)); } };
    }

    function gDry(c, T) {
        c.bg('rack_bg');
        const m = c.meta('rack_bg'), spots = m.spots || [];
        const g = spots.map(([x, y], i) => {
            const a = c.spr('grape_lay', 'lay'), r = c.spr('raisin_lay', 'lay'); put(a, x, y, i * 0.7 - 1); put(r, x, y, i * 0.7 - 1); r.style.opacity = '0'; return { a, r };
        });
        const dial = gauge(c, 'dryg', { unit: '°C  ×1' });
        const smoke = c.el('div', 'jg-smoke'), hum = c.loop('heater_loop', 0.8);
        let heat = 0.15, hold = false, good = 0, total = 0, centre = 0.55, dry = 0;
        G.score = () => total ? good / total : 0;
        const down = (e) => { if (e.code === 'Space') { e.preventDefault(); hold = true; } };
        const up = (e) => { if (e.code === 'Space') hold = false; };
        c.on(window, 'keydown', down); c.on(window, 'keyup', up);
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); hold = true; }); c.on(window, 'pointerup', () => { hold = false; });
        return (dt, t) => {
            heat = clamp(heat + (hold ? 0.42 : -0.3) * dt, 0, 1);
            centre = 0.55 + Math.sin(t * 0.45) * 0.18 + Math.sin(t * 1.3 + 1) * 0.05;
            const lo = centre - 0.09, hi = centre + 0.09;
            dial.zone(lo, hi); dial.needle(heat + Math.sin(t * 30) * 0.004);
            hum.set(0.25 + heat * 0.75); hum.rate(0.85 + heat * 0.35);
            if (t > 1.2) { total += dt; if (heat >= lo && heat <= hi) good += dt; }
            const q = total ? good / total : 1;
            dry = clamp(t / T, 0, 1);
            g.forEach((s) => { s.r.style.opacity = String(clamp(dry * 1.15, 0, 1)); s.a.style.opacity = String(clamp(1 - dry * 1.15, 0, 1)); });
            smoke.style.opacity = String(clamp((heat - hi) * 4, 0, 0.8));
            c.count(`${Math.round(q * 100)}%`);
        };
    }

    function gBox(c, T) {
        c.bg('box_bg');
        const m = c.meta('box_bg'), [cx, cy] = m.carton || [720, 345], [cw, ch] = m.carton_wh || [400, 300], [bx, by] = m.bin || [270, 365], TARGET = 4;
        const fill = c.layer('box_fill', 'fill'), shut = c.layer('box_shut', 'shut'), tape = c.layer('box_tape', 'tape');
        const scoop = c.spr('scoop', 'scoop hit'); put(scoop, bx + 40, by + 60, -0.4);
        let st = 0, scoops = 0, done = 0, drag = null, taping = null;
        const reset = () => { st = 0; scoops = 0; fill.style.opacity = '0'; shut.style.opacity = '0'; tape.style.clipPath = 'inset(0 100% 0 0)'; [fill, shut, tape].forEach((l) => l.classList.remove('ship')); };
        reset(); c.count(0, TARGET);
        G.score = () => clamp((done + (st === 0 ? scoops / 3 : st === 1 ? 0.8 : 0.9) * 0.6) / TARGET, 0, 1);
        const over = (x, y) => Math.abs(x - cx) < cw / 2 && Math.abs(y - cy) < ch / 2;
        const hint = c.el('div', 'jg-hintbox');
        const say = () => { hint.textContent = st === 0 ? `املأ بالمغرفة (${scoops}/3)` : st === 1 ? 'اضغط على الكرتونة لتغلقها' : 'اسحب الشريط من اليسار إلى اليمين'; };
        say();
        scoop.onpointerdown = (e) => { e.preventDefault(); if (st !== 0 || !G) return; drag = true; scoop.classList.add('held'); };
        c.on(c.stage, 'pointerdown', (e) => {
            const [x, y] = c.at(e);
            if (st === 1 && over(x, y)) { st = 2; shut.style.opacity = '1'; sfx('flap_card', 0.8); c.later(() => sfx('flap_card', 0.6, 1.1), 140); say(); return; }
            if (st === 2 && over(x, y) && x < cx - cw * 0.15) { taping = { x0: cx - cw * 0.58 }; }
        });
        c.on(window, 'pointermove', (e) => {
            const [x, y] = c.at(e);
            if (drag) put(scoop, x, y, -0.2, 1.05);
            if (taping) {
                const p = clamp((x - taping.x0) / (cw * 1.16), 0, 1);
                tape.style.clipPath = `inset(0 ${(1 - ((cx - cw * 0.58 + p * cw * 1.16) / SW)) * 100}% 0 0)`;
                if (p >= 0.9) {
                    tape.style.clipPath = 'inset(0 0 0 0)'; taping = null; sfx('tape', 0.8); done += 1; c.count(done, TARGET); c.flash('ok'); st = 3;
                    [fill, shut, tape].forEach((l) => l.classList.add('ship'));
                    c.later(() => { reset(); say(); }, 650);
                }
            }
        });
        c.on(window, 'pointerup', (e) => {
            if (taping) { taping = null; tape.style.clipPath = 'inset(0 100% 0 0)'; sfx('miss', 0.4); }
            if (!drag) return; drag = false; scoop.classList.remove('held');
            const [x, y] = c.at(e);
            if (over(x, y) && st === 0) {
                scoops += 1; sfx('pour', 0.9, rnd(0.95, 1.05)); fill.style.opacity = String(scoops / 3);
                if (scoops >= 3) { st = 1; }
                say();
            }
            put(scoop, bx + 40, by + 60, -0.4);
        });
        return () => {};
    }

    // ===================================================================== BREAD
    function gHarvest(c, T) {
        c.bg('field_bg');
        const m = c.meta('field_bg'), spots = m.spots || [], N = 20, LIFE = 6, times = schedule(N, T, 0.3, 3);
        const sick = c.spr('sickle', 'sickle'); let mx = 600, my = 400, px = 600, py = 400, down = false, spd = 0;
        const cl = []; let next = 0, cut = 0;
        c.count(0, N); G.score = () => cut / N;
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); down = true; sick.classList.add('swing'); });
        c.on(window, 'pointerup', () => { down = false; sick.classList.remove('swing'); });
        c.on(window, 'pointermove', (e) => { [mx, my] = c.at(e); });
        return (dt, t) => {
            while (next < N && t >= times[next]) {
                const free = spots.filter((s) => !cl.some((q) => !q.gone && q.s === s));
                if (free.length) { const s = pick(free); const el = c.spr('clump', 'clump'); put(el, s[0] + rnd(-20, 20), s[1] + rnd(-10, 10)); cl.push({ s, el, x: s[0], y: s[1], born: t }); }
                next += 1;
            }
            spd = spd * 0.7 + (Math.hypot(mx - px, my - py) / Math.max(dt, 0.001)) * 0.3; px = mx; py = my;
            put(sick, mx, my, down ? -0.5 : 0.1);
            for (const q of cl) {
                if (q.gone) continue;
                const age = t - q.born;
                q.el.style.filter = age > LIFE * 0.7 ? `saturate(${1 - (age - LIFE * 0.7) * 0.6}) brightness(${1 - (age - LIFE * 0.7) * 0.25})` : '';
                if (down && spd > 700 && Math.abs(mx - q.x) < 70 && my > q.y - 230 && my < q.y + 30) {
                    q.gone = true; cut += 1; c.count(cut, N); sfx('swish', 0.8, rnd(0.9, 1.1)); c.later(() => sfx('rustle', 0.5), 160);
                    q.el.classList.add('cut'); put(q.el, q.x + 30, q.y + 10, 1.2, 0.9);
                    const sh = c.spr('sheaf', 'sheaf'); put(sh, q.x, q.y, rnd(-0.3, 0.3), 0.8); c.later(() => sh.classList.add('gone'), 1400); c.later(() => { sh.remove(); q.el.remove(); }, 2200);
                } else if (age > LIFE) { q.gone = true; q.el.classList.add('wilt'); c.later(() => q.el.remove(), 800); }
            }
        };
    }

    function gMill(c, T) {
        c.bg('mill_bg');
        const m = c.meta('mill_bg'), [cx, cy] = m.center || [600, 345], [sx, sy] = m.spout || [600, 150];
        const run = c.spr('runner', 'runner'); const cv = c.el('canvas', 'jg-grain'); cv.width = SW; cv.height = SH; const g2 = cv.getContext('2d');
        const sackbar = c.el('div', 'jg-sack', '<i></i>'); const grind = c.loop('grind_loop', 0.9); grind.on();
        const spoutAng = Math.atan2(sx - cx, -(sy - cy));
        let ang = rnd(1.5, 3), speed = 2.6, hits = 0, passes = 0, misses = 0, last = ang, grains = [], lock = 0;
        c.count(0, 0); G.score = () => hits / Math.max(passes + misses, 10);   // a wrong press counts against you
        const press = () => {
            if (lock > 0) return; lock = 0.25;
            let d = ((ang - spoutAng) % (Math.PI * 2) + Math.PI * 3) % (Math.PI * 2) - Math.PI;
            if (Math.abs(d) < 0.27) {
                hits += 1; c.count(hits, Math.max(passes, 10)); sfx('grain', 0.8, rnd(0.95, 1.05)); speed = Math.min(5.2, speed + 0.18);
                for (let i = 0; i < 60; i++) grains.push({ x: sx + rnd(-6, 6), y: sy + rnd(-4, 4), vy: rnd(40, 120), life: rnd(0.4, 0.9) });
                sackbar.firstChild.style.height = `${clamp(hits / 12, 0, 1) * 100}%`;
            } else { misses += 1; sfx('miss', 0.7); c.flash('bad'); c.jolt(); }
        };
        c.on(window, 'keydown', (e) => { if (e.code === 'Space') { e.preventDefault(); if (!e.repeat) press(); } });
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); press(); });
        return (dt, t) => {
            lock -= dt; ang += speed * dt;
            const k = (a) => Math.floor((a - spoutAng + Math.PI) / (Math.PI * 2));
            if (k(ang) > k(last)) { passes += 1; c.count(hits, Math.max(passes, 10)); }
            last = ang; put(run, cx, cy, ang); grind.rate(0.8 + speed * 0.08);
            g2.clearRect(0, 0, SW, SH);
            for (const p of grains) { p.life -= dt; p.vy += 300 * dt; p.y += p.vy * dt * 0.15; if (p.life <= 0) continue; g2.fillStyle = `rgba(205,160,80,${clamp(p.life * 2, 0, 1)})`; g2.beginPath(); g2.ellipse(p.x, p.y, 2.2, 1.4, 0.4, 0, 7); g2.fill(); }
            grains = grains.filter((p) => p.life > 0);
        };
    }

    function gBake(c, T) {
        c.bg('oven_bg');
        const m = c.meta('oven_bg'), spots = m.spots || [[420, 420], [620, 420], [820, 420]];
        const glow = c.el('div', 'jg-glow'), fire = c.loop('fire_loop', 0.9); fire.on();
        const peel = c.spr('peel', 'peel'); peel.style.opacity = '0';
        let sum = 0, n = 0;
        c.count('0'); G.score = () => sum / Math.max(n, 7);
        const L = spots.map(([x, y]) => {
            const d = c.spr('loaf_dough', 'loaf hit'), gd = c.spr('loaf_golden', 'loaf'), bu = c.spr('loaf_burnt', 'loaf');
            [d, gd, bu].forEach((e) => put(e, x, y));
            const o = { x, y, d, gd, bu, p: rnd(-0.5, 0), rate: 1 / rnd(6.5, 9), busy: false };
            d.onpointerdown = (e) => { e.preventDefault(); if (!G || o.busy) return; take(o); };
            return o;
        });
        const quality = (p) => (p >= 0.58 && p <= 0.86 ? 1 : (p >= 0.45 && p < 0.58) || (p > 0.86 && p <= 1.0) ? 0.5 : 0);
        const take = (o) => {
            o.busy = true; const q = quality(o.p); sum += q; n += 1; c.count(`${Math.round(sum / Math.max(n, 1) * 100)}%`);
            sfx('peel', 0.8); c.flash(q === 1 ? 'ok' : q ? '' : 'bad');
            peel.style.opacity = '1'; peel.classList.remove('go'); put(peel, o.x, o.y + 260); void peel.offsetWidth; peel.classList.add('go'); put(peel, o.x, o.y);
            c.later(() => { [o.d, o.gd, o.bu, peel].forEach((e) => { e.classList.add('out'); put(e, o.x, o.y + 300); }); }, 260);
            c.later(() => { peel.style.opacity = '0'; [o.d, o.gd, o.bu, peel].forEach((e) => e.classList.remove('out')); [o.d, o.gd, o.bu].forEach((e) => put(e, o.x, o.y)); o.p = -0.25; o.rate = 1 / rnd(6, 9); o.busy = false; }, 900);
        };
        return (dt, t) => {
            glow.style.opacity = String(0.55 + Math.sin(t * 7) * 0.08 + Math.sin(t * 13) * 0.05);
            for (const o of L) {
                if (o.busy) continue;
                o.p += o.rate * dt; const p = Math.max(0, o.p);
                o.gd.style.opacity = String(clamp(p / 0.6, 0, 1)); o.bu.style.opacity = String(clamp((p - 0.85) / 0.35, 0, 1));
                o.d.style.opacity = p < 0.6 ? '1' : String(clamp(1 - (p - 0.6) * 4, 0.01, 1));
                if (o.p > 1.3) { sfx('miss', 0.5); take(o); }   // left too long: thrown away (counts as 0)
            }
        };
    }

    // ===================================================================== FISH
    function gFish(c, T) {
        c.bg('pier_bg');
        const m = c.meta('pier_bg'), spots = m.bob || [[500, 250]], [rx, ry] = m.tip || [330, 520];
        const svg = c.el('div', 'jg-line', `<svg width="${SW}" height="${SH}"><path/></svg>`), path = svg.querySelector('path');
        const bob = c.spr('bobber', 'bob'), rod = c.spr('rod', 'rod'); put(rod, rx, ry);
        const rip = c.el('div', 'jg-ripple'), meter = c.el('div', 'jg-meter', '<i class="zone"></i><i class="mark"></i><b><s></s></b>');
        const zoneE = meter.querySelector('.zone'), markE = meter.querySelector('.mark'), progE = meter.querySelector('s');
        const reel = c.loop('reel_loop', 0.8);
        let st = 'cast', tt = 0, bx = 0, by = 0, wait = 0, nib = 0, caught = 0, bites = 0, hold = false, mark = 0, zone = 0.5, zv = 0, prog = 0, over = 0, jump = null;
        meter.style.display = 'none'; c.count(0); G.score = () => caught / Math.max(bites, 4);
        const cast = () => { st = 'float'; tt = 0; [bx, by] = pick(spots); bx += rnd(-40, 40); by += rnd(-20, 20); wait = rnd(1.6, 3.6); nib = Math.random() < 0.6 ? 1 : 0; sfx('cast', 0.6); c.later(() => sfx('plop', 0.6), 380); rip.className = 'jg-ripple'; };
        const press = () => {
            if (st === 'bite') { st = 'reel'; tt = 0; mark = 0.3; zone = 0.5; prog = 0.2; over = 0; meter.style.display = ''; reel.on(); sfx('splash', 0.5); }
            else if (st === 'float' || st === 'nibble') { st = 'scared'; tt = 0; sfx('miss', 0.6); c.flash('bad'); }
        };
        c.on(window, 'keydown', (e) => { if (e.code === 'Space') { e.preventDefault(); if (!e.repeat) press(); hold = true; } });
        c.on(window, 'keyup', (e) => { if (e.code === 'Space') hold = false; });
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); press(); hold = true; }); c.on(window, 'pointerup', () => { hold = false; });
        cast();
        return (dt, t) => {
            tt += dt; let dip = 0;
            if (st === 'float') { if (tt > wait - (nib ? 0.9 : 0) && nib) { st = 'nibble'; } if (tt > wait) { st = 'bite'; tt = 0; bites += 1; sfx('splash', 0.9); rip.className = 'jg-ripple go'; } }
            if (st === 'nibble') { dip = Math.max(0, Math.sin(tt * 18)) * 6; if (tt > wait) { st = 'bite'; tt = 0; bites += 1; sfx('splash', 0.9); rip.className = 'jg-ripple go'; } }
            if (st === 'bite') { dip = 26; if (tt > 0.85) { st = 'gone'; tt = 0; sfx('miss', 0.5); } }
            if (st === 'reel') {
                zv += rnd(-3, 3) * dt; zv *= 0.97; zone = clamp(zone + zv * dt * 3 + Math.sin(t * 2.1) * 0.25 * dt, 0.12, 0.88);
                mark = clamp(mark + (hold ? 0.9 : -0.75) * dt, 0, 1);
                const inside = Math.abs(mark - zone) < 0.12;
                prog = clamp(prog + (inside ? 0.38 : -0.22) * dt, 0, 1); over = mark >= 0.99 ? over + dt : 0;
                zoneE.style.left = `${(zone - 0.12) * 100}%`; markE.style.left = `${mark * 100}%`; progE.style.width = `${prog * 100}%`;
                markE.classList.toggle('in', inside); dip = 18 + Math.sin(t * 20) * 6;
                if (prog >= 1) { st = 'caught'; tt = 0; caught += 1; c.count(caught); meter.style.display = 'none'; reel.off(); sfx('splash', 1); c.flash('ok'); jump = c.spr('fish_jump', 'jump'); }
                else if (prog <= 0 || over > 0.7 || tt > 7) { st = 'gone'; tt = 0; meter.style.display = 'none'; reel.off(); sfx(over > 0.7 ? 'snap' : 'miss', 0.8); c.flash('bad'); }
            }
            if (st === 'caught') { const f = tt / 0.9; if (jump) { put(jump, bx + f * (rx - bx) * 0.6, by - Math.sin(Math.PI * Math.min(f, 1)) * 160 + f * 60, -0.6 + f * 1.4, 0.9); jump.style.opacity = String(clamp(1.6 - f, 0, 1)); } if (tt > 1.0) { if (jump) jump.remove(); jump = null; cast(); } }
            if (st === 'gone' || st === 'scared') { if (tt > 1.1) cast(); }
            const y = by + Math.sin(t * 2.4) * 2 + dip;
            put(bob, bx, y, Math.sin(t * 1.7) * 0.08); bob.style.opacity = st === 'bite' || st === 'reel' ? '0.55' : '1';
            rip.style.left = `${bx}px`; rip.style.top = `${by + 4}px`;
            const mxp = (rx + bx) / 2, myp = Math.max(ry, y) - (st === 'reel' ? 40 : -30);
            path.setAttribute('d', `M ${rx} ${ry} Q ${mxp} ${myp} ${bx} ${y - 4}`);
        };
    }

    function gFillet(c, T) {
        c.bg('fillet_bg');
        const m = c.meta('fillet_bg'), [fx, fy] = m.board || [550, 345], [wx, wy] = m.bowl || [960, 225];
        const line = c.el('div', 'jg-cut', `<svg width="${SW}" height="${SH}"><path class="chalk"/><path class="done"/></svg>`);
        const chalk = line.querySelector('.chalk'), doneP = line.querySelector('.done');
        const knife = c.spr('knife', 'knife');
        // the cut along the back, from behind the head to the tail (fish anchor = its middle)
        const P0 = [-205, 52], P1 = [215, 44];
        let fish = null, cutting = false, prog = 0, dev = 0, samples = 0, sum = 0, n = 0, pts = [];
        c.count('0'); G.score = () => sum / Math.max(n, 5);
        const yAt = (x) => { const k = (x - (fx + P0[0])) / (P1[0] - P0[0]); return fy + P0[1] + (P1[1] - P0[1]) * k - Math.sin(Math.PI * clamp(k, 0, 1)) * 22; };
        const draw = () => { let d = ''; for (let i = 0; i <= 30; i++) { const x = fx + P0[0] + (P1[0] - P0[0]) * i / 30; d += `${i ? 'L' : 'M'} ${x} ${yAt(x)} `; } chalk.setAttribute('d', d); };
        const newFish = () => { fish = c.spr('fish_top', 'fishtop'); put(fish, fx - 500, fy); void fish.offsetWidth; fish.classList.add('slide'); put(fish, fx, fy); prog = 0; dev = 0; samples = 0; pts = []; doneP.setAttribute('d', ''); c.later(draw, 250); };
        chalk.setAttribute('d', '');
        newFish();
        c.on(c.stage, 'pointerdown', (e) => {
            e.preventDefault(); const [x, y] = c.at(e);
            if (!fish || fish.busy) return;
            if (Math.hypot(x - (fx + P0[0]), y - yAt(fx + P0[0])) < 60) { cutting = true; prog = 0; pts = [[x, y]]; }
        });
        c.on(window, 'pointermove', (e) => {
            const [x, y] = c.at(e); put(knife, x, y, -0.25);
            if (!cutting) return;
            const x0 = fx + P0[0], x1 = fx + P1[0];
            if (x > x0 + prog * (x1 - x0)) prog = clamp((x - x0) / (x1 - x0), 0, 1);
            const d = Math.abs(y - yAt(x)); dev += d; samples += 1; pts.push([x, y]);
            doneP.setAttribute('d', pts.map((p, i) => `${i ? 'L' : 'M'} ${p[0]} ${p[1]}`).join(' '));
            if (samples % 6 === 0) sfx('slice', 0.25, rnd(1.1, 1.3));
            if (prog >= 0.98) finishCut();
        });
        const finishCut = () => {
            cutting = false; const acc = clamp(1 - (dev / Math.max(1, samples)) / 38, 0, 1) * prog;
            sum += acc; n += 1; c.count(`${Math.round(sum / n * 100)}%`); sfx('slice', 0.9); c.flash(acc > 0.7 ? 'ok' : 'bad');
            const f = fish; f.busy = true; fish = null; chalk.setAttribute('d', '');
            const fl = c.spr('fillet_top', 'fl'); put(fl, fx, fy + 30); void fl.offsetWidth; fl.classList.add('slide'); put(fl, wx, wy, 0.4, 0.6);
            f.classList.add('off'); put(f, fx, fy + 500);
            c.later(() => { f.remove(); fl.classList.add('gone'); }, 700); c.later(() => fl.remove(), 1300); c.later(newFish, 800);
        };
        c.on(window, 'pointerup', () => { if (cutting && prog > 0.15) finishCut(); cutting = false; if (fish && !fish.busy) { pts = []; doneP.setAttribute('d', ''); } });
        return () => {};
    }

    function gIcepack(c, T) {
        c.bg('icepack_bg');
        const m = c.meta('icepack_bg'), [tx, ty] = m.tray || [700, 345], [tw, th] = m.tray_wh || [260, 380], [bx, by] = m.bin || [260, 345], TARGET = 5;
        const ice = c.layer('ice_cover', 'icel'), scoop = c.spr('ice_scoop', 'scoop hit'), stamp = c.el('div', 'jg-stamp', '<span>EX · FRESH<br><b>ICED</b></span>');
        let st = 0, n = 0, done = 0, fl = null, drag = null;
        const say = c.el('div', 'jg-hintbox');
        G.score = () => clamp((done + (st < 3 ? st * 0.2 : 0)) / TARGET, 0, 1);
        const inT = (x, y) => Math.abs(x - tx) < tw / 2 && Math.abs(y - ty) < th / 2;
        const tell = () => { say.textContent = ['اسحب السمك إلى الصينية', `غطّه بالثلج (${n}/2)`, 'اضغط على الصينية لتختمها'][st] || ''; };
        const newPack = () => {
            st = 0; n = 0; ice.style.opacity = '0'; stamp.className = 'jg-stamp'; ice.classList.remove('ship');
            fl = c.spr('fillet_top', 'fl hit'); fl._h = [tx + 330, ty - 170]; put(fl, ...fl._h, 0.3, 0.85);
            fl.onpointerdown = (e) => { e.preventDefault(); if (st === 0) drag = fl; };
            tell();
        };
        put(scoop, bx, by + 120, -0.3);
        scoop.onpointerdown = (e) => { e.preventDefault(); if (st === 1) { drag = scoop; scoop.classList.add('held'); } };
        Object.assign(stamp.style, { left: `${tx}px`, top: `${ty}px` });
        c.on(window, 'pointermove', (e) => { if (!drag) return; const [x, y] = c.at(e); put(drag, x, y, drag === scoop ? -0.2 : 0, drag === scoop ? 1 : 0.85); });
        c.on(window, 'pointerup', (e) => {
            if (!drag) return; const d = drag; drag = null; d.classList.remove('held'); const [x, y] = c.at(e);
            if (d === fl) { if (inT(x, y)) { put(fl, tx, ty, Math.PI / 2, 0.82); st = 1; sfx('tray', 0.8); } else put(fl, ...fl._h, 0.3, 0.85); }
            else { if (inT(x, y)) { n += 1; sfx('ice', 0.9, rnd(0.95, 1.05)); ice.style.opacity = String(n / 2); if (n >= 2) st = 2; } put(scoop, bx, by + 120, -0.3); }
            tell();
        });
        c.on(c.stage, 'pointerdown', (e) => {
            const [x, y] = c.at(e); if (st !== 2 || !inT(x, y)) return;
            st = 3; sfx('stamp', 0.9); stamp.className = 'jg-stamp on'; done += 1; c.count(done, TARGET); c.flash('ok'); say.textContent = '';
            c.later(() => { ice.classList.add('ship'); fl.classList.add('ship'); stamp.className = 'jg-stamp on ship'; }, 450);
            const old = fl; c.later(() => { old.remove(); newPack(); }, 1000);
        });
        c.count(0, TARGET); newPack();
        return () => {};
    }

    // ===================================================================== METALS
    function gMine(c, T) {
        c.bg('mine_bg');
        const m = c.meta('mine_bg'), [[x0, y0], [x1, y1]] = m.area || [[130, 60], [1070, 600]];
        const dark = c.el('div', 'jg-dark'), pickx = c.spr('pickaxe', 'pickx');
        const N = 12, LIFE = 8, times = schedule(N, T, 0.2, 3.5); let next = 0, mined = 0, mx = 600, my = 345; const ns = [];
        c.count(0, N); G.score = () => mined / N;
        c.on(window, 'pointermove', (e) => { [mx, my] = c.at(e); });
        const swing = () => { pickx.classList.remove('hitnow'); void pickx.offsetWidth; pickx.classList.add('hitnow'); };
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); swing(); const [x, y] = c.at(e); if (!ns.some((q) => !q.gone && Math.hypot(q.x - x, q.y - y) < 55)) sfx('pick', 0.45, 0.8); });
        return (dt, t) => {
            while (next < N && t >= times[next]) {
                let x, y, tries = 0; do { x = rnd(x0 + 60, x1 - 60); y = rnd(y0 + 60, y1 - 60); tries++; } while (tries < 20 && ns.some((q) => !q.gone && Math.hypot(q.x - x, q.y - y) < 160));
                const el = c.spr(`nodule${Math.floor(Math.random() * 3)}`, 'nod hit'); put(el, x, y, rnd(-1, 1));
                const cr = c.el('div', 'jg-crack'); Object.assign(cr.style, { left: `${x}px`, top: `${y}px` });
                const gl = c.el('div', 'jg-glint'); Object.assign(gl.style, { left: `${x + rnd(-20, 20)}px`, top: `${y + rnd(-20, 10)}px` });
                const q = { el, cr, gl, x, y, hits: 0, born: t, gone: false };
                el.onpointerdown = (e) => {
                    e.preventDefault(); if (q.gone || !G) return; q.hits += 1; sfx('pick', 0.9, rnd(0.9, 1.1)); c.jolt();
                    cr.innerHTML = `<svg width="120" height="120" viewBox="-60 -60 120 120">${Array.from({ length: q.hits * 2 }, () => { const a = rnd(0, 6.28), l = rnd(20, 45); return `<path d="M 0 0 L ${Math.cos(a) * l * 0.5 + rnd(-6, 6)} ${Math.sin(a) * l * 0.5 + rnd(-6, 6)} L ${Math.cos(a) * l} ${Math.sin(a) * l}"/>`; }).join('')}</svg>` + cr.innerHTML;
                    if (q.hits >= 3) { q.gone = true; mined += 1; c.count(mined, N); sfx('rockfall', 0.9); el.classList.add('fall'); put(el, x + rnd(-30, 30), y + 420, rnd(-3, 3)); cr.remove(); gl.remove(); c.later(() => el.remove(), 900); }
                };
                ns.push(q); next += 1;
            }
            dark.style.setProperty('--mx', `${mx}px`); dark.style.setProperty('--my', `${my}px`);
            put(pickx, mx + 30, my + 10, 0.2, 0.6);
            for (const q of ns) if (!q.gone && t - q.born > LIFE) { q.gone = true; q.el.classList.add('fade'); q.cr.remove(); q.gl.remove(); c.later(() => q.el.remove(), 700); }
        };
    }

    function gSort(c, T) {
        c.bg('belt_bg');
        const m = c.meta('belt_bg'), Y = m.y ?? 310, [chx, chy] = m.chute || [600, 590], X0 = m.x0 ?? 30, X1 = m.x1 ?? 1170;
        const seams = c.el('div', 'jg-belt'); seams.style.top = `${Y - 130}px`;
        const belt = c.loop('belt_loop', 0.7); belt.on();
        const N = 22, times = schedule(N, T, 0.2, 2.6), rocks = []; let next = 0, right = 0, total = 0, off = 0;
        const SPEED = 260;
        c.count('0'); G.score = () => right / Math.max(total, N);
        const judge = (ok) => { total += 1; if (ok) right += 1; c.count(`${right}/${total}`); };
        return (dt, t) => {
            off = (off + SPEED * dt) % 80; seams.style.backgroundPositionX = `${off}px`;
            while (next < N && t >= times[next]) {
                const slag = Math.random() < 0.42, kind = slag ? pick(['slag_a', 'slag_b']) : pick(['ore_a', 'ore_b', 'ore_c']);
                const el = c.spr(kind, 'rock hit'); const r = { el, slag, x: X0 - 60, y: Y + rnd(-70, 70), rot: rnd(0, 6), done: false };
                el.onpointerdown = (e) => {
                    e.preventDefault(); if (r.done || !G) return; r.done = true;
                    if (r.slag) { judge(true); sfx('toss', 0.8, rnd(0.9, 1.1)); el.classList.add('toss'); put(el, chx + rnd(-60, 60), chy + 40, r.rot + 2, 0.8); c.later(() => el.remove(), 600); }
                    else { judge(false); sfx('miss', 0.8); c.flash('bad'); c.jolt(); el.classList.add('toss'); put(el, chx + rnd(-60, 60), chy + 40, r.rot + 2, 0.8); c.later(() => el.remove(), 600); }
                };
                rocks.push(r); next += 1;
            }
            for (const r of rocks) {
                if (r.done) continue;
                r.x += SPEED * dt; put(r.el, r.x, r.y, r.rot);
                if (r.x > X1 + 20) { r.done = true; judge(!r.slag); if (r.slag) { sfx('miss', 0.6); c.flash('bad'); } else sfx('thud', 0.3); r.el.classList.add('fade'); c.later(() => r.el.remove(), 500); }
            }
        };
    }

    function gSmelt(c, T) {
        c.bg('smelt_bg');
        const m = c.meta('smelt_bg'), molds = m.molds || [[360, 345], [520, 345], [680, 345], [840, 345]];
        const cru = c.spr('crucible', 'cru'), stream = c.el('div', 'jg-stream'), pour = c.loop('pour_loop', 0.9);
        const M = molds.map(([x, y]) => {
            const mo = c.spr('molten', 'molt'), ca = c.spr('cast', 'cast'); put(mo, x, y); put(ca, x, y); mo.style.opacity = ca.style.opacity = '0';
            const line = c.el('div', 'jg-fill', '<i></i>'); Object.assign(line.style, { left: `${x + 92}px`, top: `${y - 40}px` });
            return { x, y, mo, ca, line, f: 0, state: 'empty' };
        });
        let mx = 600, hold = false, good = 0, judged = 0, cur = M[0], tilt = 0;
        c.count('0'); G.score = () => good / Math.max(judged, 8);
        c.on(window, 'pointermove', (e) => { [mx] = c.at(e); });
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); hold = true; });
        c.on(window, 'pointerup', () => { hold = false; if (cur && cur.state === 'pour') settle(cur, false); });
        const settle = (o, spill) => {
            judged += 1; const ok = !spill && o.f >= 0.85;
            o.state = ok ? 'good' : 'bad'; if (ok) good += 1; c.count(`${good}/${judged}`);
            if (ok) { sfx('hiss', 0.7); c.flash('ok'); c.later(() => { o.ca.style.opacity = '1'; o.mo.style.opacity = '0'; }, 900); }
            else { sfx(spill ? 'hiss' : 'miss', 0.8); c.flash('bad'); o.mo.classList.add(spill ? 'spill' : 'short'); }
            o.line.firstChild.style.height = '0%';
            if (M.every((q) => q.state === 'good' || q.state === 'bad')) c.later(() => M.forEach((q) => { q.state = 'empty'; q.f = 0; q.mo.className = 'spr molt'; q.mo.style.opacity = q.ca.style.opacity = '0'; }), 1500);
        };
        return (dt, t) => {
            const near = M.reduce((a, b) => (Math.abs(b.x - mx) < Math.abs(a.x - mx) ? b : a));
            if (!(cur && cur.state === 'pour' && hold)) cur = near;
            const pouring = hold && (cur.state === 'empty' || cur.state === 'pour');
            tilt += ((pouring ? 1 : 0) - tilt) * Math.min(1, dt * 8);
            put(cru, cur.x + 70 - tilt * 30, cur.y - 120, -tilt * 0.9, 1);
            stream.style.opacity = String(pouring ? 1 : 0); Object.assign(stream.style, { left: `${cur.x + 30}px`, top: `${cur.y - 100}px` });
            if (pouring) {
                cur.state = 'pour'; pour.on(); cur.f += dt * 0.42;
                cur.mo.style.opacity = String(clamp(cur.f * 1.4, 0, 1)); cur.mo.style.transform = cur.mo.style.transform.replace(/scale\([^)]*\)/, `scale(${0.55 + clamp(cur.f, 0, 1) * 0.45})`);
                cur.line.firstChild.style.height = `${clamp(cur.f / 1.05, 0, 1) * 100}%`;
                if (cur.f > 1.05) { hold = false; settle(cur, true); }
            } else pour.off();
            for (const o of M) o.line.style.opacity = o === cur && (o.state === 'empty' || o.state === 'pour') ? '1' : '0';
        };
    }

    // ===================================================================== FABRICS
    function gShear(c, T) {
        c.bg('shear_bg');
        const m = c.meta('shear_bg'), [sx, sy] = m.sheep || [600, 345], TARGET = 3;
        const sw = META.sheep_wool || { w: 600, h: 400, ax: 300, ay: 200 };
        const shorn = c.spr('sheep_shorn', 'sheep'); const cv = c.el('canvas', 'jg-wool'); cv.width = sw.w; cv.height = sw.h;
        const g2 = cv.getContext('2d'); const woolImg = new Image(); woolImg.src = 'mg/sheep_wool.webp';
        const clip = c.spr('clippers', 'clip'), buzz = c.loop('clipper_loop', 0.8);
        let down = false, total = 0, left = 1, sum = 0, done = 0, lx = null, ly = null, ready = false, x = sx, moving = false;
        const tufts = [];
        G.score = () => clamp((sum + (1 - left)) / TARGET, 0, 1);
        const place = () => { cv.style.left = `${x - sw.ax}px`; cv.style.top = `${sy - sw.ay}px`; put(shorn, x, sy); };
        const fresh = () => {
            g2.globalCompositeOperation = 'source-over'; g2.clearRect(0, 0, cv.width, cv.height); g2.drawImage(woolImg, 0, 0);
            cells = Array.from(MK.bits, (b) => (b === '1' ? 1 : 0)); total = count(); left = 1; ready = true;
        };
        // what is left of the fleece, on the coarse grid from the render (no canvas reads)
        const MK = sw.mask || { c: 16, cols: 1, rows: 1, bits: '1' }; let cells = null;
        const count = () => (cells ? cells.reduce((n, v) => n + v, 0) : 0);
        const shave = (cx, cy, r) => {
            if (!cells) return; const C = MK.c;
            for (let gy = Math.max(0, Math.floor((cy - r) / C)); gy <= Math.min(MK.rows - 1, Math.floor((cy + r) / C)); gy++)
                for (let gx = Math.max(0, Math.floor((cx - r) / C)); gx <= Math.min(MK.cols - 1, Math.floor((cx + r) / C)); gx++)
                    if (Math.hypot(gx * C + C / 2 - cx, gy * C + C / 2 - cy) < r) cells[gy * MK.cols + gx] = 0;
        };
        woolImg.onload = () => { place(); fresh(); };
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); down = true; lx = null; });
        c.on(window, 'pointerup', () => { down = false; buzz.off(); });
        let ang = 0;
        c.on(window, 'pointermove', (e) => {
            const [px, py] = c.at(e);
            if (lx !== null) { const a = Math.atan2(py - ly, px - lx); if (Math.hypot(px - lx, py - ly) > 2) ang = a; }
            put(clip, px, py, ang);
            if (down && ready && !moving) {
                buzz.on();
                const cx = px - (x - sw.ax), cy = py - (sy - sw.ay);
                g2.globalCompositeOperation = 'destination-out'; g2.lineCap = 'round'; g2.lineWidth = 58;
                g2.beginPath(); g2.moveTo(lx === null ? cx : lx - (x - sw.ax), ly === null ? cy : ly - (sy - sw.ay)); g2.lineTo(cx, cy); g2.stroke();
                if (lx !== null) { const ox = lx - (x - sw.ax), oy = ly - (sy - sw.ay), L = Math.hypot(cx - ox, cy - oy); for (let k = 0; k <= L; k += 10) shave(ox + (cx - ox) * k / Math.max(L, 1), oy + (cy - oy) * k / Math.max(L, 1), 29); } else shave(cx, cy, 29);
                if (Math.random() < 0.25) { const t2 = c.el('div', 'jg-tuft'); Object.assign(t2.style, { left: `${px}px`, top: `${py}px` }); tufts.push({ e: t2, x: px, y: py, vx: rnd(-80, 80), vy: rnd(-80, 80), life: 1.2 }); }
            }
            lx = px; ly = py;
        });
        let chk = 0;
        return (dt) => {
            chk += dt;
            if (ready && !moving && chk > 0.25) { chk = 0; left = total ? count() / total : 1; c.count(`${Math.round((1 - left) * 100)}%`); }
            if (ready && !moving && left < 0.12) {
                moving = true; left = 1; sum += 1; done += 1; c.flash('ok'); sfx('ok', 0.5); buzz.off();
                const go = () => { x += 18; place(); if (x < SW + 400) c.later(go, 16); else { x = -400; fresh(); const back = () => { x = Math.min(sx, x + 22); place(); if (x < sx) c.later(back, 16); else moving = false; }; back(); } };
                go();
            }
            for (const q of tufts) { q.life -= dt; q.x += q.vx * dt; q.y += q.vy * dt + 30 * dt; q.vx *= 0.96; q.vy *= 0.96; q.e.style.left = `${q.x}px`; q.e.style.top = `${q.y}px`; q.e.style.opacity = String(clamp(q.life, 0, 1)); if (q.life <= 0) q.e.remove(); }
            for (let i = tufts.length - 1; i >= 0; i--) if (tufts[i].life <= 0) tufts.splice(i, 1);
        };
    }

    function gWeave(c, T) {
        c.bg('loom_bg');
        const m = c.meta('loom_bg'), top = m.cloth_top ?? 125, bot = m.cloth_bot ?? 585, [cl, cr] = m.cloth_x || [245, 955], [lx, ly] = m.box_l || [180, 335], [rx] = m.box_r || [1020];
        const cloth = c.layer('loom_cloth', 'cloth'), reed = c.spr('reed', 'reed'), sh = c.spr('shuttle', 'shuttle');
        let rows = 0, fell = bot - 40, x = lx, dir = 1, sp = 520, state = 'fly', wait = 0, good = 0, arr = 0, beat = 0;
        c.count('0'); G.score = () => good / Math.max(arr, 14);
        const setCloth = () => { cloth.style.clipPath = `inset(${(fell / SH) * 100}% 0 0 0)`; };
        setCloth();
        const win = c.el('div', 'jg-win'); win.style.display = 'none';
        c.on(window, 'keydown', (e) => {
            const k = c.key(e); if ((k !== 'A' && k !== 'D') || e.repeat) return;
            if (state !== 'wait') { arr += 0.5; c.count(`${good}/${Math.round(arr)}`); sfx('miss', 0.5); return; }   // too early counts against you
            const side = dir > 0 ? 'D' : 'A';
            if (k === side) {
                good += 1; arr += 1; c.count(`${good}/${arr}`); sfx('shuttle', 0.8, rnd(0.95, 1.05)); state = 'fly'; dir = -dir; sp = Math.min(900, sp + 22); win.style.display = 'none';
                beat = 0.001; fell = Math.max(top, fell - (bot - top) / 18); setCloth();
            } else { arr += 1; c.count(`${good}/${arr}`); sfx('miss', 0.7); c.flash('bad'); state = 'drop'; wait = 0.7; win.style.display = 'none'; }
        });
        return (dt, t) => {
            if (state === 'fly') {
                x += dir * sp * dt; const end = dir > 0 ? rx : lx;
                if ((dir > 0 && x >= end) || (dir < 0 && x <= end)) { x = end; state = 'wait'; wait = 0.55; win.style.display = ''; win.textContent = dir > 0 ? 'D' : 'A'; win.style.left = `${x}px`; win.style.top = `${fell - 60}px`; }
            } else if (state === 'wait') {
                wait -= dt; if (wait <= 0) { arr += 1; c.count(`${good}/${arr}`); sfx('miss', 0.6); state = 'drop'; wait = 0.7; win.style.display = 'none'; }
            } else if (state === 'drop') { wait -= dt; if (wait <= 0) { state = 'fly'; dir = -dir; } }
            if (beat) { beat += dt; if (beat > 0.08 && beat - dt <= 0.08) sfx('beat', 0.7); if (beat > 0.3) beat = 0; }
            const by = fell - 12 + (beat ? Math.sin(Math.min(1, beat / 0.3) * Math.PI) * -36 : -36);
            put(reed, (cl + cr) / 2, by); put(sh, x, fell - 22, 0, 1, dir < 0);
        };
    }

    function gSew(c, T) {
        c.bg('sew_bg');
        const m = c.meta('sew_bg'), [nx, ny] = m.needle || [600, 345];
        const fab = c.el('div', 'jg-fabric'), cv = c.el('canvas', 'jg-seam'); cv.width = SW; cv.height = SH; const g2 = cv.getContext('2d');
        c.layer('sew_head', 'head');
        const motor = c.loop('sew_loop', 0.9);
        const tint = pick(['#2f4f7a', '#7a3030', '#3d5b3a', '#6b5a3a']); fab.style.setProperty('--tint', tint);
        let off = 0, fx = 0, mx = nx, down = false, speed = 0, onLine = 0, run = 0, ph = rnd(0, 6);
        const stitches = [];
        G.score = () => clamp(onLine / (T * 120 * 0.8), 0, 1);
        const seamX = (y) => nx + Math.sin((y + ph * 100) / 140) * 120 + Math.sin((y + ph * 37) / 61) * 35;
        c.on(window, 'pointermove', (e) => { [mx] = c.at(e); });
        c.on(c.stage, 'pointerdown', (e) => { e.preventDefault(); down = true; });
        c.on(window, 'pointerup', () => { down = false; });
        return (dt) => {
            speed += ((down ? 120 : 0) - speed) * Math.min(1, dt * 6);
            motor.set(speed / 120); motor.rate(0.8 + speed / 300);
            off += speed * dt;                                   // the fabric moves away from you (up the screen)
            fx += ((mx - nx) - fx) * Math.min(1, dt * 5);        // you steer the fabric sideways
            fab.style.backgroundPosition = `${fx}px ${-off}px`;
            // the needle sits still; in fabric coordinates it is at (nx - fx, ny + off)
            const fy = ny + off, sx = seamX(fy), d = Math.abs((nx - fx) - sx);
            G.aim = 2 * nx - seamX(fy + 40);                    // (where the mouse should be: used by the test bot)
            if (speed > 30) { run += speed * dt; if (d < 16) onLine += speed * dt; if (run > 9) { run = 0; stitches.push([nx - fx, fy, d < 16]); } }
            c.count(`${Math.round(clamp(onLine / (T * 120 * 0.8), 0, 1) * 100)}%`);
            g2.clearRect(0, 0, SW, SH);
            g2.setLineDash([9, 7]); g2.lineWidth = 3; g2.strokeStyle = 'rgba(240,236,225,.75)'; g2.beginPath();
            for (let y = -20; y <= SH + 20; y += 8) { const wy = y + off; const X = seamX(wy) + fx; if (y === -20) g2.moveTo(X, y); else g2.lineTo(X, y); }
            g2.stroke(); g2.setLineDash([]);
            g2.lineWidth = 2.6; g2.lineCap = 'round';
            for (let i = 1; i < stitches.length; i++) {
                const a = stitches[i - 1], b = stitches[i]; const ay = a[1] - off, by2 = b[1] - off; if (by2 < -30 || ay > SH + 30) continue;
                g2.strokeStyle = b[2] ? '#f3e9c8' : '#e85a3a'; g2.beginPath(); g2.moveTo(a[0] + fx, ay); g2.lineTo(b[0] + fx, by2 - 4); g2.stroke();
            }
            while (stitches.length > 400) stitches.shift();
        };
    }

    const GAMES = { catch: gCatch, slaughter: gSlaughter, pack: gPack, pick: gPick, dry: gDry, box: gBox, harvest: gHarvest, mill: gMill, bake: gBake, fish: gFish, fillet: gFillet, icepack: gIcepack, mine: gMine, sort_ore: gSort, smelt: gSmelt, shear: gShear, weave: gWeave, sew: gSew };

    // close a game without sending anything (the game client gave up on it)
    function stop() {
        if (!G) return;
        G.over = true; (G.c ? G.c.off : []).forEach((f) => { try { f(); } catch (e) { /* */ } });
        G = null; const box = root(); box.className = 'jg'; box.innerHTML = '';
    }

    function start(game, count, seconds) {
        if (G) stop();                       // a game left over from before: the client already gave up on it
        if (!GAMES[game]) game = 'pack';
        const T = Math.max(25, Number(seconds) || 28);
        G = { over: false, score: () => 0 };
        const c = shell(game, count); G.c = c;
        let step;
        try { step = GAMES[game](c, T) || (() => {}); } catch (e) { console.error(e); step = () => {}; }
        const timeBar = document.getElementById('jgt');
        let t0 = null, last = null;
        const tick = (now) => {
            if (!G || G.over || G.c !== c) return;
            if (t0 === null) { t0 = now; last = now; }
            const t = (now - t0) / 1000, dt = Math.min(0.05, (now - last) / 1000); last = now;
            timeBar.style.width = `${Math.max(0, 100 - (t / T) * 100)}%`;
            if (t >= T - 3) timeBar.classList.add('late');
            try { step(dt, t); } catch (e) { console.error(e); }
            if (t >= T) { finish(); return; }
            requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
        return true;
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'game') start(m.game, m.count || 0, m.seconds);
        else if (m.action === 'gameStop') stop();
    });
    window.EXJ_GAME = { start, state: () => G }; // (for testing outside the game)
})();
