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

-- admins (testing): /dmgtest = every hit you land shows the health it took (people and players)
local dmgtest, lastHp = false, {}
RegisterNetEvent('exti_weapons:client:dmgtest', function()
    if GetInvokingResource() then return end
    dmgtest = not dmgtest; lastHp = {}
    lib.notify({ type = 'inform', description = dmgtest and 'اختبار الضرر: يعمل (كل إصابة تظهر كم أخذت من الصحة)' or 'اختبار الضرر: متوقف' })
end)
AddEventHandler('gameEventTriggered', function(name, args)
    if not dmgtest or name ~= 'CEventNetworkEntityDamage' then return end
    local victim, attacker, weapon = args[1], args[2], args[7]
    if attacker ~= cache.ped or not victim or victim == cache.ped or not DoesEntityExist(victim) or not IsEntityAPed(victim) then return end
    local before = lastHp[victim] or GetEntityMaxHealth(victim)
    SetTimeout(0, function()
        if not DoesEntityExist(victim) then return end
        local now = math.max(0, GetEntityHealth(victim))
        local armour = GetPedArmour(victim)
        lastHp[victim] = now
        local ok, bone = GetPedLastDamageBone(victim)
        local where = (ok and bone == 31086) and 'رأس' or 'جسم'
        local who = IsPedAPlayer(victim) and 'لاعب' or 'شخص'
        lib.notify({ type = 'inform', duration = 6000, description = ('%s · %s · -%d صحة · الباقي %d%s'):format(who, where, before - now, now, armour > 0 and (' · درع %d'):format(armour) or '') })
    end)
end)

-- EX_Tii (Moe): no shooting while a screen is open (a tablet, the phone, a menu): clicking on the
-- screen with a gun in your hand fired it before
local function phoneOpen()
    if GetResourceState('npwd') ~= 'started' then return false end
    local ok, open = pcall(function() return exports.npwd:isPhoneVisible() end)
    return ok and open == true
end
CreateThread(function()
    local phone, nextPhone = false, 0
    while true do
        local now = GetGameTimer()
        if now >= nextPhone then phone, nextPhone = phoneOpen(), now + 300 end
        if IsNuiFocused() or phone or IsPauseMenuActive() then
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)    -- attack
            DisableControlAction(0, 25, true)    -- aim
            DisableControlAction(0, 140, true)   -- melee
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)   -- attack 2
            DisableControlAction(0, 263, true)   -- melee 1
            Wait(0)
        else
            Wait(150)
        end
    end
end)
