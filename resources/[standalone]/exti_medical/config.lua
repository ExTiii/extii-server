-- =====================================================================
-- EX_Tii medical: every hit is written down quietly (where, what hit you, how bad).
-- Players feel nothing extra (injuries stay OFF in qbx_medical); medics find the injuries
-- with the exam on the EMS tablet. Injuries stay until treated, also after logging out.
-- =====================================================================

Config = {}

Config.job = 'ambulance'           -- who can examine (on duty)
Config.examReach = 3.5             -- how close the medic must stay to the patient (meters)
Config.examKeep = 15               -- minutes the exam results stay after the last action
Config.consentTimeout = 20         -- seconds an awake patient has to accept the exam
Config.maxWounds = 30

-- how long each exam step takes (seconds)
Config.time = {
    zone = 3,        -- check one body part
    pulse = 6,       -- feel the pulse
    spo2 = 4,        -- oxygen clip
    temp = 5,        -- thermometer
    listen = 3,      -- stethoscope, one spot
    pupils = 3,      -- eye light
    ask = 2,         -- ask the patient
    bpMin = 5,       -- the cuff mini-game can't be faster than this
}

-- the 9 parts of the body on the exam screen, and which injury spots belong to each
Config.zones = {
    head    = { label = 'الرأس', parts = { 'HEAD' } },
    neck    = { label = 'الرقبة', parts = { 'NECK' } },
    chest   = { label = 'الصدر', parts = { 'UPPER_BODY' } },
    abdomen = { label = 'البطن', parts = { 'LOWER_BODY' } },
    back    = { label = 'الظهر', parts = { 'SPINE' } },
    r_arm   = { label = 'الذراع اليمنى', parts = { 'RARM', 'RHAND', 'RFINGER' } },
    l_arm   = { label = 'الذراع اليسرى', parts = { 'LARM', 'LHAND', 'LFINGER' } },
    r_leg   = { label = 'الرجل اليمنى', parts = { 'RLEG', 'RFOOT' } },
    l_leg   = { label = 'الرجل اليسرى', parts = { 'LLEG', 'LFOOT' } },
}
Config.zoneOrder = { 'head', 'neck', 'chest', 'abdomen', 'back', 'r_arm', 'l_arm', 'r_leg', 'l_leg' }

Config.parts = {
    HEAD = 'الرأس', NECK = 'الرقبة', SPINE = 'الظهر', UPPER_BODY = 'الصدر', LOWER_BODY = 'البطن',
    LARM = 'الذراع اليسرى', LHAND = 'اليد اليسرى', LFINGER = 'أصابع اليد اليسرى',
    RARM = 'الذراع اليمنى', RHAND = 'اليد اليمنى', RFINGER = 'أصابع اليد اليمنى',
    LLEG = 'الرجل اليسرى', LFOOT = 'القدم اليسرى', RLEG = 'الرجل اليمنى', RFOOT = 'القدم اليمنى',
}
Config.limbs = { LARM = true, LHAND = true, LFINGER = true, RARM = true, RHAND = true, RFINGER = true, LLEG = true, LFOOT = true, RLEG = true, RFOOT = true }

-- game bone -> injury spot (same list as qbx_medical)
Config.bones = {
    [31085] = 'HEAD', [31086] = 'HEAD', [39317] = 'NECK',
    [57597] = 'SPINE', [23553] = 'SPINE', [24816] = 'SPINE', [24817] = 'SPINE', [24818] = 'SPINE',
    [10706] = 'UPPER_BODY', [64729] = 'UPPER_BODY', [11816] = 'LOWER_BODY',
    [45509] = 'LARM', [61163] = 'LARM', [18905] = 'LHAND',
    [4089] = 'LFINGER', [4090] = 'LFINGER', [4137] = 'LFINGER', [4138] = 'LFINGER', [4153] = 'LFINGER', [4154] = 'LFINGER',
    [4169] = 'LFINGER', [4170] = 'LFINGER', [4185] = 'LFINGER', [4186] = 'LFINGER', [26610] = 'LFINGER', [26611] = 'LFINGER',
    [26612] = 'LFINGER', [26613] = 'LFINGER', [26614] = 'LFINGER',
    [58271] = 'LLEG', [63931] = 'LLEG', [2108] = 'LFOOT', [14201] = 'LFOOT',
    [40269] = 'RARM', [28252] = 'RARM', [57005] = 'RHAND',
    [58866] = 'RFINGER', [58867] = 'RFINGER', [58868] = 'RFINGER', [58869] = 'RFINGER', [58870] = 'RFINGER', [64016] = 'RFINGER',
    [64017] = 'RFINGER', [64064] = 'RFINGER', [64065] = 'RFINGER', [64080] = 'RFINGER', [64081] = 'RFINGER', [64096] = 'RFINGER',
    [64097] = 'RFINGER', [64112] = 'RFINGER', [64113] = 'RFINGER',
    [36864] = 'RLEG', [51826] = 'RLEG', [20781] = 'RFOOT', [52301] = 'RFOOT',
}

