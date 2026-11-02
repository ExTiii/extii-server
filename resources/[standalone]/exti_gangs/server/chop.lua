-- =====================================================================
-- EX_Tii gangs: the Chop Shop.
--   * the thief is tagged on the car when he lockpicks / hotwires / takes the keys (car keys script)
--   * a player-owned car sets off the owner's alarm; he can report it stolen (police BOLO)
--   * chop in the HQ garage: 4 stages of real work, the server checks each one and its time
--   * dirty money split (thief / chopper / gang stash), lockpicks + C4 to the stash, daily wanted list
--   * player cars go to the impound with the recovery fee = what the gang made (the fee leaves the economy)
-- =====================================================================
local ox = exports.ox_inventory
local CH = C.chop
local sessions = {}   -- [gang name] = session
local bench = {}      -- [source] = { token, at }

local function isOwnedBy(vehicle)
    local id = Entity(vehicle).state.vehicleid
    if not id then
        local ok, vid = pcall(function() return exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle)) end)
        id = ok and vid or nil
    end
    if not id then return nil end
    local ok, owned = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(id) end)
    if not ok or not owned then return nil end
    return { id = id, citizenid = owned.citizenid, model = owned.modelName }
end

---------------------------------------------------------------------------
-- the thief tag (+ the owner's car alarm)
---------------------------------------------------------------------------
local alarmed = {}   -- [plate] = os.time() (one alarm per car per 10 min)

local function tagThief(src, vehicle, how)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local st = Entity(vehicle).state
    if st.exti_thief then return end
    local cid = GANG.cid(src)
    if not cid then return end
    -- he must really be at the car (these are plain game events: a cheat could send them for any car)
    local here = GANG.coords(src)
    if not here or #(here - GetEntityCoords(vehicle)) > 5.0 then return end
    local owned = isOwnedBy(vehicle)
    if owned and owned.citizenid == cid then return end -- your own car
    st:set('exti_thief', cid, true)
    if owned then
        local plate = GetVehicleNumberPlateText(vehicle):gsub('^%s+', ''):gsub('%s+$', '')
        if (alarmed[plate] or 0) + 600 < os.time() then
            alarmed[plate] = os.time()
            local os_ = GANG.srcOf(owned.citizenid)
            if os_ then
                TriggerClientEvent('exti_gangs:client:carAlarm', os_, { plate = plate, coords = GetEntityCoords(vehicle) })
            end
        end
    end
end

RegisterNetEvent('qbx_vehiclekeys:server:hotwiredVehicle', function(netId)
    tagThief(source, NetworkGetEntityFromNetworkId(netId), 'hotwire')
end)
RegisterNetEvent('qbx_vehiclekeys:server:tookKeys', function(netId)
    tagThief(source, NetworkGetEntityFromNetworkId(netId), 'keys')
end)
RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(netId, state)
    if state ~= 1 then return end
    local src = source
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    local ok, has = pcall(function() return exports.qbx_vehiclekeys:HasKeys(src, veh) end)
    if ok and has then return end -- the owner (or someone with keys) unlocking
    tagThief(src, veh, 'lockpick')
end)

-- the owner reports his car stolen: a BOLO for the police
RegisterNetEvent('exti_gangs:server:reportStolen', function(plate)
    local src = source
    if type(plate) ~= 'string' or #plate > 12 then return end
    local p = GANG.player(src)
    if not p then return end
    local ok, vid = pcall(function() return exports.qbx_vehicles:GetVehicleIdByPlate(plate) end)
    local owned = ok and vid and exports.qbx_vehicles:GetPlayerVehicle(vid)
    if not owned or owned.citizenid ~= p.PlayerData.citizenid then return end
    if GetResourceState('exti_police') == 'started' then
        MySQL.insert('INSERT INTO `exti_police_bolos` (`kind`, `title`, `text`, `plate`, `officer`, `created`) VALUES (?, ?, ?, ?, ?, ?)', {
            'vehicle', ('سيارة مسروقة %s'):format(plate), ('بلاغ من المالك %s'):format(GANG.charName(p)), plate, 'بلاغ مواطن', os.time() })
    end
    GANG.notify(src, ('تم إبلاغ الشرطة: اللوحة %s مطلوبة الآن'):format(plate), 'success')
    GANG.log('-', GANG.charName(p), 'stolen_report', plate)
end)

