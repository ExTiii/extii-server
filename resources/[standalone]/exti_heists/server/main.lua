-- =====================================================================
-- EX_Tii heists (server core). The server decides everything: the game only says "I pressed E here"
-- or "I finished this minigame". Rep and skills, heat, cooldowns, the cop counter and the two modes,
-- minigame tokens (no instant results), the combat-log rule, logs (database + Discord).
-- =====================================================================
H = {}
local C = Config

local function now() return os.time() end
H.now = now

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
function H.player(src) return exports.qbx_core:GetPlayer(src) end
local cidOf = {}   -- [src] = citizenid (still known in playerDropped, after qbx_core forgot him)
function H.cid(src)
    local p = H.player(src)
    local cid = p and p.PlayerData.citizenid
    if cid then cidOf[src] = cid end
    return cid or cidOf[src]
end
function H.name(src)
    local p = H.player(src); local ci = p and p.PlayerData.charinfo
    return ci and ((ci.firstname or '') .. ' ' .. (ci.lastname or '')) or GetPlayerName(src) or '?'
end
function H.notify(src, text, kind, duration)
    TriggerClientEvent('ox_lib:notify', src, { description = text, type = kind or 'inform', position = 'top', duration = duration or 5000 })
end
function H.coords(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end
function H.near(src, pos, dist)
    local here = H.coords(src)
    return here ~= nil and pos ~= nil and #(here - vec3(pos.x, pos.y, pos.z)) <= (dist or 3.0)
end
function H.isCopOnDuty(src)
    local p = H.player(src); local j = p and p.PlayerData.job
    return j and j.name == C.cops.job and j.onduty == true or false
end
local function rand(range) return math.random(range[1], range[2]) end
H.rand = rand

---------------------------------------------------------------------------
-- database
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_heist_rep` (
        `citizenid` VARCHAR(64) NOT NULL PRIMARY KEY,
        `xp` INT NOT NULL DEFAULT 0,
        `lockpick` INT NOT NULL DEFAULT 0, `hacking` INT NOT NULL DEFAULT 0, `breaching` INT NOT NULL DEFAULT 0,
        `heat_until` INT NOT NULL DEFAULT 0,
        `loot` LONGTEXT NULL,
        `dropped_at` INT NOT NULL DEFAULT 0
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_heist_cooldowns` (
        `k` VARCHAR(96) NOT NULL PRIMARY KEY, `until` INT NOT NULL
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `exti_heist_logs` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `at` INT NOT NULL, `actor` VARCHAR(96), `action` VARCHAR(64), `details` TEXT
    )]])
    local rows = MySQL.query.await('SELECT `k`, `until` FROM `exti_heist_cooldowns` WHERE `until` > ?', { now() }) or {}
    for _, r in ipairs(rows) do H.cooldowns[r.k] = r['until'] end
    H.ready = true
end)