-- what hurt you. Anything not listed is worked out from the game's own damage type.
-- bullet: caliber 1 small (pistols), 2 medium (SMG, rifles), 3 high (big rifles, snipers)
Config.weapons = {
    -- small caliber
    [`WEAPON_PISTOL`] = { 'bullet', 1, 'مسدس' }, [`WEAPON_COMBATPISTOL`] = { 'bullet', 1, 'مسدس' },
    [`WEAPON_APPISTOL`] = { 'bullet', 1, 'مسدس' }, [`WEAPON_PISTOL_MK2`] = { 'bullet', 1, 'مسدس' },
    [`WEAPON_SNSPISTOL`] = { 'bullet', 1, 'مسدس صغير' }, [`WEAPON_SNSPISTOL_MK2`] = { 'bullet', 1, 'مسدس صغير' },
    [`WEAPON_VINTAGEPISTOL`] = { 'bullet', 1, 'مسدس' }, [`WEAPON_CERAMICPISTOL`] = { 'bullet', 1, 'مسدس' },
    [`WEAPON_COMBATPDW`] = { 'bullet', 1, 'رشاش صغير' }, [`WEAPON_MACHINEPISTOL`] = { 'bullet', 1, 'رشاش صغير' },
    [`WEAPON_MICROSMG`] = { 'bullet', 1, 'رشاش صغير' }, [`WEAPON_MINISMG`] = { 'bullet', 1, 'رشاش صغير' },
    -- medium caliber
    [`WEAPON_HEAVYPISTOL`] = { 'bullet', 2, 'مسدس ثقيل' }, [`WEAPON_PISTOL50`] = { 'bullet', 2, 'مسدس ثقيل' },
    [`WEAPON_REVOLVER`] = { 'bullet', 2, 'مسدس دوّار' }, [`WEAPON_REVOLVER_MK2`] = { 'bullet', 2, 'مسدس دوّار' },
    [`WEAPON_DOUBLEACTION`] = { 'bullet', 2, 'مسدس دوّار' }, [`WEAPON_MARKSMANPISTOL`] = { 'bullet', 2, 'مسدس' },
    [`WEAPON_SMG`] = { 'bullet', 2, 'رشاش' }, [`WEAPON_SMG_MK2`] = { 'bullet', 2, 'رشاش' }, [`WEAPON_ASSAULTSMG`] = { 'bullet', 2, 'رشاش' },
    [`WEAPON_GUSENBERG`] = { 'bullet', 2, 'رشاش' }, [`WEAPON_CARBINERIFLE`] = { 'bullet', 2, 'بندقية' },
    [`WEAPON_CARBINERIFLE_MK2`] = { 'bullet', 2, 'بندقية' }, [`WEAPON_ADVANCEDRIFLE`] = { 'bullet', 2, 'بندقية' },
    [`WEAPON_BULLPUPRIFLE`] = { 'bullet', 2, 'بندقية' }, [`WEAPON_BULLPUPRIFLE_MK2`] = { 'bullet', 2, 'بندقية' },
    [`WEAPON_COMPACTRIFLE`] = { 'bullet', 2, 'بندقية' }, [`WEAPON_SPECIALCARBINE`] = { 'bullet', 2, 'بندقية' },
    [`WEAPON_SPECIALCARBINE_MK2`] = { 'bullet', 2, 'بندقية' },
    -- high caliber
    [`WEAPON_ASSAULTRIFLE`] = { 'bullet', 3, 'بندقية' }, [`WEAPON_ASSAULTRIFLE_MK2`] = { 'bullet', 3, 'بندقية' },
    [`WEAPON_HEAVYRIFLE`] = { 'bullet', 3, 'بندقية' }, [`WEAPON_MG`] = { 'bullet', 3, 'رشاش ثقيل' },
    [`WEAPON_COMBATMG`] = { 'bullet', 3, 'رشاش ثقيل' }, [`WEAPON_COMBATMG_MK2`] = { 'bullet', 3, 'رشاش ثقيل' },
    [`WEAPON_SNIPERRIFLE`] = { 'bullet', 3, 'قناصة' }, [`WEAPON_HEAVYSNIPER`] = { 'bullet', 3, 'قناصة' },
    [`WEAPON_HEAVYSNIPER_MK2`] = { 'bullet', 3, 'قناصة' }, [`WEAPON_MARKSMANRIFLE`] = { 'bullet', 3, 'قناصة' },
    [`WEAPON_MARKSMANRIFLE_MK2`] = { 'bullet', 3, 'قناصة' }, [`WEAPON_MUSKET`] = { 'bullet', 3, 'بندقية قديمة' },
    [`WEAPON_MINIGUN`] = { 'bullet', 3, 'رشاش ثقيل' },
    -- shotguns
    [`WEAPON_PUMPSHOTGUN`] = { 'pellet', 2, 'شوزن' }, [`WEAPON_PUMPSHOTGUN_MK2`] = { 'pellet', 2, 'شوزن' },
    [`WEAPON_SAWNOFFSHOTGUN`] = { 'pellet', 2, 'شوزن' }, [`WEAPON_ASSAULTSHOTGUN`] = { 'pellet', 2, 'شوزن' },
    [`WEAPON_BULLPUPSHOTGUN`] = { 'pellet', 2, 'شوزن' }, [`WEAPON_DBSHOTGUN`] = { 'pellet', 2, 'شوزن' },
    [`WEAPON_HEAVYSHOTGUN`] = { 'pellet', 2, 'شوزن' }, [`WEAPON_AUTOSHOTGUN`] = { 'pellet', 2, 'شوزن' },
    [`WEAPON_COMBATSHOTGUN`] = { 'pellet', 2, 'شوزن' },
    -- knives and blades
    [`WEAPON_KNIFE`] = { 'blade', 1, 'سكين' }, [`WEAPON_DAGGER`] = { 'blade', 1, 'خنجر' },
    [`WEAPON_SWITCHBLADE`] = { 'blade', 1, 'سكين' }, [`WEAPON_BOTTLE`] = { 'blade', 1, 'زجاجة مكسورة' },
    [`WEAPON_MACHETE`] = { 'blade', 2, 'ساطور' }, [`WEAPON_HATCHET`] = { 'blade', 2, 'فأس' },
    [`WEAPON_BATTLEAXE`] = { 'blade', 2, 'فأس' }, [`WEAPON_STONE_HATCHET`] = { 'blade', 2, 'فأس' },
    -- blunt
    [`WEAPON_UNARMED`] = { 'blunt', 1, 'لكمات' }, [`WEAPON_KNUCKLE`] = { 'blunt', 1, 'قبضة حديدية' },
    [`WEAPON_FLASHLIGHT`] = { 'blunt', 1, 'كشاف' }, [`WEAPON_NIGHTSTICK`] = { 'blunt', 1, 'عصا' },
    [`WEAPON_BAT`] = { 'blunt', 2, 'مضرب' }, [`WEAPON_CROWBAR`] = { 'blunt', 2, 'عتلة' }, [`WEAPON_HAMMER`] = { 'blunt', 2, 'مطرقة' },
    [`WEAPON_GOLFCLUB`] = { 'blunt', 2, 'مضرب غولف' }, [`WEAPON_WRENCH`] = { 'blunt', 2, 'مفتاح ربط' },
    [`WEAPON_POOLCUE`] = { 'blunt', 2, 'عصا بلياردو' }, [`WEAPON_FIREEXTINGUISHER`] = { 'blunt', 1, 'طفاية' },
    [`WEAPON_PETROLCAN`] = { 'blunt', 1, 'جالون' },
    -- vehicles and falls
    [`WEAPON_RUN_OVER_BY_CAR`] = { 'vehicle', 2, 'دهس سيارة' }, [`WEAPON_RAMMED_BY_CAR`] = { 'vehicle', 2, 'صدمة سيارة' },
    [`WEAPON_FALL`] = { 'fall', 1, 'سقوط' },
    -- explosions and fire
    [`WEAPON_EXPLOSION`] = { 'explosion', 2, 'انفجار' }, [`WEAPON_GRENADE`] = { 'explosion', 2, 'قنبلة' },
    [`WEAPON_STICKYBOMB`] = { 'explosion', 3, 'متفجرات' }, [`WEAPON_PIPEBOMB`] = { 'explosion', 2, 'متفجرات' },
    [`WEAPON_PROXMINE`] = { 'explosion', 3, 'لغم' }, [`WEAPON_RPG`] = { 'explosion', 3, 'قاذف' },
    [`WEAPON_HELI_CRASH`] = { 'explosion', 3, 'تحطم مروحية' },
    [`WEAPON_FIRE`] = { 'fire', 1, 'نار' }, [`WEAPON_MOLOTOV`] = { 'fire', 2, 'مولوتوف' },
    [`WEAPON_FLARE`] = { 'fire', 1, 'شعلة' }, [`WEAPON_FLAREGUN`] = { 'fire', 1, 'مسدس إشارة' },
    [`WEAPON_ELECTRIC_FENCE`] = { 'fire', 1, 'سياج كهربائي' },
    -- other
    [`WEAPON_ANIMAL`] = { 'bite', 1, 'حيوان' }, [`WEAPON_COUGAR`] = { 'bite', 2, 'أسد جبلي' },
    [`WEAPON_BARBED_WIRE`] = { 'wire', 1, 'سلك شائك' },
    [`WEAPON_STUNGUN`] = { 'taser', 1, 'صاعق كهربائي' }, [`WEAPON_STUNGUN_MP`] = { 'taser', 1, 'صاعق كهربائي' },
    [`WEAPON_DROWNING`] = { 'air', 1, 'غرق' }, [`WEAPON_DROWNING_IN_VEHICLE`] = { 'air', 1, 'غرق' },
    [`WEAPON_BZGAS`] = { 'air', 1, 'غاز' }, [`WEAPON_SMOKEGRENADE`] = { 'air', 1, 'دخان' },
    [`WEAPON_EXHAUSTION`] = { 'none', 1, 'إرهاق' }, [`WEAPON_HIT_BY_WATER_CANNON`] = { 'blunt', 1, 'خرطوم مياه' },
}

