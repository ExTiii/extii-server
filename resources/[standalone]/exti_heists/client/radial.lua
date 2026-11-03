-- =====================================================================
-- EX_Tii heists (game side): the "الرهينة" slice of the Z wheel (exti_radial asks for it when it opens).
-- Next to someone with his hands up (an NPC you aim at, a player who pressed X): tie him (zip ties).
-- Next to a tied hostage: let him go, the sack on / off, walk him / leave him, flat on the floor / up,
-- into the car / out of it. An officer (or anyone else) next to a tied person: cut the ties, take the
-- sack off. The server checks everything again.
-- =====================================================================
local C = Config
local HG = C.hostages

local function isCop()
    local j = QBX and QBX.PlayerData and QBX.PlayerData.job
    return j ~= nil and j.name == C.cops.job and j.onduty == true
end
local function down(ped)
    if IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) <= 101 then return true end
    return false
end

-- the person to act on: the one I walk, then the closest one within reach, then one sitting in the car next to me
function HC.radialTarget()
    if LocalPlayer.state.exti_tied or LocalPlayer.state.cuffed then return nil end
    local me = cache.serverId
    local myPos = GetEntityCoords(cache.ped)
    local npcs = HC.npcHostages and HC.npcHostages() or {}
    -- 1. the one I walk
    for net, h in pairs(npcs) do
        if h.escort == me then local ped = HC.hostagePed(net); if ped then return { kind = 'npc', id = net, ped = ped, h = h, tied = true } end end
    end
    for _, pl in ipairs(GetActivePlayers()) do
        local sid = GetPlayerServerId(pl)
        local st = Player(sid).state
        if pl ~= cache.playerId and st.exti_heldBy == me then
            return { kind = 'player', id = sid, ped = GetPlayerPed(pl), h = { by = st.exti_tied, blind = st.exti_blind, prone = st.exti_prone, escort = me }, tied = true }
        end
    end
    if cache.vehicle then return nil end
    -- 2. the closest within reach
    local best, bd = nil, 2.3
    for net, h in pairs(npcs) do
        local ped = HC.hostagePed(net)
        if ped and not h.veh then
            local d = #(GetEntityCoords(ped) - myPos)
            if d < bd then best, bd = { kind = 'npc', id = net, ped = ped, h = h, tied = true }, d end
        end
    end
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= cache.playerId then
            local ped = GetPlayerPed(pl)
            local sid = GetPlayerServerId(pl)
            local st = Player(sid).state
            if ped ~= 0 and not IsPedInAnyVehicle(ped, false) then
                local d = #(GetEntityCoords(ped) - myPos)
                if d < bd then
                    if st.exti_tied then
                        best, bd = { kind = 'player', id = sid, ped = ped, h = { by = st.exti_tied, blind = st.exti_blind, prone = st.exti_prone, escort = st.exti_heldBy }, tied = true }, d
                    elseif st.handsup == true and not down(ped) and not st.cuffed then
                        best, bd = { kind = 'player', id = sid, ped = ped, tied = false }, d
                    end
                end
            end
        end
    end
    if not isCop() then
        for _, ped in ipairs(GetGamePool('CPed')) do
            if ped ~= cache.ped and HC.covered(ped) and HC.canCover(ped) then
                local d = #(GetEntityCoords(ped) - myPos)
                if d < bd and not (HC.netOf(ped) and npcs[HC.netOf(ped)]) then best, bd = { kind = 'npc', ped = ped, tied = false, cover = HC.covered(ped) }, d end
            end
        end
    end
    if best then return best end
    -- 3. a hostage sitting in the car next to me
    local veh = lib.getClosestVehicle(myPos, 4.0, false)
    if veh then
        for net, h in pairs(npcs) do
            if h.veh and NetworkDoesNetworkIdExist(h.veh) and NetworkGetEntityFromNetworkId(h.veh) == veh then
                local ped = HC.hostagePed(net)
                if ped then return { kind = 'npc', id = net, ped = ped, h = h, tied = true, inCar = true } end
            end
        end
        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and IsPedAPlayer(ped) and ped ~= cache.ped then
                local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
                local st = Player(sid).state
                if st.exti_tied then return { kind = 'player', id = sid, ped = ped, h = { by = st.exti_tied, blind = st.exti_blind }, tied = true, inCar = true } end
            end
        end
    end
    return nil
