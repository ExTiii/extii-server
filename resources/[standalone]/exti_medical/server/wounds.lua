-- =====================================================================
-- EX_Tii medical (server): the injury records.
-- One list per character, saved in its own table, kept until a medic / the hospital treats it.
-- A wound: { id, k = kind, p = body spot, n = how many, b = bleeding 0-3, s = 1-3 how bad,
--            r = bullets/pieces still inside, cm, deg (burn), lung ('L'/'R'), conc (head knock),
--            vest (the vest stopped it), pw (bullet size 1-3), w = what did it, t = when }
-- =====================================================================

Med = Med or {}

local lists = {}     -- [citizenid] = { wounds } (only for characters that finished loading)
local metas = {}     -- [citizenid] = { treatment state: infusions, painkiller, pulse back, oxygen, CPR }
local cidOfSrc = {}  -- [source] = citizenid of the character that is loaded
local dirty = {}     -- [citizenid] = true -> save soon
local hitLog = {}    -- [source] = { count, since } (anti-spam)
local AIR_MINUTES = 20

-- test patients (NPCs an admin spawns with /fakepatient, see server/fake.lua): they use
-- negative ids instead of a player id, live only in memory and are never saved
local fakes = {}     -- [negative id] = { cid, name, female, age, blood, death, hp, list, ... }
Med.fakes = fakes

local function fakeOf(src)
    if type(src) == 'number' and src < 0 then return fakes[src] end
end
Med.fakeOf = fakeOf

local function getPlayer(src)
    if type(src) ~= 'number' or src <= 0 then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end
Med.getPlayer = getPlayer

local function cidOf(src)
    local f = fakeOf(src)
    if f then return f.cid end
    local player = getPlayer(src)
    return player and player.PlayerData.citizenid or nil
end
Med.cidOf = cidOf

-- smoke / water in the lungs goes away by itself after a while
local function fresh(list)
    local now, out, changed = os.time(), {}, false
    for i = 1, #list do
        local w = list[i]
        if (w.k == 'smoke' or w.k == 'drown') and now - (w.t or now) > AIR_MINUTES * 60 then
            changed = true
        else
            out[#out + 1] = w
        end
    end
    return out, changed
end

local function setCount(src, list)
    if type(src) == 'number' and src > 0 then Player(src).state:set('exti_wounds', #list, true) end
end

--- the wound list of a player (in memory; empty if none)
function Med.list(src)
    local f = fakeOf(src)
    if f then return f.list end
    if type(src) == 'number' and src < 0 then return {} end
    local cid = cidOf(src)
    if not cid or not lists[cid] then return {} end
    local list = lists[cid]
    local cleaned, changed = fresh(list)
    if changed then
        lists[cid] = cleaned
        dirty[cid] = true
        setCount(src, cleaned)
    end
    return lists[cid]
end

local function changed(src, cid)
    dirty[cid] = true
    setCount(src, lists[cid] or {})
    TriggerEvent('exti_medical:server:woundsChanged', src)
end

-- ---------------------------------------------------------------------
-- saving
-- ---------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `exti_medical_wounds` (
            `citizenid` VARCHAR(50) NOT NULL,
            `wounds` LONGTEXT NULL,
            `updated` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        )
    ]])
end)

local function save(cid)
    dirty[cid] = nil
    local list = lists[cid]
    local meta = metas[cid]
    if (not list or #list == 0) and not next(meta or {}) then
        MySQL.prepare('DELETE FROM `exti_medical_wounds` WHERE `citizenid` = ?', { cid })
    else
        -- old rows are a plain list; with treatment state it is { w = list, m = state }
        local data = next(meta or {}) and { w = list or {}, m = meta } or (list or {})
        MySQL.prepare('INSERT INTO `exti_medical_wounds` (`citizenid`, `wounds`, `updated`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `wounds` = VALUES(`wounds`), `updated` = VALUES(`updated`)',
            { cid, json.encode(data), os.time() })
    end
end

CreateThread(function()
    while true do
        Wait(5000)
        for cid in pairs(dirty) do save(cid) end
    end
end)

local function load(src, cid)
    if not cid then return end
    cidOfSrc[src] = cid
    if lists[cid] then setCount(src, Med.list(src)) return end
    local row = MySQL.single.await('SELECT `wounds` FROM `exti_medical_wounds` WHERE `citizenid` = ?', { cid })
    if cidOfSrc[src] ~= cid then return end -- left / switched character while loading
    local list, meta = {}, nil
    if row and row.wounds then
        local ok, decoded = pcall(json.decode, row.wounds)
        if ok and type(decoded) == 'table' then
            if type(decoded.w) == 'table' then
                list = decoded.w
                meta = type(decoded.m) == 'table' and decoded.m or nil
            else
                list = decoded
            end
        end
    end
    lists[cid] = lists[cid] or list
    if meta and not metas[cid] then metas[cid] = meta end
    setCount(src, Med.list(src))
end

-- make sure a character's list is loaded (used by admin commands / other scripts)
local function ensure(src)
    local cid = cidOf(src)
    if cid and not lists[cid] then load(src, cid) end
    return cid
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if src then load(src, player.PlayerData.citizenid) end
end)

