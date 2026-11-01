// EX_Tii Mechanic — the mechanic tablet (like the video).
// One page, two copies: the real one on your screen, and a "mirror" copy (tablet.html?mirror=1)
// that the game paints on the tablet in your character's hands. Everything on the screen comes
// from one state object S, so the mirror always shows exactly the same thing.
// This file: the device, the state, drawing, the home screen and the small shared pieces.
// The apps are in the other files (map.js, chat.js, cal.js, forms.js, boss.js, tools.js).
window.PT = (() => {
    const params = new URLSearchParams(location.search);
    const MIRROR = params.get('mirror') === '1';
    const inGame = typeof GetParentResourceName === 'function';
    const RES = inGame ? GetParentResourceName() : 'exti_mechanic';
    const $ = (id) => document.getElementById(id);

    // ------------------------------------------------------------------
    // the device (your screen) or the bare screen (the mirror)
    // ------------------------------------------------------------------
    let host = $('ptab');
    let os;
    if (MIRROR) {
        document.body.classList.add('pt-mirror');
        os = document.createElement('div');
        os.id = 'pt-os';
        os.className = 'pt-os';
        document.body.appendChild(os);
        if (host) host.remove();
        host = null;
    } else {
        host.className = 'pt-root hidden';
        host.innerHTML = `<div class="pt-device" id="pt-device">
            <div class="pt-shell"></div>
            <div class="pt-bump tl"></div><div class="pt-bump tr"></div><div class="pt-bump bl"></div><div class="pt-bump br"></div>
            <div class="pt-ridge top"></div><div class="pt-ridge bottom"></div>
            <div class="pt-ridge tl"></div><div class="pt-ridge tr"></div><div class="pt-ridge bl"></div><div class="pt-ridge br"></div>
            <div class="pt-ridge l"></div><div class="pt-ridge r"></div>
            <div class="pt-side" style="left: 260px; width: 70px;"></div>
            <div class="pt-side" style="left: 350px; width: 44px;"></div>
            <div class="pt-bezel">
                <div class="pt-cam"></div>
                <div class="pt-screen"><div class="pt-os" id="pt-os"></div></div>
                <div class="pt-glass"></div>
            </div>
        </div>`;
        os = $('pt-os');
    }

    // ------------------------------------------------------------------
    // small helpers
    // ------------------------------------------------------------------
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.floor(Number(n) || 0).toLocaleString('en-US');
    const list = (x) => (Array.isArray(x) ? x : Object.values(x || {}));
    const initials = (name) => {
        const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
        return parts.length ? parts.slice(0, 2).map((p) => [...p][0]).join('') : '?';
    };
    // a picture link we are willing to show (the server checks it too)
    const safeUrl = (u) => (typeof u === 'string' && /^https:\/\/[\w.-]+\/[^\s"'()\\<>]*$/.test(u) && u.length <= 300 ? u : '');

    const DAYS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    const MONTHS = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    const pad = (n) => String(n).padStart(2, '0');
    const now = () => Math.floor((Date.now() + (S.skew || 0)) / 1000);  // the server's time
    const dateOf = (t) => new Date(t * 1000);
    const fmtDate = (t) => { const d = dateOf(t); return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`; };
    const fmtTime = (t) => { const d = dateOf(t); return `${pad(d.getHours())}:${pad(d.getMinutes())}`; };
    const fmtStamp = (t) => `${fmtDate(t)} ${fmtTime(t)}`;
    const ago = (t) => {
        const s = Math.max(0, now() - t);
        if (s < 60) return 'الآن';
        if (s < 3600) return `قبل ${Math.floor(s / 60)} د`;
        if (s < 86400) return `قبل ${Math.floor(s / 3600)} س`;
        return fmtDate(t);
    };

    // ------------------------------------------------------------------
    // icons (simple line icons)
    // ------------------------------------------------------------------
    const svg = (d, size = 20, sw = 1.9) => `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
    const P = {
        back: '<path d="M9 5l7 7-7 7"/>',
        next: '<path d="M15 5l-7 7 7 7"/>',
        users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.6 3.2-5.5 6.5-5.5s5.9 1.9 6.5 5.5"/><circle cx="17.5" cy="9.5" r="2.5"/><path d="M17 14.6c2.5.2 4 1.9 4.5 4.6"/>',
        folder: '<path d="M3 7.5A2.5 2.5 0 0 1 5.5 5h3.8l2 2.2h7.2A2.5 2.5 0 0 1 21 9.7v7.8a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5Z"/>',
        scale: '<path d="M12 4v16M7 20h10M5 7h14"/><path d="M5 7l-3 6a3 3 0 0 0 6 0Z"/><path d="M19 7l-3 6a3 3 0 0 0 6 0Z"/>',
        alert: '<path d="M10.3 4.2 2.6 17.5A2 2 0 0 0 4.3 20.5h15.4a2 2 0 0 0 1.7-3L13.7 4.2a2 2 0 0 0-3.4 0Z"/><path d="M12 9.5v4.2M12 17h.01"/>',
        doc: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8Z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>',
        gavel: '<path d="m14 6 4 4M9.5 10.5l5-5 4 4-5 5Z"/><path d="m11.5 12.5-7 7a1.4 1.4 0 0 1-2-2l7-7M14 21h7"/>',
        inbox: '<rect x="5" y="4" width="14" height="17" rx="2.5"/><path d="M9 4.5V3.5h6v1M9 10h6M9 14h6M9 18h3"/>',
        lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
        car: '<path d="M5 16.5h14M4.5 16.5V13l1.8-4.6A2 2 0 0 1 8.2 7h7.6a2 2 0 0 1 1.9 1.4l1.8 4.6v3.5"/><path d="M4.5 13h15"/><circle cx="8" cy="16.5" r="1.8"/><circle cx="16" cy="16.5" r="1.8"/>',
        clip: '<rect x="5.5" y="4.5" width="13" height="16" rx="2.5"/><path d="M9.5 4.5V3.5h5v1"/><path d="m9 13 2 2 4-4.5"/>',
        crown: '<path d="M4 8l4 4 4-6 4 6 4-4-1.5 10h-13Z"/><path d="M6 21h12"/>',
        video: '<rect x="3" y="6.5" width="12.5" height="11" rx="2.5"/><path d="m15.5 10.5 5.5-3v9l-5.5-3"/>',
        building: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2M10 21v-3h4v3"/>',
        landmark: '<path d="M3 21h18M5 21V10M9 21V10M15 21V10M19 21V10M3 10l9-6 9 6z"/>',
        store: '<path d="M3 9l1.5-5h15L21 9M3 9v2a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0V9M5 13v8h14v-8M10 21v-5h4v5"/>',
        'gas-pump': '<path d="M4 21V5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v16M4 21h11M7 7h5v4H7zM15 9h2a2 2 0 0 1 2 2v6a1.5 1.5 0 0 0 3 0V9l-3-3"/>',
        camera: '<path d="M4 8.5A2.5 2.5 0 0 1 6.5 6h1.8l1.5-2h4.4l1.5 2h1.8A2.5 2.5 0 0 1 20 8.5v8a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 16.5Z"/><circle cx="12" cy="12.5" r="3.5"/>',
        image: '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="9.5" r="1.8"/><path d="m20.5 16-5-5-9 8.5"/>',
        map: '<path d="M3.5 6.5 9 4l6 2.5 5.5-2.5v13.5L15 20l-6-2.5-5.5 2.5Z"/><path d="M9 4v13.5M15 6.5V20"/>',
        chat: '<path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h7A2.5 2.5 0 0 1 16 6.5v4a2.5 2.5 0 0 1-2.5 2.5H9l-3.5 3v-3H6.5"/><path d="M16 8.5h1.5A2.5 2.5 0 0 1 20 11v4a2.5 2.5 0 0 1-2.5 2.5H17v3l-3.5-3H11a2.5 2.5 0 0 1-2.4-1.8"/>',
        cal: '<rect x="4" y="5" width="16" height="15.5" rx="2.5"/><path d="M8 3v4M16 3v4M4 10h16"/>',
        calc: '<rect x="5.5" y="3.5" width="13" height="17" rx="2.5"/><path d="M8.5 7.5h7M9 12h.01M12 12h.01M15 12h.01M9 15.5h.01M12 15.5h.01M15 15.5h.01"/>',
        gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z"/>',
        mail: '<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/><path d="m4 7 8 6 8-6"/>',
        search: '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>',
        plus: '<path d="M12 5v14M5 12h14"/>',
        minus: '<path d="M5 12h14"/>',
        x: '<path d="M6 6l12 12M18 6 6 18"/>',
        send: '<path d="M21 3 10 14"/><path d="m21 3-7 18-4-7-7-4Z"/>',
        smile: '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 14.5a4.5 4.5 0 0 0 7 0M9.5 9.5h.01M14.5 9.5h.01"/>',
        menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
        newchat: '<path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v8a2.5 2.5 0 0 1-2.5 2.5H9l-4 3.5V17"/><path d="M12 7.5v6M9 10.5h6"/>',
        check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
        sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6l1.4 1.4M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4 6 18M18 6l1.4-1.4"/>',
        moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5Z"/>',
        trash: '<path d="M4.5 7h15M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4.5h6V7"/>',
        pin: '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11Z"/><circle cx="12" cy="10" r="2.3"/>',
        up: '<path d="M12 19V5M6 11l6-6 6 6"/>',
        down: '<path d="M12 5v14M6 13l6 6 6-6"/>',
        dollar: '<path d="M12 3v18M16.5 7.5c-.6-1.6-2.3-2.5-4.5-2.5-2.6 0-4.5 1.3-4.5 3.3 0 4.6 9.3 2.4 9.3 7.2 0 2.1-2 3.5-4.8 3.5-2.4 0-4.2-1-4.8-2.8"/>',
        wallet: '<path d="M4 7.5A2.5 2.5 0 0 1 6.5 5h11A2.5 2.5 0 0 1 20 7.5v9a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 16.5Z"/><path d="M15.5 12h4.5v3.5h-4.5a1.75 1.75 0 0 1 0-3.5Z"/>',
        chart: '<path d="M4 20V4M4 20h16"/><path d="m7.5 15 3.5-4 3 2.5 5-6.5"/>',
        grid: '<rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/>',
        receipt: '<path d="M6 3.5h12v17l-3-2-3 2-3-2-3 2Z"/><path d="M9 8.5h6M9 12h6M9 15.5h3"/>',
        user: '<circle cx="12" cy="8" r="4"/><path d="M4.5 21c.7-4 3.6-6.2 7.5-6.2s6.8 2.2 7.5 6.2"/>',
        badge: '<path d="M12 3 4.5 6v5.5c0 4.6 3.2 8 7.5 9.5 4.3-1.5 7.5-4.9 7.5-9.5V6Z"/><path d="m9 12 2 2 4-4"/>',
        list: '<path d="M9 6.5h11M9 12h11M9 17.5h11M4.5 6.5h.01M4.5 12h.01M4.5 17.5h.01"/>',
        refresh: '<path d="M20 11a8 8 0 0 0-14.4-4.6L4 8"/><path d="M4 3.5V8h4.5"/><path d="M4 13a8 8 0 0 0 14.4 4.6L20 16"/><path d="M20 20.5V16h-4.5"/>',
        edit: '<path d="M4 20h4.5L19.3 9.2a2.1 2.1 0 0 0-3-3L5.5 17v3Z"/><path d="m14.5 8 3 3"/>',
        satellite: '<path d="m13 7 4 4M7.5 12.5 4 16l4 4 3.5-3.5"/><path d="m9.5 9.5 5 5"/><path d="m14.5 5.5 3-3 4 4-3 3"/><path d="M5.5 5.5a6 6 0 0 0 0 4"/>',
        zone: '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11Z"/>',
        shield: '<path d="M12 3 4.5 6v5.5c0 4.6 3.2 8 7.5 9.5 4.3-1.5 7.5-4.9 7.5-9.5V6Z"/>',
        signal: '<path d="M4 18v-2M8.5 18v-5M13 18V10M17.5 18V6.5"/>',
        clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
        archive: '<rect x="3.5" y="4.5" width="17" height="4.5" rx="1.5"/><path d="M5 9v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9M10 13h4"/>',
        eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="3"/>',
        fire: '<path d="M12 21c-3.9 0-6.5-2.6-6.5-6.2 0-3.4 2.6-5.6 3.8-8.8.4 2 1.6 3.2 2.7 3.6.3-2.6 1.5-4.8 3.5-6.6-.2 3.6 3 6.1 3 10.3 0 4.1-2.6 7.7-6.5 7.7Z"/>',
        gift: '<rect x="3.5" y="8.5" width="17" height="4" rx="1"/><path d="M5 12.5V20h14v-7.5M12 8.5V20M12 8.5c-1.5-3.5-5.5-4-5.5-1.5 0 1.5 2.5 1.5 5.5 1.5Zm0 0c1.5-3.5 5.5-4 5.5-1.5 0 1.5-2.5 1.5-5.5 1.5Z"/>',
    };
    const I = (name, size, sw) => svg(P[name] || '', size, sw);

    // ------------------------------------------------------------------
    // the state (everything the screen shows)
    // ------------------------------------------------------------------
    function fresh() {
        return {
            open: false,
            me: null,
            settings: { mode: 'dark', wallpaper: '' },
            badges: { chat: 0, forms: 0 },
            cfg: { colors: ['#f2c230'], bonusMax: 50000, salaryMax: 1000, maxText: 500, stations: [] },
            clock: '',
            skew: 0,
            app: null,        // null = the home screen
            page: 0,          // the home screen page (0 / 1)
            scrolls: {},
            toast: null,      // { text, type }
            sheet: null,      // { title, text, ok, danger, input }
            viewer: null,     // a picture shown big
            soon: null,
        };
    }
    const S = fresh();

    // ------------------------------------------------------------------
    // talking to the game
    // ------------------------------------------------------------------
    const mock = {}; // filled by the preview page outside the game
    function post(name, body) {
        if (!inGame) return Promise.resolve(mock[name] ? mock[name](body) : { ok: true });
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false, e: 'failed' }));
    }
    // ask the server (through the game). Always answers { ok, r, e }
    function call(fn, ...args) {
        if (!inGame) {
            const f = mock.calls && mock.calls[fn];
            let r;
            try { r = f ? f(...args) : null; } catch (err) { console.error(err); r = null; }
            return Promise.resolve(r && r.e ? { ok: false, e: r.e } : (r != null && r !== false ? { ok: true, r } : { ok: false, e: 'failed' }));
        }
        return post('ptCall', { fn, args }).then((x) => x || { ok: false, e: 'failed' });
    }

    const ERR = {
        off_duty: 'ابدأ مناوبتك في الورشة أولًا',
        not_boss: 'هذا لمدير الورشة فقط',
        wait: 'انتظر لحظة ثم حاول مرة أخرى',
        failed: 'حدث خطأ، حاول مرة أخرى',
        bad_url: 'الرابط غير صالح: رابط صورة مباشر يبدأ بـ https',
        name: 'الاسم قصير جدًا',
        members: 'اختر زميلًا واحدًا على الأقل',
        title: 'اكتب عنوانًا (حرفان على الأقل)',
        date: 'التاريخ غير صحيح',
        amount: 'المبلغ غير صحيح',
        no_money: 'رصيد حساب الورشة لا يكفي',
        no_money_me: 'رصيدك في البنك لا يكفي',
        rank: 'لا يمكنك اختيار هذه الرتبة',
        too_far: 'يجب أن يكون الشخص بجانبك',
        upload: 'تعذّر رفع الصورة',
        no_camera: 'الكاميرا غير متاحة الآن (السيرفر ليس له عنوان عام بعد)',
    };
    const errText = (code) => ERR[code] || ERR.failed;

    // ------------------------------------------------------------------
    // the apps (each file adds its own: PT.app('map', {...}))
    // ------------------------------------------------------------------
    const APPS = {};
    function app(id, def) { APPS[id] = def; }

    // the home screen icons (like the video: two pages + the dock)
    const HOME = [
        [['orders', 'الطلبات', 'doc', 'amber'], ['diagnostics', 'الفحص', 'scale', 'sky'], ['parts', 'متجر القطع', 'inbox', 'red'], ['dyno', 'الداينو', 'calc', 'violet'],
         ['forms', 'صندوق النماذج', 'inbox', 'amber'], ['offences', 'قوالب الفواتير', 'gavel', 'slate'], ['boss', 'الإدارة', 'crown', 'dark'], ['map', 'الخريطة', 'map', 'sky']],
        [['camera', 'الكاميرا', 'camera', 'dark'], ['gallery', 'المعرض', 'image', 'silver'], ['chat', 'المحادثات', 'chat', 'indigo'],
         ['calendar', 'التقويم', 'cal', 'amber'], ['calc', 'الحاسبة', 'calc', 'silver'], ['settings', 'الإعدادات', 'gear', 'grey']],
    ];
    const DOCK = ['orders', 'boss', 'chat', 'map'];
    const INFO = {};
    HOME.flat().forEach(([id, label, icon, color]) => { INFO[id] = { label, icon, color }; });

    // the apps that come in the next updates
    const SOON = {
        orders: ['later', 'طلبات التعديل من الزبائن: تأتي مع تحديث التعديل.'],
        diagnostics: ['later', 'فحص المركبة (الفرامل، الزيت، الكلتش، الإطارات...): يأتي مع تحديث الصيانة.'],
        parts: ['later', 'متجر القطع: يأتي مع تحديث الصيانة.'],
        dyno: ['later', 'الداينو: يأتي مع تحديث التعديل.'],
    };

    function badgeOf(id) {
        if (id === 'chat') return S.badges.chat || 0;
        if (id === 'forms') return S.badges.forms || 0;
        return 0;
    }

    function appIcon(id, withLabel = true) {
        const a = INFO[id];
        const b = badgeOf(id);
        return `<button class="pt-app" data-act="open" data-app="${id}">
            <i class="pt-ic ${a.color}">${I(a.icon, 26, 1.8)}${b ? `<em class="pt-badge">${b > 99 ? '99+' : b}</em>` : ''}</i>
            ${withLabel ? `<span>${esc(a.label)}</span>` : ''}
        </button>`;
    }

    function dateLine() {
        const d = dateOf(now());
        return `${DAYS[d.getDay()]}، ${d.getDate()} ${MONTHS[d.getMonth()]}`;
    }

    function statusIcons() {
        const total = (S.badges.chat || 0) + (S.badges.forms || 0);
        return `<div class="pt-sicons">
            <span class="pt-mail">${I('mail', 18, 1.8)}${total ? `<em>${total > 9 ? '9+' : total}</em>` : ''}</span>
            <span class="pt-bars"><i></i><i></i><i></i><i></i></span>
            <span class="pt-batt"><i></i></span>
        </div>`;
    }

    function homeView() {
        const pages = HOME.map((pg) => `<div class="pt-grid">${pg.map(([id]) => appIcon(id)).join('')}</div>`).join('');
        return `<div class="pt-home">
            <div class="pt-hstatus">
                <div class="pt-hclock"><b id="pt-clock">${esc(S.clock)}</b><small>${esc(dateLine())}</small></div>
                ${statusIcons()}
            </div>
            <div class="pt-pages"><div class="pt-track" style="transform: translateX(${S.page * 100}%)">${pages}</div></div>
            <div class="pt-dots">${HOME.map((_, i) => `<button data-act="page" data-p="${i}" class="${i === S.page ? 'on' : ''}"></button>`).join('')}</div>
            <div class="pt-dock">${DOCK.map((id) => appIcon(id, false)).join('')}</div>
        </div>`;
    }

    // the frame every app sits in: back, small title, big title, something on the other side
    function head(sub, title, meta, extra) {
        return `<header class="pt-ahead">
            <button class="pt-back" data-act="home" title="رجوع">${I('back', 20, 2.2)}</button>
            <div class="pt-titles"><small>${esc(sub)}</small><h1>${esc(title)}</h1></div>
            <div class="pt-meta">${meta || ''}</div>
            ${extra || ''}
        </header>`;
    }
    const metaBox = (label, value, id) => `<div class="pt-metabox"><small>${esc(label)}</small><b${id ? ` id="${id}"` : ''}>${esc(value)}</b></div>`;

    function soonView(id) {
        const a = INFO[id];
        const [when, text] = SOON[id];
        return `<div class="pt-appwin">${head(when === 'round' ? 'السجلات' : 'قريبًا', a.label)}
            <div class="pt-abody"><div class="pt-empty big">
                <i class="pt-ic ${a.color} lg">${I(a.icon, 38, 1.7)}</i>
                <h3>قريبًا</h3>
                <p>${esc(text)}</p>
                <span class="pt-chip">${when === 'round' ? 'يجهز في التحديث القادم' : 'في تحديث لاحق'}</span>
            </div></div></div>`;
    }

    // ------------------------------------------------------------------
    // the pieces over everything: question sheet, message, picture viewer
    // ------------------------------------------------------------------
    function sheetView() {
        const s = S.sheet;
        if (!s) return '';
        const input = s.input ? `<label class="pt-field"><span>${esc(s.input.label || '')}</span>
            <input class="pt-in ${s.input.ltr ? 'ltr' : ''}" data-model="sheet.input.value" data-enter="sheetOk" value="${esc(s.input.value || '')}" placeholder="${esc(s.input.placeholder || '')}" ${s.input.type === 'number' ? 'inputmode="numeric"' : ''} maxlength="${s.input.max || 60}"></label>` : '';
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="sheetCancel"></div>
            <div class="pt-modal small">
                <div class="pt-mhead"><div><small>${esc(s.sub || 'تأكيد')}</small><h2>${esc(s.title)}</h2></div><button class="pt-x" data-act="sheetCancel">${I('x', 16, 2.2)}</button></div>
                ${s.text ? `<p class="pt-mtext">${esc(s.text)}</p>` : ''}
                ${input}
                <div class="pt-mfoot"><button class="pt-btn ghost" data-act="sheetCancel">إلغاء</button><button class="pt-btn ${s.danger ? 'danger' : 'primary'}" data-act="sheetOk">${esc(s.ok || 'تأكيد')}</button></div>
            </div></div>`;
    }

    function toastView() {
        if (!S.toast) return '';
        return `<div class="pt-toast ${S.toast.type || ''}">${I(S.toast.type === 'error' ? 'alert' : 'check', 16, 2.2)}<span>${esc(S.toast.text)}</span></div>`;
    }

    function viewerView() {
        const u = safeUrl(S.viewer);
        if (!u) return '';
        return `<div class="pt-layer"><div class="pt-backdrop dark" data-act="viewerClose"></div>
            <div class="pt-viewer"><img src="${esc(u)}" alt=""><button class="pt-x" data-act="viewerClose">${I('x', 16, 2.2)}</button></div></div>`;
    }

    // ------------------------------------------------------------------
    // drawing
    // ------------------------------------------------------------------
    function wallStyle() {
        const u = safeUrl(S.settings.wallpaper);
        return u ? `--wall: url("${u}")` : '';
    }

    let afterHooks = [];
    function after(fn) { afterHooks.push(fn); }

    function render() {
        if (!S.open) { os.innerHTML = ''; return; }
        // keep the box you are typing in, and where each list was scrolled
        const active = document.activeElement;
        let keep = null;
        if (active && os.contains(active) && active.dataset && active.dataset.model) {
            keep = { key: active.dataset.model };
            try { keep.s = active.selectionStart; keep.e = active.selectionEnd; } catch (_) { /* not a text box */ }
        }
        os.className = `pt-os ${S.settings.mode === 'light' ? 'light' : 'dark'}${S.app ? ' in-app' : ''}`;
        os.setAttribute('style', wallStyle());
        const a = S.app && APPS[S.app];
        afterHooks = [];
        let body;
        if (!S.app) body = homeView();
        else if (SOON[S.app]) body = soonView(S.app);
        else if (a) body = a.view();
        else body = homeView();
        os.innerHTML = body + sheetView() + viewerView() + toastView();
        os.querySelectorAll('[data-scroll]').forEach((el) => {
            const top = S.scrolls[el.dataset.scroll];
            if (top) el.scrollTop = top;
        });
        afterHooks.forEach((fn) => { try { fn(); } catch (err) { console.error(err); } });
        if (keep) {
            const el = os.querySelector(`[data-model="${keep.key}"]`);
            if (el) {
                el.focus({ preventScroll: true });
                try { if (keep.s != null) el.setSelectionRange(keep.s, keep.e); } catch (_) { /* not a text box */ }
            }
        }
        if (!MIRROR) pushMirror();
    }

    // ------------------------------------------------------------------
    // the mirror copy
    // ------------------------------------------------------------------
    let lastMirror = '';
    let mirrorTimer = null;
    function pushMirror() {
        if (!inGame || MIRROR) return;
        clearTimeout(mirrorTimer);
        mirrorTimer = setTimeout(() => {
            const json = JSON.stringify(S);
            if (json === lastMirror) return;
            lastMirror = json;
            post('ptMirror', { s: json });
        }, 30);
    }
    const lastUi = {};
    function mirrorUi(msg, every) {
        if (!inGame || MIRROR) return;
        const t = Date.now();
        if (every && t - (lastUi[msg.type] || 0) < every) return;
        lastUi[msg.type] = t;
        post('ptMirrorUi', msg);
    }

    const mirrorHandlers = {};
    function onMirror(type, fn) { mirrorHandlers[type] = fn; }

    function applyMirror(msg) {
        if (msg.type === 'state' && msg.s) {
            const next = typeof msg.s === 'string' ? JSON.parse(msg.s) : msg.s;
            Object.keys(S).forEach((k) => { if (!(k in next)) delete S[k]; });
            Object.assign(S, next);
            render();
        } else if (msg.type === 'clock') {
            S.clock = msg.t || '';
            const c = $('pt-clock');
            if (c) c.textContent = S.clock;
        } else if (msg.type === 'scroll') {
            const el = os.querySelector(`[data-scroll="${msg.key}"]`);
            if (el) el.scrollTop = msg.top || 0;
        } else if (mirrorHandlers[msg.type]) {
            mirrorHandlers[msg.type](msg);
        }
    }

    // ------------------------------------------------------------------
    // the shared actions
    // ------------------------------------------------------------------
    let toastTimer = null;
    function toast(text, type) {
        S.toast = { text, type };
        render();
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { S.toast = null; render(); }, 2600);
    }
    const fail = (res) => toast(errText(res && res.e), 'error');

    let sheetFn = null;
    // ask first: ask({ title, text, ok, danger, input: { label, value, placeholder, type, max } }, (value) => ...)
    function ask(opts, fn) {
        S.sheet = { title: opts.title, sub: opts.sub, text: opts.text, ok: opts.ok, danger: !!opts.danger, input: opts.input ? { ...opts.input, value: opts.input.value || '' } : null };
        sheetFn = fn;
        render();
    }

    function openApp(id) {
        if (!INFO[id] && !APPS[id]) return;
        const prev = S.app && APPS[S.app];
        if (prev && prev.leave) prev.leave();
        S.app = id;
        S.scrolls = {};
        const a = APPS[id];
        if (a && a.enter) a.enter();
        render();
    }
    function goHome() {
        const prev = S.app && APPS[S.app];
        if (prev && prev.leave) prev.leave();
        S.app = null;
        S.scrolls = {};
        render();
    }

    const ACT = {
        home: () => goHome(),
        open: (el) => openApp(el.dataset.app),
        page: (el) => { S.page = Number(el.dataset.p) || 0; render(); },
        sheetCancel: () => { S.sheet = null; sheetFn = null; render(); },
        sheetOk: () => {
            const fn = sheetFn;
            const value = S.sheet && S.sheet.input ? S.sheet.input.value : undefined;
            S.sheet = null;
            sheetFn = null;
            render();
            if (fn) fn(value);
        },
        viewerClose: () => { S.viewer = null; render(); },
        view: (el) => { S.viewer = el.dataset.url; render(); },
    };

    // set S.a.b.c from "a.b.c"
    function setPath(path, value) {
        const keys = path.split('.');
        let o = S;
        for (let i = 0; i < keys.length - 1; i++) {
            if (o[keys[i]] == null || typeof o[keys[i]] !== 'object') return;
            o = o[keys[i]];
        }
        o[keys[keys.length - 1]] = value;
    }

    function runAct(name, el, ev) {
        const a = S.app && APPS[S.app];
        const fn = (a && a.act && a.act[name]) || ACT[name];
        if (fn) fn(el, ev);
    }

    return {
        MIRROR, inGame, RES, S, os, host, $, esc, money, list, initials, safeUrl, pad, now, dateOf, fmtDate, fmtTime, fmtStamp, ago,
        DAYS, MONTHS, I, svg, post, call, mock, ERR, errText, app, APPS, INFO, head, metaBox, render, after, pushMirror, mirrorUi,
        onMirror, applyMirror, toast, fail, ask, openApp, goHome, ACT, setPath, runAct, fresh,
    };
})();
