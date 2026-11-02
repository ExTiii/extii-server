// The XP card: { gained, reason, level, cur, need, pct, fromPct, up, oldLevel, unlocks, next, max, seconds }
// A new gain while the card is showing updates that card right away (the bar slides on from where it is).
(() => {
    const root = document.getElementById('lv');
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const num = (n) => Math.round(n || 0).toLocaleString('en-US');
    const clamp = (n) => Math.max(0, Math.min(100, Number(n) || 0));
    let el = null, hideTimer = null, goneTimer = null, shown = null;

    function inner(c, barFrom) {
        const unlocks = Array.isArray(c.unlocks) ? c.unlocks : c.unlocks ? Object.values(c.unlocks) : [];
        return `<div class="lv-top">
                <div class="lv-badge">${c.level}</div>
                <div class="lv-titles"><small>${c.up ? 'مستوى جديد!' : 'المستوى'}</small><b>${c.max ? 'المستوى الأعلى' : `المستوى ${c.level}`}</b></div>
                ${c.gained ? `<div class="lv-gain">+${num(c.gained)} XP</div>` : ''}
            </div>
            <div class="lv-bar"><s style="width:${clamp(barFrom)}%"></s></div>
            <div class="lv-foot"><span>${esc(c.reason || '')}</span><bdi>${c.max ? 'MAX' : `${num(c.cur)} / ${num(c.need)}`}</bdi></div>
            ${c.up ? `<div class="lv-up">وصلت إلى المستوى ${c.level}${unlocks.length ? `<span>انفتح لك: ${unlocks.map(esc).join('، ')}</span>` : ''}</div>` : ''}
            ${c.next ? `<div class="lv-next">التالي: <b>${esc(c.next.label)}</b> في المستوى ${c.next.level}</div>` : ''}`;
    }

    // slide the bar to the card's real % (a frame later, so the browser animates it)
    function fill(c) {
        const s = el && el.querySelector('.lv-bar s');
        if (!s) return;
        void s.offsetWidth;
        requestAnimationFrame(() => { s.style.width = `${clamp(c.pct)}%`; });
    }

    function hideLater(c) {
        clearTimeout(hideTimer);
        const ms = ((c.seconds || 4.5) + (c.up ? 2 : 0)) * 1000;
        hideTimer = setTimeout(() => {
            if (!el) return;
            el.classList.remove('in');
            const gone = el;
            goneTimer = setTimeout(() => { if (el === gone) { root.innerHTML = ''; el = null; shown = null; } }, 450);
        }, ms);
    }

    function show(c) {
        clearTimeout(goneTimer);
        const open = el && el.classList.contains('in') && shown;
        if (open) {
            // already on screen: same card, new numbers. The bar starts from where it is now
            // (or from empty after a level up), and a level up keeps its glow until the card hides.
            const sameLevel = shown.level === c.level;
            const from = c.up || !sameLevel ? 0 : clamp(el.querySelector('.lv-bar s') ? parseFloat(el.querySelector('.lv-bar s').style.width) : c.fromPct);
            const keepUp = c.up || (sameLevel && shown.up);
            const card = Object.assign({}, c, keepUp && !c.up ? { up: true, unlocks: shown.unlocks, oldLevel: shown.oldLevel } : {});
            el.className = `lv-card in${card.up ? ' up' : ''}`;
            el.innerHTML = inner(card, from);
            if (c.up) { const b = el.querySelector('.lv-badge'); if (b) { b.style.animation = 'none'; void b.offsetWidth; b.style.animation = ''; } }
            shown = card;
            fill(card);
            hideLater(card);
            return;
        }
        root.innerHTML = `<div class="lv-card${c.up ? ' up' : ''}">${inner(c, c.fromPct)}</div>`;
        el = root.firstElementChild;
        shown = c;
        void el.offsetWidth;
        requestAnimationFrame(() => {
            if (!el) return;
            el.classList.add('in');
            setTimeout(() => fill(c), 250);
        });
        hideLater(c);
    }

    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || !m.card) return;
        if (m.action === 'gain' || m.action === 'show') show(m.card);
    });
})();
