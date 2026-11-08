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
    lootItems = { 'black_money', 'marked_bills', 'rolex', 'diamond_ring', 'goldchain', 'diamond', 'small_tv', 'stolen_laptop', 'stolen_console', 'stolen_radio', 'stolen_microwave', '10kgoldchain', 'painting', 'vault_goldbar', 'bearer_bonds', 'mw_electronics' },
}

---------------------------------------------------------------------------
-- NPC security (no-police mode): "حراسة الحي"
---------------------------------------------------------------------------
Config.npc = {
    enabled = false,         -- EX_Tii (Moe): off for now. true = the NPC guards come to robberies again
    kinds = {   -- delay = seconds after the alarm, cars = how many (each car: 2 guards)
        -- (EX_Tii: faster and more of them; they drive in from 160-260 m, about 20-30 s more)
        store   = { delay = 40,  cars = { 2, 3 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_PUMPSHOTGUN' } },
        house   = { delay = 40,  cars = { 2, 2 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_PISTOL' } },
        atm     = { delay = 40,  cars = { 2, 2 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_PUMPSHOTGUN' } },
        jewelry = { delay = 60,  cars = { 2, 3 }, weapons = { 'WEAPON_PISTOL', 'WEAPON_CARBINERIFLE' } },
        bank    = { delay = 75,  cars = { 3, 4 }, weapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_PUMPSHOTGUN' } },
        truck   = { delay = 60,  cars = { 2, 3 }, weapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_SMG' } },
    },
    lostSeconds = 60,        -- out of their sight this long: they lose you (like GTA's wanted stars)
    knowDistance = 45.0,     -- this close to one of them you are never "out of sight" (hiding in the shop doesn't lose them)
    arriveTimeout = 60,      -- seconds: they count as on scene after this even if a car got stuck on the way
    giveUpDistance = 220.0,  -- nobody this close to the spot when they arrive: they don't come
    copStandDown = 100.0,    -- a real cop this close to a robber: the NPCs back off
    maxMinutes = 12,         -- they give up after this long anyway
    accuracy = 34,           -- EX_Tii: hard. A good shooter wins about half the fights against them
    health = 200, armour = 75, -- each guard (GTA default 100 health)
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
    aimSeconds = 20,          -- keep the gun on him while he opens the till (Moe: 20)
    reportSeconds = 10,       -- EX_Tii (Moe): the police are told 10 s after the gun is pointed, whatever happens next
    lookAwaySeconds = 2,      -- look away this long: he ALWAYS presses the silent alarm (you get a warning first)
    cowerSeconds = 2,         -- look away this long: he drops behind the counter, lockpick the till (Moe: 2, same as the alarm)
    shotResetMinutes = 5,     -- shot: he stays down this long, then the shop opens again
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
    hintNumber = 'رقم مجهول',     -- after a first robbery, a stranger texts where to look for him (until you meet him)
    hintRadius = 160.0,           -- the circle on the map (he is somewhere inside, not in the middle)
    hintMinutes = 0,              -- EX_Tii (Moe): 0 = the circle stays until you meet him
    leadCooldownMinutes = 20,     -- one lead per character this often
    -- what he buys (dirty money each), and how many of each he takes per day from the whole city
    goods = {
        rolex          = { price = 450,  daily = 25 },
        diamond_ring   = { price = 600,  daily = 25 },
        goldchain      = { price = 300,  daily = 40 },
        ['10kgoldchain'] = { price = 200, daily = 40 },
        diamond        = { price = 900,  daily = 15 },
        small_tv       = { price = 350,  daily = 20 },
        stolen_radio   = { price = 160,  daily = 40 },
        stolen_microwave = { price = 200, daily = 40 },
        stolen_laptop  = { price = 500,  daily = 20 },
        stolen_console = { price = 400,  daily = 20 },
        painting       = { price = 1400, daily = 8 },
        vault_goldbar  = { price = 15000, daily = 5 },
        bearer_bonds   = { price = 4000, daily = 10 },
        mw_electronics = { price = 1800, daily = 12 },
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
        sprint = 24, run = 11, jump = 14, search = 3, safeFail = 18, pickFail = 10, window = 55, decay = 3, -- per second (EX_Tii: running fills it, only walking lets it fall)
        shot = 100, shotSilenced = 40,    -- one shot (a suppressor still makes noise)
        smash = 30,                       -- glass / something broken by a hit or a bullet
        melee = 8,                        -- a punch or a swing
        nearSleeper = 3,                  -- per second while you stand next to the sleeping owner (no calming down)
        bark = 25,                        -- the dog barks
    },
    sleeperReach = 2.5,                   -- "next to the sleeping owner"
    dogSees = 7.0,                        -- the dog wakes when you come this close (and it can see you)
    sizes = {
        small   = { tier = 1, label = 'شقة صغيرة', interior = 1, spots = { 5, 7 }, rolls = { 1, 1 }, safe = false, dog = false, sleeper = true, pickup = 'small_tv' },
        medium  = { tier = 2, label = 'بيت متوسط', interior = 2, spots = { 7, 9 }, rolls = { 1, 2 }, safe = { 800, 1200 }, dog = false, sleeper = true, pickup = 'small_tv' },
        mansion = { tier = 3, label = 'فيلا', interior = 3, spots = { 9, 12 }, rolls = { 1, 2 }, safe = { 1200, 1800 }, dog = true, sleeper = true, pickup = 'painting', usb = 0.10 },
    },
    -- what one search can find (weight = how often): mostly things from the house (radios, microwaves,
    -- electronics), some jewelry, a little dirty money. The TV / painting is the big item you carry out.
    loot = {
        { item = 'stolen_radio', amount = { 1, 1 }, weight = 24 },
        { item = 'stolen_microwave', amount = { 1, 1 }, weight = 20 },
        { item = 'stolen_laptop', amount = { 1, 1 }, weight = 11 },
        { item = 'stolen_console', amount = { 1, 1 }, weight = 11 },
        { item = 'goldchain', amount = { 1, 1 }, weight = 8 },
        { item = '10kgoldchain', amount = { 1, 1 }, weight = 7 },
        { item = 'rolex', amount = { 1, 1 }, weight = 4 },
        { item = 'diamond_ring', amount = { 1, 1 }, weight = 3 },
        { item = 'diamond', amount = { 1, 1 }, weight = 3, minTier = 3 },
        { item = 'black_money', amount = { 40, 140 }, weight = 7 },
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
-- ATM pull (Tier 2): a tow chain from a wall ATM to the back of any car, floor it, drag it somewhere quiet, drill it
---------------------------------------------------------------------------
Config.atm = {
    tier = 2,
    models = { 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
    trucks = { 'bison', 'bison2', 'bison3', 'bobcatxl', 'sadler', 'sandking', 'sandking2', 'rebel', 'rebel2', 'guardian', 'kamacho',
               'caracara2', 'everon', 'yosemite', 'yosemite3', 'riata', 'contender', 'dubsta3', 'towtruck', 'towtruck2', 'flatbed', 'mesa3', 'bodhi2' },
    perHour = 2,              -- ATM pulls in the whole city per hour
    cooldownHours = 6,        -- the same ATM
    hiddenMinutes = 30,       -- a pulled ATM is gone from the wall this long (then it's "replaced")
    hookSeconds = 5,          -- wrapping the chain round the ATM
    carSeconds = 4,           -- tying the other end to the car's back
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
        { id = 'fleeca',    kind = 'fleeca', need = { 2, 3 }, text = 'افتح %d صناديق أمانات في فليكا', minRep = 4 },
        { id = 'truck',     kind = 'armored', need = 1,       text = 'أفرغ شاحنة مصفّحة (%d)', minRep = 5 },
    },
}

---------------------------------------------------------------------------
-- hostages (zip ties): aim at a person on the street or in a store, walk up, [G] tie him up.
-- With real cops: a hostage call; it's roleplay from there. With NPC security: they hold their fire
-- while you have hostages, and each one you let go buys a head start. Hurt one: no more talking.
---------------------------------------------------------------------------
Config.hostages = {
    maxPerRobber = 4,
    aimDistance = 12.0,       -- aim at a person this close: hands up (aim at him again: flat on his stomach)
    tieDistance = 1.8,
    tieSeconds = 4,
    leaveDistance = 150.0,    -- the robber is this far from his hostage: he goes free
    playerMaxMinutes = 40,    -- a PLAYER hostage is never kept longer than this (nobody stuck tied for good)
    playerFreeDownMinutes = 3, -- his robber is down this long: the player hostage goes free
    copFreeBonus = 250,       -- an officer who frees a hostage (bank): not his own, held 60 s+, 5 a day
    minHoldForBonus = 60, copFreeDaily = 5,
    hurtMinutes = 60,         -- a robber who hurt a hostage: double arrest bonus this long
    rageAccuracy = 55,        -- NPC police after a hostage was hurt, the deal broke, or the standoff ran out
    -- NPC police with a hostage (no-police mode): they hold their fire until a deal, a hurt hostage, or the time
    standoffMinutes = 15,     -- no deal by then: they storm in
    moreTimeMinutes = 5,      -- "more time" (once)
    dropDistance = { 400, 800 }, -- the drop-off spot they text you: this far from where you are
    dropRadius = 30.0,        -- let him go this close to the spot
    dropMinutes = 6,          -- to get there (they follow you, no shooting)
    dropHeadStart = 10,       -- he's out at the spot: they stay put this long, then come after you
    releaseHeadStart = 10,    -- "release on the spot" (the same)
    chaseMinutes = 15,        -- the chase after a deal: they give up after this long
    chaseLostSeconds = 120,   -- out of their sight this long in that chase: you lost them
    surrenderJail = 10,       -- minutes of prison when you give up to them
    leaveJail = 15,           -- left with a hostage (logged out / went into a house): prison on return
    swat = { cars = 4, weapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_SPECIALCARBINE' }, armour = 100, accuracy = 55, ped = 's_m_y_swat_01', car = 'fbi2' },
    roadblocks = { every = 45, max = 5, ahead = 260.0, weapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_PUMPSHOTGUN' } },
    pursuitCars = 2,          -- the chase after a deal: this many more cars join, right behind you
    chaseAccuracy = 45,       -- the chase after a deal: they shoot to stop you
    blindProp = 'prop_money_bag_01', -- the cloth sack over the head
}
Config.calls.hostages = 'احتجاز رهائن'
Config.calls.hostageHurt = 'رهينة أُصيبت'

-- robbing a PLAYER (Z wheel → فتّشه): only someone with his hands up (X), tied with zip ties, or down.
-- Someone cuffed by the police: only the officer searches him (exti_police, it all goes to the seized room).
-- The robber searches for a few seconds, then the person's bag opens next to his own and he drags out
-- what he wants. The victim is told, every item taken is written in the heist log.
Config.rob = {
    reach = 2.0,          -- how close to the person to start (meters)
    keepReach = 3.0,      -- the bag closes if he moves farther than this
    searchSeconds = 5,    -- the search before the bag opens
    -- what always stays with its owner (his papers and his phone)
    keep = { id_card = true, driver_license = true, weaponlicense = true, lawyerpass = true, phone = true },
    -- no robbing here (the same safe zones as the new-player guide: job center, spawn, Legion Square, hospital)
    safeZones = {
        { coords = vec3(-232.44, -915.57, 32.30), radius = 35.0 },
        { coords = vec3(-265.49, -962.85, 31.22), radius = 25.0 },
        { coords = vec3(195.17, -933.77, 29.7), radius = 45.0 },
        { coords = vec3(308.19, -595.35, 43.29), radius = 40.0 },
    },
}

-- the NPC negotiator (no-police mode): texts you when the units are on scene
Config.negotiator = {
    number = '555-0119',      -- shows as the sender in the phone (also the admins' messages)
    textAfter = 6,            -- seconds after they arrive (really there: out of their cars)
    startTrust = 40,          -- the phone call: trust at the start (0-100; 0 = he ends the talk, the SWAT team)
    surrenderXp = -5,
}

-- cop bonuses (bank): an arrest of a robber with heat, per tier of his last robbery
Config.copBonus = { perTier = 150, hostageHurtMult = 2.0 }

---------------------------------------------------------------------------
-- crews and the monthly boards (the phone's Crew app)
---------------------------------------------------------------------------
Config.crew = {
    maxMembers = 6,
    titles = {   -- the top 3 of each board on the 1st of the month (kept forever)
        crew = { 'أخطر طاقم في المدينة', 'ثاني أخطر طاقم', 'ثالث أخطر طاقم' },
        rob  = { 'لص الشهر', 'ثاني لصوص الشهر', 'ثالث لصوص الشهر' },
        cop  = { 'شرطي الشهر', 'ثاني شرطيي الشهر', 'ثالث شرطيي الشهر' },
    },
}

---------------------------------------------------------------------------
-- M3: the minigames' minimum times (the server refuses a faster result)
---------------------------------------------------------------------------
Config.games.c4 = { minSeconds = 4.0 }
Config.games.wirecut = { minSeconds = 3.0 }
Config.games.keypad = { minSeconds = 4.0 }

Config.calls.fleeca = 'سطو على بنك فليكا'
Config.calls.fleecaQuiet = 'إنذار متأخر: بنك فليكا'
Config.calls.truck = 'سطو على شاحنة مصفّحة'
Config.calls.convoy = 'هجوم على قافلة ميري ويذر'
Config.calls.stash = 'إطلاق نار في مزرعة الكارتيل'
Config.calls.prep = 'سرقة من سيارة'

-- one bank at a time in the whole city (Fleeca, Paleto, Pacific)
Config.bankLock = true

---------------------------------------------------------------------------
-- banks (vaults). Every step is a minigame at a spot; some open a door, some start a time lock.
-- alarm: 'start' = the alarm goes off when the step starts, 'fail' = only if it fails, 'quiet' = a late alarm
-- (quietSeconds after the step) unless a wire-cut step before it worked. GTA's own Fleeca interiors.
---------------------------------------------------------------------------
local function fleeca(label, area, door, doorModel, closed, open, panel, lockers)
    return {
        kind = 'fleeca', tier = 4, label = label, area = area, center = door, radius = 18.0,
        cooldownMinutes = 120, crew = { 2, 4 },
        steps = {
            { id = 'alarm', label = '[E] افتح لوحة الإنذار واقطع الأسلاك', at = panel, game = 'wirecut', params = {}, alarm = 'fail', quiet = true, optional = true },
            { id = 'vault', label = '[E] اخترق قفل الخزنة (فلاشة خضراء)', at = door, game = 'hack', params = { tier = 1 }, item = 'usb_green', alarm = 'quiet',
              timelock = 90, opens = 'vault' },
        },
        doors = { vault = { model = doorModel, pos = door, closed = closed, open = open } },
        lockers = lockers, lockerGame = 'drill',
        loot = { item = 'marked_bills', money = { 3200, 5000 }, usb = { item = 'usb_blue', chance = 0.15 } },
        quietSeconds = 90,   -- the alarm panel cut: the bank's alarm only goes off this long after the vault hack
    }
end
Config.vaults = {
    fleeca_legion = fleeca('فليكا · ليجن سكوير', 'ليجن سكوير', vec3(146.92, -1046.11, 29.36), `v_ilev_gb_vauldr`, 250.0, 160.0, vec3(147.75, -1044.40, 29.37), {
        vec3(149.84, -1044.9, 29.34), vec3(151.16, -1046.64, 29.34), vec3(147.16, -1047.72, 29.34), vec3(146.54, -1049.28, 29.34),
        vec3(146.88, -1050.33, 29.34), vec3(150.0, -1050.67, 29.34), vec3(149.47, -1051.28, 29.34), vec3(150.58, -1049.09, 29.34) }),
    fleeca_alta = fleeca('فليكا · ألتا', 'ألتا', vec3(311.15, -284.49, 54.16), `v_ilev_gb_vauldr`, 250.0, 160.0, vec3(311.98, -282.78, 54.17), {
        vec3(311.16, -287.71, 54.14), vec3(311.86, -286.21, 54.14), vec3(313.39, -289.15, 54.14), vec3(311.7, -288.45, 54.14),
        vec3(314.23, -288.77, 54.14), vec3(314.83, -287.33, 54.14), vec3(315.24, -284.85, 54.14), vec3(314.08, -283.38, 54.14) }),
    fleeca_hawick = fleeca('فليكا · هاويك', 'بيرتون', vec3(-353.82, -55.37, 49.03), `v_ilev_gb_vauldr`, 250.0, 160.0, vec3(-352.99, -53.66, 49.04), {
        vec3(-350.99, -54.13, 49.01), vec3(-349.53, -55.77, 49.01), vec3(-353.54, -56.94, 49.01), vec3(-354.09, -58.55, 49.01),
        vec3(-353.81, -59.48, 49.01), vec3(-349.8, -58.3, 49.01), vec3(-351.14, -60.37, 49.01), vec3(-350.4, -59.92, 49.01) }),
    fleeca_delperro = fleeca('فليكا · ديل بيرو', 'روكفورد هيلز', vec3(-1210.77, -336.57, 37.78), `v_ilev_gb_vauldr`, 296.863, 206.863, vec3(-1211.70, -334.94, 37.79), {
        vec3(-1209.68, -333.65, 37.75), vec3(-1207.46, -333.77, 37.75), vec3(-1209.45, -337.47, 37.75), vec3(-1208.65, -339.06, 37.75),
        vec3(-1207.75, -339.42, 37.75), vec3(-1205.28, -338.14, 37.75), vec3(-1205.08, -337.28, 37.75), vec3(-1205.92, -335.75, 37.75) }),
    fleeca_ocean = fleeca('فليكا · الطريق الساحلي', 'بانهام كانيون', vec3(-2956.55, 481.74, 15.69), `hei_prop_heist_sec_door`, 357.542, 267.542, vec3(-2958.21, 482.53, 15.70), {
        vec3(-2958.54, 484.1, 15.67), vec3(-2957.3, 485.95, 15.67), vec3(-2955.09, 482.43, 15.67), vec3(-2953.26, 482.42, 15.67),
        vec3(-2952.63, 483.09, 15.67), vec3(-2952.45, 485.66, 15.67), vec3(-2953.13, 486.26, 15.67), vec3(-2954.98, 486.37, 15.67) }),
    fleeca_route68 = fleeca('فليكا · الطريق 68', 'هارموني', vec3(1175.96, 2712.87, 38.09), `v_ilev_gb_vauldr`, 89.458, -10.542, vec3(1176.40, 2711.03, 38.10), {
        vec3(1173.69, 2710.76, 38.07), vec3(1171.78, 2711.94, 38.07), vec3(1175.25, 2714.51, 38.07), vec3(1175.26, 2715.97, 38.07),
        vec3(1174.27, 2716.83, 38.07), vec3(1172.32, 2716.82, 38.07), vec3(1171.25, 2716.08, 38.07), vec3(1171.23, 2714.44, 38.07) }),
}
Config.hotBranch = { mult = 2.0 }   -- one Fleeca a day holds double (the fence hints which: text him "بنك")

---------------------------------------------------------------------------
-- guards (stash house, convoy, big banks): server-made people who patrol, see and hear, call for help.
---------------------------------------------------------------------------
Config.guards = {
    sight = 38.0, cone = 70,          -- metres, degrees (each side)
    noticeSeconds = 2.2,              -- seen this long in the open (faster if armed, masked, running)
    hearShots = 70.0, hearRun = 9.0,
    accuracy = 30, armour = 60,
    rel = 'EXTI_GUARD',
}

---------------------------------------------------------------------------
-- the armored truck (Tier 5) and the Merryweather convoy (Tier 6): text the fence "شاحنة" / "قافلة"
---------------------------------------------------------------------------
Config.trucks = {
    armored = {
        tier = 5, label = 'شاحنة غروبه 6 المصفّحة', cooldownMinutes = 180, cost = 0, needs = {},
        model = 'stockade', guardModel = 's_m_m_security_01',
        crew = { { seat = -1, weapon = 'WEAPON_COMBATPISTOL' }, { seat = 0, weapon = 'WEAPON_PUMPSHOTGUN' }, { seat = 1, weapon = 'WEAPON_SMG' } },
        escorts = {},
        speed = 16.0,
        bags = 4, bagSeconds = 6, money = { 7500, 11200 }, item = 'marked_bills', usb = { item = 'usb_blue', chance = 0.10 },
        gpsSeconds = 180, fuseSeconds = 30,
    },
    convoy = {
        tier = 6, label = 'قافلة ميري ويذر', cooldownMinutes = 360, cost = 8000, needs = { usb = 'usb_blue', prep = 'blueprints' },
        model = 'mule', guardModel = 's_m_y_blackops_01',
        crew = { { seat = -1, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 0, weapon = 'WEAPON_CARBINERIFLE' } },
        escorts = { { model = 'mesa3', crew = { { seat = -1, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 0, weapon = 'WEAPON_CARBINERIFLE' } } },
                    { model = 'mesa3', crew = { { seat = -1, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 0, weapon = 'WEAPON_SPECIALCARBINE' } } } },
        speed = 14.0,
        bags = 6, bagSeconds = 7, money = { 6500, 9500 }, item = 'black_money', extra = { item = 'mw_electronics', amount = { 2, 4 } }, usb = { item = 'usb_red', chance = 0.10 },
        gpsSeconds = 0, fuseSeconds = 30,
    },
    -- the roads they drive (start, then the way points); the server picks one
    routes = {
        { vec4(-281.05, -617.55, 33.35, 276.51), vec3(-74.0, -610.0, 36.0), vec3(135.0, -560.0, 43.0), vec3(240.0, -365.0, 44.0), vec3(395.0, -350.0, 46.5), vec3(560.0, -400.0, 44.0) },
        { vec4(2.55, -671.9, 32.34, 181.81), vec3(10.0, -860.0, 30.0), vec3(110.0, -1020.0, 29.0), vec3(220.0, -1060.0, 29.0), vec3(400.0, -1060.0, 29.0), vec3(500.0, -1240.0, 29.0) },
        { vec4(147.24, -1081.15, 29.19, 1.6), vec3(150.0, -950.0, 30.0), vec3(250.0, -650.0, 42.0), vec3(320.0, -470.0, 43.0), vec3(220.0, -200.0, 54.0), vec3(110.0, 30.0, 80.0) },
        { vec4(-1187.67, -321.86, 37.61, 22.79), vec3(-1100.0, -260.0, 37.5), vec3(-950.0, -240.0, 37.8), vec3(-760.0, -220.0, 37.0), vec3(-650.0, -320.0, 35.0), vec3(-570.0, -480.0, 34.5) },
        { vec4(1226.0, 2690.0, 37.6, 90.0), vec3(1000.0, 2690.0, 39.0), vec3(700.0, 2700.0, 40.0), vec3(450.0, 2640.0, 43.0), vec3(250.0, 2620.0, 45.0), vec3(-20.0, 2860.0, 57.0) },
    },
}

---------------------------------------------------------------------------
-- the cartel stash house (Tier 6): La Fuente Blanca. Guards in the yard, the money in the barn.
---------------------------------------------------------------------------
Config.stash = {
    tier = 6, label = 'مزرعة الكارتيل', area = 'لا فوينتي بلانكا', cooldownMinutes = 360, cost = 6000,
    needs = { usb = 'usb_blue', prep = 'guard_keycard' },
    center = vec3(1440.0, 1120.0, 114.3), radius = 120.0,
    model = 'g_m_m_mexboss_01', models = { 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03' },
    guards = {   -- where each stands; patrol = the points he walks between
        { pos = vec4(1394.6, 1141.7, 114.3, 90.0), weapon = 'WEAPON_ASSAULTRIFLE', patrol = { vec3(1394.6, 1141.7, 114.3), vec3(1394.0, 1120.0, 114.3), vec3(1410.0, 1110.0, 114.3) } },
        { pos = vec4(1420.0, 1150.0, 114.3, 180.0), weapon = 'WEAPON_MICROSMG', patrol = { vec3(1420.0, 1150.0, 114.3), vec3(1450.0, 1150.0, 114.3) } },
        { pos = vec4(1455.0, 1125.0, 114.3, 270.0), weapon = 'WEAPON_ASSAULTRIFLE', patrol = { vec3(1455.0, 1125.0, 114.3), vec3(1455.0, 1100.0, 114.3), vec3(1435.0, 1095.0, 114.3) } },
        { pos = vec4(1462.0, 1112.0, 114.3, 0.0), weapon = 'WEAPON_PUMPSHOTGUN' },
        { pos = vec4(1405.0, 1095.0, 114.3, 45.0), weapon = 'WEAPON_ASSAULTRIFLE', patrol = { vec3(1405.0, 1095.0, 114.3), vec3(1430.0, 1080.0, 114.3) } },
        { pos = vec4(1470.0, 1140.0, 114.3, 200.0), weapon = 'WEAPON_MACHINEPISTOL' },
    },
    waves = { { delay = 45, from = vec4(1370.0, 1180.0, 113.5, 200.0), count = 3, weapon = 'WEAPON_ASSAULTRIFLE' },
              { delay = 110, from = vec4(1500.0, 1180.0, 112.0, 140.0), count = 3, weapon = 'WEAPON_CARBINERIFLE' } },
    -- the gate camera box: the blue USB keeps the yard blind (no instant alert at first sight)
    camera = vec3(1388.6, 1150.6, 114.3),
    crates = { vec4(1468.2, 1131.0, 114.3, 90.0), vec4(1468.2, 1129.0, 114.3, 90.0), vec4(1466.5, 1127.2, 114.3, 0.0), vec4(1464.4, 1127.2, 114.3, 0.0), vec4(1466.0, 1133.4, 114.3, 180.0) },
    crateModel = 'prop_box_wood05a', crateSeconds = 8,
    money = { 8000, 12000 }, usb = { item = 'usb_red', chance = 0.10 },
}

---------------------------------------------------------------------------
-- prep missions: a car parked somewhere with what the big job needs, sometimes guarded
---------------------------------------------------------------------------
Config.preps = {
    guard_keycard = { label = 'بطاقة حارس الكارتيل', model = 'cavalcade', guards = 2, guardModel = 'g_m_y_mexgoon_01', weapon = 'WEAPON_PISTOL' },
    blueprints    = { label = 'مخططات قافلة ميري ويذر', model = 'baller', guards = 2, guardModel = 's_m_y_blackops_01', weapon = 'WEAPON_CARBINERIFLE' },
    catering_uniform = { label = 'زي شركة التموين', model = 'pony', guards = 0 },
    spots = {
        vec4(-1153.0, -1561.0, 4.4, 35.0), vec4(-339.0, -1530.0, 27.5, 0.0), vec4(1217.0, -1385.0, 35.2, 180.0), vec4(-1324.0, -421.0, 34.5, 120.0),
        vec4(872.0, -2196.0, 30.5, 85.0), vec4(-97.0, 6340.0, 31.5, 225.0), vec4(1695.0, 3594.0, 35.4, 210.0), vec4(-3175.0, 1090.0, 20.8, 245.0),
    },
    minutes = 45, cooldownMinutes = 30, lockpickPins = 5, itemHours = 24,
}

---------------------------------------------------------------------------
-- M4: the Broker (الوسيط)
---------------------------------------------------------------------------
Config.broker = {
    number = '555-0420',
    minRep = 4,
    usbs = {   -- clean money from the bank; a few a day for the whole city
        usb_green = { price = 2500, rep = 4, daily = 5 },
        usb_blue  = { price = 6000, rep = 5, daily = 2 },
    },
    pacificSpecials = {   -- one each week, in two of Pacific's boxes
        { item = 'diamond', amount = { 3, 5 }, label = 'ألماس خام' },
        { item = 'painting', amount = { 1, 1 }, label = 'لوحة لا تُقدّر بثمن' },
        { item = 'bearer_bonds', amount = { 2, 3 }, label = 'سندات لحاملها' },
    },
    bigScore = {
        rep = 10,
        preps = { 'guard_keycard', 'blueprints', 'catering_uniform' },
        utcOffset = 3,    -- the Gulf (Moe: "Fri-Sat 20:00-02:00 Gulf"; 3 = Saudi/Kuwait/Qatar time, 4 = UAE)
        windows = { { day = 6, from = 20, to = 2 }, { day = 7, from = 20, to = 2 } },   -- 6 = Friday, 7 = Saturday (night into the next day)
    },
    -- the story: one text when you reach each level
    story = {
        [4] = 'سمعت عنك. لا تبحث عني، أنا أجدك. حين تريد شيئًا أكبر من البيوت والمحلات، اكتب. ولا تكتب أسماء أبدًا.',
        [5] = 'البنوك الصغيرة كانت بداية جيدة. الشاحنات المصفّحة تمر كل يوم. المصرّف يعرف متى.',
        [6] = 'الكارتيل لا يحب من يدخل مزرعته. لكن المال هناك لا ينام. احضر طاقمًا، لا أصدقاء.',
        [7] = 'باليتو. بنك صغير في بلدة نائمة، وخزنة أكبر مما تظن. لا يُسرق بلا شرطة في الخدمة: هم جزء من اللعبة.',
        [8] = 'باسيفيك ستاندرد. كثيرون حاولوا. اسألني كل أسبوع ماذا في الخزنة.',
        [9] = 'هناك يخت قبالة الساحل لا يرسو أبدًا. صاحبه يحب الحفلات. التموين هو الطريق.',
        [10] = 'الآن تعرف كيف تعمل المدينة. الكبيرة كل أسبوع، لطاقم واحد فقط. اكتب "الكبيرة".',
    },
}

---------------------------------------------------------------------------
-- M4: the big banks (the same engine as Fleeca, more steps). Police only (Tier 7+).
-- door: closed / open = headings; or swing = turn this many degrees from where the map has it
---------------------------------------------------------------------------
Config.vaults.paleto = {
    kind = 'paleto', tier = 7, label = 'بنك بلين كاونتي (باليتو)', area = 'باليتو باي', center = vec3(-104.0, 6470.0, 31.6), radius = 22.0,
    cooldownMinutes = 360, crew = { 4, 6 }, cost = 10000, prep = 'blueprints',
    steps = {
        { id = 'alarm', label = '[E] اقطع حلقة الإنذار', at = vec3(-109.9, 6469.2, 31.63), game = 'wirecut', params = {}, alarm = 'fail', quiet = true, optional = true },
        { id = 'gate',  label = '[E] اخترق بوابة الخزنة (فلاشة زرقاء)', at = vec3(-106.11, 6475.36, 31.62), game = 'hack', params = { tier = 2 }, item = 'usb_blue', alarm = 'quiet', opens = 'gate' },
        { id = 'vault', label = '[E] ضع C4 على باب الخزنة', at = vec3(-104.6, 6473.9, 31.62), game = 'c4', params = { leads = 4 }, item = 'c4', alarm = 'start', blast = 20, opens = 'vault' },
    },
    doors = {
        gate = { model = `v_ilev_cbankvaulgate02`, pos = vec3(-106.11, 6475.36, 31.62), swing = -90.0 },
        vault = { model = -1185205679, pos = vec3(-105.61, 6472.03, 31.62), closed = 45.45, open = 130.45 },
    },
    lockers = { vec3(-107.4, 6473.87, 31.62), vec3(-107.66, 6475.61, 31.62), vec3(-103.52, 6475.03, 31.62), vec3(-102.3, 6476.13, 31.66),
                vec3(-102.43, 6477.45, 31.67), vec3(-103.97, 6478.97, 31.62), vec3(-105.39, 6479.19, 31.67), vec3(-106.57, 6478.01, 31.62) },
    lockerGame = 'drill',
    loot = { item = 'marked_bills', money = { 7500, 11200 }, usb = { item = 'usb_red', chance = 0.20 }, extra = { { item = 'vault_goldbar', amount = { 1, 1 }, chance = 0.4 } } },
    quietSeconds = 60,
}
Config.vaults.pacific = {
    kind = 'pacific', tier = 8, label = 'بنك باسيفيك ستاندرد', area = 'وسط فاينوود', center = vec3(255.0, 220.0, 104.0), radius = 35.0,
    cooldownMinutes = 1440, crew = { 4, 8 }, cost = 25000, prep = 'blueprints', prep2 = 'guard_keycard', special = true, lasers = true,
    steps = {
        { id = 'stairs', label = '[E] اخترق باب الدرج (فلاشة حمراء)', at = vec3(261.95, 223.11, 106.28), game = 'hack', params = { tier = 3 }, item = 'usb_red', alarm = 'fail', opens = 'stairs' },
        { id = 'gate1',  label = '[E] أدخل رمز البوابة الأولى', at = vec3(252.55, 221.15, 101.68), game = 'keypad', params = { tries = 6 }, alarm = 'fail', opens = 'gate1' },
        { id = 'vault',  label = '[E] ضع C4 على باب الخزنة الكبير (اثنتان)', at = vec3(253.25, 228.44, 101.68), game = 'c4', params = { leads = 4 }, item = 'c4', count = 2, alarm = 'start', blast = 25, opens = 'vault' },
        { id = 'gate2',  label = '[E] افتح البوابة الداخلية (أسلاك الإنذار)', at = vec3(261.15, 215.21, 101.68), game = 'wirecut', params = {}, alarm = 'fail', opens = 'gate2' },
    },
    doors = {
        stairs = { model = `hei_v_ilev_bk_gate2_pris`, pos = vec3(261.95, 223.11, 106.28), swing = -90.0, radius = 4.0 },
        gate1 = { model = `hei_v_ilev_bk_safegate_pris`, pos = vec3(252.55, 221.15, 101.68), swing = -90.0, radius = 4.0 },
        vault = { model = 961976194, pos = vec3(253.25, 228.44, 101.68), closed = 160.0, open = 70.0, radius = 20.0 },
        gate2 = { model = `hei_v_ilev_bk_safegate_pris`, pos = vec3(261.15, 215.21, 101.68), swing = -90.0, radius = 4.0 },
    },
    lockers = { vec3(258.57, 218.36, 101.68), vec3(260.82, 217.62, 101.68), vec3(259.33, 213.76, 101.68), vec3(257.09, 214.55, 101.68), vec3(263.7, 216.48, 101.68),
                vec3(265.81, 215.81, 101.68), vec3(266.43, 214.37, 101.68), vec3(265.71, 212.49, 101.68), vec3(264.24, 211.92, 101.68), vec3(262.21, 212.67, 101.68) },
    lockerGame = 'drill',
    loot = { item = 'marked_bills', money = { 15000, 25000 }, usb = { item = 'usb_gold', chance = 0.25 }, extra = { { item = 'vault_goldbar', amount = { 1, 2 }, chance = 0.35 } } },
    quietSeconds = 45,
    -- the downstairs hallway: red beams that sweep; touch one = the alarm
    laserArea = { a = vec3(250.0, 223.5, 101.7), b = vec3(258.5, 229.5, 101.7) },
    guards = {
        center = vec3(243.0, 220.0, 106.3), radius = 40.0, models = { 's_m_m_security_01' },
        guards = {
            { pos = vec4(241.3, 225.6, 106.3, 160.0), weapon = 'WEAPON_PISTOL', patrol = { vec3(241.3, 225.6, 106.3), vec3(250.0, 222.0, 106.3) } },
            { pos = vec4(234.5, 215.0, 106.3, 250.0), weapon = 'WEAPON_PISTOL' },
            { pos = vec4(255.8, 207.6, 110.3, 340.0), weapon = 'WEAPON_CARBINERIFLE' },
        },
    },
}
Config.calls.paleto = 'سطو على بنك باليتو'
Config.calls.pacific = 'سطو على بنك باسيفيك ستاندرد'
Config.calls.yacht = 'هجوم على اليخت'
Config.calls.bigscore = 'سطو على شاحنة ذهب مستودع الاتحاد'

---------------------------------------------------------------------------
-- M4: the yacht (Tier 9) — the heist yacht off Banham Canyon (GTA's own, loaded on demand)
---------------------------------------------------------------------------
Config.yacht = {
    tier = 9, label = 'اليخت', cooldownMinutes = 2880, cost = 35000, needs = { usb = 'usb_red', c4 = 2, prep = 'catering_uniform' },
    ipls = { 'hei_yacht_heist', 'hei_yacht_heist_Bar', 'hei_yacht_heist_Bedrm', 'hei_yacht_heist_Bridge', 'hei_yacht_heist_DistantLights', 'hei_yacht_heist_enginrm', 'hei_yacht_heist_LODLights', 'hei_yacht_heist_Lounge' },
    center = vec3(-2043.97, -1031.58, 11.98), radius = 60.0, model = 's_m_y_blackops_01', models = { 's_m_y_blackops_01', 's_m_y_blackops_02' },
    guards = {
        { pos = vec4(-2032.0, -1036.0, 8.97, 70.0), weapon = 'WEAPON_CARBINERIFLE', patrol = { vec3(-2032.0, -1036.0, 8.97), vec3(-2060.0, -1028.0, 8.97) } },
        { pos = vec4(-2090.0, -1015.0, 8.97, 250.0), weapon = 'WEAPON_CARBINERIFLE', patrol = { vec3(-2090.0, -1015.0, 8.97), vec3(-2070.0, -1022.0, 8.97) } },
        { pos = vec4(-2050.0, -1033.0, 11.9, 160.0), weapon = 'WEAPON_SPECIALCARBINE' },
        { pos = vec4(-2070.0, -1025.0, 11.9, 340.0), weapon = 'WEAPON_CARBINERIFLE', patrol = { vec3(-2070.0, -1025.0, 11.9), vec3(-2045.0, -1032.0, 11.9) } },
        { pos = vec4(-2080.0, -1020.0, 14.9, 250.0), weapon = 'WEAPON_MARKSMANRIFLE' },
        { pos = vec4(-2040.0, -1036.0, 14.9, 70.0), weapon = 'WEAPON_CARBINERIFLE' },
    },
    waves = { { delay = 50, from = vec4(-2096.0, -1012.0, 5.9, 250.0), count = 3, weapon = 'WEAPON_CARBINERIFLE' } },
    steps = {
        { id = 'bridge', label = '[E] اخترق قفل غرفة القيادة (فلاشة حمراء)', at = vec3(-2085.6, -1018.1, 12.78), game = 'hack', params = { tier = 3 }, item = 'usb_red' },
        { id = 'safe', label = '[E] ضع C4 على خزنة القبطان (اثنتان)', at = vec3(-2084.0, -1016.6, 12.78), game = 'c4', params = { leads = 4 }, item = 'c4', count = 2, blast = 20 },
    },
    loot = { spots = { vec3(-2084.0, -1016.6, 12.78) }, money = { 120000, 180000 }, bars = { 4, 8 }, usb = { item = 'usb_gold', chance = 0.15 } },
}

---------------------------------------------------------------------------
-- M4: the Big Score (Tier 10): the Union Depository gold truck. Weekly, claimed through the Broker.
---------------------------------------------------------------------------
Config.trucks.bigscore = {
    tier = 10, label = 'شاحنة ذهب مستودع الاتحاد', cooldownMinutes = 60, cost = 0, needs = { usb = 'usb_gold' }, c4 = 3,
    model = 'stockade', guardModel = 's_m_m_chemsec_01',
    crew = { { seat = -1, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 0, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 1, weapon = 'WEAPON_SPECIALCARBINE' }, { seat = 2, weapon = 'WEAPON_PUMPSHOTGUN' } },
    escorts = { { model = 'mesa3', crew = { { seat = -1, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 0, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 1, weapon = 'WEAPON_CARBINERIFLE' } } },
                { model = 'mesa3', crew = { { seat = -1, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 0, weapon = 'WEAPON_SPECIALCARBINE' }, { seat = 1, weapon = 'WEAPON_CARBINERIFLE' } } },
                { model = 'mesa3', crew = { { seat = -1, weapon = 'WEAPON_CARBINERIFLE' }, { seat = 0, weapon = 'WEAPON_CARBINERIFLE' } } } },
    speed = 13.0, bags = 6, bagSeconds = 9, money = { 0, 0 }, item = 'vault_goldbar', perBag = { 4, 5 }, usb = nil,
    gpsSeconds = 300, fuseSeconds = 30,
    route = { vec4(2.55, -671.9, 32.34, 181.81), vec3(10.0, -860.0, 30.0), vec3(110.0, -1020.0, 29.0), vec3(220.0, -1060.0, 29.0), vec3(400.0, -1060.0, 29.0), vec3(500.0, -1240.0, 29.0), vec3(780.0, -1300.0, 26.0), vec3(1050.0, -1400.0, 33.0) },
}
-- the fence's limit for gold bars (5 a day for the whole city) already lives in Config.fence.goods
