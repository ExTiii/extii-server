-- =====================================================================
-- EX_Tii medical (client): notes every hit you take (where, what hit you) and tells the
-- server. Nothing changes for you: no limping, no bleeding, no messages. Medics find it.
-- =====================================================================

local lastHp, lastArmor
local goingDown = false   -- EX_Tii: a one-tap headshot is on its way (see below)
local helmetGrace = 0     -- EX_Tii: the helmet just broke: the rest of that same blast (shotgun pellets) is a normal hit
local pending = {}
local flushing = false

-- the game can give the same weapon as a signed or an unsigned number
local function weaponEntry(h)
    if type(h) ~= 'number' then return nil end
    local w = Config.weapons[h]
    if w then return w end
    if h > 0x7FFFFFFF then return Config.weapons[h - 0x100000000] end
    if h < 0 then return Config.weapons[h + 0x100000000] end
end

local function classify(weapon)
    local w = weaponEntry(weapon)
    if w then return w[1], w[2], w[3] end
    local d = Config.damageTypes[GetWeaponDamageType(weapon)]
    if d then return d[1], d[2], d[3] end
    return 'blunt', 1, 'ضربة'
end

-- many hits can land at the same moment (a shotgun): send them together
local function flush()
    if flushing then return end
    flushing = true
    SetTimeout(150, function()
        flushing = false
        if #pending == 0 then return end
        local list = pending
        pending = {}
        TriggerServerEvent('exti_medical:server:hits', list)
    end)
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = cache.ped
    if args[1] ~= ped then return end
    local hp, armor = GetEntityHealth(ped), GetPedArmour(ped)
    local damage = math.max(0, (lastHp or hp) - hp)
    local armorLost = math.max(0, (lastArmor or armor) - armor)
    lastHp, lastArmor = hp, armor

    local kind, power, label = classify(args[7])
    if kind == 'none' then return end
    if cache.vehicle and (kind == 'blunt' or kind == 'vehicle') then kind, label = 'crash', 'حادث سيارة' end
    local tiny = damage < 2 and armorLost < 2
    if tiny and kind ~= 'bullet' and kind ~= 'pellet' and kind ~= 'taser' and kind ~= 'air' then return end

    local hit, bone = GetPedLastDamageBone(ped)
    ClearPedLastDamageBone(ped) -- so the next hit can't reuse this spot

    -- EX_Tii gun rework (Moe): a vest stops bullets, not knives and bats. What the armour took from a melee
    -- hit is given back to the armour and taken from the health instead (never below the down line, 100)
    if (kind == 'blade' or kind == 'blunt') and armorLost > 0 then
        local move = math.min(armorLost, math.max(0, hp - 100))
        if move > 0 then
            SetPedArmour(ped, armor + armorLost)
            SetEntityHealth(ped, hp - move)
            hp, armor = hp - move, armor + armorLost
            damage, armorLost = damage + move, 0
            lastHp, lastArmor = hp, armor
        end
    end

    -- EX_Tii gun rework (Moe, Nov 2026): a bullet in the head is one tap: he goes down at once (health 100 =
    -- the down / last stand, not a permanent death: EMS can still bring him back). Only the protective helmet
    -- (exti_weapons) saves him: it takes that shot and breaks. Armour never covers the head.
    if hit and bone == 31086 and (kind == 'bullet' or kind == 'pellet') and damage > 0 and hp > 100 then
        local okD, down = pcall(function() return exports.qbx_medical:IsLaststand() or exports.qbx_medical:IsDead() end)
        local alreadyDown = okD and down == true   -- (a man in the last stand is finished by normal damage, not one tap)
        -- EX_Tii (Moe): only our protective helmet (Ammu-Nation) saves the head; it takes the shot and breaks.
        -- Clothing-shop and bike helmets don't protect.
        local okH, hasHelmet = pcall(function() return exports.exti_weapons:HasHelmet() end)
        hasHelmet = okH and hasHelmet == true
        if hasHelmet and not alreadyDown then
            pcall(function() exports.exti_weapons:BreakHelmet() end)
            helmetGrace = GetGameTimer() + 500
        elseif GetGameTimer() < helmetGrace then
            -- (same blast as the shot the helmet stopped: a normal hit)
        elseif Config.headshotOneTap ~= false and not alreadyDown and not goingDown then
            -- (a shotgun is several pellets in the same moment: only the first one sends him down)
            goingDown = true
            SetTimeout(3000, function() goingDown = false end)
            -- straight into the last stand (qbx_medical's own flow: the same as the game killing him; EMS can
            -- still revive). Done through its export so the down state is never skipped or half-set.
            damage = damage + (hp - 100)
            lastHp = nil
            CreateThread(function()
                local ok = pcall(function() exports.qbx_medical:StartLastStand(args[2], args[7]) end)
                if not ok then SetEntityHealth(ped, 0) end   -- (fallback: let the game do the death itself)
            end)
        elseif hp > 101 then
            local extra = math.min(math.floor(damage * (Config.headshotBonus or 0.5) + 0.5), hp - 101)
            if extra > 0 then
                SetEntityHealth(ped, hp - extra)
                damage = damage + extra
                lastHp = hp - extra
            end
        end
    end
    pending[#pending + 1] = {
        k = kind, pw = power, w = label,
        p = hit and Config.bones[bone] or nil,
        d = damage, a = armorLost,
    }
    if #pending > 12 then table.remove(pending, 1) end
    flush()
end)

