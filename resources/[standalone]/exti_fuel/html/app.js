// EX_Tii Fuel — the pump screen and the live pump card
(() => {
    const $ = (id) => document.getElementById(id);
    const app = $('app');
    const inGame = typeof GetParentResourceName === 'function';
    const resource = inGame ? GetParentResourceName() : 'exti_fuel';

    const ICONS = {
        pump: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 21V5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v16"/><path d="M3 21h13"/><path d="M6.5 7.5h6v4h-6z"/><path d="M15 9.5h1.6a1.6 1.6 0 0 1 1.6 1.6v5.4a1.5 1.5 0 0 0 3 0V8.3l-3-3"/></svg>',
        bolt: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2.5 4.5 13.5H11l-1 8 8.5-11H12z"/></svg>',
        drop: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.8s6.5 7.1 6.5 11.7a6.5 6.5 0 0 1-13 0C5.5 9.9 12 2.8 12 2.8Z"/><path d="M9 15a3 3 0 0 0 3 3"/></svg>',
        check: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg>',
    };

    const ERRORS = {
        no_money: 'المبلغ لا يكفي',
        too_far: 'ابتعدت عن المضخة، اقترب منها وحاول مرة أخرى',
        vehicle_far: 'المركبة بعيدة عن المضخة',
        vehicle_moving: 'أوقف المركبة أولًا',
        vehicle_busy: 'هذه المركبة تُعبّأ الآن',
        no_vehicle: 'لا توجد مركبة قرب المضخة',
        no_fuel: 'هذه المركبة لا تحتاج وقودًا',
        tank_full: 'الخزان ممتلئ',
        cant_carry: 'لا يوجد مكان كافٍ في حقيبتك (الجالون الممتلئ يزن 19 كغ)',
        busy: 'لحظة… جارٍ تنفيذ طلبك السابق',
        failed: 'حدث خطأ، حاول مرة أخرى',
    };

    const CIRC = 2 * Math.PI * 82;
    const money = (n) => '$' + Math.max(0, Math.round(n || 0)).toLocaleString('en-US');
    const one = (n) => (Math.max(0, n || 0)).toFixed(1);
    const iso = (s) => '\u2066' + s + '\u2069'; // numbers / money inside Arabic text keep their order

    function post(name, data) {
        if (!inGame) return Promise.resolve(previewAnswer(name, data));
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false, code: 'failed' }));
    }

    let toastTimer = null;
    function toast(text, kind) {
        const t = $('toast');
        t.textContent = text;
        t.className = 'kit-toast show ' + (kind || '');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { t.className = 'kit-toast'; }, 2600);
    }

    // ---------- the pump screen ----------
    let q = null;        // what the server said about this vehicle
    let target = 100;
    let paying = false;

    const unitWord = () => (q && q.electric ? 'ك.و.س' : 'لتر');
    const minTarget = () => Math.ceil(q.level + 1);
    // the same sums as the server
    const unitsFor = (t) => (t - q.level) / 100 * q.capacity;
    const costFor = (t) => Math.max(q.minPrice || 1, Math.ceil(unitsFor(t) * q.price));
    const secondsFor = (t) => Math.min(q.maxSeconds, Math.max(q.minSeconds, unitsFor(t) / q.rate));

    function bestFor(budget) {
        let best = null;
        for (let t = minTarget(); t <= 100; t++) { if (costFor(t) <= budget) best = t; else break; }
        return best;
    }

    function renderPresets() {
        const box = $('presets');
        box.innerHTML = '';
        const full = minTarget() <= 100;
        const items = [{ label: q.electric ? 'شحن كامل' : 'ملء الخزان', value: 100 }];
        [20, 50, 100].forEach((b) => {
            const t = full ? bestFor(b) : null;
            items.push({ label: money(b), value: t, off: !t || (t === 100 && costFor(100) < b) });
        });
        items.forEach((it) => {
            const b = document.createElement('button');
            b.className = 'kit-chip' + (it.value === target && !it.off ? ' active' : '');
            b.textContent = it.label;
            if (it.off || !full) b.disabled = true;
            b.onclick = () => { if (!b.disabled) setTarget(it.value); };
            box.appendChild(b);
        });
    }

    function setTarget(t) {
        target = Math.max(minTarget(), Math.min(100, Math.round(t)));
        render();
    }

    function render() {
        const full = minTarget() > 100;
        const from = Math.max(0, Math.min(100, q.level));
        const to = full ? from : target;

        $('gNow').style.strokeDasharray = `${CIRC * from / 100} ${CIRC}`;
        $('gAdd').style.strokeDasharray = `${CIRC * to / 100} ${CIRC}`;
        $('gTarget').textContent = Math.round(to) + '%';
        $('gFrom').textContent = full ? (q.electric ? 'البطارية مشحونة' : 'الخزان ممتلئ') : `الآن ${iso(Math.round(from) + '%')}`;

        const s = $('slider');
        s.min = 0; // the bar and the 0 / 50 / 100 marks match; setTarget keeps it above the current level
        s.max = 100;
        s.value = full ? 100 : to;
        s.disabled = full;
        s.style.setProperty('--from', from + '%');
        s.style.setProperty('--to', to + '%');

        const units = full ? 0 : unitsFor(to);
        const cost = full ? 0 : costFor(to);
        $('addText').textContent = full ? (q.electric ? 'البطارية مشحونة' : 'الخزان ممتلئ') : `${iso('+' + one(units))} ${unitWord()}`;
        $('targetText').textContent = Math.round(to) + '%';
        $('units').textContent = full ? '—' : `${one(units)} ${unitWord()}`;
        $('seconds').textContent = full ? '—' : `${Math.round(secondsFor(to))} ث`;
        $('total').textContent = full ? '—' : money(cost);

        const canCash = !full && q.cash >= cost;
        const canBank = !full && q.bank >= cost;
        $('payCash').disabled = paying || !canCash;
        $('payBank').disabled = paying || !canBank;
        $('purseCash').classList.toggle('low', !full && !canCash);
        $('purseBank').classList.toggle('low', !full && !canBank);
        $('payNote').textContent = full ? '' : (!canCash && !canBank ? 'المبلغ لا يكفي، اختر كمية أقل' : '');
        renderPresets();
        renderOffer();
    }

    // ---------- the jerry can offer on the pump screen ----------
    const offer = $('offer');
    let offerBuying = false;
    function renderOffer() {
        const o = q && q.can;
        offer.style.display = o && !q.electric ? '' : 'none';
        if (!o) return;
        $('offerPrice').textContent = money(o.price);
        $('offerFacts').textContent = `${iso(o.liters + ' لتر')} · ممتلئ · للطوارئ على الطريق`;
        $('offerCash').disabled = offerBuying || paying || q.cash < o.price;
        $('offerBank').disabled = offerBuying || paying || q.bank < o.price;
        offer.classList.toggle('busy', offerBuying);
    }
    async function buyOffer(account) {
        if (offerBuying || !q || !q.can) return;
        offerBuying = true;
        renderOffer();
        const res = await post('buyCan', { account });
        offerBuying = false;
        if (res && res.ok) {
            if (typeof res.cash === 'number') q.cash = res.cash;
            if (typeof res.bank === 'number') q.bank = res.bank;
            $('cash').textContent = money(q.cash);
            $('bank').textContent = money(q.bank);
            offer.classList.add('bought');
            setTimeout(() => offer.classList.remove('bought'), 1800);
            render();
        } else {
            renderOffer();
            toast(ERRORS[res && res.code] || ERRORS.failed, 'error');
        }
    }
    $('offerCash').onclick = () => buyOffer('cash');
    $('offerBank').onclick = () => buyOffer('bank');
    {
        const img = $('offerImg');
        img.onerror = () => { img.parentNode.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4h4l2 2h4a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M8 10l6 6M14 10l-6 6"/><path d="M15 4l3-1.5"/></svg>'; };
        if (inGame) img.src = 'nui://ox_inventory/web/images/WEAPON_PETROLCAN.png'; else img.onerror();
    }

    function open(data) {
        if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; }
        closing = false;
        q = data;
        paying = false;
        target = 100;
        const ev = !!q.electric;
        $('brandIcon').innerHTML = ev ? ICONS.bolt : ICONS.pump;
        $('title').textContent = ev ? 'شحن كهربائي' : 'محطة وقود';
        $('station').textContent = q.station || '';
        $('cash').textContent = money(q.cash);
        $('bank').textContent = money(q.bank);
        $('carName').textContent = (q.vehicle && q.vehicle.name) || '';
        $('carPlate').textContent = (q.vehicle && q.vehicle.plate) || '';
        $('carPlate').style.display = q.vehicle && q.vehicle.plate ? '' : 'none';
        $('gKind').textContent = ev ? 'كهربائية' : 'بنزين';
        $('capLabel').textContent = ev ? 'سعة البطارية' : 'سعة الخزان';
        $('capacity').textContent = `${q.capacity} ${unitWord()}`;
        $('unitPrice').textContent = `${money(q.price)} / ${unitWord()}`;
        $('amountTitle').textContent = ev ? 'كم تريد أن تشحن؟' : 'كم تريد أن تعبّئ؟';
        offer.classList.remove('bought', 'busy');
        offerBuying = false;
        app.classList.remove('hidden', 'closing');
        render();
    }

    let closing = false;
    let closeTimer = null;
    function close(tellGame) {
        if (app.classList.contains('hidden') || closing) return;
        closing = true;
        app.classList.add('closing');
        closeTimer = setTimeout(() => {
            closeTimer = null;
            app.classList.add('hidden');
            app.classList.remove('closing');
            closing = false;
        }, 170);
        if (tellGame) post('close');
    }

    async function pay(account) {
        if (paying || !q) return;
        paying = true;
        render();
        const res = await post('start', { target, account });
        paying = false;
        if (!res || !res.ok) {
            render();
            toast(ERRORS[res && res.code] || ERRORS.failed, 'error');
        }
    }

    $('slider').addEventListener('input', (e) => setTarget(Number(e.target.value)));
    $('closeBtn').onclick = () => close(true);
    $('payCash').onclick = () => pay('cash');
    $('payBank').onclick = () => pay('bank');

    // ---------- the jerry can card (pump with no car at it) ----------
    const canApp = $('canApp');
    const CAN_SVG = '<svg width="58" height="58" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4h4l2 2h4a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M8 10l6 6M14 10l-6 6"/><path d="M15 4l3-1.5"/></svg>';
    let can = null;
    let canBuying = false;
    let canTimer = null;
    let canToastTimer = null;

    function canToast(text) {
        const t = $('canToast');
        t.textContent = text;
        t.className = 'kit-toast show error';
        clearTimeout(canToastTimer);
        canToastTimer = setTimeout(() => { t.className = 'kit-toast'; }, 2600);
    }

    function renderCan() {
        $('canCash').textContent = money(can.cash);
        $('canBank').textContent = money(can.bank);
        $('canPrice').textContent = money(can.price);
        const okCash = can.cash >= can.price;
        const okBank = can.bank >= can.price;
        $('canPayCash').disabled = canBuying || !okCash;
        $('canPayBank').disabled = canBuying || !okBank;
        $('canPurseCash').classList.toggle('low', !okCash);
        $('canPurseBank').classList.toggle('low', !okBank);
    }

    function openCan(data) {
        clearTimeout(canTimer);
        can = data;
        canBuying = false;
        $('canIcon').innerHTML = ICONS.drop;
        $('canStation').textContent = data.station || '';
        $('canLiters').textContent = `ممتلئ · ${data.liters} لتر`;
        const img = $('canImg');
        img.onerror = () => { img.parentNode.innerHTML = CAN_SVG; };
        if (inGame) img.src = 'nui://ox_inventory/web/images/WEAPON_PETROLCAN.png';
        else img.onerror();
        canApp.classList.remove('hidden', 'closing', 'bought');
        renderCan();
    }

    function closeCan(tellGame) {
        if (canApp.classList.contains('hidden') || canApp.classList.contains('closing')) return;
        canApp.classList.add('closing');
        canTimer = setTimeout(() => { canApp.classList.add('hidden'); canApp.classList.remove('closing', 'bought'); }, 170);
        if (tellGame) post('close');
    }

    async function buyCan(account) {
        if (canBuying || !can) return;
        canBuying = true;
        renderCan();
        const res = await post('buyCan', { account });
        canBuying = false;
        if (res && res.ok) {
            if (typeof res.cash === 'number') can.cash = res.cash;
            if (typeof res.bank === 'number') can.bank = res.bank;
            renderCan();
            canApp.classList.add('bought');
            canTimer = setTimeout(() => closeCan(true), 1500);
        } else {
            renderCan();
            canToast(ERRORS[res && res.code] || ERRORS.failed);
        }
    }

    $('canClose').onclick = () => closeCan(true);
    $('canPayCash').onclick = () => buyCan('cash');
    $('canPayBank').onclick = () => buyCan('bank');

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        if (!canApp.classList.contains('hidden')) closeCan(true);
        else close(true);
    });

    // ---------- the live pump card ----------
    const live = $('live');
    let run = null;
    let hideTimer = null;

    function liveStart(s) {
        clearTimeout(hideTimer);
        live.classList.remove('hidden', 'leaving', 'done');
        const ev = !!s.electric;
        const word = ev ? 'ك.و.س' : 'لتر';
        $('liveIcon').innerHTML = ev ? ICONS.bolt : ICONS.drop;
        $('liveTitle').textContent = ev ? 'جارٍ الشحن…' : 'جارٍ التعبئة…';
        $('liveUnitsOf').textContent = `من ${iso(one(s.units))} ${word}`;
        $('liveMoneyOf').textContent = `من ${iso(money(s.cost))}`;
        run = { s, t0: performance.now() };
        const step = (now) => {
            if (!run || run.s !== s) return;
            const p = Math.min(1, (now - run.t0) / Math.max(1, s.duration));
            $('liveUnits').textContent = one(s.units * p);
            $('liveMoney').textContent = money(s.cost * p);
            $('liveBar').style.width = (p * 100) + '%';
            requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
    }

    function liveEnd(r) {
        const s = run && run.s;
        run = null;
        if (!r || r.failed || !s) {
            live.classList.add('hidden');
            return;
        }
        const ev = !!r.electric;
        const stopped = (r.refund || 0) > 0;
        live.classList.add('done');
        $('liveIcon').innerHTML = ICONS.check;
        $('liveTitle').textContent = stopped ? 'أُوقفت المضخة' : (ev ? 'تم الشحن' : 'تمت التعبئة');
        $('liveUnits').textContent = one(r.units);
        $('liveMoney').textContent = money(r.paid);
        $('liveMoneyOf').textContent = stopped ? `أُعيد لك ${iso(money(r.refund))}` : '';
        $('liveBar').style.width = Math.min(100, (r.units / Math.max(0.01, s.units)) * 100) + '%';
        hideTimer = setTimeout(() => {
            live.classList.add('leaving');
            hideTimer = setTimeout(() => live.classList.add('hidden'), 350);
        }, 2600);
    }

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'open' && msg.data) open(msg.data);
        else if (msg.action === 'openCan' && msg.data) openCan(msg.data);
        else if (msg.action === 'close') { close(false); closeCan(false); }
        else if (msg.action === 'fuelStart' && msg.data) liveStart(msg.data);
        else if (msg.action === 'fuelEnd') liveEnd(msg.data);
    });

    // ---------- preview outside the game (for checking the design in a browser) ----------
    function previewAnswer(name, data) {
        if (name === 'buyCan') {
            const src = can || q, price = (can && can.price) || (q && q.can && q.can.price) || 0;
            return { ok: true, cash: src.cash - (data.account === 'cash' ? price : 0), bank: src.bank - (data.account === 'bank' ? price : 0) };
        }
        if (name === 'start') {
            const t = data.target;
            close(false);
            liveStart({ electric: q.electric, from: q.level, to: t, units: unitsFor(t), cost: costFor(t), duration: 4000 });
            setTimeout(() => liveEnd({ electric: q.electric, units: unitsFor(t), paid: costFor(t), refund: 0 }), 4100);
            return { ok: true };
        }
        return true;
    }

    if (!inGame) {
        const params = new URLSearchParams(location.search);
        const view = params.get('view') || 'panel';
        document.body.style.background = 'linear-gradient(135deg,#3a4250,#1b1f27)';
        const car = {
            station: 'غروف ستريت (Grove Street)', electric: false, level: 23.4, capacity: 60, price: 2, rate: 2.5,
            minPrice: 1, minSeconds: 4, maxSeconds: 45, cash: 340, bank: 12500, vehicle: { name: 'Sultan RS', plate: 'EXT 4821' },
            can: { price: 120, liters: 20 },
        };
        const ev = Object.assign({}, car, {
            electric: true, level: 41.7, capacity: 75, price: 1, rate: 3, vehicle: { name: 'Voltic', plate: 'VOLT 01' },
        });
        if (view === 'can') openCan({ price: 120, liters: 20, station: 'ديفيس (Davis)', cash: 340, bank: 12500 });
        else if (view === 'canpoor') openCan({ price: 120, liters: 20, station: 'ديفيس (Davis)', cash: 40, bank: 90 });
        else if (view === 'panel') open(car);
        else if (view === 'ev') open(ev);
        else if (view === 'poor') open(Object.assign({}, car, { cash: 30, bank: 12 }));
        else if (view === 'full') open(Object.assign({}, car, { level: 99.6 }));
        else if (view === 'live') { q = car; liveStart({ electric: false, units: 45.9, cost: 92, duration: 20000 }); }
        else if (view === 'done') { q = car; liveStart({ electric: false, units: 45.9, cost: 92, duration: 1 }); setTimeout(() => liveEnd({ units: 21.3, paid: 43, refund: 49 }), 50); }
    }
})();
