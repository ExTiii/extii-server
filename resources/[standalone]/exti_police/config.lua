-- =====================================================================
-- EX_Tii Police (الشرطة) — Part 1, the station (like the video): clock in at the front desk
-- computer (drag your card onto the sensor), the cloakroom (uniforms), your personal locker, the
-- armory (free gear by rank), the garages with the team's vehicles and their trunks, and the
-- public forms (citizens fill them at the front desk, officers read them in the inbox).
-- Everything is an E spot: no NPCs.
-- =====================================================================

Config = {}

Config.job = 'police'             -- the qbx_core job (grades and pay are in qbx_core/shared/jobs.lua)
Config.offDutyOnLogin = true      -- officers always start a session off duty (they clock in at a station)

-- where things are in each station. Admins can move any spot in game with /policespots (stand
-- where you want it, pick the spot, done: it is saved in data/spots.json and wins over the numbers
-- here). The numbers below are for the normal GTA stations; when the new station map comes, move
-- the spots with /policespots.
--   duty      = the front desk computer: clock in / out
--   cloakroom = the uniforms
--   locker    = your personal locker (the same locker in every station)
--   armory    = the armory (free gear, each rank gets its own list)
--   forms     = the public forms (anyone: job application, complaint)
--   inbox     = (not used any more: officers read the forms on the tablet; an admin can still add
--               a desk spot for it with /policespots)
--   evidence  = the seized items room (guns taken from people on the street land here)
--   garage    = the team's cars (spawn = where the car appears)
--   heli      = the helicopter pad
Config.stations = {
    mrpd = {
        label = 'شرطة ميشن رو',
        duty = vec3(440.09, -974.92, 30.69),
        cloakroom = vec3(454.91, -990.89, 30.69),
        locker = vec3(451.25, -994.28, 30.69),
        armory = vec3(452.40, -980.00, 30.69),
        forms = vec3(438.40, -979.90, 30.69),
        evidence = vec3(458.97, -982.79, 30.68),
        garage = { coords = vec3(463.00, -1019.00, 28.10), spawn = vec4(463.00, -1019.00, 28.10, 87.0) },
        heli = { coords = vec3(449.17, -981.33, 43.69), spawn = vec4(449.17, -981.33, 43.69, 87.2) },
    },
    sandy = {
        label = 'شرطة ساندي شورز',
        duty = vec3(1853.40, 3684.50, 34.27),
        garage = { coords = vec3(1866.00, 3697.00, 33.60), spawn = vec4(1866.00, 3697.00, 33.60, 210.0) },
    },
    paleto = {
        label = 'شرطة باليتو',
        duty = vec3(-449.81, 6012.91, 31.72),
        garage = { coords = vec3(-455.39, 6002.02, 31.34), spawn = vec4(-455.39, 6002.02, 31.34, 87.9) },
        heli = { coords = vec3(-475.43, 5988.35, 31.72), spawn = vec4(-475.43, 5988.35, 31.72, 31.3) },
    },
}

-- locked doors in the stations: closed to everyone; an officer of the rank below (or higher), on
-- duty, unlocks and locks them with E. They lock themselves again after autoLock seconds.
-- Admins move a door in game: stand next to it and type /policedoor <id>.
Config.doors = {
    { id = 'mrpd_armory', label = 'غرفة الأسلحة', model = 'v_ilev_arm_secdoor', coords = vec3(452.62, -982.75, 30.69), minGrade = 2, minGradeLabel = 'رقيب', autoLock = 60 },
}

-- the station icon on the map (everyone sees it)
Config.blip = { sprite = 60, color = 29, scale = 0.8 }

-- your personal locker: only you can open it, the same one in every station
Config.locker = { label = 'خزانتك الشخصية', slots = 10, weight = 60000 }

