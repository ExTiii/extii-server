-- =====================================================================
-- EX_Tii heists (game side): a PLAYER held hostage, and hands up for everyone.
--   * X (or the wheel): hands up / down. Only a player with his hands up can be zip tied by a robber.
--   * tied: hands behind the back, no running, jumping, fighting, guns, bag, phone, wheel, getting in
--     or out of a car on your own. You can still talk.
--   * the sack over the head: the screen is black, no map.
--   * flat on the floor: you don't move. Walked: you're held by the robber. In a car: you sit there.
-- The server sets the state bags (exti_tied, exti_blind, exti_prone, exti_heldBy); this game shows them.
-- =====================================================================
local C = Config
local HG = C.hostages

local function myBag() return ('player:%s'):format(cache.serverId) end
local function pedOfServerId(s)
    if not s then return nil end
    local pl = GetPlayerFromServerId(s)
    if pl == -1 or pl == cache.playerId or not NetworkIsPlayerActive(pl) then return nil end
    local ped = GetPlayerPed(pl)
    return (ped ~= 0 and DoesEntityExist(ped)) and ped or nil
end
local function phoneOff(off)
    pcall(function()
        if off and exports.npwd:isPhoneVisible() then exports.npwd:setPhoneVisible(false) end
        exports.npwd:setPhoneDisabled(off)
    end)
end

---------------------------------------------------------------------------
-- hands up (X)
---------------------------------------------------------------------------
local up = false
local HANDS = { 'missminuteman_1ig_2', 'handsup_base' }
local function setHands(on)
    if on == up then return end
    up = on
    LocalPlayer.state:set('handsup', on, true)
    if on then
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
        CreateThread(function()
            lib.requestAnimDict(HANDS[1])
            while up do
                if cache.vehicle or HC.isDown() or LocalPlayer.state.exti_tied or LocalPlayer.state.cuffed then break end
                if not IsEntityPlayingAnim(cache.ped, HANDS[1], HANDS[2], 3) then
                    TaskPlayAnim(cache.ped, HANDS[1], HANDS[2], 4.0, 4.0, -1, 49, 0.0, false, false, false)
                end
                DisablePlayerFiring(cache.playerId, true)
                for _, c in ipairs({ 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }) do DisableControlAction(0, c, true) end
                Wait(0)
            end
            if up then up = false; LocalPlayer.state:set('handsup', false, true) end
            if IsEntityPlayingAnim(cache.ped, HANDS[1], HANDS[2], 3) then StopAnimTask(cache.ped, HANDS[1], HANDS[2], 1.0) end
        end)
    end
end
-- EX_Tii: X also cancels a progress bar (ox_lib). Both run on the same key press, in any order: if the cancel
-- runs first the bar is already gone, so we remember when a bar was last on screen and ignore X right after it
local lastProgress = 0
CreateThread(function()
    while true do
        if lib.progressActive() then lastProgress = GetGameTimer() end
        Wait(50)
    end
end)
RegisterCommand('handsup', function()
    if lib.progressActive() or GetGameTimer() - lastProgress < 400 then return end
    if LocalPlayer.state.exti_tied or LocalPlayer.state.cuffed or cache.vehicle or HC.isDown() or IsNuiFocused() then return end
    setHands(not up)
end, false)
RegisterKeyMapping('handsup', 'ارفع يديك', 'keyboard', 'X')
SetTimeout(500, function() LocalPlayer.state:set('handsup', false, true) end)
function HC.handsUp() return up end
function HC.toggleHands() ExecuteCommand('handsup') end

---------------------------------------------------------------------------
-- tied
---------------------------------------------------------------------------
local tied, blind, prone, heldBy = false, false, false, nil
local TIED = { 'mp_arresting', 'idle' }
local PRONE = { 'amb@world_human_sunbathe@male@front@base', 'base' }
local BLOCK = { 21, 22, 23, 24, 25, 36, 37, 44, 45, 47, 58, 75, 140, 141, 142, 143, 199, 257, 263, 264, 288, 289, 170, 167 }
local MOVE = { 30, 31, 32, 33, 34, 35 }

local function tiedLoop()
    CreateThread(function()
        lib.requestAnimDict(TIED[1]); lib.requestAnimDict(PRONE[1])
        local lastHp = GetEntityHealth(cache.ped)
        local nextHurt = 0
        while tied do
            local ped = cache.ped
            if not cache.vehicle and not HC.isDown() then
                local a = prone and PRONE or TIED
                if not IsEntityPlayingAnim(ped, a[1], a[2], 3) then
                    TaskPlayAnim(ped, a[1], a[2], 8.0, -8.0, -1, prone and 1 or 49, 0.0, false, false, false)
                end
            end
            for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end
            if prone or heldBy then for i = 1, #MOVE do DisableControlAction(0, MOVE[i], true) end end
            DisablePlayerFiring(cache.playerId, true)
            if blind then
                HideHudAndRadarThisFrame()
                DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255)
            end
            -- hurt by someone (a weapon or a fist): the server checks it
            local hp = GetEntityHealth(ped)
            if hp < lastHp - 5 and GetGameTimer() > nextHurt and HasPedBeenDamagedByWeapon(ped, 0, 2) then
                local who
                for _, pl in ipairs(GetActivePlayers()) do
                    local pp = GetPlayerPed(pl)
                    if pl ~= cache.playerId and pp ~= 0 and HasEntityBeenDamagedByEntity(ped, pp, true) then who = GetPlayerServerId(pl) break end
                end
                ClearEntityLastDamageEntity(ped); ClearPedLastWeaponDamage(ped)
                nextHurt = GetGameTimer() + 1000
                TriggerServerEvent('exti_heists:server:captiveHurt', who)
            end
            lastHp = hp
            Wait(0)
        end
        local ped = cache.ped
        for _, a in ipairs({ TIED, PRONE }) do if IsEntityPlayingAnim(ped, a[1], a[2], 3) then StopAnimTask(ped, a[1], a[2], 1.0) end end
    end)
