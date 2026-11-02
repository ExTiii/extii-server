-- =====================================================================
-- EX_Tii gangs: the Ammo press and the Weapons workbench (both Crew and up, in the HQ), and the
-- black market buyer (anyone: he buys only what these two gangs made).
--   Each batch: the server takes the parts from the gang stash, then 3 steps of work it times and orders,
--   then the product goes into the gang stash. One batch at a time per gang. Stopping loses the parts.
-- =====================================================================
local ox = exports.ox_inventory
local AM, WP, BM = C.ammo, C.weapons, C.blackMarket
local sessions = {}   -- [gang] = { src, token, stage, stageAt, kind, item, count, parts, pending }

local function station(g) return g.type == 'ammo' and 'press' or g.type == 'weapons' and 'workbench' or nil end

local function tip(g, spotName, text)
    local spot = GANG.spot(g, spotName)
    if not spot or GetResourceState('exti_police') ~= 'started' then return end
    local a, r = math.random() * math.pi * 2, 150.0 * (0.3 + math.random() * 0.7)
    local c = { x = spot.x + math.cos(a) * r, y = spot.y + math.sin(a) * r, z = spot.z }
    SetTimeout(math.random(60, 240) * 1000, function()
        pcall(function()
            exports.exti_police:AddCall({ kind = 'alarm', label = 'بلاغ مجهول', coords = c, text = text, number = 'مجهول' })
        end)
    end)
end
GANG.anonTip = tip

local function level(g) return (GANG.level(g)) end

