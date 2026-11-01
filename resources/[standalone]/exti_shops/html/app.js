// EX_Tii shops — the shop panel
(() => {
    const $ = (id) => document.getElementById(id);
    const app = $('app');
    const inGame = typeof GetParentResourceName === 'function';
    const resource = inGame ? GetParentResourceName() : 'exti_shops';
    const IMG = inGame ? 'nui://ox_inventory/web/images/' : (new URLSearchParams(location.search).get('img') || '');

    const ICONS = {
        store: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9.5V20h16V9.5"/><path d="M2.8 9.5 5 4h14l2.2 5.5a2.6 2.6 0 0 1-4.8 1.3 2.6 2.6 0 0 1-4.4 0 2.6 2.6 0 0 1-4.4 0A2.6 2.6 0 0 1 2.8 9.5Z"/><path d="M10 20v-5h4v5"/></svg>',
        bottle: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M10 2.5h4M10.5 2.5v4.2L8 10.5V20a1.5 1.5 0 0 0 1.5 1.5h5A1.5 1.5 0 0 0 16 20v-9.5l-2.5-3.8V2.5"/><path d="M8 13.5h8"/></svg>',
        wrench: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a4 4 0 0 0 5 5L21 12.6a6 6 0 0 1-7.4 1.3L6 21.5 2.5 18l7.6-7.6a6 6 0 0 1 1.3-7.4l1.3 1.3a4 4 0 0 0 2 2Z"/></svg>',
        pharmacy: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="5"/><path d="M12 7.5v9M7.5 12h9"/></svg>',
        target: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 1.5v4M12 18.5v4M1.5 12h4M18.5 12h4"/></svg>',
        box: '<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 8 12 3 3 8v8l9 5 9-5Z"/><path d="M3 8l9 5 9-5M12 13v8"/></svg>',
        plus: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
        lock: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><rect x="4.5" y="10.5" width="15" height="10" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/></svg>',
        empty: '<svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 4h2l2.4 11.2a2 2 0 0 0 2 1.6h7.7a2 2 0 0 0 2-1.5L21 8H6"/><circle cx="10" cy="20" r="1.4"/><circle cx="17" cy="20" r="1.4"/></svg>',
    };

    const CATEGORIES = {
        food: 'طعام وشراب',
        medical: 'طبي',
        tools: 'أدوات',
        weapons: 'أسلحة',
        ammo: 'ذخيرة',
    };

    const ERRORS = {
        no_money: 'المبلغ لا يكفي',
        too_far: 'ابتعدت عن البائع، اقترب منه وحاول مرة أخرى',
        cant_carry: 'لا يوجد مكان كافٍ في حقيبتك',
        no_license: 'تحتاج رخصة سلاح لشراء هذا',
        empty: 'السلة فارغة',
        busy: 'لحظة… جارٍ تنفيذ طلبك السابق',
        failed: 'حدث خطأ، حاول مرة أخرى',
    };

    let shop = null;
    let cart = new Map(); // name -> count
    let category = 'all';
    let paying = false;

    // "عدة تصليح (Repair Kit)" -> Arabic name + small English name under it
    function nameParts(label) {
        const m = /^(.*?)\s*\(([^()]+)\)\s*$/.exec(label || '');
        return m ? [m[1], m[2]] : [label || '', ''];
    }
    function fillName(el, label) {
        const [ar, en] = nameParts(label);
        el.textContent = ar;
        if (en) {
            const sub = document.createElement('small');
            sub.className = 'name-en';
            sub.dir = 'ltr';
            sub.textContent = en;
            el.appendChild(sub);
        }
    }

    const money = (n) => '$' + Math.max(0, Math.floor(n || 0)).toLocaleString('en-US');
    const product = (name) => shop && shop.products.find((p) => p.name === name);

    function post(name, data) {
        if (!inGame) return Promise.resolve(previewAnswer(name, data));
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ ok: false, code: 'failed' }));
    }

    function imageFor(p, cls) {
        const img = document.createElement('img');
        img.src = IMG + p.image;
        img.alt = '';
        if (cls) img.className = cls;
        img.onerror = () => {
            const box = document.createElement('div');
            box.className = 'fallback';
            box.innerHTML = ICONS.box;
            img.replaceWith(box);
        };
        return img;
    }

    let toastTimer;
    function toast(text, type) {
        const t = $('toast');
        t.textContent = text;
        t.className = `kit-toast show ${type || ''}`;
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { t.className = 'kit-toast'; }, 2800);
    }

    function total() {
        let sum = 0;
        cart.forEach((count, name) => { const p = product(name); if (p) sum += p.price * count; });
        return sum;
    }

    // ---------- render ----------
    function renderTop() {
        $('shopIcon').innerHTML = ICONS[shop.icon] || ICONS.store;
        $('shopName').textContent = shop.label;
        $('shopArea').textContent = shop.area ? `فرع ${shop.area}` : '';
        $('greeting').textContent = shop.greeting || 'أهلًا بك!';
        document.querySelector('.clerk-name').textContent = (shop.clerkTitle || 'البائع') + ':'; // EX_Tii: e.g. الصيدلي
        renderWallet();
    }

    function renderWallet() {
        $('cash').textContent = money(shop.cash);
        $('bank').textContent = money(shop.bank);
    }

    function bump(id) {
        const el = $(id);
        el.classList.remove('bump');
        void el.offsetWidth;
        el.classList.add('bump');
        setTimeout(() => el.classList.remove('bump'), 700);
    }

    function renderChips() {
        const used = [...new Set(shop.products.map((p) => p.category))];
        const chips = $('chips');
        chips.innerHTML = '';
        chips.style.display = used.length > 1 ? '' : 'none';
        const make = (key, label, count) => {
            const b = document.createElement('button');
            b.className = 'kit-chip' + (category === key ? ' active' : '');
            b.innerHTML = `${label} <b>${count}</b>`;
            b.onclick = () => { category = key; renderChips(); renderGrid(true); };
            chips.appendChild(b);
        };
        make('all', 'الكل', shop.products.length);
        used.forEach((key) => make(key, CATEGORIES[key] || key, shop.products.filter((p) => p.category === key).length));
    }

    function renderGrid(animate) {
        const grid = $('grid');
        const scroll = grid.scrollTop;
        grid.classList.toggle('calm', !animate);
        grid.innerHTML = '';
        const list = shop.products.filter((p) => category === 'all' || p.category === category);
        list.forEach((p, i) => {
            const inCart = cart.get(p.name) || 0;
            const locked = p.licence && !p.licensed;
            const card = document.createElement('div');
            card.className = 'card' + (inCart ? ' in-cart' : '') + (locked ? ' locked' : '');
            card.style.animationDelay = `${i * 35}ms`;

            const art = document.createElement('div');
            art.className = 'card-art';
            art.appendChild(imageFor(p));
            const qty = document.createElement('span');
            qty.className = 'card-qty';
            qty.textContent = inCart;
            art.appendChild(qty);
            card.appendChild(art);

            const info = document.createElement('div');
            info.className = 'card-info';
            const name = document.createElement('div');
            name.className = 'card-name';
            fillName(name, p.label);
            info.appendChild(name);
            // EX_Tii: one short line saying what the item does (pharmacy)
            if (p.desc) {
                const desc = document.createElement('div');
                desc.className = 'card-desc';
                desc.textContent = p.desc;
                info.appendChild(desc);
            }
            if (p.licence) {
                const tag = document.createElement('span');
                tag.className = 'card-tag' + (locked ? ' warn' : '');
                tag.innerHTML = locked ? `${ICONS.lock} تحتاج رخصة سلاح` : 'معك رخصة سلاح';
                info.appendChild(tag);
            } else if (p.step > 1) {
                const tag = document.createElement('span');
                tag.className = 'card-tag';
                tag.textContent = `+${p.step} كل ضغطة`;
                info.appendChild(tag);
            }

            const row = document.createElement('div');
            row.className = 'card-row';
            const price = document.createElement('div');
            price.className = 'price';
            price.innerHTML = `<span dir="ltr">${money(p.price)}</span>${p.step > 1 ? '<small>للواحدة</small>' : ''}`;
            const add = document.createElement('button');
            add.className = 'add-btn';
            add.innerHTML = `${ICONS.plus} أضف`;
            add.disabled = locked || inCart >= p.max;
            add.onclick = () => change(p.name, p.step || 1);
            row.appendChild(price);
            row.appendChild(add);
            info.appendChild(row);
            card.appendChild(info);
            grid.appendChild(card);
        });
        if (!animate) grid.scrollTop = scroll;
    }

    function renderCart() {
        const list = $('cartList');
        list.innerHTML = '';
        let lines = 0;
        cart.forEach((count, name) => {
            const p = product(name);
            if (!p) return;
            lines += 1;
            const line = document.createElement('div');
            line.className = 'line';
            line.appendChild(imageFor(p));
            const text = document.createElement('div');
            text.className = 'line-text';
            text.innerHTML = `<div class="line-name"></div><div class="line-sum">${count} × ${money(p.price)} = ${money(count * p.price)}</div>`;
            text.querySelector('.line-name').textContent = nameParts(p.label)[0];
            line.appendChild(text);

            const step = p.step || 1;
            const stepper = document.createElement('div');
            stepper.className = 'stepper';
            const minus = document.createElement('button');
            minus.textContent = '−';
            minus.onclick = () => change(name, -step);
            const num = document.createElement('span');
            num.textContent = count;
            const plus = document.createElement('button');
            plus.textContent = '+';
            plus.disabled = count >= p.max;
            plus.onclick = () => change(name, step);
            stepper.append(plus, num, minus);
            line.appendChild(stepper);
            list.appendChild(line);
        });

        if (!lines) {
            list.innerHTML = `<div class="cart-empty">${ICONS.empty}<span>سلتك فارغة<br>اختر ما تحتاجه من الرفوف</span></div>`;
        }

        let items = 0;
        cart.forEach((c) => { items += c; });
        $('cartCount').textContent = items;
        $('clearBtn').style.visibility = lines ? 'visible' : 'hidden';

        const sum = total();
        const t = $('total');
        if (t.textContent !== money(sum)) {
            t.textContent = money(sum);
            t.classList.remove('pulse');
            void t.offsetWidth;
            t.classList.add('pulse');
        }

        const cashOk = sum <= shop.cash;
        const bankOk = sum <= shop.bank;
        $('payCash').disabled = paying || !sum || !cashOk;
        $('payBank').disabled = paying || !sum || !bankOk;
        $('purseCash').classList.toggle('low', !!sum && !cashOk);
        $('purseBank').classList.toggle('low', !!sum && !bankOk);

        const note = $('payNote');
        note.classList.remove('bad');
        if (!sum) note.textContent = 'أضف شيئًا إلى السلة للدفع';
        else if (!cashOk && !bankOk) { note.textContent = 'المبلغ لا يكفي نقدًا ولا في البنك'; note.classList.add('bad'); }
        else if (!cashOk) note.textContent = 'النقد لا يكفي، يمكنك الدفع بالبطاقة';
        else if (!bankOk) note.textContent = 'رصيد البنك لا يكفي، يمكنك الدفع نقدًا';
        else note.textContent = 'اختر طريقة الدفع';
    }

    function change(name, delta) {
        const p = product(name);
        if (!p || paying) return;
        if (p.licence && !p.licensed) return toast(ERRORS.no_license, 'error');
        const next = Math.max(0, Math.min(p.max, (cart.get(name) || 0) + delta));
        if (next === 0) cart.delete(name); else cart.set(name, next);
        renderGrid();
        renderCart();
    }

    // ---------- pay ----------
    async function pay(account) {
        if (paying || !cart.size) return;
        const sum = total();
        paying = true;
        const btn = account === 'cash' ? $('payCash') : $('payBank');
        const label = btn.querySelector('span').textContent;
        btn.classList.add('loading');
        btn.querySelector('span').textContent = 'جارٍ الدفع…';
        renderCart();

        const lines = [];
        cart.forEach((count, name) => lines.push({ name, count }));
        const res = await post('buy', { cart: lines, account });

        btn.classList.remove('loading');
        btn.querySelector('span').textContent = label;
        paying = false;

        if (res && res.ok) {
            if (typeof res.cash === 'number') shop.cash = res.cash;
            if (typeof res.bank === 'number') shop.bank = res.bank;
            renderWallet();
            bump(account === 'cash' ? 'purseCash' : 'purseBank');
            cart = new Map();
            renderGrid();
            renderCart();
            const paid = typeof res.paid === 'number' ? res.paid : sum;
            $('receiptText').textContent = `دفعت ${money(paid)} ${account === 'cash' ? 'نقدًا' : 'بالبطاقة'} — شكرًا لزيارتك!`;
            const r = $('receipt');
            r.classList.add('show');
            setTimeout(() => r.classList.remove('show'), 1600);
            if (res.code === 'partial') setTimeout(() => toast('لم يتسع كل شيء في حقيبتك، أعدنا لك ثمن الباقي'), 1700);
        } else {
            renderCart();
            toast(ERRORS[res && res.code] || ERRORS.failed, 'error');
        }
    }

    // ---------- open / close ----------
    let closeTimer = null;
    function open(data) {
        // EX_Tii: reopening right after closing must not be hidden by the old closing timer
        if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; }
        closing = false;
        shop = data;
        cart = new Map();
        category = 'all';
        paying = false;
        app.classList.remove('hidden', 'closing');
        renderTop();
        renderChips();
        renderGrid(true);
        $('grid').scrollTop = 0;
        renderCart();
    }

    let closing = false;
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

    $('closeBtn').onclick = () => close(true);
    $('clearBtn').onclick = () => { if (!paying) { cart = new Map(); renderGrid(); renderCart(); } };
    $('payCash').onclick = () => pay('cash');
    $('payBank').onclick = () => pay('bank');
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(true); });

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'open' && msg.shop) open(msg.shop);
        else if (msg.action === 'close') close(false);
    });

    // ---------- preview outside the game (for checking the design in a browser) ----------
    function previewAnswer(name, data) {
        if (name !== 'buy') return true;
        let sum = 0;
        data.cart.forEach((l) => { sum += product(l.name).price * l.count; });
        const cash = data.account === 'cash' ? shop.cash - sum : shop.cash;
        const bank = data.account === 'bank' ? shop.bank - sum : shop.bank;
        return { ok: true, cash, bank, paid: sum };
    }

    if (!inGame) {
        const params = new URLSearchParams(location.search);
        const kind = params.get('shop') || 'general';
        const samples = {
            general: { icon: 'store', label: 'بقالة 24/7', area: 'ستروبيري', greeting: 'أهلًا بك! خذ راحتك، كل شيء طازج اليوم.', products: [
                { name: 'burger', label: 'برغر (Burger)', price: 10, category: 'food', max: 25, step: 1, image: 'burger.png' },
                { name: 'water', label: 'ماء (Water)', price: 10, category: 'food', max: 25, step: 1, image: 'water.png' },
                { name: 'sprunk', label: 'مشروب سبرنك (Sprunk)', price: 10, category: 'food', max: 25, step: 1, image: 'sprunk.png' },
                { name: 'bandage', label: 'ضمادة (Bandage)', price: 50, category: 'medical', max: 25, step: 1, image: 'bandage.png' },
                { name: 'repairkit', label: 'عدة تصليح (Repair Kit)', price: 250, category: 'tools', max: 5, step: 1, image: 'repairkit.png' },
            ] },
            pharmacy: { icon: 'pharmacy', label: 'صيدلية المستشفى', clerkTitle: 'الصيدلي', area: 'بيلبوكس', greeting: 'أهلًا بك! مفتوحون 24 ساعة، كيف أقدر أساعدك؟', products: [
                { name: 'gauze', label: 'شاش طبي (Gauze)', price: 50, category: 'medical', max: 20, step: 1, image: 'gauze.png', desc: 'يعيد ربع صحتك خلال 3 ثوانٍ' },
                { name: 'painkillers', label: 'مسكنات (Painkillers)', price: 75, category: 'medical', max: 10, step: 1, image: 'painkillers.png', desc: 'يعيد صحتك شيئًا فشيئًا خلال 40 ثانية' },
                { name: 'medikit', label: 'حقيبة إسعافات (First Aid Kit)', price: 300, category: 'medical', max: 3, step: 1, image: 'medikit.png', desc: 'يعيد صحتك كاملة، يحتاج 10 ثوانٍ وأنت واقف' },
            ] },
            ammunation: { icon: 'target', label: 'متجر الأسلحة', area: 'ليتل سيول', greeting: 'أهلًا بك في أمونيشن. السلاح الناري يحتاج رخصة سلاح.', products: [
                { name: 'WEAPON_KNIFE', label: 'سكين (Knife)', price: 200, category: 'weapons', max: 1, step: 1, image: 'WEAPON_KNIFE.png' },
                { name: 'WEAPON_BAT', label: 'مضرب (Bat)', price: 100, category: 'weapons', max: 1, step: 1, image: 'WEAPON_BAT.png' },
                { name: 'WEAPON_PISTOL', label: 'مسدس (Pistol)', price: 1000, category: 'weapons', max: 1, step: 1, image: 'WEAPON_PISTOL.png', licence: 'weapon', licensed: false },
                { name: 'ammo-9', label: 'ذخيرة 9 ملم', price: 5, category: 'ammo', max: 250, step: 10, image: 'ammo-9.png' },
            ] },
        };
        const data = Object.assign({ cash: 340, bank: 12500 }, samples[kind] || samples.general);
        document.body.style.background = 'linear-gradient(135deg,#3a4250,#1b1f27)';
        open(data);
        if (params.get('cart')) { change(data.products[0].name, 2); change(data.products[3].name, data.products[3].step || 1); }
    }
})();
