-- =====================================================================
-- EX_Tii heists: the ATM pull (Tier 2). A tow chain from a pickup truck to a wall ATM, floor it: the ATM
-- rips out of the wall and drags behind the truck (the alarm goes off). Drag it somewhere quiet, unhook
-- it, drill it open. At most 2 in the whole city per hour; the same ATM every 6 hours.
-- =====================================================================
local C = Config
local AT = C.atm

local atms = {}      -- [key] = { key, pos, model, by, veh (netId), phase = 'hooked'|'dragging'|'down'|'drilling', mode, obj (netId) }
local recent = {}    -- os.time() of each rip in the last hour
local TRUCK = {}
for _, m in ipairs(AT.trucks) do TRUCK[joaat(m)] = true end
local MODEL = {}
for _, m in ipairs(AT.models) do MODEL[joaat(m)] = m end

local function keyOf(p) return ('atm:%d:%d:%d'):format(math.floor(p.x * 2), math.floor(p.y * 2), math.floor(p.z)) end

local function publish()
    local out = {}
    for k, a in pairs(atms) do out[k] = { phase = a.phase, x = a.pos.x, y = a.pos.y, z = a.pos.z, model = a.model, veh = a.veh, obj = a.obj, by = a.by } end
    -- the pulled ones stay gone from the wall for a while
    for k, t in pairs(H.atmHidden or {}) do if t > H.now() and not out[k] then out[k] = { phase = 'gone', x = t and H.atmHiddenPos[k].x, y = H.atmHiddenPos[k].y, z = H.atmHiddenPos[k].z, model = H.atmHiddenPos[k].model } end end
    GlobalState['exti_heists:atms'] = out
end
H.atmHidden, H.atmHiddenPos = {}, {}

local function lastHour()
    local t, n = H.now(), 0
    for i = #recent, 1, -1 do if t - recent[i] > 3600 then table.remove(recent, i) else n = n + 1 end end
    return n
end

local function entityOf(netId)
    local e = NetworkGetEntityFromNetworkId(math.tointeger(netId) or 0)
    return (e ~= 0 and DoesEntityExist(e)) and e or nil
end

-- hook the chain: the ATM (where the game found it) and the truck
lib.callback.register('exti_heists:server:atmHook', function(src, pos, modelName, vehNet)
    if type(pos) ~= 'table' or not tonumber(pos.x) then return false end
    pos = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    if H.isCopOnDuty(src) or not H.near(src, pos, 3.0) then return false end
    local mh = joaat(tostring(modelName or ''))
    if not MODEL[mh] then return false end
    local veh = entityOf(vehNet)
    if not veh or not TRUCK[GetEntityModel(veh)] then return false, 'تحتاج شاحنة بيك أب قريبة (Bison, Sadler, Rebel...)' end
    if #(GetEntityCoords(veh) - pos) > 12.0 then return false, 'قرّب الشاحنة من الجهاز' end
    if (exports.ox_inventory:Search(src, 'count', 'tow_chain') or 0) < 1 then return false, 'تحتاج سلسلة سحب (من متجر العدد)' end
    local key = keyOf(pos)
    if atms[key] then return false end
    if H.cooldownLeft(key) > 0 or (H.atmHidden[key] or 0) > H.now() then return false, 'هذا الجهاز سُرق قبل قليل' end
    if lastHour() >= AT.perHour then return false, 'الشرطة متيقّظة الآن: لا أجهزة صراف هذه الساعة' end
    local ok, need = H.canTier(src, AT.tier, true)
    if not ok then return false, ('تحتاج سمعة %d'):format(need) end
    local mode = H.modeFor(AT.tier); if not mode then return false end
    atms[key] = { key = key, pos = pos, model = MODEL[mh], by = src, veh = vehNet, phase = 'hooked', mode = mode, at = H.now() }
    exports.ox_inventory:RemoveItem(src, 'tow_chain', 1)   -- (the chain goes with the ATM)
    publish()
    H.setHeat(src)
    H.log(src, 'atm_hook', ('%s · %s'):format(key, H.modeText(mode)))
    -- not pulled within 2 minutes: the chain comes off (and comes back)
    local a = atms[key]
    SetTimeout(120000, function()
        if atms[key] == a and a.phase == 'hooked' then atms[key] = nil; publish(); exports.ox_inventory:AddItem(src, 'tow_chain', 1) end
    end)
    return true, key
end)

