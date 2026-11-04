-- =====================================================================
-- EX_Tii heists: hostages, NPCs and players, all from the Z wheel ("الرهينة").
--   * aim at an NPC: hands up; aim at him again: flat on his stomach. A player puts his own hands up (X).
--   * zip ties (the gangs make them): tie him. Then: blindfold (a sack over the head), walk him with you,
--     put him in a car / take him out, down on his stomach / up again, let him go.
--   * a downed player is never tied (only the police pick up the downed); a cuffed one neither.
--   * officers: cut the ties / take the sack off (a bonus for a freed NPC hostage).
--   * real cops: a hostage call, the rest is roleplay. NPC police (npc.lua): a standoff, a deal, a chase.
--   * hurt one: an urgent call, the NPC police storm in, the arrest bonus on you doubles.
--   * the robber logs out or walks into a house while holding someone: the hostage goes free, the admins
--     get a message, and on his return he goes to prison and loses the loot of that robbery.
-- The server keeps the list; the robber's game drives an NPC hostage, a player's own game shows his.
-- =====================================================================
local C = Config
local HG = C.hostages
local ox = exports.ox_inventory

local list = {}      -- NPCs:    [netId] = { net, by, byCid, at, hp, escort, blind, prone, veh }
local caps = {}      -- players: [src]   = { by, byCid, at, hp, escort, blind, prone, veh }
local hurtBy = {}    -- [citizenid] = os.time() until (double arrest bonus)
local freedBy = {}   -- [officer cid] = { day, n } (a daily cap on the bonus)
local tieTokens = {} -- [src] = { kind, id, at, token }

local function entOf(net)
    local e = NetworkGetEntityFromNetworkId(math.tointeger(net) or 0)
    return (e ~= 0 and DoesEntityExist(e)) and e or nil
end
local function alive(src) return src and GetPlayerName(src) ~= nil end

local function publish()
    local out = {}
    for net, h in pairs(list) do out[tostring(net)] = { by = h.by, escort = h.escort, blind = h.blind, prone = h.prone, veh = h.veh, seat = h.seat } end
    GlobalState['exti_heists:hostages'] = out
end

-- the player's state bags (his own game reads them: tied, the sack, on the floor, walked by someone)
local function bagsOf(t)
    local c = caps[t]
    local st = Player(t).state
    st:set('exti_tied', c and c.by or nil, true)
    st:set('exti_blind', c and c.blind or nil, true)
    st:set('exti_prone', c and c.prone or nil, true)
    st:set('exti_heldBy', c and c.escort or nil, true)
end

local function isDown(src)
    local ds = Player(src).state['qbx_medical:deathState']
    return (ds ~= nil and ds ~= 1) or GetEntityHealth(GetPlayerPed(src)) <= 101
end
local function isCuffed(src)
    if Player(src).state.cuffed == true then return true end
    if GetResourceState('exti_police') ~= 'started' then return false end
    local ok, v = pcall(function() return exports.exti_police:IsCuffed(src) end)
    return ok and v == true
end
local function busyBody(src) return caps[src] ~= nil or isCuffed(src) or isDown(src) end

