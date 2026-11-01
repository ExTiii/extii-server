// =====================================================================
// Duty terminal: drag your employee card onto the sensor to clock in / out
// =====================================================================
const Duty = (() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => {
        if (!RES) return Promise.resolve(Duty.fake ? Duty.fake(name, data) : null);
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
            .then((r) => r.json()).catch(() => null);
    };

    const ART = {
        star: `<svg viewBox="0 0 100 100"><g fill="#7eaed9"><rect x="38" y="4" width="24" height="92" rx="3"/><rect x="38" y="4" width="24" height="92" rx="3" transform="rotate(60 50 50)"/><rect x="38" y="4" width="24" height="92" rx="3" transform="rotate(120 50 50)"/></g><rect x="48" y="20" width="4" height="62" rx="2" fill="#fff"/><path d="M50 26c7 3 7 8 0 11s-7 8 0 11 7 8 0 11-7 8 0 11" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/><circle cx="50" cy="23" r="3.4" fill="#fff"/></svg>`,
        medic: `<svg viewBox="0 0 104 128"><path d="M8 128c2-30 18-44 44-44s42 14 44 44z" fill="#6c9fd0"/><path d="M40 86l12 16 12-16" fill="#4f84b8"/><path d="M33 92c-6 10-4 22 8 24" fill="none" stroke="#2c3742" stroke-width="3" stroke-linecap="round"/><path d="M71 92c6 10 4 22-8 24" fill="none" stroke="#2c3742" stroke-width="3" stroke-linecap="round"/><circle cx="41" cy="117" r="4" fill="#9aa7b3" stroke="#2c3742" stroke-width="2"/><rect x="44" y="66" width="16" height="18" rx="6" fill="#e2ad8c"/><ellipse cx="52" cy="52" rx="19" ry="22" fill="#eebd9d"/><path d="M32 46c0-16 9-24 20-24s20 8 20 24c-6-6-14-9-20-9s-14 3-20 9z" fill="#5fae8f"/><circle cx="45" cy="54" r="1.8" fill="#2c3742"/><circle cx="59" cy="54" r="1.8" fill="#2c3742"/><path d="M46 63c4 3 8 3 12 0" fill="none" stroke="#b9775a" stroke-width="2" stroke-linecap="round"/></svg>`,
        amb: `<svg viewBox="0 0 112 56"><path d="M4 14h62v32H4z" fill="#fff" stroke="#9fb0bf" stroke-width="1.5"/><path d="M66 22h22l14 12v12H66z" fill="#fff" stroke="#9fb0bf" stroke-width="1.5"/><path d="M70 25h16l9 8H70z" fill="#a9cbe6"/><rect x="4" y="34" width="98" height="5" fill="#d9363e"/><g transform="translate(26 16) scale(.16)" fill="#3c7fc4"><rect x="38" y="4" width="24" height="92" rx="3"/><rect x="38" y="4" width="24" height="92" rx="3" transform="rotate(60 50 50)"/><rect x="38" y="4" width="24" height="92" rx="3" transform="rotate(120 50 50)"/></g><rect x="40" y="9" width="12" height="5" rx="1" fill="#d9363e"/><circle cx="22" cy="47" r="7" fill="#2b3640"/><circle cx="22" cy="47" r="3" fill="#c5ced6"/><circle cx="84" cy="47" r="7" fill="#2b3640"/><circle cx="84" cy="47" r="3" fill="#c5ced6"/></svg>`,
        city: `<svg viewBox="0 0 312 70" preserveAspectRatio="none"><path d="M0 70V40h14V22h16v18h10V30h18v-14h14v24h12V8h20v32h10V26h16v14h12V18h14v22h10V34h18V12h16v28h12V28h14v12h10V20h16v20h14V36h12v34z" fill="#7d9bb8"/></svg>`,
        sensor: `<svg viewBox="0 0 118 90"><g transform="rotate(-14 46 46)" fill="none" stroke="#d8d8d6" stroke-width="3.2" stroke-linejoin="round"><rect x="12" y="26" width="64" height="42" rx="6"/><path d="M22 54h20"/></g><g fill="none" stroke="#d8d8d6" stroke-width="3.2" stroke-linecap="round"><path d="M88 34c5 6 5 16 0 22"/><path d="M97 27c9 10 9 26 0 36"/></g></svg>`,
    };

    let root, card, pad, lcd, led, backTimer, data = {}, busy = false, open = false;

    function el(html) { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstChild; }
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    function clock(t) {
        if (!t) return '';
        const h = t.h % 12 === 0 ? 12 : t.h % 12;
        return `<bdi>${String(h).padStart(2, '0')}:${String(t.m).padStart(2, '0')}</bdi> ${t.h < 12 ? 'ص' : 'م'}`;
    }
    function dur(min) {
        min = Math.max(0, Math.round(min || 0));
        const h = Math.floor(min / 60), m = min % 60;
        return h > 0 ? `${h}س ${String(m).padStart(2, '0')}د` : `${m}د`;
    }

    function build() {
        root = document.getElementById('duty');
        root.innerHTML = '';
        root.append(el('<div class="dt-shade"></div>'));
        const dev = el(`<div class="dt-device">
            <div class="dt-bezel"><div class="dt-lcd"></div></div>
            <div class="dt-pad"><span class="dt-led"></span>${ART.sensor}<span class="dt-brand">PILLBOX · EMS</span></div>
        </div>`);
        root.append(dev);
        card = el(`<div class="dt-card"><span class="stripe"></span><div class="city">${ART.city}</div><div class="star">${ART.star}</div>
            <div class="amb">${ART.amb}</div><div class="medic">${ART.medic}</div><div class="info"></div></div>`);
        root.append(card);
        root.append(el('<div class="dt-hint"><span><kbd>اسحب</kbd>البطاقة إلى الحساس</span><span><kbd>Esc</kbd>إغلاق</span></div>'));
        pad = root.querySelector('.dt-pad');
        lcd = root.querySelector('.dt-lcd');
        led = root.querySelector('.dt-led');
        card.addEventListener('pointerdown', grab);
    }

    function show(kind, d = {}) {
        clearTimeout(backTimer);
        lcd.classList.toggle('bad', kind === 'bad');
        const time = `<div class="dt-time">الوقت الحالي: <span>${clock(data.time)}</span></div>`;
        if (kind === 'wait') {
            lcd.innerHTML = `<div class="dt-l1">بانتظار البطاقة</div><div class="dt-l2">اسحب بطاقة الموظف إلى الحساس لبدء مناوبتك أو إنهائها.</div>${time}`;
        } else if (kind === 'read') {
            lcd.innerHTML = `<div class="dt-l1"><span class="dt-dots">جارٍ قراءة البطاقة</span></div><div class="dt-l2">لا تحرّك البطاقة.</div>${time}`;
        } else if (kind === 'in') {
            lcd.innerHTML = `<div class="dt-l1">بدأت المناوبة. أهلًا، ${esc(data.name)}.</div><div class="dt-l2">تم تسجيل الدخول بنجاح. البس زيّك من غرفة الملابس.</div>
                <div class="dt-row">ساعاتك هذا الأسبوع<b>${esc(dur(d.week))}</b></div>${time}`;
        } else if (kind === 'out') {
            lcd.innerHTML = `<div class="dt-l1">انتهت المناوبة. في أمان الله، ${esc(data.name)}.</div><div class="dt-l2">تم تسجيل الخروج بنجاح.</div>
                <div class="dt-row">مدة المناوبة<b>${esc(dur(d.minutes))}</b></div>${time}`;
        } else {
            lcd.innerHTML = `<div class="dt-l1">البطاقة مرفوضة</div><div class="dt-l2">${esc(d.text || 'حاول مرة أخرى.')}</div>${time}`;
        }
        if (kind !== 'wait' && kind !== 'read') backTimer = setTimeout(() => { if (open && !busy) { show('wait'); led.className = 'dt-led'; } }, 9000);
    }

    function fillCard() {
        card.querySelector('.info').innerHTML = `<i>الاسم</i><b>${esc(data.name)}</b><i>الرتبة</i><b>${esc(data.rank)}</b><i>المركز</i><b>${esc(data.station)}</b>`;
    }

    // where the card rests: left of the terminal, lined up with the sensor
    function home() {
        const d = root.querySelector('.dt-device').getBoundingClientRect();
        return { x: d.left - card.offsetWidth - 90, y: d.top + d.height * 0.5 - card.offsetHeight * 0.35 };
    }
    function place(p) { card.style.left = `${p.x}px`; card.style.top = `${p.y}px`; }

    let drag = null;
    function overPad() {
        const a = card.getBoundingClientRect(), b = pad.getBoundingClientRect();
        const cx = a.left + a.width / 2, cy = a.top + a.height / 2;
        return cx > b.left - 40 && cx < b.right + 40 && cy > b.top - 30 && cy < b.bottom + 30;
    }
    function grab(e) {
        if (busy || e.button !== 0) return;
        const r = card.getBoundingClientRect();
        drag = { dx: e.clientX - r.left, dy: e.clientY - r.top };
        card.classList.remove('back');
        card.classList.add('drag');
        card.setPointerCapture(e.pointerId);
        card.addEventListener('pointermove', move);
        card.addEventListener('pointerup', drop, { once: true });
        card.addEventListener('pointercancel', drop, { once: true });
    }
    function move(e) {
        if (!drag) return;
        place({ x: e.clientX - drag.dx, y: e.clientY - drag.dy });
        pad.classList.toggle('hot', overPad());
    }
    function drop() {
        card.removeEventListener('pointermove', move);
        const hit = overPad();
        drag = null;
        card.classList.remove('drag');
        pad.classList.remove('hot');
        if (hit) swipe();
        else goHome();
    }
    function goHome() { card.classList.add('back'); place(home()); }

    let audio;
    function beep(ok) {
        try {
            audio = audio || new (window.AudioContext || window.webkitAudioContext)();
            const o = audio.createOscillator(), g = audio.createGain();
            o.type = 'square'; o.frequency.value = ok ? 1760 : 330;
            g.gain.setValueAtTime(0.05, audio.currentTime);
            g.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + (ok ? 0.12 : 0.3));
            o.connect(g).connect(audio.destination); o.start(); o.stop(audio.currentTime + 0.32);
        } catch (_) { /* no sound */ }
    }

    async function swipe() {
        busy = true;
        led.className = 'dt-led read';
        show('read');
        const started = Date.now();
        const res = await post('dutySwipe', {});
        const wait = 750 - (Date.now() - started);
        if (wait > 0) await new Promise((r) => setTimeout(r, wait));
        if (!open) { busy = false; return; }
        if (res && res.time) data.time = res.time;
        if (res && res.ok) {
            led.className = 'dt-led on';
            beep(true);
            show(res.on ? 'in' : 'out', res);
        } else {
            led.className = 'dt-led err';
            beep(false);
            show('bad', { text: (res && res.text) || 'حاول مرة أخرى.' });
        }
        goHome();
        setTimeout(() => { busy = false; }, 600);
    }

    function openUI(d) {
        if (!root) build();
        data = d || {};
        open = true;
        busy = false;
        root.classList.remove('hidden');
        led.className = 'dt-led';
        fillCard();
        show('wait');
        requestAnimationFrame(() => { card.classList.remove('back', 'drag'); place(home()); });
    }
    function closeUI(tell) {
        if (!open) return;
        open = false;
        clearTimeout(backTimer);
        root.classList.add('hidden');
        if (tell) post('dutyClose', {});
    }

    window.addEventListener('keydown', (e) => {
        if (!open) return;
        if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); closeUI(true); }
    });
    window.addEventListener('resize', () => { if (open && !drag) place(home()); });
    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || m.action !== 'duty') return;
        if (m.open) openUI(m.data);
        else if (m.time && open) { data.time = m.time; const t = lcd.querySelector('.dt-time span'); if (t) t.innerHTML = clock(data.time); }
        else closeUI(false);
    });

    return { open: openUI, close: closeUI, show, fake: null, _state: () => ({ open, busy }) };
})();
