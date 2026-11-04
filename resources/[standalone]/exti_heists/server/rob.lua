-- =====================================================================
-- EX_Tii heists (server): robbing a PLAYER (Z wheel → فتّشه).
-- Who can be robbed: hands up (X), tied with zip ties, or down. Never someone cuffed by the police
-- (only the officer searches him: exti_police sends all of it to the seized room).
--   1. robBegin: the server checks both people, the victim is told someone is searching him
--   2. a few seconds of searching (the robber's game shows it)
--   3. robOpen: checked again, then the victim's bag opens next to the robber's own
--   4. while it is open the server keeps checking: the victim puts his hands down (and is not tied or
--      down), one of them walks away, the robber goes down... the bag closes
-- The papers and the phone (Config.rob.keep) cannot be taken. Every item taken goes in the heist log.
-- /steal (ox_inventory's own command) is off: inventory:enablestealcommand false in ox.cfg.
-- =====================================================================
local C = Config
local R = C.rob
local ox = exports.ox_inventory

local pending = {}   -- [robber] = { tid, at, token }
local robbing = {}   -- [robber] = victim
local robbedBy = {}  -- [victim] = robber

local function alive(src) return src and GetPlayerName(src) ~= nil end
local function ped(src) local p = GetPlayerPed(src); return (p and p ~= 0 and DoesEntityExist(p)) and p or nil end
local function st(src) return Player(src) and Player(src).state end

local function isDown(src)
    local s = st(src)
    local ds = s and s['qbx_medical:deathState']
    local p = ped(src)
    return (ds ~= nil and ds ~= 1) or (p ~= nil and GetEntityHealth(p) <= 101)
end
local function policeCuffed(src)
    local s = st(src)
    if s and s.cuffed == true then return true end
    if GetResourceState('exti_police') ~= 'started' then return false end
    local ok, v = pcall(function() return exports.exti_police:IsCuffed(src) end)
    return ok and v == true
end
local function tied(src) local s = st(src); return s ~= nil and s.exti_tied ~= nil end
local function handsUp(src) local s = st(src); return s ~= nil and s.handsup == true end
local function inCar(src) local p = ped(src); return p ~= nil and GetVehiclePedIsIn(p, false) ~= 0 end

local function dist(a, b)
    local pa, pb = ped(a), ped(b)
    if not pa or not pb then return math.huge end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end
local function inSafeZone(src)
    local p = ped(src)
    if not p then return false end
    local here = GetEntityCoords(p)
    for _, z in ipairs(R.safeZones or {}) do
        if #(here - z.coords) <= z.radius then return true end
    end
    return false
end

-- can src rob tid right now? (reach: how close they must be)
local function check(src, tid, reach)
    if not alive(src) or not alive(tid) or src == tid then return false, 'لا يوجد أحد قريب' end
    if H.isCopOnDuty(src) then return false, 'أنت شرطي في الخدمة: استخدم تفتيش الشرطة' end
    if isDown(src) or tied(src) or policeCuffed(src) or handsUp(src) then return false, 'لا تستطيع الآن' end
    if inCar(src) or inCar(tid) then return false, 'لا يمكن التفتيش داخل مركبة' end
    if dist(src, tid) > reach then return false, 'ابتعد كثيرًا' end
    if policeCuffed(tid) then return false, 'هذا الشخص مكبّل من الشرطة' end
    if not (handsUp(tid) or tied(tid) or isDown(tid)) then return false, 'يجب أن يرفع يديه أو يكون مقيّدًا أو ساقطًا' end
    if inSafeZone(src) or inSafeZone(tid) then return false, 'منطقة آمنة: لا سرقة هنا' end
    if robbedBy[tid] and robbedBy[tid] ~= src then return false, 'شخص آخر يفتّشه الآن' end
    return true
end

local function stop(robber, why)
    local tid = robbing[robber]
    if not tid then return end
    robbing[robber] = nil
    if robbedBy[tid] == robber then robbedBy[tid] = nil end
    if alive(robber) then
        TriggerClientEvent('ox_inventory:closeInventory', robber)
        if why then H.notify(robber, why, 'error') end
    end
    if alive(tid) then TriggerClientEvent('exti_heists:client:robbed', tid, false) end
end

---------------------------------------------------------------------------
-- the robber's game
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:robBegin', function(source, targetId)
    local tid = math.tointeger(tonumber(targetId))
    if not tid then return false, 'لا يوجد أحد قريب' end
    if robbing[source] then return false, 'أنت تفتّش الآن' end
    local ok, why = check(source, tid, R.reach + 0.5) -- (a little slack: the server sees positions a moment late)
    if not ok then return false, why end
    local token = ('%d:%d:%d'):format(source, tid, math.random(100000, 999999))
    pending[source] = { tid = tid, at = os.clock(), token = token }
    H.notify(tid, 'أحدهم يفتّشك...', 'warning', R.searchSeconds * 1000 + 1000)
    return true, token
end)

lib.callback.register('exti_heists:server:robOpen', function(source, token)
    local p = pending[source]
    pending[source] = nil
    if not p or p.token ~= token then return false end
    if os.clock() - p.at < R.searchSeconds - 0.5 then return false end -- no skipping the search
    local tid = p.tid
    local ok, why = check(source, tid, R.keepReach)
    if not ok then return false, why end
    robbing[source] = tid
    robbedBy[tid] = source
    TriggerClientEvent('exti_heists:client:robbed', tid, true)
    local okO, opened = pcall(function() return ox:forceOpenInventory(source, 'player', tid) end)
    if not okO or not opened then
        stop(source)
        return false, 'تعذّر فتح الحقيبة، حاول مرة أخرى'
    end
    H.log(source, 'rob_player', ('searched %s (%s)'):format(H.name(tid), H.cid(tid) or '?'))
    H.notify(tid, 'أحدهم يفتّش حقيبتك', 'warning')
    return true
end)

-- the robber closed the bag himself
AddEventHandler('ox_inventory:closedInventory', function(playerId)
    local src = tonumber(playerId)
    if src and robbing[src] then stop(src) end
end)

-- while it is open: keep checking
CreateThread(function()
    while true do
        Wait(500)
        for robber, tid in pairs(robbing) do
            local ok, why = check(robber, tid, R.keepReach)
            if not ok then stop(robber, why) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    pending[src] = nil
    if robbing[src] then stop(src) end
    local robber = robbedBy[src]
    if robber then stop(robber, 'غادر الشخص') end
end)

---------------------------------------------------------------------------
-- what may move while robbing (only for the robber, only from his victim's bag)
---------------------------------------------------------------------------
local function itemText(slot, count)
    return ('%dx %s'):format(count or (slot and slot.count) or 1, slot and (slot.label or slot.name) or '?')
end

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
    ox:registerHook('swapItems', function(p)
        local src = tonumber(p.source)
        local tid = src and robbing[src]
        if not tid then return true end
        if p.fromInventory == p.toInventory then return true end
        local fromVictim = p.fromType == 'player' and tonumber(p.fromInventory) == tid
        local toVictim = p.toType == 'player' and tonumber(p.toInventory) == tid
        if fromVictim then
            local name = type(p.fromSlot) == 'table' and p.fromSlot.name
            if not name or R.keep[name] then
                H.notify(src, 'لا يمكنك أخذ الهوية أو الرخص أو الهاتف', 'error')
                return false
            end
            if p.action == 'swap' then
                -- dropping it on one of my items would trade them: empty slots only
                H.notify(src, 'ضعه في خانة فارغة', 'error')
                return false
            end
            local what = itemText(p.fromSlot, tonumber(p.count))
            H.log(src, 'rob_take', ('from %s (%s): %s'):format(H.name(tid), H.cid(tid) or '?', what))
            return true
        end
        if toVictim and p.action == 'swap' then
            -- my item onto his: that would hand me his item (maybe his papers)
            H.notify(src, 'ضعه في خانة فارغة', 'error')
            return false
        end
        return true
    end, {})
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for robber in pairs(robbing) do stop(robber) end
end)
