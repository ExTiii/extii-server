-- =====================================================================
-- EX_Tii weapons (game side): the damage table, no critical headshots (+50% instead), shots-fired reports.
-- =====================================================================
local function isCop()
    local j = QBX and QBX.PlayerData and QBX.PlayerData.job
    return j ~= nil and j.name == 'police' and j.onduty == true
end

-- the damage table (each game applies it to its own shots; re-applied now and then to be safe)
local function applyDamage()
    for name, mod in pairs(Config.damage) do SetWeaponDamageModifier(joaat(name), mod + 0.0) end
end
CreateThread(function()
    while true do
        applyDamage()
        SetPedSuffersCriticalHits(PlayerPedId(), false)   -- no instant headshots (a new ped after a respawn too)
        Wait(5000)
    end
end)

-- headshots: +50% on top of the body damage
local FIREARM = {}
for name in pairs(Config.damage) do
    if name ~= 'WEAPON_UNARMED' and not name:find('KNIFE') and not name:find('BLADE') and not name:find('MACHETE') and not name:find('HATCHET')
        and not name:find('BAT') and not name:find('CLUB') and not name:find('CROWBAR') and not name:find('HAMMER') and not name:find('WRENCH')
        and not name:find('KNUCKLE') and not name:find('NIGHTSTICK') and not name:find('FLASHLIGHT') then
        FIREARM[joaat(name)] = true
    end
end
local HEAD = 31086
local lastHealth = 200
CreateThread(function()
    while true do
        lastHealth = GetEntityHealth(PlayerPedId())
        Wait(0)
    end
end)
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = PlayerPedId()
    if args[1] ~= ped then return end
    local weapon = args[7]
    if not FIREARM[weapon] then return end
    local ok, bone = GetPedLastDamageBone(ped)
    if not ok or bone ~= HEAD then return end
    local now = GetEntityHealth(ped)
    local lost = lastHealth - now
    if lost <= 0 or now <= 0 then return end
    local extra = math.floor(lost * (Config.headshot - 1.0) + 0.5)
    if extra > 0 then SetEntityHealth(ped, math.max(0, now - extra)) end
    lastHealth = math.max(0, now - extra)
end)

-- shots fired: tell the server where (it decides about the call)
local NOT_A_GUN = {
    [`WEAPON_UNARMED`] = true, [`WEAPON_STUNGUN`] = true, [`WEAPON_PETROLCAN`] = true, [`WEAPON_FIREEXTINGUISHER`] = true,
}
CreateThread(function()
    local lastSent = 0
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 4) then
            if IsPedShooting(ped) and GetGameTimer() - lastSent > 5000 and not isCop() then
                local w = GetSelectedPedWeapon(ped)
                if not NOT_A_GUN[w] then
                    lastSent = GetGameTimer()
                    local c = GetEntityCoords(ped)
                    local s1 = GetStreetNameAtCoord(c.x, c.y, c.z)
                    TriggerServerEvent('exti_weapons:server:shots', { x = c.x, y = c.y, z = c.z }, GetStreetNameFromHashKey(s1),
                        GetNameOfZone(c.x, c.y, c.z), IsPedCurrentWeaponSilenced(ped))
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)
