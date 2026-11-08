-- =====================================================================
-- EX_Tii Mechanic (الميكانيكي) — the workshop (like the video): clock in at the desk, the cloakroom
-- (work clothes), your personal locker, the tool storage (by rank), the garage with the service
-- trucks and cars and their trunks, the public forms (customers fill them at the counter, the team
-- reads them on the tablet), the tablet (map, chat, calendar, camera, forms, management, billing
-- presets) and the bill sheet (the customer gets a bill in his bank, the money goes to the workshop).
-- Everything is an E spot: no NPCs.
-- =====================================================================

Config = {}

Config.job = 'mechanic'           -- the qbx_core job (grades and pay are in qbx_core/shared/jobs.lua)
Config.offDutyOnLogin = true      -- mechanics always start a session off duty (they clock in at the workshop)

-- where things are in each workshop. Admins can move any spot in game with /mechspots (stand
-- where you want it, pick the spot, done: it is saved in data/spots.json and wins over the numbers
-- here). The numbers below are for the normal GTA Los Santos Customs in Burton.
--   duty      = the desk computer: clock in / out
--   cloakroom = the work clothes
--   locker    = your personal locker (the same locker in every workshop)
--   armory    = the tool storage (free, each rank gets its own list)
--   forms     = the public forms (anyone: job application, complaint, service request)
--   evidence  = the parts shelf (parts and things taken off customers' vehicles land here)
--   garage    = the service units garage: tow trucks, flatbeds, vans (spawn = where the vehicle appears)
--   cars      = the car garage: the workshop's cars (like the video: one garage for cars, one for service units)
--   delivery  = where the boxes from the parts shop arrive
Config.stations = {
    -- Benny's Original Motor Works, Strawberry (the workshop in the video). The spots are a first
    -- guess (not checked in game): stand where each one belongs and use /mechspots to place it.
    bennys = {
        label = 'ورشة بيني',
        duty = vec3(-208.00, -1330.50, 30.89),
        cloakroom = vec3(-215.50, -1331.50, 30.89),
        locker = vec3(-217.50, -1329.00, 30.89),
        armory = vec3(-219.00, -1325.50, 30.89),
        forms = vec3(-205.50, -1319.50, 30.89),
        evidence = vec3(-218.50, -1321.50, 30.89),
        garage = { coords = vec3(-190.50, -1302.00, 31.30), spawn = vec4(-190.50, -1302.00, 31.30, 90.0) },
        cars = { coords = vec3(-190.50, -1310.00, 31.30), spawn = vec4(-190.50, -1310.00, 31.30, 90.0) },
        -- where the parts shop's boxes arrive (move it with /mechspots → نقطة استلام القطع)
        delivery = vec3(-224.00, -1309.00, 30.89),
        -- the two tuning bays: the customer drives in and picks his upgrades (first guess too:
        -- /mechspots → منصة التعديل 1 / 2)
        tune1 = vec3(-211.55, -1324.55, 30.90),
        tune2 = vec3(-199.50, -1324.50, 30.90),
        -- the dyno: the car stands on it while the mechanic runs the test from the tablet
        -- (first guess: /mechspots → الداينو)
        dyno = vec3(-205.00, -1316.00, 30.90),
    },
}

-- locked doors (none in the workshop by default; same format as the police: id, label, model, coords, minGrade)
Config.doors = {}

-- the workshop icon on the map (everyone sees it)
Config.blip = { sprite = 446, color = 5, scale = 0.72 }

-- your personal locker: only you can open it, the same one in every workshop
Config.locker = { label = 'خزانتك الشخصية', slots = 10, weight = 60000 }

-- the tool storage (مستودع الأدوات): free, each rank sees its own list (the rest is greyed out).
-- grade = from this rank up (0 متدرب, 1 ميكانيكي, 2 فني, 3 مشرف, 4 مدير). max = how many a mechanic
-- can carry. Nothing here gets a serial: tools may be put down and handed over.
Config.armory = {
    label = 'مستودع الأدوات',
    perDay = 3,                   -- each mechanic can take each thing up to 3 times its max per day
    items = {
        { name = 'repairkit', grade = 0, max = 3 },
        { name = 'cleaningkit', grade = 0, max = 2 },
        { name = 'screwdriverset', grade = 0, max = 1 },
        { name = 'advancedrepairkit', grade = 1, max = 2 },
        { name = 'WEAPON_FLASHLIGHT', grade = 0 },
        { name = 'WEAPON_WRENCH', grade = 0 },
    },
}

-- the uniforms the cloakroom starts with (the first time only; after that the leader adds, edits
-- and deletes them in game and they are saved in the database).
-- components = { component id, drawable, texture }  (1 mask, 3 arms, 4 trousers, 5 bag, 6 shoes,
-- 7 neck, 8 undershirt, 9 vest, 10 badges, 11 shirt/jacket);  props = { prop id, drawable, texture }
-- (0 hat, -1 = none);  grades = which ranks can wear it
Config.defaultOutfits = {
    male = {
        -- dark overalls, work boots (the leader edits these in game)
        { label = 'أفرول الورشة', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 38, 0 }, { 3, 64, 0 }, { 8, 15, 0 }, { 9, 0, 0 }, { 11, 65, 0 }, { 6, 25, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'قميص الورشة', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 98, 0 }, { 3, 1, 0 }, { 8, 15, 0 }, { 9, 0, 0 }, { 11, 63, 0 }, { 6, 51, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, 5, 0 } } },
        { label = 'زي المشرف', grades = { 3, 4 },
          components = { { 4, 24, 0 }, { 3, 4, 0 }, { 8, 15, 0 }, { 9, 0, 0 }, { 11, 26, 0 }, { 6, 10, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
    },
    female = {
        { label = 'أفرول الورشة', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 33, 0 }, { 3, 73, 0 }, { 8, 14, 0 }, { 9, 0, 0 }, { 11, 53, 0 }, { 6, 25, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'قميص الورشة', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 95, 0 }, { 3, 1, 0 }, { 8, 14, 0 }, { 9, 0, 0 }, { 11, 49, 0 }, { 6, 52, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, 4, 0 } } },
        { label = 'زي المشرفة', grades = { 3, 4 },
          components = { { 4, 23, 0 }, { 3, 3, 0 }, { 8, 14, 0 }, { 9, 0, 0 }, { 11, 7, 0 }, { 6, 29, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
    },
}
Config.maxOutfits = 12            -- per men / women

-- the workshop's vehicles (the fleet): every vehicle has its own plate and its own trunk that keeps
-- the tools you leave in it between shifts. The leader buys / sells vehicles (with the workshop
-- account in the bank) and can change a plate (free) in the garage.
Config.fleet = {
    plate = 'MECH',              -- new plates: MECH + 4 letters/numbers
    trunk = { slots = 30, weight = 200000 },
    sellBack = 0.5,              -- selling a vehicle gives back this much of its price
    max = 15,                    -- how many vehicles the workshop can own
    models = {
        flatbed = { label = 'سطحة', kind = 'ground', price = 45000 },
        towtruck2 = { label = 'ونش صغير', kind = 'ground', price = 30000 },
        towtruck = { label = 'ونش كبير', kind = 'ground', price = 38000 },
        utillitruck3 = { label = 'شاحنة خدمة', kind = 'ground', price = 22000 },
        burrito3 = { label = 'فان الورشة', kind = 'ground', price = 18000 },
        speedo = { label = 'فان صغير', kind = 'ground', price = 15000 },
        bison = { label = 'بيك أب', kind = 'ground', price = 20000 },
        -- the car garage (kind = 'car')
        sultan = { label = 'سلطان', kind = 'car', price = 24000 },
        kuruma = { label = 'كوروما', kind = 'car', price = 30000 },
        buffalo = { label = 'بافالو', kind = 'car', price = 28000 },
        blista = { label = 'بليستا', kind = 'car', price = 12000 },
    },
    start = { 'flatbed', 'towtruck2', 'burrito3', 'sultan' }, -- what the workshop has the first time
}

-- the public forms: customers fill them at the counter, the team reads them on the tablet.
-- fields: id, label, required, type = 'area' (a big box), max = how many letters
Config.forms = {
    cooldown = 300,               -- seconds between two forms from the same citizen
    maxOpen = 3,                  -- a citizen can have this many forms nobody has looked at yet
    keep = 300,                   -- the inbox shows the newest this many
    archiveGrade = 2,             -- archive from this rank up (2 = فني)
    types = {
        { id = 'application', prefix = 'APP', icon = 'application', label = 'طلب توظيف', desc = 'قدّم للعمل في الورشة', fields = {
            { id = 'name', label = 'الاسم الكامل', required = true },
            { id = 'dob', label = 'تاريخ الميلاد' },
            { id = 'phone', label = 'رقم الهاتف' },
            { id = 'availability', label = 'الأوقات المتاحة', placeholder = 'الأيام والساعات' },
            { id = 'experience', label = 'الخبرة', type = 'area', placeholder = 'عمل سابق في ورش أو تعديل سيارات' },
            { id = 'why', label = 'لماذا تريد الانضمام؟', type = 'area', required = true },
        } },
        { id = 'complaint', prefix = 'CMP', icon = 'complaint', label = 'شكوى', desc = 'على خدمة أو على أحد عمّال الورشة', fields = {
            { id = 'name', label = 'الاسم الكامل', required = true },
            { id = 'phone', label = 'رقم الهاتف' },
            { id = 'against', label = 'ضد من؟', placeholder = 'اسم الميكانيكي إن عرفته' },
            { id = 'when', label = 'متى وأين؟' },
            { id = 'what', label = 'ماذا حدث؟', type = 'area', required = true },
        } },
        { id = 'request', prefix = 'REQ', icon = 'request', label = 'طلب خدمة', desc = 'اطلب تصليحًا أو تعديلًا لمركبتك', fields = {
            { id = 'name', label = 'الاسم الكامل', required = true },
            { id = 'phone', label = 'رقم الهاتف', required = true },
            { id = 'plate', label = 'لوحة المركبة', required = true, max = 10 },
            { id = 'vehicle', label = 'نوع المركبة' },
            { id = 'what', label = 'ماذا تريد؟', type = 'area', required = true, placeholder = 'تصليح، صيانة، صبغ، تعديل...' },
        } },
    },
}

-- =====================================================================
-- the mechanic tablet (like the video): F6 on duty. Home screen with the apps, held in your hands,
-- its screen shown live on the tablet. Other players see a locked screen.
-- =====================================================================
Config.tabletKey = 'F6'           -- the same key as the police / EMS tablets (each job only gets its own)
Config.tablet = {
    prop = `prop_cs_tablet`,
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base',
    bone = 60309, pos = vec3(0.03, 0.002, -0.0), rot = vec3(10.0, 160.0, 0.0),
    screenW = 1220, screenH = 776,   -- the size of the screen page (do not change)
    screen = { face = -1, push = 0.0015, insetLong = 0.050, insetShort = 0.070, scale = 1.000, shiftLong = 0.0040, shiftShort = 0.0000, rot = 2, mirror = false, w = 1.0, both = true },
    othersDistance = 20.0,           -- other mechanics' tablets show a locked screen within this distance
}

-- the tablet apps
Config.chat = { maxText = 500, history = 100 }   -- letters per message, messages shown per chat
Config.calendarColors = { '#3b8cf0', '#f29b38', '#2fb36a', '#e0566b', '#9b6cf0', '#22c7b8' } -- the first one is picked by default
Config.bonusMax = 50000           -- the leader's bonus to one mechanic at a time (from the workshop account)
Config.salaryMax = 250            -- the highest salary the leader can set for a rank (every paycheck = 10 min). EX_Tii economy: max $1,500/hour on duty

Config.reachPoint = 1.6           -- how close to an E spot you must be (meters)
Config.vehicleReach = 4.0         -- in a workshop vehicle: how close to the garage to return it

-- the small white circle on the floor at every spot (mechanics see them; everyone sees the forms one)
Config.circle = { size = 1.0, color = { 255, 255, 255 }, distance = 20.0 }

-- the bill sheet (the Z wheel → الورشة → فاتورة, next to the customer): the mechanic ticks the
-- services, the total lands as a bill in the customer's bank (exti_bank), he pays it at the teller,
-- the ATM or the phone and the money goes to the workshop account.
-- The list below is only the starting list: after the first start it lives in the database and the
-- manager edits it on the tablet (الإدارة → قوالب الفواتير).
Config.charges = {
    jail = false,            -- a workshop bill never has jail time (hides those buttons)
    maxFine = 100000,        -- the biggest price one service may carry
    maxJail = 0,
    maxPicks = 12,           -- how many services one bill may hold
    noteLength = 160,        -- the mechanic's note on the bill
    defaults = {
        -- { label, category, price $, 0 }
        { 'فحص المركبة', 'صيانة', 100, 0 },
        { 'تغيير زيت المحرك', 'صيانة', 250, 0 },
        { 'تغيير سائل التبريد', 'صيانة', 200, 0 },
        { 'تغيير فلتر الهواء', 'صيانة', 150, 0 },
        { 'تغيير شمعات الإشعال', 'صيانة', 300, 0 },
        { 'تغيير فحمات الفرامل', 'صيانة', 400, 0 },
        { 'تغيير سائل الفرامل', 'صيانة', 200, 0 },
        { 'تغيير القابض (الكلتش)', 'صيانة', 900, 0 },
        { 'تغيير إطار', 'إطارات', 250, 0 },
        { 'تغيير 4 إطارات', 'إطارات', 900, 0 },
        { 'إصلاح الهيكل', 'تصليح', 600, 0 },
        { 'إصلاح المحرك', 'تصليح', 1200, 0 },
        { 'إصلاح كامل', 'تصليح', 2000, 0 },
        { 'سحب المركبة (ونش)', 'تصليح', 400, 0 },
        { 'غسيل', 'تنظيف', 100, 0 },
        { 'غسيل وتلميع (واكس)', 'تنظيف', 250, 0 },
        { 'صبغ كامل', 'تعديل', 1500, 0 },
        { 'تركيب نيون', 'تعديل', 800, 0 },
        { 'تعديل أداء (مرحلة 1)', 'تعديل', 5000, 0 },
        { 'تعديل أداء (مرحلة 2)', 'تعديل', 12000, 0 },
        { 'تركيب نيتروز', 'تعديل', 8000, 0 },
    },
}

-- =====================================================================
-- SERVICE (part B): wear, diagnostics, repairs with mini-games, wash/wax, the parts shop
-- =====================================================================
-- Every car wears while it is driven (player cars, job cars, street cars). Cars people own and
-- job cars (police / EMS / mechanic fleets) keep their condition in the database; a street car
-- keeps it while the server runs.
-- life = km of driving until the part is at 0% (a city hour of driving is about 40-60 km, so the
-- oil lasts about 3 real hours of driving). Hard driving (very fast) wears up to 1.5x faster.
Config.service = {
    -- the parts of a petrol car. part = the item that replaces it, count = how many,
    -- game = the mini-game recipe (see Config.service.recipes)
    components = {
        { id = 'engine_oil',  label = 'زيت المحرك',       life = 150, part = 'engine_oil',         count = 1, game = 'oil',     ice = true },
        { id = 'air_filter',  label = 'فلتر الهواء',       life = 250, part = 'air_filter',         count = 1, game = 'filter',  ice = true },
        { id = 'coolant',     label = 'سائل التبريد',      life = 220, part = 'coolant',            count = 1, game = 'pour',    ice = true, ev = true },
        { id = 'spark_plugs', label = 'شمعات الإشعال',     life = 300, part = 'spark_plugs',        count = 1, game = 'plugs',   ice = true },
        { id = 'brake_pads',  label = 'فحمات الفرامل',     life = 180, part = 'brake_pads',         count = 1, game = 'brakes',  ice = true, ev = true },
        { id = 'brake_fluid', label = 'سائل الفرامل',      life = 350, part = 'brake_fluid',        count = 1, game = 'pour',    ice = true, ev = true },
        { id = 'clutch',      label = 'القابض (الكلتش)',   life = 400, part = 'clutch_kit',         count = 1, game = 'clutch',  ice = true },
        { id = 'trans_fluid', label = 'زيت ناقل الحركة',   life = 350, part = 'transmission_fluid', count = 1, game = 'pour',    ice = true },
        { id = 'tires',       label = 'الإطارات',          life = 200, part = 'car_tire',           count = 4, game = 'wheels',  ice = true, ev = true },
        -- electric cars only
        { id = 'battery',     label = 'البطارية',          life = 400, part = 'ev_battery',         count = 1, game = 'battery', ev = true },
        { id = 'motor',       label = 'المحرك الكهربائي',  life = 500, part = 'ev_motor',           count = 1, game = 'clutch',  ev = true },
    },
    -- a street car nobody owns starts somewhere in this range (%)
    streetStart = { 55, 100 },
    -- how often the driver's game reports the distance (seconds) and the database is written (seconds)
    reportEvery = 20, saveEvery = 60,
    -- when the effects start (%)
    warnAt = 15,           -- below this: the part starts to misbehave (misfires, weak brakes, slipping clutch)
    -- how close the mechanic must be to the car (metres)
    reach = 4.0,
    -- wash / wax
    washItem = 'car_soap', waxItem = 'car_wax',
    waxHours = 6,          -- a waxed car gets dirty much more slowly for this many real hours
    -- the steps of every repair. pour = fill to the green line; torque = stop the needle in the green
    -- (one per bolt); keys = press the keys shown; hold = hold SPACE until the bar is full;
    -- skill = ox_lib skill check; wait = a progress bar; scrub = wash with the mouse
    -- EX_Tii (Moe): ONE small game per job, nothing more (no chains of 3-4 games)
    recipes = {
        oil     = { { 'pour', 'اسكب الزيت الجديد حتى الخط الأخضر' } },
        pour    = { { 'pour', 'اسكب حتى الخط الأخضر' } },
        filter  = { { 'keys', 'بدّل الفلتر', 3 } },
        plugs   = { { 'skill', 'بدّل شمعات الاحتراق' } },
        brakes  = { { 'torque', 'ركّب الفحمات واربط البراغي', 1 } },
        clutch  = { { 'skill', 'ركّب القطعة الجديدة' } },
        battery = { { 'keys', 'بدّل البطارية', 3 } },
        -- one wheel (done 4 times)
        wheel   = { { 'torque', 'بدّل الإطار واربط الصواميل', 1 } },
        wash    = { { 'scrub', 'نظّف السيارة بالإسفنجة' } },
        wax     = { { 'scrub', 'وزّع الواكس على السيارة' } },
        -- installing the tuning (part C)
        t_engine = { { 'skill', 'ركّب قطع المحرك واضبط التوقيت' } },
        t_brakes = { { 'torque', 'ركّب الأقراص واربط البراغي', 1 } },
        t_trans  = { { 'skill', 'ركّب الجير واضبط النقلات' } },
        t_susp   = { { 'torque', 'ركّب التعليق واربط البراغي', 1 } },
        t_turbo  = { { 'skill', 'ركّب التيربو ووصّل الأنابيب' } },
        t_paint  = { { 'scrub', 'رش الصبغ على السيارة' } },
        t_body   = { { 'torque', 'ركّب القطعة واربط البراغي', 1 } },
        t_tint   = { { 'scrub', 'ألصق فيلم التظليل' } },
        t_neon   = { { 'keys', 'مدّ الأسلاك ووصّل الكهرباء', 3 } },
        t_xenon  = { { 'skill', 'ركّب لمبات الزينون' } },
        t_small  = { { 'keys', 'التركيب', 3 } },
        t_nitro  = { { 'skill', 'ركّب أسطوانة النيترو ووصّل الخط' } },
        t_refill = { { 'pour', 'عبّئ النيترو حتى الخط الأخضر' } },
        t_swap   = { { 'skill', 'ثبّت المحرك الجديد ووصّله' } },
    },
}

-- =====================================================================
-- TUNING (part C, step 1): performance and looks.
-- The customer drives his OWN car into a tuning bay at the workshop and opens the menu: he sees
-- every change on his car while he picks it, then confirms and pays (bank) — the money goes to the
-- workshop account. The order lands on the mechanics' tablet (الطلبات). A mechanic on duty takes
-- it, carries the parts (ordered from the parts shop) and installs each change at the car with the
-- mini-games. Nothing changes on the car until it is installed. No mechanic on duty = no tuning.
-- =====================================================================
Config.tuning = {
    needMechanic = true,   -- the menu only opens when at least one mechanic is on duty
    area = 70.0,           -- the mechanic installs within this distance of the workshop (the clock in desk)
    bayReach = 3.5,        -- how close to the bay circle the car must be (metres)
    keepDays = 14,         -- the finished orders list shows this many days
    maxLines = 30,         -- changes in one order
    -- performance: mod = the GTA mod slot, item = the part the mechanic uses (one per level step up;
    -- going down needs no part, it costs the "remove" price)
    perf = {
        { key = 'engine', mod = 11, prop = 'modEngine', label = 'المحرك', item = 'engine_kit', recipe = 't_engine' },
        { key = 'brakes', mod = 12, prop = 'modBrakes', label = 'الفرامل', item = 'brake_kit', recipe = 't_brakes' },
        { key = 'transmission', mod = 13, prop = 'modTransmission', label = 'ناقل الحركة', item = 'trans_kit', recipe = 't_trans' },
        { key = 'suspension', mod = 15, prop = 'modSuspension', label = 'التعليق', item = 'susp_kit', recipe = 't_susp' },
    },
    turbo = { item = 'turbo_kit', recipe = 't_turbo' },
    -- NITRO (step 2): installed once (nitro_kit); the driver holds LEFT SHIFT while accelerating to
    -- boost. A full bottle lasts `seconds` of boost; a mechanic refills it with a nitro_bottle (the
    -- service menu at the car; charge the customer with a bill).
    nitro = { item = 'nitro_kit', bottle = 'nitro_bottle', seconds = 15, power = 2.2, recipe = 't_nitro', refill = 't_refill' },
    -- ENGINE SWAP (step 2): the car gets another engine's sound and power (power = how much
    -- stronger than the car's own engine). One engine_crate per swap; going back to the car's own
    -- engine needs no part. The prices are swap_<id> (and swap_stock) in the price list.
    swap = {
        item = 'engine_crate', recipe = 't_swap',
        engines = {
            { id = 'dominator', label = 'V8 مسل', power = 1.12 },
            { id = 'gauntlet', label = 'V8 كلاسيك', power = 1.08 },
            { id = 'elegy2', label = 'تونر توربو', power = 1.10 },
            { id = 'sultanrs', label = 'رالي 4 سلندر', power = 1.12 },
            { id = 'omnis', label = 'رالي توربو', power = 1.15 },
            { id = 'zentorno', label = 'V12 سوبر', power = 1.25 },
            { id = 't20', label = 'هايبر هايبرد', power = 1.30 },
            { id = 'voltic', label = 'كهربائي', power = 1.15 },
        },
    },
    -- the mechanic who installs a change gets this % of its price from the workshop account (the
    -- manager changes it on the tablet: الطلبات → الأسعار → حصة الميكانيكي)
    cut = 15,
    -- the dyno: how close the car must be to the dyno circle, and the mechanic to the car
    dyno = { carReach = 3.5, mechReach = 15.0 },
    -- the body parts (only those the car has show up). price = the price key (see prices)
    body = {
        { mod = 0, prop = 'modSpoilers', label = 'الجناح الخلفي' },
        { mod = 1, prop = 'modFrontBumper', label = 'الصدام الأمامي' },
        { mod = 2, prop = 'modRearBumper', label = 'الصدام الخلفي' },
        { mod = 3, prop = 'modSideSkirt', label = 'الجوانب' },
        { mod = 4, prop = 'modExhaust', label = 'الشكمان' },
        { mod = 5, prop = 'modFrame', label = 'القفص' },
        { mod = 6, prop = 'modGrille', label = 'الشبك' },
        { mod = 7, prop = 'modHood', label = 'الكبوت' },
        { mod = 8, prop = 'modFender', label = 'الرفرف' },
        { mod = 9, prop = 'modRightFender', label = 'الرفرف الأيمن' },
        { mod = 10, prop = 'modRoof', label = 'السقف' },
        { mod = 25, prop = 'modPlateHolder', label = 'حامل اللوحة' },
        { mod = 27, prop = 'modTrimA', label = 'الديكور الداخلي' },
        { mod = 28, prop = 'modOrnaments', label = 'الزينة' },
        { mod = 29, prop = 'modDashboard', label = 'الطبلون' },
        { mod = 30, prop = 'modDial', label = 'العدادات' },
        { mod = 32, prop = 'modSeats', label = 'المقاعد' },
        { mod = 33, prop = 'modSteeringWheel', label = 'المقود' },
        { mod = 34, prop = 'modShifterLeavers', label = 'عصا الجير' },
        { mod = 37, prop = 'modTrunk', label = 'الشنطة' },
        { mod = 39, prop = 'modEngineBlock', label = 'غطاء المحرك' },
        { mod = 40, prop = 'modAirFilter', label = 'فلتر الهواء الرياضي' },
        { mod = 42, prop = 'modArchCover', label = 'أغطية الأقواس' },
        { mod = 43, prop = 'modAerials', label = 'الهوائيات' },
        { mod = 45, prop = 'modTank', label = 'خزان الوقود' },
        { mod = 46, prop = 'modWindows', label = 'النوافذ' },
        { mod = 14, prop = 'modHorns', label = 'الزامور', price = 'horn', item = 'body_kit' },
        { mod = 48, prop = 'modLivery', label = 'الملصقات', price = 'livery', item = 'paint_can' },
    },
    -- the items the looks use (one per change)
    items = {
        paint = 'paint_can', wheels = 'wheel_set', body = 'body_kit', tint = 'tint_film',
        neon = 'neon_kit', xenon = 'xenon_kit', plate = 'body_kit',
    },
    -- the starting prices the customer pays ($; EX_Tii economy: +25%). After the first start they live in the database
    -- and the manager edits them on the tablet (الطلبات → الأسعار).
    prices = {
        { 'engine_1', 'المحرك: المستوى 1', 2500 }, { 'engine_2', 'المحرك: المستوى 2', 5600 },
        { 'engine_3', 'المحرك: المستوى 3', 10000 }, { 'engine_4', 'المحرك: المستوى 4', 16250 },
        { 'brakes_1', 'الفرامل: المستوى 1', 1500 }, { 'brakes_2', 'الفرامل: المستوى 2', 3500 },
        { 'brakes_3', 'الفرامل: المستوى 3', 6250 },
        { 'transmission_1', 'ناقل الحركة: المستوى 1', 1900 }, { 'transmission_2', 'ناقل الحركة: المستوى 2', 4000 },
        { 'transmission_3', 'ناقل الحركة: المستوى 3', 7500 },
        { 'suspension_1', 'التعليق: المستوى 1', 1000 }, { 'suspension_2', 'التعليق: المستوى 2', 2000 },
        { 'suspension_3', 'التعليق: المستوى 3', 3500 }, { 'suspension_4', 'التعليق: المستوى 4', 5250 },
        { 'turbo', 'تيربو', 12500 },
        { 'remove', 'إرجاع قطعة أداء للأصل', 400 },
        { 'paint1', 'الصبغ الأساسي', 1900 }, { 'paint2', 'الصبغ الثانوي', 1100 },
        { 'pearl', 'اللمعة (البيرل)', 1000 }, { 'wheelColor', 'لون الجنوط', 500 },
        { 'wheels', 'طقم جنوط', 2250 },
        { 'body', 'قطعة هيكل', 900 }, { 'horn', 'الزامور', 400 }, { 'livery', 'ملصقات', 1500 },
        { 'tint', 'تظليل النوافذ', 550 },
        { 'neon', 'تركيب / إزالة النيون', 2250 }, { 'neonColor', 'لون النيون', 400 },
        { 'xenon', 'تركيب / إزالة الزينون', 1250 }, { 'xenonColor', 'لون الزينون', 300 },
        { 'plate', 'شكل اللوحة', 250 },
        { 'nitro', 'تركيب نظام النيترو', 15000 },
        { 'swap_dominator', 'محرك V8 مسل', 11250 }, { 'swap_gauntlet', 'محرك V8 كلاسيك', 9400 },
        { 'swap_elegy2', 'محرك تونر توربو', 10600 }, { 'swap_sultanrs', 'محرك رالي 4 سلندر', 11250 },
        { 'swap_omnis', 'محرك رالي توربو', 15000 }, { 'swap_zentorno', 'محرك V12 سوبر', 25000 },
        { 'swap_t20', 'محرك هايبر هايبرد', 32500 }, { 'swap_voltic', 'محرك كهربائي', 18750 },
        { 'swap_stock', 'إرجاع المحرك الأصلي', 3750 },
    },
    maxPrice = 250000,     -- the most the manager can set for one change
}

-- the parts shop on the tablet: paid from the workshop account, the box arrives at the delivery
-- spot near the workshop after a few minutes and a mechanic carries it to the parts shelf
Config.parts = {
    orderGrade = 1,        -- from this rank up a mechanic may order (1 = ميكانيكي)
    etaMinutes = 5,        -- how long a delivery takes (real minutes)
    maxPerOrder = 40,      -- items in one order
    keepDays = 14,         -- the orders list shows this many days
    catalog = {
        { item = 'engine_oil',         price = 60,   category = 'سوائل' },
        { item = 'coolant',            price = 45,   category = 'سوائل' },
        { item = 'brake_fluid',        price = 45,   category = 'سوائل' },
        { item = 'transmission_fluid', price = 70,   category = 'سوائل' },
        { item = 'air_filter',         price = 40,   category = 'محرك' },
        { item = 'spark_plugs',        price = 90,   category = 'محرك' },
        { item = 'clutch_kit',         price = 350,  category = 'ناقل الحركة' },
        { item = 'brake_pads',         price = 120,  category = 'فرامل' },
        { item = 'car_tire',           price = 80,   category = 'إطارات' },
        { item = 'ev_battery',         price = 1500, category = 'كهربائي' },
        { item = 'ev_motor',           price = 1200, category = 'كهربائي' },
        { item = 'car_soap',           price = 15,   category = 'تنظيف' },
        { item = 'car_wax',            price = 40,   category = 'تنظيف' },
        { item = 'repairkit',          price = 150,  category = 'عُدد' },
        { item = 'advancedrepairkit',  price = 400,  category = 'عُدد' },
        -- (EX_Tii: 'tirekit' removed: no such item, it blocked the boxes on the shelf)
        -- tuning (part C)
        { item = 'engine_kit',         price = 900,  category = 'أداء' },
        { item = 'brake_kit',          price = 600,  category = 'أداء' },
        { item = 'trans_kit',          price = 700,  category = 'أداء' },
        { item = 'susp_kit',           price = 400,  category = 'أداء' },
        { item = 'turbo_kit',          price = 3500, category = 'أداء' },
        { item = 'paint_can',          price = 250,  category = 'مظهر' },
        { item = 'wheel_set',          price = 600,  category = 'مظهر' },
        { item = 'body_kit',           price = 200,  category = 'مظهر' },
        { item = 'tint_film',          price = 120,  category = 'مظهر' },
        { item = 'neon_kit',           price = 500,  category = 'مظهر' },
        { item = 'xenon_kit',          price = 300,  category = 'مظهر' },
        { item = 'nitro_kit',          price = 4000, category = 'أداء' },
        { item = 'nitro_bottle',       price = 600,  category = 'أداء' },
        { item = 'engine_crate',       price = 5000, category = 'أداء' },
    },
}