-- the robber himself, a member of his crew, or someone in the same NPC police response
local function sameSide(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local ra = H.npcOf and H.npcOf(a)
    if ra and ra == H.npcOf(b) then return true end
    local ca, cb = H.crewOf and H.crewOf(H.cid(a)), H.crewOf and H.crewOf(H.cid(b))
    return ca ~= nil and cb ~= nil and ca.id == cb.id
end
H.sameSide = sameSide

-- where a hostage is (NPC or player)
local function posOf(kind, id)
    if kind == 'npc' then local e = entOf(id); return e and GetEntityCoords(e) or nil end
    return alive(id) and H.coords(id) or nil
end
local function recOf(kind, id) if kind == 'npc' then return list[id] end return caps[id] end

-- every hostage of this robber (or walked by him)
function H.hostagesOf(src)
    local out = {}
    for net, h in pairs(list) do if h.by == src or h.escort == src then out[#out + 1] = { kind = 'npc', id = net, h = h } end end
    for t, h in pairs(caps) do if h.by == src or h.escort == src then out[#out + 1] = { kind = 'player', id = t, h = h } end end
    return out
end

-- hostages held by these robbers, close to one of them (35 m, or in the same car)
function H.hostageCount(players)
    local n = 0
    local function near(kind, id, s)
        local p, here = posOf(kind, id), H.coords(s)
        return p and here and #(p - here) < 35.0
    end
    for net, h in pairs(list) do
        for _, s in ipairs(players) do if (h.by == s or h.escort == s) and near('npc', net, s) then n = n + 1 break end end
    end
    for t, h in pairs(caps) do
        for _, s in ipairs(players) do if (h.by == s or h.escort == s) and near('player', t, s) then n = n + 1 break end end
    end
    return n
end
local function countOf(src)
    local n = 0
    for _, h in pairs(list) do if h.by == src then n = n + 1 end end
    for _, h in pairs(caps) do if h.by == src then n = n + 1 end end
    return n
end

-- the police call (one per robber; the same robber again within a minute updates it)
local function call(src, label, text, urgentHurt)
    if GetResourceState('exti_police') ~= 'started' then return end
    local here = H.coords(src); if not here then return end
    pcall(function()
        exports.exti_police:AddCall({ kind = 'alarm', label = label, coords = { x = here.x, y = here.y, z = here.z },
            text = text, number = urgentHurt and 'شاهد عيان' or 'بلاغ هاتفي', suspect = src, caller = (not urgentHurt) and src or nil })
    end)
end

-- he goes free (and whoever put the sack on gets it back if he took it off; a sack left on stays on him)
local function free(kind, id, why, by)
    local h = recOf(kind, id); if not h then return end
    local at = posOf(kind, id)
    if kind == 'npc' then
        list[id] = nil; publish()
        local from = by and H.coords(by) or at
        TriggerClientEvent('exti_heists:client:hostageFree', -1, id, from and { x = from.x, y = from.y, z = from.z } or nil)
    else
        caps[id] = nil
        if alive(id) then bagsOf(id); TriggerClientEvent('exti_heists:client:captiveFree', id) end
    end
    H.log(h.by, 'hostage_free', ('%s · %s'):format(kind, why))
    if H.npcOnRelease and at then H.npcOnRelease(h.by, at, why) end
end
H.hostageFree = free

---------------------------------------------------------------------------
-- tie him (two steps: the game shows the progress, the server times it)
---------------------------------------------------------------------------
local function canTie(src, kind, id)
    if H.isCopOnDuty(src) then return false end
    if busyBody(src) then return false end
    if countOf(src) >= HG.maxPerRobber then return false, ('لا تستطيع السيطرة على أكثر من %d'):format(HG.maxPerRobber) end
    if (ox:Search(src, 'count', 'zip_ties') or 0) < 1 then return false, 'تحتاج أربطة بلاستيكية (تصنعها العصابات)' end
    if kind == 'npc' then
        local e = entOf(id)
        if not e or list[id] then return false end
        if GetEntityType(e) ~= 1 or IsPedAPlayer(e) or GetEntityHealth(e) <= 0 then return false end
        if Entity(e).state.exti_npcsec or Entity(e).state.exti_guard then return false end
        if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(e) then return false end
        if not H.near(src, GetEntityCoords(e), HG.tieDistance + 1.5) then return false, 'اقترب منه أكثر' end
        return true
    end
    -- a player: only with his hands up, never downed, never cuffed by the police
    if not alive(id) or id == src or caps[id] then return false end
    if sameSide(src, id) then return false, 'لا تستطيع أخذ أحد أفراد طاقمك رهينة' end
    if isDown(id) then return false, 'لا يمكن تقييد شخص مصاب على الأرض' end
    if isCuffed(id) then return false, 'مقيّد بالأصفاد' end
    if Player(id).state.handsup ~= true then return false, 'يجب أن يرفع يديه أولًا' end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(id) then return false end
    if GetVehiclePedIsIn(GetPlayerPed(id), false) ~= 0 then return false end
    if not H.near(src, H.coords(id), HG.tieDistance + 1.0) then return false, 'اقترب منه أكثر' end
    return true
end

lib.callback.register('exti_heists:server:tieBegin', function(src, kind, id)
    kind = kind == 'player' and 'player' or 'npc'
    id = math.tointeger(id)
    if not id then return false end
    local ok, why = canTie(src, kind, id)
    if not ok then return false, why end
    local tok = math.random(100000, 999999)
    tieTokens[src] = { kind = kind, id = id, at = GetGameTimer(), token = tok }
    if kind == 'player' then TriggerClientEvent('exti_heists:client:beingTied', id, src, HG.tieSeconds) end
    return true, tok
end)

lib.callback.register('exti_heists:server:tieEnd', function(src, token, done)
    local t = tieTokens[src]; tieTokens[src] = nil
    if not t or t.token ~= token then return false end
    if t.kind == 'player' and not done and alive(t.id) then TriggerClientEvent('exti_heists:client:beingTied', t.id, nil) end
    if not done then return false end
    if GetGameTimer() - t.at < (HG.tieSeconds - 0.6) * 1000 then return false end
    -- (a player keeps "hands up" while he's being tied: his game holds him still)
    local ok, why = canTie(src, t.kind, t.id)
    if not ok then
        if t.kind == 'player' and alive(t.id) then TriggerClientEvent('exti_heists:client:beingTied', t.id, nil) end
        return false, why
    end
    if not ox:RemoveItem(src, 'zip_ties', 1) then return false end
    local rec = { by = src, byCid = H.cid(src), at = H.now() }
    if t.kind == 'npc' then
        local e = entOf(t.id)
        rec.net, rec.hp = t.id, GetEntityHealth(e)
        list[t.id] = rec; publish()
    else
        rec.hp = GetEntityHealth(GetPlayerPed(t.id))
        caps[t.id] = rec; bagsOf(t.id)
        Player(t.id).state:set('handsup', false, true)
        H.notify(t.id, 'قُيّدت يداك', 'error', 5000)
    end
    H.setHeat(src, 1)
    local n = countOf(src)
    local mode = H.modeFor(1)
    if mode and mode.police then call(src, C.calls.hostages, ('رجل مسلح يحتجز رهائن · العدد: %d'):format(n)) end
    if H.npcOnHostage then H.npcOnHostage(src) end
    H.log(src, 'hostage_tie', ('%s %d · %d now'):format(t.kind, t.id, n))
    return true, n
end)

---------------------------------------------------------------------------
-- everything else on the wheel: one callback
---------------------------------------------------------------------------
lib.callback.register('exti_heists:server:hostageAct', function(src, action, kind, id, extra)
    kind = kind == 'player' and 'player' or 'npc'
    id = math.tointeger(id)
    local h = id and recOf(kind, id)
    if not h then return false end
    if busyBody(src) then return false end
    local at = posOf(kind, id)
    if not at then return false end
    local cop = H.isCopOnDuty(src)
    local reach = (action == 'carOut' and 4.5) or (action == 'prone' and extra == 'aim' and HG.aimDistance) or 3.0
    if not H.near(src, at, reach) then return false, 'اقترب منه أكثر' end
    local function sync() if kind == 'npc' then publish() else bagsOf(id) end end

    if action == 'free' then
        -- the robber lets him go; anyone else (an officer, a passer-by) cuts the ties
        if cop then
            free(kind, id, 'freed by police', src)
            local pay = 0
            if kind == 'npc' then
                local cid = H.cid(src)
                local day = os.date('%Y-%m-%d')
                local f = freedBy[cid]
                if not f or f.day ~= day then f = { day = day, n = 0 }; freedBy[cid] = f end
                pay = (cid ~= h.byCid and H.now() - h.at >= HG.minHoldForBonus and f.n < HG.copFreeDaily) and HG.copFreeBonus or 0
                if pay > 0 then
                    f.n = f.n + 1
                    local p = H.player(src)
                    if p then p.Functions.AddMoney('bank', pay, 'police-hostage-freed') end
                    if H.boardAdd then H.boardAdd('cop', src, 3) end
                end
            end
            H.log(src, 'hostage_freed_cop', ('%s $%d'):format(kind, pay))
            return true, pay
        end
        if sameSide(h.by, src) and H.npcDropGuard then
            local okg, why = H.npcDropGuard(h.by, at)
            if not okg then return false, why end
        end
        free(kind, id, sameSide(h.by, src) and 'released' or ('cut by %d'):format(src), src)
        return true, 0

    elseif action == 'blind' then
        if h.blind then return false end
        if (ox:Search(src, 'count', 'blindfold') or 0) < 1 then return false, 'تحتاج عصابة عينين (تصنعها العصابات)' end
        if not ox:RemoveItem(src, 'blindfold', 1) then return false end
        h.blind = true; sync()
        if kind == 'player' then H.notify(id, 'وُضع كيس على رأسك', 'error', 5000) end
        return true

    elseif action == 'unblind' then
        if not h.blind then return false end
        h.blind = nil; sync()
        ox:AddItem(src, 'blindfold', 1)
        return true

    -- the rest is the robber's (and his crewmates', not an officer's)
    elseif cop or not sameSide(h.by, src) then return false

    elseif action == 'escort' then
        if h.veh then return false, 'أخرجه من المركبة أولًا' end
        if h.escort == src then h.escort = nil
        else
            -- (nobody walks two at once)
            for _, o in ipairs(H.hostagesOf(src)) do if o.h.escort == src and o.h ~= h then return false, 'أنت تقود رهينة أخرى' end end
            h.escort, h.prone = src, nil
        end
        sync()
        return true, h.escort == src

    elseif action == 'prone' or action == 'up' then
        if h.veh or h.escort then return false end
        h.prone = action == 'prone' or nil; sync()
        return true

    elseif action == 'carIn' then
        if h.veh then return false end
        local vnet = type(extra) == 'table' and math.tointeger(extra.net) or nil
        local want = type(extra) == 'table' and math.tointeger(extra.seat) or nil
        local veh = entOf(vnet)
        if not veh or GetEntityType(veh) ~= 2 or #(GetEntityCoords(veh) - at) > 6.0 or not H.near(src, GetEntityCoords(veh), 6.0) then return false, 'لا توجد مركبة قريبة' end
        local seat = want and want >= 0 and want <= 6 and GetPedInVehicleSeat(veh, want) == 0 and want or nil
        if not seat then return false, 'المركبة ممتلئة' end
        h.veh, h.seat, h.escort, h.prone = vnet, seat, nil, nil; sync()
        if kind == 'player' then TriggerClientEvent('exti_heists:client:captiveCar', id, h.veh, seat) end
        return true

    elseif action == 'carOut' then
        if not h.veh then return false end
        h.veh, h.seat = nil, nil; sync()
        if kind == 'player' then TriggerClientEvent('exti_heists:client:captiveCar', id, nil) end
        return true
    end
    return false
end)

-- a player hostage's game: the car he was put in is gone / he fell out of it
RegisterNetEvent('exti_heists:server:captiveOutOfCar', function()
    local src = source
    local h = caps[src]
    if h and h.veh then h.veh, h.seat = nil, nil; bagsOf(src) end
end)

---------------------------------------------------------------------------
-- hurt (the game that watches him reports, we check his health ourselves)
---------------------------------------------------------------------------
local function hurt(kind, id, damager)
    local h = recOf(kind, id); if not h then return end
    local ped = kind == 'npc' and entOf(id) or (alive(id) and GetPlayerPed(id))
    if not ped or ped == 0 then return end
    local hp = GetEntityHealth(ped)
    if hp >= h.hp - 5 then return end
    -- who did it: what the game engine says first; the reporting game only if it fits
    local by
    local srcEnt = GetPedSourceOfDamage(ped)
    if (not srcEnt or srcEnt == 0) and hp <= (kind == 'npc' and 0 or 101) then srcEnt = GetPedSourceOfDeath(ped) end
    if srcEnt and srcEnt ~= 0 and GetEntityType(srcEnt) == 2 then srcEnt = GetPedInVehicleSeat(srcEnt, -1) end
    if srcEnt and srcEnt ~= 0 and IsPedAPlayer(srcEnt) then by = NetworkGetEntityOwner(srcEnt) end
    damager = math.tointeger(damager)
    if not by and damager and alive(damager) then
        local dped = GetPlayerPed(damager)
        if dped ~= 0 and #(GetEntityCoords(dped) - GetEntityCoords(ped)) < 60.0 and GetSelectedPedWeapon(dped) ~= `WEAPON_UNARMED` then by = damager end
    end
    h.hp = hp
    local dead = hp <= (kind == 'npc' and 0 or 101)
    if by and by ~= id and not H.isCopOnDuty(by) then
        local cid = H.cid(by)
        if cid then hurtBy[cid] = H.now() + HG.hurtMinutes * 60 end
        call(by, C.calls.hostageHurt, dead and 'قُتلت رهينة' or 'إطلاق نار على رهينة', true)
        if H.npcRage then H.npcRage(by) end
        H.log(by, 'hostage_hurt', ('%s %s'):format(kind, dead and 'killed' or ('hp %d'):format(hp)))
    else
        H.log(by or h.by, 'hostage_hurt_other', ('%s hp %d'):format(kind, hp))
    end
    if dead then free(kind, id, 'dead') end
end
RegisterNetEvent('exti_heists:server:hostageHurt', function(net, damager) hurt('npc', math.tointeger(net), damager) end)
RegisterNetEvent('exti_heists:server:captiveHurt', function(damager) hurt('player', source, damager) end)

function H.hurtHostage(src) local cid = H.cid(src); return cid and (hurtBy[cid] or 0) > H.now() or false end

-- the oldest hostage of this robber goes free / all of them (the negotiator's deals)
function H.releaseOne(src)
    local best
    for _, o in ipairs(H.hostagesOf(src)) do if not best or o.h.at < best.h.at then best = o end end
    if best then free(best.kind, best.id, 'deal', src) return true end
    return false
end
function H.releaseAll(src, why)
    for _, o in ipairs(H.hostagesOf(src)) do free(o.kind, o.id, why or 'all', src) end
end

---------------------------------------------------------------------------
-- leaving with a hostage: logged out / went into a house
---------------------------------------------------------------------------
local function streetText(c) return c and ('(%.0f, %.0f)'):format(c.x, c.y) or '?' end
local function adminText(msg)
    for _, s in ipairs(GetPlayers()) do
        local p = tonumber(s)
        if p and IsPlayerAceAllowed(p, 'group.admin') then
            local to = H.phoneOf and H.phoneOf(p)
            if to and GetResourceState('npwd') == 'started' then
                pcall(function() exports.npwd:emitMessage({ senderNumber = C.negotiator.number, targetNumber = to, message = msg }) end)
            end
            H.notify(p, msg, 'warning', 12000)
        end
    end
end

local function penaltyKey(cid) return 'exti_heists:leftwith:' .. cid end
local function leftWith(src, cid, name, how, held)
    if not cid then return end
    local c = H.coords(src)
    local n = #held
    for _, o in ipairs(held) do free(o.kind, o.id, how == 'logout' and 'dropped' or 'house') end
    SetResourceKvp(penaltyKey(cid), json.encode({ jail = HG.leaveJail, at = os.time(), how = how }))
    local msg = ('حراسة الحي · بلاغ للإدارة: %s (%s) %s وهو يحتجز %d %s · الساعة %s · المكان %s'):format(
        name or '?', cid, how == 'logout' and 'خرج من السيرفر' or 'دخل منزلًا', n, n == 1 and 'رهينة' or 'رهائن',
        os.date('%H:%M'), streetText(c))
    adminText(msg)
    H.log(src, 'hostage_left', msg)
end

-- on his return (log in / back out of the house): the loot of that robbery goes, then the prison
local function applyPenalty(src)
    local cid = H.cid(src); if not cid then return end
    local raw = GetResourceKvpString(penaltyKey(cid)); if not raw then return end
    DeleteResourceKvp(penaltyKey(cid))
    local pen = json.decode(raw) or {}
    local rec = H.rec(src)
    if rec then
        for item, n in pairs(rec.loot or {}) do
            local have = ox:Search(src, 'count', item) or 0
            local take = math.min(have, n)
            if take > 0 then ox:RemoveItem(src, item, take) end
        end
        rec.loot = {}
    end
    H.notify(src, 'تركت رهينتك وهربت: صودرت غنيمتك، وأنت مطلوب للسجن', 'error', 10000)
    if GetResourceState('exti_police') == 'started' then
        pcall(function() exports.exti_police:Jail(src, pen.jail or HG.leaveJail, 'حراسة الحي') end)
    end
    H.log(src, 'hostage_left_jailed', ('%d min'):format(pen.jail or HG.leaveJail))
end
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(15000, function() if alive(src) then applyPenalty(src) end end)
end)

local inHouse = {}   -- [src] = cid: he walked into a house holding someone (the penalty waits for him outside)
CreateThread(function()
    while true do
        Wait(2000)
        -- a robber who holds someone and is now in another copy of the world (a house)
        local robbers = {}
        for _, h in pairs(list) do robbers[h.by] = true end
        for _, h in pairs(caps) do robbers[h.by] = true end
        for s in pairs(robbers) do
            if alive(s) and GetPlayerRoutingBucket(s) ~= 0 then
                local held = {}
                for _, o in ipairs(H.hostagesOf(s)) do if o.h.by == s then held[#held + 1] = o end end
                if #held > 0 then inHouse[s] = H.cid(s); leftWith(s, H.cid(s), H.name(s), 'house', held) end
            end
        end
        for s in pairs(inHouse) do
            if not alive(s) then inHouse[s] = nil
            elseif GetPlayerRoutingBucket(s) == 0 then inHouse[s] = nil; applyPenalty(s) end
        end
    end
end)

---------------------------------------------------------------------------
-- clean-up: gone, the robber walked away, he left
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        for net, h in pairs(list) do
            local e = entOf(net)
            local by = h.escort or h.by
            local here = alive(by) and H.coords(by)
            if not e then
                list[net] = nil; publish()
            elseif here and #(here - GetEntityCoords(e)) > HG.leaveDistance then
                free('npc', net, 'left')
            end
        end
        for t, h in pairs(caps) do
            local by = h.escort or h.by
            local here = alive(by) and H.coords(by)
            local there = alive(t) and H.coords(t)
            -- (a player is never left tied for good: his robber down for a few minutes, or the hard cap)
            if alive(h.by) and isDown(h.by) then h.downAt = h.downAt or H.now() else h.downAt = nil end
            if not alive(t) then caps[t] = nil
            elseif here and there and #(here - there) > HG.leaveDistance then free('player', t, 'left')
            elseif h.downAt and H.now() - h.downAt > HG.playerFreeDownMinutes * 60 then free('player', t, 'robber down')
            elseif H.now() - h.at > HG.playerMaxMinutes * 60 then free('player', t, 'time')
            elseif h.escort and not alive(h.escort) then h.escort = nil; bagsOf(t) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    tieTokens[src] = nil
    -- a hostage who left: off the list
    if caps[src] then caps[src] = nil end
    -- a robber who left holding someone
    local held, cid, name = {}, nil, nil
    for _, o in ipairs(H.hostagesOf(src)) do
        if o.h.by == src then held[#held + 1] = o; cid = cid or o.h.byCid
        elseif o.h.escort == src then o.h.escort = nil; if o.kind == 'npc' then publish() elseif alive(o.id) then bagsOf(o.id) end end
    end
    if #held > 0 then
        name = GetPlayerName(src)
        local ok, n = pcall(H.name, src); if ok and n then name = n end
        leftWith(src, cid, name, 'logout', held)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    GlobalState['exti_heists:hostages'] = {}
    for t in pairs(caps) do caps[t] = nil; if alive(t) then bagsOf(t) end end
end)
CreateThread(function()
    Wait(1000)
    GlobalState['exti_heists:hostages'] = {}
    -- (a restart: nobody stays tied by a list that's gone)
    for _, s in ipairs(GetPlayers()) do
        local p = tonumber(s)
        if p and Player(p).state.exti_tied then caps[p] = nil; bagsOf(p) end
    end
end)

exports('HostageCount', function(src) return H.hostageCount({ src }) end)
exports('HurtHostage', function(src) return H.hurtHostage(src) end)
exports('IsHostage', function(src) return caps[src] ~= nil end)
