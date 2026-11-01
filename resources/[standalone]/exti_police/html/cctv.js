// =====================================================================
// The CCTV overlay: REC, the camera's name, the time, the keys
// =====================================================================
const Cctv = (() => {
    let root = null, timer = null;
    const pad = (n) => String(n).padStart(2, '0');
    function stamp() {
        const d = new Date();
        return { time: `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`, date: `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}` };
    }
    function show(d) {
        if (!root) root = document.getElementById('cctv');
        const s = stamp();
        const esc = (x) => String(x == null ? '' : x).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
        root.innerHTML = `<div class="cc-vignette"></div><div class="cc-frame"></div>
            <div class="cc-top"><span class="cc-rec"><i></i>REC</span><div class="cc-cam">${esc(d.label)}<small>${esc(d.area || '')}</small></div></div>
            <div class="cc-topleft"><b id="ccTime">${s.time}</b><span id="ccDate">${s.date}</span></div>
            <div class="cc-bottom">
                <span class="cc-key"><kbd>Mouse</kbd> تحريك</span>
                <span class="cc-key"><kbd>Scroll</kbd> تقريب</span>
                <span class="cc-key"><kbd>←</kbd><kbd>→</kbd> كاميرا أخرى</span>
                <span class="cc-key"><kbd>Esc</kbd> رجوع إلى التابلت</span>
            </div>
            <div class="cc-id">CAM ${pad(d.index || 0)} / ${pad(d.count || 0)}</div>`;
        root.classList.remove('hidden');
        clearInterval(timer);
        timer = setInterval(() => { const x = stamp(); const t = document.getElementById('ccTime'); if (t) t.textContent = x.time; }, 1000);
    }
    function hide() {
        if (!root) root = document.getElementById('cctv');
        clearInterval(timer); timer = null;
        root.classList.add('hidden');
        root.innerHTML = '';
    }
    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'cctv') return;
        if (m.open) show(m.data || {}); else hide();
    });
    return { show, hide };
})();
