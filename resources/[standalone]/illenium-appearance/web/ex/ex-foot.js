/* ======================================================================
   EX_Tii appearance: the footer (the receipt, paying, saving), the dock by the character, the modal,
   the toast, turning the character with the mouse, the keyboard.
   ====================================================================== */
'use strict';

function renderFoot() {
    const f = $('#foot'); f.innerHTML = '';
    if (S.mode === 'clothing') return footClothing(f);
    if (S.mode === 'creator') return footCreator(f);
    if (S.mode === 'wardrobe') {
        const a = h('div', S.fromShop ? 'acts' : 'acts one');
        if (S.fromShop) {
            a.appendChild(btn('btn gold', 'العودة للمتجر', 'hanger', () => backToShop()));
            a.appendChild(btn('btn ghost', 'اخرج', null, () => post('appearance_exit')));
        } else a.appendChild(btn('btn dark', 'تم', 'check', () => save()));
        f.appendChild(a); return;
    }
    if (S.mode === 'tattoo') {
        wallet(f);
        // EX_Tii: trying a tattoo on -> the gold button buys it; nothing picked -> "done" saves and leaves
        const pick = S.tatPick && S.tatPreview === S.tatPick.t.name ? S.tatPick : null;
        if (pick) {
            const a = h('div', 'acts');
            a.appendChild(btn('btn gold', `اشترِ الوشم · ${money(pick.t.cost || S.shop.tattooCost || 0)}`, 'check', () => buyTattoo(pick.t, pick.zone)));
            a.appendChild(btn('btn ghost', 'انتهيت', null, () => save()));
            f.appendChild(a);
        } else {
            const a = h('div', 'acts one'); a.appendChild(btn('btn gold', 'انتهيت', 'check', () => save())); f.appendChild(a);
        }
        return;
    }
    if (S.mode === 'barber' || S.mode === 'surgeon') {
        const cost = S.shop.flatCost || 0;
        wallet(f);
        const a = h('div', 'acts');
        a.appendChild(btn('btn gold', cost ? `احفظ وادفع ${money(cost)}` : 'احفظ', 'check', () => confirmSave(cost)));
        a.appendChild(btn('btn ghost', 'إلغاء', null, () => leave(true)));
        f.appendChild(a);
        return;
    }
    // uniform / admin
    const a = h('div', 'acts');
    a.appendChild(btn('btn gold', S.mode === 'uniform' ? 'احفظ الزي' : 'احفظ', 'save', () => save()));
    a.appendChild(btn('btn ghost', 'إلغاء', null, () => leave(true)));
    f.appendChild(a);
}
function btn(cls, label, ic, fn) {
    const b = h('button', cls, `${ic ? icon(ic) : ''}<span>${label}</span>`); b.type = 'button'; b.onclick = fn; return b;
}
function wallet(f) {
    if (S.shop.cash == null) return;
    f.appendChild(h('div', 'wallet', `<span>نقدًا <b>${money(S.shop.cash)}</b></span><span>في البنك <b>${money(S.shop.bank)}</b></span>`));
}

function footClothing(f) {
    const lines = cart();
    const total = lines.reduce((s, l) => s + l.price, 0);
    const r = h('div', 'receipt');
    r.appendChild(h('div', 'r-head', `<span>الفاتورة · ${lines.length} ${lines.length === 1 ? 'قطعة' : (lines.length === 2 ? 'قطعتان' : 'قطع')}</span>`));
    if (lines.length) {
        const clear = h('button', null, 'أرجع كل شيء'); clear.type = 'button';
        clear.onclick = async () => { for (const l of lines) await undo(l.cat); };
        r.firstChild.appendChild(clear);
        const ul = h('ul', 'r-lines');
        lines.forEach((l) => {
            const li = h('li', null, `<span class="r-n">${l.label}<i>${l.removed ? 'خلعته' : '#' + (l.d + 1) + (l.t > 0 ? ' · لون ' + (l.t + 1) : '')}</i></span><span class="r-p">${l.price ? money(l.price) : '—'}</span>`);
            const u = h('button', null, icon('undo')); u.type = 'button'; u.title = 'أرجع القطعة القديمة'; u.setAttribute('aria-label', 'أرجع ' + l.label);
            u.onclick = () => undo(l.cat);
            li.appendChild(u); ul.appendChild(li);
        });
        r.appendChild(ul);
        r.appendChild(h('div', 'r-total', `<span>المجموع</span><b>${money(total)}</b>`));
    } else {
        r.appendChild(h('p', 'r-empty', 'لم تختر شيئًا بعد. كل قطعة تختارها تظهر هنا بسعرها.'));
    }
    f.appendChild(r);
    wallet(f);
    const a = h('div', 'acts');
    if (lines.length) {
        const cash = btn('btn gold', 'ادفع نقدًا', 'cash', () => pay('cash'));
        const bank = btn('btn dark', 'ادفع بالبطاقة', 'card', () => pay('bank'));
        if (S.shop.cash != null && S.shop.cash < total) cash.disabled = true;
        if (S.shop.bank != null && S.shop.bank < total) bank.disabled = true;
        a.append(cash, bank);
        f.appendChild(a);
        const out = h('button', 'leave', 'اخرج بلا شراء'); out.type = 'button'; out.onclick = () => leave(true);
        f.appendChild(out);
    } else {
        a.classList.add('one'); a.appendChild(btn('btn dark', 'اخرج من المتجر', null, () => leave(false)));
        f.appendChild(a);
    }
}

