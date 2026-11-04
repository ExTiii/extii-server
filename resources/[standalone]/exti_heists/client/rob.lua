-- =====================================================================
-- EX_Tii heists (game side): robbing a PLAYER (Z wheel → فتّشه). The server decides everything
-- (server/rob.lua); this only finds who is next to me, plays the search and opens nothing by itself.
-- =====================================================================
local R = Config.rob
local SEARCH = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search' }

local function isCop()
    local j = QBX and QBX.PlayerData and QBX.PlayerData.job
    return j ~= nil and j.name == Config.cops.job and j.onduty == true
end
local function down(p, s)
    local ds = s and s['qbx_medical:deathState']
    return (ds ~= nil and ds ~= 1) or IsPedDeadOrDying(p, true) or GetEntityHealth(p) <= 101
end

-- someone next to me who can be searched: hands up, tied, or down (never cuffed by the police)
function HC.robTarget()
    if isCop() or cache.vehicle or HC.isDown() or LocalPlayer.state.exti_tied or LocalPlayer.state.cuffed then return nil end
    local myPos = GetEntityCoords(cache.ped)
    local best, bd = nil, R.reach
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= cache.playerId then
            local p = GetPlayerPed(pl)
            if p ~= 0 and not IsPedInAnyVehicle(p, false) then
                local d = #(GetEntityCoords(p) - myPos)
                if d < bd then
                    local sid = GetPlayerServerId(pl)
                    local s = Player(sid).state
                    if not s.cuffed and (s.handsup == true or s.exti_tied or down(p, s)) then best, bd = sid, d end
                end
            end
        end
    end
    return best
end

function HC.robItem(sid)
    return { id = 'rob', label = 'فتّشه', icon = 'magnifying-glass', action = 'event', arg = { name = 'exti_heists:client:rob', data = { sid } } }
end

local robbing = false
AddEventHandler('exti_heists:client:rob', function(sid)
    if robbing or not sid then return end
    robbing = true
    local ok, token = lib.callback.await('exti_heists:server:robBegin', false, sid)
    if not ok then robbing = false; if token then HC.notify(token, 'error') end return end
    local pl = GetPlayerFromServerId(sid)
    local p = pl ~= -1 and GetPlayerPed(pl) or 0
    if p ~= 0 then TaskTurnPedToFaceEntity(cache.ped, p, 600); Wait(600) end
    local done = lib.progressCircle({ duration = R.searchSeconds * 1000, label = 'تفتّشه...', position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { dict = SEARCH.dict, clip = SEARCH.clip, flag = 49 } })
    if done then
        local res, why = lib.callback.await('exti_heists:server:robOpen', false, token)
        if not res and why then HC.notify(why, 'error') end
    end
    robbing = false
end)

-- me: someone is going through my bag (my own bag stays shut until he is done)
RegisterNetEvent('exti_heists:client:robbed', function(on)
    if on then
        LocalPlayer.state:set('invBusy', true, false)
        pcall(function() exports.ox_inventory:closeInventory() end)
    else
        -- tied or cuffed: those keep the bag shut themselves
        local keep = LocalPlayer.state.exti_tied ~= nil or LocalPlayer.state.cuffed == true
        LocalPlayer.state:set('invBusy', keep, false)
    end
end)