---------------------------------------------------------------------------
-- the daily wanted list (3 models, same for everyone that day)
---------------------------------------------------------------------------
local function wantedToday()
    local seed = tonumber(os.date('%Y%m%d'))
    local pool, out = {}, {}
    for i, m in ipairs(CH.wantedPool) do pool[i] = m end
    for i = 1, math.min(CH.wantedCount, #pool) do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local k = seed % #pool + 1
        out[#out + 1] = table.remove(pool, k)
    end
    return out
end
local function isWanted(model)
    for _, m in ipairs(wantedToday()) do if joaat(m) == model then return true end end
    return false
end

---------------------------------------------------------------------------
-- can this car be chopped here? (the E prompt asks first, the start checks it all again)
---------------------------------------------------------------------------
local function blockedVehicle(veh)
    local st = Entity(veh).state
    for _, k in ipairs(CH.blockedStates) do if st[k] then return true end end
    return false
end

-- the server can't read a vehicle's class: Qbox's vehicle list knows every model's category
local CATEGORY_TIER = { super = 'super', sports = 'sports', sportsclassics = 'sports', coupes = 'mid', muscle = 'mid', suvs = 'mid',
                        compacts = 'low', sedans = 'low', motorcycles = 'low', offroad = 'low', vans = 'low' }
local byHash
local function tierOf(veh, classFromClient)
    local vt = GetVehicleType and GetVehicleType(veh)
    if vt and vt ~= 'automobile' and vt ~= 'bike' then return nil end -- boats, helis, planes, trailers, trains
    byHash = byHash or exports.qbx_core:GetVehiclesByHash()
    local info = byHash and byHash[GetEntityModel(veh)]
    if info and info.category then return CATEGORY_TIER[info.category] end
    -- a model Qbox doesn't list (can't be checked): the lowest class, if the game says it's a normal car
    local t = math.type(classFromClient) == 'integer' and CH.classes[classFromClient]
    return t and 'low' or nil
end

local function check(src, netId, classFromClient)
    local g, m = GANG.memberOf(src)
    if not g or g.type ~= 'chop' then return nil, 'nogang' end
    if m.rank < 1 then return nil, 'rank' end
    if g.locked then return nil, 'locked' end
    local garage = GANG.spot(g, 'garage')
    if not garage or not GANG.near(src, garage, CH.garageRadius + 3.0) then return nil, 'far' end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'novehicle' end
    local vc = GetEntityCoords(veh)
    if #(vc - vec3(garage.x, garage.y, garage.z)) > CH.garageRadius then return nil, 'outside' end
    for seat = -1, 6 do if GetPedInVehicleSeat(veh, seat) ~= 0 then return nil, 'occupied' end end
    if blockedVehicle(veh) then return nil, 'blocked' end
    local tierName = tierOf(veh, classFromClient)
    if not tierName then return nil, 'blocked' end
    local tier = CH.tiers[tierName]
    local owned = isOwnedBy(veh)
    if owned then
        local cid = m.citizenid
        if owned.citizenid == cid then return nil, 'own' end
        local om = GANG.members[owned.citizenid]
        if om and om.gang == g.name then return nil, 'member' end
        if GANG.cooldownLeft('owner:' .. owned.citizenid) > 0 then return nil, 'hot' end
    end
    return { g = g, m = m, veh = veh, tierName = tierName, tier = tier, owned = owned, wanted = isWanted(GetEntityModel(veh)) }
end

local REASON = {
    nogang = 'ليس لك شيء هنا', rank = 'التفكيك للطاقم فما فوق', locked = 'المقر مقفل: الإيجار غير مدفوع',
    far = 'ادخل ورشة التفكيك', novehicle = 'لا توجد سيارة', outside = 'أدخل السيارة داخل الورشة', occupied = 'أخرِج الجميع من السيارة',
    blocked = 'هذه المركبة لا تُفكّك', own = 'لا يمكنك تفكيك سيارتك', member = 'هذه سيارة أحد أفراد العصابة',
    hot = 'سيارات هذا المالك ساخنة (فُكّكت له سيارة خلال 72 ساعة)', cooldown = 'الورشة تبرد: انتظر', daily = 'وصلتم حد التفكيك اليومي',
    tools = 'أدوات التفكيك في المخزن لا تكفي', busy = 'هناك سيارة قيد التفكيك',
}

lib.callback.register('exti_gangs:server:chopPreview', function(source, netId, class)
    local c, why = check(source, netId, class)
    if not c then return false, REASON[why] or why end
    local t = c.tier
    local lo, hi = t.money[1], t.money[2]
    if c.wanted then lo, hi = math.floor(lo * (1 + CH.wantedBonus)), math.floor(hi * (1 + CH.wantedBonus)) end
    return true, { tier = t.label, tools = t.tools, minutes = math.ceil(t.seconds / 60), money = { lo, hi }, wanted = c.wanted, owned = c.owned ~= nil }
end)

---------------------------------------------------------------------------
-- a chop: start -> 4 stages (doors, wheels, hood & trunk, frame) -> rewards
---------------------------------------------------------------------------
local function endSession(g, keepCar)
    local s = sessions[g.name]
    sessions[g.name] = nil
    if s and DoesEntityExist(s.veh) and keepCar then
        FreezeEntityPosition(s.veh, false)
        Entity(s.veh).state:set('exti_chop', nil, true)
    end
    return s
end

local SESSION_IDLE = 600 -- a chop with no stage for 10 min is abandoned (the car is let go)

lib.callback.register('exti_gangs:server:chopStart', function(source, netId, class)
    local c, why = check(source, netId, class)
    if not c then return false, REASON[why] or why end
    local g, m = c.g, c.m
    local old = sessions[g.name]
    if old and (os.time() - old.stageAt > SESSION_IDLE or GetPlayerPed(old.chopper) == 0) then endSession(g, true); old = nil end
    if old then return false, REASON.busy end
    local cd = GANG.cooldownLeft('chop:' .. g.name)
    if cd > 0 then return false, ('%s (%d:%02d)'):format(REASON.cooldown, cd // 60, cd % 60) end
    local _, L = GANG.level(g)
    if GANG.getDaily('g', g.name, 'chops') >= L.chopsDaily then return false, REASON.daily end
    local stash = GANG.stashId(g)
    if (ox:GetItemCount(stash, 'chop_tools') or 0) < c.tier.tools then return false, REASON.tools end
    if not ox:RemoveItem(stash, 'chop_tools', c.tier.tools) then return false, REASON.tools end
    FreezeEntityPosition(c.veh, true)
    SetVehicleDoorsLocked(c.veh, 2)
    Entity(c.veh).state:set('exti_chop', g.name, true)
    sessions[g.name] = {
        veh = c.veh, netId = netId, chopper = source, chopperCid = m.citizenid, thief = Entity(c.veh).state.exti_thief,
        tierName = c.tierName, tier = c.tier, model = GetEntityModel(c.veh), plate = GetVehicleNumberPlateText(c.veh),
        owned = c.owned, wanted = c.wanted, stage = 0, stageAt = os.time(), startedAt = os.time(),
    }
    GANG.log(g, m.name, 'chop_start', ('%s · %s%s'):format(c.tier.label, sessions[g.name].plate, c.owned and ' · سيارة لاعب' or ''))
    return true, { stageSeconds = math.floor(c.tier.seconds / 4), tier = c.tier.label }
end)

local function pay(src, cid, amount)
    if amount < 1 then return false end
    if src and ox:CanCarryItem(src, 'black_money', amount) then ox:AddItem(src, 'black_money', amount) return true end
    return false
end

local function finish(g, s)
    local t = s.tier
    local money = math.random(t.money[1], t.money[2])
    if s.wanted then money = math.floor(money * (1 + CH.wantedBonus)) end
    local stash = GANG.stashId(g)
    local thiefCut = math.floor(money * g.settings.thiefCut / 100)
    local chopCut = math.floor(money * g.settings.chopperCut / 100)
    local toGang = money - thiefCut - chopCut
    -- the chopper's share
    local chopPlayer = GANG.player(s.chopper)
    if not pay(s.chopper, s.chopperCid, chopCut) then toGang = toGang + chopCut; chopCut = 0 end
    -- the thief's share (only a member of this gang; someone else's share stays with the gang)
    local thiefName = '-'
    local tm = s.thief and GANG.members[s.thief]
    if tm and tm.gang == g.name then
        thiefName = tm.name
        if not pay(GANG.srcOf(s.thief), s.thief, thiefCut) then toGang = toGang + thiefCut; thiefCut = 0 end
    else
        toGang = toGang + thiefCut; thiefCut = 0
    end
    ox:AddItem(stash, 'black_money', toGang)
    local picks = math.random(t.lockpicks[1], t.lockpicks[2])
    ox:AddItem(stash, 'lockpick', picks)
    local c4 = 0
    if t.c4 > 0 and GANG.getDaily('g', g.name, 'c4') < CH.c4Daily and math.random() < t.c4 then
        c4 = 1; ox:AddItem(stash, 'c4', 1); GANG.addDaily('g', g.name, 'c4', 1)
    end
    -- the car itself
    if s.owned and DoesEntityExist(s.veh) then
        local ok, err = pcall(function()
            exports.qbx_vehicles:SaveVehicle(s.veh, { state = 2, depotPrice = money, garage = 'impoundlot', props = nil })
        end)
        if not ok then lib.print.error('[chop] impound failed: ' .. tostring(err)) end
        GANG.setCooldown('owner:' .. s.owned.citizenid, CH.ownerCooldownHours * 3600)
        local os_ = GANG.srcOf(s.owned.citizenid)
        if os_ then
            GANG.notify(os_, ('سيارتك (%s) فُكّكت! تجدها في ساحة الحجز، رسوم الاسترجاع $%d'):format(s.plate:gsub('%s+$', ''), money), 'error', 12000)
        end
    end
    if DoesEntityExist(s.veh) then DeleteEntity(s.veh) end
    GANG.addDaily('g', g.name, 'chops', 1)
    GANG.setCooldown('chop:' .. g.name, CH.cooldown)
    GANG.addRep(g, s.owned and C.rep.gain.playerChop or C.rep.gain.chop, 'chop')
    GANG.log(g, chopPlayer and GANG.charName(chopPlayer) or '-', s.owned and 'chop_player_car' or 'chop',
        ('%s · $%d (العصابة $%d · السارق %s $%d · المفكك $%d) · %d مفاتيح%s%s%s'):format(t.label, money, toGang, thiefName, thiefCut, chopCut,
            picks, c4 > 0 and ' · C4' or '', s.wanted and ' · مطلوبة +30%' or '', s.owned and (' · المالك ' .. s.owned.citizenid) or ''))
    return { money = money, gang = toGang, mine = chopCut + (s.thief == s.chopperCid and thiefCut or 0), lockpicks = picks, c4 = c4, wanted = s.wanted }
end

lib.callback.register('exti_gangs:server:chopStage', function(source, stage)
    local g, m = GANG.memberOf(source)
    local s = g and sessions[g.name]
    if not s or s.chopper ~= source then
        for name, ss in pairs(sessions) do if ss.chopper == source then endSession(GANG.gangs[name], true) end end
        return false, 'nosession'
    end
    if m.rank < 1 then endSession(g, true) return false, 'rank' end
    if math.type(stage) ~= 'integer' or stage ~= s.stage + 1 then return false, 'order' end
    if not DoesEntityExist(s.veh) then endSession(g); return false, 'gone' end
    local here = GANG.coords(source)
    if not here or #(here - GetEntityCoords(s.veh)) > 6.0 then return false, 'far' end
    local need = math.floor(s.tier.seconds / 4 * 0.85)
    if os.time() - s.stageAt < need then return false, 'fast' end
    s.stage, s.stageAt = stage, os.time()
    if stage < 4 then return true end
    endSession(g)
    return true, finish(g, s)
end)

lib.callback.register('exti_gangs:server:chopCancel', function(source)
    local g, s
    for name, ss in pairs(sessions) do if ss.chopper == source then g, s = GANG.gangs[name], ss end end
    if not s or not g then return false end
    endSession(g, true)
    GANG.log(g, GANG.charName(GANG.player(source)), 'chop_cancel', s.plate)
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    for name, s in pairs(sessions) do
        if s.chopper == src then endSession(GANG.gangs[name], true) end
    end
    bench[src] = nil
end)

---------------------------------------------------------------------------
-- the lockpick bench: 1 Chop Tools from the stash -> 2 lockpicks into the stash
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:benchBegin', function(source)
    local g, m = GANG.memberOf(source)
    if not g or g.type ~= 'chop' or m.rank < 1 then return false, 'rank' end
    if g.locked then return false, 'locked' end
    if not GANG.near(source, GANG.spot(g, 'bench'), 2.5) then return false, 'far' end
    if (ox:GetItemCount(GANG.stashId(g), 'chop_tools') or 0) < 1 then return false, 'tools' end
    bench[source] = { token = math.random(100000, 999999), at = os.time() }
    return true, { token = bench[source].token, seconds = CH.benchSeconds }
end)