-- the armory: free, each rank sees its own list (the rest is greyed out). grade = from this rank up
-- (0 مستجد, 1 ضابط, 2 رقيب, 3 ملازم, 4 قائد). max = how many an officer can carry (guns: 1 each).
-- serial = the gun gets a police serial and the officer's name on it; police guns stay with the
-- officer (no dropping, giving or putting them away) and are taken back if they leave the police.
Config.armory = {
    label = 'مستودع الأسلحة',
    perDay = 3,                   -- each officer can take each thing up to 3 times its max per day
    items = {
        { name = 'WEAPON_FLASHLIGHT', grade = 0 },
        { name = 'WEAPON_NIGHTSTICK', grade = 0 },
        { name = 'WEAPON_STUNGUN', grade = 0, serial = true },
        { name = 'handcuffs', grade = 0, max = 2 },
        { name = 'radio', grade = 0, max = 1 },
        { name = 'armour', grade = 0, max = 2 },
        { name = 'bandage', grade = 0, max = 5 },
        { name = 'evidence_bag', grade = 0, max = 10 },
        { name = 'WEAPON_COMBATPISTOL', grade = 1, serial = true },
        { name = 'ammo-9', grade = 1, max = 120 },
        { name = 'WEAPON_PUMPSHOTGUN', grade = 2, serial = true },
        { name = 'ammo-shotgun', grade = 2, max = 40 },
        { name = 'WEAPON_CARBINERIFLE', grade = 3, serial = true },
        { name = 'ammo-rifle', grade = 3, max = 180 },
    },
}

