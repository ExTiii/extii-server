-- =====================================================================
-- EX_Tii weapons: every number of the gun rework (damage + shots-fired calls).
-- A player has 100 health to lose before he is down (plus armour).
-- =====================================================================
Config = {}

-- Damage: one table for everyone (each game applies it to the shots it fires, so every player is equal).
-- The number multiplies GTA's own damage. Target: pistols 4-5 body shots, SMGs fast but weak,
-- shotguns deadly only up close, rifles 3-4 shots, melee never one punch.
Config.damage = {
    -- pistols                                   (GTA damage -> per shot here)
    WEAPON_SNSPISTOL = 0.80,     -- 28 -> 22
    WEAPON_PISTOL = 0.85,        -- 26 -> 22
    WEAPON_VINTAGEPISTOL = 0.65, -- 34 -> 22
    WEAPON_COMBATPISTOL = 0.80,  -- 27 -> 22
    WEAPON_HEAVYPISTOL = 0.60,   -- 40 -> 24
    WEAPON_APPISTOL = 0.75,      -- 28 -> 21 (fast)
    WEAPON_REVOLVER = 0.35,      -- 110 -> 38 (3 shots, slow)
    -- SMGs
    WEAPON_MACHINEPISTOL = 0.60, -- 20 -> 12
    WEAPON_MICROSMG = 0.60,      -- 21 -> 13
    WEAPON_MINISMG = 0.60,       -- 22 -> 13
    WEAPON_SMG = 0.65,           -- 22 -> 14
    -- shotguns (GTA's falloff keeps them weak at range)
    WEAPON_SAWNOFFSHOTGUN = 0.55,
    WEAPON_PUMPSHOTGUN = 0.55,
    WEAPON_DBSHOTGUN = 0.55,
    -- rifles
    WEAPON_COMPACTRIFLE = 0.80,  -- 34 -> 27
    WEAPON_CARBINERIFLE = 0.85,  -- 32 -> 27
    WEAPON_SPECIALCARBINE = 0.85,
    WEAPON_ASSAULTRIFLE = 0.90,  -- 30 -> 27
    -- long guns
    WEAPON_MUSKET = 0.45,        -- 165 -> 74
    WEAPON_SNIPERRIFLE = 0.75,   -- 101 -> 76
    -- melee
    WEAPON_UNARMED = 0.30,
    WEAPON_KNIFE = 0.55, WEAPON_SWITCHBLADE = 0.55, WEAPON_MACHETE = 0.60, WEAPON_HATCHET = 0.60,
    WEAPON_BAT = 0.60, WEAPON_GOLFCLUB = 0.60, WEAPON_CROWBAR = 0.60, WEAPON_HAMMER = 0.60, WEAPON_WRENCH = 0.60,
    WEAPON_KNUCKLE = 0.45, WEAPON_NIGHTSTICK = 0.50, WEAPON_FLASHLIGHT = 0.40,
}
Config.headshot = 1.5            -- a headshot does this much of a body shot (no instant one-tap)

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
                  'VINE', 'WVINE', 'ZP_ORT', 'PALHIGH', 'TATAMO', 'RGLEN', 'OBSERV', 'GREATC' },
    townZones = { 'SANDY', 'GRAPES', 'PALETO', 'HARMO', 'CHU', 'BANHAMC', 'BHAMCA', 'ALAMO', 'RTRAK', 'PALFOR' },
}
