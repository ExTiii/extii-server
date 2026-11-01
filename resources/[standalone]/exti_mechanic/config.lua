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
    },
}

-- locked doors (none in the workshop by default; same format as the police: id, label, model, coords, minGrade)
Config.doors = {}

-- the workshop icon on the map (everyone sees it)
Config.blip = { sprite = 446, color = 5, scale = 0.8 }

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
Config.salaryMax = 1000           -- the highest salary the leader can set for a rank (every paycheck)

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
