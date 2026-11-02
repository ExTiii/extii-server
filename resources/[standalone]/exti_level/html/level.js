// The XP card: { gained, reason, level, cur, need, pct, fromPct, up, oldLevel, unlocks, next, max, seconds }
(() => {
    const root = document.getElementById('lv');
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const num = (n) => Math.round(n || 0).toLocaleString('en-US');
    let el = null, hideTimer = null, queue = [], busy = false;

    function render(c) {
        const unlocks = Array.isArray(c.unlocks) ? c.unlocks : c.unlocks ? Object.values(c.unlocks) : [];
        return `<div class="lv-card${c.up ? ' up' : ''}">
            <div class="lv-top">
                <div class="lv-badge">${c.level}</div>
                <div class="lv-titles"><small>${c.up ? 'مستوى جديد!' : 'المستوى'}</small><b>${c.max ? 'المستوى الأعلى' : `المستوى ${c.level}`}</b></div>
                ${c.gained ? `<div class="lv-gain">+${num(c.gained)} XP</div>` : ''}
            </div>
            <div class="lv-bar"><s style="width:${Math.max(0, Math.min(100, c.fromPct || 0))}%"></s></div>
            <div class="lv-foot"><span>${esc(c.reason || '')}</span><bdi>${c.max ? 'MAX' : `${num(c.cur)} / ${num(c.need)}`}</bdi></div>
            ${c.up ? `<div class="lv-up">وصلت إلى المستوى ${c.level}${unlocks.length ? `<span>انفتح لك: ${unlocks.map(esc).join('، ')}</span>` : ''}</div>` : ''}
            ${c.next ? `<div class="lv-next">التالي: <b>${esc(c.next.label)}</b> في المستوى ${c.next.level}</div>` : ''}
        </div>`;
    }

    function play(c) {
        busy = true;
        clearTimeout(hideTimer);
        root.innerHTML = render(c);
        el = root.firstElementChild;
        requestAnimationFrame(() => {
            el.classList.add('in');
            setTimeout(() => { const s = el.querySelector('.lv-bar s'); if (s) s.style.width = `${Math.max(0, Math.min(100, c.pct))}%`; }, 250);
        });
        const ms = ((c.seconds || 4.5) + (c.up ? 2 : 0)) * 1000;
        hideTimer = setTimeout(() => {
            if (el) el.classList.remove('in');
            setTimeout(() => { busy = false; if (queue.length) play(queue.shift()); }, 450);
        }, ms);
    }

    // several gains close together: only the newest small one waits, a level up always shows
    function push(c) {
        if (!busy) return play(c);
        queue = queue.filter((q) => q.up);
        queue.push(c);
    }

    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || !m.card) return;
        if (m.action === 'gain' || m.action === 'show') push(m.card);
    });
})();
