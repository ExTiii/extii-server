/* EX_Tii heists: the chase bar. The game (client/npc.lua) sends { action: 'hud', state } every half second. */
(() => {
    const box = document.createElement('div'); box.id = 'hhud'; box.className = 'off'; document.body.appendChild(box);
    const ICON = {
        siren: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 18v-6a5 5 0 0 1 10 0v6"/><path d="M5 21h14v-3H5z"/><path d="M12 3v2M4.2 6.2l1.4 1.4M19.8 6.2l-1.4 1.4"/></svg>',
        eye: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6z"/><circle cx="12" cy="12" r="2.8"/></svg>',
        hide: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3l18 18"/><path d="M10.6 6.1A9.6 9.6 0 0 1 12 6c6 0 9.5 6 9.5 6a17 17 0 0 1-3.2 3.8M6.2 7.6A16 16 0 0 0 2.5 12s3.5 6 9.5 6a9 9 0 0 0 4.2-1"/></svg>',
    };
    const mmss = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
    let kind = null, total = 1;
    function render(st) {
        if (!st) { box.className = 'off'; box.innerHTML = ''; kind = null; return; }
        const s = Math.max(0, st.seconds | 0);
        if (st.kind !== kind) { kind = st.kind; total = Math.max(1, s); }
        const T = {
            coming: ['siren', 'إنذار! حراسة الحي في الطريق', 'اخرج قبل أن يصلوا'],
            seen: ['eye', 'حراسة الحي تراك', st.units ? `${st.units} حرّاس يطاردونك · اختفِ عن أنظارهم` : 'اختفِ عن أنظارهم'],
            hiding: ['hide', 'فقدوا أثرك', 'ابقَ بعيدًا عن أنظارهم حتى ينتهي العدّ'],
        }[st.kind] || ['siren', '', ''];
        const pct = st.kind === 'seen' ? 100 : Math.round((s / total) * 100);
        box.className = '';
        box.innerHTML = `<div class="hh ${st.kind}"><div class="ic">${ICON[T[0]]}</div><div class="tx"><b>${T[1]}</b><span>${T[2]}</span></div>${st.kind === 'seen' ? '' : `<div class="t">${mmss(s)}</div>`}<div class="prog"><i style="width:${pct}%"></i></div></div>`;
    }
    // the noise meter inside a house
    const nz = document.createElement('div'); nz.id = 'hnoise'; nz.className = 'off';
    nz.innerHTML = '<div class="lb"><b>الضجيج</b><span>امشِ بهدوء</span></div><div class="tr"><i style="width:0%"></i></div>';
    document.body.appendChild(nz);
    function noise(d) {
        if (d.show === false) { nz.className = 'off'; return; }
        const v = Math.max(0, Math.min(100, d.value | 0));
        nz.className = d.alarm ? 'alarm' : (v >= 70 ? 'hot' : '');
        nz.querySelector('i').style.width = v + '%';
        nz.querySelector('.lb span').textContent = d.alarm ? 'استيقظ صاحب البيت!' : (v >= 70 ? 'هدّئ نفسك...' : 'امشِ بهدوء');
    }
    window.addEventListener('message', (e) => { const d = e.data || {}; if (d.action === 'hud') render(d.state); else if (d.action === 'noise') noise(d); });
    window.EXH_HUD = { render };
})();
