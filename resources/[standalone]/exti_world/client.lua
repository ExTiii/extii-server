-- EX_Tii world rules (our own, replaces the stock "small resources" and "density" packs)
-- * no wanted stars and no GTA police / ambulance / fire / army coming after you
-- * GTA's street gangs, cops and medics leave players alone
-- * no random cop cars, ambulances, fire trucks or military planes driving around
-- * traffic and people in the street at 80% (a bit calmer than GTA Online)
-- * GTA's own money, ammo, area and street-name text is hidden (our HUD shows what matters)
-- * the weapon wheel (TAB) is off: weapons come from the inventory hotbar
-- * no hitting people with the gun you are holding, no picking up GTA weapons from the ground
-- * passengers don't slide into the driver seat by themselves
-- * no GTA traffic or parked-car spawns inside the new Legion Square (the map replaced the old parking lot)

---------------------------------------------------------------------------
-- no wanted stars, no GTA emergency services
---------------------------------------------------------------------------
CreateThread(function()
    SetMaxWantedLevel(0)
    for service = 1, 15 do
        EnableDispatchService(service, service == 8) -- 8 = police road blocks (kept like before)
    end
end)

---------------------------------------------------------------------------
-- GTA's street gangs, cops, medics and firemen leave players alone
---------------------------------------------------------------------------
local FRIENDLY = {
    'AMBIENT_GANG_HILLBILLY', 'AMBIENT_GANG_BALLAS', 'AMBIENT_GANG_MEXICAN', 'AMBIENT_GANG_FAMILY',
    'AMBIENT_GANG_MARABUNTE', 'AMBIENT_GANG_SALVA', 'AMBIENT_GANG_LOST', 'GANG_1', 'GANG_2', 'GANG_9',
    'GANG_10', 'FIREMAN', 'MEDIC', 'COP', 'PRISONER',
}
for i = 1, #FRIENDLY do
    SetRelationshipBetweenGroups(1, joaat(FRIENDLY[i]), `PLAYER`)
end

---------------------------------------------------------------------------
-- no emergency / military vehicles in the city traffic
---------------------------------------------------------------------------
local SCENARIO_TYPES = {
    'WORLD_VEHICLE_AMBULANCE', 'WORLD_VEHICLE_FIRE_TRUCK', 'WORLD_VEHICLE_POLICE_BIKE',
    'WORLD_VEHICLE_POLICE_CAR', 'WORLD_VEHICLE_POLICE', 'WORLD_VEHICLE_POLICE_NEXT_TO_CAR',
    'WORLD_VEHICLE_SECURITY_CAR', 'WORLD_VEHICLE_HELI_LIFEGUARD',
    'WORLD_VEHICLE_MILITARY_PLANES_BIG', 'WORLD_VEHICLE_MILITARY_PLANES_SMALL',
}
local SUPPRESSED = { 'SHAMAL', 'LUXOR', 'LUXOR2', 'JET', 'LAZER', 'TITAN', 'CRUSADER', 'RHINO', 'AIRTUG', 'RIPLEY', 'BLIMP' }
local SCENARIO_GROUPS = { 'LSA_Planes', 'SANDY_PLANES', 'GRAPESEED_PLANES', 'ng_planes' }

CreateThread(function()
    while true do
        for i = 1, #SCENARIO_TYPES do SetScenarioTypeEnabled(SCENARIO_TYPES[i], false) end
        for i = 1, #SUPPRESSED do SetVehicleModelIsSuppressed(joaat(SUPPRESSED[i]), true) end
        for i = 1, #SCENARIO_GROUPS do SetScenarioGroupEnabled(SCENARIO_GROUPS[i], false) end
        Wait(10000)
    end
end)

-- people in the street don't drop their guns when they die
AddEventHandler('populationPedCreating', function(x, y, z)
    Wait(500)
    local _, ped = GetClosestPed(x, y, z, 1.0)
    if ped and ped ~= 0 then SetPedDropsWeaponsWhenDead(ped, false) end
end)

CreateThread(function()
    StartAudioScene('CHARACTER_CHANGE_IN_SKY_SCENE') -- no far-away sirens and car alarms
    SetAudioFlag('PoliceScannerDisabled', true)
    SetGarbageTrucks(false)
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    DistantCopCarSirens(false)
    SetFarDrawVehicles(false)
    -- no parked cars spawning at the hospital, the police stations and the army base
    local areas = {
        { 335.26, -1432.46, 46.51, 300.0 },  -- central LS medical center
        { 441.85, -987.99, 30.68, 500.0 },   -- Mission Row police station
        { 316.79, -592.36, 43.28, 300.0 },   -- Pillbox hospital
        { -2150.44, 3075.99, 32.8, 500.0 },  -- army base
        { -1108.35, 4920.64, 217.2, 300.0 },
        { -458.24, 6019.81, 31.34, 300.0 },  -- Paleto police station
        { 1854.82, 3679.4, 33.82, 300.0 },   -- Sandy Shores police station
        { -724.46, -1444.03, 5.0, 300.0 },   -- helicopters at the heliport
    }
    for i = 1, #areas do
        local a = areas[i]
        RemoveVehiclesFromGeneratorsInArea(a[1] - a[4], a[2] - a[4], a[3] - a[4], a[1] + a[4], a[2] + a[4], a[3] + a[4])
    end
end)

