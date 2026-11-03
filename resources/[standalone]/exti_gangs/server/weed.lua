-- =====================================================================
-- EX_Tii gangs: the Weed gang.
--   * pots in the HQ grow room (placed with /gangspots). Crew and up plant a seed from the gang stash.
--   * the plant grows for 30 min (in real time, also while nobody is there). Any member waters it
--     (a watered plant is fine for 10 min); dry time costs buds. Fertilizer (weed_nutrition) gives more.
--   * harvest (Crew+) -> buds into the stash; the table: trim + weigh 2 g bags (2 mini games).
--   * corner selling (anyone with bags): locals walk up and buy; police chance by whose turf it is.
-- =====================================================================
local ox = exports.ox_inventory
local WD = C.weed
local CO = WD.corner
local plants = {}   -- [gang] = { [pot] = { planted, watered, dry, fert } }
local tableBusy = {}
local corners = {}  -- [src] = { pos, started, next, bags }

local function publish()
    local out = {}
    for gang, list in pairs(plants) do
        out[gang] = {}
        for pot, pl in pairs(list) do out[gang][tostring(pot)] = { planted = pl.planted, watered = pl.watered, fert = pl.fert } end
    end
    GlobalState['exti_gangs:plants'] = { list = out, now = os.time() }
end

local function save(gang, pot)
    local pl = plants[gang] and plants[gang][pot]
    if pl then
        MySQL.query('REPLACE INTO `exti_gang_plants` (`gang`, `pot`, `planted`, `watered`, `dry`, `fert`) VALUES (?, ?, ?, ?, ?, ?)',
            { gang, pot, pl.planted, pl.watered, pl.dry, pl.fert and 1 or 0 })
    else
        MySQL.query('DELETE FROM `exti_gang_plants` WHERE `gang` = ? AND `pot` = ?', { gang, pot })
    end
