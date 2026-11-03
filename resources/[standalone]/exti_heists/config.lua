-- =====================================================================
-- EX_Tii heists: every number of the robbery system lives here (Moe's Build Plan v2).
-- Money is the crew's total in police mode, before washing. Change one number at a time and watch the logs.
-- =====================================================================
Config = {}

Config.webhookConvar = 'exti_heists_webhook'   -- set exti_heists_webhook "https://discord.com/api/webhooks/..." in server.cfg (Moe pastes it himself)

---------------------------------------------------------------------------
-- cops: who counts, and how many each tier needs (scales with players online)
---------------------------------------------------------------------------
Config.cops = {
    job = 'police',
    dutyMinutes = 10,      -- on duty this long before he counts (no clocking in just to unlock a job)
    movedMinutes = 5,      -- and moved within this (AFK cops don't count)
    sampleSeconds = 20,    -- how often the server looks at every cop
}
-- cops needed = ceil(players online * share), never below floor or above cap
Config.copsNeeded = {
    [1] = { share = 0.00, floor = 1, cap = 1 }, [2] = { share = 0.00, floor = 1, cap = 1 },
    [3] = { share = 0.05, floor = 2, cap = 3 }, [4] = { share = 0.05, floor = 2, cap = 3 },
    [5] = { share = 0.07, floor = 2, cap = 4 }, [6] = { share = 0.07, floor = 2, cap = 4 },
    [7] = { share = 0.08, floor = 3, cap = 5 },
    [8] = { share = 0.10, floor = 4, cap = 7 }, [9] = { share = 0.10, floor = 4, cap = 7 },
    [10] = { share = 0.12, floor = 5, cap = 8 },
}
Config.noPoliceMaxTier = 6          -- tiers 7-10 never run without real police

Config.mode = {
    bonusPerCop = 0.05, bonusMax = 0.25,      -- police mode: +5% per counted cop above the minimum
    noPolicePay = 0.60, noPoliceUsb = 0.50, noPoliceRep = 0.50,
}

---------------------------------------------------------------------------
-- criminal Rep (per character) and skills
---------------------------------------------------------------------------
Config.rep = {
    -- XP needed to BE each level (level 1 = 0 XP)
    levels = { 0, 50, 150, 300, 500, 800, 1200, 1700, 2300, 3000 },
    xp = { 10, 15, 25, 40, 50, 75, 150, 200, 250, 400 },   -- per successful robbery of that tier (police mode)
    arrest = -15,                                        -- jailed by the police
    leaderNeeds = 1.0, memberNeeds = 0.5,                -- of the tier's level
}
Config.skills = {
    lockpick = { label = 'فتح الأقفال', xp = { 0, 25, 70, 140, 240 } },   -- XP to BE level 1..5
    hacking  = { label = 'الاختراق',    xp = { 0, 25, 70, 140, 240 } },
    breaching = { label = 'الكسر',      xp = { 0, 25, 70, 140, 240 } },
    gain = 5,              -- per passed minigame of that kind
    timeBonus = 0.10,      -- +10% minigame time per level above 1
}

Config.heatMinutes = 30              -- after any robbery: no new Tier 4+ job
Config.combatLog = {
    graceSeconds = 180,  -- a crash: back within 3 min = keep everything
    xp = -15,            -- logged out with heat for longer: the loot is deleted and this XP
    lootItems = { 'black_money', 'marked_bills', 'rolex', 'diamond_ring', 'goldchain', 'diamond', 'small_tv', 'stolen_laptop', 'stolen_console', 'painting', 'vault_goldbar' },
}

---------------------------------------------------------------------------
-- NPC security (no-police mode): "حراسة الحي"
---------------------------------------------------------------------------
Config.npc = {
    kinds = {   -- delay = seconds after the alarm, cars = how many (each car: 2 guards)
        store   = { delay = 90,  cars = { 1, 2 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_PISTOL' } },
        house   = { delay = 60,  cars = { 1, 1 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_PISTOL' } },
        atm     = { delay = 60,  cars = { 1, 2 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_PUMPSHOTGUN' } },
        jewelry = { delay = 120, cars = { 2, 3 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_CARBINERIFLE' } },
    },
    lostSeconds = 60,        -- out of their sight this long: they lose you (like GTA's wanted stars)
    giveUpDistance = 220.0,  -- nobody this close to the spot when they arrive: they don't come
    copStandDown = 100.0,    -- a real cop this close to a robber: the NPCs back off
    maxMinutes = 12,         -- they give up after this long anyway
    accuracy = 18,           -- GTA default is ~50 for cops: tense, not unfair
    car = 'police4',         -- unmarked cruiser, no light bar (they are a private patrol, not LSPD)
    ped = 's_m_m_security_01',
    spawnDistance = { 160.0, 260.0 },
}

---------------------------------------------------------------------------
-- the minigames: the server refuses a result faster than this (seconds)
---------------------------------------------------------------------------
Config.games = {
    maxSeconds = 240,                -- a game result later than this after its start is refused
    lockpick = { minSeconds = 6.0 },
    safedial = { minSeconds = 12.0 },
}

---------------------------------------------------------------------------
-- stores (Tier 1 register, Tier 2 safe) — the 20 stores of exti_shops
---------------------------------------------------------------------------
Config.storeTypes = { general = true, liquor = true, fuel = true }
-- store rooms that are built the same way (a safe placed in one is copied to the others with /heistspots)
Config.storeLayouts = {
    ltd = { 'غروف ستريت', 'ليتل سيول', 'ميرور بارك', 'ريتشمان غلين', 'غريبسيد' },   -- fuel stores that are LTDs
    -- every other fuel store and every general store is a 24/7; every liquor store is a Rob's Liquor
}
Config.register = {
    tier = 1,
    aimSeconds = 10,          -- keep the gun on him while he opens the till
    lookAwayAlarm = 0.30,     -- look away for 2 s: this chance he presses the silent alarm (once)
    cowerSeconds = 6,         -- look away this long: he drops behind the counter, lockpick the till
    grabSeconds = 7,          -- emptying the till
    pay = { 600, 1200 },      -- black_money
    cooldownMinutes = 20,     -- per store
    reportDelay = 40,         -- no alarm pressed: the clerk calls the police this long after you leave the till
}
-- where each store's back-room safe is (GTA's own store rooms). A store takes the one within 14 m of its clerk.
-- /heistspots (admins) puts a safe somewhere else and wins over these.
Config.storeSafeSpots = {
    vec3(-43.43, -1748.30, 29.42), vec3(-1478.94, -375.50, 39.16), vec3(-1220.85, -916.05, 11.32), vec3(1126.77, -980.10, 45.41),
    vec3(1159.46, -314.05, 69.20), vec3(-709.74, -904.15, 19.21), vec3(-1829.27, 798.76, 138.19), vec3(28.20, -1338.42, 29.49),
    vec3(1734.78, 6420.84, 35.03), vec3(546.41, 2662.80, 42.15), vec3(1959.16, 3748.92, 32.34), vec3(2672.69, 3286.63, 55.24),
    vec3(1707.93, 4920.33, 42.06), vec3(-3047.88, 585.61, 7.90), vec3(-3250.02, 1004.43, 12.83), vec3(378.17, 333.44, 103.56),
    vec3(-2959.64, 387.08, 14.04), vec3(1169.31, 2717.79, 37.15), vec3(2549.19, 384.88, 108.62), vec3(1394.95, 3613.62, 34.98),
}
Config.storeSafe = {
    tier = 2,
    timelockSeconds = 120,    -- after the dial: wait it out while the alarm rings
    pay = { 2500, 4500 },
    usb = { item = 'usb_green', chance = 0.05 },
    cooldownMinutes = 45,
}

---------------------------------------------------------------------------
-- police calls (exti_police card)
---------------------------------------------------------------------------
Config.calls = {
    register = 'سطو مسلح على متجر',
    registerQuiet = 'سطو على متجر',
    safe = 'سطو على خزنة متجر',
}
Config.calls.house = 'سطو على منزل'
Config.calls.houseLoud = 'سطو على منزل · كسر نافذة'

---------------------------------------------------------------------------
-- the fence (المصرّف): the gang fence, now also the robbery fence. A phone contact.
---------------------------------------------------------------------------
Config.fence = {
    number = '555-0187',          -- his phone number (text him: "شغل" for a house, "مكان" for where he is today)
    leadMinutes = 60,             -- a house lead stays good this long
    leadCooldownMinutes = 20,     -- one lead per character this often
    -- what he buys (dirty money each), and how many of each he takes per day from the whole city
    goods = {
        rolex          = { price = 450,  daily = 25 },
        diamond_ring   = { price = 600,  daily = 25 },
        goldchain      = { price = 300,  daily = 40 },
        ['10kgoldchain'] = { price = 200, daily = 40 },
        diamond        = { price = 900,  daily = 15 },
        small_tv       = { price = 350,  daily = 20 },
        stolen_laptop  = { price = 500,  daily = 20 },
        stolen_console = { price = 400,  daily = 20 },
        painting       = { price = 1400, daily = 8 },
        vault_goldbar  = { price = 15000, daily = 5 },
    },
}

---------------------------------------------------------------------------
-- house burglary (Tiers 1-3). Interiors: GTA's own (the spots inside come from Qbox's qbx_houserobbery data),
-- each break-in happens in its own copy of the world (routing bucket), so two crews never meet inside.
---------------------------------------------------------------------------
Config.house = {
    nightFrom = 22, nightTo = 5,          -- game time
    playerCooldownMinutes = 30,
    houseCooldownMinutes = 120,
    maxMinutes = 15,                      -- inside longer than this: the owner comes home (alarm)
    searchSeconds = { 6, 9 },
    noise = {                             -- the noise meter (0-100): full = the owner wakes up and calls
        sprint = 9, run = 3, jump = 14, search = 3, safeFail = 18, pickFail = 10, window = 55, decay = 4, -- per second
    },
    sizes = {
        small   = { tier = 1, label = 'شقة صغيرة', interior = 1, spots = { 5, 7 }, rolls = { 0, 2 }, safe = false, dog = false, pickup = 'small_tv' },
        medium  = { tier = 2, label = 'بيت متوسط', interior = 2, spots = { 7, 9 }, rolls = { 0, 2 }, safe = { 800, 1200 }, dog = false, pickup = 'small_tv' },
        mansion = { tier = 3, label = 'فيلا', interior = 3, spots = { 9, 12 }, rolls = { 1, 2 }, safe = { 1200, 1800 }, dog = true, pickup = 'painting', usb = 0.10 },
    },
    -- what one search can find (weight = how often)
    loot = {
        { item = 'black_money', amount = { 60, 240 }, weight = 30 },
        { item = 'goldchain', amount = { 1, 1 }, weight = 14 },
        { item = '10kgoldchain', amount = { 1, 2 }, weight = 14 },
        { item = 'rolex', amount = { 1, 1 }, weight = 9 },
        { item = 'diamond_ring', amount = { 1, 1 }, weight = 7 },
        { item = 'stolen_laptop', amount = { 1, 1 }, weight = 8 },
        { item = 'stolen_console', amount = { 1, 1 }, weight = 8 },
        { item = 'diamond', amount = { 1, 1 }, weight = 3, minTier = 3 },
    },
    -- inside: exit = where you stand after coming in (and the [E] to leave); spots = drawers, closets, shelves;
    -- safe = the wall safe; pickup = the big item (carried out at walking speed); dog = where the guard dog sleeps
    interiors = {
        [1] = { exit = vec4(266.11, -1007.61, -101.01, 357.68),
            spots = { vec3(265.97, -999.46, -99.01), vec3(265.66, -997.40, -99.01), vec3(263.69, -995.40, -99.01), vec3(262.67, -999.88, -99.01),
                      vec3(257.01, -995.84, -99.01), vec3(256.73, -998.34, -99.01), vec3(259.98, -1004.0, -99.01) },
            pickup = { pos = vec3(262.77, -1002.53, -99.01), model = 'prop_tv_flat_03' } },
        [2] = { exit = vec4(346.55, -1012.83, -99.2, 5.8),
            spots = { vec3(346.15, -1001.71, -99.2), vec3(345.01, -995.49, -99.2), vec3(341.97, -997.45, -99.2), vec3(340.69, -995.03, -99.2),
                      vec3(338.35, -995.22, -99.2), vec3(338.31, -997.88, -99.2), vec3(339.71, -1000.35, -99.2), vec3(338.6, -1003.18, -99.2),
                      vec3(351.13, -999.23, -99.2), vec3(351.31, -993.76, -99.2), vec3(349.36, -995.05, -99.2) },
            safe = vec3(347.5, -994.17, -99.2),
            pickup = { pos = vec3(344.14, -1002.33, -99.2), model = 'prop_tv_flat_01' } },
        [3] = { exit = vec4(-174.27, 497.71, 137.65, 191.5),
            spots = { vec3(-170.21, 495.82, 137.65), vec3(-168.18, 494.13, 137.65), vec3(-171.02, 486.88, 137.44), vec3(-163.0, 482.49, 137.27),
                      vec3(-164.44, 487.09, 137.44), vec3(-170.32, 482.18, 133.85), vec3(-162.86, 482.02, 133.87), vec3(-167.4, 487.85, 133.84),
                      vec3(-165.71, 495.38, 133.85), vec3(-172.71, 500.42, 130.04), vec3(-170.01, 491.14, 130.04), vec3(-174.03, 493.64, 130.04) },
            safe = vec3(-175.79, 492.05, 130.04),
            pickup = { pos = vec3(-165.26, 495.01, 137.65), model = 'ch_prop_vault_painting_01a' },
            dog = vec3(-174.45, 496.08, 130.04) },
    },
    -- the front doors (outside). size picks the interior.
    doors = {
        { pos = vec3(495.25, -1823.31, 28.87), size = 'small', area = 'ديفيس' },
        { pos = vec3(311.99, -1956.12, 24.62), size = 'small', area = 'ديفيس' },
        { pos = vec3(1193.67, -1656.54, 43.03), size = 'small', area = 'إل بوريو' },
        { pos = vec3(179.29, -1923.98, 21.37), size = 'small', area = 'ستروبيري' },
        { pos = vec3(-64.58, -1449.61, 32.52), size = 'small', area = 'ستروبيري' },
        { pos = vec3(-138.22, -1470.78, 36.99), size = 'small', area = 'ستروبيري' },
        { pos = vec3(69.43, -56.69, 73.02), size = 'small', area = 'هاوك' },
        { pos = vec3(-102.84, -11.91, 70.52), size = 'small', area = 'بيرتون' },
        { pos = vec3(1435.45, 3657.04, 34.4), size = 'small', area = 'ساندي شورز' },
        { pos = vec3(1808.93, 3907.97, 33.74), size = 'small', area = 'ساندي شورز' },
        { pos = vec3(-480.95, 6266.33, 13.63), size = 'small', area = 'باليتو' },
        { pos = vec3(-280.54, 6350.67, 32.6), size = 'small', area = 'باليتو' },
        { pos = vec3(-884.14, -1072.51, 2.53), size = 'medium', area = 'فسبوتشي' },
        { pos = vec3(-1134.11, -1050.19, 2.15), size = 'medium', area = 'فسبوتشي' },
        { pos = vec3(-1089.85, -1680.31, 4.67), size = 'medium', area = 'فسبوتشي بيتش' },
        { pos = vec3(960.01, -669.94, 58.45), size = 'medium', area = 'ميرور بارك' },
        { pos = vec3(1240.51, -601.62, 69.78), size = 'medium', area = 'ميرور بارك' },
        { pos = vec3(1098.57, -464.54, 67.32), size = 'medium', area = 'ميرور بارك' },
        { pos = vec3(-332.97, 57.08, 54.43), size = 'medium', area = 'وست فاينوود' },
        { pos = vec3(-1009.5, 479.12, 79.59), size = 'medium', area = 'روكفورد هيلز' },
        { pos = vec3(-371.74, 343.46, 109.94), size = 'medium', area = 'فاينوود هيلز' },
        { pos = vec3(-174.65, 502.47, 137.42), size = 'mansion', area = 'فاينوود هيلز (وايلد أوتس)' },
    },
}
Config.calls.atm = 'سرقة جهاز صراف آلي'
Config.calls.jewelry = 'سطو على محل المجوهرات'
Config.calls.jewelryQuiet = 'إنذار متأخر: محل المجوهرات'

---------------------------------------------------------------------------
-- ATM pull (Tier 2): a tow chain from a pickup truck to a wall ATM, floor it, drag it somewhere quiet, drill it
---------------------------------------------------------------------------
Config.atm = {
    tier = 2,
    models = { 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
    trucks = { 'bison', 'bison2', 'bison3', 'bobcatxl', 'sadler', 'sandking', 'sandking2', 'rebel', 'rebel2', 'guardian', 'kamacho',
               'caracara2', 'everon', 'yosemite', 'yosemite3', 'riata', 'contender', 'dubsta3', 'towtruck', 'towtruck2', 'flatbed', 'mesa3', 'bodhi2' },
    perHour = 2,              -- ATM pulls in the whole city per hour
    cooldownHours = 6,        -- the same ATM
    hiddenMinutes = 30,       -- a pulled ATM is gone from the wall this long (then it's "replaced")
    hookSeconds = 6,
    quietDistance = 120.0,    -- drill it at least this far from where it was
    pay = { 3000, 5000 },     -- black_money
}

---------------------------------------------------------------------------
-- the jewelry store (Tier 3): Vangelico, 20 cases (GTA's own store; the spots come from Qbox's qbx_jewelery data)
---------------------------------------------------------------------------
Config.jewelry = {
    tier = 3,
    cooldownMinutes = 120,    -- the whole store
    quietSeconds = 180,       -- the green USB at the panel: cameras and alarm off this long
    hackTries = 2,            -- 2 failed hacks = the alarm
    panel = vec4(-624.295, -215.22, 52.54, 118.0),   -- the security box on the roof
    area = vec3(-622.6, -231.0, 38.0),
    rolls = { 1, 2 },         -- loot rolls per case
    loot = {
        { item = 'rolex', amount = { 1, 2 }, weight = 30 },
        { item = 'diamond_ring', amount = { 1, 1 }, weight = 25 },
        { item = 'goldchain', amount = { 1, 2 }, weight = 30 },
        { item = '10kgoldchain', amount = { 1, 3 }, weight = 25 },
        { item = 'diamond', amount = { 1, 1 }, weight = 8 },
    },
    cases = {
        { pos = vec3(-626.83, -235.35, 38.05), h = 36.17, ray = 'DES_Jewel_Cab3' }, { pos = vec3(-625.81, -234.7, 38.05), h = 36.17, ray = 'DES_Jewel_Cab4' },
        { pos = vec3(-626.95, -233.14, 38.05), h = 216.17, ray = 'DES_Jewel_Cab' }, { pos = vec3(-628.0, -233.86, 38.05), h = 216.17, ray = 'DES_Jewel_Cab' },
        { pos = vec3(-625.7, -237.8, 38.05), h = 216.17, ray = 'DES_Jewel_Cab3' }, { pos = vec3(-626.7, -238.58, 38.05), h = 216.17, ray = 'DES_Jewel_Cab2' },
        { pos = vec3(-624.55, -231.06, 38.05), h = 305.0, ray = 'DES_Jewel_Cab4' }, { pos = vec3(-623.13, -232.94, 38.05), h = 305.0, ray = 'DES_Jewel_Cab' },
        { pos = vec3(-620.29, -234.44, 38.05), h = 216.17, ray = 'DES_Jewel_Cab' }, { pos = vec3(-619.15, -233.66, 38.05), h = 216.17, ray = 'DES_Jewel_Cab3' },
        { pos = vec3(-620.19, -233.44, 38.05), h = 36.17, ray = 'DES_Jewel_Cab4' }, { pos = vec3(-617.63, -230.58, 38.05), h = 305.0, ray = 'DES_Jewel_Cab2' },
        { pos = vec3(-618.33, -229.55, 38.05), h = 305.0, ray = 'DES_Jewel_Cab3' }, { pos = vec3(-619.7, -230.33, 38.05), h = 125.0, ray = 'DES_Jewel_Cab' },
        { pos = vec3(-620.95, -228.6, 38.05), h = 125.0, ray = 'DES_Jewel_Cab3' }, { pos = vec3(-619.79, -227.6, 38.05), h = 305.0, ray = 'DES_Jewel_Cab2' },
        { pos = vec3(-620.42, -226.6, 38.05), h = 305.0, ray = 'DES_Jewel_Cab' }, { pos = vec3(-623.94, -227.18, 38.05), h = 36.17, ray = 'DES_Jewel_Cab4' },
        { pos = vec3(-624.91, -227.87, 38.05), h = 36.17, ray = 'DES_Jewel_Cab3' }, { pos = vec3(-623.94, -228.05, 38.05), h = 216.17, ray = 'DES_Jewel_Cab2' },
    },
}
Config.games.drill = { minSeconds = 8.0 }
Config.games.glasscut = { minSeconds = 4.0 }
Config.games.hack = { minSeconds = 6.0 }

---------------------------------------------------------------------------
-- the fence's daily contracts (texted each day to characters who know him)
---------------------------------------------------------------------------
Config.contracts = {
    perDay = 3,
    dayStartsHour = 6,
    reward = { xp = 10, money = { 400, 900 } },   -- each contract done (dirty money)
    pool = {
        { id = 'stores',    kind = 'store',     need = { 2, 3 }, text = 'اسرق %d صناديق محلات' },
        { id = 'safe',      kind = 'storesafe', need = 1,        text = 'افتح خزنة محل (%d)', minRep = 2 },
        { id = 'house',     kind = 'house',     need = 1,        text = 'ادخل بيتًا من بيوتي وخذ شيئًا (%d)' },
        { id = 'atm',       kind = 'atm',       need = 1,        text = 'اقتلع جهاز صراف وافتحه (%d)', minRep = 2 },
        { id = 'jewel',     kind = 'jewel',     need = { 2, 4 }, text = 'افتح %d خزائن في فانجيليكو', minRep = 3 },
        { id = 'watches',   kind = 'sell', item = 'rolex',        need = { 2, 3 }, text = 'بِعني %d ساعات رولكس' },
        { id = 'rings',     kind = 'sell', item = 'diamond_ring', need = { 1, 2 }, text = 'بِعني %d خواتم ألماس' },
        { id = 'laptops',   kind = 'sell', item = 'stolen_laptop', need = 1,       text = 'أحضر لي حاسوبًا مسروقًا (%d)' },
        { id = 'tv',        kind = 'sell', item = 'small_tv',     need = 1,        text = 'أحضر لي تلفازًا (%d)' },
    },
}
