/* =====================================================================
   EX_Tii admin tablet (page). Every button asks the server, which checks your rights and logs it.
   ===================================================================== */
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'exti_admin';
    const nui = (name, body) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).then((r) => r.json()).catch(() => null);
    const app = document.getElementById('app');
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.floor(n || 0).toLocaleString('en-US');
    const ago = (t) => { const s = Math.max(0, Math.floor(Date.now() / 1000 - t)); return s < 60 ? `${s} ث` : s < 3600 ? `${Math.floor(s / 60)} د` : s < 86400 ? `${Math.floor(s / 3600)} س` : `${Math.floor(s / 86400)} ي`; };
    const dur = (s) => `${Math.floor(s / 3600)} س ${Math.floor((s % 3600) / 60)} د`;

    let S = null;          // what the server sent on open
    let page = 'home', players = [], sel = null, srv = null, gangs = null, timer = null, q = '';

    const has = (r) => S && (S.rights['*'] || S.rights[r]);
    const arr = (x) => (Array.isArray(x) ? x : []);      // (an empty Lua list can arrive as {})

    // ------------------------------------------------------------- helpers
    function toast(msg, ok = true) {
        if (!msg) return;
        let t = document.querySelector('.toasts'); if (!t) { t = document.createElement('div'); t.className = 'toasts'; document.body.appendChild(t); }
        const e = document.createElement('div'); e.className = `toast ${ok ? 'ok' : 'bad'}`; e.textContent = msg; t.appendChild(e);
        setTimeout(() => e.remove(), 3200);
    }
    function confirmBox(text) {
        return new Promise((done) => {
            const m = document.createElement('div'); m.className = 'modal';
            m.innerHTML = `<div class="box"><p>${esc(text)}</p><div class="row"><button class="btn acc" data-y>نعم، نفّذ</button><button class="btn" data-n>إلغاء</button></div></div>`;
            document.body.appendChild(m);
            m.querySelector('[data-y]').onclick = () => { m.remove(); done(true); };
            m.querySelector('[data-n]').onclick = () => { m.remove(); done(false); };
        });
    }
    async function act(action, data, ask) {
        if (ask && !(await confirmBox(ask))) return null;
        const r = await nui('do', { action, data });
        if (!r) return toast('لا رد من السيرفر', false);
        toast(r.msg || (r.ok ? 'تم' : 'لم ينجح'), !!r.ok);
        return r;
    }
    const self = (what, extra) => nui('self', Object.assign({ what }, extra || {}));
    const fetchX = (what, qq) => nui('fetch', { what, q: qq });
    const val = (id) => { const e = document.getElementById(id); return e ? e.value : ''; };

    // ------------------------------------------------------------- frame
    // [id, label, right, what it is for (the home tiles)]
    const TABS = [
        ['home', 'الرئيسية', 'view', ''],
        ['players', 'اللاعبون', 'view', 'كل لاعب: انتقل، اجلب، أنعش، أنذر، مال، أغراض، وظيفة، سيارات، رخص، طرد وحظر'],
        ['reports', 'البلاغات', 'reports', 'بلاغات اللاعبين (/report): اذهب إليه، اجلبه، أغلق البلاغ'],
        ['me', 'أنا', 'noclip', 'نوكليب، انتقال للعلامة أو لإحداثيات، لا أموت، مخفي، أسماء فوق الرؤوس'],
        ['spawn', 'إنزال', 'car', 'أنزل أي سيارة، أعطِ سيارة مملوكة، أعطِ نفسك أي غرض'],
        ['server', 'السيرفر والعالم', 'view', 'إعلان للجميع، الطقس، الوقت، الكهرباء، إعادة تشغيل الموارد'],
        ['gangs', 'العصابات', 'gangs', 'إنشاء وحذف العصابات، السمعة، البنك، المخزن، الأعضاء'],
        ['test', 'التجربة', 'test', 'عُدد التجربة، الألعاب المصغّرة، الشرطة، السطو'],
        ['logs', 'السجل والحظر', 'ban', 'كل ما فعله الطاقم، المحظورون وفك الحظر'],
        ['staff', 'الطاقم والرتب', 'staff', 'أضف طاقمًا، غيّر رتبهم، أزلهم'],
    ];
    function frame() {
        app.innerHTML = `<div class="tab">
            <div class="top"><div class="logo">EX<b>_</b>Tii · لوحة الإدارة</div><span class="badge">${esc(S.roleLabel)}</span>
                <div class="gsearch"><input class="in" id="gq" autocomplete="off" placeholder="ابحث عن أي شيء: لاعب، رقم، غرض، سيارة، صفحة..."><div class="gres" id="gres"></div></div>
                <span class="stat" id="stat"></span><button class="x" id="x">×</button></div>
            <div class="side">${TABS.filter((t) => has(t[2])).map(([id, l]) => `<button data-p="${id}" class="${id === page ? 'on' : ''}">${l}${id === 'reports' ? '<span class="dot hidden" id="rdot"></span>' : ''}</button>`).join('')}
                <span class="sp"></span><div class="hint">F1 للفتح والإغلاق · كل ما تفعله يُسجَّل</div></div>
            <div class="main"><div class="page" id="pg"></div></div></div>`;
        document.getElementById('x').onclick = () => nui('close');
        app.querySelectorAll('.side button').forEach((b) => b.onclick = () => go(b.dataset.p));
        searchBox();
    }
    function go(p, after) {
        page = p;
        app.querySelectorAll('.side button').forEach((x) => x.classList.toggle('on', x.dataset.p === p));
        render(); if (after) after();
    }
    function render() {
        const pg = document.getElementById('pg'); if (!pg) return;
        ({ home: rHome, players: rPlayers, reports: rReports, me: rMe, spawn: rSpawn, server: rServer, gangs: rGangs, test: rTest, logs: rLogs, staff: rStaff })[page](pg);
    }

    // ------------------------------------------------------------- the search (top): everything in one box
    function searchBox() {
        const box = document.getElementById('gq'), res = document.getElementById('gres');
        const draw = () => {
            const k = box.value.trim().toLowerCase();
            if (!k) { res.classList.remove('on'); res.innerHTML = ''; return; }
            const hit = (v) => String(v ?? '').toLowerCase().includes(k);
            const P = players.filter((p) => String(p.id) === k || [p.name, p.char, p.cid, p.job].some(hit)).slice(0, 6);
            const T = TABS.filter((t) => has(t[2]) && t[0] !== 'home' && (hit(t[1]) || hit(t[3]))).slice(0, 4);
            const I = has('item') ? arr(S.items).filter((i) => hit(i.name) || hit(i.label)).slice(0, 6) : [];
            const C = has('car') ? arr(S.catalog).filter((c) => hit(c.model) || hit(c.label)).slice(0, 6) : [];
            const sec = (title, rows) => rows.length ? `<div class="gsec">${title}</div>${rows.join('')}` : '';
            res.innerHTML = sec('اللاعبون', P.map((p) => `<button data-gp="${p.id}"><b>${p.id} · ${esc(p.char || p.name)}</b><span>${esc(p.name)}${p.job ? ' · ' + esc(p.job) : ''}</span></button>`))
                + sec('الصفحات', T.map((t) => `<button data-gt="${t[0]}"><b>${esc(t[1])}</b><span>${esc(t[3])}</span></button>`))
                + sec('الأغراض (تُعطى لك)', I.map((i) => `<button data-gi="${esc(i.name)}"><b>${esc(i.label || i.name)}</b><span class="ltr">${esc(i.name)}</span></button>`))
                + sec('السيارات (تنزل عندك)', C.map((c) => `<button data-gc="${esc(c.model)}"><b>${esc(c.label)}</b><span class="ltr">${esc(c.model)}</span></button>`))
                || '<div class="mute" style="padding:10px">لا نتائج</div>';
            res.classList.add('on');
            res.querySelectorAll('[data-gp]').forEach((b) => b.onmousedown = (e) => { e.preventDefault(); sel = Number(b.dataset.gp); box.value = ''; draw(); go('players'); });
            res.querySelectorAll('[data-gt]').forEach((b) => b.onmousedown = (e) => { e.preventDefault(); box.value = ''; draw(); go(b.dataset.gt); });
            res.querySelectorAll('[data-gi]').forEach((b) => b.onmousedown = (e) => { e.preventDefault(); act('item', { self: true, item: b.dataset.gi, count: 1 }); });
            res.querySelectorAll('[data-gc]').forEach((b) => b.onmousedown = (e) => { e.preventDefault(); act('car', { model: b.dataset.gc }); });
        };
        box.oninput = draw; box.onfocus = draw; box.onblur = () => setTimeout(() => res.classList.remove('on'), 150);
        box.onkeydown = (e) => { if (e.key === 'Enter') { const f = res.querySelector('button'); if (f) f.dispatchEvent(new MouseEvent('mousedown')); } };
    }

    // ------------------------------------------------------------- HOME
    function rHome(pg) {
        pg.style.overflow = 'auto';
        const s = srv || { reports: [] };
        const L = S.limits || {};
        const lim = (k, word, isMoney) => L[k] ? `<div class="lim"><small>${word} اليوم</small><b class="num">${isMoney ? money(L[k].left) : L[k].left} / ${isMoney ? money(L[k].max) : L[k].max}</b></div>` : '';
        const me = (S.roles || []).find((r) => r.id === S.role) || {};
        pg.innerHTML = `<div class="hello"><div><h2>أهلًا، ${esc(S.roleLabel)}</h2><div class="mute">${esc(me.desc || '')}</div></div>
            <div class="hstats"><div><small>اللاعبون</small><b class="num">${s.players || 0} / ${s.max || 0}</b></div><div><small>بلاغات مفتوحة</small><b class="num">${arr(s.reports).length}</b></div>
            ${lim('money', 'المال', true)}${lim('items', 'الأغراض')}${lim('cars', 'السيارات')}</div></div>
          <div class="tiles">${TABS.filter((t) => t[0] !== 'home' && has(t[2])).map((t) => `<button class="tile" data-go="${t[0]}"><b>${esc(t[1])}</b><span>${esc(t[3])}</span></button>`).join('')}</div>
          <div class="card" style="margin-top:12px"><h3>سريع</h3><div class="row">
            ${has('noclip') ? `<button class="btn big ${S.self && S.self.noclip ? 'on' : ''}" data-q="noclip">نوكليب</button>` : ''}
            ${has('tp') ? '<button class="btn big" data-q="waypoint">انتقل إلى العلامة</button>' : ''}
            ${has('revive') ? '<button class="btn big ok" data-q="revive">أنعشني</button>' : ''}
            ${has('car') ? '<button class="btn big" data-q="fix">صلّح سيارتي</button>' : ''}
            ${has('reviveall') ? '<button class="btn big" data-q="reviveall">أنعش الجميع</button>' : ''}</div></div>`;
        pg.querySelectorAll('[data-go]').forEach((b) => b.onclick = () => go(b.dataset.go));
        pg.querySelectorAll('[data-q]').forEach((b) => b.onclick = async () => {
            const q = b.dataset.q;
            if (q === 'noclip') { const r = await self('noclip', { on: !(S.self && S.self.noclip) }); if (r && r.ok) { S.self = r.state; rHome(pg); } return; }
            if (q === 'revive') return act('revive', { self: true });
            if (q === 'reviveall') return act('reviveall', {}, 'إنعاش كل اللاعبين في السيرفر؟');
            const r = await self(q); if (r) toast(r.msg || (r.ok ? 'تم' : 'لم ينجح'), r.ok);
        });
    }

    // ------------------------------------------------------------- REPORTS
    function rReports(pg) {
        pg.style.overflow = 'auto';
        const R = arr(srv && srv.reports);
        pg.innerHTML = `<div class="card"><h3>البلاغات المفتوحة (اللاعب يكتب /report والمشكلة)</h3>${R.length ? R.map((r) => `<div class="mem"><div><b>#${r.id} ${esc(r.name)}</b><div class="mute">${esc(r.text)} · قبل ${ago(r.at)}${r.left ? ' · خرج من السيرفر' : ''}</div></div>
            <div class="row"><button class="btn" data-r="goto" data-id="${r.id}">اذهب إليه</button>${has('bring') ? `<button class="btn" data-r="bring" data-id="${r.id}">اجلبه</button>` : ''}<button class="btn ok" data-r="close" data-id="${r.id}">تمّ</button></div></div>`).join('') : '<div class="empty" style="height:160px">لا بلاغات الآن 👍</div>'}</div>`;
        pg.querySelectorAll('[data-r]').forEach((b) => b.onclick = async () => { await act('report', { report: Number(b.dataset.id), op: b.dataset.r }); await refresh(); if (page === 'reports') rReports(pg); });
    }

    // ------------------------------------------------------------- SPAWN (cars & items for me)
    function rSpawn(pg) {
        pg.style.overflow = 'auto';
        pg.innerHTML = `<div class="grid2">
          <div class="card"><h3>السيارات</h3><div class="row"><input class="in grow" id="sq" placeholder="ابحث: الاسم أو الموديل"><input class="in w160 ltr" id="sm" placeholder="أي موديل آخر"><button class="btn acc" id="smgo">أنزلها</button></div>
            <div class="mute" style="margin:8px 0">«أنزلها» = سيارة مؤقتة لك الآن. ${has('givecar') ? '«لي» = سيارة مملوكة تذهب لمرآبك (بحد يومي).' : ''}</div><div class="clist" id="cl"></div></div>
          ${has('item') ? `<div class="card"><h3>الأغراض (تُعطى لك)</h3><div class="row"><input class="in grow" id="iq" placeholder="ابحث: الاسم بالعربي أو بالإنجليزية"><input class="in w80 num" id="ic" value="1"></div><div class="clist" id="il" style="margin-top:8px"></div></div>` : ''}
        </div>`;
        const cl = document.getElementById('cl');
        const drawC = () => {
            const k = val('sq').toLowerCase();
            const list = arr(S.catalog).filter((c) => !k || c.model.toLowerCase().includes(k) || String(c.label).toLowerCase().includes(k)).slice(0, 80);
            cl.innerHTML = list.map((c) => `<div class="crow"><div><b>${esc(c.label)}</b><span class="ltr">${esc(c.model)} · ${money(c.price)}</span></div><div class="row"><button class="btn" data-sp="${esc(c.model)}">أنزلها</button>${has('givecar') ? `<button class="btn" data-own="${esc(c.model)}">لي</button>` : ''}</div></div>`).join('') || '<div class="mute">لا شيء</div>';
            cl.querySelectorAll('[data-sp]').forEach((b) => b.onclick = () => act('car', { model: b.dataset.sp }));
            cl.querySelectorAll('[data-own]').forEach((b) => b.onclick = () => act('givecar', { self: true, model: b.dataset.own }, `إضافة ${b.dataset.own} إلى مرآبك؟`));
        };
        document.getElementById('sq').oninput = drawC; drawC();
        document.getElementById('smgo').onclick = () => act('car', { model: val('sm') });
        const il = document.getElementById('il');
        if (il) {
            const drawI = () => {
                const k = val('iq').toLowerCase();
                const list = arr(S.items).filter((i) => !k || String(i.name).toLowerCase().includes(k) || String(i.label).toLowerCase().includes(k)).slice(0, 80);
                il.innerHTML = list.map((i) => `<div class="crow"><div><b>${esc(i.label || i.name)}</b><span class="ltr">${esc(i.name)}</span></div><button class="btn" data-gi="${esc(i.name)}">أعطني</button></div>`).join('') || '<div class="mute">لا شيء</div>';
                il.querySelectorAll('[data-gi]').forEach((b) => b.onclick = () => act('item', { self: true, item: b.dataset.gi, count: val('ic') }));
            };
            document.getElementById('iq').oninput = drawI; drawI();
        }
    }
    async function refresh() {
        const [p, s] = await Promise.all([fetchX('players'), fetchX('server')]);
        if (p) players = arr(p);
        if (s) {
            srv = s; s.reports = arr(s.reports); s.resources = arr(s.resources);
            const st = document.getElementById('stat'); if (st) st.textContent = `${s.players}/${s.max} لاعب · يعمل منذ ${dur(s.uptime)}`;
            const d = document.getElementById('rdot'); if (d) { d.textContent = s.reports.length; d.classList.toggle('hidden', !s.reports.length); }
        }
        if (page === 'players') rPlayerList();
        const typing = document.activeElement && document.activeElement.matches('input,textarea');
        if ((page === 'reports' || page === 'home') && !typing) render();
        if (page === 'server' && !typing && !(val('ann') || val('rs'))) render();
    }

    // ------------------------------------------------------------- PLAYERS
    function rPlayers(pg) {
        pg.style.overflow = 'hidden';
        pg.innerHTML = `<div class="pl"><div class="plist"><div class="search"><input class="in" id="ps" placeholder="ابحث: رقم، اسم، شخصية، وظيفة..." value="${esc(q)}"></div><div class="list" id="plist"></div></div>
            <div class="pdetail" id="pd"></div></div>`;
        const ps = document.getElementById('ps'); ps.oninput = () => { q = ps.value; rPlayerList(); }; ps.focus();
        rPlayerList(); rDetail();
    }
    function rPlayerList() {
        const el = document.getElementById('plist'); if (!el) return;
        const k = q.trim().toLowerCase();
        const list = players.filter((p) => !k || [p.id, p.name, p.char, p.cid, p.job, p.gang].some((v) => String(v ?? '').toLowerCase().includes(k)));
        el.innerHTML = list.map((p) => `<div class="pitem ${sel === p.id ? 'on' : ''}" data-id="${p.id}"><div class="pid">${p.id}</div>
            <div class="pn"><b>${esc(p.char || p.name)}</b><span>${esc(p.name)}${p.job ? ' · ' + esc(p.job) : ''}</span></div>
            <div>${p.dead ? '<span class="tag dead">ساقط</span>' : ''}${p.staff ? '<span class="tag st">طاقم</span>' : ''}</div></div>`).join('') || '<div class="empty" style="height:120px">لا أحد</div>';
        el.querySelectorAll('.pitem').forEach((r) => r.onclick = () => { sel = Number(r.dataset.id); rPlayerList(); rDetail(); });
        if (sel && !players.find((p) => p.id === sel)) { sel = null; rDetail(); }
    }
    function rDetail() {
        const el = document.getElementById('pd'); if (!el) return;
        const p = players.find((x) => x.id === sel);
        if (!p) { el.innerHTML = '<div class="empty">اختر لاعبًا من القائمة</div>'; return; }
        const jobs = (S.jobs || []).map((j) => `<option value="${esc(j.name)}">${esc(j.label)}</option>`).join('');
        el.innerHTML = `<div class="phead"><div class="big">${p.id}</div><div><b>${esc(p.char || '—')}</b><span>${esc(p.name)} · <span class="ltr">${esc(p.cid || '')}</span></span></div></div>
        <div class="kv"><div><small>كاش</small><b class="num">${money(p.cash)}</b></div><div><small>بنك</small><b class="num">${money(p.bank)}</b></div>
            <div><small>الوظيفة</small><b>${esc(p.job || '—')}${p.duty ? ' ✓' : ''}</b></div><div><small>العصابة</small><b>${esc(p.gang || '—')}</b></div></div>
        <div class="grid2">
          <div class="card"><h3>سريع</h3><div class="row">
            ${has('goto') ? '<button class="btn" data-a="goto">اذهب إليه</button>' : ''}${has('bring') ? '<button class="btn" data-a="bring">اجلبه</button>' : ''}
            ${has('spectate') ? '<button class="btn" data-a="spectate">راقبه</button>' : ''}${has('inventory') ? '<button class="btn" data-a="inventory">افتح حقيبته</button>' : ''}</div>
            <div class="row">${has('revive') ? '<button class="btn ok" data-a="revive">إنعاش</button>' : ''}${has('heal') ? '<button class="btn ok" data-a="heal">علاج كامل</button>' : ''}
            ${has('freeze') ? '<button class="btn" data-a="freeze1">تجميد</button><button class="btn" data-a="freeze0">فك التجميد</button>' : ''}</div></div>
          ${has('message') ? `<div class="card"><h3>رسالة خاصة له</h3><div class="row"><input class="in grow" id="pmsg" placeholder="اكتب رسالة تظهر على شاشته"><button class="btn acc" data-a="message">أرسل</button></div></div>` : ''}
          ${has('money') ? `<div class="card"><h3>المال</h3><div class="row"><input class="in w160 num" id="mamt" placeholder="المبلغ (- للخصم)"><select class="in" id="macc"><option value="cash">كاش</option><option value="bank">بنك</option></select>
            <button class="btn acc" data-a="money">نفّذ</button></div><div class="row"><button class="chip" data-m="1000">+1,000</button><button class="chip" data-m="10000">+10,000</button><button class="chip" data-m="100000">+100,000</button></div></div>` : ''}
          ${has('item') ? `<div class="card"><h3>أعطه غرضًا</h3><div class="row"><div class="isw grow"><input class="in" id="iname" autocomplete="off" placeholder="ابحث عن الغرض بالاسم أو بالعربي"><div class="isug" id="isug"></div></div><input class="in w80 num" id="icnt" value="1"><button class="btn acc" data-a="item">أعطِ</button></div>
            <div class="row"><button class="btn bad" data-a="clearinv">أفرغ حقيبته</button></div></div>` : ''}
          ${has('job') ? `<div class="card"><h3>الوظيفة</h3><div class="row"><select class="in grow" id="job">${jobs}</select><select class="in w160" id="grade"></select><button class="btn acc" data-a="job">غيّر</button></div></div>` : ''}
          ${has('gang') ? `<div class="card"><h3>العصابة</h3><div class="row"><select class="in grow" id="gsel"></select><select class="in w120" id="grank"><option value="0">عدّاء</option><option value="1">طاقم</option><option value="2">نائب</option><option value="3">الزعيم</option></select>
            <button class="btn acc" data-a="setgang">ضعه</button></div><div class="mute" style="margin-top:6px">بدون انتظار 48 ساعة. «زعيم» يجعله الزعيم ويُنزل القديم.</div></div>` : ''}
          ${has('givecar') ? `<div class="card"><h3>أعطه سيارة (تذهب لمرآبه)</h3><div class="row"><select class="in grow" id="gcar">${arr(S.catalog).map((c) => `<option value="${esc(c.model)}">${esc(c.label)}</option>`).join('')}</select><button class="btn acc" data-a="givecar">أعطِ</button></div></div>` : ''}
          ${has('licence') ? `<div class="card"><h3>الرخص</h3><div class="row">${[['car', 'سيارة'], ['truck', 'شاحنة'], ['boat', 'قارب'], ['heli', 'طيران'], ['weapon', 'سلاح']].map(([k, l]) => `<span class="lic"><b>${l}</b><button class="chip" data-lic="${k}" data-on="1">أعطِ</button><button class="chip" data-lic="${k}" data-on="0">اسحب</button></span>`).join('')}</div></div>` : ''}
          ${has('kick') || has('warn') ? `<div class="card"><h3>إنذار / طرد / حظر</h3><div class="row"><input class="in grow" id="reason" placeholder="السبب (يراه اللاعب)"></div>
            <div class="row">${has('warn') ? '<button class="btn" data-a="warn">أنذره</button>' : ''}${has('kick') ? '<button class="btn bad" data-a="kick">اطرد</button>' : ''}${has('ban') ? `<select class="in w160" id="bh">${banChoices()}</select><button class="btn bad" data-a="ban">احظر</button>` : ''}</div></div>` : ''}
          <div class="card" id="pinfo"><h3>سجله</h3><div class="mute">...</div></div>
        </div>`;
        (async () => {
            const info = await fetchX('pinfo', p.id);
            const box = document.getElementById('pinfo'); if (!box || sel !== p.id) return;
            if (!info) { box.innerHTML = '<h3>سجله</h3><div class="mute">لا معلومات</div>'; return; }
            const W = arr(info.warns), C = arr(info.cars);
            const ST = { 0: 'في الشارع', 1: 'في المرآب', 2: 'محجوزة' };
            box.innerHTML = `<h3>الإنذارات (${W.length})</h3>${W.map((w) => `<div class="mem"><span>${esc(w.reason)}</span><span class="mute">${esc(w.by)} · قبل ${ago(w.at)}</span></div>`).join('') || '<div class="mute">لا إنذارات</div>'}
                <h3 style="margin-top:12px">سياراته (${C.length})</h3>${C.map((c) => `<div class="mem"><span class="ltr">${esc(c.vehicle)} · ${esc(c.plate)}</span><span class="mute">${ST[c.state] || ''}${c.garage ? ' · ' + esc(c.garage) : ''}</span></div>`).join('') || '<div class="mute">لا سيارات</div>'}`;
        })();
        // grades follow the job
        const jsel = document.getElementById('job'), gsel = document.getElementById('grade');
        const fillGrades = () => { const j = (S.jobs || []).find((x) => x.name === jsel.value); gsel.innerHTML = (j ? j.grades : []).map((g) => `<option value="${g.grade}">${g.grade} · ${esc(g.label)}</option>`).join(''); };
        if (jsel) { jsel.onchange = fillGrades; fillGrades(); }
        const gs = document.getElementById('gsel');
        if (gs) { (async () => { if (!gangs) gangs = await fetchX('gangs'); gs.innerHTML = arr(gangs && gangs.gangs).map((g) => `<option value="${esc(g.name)}">${esc(g.label)}</option>`).join('') || '<option value="">لا توجد عصابات</option>'; })(); }
        el.querySelectorAll('[data-m]').forEach((b) => b.onclick = () => { document.getElementById('mamt').value = b.dataset.m; });
        el.querySelectorAll('[data-lic]').forEach((b) => b.onclick = () => act('licence', { id: p.id, kind: b.dataset.lic, on: b.dataset.on === '1' }));
        // the item search: a real list under the box (FiveM's browser doesn't show <datalist> drop-downs)
        const iname = document.getElementById('iname'), isug = document.getElementById('isug');
        if (iname && isug) {
            const all = arr(S.items);
            const show = () => {
                const q = iname.value.trim().toLowerCase();
                if (!q) { isug.innerHTML = ''; isug.classList.remove('on'); return; }
                const hit = all.filter((i) => String(i.name).toLowerCase().includes(q) || String(i.label || '').toLowerCase().includes(q))
                    .sort((x, y) => (String(x.name).toLowerCase().startsWith(q) ? 0 : 1) - (String(y.name).toLowerCase().startsWith(q) ? 0 : 1)).slice(0, 12);
                isug.innerHTML = hit.map((i) => `<button type="button" data-n="${esc(i.name)}"><b>${esc(i.label || i.name)}</b><span class="ltr">${esc(i.name)}</span></button>`).join('') || '<div class="mute">لا يوجد غرض بهذا الاسم</div>';
                isug.classList.add('on'); isug.scrollIntoView({ block: 'nearest' });
                isug.querySelectorAll('[data-n]').forEach((b) => b.onmousedown = (e) => { e.preventDefault(); iname.value = b.dataset.n; isug.classList.remove('on'); });
            };
            iname.oninput = show; iname.onfocus = show; iname.onblur = () => setTimeout(() => isug.classList.remove('on'), 120);
        }
        el.querySelectorAll('[data-a]').forEach((b) => b.onclick = async () => {
            const id = p.id, a = b.dataset.a;
            if (a === 'freeze1' || a === 'freeze0') return act('freeze', { id, on: a === 'freeze1' });
            if (a === 'message') return act('message', { id, text: val('pmsg') });
            if (a === 'money') return act('money', { id, amount: val('mamt'), account: val('macc') });
            if (a === 'item') return act('item', { id, item: val('iname').trim(), count: val('icnt') });
            if (a === 'clearinv') return act('clearinv', { id }, `تفريغ كل حقيبة ${p.char || p.name}؟ لا رجعة.`);
            if (a === 'job') return act('job', { id, job: val('job'), grade: val('grade') });
            if (a === 'setgang') return act('setgang', { id, gang: val('gsel'), rank: val('grank') });
            if (a === 'kick') return act('kick', { id, reason: val('reason') }, `طرد ${p.name}؟`);
            if (a === 'warn') { const r = await act('warn', { id, reason: val('reason') }); if (r && r.ok) rDetail(); return; }
            if (a === 'givecar') return act('givecar', { id, model: val('gcar') }, `إعطاء ${p.char || p.name} هذه السيارة في مرآبه؟`);
            if (a === 'ban') return act('ban', { id, hours: val('bh'), reason: val('reason') }, `حظر ${p.name}؟`);
            act(a, { id });
        });
    }

    function banChoices() {
        const all = [[24, 'يوم'], [72, '3 أيام'], [168, 'أسبوع'], [720, 'شهر'], [0, 'دائم']];
        const max = S.banMax;
        return all.filter(([h]) => max === 0 || (h > 0 && h <= max)).map(([h, l]) => `<option value="${h}">${l}</option>`).join('');
    }

    // ------------------------------------------------------------- ME & WORLD
    function rMe(pg) {
        pg.style.overflow = 'auto';
        const st = S.self || {};
        const tg = (w, l) => `<button class="btn big ${st[w] ? 'on' : ''}" data-t="${w}">${l}${st[w] ? ' ✓' : ''}</button>`;
        pg.innerHTML = `<div class="grid2">
          <div class="card"><h3>أنا</h3><div class="grid2">${tg('noclip', 'نوكليب')}${has('names') ? tg('names', 'أسماء فوق الرؤوس') : ''}${has('me') ? tg('god', 'لا أموت') + tg('invisible', 'مخفي') : ''}</div>
            <div class="row" style="margin-top:10px">${has('tp') ? '<button class="btn" data-s="waypoint">انتقل إلى العلامة</button>' : ''}<button class="btn" data-s="mycoords">انسخ موقعي</button>
            ${has('revive') ? '<button class="btn ok" data-me="revive">أنعشني</button>' : ''}${has('heal') ? '<button class="btn ok" data-me="heal">عالجني</button>' : ''}</div>
            ${has('tp') ? `<div class="row"><input class="in w120 num" id="cx" placeholder="X"><input class="in w120 num" id="cy" placeholder="Y"><input class="in w120 num" id="cz" placeholder="Z"><button class="btn" data-s="coords">انتقل</button></div>` : ''}
            <div class="row"><input class="in grow ltr" id="cout" readonly placeholder="الموقع يظهر هنا"></div></div>
          ${has('car') ? `<div class="card"><h3>السيارات</h3><div class="row"><input class="in grow ltr" id="model" placeholder="اسم الموديل (sultan, adder...)"><button class="btn acc" data-car>أنزلها</button></div>
            <div class="row">${S.cars.map((c) => `<button class="chip ltr" data-cm="${esc(c)}">${esc(c)}</button>`).join('')}</div>
            <div class="row" style="margin-top:10px"><button class="btn ok" data-s="fix">صلّح</button><button class="btn" data-s="clean">نظّف</button><button class="btn" data-s="fuel">املأ الوقود</button><button class="btn" data-s="flip">اقلبها</button><button class="btn bad" data-s="delete">احذفها</button></div>
            <div class="mute" style="margin-top:6px">تعمل على سيارتك أو أقرب سيارة.</div></div>` : ''}
          ${has('clearcars') ? `<div class="card"><h3>نظّف المكان</h3><div class="row"><span class="mute">احذف كل المركبات الفارغة حولي:</span><button class="chip" data-cc="25">25 م</button><button class="chip" data-cc="50">50 م</button><button class="chip" data-cc="100">100 م</button></div></div>` : ''}
          ${has('reviveall') ? `<div class="card"><h3>الجميع</h3><div class="row"><button class="btn ok" data-reviveall>أنعش كل اللاعبين</button></div></div>` : ''}
        </div>`;
        pg.querySelectorAll('[data-t]').forEach((b) => b.onclick = async () => { const w = b.dataset.t; const r = await self(w, { on: !st[w] }); if (r && r.ok) { S.self = r.state; rMe(pg); } else toast('ليس لك هذا الحق', false); });
        pg.querySelectorAll('[data-s]').forEach((b) => b.onclick = async () => {
            const w = b.dataset.s;
            const r = await self(w, w === 'coords' ? { c: { x: val('cx'), y: val('cy'), z: val('cz') } } : {});
            if (w === 'mycoords' && r) { const o = document.getElementById('cout'); o.value = r.text; o.select(); document.execCommand('copy'); toast('نُسخ: ' + r.text); return; }
            if (r) toast(r.msg || (r.ok ? 'تم' : 'لم ينجح'), r.ok);
        });
        pg.querySelectorAll('[data-me]').forEach((b) => b.onclick = () => act(b.dataset.me, { self: true }));
        pg.querySelectorAll('[data-cm]').forEach((b) => b.onclick = () => act('car', { model: b.dataset.cm }));
        const cb = pg.querySelector('[data-car]'); if (cb) cb.onclick = () => act('car', { model: val('model') });
        pg.querySelectorAll('[data-cc]').forEach((b) => b.onclick = () => act('clearcars', { radius: Number(b.dataset.cc) }, `حذف كل المركبات الفارغة في ${b.dataset.cc} مترًا حولك؟`));
        const ra = pg.querySelector('[data-reviveall]'); if (ra) ra.onclick = () => act('reviveall', {}, 'إنعاش كل اللاعبين في السيرفر؟');
    }

    // ------------------------------------------------------------- the world (time, weather, power)
    function rWorldCards() {
        const t = srv && srv.time;
        return `<div class="card"><h3>الوقت</h3><div class="row"><input class="in w80 num" id="hh" placeholder="ساعة" value="${t ? t.hour : 12}"><input class="in w80 num" id="mm" placeholder="دقيقة" value="${t ? t.minute : 0}"><button class="btn acc" data-time>اضبط</button></div>
            <div class="row"><button class="chip" data-h="7">صباح</button><button class="chip" data-h="12">ظهر</button><button class="chip" data-h="18">مساء</button><button class="chip" data-h="23">ليل</button><button class="chip" data-h="3">منتصف الليل</button></div>
            <div class="row"><button class="btn ${srv && srv.frozen ? 'on' : ''}" data-freeze>${srv && srv.frozen ? 'الوقت متوقف ✓' : 'أوقف الوقت'}</button><button class="btn ${srv && srv.blackout ? 'on' : ''}" data-black>${srv && srv.blackout ? 'انقطاع الكهرباء ✓' : 'اقطع الكهرباء'}</button></div></div>
          <div class="card"><h3>الطقس <span class="mute">(الآن: ${esc(srv && srv.weather || '?')})</span></h3><div class="row">${S.weathers.map((w) => `<button class="chip ltr" data-w="${w}">${w}</button>`).join('')}</div>
            <div class="row"><button class="btn" data-wauto>رجّع الطقس الطبيعي</button></div></div>`;
    }
    function bindWorld(pg) {
        const tb = pg.querySelector('[data-time]'); if (tb) tb.onclick = () => act('time', { hour: val('hh'), minute: val('mm') });
        pg.querySelectorAll('[data-h]').forEach((b) => b.onclick = () => act('time', { hour: b.dataset.h, minute: 0 }));
        const fz = pg.querySelector('[data-freeze]'); if (fz) fz.onclick = async () => { await act('time', { freeze: !(srv && srv.frozen) }); await refresh(); render(); };
        const bl = pg.querySelector('[data-black]'); if (bl) bl.onclick = async () => { await act('blackout', { on: !(srv && srv.blackout) }); await refresh(); render(); };
        pg.querySelectorAll('[data-w]').forEach((b) => b.onclick = () => act('weather', { weather: b.dataset.w }));
        const wa = pg.querySelector('[data-wauto]'); if (wa) wa.onclick = () => act('weather', { auto: true });
    }

    // ------------------------------------------------------------- SERVER
    function rServer(pg) {
        pg.style.overflow = 'auto';
        const s = srv || { reports: [], resources: [] };
        pg.innerHTML = `<div class="grid3" style="margin-bottom:12px">
            <div class="card"><div class="mute">اللاعبون</div><h2 class="num">${s.players || 0} / ${s.max || 0}</h2></div>
            <div class="card"><div class="mute">يعمل منذ</div><h2>${dur(s.uptime || 0)}</h2></div>
            <div class="card"><div class="mute">بلاغات مفتوحة</div><h2 class="num">${s.reports.length}</h2></div></div>
          <div class="grid2">
            ${has('announce') ? `<div class="card"><h3>إعلان لكل السيرفر</h3><textarea class="in" id="ann" placeholder="يظهر في أعلى شاشة كل اللاعبين"></textarea><div class="row" style="margin-top:8px"><button class="btn acc" data-ann>انشر</button></div></div>` : ''}
            ${has('world') ? rWorldCards() : ''}
          </div>
          ${has('resource') ? `<div class="card" style="margin-top:12px"><h3>الموارد (إعادة تشغيل مورد واحد)</h3><div class="row"><input class="in w220" id="rs" placeholder="ابحث عن مورد"></div><div id="rl" style="margin-top:8px"></div></div>` : ''}`;
        const ab = pg.querySelector('[data-ann]'); if (ab) ab.onclick = () => act('announce', { text: val('ann') }, 'نشر الإعلان لكل اللاعبين؟');
        bindWorld(pg);
        const rl = document.getElementById('rl');
        if (rl) {
            const draw = () => { const k = val('rs').toLowerCase(); rl.innerHTML = `<table><tr><th>المورد</th><th>الحالة</th><th></th></tr>${s.resources.filter((r) => !k || r.name.toLowerCase().includes(k)).slice(0, 60).map((r) => `<tr><td class="ltr">${esc(r.name)}</td><td>${r.state === 'started' ? '✓ يعمل' : esc(r.state)}</td><td>${r.locked ? '<span class="mute">محمي</span>' : `<button class="btn" data-res="${esc(r.name)}">أعد التشغيل</button>`}</td></tr>`).join('')}</table>`;
                rl.querySelectorAll('[data-res]').forEach((b) => b.onclick = () => act('resource', { name: b.dataset.res }, `إعادة تشغيل ${b.dataset.res}؟ من يستعمله الآن قد يتأثر.`)); };
            document.getElementById('rs').oninput = draw; draw();
        }
    }

    // ------------------------------------------------------------- GANGS
    async function rGangs(pg) {
        pg.style.overflow = 'auto';
        const my = page;
        pg.innerHTML = '<div class="mute">...</div>';
        gangs = await fetchX('gangs');
        if (page !== my) return;
        const G = arr(gangs && gangs.gangs);
        G.forEach((g) => { g.members = arr(g.members); });
        if (gangs) gangs.places = arr(gangs.places);
        const types = (S.gangTypes || []).map((t) => `<option value="${t.id}">${esc(t.label)}</option>`).join('');
        const pls = players.map((p) => `<option value="${p.id}">${p.id} · ${esc(p.char || p.name)}</option>`).join('');
        pg.innerHTML = `<div class="card" style="margin-bottom:12px"><h3>عصابة جديدة</h3><div class="row"><input class="in w160 ltr" id="gn" placeholder="name (english)"><input class="in w160" id="gl" placeholder="الاسم الظاهر">
            <select class="in" id="gk">${types}</select><select class="in w220" id="gld">${pls}</select><button class="btn acc" data-gc>أنشئ</button></div></div>
          <div class="grid2">${G.map((g) => `<div class="gcard" data-g="${esc(g.name)}">
            <div class="gh"><span class="gtag" style="background:${esc(g.color || '#e8b547')}">${esc(g.tag || '')}</span><div><b>${esc(g.label)}</b><div class="mute">${esc(g.typeLabel)} · المستوى ${g.level} ${esc(g.levelName)} · ${g.members.length} عضو${g.locked ? ' · <span style="color:#ff8a8d">مقفل</span>' : ''}</div></div></div>
            <div class="row"><span class="mute w80">السمعة</span><input class="in w120 num" data-f="rep" value="${g.rep}"><button class="btn" data-set="rep">حفظ</button></div>
            <div class="row"><span class="mute w80">البنك</span><input class="in w120 num" data-f="bank" value="${g.bank}"><button class="btn" data-set="bank">حفظ</button><button class="btn ${g.locked ? 'bad' : ''}" data-lock="${g.locked ? 0 : 1}">${g.locked ? 'افتح المقر' : 'اقفل المقر'}</button></div>
            <div class="row"><span class="mute w80">المخزن</span><input class="in w80 num" data-f="cnt" value="10"><button class="btn" data-stash>أضف ${esc(g.part || 'قطع')}</button><button class="btn" data-cool>صفّر الانتظار</button><button class="btn" data-tags>امسح علاماتها</button></div>
            <div class="row">${g.hq ? `<button class="btn" data-hq="${g.hq.x},${g.hq.y},${g.hq.z}">اذهب للمقر</button>` : '<span class="mute">لا مقر بعد (/gangspots)</span>'}<button class="btn bad" data-del>احذف العصابة</button></div>
            <div class="sep"></div>${g.members.map((m) => `<div class="mem"><span>${m.online ? '🟢' : '⚪'} ${esc(m.name || m.cid)} · <span class="mute">${['عدّاء', 'طاقم', 'نائب', 'الزعيم'][m.rank] || m.rank}</span></span>${m.rank < 3 ? `<button class="btn bad" data-kick="${esc(m.cid)}">أخرجه</button>` : ''}</div>`).join('') || '<div class="mute">لا أعضاء</div>'}
          </div>`).join('') || '<div class="mute">لا توجد عصابات بعد</div>'}</div>
          <div class="card" style="margin-top:12px"><h3>أماكن العصابات</h3><div class="row">${((gangs && gangs.places) || []).map((p) => `<button class="chip" data-hq="${p.x},${p.y},${p.z}">${esc(p.label)}</button>`).join('') || '<span class="mute">لم يُوضع شيء بعد</span>'}</div></div>`;
        const reload = () => rGangs(pg);
        pg.querySelector('[data-gc]').onclick = async () => { await act('gangcreate', { name: val('gn'), label: val('gl'), kind: val('gk'), id: Number(val('gld')) }); setTimeout(reload, 600); };
        pg.querySelectorAll('[data-hq]').forEach((b) => b.onclick = () => { const [x, y, z] = b.dataset.hq.split(',').map(Number); self('coords', { c: { x, y, z } }); });
        pg.querySelectorAll('.gcard').forEach((c) => {
            const g = c.dataset.g;
            const f = (n) => c.querySelector(`[data-f="${n}"]`).value;
            c.querySelectorAll('[data-set]').forEach((b) => b.onclick = async () => { await act('gangset', { gang: g, field: b.dataset.set, value: f(b.dataset.set) }); reload(); });
            c.querySelector('[data-lock]').onclick = async (e) => { await act('gangset', { gang: g, field: 'locked', value: e.target.dataset.lock === '1' }); reload(); };
            c.querySelector('[data-stash]').onclick = () => act('gangstash', { gang: g, count: f('cnt') });
            c.querySelector('[data-cool]').onclick = () => act('gangcool', { gang: g });
            c.querySelector('[data-tags]').onclick = () => act('gangtags', { gang: g }, 'مسح كل علامات هذه العصابة من الجدران؟');
            c.querySelector('[data-del]').onclick = async () => { const r = await act('gangdelete', { gang: g }, 'حذف العصابة نهائيًا؟ المخزن والبنك يُحذفان معها.'); if (r && r.ok) setTimeout(reload, 600); };
            c.querySelectorAll('[data-kick]').forEach((b) => b.onclick = async () => { await act('kickgang', { cid: b.dataset.kick }, 'إخراجه من العصابة؟'); reload(); });
        });
    }

    // ------------------------------------------------------------- TEST
    async function rTest(pg) {
        pg.style.overflow = 'auto';
        const my = page;
        if (!gangs) gangs = await fetchX('gangs');
        if (page !== my) return;
        if (gangs) gangs.places = arr(gangs.places);
        pg.innerHTML = `<div class="grid2">
          <div class="card"><h3>جرّب أي لعبة مصغّرة (لا يُعطى أو يُؤخذ شيء)</h3><div class="row">${S.minigames.map(([id, l]) => `<button class="btn" data-mg="${id}">${esc(l)}</button>`).join('')}</div></div>
          <div class="card"><h3>عُدد التجربة (تذهب لحقيبتك)</h3><div class="row">${S.kits.map((k, i) => `<button class="btn" data-kit="${i + 1}">${esc(k.label)}</button>`).join('')}</div>
            <div class="row" style="margin-top:10px"><button class="btn acc" data-cool>صفّر كل أوقات الانتظار عني وعن عصابتي</button></div></div>
          <div class="card"><h3>الشرطة</h3><div class="row"><button class="btn" data-cop="1">اجعلني شرطيًا في الخدمة</button><button class="btn" data-cop="0">رجّعني مدنيًا</button></div>
            <div class="row"><button class="btn" data-call="theft">بلاغ سرقة سيارة هنا</button><button class="btn" data-call="shots">بلاغ إطلاق نار هنا</button><button class="btn" data-call="call">بلاغ 911 هنا</button></div></div>
          <div class="card" id="hcard"><h3>السطو</h3><div class="mute" id="hinfo">...</div>
            <div class="row"><span class="mute">السمعة:</span>${[1, 2, 3, 4, 7, 10].map((n) => `<button class="chip" data-hl="${n}">${n}</button>`).join('')}</div>
            <div class="row"><span class="mute">المهارات:</span><button class="chip" data-hs="1">كلها 1</button><button class="chip" data-hs="3">كلها 3</button><button class="chip" data-hs="5">كلها 5</button></div>
            <div class="row"><span class="mute">الوضع:</span><button class="chip" data-hf="auto">طبيعي</button><button class="chip" data-hf="police">بالشرطة</button><button class="chip" data-hf="npc">بلا شرطة</button></div>
            <div class="row"><span class="mute">بيت للسرقة الآن:</span><button class="chip" data-hh="small">شقة</button><button class="chip" data-hh="medium">بيت متوسط</button><button class="chip" data-hh="mansion">فيلا</button></div>
            <div class="row"><button class="btn" data-hx="kit">عُدّة السطو</button><button class="btn" data-hx="heat">أزل الملاحقة عني</button><button class="btn acc" data-hx="cooldowns">صفّر انتظار السطو</button></div></div>
          <div class="card"><h3>نفسي بسرعة</h3><div class="row"><button class="btn ok" data-me="revive">أنعشني</button><button class="btn ok" data-me="heal">عالجني</button>
            <button class="btn" data-money="10000">+10,000 كاش لي</button><button class="btn" data-time="12">ظهر</button><button class="btn" data-time="0">ليل</button></div></div>
          <div class="card" style="grid-column:1/-1"><h3>انتقل إلى</h3><div class="row">${((gangs && gangs.places) || []).map((p) => `<button class="chip" data-hq="${p.x},${p.y},${p.z}">${esc(p.label)}</button>`).join('') || '<span class="mute">لا أماكن بعد</span>'}</div></div></div>`;
        pg.querySelectorAll('[data-mg]').forEach((b) => b.onclick = () => self('minigame', { game: b.dataset.mg }));
        pg.querySelectorAll('[data-kit]').forEach((b) => b.onclick = () => act('kit', { kit: Number(b.dataset.kit) }));
        pg.querySelector('[data-cool]').onclick = () => act('mycool', {});
        pg.querySelectorAll('[data-cop]').forEach((b) => b.onclick = () => act('copduty', { on: b.dataset.cop === '1' }));
        pg.querySelectorAll('[data-call]').forEach((b) => b.onclick = () => act('fakecall', { kind: b.dataset.call }));
        pg.querySelectorAll('[data-me]').forEach((b) => b.onclick = () => act(b.dataset.me, { self: true }));
        pg.querySelectorAll('[data-money]').forEach((b) => b.onclick = () => act('money', { self: true, amount: Number(b.dataset.money), account: 'cash' }));
        pg.querySelectorAll('[data-time]').forEach((b) => b.onclick = () => act('time', { hour: Number(b.dataset.time), minute: 0 }));
        pg.querySelectorAll('[data-hq]').forEach((b) => b.onclick = () => { const [x, y, z] = b.dataset.hq.split(',').map(Number); self('coords', { c: { x, y, z } }); });
        // the robbery card
        const MODE = { auto: 'طبيعي', police: 'بالشرطة دائمًا', npc: 'بلا شرطة دائمًا' };
        const hload = async () => {
            const h = await fetchX('heist');
            const el = document.getElementById('hinfo'); if (!el) return;
            if (!h) { el.textContent = 'سكربت السطو لا يعمل'; return; }
            el.innerHTML = `سمعتك <b>${h.level}</b> (${h.xp} XP) · أقفال ${h.lockpick} · اختراق ${h.hacking} · كسر ${h.breaching}${h.heat > 0 ? ` · <b style="color:var(--bad)">ملاحَق ${Math.ceil(h.heat / 60)} د</b>` : ''}<br>شرطة محسوبة ${h.cops} · المطلوب: الدرجة 1 = ${h.need1}، الدرجة 4 = ${h.need4}، الدرجة 7 = ${h.need7} · الوضع: ${MODE[h.force] || h.force}`;
        };
        const hact = async (what, value) => { await act('heist', { what, value }); hload(); };
        pg.querySelectorAll('[data-hl]').forEach((b) => b.onclick = () => hact('level', Number(b.dataset.hl)));
        pg.querySelectorAll('[data-hs]').forEach((b) => b.onclick = async () => { for (const k of ['lockpick', 'hacking', 'breaching']) await act('heist', { what: k, value: Number(b.dataset.hs) }); hload(); });
        pg.querySelectorAll('[data-hf]').forEach((b) => b.onclick = () => hact('force', b.dataset.hf));
        pg.querySelectorAll('[data-hx]').forEach((b) => b.onclick = () => hact(b.dataset.hx));
        pg.querySelectorAll('[data-hh]').forEach((b) => b.onclick = () => hact('house', b.dataset.hh));
        hload();
    }

    // ------------------------------------------------------------- LOGS & BANS
    async function rLogs(pg) {
        pg.style.overflow = 'auto';
        pg.innerHTML = `${has('logs') ? '<div class="row" style="margin-bottom:10px"><input class="in w220" id="lq" placeholder="ابحث في السجل"><button class="btn" id="lgo">ابحث</button></div><div id="lt"></div>' : '<div class="mute">السجل الكامل للأدمن الأول فما فوق.</div>'}
          ${has('ban') ? '<div class="card" style="margin-top:12px"><h3>المحظورون</h3><div id="bt"></div></div>' : ''}`;
        const my = page;
        const load = async () => {
            const L = has('logs') ? arr(await fetchX('logs', val('lq'))) : [];
            if (page !== my) return;
            if (document.getElementById('lt')) document.getElementById('lt').innerHTML = `<table><tr><th>متى</th><th>من</th><th>ماذا</th><th>على من</th><th>تفاصيل</th></tr>${L.map((l) => `<tr><td>قبل ${ago(l.at)}</td><td>${esc(l.actor)}</td><td class="ltr">${esc(l.action)}</td><td>${esc(l.target || '')}</td><td>${esc(l.details || '')}</td></tr>`).join('')}</table>`;
            if (has('ban')) {
                const B = arr(await fetchX('bans'));
                if (page !== my || !document.getElementById('bt')) return;
                document.getElementById('bt').innerHTML = B.length ? `<table><tr><th>#</th><th>الاسم</th><th>السبب</th><th>حتى</th><th></th></tr>${B.map((b) => `<tr><td>${b.id}</td><td>${esc(b.name)}</td><td>${esc(b.reason)}</td><td>${b.until ? new Date(b.until * 1000).toLocaleString('en-GB') : 'دائم'}</td><td>${has('unban') ? `<button class="btn" data-ub="${b.id}">فك الحظر</button>` : ''}</td></tr>`).join('')}</table>` : '<div class="mute">لا أحد محظور</div>';
                document.querySelectorAll('[data-ub]').forEach((x) => x.onclick = async () => { await act('unban', { ban: Number(x.dataset.ub) }, 'فك هذا الحظر؟'); load(); });
            }
        };
        const lgo = document.getElementById('lgo'); if (lgo) { lgo.onclick = load; document.getElementById('lq').onkeydown = (e) => { if (e.key === 'Enter') load(); }; }
        load();
    }

    // ------------------------------------------------------------- STAFF
    async function rStaff(pg) {
        pg.style.overflow = 'auto';
        const my = page;
        const L = arr(await fetchX('staff'));
        if (page !== my) return;
        const roles = arr(S.roles).filter((r) => r.level <= (S.level || 0));
        const opts = (cur) => roles.map((r) => `<option value="${r.id}" ${r.id === cur ? 'selected' : ''}>${esc(r.label)}</option>`).join('');
        L.sort((a, b) => (b.level || 0) - (a.level || 0));
        pg.innerHTML = `<div class="card" style="margin-bottom:12px"><h3>أضف للطاقم (اللاعب يجب أن يكون في السيرفر)</h3><div class="row"><select class="in w220" id="sp">${players.map((p) => `<option value="${p.id}">${p.id} · ${esc(p.char || p.name)}</option>`).join('')}</select>
            <select class="in" id="sr">${opts('helper')}</select><button class="btn acc" id="sa">أضف</button></div>
            <div class="ranks">${arr(S.roles).map((r) => `<div><b>${esc(r.label)}</b><span>${esc(r.desc)}</span></div>`).join('')}</div>
            <div class="mute" style="margin-top:8px">من عنده group.admin في server.cfg هو «المالك» دائمًا. الحدود اليومية للمال والأغراض للأدمن والأدمن الأول فقط.</div></div>
          <div class="card"><table><tr><th>الاسم</th><th>الرتبة</th><th>الحالة</th><th></th></tr>${L.map((s) => `<tr><td>${esc(s.name)}</td><td><select class="in" data-rank="${esc(s.license)}">${opts(s.role)}</select></td><td>${s.online ? '🟢 #' + s.online : '⚪'}</td><td><button class="btn bad" data-rm="${esc(s.license)}">أزله</button></td></tr>`).join('') || '<tr><td colspan="4" class="mute">لا أحد بعد</td></tr>'}</table></div>`;
        document.getElementById('sa').onclick = async () => { await act('staffadd', { id: Number(val('sp')), role: val('sr') }); rStaff(pg); };
        pg.querySelectorAll('[data-rank]').forEach((s) => s.onchange = async () => { await act('staffrank', { license: s.dataset.rank, role: s.value }); rStaff(pg); });
        pg.querySelectorAll('[data-rm]').forEach((b) => b.onclick = async () => { await act('staffremove', { license: b.dataset.rm }, 'إزالته من الطاقم؟'); rStaff(pg); });
    }

    // ------------------------------------------------------------- messages from the game
    let annT = null, pmT = null;
    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'open') { S = m.data; app.classList.remove('hidden'); frame(); refresh().then(render); clearInterval(timer); timer = setInterval(refresh, 4000); }
        if (m.action === 'close') { app.classList.add('hidden'); app.innerHTML = ''; clearInterval(timer); gangs = null; document.querySelectorAll('.modal').forEach((x) => x.remove()); }
        if (m.action === 'announce') {
            const a = document.getElementById('announce');
            a.innerHTML = `<small>إعلان من الإدارة</small><div>${esc(m.data.text)}</div>`; a.classList.remove('hidden');
            clearTimeout(annT); annT = setTimeout(() => a.classList.add('hidden'), 12000);
        }
        if (m.action === 'message') {
            const a = document.getElementById('pm');
            a.innerHTML = `<small>رسالة من الإدارة</small><div>${esc(m.data.text)}</div>`; a.classList.remove('hidden');
            clearTimeout(pmT); pmT = setTimeout(() => a.classList.add('hidden'), 15000);
        }
    });
    window.addEventListener('keydown', (e) => {
        if (app.classList.contains('hidden')) return;
        if (e.key === 'Escape' || (e.key === 'F1' && !e.target.matches('input,textarea'))) { e.preventDefault(); nui('close'); }
    });
})();
