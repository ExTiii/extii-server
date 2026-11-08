-- =====================================================================
-- EX_Tii heists: the ATM pull (Tier 2). A tow chain from a car to a wall ATM, floor it: the ATM
-- rips out of the wall and drags behind the truck (the alarm goes off). Drag it somewhere quiet, unhook
-- it, drill it open. At most 2 in the whole city per hour; the same ATM every 6 hours.
-- =====================================================================
local C = Config
local AT = C.atm

local atms = {}      -- [key] = { key, pos, model, by, veh (netId), phase = 'hooked'|'dragging'|'down'|'drilling', mode, obj (netId) }
local recent = {}    -- os.time() of each rip in the last hour
local MODEL = {}
for _, m in ipairs(AT.models) do MODEL[joaat(m)] = m end

-- (half-metre grid: two ATMs side by side are two different ATMs)
local function keyOf(p) return ('atm2:%d:%d'):format(math.floor(p.x * 2 + 0.5), math.floor(p.y * 2 + 0.5)) end

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
-- before the chain goes on: can this ATM be pulled right now? (so nobody does both steps for nothing)
local function hoursMins(s) s = math.max(0, math.floor(s)); local h = s // 3600; return h > 0 and ('%d س %d د'):format(h, (s % 3600) // 60) or H.mmss(s) end
lib.callback.register('exti_heists:server:atmCheck', function(src, pos)
    if type(pos) ~= 'table' or not tonumber(pos.x) then return false end
    pos = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    if H.isCopOnDuty(src) then return false, 'أنت شرطي في الخدمة' end
    local key = keyOf(pos)
    if atms[key] then return false, 'هذا الجهاز مربوط أو مقتلع الآن' end
    local left = math.max(H.cooldownLeft(key), (H.atmHidden[key] or 0) - H.now())
    if left > 0 then return false, ('هذا الجهاز سُرق قبل قليل: الصندوق فارغ · بعد %s'):format(hoursMins(left)) end
    if lastHour() >= AT.perHour then return false, 'الشرطة متيقّظة الآن: لا أجهزة صراف هذه الساعة' end
    local ok, need = H.canTier(src, AT.tier, true)
    if not ok then return false, ('تحتاج سمعة مستوى %d لسرقة أجهزة الصراف (تطبيق الطاقم ← أنا)'):format(need) end
    if not H.modeFor(AT.tier) then return false, 'لا يمكن الآن' end
    return true
end)

