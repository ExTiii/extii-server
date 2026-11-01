// EX_Tii hospitals — reception panel + medical report card
(() => {
    const $ = (id) => document.getElementById(id);
    const app = $('app');
    const inGame = typeof GetParentResourceName === 'function';
    const resource = inGame ? GetParentResourceName() : 'exti_hospital';

    let info = null;
    let busy = false;
    let closing = false;
    let closeTimer = null;

    function post(name, data) {
        if (!inGame) return Promise.resolve(previewAnswer(name));
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false }));
    }

    let toastTimer;
    function toast(text, type) {
        const t = app.classList.contains('mode-report') ? $('toast2') : $('toast');
        t.textContent = text;
        t.className = `kit-toast show ${type || ''}`;
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { t.className = 'kit-toast'; }, 2800);
    }

    function setBar(bar, percent) {
        bar.style.width = `${Math.max(0, Math.min(100, percent))}%`;
        bar.className = percent >= 60 ? '' : percent >= 30 ? 'mid' : 'low';
    }

    function show(mode) {
        if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; }
        closing = false;
        app.className = `mode-${mode}`;
    }

    // ---------- reception ----------
    function renderReception() {
        $('hospitalName').textContent = info.label;
        $('greeting').textContent = `أهلًا بك في ${info.label}! كيف أقدر أساعدك اليوم؟`;

        $('healthText').textContent = `${info.health}%`;
        setBar($('healthBar'), info.health);

        const total = info.bedsTotal || 0;
        const beds = typeof info.beds === 'number' ? info.beds : total;
        $('bedsText').innerHTML = `${beds}<small> / ${total}</small>`;
        setBar($('bedsBar'), total ? (beds / total) * 100 : 0);

        $('emsText').textContent = info.ems;
        const line = $('emsLine');
        line.innerHTML = '';
        line.classList.toggle('none', !info.ems);
        for (let i = 0; i < Math.max(1, Math.min(info.ems, 8)); i++) line.appendChild(document.createElement('i'));

        // treatment
        const healthy = info.health >= 100;
        const noBeds = beds === 0;
        $('treatText').textContent = healthy
            ? 'صحتك كاملة الآن، لا تحتاج إلى علاج.'
            : noBeds
                ? 'كل الأسرّة مشغولة الآن، حاول بعد قليل.'
                : `استلقِ على سرير ويعالجك الطبيب خلال ${info.treatTime} ثانية، وتخرج بصحة كاملة.`;
        $('btnTreat').disabled = healthy || noBeds;
        $('optTreat').classList.toggle('off', healthy || noBeds);

        // check-up
        $('checkupText').textContent = info.checkupWait > 0
            ? `أخذت تقريرًا قبل قليل، تقدر تطلب فحصًا جديدًا بعد ${info.checkupWait} دقيقة.`
            : `فحص سريع (${info.checkupTime} ثوانٍ)، وتأخذ تقريرًا طبيًا باسمك تقدر تُظهره لأي شخص.`;
        $('btnCheckup').disabled = info.checkupWait > 0;
        $('optCheckup').classList.toggle('off', info.checkupWait > 0);

        // call a medic
        const canCall = info.ems > 0 && !info.callWait;
        $('callText').textContent = !info.ems
            ? 'لا يوجد مسعفون في الخدمة الآن. العلاج المجاني متاح دائمًا.'
            : info.callWait
                ? `أرسلت طلبًا قبل قليل، تقدر تطلب مرة أخرى بعد ${info.callWait} دقيقة.`
                : 'نرسل طلبك إلى المسعفين في الخدمة ليأتوا إليك هنا.';
        $('btnCall').disabled = !canCall;
        $('optCall').classList.toggle('off', !canCall);
    }

    async function act(name, button) {
        if (busy) return;
        busy = true;
        button.disabled = true;
        const res = await post(name);
        busy = false;
        if (!res || !res.ok) {
            button.disabled = false;
            toast((res && res.error) || 'حدث خطأ، حاول مرة أخرى', 'error');
            return;
        }
        if (res.message) toast(res.message, 'success');
        if (name === 'callMedic') { info.callWait = info.callCooldown || 2; renderReception(); }
    }

    $('btnTreat').onclick = () => act('treat', $('btnTreat'));
    $('btnCheckup').onclick = () => act('checkup', $('btnCheckup'));
    $('btnCall').onclick = () => act('callMedic', $('btnCall'));

    // ---------- report ----------
    function renderReport(r, canShow) {
        $('report').classList.toggle('view-only', !canShow);
        $('rHospital').textContent = r.hospital || '';
        $('rNumber').textContent = `#${r.number || ''}`;
        $('rPatient').textContent = r.patient || '-';
        $('rBirth').textContent = r.birthdate || '-';
        $('rGender').textContent = r.gender || '-';
        $('rBlood').textContent = r.blood || '-';
        $('rDate').textContent = [r.date, r.time].filter(Boolean).join('  ') || '-';
        $('rDoctor').textContent = r.doctor || '-';
        $('rResult').textContent = `${r.result || ''} (${r.health ?? 0}%)`;
        $('rAdvice').textContent = r.advice || '';
        $('rResultBox').className = `report-result ${r.level === 'ok' ? '' : r.level || ''}`;
        setBar($('rBar'), r.health ?? 0);
    }

    $('btnShow').onclick = async () => {
        if (busy) return;
        busy = true;
        const res = await post('showReport');
        busy = false;
        toast(res && res.ok ? res.message : ((res && res.error) || 'حدث خطأ'), res && res.ok ? 'success' : 'error');
    };

    // ---------- open / close ----------
    function close(tellGame) {
        if (app.classList.contains('hidden') || closing) return;
        closing = true;
        app.classList.add('closing');
        closeTimer = setTimeout(() => {
            closeTimer = null;
            app.className = 'hidden';
            closing = false;
        }, 170);
        if (tellGame) post('close');
    }

    document.querySelectorAll('[data-close]').forEach((b) => { b.onclick = () => close(true); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(true); });

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'reception' && msg.data) {
            info = msg.data;
            busy = false;
            show('reception');
            renderReception();
        } else if (msg.action === 'report' && msg.data) {
            busy = false;
            show('report');
            renderReport(msg.data, msg.canShow);
        } else if (msg.action === 'close') {
            close(false);
        }
    });

    // ---------- preview outside the game ----------
    function previewAnswer(name) {
        if (name === 'callMedic') return { ok: true, message: 'تم إبلاغ المسعفين، انتظر هنا قليلًا' };
        if (name === 'showReport') return { ok: true, message: 'أظهرت التقرير لأقرب شخص' };
        return { ok: true };
    }
    if (!inGame) {
        const params = new URLSearchParams(location.search);
        document.body.style.background = 'linear-gradient(135deg,#3a4250,#1b1f27)';
        if (params.get('view') === 'report') {
            show('report');
            renderReport({
                hospital: 'مستشفى بيلبوكس', number: '41377-0619', patient: 'آدم الحربي', birthdate: '1998-04-12',
                gender: 'ذكر', blood: 'O+', date: '2026/10/27', time: '21:40', doctor: 'د. ليلى منصور',
                result: params.get('lvl') === 'warn' ? 'إصابات خفيفة' : 'سليم', level: params.get('lvl') || 'ok',
                health: params.get('lvl') === 'warn' ? 72 : 100,
                advice: params.get('lvl') === 'warn' ? 'يكفي الشاش الطبي أو المسكنات' : 'لا يحتاج إلى علاج',
            }, true);
        } else {
            info = { label: params.get('h') === 'paleto' ? 'مركز باليتو الطبي' : 'مستشفى بيلبوكس', health: 64, ems: Number(params.get('ems') || 2), beds: 9, bedsTotal: 12, checkupWait: 0, callWait: 0, treatTime: 20, checkupTime: 8 };
            show('reception');
            renderReception();
        }
    }
})();