-- the game's damage type -> our kind (for weapons not in the list above)
Config.damageTypes = {
    [2] = { 'blunt', 1, 'ضربة' },
    [3] = { 'bullet', 2, 'سلاح ناري' },
    [5] = { 'explosion', 2, 'انفجار' },
    [6] = { 'fire', 1, 'نار' },
    [8] = { 'fall', 1, 'سقوط' },
    [10] = { 'taser', 1, 'صعقة كهربائية' },
    [11] = { 'wire', 1, 'سلك شائك' },
    [13] = { 'air', 1, 'غاز' },
}

-- test patients: an admin types /fakepatient to get a hurt NPC on the ground to practise the exam on
-- (the NPC is only for practice: nothing is saved, it disappears with /fakepatientclear or after a while)
Config.fake = {
    max = 3,        -- at most this many at the same time (the oldest goes away)
    minutes = 30,   -- each one goes away by itself after this long
    -- how it lies / sits: [1] awake, [2] down (in pain on the ground), [3] unconscious / dead
    anims = {
        [1] = { male = { 'amb@world_human_picnic@male@base', 'base' }, female = { 'amb@world_human_picnic@female@base', 'base' } },
        [2] = { male = { 'combat@damage@writhe', 'writhe_loop' }, female = { 'combat@damage@writhe', 'writhe_loop' } },
        [3] = { male = { 'dead', 'dead_a' }, female = { 'dead', 'dead_a' } },
    },
    models = {
        male = { 'a_m_y_business_01', 'a_m_y_genstreet_01', 'a_m_m_skater_01', 'a_m_y_hipster_01' },
        female = { 'a_f_y_business_01', 'a_f_y_genhot_01', 'a_f_m_bevhills_01', 'a_f_y_hipster_01' },
    },
    names = {
        male = { 'محمد', 'أحمد', 'خالد', 'يوسف', 'عمر', 'سامي', 'فيصل', 'ماجد' },
        female = { 'سارة', 'نورة', 'ليلى', 'ريم', 'هند', 'مريم', 'دانة', 'جود' },
        last = { 'العتيبي', 'الحربي', 'منصور', 'الشمري', 'القحطاني', 'الزهراني', 'حداد', 'النجار' },
    },
    blood = { 'O+', 'A+', 'B+', 'AB+', 'O-', 'A-' },
}