-- the uniforms the cloakroom starts with (the first time only; after that the leader adds, edits
-- and deletes them in game and they are saved in the database).
-- components = { component id, drawable, texture }  (1 mask, 3 arms, 4 trousers, 5 bag, 6 shoes,
-- 7 neck, 8 undershirt, 9 vest, 10 badges, 11 shirt/jacket);  props = { prop id, drawable, texture }
-- (0 hat, -1 = none);  grades = which ranks can wear it
Config.defaultOutfits = {
    male = {
        -- like the video: dark short-sleeve shirt, grey plate carrier, black cargo trousers, duty belt, boots
        -- (added = the update it came with: a server that already has its uniforms gets it once, at the top)
        { label = 'زي الدورية (الدرع الرمادي)', grades = { 0, 1, 2, 3, 4 }, added = 2,
          components = { { 4, 31, 0 }, { 3, 19, 0 }, { 8, 58, 0 }, { 9, 1, 0 }, { 11, 55, 0 }, { 6, 25, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'أكمام قصيرة', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 24, 0 }, { 3, 19, 0 }, { 8, 58, 0 }, { 9, 0, 0 }, { 11, 55, 0 }, { 6, 51, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'زي الدورية البيج', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 24, 0 }, { 3, 20, 0 }, { 8, 58, 0 }, { 9, 0, 0 }, { 11, 317, 3 }, { 6, 51, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, 58, 0 } } },
        { label = 'أكمام طويلة', grades = { 1, 2, 3, 4 },
          components = { { 4, 24, 0 }, { 3, 20, 0 }, { 8, 58, 0 }, { 9, 0, 0 }, { 11, 317, 0 }, { 6, 51, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'زي الدورية الأسود', grades = { 2, 3, 4 },
          components = { { 4, 24, 0 }, { 3, 20, 0 }, { 8, 58, 0 }, { 9, 0, 0 }, { 11, 317, 8 }, { 6, 51, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, 58, 3 } } },
        { label = 'القوات الخاصة', grades = { 3, 4 },
          components = { { 4, 130, 1 }, { 3, 172, 0 }, { 8, 15, 0 }, { 9, 15, 2 }, { 11, 336, 3 }, { 6, 24, 0 }, { 7, 133, 0 }, { 5, 0, 0 }, { 1, 52, 0 }, { 10, 0, 0 } },
          props = { { 0, 150, 0 } } },
    },
    female = {
        { label = 'زي الدورية (الدرع الرمادي)', grades = { 0, 1, 2, 3, 4 }, added = 2,
          components = { { 4, 32, 0 }, { 3, 31, 0 }, { 8, 35, 0 }, { 9, 1, 0 }, { 11, 48, 0 }, { 6, 25, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'أكمام قصيرة', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 133, 0 }, { 3, 31, 0 }, { 8, 35, 0 }, { 9, 34, 0 }, { 11, 48, 0 }, { 6, 52, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'زي الدورية البيج', grades = { 0, 1, 2, 3, 4 },
          components = { { 4, 133, 0 }, { 3, 31, 0 }, { 8, 35, 0 }, { 9, 34, 0 }, { 11, 327, 3 }, { 6, 52, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'أكمام طويلة', grades = { 1, 2, 3, 4 },
          components = { { 4, 133, 0 }, { 3, 31, 0 }, { 8, 35, 0 }, { 9, 34, 0 }, { 11, 327, 0 }, { 6, 52, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'زي الدورية الأسود', grades = { 2, 3, 4 },
          components = { { 4, 133, 0 }, { 3, 31, 0 }, { 8, 35, 0 }, { 9, 34, 0 }, { 11, 327, 8 }, { 6, 52, 0 }, { 7, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 }, { 10, 0, 0 } },
          props = { { 0, -1, 0 } } },
        { label = 'القوات الخاصة', grades = { 3, 4 },
          components = { { 4, 135, 1 }, { 3, 213, 0 }, { 8, 0, 0 }, { 9, 17, 2 }, { 11, 327, 8 }, { 6, 52, 0 }, { 7, 102, 0 }, { 5, 0, 0 }, { 1, 35, 0 }, { 10, 0, 0 } },
          props = { { 0, 149, 0 } } },
    },
}
Config.maxOutfits = 12            -- per men / women

-- the police vehicles (the team's fleet, like the video): every vehicle has its own plate and its
-- own trunk that keeps what you leave in it between shifts. The leader buys / sells vehicles (with
-- the police account in the bank) and can change a plate (free) in the garage.
Config.fleet = {
    plate = 'LSPD',              -- new plates: LSPD + 4 letters/numbers
    trunk = { slots = 30, weight = 200000 },
    sellBack = 0.5,              -- selling a vehicle gives back this much of its price
    max = 25,                    -- how many vehicles the team can own
    models = {
        police = { label = 'ستانير', kind = 'ground', price = 35000 },
        police2 = { label = 'بافالو', kind = 'ground', price = 42000 },
        police3 = { label = 'إنترسبتور', kind = 'ground', price = 40000 },
        police4 = { label = 'ستانير بدون علامات', kind = 'ground', price = 38000 },
        policeb = { label = 'دراجة الشرطة', kind = 'ground', price = 22000 },
        sheriff = { label = 'ستانير الشريف', kind = 'ground', price = 35000 },
        sheriff2 = { label = 'غرانجر الشريف', kind = 'ground', price = 45000 },
        fbi2 = { label = 'غرانجر بدون علامات', kind = 'ground', price = 50000 },
        policet = { label = 'شاحنة نقل السجناء', kind = 'ground', price = 48000 },
        riot = { label = 'المدرعة', kind = 'ground', price = 120000 },
        polmav = { label = 'مروحية الشرطة', kind = 'air', price = 250000, livery = 0 },
    },
    start = { 'police3', 'police3', 'police2', 'police', 'polmav' }, -- what the team has the first time
}

-- the public forms: citizens fill them at the front desk, officers read them in the inbox.
-- fields: id, label, required, type = 'area' (a big box), max = how many letters
Config.forms = {
    cooldown = 300,               -- seconds between two forms from the same citizen
    maxOpen = 3,                  -- a citizen can have this many forms nobody has looked at yet
    keep = 300,                   -- the inbox shows the newest this many
    archiveGrade = 2,             -- archive from this rank up (2 = رقيب)
    types = {
        { id = 'application', prefix = 'APP', icon = 'application', label = 'طلب توظيف', desc = 'قدّم للانضمام لشرطة لوس سانتوس', fields = {
            { id = 'name', label = 'الاسم الكامل', required = true },
            { id = 'dob', label = 'تاريخ الميلاد' },
            { id = 'phone', label = 'رقم الهاتف' },
            { id = 'availability', label = 'الأوقات المتاحة', placeholder = 'الأيام والساعات' },
            { id = 'experience', label = 'الخبرة', type = 'area', placeholder = 'عمل سابق في الأمن أو الشرطة أو غيرها' },
            { id = 'why', label = 'لماذا تريد الانضمام؟', type = 'area', required = true },
        } },
        { id = 'complaint', prefix = 'CMP', icon = 'complaint', label = 'شكوى', desc = 'على شخص أو على أحد أفراد الشرطة', fields = {
            { id = 'name', label = 'الاسم الكامل', required = true },
            { id = 'phone', label = 'رقم الهاتف' },
            { id = 'against', label = 'ضد من؟', placeholder = 'الاسم أو رقم الشارة إن عرفته' },
            { id = 'when', label = 'متى وأين؟' },
            { id = 'what', label = 'ماذا حدث؟', type = 'area', required = true },
        } },
    },
}

-- =====================================================================
-- the police tablet (like the video): F6 on duty. Home screen with the apps, held in your hands,
-- its screen shown live on the tablet. Other players see a locked police screen.
-- =====================================================================
Config.tabletKey = 'F6'           -- the same key as the EMS tablet (each job only gets its own)
Config.tablet = {
    prop = `prop_cs_tablet`,
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base',
    bone = 60309, pos = vec3(0.03, 0.002, -0.0), rot = vec3(10.0, 160.0, 0.0),
    screenW = 1220, screenH = 776,   -- the size of the screen page (do not change)
    screen = { face = -1, push = 0.0015, insetLong = 0.050, insetShort = 0.070, scale = 1.000, shiftLong = 0.0040, shiftShort = 0.0000, rot = 2, mirror = false, w = 1.0, both = true },
    othersDistance = 20.0,           -- other officers' tablets show a locked police screen within this distance
}

-- the tablet apps
Config.chat = { maxText = 500, history = 100 }   -- letters per message, messages shown per chat
Config.calendarColors = { '#3b8cf0', '#f29b38', '#2fb36a', '#e0566b', '#9b6cf0', '#22c7b8' } -- the first one is picked by default
Config.bonusMax = 50000           -- the leader's bonus to one officer at a time (from the police account)
Config.salaryMax = 250            -- the highest salary the leader can set for a rank (every paycheck = 10 min). EX_Tii economy: max $1,500/hour on duty

Config.reachPoint = 1.6           -- how close to an E spot you must be (meters)
Config.vehicleReach = 4.0         -- in your car / helicopter: how close to the garage / pad to return it

-- the small white circle on the floor at every spot (officers see them; everyone sees the forms one)
Config.circle = { size = 1.0, color = { 255, 255, 255 }, distance = 20.0 }

-- the street: what an officer on duty does to the person next to him (Z wheel → الشرطة):
-- cuff / uncuff, escort, put in a vehicle / take out, search the bag, seize the guns
Config.street = {
    reach = 2.0,                  -- how close the officer must be to the person (meters)
    vehicleReach = 4.0,           -- how close to the vehicle to put a cuffed person in it
    cuffItem = 'handcuffs',       -- the officer needs this in his bag to cuff (it is not used up)
    cuffSeconds = 3.5,            -- how long cuffing / uncuffing takes
    -- where seized guns and ammo go: the evidence spot of the station opens it
    seized = { id = 'exti_police_seized', label = 'غرفة المصادرات', slots = 200, weight = 500000 },
}

-- charges (the Z wheel → الشرطة → مخالفة): the officer ticks the offences, the fine lands as a bill in the
-- person's bank (exti_bank), he pays it at the teller or the ATM and the money goes to the police account.
-- The list below is only the starting list: after the first start it lives in the database and the
-- chief edits it on the tablet (الإدارة → قوالب الفواتير).
Config.charges = {
    maxFine = 100000,        -- the biggest fine one offence may carry
    maxJail = 120,           -- the longest jail time (minutes) one offence may carry
    maxPicks = 12,           -- how many offences one charge sheet may hold
    noteLength = 160,        -- the officer's note on the sheet
    defaults = {
        -- { label, category, fine $, jail minutes }
        { 'تجاوز السرعة', 'مرور', 300, 0 },
        { 'قيادة متهورة', 'مرور', 600, 0 },
        { 'قطع إشارة حمراء', 'مرور', 250, 0 },
        { 'القيادة عكس الاتجاه', 'مرور', 400, 0 },
        { 'القيادة بدون رخصة', 'مرور', 500, 0 },
        { 'وقوف ممنوع', 'مرور', 150, 0 },
        { 'الهروب من الشرطة (مطاردة)', 'مرور', 1500, 10 },
        { 'حادث والهروب من موقعه', 'مرور', 1000, 5 },
        { 'مركبة بدون لوحة أو بلوحة مزورة', 'مرور', 700, 0 },
        { 'إزعاج عام', 'نظام عام', 200, 0 },
        { 'التعدي على ملكية خاصة', 'نظام عام', 400, 0 },
        { 'إخفاء الهوية أثناء جريمة', 'نظام عام', 500, 5 },
        { 'عدم الامتثال لأوامر الشرطة', 'نظام عام', 500, 5 },
        { 'إهانة موظف عام', 'نظام عام', 400, 0 },
        { 'حمل سلاح أبيض', 'أسلحة', 500, 5 },
        { 'حيازة سلاح ناري بدون ترخيص', 'أسلحة', 2500, 15 },
        { 'إشهار سلاح في مكان عام', 'أسلحة', 1500, 10 },
        { 'إطلاق نار في مكان عام', 'أسلحة', 3000, 20 },
        { 'حيازة سلاح آلي', 'أسلحة', 5000, 30 },
        { 'تهديد', 'عنف', 600, 5 },
        { 'اعتداء', 'عنف', 800, 10 },
        { 'اعتداء بسلاح', 'عنف', 2500, 20 },
        { 'محاولة قتل', 'عنف', 10000, 45 },
        { 'قتل', 'عنف', 20000, 60 },
        { 'خطف واحتجاز', 'عنف', 8000, 40 },
        { 'سرقة', 'ممتلكات', 1500, 10 },
        { 'سرقة مركبة', 'ممتلكات', 2500, 15 },
        { 'سطو على متجر', 'ممتلكات', 5000, 25 },
        { 'سطو على بنك', 'ممتلكات', 15000, 45 },
        { 'تخريب ممتلكات', 'ممتلكات', 800, 5 },
        { 'حيازة مخدرات', 'مخدرات', 1000, 5 },
        { 'بيع مخدرات', 'مخدرات', 4000, 25 },
        { 'تصنيع أو زراعة مخدرات', 'مخدرات', 8000, 40 },
        { 'الاعتداء على شرطي', 'ضد السلطة', 5000, 30 },
        { 'مقاومة الاعتقال', 'ضد السلطة', 1500, 10 },
        { 'الهروب من السجن', 'ضد السلطة', 10000, 45 },
        { 'رشوة موظف', 'ضد السلطة', 3000, 15 },
        { 'انتحال صفة الشرطة', 'ضد السلطة', 4000, 20 },
    },
}

-- the prison (Bolingbroke). The officer drives the cuffed person to the gate, stands with him in the
-- intake circle and presses E (or opens the charge sheet there): the سجن buttons work only here.
-- Inside, the prisoner wears the prison uniform, his bag is locked up until he walks out, and the
-- small jobs in the yard take minutes off his time. Admins move the spots in game with /prisonspot.
Config.prison = {
    intake = vec3(1848.13, 2586.05, 45.67),          -- outside the main gate: the officer hands him over here
    intakeRadius = 5.0,
    spawn = vec4(1661.05, 2524.68, 45.56, 260.5),    -- the cells: where he appears
    release = vec4(1848.13, 2586.05, 45.67, 269.5),  -- outside the gate: where he walks out
    center = vec3(1693.33, 2569.51, 45.55),          -- the middle of the prison
    radius = 145.0,                                  -- farther than this from the middle = outside: straight back to the cell
                                                     -- (the cells and yard jobs are within 100 m; the main gate is 156 m out)
    escapeSeconds = 15,                              -- that far for this long = escaped
    maxMinutes = 300,                                -- the longest sentence (the offences add up)
    workCooldown = 30,                               -- seconds between two jobs
    -- the uniform (clothes components: id, drawable, texture). The face and hair stay his.
    uniform = {
        male = { { 11, 345, 0 }, { 8, 15, 0 }, { 3, 19, 0 }, { 4, 3, 7 }, { 6, 1, 0 }, { 7, 0, 0 }, { 9, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 } },
        female = { { 11, 370, 0 }, { 8, 14, 0 }, { 3, 0, 0 }, { 4, 0, 12 }, { 6, 1, 0 }, { 7, 0, 0 }, { 9, 0, 0 }, { 5, 0, 0 }, { 1, 0, 0 } },
    },
    -- the jobs: each spot takes `minutes` off the sentence after `seconds` of work
    works = {
        { id = 'electric', label = 'إصلاح الكهرباء', minutes = 2, seconds = 12, scenario = 'WORLD_HUMAN_WELDING',
          spots = { vec3(1761.46, 2540.41, 45.56), vec3(1718.54, 2527.80, 45.56), vec3(1700.20, 2474.81, 45.56), vec3(1664.83, 2501.58, 45.56), vec3(1621.62, 2509.30, 45.56), vec3(1627.94, 2538.39, 45.56), vec3(1625.10, 2575.99, 45.56) } },
        { id = 'clean', label = 'تنظيف الساحة', minutes = 1, seconds = 10, scenario = 'WORLD_HUMAN_MAID_CLEAN',
          spots = { vec3(1792.45, 2584.37, 45.56), vec3(1768.33, 2566.08, 45.56), vec3(1770.59, 2536.06, 45.56), vec3(1696.09, 2469.40, 45.56), vec3(1697.11, 2525.56, 45.56) } },
        { id = 'gym', label = 'رفع الأثقال', minutes = 1, seconds = 12, scenario = 'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS',
          spots = { vec3(1765.67, 2565.91, 45.56), vec3(1650.81, 2540.58, 45.56), vec3(1673.08, 2519.82, 45.56) } },
    },
}

-- 911: calls from the phone's services app and from /911 in the chat land on the officers' phones
-- (blip + notification) and on the tablet map (البلاغات)
Config.dispatch = {
    expireMinutes = 20,      -- an untouched call disappears after this
    cooldown = 45,           -- seconds between two /911 of the same player
    textLength = 160,
    labels = { phone = 'بلاغ هاتفي', chat = 'بلاغ 911', alarm = 'إنذار' },
    -- the call card that pops up for officers (like NoPixel's dispatch): the code shown for a call,
    -- picked by the first words of its title (urgent = red card + the urgent radio sound)
    codes = {
        { match = 'إطلاق نار', code = '10-71', icon = 'gun', urgent = true },
        { match = 'سرقة مركبة شرطة', code = '10-99', icon = 'car', urgent = true },
        { match = 'سرقة سيارة', code = '10-16', icon = 'car' },
        { match = 'بيع مخدرات', code = '10-66', icon = 'pill' },
        { match = 'كتابة على الجدران', code = '10-31', icon = 'spray' },
        { match = 'بلاغ مجهول', code = '10-31', icon = 'eye' },
        { match = 'رهين', code = '10-90', icon = 'user', urgent = true },     -- (exti_heists: hostages taken / a hostage hurt)
        { match = 'تتبّع', code = '10-62', icon = 'arrow' },                  -- (marked bills: the bank's trace)
        { match = 'سطو', code = '10-90', icon = 'store', urgent = true },   -- (exti_heists: stores; more specific robberies go above this)
    },
    kindCodes = { phone = { code = '911', icon = 'phone' }, chat = { code = '911', icon = 'phone' }, alarm = { code = '10-90', icon = 'bell' } },
    cardSeconds = 12,        -- (not used now: a card stays on screen until a cop takes the call or it is closed)
    blipSeconds = 180,
    -- what the reporter saw (server/witness.lua): the chance of each detail
    witness = {
        day    = { person = 0.85, car = 0.9, plate = 0.55, dir = 0.75 },
        night  = { person = 0.55, car = 0.7, plate = 0.25, dir = 0.5 },   -- 21:00 to 06:00 (a witness who surely saw it uses the day chances)
        camera = { person = 0.95, car = 1.0, plate = 0.9, dir = 0.9 },   -- a CCTV camera within cameraRange
        cameraRange = 45.0,
        nightFrom = 21, nightTo = 6,
        movingSpeed = 2.5,   -- slower than this: no direction
    },
    recentSeconds = 120,   -- coming on duty: the open calls of the last 2 minutes pop up too (no beep)       -- the flashing map icon at the call
}

-- CCTV (الكاميرات): the tablet looks through them. The list builds itself: one camera in every
-- shop and bank (behind the counter, exti_shops), one over the pumps of every gas station
-- (exti_fuel), plus the extra ones below, plus what admins add in game with /cctvadd.
-- Fix a bad angle in game: aim your own view, type /cctvspot <n> (the number from the tablet).
Config.cctv = {
    maxTurn = 70,        -- how far left / right the officer may turn a camera (degrees)
    maxTilt = 35,        -- up / down
    fov = { 25, 75 },    -- zoom range (the mouse wheel)
    -- shops and banks: the camera hangs this far behind the clerk, this high over his feet, tilted down
    shopBack = 1.6, shopHeight = 2.3, shopPitch = -22.0,
    shopTypes = nil,     -- nil = every store type; or { general = true, bank = true, fuel = true, ... }
    -- gas stations: on the far side of the pumps, this high, looking back over them
    fuelDistance = 11.0, fuelHeight = 5.5, fuelPitch = -28.0,
    -- the extra cameras: coords = where it hangs, rot = pitch / roll / yaw it starts with
    cameras = {
        { label = 'مركز شرطة ميشن رو · المدخل', area = 'ميشن رو', kind = 'city', coords = vec3(434.0, -979.0, 35.0), rot = vec3(-25.0, 0.0, 180.0) },
        { label = 'مستشفى بيلبوكس · المدخل', area = 'بيلبوكس هيل', kind = 'city', coords = vec3(306.0, -590.0, 47.5), rot = vec3(-22.0, 0.0, 70.0) },
        { label = 'سجن بولينغبروك · البوابة', area = 'بولينغبروك', kind = 'city', coords = vec3(1845.0, 2595.0, 50.0), rot = vec3(-28.0, 0.0, 200.0) },
        { label = 'مجوهرات فانجيليكو', area = 'روكفورد هيلز', kind = 'city', coords = vec3(-623.0, -230.0, 42.0), rot = vec3(-22.0, 0.0, 215.0) },
    },
}

-- =====================================================================
-- evidence (server/evidence.lua): what a crime leaves behind. Officers on duty see the small marks on
-- the ground within showDistance, bag them ([E], one evidence bag each, from the armory) and hand the
-- bags in at the lab (the seized items room of a station). The lab answers after labMinutes, on the
-- case they picked and on their phone.
--   print  = a partial fingerprint (a robber with no gloves touched the till, a safe, a case, a door)
--   blood  = someone bled here (shot, stabbed)
--   casing = a shell casing (the gun's serial and owner, or "no serial")
-- marked bills (exti_heists: banks, the armored truck) send a trace to the police for a while.
-- =====================================================================
Config.evidence = {
    lifeMinutes = 90,        -- a mark nobody bagged washes away after this
    showDistance = 10.0,     -- officers see the marks this close
    pickDistance = 1.6,
    labMinutes = 10,         -- the lab's answer comes this long after the bag is handed in
    bagItem = 'evidence_bag',
    item = 'police_evidence',
    maxMarks = 400,          -- oldest go first
    bonus = { named = 100, daily = 5 }, -- an officer whose bag (on a case) named someone gets this (bank), up to 5 a day
    blood = { minDamage = 15, everySeconds = 20 },
    casing = { everySeconds = 6 },
    trace = { everySeconds = 45, radius = 160.0, offset = 90.0 },   -- marked bills: a circle on the cops' map
    -- arms (component 3) with NO gloves on the freemode models: any other number = gloves
    noGloves = {
        male = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 18, 26, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 112, 113, 114, 118, 125, 132 },
        female = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 129, 130, 131, 135, 142, 149, 153, 157, 161, 165 },
    },
    labels = { print = 'بصمة جزئية', blood = 'عينة دم', casing = 'ظرف رصاصة' },
}
