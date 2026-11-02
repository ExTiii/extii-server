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
        SetPedSuffersCriticalHits(PlayerPedId(), false)   -- no instant headshots
        Wait(5000)
    end
end)
-- a new ped (respawn, a new model) gets it at once
lib.onCache('ped', function(ped) SetPedSuffersCriticalHits(ped, false) end)

-- (the headshot +50% is done in exti_medical, which reads every hit first)

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

-- the light vest (Ammu-Nation): 50% armour (the heavy vest, item 'armour', is ox_inventory's own: 100%)
exports('useLightArmour', function(data, slot)
    local ped = PlayerPedId()
    if GetPedArmour(ped) >= 50 then
        return lib.notify({ description = 'درعك أقوى من هذه السترة', type = 'error', position = 'top' })
    end
    exports.ox_inventory:useItem(data, function(used)
        if used then
            SetPlayerMaxArmour(PlayerId(), 100)
            SetPedArmour(PlayerPedId(), 50)
        end
    end)
end)
