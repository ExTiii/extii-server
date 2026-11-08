-- =====================================================================
-- EX_Tii Police (server): the armory — free gear, each rank its own list (the rest greyed out).
-- An ox_inventory shop that only police can open; on top of that we check here: on duty, at the
-- armory spot, never more than an officer may carry (one of each gun), and a daily limit per
-- officer. Police guns (police serial) never leave the officer: they cannot be dropped, given,
-- put in a stash / trunk / locker or swapped out, and they are taken away when someone stops
-- being police.
-- =====================================================================

local JOB = Config.job
local SHOP = 'exti_police_armory'

local getPlayer, isCop, onDuty, nearSpot, notify = POL.getPlayer, POL.isCop, POL.onDuty, POL.nearSpot, POL.notify

local limits = {}    -- [item name] = how many an officer may carry
local serialGuns = {} -- [item name] = true for the guns that get a police serial
local taken = {}     -- [citizenid] = { day = 'YYYY-MM-DD', [item name] = count taken today }

-- next to the armory of any station
local function atArmory(src)
    for _, st in pairs(Config.stations) do
        if st.armory and nearSpot(src, st.armory, 2.5) then return true end
    end
    return false
end

-- a gun from the police armory (its serial is made by ox_inventory as 123456POL654321)
local function isPoliceGun(slot)
    return type(slot) == 'table' and type(slot.name) == 'string' and slot.name:sub(1, 7) == 'WEAPON_'
        and type(slot.metadata) == 'table' and type(slot.metadata.serial) == 'string' and slot.metadata.serial:match('^%d+POL%d+$') ~= nil
end
POL.isPoliceGun = isPoliceGun

-- how many of this item the officer took today (the day turns at midnight server time)
local function takenToday(cid, item)
    local day = os.date('%Y-%m-%d')
    local t = taken[cid]
    if not t or t.day ~= day then
        t = { day = day }
        taken[cid] = t
    end
    return t[item] or 0, t
end

local hookIds = {}

