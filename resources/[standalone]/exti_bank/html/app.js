// EX_Tii Bank — tablet (bank branch) + ATM
(() => {
    const $ = (id) => document.getElementById(id);
    const inGame = typeof GetParentResourceName === 'function';
    const resource = inGame ? GetParentResourceName() : 'exti_bank';

    const ERRORS = {
        amount: (s) => `أدخل مبلغًا صحيحًا (من ${iso('$' + fmtNum(s.limits.min))} إلى ${iso('$' + fmtNum(s.limits.max))})`,
        no_cash: () => 'لا يوجد معك نقد كافٍ',
        no_bank: () => 'رصيد حسابك لا يكفي',
        not_found: () => 'لا يوجد مواطن بهذا الرقم في المدينة الآن',
        self: () => 'لا يمكنك التحويل إلى نفسك',
        busy: () => 'لحظة… جارٍ تنفيذ العملية السابقة',
        cooldown: () => 'لحظة… جارٍ تنفيذ العملية السابقة',
        too_far: () => 'ابتعدت عن موظف البنك',
        too_far_atm: () => 'ابتعدت عن الصراف',
        no_bill: () => 'هذه الفاتورة لم تعد موجودة (ربما دُفعت)',
        no_room: () => 'لا توجد مساحة في حقيبتك لاستلام النقد',
        closed: () => 'انتهت الجلسة، افتح البنك من جديد',
        failed: () => 'حدث خطأ، حاول مرة أخرى',
    };

    let state = null; // { kind, name, account, cash, bank, history, limits, branch }

    const fmtNum = (n) => Math.max(0, Math.floor(n || 0)).toLocaleString('en-US');
    const money = (n) => (Math.floor(n || 0) < 0 ? '−$' : '$') + fmtNum(Math.abs(Math.floor(n || 0))); // a bank can be in the minus
    const iso = (text) => `\u2066${text}\u2069`; // keeps "$1,000" the right way round inside Arabic text
    const digitsOnly = (v) => String(v || '').replace(/[^\d]/g, '').slice(0, 9);

    function post(name, data) {
        if (!inGame) return Promise.resolve(preview(name, data));
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false, code: 'failed' }));
    }

    function errorText(code) {
        return (ERRORS[code] || ERRORS.failed)(state || { limits: { min: 1, max: 0 } });
    }

    function toastIn(id, text, type) {
        const t = $(id);
        t.textContent = text;
        t.className = `kit-toast show ${type || ''}`;
        clearTimeout(t._timer);
        t._timer = setTimeout(() => { t.className = 'kit-toast'; }, 3000);
    }

    // ---------- dates ----------
    const DAY = 86400000;
    function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x.getTime(); }
    function dayLabel(ms) {
        const today = startOfDay(Date.now());
        const d = startOfDay(ms);
        if (d === today) return 'اليوم';
        if (d === today - DAY) return 'أمس';
        const x = new Date(ms);
        return `${x.getDate()}/${x.getMonth() + 1}/${x.getFullYear()}`;
    }
    function timeLabel(ms) {
        const x = new Date(ms);
        return `${String(x.getHours()).padStart(2, '0')}:${String(x.getMinutes()).padStart(2, '0')}`;
    }

    // ---------- transactions ----------
    function txRow(t) {
        const row = document.createElement('div');
        row.className = 'tx';
        const inc = t.dir === 'in';
        const icon = document.createElement('div');
        icon.className = `tx-icon ${inc ? 'in' : 'out'}`;
        icon.textContent = inc ? '↓' : '↑';
        const text = document.createElement('div');
        text.className = 'tx-text';
        const title = document.createElement('div');
        title.className = 'tx-title';
        title.textContent = t.title || 'عملية';
        const sub = document.createElement('div');
        sub.className = 'tx-sub';
        const bits = [timeLabel((t.time || 0) * 1000)];
        if (t.note) bits.push(t.note);
        sub.textContent = bits.join(' · ');
        text.append(title, sub);
        const amount = document.createElement('div');
        amount.className = `tx-amount ${inc ? 'pos' : 'neg'}`;
        amount.dir = 'ltr';
        amount.textContent = `${inc ? '+' : '−'}${money(t.amount)}`;
        row.append(icon, text, amount);
        return row;
    }

    function renderList(el, list, grouped) {
        el.innerHTML = '';
        if (!list.length) {
            el.innerHTML = '<div class="empty">لا توجد عمليات بعد</div>';
            return;
        }
        let lastDay = null;
        list.forEach((t, i) => {
            if (grouped) {
                const label = dayLabel((t.time || 0) * 1000);
                if (label !== lastDay) {
                    const h = document.createElement('div');
                    h.className = 'tx-day';
                    h.textContent = label;
                    el.appendChild(h);
                    lastDay = label;
                }
            }
            const row = txRow(t);
            row.style.animationDelay = `${Math.min(i, 12) * 25}ms`;
            el.appendChild(row);
        });
    }

    // ---------- tablet ----------
    let page = 'home';
    let cashMode = 'deposit';
    let histFilter = 'all';
    let recipient = null; // { id, name, account }

    function go(name) {
        page = name;
        document.querySelectorAll('.page').forEach((p) => p.classList.toggle('active', p.id === `page-${name}`));
        document.querySelectorAll('#nav button').forEach((b) => b.classList.toggle('active', b.dataset.page === name));
        if (name === 'cash') renderCash();
        if (name === 'transfer') renderTransfer();
        if (name === 'history') renderHistory();
        if (name === 'bills') renderBills();
        post('sound', { name: 'key' });
    }

    function renderWeek() {
        const today = startOfDay(Date.now());
        const days = [];
        for (let i = 6; i >= 0; i--) days.push({ start: today - i * DAY, net: 0 });
        let tin = 0, tout = 0;
        (state.history || []).forEach((t) => {
            const ms = (t.time || 0) * 1000;
            const d = days.find((x) => ms >= x.start && ms < x.start + DAY);
            if (!d) return;
            if (t.dir === 'in') { tin += t.amount; d.net += t.amount; } else { tout += t.amount; d.net -= t.amount; }
        });
        $('weekIn').textContent = `+${money(tin)}`;
        $('weekOut').textContent = `−${money(tout)}`;
        const max = Math.max(1, ...days.map((d) => Math.abs(d.net)));
        const names = ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];
        const bars = $('bars');
        bars.innerHTML = '';
        days.forEach((d) => {
            const b = document.createElement('div');
            b.className = 'bar';
            const i = document.createElement('i');
            if (d.net < 0) i.className = 'neg';
            i.style.height = '3px';
            const s = document.createElement('span');
            s.textContent = names[new Date(d.start).getDay()];
            b.append(i, s);
            bars.appendChild(b);
            requestAnimationFrame(() => { i.style.height = `${Math.max(3, (Math.abs(d.net) / max) * 72)}px`; });
        });
    }

    function renderTablet() {
        const first = (state.name || 'م').trim().charAt(0);
        $('avatar').textContent = first;
        $('meName').textContent = state.name;
        $('meAccount').textContent = state.account;
        $('branch').textContent = state.branch ? `فرع ${state.branch}` : 'الخدمات المصرفية';
        $('hello').textContent = `أهلًا، ${state.name.split(' ')[0]}`;
        const now = new Date();
        $('today').textContent = `${now.getDate()}/${now.getMonth() + 1}/${now.getFullYear()} · ${timeLabel(now.getTime())}`;
        $('total').textContent = money(state.cash + state.bank);
        $('cash').textContent = money(state.cash);
        $('bank').textContent = money(state.bank);
        $('cvName').textContent = state.name;
        $('cvAccount').textContent = state.account.replace(/^(EX-)(.*)(.{4})$/, (_, a, b, c) => `${a}${'•'.repeat(Math.min(6, b.length))}${c}`);
        renderWeek();
        renderList($('recent'), (state.history || []).slice(0, 4), false);
        renderDue();
        if (page === 'cash') renderCash();
        if (page === 'transfer') renderTransfer();
        if (page === 'history') renderHistory();
        if (page === 'bills') renderBills();
    }

    // ---------- bills (police fines...) ----------
    const bills = () => (Array.isArray(state && state.bills) ? state.bills : []);
    const unpaid = () => bills().filter((b) => !b.paid);
    const billsSum = () => unpaid().reduce((s, b) => s + (Number(b.amount) || 0), 0);
    const BILL_ICON = {
        fine: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l8 4v5c0 5-3.5 8.5-8 9-4.5-.5-8-4-8-9V7z"/><path d="M9.5 12l1.8 1.8L15 10"/></svg>',
        hospital: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.5"/><path d="M12 9v6M9 12h6"/></svg>',
        bill: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/></svg>',
    };
    const billDate = (b) => { const ms = (b.created || 0) * 1000; return `${dayLabel(ms)} ${timeLabel(ms)}`; };
    const billWho = (b) => [b.issuer, billDate(b)].filter(Boolean).join(' · ');

    function renderDue() {
        const n = unpaid().length;
        const badge = $('billsBadge');
        badge.textContent = n ? String(n) : '';
        badge.classList.toggle('show', n > 0);
        $('due').classList.toggle('hidden', n === 0);
        if (n) {
            $('dueTitle').textContent = n === 1 ? 'لديك فاتورة غير مدفوعة' : `لديك ${n} فواتير غير مدفوعة`;
            $('dueSub').textContent = `المجموع ${iso(money(billsSum()))} · ادفعها من حسابك أو نقدًا`;
        }
    }

    function renderBills() {
        const list = unpaid();
        const el = $('bills');
        $('billsTotal').textContent = list.length ? `المجموع ${iso(money(billsSum()))}` : '';
        el.innerHTML = '';
        if (!list.length) {
            el.innerHTML = '<div class="empty"><div class="ok-mark"><svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg></div><b>لا توجد فواتير عليك</b>كل شيء مدفوع</div>';
            return;
        }
        list.forEach((b, i) => {
            const row = document.createElement('div');
            row.className = 'bill';
            row.style.animationDelay = `${Math.min(i, 12) * 25}ms`;
            const icon = document.createElement('div');
            const tone = b.society === 'police' || b.kind === 'fine' ? 'police' : b.society === 'ambulance' ? 'hospital' : '';
            icon.className = `bill-icon ${tone}`;
            icon.innerHTML = BILL_ICON[b.kind] || BILL_ICON.bill;
            const text = document.createElement('div');
            text.className = 'bill-text';
            const title = document.createElement('div'); title.className = 'bill-title'; title.textContent = b.title || 'فاتورة';
            const sub = document.createElement('div'); sub.className = 'bill-sub'; sub.textContent = billWho(b);
            text.append(title, sub);
            if (b.note) { const note = document.createElement('div'); note.className = 'bill-note'; note.textContent = b.note; text.appendChild(note); }
            const end = document.createElement('div');
            end.className = 'bill-end';
            const amount = document.createElement('div'); amount.className = 'bill-amount'; amount.dir = 'ltr'; amount.textContent = money(b.amount);
            const pay = document.createElement('div'); pay.className = 'bill-pay';
            const fromBank = document.createElement('button'); fromBank.className = 'kit-btn primary'; fromBank.textContent = 'ادفع من الحساب';
            fromBank.disabled = state.bank < b.amount;
            fromBank.onclick = () => payBill(b, 'bank');
            const fromCash = document.createElement('button'); fromCash.className = 'kit-btn'; fromCash.textContent = 'ادفع نقدًا';
            fromCash.disabled = state.cash < b.amount;
            fromCash.onclick = () => payBill(b, 'cash');
            pay.append(fromBank, fromCash);
            end.append(amount, pay);
            row.append(icon, text, end);
            el.appendChild(row);
        });
    }

    function payBill(b, account) {
        const safe = document.createElement('b'); safe.textContent = b.title || 'فاتورة';
        const left = account === 'bank' ? state.bank - b.amount : state.cash - b.amount;
        ask('دفع الفاتورة', `ستدفع <b dir="ltr">${money(b.amount)}</b> ${account === 'bank' ? 'من حسابك' : 'نقدًا'} عن ${safe.outerHTML}<br>${account === 'bank' ? 'رصيدك بعد الدفع' : 'النقد معك بعد الدفع'}: <b dir="ltr">${money(left)}</b>`, async () => {
            closeSheet();
            const res = await run('paybill', { id: b.id, account });
            if (!res) return;
            if (Array.isArray(res.bills)) state.bills = res.bills;
            renderTablet();
            done('تم الدفع', `${iso(money(b.amount))} · ${b.title || 'فاتورة'}`);
        });
    }

    // deposit / withdraw
    function renderCash() {
        document.querySelectorAll('#cashSeg button').forEach((b) => b.classList.toggle('active', b.dataset.mode === cashMode));
        const dep = cashMode === 'deposit';
        $('cashLabel').textContent = dep ? 'المبلغ المراد إيداعه' : 'المبلغ المراد سحبه';
        $('cashGo').textContent = dep ? 'إيداع' : 'سحب';
        const avail = dep ? state.cash : state.bank;
        $('cashAvail').innerHTML = `${dep ? 'النقد معك' : 'رصيد الحساب'}: <b dir="ltr">${money(avail)}</b>`;
        const chips = $('cashChips');
        chips.innerHTML = '';
        [100, 500, 1000, 5000].forEach((v) => {
            const b = document.createElement('button');
            b.textContent = money(v);
            b.onclick = () => { $('cashAmount').value = fmtNum(v); };
            chips.appendChild(b);
        });
        const all = document.createElement('button');
        all.textContent = 'الكل';
        all.onclick = () => { $('cashAmount').value = fmtNum(Math.min(avail, state.limits.max)); };
        chips.appendChild(all);
    }

    // transfer
    function renderTransfer() {
        $('trAvail').innerHTML = `رصيد الحساب: <b dir="ltr">${money(state.bank)}</b>`;
        $('stepHow').classList.toggle('disabled', !recipient);
    }

    function showWho(ok, title, sub) {
        const who = $('trWho');
        who.className = `who show ${ok ? '' : 'bad'}`;
        who.innerHTML = '';
        const av = document.createElement('div');
        av.className = 'avatar';
        av.textContent = ok ? title.trim().charAt(0) : '!';
        const box = document.createElement('div');
        const b = document.createElement('b');
        b.textContent = title;
        const s = document.createElement('small');
        s.textContent = sub;
        box.append(b, s);
        who.append(av, box);
    }

    async function checkRecipient() {
        const id = parseInt(digitsOnly($('trId').value), 10);
        recipient = null;
        renderTransfer();
        if (!id) return showWho(false, 'أدخل رقم المواطن', 'رقم الـ ID الذي يظهر فوق رأسه أو في قائمة اللاعبين');
        const res = await post('lookup', { id });
        if (!res) return showWho(false, 'غير موجود', 'لا يوجد مواطن بهذا الرقم في المدينة الآن');
        if (res.self) return showWho(false, 'هذا أنت', 'لا يمكنك التحويل إلى نفسك');
        recipient = { id, name: res.name, account: res.account };
        showWho(true, res.name, `${res.account} · رقم ${id}`);
        renderTransfer();
        $('trAmount').focus();
    }

    // confirm sheet
    let sheetYes = null;
    function ask(title, html, onYes) {
        $('sheetTitle').textContent = title;
        $('sheetText').innerHTML = html;
        sheetYes = onYes;
        $('sheet').classList.add('show');
    }
    function closeSheet() { $('sheet').classList.remove('show'); sheetYes = null; }

    function done(title, text) {
        $('doneTitle').textContent = title;
        $('doneText').textContent = text;
        const d = $('done');
        d.classList.add('show');
        setTimeout(() => d.classList.remove('show'), 1700);
    }

    let working = false;
    async function run(action, data) {
        if (working) return null;
        working = true;
        const res = await post('action', Object.assign({ action }, data));
        working = false;
        if (res && res.ok) {
            state.cash = res.cash;
            state.bank = res.bank;
            if (res.history) state.history = res.history;
            if (Array.isArray(res.bills)) state.bills = res.bills;
            return res;
        }
        const msg = errorText(res && res.code);
        if (state.kind === 'atm') atmError(msg); else toastIn('toast', msg, 'error');
        return null;
    }

    async function cashGo() {
        const amount = parseInt(digitsOnly($('cashAmount').value), 10);
        if (!amount) return toastIn('toast', errorText('amount'), 'error');
        const res = await run(cashMode, { amount });
        if (!res) return;
        $('cashAmount').value = '';
        renderTablet();
        done(cashMode === 'deposit' ? 'تم الإيداع' : 'تم السحب', `${iso(money(amount))} ${cashMode === 'deposit' ? 'أُضيفت إلى حسابك' : 'أصبحت نقدًا معك'}`);
    }

    function transferGo() {
        if (!recipient) return;
        const amount = parseInt(digitsOnly($('trAmount').value), 10);
        if (!amount) return toastIn('toast', errorText('amount'), 'error');
        if (amount > state.bank) return toastIn('toast', errorText('no_bank'), 'error');
        const note = $('trNote').value.trim();
        const safeName = document.createElement('b');
        safeName.textContent = recipient.name;
        ask('تأكيد التحويل', `ستحوّل <b dir="ltr">${money(amount)}</b> إلى ${safeName.outerHTML}<br>رصيدك بعد التحويل: <b dir="ltr">${money(state.bank - amount)}</b>`, async () => {
            closeSheet();
            const res = await run('transfer', { amount, target: recipient.id, note, account: recipient.account });
            if (!res) return;
            const name = recipient.name;
            $('trAmount').value = '';
            $('trNote').value = '';
            renderTablet();
            done('تم التحويل', `${iso(money(amount))} إلى ${name}`);
        });
    }

    function renderHistory() {
        const q = $('histSearch').value.trim().toLowerCase();
        const list = (state.history || []).filter((t) => {
            if (histFilter !== 'all' && t.dir !== histFilter) return false;
            if (!q) return true;
            return [t.title, t.note, t.from, t.to, String(t.amount)].some((v) => String(v || '').toLowerCase().includes(q));
        });
        renderList($('history'), list, true);
    }

    // ---------- ATM ----------
    let atmMode = 'withdraw';
    let atmValue = '';

    function renderAtm() {
        $('atmName').textContent = state.name.split(' ')[0];
        $('atmBank').textContent = money(state.bank);
        $('atmCash').textContent = money(state.cash);
        $('atmAmount').textContent = fmtNum(parseInt(atmValue || '0', 10));
        document.querySelectorAll('#atmTabs button').forEach((b) => b.classList.toggle('active', b.dataset.mode === atmMode));
        const n = unpaid().length;
        $('atmBadge').textContent = n ? String(n) : '';
        $('atmBadge').classList.toggle('show', n > 0);
        document.querySelector('.atm').classList.toggle('bills', atmMode === 'bills');
        $('atmGo').textContent = atmMode === 'withdraw' ? 'سحب' : atmMode === 'deposit' ? 'إيداع' : 'تأكيد';
        $('atmGo').disabled = atmMode === 'bills';
        const note = $('atmNote');
        note.className = 'atm-note';
        if (atmMode === 'bills') {
            note.textContent = n ? `المجموع ${iso(money(billsSum()))} · الدفع من حسابك البنكي` : 'لا توجد فواتير عليك';
            renderAtmBills();
        } else {
            note.textContent = `الحد الأقصى في الصراف ${iso(money(state.limits.max))} · المبالغ الأكبر في فروع البنك`;
        }
    }

    function renderAtmBills() {
        const el = $('atmBills');
        el.innerHTML = '';
        const list = unpaid();
        if (!list.length) { el.innerHTML = '<div class="empty">كل شيء مدفوع ✓</div>'; return; }
        list.forEach((b) => {
            const row = document.createElement('div');
            row.className = 'atm-bill';
            const text = document.createElement('div');
            const title = document.createElement('b'); title.textContent = b.title || 'فاتورة';
            const sub = document.createElement('small'); sub.textContent = billWho(b);
            text.append(title, sub);
            const r = document.createElement('div'); r.className = 'r';
            const amt = document.createElement('span'); amt.className = 'amt'; amt.dir = 'ltr'; amt.textContent = money(b.amount);
            const btn = document.createElement('button'); btn.textContent = 'ادفع';
            btn.disabled = state.bank < b.amount;
            btn.onclick = async () => {
                btn.disabled = true;
                const res = await run('paybill', { id: b.id, account: 'bank' });
                if (!res) { renderAtm(); return; }
                if (Array.isArray(res.bills)) state.bills = res.bills;
                renderAtm();
                post('sound', { name: 'key' });
                toastIn('atmToast', `تم دفع ${iso(money(b.amount))} · ${b.title || 'فاتورة'}`, 'success');
            };
            r.append(amt, btn);
            row.append(text, r);
            el.appendChild(row);
        });
    }

    function atmError(msg) {
        const n = $('atmNote');
        n.className = 'atm-note bad';
        n.textContent = msg;
        const a = document.querySelector('.atm-amount');
        a.classList.remove('shake'); void a.offsetWidth; a.classList.add('shake');
    }

    function buildAtm() {
        const pad = $('atmPad');
        pad.innerHTML = '';
        ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'].forEach((k) => {
            const b = document.createElement('button');
            b.textContent = k;
            if (k === 'C' || k === '⌫') b.className = 'fn';
            b.onclick = () => {
                if (k === 'C') atmValue = '';
                else if (k === '⌫') atmValue = atmValue.slice(0, -1);
                else if (atmValue.length < 7) atmValue = (atmValue + k).replace(/^0+/, '');
                post('sound', { name: 'key' });
                renderAtm();
            };
            pad.appendChild(b);
        });
        const quick = $('atmQuick');
        quick.innerHTML = '';
        [100, 500, 1000, 5000].forEach((v) => {
            const b = document.createElement('button');
            b.textContent = money(v);
            b.onclick = () => { atmValue = String(v); renderAtm(); };
            quick.appendChild(b);
        });
    }

    async function atmGo() {
        if (atmMode === 'bills') return;
        const amount = parseInt(atmValue || '0', 10);
        if (!amount) return atmError(errorText('amount'));
        const res = await run(atmMode, { amount });
        if (!res) return;
        atmValue = '';
        renderAtm();
        const slot = document.querySelector('.atm-slot');
        slot.classList.add('pay');
        setTimeout(() => slot.classList.remove('pay'), 1400);
        toastIn('atmToast', atmMode === 'withdraw' ? `خذ نقودك: ${iso(money(amount))}` : `تم إيداع ${iso(money(amount))}`, 'success');
    }

    // ---------- open / close ----------
    let closing = false;
    let closeTimer = null;
    function close(tellGame) {
        const shown = !$('tablet').classList.contains('hidden') ? $('tablet') : !$('atm').classList.contains('hidden') ? $('atm') : null;
        if (!shown || closing) return;
        closing = true;
        closeSheet();
        shown.classList.add('closing');
        closeTimer = setTimeout(() => { closeTimer = null; shown.classList.add('hidden'); shown.classList.remove('closing'); closing = false; }, 190);
        if (tellGame) post('close');
    }

    function open(data) {
        if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; } // a quick reopen must stay visible
        state = data;
        closing = false;
        if (data.kind === 'atm') {
            atmMode = 'withdraw';
            atmValue = '';
            $('tablet').classList.add('hidden');
            $('atm').classList.remove('hidden', 'closing');
            buildAtm();
            renderAtm();
            const tick = () => { const n = new Date(); $('atmClock').textContent = timeLabel(n.getTime()); };
            tick();
        } else {
            page = 'home';
            cashMode = 'deposit';
            histFilter = 'all';
            recipient = null;
            ['cashAmount', 'trId', 'trAmount', 'trNote', 'histSearch'].forEach((id) => { $(id).value = ''; });
            $('trWho').className = 'who';
            $('atm').classList.add('hidden');
            $('tablet').classList.remove('hidden', 'closing');
            document.querySelectorAll('.page').forEach((p) => p.classList.toggle('active', p.id === 'page-home'));
            document.querySelectorAll('#nav button').forEach((b) => b.classList.toggle('active', b.dataset.page === 'home'));
            renderTablet();
        }
    }

    // ---------- wiring ----------
    document.querySelectorAll('#nav button').forEach((b) => { b.onclick = () => go(b.dataset.page); });
    document.querySelectorAll('[data-go]').forEach((b) => {
        b.onclick = () => { if (b.dataset.mode) cashMode = b.dataset.mode; go(b.dataset.go); };
    });
    document.querySelectorAll('#cashSeg button').forEach((b) => { b.onclick = () => { cashMode = b.dataset.mode; renderCash(); }; });
    document.querySelectorAll('#histChips button').forEach((b) => {
        b.onclick = () => {
            histFilter = b.dataset.f;
            document.querySelectorAll('#histChips button').forEach((x) => x.classList.toggle('active', x === b));
            renderHistory();
        };
    });
    document.querySelectorAll('#atmTabs button').forEach((b) => { b.onclick = () => { atmMode = b.dataset.mode; renderAtm(); }; });

    const moneyInput = (el) => el.addEventListener('input', () => {
        const d = digitsOnly(el.value);
        el.value = d ? fmtNum(parseInt(d, 10)) : '';
    });
    moneyInput($('cashAmount'));
    moneyInput($('trAmount'));
    $('trId').addEventListener('input', () => { $('trId').value = digitsOnly($('trId').value).slice(0, 5); recipient = null; renderTransfer(); $('trWho').className = 'who'; });
    $('trId').addEventListener('keydown', (e) => { if (e.key === 'Enter') checkRecipient(); });
    $('cashAmount').addEventListener('keydown', (e) => { if (e.key === 'Enter') cashGo(); });
    $('histSearch').addEventListener('input', renderHistory);

    $('cashGo').onclick = cashGo;
    $('trCheck').onclick = checkRecipient;
    $('trGo').onclick = transferGo;
    $('sheetNo').onclick = closeSheet;
    $('sheetYes').onclick = () => { if (sheetYes) sheetYes(); };
    $('closeTablet').onclick = () => close(true);
    $('atmClose').onclick = () => close(true);
    $('atmGo').onclick = atmGo;

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if ($('sheet').classList.contains('show')) return closeSheet();
            close(true);
        }
        if (state && state.kind === 'atm' && !$('atm').classList.contains('hidden')) {
            if (/^\d$/.test(e.key) && atmValue.length < 7) { atmValue = (atmValue + e.key).replace(/^0+/, ''); renderAtm(); }
            else if (e.key === 'Backspace') { atmValue = atmValue.slice(0, -1); renderAtm(); }
            else if (e.key === 'Enter') atmGo();
        }
    });

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'open' && msg.data) open(msg.data);
        else if (msg.action === 'close') close(false);
        else if (msg.action === 'balance' && state) {
            if (typeof msg.cash === 'number') state.cash = msg.cash;
            if (typeof msg.bank === 'number') state.bank = msg.bank;
            if (Array.isArray(msg.history)) state.history = msg.history;
            if (Array.isArray(msg.bills)) state.bills = msg.bills;
            if (state.kind === 'atm') renderAtm(); else renderTablet();
        }
    });

    // ---------- browser preview (design check outside the game) ----------
    function preview(name, data) {
        if (name === 'lookup') return data.id === 7 ? { name: 'سارة الأحمد', account: 'EX-QX12AB34' } : (data.id === 1 ? { self: true } : false);
        if (name !== 'action') return true;
        const a = data.amount;
        if (data.action === 'deposit') { if (a > state.cash) return { ok: false, code: 'no_cash' }; state.cash -= a; state.bank += a; state.history.unshift({ title: 'إيداع نقدي', note: 'فرع ليجن سكوير', amount: a, dir: 'in', time: Date.now() / 1000 }); }
        if (data.action === 'withdraw') { if (a > state.bank) return { ok: false, code: 'no_bank' }; state.cash += a; state.bank -= a; state.history.unshift({ title: 'سحب نقدي', note: 'صراف آلي', amount: a, dir: 'out', time: Date.now() / 1000 }); }
        if (data.action === 'transfer') { state.bank -= a; state.history.unshift({ title: 'تحويل بنكي إلى سارة الأحمد', note: data.note, amount: a, dir: 'out', time: Date.now() / 1000 }); }
        if (data.action === 'paybill') {
            const b = (state.bills || []).find((x) => x.id === data.id);
            if (!b) return { ok: false, code: 'no_bill' };
            if (data.account === 'bank') { if (state.bank < b.amount) return { ok: false, code: 'no_bank' }; state.bank -= b.amount; } else { if (state.cash < b.amount) return { ok: false, code: 'no_cash' }; state.cash -= b.amount; }
            state.bills = state.bills.filter((x) => x.id !== b.id);
            state.history.unshift({ title: 'دفع فاتورة · ' + b.title, note: b.issuer, amount: b.amount, dir: 'out', time: Date.now() / 1000 });
            return { ok: true, cash: state.cash, bank: state.bank, history: state.history, bills: state.bills };
        }
        return { ok: true, cash: state.cash, bank: state.bank, history: state.history };
    }

    if (!inGame) {
        const p = new URLSearchParams(location.search);
        const now = Date.now() / 1000;
        const h = [
            { title: 'أجر · سحب مركبة معطلة', amount: 420, dir: 'in', time: now - 1800, note: '' },
            { title: 'مشتريات · بقالة 24/7', amount: 70, dir: 'out', time: now - 5000, note: '' },
            { title: 'رسوم ساحة الحجز', amount: 500, dir: 'out', time: now - 86400 - 3000, note: '' },
            { title: 'تحويل بنكي من خالد الزهراني', amount: 2500, dir: 'in', time: now - 86400 * 2, note: 'إيجار الشهر' },
            { title: 'شراء مركبة من المعرض', amount: 25000, dir: 'out', time: now - 86400 * 3, note: '' },
            { title: 'الراتب', amount: 1500, dir: 'in', time: now - 86400 * 4, note: '' },
            { title: 'أجر · جمع القمامة', amount: 640, dir: 'in', time: now - 86400 * 5, note: '' },
            { title: 'إيداع نقدي', amount: 3000, dir: 'in', time: now - 86400 * 6, note: 'صراف آلي' },
        ];
        document.body.style.background = 'radial-gradient(circle at 30% 20%, #3b4252, #12151b)';
        const bl = p.get('bills') === '0' ? [] : [
            { id: 3, kind: 'fine', title: 'غرامة: تجاوز السرعة، قطع إشارة حمراء', note: 'شارع فينوود، السيارة ABC 123', amount: 1500, issuer: 'الضابط خالد العمري', society: 'police', created: now - 3600 },
            { id: 2, kind: 'fine', title: 'غرامة: وقوف ممنوع', amount: 250, issuer: 'الضابط سارة الأحمد', society: 'police', created: now - 86400 * 2 },
        ];
        open({ kind: p.get('kind') || 'bank', name: 'محمد الهاشمي', account: 'EX-IQ7KLCTG', branch: 'ليجن سكوير', cash: 2350, bank: 22500, history: h, bills: bl, limits: { min: 1, max: p.get('kind') === 'atm' ? 10000 : 1000000 } });
        if (p.get('page')) go(p.get('page'));
    }
})();