lib.callback.register('exti_heists:server:atmHook', function(src, pos, modelName, vehNet)
    if type(pos) ~= 'table' or not tonumber(pos.x) then return false end
    pos = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    -- (the chain is tied to the ATM first, then the player walks it to the car's back: he's at the car now)
    if H.isCopOnDuty(src) or not H.near(src, pos, 18.0) then return false end
    local mh = joaat(tostring(modelName or ''))
    if not MODEL[mh] then return false end
    local veh = entityOf(vehNet)
    if not veh or GetVehicleType(veh) ~= 'automobile' then return false, 'تحتاج سيارة (لا دراجة ولا قارب)' end
    if not H.near(src, GetEntityCoords(veh), 6.0) then return false end
    if #(GetEntityCoords(veh) - pos) > 14.0 then return false, 'قرّب السيارة من الجهاز' end
    if (exports.ox_inventory:Search(src, 'count', 'tow_chain') or 0) < 1 then return false, 'تحتاج سلسلة سحب (من متجر العدد)' end
    local key = keyOf(pos)
    if atms[key] then return false end
    -- a pulled-out ATM lying somewhere can't be pulled again
    for _, o in pairs(atms) do
        local e = o.obj and entityOf(o.obj)
        if e and #(GetEntityCoords(e) - pos) < 3.0 then return false, 'هذا الجهاز مقتلع أصلًا: اثقبه' end
    end
    if H.cooldownLeft(key) > 0 or (H.atmHidden[key] or 0) > H.now() then return false, 'هذا الجهاز سُرق قبل قليل' end
    if lastHour() >= AT.perHour then return false, 'الشرطة متيقّظة الآن: لا أجهزة صراف هذه الساعة' end
    local ok, need = H.canTier(src, AT.tier, true)
    if not ok then return false, ('تحتاج سمعة %d'):format(need) end
    local mode = H.modeFor(AT.tier); if not mode then return false end
    atms[key] = { key = key, pos = pos, model = MODEL[mh], by = src, veh = vehNet, phase = 'hooked', mode = mode, at = H.now() }
    exports.ox_inventory:RemoveItem(src, 'tow_chain', 1)   -- (the chain goes with the ATM)
    H.touch(src, pos)
    publish()
    H.setHeat(src, AT.tier)
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
    if lastHour() >= AT.perHour then return end
    local veh = entityOf(a.veh)
    if not veh then return end
    local d = #(GetEntityCoords(veh) - a.pos)
    if d < 4.0 or d > 40.0 then return end
    -- whoever drives the truck (the hooker or a crew mate)
    local drv = GetPedInVehicleSeat(veh, -1)
    if drv == 0 or NetworkGetEntityOwner(veh) ~= src then return end
    a.phase = 'dragging'; a.dragger = src; a.at = H.now()
    recent[#recent + 1] = H.now()
    H.atmHidden[key] = H.now() + AT.hiddenMinutes * 60
    H.atmHiddenPos[key] = { x = a.pos.x, y = a.pos.y, z = a.pos.z, model = a.model }
    H.setCooldown(key, AT.cooldownHours * 3600)
    H.setHeat(src, AT.tier)
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
    if not a or a.dragger ~= source or a.phase ~= 'dragging' or a.obj or math.type(objNet) ~= 'integer' then return end
    local obj, veh = entityOf(objNet), entityOf(a.veh)
    if not obj or GetEntityModel(obj) ~= joaat(a.model) or (veh and GetEntityAttachedTo(obj) ~= veh) then return end
    a.obj = objNet; a.at = H.now(); publish()
end)

-- unhook it somewhere quiet
lib.callback.register('exti_heists:server:atmDrop', function(src, key)
    local a = atms[key]
    if not a or a.phase ~= 'dragging' then return false end
    local obj, veh = entityOf(a.obj), entityOf(a.veh)
    local here = H.coords(src)
    -- (while it hangs on the chain the server may still think it's at the bank: measure from the truck)
    local at = veh and GetEntityCoords(veh) or (obj and GetEntityCoords(obj))
    if not obj or not here or not at or #(at - here) > 9.0 then return false end
    if #(at - a.pos) < AT.quietDistance then return false, ('ابتعد أكثر (%d م على الأقل من مكانه)'):format(math.floor(AT.quietDistance)) end
    a.phase = 'down'; a.at = H.now(); publish()
    -- the game that owns it now lets go of it
    local owner = NetworkGetEntityOwner(obj)
    if owner and owner > 0 then TriggerClientEvent('exti_heists:client:atmDetach', owner, key) end
    if owner ~= src then TriggerClientEvent('exti_heists:client:atmDetach', src, key) end
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
    a.phase = 'drilling'; a.driller = src; a.at = H.now(); publish()
    H.touch(src, GetEntityCoords(obj))
    local lv = H.skillLevel(H.rec(src), 'breaching')
    return true, H.gameBegin(src, 'drill', { atm = key }), { time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:atmDrillEnd', function(src, token, passed)
    local ctx = H.gameEnd(src, 'drill', token, passed == true)
    if not ctx then
        for _, x in pairs(atms) do if x.phase == 'drilling' and x.driller == src then x.phase = 'down'; publish() end end
        return false
    end
    local a = atms[ctx.atm]
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
AddEventHandler('playerDropped', function()
    local src = source
    for _, a in pairs(atms) do if a.phase == 'drilling' and a.driller == src then a.phase = 'down'; a.driller = nil end end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, a in pairs(atms) do local o = entityOf(a.obj); if o then DeleteEntity(o) end end
end)
CreateThread(function() Wait(2000); publish() end)

H.registerHeist({ id = 'atm', label = 'جهاز صراف', tier = AT.tier, where = 'بشاحنة وسلسلة', status = function()
    local n = lastHour()
    if n >= AT.perHour then
        local oldest = recent[1] or H.now()
        return 'cooldown', 3600 - (H.now() - oldest), 'الشرطة متيقّظة هذه الساعة'
    end
    return 'ready', 0, ('%d من %d هذه الساعة'):format(n, AT.perHour)
end })

-- admins (F1 → reset robbery waits): the hourly ATM limit and the pulled-out walls come back
function H.resetAtms()
    recent = {}
    H.atmHidden, H.atmHiddenPos = {}, {}
    publish()
end
