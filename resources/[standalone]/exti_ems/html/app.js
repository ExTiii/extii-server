// EX_Tii EMS — the medics' rugged tablet.
// One page, two copies: the real one on your screen, and a "mirror" copy (?mirror=1) that the
// game paints on the tablet in your character's hands. Everything on the screen comes from
// one state object, so the mirror always shows exactly the same thing.
(() => {
    const params = new URLSearchParams(location.search);
    const MIRROR = params.get('mirror') === '1';
    const inGame = typeof GetParentResourceName === 'function';
    const resource = inGame ? GetParentResourceName() : 'exti_ems';
    const $ = (id) => document.getElementById(id);
    const root = $('root');
    const os = $('os');
    const device = $('device');

    if (MIRROR) {
        document.body.classList.add('mirror');
        document.body.appendChild(os);
        root.remove();
    }

    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.max(0, Math.floor(n || 0)).toLocaleString('en-US');
    const list = (x) => (Array.isArray(x) ? x : Object.values(x || {}));
    const obj = (x) => (x && !Array.isArray(x) && typeof x === 'object' ? x : {});

    // ------------------------------------------------------------------
    // state (everything the screen shows)
    // ------------------------------------------------------------------
    const S = {
        data: null,       // tablet data (me, calls, team, ranks, pay)
        tab: 'calls',
        clock: '',
        exam: null,       // the exam of the current patient (from the server)
        examAt: 0,        // when it arrived (to run the timer)
        wait: null,       // 'waiting for the patient' text
        view: 'front',    // body seen from the front / back
        listen: false,    // stethoscope: choosing where to listen
        busy: null,       // a running step { label, secs, at, zone }
        bp: null,         // the cuff game { phase, sys, dia, msg, warn, none }
        sheet: null,      // a yes/no question
        toast: null,
        hover: null,
    };

    function post(name, body) {
        if (!inGame) return Promise.resolve(preview(name, body));
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false }));
    }

    const ERR = {
        too_far: 'اقترب أكثر من المريض',
        off_duty: 'ابدأ مناوبتك في المستشفى أولًا',
        no_patient: 'لا يوجد مريض قريب منك',
        declined: 'المريض رفض الفحص',
        ask_later: 'المريض رفض قبل قليل: انتظر قليلًا ثم اطلب مرة أخرى',
        busy: 'انتظر حتى تنتهي الخطوة الحالية',
        not_open: 'افتح الفحص من جديد',
        failed: 'حدث خطأ، حاول مرة أخرى',
    };
    const errText = (code) => ERR[code] || (typeof code === 'string' && code.length > 12 ? code : ERR.failed);

    // ------------------------------------------------------------------
    // icons
    // ------------------------------------------------------------------
    const svg = (d, s = 16, w = 2) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
    const I = {
        bell: svg('<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15Z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>'),
        team: svg('<circle cx="9" cy="8" r="3.2"/><path d="M3 19.5a6 6 0 0 1 12 0"/><circle cx="17" cy="9" r="2.6"/><path d="M16 14.2a5 5 0 0 1 5.5 5.3"/>'),
        me: svg('<rect x="4" y="3.5" width="16" height="17" rx="3"/><circle cx="12" cy="10" r="2.8"/><path d="M7.5 17a4.8 4.8 0 0 1 9 0"/>'),
        boss: svg('<path d="M3 8l4.5 4L12 5l4.5 7L21 8l-2 10H5Z"/>'),
        steth: svg('<path d="M4.8 2.3A.3.3 0 1 0 5 2H4a2 2 0 0 0-2 2v5a6 6 0 0 0 6 6v0a6 6 0 0 0 6-6V4a2 2 0 0 0-2-2h-1a.2.2 0 1 0 .3.3"/><path d="M8 15v1a6 6 0 0 0 6 6v0a6 6 0 0 0 6-6v-4"/><circle cx="20" cy="10" r="2"/>'),
        star: svg('<path d="M10 3.5h4v4.6l4-2.3 2 3.5-4 2.3 4 2.2-2 3.5-4-2.3v4.5h-4v-4.5l-4 2.3-2-3.5 4-2.2-4-2.3 2-3.5 4 2.3Z"/>', 21, 1.9),
        x: svg('<path d="M6 6l12 12M18 6L6 18"/>', 15, 2.3),
        down: svg('<circle cx="17.5" cy="7" r="2.2"/><path d="M3 18.5h18M5 15l5-2.5 4 1.5 3.5-2"/><path d="M12 4v2.5M10.8 5.2h2.4"/>', 24, 1.9),
        reception: svg('<path d="M9 3.5h6v5.5h5.5v6H15v5.5H9V15H3.5V9H9Z"/>', 24, 1.9),
        phone: svg('<path d="M5 3.5h3.5l1.5 4.5-2.2 1.5a11 11 0 0 0 6.7 6.7L16 14l4.5 1.5V19a1.5 1.5 0 0 1-1.6 1.5A16 16 0 0 1 3.5 5.1 1.5 1.5 0 0 1 5 3.5Z"/>', 24, 1.9),
        pin: svg('<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21Z"/><circle cx="12" cy="9.5" r="2.4"/>', 13, 2.2),
        clock: svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', 13, 2.2),
        route: svg('<circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h6.5a3.5 3.5 0 0 0 0-7h-5a3.5 3.5 0 0 1 0-7H16"/>', 13, 2.2),
        quiet: svg('<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15Z"/><path d="M10 20.5a2 2 0 0 0 4 0"/><path d="M3 3l18 18"/>', 32, 1.7),
        hospital: svg('<path d="M4 20.5V8l8-4.5L20 8v12.5"/><path d="M10 20.5v-4h4v4"/><path d="M12 8v4M10 10h4"/>', 32, 1.7),
        pulse: svg('<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7Z"/>', 17),
        gauge: svg('<circle cx="12" cy="13" r="8"/><path d="M12 13l3-3M12 5V3"/>', 17),
        oxi: svg('<rect x="6" y="3" width="12" height="18" rx="5"/><path d="M10 8h4"/>', 17),
        thermo: svg('<path d="M14 4v10.5a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z"/>', 17),
        stethS: svg('<path d="M6 3v6a6 6 0 0 0 12 0V3"/><path d="M12 15v2a4 4 0 0 0 8 0v-3"/><circle cx="20" cy="12" r="2"/>', 17),
        eye: svg('<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>', 17),
        bullet: svg('<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8" stroke-dasharray="3 3"/>', 16),
        bone: svg('<path d="m4 20 7-7M13 11l7-7M9 9l6 6"/>', 16),
        cut: svg('<path d="M5 19 19 5"/>', 16),
        flame: svg('<path d="M12 21c4 0 6.5-2.6 6.5-6.2 0-3.6-3-5.8-4-9.3-2.6 1.8-4 4.4-3.8 6.6-1.3-.8-2-2.2-2.2-3.4C6.6 10.4 5.5 12.5 5.5 14.8 5.5 18.4 8 21 12 21Z"/>', 16),
        bruise: svg('<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="3"/>', 16),
        lungs: svg('<path d="M12 4v8M12 12c-2 0-3-1.5-5-1.5S3 13 3 17c0 2 1 3 2.5 3S9 18.5 9 16v-5M12 12c2 0 3-1.5 5-1.5s4 2.5 4 6.5c0 2-1 3-2.5 3S15 18.5 15 16v-5"/>', 16),
        check: svg('<path d="M5 12l5 5L20 7"/>', 16, 2.4),
        file: svg('<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M8 13h8M8 17h5"/>', 15),
        plus: svg('<path d="M12 5v14M5 12h14"/>', 15, 2.4),
        ask: svg('<path d="M21 12a8.5 8.5 0 0 1-12.4 7.6L3 21l1.4-5.4A8.5 8.5 0 1 1 21 12Z"/>', 15),
    };
    const KIND_ICON = { gunshot: I.bullet, pellets: I.bullet, shrapnel: I.bullet, fracture: I.bone, laceration: I.cut, stab: I.cut, wire: I.cut, bite: I.cut, burn: I.flame, bruise: I.bruise, smoke: I.lungs, drown: I.lungs };

    // ------------------------------------------------------------------
    // shared pieces
    // ------------------------------------------------------------------
    function initials(name) {
        const parts = String(name || '').trim().split(/\s+/);
        return (parts[0] || '?').charAt(0) + (parts[1] ? parts[1].charAt(0) : '');
    }
    function ago(seconds) {
        if (seconds < 60) return 'الآن';
        const m = Math.floor(seconds / 60);
        if (m < 60) return `قبل ${m} د`;
        return `قبل ${Math.floor(m / 60)} س`;
    }

    function statusBar() {
        return `<div class="status"><span>EX_Tii · إسعاف</span><span class="mid" id="clock">${esc(S.clock)}</span><span class="icons">
            <svg width="16" height="12" viewBox="0 0 24 18" fill="currentColor"><rect x="0" y="12" width="4" height="6" rx="1"/><rect x="6" y="8" width="4" height="10" rx="1"/><rect x="12" y="4" width="4" height="14" rx="1"/><rect x="18" y="0" width="4" height="18" rx="1"/></svg>
            <svg width="16" height="12" viewBox="0 0 24 18" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M2 6a15 15 0 0 1 20 0M5.5 10a10 10 0 0 1 13 0M9 14a5 5 0 0 1 6 0"/></svg>
            <span>82%</span><span class="batt"></span></span></div>`;
    }

    function header() {
        const me = S.data.me;
        const tabs = [['calls', I.bell, 'البلاغات', S.data.calls.length], ['team', I.team, 'الفريق'], ['me', I.me, 'ملفي']];
        if (me.isBoss) tabs.push(['boss', I.boss, 'الإدارة']);
        tabs.push(['exam', I.steth.replace(/width="16" height="16"/, 'width="15" height="15"'), 'فحص المريض']);
        const exam = S.tab === 'exam';
        return `<div class="apphead">
            <div class="brand">
                <div class="brand-icon">${exam ? I.steth.replace(/width="16" height="16"/, 'width="21" height="21"') : I.star}</div>
                <div><h1>${exam ? 'فحص المريض' : 'إسعاف EX_Tii'}</h1><p>${esc(me.name)} · ${esc(me.gradeLabel)}</p></div>
            </div>
            <div class="tabs">${tabs.map(([key, icon, label, count]) => `<span class="tab ${S.tab === key ? 'on' : ''}" data-tab="${key}">${icon} ${label}${count ? ` <i class="badge">${count}</i>` : ''}</span>`).join('')}</div>
            <div class="head-left">
                ${exam && S.exam ? `<span class="pill">مدة الفحص <b id="examTimer">00:00</b></span>` : ''}
                <span class="pill ${me.onDuty ? 'duty-on' : ''}">${me.onDuty ? 'في الخدمة' : 'خارج الخدمة'}</span>
                <span class="icon-btn" data-close title="إغلاق (Esc)">${I.x}</span>
            </div>
        </div>`;
    }

    // ------------------------------------------------------------------
    // calls / team / me / boss
    // ------------------------------------------------------------------
    function callsView() {
        const d = S.data;
        if (!d.me.onDuty) {
            return `<div class="empty"><div class="empty-icon">${I.hospital}</div><h3>أنت خارج الخدمة</h3>
                <p>ابدأ مناوبتك من غرفة الطاقم في أحد المستشفيين، لتلبس زي الإسعاف وتبدأ البلاغات تصلك هنا.</p>
                <div class="row"><button class="kit-btn primary" data-hgps="pillbox">مستشفى بيلبوكس</button><button class="kit-btn" data-hgps="paleto">مركز باليتو الطبي</button></div></div>`;
        }
        if (!d.calls.length) {
            return `<div class="empty"><div class="empty-icon">${I.quiet}</div><h3>لا توجد بلاغات الآن</h3>
                <p>عندما يسقط شخص مصابًا، أو يطلب أحد مسعفًا من الاستقبال أو من هاتفه، يظهر البلاغ هنا مباشرة.</p></div>`;
        }
        return `<div class="calls">${d.calls.map((c) => `
            <div class="call ${c.mine ? 'mine' : ''}">
                <div class="call-icon ${esc(c.kind)}">${I[c.kind] || I.bell}</div>
                <div>
                    <div class="call-title">${esc(c.label)} ${c.patientName ? `<small>${esc(c.patientName)}</small>` : ''}</div>
                    ${c.text ? `<div class="call-text">${esc(c.text)}</div>` : ''}
                    <div class="call-meta">
                        <span>${I.pin} ${esc(c.street || '-')}</span>
                        <span>${I.route} ${c.distance != null ? `<b>${(c.distance / 1000).toFixed(c.distance < 1000 ? 2 : 1)}</b> كم` : '-'}</span>
                        <span>${I.clock} ${ago(c.ago)}</span>
                        ${c.takenBy ? `<span class="call-taken">${c.mine ? 'استلمته أنت' : `استلمه ${esc(c.takenBy)}${c.helping ? ' · أنت تساعده' : ''}`}</span>` : ''}
                    </div>
                </div>
                <div class="call-actions">${c.mine
                    ? `<button class="kit-btn primary" data-go="${c.id}">الطريق</button><button class="kit-btn" data-done="${c.id}">تم</button>`
                    : c.helping
                        ? `<button class="kit-btn primary" data-go="${c.id}">الطريق</button>`
                        : `<button class="kit-btn primary" data-take="${c.id}">${c.takenBy ? 'ساعد' : 'استلم البلاغ'}</button>`}</div>
            </div>`).join('')}</div>`;
    }

    function teamView() {
        const on = S.data.team.filter((m) => m.onDuty);
        if (!on.length) return `<div class="empty"><div class="empty-icon">${I.team.replace(/16/g, '32')}</div><h3>لا أحد في الخدمة الآن</h3><p>المسعفون الذين يبدؤون مناوبتهم يظهرون هنا.</p></div>`;
        return `<div class="section-title"><h3>في الخدمة الآن</h3><span>${on.length} مسعف</span></div>
            <div class="people">${on.map((m) => `<div class="person"><div class="avatar">${esc(initials(m.name))}</div>
                <div class="person-main"><b>${esc(m.name)}${m.me ? '<span class="me-tag">أنت</span>' : ''}</b><span>${esc(m.gradeLabel)}</span></div>
                <span class="kit-status ok">في الخدمة</span></div>`).join('')}</div>`;
    }

    function meView() {
        const d = S.data;
        const me = d.me;
        const s = me.stats || {};
        const shift = me.shift;
        const rungs = d.ranks.map((r) => `<div class="rung ${r.grade === me.grade ? 'now' : r.grade < me.grade ? 'done' : ''}"><b>${esc(r.name)}</b><span>${money(r.payment)} / 10 د</span></div>`).join('');
        return `<div class="me-grid">
            <div class="rank-card"><small>رتبتك</small><h2>${esc(me.gradeLabel)}</h2><p>الترقية يمنحها قائد الإسعاف. كل رتبة براتب أعلى.</p><div class="ladder">${rungs}</div></div>
            <div>
                <div class="stats">
                    <div class="stat"><span>إنعاش</span><b>${s.revives || 0}</b><small>كل الوقت</small></div>
                    <div class="stat"><span>علاج</span><b>${s.treats || 0}</b><small>كل الوقت</small></div>
                    <div class="stat"><span>أرباح المرضى</span><b class="gold">${money(s.earned)}</b><small>كل الوقت</small></div>
                    <div class="stat"><span>هذه المناوبة</span><b class="gold">${money(shift ? shift.earned : 0)}</b><small>${shift ? `${shift.revives || 0} إنعاش · ${shift.treats || 0} علاج` : 'لم تبدأ مناوبة'}</small></div>
                </div>
                <div class="rules">
                    <div class="rule"><i>1</i><span>إنعاش شخص على الأرض: ${money(d.pay.revive)}. اضغط E بجانبه ثم «علاج المريض» واتبع الخطوات حتى يقوم.</span></div>
                    <div class="rule"><i>2</i><span>علاج مصاب صحته أقل من ${d.treatBelow}%: ${money(d.pay.treat)}. أوقف النزيف وضمّد الجروح من خطة العلاج.</span></div>
                    <div class="rule"><i>3</i><span>المريض نفسه يُحتسب مرة كل ${d.payCooldown} دقائق. المستلزمات مجانية من الخزانة.</span></div>
                </div>
                <div class="quit"><button class="kit-btn danger small" data-quit>اترك العمل في الإسعاف</button></div>
            </div></div>`;
    }

    // job applications (filled at the hospital reception)
    function appsView() {
        const apps = Array.isArray(S.data.applications) ? S.data.applications : Object.values(S.data.applications || {});
        if (!apps.length) return `<div class="section-title"><h3>طلبات التوظيف</h3><span>لا توجد طلبات جديدة · تُقدَّم من استقبال المستشفى</span></div>`;
        const now = S.data.now || Math.floor(Date.now() / 1000);
        return `<div class="section-title"><h3>طلبات التوظيف</h3><span>${apps.length} طلب</span></div>
            <div class="apps">${apps.map((a) => {
                const ans = a.answers || {};
                return `<div class="app-card">
                    <div class="app-head"><div class="avatar">${esc(initials(a.name))}</div>
                        <div class="person-main"><b>${esc(a.name)}</b><span class="kit-status ${a.online ? 'info' : ''}">${a.online ? 'متصل' : 'غير متصل'}</span> <small>${esc(ago(now - a.created))}${a.phone ? ` · ${esc(a.phone)}` : ''}</small></div></div>
                    ${ans.why ? `<p><b>لماذا الإسعاف:</b> ${esc(ans.why)}</p>` : ''}
                    ${ans.experience ? `<p><b>الخبرة:</b> ${esc(ans.experience)}</p>` : ''}
                    ${ans.hours ? `<p><b>الأوقات:</b> ${esc(ans.hours)}</p>` : ''}
                    ${a.free ? '' : `<p class="app-warn">يعمل الآن في وظيفة فريق أخرى، يجب أن يتركها قبل التوظيف</p>`}
                    <div class="app-acts">
                        <button class="kit-btn small" data-apphire="${a.id}" data-name="${esc(a.name)}" ${a.free ? '' : 'disabled'}>توظيف كمستجد</button>
                        <button class="kit-btn danger small" data-appno="${a.id}" data-name="${esc(a.name)}">رفض</button>
                    </div></div>`;
            }).join('')}</div>`;
    }

    function bossView() {
        const d = S.data;
        const myGrade = d.me.grade;
        return appsView() + `<div class="section-title"><h3>طاقم الإسعاف</h3><span>${d.team.length} عضو · التوظيف من طلبات التوظيف أعلاه</span></div>
            <div class="staff">${d.team.map((m) => {
                const locked = m.me || m.grade >= myGrade;
                const options = d.ranks.filter((r) => r.grade < myGrade || r.grade === m.grade).map((r) => `<option value="${r.grade}" ${r.grade === m.grade ? 'selected' : ''}>${esc(r.name)}</option>`).join('');
                const status = m.onDuty ? '<span class="kit-status ok">في الخدمة</span>' : m.online ? '<span class="kit-status info">متصل</span>' : '<span class="kit-status">غير متصل</span>';
                return `<div class="staff-row"><div class="avatar">${esc(initials(m.name))}</div>
                    <div class="person-main"><b>${esc(m.name)}${m.me ? '<span class="me-tag">أنت</span>' : ''}</b>${status}</div>
                    <select data-grade="${esc(m.citizenid)}" ${locked ? 'disabled' : ''}>${options}</select>
                    <button class="kit-btn danger small" data-fire="${esc(m.citizenid)}" data-name="${esc(m.name)}" ${locked ? 'disabled' : ''}>إنهاء الخدمة</button></div>`;
            }).join('')}</div>`;
    }

    // ------------------------------------------------------------------
    // the exam
    // ------------------------------------------------------------------
    const ZONES_FRONT = {
        head: 'ellipse:120,46,29,35',
        neck: 'M107 79 L133 79 L136 104 L104 104 Z',
        chest: 'M72 110 C92 101 148 101 168 110 L165 186 L75 186 Z',
        abdomen: 'M75 189 L165 189 L170 252 C150 262 90 262 70 252 Z',
        r_arm: 'M69 111 C55 115 49 128 47 148 L41 214 L34 296 C30 306 30 318 38 324 C46 328 52 318 50 304 L58 228 L68 168 Z',
        l_arm: 'M171 111 C185 115 191 128 193 148 L199 214 L206 296 C210 306 210 318 202 324 C194 328 188 318 190 304 L182 228 L172 168 Z',
        r_leg: 'M71 255 C88 264 104 266 117 264 L114 380 L110 480 C112 492 114 500 104 503 L80 503 C74 499 78 492 84 482 L80 380 C74 336 70 296 71 255 Z',
        l_leg: 'M169 255 C152 264 136 266 123 264 L126 380 L130 480 C128 492 126 500 136 503 L160 503 C166 499 162 492 156 482 L160 380 C166 336 170 296 169 255 Z',
    };
    // from behind, the patient's right side is on your right
    const ZONES_BACK = {
        head: ZONES_FRONT.head,
        neck: ZONES_FRONT.neck,
        back: 'M72 110 C92 101 148 101 168 110 L170 252 C150 262 90 262 70 252 Z',
        r_arm: ZONES_FRONT.l_arm,
        l_arm: ZONES_FRONT.r_arm,
        r_leg: ZONES_FRONT.l_leg,
        l_leg: ZONES_FRONT.r_leg,
    };
    const ANCHOR_FRONT = { head: [120, 46], neck: [120, 92], chest: [120, 146], abdomen: [120, 222], r_arm: [46, 240], l_arm: [194, 240], r_leg: [95, 380], l_leg: [145, 380] };
    const ANCHOR_BACK = { head: [120, 46], neck: [120, 92], back: [120, 180], r_arm: [194, 240], l_arm: [46, 240], r_leg: [145, 380], l_leg: [95, 380] };
    const ZONE_LABEL = { head: 'الرأس', neck: 'الرقبة', chest: 'الصدر', abdomen: 'البطن', back: 'الظهر', r_arm: 'الذراع اليمنى', l_arm: 'الذراع اليسرى', r_leg: 'الرجل اليمنى', l_leg: 'الرجل اليسرى' };
    const LEVEL_COLOR = ['#3ddc97', '#f6c945', '#f6a94a', '#ff5f5f'];

    function bodySvg() {
        const zones = S.view === 'back' ? ZONES_BACK : ZONES_FRONT;
        const anchors = S.view === 'back' ? ANCHOR_BACK : ANCHOR_FRONT;
        const results = obj(S.exam.zones);
        let shapes = '';
        let marks = '';
        for (const [zone, d] of Object.entries(zones)) {
            const r = results[zone];
            const cls = r ? `z-l${r.level || 0}` : 'z-un';
            const doing = S.busy && S.busy.zone === zone ? ' doing' : '';
            const hover = S.hover === zone ? ' hover' : '';
            const attrs = `class="zone ${cls}${doing}${hover}" data-zone="${zone}"`;
            if (d.startsWith('ellipse:')) {
                const [cx, cy, rx, ry] = d.slice(8).split(',');
                shapes += `<ellipse ${attrs} cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}"/>`;
            } else {
                shapes += `<path ${attrs} d="${d}"/>`;
            }
            if (r && r.level > 0) {
                const [x, y] = anchors[zone];
                const c = LEVEL_COLOR[r.level];
                marks += `<circle cx="${x}" cy="${y}" r="11" fill="${c}" opacity=".22" pointer-events="none"/><circle cx="${x}" cy="${y}" r="4.5" fill="${c}" pointer-events="none"/>
                    <circle cx="${x}" cy="${y}" r="16" fill="none" stroke="${c}" stroke-width="1" opacity=".5" pointer-events="none"/>`;
            }
        }
        return `<svg class="fig" width="248" height="520" viewBox="0 0 240 520">${shapes}${marks}</svg>`;
    }

    function ecg(width, period) {
        let pts = [];
        for (let x = 0; x < width; x += period) {
            const f = (dx, y) => pts.push(`${(x + dx * period / 100).toFixed(1)},${y}`);
            f(0, 26); f(30, 26); f(36, 22); f(40, 26); f(52, 26); f(56, 4); f(60, 36); f(64, 26); f(80, 26); f(88, 20); f(96, 26);
        }
        return pts.join(' ');
    }
    const flat = '<path d="M0 22 H400" stroke="#1d2a30" stroke-width="2" stroke-dasharray="6 6"/>';

    function vrow(color, wave, value, unit, name, labelText, cls, speed) {
        const measured = value != null;
        return `<div class="vrow">
            <svg viewBox="0 0 300 40" preserveAspectRatio="none">${measured ? `<g class="wave" style="animation-duration:${speed || 2.4}s">${wave}</g>` : flat}</svg>
            <div class="vval ${measured ? color : 'dim'}"><b>${measured ? value : '--'}</b><small>${unit}</small>
                <div class="vlab"><span>${name}</span><em class="${measured ? cls || '' : ''}">${measured ? esc(labelText) : 'لم يُقَس'}</em></div></div>
        </div>`;
    }

    function monitor(v) {
        const hr = v.hr;
        const hrDead = hr && hr.v <= 0;
        const hrWave = hrDead ? '<path d="M0 26 H400" stroke="#ff5f5f" stroke-width="2"/>' : `<polyline fill="none" stroke="#3ddc97" stroke-width="2" points="${ecg(400, 100)}"/>`;
        const hrSpeed = hr && hr.v > 0 ? (60 / hr.v).toFixed(2) : 2.4;
        const pleth = '<path d="M0 30 C10 30 12 10 20 10 C28 10 30 26 37 26 C45 26 46 30 50 30 C60 30 62 10 70 10 C78 10 80 26 87 26 C95 26 96 30 100 30 C110 30 112 10 120 10 C128 10 130 26 137 26 C145 26 146 30 150 30 C160 30 162 10 170 10 C178 10 180 26 187 26 C195 26 196 30 200 30 C210 30 212 10 220 10 C228 10 230 26 237 26 C245 26 246 30 250 30 C260 30 262 10 270 10 C278 10 280 26 287 26 C295 26 296 30 300 30 C310 30 312 10 320 10 C328 10 330 26 337 26 C345 26 346 30 350 30 C360 30 362 10 370 10 C378 10 380 26 387 26 C395 26 396 30 400 30" fill="none" stroke="#46d6ff" stroke-width="1.6" opacity=".75"/>';
        const bpWave = pleth.replace('#46d6ff', '#f2f2f2').replace('.75', '.5');
        const breath = '<path d="M0 20 C25 6 50 6 75 20 C100 34 125 34 150 20 C175 6 200 6 225 20 C250 34 275 34 300 20 C325 6 350 6 375 20 C387 27 395 30 400 30" fill="none" stroke="#f6d34a" stroke-width="1.6" opacity=".7"/>';
        const thermo = '<path d="M0 22 H400" stroke="#f6a94a" stroke-width="1.6" opacity=".5"/>';
        const last = Math.max(...['hr', 'bp', 'spo2', 'resp', 'temp'].map((k) => (v[k] && v[k].at) || 0));
        const lastText = last ? `آخر قياس ${ago(Math.max(0, (S.exam.now || 0) - last))}` : 'لا توجد قياسات بعد';
        return `<div class="monitor">
            <div class="mon-head"><span class="live">جهاز المراقبة</span><span>${lastText}</span></div>
            ${vrow(hrDead ? 'c-r' : 'c-g', hrWave, hr ? hr.v : null, 'bpm', 'النبض', hr && hr.label, hr && hr.cls, hrSpeed)}
            ${vrow('c-c', pleth, v.spo2 ? (v.spo2.v != null ? v.spo2.v : '—') : null, '%', 'الأكسجين', v.spo2 && v.spo2.label, v.spo2 && v.spo2.cls, 1.6)}
            ${vrow('c-w', bpWave, v.bp ? (v.bp.sys > 0 ? `<span style="font-size:21px">${v.bp.sys}/${v.bp.dia}</span>` : '—') : null, 'mmHg', 'الضغط', v.bp && v.bp.label, v.bp && v.bp.cls, 1.6)}
            ${vrow('c-y', breath, v.resp ? v.resp.v : null, '/min', 'التنفس', v.resp && v.resp.label, v.resp && v.resp.cls, 4)}
            ${vrow('c-o', thermo, v.temp ? Number(v.temp.v).toFixed(1) : null, '°C', 'الحرارة', v.temp && v.temp.label, v.temp && v.temp.cls, 6)}
        </div>`;
    }

    function tools(v) {
        const t = obj(S.exam.times);
        const sec = (k, d) => `${t[k] || d} ثوانٍ`;
        const listened = v.heart || v.lungL || v.lungR;
        const tool = (key, icon, name, sub, done) => `<div class="tool ${done ? 'done' : ''} ${S.listen && key === 'listen' ? 'on' : ''}" data-tool="${key}"><div class="ti">${icon}</div><b>${name}</b><small>${sub}</small></div>`;
        return `<div class="tools">
            ${tool('pulse', I.pulse, 'جسّ النبض', sec('pulse', 6), v.hr)}
            ${tool('bp', I.gauge, 'كُم الضغط', 'لعبة قصيرة', v.bp)}
            ${tool('spo2', I.oxi, 'مقياس الأكسجين', sec('spo2', 4), v.spo2)}
            ${tool('temp', I.thermo, 'ميزان الحرارة', sec('temp', 5), v.temp)}
            ${tool('listen', I.stethS, 'السماعة', 'القلب والرئتين', listened)}
            ${tool('pupils', I.eye, 'ضوء العين', sec('pupils', 3), v.pupils)}
        </div>
        ${S.listen ? `<div class="listen"><span data-listen="heart">القلب</span><span data-listen="L">الرئة اليسرى</span><span data-listen="R">الرئة اليمنى</span></div>` : ''}`;
    }

    function notes(v) {
        const rows = [['العين', v.pupils], ['القلب', v.heart], ['الرئة اليسرى', v.lungL], ['الرئة اليمنى', v.lungR]].filter(([, x]) => x);
        if (!rows.length) return '';
        return `<div class="card notes-card"><div class="sec-title">ما سمعته ورأيته</div><div class="notes" data-scroll="notes">${rows.map(([k, x]) => `<div class="note"><b>${k}</b><span class="${x.cls || ''}">${esc(x.text)}</span></div>`).join('')}</div></div>`;
    }

    function findings() {
        const results = obj(S.exam.zones);
        const items = [];
        const clean = [];
        for (const [zone, r] of Object.entries(results)) {
            const its = list(r.items);
            if (!its.length) clean.push(r.label || ZONE_LABEL[zone]);
            its.forEach((it) => items.push(it));
        }
        items.sort((a, b) => (b.level || 0) - (a.level || 0));
        let html = items.map((it) => `<div class="find l${it.level || 1}">
            <div class="ic">${KIND_ICON[it.kind] || I.bruise}</div>
            <div><h4>${esc(it.part)}</h4><p>${esc(it.text)}</p>
                ${it.cause ? `<div class="cause">${esc(it.cause)}</div>` : ''}
                ${list(it.tags).length ? `<div class="tags">${list(it.tags).map((t) => `<span class="tag ${esc(t[1])}">${esc(t[0])}</span>`).join('')}</div>` : ''}
            </div></div>`).join('');
        if (clean.length) html += `<div class="find l0"><div class="ic">${I.check}</div><div><h4>${esc(clean.join('، '))}</h4><p>لا توجد إصابات ظاهرة</p></div></div>`;
        if (!html) html = '<div class="find-empty">اضغط على أي جزء من الجسم لفحصه. ما تجده يظهر هنا.</div>';
        return { html, count: items.length };
    }

    function examView() {
        if (S.wait) {
            return `<div class="exam-empty"><div class="spinner"></div><h3>${esc(S.wait)}</h3><p>المريض واعٍ: لازم يوافق على الفحص أولًا.</p></div>`;
        }
        if (!S.exam) {
            return `<div class="exam-empty"><div class="empty-icon">${I.steth.replace(/width="16" height="16"/, 'width="32" height="32"')}</div>
                <h3>لا يوجد مريض الآن</h3>
                <p>قف بجانب المريض واضغط <kbd>E</kbd> ثم «فحص بالتابلت»، أو اضغط الزر لفحص أقرب شخص منك.</p>
                <button class="kit-btn primary" data-nearest>افحص أقرب شخص</button></div>`;
        }
        const e = S.exam;
        const p = e.patient || {};
        const v = obj(e.vitals);
        const f = findings();
        const said = e.said;
        const pain = said && said.pain != null ? said.pain : null;
        const c = e.counts || {};
        const pct = Math.round(((c.zones || 0) + (c.measures || 0)) / Math.max(1, (c.zonesOf || 9) + (c.measuresOf || 6)) * 100);
        return `<div class="exam">
            <div class="exam-body">
                <div class="col">
                    <div class="card">
                        <div class="sec-title" style="margin-bottom:6px"><span>المريض</span><span class="link" data-endexam>إنهاء الفحص</span></div>
                        <div class="patient"><div class="avatar">${esc(p.initials || '؟')}</div>
                            <div><h2>${esc(p.name)}</h2><p>${esc(p.gender || '')}${p.age ? ` · ${p.age} سنة` : ''}${p.blood ? ` · فصيلة الدم ${esc(p.blood)}` : ''}</p></div></div>
                        <div class="chips">${list(e.chips).map((ch) => `<span class="chip ${esc(ch[1])}">${esc(ch[0])}</span>`).join('')}</div>
                    </div>
                    <div class="card">
                        <div class="sec-title">${p.female ? 'ما تقوله المريضة' : 'ما يقوله المريض'} ${said ? '<span class="link" data-ask>اسأل مرة أخرى</span>' : ''}</div>
                        ${said ? `<div class="quote ${said.none ? 'none' : ''}">${esc(said.quote)}</div>
                            ${pain != null ? `<div class="ask"><span>الألم حسب كلامه: <b style="color:var(--text)">${pain} من 10</b></span><div class="pain">${Array.from({ length: 10 }, (_, i) => `<i class="${i < pain ? 'on' : ''}"></i>`).join('')}</div></div>` : ''}`
                            : `<div class="ask-btn" data-ask>${I.ask} اسأله: وين يوجعك؟</div>`}
                    </div>
                    <div class="card finds"><div class="sec-title">ما وجدته <span class="count">${f.count}</span></div>
                        <div class="find-list" data-scroll="finds">${f.html}</div></div>
                </div>
                <div class="figure-wrap">
                    <div class="view-toggle"><span class="${S.view === 'front' ? 'on' : ''}" data-view="front">من الأمام</span><span class="${S.view === 'back' ? 'on' : ''}" data-view="back">من الخلف</span></div>
                    ${bodySvg()}
                    <div class="legend"><span><i style="background:rgba(255,255,255,0.12);border:1px dashed rgba(255,255,255,0.4)"></i>لم يُفحص</span><span><i style="background:#3ddc97"></i>سليم</span><span><i style="background:#f6c945"></i>بسيطة</span><span><i style="background:#f6a94a"></i>إصابة</span><span><i style="background:#ff5f5f"></i>خطيرة</span></div>
                </div>
                <div class="col">
                    ${monitor(v)}
                    ${tools(v)}
                    ${notes(v)}
                </div>
            </div>
            <div class="exam-foot">
                <div class="progress"><div class="t"><span>تم فحص <b>${c.zones || 0}</b> من <b>${c.zonesOf || 9}</b> أجزاء</span><span>القياسات: <b>${c.measures || 0}</b> من <b>${c.measuresOf || 6}</b></span></div>
                    <div class="pbar"><i style="width:${pct}%"></i></div></div>
                <div class="actions">
                    <span class="btn soon" data-soon="4">${I.file} حفظ في ملف المريض <span class="soon-tag">قريبًا</span></span>
                    <span class="btn primary" data-treat>${I.plus} ابدأ العلاج</span>
                </div>
            </div>
        </div>`;
    }

    // ------------------------------------------------------------------
    // overlays: a running step, the cuff, a question, a message
    // ------------------------------------------------------------------
    function busyView() {
        if (!S.busy) return '';
        const elapsed = Math.max(0, (Date.now() - S.busy.at) / 1000);
        return `<div class="busy"><div class="t"><span>${esc(S.busy.label)}</span><small>لا تبتعد عن المريض</small></div>
            <div class="bar"><i style="animation-duration:${S.busy.secs}s; animation-delay:-${elapsed.toFixed(2)}s"></i></div></div>`;
    }

    function gaugeSvg() {
        const ang = (v) => (-225 + (v / 300) * 270) * Math.PI / 180;
        let ticks = '';
        for (let v = 0; v <= 300; v += 10) {
            const a = ang(v), major = v % 50 === 0;
            const r1 = 84, r2 = major ? 72 : 77;
            ticks += `<line x1="${100 + r1 * Math.cos(a)}" y1="${100 + r1 * Math.sin(a)}" x2="${100 + r2 * Math.cos(a)}" y2="${100 + r2 * Math.sin(a)}" stroke="#333" stroke-width="${major ? 1.8 : 0.9}"/>`;
            if (major) ticks += `<text x="${100 + 62 * Math.cos(a)}" y="${100 + 62 * Math.sin(a) + 3.5}" text-anchor="middle" font-size="10" fill="#333" font-weight="600" font-family="Kit Plex">${v}</text>`;
        }
        let mark = '';
        if (S.bp && S.bp.sys != null) {
            const a = ang(S.bp.sys);
            mark = `<circle cx="${100 + 88 * Math.cos(a)}" cy="${100 + 88 * Math.sin(a)}" r="3.2" fill="#3ddc97"/>`;
        }
        return `<svg width="330" height="330" viewBox="0 0 200 200">
            <defs><radialGradient id="gf" cx="50%" cy="45%" r="60%"><stop offset="0" stop-color="#f7f5ee"/><stop offset="1" stop-color="#d9d4c6"/></radialGradient></defs>
            <circle cx="100" cy="100" r="96" fill="#2a2d35"/><circle cx="100" cy="100" r="88" fill="url(#gf)"/>
            ${ticks}${mark}
            <text x="100" y="72" text-anchor="middle" font-size="9" fill="#555" font-family="Kit Plex">mmHg</text>
            <rect x="70" y="128" width="60" height="22" rx="5" fill="#1b1e24"/>
            <text id="bpDigits" x="100" y="144" text-anchor="middle" font-size="15" font-weight="700" fill="#3ddc97" font-family="Kit Plex">0</text>
            <line id="bpNeedle" x1="88" y1="100" x2="180" y2="100" stroke="#c62828" stroke-width="2.4" stroke-linecap="round" transform="rotate(-225 100 100)"/>
            <circle cx="100" cy="100" r="6" fill="#222"/><circle cx="100" cy="100" r="2.5" fill="#c33"/>
        </svg>`;
    }

    function bpView() {
        if (!S.bp) return '';
        const b = S.bp;
        const stepCls = (n) => {
            const phase = b.sys == null ? (b.phase === 'pump' || b.phase === 'ready' ? 1 : 2) : 3;
            return n < phase ? 'done' : n === phase ? 'now' : '';
        };
        return `<div class="bp-layer"><div class="bp">
            <div class="bp-top"><div class="brand"><div class="brand-icon">${I.gauge}</div><div><h1>قياس ضغط الدم</h1><p>الكُم على الذراع اليسرى للمريض</p></div></div>
                <span class="icon-btn" data-bpcancel>${I.x}</span></div>
            <div class="bp-body">
                <div class="gauge-card">${gaugeSvg()}<div class="beat" id="bpBeat">♥ تسمع نبضة؟</div></div>
                <div>
                    <div class="steps">
                        <div class="step ${stepCls(1)}"><div class="n">${stepCls(1) === 'done' ? '✓' : 1}</div><div><b>انفخ الكُم</b><span>اضغط مطولًا <kbd>مسافة</kbd> حتى يصل المؤشر إلى 180 تقريبًا، ثم اتركه ينزل ببطء</span></div></div>
                        <div class="step ${stepCls(2)}"><div class="n">${stepCls(2) === 'done' ? '✓' : 2}</div><div><b>أول نبضة = الانقباضي</b><span>اضغط <kbd>E</kbd> لحظة ما تسمع أول نبضة</span></div></div>
                        <div class="step ${stepCls(3)}"><div class="n">3</div><div><b>اختفاء النبض = الانبساطي</b><span>اضغط <kbd>E</kbd> لحظة ما تختفي النبضات تمامًا</span></div></div>
                    </div>
                    <div class="readings">
                        <div class="reading ${b.sys != null ? 'got' : ''}"><small>الانقباضي</small><b>${b.sys != null ? b.sys : '--'}</b></div>
                        <div class="reading ${b.dia != null ? 'got' : ''}"><small>الانبساطي</small><b>${b.dia != null ? b.dia : '--'}</b></div>
                    </div>
                    <div class="bp-msg ${b.warn ? 'warn' : ''}">${esc(b.msg || 'كل ما كانت ضغطتك في الوقت الصح، كانت القراءة أدق.')}</div>
                </div>
            </div>
            <div class="bp-foot"><span><kbd>مسافة</kbd> نفخ · <kbd>E</kbd> تسجيل · <kbd>Esc</kbd> إلغاء</span><span>${b.phase === 'saving' ? 'جارٍ الحفظ…' : ''}</span></div>
        </div></div>`;
    }

    function sheetView() {
        if (!S.sheet) return '';
        return `<div class="sheet-layer"><div class="sheet"><h3>${esc(S.sheet.title)}</h3><p>${esc(S.sheet.text)}</p>
            <div class="acts"><button class="kit-btn danger" data-sheetok>${esc(S.sheet.ok)}</button><button class="kit-btn" data-sheetno>إلغاء</button></div></div></div>`;
    }

    function toastView() {
        return S.toast ? `<div class="toast ${esc(S.toast.type || '')}">${esc(S.toast.text)}</div>` : '';
    }

    // ------------------------------------------------------------------
    // render
    // ------------------------------------------------------------------
    function render() {
        if (!S.data) { os.innerHTML = ''; return; }
        if (S.tab === 'boss' && !S.data.me.isBoss) S.tab = 'calls';
        let body;
        if (S.tab === 'exam') body = examView();
        else body = `<div class="pane" data-scroll="pane">${S.tab === 'team' ? teamView() : S.tab === 'me' ? meView() : S.tab === 'boss' ? bossView() : callsView()}</div>`;
        os.innerHTML = `${statusBar()}${header()}<div class="content">${body}${busyView()}</div>${bpView()}${sheetView()}${toastView()}`;
        tickTimer();
        if (bpLive) paintBp(bpLive.p, bpLive.beat);
        if (!MIRROR) { wire(); pushMirror(); }
    }

    // the exam timer (both copies run it on their own)
    function tickTimer() {
        const el = $('examTimer');
        if (!el || !S.exam) return;
        const secs = Math.max(0, (S.exam.now - S.exam.started) + Math.floor((Date.now() - S.examAt) / 1000));
        el.textContent = `${String(Math.floor(secs / 60)).padStart(2, '0')}:${String(secs % 60).padStart(2, '0')}`;
    }
    setInterval(tickTimer, 1000);

    // ------------------------------------------------------------------
    // the cuff needle (drawn straight, many times a second)
    // ------------------------------------------------------------------
    let bpLive = null; // { p, beat } last drawn
    function paintBp(p, beat) {
        bpLive = { p, beat };
        const needle = $('bpNeedle');
        if (!needle) return;
        needle.setAttribute('transform', `rotate(${(-225 + (p / 300) * 270).toFixed(2)} 100 100)`);
        const digits = $('bpDigits');
        if (digits) digits.textContent = Math.round(p);
        const b = $('bpBeat');
        if (b) b.classList.toggle('on', !!beat);
    }

    // ------------------------------------------------------------------
    // the mirror copy
    // ------------------------------------------------------------------
    let lastMirror = '';
    let mirrorTimer = null;
    function pushMirror() {
        if (!inGame) return;
        clearTimeout(mirrorTimer);
        mirrorTimer = setTimeout(() => {
            const json = JSON.stringify({ ...S, busyElapsed: S.busy ? (Date.now() - S.busy.at) / 1000 : 0 });
            if (json === lastMirror) return;
            lastMirror = json;
            post('mirror', { s: json });
        }, 30);
    }
    let lastBpSend = 0;
    function mirrorUi(msg, every) {
        if (!inGame) return;
        const now = Date.now();
        if (every && now - lastBpSend < every) return;
        lastBpSend = now;
        post('mirrorUi', msg);
    }

    function applyMirror(msg) {
        if (msg.type === 'state' && msg.s) {
            const next = typeof msg.s === 'string' ? JSON.parse(msg.s) : msg.s;
            if (next.busy) next.busy.at = Date.now() - (next.busyElapsed || 0) * 1000;
            if (next.exam) next.examAt = (S.exam && S.exam.now === next.exam.now && S.exam.started === next.exam.started) ? S.examAt : Date.now();
            delete next.busyElapsed;
            Object.assign(S, next);
            if (!S.bp) bpLive = null;
            render();
        } else if (msg.type === 'bp') {
            paintBp(msg.p || 0, msg.beat);
        } else if (msg.type === 'hover') {
            S.hover = msg.zone || null;
            os.querySelectorAll('.zone').forEach((z) => z.classList.toggle('hover', z.dataset.zone === S.hover));
        } else if (msg.type === 'scroll') {
            const el = os.querySelector(`[data-scroll="${msg.key}"]`);
            if (el) el.scrollTop = msg.top || 0;
        } else if (msg.type === 'clock') {
            S.clock = msg.t || '';
            const c = $('clock');
            if (c) c.textContent = S.clock;
        } else if (msg.type === 'clear') {
            S.data = null;
            render();
        }
    }

    if (MIRROR) {
        window.addEventListener('message', (e) => {
            let msg = e.data;
            if (typeof msg === 'string') { try { msg = JSON.parse(msg); } catch (_) { return; } }
            if (msg && msg.type) applyMirror(msg);
        });
        return; // the mirror only draws
    }

    // ==================================================================
    // the real tablet (everything below runs only on your screen)
    // ==================================================================
    // Medium size: on the right side, so your character holding the tablet stays visible in the middle
    function fit() {
        const s = Math.min((window.innerHeight * 0.62) / 880, (window.innerWidth * 0.42) / 1320);
        device.style.setProperty('--fit', `scale(${s.toFixed(4)})`);
    }
    window.addEventListener('resize', fit);
    fit();

    let toastTimer = null;
    function toast(text, type) {
        S.toast = { text, type };
        render();
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { S.toast = null; render(); }, 2600);
    }

    let sheetAction = null;
    function confirmSheet(title, text, ok, action) {
        S.sheet = { title, text, ok };
        sheetAction = action;
        render();
    }

    function setExam(view) {
        if (!view) return;
        view.zones = obj(view.zones);
        view.vitals = obj(view.vitals);
        view.chips = list(view.chips);
        S.exam = view;
        S.examAt = Date.now();
        S.wait = null;
    }

    async function step(kind, extra, label, secs) {
        if (S.busy || bpRun || bpStarting || !S.exam) return;
        const target = S.exam.target;
        S.listen = false;
        S.busy = { label, secs, at: Date.now(), zone: extra && extra.zone };
        render();
        const res = await post('examStep', { kind, ...(extra || {}) });
        S.busy = null;
        const same = S.exam && S.exam.target === target; // the tablet may have closed / switched patient meanwhile
        if (same && res && res.ok && res.data) setExam(res.data);
        else if (same && res && res.error) toast(errText(res.error), 'error');
        render();
    }

    function wire() {
        os.querySelectorAll('[data-tab]').forEach((b) => { b.onclick = () => { if (bpRun) return; S.tab = b.dataset.tab; S.listen = false; render(); }; });
        os.querySelectorAll('[data-close]').forEach((b) => { b.onclick = () => close(true); });
        os.querySelectorAll('[data-take]').forEach((b) => { b.onclick = () => act('takeCall', { id: Number(b.dataset.take) }, b); });
        os.querySelectorAll('[data-done]').forEach((b) => { b.onclick = () => act('closeCall', { id: Number(b.dataset.done) }, b); });
        os.querySelectorAll('[data-go]').forEach((b) => {
            b.onclick = () => {
                const c = S.data.calls.find((x) => x.id === Number(b.dataset.go));
                if (c) post('gps', { x: c.x, y: c.y, z: c.z, label: `بلاغ: ${c.label}` });
            };
        });
        os.querySelectorAll('[data-hgps]').forEach((b) => { b.onclick = () => post('hospitalGps', { hospital: b.dataset.hgps }); });
        os.querySelectorAll('[data-grade]').forEach((s) => {
            s.onchange = async () => {
                const res = await post('setGrade', { citizenid: s.dataset.grade, grade: Number(s.value) });
                toast(res && res.ok ? 'تم تغيير الرتبة' : ((res && res.error) || 'حدث خطأ'), res && res.ok ? 'success' : 'error');
            };
        });
        os.querySelectorAll('[data-fire]').forEach((b) => {
            b.onclick = () => confirmSheet(`إنهاء خدمة ${b.dataset.name}؟`, 'يصبح بلا وظيفة، ويستطيع التقديم مجددًا من استقبال المستشفى.', 'إنهاء الخدمة', async () => {
                const res = await post('fire', { citizenid: b.dataset.fire });
                toast(res && res.ok ? 'أُنهيت خدمته' : ((res && res.error) || 'حدث خطأ'), res && res.ok ? 'success' : 'error');
            });
        });
        os.querySelectorAll('[data-apphire]').forEach((b) => {
            b.onclick = () => confirmSheet(`توظيف ${b.dataset.name}؟`, 'يصبح مسعفًا مستجدًا، ويبدأ الدوام من المستشفى.', 'نعم، وظّفه', async () => {
                const res = await post('appHire', { id: Number(b.dataset.apphire) });
                toast(res && res.ok ? 'تم التوظيف' : ((res && res.error) || 'حدث خطأ'), res && res.ok ? 'success' : 'error');
            });
        });
        os.querySelectorAll('[data-appno]').forEach((b) => {
            b.onclick = () => confirmSheet(`رفض طلب ${b.dataset.name}؟`, 'يصله إشعار، ويستطيع التقديم مجددًا بعد يوم.', 'رفض الطلب', async () => {
                const res = await post('appReject', { id: Number(b.dataset.appno) });
                toast(res && res.ok ? 'رُفض الطلب' : ((res && res.error) || 'حدث خطأ'), res && res.ok ? 'success' : 'error');
            });
        });
        const quit = os.querySelector('[data-quit]');
        if (quit) quit.onclick = () => confirmSheet('تترك العمل في الإسعاف؟', 'تصبح بلا وظيفة، وتفقد رتبتك. تستطيع التقديم مجددًا من استقبال المستشفى كمستجد.', 'نعم، أترك العمل', () => post('quit'));
        const ok = os.querySelector('[data-sheetok]');
        if (ok) ok.onclick = async () => { const a = sheetAction; S.sheet = null; sheetAction = null; render(); if (a) await a(); };
        const no = os.querySelector('[data-sheetno]');
        if (no) no.onclick = () => { S.sheet = null; sheetAction = null; render(); };

        // exam
        const nearest = os.querySelector('[data-nearest]');
        if (nearest) nearest.onclick = () => post('examNearest');
        os.querySelectorAll('[data-view]').forEach((b) => { b.onclick = () => { S.view = b.dataset.view; render(); }; });
        os.querySelectorAll('.zone').forEach((z) => {
            z.onclick = () => {
                const zone = z.dataset.zone;
                step('zone', { zone }, `جارٍ فحص ${ZONE_LABEL[zone]}…`, (obj(S.exam.times).zone) || 3);
            };
            z.onmouseenter = () => { S.hover = z.dataset.zone; mirrorUi({ type: 'hover', zone: S.hover }); };
            z.onmouseleave = () => { if (S.hover === z.dataset.zone) { S.hover = null; mirrorUi({ type: 'hover', zone: null }); } };
        });
        const T = () => obj(S.exam && S.exam.times);
        os.querySelectorAll('[data-tool]').forEach((b) => {
            b.onclick = () => {
                const tool = b.dataset.tool;
                if (tool === 'bp') return startBp();
                if (tool === 'listen') { S.listen = !S.listen; render(); return; }
                const names = { pulse: ['جارٍ جسّ النبض…', T().pulse || 6], spo2: ['جارٍ قياس الأكسجين…', T().spo2 || 4], temp: ['جارٍ قياس الحرارة…', T().temp || 5], pupils: ['جارٍ فحص العينين بالضوء…', T().pupils || 3] };
                const n = names[tool];
                if (n) step('measure', { tool }, n[0], n[1]);
            };
        });
        os.querySelectorAll('[data-listen]').forEach((b) => {
            b.onclick = () => {
                const spot = b.dataset.listen;
                const label = spot === 'heart' ? 'جارٍ سماع القلب…' : spot === 'L' ? 'جارٍ سماع الرئة اليسرى…' : 'جارٍ سماع الرئة اليمنى…';
                step('measure', { tool: spot }, label, T().listen || 3);
            };
        });
        os.querySelectorAll('[data-ask]').forEach((b) => { b.onclick = () => step('ask', {}, 'تسأل المريض…', T().ask || 2); });
        const end = os.querySelector('[data-endexam]');
        if (end) end.onclick = () => { post('examClose'); S.exam = null; S.view = 'front'; render(); };
        os.querySelectorAll('[data-soon]').forEach((b) => { b.onclick = () => toast('ملفات المرضى تأتي في الجزء الرابع', ''); });
        // the treatment (camera over the patient, like the video): the tablet goes away, the treatment opens
        const treatBtn = os.querySelector('[data-treat]');
        if (treatBtn) treatBtn.onclick = () => { if (S.exam && !S.busy && !S.bp) post('examTreat'); };
        const cancel = os.querySelector('[data-bpcancel]');
        if (cancel) cancel.onclick = () => cancelBp();

        // keep the mirror's scroll in step
        os.querySelectorAll('[data-scroll]').forEach((el) => {
            el.onscroll = () => mirrorUi({ type: 'scroll', key: el.dataset.scroll, top: el.scrollTop }, 80);
        });
    }

    async function act(name, body, button) {
        if (button) button.disabled = true;
        await post(name, body);
        if (button) button.disabled = false;
    }

    // ------------------------------------------------------------------
    // the cuff game
    // ------------------------------------------------------------------
    let bpRun = null;
    let bpStarting = false;
    let lastFrame = 0;
    let audio = null;

    function thump() {
        try {
            audio = audio || new (window.AudioContext || window.webkitAudioContext)();
            const o = audio.createOscillator();
            const g = audio.createGain();
            o.type = 'sine';
            o.frequency.value = 62;
            const t = audio.currentTime;
            g.gain.setValueAtTime(0.0001, t);
            g.gain.exponentialRampToValueAtTime(0.6, t + 0.012);
            g.gain.exponentialRampToValueAtTime(0.0001, t + 0.13);
            o.connect(g).connect(audio.destination);
            o.start(t);
            o.stop(t + 0.15);
        } catch (_) { /* no sound */ }
    }

    async function startBp() {
        if (S.busy || bpRun || bpStarting || !S.exam) return;
        S.listen = false;
        bpStarting = true;
        const target = S.exam.target;
        const res = await post('examBp', { stage: 'start' });
        bpStarting = false;
        if (!S.exam || S.exam.target !== target || root.classList.contains('hidden')) return;
        if (!res || !res.ok || !res.data) { toast(errText(res && res.error), 'error'); return; }
        bpRun = { truth: res.data, token: res.data.token, p: 0, holding: false, max: 0, lastBeat: 0, phase: 'ready', sys: null, dia: null, early: false };
        S.bp = { phase: 'ready', sys: null, dia: null, msg: '', warn: false };
        bpLive = { p: 0, beat: false };
        render();
        lastFrame = performance.now();
        requestAnimationFrame(bpTick);
    }

    function bpTick(now) {
        const r = bpRun;
        if (!r) return;
        const dt = Math.min(0.05, (now - lastFrame) / 1000);
        lastFrame = now;
        if (r.holding) {
            r.p = Math.min(300, r.p + 95 * dt);
            r.max = Math.max(r.max, r.p);
            if (r.phase !== 'pump') { r.phase = 'pump'; S.bp.phase = 'pump'; render(); }
        } else if (r.p > 0 && r.phase === 'pump') {
            r.phase = 'deflate';
            S.bp.phase = 'deflate';
            if (!r.truth.none && r.max < r.truth.sys + 5) { r.early = true; S.bp.msg = 'تسمع النبض من البداية؟ انفخ أكثر (180 تقريبًا).'; S.bp.warn = true; }
            render();
        }
        if (r.phase === 'deflate') r.p = Math.max(0, r.p - 6 * dt);

        let beat = false;
        if (r.phase === 'deflate' && !r.truth.none && r.p <= r.truth.sys && r.p >= r.truth.dia) {
            if (now - r.lastBeat >= 60000 / Math.max(40, r.truth.hr)) { r.lastBeat = now; thump(); }
            beat = now - r.lastBeat < 150;
        }
        paintBp(r.p, beat);
        mirrorUi({ type: 'bp', p: Math.round(r.p * 10) / 10, beat }, 50);

        if (r.phase === 'deflate' && r.p <= 25) { finishBp(); return; }
        requestAnimationFrame(bpTick);
    }

    function bpMark() {
        const r = bpRun;
        if (!r || r.phase !== 'deflate') return;
        const v = Math.round(r.p / 2) * 2;
        if (r.sys == null) {
            r.sys = v; S.bp.sys = v; S.bp.msg = 'الآن انتظر حتى تختفي النبضات تمامًا.'; S.bp.warn = false;
            render();
        } else if (r.dia == null && v < r.sys) {
            r.dia = v; S.bp.dia = v;
            finishBp();
        }
    }

    async function finishBp() {
        const r = bpRun;
        bpRun = null;
        if (!r) return;
        if (!r.truth.none && (r.sys == null || r.dia == null)) {
            S.bp = null; bpLive = null;
            post('examBp', { stage: 'cancel' });
            toast('ما سجّلت القراءة كاملة — أعد القياس', 'error');
            return;
        }
        S.bp.phase = 'saving';
        render();
        const res = await post('examBp', { stage: 'finish', token: r.token, sys: r.sys, dia: r.dia });
        S.bp = null; bpLive = null;
        if (res && res.ok && res.data) {
            setExam(res.data);
            render();
            if (r.truth.none) toast('لا يوجد نبض: لا يمكن قياس الضغط', 'error');
        } else {
            toast(errText(res && res.error), 'error');
        }
    }

    function cancelBp() {
        if (!bpRun && !S.bp) return;
        bpRun = null;
        S.bp = null; bpLive = null;
        post('examBp', { stage: 'cancel' });
        render();
    }

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (S.bp) cancelBp();
            else if (S.sheet) { S.sheet = null; sheetAction = null; render(); }
            else if (S.listen) { S.listen = false; render(); }
            else close(true);
            return;
        }
        if (!bpRun) return;
        if (e.code === 'Space') { e.preventDefault(); if (!e.repeat) bpRun.holding = true; }
        else if (e.code === 'KeyE' && !e.repeat) { e.preventDefault(); bpMark(); }
    });
    document.addEventListener('keyup', (e) => {
        if (bpRun && e.code === 'Space') bpRun.holding = false;
    });

    // ------------------------------------------------------------------
    // open / close
    // ------------------------------------------------------------------
    let closing = false;
    let closeTimer = null;
    function close(tellGame) {
        if (root.classList.contains('hidden') || closing) return;
        closing = true;
        if (bpRun || S.bp) cancelBp();
        // closing the tablet ends the exam (the game forgets it too)
        S.sheet = null;
        S.exam = null;
        S.wait = null;
        S.busy = null;
        S.listen = false;
        render();
        root.classList.add('closing');
        closeTimer = setTimeout(() => {
            closeTimer = null;
            root.className = 'hidden';
            closing = false;
        }, 200);
        if (tellGame) post('close');
    }

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'tablet' && msg.data) {
            const wasHidden = root.classList.contains('hidden') || closing;
            if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; }
            closing = false;
            const d = msg.data;
            d.calls = list(d.calls); d.team = list(d.team); d.ranks = list(d.ranks);
            d.me.stats = d.me.stats || {};
            S.data = d;
            if (msg.clock) S.clock = msg.clock;
            if (wasHidden) {
                S.tab = msg.tab || 'calls';
                S.view = 'front';
                S.listen = false;
                S.toast = null;
                S.busy = null;
                S.bp = null;
                S.sheet = null;
                bpRun = null;
                bpLive = null;
            }
            root.className = '';
            render();
        } else if (msg.action === 'exam') {
            setExam(msg.data);
            if (msg.focus) S.tab = 'exam';
            render();
        } else if (msg.action === 'examWait') {
            S.wait = msg.text || 'بانتظار موافقة المريض…';
            S.tab = 'exam';
            render();
        } else if (msg.action === 'examEnd') {
            S.wait = null;
            if (msg.error) toast(errText(msg.error), 'error');
            if (msg.clear) { S.exam = null; S.busy = null; S.listen = false; bpRun = null; S.bp = null; bpLive = null; }
            render();
        } else if (msg.action === 'toast') {
            toast(msg.text, msg.type);
        } else if (msg.action === 'clock') {
            S.clock = msg.t || '';
            const c = $('clock');
            if (c) c.textContent = S.clock;
        } else if (msg.action === 'close') {
            close(false);
        }
    });

    // ------------------------------------------------------------------
    // preview outside the game (open html/index.html?tab=exam in a browser)
    // ------------------------------------------------------------------
    function preview() { return { ok: true }; }
    if (!inGame) {
        document.body.style.background = 'linear-gradient(135deg,#3a4250,#1b1f27)';
        const ranks = [['مستجد', 50], ['مسعف', 75], ['طبيب', 100], ['جرّاح', 125], ['قائد', 150]].map(([name, payment], grade) => ({ grade, name, payment, boss: grade === 4 }));
        S.data = {
            me: { name: 'آدم الحربي', grade: 4, gradeLabel: 'قائد', onDuty: true, isBoss: true, stats: { revives: 37, treats: 52, earned: 18900 }, shift: { revives: 3, treats: 4, earned: 1500 } },
            pay: { revive: 300, treat: 150 }, payCooldown: 10, treatBelow: 85, ranks,
            calls: [{ id: 3, kind: 'down', label: 'مواطن مصاب على الأرض', patientName: 'سارة منصور', street: 'Strawberry Ave', distance: 640, ago: 25 }],
            team: [{ citizenid: 'A1', name: 'آدم الحربي', grade: 4, gradeLabel: 'قائد', online: true, onDuty: true, me: true }],
        };
        S.clock = '21:09';
        S.tab = params.get('tab') || 'calls';
        if (S.tab === 'exam' && params.get('empty') !== '1') {
            setExam({
                target: 2, patient: { name: 'سارة منصور', initials: 'سم', gender: 'أنثى', female: true, age: 27, blood: 'O+' },
                death: 2, chips: [['على الأرض', 'bad'], ['واعية لكن مشوّشة', 'warn']],
                zones: {
                    head: { label: 'الرأس', level: 0, items: [] },
                    chest: { label: 'الصدر', level: 0, items: [] },
                    l_leg: { label: 'الرجل اليسرى', level: 3, items: [{ kind: 'gunshot', part: 'الرجل اليسرى', level: 3, text: 'جرح ناري بدون مخرج — الرصاصة ما زالت في الداخل', cause: 'فتحة صغيرة (مسدس على الأغلب)', tags: [['نزيف متوسط', 'r'], ['إخراج الرصاصة', 'g']] }] },
                    r_leg: { label: 'الرجل اليمنى', level: 2, items: [{ kind: 'fracture', part: 'الرجل اليمنى', level: 3, text: 'تورّم وتشوّه واضح — اشتباه كسر', tags: [['يحتاج أشعة', 'o'], ['جبيرة', 'g']] }] },
                    r_arm: { label: 'الذراع اليمنى', level: 2, items: [{ kind: 'laceration', part: 'الذراع اليمنى', level: 2, text: 'جرح قطعي، طوله 6 سم تقريبًا', cause: 'السبب المحتمل: سكين', tags: [['نزيف خفيف', 'r'], ['تنظيف وخياطة', 'g']] }] },
                    l_arm: { label: 'الذراع اليسرى', level: 0, items: [] },
                },
                vitals: { hr: { v: 124, label: 'سريع وضعيف', cls: 'warn', at: 100 }, bp: { sys: 92, dia: 58, label: 'منخفض', cls: 'warn', at: 100 }, resp: { v: 22, label: 'سريع', cls: 'warn', at: 100 }, lungL: { text: 'دخول الهواء طبيعي', cls: 'ok' }, pupils: { text: 'تتفاعل مع الضوء بشكل طبيعي', cls: 'ok' } },
                said: { quote: '«الرجل اليسرى… ما أقدر أحرّكها، وفيه دم كثير من الذراع اليمنى…»', pain: 8, weak: true },
                counts: { zones: 6, zonesOf: 9, measures: 4, measuresOf: 6 }, started: 0, now: 102,
                times: { zone: 3, pulse: 6, spo2: 4, temp: 5, listen: 3, pupils: 3, ask: 2 },
            });
            if (params.get('busy') === '1') S.busy = { label: 'جارٍ فحص البطن…', secs: 3, at: Date.now() - 1200, zone: 'abdomen' };
            if (params.get('bp') === '1') { S.bp = { phase: 'deflate', sys: 94, dia: null, msg: 'الآن انتظر حتى تختفي النبضات تمامًا.' }; bpLive = { p: 81, beat: true }; }
        }
        root.className = '';
        render();
        window.__S = S; // for checking the mirror outside the game
    }
})();
