/* ======================================================================
   EX_Tii photo tool (admins only, /extiphotos): the game sends a screenshot of the character standing
   in front of a green screen; this cuts out the green, trims the picture to the item and shrinks it to a
   small transparent webp for the picture cards. Nothing here runs for normal players.
   ====================================================================== */
'use strict';
(() => {
    const SIZE = 192;
    const load = (src) => new Promise((ok, bad) => { const i = new Image(); i.onload = () => ok(i); i.onerror = bad; i.src = src; });

    async function cut(src, size) {
        const img = await load(src);
        const side = Math.min(img.width, img.height);
        const c = document.createElement('canvas'); c.width = side; c.height = side;
        const x = c.getContext('2d', { willReadFrequently: true });
        x.drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, side, side);
        const d = x.getImageData(0, 0, side, side), p = d.data;
        let minX = side, minY = side, maxX = -1, maxY = -1;
        for (let i = 0, n = 0; i < p.length; i += 4, n++) {
            const r = p[i], g = p[i + 1], b = p[i + 2], m = Math.max(r, b);
            const k = g > 30 ? (g - m) / g : 0; // how green the pixel is
            let a = 255;
            if (k > 0.32) a = 0;
            else if (k > 0.12) a = Math.round(255 * (0.32 - k) / 0.2);
            if (g > m) p[i + 1] = m; // take the green glow off the edges
            p[i + 3] = a;
            if (a > 24) {
                const px = n % side, py = (n / side) | 0;
                if (px < minX) minX = px; if (px > maxX) maxX = px;
                if (py < minY) minY = py; if (py > maxY) maxY = py;
            }
        }
        if (maxX < 0) return null;
        x.putImageData(d, 0, 0);
        const w = maxX - minX + 1, h = maxY - minY + 1, box = Math.round(Math.max(w, h) * 1.08);
        const o = document.createElement('canvas'); o.width = size; o.height = size;
        const ox = o.getContext('2d'); ox.imageSmoothingQuality = 'high';
        const sx = minX + w / 2 - box / 2, sy = minY + h / 2 - box / 2;
        ox.drawImage(c, sx, sy, box, box, 0, 0, size, size);
        return o.toDataURL('image/webp', 0.82).split(',')[1] || null;
    }

    window.addEventListener('message', async (e) => {
        const m = e.data || {};
        if (m.type !== 'exti_photo') return;
        let data = null;
        try { data = await cut(m.src, m.size || SIZE); } catch (err) { data = null; }
        fetch(`https://${RES}/exti_photo_done`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: m.id, data }) }).catch(() => {});
    });
})();