lib.callback.register('exti_gangs:server:benchFinish', function(source, token)
    local b = bench[source]; bench[source] = nil
    local g, m, p = GANG.memberOf(source)
    if not b or not g or b.token ~= token or os.time() - b.at < CH.benchSeconds - 1 then return false end
    if not GANG.near(source, GANG.spot(g, 'bench'), 3.0) then return false end
    local stash = GANG.stashId(g)
    if not ox:RemoveItem(stash, 'chop_tools', 1) then return false, 'tools' end
    ox:AddItem(stash, 'lockpick', CH.benchGive)
    GANG.addRep(g, C.rep.gain.bench, 'bench')
    GANG.log(g, GANG.charName(p), 'bench_lockpicks', ('1 أدوات → %d مفاتيح'):format(CH.benchGive))
    return true, CH.benchGive
end)

---------------------------------------------------------------------------
-- what the laptop shows on the Production tab
---------------------------------------------------------------------------
function GANG.chopView(g, m)
    local _, L = GANG.level(g)
    local s = sessions[g.name]
    local wanted = {}
    for _, name in ipairs(wantedToday()) do wanted[#wanted + 1] = name end
    local tiers = {}
    for key, t in pairs(CH.tiers) do tiers[#tiers + 1] = { key = key, label = t.label, tools = t.tools, minutes = math.ceil(t.seconds / 60), money = t.money, lockpicks = t.lockpicks, c4 = t.c4 } end
    table.sort(tiers, function(a, b) return a.money[1] > b.money[1] end)
    return {
        cooldown = GANG.cooldownLeft('chop:' .. g.name), chops = GANG.getDaily('g', g.name, 'chops'), chopsCap = L.chopsDaily,
        c4 = GANG.getDaily('g', g.name, 'c4'), c4Cap = CH.c4Daily, wanted = wanted, wantedBonus = CH.wantedBonus,
        tools = ox:GetItemCount(GANG.stashId(g), 'chop_tools') or 0, tiers = tiers,
        busy = s and { plate = s.plate, stage = s.stage, tier = s.tier.label } or nil,
        split = { thief = g.settings.thiefCut, chopper = g.settings.chopperCut },
    }
end
