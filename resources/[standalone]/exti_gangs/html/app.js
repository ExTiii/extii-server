/* =====================================================================
   EX_Tii gangs — the street laptop (+ the top-center prompts)
   Each rank only sees what it can use: Runners get their board, Crew+ the gang, Underboss+ the logs,
   the Leader the settings and the bank withdraw.
   ===================================================================== */
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'exti_gangs';
    const post = (name, body) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) })
        .then((r) => r.json()).catch(() => ({ ok: false }));
    const $ = (s, el = document) => el.querySelector(s);
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.round(n || 0).toLocaleString('en-US');
    const mmss = (s) => `${Math.floor((s || 0) / 60)}:${String(Math.floor((s || 0) % 60)).padStart(2, '0')}`;
    const ago = (t, now) => {
        const s = Math.max(0, now - t);
        if (s < 60) return 'الآن'; if (s < 3600) return `${Math.floor(s / 60)} د`; if (s < 86400) return `${Math.floor(s / 3600)} س`; return `${Math.floor(s / 86400)} يوم`;
    };
    const dt = (t) => { const d = new Date(t * 1000); return `${d.getDate()}/${d.getMonth() + 1} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };

    const I = {
        home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>',
        users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.6 3.4-5.5 6.5-5.5s5.7 1.9 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c2 .7 3.2 2.4 3.6 5.2"/></svg>',
        wrench: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.6 2.6-2.4-.6-.6-2.4z"/></svg>',
        star: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/></svg>',
        gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>',
        list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>',
    };

    let D = null;          // the laptop data from the server
    let tab = 'home';
    const lap = $('#laptop');

    const ERR = {
        rank: 'رتبتك لا تسمح', noplayer: 'لا يوجد لاعب بهذا الرقم', far: 'اللاعب بعيد عنك (يجب أن يكون قريبًا)', ingang: 'هذا اللاعب في عصابة',
        full: 'العصابة ممتلئة', wait: 'هذا اللاعب ترك عصابة مؤخرًا وينتظر', slots: 'لا توجد أماكن فارغة لهذه الرتبة', leader: 'الزعيم لا يترك العصابة: انقل الزعامة أولًا',
        money: 'لا تملك هذا المبلغ نقدًا', bank: 'بنك العصابة لا يكفي', amount: 'أدخل مبلغًا', confirm: 'يجب التأكيد مرتين',
    };

    function toast(text, kind) {
        const old = $('.toast', lap); if (old) old.remove();
        const t = document.createElement('div'); t.className = `toast ${kind || ''}`; t.textContent = text;
        $('.screen', lap).appendChild(t); setTimeout(() => t.remove(), 2800);
    }

    function confirmBox(title, text, yes = 'تأكيد') {
        return new Promise((res) => {
            const d = document.createElement('div'); d.className = 'dlg';
            d.innerHTML = `<div class="box"><h3>${esc(title)}</h3><p>${esc(text)}</p><div class="row"><button class="btn gc" data-y>${esc(yes)}</button><button class="btn" data-n>إلغاء</button></div></div>`;
            $('.screen', lap).appendChild(d);
            d.querySelector('[data-y]').onclick = () => { d.remove(); res(true); };
            d.querySelector('[data-n]').onclick = () => { d.remove(); res(false); };
        });
    }

    async function act(name, args, okText) {
        const r = await post('act', { name, args });
        if (name === 'leave' && r && r.ok) { lap.classList.add('hidden'); lap.innerHTML = ''; D = null; S = null; return true; }
        if (r && r.data) D = r.data;
        if (r && r.ok) { if (okText) toast(okText, 'ok'); }
        else toast((r && ERR[r.why]) || 'لم يتم', 'bad');
        render();
        return r && r.ok;
    }

    // ------------------------------------------------------------------ tabs
    function tabsFor() {
        const t = [{ id: 'home', label: 'نظرة عامة', icon: I.home }];
        if (D.me.rank >= 1) t.push({ id: 'members', label: 'الأعضاء', icon: I.users });
        if (D.chop) t.push({ id: 'prod', label: 'ورشة التفكيك', icon: I.wrench });
        if (D.wash) t.push({ id: 'prod', label: 'غسيل الأموال', icon: I.wrench });
        if (D.craft) t.push({ id: 'prod', label: D.craft.type === 'ammo' ? 'مكبس الذخيرة' : 'طاولة الأسلحة', icon: I.wrench });
        if (D.weed) t.push({ id: 'prod', label: 'غرفة الزراعة', icon: I.wrench });
        if (D.turf) t.push({ id: 'turf', label: 'النفوذ', icon: I.star });
        t.push({ id: 'rep', label: 'السمعة', icon: I.star });
        if (D.me.rank === 3) t.push({ id: 'settings', label: 'الإعدادات', icon: I.gear });
        if (D.me.rank >= 2) t.push({ id: 'logs', label: 'السجل', icon: I.list });
        return t;
    }

    function shell(inner) {
        const g = D.gang;
        lap.style.setProperty('--gc', g.color);
        document.documentElement.style.setProperty('--gc', g.color);
        const tabs = tabsFor();
        if (!tabs.find((x) => x.id === tab)) tab = 'home';
        return `<div class="lap"><div class="lid"><div class="screen">
            <div class="bar">
                <div class="tagbadge">${esc(g.tag || '?')}</div>
                <div><h1>${esc(g.label)}</h1><div class="sub">${esc(g.typeLabel)} · ${g.members}/${g.maxMembers} عضو</div></div>
                <span class="chip gc">${esc(D.me.rankName)}</span>
                <div class="grow"></div>
                <span class="term">ex_tii://${esc(g.name)}<i></i></span>
                <button class="x" data-close>×</button>
            </div>
            <div class="side">
                ${tabs.map((t) => `<button class="tab ${t.id === tab ? 'on' : ''}" data-tab="${t.id}">${t.icon}<span>${t.label}</span></button>`).join('')}
                <div class="spacer"></div>
                <div class="me"><b>${esc(D.me.name)}</b><span>اليوم: ${D.me.partsToday}/${D.me.memberDaily} قطعة · ${money(D.me.paidToday)}</span></div>
            </div>
            <div class="main">${inner}</div>
        </div><div class="sticker">EX_TII · STREET-BOOK</div></div><div class="base"></div></div>`;
    }

    // ------------------------------------------------------------------ overview
    function home() {
        const g = D.gang, me = D.me;
        const rentLeft = g.rentDue - D.now;
        const partsPct = Math.min(100, (D.today.parts / Math.max(1, D.today.partsCap)) * 100);
        const myPct = Math.min(100, (me.partsToday / Math.max(1, me.memberDaily)) * 100);
        let h = '';
        if (g.locked) h += `<div class="alert bad">⚠ المقر مقفل: لم يُدفع إيجار الأسبوع (${money(g.rent)}). أودِعوا المبلغ في بنك العصابة ليُفتح تلقائيًا.</div>`;
        if (!g.deposits) h += `<div class="alert info">الزعيم أوقف تسليم القطع مؤقتًا.</div>`;
        h += `<div class="h2">نظرة عامة <small>${esc(g.typeEn)}</small></div><div class="grid g4">`;
        if (me.rank >= 1) h += `<div class="card"><div class="k">بنك العصابة</div><div class="v gc">${money(g.bank)}</div><div class="s">نقد نظيف</div></div>`;
        h += `<div class="card"><div class="k">أجر القطعة</div><div class="v">${money(g.partPay)}</div><div class="s">يُدفع عند التسليم</div></div>
              <div class="card"><div class="k">الإيجار القادم</div><div class="v">${money(g.rent)}</div><div class="s">${rentLeft > 0 ? 'بعد ' + Math.ceil(rentLeft / 86400) + ' يوم' : 'مستحق الآن'}</div></div>
              <div class="card"><div class="k">السمعة</div><div class="v">${D.rep.level} · ${esc(D.rep.name)}</div><div class="s">${D.rep.xp} نقطة</div></div>`;
        h += `</div><div class="grid g2 sect">
              <div class="card"><div class="k">قطع العصابة اليوم</div><div class="v">${D.today.parts} / ${D.today.partsCap}</div><div class="bar2"><i style="width:${partsPct}%"></i></div></div>
              <div class="card"><div class="k">قطعك اليوم</div><div class="v">${me.partsToday} / ${me.memberDaily}</div><div class="bar2"><i style="width:${myPct}%"></i></div>
                  <div class="s">${me.collectWait > 0 ? 'الجولة التالية بعد ' + mmss(me.collectWait) : 'جاهز لجولة جمع'} · ربحت اليوم ${money(me.paidToday)}</div></div></div>`;
        if (D.stash) {
            const s = D.stash;
            const ITEMS = {
                chop: [['chop_tools', 'أدوات التفكيك'], ['black_money', 'مال غير نظيف'], ['lockpick', 'مفاتيح فتح'], ['c4', 'C4']],
                wash: [['wash_supplies', 'مواد الغسيل'], ['black_money', 'مال غير نظيف'], ['lockpick', 'مفاتيح فتح'], ['c4', 'C4']],
                ammo: [['ammo_materials', 'مواد الذخيرة'], ['ammo-9', 'طلقات 9 ملم'], ['ammo-rifle', 'طلقات بندقية'], ['black_money', 'مال غير نظيف']],
                weapons: [['gun_parts', 'قطع الأسلحة'], ['WEAPON_PISTOL', 'مسدسات'], ['WEAPON_MICROSMG', 'رشاشات صغيرة'], ['black_money', 'مال غير نظيف']],
                weed: [['gang_weed_seeds', 'بذور'], ['weed_bud', 'براعم'], ['weed_og-kush', 'أكياس 2 غ'], ['black_money', 'مال غير نظيف']],
            };
            const items = ITEMS[D.gang.type] || ITEMS.chop;
            h += `<div class="h2 sect">المخزن</div><div class="grid g4">${items.map(([k, l]) => `<div class="card"><div class="k">${l}</div><div class="v">${k === 'black_money' ? money(s[k]) : (s[k] || 0)}</div></div>`).join('')}</div>`;
        }
        if (me.rank >= 1) {
            h += `<div class="h2 sect">البنك</div><div class="card"><div class="row">
                <input class="in" id="amt" type="number" min="1" placeholder="المبلغ" style="max-width:220px">
                <button class="btn gc" data-bank="deposit">إيداع نقد</button>
                ${me.rank === 3 ? '<button class="btn" data-bank="withdraw">سحب</button>' : ''}
                <div class="grow"></div><span class="s" style="color:var(--mute);font-size:12px">الإيداع للطاقم فما فوق · السحب للزعيم فقط</span></div></div>`;
        }
        if (me.rank < 3) h += `<div class="sect"><button class="btn bad" data-leave>ترك العصابة</button></div>`;
        if (me.rank === 0) h += `<div class="alert info sect">أنت عدّاء: اجمع القطع من نقطة الجمع وسلّمها هنا، وتُدفع لك من بنك العصابة. الطاقم يصنعون المنتج.</div>`;
        return h;
    }

    // ------------------------------------------------------------------ members
    function members() {
        const me = D.me;
        const can = (m) => (me.rank === 3 && m.rank < 3) || (me.rank === 2 && m.rank <= 1);
        let h = `<div class="h2">الأعضاء <small>${D.members.length}/${D.gang.maxMembers} · طاقم حتى ${D.slots.crew} · نواب حتى ${D.slots.underboss}</small></div>`;
        if (me.rank >= 2) h += `<div class="card" style="margin-bottom:12px"><div class="row"><input class="in" id="inv" type="number" placeholder="رقم اللاعب في السيرفر (قريب منك)" style="max-width:280px"><button class="btn gc" data-invite>دعوة</button><span style="color:var(--mute);font-size:12px">يبدأ كل عضو جديد عدّاءً</span></div></div>`;
        h += `<table class="table"><tr><th>العضو</th><th>الرتبة</th><th>اليوم</th><th>آخر ظهور</th><th></th></tr>`;
        for (const m of D.members) {
            const opts = [];
            if (can(m)) {
                const maxRank = me.rank === 3 ? 2 : 1;
                for (let r = 0; r <= maxRank; r++) if (r !== m.rank) opts.push(`<button class="btn sm" data-rank="${r}" data-cid="${esc(m.cid)}">${esc(D.ranks[r].name)}</button>`);
                opts.push(`<button class="btn sm bad" data-kick="${esc(m.cid)}" data-name="${esc(m.name)}">طرد</button>`);
                if (me.rank === 3) opts.push(`<button class="btn sm" data-transfer="${esc(m.cid)}" data-name="${esc(m.name)}">نقل الزعامة</button>`);
            }
            h += `<tr><td><span class="dot ${m.online ? 'on' : ''}"></span>${esc(m.name)}</td><td><span class="rank r${m.rank}">${esc(m.rankName)}</span></td>
                  <td class="num">${m.partsToday} قطعة · ${money(m.paidToday)}</td><td>${m.online ? 'متصل' : ago(m.lastSeen, D.now)}</td><td><div class="acts">${opts.join('')}</div></td></tr>`;
        }
        return h + '</table>';
    }

    // ------------------------------------------------------------------ chop shop
    function prod() {
        const c = D.chop;
        let h = `<div class="h2">ورشة التفكيك <small>السارق ${c.split.thief}% · المفكك ${c.split.chopper}% · العصابة ${100 - c.split.thief - c.split.chopper}%</small></div>`;
        if (c.busy) h += `<div class="alert info">سيارة قيد التفكيك: ${esc(c.busy.plate)} · ${esc(c.busy.tier)} · المرحلة ${c.busy.stage}/4</div>`;
        h += `<div class="grid g4">
            <div class="card"><div class="k">التفكيك اليوم</div><div class="v">${c.chops} / ${c.chopsCap}</div><div class="bar2"><i style="width:${Math.min(100, c.chops / c.chopsCap * 100)}%"></i></div></div>
            <div class="card"><div class="k">الورشة</div><div class="v ${c.cooldown > 0 ? '' : 'gc'}">${c.cooldown > 0 ? mmss(c.cooldown) : 'جاهزة'}</div><div class="s">8 دقائق بين كل تفكيك</div></div>
            <div class="card"><div class="k">أدوات التفكيك</div><div class="v">${c.tools}</div><div class="s">في المخزن</div></div>
            <div class="card"><div class="k">C4 اليوم</div><div class="v">${c.c4} / ${c.c4Cap}</div><div class="s">من الخارقة والرياضية</div></div></div>`;
        h += `<div class="h2 sect">المطلوب اليوم <small>+${Math.round(c.wantedBonus * 100)}% مال</small></div><div class="wanted">${c.wanted.map((w) => `<span>${esc(w)}</span>`).join('')}</div>`;
        h += `<div class="h2 sect">الفئات</div><table class="table tiers"><tr><th>الفئة</th><th>الأدوات</th><th>الوقت</th><th>مال غير نظيف</th><th>مفاتيح</th><th>C4</th></tr>
            ${c.tiers.map((t) => `<tr><td><b>${esc(t.label)}</b></td><td>${t.tools}</td><td>${t.minutes} د</td><td class="num"><span class="ltr">${money(t.money[0])} – ${money(t.money[1])}</span></td><td>${t.lockpicks[0] === t.lockpicks[1] ? t.lockpicks[0] : t.lockpicks.join('–')}</td><td>${Math.round(t.c4 * 100)}%</td></tr>`).join('')}</table>
            <div class="alert info sect">سيارات اللاعبين: تذهب لساحة الحجز ويدفع صاحبها ما ربحتموه منها (يُحذف من الاقتصاد). لا تُفكّك سيارات نفس المالك أكثر من مرة كل 72 ساعة.</div>`;
        return h;
    }

    // ------------------------------------------------------------------ money wash
    function washTab() {
        const w = D.wash;
        let h = `<div class="h2">غسيل الأموال <small>نسبة العصابة ${w.cut}% · للغاسل ${w.washerShare}% منها · الباقي لبنك العصابة</small></div>`;
        if (w.busy) h += `<div class="alert info">دفعة في الآلة الآن: ${money(w.busy.total)} · الخطوة ${Math.min(3, w.busy.stage + 1)}/3</div>`;
        h += `<div class="grid g4">
            <div class="card"><div class="k">غُسل اليوم</div><div class="v">${money(w.washed)}</div><div class="s">من ${money(w.washCap)}</div><div class="bar2"><i style="width:${Math.min(100, w.washed / Math.max(1, w.washCap) * 100)}%"></i></div></div>
            <div class="card"><div class="k">في الصندوق</div><div class="v">${money(w.queueTotal)}</div><div class="s">${w.queueCount} طلب ينتظر</div></div>
            <div class="card"><div class="k">الآلة</div><div class="v ${w.cooldown > 0 ? '' : 'gc'}">${w.cooldown > 0 ? mmss(w.cooldown) : 'جاهزة'}</div><div class="s">حتى ${money(w.batchMax)} للدفعة</div></div>
            <div class="card"><div class="k">مواد الغسيل</div><div class="v">${w.supplies}</div><div class="s">1 لكل ${money(w.supplyPer)}</div></div></div>`;
        h += `<div class="h2 sect">الطلبات <small>الأقدم يُغسل أولًا</small></div><table class="table"><tr><th>الزبون</th><th>ينتظر</th><th>النسبة</th><th>منذ</th></tr>
            ${(w.queue || []).map((o) => `<tr><td><b>${esc(o.name)}</b></td><td class="num">${money(o.left)}</td><td>${o.cut}%</td><td>${dt(o.created)}</td></tr>`).join('') || '<tr><td colspan="4">الصندوق فارغ</td></tr>'}</table>
            <div class="alert info sect">الزبون يضع ماله غير النظيف في صندوق الغسيل خارج المقر، ويأخذه نقدًا نظيفًا من نفس الصندوق. بعض الدفعات فيها أوراق مُعلَّمة تصل بسببها إخبارية للشرطة.</div>`;
        return h;
    }

    // ------------------------------------------------------------------ ammo / weapons
    function craftTab() {
        const c = D.craft, ammo = c.type === 'ammo';
        let h = `<div class="h2">${ammo ? 'مكبس الذخيرة' : 'طاولة الأسلحة'} <small>${ammo ? '1 مادة = ' + c.perMaterial + ' طلقة' : 'كل سلاح بلا رقم تسلسلي'}</small></div>`;
        if (c.busy) h += `<div class="alert info">قيد العمل: ${esc(c.busy.label)} · الخطوة ${Math.min(3, c.busy.stage + 1)}/3</div>`;
        h += `<div class="grid g3">
            <div class="card"><div class="k">${ammo ? 'طلقات اليوم' : 'أسلحة اليوم'}</div><div class="v">${c.made} / ${c.cap}</div><div class="bar2"><i style="width:${Math.min(100, c.made / Math.max(1, c.cap) * 100)}%"></i></div></div>
            <div class="card"><div class="k">${ammo ? 'مواد الذخيرة' : 'قطع الأسلحة'}</div><div class="v">${c.parts}</div><div class="s">في المخزن</div></div>
            <div class="card"><div class="k">الآلة</div><div class="v ${c.cooldown > 0 ? '' : 'gc'}">${c.cooldown > 0 ? mmss(c.cooldown) : 'جاهزة'}</div></div></div>`;
        h += `<div class="h2 sect">ما تصنعونه <small>يُفتح مع سمعة العصابة</small></div><table class="table"><tr><th>${ammo ? 'النوع' : 'السلاح'}</th>${ammo ? '' : '<th>القطع</th>'}<th>السمعة</th><th></th></tr>
            ${c.list.map((x) => `<tr><td><b>${esc(x.label)}</b></td>${ammo ? '' : `<td>${x.parts}</td>`}<td>${x.rep}</td><td>${x.open ? '<span style="color:var(--gc);font-weight:700">مفتوح</span>' : '<span style="color:var(--mute)">مقفل</span>'}</td></tr>`).join('')}</table>
            <div class="alert info sect">بيعوا للاعبين بالسعر الذي تريدونه. ما يزيد يشتريه رجل السوق السوداء بسعر منخفض (مال غير نظيف).</div>`;
        return h;
    }

    // ------------------------------------------------------------------ weed
    function weedTab() {
        const w = D.weed;
        let h = `<div class="h2">غرفة الزراعة <small>تنضج النبتة في ${Math.round(w.grow / 60)} دقيقة · اسقوها كل ${Math.round(w.water / 60)} دقائق</small></div>
            <div class="grid g3"><div class="card"><div class="k">بذور</div><div class="v">${w.seeds}</div></div>
            <div class="card"><div class="k">براعم</div><div class="v">${w.buds}</div></div>
            <div class="card"><div class="k">أكياس 2 غ</div><div class="v gc">${w.bags}</div></div></div>
            <div class="h2 sect">الأصص</div><div class="grid g4">`;
        h += (w.pots || []).map((p) => p.empty ? `<div class="card"><div class="k">أصيص ${p.i}</div><div class="v" style="color:var(--mute)">فارغ</div></div>`
            : `<div class="card"><div class="k">أصيص ${p.i}${p.fert ? ' · مسمّد' : ''}</div><div class="v ${p.ready ? 'gc' : ''}">${p.ready ? 'ناضجة' : mmss(p.left)}</div>
               <div class="s">${p.wet > 0 ? 'رطب ' + mmss(p.wet) : '<b style="color:#ff5a4f">جاف! اسقوها</b>'}</div></div>`).join('') || '<div class="card">لا توجد أصص بعد</div>';
        h += `</div><div class="alert info sect">البيع: استعمل كيس الحشيش على زاوية شارع وانتظر الزبائن. في منطقتكم الخطر أقل، وفي منطقة عصابة أخرى أكبر.</div>`;
        return h;
    }

    // ------------------------------------------------------------------ turf
    function turfTab() {
        const t = D.turf;
        let h = `<div class="h2">مناطق النفوذ <small>العصابة صاحبة أكثر العلامات في المنطقة تملكها · +سمعة كل ساعة</small></div>
            <div class="grid g2"><div class="card"><div class="k">مناطقكم</div><div class="v gc">${t.owned}</div></div>
            <div class="card"><div class="k">سمعة كل ساعة</div><div class="v">+${t.repPerHour}</div></div></div>`;
        h += `<table class="table sect"><tr><th>المنطقة</th><th>صاحبها</th><th>علاماتكم</th><th>كل العلامات</th></tr>
            ${(t.zones || []).map((z) => `<tr><td><b>${esc(z.name)}</b></td><td>${z.owner ? `<span class="dot" style="background:${esc(z.color || '#888')}"></span> ${esc(z.owner)}${z.mine ? ' (أنتم)' : ''}` : '<span style="color:var(--mute)">لا أحد</span>'}</td><td>${z.myTags}</td><td>${z.total} / ${z.max}</td></tr>`).join('') || '<tr><td colspan="4">لا توجد مناطق بعد</td></tr>'}</table>
            <div class="alert info sect">علبة رش من متجر العدد = علامة واحدة (20 ثانية). فرشاة التنظيف تمسح علامات العصابات الأخرى (3 مرات). الشرطة تنظّف أي علامة.</div>`;
        return h;
    }

    // ------------------------------------------------------------------ rep
    function rep() {
        const r = D.rep;
        const pct = r.to ? Math.min(100, ((r.xp - r.from) / (r.to - r.from)) * 100) : 100;
        let h = `<div class="h2">سمعة العصابة <small>تأتي من العمل: القطع والتفكيك والطاولة</small></div>
            <div class="card"><div class="row"><div class="grow"><div class="k">المستوى ${r.level}</div><div class="v gc" style="text-align:right">${esc(r.name)}</div></div>
            <div style="color:var(--mute);font-size:13px;direction:ltr">${r.xp}${r.to ? ' / ' + r.to : ''} XP</div></div><div class="bar2"><i style="width:${pct}%"></i></div></div>
            <div class="ladder sect">`;
        r.levels.forEach((l, i) => {
            const n = i + 1;
            h += `<div class="step ${n < r.level ? 'done' : n === r.level ? 'now' : ''}"><h4>${n} · ${esc(l.name)}</h4>
                <div>${l.partsDaily} قطعة يوميًا</div><div>${({ wash: money(l.washDaily) + ' غسيل يوميًا', chop: l.chopsDaily + ' تفكيك يوميًا', ammo: (D.ammoDaily ? D.ammoDaily[i] : '') + ' طلقة يوميًا', weapons: '6 أسلحة يوميًا', weed: '12 أصيصًا' })[D.gang.type] || ''}</div><div>مخزن ${l.stashSlots} خانة · ${Math.round(l.stashWeight / 1000)} كغ</div>
                <div>${l.rentOff ? 'خصم إيجار ' + Math.round(l.rentOff * 100) + '%' : 'إيجار كامل'}</div><div style="direction:ltr;text-align:right">${l.xp} XP</div></div>`;
        });
        return h + '</div>';
    }

    // ------------------------------------------------------------------ settings (leader)
    let S = null;
    function settings() {
        S = S || { ...D.settings, color: D.gang.color, tag: D.gang.tag };
        const L = D.limits;
        const slider = (key, label, lim, unit) => `<div class="field"><label>${label}<b>${unit === '$' ? '$' + S[key] : S[key] + '%'}</b></label>
            <input type="range" min="${lim.min}" max="${lim.max}" value="${S[key]}" data-set="${key}"></div>`;
        return `<div class="h2">الإعدادات <small>للزعيم فقط</small></div><div class="grid g2">
            ${slider('partPay', 'أجر القطعة للأعضاء', L.partPay, '$')}
            <div class="field"><label>تسليم القطع<b>${S.deposits ? 'مفتوح' : 'مقفل'}</b></label><button class="toggle ${S.deposits ? 'on' : ''}" data-toggle="deposits"></button></div>
            ${D.gang.type === 'wash' ? slider('washCut', 'نسبة العصابة من الغسيل', L.wash) : D.gang.type === 'chop' ? slider('thiefCut', 'حصة سارق السيارة', L.thief) + slider('chopperCut', 'حصة المفكك', L.chopper) : ''}
            <div class="field"><label>لون العصابة</label><div class="swatches">${D.colors.map((c) => `<button class="sw ${c === S.color ? 'on' : ''}" style="background:${c}" data-color="${c}"></button>`).join('')}</div></div>
            <div class="field"><label>رمز العصابة (2–4 حروف إنجليزية)</label><input class="in" id="tag" maxlength="4" value="${esc(S.tag || '')}"></div>
            </div><div class="sect"><button class="btn gc" data-save>حفظ الإعدادات</button></div>`;
    }

    // ------------------------------------------------------------------ logs
    const ACTION = { parts_in: 'تسليم قطع', chop: 'تفكيك', chop_player_car: 'تفكيك سيارة لاعب', chop_start: 'بدء تفكيك', chop_cancel: 'إلغاء تفكيك', bench_lockpicks: 'مفاتيح فتح',
        bank_deposit: 'إيداع', bank_withdraw: 'سحب', rent_paid: 'دفع الإيجار', rent_unpaid: 'إيجار غير مدفوع', joined: 'انضمام', left: 'مغادرة', kick: 'طرد', promote: 'ترقية',
        demote: 'تخفيض', leader_transfer: 'نقل الزعامة', leader_auto: 'زعامة تلقائية', settings: 'الإعدادات', stash_take: 'أخذ من المخزن', outfit_saved: 'زي العصابة',
        rep_level: 'مستوى سمعة', gang_created: 'إنشاء العصابة', wash: 'غسيل دفعة', wash_start: 'بدء غسيل', wash_drop: 'طلب غسيل', wash_collect: 'استلام نظيف',
        wash_cancel: 'إلغاء طلب', turf_tag: 'علامة نفوذ', ammo_start: 'بدء ذخيرة', ammo_made: 'ذخيرة', gun_start: 'بدء سلاح', gun_made: 'سلاح', craft_stop: 'إيقاف الآلة',
        weed_harvest: 'حصاد', weed_bagged: 'تعبئة', black_market: 'سوق سوداء', turf_scrub: 'مسح علامة', turf_scrubbed: 'مُسحت علامتنا', wash_cancel_batch: 'إيقاف الغسيل', door_breach_start: 'محاولة اقتحام', door_breached: 'اقتحام', stolen_report: 'بلاغ سرقة' };
    function logs() {
        return `<div class="h2">السجل <small>آخر 100 عملية</small></div><div class="card" style="padding:4px 4px">${(D.logs || []).map((l) =>
            `<div class="log"><span class="t">${dt(l.created)}</span><span class="a">${esc(ACTION[l.action] || l.action)}</span><span><b>${esc(l.actor)}</b> ${esc(l.details || '')}</span></div>`).join('') || '<div class="log">لا شيء بعد</div>'}</div>`;
    }

    // ------------------------------------------------------------------ render + clicks
    function render() {
        if (!D) return;
        const body = tab === 'members' ? members() : tab === 'prod' ? (D.wash ? washTab() : D.craft ? craftTab() : D.weed ? weedTab() : prod()) : tab === 'rep' ? rep() : tab === 'turf' ? turfTab() : tab === 'settings' ? settings() : tab === 'logs' ? logs() : home();
        const scroll = $('.main', lap) ? $('.main', lap).scrollTop : 0;
        lap.innerHTML = shell(body);
        $('.main', lap).scrollTop = scroll;
    }

    lap.addEventListener('click', async (e) => {
        const b = e.target.closest('button'); if (!b) return;
        if (b.dataset.close !== undefined) return close();
        if (b.dataset.tab) { tab = b.dataset.tab; S = null; return render(); }
        if (b.dataset.bank) {
            const amount = Number($('#amt', lap).value);
            return act('bank', { kind: b.dataset.bank, amount }, b.dataset.bank === 'deposit' ? 'تم الإيداع' : 'تم السحب');
        }
        if (b.dataset.invite !== undefined) return act('invite', { id: Number($('#inv', lap).value) }, 'أُرسلت الدعوة');
        if (b.dataset.rank) return act('rank', { cid: b.dataset.cid, rank: Number(b.dataset.rank) }, 'تم تغيير الرتبة');
        if (b.dataset.kick) { if (await confirmBox('طرد العضو', `طرد ${b.dataset.name}؟ ينتظر 48 ساعة قبل الانضمام لعصابة أخرى.`, 'طرد')) act('kick', { cid: b.dataset.kick }, 'تم الطرد'); return; }
        if (b.dataset.transfer) {
            if (!(await confirmBox('نقل الزعامة', `هل تريد جعل ${b.dataset.name} زعيم العصابة؟ تصبح أنت نائبًا.`, 'نعم'))) return;
            if (!(await confirmBox('تأكيد أخير', 'لا يمكنك التراجع عن هذا بنفسك. متأكد؟', 'انقل الزعامة'))) return;
            return act('transfer', { cid: b.dataset.transfer, c1: true, c2: true }, 'نُقلت الزعامة');
        }
        if (b.dataset.leave !== undefined) { if (await confirmBox('ترك العصابة', 'تنتظر 48 ساعة قبل الانضمام لعصابة أخرى.', 'اترك')) act('leave', {}, 'تركت العصابة'); return; }
        if (b.dataset.toggle) { S[b.dataset.toggle] = !S[b.dataset.toggle]; return render(); }
        if (b.dataset.color) { S.color = b.dataset.color; return render(); }
        if (b.dataset.save !== undefined) {
            S.tag = ($('#tag', lap).value || '').toUpperCase();
            const ok = await act('settings', { settings: S }, 'حُفظت الإعدادات');
            if (ok) S = null;
            render();
        }
    });
    lap.addEventListener('input', (e) => {
        if (e.target.dataset.set) { S[e.target.dataset.set] = Number(e.target.value); const l = e.target.parentElement.querySelector('b'); if (l) l.textContent = e.target.dataset.set === 'partPay' ? '$' + e.target.value : e.target.value + '%'; }
    });

    function close() { lap.classList.add('hidden'); lap.innerHTML = ''; D = null; S = null; post('close'); }
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !lap.classList.contains('hidden') && !$('.dlg', lap)) close(); });

    // ------------------------------------------------------------------ top-center prompt
    const pr = $('#prompt');
    let prTimer = null;
    function prompt(p) {
        clearTimeout(prTimer);
        pr.style.setProperty('--gc', p.color || '#e8b547');
        pr.innerHTML = `<div class="tagbadge">${esc(p.tag || '!')}</div><div><h3>${esc(p.title)}</h3><p>${esc(p.text)}</p></div>
            <div class="row"><span class="btn gc">[Y] ${esc(p.yes)}</span><span class="btn">[U] ${esc(p.no)}</span></div><div class="timer"><i style="width:100%"></i></div>`;
        pr.classList.remove('hidden');
        requestAnimationFrame(() => { const i = $('.timer i', pr); i.style.transitionDuration = (p.timeout || 20) + 's'; i.style.width = '0%'; });
        prTimer = setTimeout(() => pr.classList.add('hidden'), (p.timeout || 20) * 1000 + 500); // (the game decides; this only hides it)
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'laptop') { D = m.data; tab = 'home'; S = null; lap.classList.remove('hidden'); render(); }
        else if (m.action === 'prompt') prompt(m.prompt);
        else if (m.action === 'promptClose') { clearTimeout(prTimer); pr.classList.add('hidden'); }
    });
    window.EXG = { open: (d) => { D = d; tab = 'home'; lap.classList.remove('hidden'); render(); }, tab: (t) => { tab = t; render(); }, prompt };
})();
