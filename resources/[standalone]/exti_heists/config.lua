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
    lockpick = { minSeconds = 3.0 },
    safedial = { minSeconds = 5.0 },
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
