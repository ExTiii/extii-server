-- =====================================================================
-- EX_Tii heists: the armored truck (Tier 5) and the Merryweather convoy (Tier 6).
-- Text the fence "شاحنة" (or "قافلة": a blue USB to find it, the blueprints prep, $8,000 from your bank).
-- The truck leaves on one of its routes; you get the area. Stop it (tyres, the driver, block it): the
-- guards get out and fight, the alarm goes (the police see the truck's GPS for 3 minutes). C4 on the back
-- doors (the wiring game), 30 s, boom, then the bags one by one.
-- The server makes the trucks and their men; whichever game owns the driver drives it.
-- =====================================================================
local C = Config
local T = C.trucks

local jobs = {}    -- [id] = { id, kind, def, phase = 'drive'|'stopped'|'fuse'|'open'|'done', veh, peds, escorts, route, leg, by, crew, mode, bags }
local nextId = 0

local function entOf(n)
    local e = NetworkGetEntityFromNetworkId(math.tointeger(n) or 0)
    return (e ~= 0 and DoesEntityExist(e)) and e or nil
end
local function cdKey(kind) return 'truck:' .. kind end

local function publish()
    local out = {}
    for id, j in pairs(jobs) do
        out[tostring(id)] = { kind = j.kind, phase = j.phase, veh = j.veh, bags = j.bags, peds = j.peds, escorts = j.escorts, leg = j.leg, start = j.start,
                              route = j.route, speed = j.def.speed, fuseLeft = j.fuseAt and math.max(0, j.fuseAt - H.now()) or nil }
    end
    GlobalState['exti_heists:trucks'] = out
end

local function cleanup(j)
    local all = { j.veh }
    if not j.veh then all = {} end
    for _, n in ipairs(j.peds or {}) do all[#all + 1] = n end
    for _, e in ipairs(j.escorts or {}) do all[#all + 1] = e.veh; for _, n in ipairs(e.peds) do all[#all + 1] = n end end
    for _, n in ipairs(all) do local e = entOf(n); if e then DeleteEntity(e) end end
end

local function finish(id, why)
    local j = jobs[id]; if not j then return end
    j.phase = 'done'; publish()
    H.log(j.by, 'truck_end', ('%s · %s'):format(j.kind, why))
    SetTimeout(180000, function() if jobs[id] == j then cleanup(j); jobs[id] = nil; publish() end end)
end

---------------------------------------------------------------------------
-- starting one (the fence)
---------------------------------------------------------------------------
function H.startTruck(src, kind, test)
    local def = T[kind]; if not def then return false, 'off' end
    if H.isCopOnDuty(src) then return false, 'cop' end
    for _, j in pairs(jobs) do if j.kind == kind and j.phase ~= 'done' then return false, 'واحدة على الطريق الآن' end end
    local left = H.cooldownLeft(cdKey(kind))
    if left > 0 then return false, ('لا شاحنات الآن. بعد %d دقيقة'):format(math.ceil(left / 60)) end
    if H.isHot(src) then return false, 'أنت مطلوب الآن. اهدأ أولًا' end
    local ok, need = H.canTier(src, def.tier, true)
    if not ok then return false, ('هذا أكبر منك. تحتاج سمعة %d'):format(need) end
    local mode, need2 = H.modeFor(def.tier)
    if not mode then return false, ('الشرطة قليلة الليلة: أحتاج %d في الخدمة'):format(need2 or 0) end
    if def.needs.usb and (exports.ox_inventory:Search(src, 'count', def.needs.usb) or 0) < 1 then
        return false, ({ usb_blue = 'تحتاج فلاشة زرقاء لتعقّب القافلة', usb_gold = 'تحتاج فلاشة ذهبية لتعطيل GPS الشاحنة' })[def.needs.usb] or 'تحتاج فلاشة'
    end
    if def.needs.prep and not H.hasPrep(src, def.needs.prep) then return false, ('ينقصك التحضير: %s. اكتب "تحضير قافلة"'):format(C.preps[def.needs.prep].label) end
    local p = H.player(src)
    if def.cost > 0 and (not p or (p.PlayerData.money.bank or 0) < def.cost) then return false, ('أحتاج %d$ من حسابك في البنك'):format(def.cost) end
    -- everything checked: take it all
    if def.cost > 0 then p.Functions.RemoveMoney('bank', def.cost, 'heist-setup') end
    if def.needs.usb then exports.ox_inventory:RemoveItem(src, def.needs.usb, 1) end
    if def.needs.prep then H.takePrep(src, def.needs.prep) end
    local route = def.route or T.routes[math.random(#T.routes)]
    local s = route[1]
    nextId = nextId + 1
    local id = nextId
    local pts = {}
    for i = 2, #route do pts[#pts + 1] = { x = route[i].x, y = route[i].y, z = route[i].z } end
    -- (the truck waits at its start: it is made by the game of whoever of the crew gets there first)
    jobs[id] = { id = id, kind = kind, def = def, phase = 'waiting', start = { x = s.x, y = s.y, z = s.z, w = s.w }, peds = {}, escorts = {}, route = pts, leg = 1,
                 by = src, byCid = H.cid(src), crew = { [src] = true }, mode = mode, bags = def.bags, at = H.now(),
                 refund = { cost = def.cost, usb = def.needs.usb, prep = def.needs.prep }, test = test }
    H.setCooldown(cdKey(kind), def.cooldownMinutes * 60)
    H.setHeat(src, def.tier)
    publish()
    H.log(src, 'truck_start', ('%s · %s'):format(kind, H.modeText(mode)))
    local j = jobs[id]
    -- nobody came for it in 15 minutes: everything back; 30 minutes in any phase: over
    SetTimeout(15 * 60 * 1000, function()
        if jobs[id] ~= j or j.phase ~= 'waiting' then return end
        local by = leader(j)
        local p = GetPlayerName(by) and H.player(by)
        if p and j.refund.cost > 0 then p.Functions.AddMoney('bank', j.refund.cost, 'heist-setup-refund') end
        if p and j.refund.usb then exports.ox_inventory:AddItem(by, j.refund.usb, 1) end
        if p and j.refund.prep then exports.ox_inventory:AddItem(by, j.refund.prep, 1, { label = C.preps[j.refund.prep].label, description = 'لعملية واحدة', expires = H.now() + 3600 * 2, owner = j.byCid }) end
        H.clearCooldown(cdKey(kind))
        finish(id, 'never came')
    end)
    SetTimeout(30 * 60 * 1000, function() if jobs[id] == j and j.phase ~= 'done' then finish(id, 'time') end end)
    return true, { pos = vec3(s.x, s.y, s.z), label = def.label }
end

---------------------------------------------------------------------------
-- the truck is made by the first of the crew to come near its start (on the ground, his game)
---------------------------------------------------------------------------
-- the leader now (a relog gives him a new server id: we follow his character)
local function leader(j)
    if j.byCid then
        local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(j.byCid) end)
        if ok and p then j.by = p.PlayerData.source end
    end
    return j.by
end
local function crewOf(j)
    local by = leader(j)
    local list = H.crewOnline and H.crewOnline(by) or { by }
    local set = {}
    for _, s in ipairs(list) do set[s] = true end
    set[j.by] = true
    return set
end
CreateThread(function()
    while true do
        Wait(2000)
        for id, j in pairs(jobs) do
            if j.phase == 'waiting' and (not j.asked or H.now() - j.asked > 45) then
                local start = vec3(j.start.x, j.start.y, j.start.z)
                for s in pairs(crewOf(j)) do
                    if GetPlayerName(s) and H.near(s, start, 300.0) then
                        j.asked, j.asker = H.now(), s
                        TriggerClientEvent('exti_heists:client:truckSpawn', s, id, j.start, j.def.model, j.def.crew, j.def.escorts or {}, j.def.guardModel)
                        break
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('exti_heists:server:truckSpawned', function(id, vehNet, pedNets, escorts)
    local src = source
    local j = jobs[math.tointeger(id) or -1]
    -- a report we can't use (late, or not ours): what it made must not stay in the world
    local function scrap()
        local list = { vehNet }
        for _, n in ipairs(type(pedNets) == 'table' and pedNets or {}) do list[#list + 1] = n end
        for _, e in ipairs(type(escorts) == 'table' and escorts or {}) do list[#list + 1] = e.veh; for _, n in ipairs(type(e.peds) == 'table' and e.peds or {}) do list[#list + 1] = n end end
        for _, n in ipairs(list) do
            local e = entOf(n)
            if e and NetworkGetEntityOwner(e) == src and not IsPedAPlayer(e) then DeleteEntity(e) end
        end
    end
    if not j or j.phase ~= 'waiting' or j.asker ~= src then return scrap() end
    local start = vec3(j.start.x, j.start.y, j.start.z)
    local veh = entOf(vehNet)
    if not veh or GetEntityType(veh) ~= 2 or GetEntityModel(veh) ~= joaat(j.def.model) or #(GetEntityCoords(veh) - start) > 30.0 then return scrap() end
    local tag = ('%s:%d'):format(j.kind, j.id)
    local function takePeds(list, max)
        local out = {}
        for _, n in ipairs(type(list) == 'table' and list or {}) do
            local e = entOf(n)
            if e and GetEntityType(e) == 1 and not IsPedAPlayer(e) and #out < max and #(GetEntityCoords(e) - start) < 60.0 then
                out[#out + 1] = n; Entity(e).state:set('exti_truckped', tag, true); pcall(SetEntityOrphanMode, e, 2)
            end
        end
        return out
    end
    j.veh = vehNet
    Entity(veh).state:set('exti_truck', tag, true); pcall(SetEntityOrphanMode, veh, 2)
    j.peds = takePeds(pedNets, #j.def.crew)
    j.escorts = {}
    for k, e in ipairs(type(escorts) == 'table' and escorts or {}) do
        local ev = entOf(e.veh)
        if ev and GetEntityType(ev) == 2 and k <= #(j.def.escorts or {}) and #(GetEntityCoords(ev) - start) < 60.0 then
            Entity(ev).state:set('exti_truck', tag, true); pcall(SetEntityOrphanMode, ev, 2)
            j.escorts[#j.escorts + 1] = { veh = e.veh, peds = takePeds(e.peds, #j.def.escorts[k].crew) }
        end
    end
    j.phase = 'drive'
    publish()
    H.log(src, 'truck_spawned', ('%s · %d guards'):format(j.kind, #j.peds))
end)

---------------------------------------------------------------------------
-- on the road: the driver's game tells us the leg he finished; stopped = the fight
---------------------------------------------------------------------------
RegisterNetEvent('exti_heists:server:truckLeg', function(id, leg)
    local j = jobs[math.tointeger(id) or -1]
    if not j or j.phase ~= 'drive' then return end
    local veh = entOf(j.veh); if not veh or NetworkGetEntityOwner(veh) ~= source then return end
    leg = math.tointeger(leg)
    if not leg or leg ~= j.leg then return end
    local p = j.route[leg]
    if #(GetEntityCoords(veh) - vec3(p.x, p.y, p.z)) > 40.0 then return end
    if leg >= #j.route then return finish(j.id, 'arrived') end
    j.leg = leg + 1; publish()
end)

local function alarmTruck(j, src)
    if j.alarmed then return end
    j.alarmed = true
    local veh = entOf(j.veh)
    local c = veh and GetEntityCoords(veh) or H.coords(src)
    local list = {}
    for s in pairs(j.crew) do list[#list + 1] = s end
    if GetResourceState('exti_police') == 'started' and c then
        pcall(function()
            exports.exti_police:AddCall({ kind = 'alarm', label = j.kind == 'convoy' and C.calls.convoy or C.calls.truck, coords = { x = c.x, y = c.y, z = c.z },
                text = ('%s · توقّفت والحرّاس يطلقون النار'):format(j.def.label), number = j.kind == 'convoy' and 'ميري ويذر' or 'غروبه 6', suspect = src, vehicle = veh, seen = true })
        end)
    end
    if not j.mode.police and c and #list > 0 then H.npcRespond(list, c, 'truck') end
    -- the truck's GPS: the police see it for a while
    if (j.def.gpsSeconds or 0) > 0 then
        local untilT = H.now() + j.def.gpsSeconds
        CreateThread(function()
            while jobs[j.id] == j and H.now() < untilT do
                local v = entOf(j.veh)
                if v then
                    local p = GetEntityCoords(v)
                    for _, cop in ipairs(GetPlayers()) do
                        local cs = tonumber(cop)
                        if cs and H.isCopOnDuty(cs) then TriggerClientEvent('exti_heists:client:truckGps', cs, { x = p.x, y = p.y }, untilT - H.now()) end
                    end
                end
                Wait(5000)
            end
        end)
    end
    H.log(src, 'truck_alarm', j.kind)
end

RegisterNetEvent('exti_heists:server:truckStopped', function(id, why)
    local src = source
    local j = jobs[math.tointeger(id) or -1]
    if not j or j.phase ~= 'drive' then return end
    local veh = entOf(j.veh); if not veh then return end
    local here = H.coords(src)
    if H.isCopOnDuty(src) or not here or #(GetEntityCoords(veh) - here) > 80.0 then return end
    local drv = GetPedInVehicleSeat(veh, -1)
    local downed = drv == 0 or GetEntityHealth(drv) <= 0
    local speed = #(GetEntityVelocity(veh))
    -- the crew can say "it stopped" (it really stands still); anyone else only when it's plainly hit
    -- (a truck waiting at a red light next to a stranger is not a robbery)
    if crewOf(j)[src] then
        if speed > 2.5 and not downed then return end
    elseif not downed then
        return
    end
    j.phase = 'stopped'; j.crew[src] = true
    H.setHeat(src, j.def.tier)
    publish()
    alarmTruck(j, src)
    H.log(src, 'truck_stopped', ('%s · %s'):format(j.kind, tostring(why)))
end)

---------------------------------------------------------------------------
-- the back doors: C4 (the wiring game), the fuse, the doors blow
---------------------------------------------------------------------------
local function rearOf(veh)
    local c, f = GetEntityCoords(veh), GetEntityHeading(veh)
    local a = math.rad(f)
    return vec3(c.x + math.sin(a) * 4.2, c.y - math.cos(a) * 4.2, c.z)
end

lib.callback.register('exti_heists:server:truckC4Begin', function(src, id)
    local j = jobs[math.tointeger(id) or -1]
    if j and j.planting and H.now() - (j.plantAt or 0) > (C.games.maxSeconds or 240) then j.planting = nil end
    if not j or j.phase ~= 'stopped' or H.isCopOnDuty(src) or j.planting then return false end
    local veh = entOf(j.veh); if not veh then return false end
    if #(H.coords(src) - rearOf(veh)) > 2.6 then return false, 'قف عند الباب الخلفي' end
    local n = j.def.c4 or 1
    if (exports.ox_inventory:Search(src, 'count', 'c4') or 0) < n then return false, ('تحتاج %d C4 (من ورشة التفكيك)'):format(n) end
    exports.ox_inventory:RemoveItem(src, 'c4', n)
    H.log(src, 'item_used', 'c4 · ' .. j.kind)
    j.planting, j.plantAt = src, H.now(); j.crew[src] = true
    H.touch(src, rearOf(veh))
    local lv = H.skillLevel(H.rec(src), 'breaching')
    return true, H.gameBegin(src, 'c4', { truck = j.id }), { leads = j.def.tier >= 6 and 4 or 3, time = 1.0 + (lv - 1) * C.skills.timeBonus, level = lv }
end)

lib.callback.register('exti_heists:server:truckC4End', function(src, token, passed)
    local ctx = H.gameEnd(src, 'c4', token, passed == true)
    local j = ctx and jobs[ctx.truck]
    if not j then for _, x in pairs(jobs) do if x.planting == src then x.planting = nil end end return false end
    j.planting = nil
    if j.phase ~= 'stopped' then return false end
    if not passed then return false, 'fault' end
    local veh = entOf(j.veh); if not veh or #(H.coords(src) - rearOf(veh)) > 3.5 then return false end
    H.addSkill(src, 'breaching')
    j.phase = 'fuse'; j.fuseAt = H.now() + j.def.fuseSeconds; publish()
    local mark = j
    SetTimeout(j.def.fuseSeconds * 1000, function()
        if jobs[mark.id] ~= mark or mark.phase ~= 'fuse' then return end
        mark.phase = 'open'; mark.fuseAt = nil; publish()
        local v = entOf(mark.veh)
        if v then
            local r = rearOf(v)
            TriggerClientEvent('exti_heists:client:truckBlow', -1, mark.veh, { x = r.x, y = r.y, z = r.z })
        end
    end)
    return true, j.def.fuseSeconds
end)

---------------------------------------------------------------------------
-- the bags
---------------------------------------------------------------------------
local grabbing = {}   -- [src] = { id, at }
lib.callback.register('exti_heists:server:truckBagBegin', function(src, id)
    local j = jobs[math.tointeger(id) or -1]
    if not j or j.phase ~= 'open' or j.bags <= 0 or H.isCopOnDuty(src) then return false end
    local veh = entOf(j.veh); if not veh or #(H.coords(src) - rearOf(veh)) > 3.0 then return false end
    grabbing[src] = { id = j.id, at = GetGameTimer() }
    return true, j.def.bagSeconds
end)
lib.callback.register('exti_heists:server:truckBagEnd', function(src)
    local g = grabbing[src]; grabbing[src] = nil
    local j = g and jobs[g.id]
    if not j or j.phase ~= 'open' or j.bags <= 0 then return false end
    if GetGameTimer() - g.at < (j.def.bagSeconds - 1) * 1000 then return false end
    local veh = entOf(j.veh); if not veh or #(H.coords(src) - rearOf(veh)) > 3.5 then return false end
    j.bags = j.bags - 1; publish()
    local d = j.def
    local pay = d.perBag and math.random(d.perBag[1], d.perBag[2]) or H.payOf(d.money, j.mode)
    H.giveLoot(src, d.item, pay, d.item == 'marked_bills' and { trace = H.now() + 600, bank = d.label } or nil)
    local extra
    if d.extra and j.bags < 2 then extra = math.random(d.extra.amount[1], d.extra.amount[2]); H.giveLoot(src, d.extra.item, extra) end
    local usb = d.usb and not j.usbGiven and math.random() < d.usb.chance * (j.mode.usb or 1)
    if usb then j.usbGiven = true; exports.ox_inventory:AddItem(src, d.usb.item, 1) end
    j.looted = j.looted or {}; j.looted[src] = true
    H.log(src, 'truck_bag', ('%s · $%d%s'):format(j.kind, pay, usb and (' + ' .. d.usb.item) or ''))
    if j.bags <= 0 then
        for s in pairs(j.looted) do if GetPlayerName(s) then H.repFor(s, d.tier, j.mode) end end
        if H.contract then H.contract(src, j.kind) end
        if j.kind == 'bigscore' and H.bigScoreFinished then H.bigScoreFinished(j.looted, j.test) end
        finish(j.id, 'emptied')
    end
    return true, { money = pay, item = d.item, extra = extra and { item = d.extra.item, n = extra } or nil, usb = usb and d.usb.item or nil, left = j.bags }
end)
AddEventHandler('playerDropped', function() grabbing[source] = nil end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then for _, j in pairs(jobs) do cleanup(j) end end end)
CreateThread(function() Wait(1000); GlobalState['exti_heists:trucks'] = {} end)

for kind, def in pairs({ armored = T.armored, convoy = T.convoy }) do
    H.registerHeist({ id = kind, label = def.label, tier = def.tier, where = kind == 'convoy' and 'فلاشة زرقاء + تحضير + 8,000$' or 'C4 + طاقم من 3', status = function()
        for _, j in pairs(jobs) do if j.kind == kind and j.phase ~= 'done' then return 'busy', 0, 'على الطريق الآن' end end
        local left = H.cooldownLeft(cdKey(kind))
        if left > 0 then return 'cooldown', left end
        return 'ready', 0, ('اكتب للمصرّف "%s"'):format(kind == 'convoy' and 'قافلة' or 'شاحنة')
    end })
end
function H.resetTrucks()
    for k in pairs(T) do if type(T[k]) == 'table' and T[k].model then H.clearCooldown(cdKey(k)) end end
    for _, j in pairs(jobs) do cleanup(j) end
    jobs = {}
    publish()
end