-- what this gang can make right now (for the menu and the laptop)
local function menuOf(g)
    local lv = level(g)
    local out = {}
    if g.type == 'ammo' then
        for i, t in ipairs(AM.types) do out[#out + 1] = { i = i, label = t.label, item = t.item, rep = t.rep, open = lv >= t.rep } end
    elseif g.type == 'weapons' then
        for i, t in ipairs(WP.guns) do out[#out + 1] = { i = i, label = t.label, item = t.item, rep = t.rep, parts = t.parts, open = lv >= t.rep } end
        for i, t in ipairs(WP.attachments or {}) do out[#out + 1] = { i = 100 + i, label = t.label, item = t.item, rep = t.rep, parts = t.parts, open = lv >= t.rep, attachment = true } end
    end
    return out
end

local function dailyLeft(g)
    local lv = level(g)
    if g.type == 'ammo' then return (AM.dailyRounds[lv] or AM.dailyRounds[#AM.dailyRounds]) - GANG.getDaily('g', g.name, 'rounds') end
    return WP.daily - GANG.getDaily('g', g.name, 'guns')
end

lib.callback.register('exti_gangs:server:craftMenu', function(source)
    local g, m = GANG.memberOf(source)
    local st = g and station(g)
    if not st then return false, 'nogang' end
    if m.rank < 1 then return false, 'rank' end
    if not GANG.near(source, GANG.spot(g, st), 2.5) then return false, 'far' end
    local stash = GANG.stashId(g)
    return true, { type = g.type, list = menuOf(g), parts = ox:GetItemCount(stash, C.types[g.type].part) or 0, left = math.max(0, dailyLeft(g)),
                   cooldown = GANG.cooldownLeft('craft:' .. g.name), batchMax = AM.batchMax, perMaterial = AM.perMaterial }
end)

lib.callback.register('exti_gangs:server:craftBegin', function(source, choice, amount)
    local g, m = GANG.memberOf(source)
    local st = g and station(g)
    if not st then return false, 'nogang' end
    if m.rank < 1 then return false, 'rank' end
    if g.locked then return false, 'locked' end
    if not GANG.near(source, GANG.spot(g, st), 2.5) then return false, 'far' end
    local old = sessions[g.name]
    if old and not (os.time() - old.stageAt > 600 or GetPlayerPed(old.src) == 0) then return false, 'busy' end
    local cd = GANG.cooldownLeft('craft:' .. g.name)
    if cd > 0 then return false, 'cooldown', cd end
    choice = math.tointeger(tonumber(choice))
    local lv = level(g)
    local part = C.types[g.type].part
    local s = { src = source, token = math.random(100000, 999999), stage = 0, stageAt = os.time(), kind = g.type }
    if g.type == 'ammo' then
        local t = choice and AM.types[choice]
        if not t then return false, 'bad' end
        if lv < t.rep then return false, 'rep' end
        amount = math.tointeger(tonumber(amount))
        if not amount or amount < 1 or amount > AM.batchMax then return false, 'bad' end
        local left = dailyLeft(g)
        amount = math.min(amount, math.floor(left / AM.perMaterial))
        if amount < 1 then return false, 'daily' end
        s.item, s.count, s.parts, s.label = t.item, amount * AM.perMaterial, amount, t.label
        s.seconds = AM.stageSeconds
    elseif choice and choice > 100 then
        -- an attachment (no daily cap)
        local t = WP.attachments and WP.attachments[choice - 100]
        if not t then return false, 'bad' end
        if lv < t.rep then return false, 'rep' end
        s.item, s.count, s.parts, s.label, s.attachment = t.item, 1, t.parts, t.label, true
        s.seconds = WP.stageSeconds
    else
        local t = choice and WP.guns[choice]
        if not t then return false, 'bad' end
        if lv < t.rep then return false, 'rep' end
        if dailyLeft(g) < 1 then return false, 'daily' end
        s.item, s.count, s.parts, s.label = t.item, 1, t.parts, t.label
        s.seconds = WP.stageSeconds
    end
    local stash = GANG.stashId(g)
    -- room for what comes out (a full stash would swallow the product)
    if not ox:CanCarryItem(stash, s.item, s.count, (g.type == 'weapons' and not s.attachment) and { serial = WP.serial } or nil) then return false, 'stashfull' end
    -- the machine is taken before the stash is touched (two presses can't start two batches)
    sessions[g.name] = s
    if (ox:GetItemCount(stash, part) or 0) < s.parts or not ox:RemoveItem(stash, part, s.parts) then
        if sessions[g.name] == s then sessions[g.name] = nil end
        return false, 'parts', s.parts
    end
    GANG.log(g, m.name, g.type == 'ammo' and 'ammo_start' or 'gun_start', ('%s · %d'):format(s.label, s.count))
    return true, { token = s.token, label = s.label, count = s.count, parts = s.parts, seconds = s.seconds, kind = g.type }
end)

lib.callback.register('exti_gangs:server:craftStage', function(source, token, stage)
    local g, m, p = GANG.memberOf(source)
    local s = g and sessions[g.name]
    if not s or s.src ~= source or s.token ~= token then return false, 'nosession' end
    if math.type(stage) ~= 'integer' or stage ~= s.stage + 1 then return false, 'order' end
    if not GANG.near(source, GANG.spot(g, station(g)), 4.0) then return false, 'far' end
    if os.time() - s.stageAt < (s.seconds[stage] or 12) then return false, 'fast' end
    s.stage, s.stageAt = stage, os.time()
    if stage < 3 then return true end
    sessions[g.name] = nil
    -- done: the cooldown and the daily count first, then the product
    GANG.setCooldown('craft:' .. g.name, g.type == 'ammo' and AM.cooldown or WP.cooldown)
    local stash = GANG.stashId(g)
    local function give(item, n, meta)
        -- into the stash; if it filled up meanwhile, into his own pockets; else on the floor at his feet
        if ox:AddItem(stash, item, n, meta) then return end
        if ox:CanCarryItem(source, item, n, meta) and ox:AddItem(source, item, n, meta) then
            return GANG.notify(source, 'المخزن ممتلئ: وضعتها في حقيبتك', 'inform')
        end
        local c = GANG.coords(source)
        if c then ox:CustomDrop('صنع العصابة', { { item, n, meta } }, c) end
        GANG.notify(source, 'المخزن وحقيبتك ممتلئان: وضعتها على الأرض بجانبك', 'error')
    end
    if g.type == 'ammo' then
        GANG.addDaily('g', g.name, 'rounds', s.count)
        give(s.item, s.count)
        GANG.addRep(g, C.rep.gain.ammo, 'ammo')
    elseif s.attachment then
        give(s.item, 1)
    else
        GANG.addDaily('g', g.name, 'guns', 1)
        give(s.item, 1, { serial = WP.serial, registered = false, exti_craft = g.name, description = 'الرقم التسلسلي مكشوط' })
        GANG.addRep(g, C.rep.gain.gun, 'gun')
        if math.random() < WP.testFireTip then tip(g, 'workbench', 'إطلاق نار متكرر سُمع في هذه المنطقة (تجربة سلاح؟)') end
    end
    GANG.log(g, GANG.charName(p), g.type == 'ammo' and 'ammo_made' or 'gun_made', ('%s · %d'):format(s.label, s.count))
    return true, { label = s.label, count = s.count }
end)

lib.callback.register('exti_gangs:server:craftStop', function(source)
    for name, s in pairs(sessions) do
        if s.src == source then
            sessions[name] = nil
            GANG.log(GANG.gangs[name], GANG.charName(GANG.player(source)), 'craft_stop', s.label or '')
            return true
        end
    end
    return false
end)

AddEventHandler('playerDropped', function()
    local src = source
    for name, s in pairs(sessions) do if s.src == src then sessions[name] = nil end end
end)

-- the laptop's production tab
function GANG.craftView(g)
    local s = sessions[g.name]
    return {
        type = g.type, list = menuOf(g), parts = ox:GetItemCount(GANG.stashId(g), C.types[g.type].part) or 0,
        made = g.type == 'ammo' and GANG.getDaily('g', g.name, 'rounds') or GANG.getDaily('g', g.name, 'guns'),
        cap = g.type == 'ammo' and (AM.dailyRounds[level(g)] or AM.dailyRounds[#AM.dailyRounds]) or WP.daily,
        cooldown = GANG.cooldownLeft('craft:' .. g.name), busy = s and { label = s.label, stage = s.stage } or nil,
        perMaterial = AM.perMaterial,
    }
end

---------------------------------------------------------------------------
-- the Weapons gang repairs guns at the bench (any gun but police guns): parts from the gang stash
---------------------------------------------------------------------------
local repairing = {}
local function isPoliceGun(m) return type(m) == 'table' and type(m.serial) == 'string' and m.serial:match('POL') ~= nil end
-- tools that use the weapon slot but aren't guns or melee: nothing to repair
local NOT_REPAIRABLE = { WEAPON_PETROLCAN = true, WEAPON_FIREEXTINGUISHER = true, WEAPON_STUNGUN = true }
local function repairable(it)
    return it and type(it.name) == 'string' and it.name:sub(1, 7) == 'WEAPON_' and not NOT_REPAIRABLE[it.name] and not isPoliceGun(it.metadata)
end
local function refund(r)
    local g = r and GANG.gangs[r.g]
    if g then ox:AddItem(GANG.stashId(g), 'gun_parts', WP.repairParts) end
end

lib.callback.register('exti_gangs:server:repairList', function(source)
    local g, m = GANG.memberOf(source)
    if not g or g.type ~= 'weapons' or m.rank < 1 then return false, 'rank' end
    if not GANG.near(source, GANG.spot(g, 'workbench'), 2.5) then return false, 'far' end
    local list = {}
    for _, it in pairs(ox:GetInventoryItems(source) or {}) do
        if repairable(it) and it.metadata then
            local d = tonumber(it.metadata.durability) or 100
            if d < 100 then list[#list + 1] = { slot = it.slot, label = it.label or it.name, durability = math.floor(d) } end
        end
    end
    return true, { list = list, parts = WP.repairParts, have = ox:GetItemCount(GANG.stashId(g), 'gun_parts') or 0, seconds = WP.repairSeconds }
end)

lib.callback.register('exti_gangs:server:repairBegin', function(source, slot)
    local g, m = GANG.memberOf(source)
    if not g or g.type ~= 'weapons' or m.rank < 1 then return false, 'rank' end
    if not GANG.near(source, GANG.spot(g, 'workbench'), 2.5) then return false, 'far' end
    slot = math.tointeger(tonumber(slot))
    local it = slot and ox:GetSlot(source, slot)
    if not repairable(it) then return false, 'bad' end
    if repairing[source] then return false, 'busy' end
    if not ox:RemoveItem(GANG.stashId(g), 'gun_parts', WP.repairParts) then return false, 'parts', WP.repairParts end
    repairing[source] = { slot = slot, name = it.name, serial = it.metadata and it.metadata.serial, at = os.time(), g = g.name }
    return true, WP.repairSeconds
end)

lib.callback.register('exti_gangs:server:repairFinish', function(source)
    local r = repairing[source]; repairing[source] = nil
    if not r then return false end
    -- any failure gives the parts back to the gang stash
    if os.time() - r.at < WP.repairSeconds - 1 then refund(r); return false, 'fast' end
    local g, m = GANG.memberOf(source)
    if not g or g.name ~= r.g or m.rank < 1 or not GANG.near(source, GANG.spot(g, 'workbench'), 3.5) then refund(r); return false, 'far' end
    local it = ox:GetSlot(source, r.slot)
    -- the same gun still in that slot
    if not it or it.name ~= r.name or (it.metadata and it.metadata.serial) ~= r.serial then refund(r); return false, 'moved' end
    it.metadata = it.metadata or {}
    it.metadata.durability = 100
    ox:SetMetadata(source, r.slot, it.metadata)
    GANG.log(GANG.gangs[r.g], GANG.charName(GANG.player(source)), 'gun_repair', it.label or it.name)
    return true, it.label or it.name
end)
AddEventHandler('playerDropped', function()
    local r = repairing[source]; repairing[source] = nil
    refund(r)
end)

---------------------------------------------------------------------------
-- the black market buyer
---------------------------------------------------------------------------
local selling = {}
lib.callback.register('exti_gangs:server:blackMarket', function(source, preview)
    local spot = GANG.spots.blackmarket
    if not spot or not GANG.near(source, spot, 3.0) then return false, 'far' end
    if selling[source] then return false, 'busy' end
    local p = GANG.player(source)
    if not p then return false end
    local cid = p.PlayerData.citizenid
    local room = BM.dailyPerPlayer - GANG.getDaily('m', cid, 'blackmarket')
    -- what he would buy: gang ammo (any) and gang-made guns (no serial, made by a gang)
    local offer, total = {}, 0
    -- ammo: only from an Ammo gang member, up to what his gang made today (minus what it sold here today)
    local mg = GANG.memberOf(source)
    local ammoRoom = 0
    if mg and mg.type == 'ammo' then
        ammoRoom = math.max(0, GANG.getDaily('g', mg.name, 'rounds') - GANG.getDaily('g', mg.name, 'bm_rounds'))
    end
    for _, it in pairs(ox:GetInventoryItems(source) or {}) do
        local price = it and BM.prices[it.name]
        if price then
            local isGun = it.name:sub(1, 7) == 'WEAPON_'
            if isGun and it.metadata and it.metadata.exti_craft then
                offer[#offer + 1] = { name = it.name, slot = it.slot, count = it.count, price = price, label = it.label or it.name }
                total = total + price * it.count
            elseif not isGun and ammoRoom > 0 then
                local n = math.min(it.count, ammoRoom)
                ammoRoom = ammoRoom - n
                offer[#offer + 1] = { name = it.name, slot = it.slot, count = n, price = price, label = it.label or it.name, ammo = true }
                total = total + price * n
            end
        end
    end
    if preview then return true, { offer = offer, total = total, room = math.max(0, room) } end
    if #offer == 0 then return false, 'nothing' end
    if room <= 0 then return false, 'daily' end
    if not ox:CanCarryItem(source, 'black_money', math.min(total, room)) then return false, 'full' end
    selling[source] = true
    local paid, rounds = 0, 0
    for _, o in ipairs(offer) do
        local n = math.min(o.count, math.floor((room - paid) / o.price))
        if n > 0 and ox:RemoveItem(source, o.name, n, nil, o.slot) then
            paid = paid + n * o.price
            if o.ammo then rounds = rounds + n end
        end
        if room - paid < 1 then break end
    end
    if rounds > 0 and mg then GANG.addDaily('g', mg.name, 'bm_rounds', rounds) end
    if paid > 0 then
        ox:AddItem(source, 'black_money', paid)
        GANG.addDaily('m', cid, 'blackmarket', paid)
        GANG.log('-', GANG.charName(p), 'black_market', ('$%d'):format(paid))
    end
    selling[source] = nil
    if paid == 0 then return false, 'daily' end
    return true, paid
end)
AddEventHandler('playerDropped', function() selling[source] = nil end)