end

local function ev(action, t) return { name = 'exti_heists:client:radial', data = { action, t.kind, t.id } } end

exports('RadialMenu', function()
    local t = HC.radialTarget()
    if not t then return nil end
    local items = {}
    local cop = isCop()
    if not t.tied then
        if cop then return nil end
        items[#items + 1] = { id = 'tie', label = HC.count('zip_ties') > 0 and 'قيّده' or 'قيّده (لا أربطة معك)', icon = 'handcuffs',
            action = 'event', arg = { name = 'exti_heists:client:radialTie', data = { t.kind, t.id or HC.netOf(t.ped) } }, disabled = HC.count('zip_ties') < 1 }
        if t.kind == 'npc' then
            local net = HC.netOf(t.ped)
            if t.cover == 'prone' then items[#items + 1] = { id = 'up', label = 'قف (ارفع يديك)', icon = 'person-circle-check', action = 'event', arg = { name = 'exti_heists:client:radialCover', data = { net, 'up' } } }
            else items[#items + 1] = { id = 'prone', label = 'انبطح أرضًا', icon = 'person-circle-xmark', action = 'event', arg = { name = 'exti_heists:client:radialCover', data = { net, 'prone' } } } end
        end
        return { label = 'الرهينة', icon = 'hands-holding', items = items }
    end
    local h = t.h or {}
    local mine = h.by == cache.serverId or h.escort == cache.serverId
    if mine and not cop then
        items[#items + 1] = { id = 'free', label = 'أطلق سراحه', icon = 'person-running', action = 'event', arg = ev('free', t) }
        items[#items + 1] = { id = 'blind', label = h.blind and 'انزع الكيس' or 'ضع الكيس على رأسه', icon = h.blind and 'eye' or 'eye-slash',
            action = 'event', arg = ev(h.blind and 'unblind' or 'blind', t), disabled = not h.blind and HC.count('blindfold') < 1 }
        if t.inCar then
            -- (in the car: out first, then the rest; letting him go is on the list above)
            items[#items + 1] = { id = 'carOut', label = 'أخرجه من المركبة', icon = 'door-open', action = 'event', arg = ev('carOut', t) }
        else
            items[#items + 1] = { id = 'escort', label = h.escort == cache.serverId and 'اتركه هنا' or 'خذه معك', icon = h.escort == cache.serverId and 'hand' or 'person-walking-arrow-right',
                action = 'event', arg = ev('escort', t) }
            items[#items + 1] = { id = 'prone', label = h.prone and 'قف (على ركبتيك)' or 'انبطح أرضًا', icon = h.prone and 'person-circle-check' or 'person-circle-xmark',
                action = 'event', arg = ev(h.prone and 'up' or 'prone', t), disabled = h.escort ~= nil }
            local near = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
            items[#items + 1] = { id = 'carIn', label = 'أدخله المركبة', icon = 'car', action = 'event', arg = ev('carIn', t), disabled = not near }
        end
    else
        -- an officer / anyone else: cut him free, take the sack off
        items[#items + 1] = { id = 'free', label = 'فك الرباط', icon = 'lock-open', action = 'event', arg = ev('free', t) }
        if h.blind then items[#items + 1] = { id = 'unblind', label = 'انزع الكيس', icon = 'eye', action = 'event', arg = ev('unblind', t) } end
    end
    return { label = 'الرهينة', icon = 'hands-holding', items = items }
end)

---------------------------------------------------------------------------
-- what the wheel picked
---------------------------------------------------------------------------
local working = false

-- tie him (an NPC with his hands up or on the floor, a player with his hands up)
AddEventHandler('exti_heists:client:radialTie', function(kind, id)
    if working or not id then return end
    working = true
    local ped
    if kind == 'npc' then ped = NetworkDoesNetworkIdExist(id) and NetworkGetEntityFromNetworkId(id) or nil
    else local pl = GetPlayerFromServerId(id); ped = pl ~= -1 and GetPlayerPed(pl) or nil end
    if not ped or ped == 0 then working = false return end
    local ok, token = lib.callback.await('exti_heists:server:tieBegin', false, kind, id)
    if not ok then working = false; if token then HC.notify(token, 'error') end return end
    TaskTurnPedToFaceEntity(cache.ped, ped, 700); Wait(700)
    local done = lib.progressCircle({ duration = HG.tieSeconds * 1000, label = 'تقيّده...', position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 } })
    if done and kind == 'npc' then
        -- (he must be ours and kept, or the game takes him back)
        if DoesEntityExist(ped) and HC.takeControl(ped, 1500) then
            SetEntityAsMissionEntity(ped, true, true)
            SetNetworkIdCanMigrate(id, true)
        else done = false end
    end
    local res, info = lib.callback.await('exti_heists:server:tieEnd', false, token, done == true)
    if res then
        HC.notify(('قيّدته · معك %d %s'):format(info, info == 1 and 'رهينة' or 'رهائن'), 'success')
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    elseif done then
        if kind == 'npc' and DoesEntityExist(ped) then SetBlockingOfNonTemporaryEvents(ped, false); SetPedAsNoLongerNeeded(ped) end
        HC.notify(type(info) == 'string' and info or 'لا تستطيع تقييده', 'error')
    end
    working = false
end)

-- an untied NPC: down on the floor / up again
AddEventHandler('exti_heists:client:radialCover', function(net, what)
    local ped = net and NetworkDoesNetworkIdExist(net) and NetworkGetEntityFromNetworkId(net)
    if not ped or ped == 0 then return end
    if what == 'up' then HC.coverUp(ped) else HC.coverProne(ped) end
end)

local DONE = {
    free = 'أطلقت سراحه', blind = 'وضعت الكيس على رأسه', unblind = 'نزعت الكيس',
    carIn = 'أدخلته المركبة', carOut = 'أخرجته من المركبة',
}
AddEventHandler('exti_heists:client:radial', function(action, kind, id)
    if working then return end
    working = true
    local extra
    if action == 'carIn' then
        local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
        if not veh then working = false; return HC.notify('لا توجد مركبة قريبة', 'error') end
        -- a free seat this car really has: the back first, then the front passenger
        local max, seat = GetVehicleMaxNumberOfPassengers(veh), nil
        for _, s in ipairs({ 1, 2, 0 }) do if s < max and IsVehicleSeatFree(veh, s) then seat = s break end end
        if not seat then working = false; return HC.notify('المركبة ممتلئة', 'error') end
        extra = { net = NetworkGetNetworkIdFromEntity(veh), seat = seat }
    end
    -- the hands: a short tie/untie movement (the sack, the ties)
    if action == 'free' or action == 'blind' or action == 'unblind' then
        local ok = lib.progressCircle({ duration = action == 'free' and 2500 or 2000, label = action == 'free' and 'تفك الرباط...' or 'الكيس...',
            position = 'bottom', canCancel = true, disable = { move = true, car = true, combat = true },
            anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 } })
        if not ok then working = false return end
    end
    local ok, info = lib.callback.await('exti_heists:server:hostageAct', false, action, kind, id, extra)
    if ok then
        if action == 'free' and type(info) == 'number' and info > 0 then HC.notify(('حرّرت رهينة · مكافأة $%d'):format(info), 'success')
        elseif action == 'escort' then HC.notify(info and 'تقوده معك' or 'تركته هنا', 'inform')
        elseif DONE[action] then HC.notify(DONE[action], 'inform') end
    elseif type(info) == 'string' then
        HC.notify(info, 'error')
    end
    working = false
end)
