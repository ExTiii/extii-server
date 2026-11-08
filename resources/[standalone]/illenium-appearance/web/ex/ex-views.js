/* ======================================================================
   EX_Tii appearance: what the panel shows (header, steps, tabs, the body of each tab, the footer).
   ====================================================================== */
'use strict';

/* ---------------- the camera for what you're looking at ---------------- */
const CAM_OF = { head: 'head', top: 'body', bottom: 'legs', acc: 'body' };
// EX_Tii: the camera goes to the piece you are shopping for: trousers = legs, shoes = feet, hats / masks /
// glasses / ears / hair = head, watches and bracelets = hands, everything else = the body
const CAM_OF_CAT = { c4: 'legs', c6: 'feet', c1: 'head', c2: 'head', p0: 'head', p1: 'head', p2: 'head', p6: 'hands', p7: 'hands' };
function camFor() {
    let v = 'default';
    if (S.mode === 'clothing' || S.mode === 'uniform' || (S.mode === 'creator' && S.cat === 'clothes')) {
        const cat = S.mode === 'creator' ? S.ccat : S.cat;
        v = CAM_OF_CAT[cat] || CAM_OF[S.group] || 'body';
    }
    else if (['barber', 'surgeon'].includes(S.mode) || (S.mode === 'creator' && ['origin', 'face', 'hair', 'skin'].includes(S.cat))) v = 'head';
    else if (S.mode === 'tattoo') v = S.cat === 'ZONE_HEAD' ? 'head' : (S.cat.includes('LEG') ? 'legs' : 'body');
    setView(v);
}
let view = 'default';
function setView(v) { if (v === view && S.open) { renderDock(); return; } view = v; post('appearance_set_camera', v); renderDock(); }

/* ---------------- render ---------------- */
function render() {
    const m = MODE[S.mode];
    $('#title').textContent = (S.mode === 'clothing' && S.shop.name) ? S.shop.name : m.title;
    $('#subtitle').textContent = m.sub;
    $('.p-mark use').setAttribute('href', '#i-' + m.icon);
    $('#close').classList.toggle('hidden', S.config.enableExit === false);
    const wb = $('#wbtn'), inShop = S.mode === 'clothing' || (S.mode === 'wardrobe' && S.fromShop);
    wb.classList.toggle('hidden', !inShop);
    wb.querySelector('span').textContent = S.mode === 'wardrobe' ? 'المتجر' : 'خزانتي';
    renderSteps(); renderTabs(); renderBody(); renderFoot(); renderDock();
}

function renderSteps() {
    const el = $('#steps');
    if (S.mode !== 'creator') { el.classList.add('hidden'); return; }
    el.classList.remove('hidden'); el.innerHTML = '';
    STEPS.forEach(([id, label], i) => {
        const li = h('li', 'step' + (i === S.step ? ' on' : '') + (i < S.step ? ' done' : ''), `<span>${label}</span>`);
        li.tabIndex = 0;
        li.onclick = () => { S.step = i; S.cat = id; if (id === 'clothes') { S.group = 'top'; S.ccat = firstCatOf('top'); } camFor(); render(); };
        el.appendChild(li);
    });
}

