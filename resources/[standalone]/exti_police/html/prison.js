// =====================================================================
// The prisoner's time card: remaining time, the bar, a hint about the yard jobs
// =====================================================================
const Prison = (() => {
    let root = null, open = false;
    const LOCK = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="10" width="16" height="11" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>';
    const RUN = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="14" cy="4.5" r="1.8"/><path d="M9 20l2.5-6 3-2 1.5 3.5 3 1.5M12 9l-3.5 1.5L7 14M12 9l3 1 2 3"/></svg>';
    const clock = (s) => { s = Math.max(0, Math.floor(s || 0)); const m = Math.floor(s / 60); const r = s % 60; return `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`; };

    function show(d) {
        if (!root) root = document.getElementById('prison');
        const total = Math.max(1, (d.minutes || 1) * 60);
        const left = Math.max(0, d.remaining || 0);
        const pct = Math.max(0, Math.min(100, (left / total) * 100));
        root.innerHTML = `<div class="pr-card ${d.escaped ? 'escaped' : ''}">
            <div class="pr-icon">${d.escaped ? RUN : LOCK}</div>
            <div class="pr-text">
                <div class="pr-top"><b>${d.escaped ? 'هارب من السجن' : 'سجن بولينغبروك'}</b><span>${clock(left)}</span></div>
                <div class="pr-bar"><i style="width:${pct}%"></i></div>
                <div class="pr-hint">${d.escaped ? 'الوقت متوقف · الشرطة تبحث عنك' : 'الأعمال في الساحة (الدوائر الذهبية) تقلّل المدة'}</div>
            </div></div>`;
        root.classList.remove('hidden');
        open = true;
    }
    function hide() {
        if (!root) root = document.getElementById('prison');
        root.classList.add('hidden');
        root.innerHTML = '';
        open = false;
    }
    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'prison') return;
        if (m.open) show(m.data || {}); else hide();
    });
    return { show, hide, get open() { return open; } };
})();