local function register()
    -- a second try never doubles our hooks
    for _, id in ipairs(hookIds) do pcall(function() exports.ox_inventory:removeHooks(id) end) end
    hookIds = {}
    local inventory = {}
    limits, serialGuns = {}, {}
    for _, it in ipairs(Config.armory.items or {}) do
        -- only items that exist (a missing item would break the shop)
        if type(it.name) == 'string' and exports.ox_inventory:Items(it.name) then
            local isGun = it.name:sub(1, 7) == 'WEAPON_'
            inventory[#inventory + 1] = {
                name = it.name, price = 0, grade = tonumber(it.grade) or 0,
                metadata = (it.serial and isGun) and { serial = 'POL' } or nil,
            }
            limits[it.name] = tonumber(it.max) or (isGun and 1) or 10
            if it.serial and isGun then serialGuns[it.name] = true end
        else
            print(('^3[exti_police] armory: the item "%s" does not exist in ox_inventory, skipped^0'):format(tostring(it.name)))
        end
    end
    exports.ox_inventory:RegisterShop(SHOP, {
        name = Config.armory.label,
        inventory = inventory,
        groups = { [JOB] = 0 },
    })

    -- opening it: on duty and at the armory
    hookIds[#hookIds + 1] = exports.ox_inventory:registerHook('openShop', function(payload)
        local player = getPlayer(payload.source)
        if not onDuty(player) then
            notify(payload.source, 'error', 'ابدأ مناوبتك في المركز أولًا')
            return false
        end
        if not atArmory(payload.source) then return false end
        return true
    end, { typeFilter = { [SHOP] = true } })

    -- taking something: on duty, at the armory, not more than you may carry, not more than the
    -- daily limit
    hookIds[#hookIds + 1] = exports.ox_inventory:registerHook('buyItem', function(payload)
        local src = payload.source
        local player = getPlayer(src)
        if not onDuty(player) or not atArmory(src) then return false end
        local item = payload.itemName
        local count = math.max(1, math.floor(tonumber(payload.count) or 1))
        local max = limits[item] or 1
        local ok, held = pcall(function() return exports.ox_inventory:Search(src, 'count', item) end)
        held = ok and tonumber(held) or 0
        if held + count > max then
            notify(src, 'error', max == 1 and 'معك واحد بالفعل' or ('الحد الأقصى %d'):format(max))
            return false
        end
        local today, t = takenToday(player.PlayerData.citizenid, item)
        local perDay = max * (Config.armory.perDay or 3)
        if today + count > perDay then
            notify(src, 'error', 'وصلت للحد اليومي من هذا الغرض')
            return false
        end
        t[item] = today + count
        lib.logger(src, 'police', ('took %dx %s from the armory'):format(count, item))
        return true
    end, { typeFilter = { [SHOP] = true } })

    -- police guns never leave the officer: not given, not stored, and not taken by a robber either (Moe)
    -- (isRobbery is used below for the tools that stay on a robbed officer)
    local function isRobbery(payload)
        local src, from = tonumber(payload.source), tonumber(payload.fromInventory)
        if not src or not from or src == from or payload.fromType ~= 'player' then return false end
        local ok, canSteal = pcall(function() return Player(from).state.canSteal end)
        return ok and canSteal == true
    end
    local guns = {}
    for name in pairs(serialGuns) do guns[name] = true end
    if next(guns) then
        hookIds[#hookIds + 1] = exports.ox_inventory:registerHook('swapItems', function(payload)
            if payload.fromInventory == payload.toInventory then return true end
            local out = (payload.fromType == 'player' and isPoliceGun(payload.fromSlot))
                or (payload.toType == 'player' and payload.action == 'swap' and isPoliceGun(payload.toSlot))
            if not out then return true end
            local src = tonumber(payload.source) or payload.source
            if type(src) == 'number' then notify(src, 'error', isRobbery(payload) and 'سلاح الشرطة لا يُؤخذ منه' or 'سلاح الشرطة يبقى معك، لا يُعطى ولا يُخزّن') end
            return false
        end, { itemFilter = guns })
    end

    -- EX_Tii (Moe): robbing an officer: his tools stay on him (handcuffs, radio, evidence bags) and so do his
    -- guns (above); everything else (cash, ammo, armour...) can be taken while he is down or cuffed
    local KEEP = { handcuffs = true, radio = true, evidence_bag = true, police_evidence = true }
    hookIds[#hookIds + 1] = exports.ox_inventory:registerHook('swapItems', function(payload)
        -- anything leaving another player's bag through my hands (robbery): the victim's gear
        local src, from = tonumber(payload.source), tonumber(payload.fromInventory)
        if not src or not from or src == from or payload.fromType ~= 'player' then return true end
        local victim = getPlayer(from)
        if not victim or not isCop(victim) then return true end
        notify(src, 'error', 'أدوات الشرطي (الأصفاد، اللاسلكي، أكياس الأدلة) لا تُؤخذ')
        lib.logger(src, 'police', ('tried to take %s from officer %d'):format(payload.fromSlot and payload.fromSlot.name or '?', from))
        return false
    end, { itemFilter = KEEP })
end

-- the hooks are removed by ox_inventory itself when it restarts (and when we stop): register again
POL.withInventory(register, 'the armory')

-- we stop (restart / crash): nobody can use the armory without our checks
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    pcall(function() exports.ox_inventory:RegisterShop(SHOP, { name = Config.armory.label, inventory = {}, groups = POL.NOONE }) end)
end)

lib.callback.register('exti_police:server:canArmory', function(source)
    if not onDuty(getPlayer(source)) then return false, 'off_duty' end
    if not atArmory(source) then return false, 'too_far' end
    return true
end)

---------------------------------------------------------------------------
-- no longer police (fired, quit, a new job): the police guns go back
---------------------------------------------------------------------------
local function takeGunsBack(src)
    local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
    if not ok or type(items) ~= 'table' then return end
    local n = 0
    for _, it in pairs(items) do
        if isPoliceGun(it) then
            if pcall(function() exports.ox_inventory:RemoveItem(src, it.name, it.count or 1, nil, it.slot) end) then n = n + 1 end
        end
    end
    if n > 0 then
        notify(src, 'inform', 'سُحبت منك أسلحة الشرطة')
        lib.logger(src, 'police', ('took back %d police gun(s): no longer police'):format(n))
    end
end
POL.takeGunsBack = takeGunsBack

AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if job and job.name ~= JOB then takeGunsBack(src) end
end)

-- fired while away: checked when they come back (after the inventory has loaded)
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if not src or isCop(player) then return end
    SetTimeout(5000, function()
        local p = getPlayer(src)
        if p and not isCop(p) then takeGunsBack(src) end
    end)
end)

POL.ARMORY = SHOP
