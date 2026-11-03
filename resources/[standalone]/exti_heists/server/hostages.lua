-- =====================================================================
-- EX_Tii heists: hostages. Aim at a person (on the street, in a store) and he puts his hands up; walk
-- up with zip ties and tie him ([G]). Then: walk him with you ([E]), let him go ([H]). An officer frees
-- him ([E], a bonus). Real cops: a hostage call, the rest is roleplay. NPC security: they hold their
-- fire while you hold people, every hostage you let go buys a head start. Hurt one and it's over:
-- an urgent call, NPC security comes in hard, and the arrest bonus on you doubles.
-- The server keeps the list; the robber's game drives the hostage (kneel, follow, flee).
-- =====================================================================
local C = Config
local HG = C.hostages

local list = {}      -- [netId] = { net, by, at, hp, escort }
local hurtBy = {}    -- [citizenid] = os.time() until (double arrest bonus)

local function entOf(net)
    local e = NetworkGetEntityFromNetworkId(math.tointeger(net) or 0)
    return (e ~= 0 and DoesEntityExist(e)) and e or nil
end

local function publish()
    local out = {}
    for net, h in pairs(list) do out[tostring(net)] = { by = h.by, escort = h.escort } end
    GlobalState['exti_heists:hostages'] = out
end

local function countOf(src)
    local n = 0
    for _, h in pairs(list) do if h.by == src then n = n + 1 end end
    return n
end

-- hostages held by these robbers, within 35 m of one of them
function H.hostageCount(players)
    local n = 0
    for _, h in pairs(list) do
        for _, s in ipairs(players) do
            if h.by == s or h.escort == s then
                local e, here = entOf(h.net), H.coords(s)
                if e and here and #(GetEntityCoords(e) - here) < 35.0 then n = n + 1 end
                break
            end
        end
    end
    return n
end

-- the police call (one per robber; the same robber again within a minute updates it)
local function call(src, label, text, urgentHurt)
    if GetResourceState('exti_police') ~= 'started' then return end
    local here = H.coords(src); if not here then return end
    pcall(function()
        -- (the hostage call merges with itself as more are taken; a hurt hostage is always a new call)
        exports.exti_police:AddCall({ kind = 'alarm', label = label, coords = { x = here.x, y = here.y, z = here.z },
            text = text, number = urgentHurt and 'شاهد عيان' or 'بلاغ هاتفي', suspect = src, caller = (not urgentHurt) and src or nil })
    end)
end
local freedBy = {}   -- [officer cid] = { day, n } (a daily cap on the bonus)

local function free(net, why, by)
    local h = list[net]; if not h then return end
    list[net] = nil
    publish()
    local e = entOf(net)
    local from = by and H.coords(by) or (e and GetEntityCoords(e))
    TriggerClientEvent('exti_heists:client:hostageFree', -1, net, from and { x = from.x, y = from.y, z = from.z } or nil)
    H.log(h.by, 'hostage_free', why)
end

---------------------------------------------------------------------------
-- tie him
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:hostageTie', function(src, net)
    net = math.tointeger(net)
    local e = net and entOf(net)
    if not e or list[net] or H.isCopOnDuty(src) then return false end
    if GetEntityType(e) ~= 1 or IsPedAPlayer(e) or GetEntityHealth(e) <= 0 then return false end
    if Entity(e).state.exti_npcsec then return false end
    if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(e) then return false end
    if not H.near(src, GetEntityCoords(e), HG.tieDistance + 1.5) then return false, 'اقترب منه أكثر' end
    if countOf(src) >= HG.maxPerRobber then return false, ('لا تستطيع السيطرة على أكثر من %d'):format(HG.maxPerRobber) end
    if (exports.ox_inventory:Search(src, 'count', 'zip_ties') or 0) < 1 then return false, 'تحتاج أربطة بلاستيكية (من متجر الأدوات)' end
    if not exports.ox_inventory:RemoveItem(src, 'zip_ties', 1) then return false end
    list[net] = { net = net, by = src, byCid = H.cid(src), at = H.now(), hp = GetEntityHealth(e) }
    publish()
    H.setHeat(src, 1)
    local n = countOf(src)
    -- real cops: a hostage call. NPC security already on him: they see it too
    local mode = H.modeFor(1)
    if mode and mode.police then call(src, C.calls.hostages, ('رجل مسلح يحتجز رهائن · العدد: %d'):format(n)) end
    local r = H.npcOf and H.npcOf(src)
    if r and r.phase == 'on scene' then H.npcHold(r, math.min(HG.holdMax, HG.holdPerHostage), 'hostages') end
    H.log(src, 'hostage_tie', ('net %d · %d now'):format(net, n))
    return true, n
end)

---------------------------------------------------------------------------
-- walk with him / let him go / an officer frees him
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:hostageEscort', function(src, net)
    local h = list[math.tointeger(net) or -1]
    local e = h and entOf(h.net)
    if not e or H.isCopOnDuty(src) or not H.near(src, GetEntityCoords(e), 3.0) then return false end
    if h.escort == src then h.escort = nil else h.escort = src end
    publish()
    return true, h.escort == src
end)