-- ---------------------------------------------------------------------
-- treatment (part 2): the medic treats step by step, like the video
-- ---------------------------------------------------------------------
Config.treat = {
    -- the inventory items (ox_inventory names). tool = not used up
    items = {
        forceps = { item = 'forceps', label = 'ملقط جراحي', tool = true },
        bvm = { item = 'bvm', label = 'كيس التنفس (أمبو)', tool = true },
        defib = { item = 'defibrillator', label = 'جهاز الصدمات', tool = true },
        gauze = { item = 'gauze', label = 'شاش معقّم' },
        pressure = { item = 'pressure_bandage', label = 'ضماد ضاغط' },
        quickclot = { item = 'quickclot', label = 'كويك كلوت' },
        tourniquet = { item = 'tourniquet', label = 'عاصبة' },
        blood = { item = 'blood_bag', label = 'كيس دم' },
        saline = { item = 'saline', label = 'محلول ملحي' },
        ibuprofen = { item = 'ibuprofen', label = 'إيبوبروفين' },
        morphine = { item = 'morphine', label = 'مورفين' },
    },
    order = { 'forceps', 'bvm', 'defib', 'gauze', 'pressure', 'quickclot', 'tourniquet', 'blood', 'saline', 'ibuprofen', 'morphine' },
    -- the shortest each step can take (seconds, checked on the server)
    minTime = { extract = 3.4, dress = 4, tourniquet = 3, infuse = 3, oxygen = 3, med = 2, cpr = 17, defib = 2 },
    dressMin = { gauze = 5.5, pressure = 7.5, quickclot = 3.8 }, -- the wrap game: about 2 s a turn
    quickTime = { tourniquet = 4, infuse = 5, med = 3 }, -- how long the progress bar runs for the quick steps
    infusion = { blood = 45, saline = 30 },  -- seconds a bag runs (you can keep treating meanwhile)
    cprCycles = 3,            -- CPR cycles (30 presses + 2 breaths) to bring the pulse back without the defibrillator
    tourniquetMinutes = 10,   -- a tourniquet holds the bleeding this long, then it bleeds again (dress it properly)
    painkiller = {
        ibuprofen = { drop = 3, minutes = 30 },  -- for pain up to 5
        morphine = { drop = 6, minutes = 45 },   -- for strong pain (6 and more)
    },
    wrapTurns = { gauze = 3, pressure = 4, quickclot = 2 },
    -- EX_Tii (Moe): quick care. One scan shows every body part, ONE game heals everything (revive included),
    -- no medical items needed: a patient is back on his feet in under 15 seconds. false = the old step by step.
    quick = true,
    quickMin = 2.5,           -- the quick game can't be finished faster than this (seconds, server check)
}

-- EX_Tii gun rework: a bullet in the head does this much more than a body shot (0.5 = +50%)
Config.headshotBonus = 0.5