-- no idle cinematic camera when you stand still
DisableIdleCamera(true)
DisableVehiclePassengerIdleCamera(true)

---------------------------------------------------------------------------
-- GTA's own HUD bits and the weapon wheel
---------------------------------------------------------------------------
-- 1 wanted stars, 2 weapon icon, 3 cash, 4 MP cash, 7 area name, 9 street name,
-- 13 cash change, 19 weapon wheel, 20 weapon wheel stats, 21 HUD components, 22 HUD weapons
local HIDDEN = { 1, 2, 3, 4, 7, 9, 13, 19, 20, 21, 22 }

local DENSITY = 0.5 -- EX_Tii (Moe): traffic and people in the street (1.0 = GTA Online); fewer = calmer streets
local PARKED = 0.3 -- NPC cars parked along the streets (fewer: the streets look less crowded; still enough to steal)

CreateThread(function()
    for i = 1, #HIDDEN do SetHudComponentSize(HIDDEN[i], 0.0, 0.0) end
    while true do
        DisableControlAction(2, 37, true) -- TAB weapon wheel
        SetParkedVehicleDensityMultiplierThisFrame(PARKED)
        SetVehicleDensityMultiplierThisFrame(DENSITY)
        SetRandomVehicleDensityMultiplierThisFrame(DENSITY)
        SetPedDensityMultiplierThisFrame(DENSITY)
        SetScenarioPedDensityMultiplierThisFrame(DENSITY, DENSITY)
        Wait(0)
    end
end)

-- holding a weapon: no white dot unless aiming in first person, and no hitting people with it
lib.onCache('weapon', function(weapon)
    if not weapon then return end
    CreateThread(function()
        while cache.weapon ~= weapon do Wait(1) end
        while cache.weapon == weapon do
            if not IsFirstPersonAimCamActive() then HideHudComponentThisFrame(14) end
            if IsPedArmed(cache.ped, 6) then
                DisableControlAction(1, 140, true)
                DisableControlAction(1, 141, true)
                DisableControlAction(1, 142, true)
            end
            Wait(0)
        end
    end)
end)

-- GTA weapons lying around can't be picked up (weapons only come from the inventory)
local PICKUPS = {
    'PICKUP_WEAPON_ADVANCEDRIFLE', 'PICKUP_WEAPON_APPISTOL', 'PICKUP_WEAPON_ASSAULTRIFLE', 'PICKUP_WEAPON_ASSAULTRIFLE_MK2',
    'PICKUP_WEAPON_ASSAULTSHOTGUN', 'PICKUP_WEAPON_ASSAULTSMG', 'PICKUP_WEAPON_AUTOSHOTGUN', 'PICKUP_WEAPON_BAT',
    'PICKUP_WEAPON_BATTLEAXE', 'PICKUP_WEAPON_BOTTLE', 'PICKUP_WEAPON_BULLPUPRIFLE', 'PICKUP_WEAPON_BULLPUPRIFLE_MK2',
    'PICKUP_WEAPON_BULLPUPSHOTGUN', 'PICKUP_WEAPON_CARBINERIFLE', 'PICKUP_WEAPON_CARBINERIFLE_MK2', 'PICKUP_WEAPON_COMBATMG',
    'PICKUP_WEAPON_COMBATMG_MK2', 'PICKUP_WEAPON_COMBATPDW', 'PICKUP_WEAPON_COMBATPISTOL', 'PICKUP_WEAPON_COMPACTLAUNCHER',
    'PICKUP_WEAPON_COMPACTRIFLE', 'PICKUP_WEAPON_CROWBAR', 'PICKUP_WEAPON_DAGGER', 'PICKUP_WEAPON_DBSHOTGUN',
    'PICKUP_WEAPON_DOUBLEACTION', 'PICKUP_WEAPON_FIREWORK', 'PICKUP_WEAPON_FLAREGUN', 'PICKUP_WEAPON_FLASHLIGHT',
    'PICKUP_WEAPON_GRENADE', 'PICKUP_WEAPON_GRENADELAUNCHER', 'PICKUP_WEAPON_GUSENBERG', 'PICKUP_WEAPON_GolfClub',
    'PICKUP_WEAPON_HAMMER', 'PICKUP_WEAPON_HATCHET', 'PICKUP_WEAPON_HEAVYPISTOL', 'PICKUP_WEAPON_HEAVYSHOTGUN',
    'PICKUP_WEAPON_HEAVYSNIPER', 'PICKUP_WEAPON_HEAVYSNIPER_MK2', 'PICKUP_WEAPON_HOMINGLAUNCHER', 'PICKUP_WEAPON_KNIFE',
    'PICKUP_WEAPON_KNUCKLE', 'PICKUP_WEAPON_MACHETE', 'PICKUP_WEAPON_MACHINEPISTOL', 'PICKUP_WEAPON_MARKSMANPISTOL',
    'PICKUP_WEAPON_MARKSMANRIFLE', 'PICKUP_WEAPON_MARKSMANRIFLE_MK2', 'PICKUP_WEAPON_MG', 'PICKUP_WEAPON_MICROSMG',
    'PICKUP_WEAPON_MINIGUN', 'PICKUP_WEAPON_MINISMG', 'PICKUP_WEAPON_MOLOTOV', 'PICKUP_WEAPON_MUSKET',
    'PICKUP_WEAPON_NIGHTSTICK', 'PICKUP_WEAPON_PETROLCAN', 'PICKUP_WEAPON_PIPEBOMB', 'PICKUP_WEAPON_PISTOL',
    'PICKUP_WEAPON_PISTOL50', 'PICKUP_WEAPON_PISTOL_MK2', 'PICKUP_WEAPON_POOLCUE', 'PICKUP_WEAPON_PROXMINE',
    'PICKUP_WEAPON_PUMPSHOTGUN', 'PICKUP_WEAPON_PUMPSHOTGUN_MK2', 'PICKUP_WEAPON_RAILGUN', 'PICKUP_WEAPON_RAYCARBINE',
    'PICKUP_WEAPON_RAYMINIGUN', 'PICKUP_WEAPON_RAYPISTOL', 'PICKUP_WEAPON_REVOLVER', 'PICKUP_WEAPON_REVOLVER_MK2',
    'PICKUP_WEAPON_RPG', 'PICKUP_WEAPON_SAWNOFFSHOTGUN', 'PICKUP_WEAPON_SMG', 'PICKUP_WEAPON_SMG_MK2',
    'PICKUP_WEAPON_SMOKEGRENADE', 'PICKUP_WEAPON_SNIPERRIFLE', 'PICKUP_WEAPON_SNSPISTOL', 'PICKUP_WEAPON_SNSPISTOL_MK2',
    'PICKUP_WEAPON_SPECIALCARBINE', 'PICKUP_WEAPON_SPECIALCARBINE_MK2', 'PICKUP_WEAPON_STICKYBOMB', 'PICKUP_WEAPON_STONE_HATCHET',
    'PICKUP_WEAPON_STUNGUN', 'PICKUP_WEAPON_SWITCHBLADE', 'PICKUP_WEAPON_VINTAGEPISTOL', 'PICKUP_WEAPON_WRENCH',
}
CreateThread(function()
    for i = 1, #PICKUPS do
        ToggleUsePickupsForPlayer(cache.playerId, joaat(PICKUPS[i]), false)
    end
end)

