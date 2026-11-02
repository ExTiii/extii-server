/* =====================================================================
   EX_Tii jobs: the mini games of the level jobs (Moe's design).
   { action: 'game', game: 'catch' | 'slaughter' | 'pack' | 'pick' | 'dry' | 'sort', count, seconds }
   Every game lasts the whole `seconds` (at least 25), then sends { score: 0..1 } to 'gameDone'.
     catch     — chickens run around the pen: click them before they get out
     slaughter — chickens ride the line: press SPACE / E (or click) when one is in the gold zone
     pack      — pieces drop on the table: drag each one into the tray before it spoils
     pick      — grape bunches hang on the vine with a letter: press W / A / S / D before its ring runs out
     dry       — hold SPACE (or the mouse) to heat the rack: keep the needle inside the gold band as it moves
     sort      — raisins come down the chute: A = good (to the carton, left), D = spoiled (to the bin, right)
   ===================================================================== */
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'exti_jobs';
    const send = (score) => fetch(`https://${RES}/gameDone`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ score }) }).catch(() => {});

    const HEN = `<svg viewBox="0 0 100 100"><path d="M22 66c-6-14 2-34 22-36 2-10 9-16 17-16 6 0 10 5 10 10 0 3-1 6-3 8 12 6 18 17 18 30 0 16-14 26-33 26-14 0-25-7-31-22z" fill="#fbf6ec" stroke="#5a4a32" stroke-width="3"/><path d="M58 12c2-6 8-7 10-3 3-4 9-2 8 3 4 0 5 5 2 7-6 2-14 1-20-7z" fill="#e2303c"/><path d="M78 30l12 5-12 5z" fill="#f2a623" stroke="#8a5a00" stroke-width="2"/><circle cx="68" cy="27" r="3.4" fill="#1d1d22"/><path d="M30 60c8 6 22 7 30 2" stroke="#5a4a32" stroke-width="3" fill="none" opacity=".55"/><path d="M44 92v6M56 92v6" stroke="#f2a623" stroke-width="4" stroke-linecap="round"/></svg>`;
    const MEAT = `<svg viewBox="0 0 100 100"><path d="M18 58c0-18 14-30 32-30s32 12 32 30-14 28-32 28S18 76 18 58z" fill="#f6b39a" stroke="#a5583d" stroke-width="3"/><path d="M24 50c-8-6-12-12-8-16 4-3 10 2 14 8M76 50c8-6 12-12 8-16-4-3-10 2-14 8" fill="#ffd0b8" stroke="#a5583d" stroke-width="3"/><path d="M34 54c6 6 26 6 32 0" stroke="#c97a5c" stroke-width="2.5" fill="none"/><ellipse cx="42" cy="44" rx="8" ry="4" fill="#fff" opacity=".45"/></svg>`;
    const KNIFE = `<svg viewBox="0 0 100 40"><path d="M4 22L62 8h30v20H62z" fill="#dfe3e8" stroke="#6b7280" stroke-width="2"/><rect x="62" y="12" width="34" height="14" rx="4" fill="#3a2a1a"/></svg>`;

    const TEXT = {
        catch: { title: 'اصطد الدجاج', hint: 'اضغط على كل دجاجة قبل أن تهرب من الحظيرة', unit: 'أمسكت' },
        slaughter: { title: 'اذبح الدجاج', hint: 'اضغط مسافة أو E حين تكون الدجاجة داخل المنطقة الذهبية', unit: 'ذبحت' },
        pack: { title: 'عبّئ الدجاج', hint: 'اسحب كل قطعة إلى الصينية قبل أن تفسد', unit: 'عبّأت' },
        pick: { title: 'اقطف العنب', hint: 'اضغط الحرف الظاهر على العنقود (W A S D) قبل أن تنتهي دائرته', unit: 'قطفت', word: 'عنقود' },
        dry: { title: 'جفّف العنب', hint: 'اضغط مع الاستمرار على مسافة لتسخين المنشر، وأبقِ المؤشر داخل المنطقة الذهبية', unit: 'جودة', word: 'عنقود' },
        sort: { title: 'افرز الزبيب', hint: 'A = زبيب جيد إلى الكرتونة · D = زبيب تالف إلى السلة', unit: 'فرزت', word: 'حبة زبيب' },
    };

    let G = null; // the game that is on screen

    function frame(kind, count) {
        const t = TEXT[kind];
        const el = document.createElement('div');
        el.id = 'mg';
        el.className = 'mg';
        el.innerHTML = `
            <div class="mg-card">
                <div class="mg-head">
                    <div><h3>${t.title}</h3><p>${t.hint}</p></div>
                    <div class="mg-score"><b id="mg-done">0</b><span>/ <i id="mg-total">0</i></span><small>${t.unit}</small></div>
                </div>
                <div class="mg-timer"><s id="mg-time"></s></div>
                <div class="mg-area mg-${kind}" id="mg-area"></div>
                <div class="mg-foot">تتعامل مع <b>${count}</b> ${t.word || 'دجاجة'} · نتيجتك تحدد كم تنجو منها</div>
            </div>`;
        document.body.appendChild(el);
        requestAnimationFrame(() => el.classList.add('in'));
        return el;
    }

    function finish() {
        if (!G || G.over) return;
        G.over = true;
        cancelAnimationFrame(G.raf);
        G.cleanup && G.cleanup();
        const score = Math.max(0, Math.min(1, G.score()));
        const pct = Math.round(score * 100);
        const end = document.createElement('div');
        end.className = 'mg-end';
        end.innerHTML = `<b>${pct}%</b><span>${pct >= 90 ? 'ممتاز!' : pct >= 60 ? 'جيد' : 'حاول أن تكون أسرع'}</span>`;
        G.el.querySelector('.mg-card').appendChild(end);
        const el = G.el;
        G = null;
        setTimeout(() => { el.classList.remove('in'); setTimeout(() => el.remove(), 250); send(score); }, 1300);
    }

    // the clock shared by every game: the bar and the end
    function tick(now) {
        if (!G) return;
        const t = (now - G.start) / 1000;
        G.el.querySelector('#mg-time').style.width = `${Math.max(0, 100 - (t / G.seconds) * 100)}%`;
        G.step(t, now);
        if (t >= G.seconds) return finish();
        G.raf = requestAnimationFrame(tick);
    }

    const setDone = (n) => { const b = G && G.el.querySelector('#mg-done'); if (b) b.textContent = n; };
    const setTotal = (n) => { const b = G && G.el.querySelector('#mg-total'); if (b) b.textContent = n; };

    // the moments things appear: spread over the game, the last one with time to be done
    const schedule = (n, seconds, lead = 0.8, tail = 3.4) => Array.from({ length: n }, (_, i) => lead + i * ((seconds - lead - tail) / Math.max(1, n - 1)));

    // ------------------------------------------------------------------ catch
    function catchGame(seconds) {
        const area = G.el.querySelector('#mg-area');
        const W = area.clientWidth, H = area.clientHeight;
        const N = 18, LIFE = 3.1;
        const times = schedule(N, seconds, 0.5, LIFE + 0.3);
        const hens = [];
        let next = 0, caught = 0;
        setTotal(N);
        G.score = () => caught / N;
        G.step = (t) => {
            while (next < N && t >= times[next]) {
                const el = document.createElement('button');
                el.className = 'mg-hen';
                el.innerHTML = HEN;
                const h = { el, x: 40 + Math.random() * (W - 120), y: 30 + Math.random() * (H - 110), vx: (Math.random() < 0.5 ? -1 : 1) * (170 + Math.random() * 130), vy: (Math.random() - 0.5) * 240, born: t, done: false };
                el.onpointerdown = (e) => {
                    e.preventDefault();
                    if (h.done) return;
                    h.done = true;
                    caught += 1;
                    setDone(caught);
                    el.classList.add('got');
                    setTimeout(() => el.remove(), 380);
                };
                area.appendChild(el);
                hens.push(h);
                next += 1;
            }
            for (const h of hens) {
                if (h.done) continue;
                const age = t - h.born;
                if (age > LIFE) { // it got out
                    h.done = true;
                    h.el.classList.add('gone');
                    setTimeout(() => h.el.remove(), 380);
                    continue;
                }
                const dt = 1 / 60;
                if (Math.random() < 0.02) { h.vx *= -1; }
                if (Math.random() < 0.03) { h.vy = (Math.random() - 0.5) * 200; }
                h.x += h.vx * dt; h.y += h.vy * dt;
                if (h.x < 0 || h.x > W - 72) { h.vx *= -1; h.x = Math.max(0, Math.min(W - 72, h.x)); }
                if (h.y < 0 || h.y > H - 72) { h.vy *= -1; h.y = Math.max(0, Math.min(H - 72, h.y)); }
                h.el.style.transform = `translate(${h.x}px, ${h.y}px) scaleX(${h.vx < 0 ? -1 : 1})`;
                h.el.style.opacity = age > LIFE - 0.6 ? String(Math.max(0.25, (LIFE - age) / 0.6)) : '1';
            }
        };
    }

    // ------------------------------------------------------------------ slaughter
    function slaughterGame(seconds) {
        const area = G.el.querySelector('#mg-area');
        area.innerHTML = `<div class="mg-belt"></div><div class="mg-zone"></div><div class="mg-knife">${KNIFE}</div>
            <button class="mg-cut" id="mg-cut">اذبح (مسافة / E)</button>`;
        const W = area.clientWidth;
        const zoneW = 110, zoneX = W / 2 - zoneW / 2;
        const N = 10, SPEED = 230; // px per second
        const travel = (W + 80) / SPEED;
        const times = schedule(N, seconds, 0.4, travel * 0.55);
        const hens = [];
        let next = 0, cut = 0, misses = 0;
        setTotal(N);
        G.score = () => cut / N - misses * 0.05;
        const knife = area.querySelector('.mg-knife');
        const press = () => {
            knife.classList.remove('chop');
            void knife.offsetWidth;
            knife.classList.add('chop');
            const hit = hens.find((h) => !h.done && h.x + 36 > zoneX && h.x + 36 < zoneX + zoneW);
            if (hit) {
                hit.done = true;
                cut += 1;
                setDone(cut);
                hit.el.classList.add('cut');
                hit.el.innerHTML = MEAT;
            } else {
                misses += 1;
                area.classList.remove('miss'); void area.offsetWidth; area.classList.add('miss');
            }
        };
        const onKey = (e) => {
            if (e.repeat) return;
            if (e.code === 'Space' || e.key === 'e' || e.key === 'E' || e.key === 'ث') { e.preventDefault(); press(); }
        };
        window.addEventListener('keydown', onKey);
        area.querySelector('#mg-cut').onclick = press;
        G.cleanup = () => window.removeEventListener('keydown', onKey);
        G.step = (t) => {
            while (next < N && t >= times[next]) {
                const el = document.createElement('div');
                el.className = 'mg-hen ride';
                el.innerHTML = HEN;
                area.appendChild(el);
                hens.push({ el, born: t, x: -80, done: false, passed: false });
                next += 1;
            }
            for (const h of hens) {
                h.x = -80 + (t - h.born) * SPEED;
                h.el.style.transform = `translate(${h.x}px, 0)`;
                if (!h.done && !h.passed && h.x > zoneX + zoneW) { h.passed = true; h.el.classList.add('late'); }
                if (h.x > W + 10 && !h.removed) { h.removed = true; h.el.remove(); }
            }
        };
    }

    // ------------------------------------------------------------------ pack
    function packGame(seconds) {
        const area = G.el.querySelector('#mg-area');
        area.innerHTML = `<div class="mg-tray" id="mg-tray"><span>الصينية</span></div>`;
        const tray = area.querySelector('#mg-tray');
        const N = 10, LIFE = 3.8;
        const times = schedule(N, seconds, 0.6, LIFE + 0.3);
        const pieces = [];
        let next = 0, packed = 0, drag = null;
        setTotal(N);
        G.score = () => packed / N;
        const inTray = (x, y) => {
            const r = tray.getBoundingClientRect();
            return x > r.left - 10 && x < r.right + 10 && y > r.top - 10 && y < r.bottom + 10;
        };
        const move = (e) => {
            if (!drag) return;
            const r = area.getBoundingClientRect();
            drag.p.el.style.left = `${e.clientX - r.left - drag.dx}px`;
            drag.p.el.style.top = `${e.clientY - r.top - drag.dy}px`;
            tray.classList.toggle('over', inTray(e.clientX, e.clientY));
        };
        const up = (e) => {
            if (!drag) return;
            const p = drag.p;
            drag = null;
            tray.classList.remove('over');
            p.el.classList.remove('held');
            if (!p.done && inTray(e.clientX, e.clientY)) {
                p.done = true;
                packed += 1;
                setDone(packed);
                p.el.classList.add('packed');
                tray.classList.add('fill');
                setTimeout(() => tray.classList.remove('fill'), 250);
                setTimeout(() => p.el.remove(), 300);
            }
        };
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', up);
        G.cleanup = () => { window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); };
        G.step = (t) => {
            while (next < N && t >= times[next]) {
                const el = document.createElement('div');
                el.className = 'mg-piece';
                el.innerHTML = `${MEAT}<i></i>`;
                el.style.left = `${area.clientWidth * 0.42 + Math.random() * (area.clientWidth * 0.58 - 100)}px`;
                el.style.top = `${30 + Math.random() * (area.clientHeight - 130)}px`;
                const p = { el, born: t, done: false };
                el.onpointerdown = (e) => {
                    if (p.done) return;
                    e.preventDefault();
                    const r = el.getBoundingClientRect();
                    drag = { p, dx: e.clientX - r.left, dy: e.clientY - r.top };
                    el.classList.add('held');
                };
                area.appendChild(el);
                pieces.push(p);
                next += 1;
            }
            for (const p of pieces) {
                if (p.done) continue;
                const left = 1 - (t - p.born) / LIFE;
                p.el.querySelector('i').style.setProperty('--left', String(Math.max(0, left)));
                if (left <= 0 && !(drag && drag.p === p)) { // spoiled
                    p.done = true;
                    p.el.classList.add('spoiled');
                    setTimeout(() => p.el.remove(), 400);
                }
            }
        };
    }

    // ------------------------------------------------------------------ pick (grapes)
    const GRAPE = `<svg viewBox="0 0 100 110"><path d="M50 4c-2 8 0 14 6 18" stroke="#6b4a1e" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M56 14c10-8 22-6 28 2-10 6-20 6-28-2z" fill="#5fa83a" stroke="#2f6b1a" stroke-width="2"/>${[[38,30],[56,30],[30,46],[47,46],[64,46],[38,62],[56,62],[47,78],[30,62],[64,62],[47,94]].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="10" fill="#7b3fa0" stroke="#3e1a57" stroke-width="2.4"/><circle cx="${x-3}" cy="${y-3}" r="3" fill="#fff" opacity=".35"/>`).join('')}</svg>`;
    const KEYS = [['KeyW', 'W'], ['KeyA', 'A'], ['KeyS', 'S'], ['KeyD', 'D']];

    function pickGame(seconds) {
        const area = G.el.querySelector('#mg-area');
        area.innerHTML = `<div class="mg-vine"></div><div class="mg-vine b"></div>`;
        const W = area.clientWidth, H = area.clientHeight;
        const N = 16, LIFE = 2.6;
        const times = schedule(N, seconds, 0.6, LIFE + 0.3);
        const bunches = [];
        let next = 0, picked = 0, wrong = 0;
        setTotal(N);
        G.score = () => picked / N - wrong * 0.04;
        const slots = [0.12, 0.3, 0.5, 0.7, 0.88]; // along the vines, so bunches never sit on each other
        const onKey = (e) => {
            if (e.repeat) return;
            const k = KEYS.find(([code]) => code === e.code);
            if (!k) return;
            e.preventDefault();
            const hit = bunches.filter((b) => !b.done && b.key === k[1]).sort((a, b) => a.born - b.born)[0];
            if (hit) {
                hit.done = true;
                picked += 1;
                setDone(picked);
                hit.el.classList.add('got');
                setTimeout(() => hit.el.remove(), 400);
            } else {
                wrong += 1;
                area.classList.remove('miss'); void area.offsetWidth; area.classList.add('miss');
            }
        };
        window.addEventListener('keydown', onKey);
        G.cleanup = () => window.removeEventListener('keydown', onKey);
        G.step = (t) => {
            while (next < N && t >= times[next]) {
                const busy = new Set(bunches.filter((b) => !b.done).map((b) => b.slot));
                const free = slots.map((_, i) => i).filter((i) => !busy.has(i));
                const slot = free[Math.floor(Math.random() * free.length)] ?? 0;
                const row = Math.random() < 0.5 ? 0 : 1;
                const key = KEYS[Math.floor(Math.random() * KEYS.length)][1];
                const el = document.createElement('div');
                el.className = 'mg-bunch';
                el.innerHTML = `${GRAPE}<b>${key}</b><i></i>`;
                el.style.left = `${slots[slot] * W - 50}px`;
                el.style.top = `${(row ? 0.56 : 0.14) * H}px`;
                area.appendChild(el);
                bunches.push({ el, key, slot: slot + row * 10, born: t, done: false });
                next += 1;
            }
            for (const b of bunches) {
                if (b.done) continue;
                const left = 1 - (t - b.born) / LIFE;
                b.el.querySelector('i').style.setProperty('--left', String(Math.max(0, left)));
                if (left <= 0) { // it fell
                    b.done = true;
                    b.el.classList.add('fell');
                    setTimeout(() => b.el.remove(), 450);
                }
            }
        };
    }

    // ------------------------------------------------------------------ dry (hold the heat in the band)
    function dryGame(seconds) {
        const area = G.el.querySelector('#mg-area');
        area.innerHTML = `
            <div class="mg-rack">${'<span></span>'.repeat(18)}</div>
            <div class="mg-gauge"><div class="mg-band" id="mg-band"></div><div class="mg-needle" id="mg-needle"></div><small>حرارة</small></div>
            <div class="mg-sun" id="mg-sun"></div>
            <button class="mg-cut mg-heat" id="mg-heat">سخّن (اضغط مع الاستمرار على مسافة)</button>`;
        const band = area.querySelector('#mg-band'), needle = area.querySelector('#mg-needle'), sun = area.querySelector('#mg-sun');
        const rack = area.querySelector('.mg-rack');
        const BAND = 0.24; // the height of the gold band (part of the gauge)
        let heat = 0.2, vel = 0, held = false, last = 0, inside = 0, counted = 0;
        setTotal(100);
        G.score = () => (counted > 0 ? inside / counted : 0);
        const down = (e) => { if (e.code === 'Space' || e.type === 'pointerdown') { e.preventDefault && e.preventDefault(); held = true; } };
        const up = (e) => { if (e.code === 'Space' || e.type === 'pointerup') held = false; };
        window.addEventListener('keydown', down);
        window.addEventListener('keyup', up);
        const btn = area.querySelector('#mg-heat');
        btn.addEventListener('pointerdown', down);
        window.addEventListener('pointerup', up);
        G.cleanup = () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up); window.removeEventListener('pointerup', up); };
        // the band wanders: two slow waves, so it can't be learned by heart
        const p1 = Math.random() * 6, p2 = Math.random() * 6;
        const bandAt = (t) => 0.5 + 0.26 * Math.sin(t * 0.42 + p1) + 0.1 * Math.sin(t * 1.13 + p2);
        G.step = (t) => {
            const dt = Math.min(0.05, Math.max(0, t - last));
            last = t;
            vel += (held ? 1.5 : -1.15) * dt;      // the heat rises while held, cools when let go
            vel *= Math.pow(0.18, dt);              // with some weight to it
            heat = Math.max(0, Math.min(1, heat + vel * dt));
            if (heat === 0 || heat === 1) vel = 0;
            const c = bandAt(t), lo = c - BAND / 2, hi = c + BAND / 2;
            band.style.bottom = `${lo * 100}%`;
            band.style.height = `${BAND * 100}%`;
            needle.style.bottom = `${heat * 100}%`;
            const ok = heat >= lo && heat <= hi;
            if (t > 1.0) { counted += dt; if (ok) inside += dt; } // (a second to find it)
            area.classList.toggle('hot', heat > hi);
            area.classList.toggle('cold', heat < lo);
            needle.classList.toggle('ok', ok);
            sun.style.opacity = String(0.25 + heat * 0.75);
            rack.style.setProperty('--dry', String(Math.min(1, t / seconds)));
            setDone(Math.round(G.score() * 100));
        };
    }

    // ------------------------------------------------------------------ sort (good to the carton, bad to the bin)
    const RAISIN = (bad) => `<svg viewBox="0 0 100 100">${[[34,40],[58,36],[46,58],[66,60],[30,64]].map(([x,y],i)=>`<ellipse cx="${x}" cy="${y}" rx="15" ry="11" transform="rotate(${i*37} ${x} ${y})" fill="${bad ? '#6f7a52' : '#b8742a'}" stroke="${bad ? '#3d4429' : '#6b3c0e'}" stroke-width="2.6"/><path d="M${x-8} ${y-2}q8 5 16 0" stroke="${bad ? '#2f3520' : '#7a4512'}" stroke-width="2" fill="none"/>`).join('')}${bad ? '<circle cx="40" cy="44" r="6" fill="#c9d6b0" opacity=".8"/><circle cx="62" cy="62" r="5" fill="#c9d6b0" opacity=".7"/>' : '<ellipse cx="54" cy="32" rx="5" ry="2.5" fill="#fff" opacity=".4"/>'}</svg>`;

    function sortGame(seconds) {
        const area = G.el.querySelector('#mg-area');
        area.innerHTML = `
            <div class="mg-bin good"><b>A</b><span>الكرتونة</span></div>
            <div class="mg-chute"></div>
            <div class="mg-bin bad"><b>D</b><span>سلة التالف</span></div>`;
        const H = area.clientHeight;
        const N = 18, FALL = 2.2; // seconds from the top to the bottom of the chute
        const times = schedule(N, seconds, 0.5, FALL + 0.3);
        const items = [];
        let next = 0, right = 0;
        setTotal(N);
        G.score = () => right / N;
        const flash = (cls) => { const b = area.querySelector(`.mg-bin.${cls}`); b.classList.remove('flash'); void b.offsetWidth; b.classList.add('flash'); };
        const onKey = (e) => {
            if (e.repeat) return;
            const good = e.code === 'KeyA' || e.code === 'ArrowLeft';
            const bad = e.code === 'KeyD' || e.code === 'ArrowRight';
            if (!good && !bad) return;
            e.preventDefault();
            const it = items.filter((i) => !i.done).sort((a, b) => a.born - b.born)[0]; // the lowest one in the chute
            if (!it) return;
            it.done = true;
            const ok = good ? !it.bad : it.bad;
            if (ok) { right += 1; setDone(right); }
            it.el.classList.add(good ? 'to-good' : 'to-bad', ok ? 'ok' : 'no');
            flash(good ? 'good' : 'bad');
            if (!ok) { area.classList.remove('miss'); void area.offsetWidth; area.classList.add('miss'); }
            setTimeout(() => it.el.remove(), 420);
        };
        window.addEventListener('keydown', onKey);
        G.cleanup = () => window.removeEventListener('keydown', onKey);
        G.step = (t) => {
            while (next < N && t >= times[next]) {
                const bad = Math.random() < 0.4;
                const el = document.createElement('div');
                el.className = 'mg-raisin';
                el.innerHTML = RAISIN(bad);
                area.appendChild(el);
                items.push({ el, bad, born: t, done: false });
                next += 1;
            }
            for (const it of items) {
                if (it.done) continue;
                const k = (t - it.born) / FALL;
                it.el.style.top = `${-70 + k * (H + 40)}px`;
                if (k >= 1) { // it fell off the end: lost
                    it.done = true;
                    it.el.classList.add('fell');
                    setTimeout(() => it.el.remove(), 300);
                }
            }
        };
    }

    function start(kind, count, seconds) {
        if (G) return;
        if (!TEXT[kind]) kind = 'pack';
        const el = frame(kind, count);
        G = { el, seconds: Math.max(25, Number(seconds) || 28), start: performance.now(), over: false, score: () => 0, step: () => {} };
        if (kind === 'catch') catchGame(G.seconds);
        else if (kind === 'slaughter') slaughterGame(G.seconds);
        else if (kind === 'pick') pickGame(G.seconds);
        else if (kind === 'dry') dryGame(G.seconds);
        else if (kind === 'sort') sortGame(G.seconds);
        else packGame(G.seconds);
        G.start = performance.now();
        G.raf = requestAnimationFrame(tick);
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'game') start(m.game, m.count || 0, m.seconds);
    });
    window.EXJ_GAME = { start }; // (for testing outside the game)
})();