lib.callback.register('exti_heists:server:hostageRelease', function(src, net)
    net = math.tointeger(net)
    local h = net and list[net]
    local e = h and entOf(h.net)
    if not e or H.isCopOnDuty(src) or not H.near(src, GetEntityCoords(e), 3.0) then return false end
    free(net, 'released', src)
    -- NPC security: a hostage let go = a head start
    local r = H.npcOf and H.npcOf(h.by)
    if r and r.phase == 'on scene' then H.npcHold(r, HG.releaseHold, 'released') end
    return true
end)

lib.callback.register('exti_heists:server:hostageFreeCop', function(src, net)
    net = math.tointeger(net)
    local h = net and list[net]
    local e = h and entOf(h.net)
    if not e or not H.isCopOnDuty(src) or not H.near(src, GetEntityCoords(e), 3.0) then return false end
    free(net, 'freed by police', src)
    -- the bonus: not for his own hostage, not for one held under a minute, at most a few a day
    local cid = H.cid(src)
    local day = os.date('%Y-%m-%d')
    local f = freedBy[cid]
    if not f or f.day ~= day then f = { day = day, n = 0 }; freedBy[cid] = f end
    local pay = (cid ~= h.byCid and H.now() - h.at >= HG.minHoldForBonus and f.n < HG.copFreeDaily) and HG.copFreeBonus or 0
    if pay > 0 then
        f.n = f.n + 1
        local p = H.player(src)
        if p then p.Functions.AddMoney('bank', pay, 'police-hostage-freed') end
        if H.boardAdd then H.boardAdd('cop', src, 3) end
    end
    H.log(src, 'hostage_freed_cop', ('$%d'):format(pay))
    return true, pay
end)

-- the game driving him saw him get hurt (we check his health ourselves)
RegisterNetEvent('exti_heists:server:hostageHurt', function(net, damager)
    net = math.tointeger(net)
    local h = net and list[net]
    if not h then return end
    local e = entOf(h.net)
    if not e then return end            -- (gone is not hurt: the clean-up handles it)
    local hp = GetEntityHealth(e)
    if hp >= h.hp - 5 then return end
    -- who did it: what the game engine says first; the reporting game only if it fits
    local by
    local srcEnt = GetPedSourceOfDamage(e)
    if (not srcEnt or srcEnt == 0) and hp <= 0 then srcEnt = GetPedSourceOfDeath(e) end
    if srcEnt and srcEnt ~= 0 and GetEntityType(srcEnt) == 2 then srcEnt = GetPedInVehicleSeat(srcEnt, -1) end
    if srcEnt and srcEnt ~= 0 and IsPedAPlayer(srcEnt) then by = NetworkGetEntityOwner(srcEnt) end
    damager = math.tointeger(damager)
    if not by and damager and GetPlayerName(damager) then
        local dped = GetPlayerPed(damager)
        if dped ~= 0 and #(GetEntityCoords(dped) - GetEntityCoords(e)) < 60.0 and GetSelectedPedWeapon(dped) ~= `WEAPON_UNARMED` then by = damager end
    end
    damager = by
    h.hp = hp
    if damager and not H.isCopOnDuty(damager) then
        local cid = H.cid(damager)
        if cid then hurtBy[cid] = H.now() + HG.hurtMinutes * 60 end
        call(damager, C.calls.hostageHurt, hp <= 0 and 'قُتلت رهينة' or 'إطلاق نار على رهينة', true)
        if H.npcRage then H.npcRage(damager) end
        H.log(damager, 'hostage_hurt', hp <= 0 and 'killed' or ('hp %d'):format(hp))
    else
        H.log(damager or h.by, 'hostage_hurt_other', ('hp %d'):format(hp))
    end
    if hp <= 0 then free(net, 'dead') end
end)

function H.hurtHostage(src) local cid = H.cid(src); return cid and (hurtBy[cid] or 0) > H.now() or false end

-- the oldest hostage of this robber goes free (the negotiator's head start)
function H.releaseOne(src)
    local best
    for net, h in pairs(list) do if h.by == src and (not best or h.at < list[best].at) then best = net end end
    if best then free(best, 'deal', src) return true end
    return false
end
function H.releaseAll(src)
    for net, h in pairs(list) do if h.by == src then free(net, 'all') end end
end

---------------------------------------------------------------------------
-- clean-up: gone, too long, the robber left
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        local t = H.now()
        for net, h in pairs(list) do
            local e = entOf(net)
            local by = h.escort or h.by
            local here = GetPlayerName(by) and H.coords(by)
            if not e then
                list[net] = nil; publish()
            elseif t - h.at > HG.autoReleaseMinutes * 60 then
                free(net, 'time')
            elseif not here or #(here - GetEntityCoords(e)) > HG.leaveDistance then
                free(net, 'left')
            end
        end
    end
end)
AddEventHandler('playerDropped', function()
    local src = source
    for net, h in pairs(list) do
        if h.by == src then free(net, 'dropped') elseif h.escort == src then h.escort = nil; publish() end
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    GlobalState['exti_heists:hostages'] = {}
end)
CreateThread(function() Wait(1000); GlobalState['exti_heists:hostages'] = {} end)

exports('HostageCount', function(src) return H.hostageCount({ src }) end)
exports('HurtHostage', function(src) return H.hurtHostage(src) end)
