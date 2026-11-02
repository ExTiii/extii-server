// The XP card: { gained, reason, level, cur, need, pct, fromPct, up, oldLevel, unlocks, next, max, seconds }
// The bar fills from the right: gold = the XP you had, a glowing piece = what you just got.
// The numbers count up live. A new gain while the card is showing updates that card right away.
(() => {
    const root = document.getElementById('lv');
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const num = (n) => Math.round(n || 0).toLocaleString('en-US');
    const clamp = (n) => Math.max(0, Math.min(100, Number(n) || 0));
    const MIN_PIECE = 2.5; // the glowing piece is always at least this wide so a small gain is still seen
    let el = null, hideTimer = null, goneTimer = null, countRaf = null;
    let shown = null;   // the card on screen
    let barNow = 0;     // where the gold bar is (%)
    let curNow = 0;     // the number shown on the left (XP in this level)

    function inner(c) {
        const unlocks = Array.isArray(c.unlocks) ? c.unlocks : c.unlocks ? Object.values(c.unlocks) : [];
        return `<div class="lv-top">
                <div class="lv-badge">${c.level}</div>
                <div class="lv-titles"><small>${c.up ? 'مستوى جديد!' : 'المستوى'}</small><b>${c.max ? 'المستوى الأعلى' : `المستوى ${c.level}`}</b></div>
                ${c.gained ? `<div class="lv-gain">+${num(c.gained)} XP</div>` : ''}
            </div>
            <div class="lv-bar"><s></s><i></i></div>
            <div class="lv-foot"><span>${esc(c.reason || '')}</span><bdi>${c.max ? 'MAX' : `<b class="lv-cur">${num(curNow)}</b> / ${num(c.need)} XP<em>${clamp(c.pct).toFixed(1)}%</em>`}</bdi></div>
            ${c.up ? `<div class="lv-up">وصلت إلى المستوى ${c.level}${unlocks.length ? `<span>انفتح لك: ${unlocks.map(esc).join('، ')}</span>` : ''}</div>` : ''}
            ${c.next ? `<div class="lv-next">التالي: <b>${esc(c.next.label)}</b> في المستوى ${c.next.level}</div>` : ''}`;
    }

    // count the XP number up from `from` to `to`
    function countUp(from, to) {
        cancelAnimationFrame(countRaf);
        const t0 = performance.now(), ms = 900;
        const step = (t) => {
            const k = Math.min(1, (t - t0) / ms), v = from + (to - from) * (1 - Math.pow(1 - k, 3));
            curNow = v;
            const b = el && el.querySelector('.lv-cur');
            if (b) b.textContent = num(v);
            if (k < 1) countRaf = requestAnimationFrame(step);
        };
        countRaf = requestAnimationFrame(step);
    }

    // the bar: gold from where it was, the glowing piece over the part just gained, then the gold catches up
    function animate(c, fromPct, fromCur) {
        const s = el.querySelector('.lv-bar s'), i = el.querySelector('.lv-bar i');
        const to = clamp(c.pct), from = Math.min(clamp(fromPct), to);
        s.style.transition = 'none'; s.style.width = `${from}%`;
        i.style.transition = 'none'; i.style.right = `${from}%`; i.style.width = '0%';
        void s.offsetWidth;
        s.style.transition = ''; i.style.transition = '';
        const gained = (c.gained || 0) > 0 && !c.max;
        setTimeout(() => {
            if (gained) {
                const piece = Math.max(to - from, MIN_PIECE);
                const start = Math.max(0, Math.min(from, 100 - piece));
                i.classList.add('on');
                i.style.right = `${start}%`;
                i.style.width = `${piece}%`;
            }
            countUp(fromCur, c.cur || 0);
            setTimeout(() => { s.style.width = `${to}%`; }, gained ? 650 : 0);
        }, 120);
        barNow = to;
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
        let fromPct, fromCur, card = c;
        if (open) {
            // already on screen: same card, new numbers, the bar goes on from where it is
            const sameLevel = shown.level === c.level;
            fromPct = c.up || !sameLevel ? 0 : barNow;
            fromCur = c.up || !sameLevel ? 0 : curNow;
            if (!c.up && sameLevel && shown.up) card = Object.assign({}, c, { up: true, unlocks: shown.unlocks, oldLevel: shown.oldLevel });
            el.className = `lv-card in${card.up ? ' up' : ''}`;
            el.innerHTML = inner(card);
        } else {
            fromPct = c.up ? 0 : clamp(c.fromPct);
            fromCur = c.up ? 0 : Math.max(0, (c.cur || 0) - (c.gained || 0));
            curNow = fromCur;
            root.innerHTML = `<div class="lv-card${c.up ? ' up' : ''}">${inner(c)}</div>`;
            el = root.firstElementChild;
            void el.offsetWidth;
            requestAnimationFrame(() => { if (el) el.classList.add('in'); });
        }
        shown = card;
        animate(card, fromPct, fromCur);
        hideLater(card);
    }

    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || !m.card) return;
        if (m.action === 'gain' || m.action === 'show') show(m.card);
    });
})();
