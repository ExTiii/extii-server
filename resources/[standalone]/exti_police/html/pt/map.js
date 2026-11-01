// EX_Tii Police tablet — the map (San Andreas Grid, like the video): the officers on duty and the
// team's vehicles out in the city, live. Drag to move, mouse wheel to zoom.
(() => {
    const { S, I, esc, call, render, after, mirrorUi, onMirror, toast, fail, post, MIRROR, head, metaBox } = PT;

    const IMG_W = 2048;
    const IMG_H = 3072;
    const VW = 1220;          // the map area on the screen
    const VH = 698;
    const ZMIN = 0.22;
    const ZMAX = 2.6;
    // game position -> map picture (measured on the picture)
    const toPx = (x, y) => [942.06 + 0.215 * x, 1929.23 - 0.215 * y];
    const toWorld = (px, py) => [(px - 942.06) / 0.215, (1929.23 - py) / 0.215];

    const ZONES = [
        ['لوس سانتوس', 150, -1000, 'big'],
        ['مطار لوس سانتوس', -1200, -2800],
        ['الميناء', 700, -2950],
        ['فيسبوتشي', -1250, -1350],
        ['روكفورد هيلز', -850, -150],
        ['ميرور بارك', 1150, -650],
        ['تلال فاينوود', 100, 900],
        ['تشوماش', -3150, 900],
        ['هارموني', 550, 2700],
        ['فورت زانكودو', -2250, 3150],
        ['بحيرة ألامو', 800, 4100],
        ['ساندي شورز', 1850, 3700],
        ['غريبسيد', 1750, 4850],
        ['جبل تشيلياد', 450, 5570],
        ['باليتو باي', -150, 6300],
    ];

    S.map = {
        z: 0.42, cx: 1036, cy: 1900, sat: true, zones: true, layer: 'staff', sel: null,
        units: { staff: [], vehicles: [], calls: [] }, cursor: '', centered: false, busy: false,
    };
    const agoText = (s) => { s = Math.max(0, Math.floor(s || 0)); if (s < 60) return 'الآن'; const m = Math.floor(s / 60); return m < 60 ? `قبل ${m} د` : `قبل ${Math.floor(m / 60)} س`; };

    // the map picture is made once and moved into each new drawing (no reloading, no flicker)
    const mapImg = new Image();
    mapImg.className = 'pt-mapimg';
    mapImg.draggable = false;
    mapImg.alt = '';

    function clamp() {
        const m = S.map;
        m.z = Math.min(ZMAX, Math.max(ZMIN, m.z));
        m.cx = Math.min(IMG_W, Math.max(0, m.cx));
        m.cy = Math.min(IMG_H, Math.max(0, m.cy));
    }
    function layerStyle() {
        const m = S.map;
        return `transform: translate(${(VW / 2 - m.cx * m.z).toFixed(1)}px, ${(VH / 2 - m.cy * m.z).toFixed(1)}px) scale(${m.z.toFixed(4)}); --inv: ${(1 / m.z).toFixed(4)}`;
    }
    function applyMap() {
        clamp();
        const layer = document.getElementById('pt-maplayer');
        if (layer) layer.setAttribute('style', layerStyle());
    }

    const findUnit = (sel) => {
        if (!sel) return null;
        const pool = sel.kind === 'veh' ? S.map.units.vehicles : sel.kind === 'call' ? S.map.units.calls : S.map.units.staff;
        return (pool || []).find((u) => u.id === sel.id) || null;
    };
    const coords = (u) => `${Number(u.x).toFixed(1)}, ${Number(u.y).toFixed(1)}`;

    function markers() {
        const m = S.map;
        const out = [];
        if (m.zones) {
            ZONES.forEach(([name, x, y, big]) => {
                const [px, py] = toPx(x, y);
                out.push(`<span class="pt-zone ${big ? 'big' : ''}" style="left:${px.toFixed(1)}px;top:${py.toFixed(1)}px">${esc(name)}</span>`);
            });
        }
        (S.cfg.stations || []).forEach((st) => {
            const [px, py] = toPx(st.x, st.y);
            out.push(`<span class="pt-mk station" style="left:${px.toFixed(1)}px;top:${py.toFixed(1)}px"><i>${I('shield', 13, 2.2)}</i><b>${esc(st.label)}</b></span>`);
        });
        (m.units.vehicles || []).forEach((v) => {
            const [px, py] = toPx(v.x, v.y);
            const on = m.sel && m.sel.kind === 'veh' && m.sel.id === v.id;
            out.push(`<button class="pt-mk veh ${on ? 'sel' : ''}" style="left:${px.toFixed(1)}px;top:${py.toFixed(1)}px" data-act="mapSel" data-kind="veh" data-id="${v.id}"><i>${I('car', 12, 2.3)}</i><b>${esc(v.label)}</b></button>`);
        });
        (m.units.staff || []).forEach((u) => {
            const [px, py] = toPx(u.x, u.y);
            const on = m.sel && m.sel.kind === 'staff' && m.sel.id === u.id;
            out.push(`<button class="pt-mk staff ${u.me ? 'me' : ''} ${on ? 'sel' : ''}" style="left:${px.toFixed(1)}px;top:${py.toFixed(1)}px" data-act="mapSel" data-kind="staff" data-id="${u.id}"><i></i><b>${esc(u.name)}</b></button>`);
        });
        (m.units.calls || []).forEach((c) => {
            const [px, py] = toPx(c.x, c.y);
            const on = m.sel && m.sel.kind === 'call' && m.sel.id === c.id;
            out.push(`<button class="pt-mk call ${c.takenBy ? 'taken' : ''} ${on ? 'sel' : ''}" style="left:${px.toFixed(1)}px;top:${py.toFixed(1)}px" data-act="mapSel" data-kind="call" data-id="${c.id}"><i>${I('alert', 12, 2.4)}</i><b>${esc(c.label)} · ${esc(agoText(c.ago))}</b></button>`);
        });
        return out.join('');
    }

    function sidePanel() {
        const m = S.map;
        if (m.layer === 'call') {
            const cs = m.units.calls || [];
            return `<div class="pt-mpanel start">
                <h3>البلاغات</h3><small>${cs.length} مفتوحة</small>
                <div class="pt-mlist" data-scroll="mapside">${cs.length ? cs.map((c) => `<button class="pt-mrow ${m.sel && m.sel.kind === 'call' && m.sel.id === c.id ? 'on' : ''}" data-act="mapSel" data-kind="call" data-id="${c.id}" data-go="1">
                    <span><b>${esc(c.label)} <i class="pt-mute">${esc(agoText(c.ago))}</i></b><small>${esc(c.text || 'بدون تفاصيل')}</small></span>${c.takenBy ? `<em class="pt-tag ${c.mine ? 'green' : 'blue'}">${c.mine ? 'معك' : esc(c.takenBy)}</em>` : '<em class="pt-tag red">جديد</em>'}</button>`).join('')
                    : '<p class="pt-mute">لا توجد بلاغات مفتوحة. تأتي من الهاتف (الطوارئ → الشرطة) ومن /911.</p>'}</div>
            </div>`;
        }
        if (m.layer === 'veh') {
            const vs = m.units.vehicles || [];
            return `<div class="pt-mpanel start">
                <h3>لوحة المركبات</h3><small>${vs.length} مدرجة</small>
                <div class="pt-mlist" data-scroll="mapside">${vs.length ? vs.map((v) => `<button class="pt-mrow ${m.sel && m.sel.kind === 'veh' && m.sel.id === v.id ? 'on' : ''}" data-act="mapSel" data-kind="veh" data-id="${v.id}" data-go="1">
                    <span><b>${esc(v.label)}</b><small class="ltr">${esc(v.plate)}</small></span><em class="pt-tag amber">نشطة</em></button>`).join('')
                    : '<p class="pt-mute">لا توجد مركبات للفريق في المدينة الآن.</p>'}</div>
            </div>`;
        }
        const st = m.units.staff || [];
        return `<div class="pt-mpanel start">
            <h3>قائمة الأفراد</h3><small>${st.length} في الخدمة</small>
            <div class="pt-mlist" data-scroll="mapside">${st.length ? st.map((u) => `<button class="pt-mrow ${m.sel && m.sel.kind === 'staff' && m.sel.id === u.id ? 'on' : ''}" data-act="mapSel" data-kind="staff" data-id="${u.id}" data-go="1">
                <span><b>${esc(u.name)}${u.me ? ' <i class="pt-me">أنت</i>' : ''}</b><small>${esc(u.rank || '')}</small></span><em class="pt-tag ${u.car ? 'blue' : 'green'}">${u.car ? 'في مركبة' : 'متاح'}</em></button>`).join('')
                : '<p class="pt-mute">لا يوجد أحد في الخدمة.</p>'}</div>
        </div>`;
    }

    function detailPanel() {
        const m = S.map;
        const u = findUnit(m.sel);
        if (!u) {
            return `<div class="pt-mpanel end"><h3>التفاصيل</h3><p class="pt-mute">اختر علامة لعرض التفاصيل.</p></div>`;
        }
        if (m.sel.kind === 'call') {
            return `<div class="pt-mpanel end">
                <h3>تفاصيل البلاغ</h3>
                <div class="pt-dhead"><i class="red">${I('alert', 20, 2)}</i><span><b>${esc(u.label)}</b><small>${esc(agoText(u.ago))}${u.number ? ` · <bdi class="ltr">${esc(u.number)}</bdi>` : ' · بدون رقم'}</small></span></div>
                <p class="pt-ctext">${esc(u.text || 'بدون تفاصيل')}</p>
                <dl class="pt-dl">
                    <dt>الحالة</dt><dd>${u.takenBy ? (u.mine ? 'استلمته أنت' : `استلمه ${esc(u.takenBy)}`) : 'لم يستلمه أحد'}</dd>
                    <dt>الإحداثيات</dt><dd class="ltr">${coords(u)}</dd>
                </dl>
                <div class="pt-drow">
                    <button class="pt-btn ${u.mine ? 'ghost' : 'primary'} sm" data-act="mapCallTake" ${m.busy ? 'disabled' : ''}>${I(u.mine ? 'x' : 'check', 15, 2.2)} ${u.mine ? 'ترك البلاغ' : 'استلام البلاغ'}</button>
                    <button class="pt-btn ghost sm" data-act="mapWay">${I('pin', 15, 2)} الطريق إليه</button>
                </div>
                <div class="pt-drow"><button class="pt-btn danger sm" data-act="mapCallClose" ${m.busy ? 'disabled' : ''}>${I('archive', 15, 2)} إنهاء البلاغ</button></div>
            </div>`;
        }
        if (m.sel.kind === 'veh') {
            const h = Math.max(0, Math.min(100, Number(u.health) || 0));
            return `<div class="pt-mpanel end">
                <h3>تفاصيل المركبة</h3>
                <div class="pt-dhead"><i>${I('car', 20, 2)}</i><span><b>${esc(u.label)}</b><small>اللوحة <bdi class="ltr">${esc(u.plate)}</bdi></small></span></div>
                <dl class="pt-dl">
                    <dt>السائق</dt><dd>${esc(u.driver || 'لا أحد')}</dd>
                    <dt>رقم الشبكة</dt><dd class="ltr">${esc(u.netId)}</dd>
                </dl>
                <div class="pt-hbar"><div><span>الحالة</span><b class="ltr">${h}%</b></div><i><s style="width:${h}%" class="${h < 35 ? 'bad' : h < 70 ? 'warn' : ''}"></s></i></div>
                <dl class="pt-dl"><dt>الإحداثيات</dt><dd class="ltr">${coords(u)}</dd></dl>
                <div class="pt-drow"><button class="pt-btn ghost sm" data-act="mapWay">${I('pin', 15, 2)} تحديد وجهة</button><button class="pt-btn primary sm" disabled title="قريبًا">${I('video', 15, 2)} فتح الكاميرا</button></div>
            </div>`;
        }
        return `<div class="pt-mpanel end">
            <h3>تفاصيل الفرد</h3>
            <div class="pt-dhead"><i class="round">${esc(PT.initials(u.name))}</i><span><b>${esc(u.name)}</b><small>${esc(u.rank || '')}</small></span></div>
            <dl class="pt-dl">
                <dt>الحالة</dt><dd>${u.car ? 'في مركبة' : 'متاح'}</dd>
                <dt>الإحداثيات</dt><dd class="ltr">${coords(u)}</dd>
            </dl>
            ${u.me ? '' : `<div class="pt-drow"><button class="pt-btn primary sm" data-act="mapWay">${I('pin', 15, 2)} تحديد وجهة</button></div>`}
        </div>`;
    }

    function view() {
        const m = S.map;
        const chip = (act, on, icon, label, extra = '') => `<button class="pt-mchip ${on ? 'on' : ''}" data-act="${act}" ${extra}>${icon ? I(icon, 13, 2) : ''}${esc(label)}</button>`;
        if (!mapImg.src) mapImg.src = 'pt/img/map.jpg'; // loaded the first time the map is opened
        after(() => {
            const slot = document.getElementById('pt-mapslot');
            if (slot) slot.replaceWith(mapImg);
        });
        return `<div class="pt-appwin pt-mapapp">${head('مكتب الخرائط', 'شبكة سان أندرياس', metaBox('المؤشر', m.cursor || '—', 'pt-cursor'))}
            <div class="pt-abody">
                <div class="pt-mapview ${m.sat ? '' : 'flat'}" id="pt-mapview">
                    <div class="pt-maplayer" id="pt-maplayer" style="${layerStyle()}"><span id="pt-mapslot"></span>${markers()}</div>
                </div>
                <div class="pt-mapbar">
                    ${chip('mapSat', m.sat, 'satellite', 'قمر صناعي')}
                    ${chip('mapZones', m.zones, 'zone', 'المناطق')}
                    <span class="pt-mbsep">قائمة العلامات</span>
                    ${chip('mapLayer', m.layer === 'call', '', `البلاغات${(m.units.calls || []).length ? ` (${(m.units.calls || []).length})` : ''}`, 'data-layer="call"')}
                    ${chip('mapLayer', m.layer === 'staff', '', 'الأفراد', 'data-layer="staff"')}
                    <button class="pt-mchip" disabled title="قريبًا">كاميرات السرعة</button>
                    ${chip('mapLayer', m.layer === 'veh', '', 'المركبات', 'data-layer="veh"')}
                    <button class="pt-mchip" disabled title="قريبًا">أجهزة التتبع</button>
                </div>
                ${sidePanel()}
                ${detailPanel()}
                <div class="pt-mzoom">
                    <button data-act="mapZoom" data-d="1" title="تكبير">${I('plus', 16, 2.2)}</button>
                    <button data-act="mapZoom" data-d="-1" title="تصغير">${I('minus', 16, 2.2)}</button>
                    <button data-act="mapMe" title="موقعي">${I('pin', 16, 2)}</button>
                </div>
            </div></div>`;
    }

    // ------------------------------------------------------------------
    // live positions (every 2.5 s while the map is open)
    // ------------------------------------------------------------------
    let timer = null;
    let loading = false;
    function load() {
        if (loading) return;
        loading = true;
        Promise.all([call('mapUnits'), call('calls')]).then(([res, cres]) => {
            loading = false;
            if (S.app !== 'map') return;
            if (!res.ok) return;
            S.map.units = { staff: PT.list(res.r.staff), vehicles: PT.list(res.r.vehicles), calls: cres && cres.ok ? PT.list(cres.r.calls) : (S.map.units.calls || []) };
            if (!S.map.centered) {
                const me = S.map.units.staff.find((u) => u.me);
                if (me) {
                    const [px, py] = toPx(me.x, me.y);
                    S.map.cx = px;
                    S.map.cy = py;
                    S.map.z = Math.max(S.map.z, 0.7);
                }
                S.map.centered = true;
            }
            if (!drag) render();
        });
    }

    function centerOn(u) {
        const [px, py] = toPx(u.x, u.y);
        S.map.cx = px;
        S.map.cy = py;
        if (S.map.z < 0.8) S.map.z = 0.8;
        clamp();
    }

    PT.app('map', {
        view,
        enter() {
            S.map.centered = false;
            S.map.sel = null;
            load();
            clearInterval(timer);
            timer = setInterval(load, 2500);
        },
        leave() {
            clearInterval(timer);
            timer = null;
        },
        act: {
            mapSat: () => { S.map.sat = !S.map.sat; render(); },
            mapZones: () => { S.map.zones = !S.map.zones; render(); },
            mapLayer: (el) => { S.map.layer = el.dataset.layer === 'veh' ? 'veh' : el.dataset.layer === 'call' ? 'call' : 'staff'; render(); },
            mapCallTake: () => {
                const u = findUnit(S.map.sel);
                if (!u || S.map.busy) return;
                S.map.busy = true;
                call('callTake', u.id).then((res) => {
                    S.map.busy = false;
                    if (!res.ok) { if (res.e === 'gone') { S.map.sel = null; toast('هذا البلاغ أُغلق', 'error'); load(); } else fail(res); render(); return; }
                    S.map.units.calls = PT.list(res.r.calls);
                    toast(res.r.call && res.r.call.mine ? 'استلمت البلاغ' : 'تركت البلاغ', 'success');
                    render();
                });
            },
            mapCallClose: () => {
                const u = findUnit(S.map.sel);
                if (!u || S.map.busy) return;
                PT.ask({ title: 'إنهاء البلاغ', sub: 'البلاغات', text: 'يختفي البلاغ من الخريطة عند الجميع.', ok: 'إنهاء', danger: true }, () => {
                    S.map.busy = true;
                    call('callClose', u.id).then((res) => {
                        S.map.busy = false;
                        if (!res.ok) { fail(res); render(); return; }
                        S.map.units.calls = PT.list(res.r.calls);
                        S.map.sel = null;
                        toast('أُنهي البلاغ', 'success');
                        render();
                    });
                });
            },
            mapSel: (el) => {
                const kind = el.dataset.kind === 'veh' ? 'veh' : el.dataset.kind === 'call' ? 'call' : 'staff';
                S.map.sel = { kind, id: Number(el.dataset.id) };
                S.map.layer = kind;
                const u = findUnit(S.map.sel);
                if (u && el.dataset.go) centerOn(u);
                render();
            },
            mapZoom: (el) => {
                S.map.z *= Number(el.dataset.d) > 0 ? 1.35 : 1 / 1.35;
                clamp();
                render();
            },
            mapMe: () => {
                const me = (S.map.units.staff || []).find((u) => u.me);
                if (me) { centerOn(me); render(); }
            },
            mapWay: () => {
                const u = findUnit(S.map.sel);
                if (!u) return;
                post('ptWaypoint', { x: u.x, y: u.y, label: S.map.sel.kind === 'veh' ? `${u.label} ${u.plate}` : S.map.sel.kind === 'call' ? u.label : u.name });
                if (!PT.inGame) toast('تم تحديد الوجهة على الخريطة');
            },
        },
    });

    // ------------------------------------------------------------------
    // dragging and zooming (your screen only; the mirror gets the result)
    // ------------------------------------------------------------------
    let drag = null;
    const scaleOf = (view) => {
        const r = view.getBoundingClientRect();
        return { r, k: VW / r.width };
    };
    function sendMap() { mirrorUi({ type: 'map', z: S.map.z, cx: S.map.cx, cy: S.map.cy }, 40); }

    if (!MIRROR) {
        document.addEventListener('mousedown', (e) => {
            if (S.app !== 'map' || e.button !== 0) return;
            const view = document.getElementById('pt-mapview');
            if (!view || !view.contains(e.target) || e.target.closest('[data-act]')) return;
            drag = { x: e.clientX, y: e.clientY, cx: S.map.cx, cy: S.map.cy, k: scaleOf(view).k, moved: false };
            view.classList.add('grab');
            e.preventDefault();
        });
        document.addEventListener('mousemove', (e) => {
            if (S.app !== 'map') return;
            const view = document.getElementById('pt-mapview');
            if (!view) return;
            const { r, k } = scaleOf(view);
            if (drag) {
                const dx = (e.clientX - drag.x) * drag.k;
                const dy = (e.clientY - drag.y) * drag.k;
                if (Math.abs(dx) + Math.abs(dy) > 3) drag.moved = true;
                S.map.cx = drag.cx - dx / S.map.z;
                S.map.cy = drag.cy - dy / S.map.z;
                applyMap();
                sendMap();
            }
            // the cursor's game position (top right of the map, like the video)
            const mx = (e.clientX - r.left) * k;
            const my = (e.clientY - r.top) * k;
            if (mx < 0 || my < 0 || mx > VW || my > VH) return;
            const [wx, wy] = toWorld(S.map.cx + (mx - VW / 2) / S.map.z, S.map.cy + (my - VH / 2) / S.map.z);
            S.map.cursor = `${wx.toFixed(1)}, ${wy.toFixed(1)}`;
            const c = document.getElementById('pt-cursor');
            if (c) c.textContent = S.map.cursor;
            mirrorUi({ type: 'cursor', t: S.map.cursor }, 120);
        });
        document.addEventListener('mouseup', () => {
            if (!drag) return;
            drag = null;
            const view = document.getElementById('pt-mapview');
            if (view) view.classList.remove('grab');
            PT.pushMirror();
        });
        document.addEventListener('wheel', (e) => {
            if (S.app !== 'map') return;
            const view = document.getElementById('pt-mapview');
            if (!view || !view.contains(e.target) || e.target.closest('.pt-mpanel')) return;
            e.preventDefault();
            const { r, k } = scaleOf(view);
            const mx = (e.clientX - r.left) * k;
            const my = (e.clientY - r.top) * k;
            const ix = S.map.cx + (mx - VW / 2) / S.map.z;
            const iy = S.map.cy + (my - VH / 2) / S.map.z;
            S.map.z *= e.deltaY < 0 ? 1.18 : 1 / 1.18;
            clamp();
            S.map.cx = ix - (mx - VW / 2) / S.map.z;
            S.map.cy = iy - (my - VH / 2) / S.map.z;
            applyMap();
            sendMap();
            clearTimeout(view._t);
            view._t = setTimeout(() => PT.pushMirror(), 150);
        }, { passive: false });
    }

    onMirror('map', (msg) => {
        S.map.z = Number(msg.z) || S.map.z;
        S.map.cx = Number(msg.cx) || S.map.cx;
        S.map.cy = Number(msg.cy) || S.map.cy;
        applyMap();
    });
    onMirror('cursor', (msg) => {
        S.map.cursor = msg.t || '';
        const c = document.getElementById('pt-cursor');
        if (c) c.textContent = S.map.cursor;
    });
})();
