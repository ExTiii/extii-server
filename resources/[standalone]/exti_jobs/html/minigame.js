/* =====================================================================
   EX_Tii jobs: the mini games of the level jobs (Moe's design).
   { action: 'game', game: 'catch' | 'slaughter' | 'pack', count, seconds }
   Every game lasts the whole `seconds` (at least 25), then sends { score: 0..1 } to 'gameDone'.
     catch     — chickens run around the pen: click them before they get out
     slaughter — chickens ride the line: press SPACE / E (or click) when one is in the gold zone
     pack      — pieces drop on the table: drag each one into the tray before it spoils
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
                <div class="mg-foot">تتعامل مع <b>${count}</b> دجاجة · نتيجتك تحدد كم تنجو منها</div>
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

    function start(kind, count, seconds) {
        if (G) return;
        const el = frame(kind, count);
        G = { el, seconds: Math.max(25, Number(seconds) || 28), start: performance.now(), over: false, score: () => 0, step: () => {} };
        if (kind === 'catch') catchGame(G.seconds);
        else if (kind === 'slaughter') slaughterGame(G.seconds);
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