/* the tabs: groups + categories for clothes; one row of categories for everything else */
function tabsFor() {
    const out = { groups: null, cats: [] };
    const clothes = S.mode === 'clothing' || S.mode === 'uniform' || (S.mode === 'creator' && S.cat === 'clothes') || (S.mode === 'ped' && S.pedClothes);
    if (clothes) {
        out.groups = GROUPS.filter(([g]) => ORDER[g].some(catEnabled));
        out.cats = ORDER[S.group].filter(catEnabled).map((c) => ({ id: c, label: catInfo(c).label, icon: catInfo(c).icon, dot: changed(c) }));
        return out;
    }
    if (S.mode === 'barber' || (S.mode === 'creator' && S.cat === 'hair')) {
        const list = [['hair', 'الشعر', 'hair'], ['beard', 'اللحية', 'beard'], ['eyebrows', 'الحاجبان', 'brow']];
        if (gender() === 'm') list.push(['chestHair', 'شعر الصدر', 'skin']);
        list.push(['makeUp', 'المكياج', 'eye'], ['blush', 'أحمر الخدود', 'face'], ['lipstick', 'أحمر الشفاه', 'lips'], ['eyeColor', 'لون العينين', 'eye']);
        out.cats = list.map(([id, label, ic]) => ({ id, label, icon: ic }));
        out.sub = true;
        return out;
    }
    if (S.mode === 'creator' && S.cat === 'skin') {
        out.cats = ['blemishes', 'ageing', 'complexion', 'sunDamage', 'moleAndFreckles', 'bodyBlemishes'].map((k) => ({ id: k, label: OVERLAY[k].label, icon: OVERLAY[k].icon }));
        out.sub = true;
        return out;
    }
    if (S.mode === 'surgeon') { out.cats = [{ id: 'origin', label: 'الوراثة', icon: 'dna' }, { id: 'face', label: 'ملامح الوجه', icon: 'face' }]; return out; }
    if (S.mode === 'tattoo') { out.cats = ZONES.map(([z, l]) => ({ id: z, label: l, icon: 'needle', dot: (S.cur.tattoos && (S.cur.tattoos[z] || []).length > 0) })); return out; }
    if (S.mode === 'ped') {
        out.cats = [{ id: 'model', label: 'الشخصية', icon: 'user' }, { id: 'origin', label: 'الوراثة', icon: 'dna' }, { id: 'face', label: 'الوجه', icon: 'face' }, { id: 'hairall', label: 'الشعر والمظهر', icon: 'hair' }, { id: 'clothesall', label: 'الملابس', icon: 'hanger' }];
        return out;
    }
    return out;
}
function curTab() {
    // creator / barber sub-tabs live in S.sub; clothes cats in S.cat (clothing) or S.ccat (creator)
    if (S.mode === 'creator' && S.cat === 'clothes') return S.ccat;
    if ((S.mode === 'creator' && (S.cat === 'hair' || S.cat === 'skin')) || S.mode === 'barber') return S.sub || (S.mode === 'barber' ? 'hair' : (S.cat === 'hair' ? 'hair' : 'blemishes'));
    return S.cat;
}
function renderTabs() {
    const t = tabsFor();
    const g = $('#groups'), c = $('#cats');
    g.innerHTML = ''; c.innerHTML = '';
    if (t.groups) {
        t.groups.forEach(([id, label]) => {
            const b = h('button', 'grp' + (S.group === id ? ' on' : ''), label); b.type = 'button';
            b.onclick = () => { S.group = id; const f = firstCatOf(id); if (S.mode === 'creator') S.ccat = f; else S.cat = f; camFor(); render(); };
            g.appendChild(b);
        });
    }
    const active = curTab();
    t.cats.forEach((x) => {
        const b = h('button', 'cat' + (active === x.id ? ' on' : ''), `${icon(x.icon)}<span>${x.label}</span>${x.dot ? '<i class="dot"></i>' : ''}`); b.type = 'button';
        b.onclick = () => {
            if (S.mode === 'creator' && S.cat === 'clothes') S.ccat = x.id;
            else if (t.sub) S.sub = x.id;
            else S.cat = x.id;
            camFor(); renderTabs(); renderBody(); $('#body').scrollTop = 0;
        };
        c.appendChild(b);
    });
    const on = c.querySelector('.cat.on'); if (on) on.scrollIntoView({ block: 'nearest', inline: 'nearest' });
}

function renderBody() {
    const b = $('#body'); b.innerHTML = '';
    const tab = curTab();
    if (S.mode === 'wardrobe') return viewWardrobe(b);
    if (S.mode === 'tattoo') return viewTattoos(b, S.cat);
    if (S.mode === 'creator') {
        if (S.cat === 'origin') return viewOrigin(b, true);
        if (S.cat === 'face') return viewFace(b);
        if (S.cat === 'hair') return viewHairTab(b, tab);
        if (S.cat === 'skin') return viewOverlay(b, tab);
        return viewPieces(b, tab);
    }
    if (S.mode === 'barber') return viewHairTab(b, tab);
    if (S.mode === 'surgeon') return S.cat === 'origin' ? viewOrigin(b, false) : viewFace(b);
    if (S.mode === 'ped') {
        if (S.cat === 'model') return viewModels(b, true);
        if (S.cat === 'origin') return viewOrigin(b, false);
        if (S.cat === 'face') return viewFace(b);
        if (S.cat === 'hairall') return viewAllHair(b);
        return viewAllPieces(b);
    }
    return viewPieces(b, tab);
}

