-- =====================================================================
-- EX_Tii Level (server): XP lives on the character (metadata.xp) and is only given by the scripts
-- that pay for real work. Everything is checked here: the same thing twice in a row gives nothing,
-- and nobody can get more than Config.maxPerHour XP in an hour.
--
--   exports.exti_level:AddXP(source, amount, reason, key) -> XP really given (0 if refused)
--       reason = the short text on the card ('سحب مركبة'); key = what makes it "the same thing"
--       (a patient's citizenid, a plate + part...) so it only counts once per Config.repeatMinutes
--   exports.exti_level:GetLevel(source or citizenid) -> level
--   exports.exti_level:Info(source) -> { level, xp, cur, need, pct, max }
-- =====================================================================

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function xpOf(player)
    return math.max(0, math.floor(tonumber(player.PlayerData.metadata and player.PlayerData.metadata.xp) or 0))
end

-- what the other scripts unlock at each level (the job centre tells: { { level, label } })
local function unlocksBetween(from, to)
    local list = {}
    if GetResourceState('exti_jobs') ~= 'started' then return list end
    local ok, all = pcall(function() return exports.exti_jobs:Unlocks() end)
    if not ok or type(all) ~= 'table' then return list end
    for _, u in ipairs(all) do
        if u.level > from and u.level <= to then list[#list + 1] = u.label end
    end
    return list
end

local function nextUnlock(level)
    if GetResourceState('exti_jobs') ~= 'started' then return nil end
    local ok, all = pcall(function() return exports.exti_jobs:Unlocks() end)
    if not ok or type(all) ~= 'table' then return nil end
    local best
    for _, u in ipairs(all) do
        if u.level > level and (not best or u.level < best.level) then best = u end
    end
    return best
end

local function publish(src, player)
    local info = LVL.info(xpOf(player))
    Player(src).state:set('level', info.level, true)
    return info
end

---------------------------------------------------------------------------
-- anti-farm memory
---------------------------------------------------------------------------
local recent = {}   -- [src] = { { t, xp }, ... } the last hour
local seen = {}     -- [citizenid:key] = os.time()
local capTold = {}  -- [src] = when we last said "limit reached"

local function lastHour(src)
    local now, sum, keep = os.time(), 0, {}
    for _, e in ipairs(recent[src] or {}) do
        if now - e[1] < 3600 then keep[#keep + 1] = e sum = sum + e[2] end
    end
    recent[src] = keep
    return sum
end

CreateThread(function()
    while true do
        Wait(600000)
        local now = os.time()
        for k, t in pairs(seen) do if now - t >= Config.repeatMinutes * 60 then seen[k] = nil end end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    recent[src], capTold[src] = nil, nil
end)

---------------------------------------------------------------------------
-- giving XP
---------------------------------------------------------------------------
local function addXP(src, amount, reason, key)
    src = tonumber(src)
    local player = src and getPlayer(src)
    if not player then return 0 end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return 0 end
    amount = math.min(amount, 500)
    local cid = player.PlayerData.citizenid
    local now = os.time()
    if key ~= nil then
        local k = ('%s:%s'):format(cid, tostring(key))
        if seen[k] and now - seen[k] < Config.repeatMinutes * 60 then return 0 end
        seen[k] = now
    end
    local room = Config.maxPerHour - lastHour(src)
    if room <= 0 then
        if not capTold[src] or now - capTold[src] > 600 then
            capTold[src] = now
            TriggerClientEvent('ox_lib:notify', src, { type = 'inform', duration = 7000,
                description = 'وصلت لأقصى خبرة في الساعة. استمر في العمل والمال، وتعود الخبرة بعد قليل' })
        end
        lib.logger(src, 'level', ('xp capped (%s)'):format(tostring(reason)))
        return 0
    end
    amount = math.min(amount, room)
    local old = xpOf(player)
    local new = math.min(LVL.TOTAL, old + amount)
    amount = new - old
    if amount <= 0 then return 0 end
    recent[src] = recent[src] or {}
    recent[src][#recent[src] + 1] = { now, amount }
    player.Functions.SetMetaData('xp', new)
    local before, after = LVL.info(old), publish(src, player)
    local up = after.level > before.level
    local card = {
        gained = amount, reason = type(reason) == 'string' and reason:sub(1, 60) or nil,
        level = after.level, cur = after.cur, need = after.need, pct = after.pct, max = after.max,
        fromPct = up and 0 or before.pct, up = up, oldLevel = before.level,
    }
    if up then
        card.unlocks = unlocksBetween(before.level, after.level)
        lib.logger(src, 'level', ('level %d -> %d'):format(before.level, after.level))
    end
    TriggerClientEvent('exti_level:client:gain', src, card)
    return amount
end

exports('AddXP', addXP)

-- the level of an online player (source) or anyone (citizenid)
local function getLevel(who)
    if type(who) == 'number' then
        local p = getPlayer(who)
        return p and LVL.levelOf(xpOf(p)) or 1
    end
    if type(who) == 'string' then
        local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(who) end)
        if ok and p then return LVL.levelOf(xpOf(p)) end
        local row = MySQL.scalar.await('SELECT `metadata` FROM `players` WHERE `citizenid` = ?', { who })
        local okD, meta = pcall(json.decode, row or '')
        return LVL.levelOf(okD and type(meta) == 'table' and meta.xp or 0)
    end
    return 1
end
exports('GetLevel', getLevel)

exports('Info', function(src)
    local p = getPlayer(src)
    return p and LVL.info(xpOf(p)) or nil
end)

-- the phone, the radial menu and the job centre ask this
local function status(source)
    local player = getPlayer(source)
    if not player then return nil end
    local info = publish(source, player)
    info.nextUnlock = nextUnlock(info.level)
    info.hourLeft = math.max(0, Config.maxPerHour - lastHour(source))
    info.maxLevel = Config.maxLevel
    return info
end
lib.callback.register('exti_level:server:info', status)
exports('Status', status)

-- logging in: the level rides on the player (the job centre, the radial menu, the HUD read it)
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if player and player.PlayerData then publish(player.PlayerData.source, player) end
end)
CreateThread(function()
    Wait(1000)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local p = getPlayer(src)
        if p then publish(src, p) end
    end
end)

---------------------------------------------------------------------------
-- admins (testing): /setlevel [id] [level]   /addxp [id] [amount]
---------------------------------------------------------------------------
lib.addCommand('setlevel', {
    help = 'Level: set a player\'s level (admin)',
    params = { { name = 'id', type = 'playerId', help = 'player id' }, { name = 'level', type = 'number', help = '1-300' } },
    restricted = 'group.admin',
}, function(source, args)
    local p = getPlayer(args.id)
    if not p then return end
    local level = math.max(1, math.min(Config.maxLevel, math.floor(args.level)))
    p.Functions.SetMetaData('xp', LVL.xpFor(level))
    local info = publish(args.id, p)
    TriggerClientEvent('exti_level:client:gain', args.id, { gained = 0, level = info.level, cur = info.cur, need = info.need, pct = info.pct, max = info.max, fromPct = 0, reason = 'تعديل إداري' })
    TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = ('المستوى الآن %d'):format(info.level) })
    lib.logger(source, 'level', ('set %s to level %d'):format(p.PlayerData.citizenid, level))
end)

lib.addCommand('addxp', {
    help = 'Level: give XP to a player (admin, ignores the limits)',
    params = { { name = 'id', type = 'playerId', help = 'player id' }, { name = 'amount', type = 'number', help = 'XP' } },
    restricted = 'group.admin',
}, function(source, args)
    local p = getPlayer(args.id)
    if not p then return end
    local old = xpOf(p)
    local new = math.max(0, math.min(LVL.TOTAL, old + math.floor(args.amount)))
    p.Functions.SetMetaData('xp', new)
    local before, info = LVL.info(old), publish(args.id, p)
    TriggerClientEvent('exti_level:client:gain', args.id, { gained = new - old, level = info.level, cur = info.cur, need = info.need, pct = info.pct,
        max = info.max, fromPct = info.level > before.level and 0 or before.pct, up = info.level > before.level, oldLevel = before.level,
        unlocks = info.level > before.level and unlocksBetween(before.level, info.level) or nil, reason = 'تعديل إداري' })
    lib.logger(source, 'level', ('gave %s %d xp'):format(p.PlayerData.citizenid, new - old))
end)