function footCreator(f) {
    const last = S.step === STEPS.length - 1;
    const a = h('div', 'acts');
    if (S.step > 0) a.appendChild(btn('btn ghost', 'السابق', null, () => goStep(S.step - 1)));
    a.appendChild(btn('btn gold', last ? 'ابدأ في المدينة' : 'التالي', last ? 'check' : null, () => last ? confirmFinish() : goStep(S.step + 1)));
    if (S.step === 0) a.classList.add('one');
    f.appendChild(a);
}
function goStep(i) {
    S.step = clamp(i, 0, STEPS.length - 1); S.cat = STEPS[S.step][0]; S.sub = null;
    if (S.cat === 'clothes') { S.group = 'top'; S.ccat = firstCatOf('top'); }
    camFor(); render(); $('#body').scrollTop = 0;
}

/* ---------------- paying / saving / leaving ---------------- */
async function pay(method) {
    if (S.busy) return;
    S.busy = true;
    const expected = cart().reduce((t, l) => t + l.price, 0);
    const res = await post('exti_pay_cart', { method, appearance: S.cur, expected });
    S.busy = false;
    if (!res || !res.ok) { toast((res && res.msg) || 'لم يتم الدفع', 'bad'); if (res && res.cash != null) { S.shop.cash = res.cash; S.shop.bank = res.bank; renderFoot(); } return; }
    await post('appearance_save', S.cur);
}
async function save() { if (S.busy) return; S.busy = true; await post('appearance_save', S.cur); S.busy = false; }
function confirmSave(cost) {
    if (!cost) return save();
    ask('حفظ المظهر الجديد', `سيُدفع ${money(cost)} نقدًا ويُحفظ مظهرك.`, 'احفظ وادفع', () => save());
}
function confirmFinish() {
    ask('جاهز؟', 'هذا شكل شخصيتك في المدينة. تستطيع تغيير الملابس والشعر لاحقًا في المتاجر، لكن الوجه لا يتغير بسهولة.', 'ابدأ', () => save());
}
function leave(confirmIt) {
    if (S.config.enableExit === false) return;
    if (S.mode === 'tattoo') return save(); // tattoos are paid one by one, so leaving keeps them
    const dirty = S.mode === 'clothing' ? cart().length > 0 : confirmIt;
    if (!dirty) { post('appearance_exit'); return; }
    ask('الخروج بلا حفظ؟', 'سيعود مظهرك كما كان قبل الدخول.', 'اخرج', () => post('appearance_exit'));
}

/* ---------------- the wardrobe inside a clothing store ---------------- */
async function goWardrobe() {
    if (S.busy) return;
    const enter = async () => {
        const res = await post('exti_outfit_list');
        S.outfits = (res && res.outfits) || [];
        S.mode = 'wardrobe'; S.fromShop = true; camFor(); render(); $('#body').scrollTop = 0;
    };
    const lines = cart();
    if (!lines.length) return enter();
    ask('قطع لم تدفع ثمنها', 'ستُرجع القطع التي في الفاتورة قبل فتح خزانتك.', 'تابع', async () => {
        for (const l of lines) await undo(l.cat);
        enter();
    });
}
function backToShop() { S.mode = 'clothing'; S.fromShop = false; firstTab(); render(); $('#body').scrollTop = 0; }
$('#wbtn').onclick = () => (S.mode === 'wardrobe' ? backToShop() : goWardrobe());

