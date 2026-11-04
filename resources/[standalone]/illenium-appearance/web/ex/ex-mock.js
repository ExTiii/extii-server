/* ======================================================================
   Browser preview only (never used in game): fake game answers so the screen can be checked in a
   normal browser. ?mode=clothing|barber|tattoo|surgeon|creator|uniform|wardrobe
   ====================================================================== */
'use strict';
const Mock = (() => {
    if (IN_GAME) return { handle: () => null };
    const q = new URLSearchParams(location.search);
    const mode = q.get('mode') || 'clothing';
    const comps = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    const maxD = { 0: 45, 1: 190, 2: 80, 3: 200, 4: 150, 5: 100, 6: 110, 7: 160, 8: 190, 9: 50, 10: 120, 11: 420 };
    const props = [0, 1, 2, 6, 7];
    const maxP = { 0: 160, 1: 50, 2: 40, 6: 45, 7: 15 };
    const hairCols = [];
    for (let i = 0; i < 64; i++) {
        const t = i / 63;
        hairCols.push([Math.round(30 + 200 * t * (i % 3 === 0 ? 1 : 0.7)), Math.round(20 + 150 * t * (i % 5 === 0 ? 1.1 : 0.6)), Math.round(15 + 110 * t * (i % 7 === 0 ? 1.4 : 0.4))]);
    }
    const ovs = { blemishes: 23, beard: 28, eyebrows: 33, ageing: 14, makeUp: 74, blush: 6, complexion: 11, sunDamage: 10, lipstick: 9, moleAndFreckles: 17, chestHair: 16, bodyBlemishes: 11 };
    const colored = ['beard', 'eyebrows', 'chestHair', 'makeUp', 'blush', 'lipstick'];
    const settings = () => ({
        ped: { model: { items: ['mp_m_freemode_01', 'mp_f_freemode_01', 'a_m_m_business_01'] } },
        components: comps.map((id) => ({ component_id: id, drawable: { min: 0, max: maxD[id] }, texture: { min: 0, max: id === 11 ? 7 : 3 }, blacklist: { drawables: [], textures: [] } })),
        props: props.map((id) => ({ prop_id: id, drawable: { min: -1, max: maxP[id] }, texture: { min: -1, max: 4 }, blacklist: { drawables: [], textures: [] } })),
        hair: { style: { min: 0, max: 76 }, color: { items: hairCols }, highlight: { items: hairCols }, texture: { min: 0, max: 0 }, blacklist: { drawables: [], textures: [] } },
        headOverlays: Object.fromEntries(Object.entries(ovs).map(([k, n]) => [k, Object.assign({ style: { min: 0, max: n }, opacity: { min: 0, max: 1 } }, colored.includes(k) ? { color: { items: hairCols } } : {})])),
        tattoos: { items: {
            ZONE_TORSO: ['Turbulence', 'Pilot Skull', 'Winged Bombshell', 'Balloon Pioneer', 'Parachute Belle', 'Bombs Away', 'Eagle Eyes', 'Skull and Sword', 'Dragon', 'Lion'].map((l, i) => ({ name: 'T_' + i, label: l, zone: 'ZONE_TORSO', collection: 'x', hashMale: 'a', hashFemale: 'b' })),
            ZONE_LEFT_ARM: ['Lady Liberty', 'Ace of Spades', 'Snake'].map((l, i) => ({ name: 'L_' + i, label: l, zone: 'ZONE_LEFT_ARM', collection: 'x', hashMale: 'a', hashFemale: 'b' })),
            ZONE_RIGHT_ARM: [], ZONE_HEAD: [], ZONE_LEFT_LEG: [], ZONE_RIGHT_LEG: [],
        } },
    });
    const app = {
        model: 'mp_m_freemode_01',
        headBlend: { shapeFirst: 12, shapeSecond: 21, shapeThird: 0, skinFirst: 12, skinSecond: 21, skinThird: 0, shapeMix: 0.4, skinMix: 0.6, thirdMix: 0 },
        faceFeatures: {},
        headOverlays: Object.fromEntries(Object.keys(ovs).map((k) => [k, { style: 0, opacity: k === 'eyebrows' ? 1 : 0, color: 0, secondColor: 0 }])),
        components: comps.map((id) => ({ component_id: id, drawable: { 11: 15, 8: 15, 4: 21, 6: 34, 3: 15 }[id] || 0, texture: 0 })),
        props: props.map((id) => ({ prop_id: id, drawable: -1, texture: -1 })),
        hair: { style: 12, color: 3, highlight: 3, texture: 0 },
        eyeColor: 3,
        tattoos: { ZONE_TORSO: [{ name: 'T_8', label: 'Dragon', zone: 'ZONE_TORSO', collection: 'x', hashMale: 'a', hashFemale: 'b', opacity: 1 }] },
    };
    const cfg = {
        clothing: { components: true, props: true, enableExit: true },
        uniform: { components: true, props: true, enableExit: true },
        barber: { headOverlays: true, enableExit: true },
        tattoo: { tattoos: true, enableExit: true },
        surgeon: { headBlend: true, faceFeatures: true, enableExit: true },
        creator: { ped: true, headBlend: true, faceFeatures: true, headOverlays: true, components: true, props: true, tattoos: false, enableExit: false },
        wardrobe: { components: true, props: true, enableExit: true },
    }[mode] || {};
    const shop = {
        clothing: { shopType: 'clothing', name: 'متجر ملابس بينكوين', cash: 1250, bank: 8400, prices: { c11: 220, c8: 80, c3: 60, c7: 180, c5: 200, c10: 40, c9: 0, c4: 140, c6: 120, c1: 150, p0: 90, p1: 110, p2: 150, p6: 350, p7: 200 } },
        barber: { shopType: 'barber', cash: 1250, bank: 8400, flatCost: 100 },
        tattoo: { shopType: 'tattoo', cash: 1250, bank: 8400, tattooCost: 100 },
        surgeon: { shopType: 'surgeon', cash: 1250, bank: 8400, flatCost: 500 },
        wardrobe: { shopType: 'wardrobe', wardrobe: true, outfits: [{ id: 1, name: 'بدلة العمل' }, { id: 2, name: 'ملابس السهرة' }, { id: 3, name: 'رياضي' }] },
    }[mode] || {};
    function handle(name, data) {
        switch (name) {
            case 'appearance_get_settings': return Promise.resolve({ appearanceSettings: settings() });
            case 'appearance_get_data': return Promise.resolve({ config: cfg, appearanceData: JSON.parse(JSON.stringify(app)) });
            case 'exti_get_shop': return Promise.resolve(shop);
            case 'appearance_change_component': return Promise.resolve({ component_id: data.component_id, drawable: { min: 0, max: maxD[data.component_id] }, texture: { min: 0, max: (data.drawable % 4) + 1 }, blacklist: { drawables: [], textures: [] } });
            case 'appearance_change_prop': return Promise.resolve({ prop_id: data.prop_id, drawable: { min: -1, max: maxP[data.prop_id] }, texture: { min: -1, max: 3 }, blacklist: { drawables: [], textures: [] } });
            case 'exti_pay_cart': return Promise.resolve({ ok: data.method === 'bank', msg: 'ليس معك مال كافٍ نقدًا', cash: 1250, bank: 8400 });
            case 'appearance_apply_tattoo': return Promise.resolve(true);
            case 'exti_outfit_list': return Promise.resolve({ outfits: [{ id: 1, name: 'بدلة العمل' }, { id: 2, name: 'رياضي' }] });
            case 'exti_outfit_wear': return Promise.resolve({ appearance: JSON.parse(JSON.stringify(app)) });
            case 'exti_outfit_save': if (!shop.outfits) shop.outfits = []; shop.outfits.push({ id: Date.now(), name: data.name }); return Promise.resolve({ outfits: shop.outfits });
            case 'exti_outfit_delete': shop.outfits = shop.outfits.filter((o) => o.id !== data.id); return Promise.resolve({ outfits: shop.outfits });
            default: return Promise.resolve(1);
        }
    }
    window.addEventListener('load', () => {
        document.body.style.background = '#3b4250 radial-gradient(60% 80% at 34% 60%, #5d6676 0%, #2c313b 70%)';
        const bar = $('#devbar'); bar.classList.remove('hidden');
        ['clothing', 'barber', 'tattoo', 'surgeon', 'creator', 'uniform', 'wardrobe'].forEach((m) => {
            const b = h('button', m === mode ? 'on' : '', m); b.onclick = () => { location.search = '?mode=' + m; }; bar.appendChild(b);
        });
        window.postMessage({ type: 'appearance_display' }, '*');
    });
    return { handle };
})();