---------------------------------------------------------------------------
-- passengers don't slide into the driver seat by themselves
-- (change seats with the radial menu: Vehicle -> Seats)
---------------------------------------------------------------------------
lib.onCache('ped', function(ped) SetPedConfigFlag(ped, 184, true) end)
CreateThread(function() SetPedConfigFlag(cache.ped, 184, true) end)
lib.onCache('seat', function() SetPedConfigFlag(cache.ped, 184, true) end)

---------------------------------------------------------------------------
-- two security barriers that block a parking garage entrance
---------------------------------------------------------------------------
local REMOVE = {
    { coords = vec3(266.09, -349.35, 44.74), model = `prop_sec_barier_02b` },
    { coords = vec3(285.28, -355.78, 45.13), model = `prop_sec_barier_02a` },
}
CreateThread(function()
    while true do
        for i = 1, #REMOVE do
            local r = REMOVE[i]
            local obj = GetClosestObjectOfType(r.coords.x, r.coords.y, r.coords.z, 2.0, r.model, false, false, false)
            if obj ~= 0 and DoesEntityExist(obj) then
                SetEntityAsMissionEntity(obj, true, true)
                DeleteObject(obj)
            end
        end
        Wait(5000)
    end
end)

---------------------------------------------------------------------------
-- EX_Tii (Moe): the new Legion Square (NTeam map) is a plaza where GTA used to have a parking lot and a
-- service lane, so the game still routes cars through it. No roads and no parked-car spawns in the plaza:
-- an angled box from its four corners (77.7,-1120.5) (191.5,-1119.9) (265.9,-869.6) (186.4,-841.0).
-- Road toggles are forgotten when the area streams out, so they are applied again every few seconds.
---------------------------------------------------------------------------
local PLAZA = {
    a = vec3(134.6, -1120.2, 10.0), b = vec3(226.2, -855.3, 50.0), width = 95.0,   -- centre line south -> north
    box = { vec3(77.0, -1121.0, 10.0), vec3(266.0, -840.0, 50.0) },                -- the plain box round it (car generators)
}
CreateThread(function()
    while true do
        SetRoadsInAngledArea(PLAZA.a.x, PLAZA.a.y, PLAZA.a.z, PLAZA.b.x, PLAZA.b.y, PLAZA.b.z, PLAZA.width, false, false, false)
        local b1, b2 = PLAZA.box[1], PLAZA.box[2]
        SetAllVehicleGeneratorsActiveInArea(b1.x, b1.y, b1.z, b2.x, b2.y, b2.z, false, false)
        Wait(5000)
    end
end)