/* ---------------- clothes: picture cards ---------------- */
const PAGE = 48;
function photo(path, card, cls) {
    const img = new Image(); img.alt = ''; img.decoding = 'async'; img.loading = 'lazy';
    img.onload = () => { img.classList.add('ok'); card.classList.add('has-photo'); };
    img.onerror = () => img.remove();
    img.src = path; if (cls) img.className = cls;
    card.prepend(img);
}
function viewPieces(b, cat) {
    if (!cat || !catEnabled(cat)) { b.appendChild(h('div', 'empty', 'لا يوجد شيء في هذا القسم.')); return; }
    const isProp = cat[0] === 'p', id = +cat.slice(1);
    const set = isProp ? propSet(id) : compSet(id);
    const cur = isProp ? propOf(S.cur, id) : compOf(S.cur, id);
    const orig = isProp ? propOf(S.orig, id) : compOf(S.orig, id);
    if (!set || !cur) { b.appendChild(h('div', 'empty', 'هذا القسم غير متاح لهذه الشخصية.')); return; }
    const black = new Set((set.blacklist && set.blacklist.drawables) || []);
    const list = [];
    for (let d = set.drawable.min; d <= set.drawable.max; d++) if (!black.has(d)) list.push(d);

    const head = h('div', 'sec-head', `<h2>${catInfo(cat).label}<small>${list.length}</small></h2>`);
    const jump = h('label', 'jump', `${icon('search')}<input type="number" inputmode="numeric" placeholder="رقم القطعة" aria-label="اذهب إلى رقم القطعة">`);
    head.appendChild(jump); b.appendChild(head);

    // the colours of the piece you're wearing (above the cards, they stay in view)
    const tmax = set.texture.max;
    if (cur.drawable >= 0 && tmax > 0) {
        const opts = h('div', 'opts');
        opts.appendChild(h('div', 'sub-label', `ألوان القطعة #${cur.drawable + 1} (${tmax + 1})`));
        const v = h('div', 'variants');
        const tb = new Set((set.blacklist && set.blacklist.textures) || []);
        for (let t = 0; t <= tmax; t++) {
            if (tb.has(t)) continue;
            const x = h('button', 'var' + (t === cur.texture ? ' on' : ''), String(t + 1)); x.type = 'button';
            x.onclick = () => pick(cat, cur.drawable, t);
            v.appendChild(x);
        }
        opts.appendChild(v); b.appendChild(opts);
    }

    const grid = h('div', 'grid'); b.appendChild(grid);
    const price = priceOf(cat);
    const g = gender();
    let shown = S.shown[cat] || PAGE;
    const idx = list.indexOf(cur.drawable);
    if (idx >= shown) shown = Math.ceil((idx + 1) / PAGE) * PAGE;
    const draw = () => {
        grid.innerHTML = '';
        list.slice(0, shown).forEach((d) => {
            const card = h('button', 'pc' + (d === cur.drawable ? ' on' : '')); card.type = 'button';
            card.dataset.d = d;
            const none = d === -1 || (!isProp && d === 0 && ['c1', 'c5', 'c7', 'c9', 'c10'].includes(cat));
            card.innerHTML = `<span class="ph">${none ? icon('none') : (d + 1)}</span><span class="no">${none ? 'بدون' : '#' + (d + 1)}</span>`;
            if (S.mode === 'clothing' && !none) card.insertAdjacentHTML('beforeend', `<span class="tag${price ? '' : ' free'}">${price ? money(price) : 'مجانًا'}</span>`);
            if (orig && d === orig.drawable) card.insertAdjacentHTML('beforeend', '<span class="worn">ترتديه</span>');
            if (!none && isFreemode()) photo(`img/${g}-${cat}-${d}.webp`, card);
            card.onclick = () => pick(cat, d, 0);
            grid.appendChild(card);
        });
        more.classList.toggle('hidden', shown >= list.length);
    };
    const more = h('button', 'more', 'اعرض المزيد'); more.type = 'button';
    more.onclick = () => { shown += PAGE; S.shown[cat] = shown; draw(); };
    b.appendChild(more);
    draw();

    jump.querySelector('input').onchange = (e) => {
        const n = parseInt(e.target.value, 10); if (isNaN(n)) return;
        const d = clamp(n - 1, set.drawable.min, set.drawable.max);
        if (list.indexOf(d) >= shown) { shown = Math.ceil((list.indexOf(d) + 1) / PAGE) * PAGE; S.shown[cat] = shown; draw(); }
        const el = grid.querySelector(`[data-d="${d}"]`); if (el) { el.scrollIntoView({ block: 'center' }); pick(cat, d, 0); }
    };

    const on = grid.querySelector('.pc.on'); if (on && !S.keepScroll) on.scrollIntoView({ block: 'nearest' });
    S.keepScroll = false;
}

