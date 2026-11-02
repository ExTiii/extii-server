// The nitro gauge: shown while you drive a car with nitro (the game sends { action: 'nos', show, amt })
(() => {
    let el = null;
    function build() {
        el = document.getElementById('nos');
        if (el) el.innerHTML = '<b>NOS</b><u><s></s></u><em>0%</em>';
    }
    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || m.action !== 'nos' || !el) return;
        el.classList.toggle('hidden', !m.show);
        if (!m.show) return;
        const a = Math.max(0, Math.min(100, m.amt | 0));
        el.querySelector('s').style.width = a + '%';
        el.querySelector('em').textContent = a + '%';
        el.classList.toggle('empty', a <= 0);
        el.classList.toggle('low', a > 0 && a < 25);
    });
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
})();
