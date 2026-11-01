// EX_Tii Mechanic tablet — the tools: Camera, Gallery, Settings (light / dark, wallpaper),
// Calculator, and the small "pick a photo from your gallery" window the other apps use.
(() => {
    const { S, I, esc, call, render, toast, fail, ask, post, head, metaBox, safeUrl, ACT, fmtStamp } = PT;

    S.gal = { items: [], page: 0, open: null, loaded: false };
    S.pick = null;            // { for: 'msg' | 'group' | 'wall', page }
    S.set = { url: '' };
    S.calc = { expr: '', out: '' };
    S.camFrom = null;

    const PER = 12;           // photos per page (4 x 3, like the video)
    const photos = () => PT.list(S.gal.items);
    const pages = () => Math.max(1, Math.ceil(photos().length / PER));

    function loadGallery(then) {
        call('gallery').then((res) => {
            if (res.ok) {
                S.gal.items = PT.list(res.r);
                S.gal.loaded = true;
                if (S.gal.page >= pages()) S.gal.page = pages() - 1;
            }
            if (then) then(res);
            render();
        });
    }
    PT.loadGallery = loadGallery;

    // ------------------------------------------------------------------
    // the picker (chat photos, group photo, wallpaper)
    // ------------------------------------------------------------------
    const onPick = {};
    PT.onPick = onPick;
    PT.pick = (forKey) => {
        S.pick = { for: forKey, page: 0 };
        if (!S.gal.loaded) loadGallery(); else render();
        render();
    };

    PT.pickerView = () => {
        const p = S.pick;
        if (!p) return '';
        const all = photos();
        const total = Math.max(1, Math.ceil(all.length / PER));
        const page = Math.min(p.page, total - 1);
        const items = all.slice(page * PER, page * PER + PER);
        const body = all.length ? `<div class="pt-pgrid">${items.map((g) => `<button class="pt-pcell" data-act="pickPhoto" data-url="${esc(g.url)}"><img src="${esc(safeUrl(g.url))}" alt="" loading="lazy"></button>`).join('')}</div>
            <div class="pt-pager"><button class="pt-btn ghost xs" data-act="pickPage" data-d="-1" ${page <= 0 ? 'disabled' : ''}>السابق</button><span>الصفحة ${page + 1} من ${total}</span><button class="pt-btn ghost xs" data-act="pickPage" data-d="1" ${page >= total - 1 ? 'disabled' : ''}>التالي</button></div>`
            : `<div class="pt-empty"><i>${I('image', 30, 1.7)}</i><h3>معرضك فارغ</h3><p>افتح تطبيق الكاميرا والتقط صورة أولًا.</p></div>`;
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="pickClose"></div>
            <div class="pt-modal wide">
                <div class="pt-mhead"><div><small>المعرض</small><h2>اختر صورة</h2></div><button class="pt-btn ghost xs" data-act="pickClose">إغلاق</button></div>
                ${body}
            </div></div>`;
    };

    ACT.pickClose = () => { S.pick = null; render(); };
    ACT.pickPage = (el) => { if (S.pick) { S.pick.page = Math.max(0, S.pick.page + Number(el.dataset.d)); render(); } };
    ACT.pickPhoto = (el) => {
        const p = S.pick;
        S.pick = null;
        const url = safeUrl(el.dataset.url);
        if (p && url && onPick[p.for]) onPick[p.for](url);
        else render();
    };

    // ------------------------------------------------------------------
    // the camera: the tablet goes down, the game takes the photo (client/tablet.lua)
    // ------------------------------------------------------------------
    PT.app('camera', {
        view: () => `<div class="pt-appwin">${head('الكاميرا', 'التصوير')}<div class="pt-abody"><div class="pt-empty big">
            <i class="pt-ic dark lg">${PT.I('camera', 38, 1.7)}</i><h3>الكاميرا مفتوحة</h3><p>صوّب بالكاميرا ثم اضغط E أو زر الماوس الأيسر. Backspace للرجوع.</p></div></div></div>`,
        enter() {
            if (!PT.inGame) { toast('الكاميرا تعمل داخل اللعبة فقط', 'error'); return; }
            post('ptCamera');
        },
    });
    // back from the camera (with the new photo, or nothing if you went back)
    PT.cameraDone = (result) => {
        const from = S.camFrom;
        S.camFrom = null;
        if (result && result.gallery) {
            S.gal.items = PT.list(result.gallery);
            S.gal.loaded = true;
            S.gal.page = 0;
            PT.openApp('gallery');
            // open the new photo from the list, so it has its number (and the delete button)
            const url = safeUrl(result.url) ? result.url : null;
            S.gal.open = url ? (photos().find((p) => p.url === url) || { url, created: PT.now() }) : null;
            render();
            return;
        }
        if (from && from !== 'camera') PT.openApp(from); else PT.goHome();
    };

    // ------------------------------------------------------------------
    // the gallery
    // ------------------------------------------------------------------
    function galleryView() {
        const g = S.gal;
        const all = photos();
        const total = pages();
        const page = Math.min(g.page, total - 1);
        const items = all.slice(page * PER, page * PER + PER);
        const open = g.open && safeUrl(g.open.url) ? g.open : null;
        const grid = all.length ? `<div class="pt-ggrid">${items.map((p) => `<button class="pt-gcell" data-act="galOpen" data-id="${p.id}"><img src="${esc(safeUrl(p.url))}" alt="" loading="lazy"><small class="ltr">${esc(PT.fmtDate(p.created))}</small></button>`).join('')}</div>
            <div class="pt-pager"><button class="pt-btn ghost xs" data-act="galPage" data-d="-1" ${page <= 0 ? 'disabled' : ''}>السابق</button><span>الصفحة ${page + 1} من ${total}</span><button class="pt-btn ghost xs" data-act="galPage" data-d="1" ${page >= total - 1 ? 'disabled' : ''}>التالي</button></div>`
            : `<div class="pt-empty big"><i class="pt-ic silver lg">${I('image', 38, 1.7)}</i><h3>${g.loaded ? 'لا توجد صور بعد' : 'جارٍ التحميل…'}</h3><p>الصور التي تلتقطها بكاميرا التابلت تُحفظ هنا، وتستطيع إرسالها في المحادثات.</p></div>`;
        const viewer = open ? `<div class="pt-layer"><div class="pt-backdrop dark" data-act="galClose"></div>
            <div class="pt-photo"><img src="${esc(safeUrl(open.url))}" alt="">
                <div class="pt-photobar"><span class="ltr">${esc(fmtStamp(open.created || PT.now()))}</span>
                    <div><button class="pt-btn ghost sm" data-act="galWall">${I('image', 15, 2)} خلفية للتابلت</button>
                    ${open.id ? `<button class="pt-btn danger sm" data-act="galDelete">${I('trash', 15, 2)} حذف</button>` : ''}
                    <button class="pt-btn ghost sm" data-act="galClose">إغلاق</button></div></div></div></div>` : '';
        return `<div class="pt-appwin">${head('الصور', 'المعرض', metaBox('الصور', String(all.length)),
            `<button class="pt-btn primary sm pt-headbtn" data-act="galSnap">${I('camera', 16, 2)} التقاط صورة</button>`)}
            <div class="pt-abody pad" data-scroll="gal">${grid}</div>${viewer}</div>`;
    }

    PT.app('gallery', {
        view: galleryView,
        enter() { S.gal.open = null; loadGallery(); },
        act: {
            galPage: (el) => { S.gal.page = Math.max(0, Math.min(pages() - 1, S.gal.page + Number(el.dataset.d))); render(); },
            galOpen: (el) => { S.gal.open = photos().find((p) => p.id === Number(el.dataset.id)) || null; render(); },
            galClose: () => { S.gal.open = null; render(); },
            galSnap: () => { S.camFrom = 'gallery'; PT.openApp('camera'); },
            galWall: () => {
                const url = S.gal.open && S.gal.open.url;
                if (url) saveSettings({ mode: S.settings.mode, wallpaper: url }, 'صارت هذه الصورة خلفية التابلت');
            },
            galDelete: () => {
                const p = S.gal.open;
                if (!p || !p.id) return;
                ask({ title: 'حذف الصورة؟', text: 'تُحذف من معرضك. الرسائل التي أُرسلت فيها تبقى كما هي.', ok: 'حذف', danger: true }, () => {
                    call('galleryDelete', p.id).then((res) => {
                        if (!res.ok) return fail(res);
                        S.gal.items = PT.list(res.r);
                        S.gal.open = null;
                        if (S.gal.page >= pages()) S.gal.page = pages() - 1;
                        toast('حُذفت الصورة');
                    });
                });
            },
        },
    });

    // ------------------------------------------------------------------
    // settings (Personalization)
    // ------------------------------------------------------------------
    function saveSettings(next, okText) {
        call('settingsSave', next).then((res) => {
            if (!res.ok) return fail(res);
            S.settings = { mode: res.r.mode === 'light' ? 'light' : 'dark', wallpaper: res.r.wallpaper || '' };
            toast(okText || 'تم الحفظ');
        });
    }
    onPick.wall = (url) => saveSettings({ mode: S.settings.mode, wallpaper: url }, 'تم تغيير الخلفية');

    function settingsView() {
        const st = S.settings;
        const wall = safeUrl(st.wallpaper);
        return `<div class="pt-appwin">${head('إعدادات التابلت', 'التخصيص', metaBox('الوضع', st.mode === 'light' ? 'فاتح' : 'داكن'))}
            <div class="pt-abody pad" data-scroll="set">
                <section class="pt-card row">
                    <div><h3>المظهر</h3><p>بدّل الواجهة بين الفاتح والداكن.</p></div>
                    <div class="pt-seg">
                        <button class="${st.mode === 'light' ? 'on' : ''}" data-act="setMode" data-m="light">${I('sun', 15, 2)} فاتح</button>
                        <button class="${st.mode !== 'light' ? 'on' : ''}" data-act="setMode" data-m="dark">${I('moon', 15, 2)} داكن</button>
                    </div>
                </section>
                <section class="pt-card">
                    <div class="pt-cardhead"><div><h3>الخلفية</h3><p>الخلفية الافتراضية، أو صورة من معرضك، أو رابط صورة من عندك.</p></div>
                        <button class="pt-btn ghost xs" data-act="setDefault" ${wall ? '' : 'disabled'}>استخدام الافتراضية</button></div>
                    <div class="pt-wallrow">
                        <div class="pt-wallprev ${wall ? 'img' : ''}" ${wall ? `style="background-image:url('${esc(wall)}')"` : ''}><span>${wall ? 'خلفية مخصصة' : 'الخلفية الافتراضية'}</span></div>
                        <div class="pt-wallside">
                            <button class="pt-btn ghost wide" data-act="setPick">${I('image', 16, 2)} اختر من المعرض</button>
                            <label class="pt-field"><span>رابط صورة</span>
                                <div class="pt-inrow"><input class="pt-in ltr" data-model="set.url" data-enter="setUrl" placeholder="https://example.com/wallpaper.jpg" maxlength="300" value="${esc(S.set.url)}"><button class="pt-btn ghost sm" data-act="setUrl">تطبيق</button></div></label>
                            <p class="pt-hint">أفضل نتيجة مع صور 1920x1080 أو أكبر.</p>
                        </div>
                    </div>
                </section>
            </div>${PT.pickerView()}</div>`;
    }

    PT.app('settings', {
        view: settingsView,
        enter() { S.set.url = ''; },
        act: {
            setMode: (el) => saveSettings({ mode: el.dataset.m === 'light' ? 'light' : 'dark', wallpaper: S.settings.wallpaper }, el.dataset.m === 'light' ? 'الوضع الفاتح' : 'الوضع الداكن'),
            setDefault: () => saveSettings({ mode: S.settings.mode, wallpaper: '' }, 'رجعت الخلفية الافتراضية'),
            setPick: () => PT.pick('wall'),
            setUrl: () => {
                const url = S.set.url.trim();
                if (!safeUrl(url)) return toast(PT.ERR.bad_url, 'error');
                S.set.url = '';
                saveSettings({ mode: S.settings.mode, wallpaper: url }, 'تم تغيير الخلفية');
            },
        },
    });

    // ------------------------------------------------------------------
    // calculator
    // ------------------------------------------------------------------
    // + − × ÷ with the usual order, brackets not needed
    function evaluate(expr) {
        const tokens = expr.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').match(/(\d+\.?\d*|\.\d+|[+\-*/%])/g);
        if (!tokens) return '';
        const nums = [];
        const ops = [];
        let expectNum = true;
        let neg = false;
        for (const t of tokens) {
            if (expectNum) {
                if (t === '-') { neg = !neg; continue; }
                if (!/[\d.]/.test(t)) return 'خطأ';
                nums.push(neg ? -parseFloat(t) : parseFloat(t));
                neg = false;
                expectNum = false;
            } else if (t === '%') {
                nums[nums.length - 1] /= 100;
            } else {
                ops.push(t);
                expectNum = true;
            }
        }
        if (expectNum && ops.length) ops.pop();
        // × and ÷ first
        const n2 = [nums[0]];
        const o2 = [];
        for (let i = 0; i < ops.length; i++) {
            const b = nums[i + 1];
            if (ops[i] === '*') n2[n2.length - 1] *= b;
            else if (ops[i] === '/') { if (b === 0) return 'خطأ'; n2[n2.length - 1] /= b; }
            else { o2.push(ops[i]); n2.push(b); }
        }
        let r = n2[0];
        for (let i = 0; i < o2.length; i++) r = o2[i] === '+' ? r + n2[i + 1] : r - n2[i + 1];
        if (!isFinite(r)) return 'خطأ';
        return String(Math.round(r * 1e8) / 1e8);
    }

    const KEYS = [['C', 'fn'], ['⌫', 'fn'], ['%', 'op'], ['÷', 'op'], ['7'], ['8'], ['9'], ['×', 'op'], ['4'], ['5'], ['6'], ['−', 'op'], ['1'], ['2'], ['3'], ['+', 'op'], ['±', 'fn'], ['0'], ['.'], ['=', 'eq']];

    function press(k) {
        const c = S.calc;
        if (k === 'C') { c.expr = ''; c.out = ''; }
        else if (k === '⌫') { c.expr = [...c.expr].slice(0, -1).join(''); c.out = ''; }
        else if (k === '=') { const r = evaluate(c.expr); c.out = r; if (r && r !== 'خطأ') c.expr = r; }
        else if (k === '±') { c.expr = c.expr.startsWith('−') ? c.expr.slice(1) : (c.expr ? `−${c.expr}` : c.expr); }
        else {
            if (c.expr.length >= 32) return;
            const last = c.expr.slice(-1);
            if (/[+−×÷]/.test(k) && /[+−×÷]/.test(last)) c.expr = c.expr.slice(0, -1);
            c.expr += k;
            c.out = '';
        }
        render();
    }

    PT.app('calc', {
        view: () => {
            const c = S.calc;
            const live = c.out || (c.expr && /[+−×÷%]/.test(c.expr.slice(1)) ? evaluate(c.expr) : '');
            return `<div class="pt-appwin">${head('الأدوات', 'الحاسبة')}
                <div class="pt-abody"><div class="pt-calc">
                    <div class="pt-cdisp"><small class="ltr">${esc(c.out ? '' : live)}</small><b class="ltr">${esc(c.expr || '0')}</b></div>
                    <div class="pt-ckeys">${KEYS.map(([k, kind]) => `<button class="${kind || ''}" data-act="calcKey" data-k="${esc(k)}">${esc(k)}</button>`).join('')}</div>
                </div></div></div>`;
        },
        act: { calcKey: (el) => press(el.dataset.k) },
        key(e) {
            const map = { '*': '×', '/': '÷', '-': '−', Enter: '=', '=': '=', Backspace: '⌫', Delete: 'C', ',': '.' };
            const k = map[e.key] || e.key;
            if (/^[0-9.+%]$/.test(k) || ['×', '÷', '−', '=', '⌫', 'C'].includes(k)) { e.preventDefault(); press(k); return true; }
            return false;
        },
    });

    PT.saveSettings = saveSettings;
})();