async function pick(cat, drawable, texture) {
    const isProp = cat[0] === 'p', id = +cat.slice(1);
    const cur = isProp ? propOf(S.cur, id) : compOf(S.cur, id);
    if (!cur) return;
    cur.drawable = drawable; cur.texture = texture;
    if (isProp && drawable === -1) cur.texture = -1;
    const res = isProp
        ? await post('appearance_change_prop', { prop_id: id, drawable, texture: cur.texture })
        : await post('appearance_change_component', { component_id: id, drawable, texture });
    if (res && res.drawable) {
        const list = isProp ? S.settings.props : S.settings.components;
        const key = isProp ? 'prop_id' : 'component_id';
        const i = list.findIndex((x) => x[key] === id); if (i >= 0) list[i] = res;
    }
    // a jacket brings its own arms and undershirt (the game's own data): they change with it
    if (!isProp && res && Array.isArray(res.linked)) {
        res.linked.forEach((l) => {
            const c = compOf(S.cur, l.component_id); if (!c) return;
            c.drawable = l.drawable; c.texture = l.texture;
        });
    }
    // un-strip that part of the body: you picked something to wear on it
    S.stripped = {};
    S.keepScroll = true;
    const top = $('#body').scrollTop;
    renderTabs(); renderBody(); renderFoot(); renderDock();
    $('#body').scrollTop = top;
}

/* ---------------- the cart ---------------- */
function changed(cat) {
    const isProp = cat[0] === 'p', id = +cat.slice(1);
    const a = isProp ? propOf(S.cur, id) : compOf(S.cur, id);
    const o = isProp ? propOf(S.orig, id) : compOf(S.orig, id);
    return !!(a && o && (a.drawable !== o.drawable || a.texture !== o.texture));
}
function cart() {
    const lines = [];
    Object.values(ORDER).flat().forEach((cat) => {
        if (!catEnabled(cat) || !changed(cat)) return;
        const isProp = cat[0] === 'p', id = +cat.slice(1);
        const a = isProp ? propOf(S.cur, id) : compOf(S.cur, id);
        const removed = isProp ? a.drawable === -1 : (a.drawable === 0 && FREE_OFF.includes(cat));
        const free = removed || ((cat === 'c3' || cat === 'c8') && changed('c11'));   // (arms/undershirt come free with a jacket; the server prices it the same way)
        lines.push({ cat, label: catInfo(cat).label, d: a.drawable, t: a.texture, price: free ? 0 : priceOf(cat), removed });
    });
    return lines;
}
async function undo(cat) {
    const isProp = cat[0] === 'p', id = +cat.slice(1);
    const o = isProp ? propOf(S.orig, id) : compOf(S.orig, id);
    if (o) await pick(cat, o.drawable, o.texture);
}