-- the truck pulled away hard: the ATM is out of the wall
RegisterNetEvent('exti_heists:server:atmRip', function(key)
    local src = source
    local a = atms[key]
    if not a or a.phase ~= 'hooked' then return end
    local veh = entityOf(a.veh)
    if not veh then return end
    local d = #(GetEntityCoords(veh) - a.pos)
    if d < 4.0 or d > 40.0 then return end
    -- whoever drives the truck (the hooker or a crew mate)
    local drv = GetPedInVehicleSeat(veh, -1)
    if drv == 0 or NetworkGetEntityOwner(veh) ~= src then return end
    a.phase = 'dragging'; a.dragger = src
    recent[#recent + 1] = H.now()
    H.atmHidden[key] = H.now() + AT.hiddenMinutes * 60
    H.atmHiddenPos[key] = { x = a.pos.x, y = a.pos.y, z = a.pos.z, model = a.model }
    H.setCooldown(key, AT.cooldownHours * 3600)
    H.setHeat(src)
    publish()
    TriggerClientEvent('exti_heists:client:atmDrag', src, key)
    -- the alarm: loud, right away
    local who = { a.by }
    if src ~= a.by then who[#who + 1] = src end
    if GetResourceState('exti_police') == 'started' then
        pcall(function()
            exports.exti_police:AddCall({ kind = 'alarm', label = C.calls.atm, coords = { x = a.pos.x, y = a.pos.y, z = a.pos.z },
                text = 'جهاز صراف اقتُلع من الحائط وسُحب بشاحنة', number = 'إنذار البنك', suspect = src, vehicle = veh, seen = true })
        end)
    end
    if not a.mode.police then H.npcRespond(who, a.pos, 'atm') end
    H.log(src, 'atm_rip', key)
end)

-- the dragging game made the ATM object (networked) behind the truck
RegisterNetEvent('exti_heists:server:atmObject', function(key, objNet)
    local a = atms[key]
    if not a or a.dragger ~= source or math.type(objNet) ~= 'integer' then return end
    a.obj = objNet; publish()
end)

-- unhook it somewhere quiet
lib.callback.register('exti_heists:server:atmDrop', function(src, key)
    local a = atms[key]
    if not a or a.phase ~= 'dragging' then return false end
    local obj = entityOf(a.obj)
    local here = H.coords(src)
    if not obj or not here or #(GetEntityCoords(obj) - here) > 6.0 then return false end
    if #(GetEntityCoords(obj) - a.pos) < AT.quietDistance then return false, ('ابتعد أكثر (%d م على الأقل من البنك)'):format(math.floor(AT.quietDistance)) end
    a.phase = 'down'; publish()
    -- the game that made it (the driver's) lets go of it
    if a.dragger then TriggerClientEvent('exti_heists:client:atmDetach', a.dragger, key) end
    if a.dragger ~= src then TriggerClientEvent('exti_heists:client:atmDetach', src, key) end
    return true
end)

-- drill it open
lib.callback.register('exti_heists:server:atmDrillBegin', function(src, key)
    local a = atms[key]
    if not a or a.phase ~= 'down' or H.isCopOnDuty(src) then return false end
    local obj = entityOf(a.obj)
    if not obj or not H.near(src, GetEntityCoords(obj), 2.6) then return false end
    if (exports.ox_inventory:Search(src, 'count', 'drill') or 0) < 1 then return false, 'تحتاج مثقابًا (من متجر العدد)' end
    if (exports.ox_inventory:Search(src, 'count', 'drill_bit') or 0) < 1 then return false, 'تحتاج رأس مثقاب' end
    a.phase = 'drilling'; a.driller = src; publish()
    local lv = H.skillLevel(H.rec(src), 'breaching')
    return true, H.gameBegin(src, 'drill', { atm = key }), { time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:atmDrillEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'drill', token, passed == true)
    local a = ctx and atms[ctx.atm]
    if not a or a.phase ~= 'drilling' or a.driller ~= src then return false end
    if not passed then
        a.phase = 'down'; publish()
        exports.ox_inventory:RemoveItem(src, 'drill_bit', 1)   -- (it snapped, or you stopped: it's blunt)
        return false, 'bit'
    end
    local obj = entityOf(a.obj)
    if not obj or not H.near(src, GetEntityCoords(obj), 3.0) then a.phase = 'down'; publish() return false end
    atms[a.key] = nil; publish()
    local pay = H.payOf(AT.pay, a.mode)
    H.giveLoot(src, 'black_money', pay)
    H.addSkill(src, 'breaching')
    H.repFor(src, AT.tier, a.mode)
    if H.contract then H.contract(src, 'atm') end
    if a.by ~= src and GetPlayerName(a.by) then H.repFor(a.by, AT.tier, a.mode) end
    H.log(src, 'atm_drilled', ('$%d · %s'):format(pay, H.modeText(a.mode)))
    SetTimeout(30000, function() if DoesEntityExist(obj) then DeleteEntity(obj) end end)
    return true, pay
end)

-- left behind / abandoned: cleaned up after 20 minutes
CreateThread(function()
    while true do
        Wait(30000)
        local t = H.now()
        for k, a in pairs(atms) do
            if t - a.at > 20 * 60 then
                local obj = entityOf(a.obj)
                if obj then DeleteEntity(obj) end
                atms[k] = nil
            end
        end
        publish()
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, a in pairs(atms) do local o = entityOf(a.obj); if o then DeleteEntity(o) end end
end)
CreateThread(function() Wait(2000); publish() end)