-- health going up (healing) is not a hit: keep the reference up to date
CreateThread(function()
    while true do
        local hp, armor = GetEntityHealth(cache.ped), GetPedArmour(cache.ped)
        if not lastHp or hp > lastHp then lastHp = hp end
        if not lastArmor or armor > lastArmor then lastArmor = armor end
        Wait(500)
    end
end)

-- after a revive the health jumps back: start counting fresh
-- (clearing injuries is done by the server: EMS revive / treat, the hospital bed, respawning)
RegisterNetEvent('qbx_medical:client:playerRevived', function()
    lastHp, lastArmor = nil, nil
end)

-- ---------------------------------------------------------------------
-- being examined
-- ---------------------------------------------------------------------
lib.callback.register('exti_medical:client:consent', function(medicName)
    local answer = lib.alertDialog({
        header = 'فحص طبي',
        content = ('المسعف **%s** يريد فحصك.  \nهل توافق؟'):format(medicName or ''),
        centered = true,
        cancel = true,
        labels = { confirm = 'موافق', cancel = 'لا' },
    })
    return answer == 'confirm'
end)

RegisterNetEvent('exti_medical:client:consentClosed', function()
    pcall(lib.closeAlertDialog)
end)

RegisterNetEvent('exti_medical:client:examined', function(text)
    lib.notify({ id = 'exti_medical_exam', title = 'فحص طبي', description = text, type = 'inform', icon = 'stethoscope', duration = 4000 })
end)

RegisterNetEvent('exti_medical:client:print', function(text)
    print(text)
end)

-- ---------------------------------------------------------------------
-- admin test patient (/fakepatient): the server tells us to put a hurt NPC on the ground here
-- ---------------------------------------------------------------------
local myFakes = {}  -- [id] = ped
local dropped = {}  -- [id] = true: the server already removed it (delete as soon as it exists)

local function deleteFake(id)
    local npc = myFakes[id]
    myFakes[id] = nil
    if npc and DoesEntityExist(npc) then
        SetEntityAsMissionEntity(npc, true, true)
        DeleteEntity(npc)
    end
end

RegisterNetEvent('exti_medical:client:dropFake', function(id)
    id = tonumber(id)
    if not id then return end
    dropped[id] = true
    deleteFake(id)
end)

RegisterNetEvent('exti_medical:client:spawnFake', function(data)
    if type(data) ~= 'table' or type(data.model) ~= 'string' or not tonumber(data.id) then return end
    local id = tonumber(data.id)
    if cache.vehicle then return lib.notify({ type = 'error', description = 'انزل من المركبة أولًا' }) end
    local model = joaat(data.model)
    if not IsModelInCdimage(model) or not pcall(lib.requestModel, model, 8000) then
        return lib.notify({ type = 'error', description = 'تعذّر تحميل شكل المريض التجريبي' })
    end
    local me = cache.ped
    -- in front of you, on the ground (looked up, so it doesn't float on a slope or sink into a curb)
    local front = GetOffsetFromEntityInWorldCoords(me, 0.0, 1.4, 0.0)
    local z = front.z - 1.0
    for _, up in ipairs({ 0.5, 2.0 }) do
        local found, gz = GetGroundZFor_3dCoord(front.x, front.y, front.z + up, false)
        if found and math.abs(gz - (front.z - 1.0)) < 2.5 then z = gz break end
    end
    local npc = CreatePed(4, model, front.x, front.y, z, GetEntityHeading(me) + 180.0, true, true)
    SetModelAsNoLongerNeeded(model)
    if npc == 0 then return end
    myFakes[id] = npc
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCanRagdoll(npc, false)
    SetEntityInvincible(npc, true)
    SetPedKeepTask(npc, true)
    if type(data.dict) == 'string' and type(data.clip) == 'string' and pcall(lib.requestAnimDict, data.dict, 5000) then
        for _ = 1, 20 do -- right after the NPC appears the animation sometimes doesn't take: try again
            Wait(0)
            TaskPlayAnim(npc, data.dict, data.clip, 8.0, 8.0, -1, 1, 0, false, false, false)
            Wait(50)
            if IsEntityPlayingAnim(npc, data.dict, data.clip, 3) then break end
        end
        RemoveAnimDict(data.dict)
    end
    FreezeEntityPosition(npc, true)
    for _ = 1, 50 do
        if NetworkGetEntityIsNetworked(npc) then break end
        NetworkRegisterEntityAsNetworked(npc)
        Wait(100)
    end
    if dropped[id] or not DoesEntityExist(npc) then return deleteFake(id) end
    if not NetworkGetEntityIsNetworked(npc) then
        deleteFake(id)
        return lib.notify({ type = 'error', description = 'تعذّر تجهيز المريض التجريبي' })
    end
    local netId = NetworkGetNetworkIdFromEntity(npc)
    SetNetworkIdCanMigrate(netId, false) -- stays with you, so it keeps lying the way it should
    TriggerServerEvent('exti_medical:server:fakeReady', id, netId)
end)

-- the medic finished the treatment: the test patient sits up
RegisterNetEvent('exti_medical:client:fakeStable', function(id)
    local npc = myFakes[tonumber(id) or 0]
    if not npc or not DoesEntityExist(npc) then return end
    local sex = IsPedMale(npc) and 'male' or 'female'
    local a = Config.fake.anims[1][sex]
    if pcall(lib.requestAnimDict, a[1], 5000) then
        FreezeEntityPosition(npc, false)
        ClearPedTasksImmediately(npc)
        TaskPlayAnim(npc, a[1], a[2], 8.0, 8.0, -1, 1, 0, false, false, false)
        Wait(100)
        FreezeEntityPosition(npc, true)
        RemoveAnimDict(a[1])
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(myFakes) do deleteFake(id) end
end)