---------------------------------------------------------------------------
-- logs
---------------------------------------------------------------------------
local webhook = GetConvar(C.webhookConvar, '')
function H.log(actor, action, details)
    actor = type(actor) == 'number' and ('%s (%s)'):format(H.name(actor), H.cid(actor) or '?') or tostring(actor or '-')
    MySQL.insert('INSERT INTO `exti_heist_logs` (`at`, `actor`, `action`, `details`) VALUES (?, ?, ?, ?)', { now(), actor, action, details or '' })
    lib.logger(-1, 'heists', ('%s: %s %s'):format(actor, action, details or ''))
    if webhook ~= '' then
        PerformHttpRequest(webhook, function() end, 'POST', json.encode({
            username = 'EX_Tii Heists',
            embeds = { { title = action, description = ('**%s**\n%s'):format(actor, details or ''), color = 14830413, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

---------------------------------------------------------------------------
-- cooldowns (kept in the database: a restart resets nothing)
---------------------------------------------------------------------------
H.cooldowns = {}
function H.cooldownLeft(key)
    local t = H.cooldowns[key]
    if not t then return 0 end
    local left = t - now()
    if left <= 0 then H.cooldowns[key] = nil; return 0 end
    return left
end
function H.setCooldown(key, seconds)
    local t = now() + math.floor(seconds)
    H.cooldowns[key] = t
    MySQL.prepare('INSERT INTO `exti_heist_cooldowns` (`k`, `until`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `until` = VALUES(`until`)', { key, t })
end
function H.clearCooldown(key)
    H.cooldowns[key] = nil
    MySQL.prepare('DELETE FROM `exti_heist_cooldowns` WHERE `k` = ?', { key })
end
function H.clearAllCooldowns()
    H.cooldowns = {}
    MySQL.query('DELETE FROM `exti_heist_cooldowns`')
end
function H.mmss(s) s = math.max(0, math.floor(s)); return ('%d:%02d'):format(s // 60, s % 60) end

---------------------------------------------------------------------------
-- criminal Rep, skills, heat (per character)
---------------------------------------------------------------------------
local recs = {}   -- [citizenid] = { xp, lockpick, hacking, breaching, heat_until, loot = {}, dropped_at }
local loadingCid = {}
local function load(cid)
    if recs[cid] then return recs[cid] end
    while loadingCid[cid] do Wait(50) end
    if recs[cid] then return recs[cid] end
    loadingCid[cid] = true
    local r = MySQL.single.await('SELECT * FROM `exti_heist_rep` WHERE `citizenid` = ?', { cid })
    if not r then
        r = { xp = 0, lockpick = 0, hacking = 0, breaching = 0, heat_until = 0, dropped_at = 0 }
        MySQL.insert.await('INSERT IGNORE INTO `exti_heist_rep` (`citizenid`) VALUES (?)', { cid })
    end
    local ok, loot = pcall(json.decode, r.loot or '')
    r.loot = ok and type(loot) == 'table' and loot or {}
    recs[cid] = r
    loadingCid[cid] = nil
    return r
end
local function save(cid)
    local r = recs[cid]; if not r then return end
    MySQL.prepare('UPDATE `exti_heist_rep` SET `xp` = ?, `lockpick` = ?, `hacking` = ?, `breaching` = ?, `heat_until` = ?, `loot` = ?, `dropped_at` = ? WHERE `citizenid` = ?',
        { r.xp, r.lockpick, r.hacking, r.breaching, r.heat_until, json.encode(r.loot), r.dropped_at, cid })
end
function H.rec(src) local cid = H.cid(src); return cid and load(cid), cid end

function H.levelOf(xp)
    local lv = 1
    for i, need in ipairs(C.rep.levels) do if xp >= need then lv = i end end
    return lv
end
function H.skillLevel(r, skill)
    local s = C.skills[skill]; if not s or not r then return 1 end
    local lv = 1
    for i, need in ipairs(s.xp) do if (r[skill] or 0) >= need then lv = i end end
    return lv
end
function H.repLevel(src) local r = H.rec(src); return r and H.levelOf(r.xp) or 1 end

function H.addXP(src, n, why)
    local r, cid = H.rec(src); if not r or n == 0 then return end
    local before = H.levelOf(r.xp)
    r.xp = math.max(0, r.xp + math.floor(n))
    save(cid)
    local after = H.levelOf(r.xp)
    if n > 0 then H.notify(src, ('سمعة إجرامية +%d'):format(n), 'success', 3500)
    else H.notify(src, ('سمعة إجرامية %d'):format(n), 'error', 3500) end
    if after ~= before then
        H.notify(src, after > before and ('وصلت إلى مستوى السمعة %d'):format(after) or ('نزلت إلى مستوى السمعة %d'):format(after), after > before and 'success' or 'error', 7000)
    end
    H.log(src, 'rep', ('%+d (%s) -> %d XP, level %d'):format(n, why or '', r.xp, after))
end
function H.addSkill(src, skill, n)
    local r, cid = H.rec(src); if not r or not C.skills[skill] then return end
    local before = H.skillLevel(r, skill)
    r[skill] = (r[skill] or 0) + (n or C.skills.gain)
    save(cid)
    local after = H.skillLevel(r, skill)
    if after > before then H.notify(src, ('مهارة %s: المستوى %d'):format(C.skills[skill].label, after), 'success', 6000) end
end
-- minigame time multiplier from a skill (level 1 = 1.0, level 5 = 1.4)
function H.skillTime(src, skill)
    local r = H.rec(src)
    return 1.0 + (H.skillLevel(r, skill) - 1) * C.skills.timeBonus
end

function H.setHeat(src)
    local r, cid = H.rec(src); if not r then return end
    r.heat_until = now() + C.heatMinutes * 60
    save(cid)
end
function H.isHot(src) local r = H.rec(src); return r and r.heat_until > now() or false end

-- loot given while hot (deleted if he logs out with heat and does not come back in time)
function H.giveLoot(src, item, count, metadata)
    count = math.floor(count or 1)
    if count < 1 then return false end
    if not exports.ox_inventory:CanCarryItem(src, item, count) then
        -- the rest drops at his feet: a robbery is never lost to a full bag
        local here = H.coords(src)
        if here then exports.ox_inventory:CustomDrop('غنيمة', { { item, count, metadata } }, here) end
        H.notify(src, 'حقيبتك ممتلئة: سقط الباقي عند قدميك', 'warning', 6000)
    else
        exports.ox_inventory:AddItem(src, item, count, metadata)
    end
    local r, cid = H.rec(src)
    if r then r.loot[item] = (r.loot[item] or 0) + count; save(cid) end
    return true
end

-- mode multipliers for a share of loot
function H.payOf(range, mode) return math.floor(rand(range) * (mode and mode.pay or 1.0)) end

---------------------------------------------------------------------------
-- the cop counter: on duty 10+ min and moved in the last 5 min
---------------------------------------------------------------------------
local cops = {}   -- [src] = { since, pos, moved }
CreateThread(function()
    while true do
        local t = now()
        local seen = {}
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            if src and H.isCopOnDuty(src) then
                seen[src] = true
                local here = H.coords(src)
                local c = cops[src]
                if not c then c = { since = t, pos = here, moved = t }; cops[src] = c end
                if here and c.pos and #(here - c.pos) > 3.0 then c.moved = t end
                c.pos = here or c.pos
            end
        end
        for src in pairs(cops) do if not seen[src] then cops[src] = nil end end
        Wait(C.cops.sampleSeconds * 1000)
    end
end)
AddEventHandler('playerDropped', function() cops[source] = nil end)

function H.copsCounted()
    local t, n = now(), 0
    for src, c in pairs(cops) do
        if H.isCopOnDuty(src) and t - c.since >= C.cops.dutyMinutes * 60 and t - c.moved <= C.cops.movedMinutes * 60 then n = n + 1 end
    end
    return n
end
function H.copsNeeded(tier)
    local r = C.copsNeeded[tier] or C.copsNeeded[10]
    local need = math.ceil(#GetPlayers() * r.share)
    return math.max(r.floor, math.min(r.cap, need))
end
-- which mode a robbery of this tier runs in right now (nil = it cannot run)
H.force = nil   -- admins (F1): 'police' | 'npc' | nil (normal)
function H.modeFor(tier)
    local counted, need = H.copsCounted(), H.copsNeeded(tier)
    if H.force == 'police' then counted = math.max(counted, need) end
    if H.force == 'npc' then counted = 0 end
    if counted >= need then
        local bonus = math.min(C.mode.bonusMax, (counted - need) * C.mode.bonusPerCop)
        return { police = true, pay = 1.0 + bonus, usb = 1.0, rep = 1.0, counted = counted, need = need }
    end
    if tier > C.noPoliceMaxTier then return nil, need, counted end
    return { police = false, pay = C.mode.noPolicePay, usb = C.mode.noPoliceUsb, rep = C.mode.noPoliceRep, counted = counted, need = need }
end
function H.modeText(m) return m.police and ('وضع الشرطة (%d شرطي)'):format(m.counted) or 'بلا شرطة: حراسة الحي' end

function H.repFor(src, tier, mode)
    local base = C.rep.xp[tier] or 0
    H.addXP(src, math.max(1, math.floor(base * (mode and mode.rep or 1.0))), ('tier %d %s'):format(tier, mode and (mode.police and 'police' or 'npc') or ''))
end
function H.canTier(src, tier, isLeader)
    local need = math.ceil(tier * (isLeader == false and C.rep.memberNeeds or C.rep.leaderNeeds))
    return H.repLevel(src) >= need, need
end

---------------------------------------------------------------------------
-- minigame tokens: the game starts on the server and must take a human amount of time
---------------------------------------------------------------------------
local tokens = {}   -- [src] = { id, kind, at, ctx }
function H.gameBegin(src, kind, ctx)
    local id = ('%d-%d'):format(math.random(100000, 999999), GetGameTimer())
    tokens[src] = { id = id, kind = kind, at = GetGameTimer(), ctx = ctx }
    return id
end
-- returns the ctx when the result is fair
function H.gameEnd(src, kind, id, passed)
    local t = tokens[src]; tokens[src] = nil
    if not t or t.id ~= id or t.kind ~= kind then return nil, 'token' end
    local took = (GetGameTimer() - t.at) / 1000
    if took > (C.games.maxSeconds or 240) then return nil, 'old' end   -- (a token kept for later is worthless)
    local min = (C.games[kind] and C.games[kind].minSeconds) or 2.0
    if passed and took < min then
        H.log(src, 'flag_fast_game', ('%s in %.2fs'):format(kind, took))
        return nil, 'fast'
    end
    return t.ctx, nil, took
end
AddEventHandler('playerDropped', function() tokens[source] = nil end)

---------------------------------------------------------------------------
-- the combat-log rule
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    local cid = H.cid(src); cidOf[src] = nil
    if not cid then return end
    local r = recs[cid]
    if r and r.heat_until > now() and next(r.loot) then
        r.dropped_at = now(); save(cid)
        H.log(('%s (%s)'):format(GetPlayerName(src) or '?', cid), 'drop_with_heat', json.encode(r.loot))
    end
end)
local loading = {}
local function onLoaded(src)
    if loading[src] then return end
    loading[src] = true
    SetTimeout(5000, function() loading[src] = nil end)
    local r, cid = H.rec(src); if not r then return end
    if r.dropped_at > 0 then
        local away = now() - r.dropped_at
        if away > C.combatLog.graceSeconds and r.heat_until > r.dropped_at then
            local gone = {}
            for item, n in pairs(r.loot) do
                local have = exports.ox_inventory:Search(src, 'count', item) or 0
                local take = math.min(have, n)
                if take > 0 then exports.ox_inventory:RemoveItem(src, item, take); gone[#gone + 1] = ('%dx %s'):format(take, item) end
            end
            r.loot = {}
            H.notify(src, 'خرجت والشرطة تلاحقك: ضاعت الغنيمة', 'error', 9000)
            H.addXP(src, C.combatLog.xp, 'logged out with heat')
            H.log(src, 'combat_log_penalty', table.concat(gone, ', '))
        end
        r.dropped_at = 0; save(cid)
    end
    if H.houseOnLoaded then H.houseOnLoaded(src) end
end
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() onLoaded(source) end)
AddEventHandler('QBCore:Server:PlayerLoaded', function(p) if p and p.PlayerData then onLoaded(p.PlayerData.source) end end)
-- heat over: what he carries is his to keep
CreateThread(function()
    while true do
        Wait(60000)
        local t = now()
        for cid, r in pairs(recs) do
            if r.heat_until <= t and next(r.loot) and r.dropped_at == 0 then r.loot = {}; save(cid) end
        end
    end
end)

-- arrested by the police
AddEventHandler('exti_police:server:jailed', function(src) if H.cid(src) then H.addXP(src, C.rep.arrest, 'arrested') end end)

---------------------------------------------------------------------------
-- what the phone app / F1 read
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:me', function(src)
    local r = H.rec(src); if not r then return nil end
    local lv = H.levelOf(r.xp)
    return {
        xp = r.xp, level = lv, nextXp = C.rep.levels[lv + 1],
        skills = { lockpick = H.skillLevel(r, 'lockpick'), hacking = H.skillLevel(r, 'hacking'), breaching = H.skillLevel(r, 'breaching') },
        heat = math.max(0, r.heat_until - now()),
    }
end)

exports('RepLevel', function(src) return H.repLevel(src) end)
exports('AddXP', function(src, n, why) H.addXP(src, n, why) end)
exports('CopsCounted', function() return H.copsCounted() end)

-- admins (F1 → Heists): set rep / skills / heat, clear cooldowns
function H.adminSet(src, field, value)
    local r, cid = H.rec(src); if not r then return false end
    if field == 'xp' then r.xp = math.max(0, math.floor(tonumber(value) or 0))
    elseif field == 'level' then r.xp = C.rep.levels[math.max(1, math.min(10, math.floor(tonumber(value) or 1)))]
    elseif C.skills[field] then r[field] = C.skills[field].xp[math.max(1, math.min(5, math.floor(tonumber(value) or 1)))]
    elseif field == 'heat' then r.heat_until = 0; r.loot = {}
    else return false end
    save(cid)
    return true
end

-- F1 → التجربة → السطو (exti_admin checks the admin's rights first)
exports('AdminInfo', function(src)
    local r = H.rec(src); if not r then return nil end
    return {
        xp = r.xp, level = H.levelOf(r.xp),
        lockpick = H.skillLevel(r, 'lockpick'), hacking = H.skillLevel(r, 'hacking'), breaching = H.skillLevel(r, 'breaching'),
        heat = math.max(0, r.heat_until - now()), force = H.force or 'auto',
        cops = H.copsCounted(), need1 = H.copsNeeded(1), need4 = H.copsNeeded(4), need7 = H.copsNeeded(7),
    }
end)
exports('Admin', function(src, what, value)
    if what == 'level' or what == 'heat' or C.skills[what] then
        if not H.adminSet(src, what, value) then return false end
        return true, 'تم'
    elseif what == 'cooldowns' then
        H.clearAllCooldowns()
        if H.resetStores then H.resetStores() end
        return true, 'صُفّرت كل أوقات انتظار السطو'
    elseif what == 'force' then
        H.force = (value == 'police' or value == 'npc') and value or nil
        H.log(src, 'admin_force_mode', tostring(H.force))
        return true, ({ police = 'كل سطو الآن بوضع الشرطة', npc = 'كل سطو الآن بلا شرطة (حراسة الحي)' })[H.force] or 'رجع الوضع طبيعيًا (حسب الشرطة)'
    elseif what == 'house' then
        local size = ({ small = 'small', medium = 'medium', mansion = 'mansion' })[value] or 'small'
        if not H.adminHouseLead or not H.adminHouseLead(src, size) then return false, 'لا بيت فاضٍ من هذا الحجم' end
        return true, 'وصلك بيت (تجربة: يعمل في أي وقت)'
    elseif what == 'kit' then
        for _, it in ipairs({ { 'lockpick', 5 }, { 'usb_green', 1 }, { 'drill', 1 }, { 'drill_bit', 3 }, { 'zip_ties', 3 }, { 'tow_chain', 1 } }) do
            if exports.ox_inventory:Items(it[1]) then exports.ox_inventory:AddItem(src, it[1], it[2]) end
        end
        return true, 'أخذت عُدّة السطو'
    end
    return false
end)
