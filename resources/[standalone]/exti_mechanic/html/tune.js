// =====================================================================
// Tuning menu (the customer on a tuning bay): performance, paint, wheels, body, lights, the rest.
// Every pick is shown on the car straight away; the order is checked and priced again by the server.
// =====================================================================
const Tune = (() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const post = (name, data) => {
        if (!RES) return Promise.resolve(Tune.fake ? Tune.fake(name, data) : null);
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
            .then((r) => r.json()).catch(() => null);
    };
    const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => `<bdi dir="ltr">$${Math.round(n || 0).toLocaleString('en-US')}</bdi>`;
    const hex = (c) => '#' + arr(c).slice(0, 3).map((v) => Math.max(0, Math.min(255, v | 0)).toString(16).padStart(2, '0')).join('');
    const rgbOf = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
    // the same value? (key order does not matter: the game sends its tables in any order)
    const canon = (x) => (Array.isArray(x) ? `[${x.map(canon).join(',')}]` : x && typeof x === 'object'
        ? `{${Object.keys(x).sort().map((k) => `${k}:${canon(x[k])}`).join(',')}}` : JSON.stringify(x));
    const same = (a, b) => canon(a) === canon(b);

    const SVG = (d) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
    const CATS = [
        ['perf', 'الأداء', SVG('<path d="M4 16a8 8 0 1 1 16 0"/><path d="M12 16l4-5"/>')],
        ['paint', 'الصبغ', SVG('<path d="M4 20c4 0 5-3 5-5l8-8a2 2 0 0 0-3-3l-8 8c-2 0-5 1-5 5"/><path d="M13 5l6 6"/>')],
        ['wheels', 'الجنوط', SVG('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/><path d="M12 3v6M12 15v6M3 12h6M15 12h6"/>')],
        ['body', 'الهيكل', SVG('<path d="M3 15l2-5 3-3h8l3 3 2 5v3H3z"/><circle cx="7.5" cy="17" r="1.5"/><circle cx="16.5" cy="17" r="1.5"/>')],
        ['lights', 'الإضاءة', SVG('<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.5 1 2.5h6c0-1 .3-1.8 1-2.5A6 6 0 0 0 12 3z"/>')],
        ['other', 'أخرى', SVG('<circle cx="12" cy="12" r="1"/><circle cx="5" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>')],
    ];
    const FINISH = ['عادي', 'معدني', 'لؤلؤي', 'مطفي', 'معدن', 'كروم'];
    const SWATCH = ['#0b0b0d', '#f4f4f4', '#9ea3a8', '#4a4e54', '#c4141c', '#6e0c12', '#e8621a', '#f5c518', '#c9a227', '#86d11f', '#1f8a3a', '#123d2a',
        '#14a3a3', '#3fa7f5', '#1e4fd6', '#0e1b45', '#6a2bd1', '#f06ab8', '#ff1f8e', '#5a3a22', '#d9c7a1', '#8c5a2b', '#e8d6b0', '#4b5320'];
    // the game's own colour list (for the pearl and the wheels): [id, name, colour]
    const GTA = [[0, 'أسود', '#0d1116'], [1, 'أسود غرافيت', '#1c1d21'], [3, 'فضي غامق', '#454b4f'], [4, 'فضي', '#999da0'], [5, 'فضي مزرق', '#c2c4c6'],
        [7, 'فضي ظل', '#637380'], [10, 'رصاصي', '#444e54'], [27, 'أحمر', '#c00e1a'], [28, 'أحمر تورينو', '#da1918'], [30, 'أحمر لهب', '#a51e23'],
        [31, 'أحمر نبيذي', '#7b1a22'], [36, 'برتقالي شروق', '#d44a17'], [38, 'برتقالي', '#f78616'], [88, 'أصفر', '#ffcf20'], [89, 'أصفر سباق', '#fbe212'],
        [92, 'ليموني', '#98d223'], [53, 'أخضر', '#155c2d'], [50, 'أخضر سباق', '#122e2b'], [55, 'أخضر فاتح', '#66b81f'], [70, 'أزرق فاتح', '#0b9cf1'],
        [64, 'أزرق', '#47578f'], [62, 'أزرق غامق', '#233155'], [61, 'كحلي', '#222e46'], [145, 'بنفسجي', '#621276'], [135, 'وردي فاقع', '#f21f99'],
        [137, 'وردي', '#df5891'], [90, 'برونزي', '#916532'], [96, 'بني شوكولا', '#221b19'], [111, 'أبيض', '#fffff6'], [112, 'أبيض ثلجي', '#eaeaea'],
        [120, 'كروم', '#5870a1'], [158, 'ذهبي', '#7a5f2b'], [159, 'ذهبي مصقول', '#a37d3a']];
    const XENON = [[-1, 'الأصلي', '#e9eef7'], [0, 'أبيض', '#ffffff'], [1, 'أزرق', '#2f6dff'], [2, 'أزرق كهربائي', '#36b9ff'], [3, 'أخضر نعناعي', '#5effb8'],
        [4, 'أخضر ليموني', '#a3ff3a'], [5, 'أصفر', '#ffe53a'], [6, 'ذهبي', '#ffb92e'], [7, 'برتقالي', '#ff7a1f'], [8, 'أحمر', '#ff2a2a'],
        [9, 'وردي', '#ff7ac8'], [10, 'وردي فاقع', '#ff2fa0'], [11, 'بنفسجي', '#9a4dff'], [12, 'بلاك لايت', '#5b2bff']];
    const TINTS = ['بدون', 'أسود كامل', 'دخاني غامق', 'دخاني فاتح', 'الأصلي', 'ليموزين', 'أخضر'];
    const PLATES = ['أزرق على أبيض', 'أصفر على أسود', 'أصفر على أزرق', 'أزرق على أبيض 2', 'أزرق على أبيض 3', 'يانكتون'];
    // where the camera goes for each body part
    const BODY_VIEW = { 0: 'rear', 1: 'front', 2: 'rear', 3: 'side', 4: 'rear', 5: 'inside', 6: 'front', 7: 'front', 8: 'side', 9: 'side', 10: 'top',
        14: 'front', 25: 'rear', 27: 'inside', 28: 'inside', 29: 'inside', 30: 'inside', 32: 'inside', 33: 'inside', 34: 'inside', 37: 'rear',
        39: 'front', 40: 'front', 42: 'side', 43: 'top', 45: 'rear', 46: 'side', 48: 'three' };

    let root, panel, D = null, ch = {}, cat = 'perf', sub = 'paint1', bodyOpen = null, wheelType = null, wheelList = null, review = false, busy = false, err = '', lights = false;
    const scrolls = {};

    // ------------------------------------------------------------------
    // prices (the same rules as the server)
    // ------------------------------------------------------------------
    const P = (k) => Math.max(0, Number((D.prices || {})[k]) || 0);
    function levelPrice(key, level) {
        for (let l = level; l >= 1; l--) if ((D.prices || {})[`${key}_${l}`] != null) return P(`${key}_${l}`);
        return 0;
    }
    const car = () => D.car;
    const perfNow = (p) => (p.saved != null ? p.saved : p.cur);

    // aftermarket rims on the car or picked (the game paints only those)
    const stockRims = () => !(ch.wheels && ch.wheels.i >= 0) && !(car().wheels && car().wheels.i >= 0);

    function lines() {
        const out = [];
        const c = car();
        arr(c.perf).forEach((p) => {
            if (ch[p.key] === undefined) return;
            const v = ch[p.key], now = perfNow(p);
            if (v === now) return;
            out.push(v > now ? { label: `${p.label}: المستوى ${v + 1}`, price: levelPrice(p.key, v + 1) }
                : { label: `${p.label}: إرجاع إلى ${v < 0 ? 'الأصلي' : `المستوى ${v + 1}`}`, price: P('remove') });
        });
        if (ch.turbo !== undefined && ch.turbo !== c.turbo) out.push({ label: ch.turbo ? 'تيربو' : 'إزالة التيربو', price: ch.turbo ? P('turbo') : P('remove') });
        if (ch.nitro !== undefined && ch.nitro !== !!c.nitro) out.push({ label: ch.nitro ? 'نظام النيترو' : 'إزالة النيترو', price: ch.nitro ? P('nitro') : P('remove') });
        if (ch.swap !== undefined && ch.swap !== (c.swap || 'stock')) {
            const e = arr(c.engines).find((x) => x.id === ch.swap);
            out.push(ch.swap === 'stock' ? { label: 'إرجاع المحرك الأصلي', price: P('swap_stock') } : { label: `تبديل المحرك: ${e ? e.label : ch.swap}`, price: P(`swap_${ch.swap}`) });
        }
        if (ch.paint1) out.push({ label: `الصبغ الأساسي (${FINISH[ch.paint1.t]})`, price: P('paint1'), color: hex(ch.paint1.c) });
        if (ch.paint2) out.push({ label: `الصبغ الثانوي (${FINISH[ch.paint2.t]})`, price: P('paint2'), color: hex(ch.paint2.c) });
        if (ch.pearl !== undefined) out.push({ label: 'اللمعة (البيرل)', price: P('pearl') });
        if (ch.wheelColor !== undefined && !stockRims()) out.push({ label: 'لون الجنوط', price: P('wheelColor') });
        if (ch.wheels) out.push({ label: `جنوط: ${ch.wheels.n}`, price: P('wheels') });
        Object.keys(ch.body || {}).forEach((mod) => {
            const b = arr(c.body).find((x) => String(x.mod) === mod);
            if (b) out.push({ label: `${b.label}: ${ch.body[mod].n}`, price: P(b.price || 'body') });
        });
        if (ch.tint !== undefined) out.push({ label: `تظليل: ${TINTS[ch.tint]}`, price: P('tint') });
        if (ch.neon) out.push(ch.neon.on !== c.neon.on ? { label: ch.neon.on ? 'تركيب النيون' : 'إزالة النيون', price: P('neon'), color: hex(ch.neon.c) }
            : { label: 'لون النيون', price: P('neonColor'), color: hex(ch.neon.c) });
        if (ch.xenon) out.push(ch.xenon.on !== c.xenon.on ? { label: ch.xenon.on ? 'تركيب الزينون' : 'إزالة الزينون', price: P('xenon') }
            : { label: 'لون الزينون', price: P('xenonColor') });
        if (ch.plate !== undefined) out.push({ label: 'شكل اللوحة', price: P('plate') });
        return out;
    }
    const total = () => lines().reduce((a, l) => a + l.price, 0);

    // ------------------------------------------------------------------
    // picking (shows it on the car; picking what the car has removes the change)
    // ------------------------------------------------------------------
    function pick(k, v, orig) {
        if (same(v, orig)) delete ch[k]; else ch[k] = v;
        post('tunePreview', { k, v });
    }
    function pickBody(b, i, n) {
        ch.body = ch.body || {};
        if (i === b.cur) delete ch.body[b.mod]; else ch.body[b.mod] = { i, n };
        if (!Object.keys(ch.body).length) delete ch.body;
        post('tunePreview', { k: 'body', v: { mod: b.mod, i } });
    }
    function cam(view) { post('tuneCam', { view }); }

    function goCat(id) {
        cat = id;
        bodyOpen = null;
        post('tunePreview', { k: 'hood', v: id === 'perf' });
        if (id === 'perf') cam('front');
        else if (id === 'paint') cam('three');
        else if (id === 'wheels') { cam('wheel'); if (wheelType == null) loadWheels(ch.wheels ? ch.wheels.t : car().wheels.t); }
        else if (id === 'body') cam('three');
        else if (id === 'lights') { cam('front'); }
        else cam('rear');
        render();
    }

    function loadWheels(t) {
        wheelType = t;
        wheelList = null;
        render();
        post('tuneWheels', { t }).then((r) => {
            if (wheelType !== t) return;
            wheelList = r ? arr(r.list) : [];
            render();
            // the car shows what is picked (or its own wheels) on that kind
            const w = car().wheels;
            const sel = ch.wheels && ch.wheels.t === t ? ch.wheels.i : (w.t === t ? w.i : -1);
            post('tunePreview', { k: 'wheels', v: { t, i: sel, bike: w.bike } });
        });
    }

    // ------------------------------------------------------------------
    // the views
    // ------------------------------------------------------------------
    const chip = (attrs, on, inner, extra = '') => `<button class="tn-chip${on ? ' on' : ''}${extra}" ${attrs}>${inner}</button>`;
    const tag = (text, kind = '') => `<em class="tn-tag ${kind}">${text}</em>`;

    function perfView() {
        const c = car();
        if (!arr(c.perf).length) return '<p class="tn-mute">هذه السيارة لا تقبل تعديلات أداء.</p>';
        const rows = arr(c.perf).map((p) => {
            const now = perfNow(p);
            const sel = ch[p.key] !== undefined ? ch[p.key] : now;
            const chips = [];
            for (let l = -1; l < p.n; l++) {
                const price = l === now ? tag('مركّب', 'ok') : l > now ? money(levelPrice(p.key, l + 1)) : money(P('remove'));
                chips.push(chip(`data-act="perf" data-k="${p.key}" data-v="${l}"`, l === sel, `<b>${l < 0 ? 'الأصلي' : `مستوى ${l + 1}`}</b><small>${price}</small>`, ' lvl'));
            }
            return `<div class="tn-row"><h4>${esc(p.label)}</h4><div class="tn-chips">${chips.join('')}</div></div>`;
        });
        const tsel = ch.turbo !== undefined ? ch.turbo : c.turbo;
        rows.push(`<div class="tn-row"><h4>التيربو</h4><div class="tn-chips">
            ${chip('data-act="turbo" data-v="0"', !tsel, `<b>بدون</b><small>${!c.turbo ? tag('الآن', 'ok') : money(P('remove'))}</small>`, ' lvl')}
            ${chip('data-act="turbo" data-v="1"', tsel, `<b>تيربو</b><small>${c.turbo ? tag('مركّب', 'ok') : money(P('turbo'))}</small>`, ' lvl')}
        </div></div>`);
        // nitro
        const nsel = ch.nitro !== undefined ? ch.nitro : !!c.nitro;
        rows.push(`<div class="tn-row"><h4>النيترو</h4><div class="tn-chips">
            ${chip('data-act="nitro" data-v="0"', !nsel, `<b>بدون</b><small>${!c.nitro ? tag('الآن', 'ok') : money(P('remove'))}</small>`, ' lvl')}
            ${chip('data-act="nitro" data-v="1"', nsel, `<b>نيترو</b><small>${c.nitro ? tag('مركّب', 'ok') : money(P('nitro'))}</small>`, ' lvl')}
        </div><p class="tn-hint">اضغط Shift الأيسر مع البنزين للدفعة. الأسطوانة تكفي 15 ثانية، والميكانيكي يعبّئها.</p></div>`);
        // engine swap
        const engines = arr(c.engines);
        if (engines.length) {
            const now = c.swap || 'stock';
            const sel = ch.swap !== undefined ? ch.swap : now;
            const list = [['stock', 'الأصلي'], ...engines.map((e) => [e.id, e.label])];
            rows.push(`<div class="tn-row"><h4>تبديل المحرك <button class="tn-mini" data-act="rev">اسمع الصوت</button></h4><div class="tn-chips">
                ${list.map(([id, label]) => chip(`data-act="swap" data-v="${id}"`, id === sel, `<b>${esc(label)}</b><small>${id === now ? tag(id === 'stock' ? 'الآن' : 'مركّب', 'ok') : money(id === 'stock' ? P('swap_stock') : P(`swap_${id}`))}</small>`, ' lvl')).join('')}
            </div><p class="tn-hint">صوت المحرك الجديد وقوته. اختر محركًا واضغط "اسمع الصوت".</p></div>`);
        }
        return rows.join('') + '<p class="tn-hint">كل مستوى أعلى يحتاج قطعة من الميكانيكي. الأداء لا يُرى بالعين: يظهر في القيادة.</p>';
    }

    function paintView() {
        const c = car();
        const subs = [['paint1', 'الأساسي'], ['paint2', 'الثانوي'], ['pearl', 'اللمعة'], ['wheelColor', 'لون الجنوط']];
        let body;
        if (sub === 'paint1' || sub === 'paint2') {
            const v = ch[sub] || c[sub];
            body = `<div class="tn-row"><h4>نوع الصبغ</h4><div class="tn-chips">${FINISH.map((f, i) => chip(`data-act="finish" data-v="${i}"`, v.t === i, `<b>${f}</b>`)).join('')}</div>
                ${v.t === 5 ? '<p class="tn-hint">الكروم مرآة: يعكس ما حوله ولا يُظهر اللون كثيرًا. داخل الورشة يبدو غامقًا وفي الشمس فضيًا.</p>' : ''}</div>
                <div class="tn-row"><h4>اللون <span class="tn-price">${money(P(sub))}</span></h4>
                <div class="tn-sw">${SWATCH.map((h) => `<button class="${hex(v.c) === h ? 'on' : ''}" data-act="color" data-h="${h}" style="--c:${h}"></button>`).join('')}</div>
                <label class="tn-pick"><input type="color" value="${hex(v.c)}" data-input="color"><span>لون خاص: <bdi dir="ltr">${hex(v.c).toUpperCase()}</bdi></span></label></div>`;
        } else {
            const cur = ch[sub] !== undefined ? ch[sub] : c[sub];
            // the game paints only aftermarket rims: on the car's own wheels the colour does nothing
            const stockRims = !(ch.wheels && ch.wheels.i >= 0) && !(c.wheels && c.wheels.i >= 0);
            if (sub === 'wheelColor' && stockRims) {
                if (ch.wheelColor !== undefined) { delete ch.wheelColor; post('tunePreview', { k: 'wheelColor', v: c.wheelColor }); }
                return `<div class="tn-sub">${subs.map(([id, l]) => chip(`data-act="sub" data-v="${id}"`, sub === id, l)).join('')}</div>
                    <div class="tn-row"><h4>لون الجنوط</h4><p class="tn-hint">لون الجنوط يظهر فقط على الجنوط المعدّلة. جنوط سيارتك الأصلية لا تتغير بالصبغ.</p>
                    <button class="tn-btn ghost" data-act="cat" data-v="wheels">اختر جنوطًا جديدة أولًا</button></div>`;
            }
            body = `<div class="tn-row"><h4>${sub === 'pearl' ? 'اللمعة فوق الصبغ' : 'لون الجنوط'} <span class="tn-price">${money(P(sub))}</span></h4>
                <div class="tn-sw named">${GTA.map(([id, name, h]) => `<button class="${cur === id ? 'on' : ''}" data-act="gta" data-v="${id}" style="--c:${h}" title="${esc(name)}"><i></i><span>${esc(name)}</span></button>`).join('')}</div></div>`;
        }
        return `<div class="tn-sub">${subs.map(([id, l]) => chip(`data-act="sub" data-v="${id}"`, sub === id, l)).join('')}</div>${body}`;
    }

    function wheelsView() {
        const c = car();
        const w = c.wheels;
        const t = wheelType != null ? wheelType : w.t;
        const sel = ch.wheels && ch.wheels.t === t ? ch.wheels.i : (w.t === t ? w.i : null);
        const types = `<div class="tn-chips">${arr(c.wheelTypes).map(([id, l]) => chip(`data-act="wtype" data-v="${id}"`, id === t, esc(l))).join('')}</div>`;
        let list = '<div class="tn-load"><span class="pt-spin"></span></div>';
        if (wheelList) {
            const items = [[-1, 'الأصلية'], ...wheelList.map((n, i) => [i, n])];
            list = `<div class="tn-list">${items.map(([i, n]) => `<button class="${i === sel ? 'on' : ''}" data-act="wheel" data-v="${i}" data-n="${esc(n)}">${esc(n)}${w.t === t && w.i === i ? tag('الآن', 'ok') : ''}</button>`).join('')}</div>`;
        }
        return `<div class="tn-row"><h4>النوع <span class="tn-price">${money(P('wheels'))}</span></h4>${types}</div><div class="tn-row"><h4>الجنط</h4>${list}</div>`;
    }

    function bodyView() {
        const c = car();
        const parts = arr(c.body);
        if (!parts.length) return '<p class="tn-mute">لا توجد قطع هيكل لهذه السيارة.</p>';
        return parts.map((b) => {
            const picked = ch.body && ch.body[b.mod];
            const isOpen = bodyOpen === b.mod;
            const cur = picked ? picked.i : b.cur;
            const name = cur < 0 ? 'الأصلي' : arr(b.opts)[cur] || `رقم ${cur + 1}`;
            let opts = '';
            if (isOpen) {
                const items = [[-1, 'الأصلي'], ...arr(b.opts).map((n, i) => [i, n])];
                opts = `<div class="tn-list">${items.map(([i, n]) => `<button class="${i === cur ? 'on' : ''}" data-act="bodyPick" data-mod="${b.mod}" data-v="${i}" data-n="${esc(n)}">${esc(n)}${i === b.cur ? tag('الآن', 'ok') : ''}</button>`).join('')}</div>`;
            }
            return `<div class="tn-acc${isOpen ? ' open' : ''}${picked ? ' changed' : ''}">
                <button class="tn-acch" data-act="bodyOpen" data-mod="${b.mod}"><b>${esc(b.label)}</b><span>${esc(name)}</span><small>${money(P(b.price || 'body'))}</small></button>${opts}</div>`;
        }).join('');
    }

    function lightsView() {
        const c = car();
        const n = ch.neon || c.neon;
        const x = ch.xenon || c.xenon;
        return `<div class="tn-row"><h4>النيون <span class="tn-price">${money(n.on !== c.neon.on ? P('neon') : P('neonColor'))}</span></h4>
                <div class="tn-chips">${chip('data-act="neonOn" data-v="0"', !n.on, 'بدون')}${chip('data-act="neonOn" data-v="1"', n.on, 'نيون')}</div>
                ${n.on ? `<div class="tn-sw">${SWATCH.slice(1).map((h) => `<button class="${hex(n.c) === h ? 'on' : ''}" data-act="neonColor" data-h="${h}" style="--c:${h}"></button>`).join('')}</div>
                <label class="tn-pick"><input type="color" value="${hex(n.c)}" data-input="neon"><span>لون خاص</span></label>` : ''}</div>
            <div class="tn-row"><h4>أضواء الزينون <span class="tn-price">${money(x.on !== c.xenon.on ? P('xenon') : P('xenonColor'))}</span></h4>
                <div class="tn-chips">${chip('data-act="xenonOn" data-v="0"', !x.on, 'عادية')}${chip('data-act="xenonOn" data-v="1"', x.on, 'زينون')}</div>
                ${x.on ? `<div class="tn-sw named">${XENON.map(([id, name, h]) => `<button class="${x.c === id ? 'on' : ''}" data-act="xenonColor" data-v="${id}" style="--c:${h}"><i></i><span>${esc(name)}</span></button>`).join('')}</div>` : ''}</div>
            <button class="tn-btn ghost" data-act="lights">${lights ? 'أطفئ الأضواء' : 'شغّل الأضواء لترى'}</button>`;
    }

    function otherView() {
        const c = car();
        const t = ch.tint !== undefined ? ch.tint : c.tint;
        const p = ch.plate !== undefined ? ch.plate : c.plate;
        return `<div class="tn-row"><h4>تظليل النوافذ <span class="tn-price">${money(P('tint'))}</span></h4><div class="tn-chips">${TINTS.map((l, i) => chip(`data-act="tint" data-v="${i}"`, i === t, l)).join('')}</div></div>
            <div class="tn-row"><h4>شكل اللوحة <span class="tn-price">${money(P('plate'))}</span></h4><div class="tn-chips">${PLATES.map((l, i) => chip(`data-act="plate" data-v="${i}"`, i === p, l)).join('')}</div></div>`;
    }

    function reviewView() {
        const ls = lines();
        const sum = total();
        const pay = D.bank >= sum ? 'من حسابك في البنك' : D.cash >= sum ? 'نقدًا' : null;
        return `<div class="tn-review"><div class="tn-rsheet">
            <h3>مراجعة الطلب</h3>
            <div class="tn-rlines">${ls.map((l) => `<div><span>${l.color ? `<i style="--c:${l.color}"></i>` : ''}${esc(l.label)}</span><b>${money(l.price)}</b></div>`).join('') || '<p class="tn-mute">لم تختر شيئًا بعد.</p>'}</div>
            <div class="tn-rtotal"><span>المجموع</span><b>${money(sum)}</b></div>
            <div class="tn-rbal"><span>رصيدك في البنك</span><b class="${D.bank < sum ? 'bad' : ''}">${money(D.bank)}</b></div>
            <p class="tn-hint">تدفع الآن والمبلغ يذهب للورشة. السيارة ترجع كما كانت، والميكانيكي يركّب التعديلات واحدة واحدة. يمكنك الإلغاء واسترجاع المبلغ ما دام لم يبدأ التركيب.</p>
            ${err ? `<p class="tn-err">${esc(err)}</p>` : ''}
            <div class="tn-rbtns">
                <button class="tn-btn primary" data-act="confirm" ${!ls.length || !pay || busy ? 'disabled' : ''}>${busy ? 'جارٍ الطلب…' : pay ? `ادفع ${money(sum)} ${pay}` : 'المبلغ لا يكفي'}</button>
                <button class="tn-btn ghost" data-act="back">رجوع للتعديل</button>
            </div></div></div>`;
    }

    function render() {
        if (!D) return;
        const body = panel.querySelector('.tn-body');
        if (body) scrolls[body.dataset.key] = body.scrollTop;
        const ls = lines();
        const views = { perf: perfView, paint: paintView, wheels: wheelsView, body: bodyView, lights: lightsView, other: otherView };
        const key = `${cat}-${sub}-${bodyOpen}`;
        panel.innerHTML = `
            <header class="tn-head"><small>ورشة بيني · التعديل</small><h2>${esc(D.model || 'سيارتك')}</h2><span class="tn-plate">${esc(D.plate)}</span></header>
            <nav class="tn-cats">${CATS.map(([id, l, ic]) => `<button class="${cat === id ? 'on' : ''}" data-act="cat" data-v="${id}">${ic}<span>${l}</span></button>`).join('')}</nav>
            <div class="tn-body" data-key="${key}">${views[cat]()}</div>
            <footer class="tn-foot">
                <div><small>${ls.length ? `${ls.length} تعديل` : 'لم تختر شيئًا'}</small><b>${money(total())}</b></div>
                <button class="tn-btn primary" data-act="review" ${ls.length ? '' : 'disabled'}>مراجعة الطلب</button>
                <button class="tn-btn ghost" data-act="close">إغلاق</button>
            </footer>
            ${review ? reviewView() : ''}`;
        const nb = panel.querySelector('.tn-body');
        if (nb && scrolls[key]) nb.scrollTop = scrolls[key];
    }

    // ------------------------------------------------------------------
    // clicks
    // ------------------------------------------------------------------
    function onClick(e) {
        const el = e.target.closest('[data-act]');
        if (!el || !D) return;
        const a = el.dataset.act, v = el.dataset.v, c = car();
        if (a === 'cat') return goCat(v);
        if (a === 'perf') { const p = arr(c.perf).find((x) => x.key === el.dataset.k); pick(p.key, Number(v), perfNow(p)); }
        else if (a === 'turbo') pick('turbo', v === '1', c.turbo);
        else if (a === 'nitro') pick('nitro', v === '1', !!c.nitro);
        else if (a === 'swap') { pick('swap', v, c.swap || 'stock'); post('tunePreview', { k: 'rev', v: true }); }
        else if (a === 'rev') post('tunePreview', { k: 'rev', v: true });
        else if (a === 'sub') { sub = v; cam(v === 'wheelColor' ? 'wheel' : 'three'); }
        else if (a === 'finish') { const cur = ch[sub] || c[sub]; pick(sub, { t: Number(v), c: arr(cur.c) }, c[sub]); }
        else if (a === 'color') { const cur = ch[sub] || c[sub]; pick(sub, { t: cur.t, c: rgbOf(el.dataset.h) }, c[sub]); }
        else if (a === 'gta') pick(sub, Number(v), c[sub]);
        else if (a === 'wtype') loadWheels(Number(v));
        else if (a === 'wheel') {
            const w = { t: wheelType, i: Number(v), n: el.dataset.n, bike: c.wheels.bike };
            if (w.t === c.wheels.t && w.i === c.wheels.i) { delete ch.wheels; post('tunePreview', { k: 'wheels', v: w }); } else { ch.wheels = w; post('tunePreview', { k: 'wheels', v: w }); }
        } else if (a === 'bodyOpen') {
            const mod = Number(el.dataset.mod);
            bodyOpen = bodyOpen === mod ? null : mod;
            if (bodyOpen != null) cam(BODY_VIEW[mod] || 'three');
            post('tunePreview', { k: 'hood', v: mod === 39 || mod === 40 });
        } else if (a === 'bodyPick') { const b = arr(c.body).find((x) => x.mod === Number(el.dataset.mod)); pickBody(b, Number(v), el.dataset.n); }
        else if (a === 'neonOn') { const n = ch.neon || c.neon; pick('neon', { on: v === '1', c: arr(n.c) }, c.neon); cam('side'); }
        else if (a === 'neonColor') pick('neon', { on: true, c: rgbOf(el.dataset.h) }, c.neon);
        else if (a === 'xenonOn') { const x = ch.xenon || c.xenon; pick('xenon', { on: v === '1', c: x.c }, c.xenon); lightsOn(true); }
        else if (a === 'xenonColor') { pick('xenon', { on: true, c: Number(v) }, c.xenon); lightsOn(true); }
        else if (a === 'lights') lightsOn(!lights);
        else if (a === 'tint') { pick('tint', Number(v), c.tint); cam('side'); }
        else if (a === 'plate') { pick('plate', Number(v), c.plate); cam('rear'); }
        else if (a === 'review') { review = true; err = ''; }
        else if (a === 'back') review = false;
        else if (a === 'confirm') return confirm();
        else if (a === 'close') return close();
        else if (a === 'rot') post('tuneCam', { rot: Number(v) });
        else if (a === 'zoom') post('tuneCam', { zoom: Number(v) });
        else if (a === 'view') post('tuneCam', { view: v });
        render();
    }

    function lightsOn(on) { lights = on; post('tunePreview', { k: 'lights', v: on }); }

    function onInput(e) {
        const el = e.target;
        if (!D || !el.dataset.input) return;
        const c = car();
        if (el.dataset.input === 'color') { const cur = ch[sub] || c[sub]; pick(sub, { t: cur.t, c: rgbOf(el.value) }, c[sub]); }
        if (el.dataset.input === 'neon') pick('neon', { on: true, c: rgbOf(el.value) }, c.neon);
        if (e.type === 'change') render();
        else {
            // while dragging the picker: only the text and the total change
            const t = panel.querySelector('.tn-foot b');
            if (t) t.innerHTML = money(total());
        }
    }

    function confirm() {
        if (busy) return;
        busy = true; err = ''; render();
        const c = car();
        const cur = { turbo: c.turbo, pearl: c.pearl, neon: c.neon.on, xenon: c.xenon.on };
        arr(c.perf).forEach((p) => { cur[p.key] = p.cur; });
        if (stockRims()) delete ch.wheelColor;
        post('tuneConfirm', { changes: ch, cur }).then((r) => {
            busy = false;
            if (r && r.ok) return; // the game closes the menu
            err = (r && r.msg) || 'تعذّر إرسال الطلب، حاول مرة أخرى';
            render();
        });
    }

    function close() { post('tuneClose'); hide(); }
    function hide() { D = null; root.classList.add('hidden'); panel.innerHTML = ''; }

    function show(d) {
        D = d;
        D.car = D.car || {};
        ch = {}; cat = 'perf'; sub = 'paint1'; bodyOpen = null; wheelType = null; wheelList = null; review = false; busy = false; err = ''; lights = false;
        root.classList.remove('hidden');
        goCat('perf');
    }

    function build() {
        root = document.getElementById('tune');
        if (!root) return;
        root.innerHTML = `<div class="tn-panel"></div>
            <div class="tn-camui">
                <button data-act="rot" data-v="35" title="لف">${SVG('<path d="M4 12a8 8 0 0 1 14-5l2 2M20 4v5h-5"/>')}</button>
                <button data-act="zoom" data-v="-0.6" title="قرّب">${SVG('<path d="M12 5v14M5 12h14"/>')}</button>
                <button data-act="view" data-v="three" title="المنظر">${SVG('<path d="M3 15l2-5 3-3h8l3 3 2 5v3H3z"/>')}</button>
                <button data-act="zoom" data-v="0.6" title="بعّد">${SVG('<path d="M5 12h14"/>')}</button>
                <button data-act="rot" data-v="-35" title="لف">${SVG('<path d="M20 12a8 8 0 0 0-14-5L4 9M4 4v5h5"/>')}</button>
            </div>
            <div class="tn-keys"><kbd>←</kbd><kbd>→</kbd> لف الكاميرا · <kbd>Esc</kbd> إغلاق</div>`;
        panel = root.querySelector('.tn-panel');
        root.addEventListener('click', onClick);
        root.addEventListener('input', onInput);
        root.addEventListener('change', onInput);
        root.addEventListener('wheel', (e) => { if (D && !e.target.closest('.tn-panel')) post('tuneCam', { zoom: e.deltaY > 0 ? 0.5 : -0.5 }); }, { passive: true });
    }

    window.addEventListener('keydown', (e) => {
        if (!D) return;
        if (e.key === 'Escape') { if (review) { review = false; render(); } else close(); }
        else if (e.key === 'ArrowLeft' && e.target.tagName !== 'INPUT') post('tuneCam', { rot: 25 });
        else if (e.key === 'ArrowRight' && e.target.tagName !== 'INPUT') post('tuneCam', { rot: -25 });
    });

    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || m.action !== 'tune') return;
        if (m.open) show(m.data || {}); else if (D) hide();
    });

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
    return { show, hide, fake: null, _state: () => ({ ch, cat, sub, lines: lines(), total: total() }) };
})();
