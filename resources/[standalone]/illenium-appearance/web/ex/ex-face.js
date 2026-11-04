/* ======================================================================
   EX_Tii appearance: the face and the body (models, parents, features, hair, beard, makeup, eyes),
   the tattoo shop and the wardrobe.
   ====================================================================== */
'use strict';

/* small builders */
function slider(parent, label, value, min, max, step, onInput, ends, mid) {
    const w = h('div', 'sl' + (mid ? ' mid' : ''));
    const lab = h('label', null, `<span>${label}</span>${ends ? `<b>${ends[0]} ← → ${ends[1]}</b>` : ''}`);
    const r = document.createElement('input'); r.type = 'range'; r.min = min; r.max = max; r.step = step; r.value = value;
    r.setAttribute('aria-label', label);
    const out = document.createElement('output');
    const paint = () => {
        const p = ((r.value - min) / (max - min)) * 100;
        r.style.setProperty('--p', p + '%');
        out.textContent = step < 1 ? (+r.value).toFixed(1) : r.value;
    };
    let t = 0;
    r.oninput = () => { paint(); const v = parseFloat(r.value); clearTimeout(t); t = setTimeout(() => onInput(v), 30); };
    paint(); w.append(lab, r, out); parent.appendChild(w);
    return r;
}
function stepper(parent, label, value, min, max, onChange, fmt) {
    const row = h('div', 'step-row', `<span class="lbl">${label}</span>`);
    const box = h('div', 'stp');
    const prev = h('button', 'prev', icon('chev')); prev.type = 'button'; prev.setAttribute('aria-label', 'السابق');
    const next = h('button', 'next', icon('chev')); next.type = 'button'; next.setAttribute('aria-label', 'التالي');
    const num = h('span', null, fmt ? fmt(value) : String(value + 1));
    // (RTL: the right arrow goes back, the left goes forward)
    prev.style.transform = 'scaleX(-1)';
    let v = value;
    const set = (n) => { v = n > max ? min : (n < min ? max : n); num.textContent = fmt ? fmt(v) : String(v + 1); onChange(v); };
    prev.onclick = () => set(v - 1); next.onclick = () => set(v + 1);
    box.append(prev, num, next); row.appendChild(box); parent.appendChild(row);
}
function swatches(parent, items, cur, onPick) {
    const g = h('div', 'swatches');
    (items || []).forEach((rgb, i) => {
        const s = h('button', 'sw' + (i === cur ? ' on' : '')); s.type = 'button';
        s.style.background = `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;
        s.setAttribute('aria-label', 'اللون ' + (i + 1));
        s.onclick = () => { g.querySelectorAll('.sw.on').forEach((x) => x.classList.remove('on')); s.classList.add('on'); onPick(i); };
        g.appendChild(s);
    });
    parent.appendChild(g);
}

/* ---------------- models (creator / admin ped menu) ---------------- */
async function setModel(model) {
    const res = await post('appearance_change_model', model);
    if (!res) return;
    S.settings = res.appearanceSettings;
    const keepTats = S.cur.tattoos;
    S.cur = res.appearanceData; S.cur.tattoos = keepTats || S.cur.tattoos;
    S.shown = {};
    render();
}
function viewModels(b, all) {
    b.appendChild(h('div', 'sec-head', '<h2>الشخصية</h2>'));
    const m = h('div', 'models');
    [['mp_m_freemode_01', 'رجل'], ['mp_f_freemode_01', 'امرأة']].forEach(([id, label]) => {
        const x = h('button', 'model' + (S.cur.model === id ? ' on' : ''), `${icon('user')}<span>${label}</span>`); x.type = 'button';
        x.onclick = () => { if (S.cur.model !== id) setModel(id); };
        m.appendChild(x);
    });
    b.appendChild(m);
    const others = ((S.settings.ped && S.settings.ped.model && S.settings.ped.model.items) || []).filter((x) => !/^mp_[mf]_freemode_01$/.test(x));
    if (all && others.length) {
        b.appendChild(h('div', 'sub-label', 'شخصيات أخرى'));
        const i = Math.max(0, others.indexOf(S.cur.model));
        stepper(b, 'الطراز', i, 0, others.length - 1, (n) => setModel(others[n]), (n) => others[n]);
    }
}

/* ---------------- parents / heritage ---------------- */
function sendBlend() { post('appearance_change_head_blend', S.cur.headBlend); }
function faces(parent, title, key, skinKey) {
    parent.appendChild(h('div', 'sub-label', title));
    const g = h('div', 'faces');
    const hb = S.cur.headBlend;
    for (let i = 0; i <= 45; i++) {
        const f = h('button', 'face' + (hb[key] === i ? ' on' : ''), `<span class="ph">${i + 1}</span>`); f.type = 'button';
        f.setAttribute('aria-label', `${title} ${i + 1}`);
        photo(`img/p-${i}.webp`, f);
        f.onclick = () => {
            hb[key] = i; if (skinKey && S.linkSkin !== false) hb[skinKey] = i;
            g.querySelectorAll('.face.on').forEach((x) => x.classList.remove('on')); f.classList.add('on');
            sendBlend();
        };
        g.appendChild(f);
    }
    parent.appendChild(g);
}
function viewOrigin(b, withModel) {
    if (withModel && S.config.ped !== false) viewModels(b, false);
    if (!isFreemode()) { b.appendChild(h('div', 'empty', 'الوراثة متاحة للشخصيات العادية فقط.')); return; }
    const hb = S.cur.headBlend;
    faces(b, 'الأب', 'shapeFirst', 'skinFirst');
    faces(b, 'الأم', 'shapeSecond', 'skinSecond');
    b.appendChild(h('div', 'sub-label', 'المزج'));
    slider(b, 'الوجه', hb.shapeMix, 0, 1, 0.05, (v) => { hb.shapeMix = v; sendBlend(); }, ['يشبه الأب', 'يشبه الأم']);
    slider(b, 'لون البشرة', hb.skinMix, 0, 1, 0.05, (v) => { hb.skinMix = v; sendBlend(); }, ['بشرة الأب', 'بشرة الأم']);
    b.appendChild(h('div', 'sub-label', 'لون البشرة بالتفصيل'));
    stepper(b, 'بشرة الأب', hb.skinFirst, 0, 45, (n) => { hb.skinFirst = n; sendBlend(); });
    stepper(b, 'بشرة الأم', hb.skinSecond, 0, 45, (n) => { hb.skinSecond = n; sendBlend(); });
}

/* ---------------- face features ---------------- */
function viewFace(b) {
    if (!isFreemode()) { b.appendChild(h('div', 'empty', 'ملامح الوجه متاحة للشخصيات العادية فقط.')); return; }
    const ff = S.cur.faceFeatures;
    let t = 0;
    const send = () => { clearTimeout(t); t = setTimeout(() => post('appearance_change_face_feature', ff), 20); };
    FACE.forEach(([title, list]) => {
        b.appendChild(h('div', 'sub-label', title));
        list.forEach(([k, label, lo, hi]) => slider(b, label, ff[k] || 0, -1, 1, 0.1, (v) => { ff[k] = v; send(); }, [lo, hi], true));
    });
}

/* ---------------- hair, overlays, eyes ---------------- */
function viewHairTab(b, tab) {
    if (tab === 'hair') return viewHair(b);
    if (tab === 'eyeColor') return viewEyes(b);
    return viewOverlay(b, tab);
}
async function sendHair() {
    const res = await post('appearance_change_hair', S.cur.hair);
    if (res && res.style) S.settings.hair = res;
}
function viewHair(b) {
    const set = S.settings.hair, hair = S.cur.hair;
    const black = new Set((set.blacklist && set.blacklist.drawables) || []);
    const list = []; for (let d = set.style.min; d <= set.style.max; d++) if (!black.has(d)) list.push(d);
    b.appendChild(h('div', 'sec-head', `<h2>التسريحة<small>${list.length}</small></h2>`));
    const opts = h('div', 'opts'); b.appendChild(opts);
    opts.appendChild(h('div', 'sub-label', 'لون الشعر'));
    swatches(opts, set.color.items, hair.color, (i) => { hair.color = i; sendHair(); renderFoot(); });
    opts.appendChild(h('div', 'sub-label', 'لون الخصلات'));
    swatches(opts, set.highlight.items, hair.highlight, (i) => { hair.highlight = i; sendHair(); renderFoot(); });
    const grid = h('div', 'grid'); b.appendChild(grid);
    const g = gender();
    list.forEach((d) => {
        const card = h('button', 'pc' + (d === hair.style ? ' on' : ''), `<span class="ph">${d === 0 ? icon('none') : d + 1}</span><span class="no">${d === 0 ? 'حلاقة' : '#' + (d + 1)}</span>`); card.type = 'button';
        if (isFreemode()) photo(`img/${g}-c2-${d}.webp`, card);
        card.onclick = async () => {
            hair.style = d; hair.texture = 0;
            grid.querySelectorAll('.pc.on').forEach((x) => x.classList.remove('on')); card.classList.add('on');
            await sendHair(); renderFoot();
        };
        grid.appendChild(card);
    });
}
function sendOverlays() { post('appearance_change_head_overlay', S.cur.headOverlays); }
function viewOverlay(b, key) {
    const set = S.settings.headOverlays[key], ov = S.cur.headOverlays[key], info = OVERLAY[key];
    if (!set || !ov) { b.appendChild(h('div', 'empty', 'غير متاح.')); return; }
    b.appendChild(h('div', 'sec-head', `<h2>${info.label}<small>${set.style.max + 1}</small></h2>`));
    if (ov.opacity > 0) {
        const opts = h('div', 'opts'); b.appendChild(opts);
        slider(opts, 'الكثافة', ov.opacity, 0.1, 1, 0.1, (v) => { ov.opacity = v; sendOverlays(); });
        if (info.color && set.color) {
            opts.appendChild(h('div', 'sub-label', 'اللون'));
            swatches(opts, set.color.items, ov.color || 0, (i) => { ov.color = i; ov.secondColor = ov.secondColor || 0; sendOverlays(); });
        }
    }
    const grid = h('div', 'grid'); b.appendChild(grid);
    const g = gender();
    const none = h('button', 'pc' + (ov.opacity === 0 ? ' on' : ''), `<span class="ph">${icon('none')}</span><span class="no">بدون</span>`); none.type = 'button';
    none.onclick = () => { ov.opacity = 0; sendOverlays(); renderBody(); renderFoot(); };
    grid.appendChild(none);
    for (let s = set.style.min; s <= set.style.max; s++) {
        const card = h('button', 'pc' + (ov.opacity > 0 && ov.style === s ? ' on' : ''), `<span class="ph">${s + 1}</span><span class="no">#${s + 1}</span>`); card.type = 'button';
        if (isFreemode()) photo(`img/${g}-${key}-${s}.webp`, card);
        card.onclick = () => { ov.style = s; if (!ov.opacity) ov.opacity = 1; sendOverlays(); S.keepScroll = true; const t = $('#body').scrollTop; renderBody(); $('#body').scrollTop = t; renderFoot(); };
        grid.appendChild(card);
    }
}
function viewEyes(b) {
    b.appendChild(h('div', 'sec-head', '<h2>لون العينين</h2>'));
    const v = h('div', 'variants');
    EYES.forEach((name, i) => {
        const x = h('button', 'var' + (S.cur.eyeColor === i ? ' on' : ''), name); x.type = 'button';
        x.onclick = () => { S.cur.eyeColor = i; post('appearance_change_eye_color', i); v.querySelectorAll('.var.on').forEach((y) => y.classList.remove('on')); x.classList.add('on'); };
        v.appendChild(x);
    });
    b.appendChild(v);
}
/* admin ped menu: everything in one long list */
function viewAllHair(b) {
    viewHair(b);
    ['beard', 'eyebrows', 'makeUp', 'lipstick'].forEach((k) => { const box = h('div'); b.appendChild(box); viewOverlay(box, k); });
}
function viewAllPieces(b) {
    Object.values(ORDER).flat().filter(catEnabled).forEach((cat) => {
        const isProp = cat[0] === 'p', id = +cat.slice(1);
        const set = isProp ? propSet(id) : compSet(id), cur = isProp ? propOf(S.cur, id) : compOf(S.cur, id);
        if (!set || !cur) return;
        b.appendChild(h('div', 'sub-label', catInfo(cat).label));
        stepper(b, 'الشكل', cur.drawable, set.drawable.min, set.drawable.max, (n) => pick(cat, n, 0), (n) => n < 0 ? 'بدون' : String(n + 1));
        if (set.texture.max > 0) stepper(b, 'اللون', Math.max(0, cur.texture), 0, set.texture.max, (n) => pick(cat, cur.drawable, n));
    });
}

/* ---------------- tattoos ---------------- */
function myTats(zone) { S.cur.tattoos = S.cur.tattoos || {}; S.cur.tattoos[zone] = S.cur.tattoos[zone] || []; return S.cur.tattoos[zone]; }
function hasTat(t) { return myTats(t.zone).some((x) => x.name === t.name); }
function viewTattoos(b, zone) {
    const all = ((S.settings.tattoos && S.settings.tattoos.items) || {})[zone] || [];
    const mine = myTats(zone);
    b.appendChild(h('div', 'sec-head', `<h2>${(ZONES.find((z) => z[0] === zone) || [])[1] || ''}<small>${all.length}</small></h2>`));
    if (!all.length) { b.appendChild(h('div', 'empty', 'لا توجد وشوم لهذه المنطقة.')); return; }
    const box = h('div', 'tats'); b.appendChild(box);
    const cost = S.shop.tattooCost || 0;
    const sorted = all.slice().sort((a, c) => (hasTat(c) - hasTat(a)));
    sorted.forEach((t) => {
        const own = hasTat(t);
        const row = h('div', 'tat' + (own ? ' mine' : '') + (S.tatPreview === t.name ? ' preview' : ''));
        row.innerHTML = `<span class="t-ico">${icon(own ? 'check' : 'needle')}</span><span class="t-name"><b>${t.label}</b><i>${own ? 'على جسمك' : 'اضغط لتجربته'}</i></span>`;
        if (!own) row.insertAdjacentHTML('beforeend', `<span class="t-price">${money(t.cost || cost)}</span>`);
        const act = h('button', 't-act ' + (own ? 't-del' : 't-buy'), own ? 'إزالة' : 'اشترِ'); act.type = 'button';
        row.appendChild(act);
        row.onclick = (e) => {
            if (e.target === act || own) return;
            S.tatPreview = t.name;
            post('appearance_preview_tattoo', { data: S.cur.tattoos, tattoo: Object.assign({ opacity: 1 }, t) });
            box.querySelectorAll('.tat.preview').forEach((x) => x.classList.remove('preview')); row.classList.add('preview');
        };
        act.onclick = async () => {
            if (own) {
                const i = mine.findIndex((x) => x.name === t.name); if (i >= 0) mine.splice(i, 1);
                await post('appearance_delete_tattoo', S.cur.tattoos);
                toast('أُزيل الوشم', 'ok');
            } else {
                const updated = clone(S.cur.tattoos); updated[zone] = updated[zone] || [];
                updated[zone].push(Object.assign({ opacity: 1 }, t));
                const paid = await post('appearance_apply_tattoo', { tattoo: t, updatedTattoos: updated });
                if (paid === false) { toast('ليس معك مال كافٍ نقدًا', 'bad'); return; }
                S.cur.tattoos = updated; S.tatPreview = null;
                toast(`اشتريت الوشم · ${money(t.cost || cost)}`, 'ok');
            }
            renderTabs(); renderBody();
        };
        box.appendChild(row);
    });
}

/* ---------------- wardrobe ---------------- */
function viewWardrobe(b) {
    const row = h('div', 'save-row');
    const inp = document.createElement('input'); inp.placeholder = 'اسم للزي الذي تلبسه الآن'; inp.maxLength = 30;
    const btn = h('button', 'btn gold', `${icon('save')}<span>احفظ</span>`); btn.type = 'button'; btn.style.width = '110px'; btn.style.height = '40px';
    btn.onclick = async () => {
        const name = inp.value.trim(); if (!name) { inp.focus(); return; }
        const res = await post('exti_outfit_save', { name, appearance: S.cur });
        if (res && res.outfits) { S.outfits = res.outfits; inp.value = ''; toast('حُفظ الزي', 'ok'); renderBody(); } else if (res && res.msg) toast(res.msg, 'bad');
    };
    row.append(inp, btn); b.appendChild(row);
    if (!S.outfits.length) { b.appendChild(h('div', 'empty', 'لا توجد أزياء محفوظة بعد.<br>البس ما تريد ثم احفظه باسم.')); return; }
    const list = h('div', 'outfits'); b.appendChild(list);
    S.outfits.forEach((o) => {
        const r = h('div', 'of', `<span class="o-ico">${icon('hanger')}</span><span class="o-name"></span>`);
        r.querySelector('.o-name').textContent = o.name;
        const wear = h('button', 'o-wear', 'البس'); wear.type = 'button';
        wear.onclick = async () => { const res = await post('exti_outfit_wear', { id: o.id }); if (res && res.msg) { toast(res.msg, 'bad'); return; } if (res && res.appearance) { S.cur = res.appearance; S.orig = clone(res.appearance); toast('لبست ' + o.name, 'ok'); } };
        const del = h('button', 'o-del', icon('trash')); del.type = 'button'; del.setAttribute('aria-label', 'احذف');
        del.onclick = async () => {
            if (!del.classList.contains('sure')) { del.classList.add('sure'); del.textContent = 'متأكد؟'; setTimeout(() => { if (del.isConnected) { del.classList.remove('sure'); del.innerHTML = icon('trash'); } }, 2500); return; }
            const res = await post('exti_outfit_delete', { id: o.id });
            if (res && res.outfits) { S.outfits = res.outfits; renderBody(); }
        };
        r.append(wear, del); list.appendChild(r);
    });
}