end

local function setTied(on)
    if on == tied then return end
    tied = on
    SetEnableHandcuffs(cache.ped, on)
    SetPedCanPlayGestureAnims(cache.ped, not on)
    LocalPlayer.state:set('invBusy', on, false)
    if on then
        setHands(false)
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
        pcall(function() exports.ox_inventory:closeInventory() end)
        phoneOff(true)
        tiedLoop()
    else
        phoneOff(false)
        blind, prone = false, false
        if heldBy then heldBy = nil; DetachEntity(cache.ped, true, false) end
    end
end

-- walked by the robber: held at his side
local function holdLoop()
    CreateThread(function()
        local missing = 0
        while heldBy and tied do
            if cache.vehicle then break end
            local by = pedOfServerId(heldBy)
            if not by then
                missing = missing + 1
                if missing >= 6 then break end
            else
                missing = 0
                if not IsEntityAttachedToEntity(cache.ped, by) then
                    AttachEntityToEntity(cache.ped, by, 11816, 0.38, 0.48, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
                end
            end
            Wait(400)
        end
        if IsEntityAttached(cache.ped) and not cache.vehicle then DetachEntity(cache.ped, true, false) end
    end)
end

AddStateBagChangeHandler('exti_tied', nil, function(bag, _, v) if bag == myBag() then setTied(v ~= nil and v ~= false) end end)
AddStateBagChangeHandler('exti_blind', nil, function(bag, _, v) if bag == myBag() then blind = v == true end end)
AddStateBagChangeHandler('exti_prone', nil, function(bag, _, v)
    if bag ~= myBag() then return end
    prone = v == true
    ClearPedTasks(cache.ped)
end)
AddStateBagChangeHandler('exti_heldBy', nil, function(bag, _, v)
    if bag ~= myBag() then return end
    local by = type(v) == 'number' and v or nil
    if by and heldBy ~= by then heldBy = by; holdLoop()
    elseif not by and heldBy then heldBy = nil; DetachEntity(cache.ped, true, false) end
end)
-- (a script restart or a late join: read what's already set)
SetTimeout(1200, function()
    local st = LocalPlayer.state
    if st.exti_tied then setTied(true) end
    blind, prone = st.exti_blind == true, st.exti_prone == true
    if type(st.exti_heldBy) == 'number' then heldBy = st.exti_heldBy; holdLoop() end
end)
AddEventHandler('QBCore:Client:OnPlayerUnload', function() setTied(false); setHands(false) end)

function HC.amTied() return tied end

-- being tied right now: stand still
RegisterNetEvent('exti_heists:client:beingTied', function(by, seconds)
    if not by then return end
    local untilT = GetGameTimer() + (seconds or 4) * 1000 + 500
    local other = pedOfServerId(by)
    if other then TaskTurnPedToFaceEntity(cache.ped, other, 600) end
    CreateThread(function()
        while GetGameTimer() < untilT and not tied do
            for i = 1, #MOVE do DisableControlAction(0, MOVE[i], true) end
            for _, c in ipairs({ 21, 22, 23, 24, 25, 140, 141, 142 }) do DisableControlAction(0, c, true) end
            DisablePlayerFiring(cache.playerId, true)
            Wait(0)
        end
    end)
end)

-- put in a car / taken out
RegisterNetEvent('exti_heists:client:captiveCar', function(netId, seat)
    if not tied then return end
    if netId then
        local veh = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId)
        if not veh or veh == 0 then return TriggerServerEvent('exti_heists:server:captiveOutOfCar') end
        if heldBy then DetachEntity(cache.ped, true, false) end
        ClearPedTasksImmediately(cache.ped)
        TaskWarpPedIntoVehicle(cache.ped, veh, seat or 1)
        -- (sat in it: if the car goes or he falls out, the server hears it)
        CreateThread(function()
            Wait(2000)
            while tied and LocalPlayer.state.exti_tied do
                if not cache.vehicle then TriggerServerEvent('exti_heists:server:captiveOutOfCar') break end
                Wait(1000)
            end
        end)
    else
        local veh = cache.vehicle
        if not veh then return end
        TaskLeaveVehicle(cache.ped, veh, 16)
        SetTimeout(1500, function()
            if cache.vehicle == veh then
                local c = GetOffsetFromEntityInWorldCoords(veh, -2.0, 0.0, 0.0)
                SetEntityCoords(cache.ped, c.x, c.y, c.z, false, false, false, false)
            end
        end)
    end
end)

RegisterNetEvent('exti_heists:client:captiveFree', function()
    setTied(false)
    HC.notify('أنت حر', 'success')
end)

---------------------------------------------------------------------------
-- the robber's side: aiming again at a tied player who's on his knees puts him on the floor
---------------------------------------------------------------------------
function HC.aimAtPlayer(ped, fresh)
    if not fresh then return end
    local pl = NetworkGetPlayerIndexFromPed(ped); if pl == -1 then return end
    local sid = GetPlayerServerId(pl)
    local st = Player(sid).state
    if st.exti_tied == cache.serverId and not st.exti_prone and not st.exti_heldBy and not IsPedInAnyVehicle(ped, false) then
        CreateThread(function() lib.callback.await('exti_heists:server:hostageAct', false, 'prone', 'player', sid, 'aim') end)
    end
end
