/* =====================================================================
   EX_Tii Police: the call card for officers on duty (like NoPixel's dispatch).
   The game (client/dispatch.lua) decides what is shown; this page only draws it.
   ===================================================================== */
(() => {
    const box = document.getElementById('dispatch');
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const ICON = {
        gun: '<path d="M3.5 7.5h15.5v4.5h-6.5l-1.2 2.5h-2.3l-1.2 4.5H4.6l1.6-6.5H3.5z"/><path d="M10.5 12v1.8"/>',
        car: '<path d="M4 15l1.5-5A2 2 0 0 1 7.4 8.6h9.2a2 2 0 0 1 1.9 1.4L20 15"/><rect x="3" y="15" width="18" height="4" rx="1.5"/><circle cx="7.5" cy="19" r="1.4"/><circle cx="16.5" cy="19" r="1.4"/>',
        pill: '<path d="M10.5 3.5a5 5 0 0 1 7 7l-7 7a5 5 0 0 1-7-7z"/><path d="M7 7l7 7"/>',
        spray: '<rect x="8" y="9" width="7" height="12" rx="1.5"/><path d="M9.5 9V6.5h4V9M11.5 4h1M17 5l2-1M17 7h2.5M17 9l2 1"/>',
        eye: '<path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6z"/><circle cx="12" cy="12" r="2.8"/>',
        phone: '<path d="M6.5 3.5h3l1.5 4-2 1.5a11 11 0 0 0 6 6l1.5-2 4 1.5v3a2 2 0 0 1-2 2A16 16 0 0 1 4.5 5.5a2 2 0 0 1 2-2z"/>',
        bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
        pin: '<path d="M12 21s-6.5-6.2-6.5-11a6.5 6.5 0 0 1 13 0c0 4.8-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
        info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
        clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
        user: '<circle cx="12" cy="8" r="3.6"/><path d="M5 20.5a7 7 0 0 1 14 0"/>',
        mask: '<path d="M4 8.5c2.5-2 13.5-2 16 0 0 6-3.5 10-8 10s-8-4-8-10z"/><path d="M7.5 11.5h3M13.5 11.5h3"/>',
        plate: '<rect x="3" y="7" width="18" height="10" rx="2"/><path d="M7 12h10"/>',
        arrow: '<path d="M12 20V5M6 11l6-6 6 6"/>',
        cam: '<path d="M3 8h11l4-3v12l-4-3H3z"/><path d="M7 17v3"/>',
    };
    const svg = (n, s = 15) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${ICON[n] || ICON.bell}</svg>`;
    const ago = (s) => (s < 10 ? 'الآن' : s < 60 ? `قبل ${s} ث` : `قبل ${Math.floor(s / 60)} د`);
    const far = (m) => (m >= 1000 ? `${(m / 1000).toFixed(1)} كم` : `${m} م`);

    const audio = {};
    function sound(urgent) {
        try {
            const n = urgent ? 'dispatch_urgent' : 'dispatch';
            const a = audio[n] || (audio[n] = new Audio(`sfx/${n}.ogg`));
            a.currentTime = 0; a.volume = urgent ? 0.6 : 0.45; a.play().catch(() => {});
        } catch (e) { /* no sound is fine */ }
    }

    // what the reporter saw: a camera or a witness; nobody sees everything
    function seen(w) {
        if (!w || typeof w !== 'object') return '';
        const rows = [];
        if (w.person) rows.push(`<div class="dp-row">${svg(w.person === 'ملثّم' ? 'mask' : 'user')}<span>${esc(w.person)}</span></div>`);
        if (w.car || w.plate) rows.push(`<div class="dp-row">${svg('car')}<span>${esc(w.car || 'سيارة')}</span>${w.plate ? `<span class="dp-plate">${esc(w.plate)}</span>` : ''}</div>`);
        if (w.dir) rows.push(`<div class="dp-row">${svg('arrow')}<span>هرب باتجاه ${esc(w.dir)}</span></div>`);
        const head = `<div class="dp-by">${svg(w.by === 'كاميرا مراقبة' ? 'cam' : 'eye', 13)}<span>${esc(w.by || 'شاهد عيان')}${rows.length ? '' : ' · لم يرَ التفاصيل'}</span></div>`;
        return `<div class="dp-seen">${head}${rows.join('')}</div>`;
    }

    let shown = new Set();
    function render(m) {
        const cards = m.cards || [];
        const html = cards.map((c) => {
            const fresh = !shown.has(c.id);
            const where = [c.street, c.area].filter(Boolean).join(' · ') || '—';
            const status = c.mine ? `<span class="dp-taken mine">${svg('info', 13)} استلمته · الطريق على الخريطة</span>`
                : c.takenBy ? `<span class="dp-taken">${svg('info', 13)} استلمه ${esc(c.takenBy)}</span>`
                : '<span class="dp-key"><kbd>G</kbd> استلم البلاغ</span>';
            return `<div class="dp-card ${c.urgent ? 'urgent' : ''} ${fresh ? 'in' : ''} ${c.focus ? 'focus' : ''}">
                <div class="dp-head"><span class="dp-code">${esc(c.code)}</span><b class="dp-title">${svg(c.icon, 16)}${esc(c.label)}</b><span class="dp-id">#${c.id}</span></div>
                <div class="dp-row">${svg('pin')}<span class="ltr">${esc(where)}</span></div>
                ${c.text && c.text !== c.label ? `<div class="dp-row dim">${svg('info')}<span>${esc(c.text)}</span></div>` : ''}
                ${seen(c.witness)}
                <div class="dp-row dim">${svg('clock')}<span>${ago(c.seen)}</span><span class="dp-sep">·</span><span>${far(c.dist)}</span></div>
                <div class="dp-foot">${status}${m.index ? `<span class="dp-nav"><kbd>↑</kbd><kbd>↓</kbd> ${m.index}/${m.total}</span>` : ''}</div>
            </div>`;
        }).join('');
        box.innerHTML = html;
        shown = new Set(cards.map((c) => c.id));
        box.classList.toggle('on', cards.length > 0);
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'dispatch:render') render(m);
        else if (m.action === 'dispatch:sound') sound(m.urgent);
    });
    window.EXP_DISPATCH = { render, sound }; // (for testing outside the game)
})();
