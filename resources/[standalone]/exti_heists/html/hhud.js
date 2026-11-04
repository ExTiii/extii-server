/* EX_Tii heists: the chase bar. The game (client/npc.lua) sends { action: 'hud', state } every half second.
   The bar is built once per kind and only its words, time and progress change after that: no blinking. */
(() => {
    const box = document.createElement('div'); box.id = 'hhud'; box.className = 'off'; document.body.appendChild(box);
    const ICON = {
        siren: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 18v-6a5 5 0 0 1 10 0v6"/><path d="M5 21h14v-3H5z"/><path d="M12 3v2M4.2 6.2l1.4 1.4M19.8 6.2l-1.4 1.4"/></svg>',
        eye: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6z"/><circle cx="12" cy="12" r="2.8"/></svg>',
        hand: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 11V6a2 2 0 0 0-4 0v5M14 10V4a2 2 0 0 0-4 0v6M10 10.5V6a2 2 0 0 0-4 0v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/></svg>',
        hide: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3l18 18"/><path d="M10.6 6.1A9.6 9.6 0 0 1 12 6c6 0 9.5 6 9.5 6a17 17 0 0 1-3.2 3.8M6.2 7.6A16 16 0 0 0 2.5 12s3.5 6 9.5 6a9 9 0 0 0 4.2-1"/></svg>',
    };
    const mmss = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
    const FULL = { seen: true, rage: true, arriving: true };   // kinds with no countdown (a full bar)
    function words(st) {
        return ({
            coming: ['siren', 'إنذار! حراسة الحي في الطريق', 'اخرج قبل أن يصلوا'],
            arriving: ['siren', 'حراسة الحي تصل الآن', st.units ? `${st.units} حرّاس يقتربون من المكان` : 'سياراتهم تقترب من المكان'],
            seen: ['eye', 'حراسة الحي تراك', st.units ? `${st.units} حرّاس يطاردونك · اختفِ عن أنظارهم` : 'اختفِ عن أنظارهم'],
            hiding: ['hide', 'فقدوا أثرك', 'ابقَ بعيدًا عن أنظارهم حتى ينتهي العدّ'],
            quiet: ['hide', 'الكاميرات والإنذار معطّلة', 'افتح الخزائن قبل أن تعود'],
            hold: ['hand', 'لا إطلاق نار', st.why === 'hostages' ? 'رأوا الرهائن · ينتظرون اتفاقًا (رسائل المفاوض) · بعدها يقتحمون' : (st.why === 'deal' ? 'اتفاق: خذ الرهائن إلى الدائرة الحمراء وأطلقهم' : 'مهلة · اختفِ قبل أن يلحقوا بك')],
            rage: ['siren', 'آذيت رهينة!', 'لا مفاوضات بعد الآن · يقتحمون'],
            lock: ['hide', 'قفل الوقت يعمل', 'الباب يُفتح وحده حين ينتهي العدّ'],
            fuse: ['siren', 'الفتيل يعمل', 'ابتعد عن الشاحنة!'],
        })[st.kind] || ['siren', '', ''];
    }
    let kind = null, total = 1, el = null;
    function build(st) {
        const T = words(st);
        box.innerHTML = `<div class="hh ${st.kind}"><div class="ic">${ICON[T[0]]}</div><div class="tx"><b></b><span></span></div>${FULL[st.kind] ? '' : '<div class="t"></div>'}<div class="prog"><i></i></div></div>`;
        el = { b: box.querySelector('b'), sp: box.querySelector('.tx span'), t: box.querySelector('.t'), bar: box.querySelector('.prog i') };
    }
    function render(st) {
        if (!st) { box.className = 'off'; box.innerHTML = ''; kind = null; el = null; return; }
        const s = Math.max(0, st.seconds | 0);
        if (st.kind !== kind || !el) { kind = st.kind; total = Math.max(1, s); build(st); }
        if (s > total) total = s;   // (more time was given)
        const T = words(st);
        if (el.b.textContent !== T[1]) el.b.textContent = T[1];
        if (el.sp.textContent !== T[2]) el.sp.textContent = T[2];
        if (el.t) { const v = mmss(s); if (el.t.textContent !== v) el.t.textContent = v; }
        el.bar.style.width = (FULL[st.kind] ? 100 : Math.round((s / total) * 100)) + '%';
        box.className = '';
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
        nz.querySelector('.lb span').textContent = d.alarm ? 'استيقظ صاحب البيت!' : (d.sleeper ? 'صاحب البيت نائم بجانبك...' : (v >= 70 ? 'هدّئ نفسك...' : 'امشِ بهدوء'));
    }
    window.addEventListener('message', (e) => { const d = e.data || {}; if (d.action === 'hud') render(d.state); else if (d.action === 'noise') noise(d); });
    window.EXH_HUD = { render };
})();
