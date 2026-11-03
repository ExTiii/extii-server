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
    let page = 'players', players = [], sel = null, srv = null, gangs = null, timer = null, q = '';

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
    const TABS = [
        ['players', 'اللاعبون', 'view'], ['me', 'أنا والعالم', 'noclip'], ['server', 'السيرفر', 'view'],
        ['gangs', 'العصابات', 'gangs'], ['test', 'التجربة', 'test'], ['logs', 'السجل والحظر', 'logs'], ['staff', 'الطاقم', 'staff'],
    ];
    function frame() {
        app.innerHTML = `<div class="tab">
            <div class="top"><div class="logo">EX<b>_</b>Tii · لوحة الإدارة</div><span class="badge">${esc(S.roleLabel)}</span><span class="grow"></span>
                <span class="stat" id="stat"></span><button class="x" id="x">×</button></div>
            <div class="side">${TABS.filter((t) => has(t[2])).map(([id, l]) => `<button data-p="${id}" class="${id === page ? 'on' : ''}">${l}${id === 'server' ? '<span class="dot hidden" id="rdot"></span>' : ''}</button>`).join('')}
                <span class="sp"></span><div class="hint">F1 للفتح والإغلاق · كل ما تفعله يُسجَّل</div></div>
            <div class="main"><div class="page" id="pg"></div></div></div>`;
        document.getElementById('x').onclick = () => nui('close');
        app.querySelectorAll('.side button').forEach((b) => b.onclick = () => { page = b.dataset.p; app.querySelectorAll('.side button').forEach((x) => x.classList.toggle('on', x === b)); render(); });
    }
    function render() {
        const pg = document.getElementById('pg'); if (!pg) return;
        ({ players: rPlayers, me: rMe, server: rServer, gangs: rGangs, test: rTest, logs: rLogs, staff: rStaff })[page](pg);
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
        if (page === 'server' && !document.activeElement.matches('input,textarea') && !(val('ann') || val('rs'))) render();
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
          ${has('item') ? `<div class="card"><h3>أعطه غرضًا</h3><div class="row"><input class="in grow" id="iname" list="items" placeholder="ابحث عن الغرض بالاسم"><input class="in w80 num" id="icnt" value="1"><button class="btn acc" data-a="item">أعطِ</button></div>
            <div class="row"><button class="btn bad" data-a="clearinv">أفرغ حقيبته</button></div><datalist id="items">${S.items.map((i) => `<option value="${esc(i.name)}">${esc(i.label)}</option>`).join('')}</datalist></div>` : ''}
          ${has('job') ? `<div class="card"><h3>الوظيفة</h3><div class="row"><select class="in grow" id="job">${jobs}</select><select class="in w160" id="grade"></select><button class="btn acc" data-a="job">غيّر</button></div></div>` : ''}
          ${has('gang') ? `<div class="card"><h3>العصابة</h3><div class="row"><select class="in grow" id="gsel"></select><select class="in w120" id="grank"><option value="0">عدّاء</option><option value="1">طاقم</option><option value="2">نائب</option><option value="3">الزعيم</option></select>
            <button class="btn acc" data-a="setgang">ضعه</button></div><div class="mute" style="margin-top:6px">بدون انتظار 48 ساعة. «زعيم» يجعله الزعيم ويُنزل القديم.</div></div>` : ''}
          ${has('kick') ? `<div class="card"><h3>طرد / حظر</h3><div class="row"><input class="in grow" id="reason" placeholder="السبب"></div>
            <div class="row"><button class="btn bad" data-a="kick">اطرد</button>${has('ban') ? `<select class="in w160" id="bh"><option value="24">يوم</option><option value="72">3 أيام</option><option value="168">أسبوع</option><option value="720">شهر</option><option value="0">دائم</option></select><button class="btn bad" data-a="ban">احظر</button>` : ''}</div></div>` : ''}
        </div>`;
        // grades follow the job
        const jsel = document.getElementById('job'), gsel = document.getElementById('grade');
        const fillGrades = () => { const j = (S.jobs || []).find((x) => x.name === jsel.value); gsel.innerHTML = (j ? j.grades : []).map((g) => `<option value="${g.grade}">${g.grade} · ${esc(g.label)}</option>`).join(''); };
        if (jsel) { jsel.onchange = fillGrades; fillGrades(); }
        const gs = document.getElementById('gsel');
        if (gs) { (async () => { if (!gangs) gangs = await fetchX('gangs'); gs.innerHTML = arr(gangs && gangs.gangs).map((g) => `<option value="${esc(g.name)}">${esc(g.label)}</option>`).join('') || '<option value="">لا توجد عصابات</option>'; })(); }
        el.querySelectorAll('[data-m]').forEach((b) => b.onclick = () => { document.getElementById('mamt').value = b.dataset.m; });
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
            if (a === 'ban') return act('ban', { id, hours: val('bh'), reason: val('reason') }, `حظر ${p.name}؟`);
            act(a, { id });
        });
    }

    // ------------------------------------------------------------- ME & WORLD
    function rMe(pg) {
        pg.style.overflow = 'auto';
        const st = S.self || {};
        const tg = (w, l) => `<button class="btn big ${st[w] ? 'on' : ''}" data-t="${w}">${l}${st[w] ? ' ✓' : ''}</button>`;
        const t = srv && srv.time;
        pg.innerHTML = `<div class="grid2">
          <div class="card"><h3>أنا</h3><div class="grid2">${tg('noclip', 'نوكليب')}${has('me') ? tg('god', 'لا أموت') + tg('invisible', 'مخفي') + tg('names', 'أسماء فوق الرؤوس') : ''}</div>
            <div class="row" style="margin-top:10px">${has('tp') ? '<button class="btn" data-s="waypoint">انتقل إلى العلامة</button>' : ''}<button class="btn" data-s="mycoords">انسخ موقعي</button>
            ${has('revive') ? '<button class="btn ok" data-me="revive">أنعشني</button>' : ''}${has('heal') ? '<button class="btn ok" data-me="heal">عالجني</button>' : ''}</div>
            ${has('tp') ? `<div class="row"><input class="in w120 num" id="cx" placeholder="X"><input class="in w120 num" id="cy" placeholder="Y"><input class="in w120 num" id="cz" placeholder="Z"><button class="btn" data-s="coords">انتقل</button></div>` : ''}
            <div class="row"><input class="in grow ltr" id="cout" readonly placeholder="الموقع يظهر هنا"></div></div>
          ${has('car') ? `<div class="card"><h3>السيارات</h3><div class="row"><input class="in grow ltr" id="model" placeholder="اسم الموديل (sultan, adder...)"><button class="btn acc" data-car>أنزلها</button></div>
            <div class="row">${S.cars.map((c) => `<button class="chip ltr" data-cm="${esc(c)}">${esc(c)}</button>`).join('')}</div>
            <div class="row" style="margin-top:10px"><button class="btn ok" data-s="fix">صلّح</button><button class="btn" data-s="clean">نظّف</button><button class="btn" data-s="fuel">املأ الوقود</button><button class="btn" data-s="flip">اقلبها</button><button class="btn bad" data-s="delete">احذفها</button></div>
            <div class="mute" style="margin-top:6px">تعمل على سيارتك أو أقرب سيارة.</div></div>` : ''}
          ${has('world') ? `<div class="card"><h3>الوقت</h3><div class="row"><input class="in w80 num" id="hh" placeholder="ساعة" value="${t ? t.hour : 12}"><input class="in w80 num" id="mm" placeholder="دقيقة" value="${t ? t.minute : 0}"><button class="btn acc" data-time>اضبط</button></div>
            <div class="row"><button class="chip" data-h="7">صباح</button><button class="chip" data-h="12">ظهر</button><button class="chip" data-h="18">مساء</button><button class="chip" data-h="23">ليل</button><button class="chip" data-h="3">منتصف الليل</button></div>
            <div class="row"><button class="btn ${srv && srv.frozen ? 'on' : ''}" data-freeze>${srv && srv.frozen ? 'الوقت متوقف ✓' : 'أوقف الوقت'}</button><button class="btn ${srv && srv.blackout ? 'on' : ''}" data-black>${srv && srv.blackout ? 'انقطاع الكهرباء ✓' : 'اقطع الكهرباء'}</button></div></div>
          <div class="card"><h3>الطقس <span class="mute">(الآن: ${esc(srv && srv.weather || '?')})</span></h3><div class="row">${S.weathers.map((w) => `<button class="chip ltr" data-w="${w}">${w}</button>`).join('')}</div>
            <div class="row"><button class="btn" data-wauto>رجّع الطقس الطبيعي</button></div></div>` : ''}
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
        const tb = pg.querySelector('[data-time]'); if (tb) tb.onclick = () => act('time', { hour: val('hh'), minute: val('mm') });
        pg.querySelectorAll('[data-h]').forEach((b) => b.onclick = () => act('time', { hour: b.dataset.h, minute: 0 }));
        const fz = pg.querySelector('[data-freeze]'); if (fz) fz.onclick = async () => { await act('time', { freeze: !(srv && srv.frozen) }); await refresh(); rMe(pg); };
        const bl = pg.querySelector('[data-black]'); if (bl) bl.onclick = async () => { await act('blackout', { on: !(srv && srv.blackout) }); await refresh(); rMe(pg); };
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
            <div class="card"><h3>البلاغات (اللاعب يكتب /report)</h3>${s.reports.length ? s.reports.map((r) => `<div class="mem"><div><b>#${r.id} ${esc(r.name)}</b><div class="mute">${esc(r.text)} · قبل ${ago(r.at)}${r.left ? ' · خرج' : ''}</div></div>
                <div class="row"><button class="btn" data-r="goto" data-id="${r.id}">اذهب</button><button class="btn" data-r="bring" data-id="${r.id}">اجلبه</button><button class="btn ok" data-r="close" data-id="${r.id}">تمّ</button></div></div>`).join('') : '<div class="mute">لا بلاغات الآن</div>'}</div>
          </div>
          ${has('resource') ? `<div class="card" style="margin-top:12px"><h3>الموارد (إعادة تشغيل مورد واحد)</h3><div class="row"><input class="in w220" id="rs" placeholder="ابحث عن مورد"></div><div id="rl" style="margin-top:8px"></div></div>` : ''}`;
        const ab = pg.querySelector('[data-ann]'); if (ab) ab.onclick = () => act('announce', { text: val('ann') }, 'نشر الإعلان لكل اللاعبين؟');
        pg.querySelectorAll('[data-r]').forEach((b) => b.onclick = async () => { await act('report', { report: Number(b.dataset.id), op: b.dataset.r }); refresh(); });
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
    }

    // ------------------------------------------------------------- LOGS & BANS
    async function rLogs(pg) {
        pg.style.overflow = 'auto';
        pg.innerHTML = `<div class="row" style="margin-bottom:10px"><input class="in w220" id="lq" placeholder="ابحث في السجل"><button class="btn" id="lgo">ابحث</button></div><div id="lt"></div>
          ${has('ban') ? '<div class="card" style="margin-top:12px"><h3>المحظورون</h3><div id="bt"></div></div>' : ''}`;
        const my = page;
        const load = async () => {
            const L = arr(await fetchX('logs', val('lq')));
            if (page !== my || !document.getElementById('lt')) return;
            document.getElementById('lt').innerHTML = `<table><tr><th>متى</th><th>من</th><th>ماذا</th><th>على من</th><th>تفاصيل</th></tr>${L.map((l) => `<tr><td>قبل ${ago(l.at)}</td><td>${esc(l.actor)}</td><td class="ltr">${esc(l.action)}</td><td>${esc(l.target || '')}</td><td>${esc(l.details || '')}</td></tr>`).join('')}</table>`;
            if (has('ban')) {
                const B = arr(await fetchX('bans'));
                if (page !== my || !document.getElementById('bt')) return;
                document.getElementById('bt').innerHTML = B.length ? `<table><tr><th>#</th><th>الاسم</th><th>السبب</th><th>حتى</th><th></th></tr>${B.map((b) => `<tr><td>${b.id}</td><td>${esc(b.name)}</td><td>${esc(b.reason)}</td><td>${b.until ? new Date(b.until * 1000).toLocaleString('en-GB') : 'دائم'}</td><td><button class="btn" data-ub="${b.id}">فك الحظر</button></td></tr>`).join('')}</table>` : '<div class="mute">لا أحد محظور</div>';
                document.querySelectorAll('[data-ub]').forEach((x) => x.onclick = async () => { await act('unban', { ban: Number(x.dataset.ub) }, 'فك هذا الحظر؟'); load(); });
            }
        };
        document.getElementById('lgo').onclick = load; document.getElementById('lq').onkeydown = (e) => { if (e.key === 'Enter') load(); };
        load();
    }

    // ------------------------------------------------------------- STAFF
    async function rStaff(pg) {
        pg.style.overflow = 'auto';
        const my = page;
        const L = arr(await fetchX('staff'));
        if (page !== my) return;
        pg.innerHTML = `<div class="card" style="margin-bottom:12px"><h3>أضف للطاقم (اللاعب يجب أن يكون في السيرفر)</h3><div class="row"><select class="in w220" id="sp">${players.map((p) => `<option value="${p.id}">${p.id} · ${esc(p.char || p.name)}</option>`).join('')}</select>
            <select class="in" id="sr"><option value="helper">مساعد (يساعد اللاعبين فقط)</option><option value="admin">أدمن (كل شيء إلا الطاقم والموارد)</option></select><button class="btn acc" id="sa">أضف</button></div>
            <div class="mute" style="margin-top:8px">أنت «المالك»: لك كل شيء دائمًا (من group.admin في server.cfg).</div></div>
          <div class="card"><table><tr><th>الاسم</th><th>الدور</th><th>الحالة</th><th></th></tr>${L.map((s) => `<tr><td>${esc(s.name)}</td><td>${esc(s.roleLabel)}</td><td>${s.online ? '🟢 #' + s.online : '⚪'}</td><td><button class="btn bad" data-rm="${esc(s.license)}">أزله</button></td></tr>`).join('') || '<tr><td colspan="4" class="mute">لا أحد بعد</td></tr>'}</table></div>`;
        document.getElementById('sa').onclick = async () => { await act('staffadd', { id: Number(val('sp')), role: val('sr') }); rStaff(pg); };
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
