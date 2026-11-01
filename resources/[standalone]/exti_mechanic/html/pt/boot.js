// EX_Tii Mechanic tablet — starting up: the messages from the game, the mouse and keyboard,
// opening and closing. (Loaded last, after the apps.)
(() => {
    const { S, os, host, MIRROR, render, post, call, runAct, setPath, pushMirror, mirrorUi, applyMirror, APPS } = PT;

    // the mirror only draws what the real tablet sends
    if (MIRROR) {
        window.addEventListener('message', (e) => {
            let msg = e.data;
            if (typeof msg === 'string') { try { msg = JSON.parse(msg); } catch (_) { return; } }
            if (msg && msg.type) applyMirror(msg);
        });
        return;
    }

    // ------------------------------------------------------------------
    // the size on your screen: on the right side, so your character stays visible in the middle
    // ------------------------------------------------------------------
    const device = document.getElementById('pt-device');
    function fit() {
        const s = Math.min((window.innerHeight * 0.66) / 880, (window.innerWidth * 0.46) / 1320);
        device.style.setProperty('--fit', `scale(${s.toFixed(4)})`);
    }
    window.addEventListener('resize', fit);
    fit();

    // ------------------------------------------------------------------
    // mouse and keyboard (one listener for every button on the tablet)
    // ------------------------------------------------------------------
    os.addEventListener('click', (e) => {
        const el = e.target.closest('[data-act]');
        if (!el || !os.contains(el) || el.disabled) return;
        runAct(el.dataset.act, el, e);
    });
    os.addEventListener('input', (e) => {
        const t = e.target;
        if (!t.dataset || !t.dataset.model) return;
        setPath(t.dataset.model, t.value);
        if (t.dataset.live) render(); else pushMirror();
    });
    os.addEventListener('keydown', (e) => {
        const t = e.target;
        if (e.key === 'Enter' && t.dataset && t.dataset.enter && !e.shiftKey) {
            e.preventDefault();
            runAct(t.dataset.enter, t, e);
        }
    });
    // keep the hands' copy scrolled the same way
    os.addEventListener('scroll', (e) => {
        const el = e.target;
        if (!el.dataset || !el.dataset.scroll) return;
        S.scrolls[el.dataset.scroll] = el.scrollTop;
        mirrorUi({ type: 'scroll', key: el.dataset.scroll, top: el.scrollTop }, 60);
        clearTimeout(el._t);
        el._t = setTimeout(pushMirror, 200);
    }, true);
    // the mouse wheel turns the home pages
    os.addEventListener('wheel', (e) => {
        if (S.app || Math.abs(e.deltaY) < 20) return;
        const next = Math.max(0, Math.min(1, S.page + (e.deltaY > 0 ? 1 : -1)));
        if (next !== S.page) { S.page = next; render(); }
    }, { passive: true });
    // drag the home screen sideways to turn the pages (the screen follows the mouse).
    // The pages sit right to left, so dragging to the right shows the next page.
    let swipe = null;
    let eatClick = false;
    const pageCount = () => os.querySelectorAll('.pt-dots button').length || 1;
    os.addEventListener('mousedown', (e) => {
        if (S.app || S.sheet || S.viewer || e.button !== 0) return;
        const area = e.target.closest('.pt-pages');
        const track = area && area.querySelector('.pt-track');
        if (!track) return;
        const w = area.offsetWidth || 1;
        const k = w / (area.getBoundingClientRect().width || w); // the tablet is drawn scaled down
        swipe = { x: e.clientX, y: e.clientY, k, w, track, moved: false };
    });
    document.addEventListener('mousemove', (e) => {
        if (!swipe) return;
        const dx = (e.clientX - swipe.x) * swipe.k;
        if (!swipe.moved) {
            if (Math.abs(dx) < 8) return;
            if (Math.abs(e.clientY - swipe.y) * swipe.k > Math.abs(dx)) { swipe = null; return; }
            swipe.moved = true;
        }
        // stiff past the first and the last page
        const most = (pageCount() - 1 - S.page) * swipe.w;
        const least = -S.page * swipe.w;
        let d = dx;
        if (d > most) d = most + (d - most) / 4;
        if (d < least) d = least + (d - least) / 4;
        swipe.track.style.transition = 'none';
        swipe.track.style.transform = `translateX(calc(${S.page * 100}% + ${d.toFixed(1)}px))`;
    });
    document.addEventListener('mouseup', (e) => {
        if (!swipe) return;
        const s = swipe;
        swipe = null;
        if (!s.moved) return;
        // the click that comes with this mouseup must not open an app
        eatClick = true;
        setTimeout(() => { eatClick = false; }, 0);
        const dx = (e.clientX - s.x) * s.k;
        let next = S.page;
        if (Math.abs(dx) > s.w * 0.12) next = Math.max(0, Math.min(pageCount() - 1, S.page + (dx > 0 ? 1 : -1)));
        s.track.style.transition = '';
        s.track.style.transform = `translateX(${next * 100}%)`;
        if (next === S.page) return;
        S.page = next;
        pushMirror();
        setTimeout(render, 400); // after the slide, so it doesn't jump
    });
    os.addEventListener('click', (e) => {
        if (!eatClick) return;
        eatClick = false;
        e.stopImmediatePropagation();
        e.preventDefault();
    }, true);

    document.addEventListener('keydown', (e) => {
        if (!S.open) return;
        if (e.key === 'Escape') {
            e.preventDefault();
            if (S.viewer) { S.viewer = null; render(); return; }
            if (S.sheet) { runAct('sheetCancel'); return; }
            const a = S.app && APPS[S.app];
            if (a && a.back && a.back()) return;
            if (S.app === 'gallery' && S.gal && S.gal.open) { S.gal.open = null; render(); return; }
            close(true);
            return;
        }
        if (e.key === 'F6') { e.preventDefault(); close(true); return; }
        const a = S.app && APPS[S.app];
        const typing = e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT');
        if (a && a.key && !typing) a.key(e);
    });

    // ------------------------------------------------------------------
    // open / close
    // ------------------------------------------------------------------
    let closing = false;
    let closeTimer = null;
    let badgeTimer = null;

    function close(tellGame) {
        if (!S.open || closing) return;
        closing = true;
        const a = S.app && APPS[S.app];
        if (a && a.leave) a.leave();
        clearInterval(badgeTimer);
        host.classList.add('closing');
        closeTimer = setTimeout(() => {
            closeTimer = null;
            closing = false;
            S.open = false;
            S.sheet = null;
            S.viewer = null;
            S.pick = null;
            host.className = 'pt-root hidden';
            render();
        }, 200);
        if (tellGame) post('ptClose');
    }

    function badges() {
        call('badges').then((res) => {
            if (!res.ok) return;
            const b = res.r || {};
            if (b.chat !== S.badges.chat || b.forms !== S.badges.forms) { S.badges = b; render(); }
        });
    }

    function open(msg) {
        const d = msg.data || {};
        if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; }
        closing = false;
        S.open = true;
        S.me = d.me || null;
        S.settings = d.settings || { mode: 'dark', wallpaper: '' };
        S.badges = d.badges || { chat: 0, forms: 0 };
        S.skew = d.now ? d.now * 1000 - Date.now() : 0;
        S.cfg = Object.assign({}, S.cfg, msg.cfg || {});
        S.cfg.stations = PT.list(S.cfg.stations);
        S.cfg.colors = PT.list(S.cfg.colors);
        S.clock = msg.clock || S.clock;
        S.app = null;
        S.page = 0;
        S.sheet = null;
        S.viewer = null;
        S.pick = null;
        S.toast = null;
        S.scrolls = {};
        host.className = 'pt-root';
        render();
        clearInterval(badgeTimer);
        badgeTimer = setInterval(badges, 20000);
    }

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        switch (msg.action) {
            case 'ptablet:open': open(msg); break;
            case 'ptablet:close': close(false); break;
            case 'ptablet:clock': {
                S.clock = msg.t || '';
                const c = document.getElementById('pt-clock');
                if (c) c.textContent = S.clock;
                break;
            }
            // the camera: the tablet hides while you aim, and comes back with the photo
            case 'ptablet:hide': host.classList.add('away'); break;
            case 'ptablet:cameraDone':
                host.classList.remove('away');
                if (PT.cameraDone) PT.cameraDone(msg.result);
                break;
            case 'ptablet:cctvDone': host.classList.remove('away'); render(); break;
            case 'ptablet:chat':
                if (S.app === 'chat' && APPS.chat.push) APPS.chat.push(msg.chatId);
                else badges();
                break;
            case 'ptablet:chatRead':
                if (S.app === 'chat' && APPS.chat.read) APPS.chat.read(msg.chatId);
                break;
            default: break;
        }
    });

    PT.close = close;
    PT.openTablet = open;
})();