end

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_gang_plants` (
        `gang` VARCHAR(50) NOT NULL,
        `pot` INT NOT NULL,
        `planted` INT NOT NULL,
        `watered` INT NOT NULL,
        `dry` INT NOT NULL DEFAULT 0,
        `fert` TINYINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`gang`, `pot`)
    ) DEFAULT CHARSET=utf8mb4]])
    while not GANG.ready do Wait(100) end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `exti_gang_plants`') or {}) do
        if GANG.gangs[r.gang] then
            plants[r.gang] = plants[r.gang] or {}
            plants[r.gang][r.pot] = { planted = r.planted, watered = r.watered, dry = r.dry, fert = r.fert == 1 }
        end
    end
    publish()
end)

-- a pot was removed by an admin: its plant goes
function GANG.weedPotRemoved(gang, pot)
    if not plants[gang] then return end
    if pot then
        -- the pots after it moved up by one
        local list = {}
        for i, pl in pairs(plants[gang]) do
            if i < pot then list[i] = pl elseif i > pot then list[i - 1] = pl end
        end
        plants[gang] = list
        -- (wait for the delete, or it could land after the new rows and wipe them)
        MySQL.query.await('DELETE FROM `exti_gang_plants` WHERE `gang` = ?', { gang })
        for i in pairs(list) do save(gang, i) end
    else
        plants[gang] = nil
        MySQL.query('DELETE FROM `exti_gang_plants` WHERE `gang` = ?', { gang })
    end
    publish()
end

-- time it was dry since it was last watered, up to `t`
local function dryUntil(pl, t)
    local stop = math.min(t, pl.planted + WD.growSeconds)
    return math.max(0, stop - (pl.watered + WD.waterLasts))
end

local function potSpot(g, pot)
    local set = GANG.spots.hq[g.name]
    return set and set.pots and set.pots[pot]
end

lib.callback.register('exti_gangs:server:pot', function(source, pot, action)
    local g, m, p = GANG.memberOf(source)
    if not g or g.type ~= 'weed' then return false, 'nogang' end
    pot = math.tointeger(tonumber(pot))
    local spot = pot and potSpot(g, pot)
    if not spot or not GANG.near(source, spot, 2.5) then return false, 'far' end
    if g.locked then return false, 'locked' end
    local now = os.time()
    plants[g.name] = plants[g.name] or {}
    local pl = plants[g.name][pot]
    local stash = GANG.stashId(g)

    if action == 'plant' then
        if m.rank < 1 then return false, 'rank' end
        if pl then return false, 'taken' end
        if not ox:RemoveItem(stash, 'gang_weed_seeds', 1) then return false, 'noseed' end
        plants[g.name][pot] = { planted = now, watered = now, dry = 0, fert = false }
        save(g.name, pot); publish()
        return true
    end
    if not pl then return false, 'empty' end

    if action == 'water' then
        if now - pl.watered < 60 then return false, 'wet' end
        pl.dry = pl.dry + dryUntil(pl, now)
        pl.watered = now
        save(g.name, pot); publish()
        return true
    elseif action == 'fert' then
        if pl.fert then return false, 'done' end
        if not ox:RemoveItem(source, 'weed_nutrition', 1) then return false, 'nofert' end
        pl.fert = true
        save(g.name, pot); publish()
        return true
    elseif action == 'harvest' then
        if m.rank < 1 then return false, 'rank' end
        if now < pl.planted + WD.growSeconds then return false, 'growing', pl.planted + WD.growSeconds - now end
        local dry = pl.dry + dryUntil(pl, now)
        local loss = math.min(WD.dryMaxLoss, dry / WD.growSeconds)
        local buds = math.max(1, math.floor(WD.budsBase * (1 - loss) * (pl.fert and (1 + WD.fertBonus) or 1) + 0.5))
        if not ox:CanCarryItem(stash, 'weed_bud', buds) then return false, 'stashfull' end
        plants[g.name][pot] = nil
        save(g.name, pot); publish()
        ox:AddItem(stash, 'weed_bud', buds)
        GANG.addRep(g, C.rep.gain.harvest, 'harvest')
        GANG.log(g, GANG.charName(p), 'weed_harvest', ('%d براعم%s'):format(buds, pl.fert and ' · مسمّد' or ''))
        if math.random() < WD.harvestTip and GANG.anonTip then GANG.anonTip(g, 'weedtable', 'رائحة حشيش قوية في هذه المنطقة') end
        return true, buds
    end
    return false
end)

---------------------------------------------------------------------------
-- the table: trim + weigh -> 2 g bags (buds from the stash, bags into the stash)
---------------------------------------------------------------------------
lib.callback.register('exti_gangs:server:weedTableBegin', function(source)
    local g, m = GANG.memberOf(source)
    if not g or g.type ~= 'weed' then return false, 'nogang' end
    if g.locked then return false, 'locked' end
    if not GANG.near(source, GANG.spot(g, 'weedtable'), 2.5) then return false, 'far' end
    if tableBusy[g.name] and tableBusy[g.name].src ~= source and os.time() - tableBusy[g.name].at < 120 then return false, 'busy' end
    local stash = GANG.stashId(g)
    local have = ox:GetItemCount(stash, 'weed_bud') or 0
    local n = math.min(WD.tableBatch, math.floor(have / WD.budsPerBag))
    if n < 1 then return false, 'nobuds' end
    if not ox:RemoveItem(stash, 'weed_bud', n * WD.budsPerBag) then return false, 'nobuds' end
    if not ox:CanCarryItem(stash, WD.bagItem, n) then ox:AddItem(stash, 'weed_bud', n * WD.budsPerBag); return false, 'stashfull' end
    local t = { src = source, at = os.time(), stage = 0, stageAt = os.time(), n = n, token = math.random(100000, 999999) }
    tableBusy[g.name] = t
    return true, { token = t.token, bags = n, seconds = WD.tableSeconds }
end)

lib.callback.register('exti_gangs:server:weedTableStage', function(source, token, stage)
    local g, m, p = GANG.memberOf(source)
    local t = g and tableBusy[g.name]
    if not t or t.src ~= source or t.token ~= token then return false, 'nosession' end
    if math.type(stage) ~= 'integer' or stage ~= t.stage + 1 then return false, 'order' end
    if not GANG.near(source, GANG.spot(g, 'weedtable'), 4.0) then return false, 'far' end
    if os.time() - t.stageAt < (WD.tableSeconds[stage] or 10) then return false, 'fast' end
    t.stage, t.stageAt = stage, os.time()
    if stage < 2 then return true end
    tableBusy[g.name] = nil
    if not ox:AddItem(GANG.stashId(g), WD.bagItem, t.n) and not ox:AddItem(source, WD.bagItem, t.n) then
        local c = GANG.coords(source)
        if c then ox:CustomDrop('أكياس', { { WD.bagItem, t.n } }, c) end
    end
    GANG.addRep(g, C.rep.gain.bag * t.n, 'bag')
    GANG.log(g, GANG.charName(p), 'weed_bagged', ('%d أكياس'):format(t.n))
    return true, t.n
end)

lib.callback.register('exti_gangs:server:weedTableStop', function(source)
    for name, t in pairs(tableBusy) do
        if t.src == source then
            tableBusy[name] = nil
            -- the buds come back (trimming stopped half way)
            local stash = GANG.stashId(GANG.gangs[name])
            if not ox:AddItem(stash, 'weed_bud', t.n * WD.budsPerBag) then ox:AddItem(source, 'weed_bud', t.n * WD.budsPerBag) end
            return true
        end
    end
    return false
end)

---------------------------------------------------------------------------
-- corner selling (anyone with bags)
---------------------------------------------------------------------------
local function turfKind(src, pos)
    local z = GANG.zoneAt and GANG.zoneAt(pos)
    if not z then return 'none', nil end
    local owner = GANG.turfOwner and GANG.turfOwner(z.id)
    if not owner then return 'none', z end
    local g = GANG.memberOf(src)
    return (g and g.name == owner) and 'own' or 'rival', z, owner
end

lib.callback.register('exti_gangs:server:cornerStart', function(source)
    local here = GANG.coords(source)
    if not here then return false end
    if (ox:GetItemCount(source, WD.bagItem) or 0) < 1 then return false, 'nobags' end
    local p = GANG.player(source)
    if not p then return false end
    if GANG.getDaily('m', p.PlayerData.citizenid, 'corner') >= CO.dailyBags then return false, 'daily' end
    for s, c in pairs(corners) do
        if s ~= source and #(c.pos - here) < 40.0 then return false, 'taken' end
    end
    local kind, z = turfKind(source, here)
    corners[source] = { pos = here, started = os.time(), next = os.time() + math.random(CO.every[1], CO.every[2]), kind = kind }
    return true, { kind = kind, zone = z and z.name or nil, first = corners[source].next - os.time() }
end)

lib.callback.register('exti_gangs:server:cornerStop', function(source) corners[source] = nil; return true end)

-- the game says a local is here and he pressed E to sell
lib.callback.register('exti_gangs:server:cornerSell', function(source)
    local c = corners[source]
    if not c then return false, 'notcorner' end
    local here = GANG.coords(source)
    if not here or #(here - c.pos) > CO.radius then corners[source] = nil; return false, 'moved' end
    local now = os.time()
    if now < c.next then return false, 'wait', c.next - now end
    local p = GANG.player(source)
    if not p then return false end
    local cid = p.PlayerData.citizenid
    local have = ox:GetItemCount(source, WD.bagItem) or 0
    if have < 1 then corners[source] = nil; return false, 'nobags' end
    local room = CO.dailyBags - GANG.getDaily('m', cid, 'corner')
    if room < 1 then corners[source] = nil; return false, 'daily' end
    local ped = GetPlayerPed(source)
    if ped == 0 or GetEntityHealth(ped) <= 0 or (GetResourceState('exti_police') == 'started' and exports.exti_police:IsCuffed(source)) then
        corners[source] = nil; return false, 'cantnow'
    end
    local n = math.min(have, room, math.random(CO.perSale[1], CO.perSale[2]))
    local price = math.random(CO.price[1], CO.price[2])
    if not ox:CanCarryItem(source, 'black_money', n * price) then return false, 'full' end
    if not ox:RemoveItem(source, WD.bagItem, n) then return false, 'nobags' end
    ox:AddItem(source, 'black_money', n * price)
    GANG.addDaily('m', cid, 'corner', n)
    c.next = now + math.random(CO.every[1], CO.every[2])
    local g = GANG.memberOf(source)
    if g and g.type == 'weed' then GANG.addRep(g, C.rep.gain.corner, 'corner') end
    -- the police?
    local kind, z, owner = turfKind(source, here)
    if math.random() < (CO.policeChance[kind] or CO.policeChance.none) and GetResourceState('exti_police') == 'started' then
        pcall(function()
            exports.exti_police:AddCall({ kind = 'alarm', label = 'بيع مخدرات', coords = { x = here.x, y = here.y, z = here.z },
                text = ('شخص يبيع على الزاوية%s'):format(z and (' · ' .. z.name) or ''), number = 'مواطن', suspect = source })
        end)
    end
    -- selling in a rival's turf: they hear about it
    if kind == 'rival' and owner and GANG.gangs[owner] and (c.warned or 0) + 300 < now then
        c.warned = now
        GANG.toGang(GANG.gangs[owner], ('أحدهم يبيع في منطقتكم: %s'):format(z.name), 'error')
    end
    return true, { bags = n, money = n * price, next = c.next - now, left = have - n }
end)

AddEventHandler('playerDropped', function() corners[source] = nil end)

---------------------------------------------------------------------------
-- the laptop's Weed tab
---------------------------------------------------------------------------
function GANG.weedView(g)
    local now = os.time()
    local pots = {}
    local set = GANG.spots.hq[g.name]
    for i = 1, set and set.pots and #set.pots or 0 do
        local pl = plants[g.name] and plants[g.name][i]
        if pl then
            local left = math.max(0, pl.planted + WD.growSeconds - now)
            local wet = math.max(0, pl.watered + WD.waterLasts - now)
            pots[#pots + 1] = { i = i, left = left, wet = wet, fert = pl.fert, ready = left == 0 }
        else
            pots[#pots + 1] = { i = i, empty = true }
        end
    end
    local stash = GANG.stashId(g)
    return { pots = pots, seeds = ox:GetItemCount(stash, 'gang_weed_seeds') or 0, buds = ox:GetItemCount(stash, 'weed_bud') or 0,
             bags = ox:GetItemCount(stash, WD.bagItem) or 0, grow = WD.growSeconds, water = WD.waterLasts }
end
