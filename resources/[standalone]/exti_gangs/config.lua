-- =====================================================================
-- EX_Tii gangs — every number of the gang system lives here (Moe's plan, scaled to our ~$2,900/h jobs).
-- Change one number at a time and watch the logs a few days before changing the next.
-- =====================================================================
local C = {}

-- ranks (Qbox gang grades): 0 Runner, 1 Crew, 2 Underboss, 3 Leader (boss)
C.ranks = {
    [0] = { name = 'عدّاء', en = 'Runner' },
    [1] = { name = 'طاقم', en = 'Crew' },
    [2] = { name = 'نائب', en = 'Underboss' },
    [3] = { name = 'الزعيم', en = 'Leader' },
}
C.maxMembers = 15
C.rankSlots = { [1] = 6, [2] = 3, [3] = 1 } -- Crew 6, Underboss 3, 1 Leader, the rest are Runners
C.leaveWaitHours = 48                       -- after leaving / being kicked, before joining another gang
C.leaderInactiveDays = 14                   -- then the longest-serving Underboss takes over

-- the 5 gang types (one gang per type at launch)
C.types = {
    chop    = { label = 'ورشة التفكيك', en = 'Chop Shop', part = 'chop_tools', icon = 'wrench', ready = true },
    wash    = { label = 'غسيل الأموال', en = 'Money Wash', part = 'wash_supplies', icon = 'wash', ready = true },
    ammo    = { label = 'الذخيرة', en = 'Ammo', part = 'ammo_materials', icon = 'ammo', ready = true },
    weapons = { label = 'الأسلحة', en = 'Weapons', part = 'gun_parts', icon = 'gun', ready = true },
    weed    = { label = 'الحشيش', en = 'Weed', part = 'gang_weed_seeds', icon = 'leaf', ready = true },
}
C.onePerType = true

-- the gang bank pays members for every part they hand in (the leader picks the pay)
C.partPay = { default = 100, min = 80, max = 130 }
C.rentWeekly = 20000                        -- taken from the gang bank every 7 days; unpaid = HQ locked
C.rentEveryDays = 7

-- the shared collection point (one place for every gang; the server gives each gang its own part)
C.collect = {
    seconds = 25,             -- the progress bar
    checks = 2,               -- skill checks during it (a fail = nothing + a short wait)
    give = 3,                 -- parts per run
    personalCooldown = 360,   -- 6 min between runs (per character)
    crateCooldown = 120,      -- 2 min per crate
    failWait = 60,
    memberDaily = 45,         -- parts a member can hand in per day
    gangDaily = 80,           -- parts a gang can take in per day (rep raises it)
    crateModel = 'prop_box_wood05a',
}
C.fence = { price = 40, model = 's_m_y_dealer_01', name = 'المصرّف' } -- buys stolen parts of any gang (dirty money)

-- what a Crew member may take out of the stash per day (value of the items). Runners take nothing out.
C.crewDailyTake = 10000
C.itemValue = { black_money = 1, lockpick = 150, c4 = 2500, chop_tools = 100, wash_supplies = 100, ammo_materials = 100, gun_parts = 100,
                gang_weed_seeds = 100, weed_bud = 30, ['weed_og-kush'] = 45, ['ammo-9'] = 4, ['ammo-45'] = 4, ['ammo-shotgun'] = 4, ['ammo-rifle'] = 4,
                WEAPON_SNSPISTOL = 1200, WEAPON_PISTOL = 1200, WEAPON_VINTAGEPISTOL = 1200, WEAPON_SAWNOFFSHOTGUN = 2800, WEAPON_MICROSMG = 2800,
                WEAPON_HEAVYPISTOL = 1200, WEAPON_MINISMG = 2800, WEAPON_COMPACTRIFLE = 5500 }

-- gang reputation: earned by doing the gang's work. Each level unlocks a bit more.
C.rep = {
    gain = { part = 1, chop = 12, playerChop = 20, bench = 1, wash = 8, ammo = 6, gun = 10, harvest = 6, bag = 1, corner = 1 },
    levels = {
        { xp = 0,     name = 'شارع',     partsDaily = 80,  chopsDaily = 10, washDaily = 40000, stashSlots = 60,  stashWeight = 400000, rentOff = 0.00 },
        { xp = 600,   name = 'حيّ',      partsDaily = 90,  chopsDaily = 11, washDaily = 50000, stashSlots = 70,  stashWeight = 500000, rentOff = 0.05 },
        { xp = 2000,  name = 'منطقة',    partsDaily = 100, chopsDaily = 12, washDaily = 60000, stashSlots = 80,  stashWeight = 600000, rentOff = 0.10 },
        { xp = 5000,  name = 'مدينة',    partsDaily = 110, chopsDaily = 13, washDaily = 70000, stashSlots = 90,  stashWeight = 700000, rentOff = 0.15 },
        { xp = 10000, name = 'أسطورة',   partsDaily = 120, chopsDaily = 14, washDaily = 80000, stashSlots = 100, stashWeight = 800000, rentOff = 0.20 },
    },
}

-- gang identity: the colours a leader can pick (the laptop and the member list use it)
C.colors = { '#e8b547', '#e5484d', '#3e9bff', '#2fbf71', '#a970ff', '#ff7a1a', '#14c4c4', '#f1f1f1' }

-- ------------------------------------------------------------------ Chop Shop
C.chop = {
    cooldown = 480,           -- 8 min between chops per gang
    c4Daily = 2,
    wantedCount = 3,          -- random models each day pay more
    wantedBonus = 0.30,
    split = { thief = { def = 15, min = 10, max = 25 }, chopper = { def = 10, min = 5, max = 15 } },
    ownerCooldownHours = 72,  -- a player's cars can be chopped once every 72 h
    benchSeconds = 12,        -- lockpick bench: 1 Chop Tools -> 2 lockpicks
    benchGive = 2,
    garageRadius = 7.0,
    -- by GTA vehicle class. seconds = the shortest a whole chop can take (4 stages)
    tiers = {
        super  = { label = 'خارقة',   tools = 6, seconds = 300, money = { 4000, 5200 }, lockpicks = { 2, 3 }, c4 = 0.30 },
        sports = { label = 'رياضية',  tools = 4, seconds = 240, money = { 2250, 2900 }, lockpicks = { 2, 2 }, c4 = 0.10 },
        mid    = { label = 'متوسطة',  tools = 3, seconds = 180, money = { 1300, 1750 }, lockpicks = { 1, 2 }, c4 = 0.00 },
        low    = { label = 'عادية',   tools = 2, seconds = 120, money = { 700, 1050 },  lockpicks = { 1, 1 }, c4 = 0.00 },
    },
    -- class -> tier (missing classes are blocked: cycles, boats, helis, planes, service, emergency,
    -- military, industrial, utility, commercial, trains, open wheel)
    classes = { [7] = 'super', [6] = 'sports', [5] = 'sports', [2] = 'mid', [3] = 'mid', [4] = 'mid',
                [0] = 'low', [1] = 'low', [8] = 'low', [9] = 'low', [12] = 'low' },
    -- vehicles of these scripts are never chopped (police, EMS, mechanic fleets, job vehicles)
    blockedStates = { 'exti_job', 'exti_police', 'exti_ems', 'exti_mechanic', 'exti_broken' },
    -- models that can be on the daily wanted list
    wantedPool = { 'adder', 'zentorno', 't20', 'turismor', 'entityxf', 'comet2', 'carbonizzare', 'jester', 'elegy2', 'sultanrs',
                   'massacro', 'feltzer2', 'banshee', 'ninef', 'dominator', 'gauntlet', 'baller', 'granger', 'schafter2',
                   'oracle', 'tailgater', 'buffalo', 'felon', 'sentinel', 'fugitive', 'kuruma', 'issi2', 'blista' },
}

-- ------------------------------------------------------------------ Money Wash
-- Anyone drops dirty money in the gang's drop box (outside the HQ) and gets a ticket. Crew and up wash
-- it at the machine inside (3 steps: sort the bills, run the machine, count and band the stacks).
-- The customer's clean cash waits in the box under his name. The gang keeps its cut:
-- 20% of the cut to the member who washed it (cash), the rest to the gang bank.
C.wash = {
    cut = { def = 25, min = 15, max = 35 },   -- the leader sets it (%), fixed on each order when dropped
    washerShare = 20,                         -- % of the gang's cut to the member who ran the batch
    batchMax = 5000,                          -- dirty money per batch
    supplyPer = 1000,                         -- 1 wash supplies per $1,000 (rounded up)
    dropMin = 500, dropMax = 25000,           -- per order
    openOrders = 3,                           -- orders a customer can have open at one gang
    queueMax = 200000,                        -- dirty money waiting at one gang
    cooldown = 120,                           -- seconds between two batches (one machine)
    stageSeconds = { 15, 20, 15 },            -- the shortest each step can take: sort, machine, count & band
    markedChance = 0.10,                      -- marked bills: an anonymous tip to the police (the area, not the spot)
    tipRadius = 150.0,
    tipDelay = { 60, 240 },                   -- seconds after the batch (so it isn't a live alarm)
}

-- ------------------------------------------------------------------ Ammo
-- The ammo press in the HQ (Crew and up): 3 steps (melt the lead, press the casings, box the rounds).
-- 1 ammo materials = 10 rounds. The rounds go to the gang stash.
C.ammo = {
    perMaterial = 10,
    batchMax = 10,                         -- materials per batch (100 rounds)
    cooldown = 120,
    stageSeconds = { 12, 15, 12 },
    dailyRounds = { 600, 700, 800, 900, 1000 },   -- by rep level
    types = {
        { item = 'ammo-9',       label = 'ذخيرة 9 ملم',  rep = 1 },
        { item = 'ammo-shotgun', label = 'خرطوش',        rep = 1 },
        { item = 'ammo-45',      label = 'ذخيرة .45',    rep = 2 },
        { item = 'ammo-rifle',   label = 'ذخيرة بندقية', rep = 3 },
    },
}

-- ------------------------------------------------------------------ Weapons
-- The workbench in the HQ (Crew and up): 3 steps (file the frame, assemble, test fire). Serial scratched off.
C.weapons = {
    cooldown = 180,
    daily = 6,                             -- guns per gang per day
    stageSeconds = { 15, 15, 12 },
    serial = 'SCRATCHED',
    testFireTip = 0.10,                    -- the test fire is heard: an anonymous tip to the police
    guns = {
        { item = 'WEAPON_SNSPISTOL',      label = 'مسدس SNS',        rep = 1, parts = 8 },
        { item = 'WEAPON_PISTOL',         label = 'مسدس',            rep = 1, parts = 8 },
        { item = 'WEAPON_VINTAGEPISTOL',  label = 'مسدس قديم',       rep = 2, parts = 8 },
        { item = 'WEAPON_SAWNOFFSHOTGUN', label = 'بندقية مقصوصة',   rep = 2, parts = 15 },
        { item = 'WEAPON_MICROSMG',       label = 'رشاش صغير',       rep = 3, parts = 15 },
        { item = 'WEAPON_HEAVYPISTOL',    label = 'مسدس ثقيل',       rep = 3, parts = 8 },
        { item = 'WEAPON_MINISMG',        label = 'رشاش ميني',       rep = 4, parts = 15 },
        { item = 'WEAPON_COMPACTRIFLE',   label = 'بندقية مدمجة',    rep = 5, parts = 25 },
    },
}

-- ------------------------------------------------------------------ the black market buyer (placed with /gangspots)
-- Buys only what the Ammo and Weapons gangs made (gang ammo and serial-less gang guns), for dirty money.
C.blackMarket = {
    model = 'g_m_m_armboss_01',
    dailyPerPlayer = 15000,                -- what one player can sell him per day
    prices = { ['ammo-9'] = 4, ['ammo-45'] = 4, ['ammo-shotgun'] = 4, ['ammo-rifle'] = 4,
               WEAPON_SNSPISTOL = 1200, WEAPON_PISTOL = 1200, WEAPON_VINTAGEPISTOL = 1200, WEAPON_HEAVYPISTOL = 1200,
               WEAPON_SAWNOFFSHOTGUN = 2800, WEAPON_MICROSMG = 2800, WEAPON_MINISMG = 2800, WEAPON_COMPACTRIFLE = 5500 },
}

-- ------------------------------------------------------------------ Weed
-- Up to 12 pots in the HQ grow room (placed with /gangspots). A seed grows in 30 minutes. Water keeps it
-- healthy (dry time costs buds), fertilizer (weed_nutrition) gives more. Harvest -> the table: trim + weigh 2 g bags.
-- Then sell bags on street corners to locals (anyone can, the police may get a call).
C.weed = {
    pots = 12,
    growSeconds = 1800,
    waterLasts = 600,                      -- a watered plant is fine for 10 min, then it dries out
    budsBase = 8, fertBonus = 0.25, dryMaxLoss = 0.6,
    harvestTip = 0.10,                     -- the smell of a harvest: an anonymous tip to the police
    bagItem = 'weed_og-kush',              -- a 2 g bag (the existing item)
    budsPerBag = 1,
    tableBatch = 10,                       -- bags per table round
    tableSeconds = { 10, 10 },
    corner = {
        price = { 40, 50 },                -- dirty money per bag
        perSale = { 1, 3 },
        every = { 20, 40 },                -- seconds between two buyers
        radius = 25.0,                     -- stay near your corner
        dailyBags = 80,                    -- per player
        policeChance = { own = 0.05, none = 0.12, rival = 0.25 },   -- per sale, by whose turf it is
    },
}

-- ------------------------------------------------------------------ Turf & graffiti
-- Zones are drawn by an admin in game (/turfzone). A gang member sprays the gang's tag on a wall in a
-- zone (spray can from the tools shop). The gang with the most tags owns the zone.
C.turf = {
    maxPerZone = 5,
    minGap = 3.0,            -- metres between two tags
    spraySeconds = 20,
    scrubSeconds = 15,
    cooldown = 600,          -- per player between two tags
    brushUses = 3,
    repPerZoneHour = 10,
    maxPoints = 20,          -- corners per zone
    tagSize = { 2.2, 1.1 },  -- metres on the wall
    drawDistance = 45.0,
}

-- ------------------------------------------------------------------ car theft -> police
-- Every lockpick / hotwire / key search / carjack (the car keys script) and every car really stolen.
-- Player cars, police cars and fast cars always alert. Normal cars: a chance (lower at night).
-- A witness (an NPC close by, looking at you) always calls it in.
C.theft = {
    dayChance = 0.60, nightChance = 0.35,
    nightFrom = 22, nightTo = 6,          -- game clock hours
    alwaysTiers = { super = true, sports = true },
    repeatWindow = 300,                   -- one alert per car per 5 min (a missed roll also holds for 5 min)
    witnessRadius = 25.0,
    -- GPS tracker on fast cars: the police see the car live for this long, unless the thief pulls it out
    trackerTiers = { super = true, sports = true },
    trackerSeconds = 120, trackerEvery = 4,
    pullSeconds = 7,
    ownerBlipSeconds = 30,                -- the owner sees where his car was when the alarm went off
}

-- ------------------------------------------------------------------ HQ front door
-- The HQ houses have no working front door: [E] at the door outside -> inside, [E] inside -> out.
-- Members walk in. Anyone else knocks (a member inside lets him in). Police on duty can breach it.
C.door = {
    reach = 2.0,
    knockCooldown = 20,
    breachSeconds = 10,
    breachOpen = 600,                     -- after a breach the door stays open to the police for 10 min
    insideRange = 80.0,                   -- further than this from the inside door = he isn't inside any more
}

-- Real doors (a house that has its own door: Michael's, Franklin's, a garage door, a back door).
-- Locked for everyone. A gang member opens it with [E]; it locks itself again. Others knock; police breach.
C.realDoor = {
    max = 8,               -- doors per HQ (double doors = 2: aim at each side)
    reach = 2.5,
    autoLock = 10,         -- seconds open, then it locks again by itself
    knockRange = 40.0,     -- members this close to the door hear a knock
}

-- The luxury houses on the map (for /gangspots -> "luxury houses": takes you inside to look)
C.houses = {
    { label = '3655 Wild Oats Drive',            coords = vec3(-169.29, 486.49, 137.44) },
    { label = '2044 North Conker Avenue',        coords = vec3(340.94, 437.18, 149.39) },
    { label = '2045 North Conker Avenue',        coords = vec3(373.02, 416.11, 145.70) },
    { label = '2862 Hillcrest Avenue',           coords = vec3(-676.13, 588.61, 145.17) },
    { label = '2868 Hillcrest Avenue',           coords = vec3(-763.11, 615.91, 144.14) },
    { label = '2874 Hillcrest Avenue',           coords = vec3(-857.80, 682.56, 152.65) },
    { label = '2677 Whispymound Drive',          coords = vec3(120.50, 549.95, 184.10) },
    { label = '2133 Mad Wayne Thunder Drive',    coords = vec3(-1288.00, 440.75, 97.69) },
    { label = 'Michael (Rockford Hills)',        coords = vec3(-802.31, 175.06, 72.84) },
    { label = 'Franklin (Vinewood Hills)',       coords = vec3(7.12, 536.62, 176.03) },
}

C.webhookConvar = 'exti_gangs_webhook' -- set exti_gangs_webhook "https://discord.com/api/webhooks/..." in server.cfg

return C
