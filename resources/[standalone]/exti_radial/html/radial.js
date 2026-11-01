// EX_Tii radial menu (the Z wheel): draws the slices, follows the mouse, tells the game what was picked.
(() => {
    'use strict';
    const R = 250, RI = 100, RC = 78, RRING = 90; // outer edge, inner edge, centre button, thin ring (SVG units)
    const GAP = 2.2;                               // degrees between slices
    const PER_PAGE = 8;                            // more than this: a "more" slice turns the pages

    const wheel = document.getElementById('wheel');
    const svg = document.getElementById('svg');
    const hintBack = document.getElementById('hint-back');
    const ICONS = window.RADIAL_ICONS || {};
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

    const S = { open: false, items: [], page: 0, root: true, title: '', hover: -1, centerHover: false, slices: [] };

    const post = (name, data) => {
        if (!RES) { if (window.__radialMock) window.__radialMock(name, data); return; }
        fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) }).catch(() => {});
    };

    const rad = (deg) => deg * Math.PI / 180;
    const pt = (r, deg) => [r * Math.cos(rad(deg)), r * Math.sin(rad(deg))];
    const fmt = (n) => n.toFixed(2);

    function sectorPath(a0, a1) {
        const [x0, y0] = pt(R, a0), [x1, y1] = pt(R, a1);
        const [i0, j0] = pt(RI, a0), [i1, j1] = pt(RI, a1);
        const large = a1 - a0 > 180 ? 1 : 0;
        return `M${fmt(x0)} ${fmt(y0)} A${R} ${R} 0 ${large} 1 ${fmt(x1)} ${fmt(y1)} L${fmt(i1)} ${fmt(j1)} A${RI} ${RI} 0 ${large} 0 ${fmt(i0)} ${fmt(j0)} Z`;
    }
    function ringPath() { // one item: the whole ring
        return `M${R} 0 A${R} ${R} 0 1 1 ${-R} 0 A${R} ${R} 0 1 1 ${R} 0 Z M${RI} 0 A${RI} ${RI} 0 1 0 ${-RI} 0 A${RI} ${RI} 0 1 0 ${RI} 0 Z`;
    }
    function arcPath(r, a0, a1) {
        const [x0, y0] = pt(r, a0), [x1, y1] = pt(r, a1);
        return `M${fmt(x0)} ${fmt(y0)} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${fmt(x1)} ${fmt(y1)}`;
    }
    function icon(name, x, y, size, cls) {
        const ic = ICONS[name] || ICONS.ellipsis;
        if (!ic) return '';
        const [vb, d] = ic;
        const [, , vw, vh] = vb.split(' ').map(Number);
        const k = size / Math.max(vw, vh);
        const ox = x - (vw * k) / 2, oy = y - (vh * k) / 2;
        return `<path class="icon ${cls}" transform="translate(${fmt(ox)} ${fmt(oy)}) scale(${fmt(k)})" d="${d}"/>`;
    }

    // the items on this page (a "more" slice when there are too many)
    function pageItems() {
        const all = S.items;
        if (all.length <= PER_PAGE) return all;
        const per = PER_PAGE - 1;
        const pages = Math.ceil(all.length / per);
        const page = ((S.page % pages) + pages) % pages;
        const list = all.slice(page * per, page * per + per);
        list.push({ id: '__more', label: 'المزيد', icon: 'ellipsis', more: true });
        return list;
    }

    function render() {
        const items = pageItems();
        const n = items.length;
        const step = 360 / n;
        const parts = [];
        S.slices = [];
        for (let i = 0; i < n; i++) {
            const it = items[i];
            const mid = -90 + i * step;
            const a0 = mid - step / 2 + GAP / 2, a1 = mid + step / 2 - GAP / 2;
            const on = i === S.hover ? 'on' : '';
            const dim = it.disabled ? 'dim' : '';
            const path = n === 1 ? ringPath() : sectorPath(a0, a1);
            parts.push(`<path class="slice ${on} ${it.disabled ? 'off' : ''}" data-i="${i}" d="${path}" fill-rule="evenodd"/>`);
            // the little dark arc at the inner edge of the slice under the mouse
            if (on) {
                const w = Math.min(26, (a1 - a0) * 0.4);
                parts.push(`<path class="mark" d="${arcPath(RI + 8, mid - w / 2, mid + w / 2)}"/>`);
            }
            // icon above, label below (straight down, whatever the angle), like the video
            const rm = (R + RI) / 2 + 4;
            const [px, py] = pt(rm, mid);
            const size = n <= 4 ? 44 : 38;
            parts.push(icon(it.icon, px, py - 13, size, `${on} ${dim}`));
            parts.push(`<text class="label ${on} ${dim}" x="${fmt(px)}" y="${fmt(py + 34)}">${esc(it.label)}</text>`);
            S.slices.push({ a0: mid - step / 2, a1: mid + step / 2, item: it });
        }
        parts.push(`<circle class="ring" r="${RRING}"/>`);
        parts.push(`<circle class="center ${S.centerHover ? 'on' : ''}" r="${RC}"/>`);
        parts.push(`<text class="ctext" y="7">${esc(S.title)}</text>`);
        svg.innerHTML = parts.join('');
        hintBack.textContent = S.root ? 'إغلاق' : 'رجوع';
    }
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

    // where is the mouse on the wheel?
    function hit(cx, cy) {
        const box = wheel.getBoundingClientRect();
        const k = box.width / (2 * R);
        const x = (cx - (box.left + box.width / 2)) / k, y = (cy - (box.top + box.height / 2)) / k;
        const d = Math.hypot(x, y);
        if (d <= RC) return { center: true };
        if (d < RI || d > R + 12) return { none: true };
        let a = Math.atan2(y, x) * 180 / Math.PI; // -180..180, 0 = right
        const n = S.slices.length;
        if (!n) return { none: true };
        const step = 360 / n;
        let rel = a + 90 + step / 2; // 0 at the start of slice 0
        rel = ((rel % 360) + 360) % 360;
        return { index: Math.floor(rel / step) };
    }

    function setHover(idx, center) {
        if (idx === S.hover && center === S.centerHover) return;
        S.hover = idx; S.centerHover = center;
        render();
    }

    function show(data, isSub) {
        S.items = Array.isArray(data.items) ? data.items : [];
        S.page = 0;
        S.root = !isSub;
        S.title = isSub ? 'رجوع' : 'القائمة';
        S.hover = -1; S.centerHover = false;
        render();
        if (!S.open) {
            S.open = true;
            wheel.setAttribute('aria-hidden', 'false');
            wheel.style.pointerEvents = 'auto';
            requestAnimationFrame(() => wheel.classList.add('show'));
        } else {
            wheel.classList.remove('pulse'); void svg.offsetWidth; wheel.classList.add('pulse');
        }
    }
    function hide() {
        if (!S.open) return;
        S.open = false;
        wheel.classList.remove('show', 'pulse');
        wheel.setAttribute('aria-hidden', 'true');
        wheel.style.pointerEvents = 'none';
    }

    document.addEventListener('mousemove', (e) => {
        if (!S.open) return;
        const h = hit(e.clientX, e.clientY);
        setHover(h.index != null ? h.index : -1, !!h.center);
    });
    document.addEventListener('mousedown', (e) => {
        if (!S.open) return;
        e.preventDefault();
        if (e.button === 2) { post(S.root ? 'close' : 'back'); return; }
        if (e.button !== 0) return;
        const h = hit(e.clientX, e.clientY);
        if (h.center) { post(S.root ? 'close' : 'back'); return; }
        if (h.index == null) return;
        const s = S.slices[h.index];
        if (!s) return;
        if (s.item.id === '__more') { S.page += 1; S.hover = -1; render(); setHover(hit(e.clientX, e.clientY).index ?? -1, false); return; }
        if (s.item.disabled) return;
        post('select', { id: s.item.id });
    });
    document.addEventListener('contextmenu', (e) => e.preventDefault());
    document.addEventListener('wheel', (e) => { if (S.open && S.items.length > PER_PAGE) { S.page += e.deltaY > 0 ? 1 : -1; render(); } }, { passive: true });
    document.addEventListener('keydown', (e) => {
        if (!S.open) return;
        if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); post(S.root ? 'close' : 'back'); }
        else if (e.code === 'KeyZ') { e.preventDefault(); post('close'); }
    });

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'open') show(m, false);
        else if (m.action === 'sub') show(m, true);
        else if (m.action === 'close') hide();
    });

    window.RADIAL = { show, hide, S, render }; // for the preview outside the game
})();
