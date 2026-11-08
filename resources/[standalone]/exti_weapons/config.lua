-- =====================================================================
-- EX_Tii weapons: every number of the gun rework (damage + shots-fired calls).
-- A player has 100 health to lose before he is down (plus armour).
-- =====================================================================
Config = {}

-- Damage: one table for everyone (each game applies it to the shots it fires, so every player is equal).
-- The number multiplies GTA's own damage. Target: pistols 4-5 body shots, SMGs fast but weak,
-- shotguns deadly only up close, rifles 3-4 shots, melee never one punch.
Config.damage = {
    -- EX_Tii gun rework (Moe, Nov 2026). A player loses 100 health from full to down. Body shots to down:
    -- pistols 4 (heavy pistol / revolver 3), SMGs 6, rifles 3, sniper 1, shotgun 1 up close (GTA's own falloff
    -- makes it 2-3 at 10 m and useless past 20 m). A headshot without a helmet is one tap (exti_medical).
    -- pistols                                   (GTA damage -> per shot here)
    WEAPON_SNSPISTOL = 0.90,     -- 28 -> 25
    WEAPON_PISTOL = 0.96,        -- 26 -> 25
    WEAPON_VINTAGEPISTOL = 0.74, -- 34 -> 25
    WEAPON_COMBATPISTOL = 0.93,  -- 27 -> 25
    WEAPON_PISTOL_MK2 = 0.83,    -- 30 -> 25
    WEAPON_HEAVYPISTOL = 0.85,   -- 40 -> 34 (3 shots)
    WEAPON_APPISTOL = 0.72,      -- 28 -> 20 (fast: 5 shots)
    WEAPON_REVOLVER = 0.31,      -- 110 -> 34 (3 shots, slow)
    WEAPON_DOUBLEACTION = 0.65,  -- 52 -> 34
    -- SMGs (6 shots)
    WEAPON_MACHINEPISTOL = 0.85, -- 20 -> 17
    WEAPON_MICROSMG = 0.80,      -- 21 -> 17
    WEAPON_MINISMG = 0.77,       -- 22 -> 17
    WEAPON_SMG = 0.77,           -- 22 -> 17
    WEAPON_ASSAULTSMG = 0.74,    -- 23 -> 17
    WEAPON_COMBATPDW = 0.61,     -- 28 -> 17
    -- shotguns (one shot up close; GTA's falloff keeps them weak at range)
    WEAPON_SAWNOFFSHOTGUN = 1.0,
    WEAPON_PUMPSHOTGUN = 1.0,
    WEAPON_DBSHOTGUN = 1.0,
    WEAPON_ASSAULTSHOTGUN = 0.7,
    -- rifles (3 shots)
    WEAPON_COMPACTRIFLE = 1.0,   -- 34 -> 34
    WEAPON_CARBINERIFLE = 1.05,  -- 32 -> 34
    WEAPON_SPECIALCARBINE = 1.0, -- 34 -> 34
    WEAPON_ASSAULTRIFLE = 1.13,  -- 30 -> 34
    WEAPON_BULLPUPRIFLE = 1.06,  -- 32 -> 34
    WEAPON_ADVANCEDRIFLE = 1.13, -- 30 -> 34
    -- long guns (one hit)
    WEAPON_MUSKET = 0.65,        -- 165 -> 107
    WEAPON_SNIPERRIFLE = 1.0,    -- 101 -> 101
    WEAPON_HEAVYSNIPER = 1.0,
    WEAPON_MARKSMANRIFLE = 1.6,  -- 65 -> 104
    -- melee: never one hit (fists 12+, bats 7-8, knives 5-6); armour does not stop these (exti_medical)
    WEAPON_UNARMED = 0.30,
    WEAPON_KNIFE = 0.55, WEAPON_SWITCHBLADE = 0.55, WEAPON_DAGGER = 0.55, WEAPON_BOTTLE = 0.50,
    WEAPON_MACHETE = 0.60, WEAPON_HATCHET = 0.60, WEAPON_BATTLEAXE = 0.60, WEAPON_STONE_HATCHET = 0.60,
    WEAPON_BAT = 0.60, WEAPON_GOLFCLUB = 0.60, WEAPON_CROWBAR = 0.60, WEAPON_HAMMER = 0.60, WEAPON_WRENCH = 0.60, WEAPON_POOLCUE = 0.60,
    WEAPON_KNUCKLE = 0.45, WEAPON_NIGHTSTICK = 0.50, WEAPON_FLASHLIGHT = 0.40,
}
-- (headshots: one tap without a helmet, +50% with one: exti_medical/config.lua)

-- Shots fired: gunfire calls the police. Chance by area, one call per area per minute, a suppressor halves it.
Config.shots = {
    city = 1.0, town = 0.5, wild = 0.15,
    suppressor = 0.5,
    areaSeconds = 60,            -- one call per ~150 m area per minute
    areaSize = 150.0,
    -- GTA zone codes (GetNameOfZone): Los Santos = city, the small towns = town, everything else = wild
    cityZones = { 'AIRP', 'ALTA', 'BANNING', 'BEACH', 'BURTON', 'CHAMH', 'CHIL', 'CYPRE', 'DAVIS', 'DELBE', 'DELPE', 'DELSOL', 'DOWNT',
                  'DTVINE', 'EAST_V', 'EBURO', 'ELYSIAN', 'GOLF', 'HAWICK', 'HORS', 'KOREAT', 'LEGSQU', 'LMESA', 'LOSPUER', 'MIRR', 'MORN',
                  'MOVIE', 'MURRI', 'NOOSE', 'PBOX', 'RANCHO', 'RICHM', 'ROCKF', 'SKID', 'STAD', 'STRAW', 'TERMINA', 'TEXTI', 'VCANA', 'VESP',
                  'VINE', 'WVINE', 'ZP_ORT', 'PALHIGH', 'TATAMO', 'RGLEN', 'OBSERV', 'GREATC', 'PBLUFF' },
    townZones = { 'SANDY', 'GRAPES', 'PALETO', 'HARMO', 'CHU', 'SLAB', 'GALFISH', 'ALAMO', 'DESRT', 'SANCHIA' },
    streakStep = 0.25,           -- each burst that wasn't reported (within 45 s) adds 25% (half with a suppressor)
}
