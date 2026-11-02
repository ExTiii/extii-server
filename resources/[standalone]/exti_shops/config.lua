-- EX_Tii shops: every 24/7 store, liquor store, tool shop and gun shop.
-- A shopkeeper stands behind the counter, a small gold circle sits in front of the counter,
-- you stand in the circle and press E, and the shop panel opens.
--
-- To move a shopkeeper: stand where he should stand (behind the counter, facing the customers),
-- type /savespot npc and tell EX_Tii which shop it is. The circle moves with him.

Config = {}

Config.circles = false       -- EX_Tii: no gold circle on the floor: walk up to the shopkeeper and press E
Config.reach = 1.3           -- how close to the counter spot you must be to press E (meters)
Config.circleRadius = 0.65   -- the circle's size, only used when Config.circles = true
Config.useDistance = 3.0     -- the server only sells to players this close to the circle (meters)

-- what each kind of shop sells. category: food | medical | tools | weapons | ammo | work
-- max = most you can buy of it at once
Config.types = {
    general = {
        label = 'بقالة 24/7',
        icon = 'store',
        greeting = 'أهلًا بك! خذ راحتك، كل شيء طازج اليوم.',
        clerk = { model = 'mp_m_shopkeep_01' },
        circleDistance = 1.45, -- how far in front of the shopkeeper the circle is (across the counter)
        blip = { sprite = 59, colour = 3 }, -- EX_Tii map icon plan: shopping = blue
        products = {
            { name = 'burger', price = 10, category = 'food' },
            { name = 'water', price = 10, category = 'food' },
            { name = 'sprunk', price = 10, category = 'food' },
            { name = 'redbull', price = 50, category = 'food', max = 10 }, -- 1 minute of sprinting without getting tired
            -- EX_Tii: no bandage here any more: medicine is sold at the two hospital pharmacies
            -- EX_Tii level jobs (exti_jobs): the supplies used up every run
            { name = 'poultry_kit', price = 3, category = 'work', max = 25, desc = 'لوظيفة الدواجن: كل عدة = دجاجة واحدة' },
            { name = 'grape_kit', price = 3, category = 'work', max = 30, desc = 'لوظيفة الزبيب: كل عدة = عنقود واحد' },
        },
    },

    -- the store at a gas station: 24/7 items. No map icon of its own:
    -- the gas station icon (exti_fuel) shows the station and its store together.
    -- EX_Tii: the jerry can is NOT sold here any more. It is bought at the pump (exti_fuel pump screen).
    fuel = {
        label = 'متجر المحطة',
        icon = 'store',
        greeting = 'أهلًا! عبّئ مركبتك وخذ ما تحتاجه للطريق.',
        clerk = { model = 'mp_m_shopkeep_01' },
        circleDistance = 1.45,
        blip = false,
        products = {
            { name = 'burger', price = 10, category = 'food' },
            { name = 'water', price = 10, category = 'food' },
            { name = 'sprunk', price = 10, category = 'food' },
            { name = 'redbull', price = 50, category = 'food', max = 10 },
        },
    },

    liquor = {
        label = 'متجر المشروبات',
        icon = 'bottle',
        greeting = 'مرحبًا! المشروبات باردة والأسعار حلوة.',
        clerk = { model = 'mp_m_shopkeep_01' },
        circleDistance = 1.45,
        blip = { sprite = 93, colour = 3 },
        products = {
            { name = 'water', price = 10, category = 'food' },
            { name = 'sprunk', price = 10, category = 'food' },
            { name = 'redbull', price = 50, category = 'food', max = 10 },
            { name = 'burger', price = 15, category = 'food' },
        },
    },

    tools = {
        label = 'متجر العدد',
        icon = 'wrench',
        greeting = 'أهلًا يا صديقي! عندنا كل ما تحتاجه للتصليح.',
        clerk = { model = 's_m_m_lathandy_01' },
        circleDistance = 1.45,
        blip = { sprite = 402, colour = 3 },
        products = {
            -- EX_Tii: repair kits are for mechanics only now (they get them at the workshop)
            -- EX_Tii gangs: no lockpicks in shops any more (only the Chop Shop gang makes them)
            { name = 'screwdriverset', price = 120, category = 'tools', max = 2 },
            { name = 'binoculars', price = 250, category = 'tools', max = 1 },
            { name = 'lighter', price = 15, category = 'tools', max = 3 },
            -- EX_Tii gangs: turf graffiti
            { name = 'spray_can', price = 150, category = 'tools', max = 5 },
            { name = 'weed_nutrition', price = 60, category = 'tools', max = 5 },   -- (the Weed gang's fertilizer)
            { name = 'scrub_brush', price = 40, category = 'tools', max = 2, metadata = { uses = 3, description = 'استعمالات متبقية: 3' } },
        },
    },

    ammunation = {
        label = 'متجر الأسلحة',
        icon = 'target',
        greeting = 'أهلًا بك في أمونيشن. السلاح الناري يحتاج رخصة سلاح.',
        clerk = { model = 's_m_y_ammucity_01' },
        circleDistance = 1.6,
        blip = false, -- no map icon (map cleanup)
        products = {
            -- EX_Tii gun rework: the legal guns (weapon licence, the serial is registered to the buyer)
            { name = 'WEAPON_SNSPISTOL', price = 1125, category = 'weapons', max = 1, license = 'weapon', metadata = { registered = true } },
            { name = 'WEAPON_PISTOL', price = 1800, category = 'weapons', max = 1, license = 'weapon', metadata = { registered = true } },
            { name = 'WEAPON_VINTAGEPISTOL', price = 2250, category = 'weapons', max = 1, license = 'weapon', metadata = { registered = true } },
            { name = 'WEAPON_PUMPSHOTGUN', price = 3750, category = 'weapons', max = 1, license = 'weapon', metadata = { registered = true } },
            { name = 'WEAPON_MUSKET', price = 2700, category = 'weapons', max = 1, license = 'weapon', metadata = { registered = true } },
            -- melee (no licence)
            { name = 'WEAPON_KNIFE', price = 300, category = 'melee', max = 1 },
            { name = 'WEAPON_SWITCHBLADE', price = 270, category = 'melee', max = 1 },
            { name = 'WEAPON_MACHETE', price = 300, category = 'melee', max = 1 },
            { name = 'WEAPON_HATCHET', price = 225, category = 'melee', max = 1 },
            { name = 'WEAPON_BAT', price = 150, category = 'melee', max = 1 },
            { name = 'WEAPON_GOLFCLUB', price = 180, category = 'melee', max = 1 },
            { name = 'WEAPON_CROWBAR', price = 120, category = 'melee', max = 1 },
            { name = 'WEAPON_HAMMER', price = 90, category = 'melee', max = 1 },
            { name = 'WEAPON_WRENCH', price = 90, category = 'melee', max = 1 },
            { name = 'WEAPON_KNUCKLE', price = 300, category = 'melee', max = 1 },
            -- ammo: a little per player per day (the rest comes from the Ammo gang)
            { name = 'ammo-9', price = 8, category = 'ammo', max = 60, step = 10, daily = 60 },
            { name = 'ammo-45', price = 8, category = 'ammo', max = 36, step = 6, daily = 36 },
            { name = 'ammo-shotgun', price = 12, category = 'ammo', max = 24, step = 6, daily = 24 },
            { name = 'ammo-musket', price = 15, category = 'ammo', max = 20, step = 5, daily = 20 },
            -- legal attachments (the rest only from the Weapons gang)
            { name = 'at_flashlight', price = 225, category = 'parts', max = 1 },
            { name = 'at_grip', price = 340, category = 'parts', max = 1 },
            -- a service: fixes the most worn legal gun you carry (not gang guns with no serial)
            { name = 'gun_repair', price = 450, category = 'services', max = 1, service = 'repair' },
        },
    },
}

-- clothing, barber and tattoo shops: same shopkeeper + circle + E, then the appearance menu opens
-- (illenium-appearance does the clothes, hair and tattoos and takes the money)
Config.types.clothing = {
    label = 'متجر الملابس',
    opens = 'clothing',
    prompt = '[E] تحدّث مع البائعة',
    clerk = { model = 's_f_m_shop_high' },
    circleDistance = 1.4,
    blip = { sprite = 73, colour = 8 }, -- EX_Tii map icon plan: your look = pink, t-shirt icon
}
Config.types.barber = {
    label = 'الحلاق',
    opens = 'barber',
    prompt = '[E] تحدّث مع الحلاق',
    clerk = { model = 's_m_m_hairdress_01' },
    circleDistance = 1.3,
    blip = { sprite = 71, colour = 8 },
}
Config.types.tattoo = {
    label = 'محل الوشم',
    opens = 'tattoo',
    prompt = '[E] تحدّث مع فنان الوشم',
    clerk = { model = 'u_m_y_tattoo_01' },
    circleDistance = 1.3,
    blip = { sprite = 75, colour = 8 },
}

-- banks: a teller behind the counter + circle; E opens your bank account (exti_bank tablet).
-- At the two big banks (manage = true) you can also open and manage shared accounts.
Config.types.bank = {
    label = 'البنك',
    opens = 'bank',
    prompt = '[E] تحدّث مع موظف البنك',
    clerk = { model = 'ig_barry' },
    circleDistance = 1.4,
    blip = { sprite = 108, colour = 2 },
}

-- EX Mart: the server's own store brand (black and gold). Sells the same things as a 24/7.
-- For now only Don's Country Store in Paleto (its signs and posters were redone as EX Mart).
Config.types.exmart = {
    label = 'إكس مارت',
    icon = 'store',
    greeting = 'أهلًا بك في إكس مارت! خذ راحتك، كل شيء طازج اليوم.',
    clerk = { model = 'mp_m_shopkeep_01' },
    circleDistance = 1.45,
    blip = { sprite = 59, colour = 3 },
    products = Config.types.general.products,
}

-- EX_Tii hospitals (open 24/7, the staff never leave):
-- the receptionist opens the hospital panel (exti_hospital): free treatment in a bed, a free check-up
-- with a medical report, call a medic. The pharmacist sells the medicine (the only place that does).
Config.types.hospital = {
    label = 'المستشفى',
    opens = 'hospital',
    prompt = '[E] تحدّث مع موظفة الاستقبال',
    clerk = { model = 's_f_y_scrubs_01' },
    circleDistance = 1.6,
    blip = { sprite = 61, colour = 1 }, -- hospital icon, red
}
Config.types.pharmacy = {
    label = 'صيدلية المستشفى',
    icon = 'pharmacy',
    clerkTitle = 'الصيدلي',
    prompt = '[E] تحدّث مع الصيدلي',
    greeting = 'أهلًا بك! مفتوحون 24 ساعة، كيف أقدر أساعدك؟',
    clerk = { model = 's_m_m_doctor_01' },
    circleDistance = 1.6,
    blip = false, -- the hospital icon shows it
    products = {
        -- desc = the short line under the name in the shop panel
        { name = 'gauze', price = 50, category = 'medical', max = 20, desc = 'يعيد ربع صحتك خلال 3 ثوانٍ' },
        { name = 'painkillers', price = 75, category = 'medical', max = 10, desc = 'يعيد صحتك شيئًا فشيئًا خلال 40 ثانية' },
        { name = 'medikit', price = 300, category = 'medical', max = 3, desc = 'يعيد صحتك كاملة، يحتاج 10 ثوانٍ وأنت واقف' },
    },
}

-- every shop: type, area name, and where the shopkeeper stands (x, y, z, heading = the way he faces)
Config.stores = {
    -- 24/7
    { type = 'general', area = 'ستروبيري', clerk = vec4(24.47, -1346.62, 29.50, 271.66) },
    { type = 'general', area = 'بانهام كانيون', clerk = vec4(-3039.54, 584.38, 7.91, 17.27) },
    { type = 'general', area = 'تشوماش', clerk = vec4(-3242.97, 1000.01, 12.83, 357.57) },
    { type = 'general', area = 'هارموني', clerk = vec4(549.13, 2670.85, 42.16, 99.39) },
    { type = 'general', area = 'داون تاون فاينوود', clerk = vec4(372.66, 326.98, 103.57, 253.73) },
    -- EX Mart (was Don's Country Store), Paleto: its inside comes from the map [assets]/patoche_paleto (GTA has it closed).
    -- The spot is worked out from that map: behind the counter, between the two tills, facing the door.
    { type = 'exmart', area = 'باليتو', clerk = vec4(161.11, 6642.40, 31.70, 225.0) },

    -- hospitals: the spots come from the hospital maps (behind each counter, facing the customers).
    -- hospital = the name of that hospital in qbx_ambulancejob (its beds, its check-in)
    { type = 'hospital', area = 'بيلبوكس', hospital = 'pillbox', clerk = vec4(308.60, -596.77, 43.33, 17.0) },
    { type = 'pharmacy', area = 'بيلبوكس', clerk = vec4(316.60, -587.06, 43.33, 180.0), circleDistance = 1.45 }, -- the hospital gift shop
    { type = 'hospital', area = 'باليتو', hospital = 'paleto', clerk = vec4(-255.37, 6330.41, 32.42, 315.0) },
    { type = 'pharmacy', area = 'باليتو', clerk = vec4(-256.93, 6331.97, 32.42, 315.0) }, -- same counter, the other end

    -- gas station stores (the station icon shows them)
    { type = 'fuel', area = 'باليتو', clerk = vec4(1728.07, 6415.63, 35.04, 242.95) },
    { type = 'fuel', area = 'غريبسيد', clerk = vec4(1697.87, 4922.96, 42.06, 324.71) },
    { type = 'fuel', area = 'ساندي شورز', clerk = vec4(1959.82, 3740.48, 32.34, 301.57) },
    { type = 'fuel', area = 'صحراء سينورا', clerk = vec4(2677.47, 3279.76, 55.24, 335.08) },
    { type = 'fuel', area = 'تاتافيام', clerk = vec4(2556.66, 380.84, 108.62, 356.67) },
    { type = 'fuel', area = 'غروف ستريت', clerk = vec4(-47.02, -1758.23, 29.42, 45.05) },
    { type = 'fuel', area = 'ليتل سيول', clerk = vec4(-706.06, -913.97, 19.22, 88.04) },
    { type = 'fuel', area = 'ريتشمان غلين', clerk = vec4(-1820.02, 794.03, 138.09, 135.45) },
    { type = 'fuel', area = 'ميرور بارك', clerk = vec4(1164.71, -322.94, 69.21, 101.72) },

    -- liquor stores
    { type = 'liquor', area = 'إل رانشو', clerk = vec4(1134.35, -982.38, 46.41, 273.7) },
    { type = 'liquor', area = 'فسبوتشي', clerk = vec4(-1222.01, -908.27, 12.33, 35.0) },
    { type = 'liquor', area = 'مورنينغوود', clerk = vec4(-1486.23, -378.13, 40.16, 126.2) },
    { type = 'liquor', area = 'بانهام كانيون', clerk = vec4(-2966.45, 390.90, 15.04, 89.5) },
    { type = 'liquor', area = 'طريق 68', clerk = vec4(1165.92, 2710.75, 38.16, 183.3) },
    { type = 'liquor', area = 'ساندي شورز', clerk = vec4(1392.81, 3606.47, 34.98, 200.0) },

    -- tool shop
    { type = 'tools', area = 'صحراء سينورا', clerk = vec4(2746.25, 3473.19, 55.67, 263.8) },

    -- gun shops
    { type = 'ammunation', area = 'ليتل سيول', clerk = vec4(-661.96, -933.53, 21.83, 177.05) },
    { type = 'ammunation', area = 'سايبرس فلاتس', clerk = vec4(809.68, -2159.13, 29.62, 1.43) },
    { type = 'ammunation', area = 'ساندي شورز', clerk = vec4(1692.67, 3761.38, 34.71, 227.65) },
    { type = 'ammunation', area = 'باليتو', clerk = vec4(-331.23, 6085.37, 31.45, 228.02) },
    { type = 'ammunation', area = 'هاويك', clerk = vec4(253.63, -51.02, 69.94, 72.91) },
    { type = 'ammunation', area = 'بيلبوكس هيل', clerk = vec4(23.00, -1105.67, 29.80, 162.91) },
    { type = 'ammunation', area = 'تاتافيام', clerk = vec4(2567.48, 292.59, 108.73, 349.68) },
    { type = 'ammunation', area = 'طريق 68', clerk = vec4(-1118.59, 2700.05, 18.55, 221.89) },
    { type = 'ammunation', area = 'لا ميسا', clerk = vec4(841.92, -1035.32, 28.19, 1.56) },

    -- clothing stores
    { type = 'clothing', area = 'غريبسيد', clerk = vec4(1693.2, 4828.11, 42.07, 188.66) },
    { type = 'clothing', area = 'روكفورد هيلز', clerk = vec4(-705.5, -149.22, 37.42, 122.0) },
    { type = 'clothing', area = 'ديل بيرو', clerk = vec4(-1192.61, -768.4, 17.32, 216.6) },
    { type = 'clothing', area = 'تكستايل سيتي', clerk = vec4(425.91, -801.03, 29.49, 177.79) },
    { type = 'clothing', area = 'بيرتون', clerk = vec4(-168.73, -301.41, 39.73, 238.67) },
    { type = 'clothing', area = 'ستروبيري', clerk = vec4(75.39, -1398.28, 29.38, 6.73) },
    { type = 'clothing', area = 'فسبوتشي', clerk = vec4(-827.39, -1075.93, 11.33, 294.31) },
    { type = 'clothing', area = 'مورنينغوود', clerk = vec4(-1445.86, -240.78, 49.82, 36.17) },
    { type = 'clothing', area = 'باليتو', clerk = vec4(9.22, 6515.74, 31.88, 131.27) },
    { type = 'clothing', area = 'هارموني', clerk = vec4(615.35, 2762.72, 42.09, 170.51) },
    { type = 'clothing', area = 'طريق 68', clerk = vec4(1191.61, 2710.91, 38.22, 269.96) },
    { type = 'clothing', area = 'تشوماش', clerk = vec4(-3171.32, 1043.56, 20.86, 334.3) },
    { type = 'clothing', area = 'زانكودو', clerk = vec4(-1105.52, 2707.79, 19.11, 317.19) },
    { type = 'clothing', area = 'هاويك', clerk = vec4(124.82, -224.36, 54.56, 335.41) },

    -- barbers
    { type = 'barber', area = 'روكفورد هيلز', clerk = vec4(-814.22, -183.7, 37.57, 116.91) },
    { type = 'barber', area = 'دايفس', clerk = vec4(136.78, -1708.4, 29.29, 144.19) },
    { type = 'barber', area = 'شاطئ فسبوتشي', clerk = vec4(-1282.57, -1116.84, 6.99, 89.25) },
    { type = 'barber', area = 'ساندي شورز', clerk = vec4(1931.41, 3729.73, 32.84, 212.08) },
    { type = 'barber', area = 'ميرور بارك', clerk = vec4(1212.8, -472.9, 65.2, 60.94) },
    { type = 'barber', area = 'هاويك', clerk = vec4(-32.9, -152.3, 56.1, 335.22) },
    { type = 'barber', area = 'باليتو', clerk = vec4(-278.1, 6228.5, 30.7, 49.32) },

    -- tattoo shops
    { type = 'tattoo', area = 'إل بورو هايتس', clerk = vec4(1322.6, -1651.9, 51.2, 42.47) },
    { type = 'tattoo', area = 'فسبوتشي', clerk = vec4(-1154.01, -1425.31, 4.95, 23.21) },
    { type = 'tattoo', area = 'فاينوود', clerk = vec4(322.62, 180.34, 103.59, 156.2) },
    { type = 'tattoo', area = 'تشوماش', clerk = vec4(-3169.52, 1074.86, 20.83, 253.29) },
    { type = 'tattoo', area = 'ساندي شورز', clerk = vec4(1864.1, 3747.91, 33.03, 17.23) },
    { type = 'tattoo', area = 'باليتو', clerk = vec4(-294.24, 6200.12, 31.49, 195.72) },

    -- banks
    { type = 'bank', area = 'باسيفيك ستاندرد', clerk = vec4(241.44, 227.19, 106.29, 170.43), model = 'u_m_m_bankman', manage = true },
    { type = 'bank', area = 'هاويك', clerk = vec4(313.84, -280.58, 54.16, 338.31) },
    { type = 'bank', area = 'ليجن سكوير', clerk = vec4(149.46, -1042.09, 29.37, 335.43) },
    { type = 'bank', area = 'بيرتون', clerk = vec4(-351.23, -51.28, 49.04, 341.73) },
    { type = 'bank', area = 'ديل بيرو', clerk = vec4(-1211.9, -331.9, 37.78, 20.07) },
    { type = 'bank', area = 'المحيط الكبير', clerk = vec4(-2961.14, 483.09, 15.7, 83.84) },
    { type = 'bank', area = 'طريق 68', clerk = vec4(1174.8, 2708.2, 38.09, 178.52) },
    { type = 'bank', area = 'باليتو', clerk = vec4(-112.22, 6471.01, 31.63, 134.18), model = 'u_m_m_bankman', manage = true },
}

---------------------------------------------------------------------------
-- E only (no shopkeeper, no circle): walk up and press E
---------------------------------------------------------------------------
Config.atmModels = { `prop_atm_01`, `prop_atm_02`, `prop_atm_03`, `prop_fleeca_atm` }
Config.vendingModels = { `prop_vend_soda_02`, `prop_vend_fridge01`, `prop_vend_water_01`, `prop_vend_soda_01` }

-- jobs = only these jobs see it. radius = how close you must be (meters)
-- e.g. { prompt = '[E] افتح خزانتك الشخصية', coords = vec3(451.25, -994.28, 30.69), radius = 2.6, jobs = { 'police' }, action = 'stash', stash = 'policelocker' }
-- EX_Tii: the police and EMS lockers, evidence and medicine cabinet are off until we build our own
-- police and EMS systems.
Config.points = {}

--- where a shop's gold circle is: straight in front of the shopkeeper, across the counter
---@param store table
---@return vector3
function Config.circleOf(store)
    local c = store.clerk
    if store.circle then return store.circle end
    local kind = Config.types[store.type]
    local d = store.circleDistance or (kind and kind.circleDistance) or 1.45
    local h = math.rad(c.w or 0.0)
    return vec3(c.x - math.sin(h) * d, c.y + math.cos(h) * d, c.z)
end
