/* EX_Tii heists: the negotiator's phone call (right side). The game sends { action: 'call', ... }:
   ring        the phone rings (the box shows "incoming call")
   say         the negotiator's words      me      what the robber said (his pick)
   typing      the negotiator is answering opts    the answers (keys 1-4), [] = none
   trust       0-100                       close   seconds until the box goes away (0 = stays)
   hide        put it away now */
(() => {
    const box = document.createElement('div'); box.id = 'hcall'; box.className = 'off';
    box.innerHTML = `
        <div class="ch">
            <div class="av"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l7 3v5c0 5-3.5 8.5-7 10-3.5-1.5-7-5-7-10V6z"/></svg></div>
            <div class="who"><b>مفاوض حراسة الحي</b><span id="hcState">مكالمة جارية</span></div>
            <div class="tm" id="hcTime">00:00</div>
        </div>
        <div class="tr"><span>الثقة</span><div class="tb"><i id="hcTrust"></i></div></div>
        <div class="msgs" id="hcMsgs"></div>
        <div class="opts" id="hcOpts"></div>`;
    document.body.appendChild(box);
    const $ = (id) => document.getElementById(id);
    const esc = (t) => String(t == null ? '' : t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
    const DIG = ['1', '2', '3', '4'];   // (the keys as they are printed on the keyboard)
    let started = 0, clock = null, closeT = null, history = [];

    function tick() {
        const s = Math.floor((Date.now() - started) / 1000);
        $('hcTime').textContent = `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
    }
    function open() {
        if (box.className === 'off') {
            box.className = '';
            if (!started) { started = Date.now(); clearInterval(clock); clock = setInterval(tick, 1000); tick(); }
        }
    }
    function hide() {
        box.className = 'off'; clearTimeout(closeT);
    }
    function drawMsgs(typing) {
        const last = history.slice(-3);
        $('hcMsgs').innerHTML = last.map((m) => `<div class="m ${m.who}">${esc(m.text)}</div>`).join('')
            + (typing ? '<div class="m n dots"><i></i><i></i><i></i></div>' : '');
    }
    function drawOpts(opts) {
        $('hcOpts').innerHTML = (opts || []).map((t, i) => `<div class="o"><span class="k">${DIG[i] || i + 1}</span><span class="t">${esc(t)}</span></div>`).join('');
        $('hcOpts').classList.toggle('none', !(opts && opts.length));
    }
    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action !== 'call') return;
        clearTimeout(closeT);
        if (d.hide) return hide();
        if (d.ring) {
            history = [];
            open(); box.classList.add('ring');
            started = Date.now(); clearInterval(clock); clock = setInterval(tick, 1000); tick();
            $('hcState').textContent = 'اتصال وارد...';
            drawMsgs(false); drawOpts([]);
            return;
        }
        open(); box.classList.remove('ring');
        $('hcState').textContent = 'مكالمة جارية';
        if (typeof d.trust === 'number') {
            const v = Math.max(0, Math.min(100, d.trust));
            $('hcTrust').style.width = v + '%';
            $('hcTrust').className = v < 25 ? 'lo' : (v >= 60 ? 'hi' : '');
        }
        if (d.me) history.push({ who: 'me', text: d.me });
        if (d.say) history.push({ who: 'n', text: d.say });
        drawMsgs(!!d.typing);
        drawOpts(d.opts);
        if (d.close > 0) closeT = setTimeout(hide, d.close * 1000);
    });
})();