/* ---------------- modal / toast ---------------- */
function ask(title, text, yes, fn) {
    $('#m-title').textContent = title; $('#m-text').textContent = text; $('#m-yes').textContent = yes;
    const m = $('#modal'); m.classList.remove('hidden');
    $('#m-yes').onclick = () => { m.classList.add('hidden'); fn(); };
    $('#m-no').onclick = () => m.classList.add('hidden');
    $('#m-yes').focus();
}
let toastT = 0;
function toast(text, kind) {
    const t = $('#toast'); t.textContent = text; t.className = 'toast ' + (kind || '');
    clearTimeout(toastT); toastT = setTimeout(() => t.classList.add('hidden'), 2600);
}

/* ---------------- the dock ---------------- */
const VIEWS = [['default', 'كامل'], ['head', 'الوجه'], ['body', 'الجسم'], ['bottom', 'الساقان']];
function renderDock() {
    const v = $('#views'); v.innerHTML = '';
    VIEWS.forEach(([id, label]) => {
        const b = h('button', 'view' + (view === id ? ' on' : ''), label); b.type = 'button';
        b.onclick = () => { view = id; post('appearance_set_camera', id); renderDock(); };
        v.appendChild(b);
    });
    document.querySelectorAll('[data-strip]').forEach((b) => b.classList.toggle('on', !!S.stripped[b.dataset.strip]));
    // (stripping makes sense with clothes on)
    const showStrip = ['clothing', 'uniform', 'creator', 'ped', 'tattoo', 'wardrobe'].includes(S.mode);
    document.querySelectorAll('[data-strip]').forEach((b) => b.classList.toggle('hidden', !showStrip));
    const sep = $('.dock-sep'); if (sep) sep.classList.toggle('hidden', !showStrip);
}
document.addEventListener('click', (e) => {
    const b = e.target.closest('.dock-btn'); if (!b) return;
    const act = b.dataset.act, strip = b.dataset.strip;
    if (act === 'rotL') post('appearance_rotate_camera', 'left');
    else if (act === 'rotR') post('appearance_rotate_camera', 'right');
    else if (act === 'turn') post('exti_rotate', { deg: 180 });
    else if (strip) {
        if (S.stripped[strip]) { post('appearance_wear_clothes', { data: S.cur, key: strip }); S.stripped[strip] = false; }
        else { post('appearance_remove_clothes', strip); S.stripped[strip] = true; }
        renderDock();
    }
});

/* ---------------- turn the character: drag on the empty screen ---------------- */
(function drag() {
    const app = $('#app');
    let x0 = null, acc = 0, pending = 0, sending = false;
    const flush = async () => {
        if (sending || !pending) return;
        sending = true; const d = pending; pending = 0;
        await post('exti_rotate', { deg: d });
        sending = false; if (pending) flush();
    };
    app.addEventListener('pointerdown', (e) => { if (e.target !== app) return; x0 = e.clientX; acc = 0; app.classList.add('dragging'); app.setPointerCapture(e.pointerId); });
    app.addEventListener('pointermove', (e) => {
        if (x0 == null) return;
        const dx = e.clientX - x0; x0 = e.clientX; acc += dx;
        if (Math.abs(acc) >= 4) { pending += acc * 0.6; acc = 0; flush(); }
    });
    const up = () => { x0 = null; app.classList.remove('dragging'); };
    app.addEventListener('pointerup', up); app.addEventListener('pointercancel', up);
})();

/* ---------------- keyboard ---------------- */
document.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.key === 'Escape') {
        if (!$('#modal').classList.contains('hidden')) { $('#modal').classList.add('hidden'); return; }
        leave(true);
    } else if ((e.key === 'a' || e.key === 'd' || e.key === 'A' || e.key === 'D') && document.activeElement.tagName !== 'INPUT') {
        post('exti_rotate', { deg: (e.key.toLowerCase() === 'a') ? -12 : 12 });
    }
});
$('#close').onclick = () => leave(true);
