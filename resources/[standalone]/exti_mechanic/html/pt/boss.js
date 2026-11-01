// EX_Tii Mechanic tablet — Management (the Boss Menu, like the video): dashboard, cash flow, funds,
// members (hire, bonus, promote, demote, fire), ranks (name and salary), the department log.
(() => {
    const { S, I, esc, call, render, toast, fail, ask, money, fmtStamp, fmtDate } = PT;

    const iso = (t) => { const d = PT.dateOf(t); return `${d.getFullYear()}-${PT.pad(d.getMonth() + 1)}-${PT.pad(d.getDate())}`; };
    S.boss = {
        tab: 'dash', dash: null, flow: null, funds: null, members: null, roles: null, logs: null, nearby: [], sal: false,
        dep: '', wd: '', inv: { target: '', grade: '' }, edit: null, q: '', from: '', to: '',
    };
    const B = () => S.boss;

    const TABS = [
        ['dash', 'لوحة التحكم', 'grid'], ['flow', 'التدفق المالي', 'chart'], ['funds', 'الأموال', 'wallet'],
        ['billing', 'قوالب الفواتير', 'receipt'], ['members', 'الأعضاء', 'users'], ['roles', 'الرتب', 'badge'], ['logs', 'السجل', 'list'],
    ];

    // what each line in the log means
    const ACTIONS = {
        salary_paid: 'راتب مدفوع', vehicle_bought: 'شراء مركبة', vehicle_sold: 'بيع مركبة', plate_changed: 'تغيير لوحة',
        money_deposited: 'إيداع', money_withdrawn: 'سحب', bonus_paid: 'مكافأة', promoted: 'ترقية', demoted: 'تخفيض رتبة',
        fired: 'فصل', hired: 'توظيف', role_changed: 'تعديل رتبة', calendar_added: 'موعد جديد',
        fine_issued: 'فاتورة', fine_paid: 'فاتورة مدفوعة', offence_added: 'خدمة جديدة', offence_changed: 'تعديل خدمة', offence_removed: 'حذف خدمة',
        door_unlocked: 'فتح باب', door_locked: 'قفل باب',
    };
    const actionLabel = (a) => ACTIONS[a] || a;

    const short = (n) => {
        n = Number(n) || 0;
        if (Math.abs(n) >= 1e6) return `$${(n / 1e6).toFixed(n % 1e6 ? 1 : 0)}M`;
        if (Math.abs(n) >= 1e3) return `$${(n / 1e3).toFixed(n % 1e3 ? 1 : 0)}k`;
        return `$${n}`;
    };
    const balanceNow = () => {
        const b = B();
        if (b.funds && b.funds.balance != null) return b.funds.balance;
        if (b.dash && b.dash.funds != null) return b.dash.funds;
        return null;
    };

    // ------------------------------------------------------------------
    // the pages
    // ------------------------------------------------------------------
    const loading = '<div class="pt-empty"><span class="pt-spin"></span><p>جارٍ التحميل…</p></div>';
    const stat = (icon, label, value, tone = '') => `<div class="pt-stat ${tone}"><i>${I(icon, 20, 2)}</i><span><small>${esc(label)}</small><b class="ltr">${esc(value)}</b></span></div>`;

    function dashView() {
        const d = B().dash;
        if (!d) return loading;
        const col = (icon, title, rows) => `<div class="pt-bcol"><h4>${I(icon, 16, 2)} ${esc(title)}</h4>${rows.length ? rows.map((r) => `<p>${I('user', 14, 2)} ${r}</p>`).join('') : '<p class="pt-mute">لا أحد</p>'}</div>`;
        return `<h2 class="pt-bh">نظرة عامة</h2>
            <div class="pt-stats">
                ${stat('wallet', 'الأموال', money(d.funds))}
                ${stat('badge', 'في الخدمة', String(PT.list(d.onDuty).length), 'green')}
                ${stat('user', 'خارج الخدمة', String(PT.list(d.offDuty).length))}
            </div>
            <h3 class="pt-bh3">الأعضاء المتصلون</h3>
            <div class="pt-bcols">
                ${col('badge', 'في الخدمة', PT.list(d.onDuty).map(esc))}
                ${col('user', 'خارج الخدمة', PT.list(d.offDuty).map(esc))}
                ${col('fire', 'الأكثر نشاطًا هذا الأسبوع', PT.list(d.active).map((a) => `${esc(a.name)} <span class="pt-mute">· ${a.hours} ساعة</span>`))}
            </div>
            <p class="pt-hint">عدد عمّال الورشة كلهم: ${d.members || 0}</p>`;
    }

    // two series (money in / money out) over the last 14 days. Hover a day for the numbers.
    function lineChart(days) {
        const W = 620; const H = 250; const L = 58; const R = 14; const T = 14; const Bt = 30;
        const n = days.length;
        const top = Math.max(1, ...days.map((d) => Math.max(d.rev, d.exp)));
        const step = Math.pow(10, Math.floor(Math.log10(top)));
        const max = Math.ceil(top / step) * step;
        const x = (i) => L + (i * (W - L - R)) / Math.max(1, n - 1);
        const y = (v) => T + (H - T - Bt) * (1 - v / max);
        const ticks = [0, 0.25, 0.5, 0.75, 1].map((k) => max * k);
        const path = (key) => days.map((d, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(d[key]).toFixed(1)}`).join(' ');
        const cols = days.map((d, i) => `<div class="pt-hcol" style="left:${((x(i) - (W - L - R) / (2 * (n - 1))) / W * 100).toFixed(2)}%;width:${((W - L - R) / (n - 1) / W * 100).toFixed(2)}%">
            <span class="pt-hx" style="top:${(T / H * 100).toFixed(1)}%;bottom:${(Bt / H * 100).toFixed(1)}%"></span>
            <div class="pt-htip ${i > n / 2 ? 'left' : ''}"><b class="ltr">${esc(d.day)}</b><span><i class="s1"></i>الإيرادات <bdi class="ltr">${money(d.rev)}</bdi></span><span><i class="s2"></i>المصروفات <bdi class="ltr">${money(d.exp)}</bdi></span></div>
        </div>`).join('');
        return `<div class="pt-chart">
            <div class="pt-legend"><span><i class="s1"></i>الإيرادات</span><span><i class="s2"></i>المصروفات</span></div>
            <div class="pt-plot">
                <svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
                    ${ticks.map((t) => `<line class="grid" x1="${L}" x2="${W - R}" y1="${y(t).toFixed(1)}" y2="${y(t).toFixed(1)}"/><text class="ytick" x="${L - 8}" y="${(y(t) + 4).toFixed(1)}" text-anchor="end">${short(t)}</text>`).join('')}
                    ${days.map((d, i) => (i % 2 === (n - 1) % 2 ? `<text class="xtick" x="${x(i).toFixed(1)}" y="${H - 9}" text-anchor="middle">${esc(d.day)}</text>` : '')).join('')}
                    <path class="line s1" d="${path('rev')}"/><path class="line s2" d="${path('exp')}"/>
                    ${days.map((d, i) => `<circle class="dot s1" cx="${x(i).toFixed(1)}" cy="${y(d.rev).toFixed(1)}" r="3"/><circle class="dot s2" cx="${x(i).toFixed(1)}" cy="${y(d.exp).toFixed(1)}" r="3"/>`).join('')}
                </svg>
                <div class="pt-hcols">${cols}</div>
            </div>
        </div>`;
    }

    // the share of each kind (at most 5 + the rest)
    const SERIES = ['var(--s1)', 'var(--s2)', 'var(--s3)', 'var(--s4)', 'var(--s5)', 'var(--s6)'];
    function donut(title, cats) {
        let items = PT.list(cats).filter((c) => c.amount > 0);
        if (items.length > 5) {
            const rest = items.slice(5).reduce((s, c) => s + c.amount, 0);
            items = items.slice(0, 5).concat([{ action: '_other', amount: rest }]);
        }
        const total = items.reduce((s, c) => s + c.amount, 0);
        const r = 46; const C = 2 * Math.PI * r;
        let at = 0;
        const gap = items.length > 1 ? 2 : 0;
        const segs = items.map((c, i) => {
            const len = (c.amount / total) * C;
            const seg = `<circle r="${r}" cx="60" cy="60" stroke="${SERIES[i]}" stroke-dasharray="${Math.max(0, len - gap).toFixed(2)} ${(C - Math.max(0, len - gap)).toFixed(2)}" stroke-dashoffset="${(-at).toFixed(2)}"/>`;
            at += len;
            return seg;
        }).join('');
        return `<div class="pt-donut"><h4>${esc(title)}</h4>
            ${total ? `<div class="pt-dring"><svg viewBox="0 0 120 120"><g transform="rotate(-90 60 60)">${segs}</g></svg><b class="ltr">${short(total)}</b></div>
            <ul>${items.map((c, i) => `<li><i style="background:${SERIES[i]}"></i><span>${esc(c.action === '_other' ? 'أخرى' : actionLabel(c.action))}</span><b class="ltr">${money(c.amount)}</b><small class="ltr">${Math.round((c.amount / total) * 100)}%</small></li>`).join('')}</ul>`
            : '<p class="pt-mute">لا شيء بعد.</p>'}
        </div>`;
    }

    function flowView() {
        const f = B().flow;
        if (!f) return loading;
        const days = PT.list(f.days).map((d) => ({ day: d.day, rev: Number(d.rev) || 0, exp: Number(d.exp) || 0 }));
        const any = days.some((d) => d.rev || d.exp);
        return `<h2 class="pt-bh">النظرة المالية <small>آخر 14 يومًا</small></h2>
            <div class="pt-stats">
                ${stat('up', 'الإيرادات', money(f.revenue), 'green')}
                ${stat('down', 'المصروفات', money(f.expenses), 'red')}
                ${stat('dollar', 'الصافي', `${f.profit < 0 ? '-' : ''}${money(Math.abs(f.profit))}`, 'amber')}
            </div>
            <div class="pt-flow">
                <div class="pt-card">${any ? lineChart(days) : '<div class="pt-empty"><p>لا توجد حركة مالية في آخر 14 يومًا.</p></div>'}</div>
                <div class="pt-card pt-donuts">${donut('أين ذهبت الأموال', f.outCat)}${donut('من أين جاءت الأموال', f.inCat)}</div>
            </div>
            <p class="pt-hint">الرواتب تدفعها المدينة ولا تُخصم من حساب الورشة، لذلك تظهر في السجل فقط.</p>`;
    }

    function moneyTable(rows) {
        rows = PT.list(rows);
        if (!rows.length) return '<p class="pt-mute pad">لا توجد عمليات بعد.</p>';
        return `<table class="pt-table"><thead><tr><th>الوقت</th><th>الاسم</th><th>العملية</th><th>المبلغ</th></tr></thead><tbody>
            ${rows.map((r) => `<tr><td class="ltr">${esc(fmtStamp(r.at))}</td><td>${esc(r.name || '—')}</td><td>${esc(actionLabel(r.action))}${r.content ? ` <small class="pt-mute">${esc(r.content)}</small>` : ''}</td>
            <td class="ltr ${r.money === 'in' ? 'pos' : 'neg'}">${r.money === 'in' ? '+' : '-'}${money(r.amount)}</td></tr>`).join('')}
        </tbody></table>`;
    }

    function fundsView() {
        const f = B().funds;
        if (!f) return loading;
        return `<h2 class="pt-bh">إدارة الأموال</h2>
            <small class="pt-mute">الرصيد الحالي</small>
            <div class="pt-balance ltr">${money(f.balance)}</div>
            <div class="pt-moneyrow">
                <div class="pt-moneybox"><span class="ltr">$</span><input class="pt-in bare ltr" inputmode="numeric" data-model="boss.dep" data-enter="bossDeposit" value="${esc(B().dep)}" placeholder="0"><button class="pt-btn green sm" data-act="bossDeposit">${I('down', 14, 2.2)} إيداع</button></div>
                <div class="pt-moneybox"><span class="ltr">$</span><input class="pt-in bare ltr" inputmode="numeric" data-model="boss.wd" data-enter="bossWithdraw" value="${esc(B().wd)}" placeholder="0"><button class="pt-btn primary sm" data-act="bossWithdraw">${I('up', 14, 2.2)} سحب</button></div>
            </div>
            <p class="pt-hint">الإيداع من حسابك البنكي إلى حساب الورشة، والسحب من حساب الورشة إلى حسابك.</p>
            <h3 class="pt-bh3">آخر العمليات</h3>
            <div class="pt-tablewrap">${moneyTable(f.recent)}</div>`;
    }

    function membersView() {
        const m = B().members;
        if (!m) return loading;
        const my = m.myGrade;
        const grades = PT.list(m.grades);
        const nearby = PT.list(B().nearby);
        const inv = B().inv;
        const lower = grades.filter((g) => g.grade < my);
        const lastSeen = (x) => (x.online ? '<em class="pt-tag green">متصل الآن</em>' : x.lastSeen ? `<span class="ltr">${esc(fmtStamp(x.lastSeen))}</span>` : '—');
        const rows = PT.list(m.members).map((x) => {
            const me = x.cid === m.me;
            const canRank = !me && x.grade < my;
            return `<tr class="${me ? 'me' : ''}">
                <td><b>${esc(x.name)}</b>${me ? ' <i class="pt-me">أنت</i>' : ''}</td>
                <td>${esc(x.rank)}</td>
                <td>${lastSeen(x)}</td>
                <td class="ltr">${x.hours}</td>
                <td>${x.onDuty ? '<em class="pt-tag green">في الخدمة</em>' : x.online ? '<em class="pt-tag grey">خارج الخدمة</em>' : '<span class="pt-mute">غير متصل</span>'}</td>
                <td class="pt-acts">
                    <button class="pt-mini blue" data-act="bossBonus" data-cid="${esc(x.cid)}" ${me ? 'disabled' : ''} title="مكافأة">${I('gift', 13, 2)} مكافأة</button>
                    <button class="pt-mini green" data-act="bossGrade" data-cid="${esc(x.cid)}" data-g="${x.grade + 1}" ${canRank && x.grade + 1 < my && grades.some((g) => g.grade === x.grade + 1) ? '' : 'disabled'} title="ترقية">${I('up', 13, 2.4)}</button>
                    <button class="pt-mini amber" data-act="bossGrade" data-cid="${esc(x.cid)}" data-g="${x.grade - 1}" ${canRank && x.grade > 0 ? '' : 'disabled'} title="تخفيض">${I('down', 13, 2.4)}</button>
                    <button class="pt-mini red" data-act="bossFire" data-cid="${esc(x.cid)}" ${canRank ? '' : 'disabled'} title="فصل">${I('x', 13, 2.4)}</button>
                </td></tr>`;
        }).join('');
        return `<h2 class="pt-bh">قائمة الأعضاء</h2>
            <div class="pt-invite">
                <select class="pt-in" data-model="boss.inv.target"><option value="">اختر شخصًا بجانبك…</option>${nearby.map((p) => `<option value="${p.id}" ${String(inv.target) === String(p.id) ? 'selected' : ''}>${esc(p.name)}</option>`).join('')}</select>
                <button class="pt-iconbtn" data-act="bossNearby" title="تحديث">${I('refresh', 16, 2)}</button>
                <select class="pt-in" data-model="boss.inv.grade"><option value="">اختر الرتبة…</option>${lower.map((g) => `<option value="${g.grade}" ${String(inv.grade) === String(g.grade) ? 'selected' : ''}>${esc(g.name)}</option>`).join('')}</select>
                <button class="pt-btn green sm" data-act="bossInvite">${I('mail', 15, 2)} دعوة</button>
            </div>
            <p class="pt-hint">الشخص لازم يكون واقفًا بجانبك (8 أمتار)، وتصله رسالة يوافق عليها.</p>
            <div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>الاسم</th><th>الرتبة</th><th>آخر ظهور</th><th>ساعات هذا الأسبوع</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>${rows}</tbody></table></div>`;
    }

    function rolesView() {
        const r = B().roles;
        if (!r) return loading;
        const e = B().edit;
        const rows = PT.list(r.grades).map((g) => {
            const locked = g.boss || g.grade >= r.myGrade;
            if (e && e.grade === g.grade) {
                return `<tr class="edit"><td class="ltr">${g.grade}</td>
                    <td><input class="pt-in sm" data-model="boss.edit.name" maxlength="24" value="${esc(e.name)}"></td>
                    <td><input class="pt-in sm ltr" inputmode="numeric" data-model="boss.edit.payment" data-enter="bossRoleSave" value="${esc(e.payment)}"></td>
                    <td class="ltr">${r.interval}</td>
                    <td class="pt-acts"><button class="pt-mini green" data-act="bossRoleSave">${I('check', 13, 2.4)} حفظ</button><button class="pt-mini" data-act="bossRoleCancel">إلغاء</button></td></tr>`;
            }
            return `<tr class="${locked ? 'locked' : ''}"><td class="ltr">${g.grade}</td><td>${esc(g.name)}${g.boss ? ' <em class="pt-tag amber">قائد</em>' : ''}</td><td class="ltr">$${g.payment}</td><td class="ltr">${r.interval}</td>
                <td class="pt-acts"><button class="pt-mini green" data-act="bossRoleEdit" data-g="${g.grade}" ${locked ? 'disabled' : ''}>${I('edit', 13, 2)} تعديل</button></td></tr>`;
        }).join('');
        return `<h2 class="pt-bh">الرتب</h2>
            <div class="pt-tablewrap"><table class="pt-table"><thead><tr><th>الدرجة</th><th>اسم الرتبة</th><th>الراتب ($)</th><th>كل (دقيقة)</th><th>إجراءات</th></tr></thead><tbody>${rows}</tbody></table></div>
            <p class="pt-hint">الراتب يُدفع كل ${r.interval} دقائق لمن في الخدمة (حد أقصى $${S.cfg.salaryMax || 1000}). رتبة رتبة المدير وما فوق رتبتك لا تتغير من هنا. إضافة رتب جديدة أو حذفها تتم من ملف الوظائف في السيرفر.</p>`;
    }

    function logsView() {
        const b = B();
        const q = (b.q || '').trim().toLowerCase();
        const rows = PT.list(b.logs).filter((r) => !q || [r.name, actionLabel(r.action), r.content].some((v) => String(v || '').toLowerCase().includes(q)));
        return `<div class="pt-logtop"><h2 class="pt-bh">السجل</h2>
                <div class="pt-logf">
                    <label><span>من</span><input class="pt-in sm ltr" type="date" data-model="boss.from" value="${esc(b.from)}"></label>
                    <label><span>إلى</span><input class="pt-in sm ltr" type="date" data-model="boss.to" value="${esc(b.to)}"></label>
                    <button class="pt-btn ghost xs ${b.sal ? 'on' : ''}" data-act="bossLogsSal" title="الرواتب كثيرة، لذلك هي مخفية">${b.sal ? 'إخفاء الرواتب' : 'إظهار الرواتب'}</button>
                    <button class="pt-btn ghost xs" data-act="bossLogsLoad">عرض</button>
                    <div class="pt-search sm">${I('search', 14, 2)}<input class="pt-in bare" data-model="boss.q" data-live="1" value="${esc(b.q)}" placeholder="بحث"></div>
                </div></div>
            <div class="pt-tablewrap">${b.logs == null ? loading : rows.length ? `<table class="pt-table"><thead><tr><th>الوقت</th><th>الاسم</th><th>الإجراء</th><th>التفاصيل</th></tr></thead><tbody>
                ${rows.map((r) => `<tr><td class="ltr">${esc(fmtStamp(r.at))}</td><td>${esc(r.name || 'النظام')}</td><td><em class="pt-tag ${r.action === 'fired' ? 'red' : r.action === 'hired' || r.action === 'promoted' ? 'green' : 'grey'}">${esc(actionLabel(r.action))}</em></td>
                <td>${esc(r.content || '')}${r.amount ? ` <bdi class="ltr pt-mute">${money(r.amount)}</bdi>` : ''}</td></tr>`).join('')}
            </tbody></table>` : '<p class="pt-mute pad">لا يوجد شيء في هذه الفترة.</p>'}</div>`;
    }

    function billingView() {
        return `<h2 class="pt-bh">قوالب الفواتير <small>الخدمات التي يختار منها الميكانيكي عند كتابة الفاتورة، بسعرها</small></h2>
            ${PT.offencesEditor ? PT.offencesEditor.table() : ''}`;
    }

    function view() {
        const isBoss = S.me && S.me.isBoss;
        const bal = balanceNow();
        const meta = PT.metaBox('الرصيد', bal == null ? '—' : money(bal));
        if (!isBoss) {
            return `<div class="pt-appwin">${PT.head('لوحة المدير', 'الإدارة')}<div class="pt-abody"><div class="pt-empty big">
                <i class="pt-ic dark lg">${I('lock', 34, 1.8)}</i><h3>لمدير الورشة فقط</h3><p>هذا القسم يظهر لمن عنده رتبة المدير.</p></div></div></div>`;
        }
        const b = B();
        const page = { dash: dashView, flow: flowView, funds: fundsView, billing: billingView, members: membersView, roles: rolesView, logs: logsView }[b.tab] || dashView;
        return `<div class="pt-appwin">${PT.head('لوحة المدير', 'الإدارة', meta)}
            <div class="pt-abody pt-boss">
                <nav class="pt-bnav">${TABS.map(([id, label, icon]) => `<button class="${b.tab === id ? 'on' : ''}" data-act="bossTab" data-t="${id}">${I(icon, 17, 1.9)}<span>${esc(label)}</span></button>`).join('')}</nav>
                <div class="pt-bmain" data-scroll="boss-${b.tab}">${page()}</div>
            </div></div>`;
    }

    // ------------------------------------------------------------------
    // loading each page
    // ------------------------------------------------------------------
    function load(tab) {
        const b = B();
        const done = (key) => (res) => {
            if (res.ok) b[key] = res.r; else fail(res);
            render();
        };
        if (tab === 'dash') call('bossDashboard').then(done('dash'));
        else if (tab === 'flow') call('bossCashFlow').then(done('flow'));
        else if (tab === 'funds') call('bossFunds').then(done('funds'));
        else if (tab === 'members') { call('bossMembers').then(done('members')); nearby(); }
        else if (tab === 'roles') call('bossRoles').then(done('roles'));
        else if (tab === 'billing') { if (PT.offencesEditor) { S.off.q = ''; S.off.cat = 'all'; S.off.edit = null; PT.offencesEditor.load(); } }
        else if (tab === 'logs') loadLogs();
    }
    function nearby() {
        call('bossNearby').then((res) => {
            if (res.ok) {
                B().nearby = PT.list(res.r);
                if (!B().nearby.some((p) => String(p.id) === String(B().inv.target))) B().inv.target = '';
                render();
            }
        });
    }
    function loadLogs() {
        const b = B();
        const from = b.from ? Math.floor(new Date(`${b.from}T00:00`).getTime() / 1000) : null;
        const to = b.to ? Math.floor(new Date(`${b.to}T00:00`).getTime() / 1000) + 86400 : null;
        b.logs = null;
        render();
        call('bossLogs', from || 0, to || 0, !!b.sal).then((res) => {
            b.logs = res.ok ? PT.list(res.r) : [];
            if (!res.ok) fail(res);
            render();
        });
    }
    const amountOf = (v) => {
        const n = Number(String(v || '').replace(/[^\d]/g, ''));
        return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
    };
    const nameOf = (cid) => {
        const x = B().members && PT.list(B().members.members).find((m) => m.cid === cid);
        return x ? x.name : cid;
    };

    PT.app('boss', {
        view,
        enter() {
            const b = B();
            b.edit = null;
            b.q = '';
            b.from = iso(PT.now() - 7 * 86400);
            b.to = iso(PT.now());
            if (S.me && S.me.isBoss) { load(b.tab); if (b.tab !== 'dash' && b.tab !== 'funds') call('bossDashboard').then((res) => { if (res.ok) { b.dash = res.r; render(); } }); }
        },
        act: {
            ...((PT.offencesEditor && PT.offencesEditor.act) || {}),
            bossTab: (el) => { B().tab = el.dataset.t; B().edit = null; render(); load(B().tab); },
            bossNearby: () => nearby(),
            bossDeposit: () => {
                const n = amountOf(B().dep);
                if (!n) return toast(PT.ERR.amount, 'error');
                ask({ title: `إيداع ${money(n)}؟`, text: 'من حسابك البنكي إلى حساب الورشة.', ok: 'إيداع' }, () => {
                    call('bossDeposit', n).then((res) => {
                        if (!res.ok) return fail(res);
                        B().dep = '';
                        toast(`تم إيداع ${money(n)}`);
                        load('funds');
                    });
                });
            },
            bossWithdraw: () => {
                const n = amountOf(B().wd);
                if (!n) return toast(PT.ERR.amount, 'error');
                ask({ title: `سحب ${money(n)}؟`, text: 'من حساب الورشة إلى حسابك البنكي. يظهر في السجل.', ok: 'سحب' }, () => {
                    call('bossWithdraw', n).then((res) => {
                        if (!res.ok) return fail(res);
                        B().wd = '';
                        toast(`تم سحب ${money(n)}`);
                        load('funds');
                    });
                });
            },
            bossInvite: () => {
                const inv = B().inv;
                if (!inv.target) return toast('اختر الشخص أولًا (لازم يكون بجانبك)', 'error');
                if (inv.grade === '') return toast('اختر الرتبة', 'error');
                call('bossInvite', Number(inv.target), Number(inv.grade)).then((res) => {
                    if (!res.ok) return fail(res);
                    toast('أُرسلت الدعوة، بانتظار موافقته');
                    B().inv = { target: '', grade: '' };
                    render();
                });
            },
            bossBonus: (el) => {
                const cid = el.dataset.cid;
                ask({ title: `مكافأة لـ ${nameOf(cid)}`, text: `من حساب الورشة إلى حسابه البنكي (حد أقصى ${money(S.cfg.bonusMax)}).`, ok: 'إرسال المكافأة',
                    input: { label: 'المبلغ ($)', placeholder: '500', type: 'number', ltr: true, max: 9 } }, (value) => {
                    const n = amountOf(value);
                    if (!n) return toast(PT.ERR.amount, 'error');
                    call('bossBonus', cid, n).then((res) => {
                        if (!res.ok) return fail(res);
                        toast(`أُرسلت مكافأة ${money(n)}`);
                        load('members');
                    });
                });
            },
            bossGrade: (el) => {
                const cid = el.dataset.cid;
                const g = Number(el.dataset.g);
                const grades = PT.list(B().members && B().members.grades);
                const to = grades.find((x) => x.grade === g);
                const cur = PT.list(B().members.members).find((m) => m.cid === cid);
                const up = cur && g > cur.grade;
                ask({ title: `${up ? 'ترقية' : 'تخفيض'} ${nameOf(cid)}؟`, text: `الرتبة الجديدة: ${to ? to.name : g}`, ok: up ? 'ترقية' : 'تخفيض', danger: !up }, () => {
                    call('bossSetGrade', cid, g).then((res) => {
                        if (!res.ok) return fail(res);
                        toast('تم تغيير الرتبة');
                        load('members');
                    });
                });
            },
            bossFire: (el) => {
                const cid = el.dataset.cid;
                ask({ title: `فصل ${nameOf(cid)}؟`, text: 'يخرج من الورشة فورًا ويرجع عاطلًا عن العمل. يُسجَّل في السجل.', ok: 'فصل', danger: true }, () => {
                    call('bossFire', cid).then((res) => {
                        if (!res.ok) return fail(res);
                        toast('تم الفصل');
                        load('members');
                    });
                });
            },
            bossRoleEdit: (el) => {
                const g = Number(el.dataset.g);
                const r = PT.list(B().roles && B().roles.grades).find((x) => x.grade === g);
                if (r) { B().edit = { grade: g, name: r.name, payment: String(r.payment) }; render(); }
            },
            bossRoleCancel: () => { B().edit = null; render(); },
            bossRoleSave: () => {
                const e = B().edit;
                if (!e) return;
                const pay = Number(String(e.payment).replace(/[^\d]/g, ''));
                if (!Number.isFinite(pay) || pay > (S.cfg.salaryMax || 1000)) return toast(`الراتب من 0 إلى ${money(S.cfg.salaryMax || 1000)}`, 'error');
                if ((e.name || '').trim().length < 2) return toast(PT.ERR.name, 'error');
                call('bossRoleSave', e.grade, e.name.trim(), Math.floor(pay)).then((res) => {
                    if (!res.ok) return fail(res);
                    B().roles = res.r;
                    B().edit = null;
                    toast('حُفظت الرتبة');
                });
            },
            bossLogsLoad: () => loadLogs(),
            bossLogsSal: () => { B().sal = !B().sal; loadLogs(); },
        },
    });
})();
