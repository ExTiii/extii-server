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

-- EX_Tii (Moe): no aim assist. GTA's "assisted aim" snaps the gun to the nearest person, even one lying
-- on the ground, so the aim jumps down like an aimbot. Everyone uses free aim, and the soft lock-on is off.
CreateThread(function()
    while true do
        SetPlayerTargetingMode(3)                 -- free aim
        SetPlayerLockon(PlayerId(), false)        -- no lock-on to people
        SetPlayerLockonRangeOverride(PlayerId(), 0.0)
        Wait(2000)
    end
end)

-- =====================================================================
-- EX_Tii (Moe): the protective helmet. Using it puts it on for good: it leaves the bag, sits on your head and
-- shows next to the shield bar, and it can't be taken off. A headshot breaks it (exti_medical calls
-- BreakHelmet): gone from your head and from the HUD. The server keeps it on your character (relog, restart).
-- The state bag `extiHelmet` (set by the server) is the truth; this side only draws it.
-- =====================================================================
local helmet = { on = false, prev = nil, hidden = false, broken = false }

local function helmetLook()
    local look = Config.helmet.look
    return GetEntityModel(cache.ped) == `mp_f_freemode_01` and look.female or look.male
end

local function restoreHat()
    if helmet.prev and helmet.prev[1] >= 0 then
        SetPedPropIndex(cache.ped, 0, helmet.prev[1], helmet.prev[2], true)
    else
        ClearPedProp(cache.ped, 0)
    end
end

local function showHelmet(on)
    if on and not helmet.on then
        helmet.on, helmet.broken = true, false
        CreateThread(function()
            while helmet.on do
                if not helmet.hidden then
                    SetPedCanLosePropsOnDamage(cache.ped, false, 0)   -- (a hit or a fall can't knock it off)
                    local look = helmetLook()
                    local now = GetPedPropIndex(cache.ped, 0)
                    if now ~= look.drawable then
                        -- your own hat (or a clothes reload) took the head slot: keep it as the hat under, helmet back on
                        helmet.prev = { now, GetPedPropTextureIndex(cache.ped, 0) }
                        SetPedPropIndex(cache.ped, 0, look.drawable, look.texture, true)
                    end
                end
                Wait(1000)
            end
        end)
    elseif not on and helmet.on then
        helmet.on = false
        restoreHat()
        helmet.prev = nil
        SetPedCanLosePropsOnDamage(cache.ped, true, 0)
    end
end

AddStateBagChangeHandler('extiHelmet', ('player:%s'):format(cache.serverId), function(_, _, value)
    showHelmet(value == true)
end)
CreateThread(function() Wait(1000); showHelmet(LocalPlayer.state.extiHelmet == true) end)

exports('useHelmet', function(data, slot)
    if LocalPlayer.state.extiHelmet then
        return lib.notify({ description = 'تلبس خوذة واقية بالفعل', type = 'error' })
    end
    lib.playAnim(cache.ped, 'mp_masks@standard_car@ds@', 'put_on_mask', 8.0, 8.0, 800, 49)
    Wait(800)
    TriggerServerEvent('exti_weapons:server:wearHelmet', slot)
end)

exports('HasHelmet', function() return LocalPlayer.state.extiHelmet == true and not helmet.broken end)

-- a headshot: the helmet takes it and is gone
exports('BreakHelmet', function()
    if LocalPlayer.state.extiHelmet ~= true or helmet.broken then return false end
    helmet.broken = true
    showHelmet(false)
    TriggerServerEvent('exti_weapons:server:helmetBroke')
    lib.notify({ description = 'تحطمت خوذتك! أنقذتك من الرصاصة', type = 'error', duration = 6000 })
    return true
end)

-- the clothing screen: the helmet is set aside while you shop (never priced or saved as a hat), then back on
AddEventHandler('exti_weapons:client:takeOffHelmet', function()
    if not helmet.on then return end
    helmet.hidden = true
    restoreHat()
end)
AddEventHandler('exti_weapons:client:helmetBack', function()
    helmet.hidden = false   -- (the loop puts it back over whatever hat you chose)
end)

-- admins: try a head prop on yourself to pick the helmet's look (/extihelmetlook 39 0)
RegisterNetEvent('exti_weapons:client:helmetLook', function(drawable, texture)
    if GetInvokingResource() then return end
    drawable, texture = tonumber(drawable) or 0, tonumber(texture) or 0
    SetPedPropIndex(cache.ped, 0, drawable, texture, true)
    lib.notify({ description = ('الرأس: %d / %d (من أصل %d)'):format(drawable, texture, GetNumberOfPedPropDrawableVariations(cache.ped, 0)), type = 'inform', duration = 6000 })
end)