local function unload(src)
    local cid = cidOfSrc[src] or cidOf(src)
    cidOfSrc[src] = nil
    if cid then
        if dirty[cid] then save(cid) end
        lists[cid] = nil
        metas[cid] = nil
    end
    hitLog[src] = nil
end

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) unload(src) end)
AddEventHandler('playerDropped', function() unload(source) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetTimeout(1500, function()
        local ok, players = pcall(function() return exports.qbx_core:GetQBPlayers() end)
        if not ok or type(players) ~= 'table' then return end
        for src, player in pairs(players) do
            load(tonumber(src) or player.PlayerData.source, player.PlayerData.citizenid)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for cid in pairs(dirty) do save(cid) end
end)

-- ---------------------------------------------------------------------
-- making wounds out of hits
-- ---------------------------------------------------------------------
local LIMB_ARMS = { 'LARM', 'RARM', 'LHAND', 'RHAND' }
local LIMB_LEGS = { 'LLEG', 'RLEG', 'LFOOT', 'RFOOT' }
local ANY = { 'HEAD', 'UPPER_BODY', 'LOWER_BODY', 'LARM', 'RARM', 'LLEG', 'RLEG', 'SPINE' }

local function pick(t) return t[math.random(#t)] end
local function chance(p) return math.random() < p end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function nextId(list)
    local id = 0
    for i = 1, #list do if (list[i].id or 0) > id then id = list[i].id end end
    return id + 1
end

-- adds a wound, or makes the same wound on the same spot worse
-- t0 = when it started (bleeding is counted from then), t = the last hit
local function put(list, w)
    w.t = os.time()
    w.t0 = w.t0 or w.t
    w.n = w.n or 1
    for i = 1, #list do
        local o = list[i]
        if o.p == w.p and o.k == w.k and not o.dr and not (o.k == 'bruise' and (o.vest ~= w.vest)) then
            o.t0 = o.t0 or o.t or w.t
            o.n = (o.n or 1) + (w.n or 1)
            -- a new hit makes the bleeding worse, but many hits in the same moment (a shotgun) count once
            local again = (w.b or 0) > 0 and (o.b or 0) > 0 and (w.t - (o.t or 0)) >= 5
            o.b = clamp(math.max(o.b or 0, w.b or 0) + (again and 1 or 0), 0, 3)
            o.s = math.max(o.s or 1, w.s or 1)
            o.r = math.min((o.r or 0) + (w.r or 0), (o.k == 'gunshot' and 6) or 12)
            if w.cm then o.cm = math.max(o.cm or 0, w.cm) end
            if w.deg then o.deg = math.max(o.deg or 0, w.deg) end
            if w.lung then o.lung = o.lung or w.lung end
            if w.conc then o.conc = true end
            if w.pw then o.pw = math.max(o.pw or 1, w.pw) end
            o.t = w.t
            return o
        end
    end
    if #list >= Config.maxWounds then table.remove(list, 1) end
    w.id = nextId(list)
    list[#list + 1] = w
    return w
end

local function isLimb(part) return Config.limbs[part] == true end
local function isTorso(part) return part == 'UPPER_BODY' or part == 'LOWER_BODY' or part == 'NECK' or part == 'SPINE' end

local rules = {}

rules.bullet = function(list, part, dmg, pw, label, armor)
    part = part or 'UPPER_BODY'
    if armor and armor > 0 and dmg < 5 and (part == 'UPPER_BODY' or part == 'LOWER_BODY' or part == 'SPINE') then
        put(list, { k = 'bruise', p = part, s = 2, b = 0, vest = true, w = label })
        return
    end
    local retained = chance(({ 0.65, 0.5, 0.3 })[pw])
    local bleed = (isLimb(part) and 1 or 2) + ((dmg >= 35 or pw == 3) and 1 or 0)
    if part == 'HEAD' then bleed = 3 end
    bleed = clamp(bleed, 1, 3)
    local w = { k = 'gunshot', p = part, r = retained and 1 or 0, b = bleed, s = bleed >= 3 and 3 or 2, pw = pw, w = label }
    if part == 'UPPER_BODY' and chance(({ 0.4, 0.55, 0.8 })[pw]) then w.lung = chance(0.5) and 'L' or 'R' end
    put(list, w)
    if isLimb(part) and chance(({ 0.12, 0.2, 0.35 })[pw]) then
        put(list, { k = 'fracture', p = part, s = 3, b = 0, w = label })
    end
end

rules.pellet = function(list, part, dmg, pw, label)
    part = part or 'UPPER_BODY'
    put(list, { k = 'pellets', p = part, r = math.random(1, 3), b = isTorso(part) and 2 or 1, s = 2, w = label })
end

rules.blade = function(list, part, dmg, pw, label)
    part = part or pick({ 'UPPER_BODY', 'LOWER_BODY', 'LARM', 'RARM' })
    local stab = (pw == 1 and label ~= 'زجاجة مكسورة') and chance(0.65) or chance(0.2)
    if stab then
        local w = { k = 'stab', p = part, b = clamp((isLimb(part) and 1 or 2) + (dmg >= 30 and 1 or 0), 1, 3), s = isLimb(part) and 2 or 3, w = label }
        if part == 'UPPER_BODY' and chance(0.35) then w.lung = chance(0.5) and 'L' or 'R' end
        put(list, w)
    else
        local cm = pw >= 2 and math.random(6, 18) or math.random(3, 12)
        put(list, { k = 'laceration', p = part, cm = cm, b = cm >= 10 and 2 or 1, s = cm >= 12 and 3 or 2, w = label })
    end
end

rules.blunt = function(list, part, dmg, pw, label)
    part = part or pick(ANY)
    local w = { k = 'bruise', p = part, s = (pw >= 2 or dmg >= 15) and 2 or 1, b = 0, w = label }
    if part == 'HEAD' and ((pw >= 2 and chance(0.5)) or (dmg >= 25 and chance(0.25))) then w.conc = true end
    put(list, w)
    if pw >= 2 and dmg >= 20 then
        if isLimb(part) and chance(0.3) then put(list, { k = 'fracture', p = part, s = 3, b = 0, w = label })
        elseif part == 'UPPER_BODY' and chance(0.25) then put(list, { k = 'fracture', p = part, s = 3, b = 0, w = label }) end
    end
end

rules.vehicle = function(list, part, dmg, pw, label)
    part = part or pick(ANY)
    put(list, { k = 'bruise', p = part, s = 2, b = 0, w = label })
    put(list, { k = 'abrasion', p = pick({ 'LARM', 'RARM', 'LLEG', 'RLEG' }), s = 1, b = 0, w = label })
    if chance(0.4) then put(list, { k = 'fracture', p = pick({ 'LLEG', 'RLEG' }), s = 3, b = 0, w = label }) end
    if dmg >= 30 and chance(0.3) then put(list, { k = 'bruise', p = 'HEAD', s = 2, b = 0, conc = true, w = label }) end
end

rules.crash = function(list, part, dmg, pw, label)
    put(list, { k = 'bruise', p = 'UPPER_BODY', s = dmg >= 25 and 2 or 1, b = 0, w = label })
    if dmg >= 25 and chance(0.35) then put(list, { k = 'bruise', p = 'HEAD', s = 2, b = 0, conc = true, w = label }) end
    if dmg >= 40 and chance(0.2) then put(list, { k = 'fracture', p = pick({ 'UPPER_BODY', 'LARM', 'RARM' }), s = 3, b = 0, w = label }) end
    if chance(0.25) then put(list, { k = 'laceration', p = pick({ 'HEAD', 'LARM', 'RARM' }), cm = math.random(2, 6), b = 1, s = 2, w = 'زجاج' }) end
end

rules.fall = function(list, part, dmg, pw, label)
    if dmg >= 40 then
        if chance(0.7) then put(list, { k = 'fracture', p = pick(LIMB_LEGS), s = 3, b = 0, w = label })
        else put(list, { k = 'bruise', p = pick(LIMB_LEGS), s = 2, b = 0, w = label }) end
        if dmg >= 80 then
            if chance(0.15) then put(list, { k = 'fracture', p = 'SPINE', s = 3, b = 0, w = label }) end
            if chance(0.3) then put(list, { k = 'bruise', p = 'HEAD', s = 2, b = 0, conc = true, w = label }) end
        end
    elseif dmg >= 15 then
        if chance(0.6) then put(list, { k = 'sprain', p = pick({ 'LFOOT', 'RFOOT' }), s = 2, b = 0, w = label })
        else put(list, { k = 'bruise', p = pick(LIMB_LEGS), s = 1, b = 0, w = label }) end
    else
        put(list, { k = 'abrasion', p = pick({ 'LHAND', 'RHAND', 'LLEG', 'RLEG' }), s = 1, b = 0, w = label })
    end
end

rules.explosion = function(list, part, dmg, pw, label)
    local deg = clamp(pw + (dmg >= 50 and 1 or 0) - 1, 1, 3)
    for _ = 1, math.random(2, 3) do
        put(list, { k = 'burn', p = pick(ANY), deg = deg, s = deg, b = 0, w = label })
    end
    for _ = 1, math.random(1, 2) do
        put(list, { k = 'shrapnel', p = pick(ANY), r = math.random(1, 4), b = math.random(1, 2), s = 2, w = label })
    end
    if chance(0.4) then put(list, { k = 'bruise', p = 'HEAD', s = 2, b = 0, conc = true, w = label }) end
end

rules.fire = function(list, part, dmg, pw, label)
    local deg = clamp((dmg < 15 and 1 or dmg < 40 and 2 or 3) + (pw >= 2 and 1 or 0), 1, 3)
    for _ = 1, math.random(1, 3) do
        put(list, { k = 'burn', p = part and chance(0.5) and part or pick({ 'LARM', 'RARM', 'LLEG', 'RLEG', 'UPPER_BODY', 'LHAND', 'RHAND' }), deg = deg, s = deg, b = 0, w = label })
    end
end

rules.bite = function(list, part, dmg, pw, label)
    put(list, { k = 'bite', p = part or pick({ 'LLEG', 'RLEG', 'LARM', 'RARM' }), b = pw >= 2 and 2 or 1, s = 2, w = label })
end

rules.wire = function(list, part, dmg, pw, label)
    put(list, { k = 'laceration', p = part or pick({ 'LLEG', 'RLEG', 'LARM', 'RARM' }), cm = math.random(2, 5), b = 1, s = 1, w = label })
end

rules.taser = function(list, part, dmg, pw, label)
    local p = (part == 'UPPER_BODY' or part == 'LOWER_BODY' or part == 'SPINE') and part or 'UPPER_BODY'
    for i = 1, #list do if list[i].k == 'probes' then return end end -- one pair at a time
    put(list, { k = 'probes', p = p, r = 2, s = 1, b = 0, w = label })
end

rules.air = function(list, part, dmg, pw, label)
    put(list, { k = label == 'غرق' and 'drown' or 'smoke', p = 'UPPER_BODY', s = 2, b = 0, w = label })
end

local KINDS = {}
for k in pairs(rules) do KINDS[k] = true end

--- the player's own client reports the hits it just took
RegisterNetEvent('exti_medical:server:hits', function(hits)
    local src = source
    if type(hits) ~= 'table' then return end
    local cid = cidOf(src)
    if not cid or cidOfSrc[src] ~= cid or not lists[cid] then return end -- not loaded yet / logging out
    local log = hitLog[src]
    local now = os.time()
    if not log or now - log.since > 10 then log = { count = 0, since = now } hitLog[src] = log end
    local list = lists[cid]
    local any = false
    for i = 1, math.min(#hits, 12) do
        local h = hits[i]
        if type(h) == 'table' and KINDS[h.k] and log.count < 40 then
            log.count = log.count + 1
            local part = type(h.p) == 'string' and Config.parts[h.p] and h.p or nil
            local dmg = clamp(tonumber(h.d) or 0, 0, 200)
            local pw = clamp(math.floor(tonumber(h.pw) or 1), 1, 3)
            local label = type(h.w) == 'string' and h.w:sub(1, 60) or ''
            local armor = clamp(tonumber(h.a) or 0, 0, 100)
            local ok, err = pcall(rules[h.k], list, part, dmg, pw, label, armor)
            if not ok then print(('^1[exti_medical] hit failed: %s^0'):format(tostring(err))) end
            any = true
        end
    end
    if any then changed(src, cid) end
end)

-- ---------------------------------------------------------------------
-- other scripts / admin
-- ---------------------------------------------------------------------
--- removes every wound (until the treatment part exists, a revive / heal / respawn does this)
function Med.clear(src)
    local f = fakeOf(src)
    if f then
        f.list = {}
        f.meta = {}
        TriggerEvent('exti_medical:server:woundsChanged', src)
        return
    end
    if type(src) ~= 'number' or src <= 0 then return end
    local cid = cidOf(src)
    if not cid then return end
    if lists[cid] and #lists[cid] == 0 and not next(metas[cid] or {}) then return end
    lists[cid] = {}
    metas[cid] = nil
    changed(src, cid) -- saving an empty list deletes the saved one too
end

--- adds a ready wound (tests, other scripts)
function Med.add(src, w)
    local f = fakeOf(src)
    if f then
        put(f.list, w)
        TriggerEvent('exti_medical:server:woundsChanged', src)
        return
    end
    if type(src) ~= 'number' or src <= 0 then return end
    local cid = ensure(src)
    if not cid or not lists[cid] then return end
    put(lists[cid], w)
    changed(src, cid)
end

-- the treatment state belongs to one fall: when he goes down or gets up (any way, also an admin
-- revive) it starts fresh; when he dies again the pulse that CPR brought back is gone
AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    local cid = cidOfSrc[src]
    if not cid or not metas[cid] then return end
    if value == 3 then
        metas[cid].rosc, metas[cid].cpr = nil, nil
    else
        metas[cid] = nil
    end
    dirty[cid] = true
end)

--- the treatment state of a patient (infusions, painkiller, pulse back...); create = make it if missing
function Med.meta(src, create)
    local f = fakeOf(src)
    if f then
        if not f.meta and create then f.meta = {} end
        return f.meta
    end
    if type(src) ~= 'number' or src <= 0 then return nil end
    local cid = cidOf(src)
    if not cid or not lists[cid] then return nil end
    if not metas[cid] and create then metas[cid] = {} end
    return metas[cid]
end

--- a treatment changed the wounds / the state in place: save it and tell everyone
function Med.touch(src)
    if fakeOf(src) then
        TriggerEvent('exti_medical:server:woundsChanged', src)
        return
    end
    local cid = cidOf(src)
    if cid and lists[cid] then changed(src, cid) end
end

--- treatment is finished: the treated wounds go; what still needs the hospital (fractures) stays
function Med.keepForHospital(src)
    local list = Med.list(src)
    local keep = {}
    for i = 1, #list do
        local w = list[i]
        if w.k == 'fracture' or w.k == 'sprain' then keep[#keep + 1] = w end
    end
    local f = fakeOf(src)
    if f then
        f.list, f.meta = keep, {}
    else
        local cid = cidOf(src)
        if not cid or not lists[cid] then return end
        lists[cid] = keep
        metas[cid] = nil
    end
    Med.touch(src)
end

exports('GetWounds', function(src) return Med.list(src) end)
exports('ClearWounds', function(src) Med.clear(src) end)

-- waking up at the hospital clears the injuries (for now). EMS revive / treat and the hospital
-- bed call exports.exti_medical:ClearWounds themselves (on the server, so nobody can fake it).
AddEventHandler('qbx_medical:server:playerRespawned', function(src)
    Med.clear(src)
end)

-- txAdmin "heal" (menu)
AddEventHandler('txAdmin:events:playerHealed', function(data)
    if GetInvokingResource() ~= 'monitor' or type(data) ~= 'table' then return end
    if data.target == -1 then
        for src in pairs(cidOfSrc) do Med.clear(src) end
    elseif type(data.target) == 'number' then
        Med.clear(data.target)
    end
end)
AddEventHandler('txAdmin:events:healedPlayer', function(data)
    if GetInvokingResource() ~= 'monitor' or type(data) ~= 'table' then return end
    if data.id == -1 then
        for src in pairs(cidOfSrc) do Med.clear(src) end
    elseif type(data.id) == 'number' then
        Med.clear(data.id)
    end
end)
