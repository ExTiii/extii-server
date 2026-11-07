-- =====================================================================
-- EX_Tii Police (client): the street.
-- The officer's side: the "الشرطة" menu on the Z wheel next to a person (cuff / uncuff, escort,
-- in / out of a vehicle, search, seize the guns) and the cuffing animation.
-- The person's side: hands behind the back while cuffed (no running, fighting, bag, phone,
-- driving), walking attached to the officer while escorted, getting in / out of the car.
-- =====================================================================

local S = Config.street

local STREET_ERRORS = {
    nobody = 'لا يوجد أحد بجانبك',
    busy = 'انتظر لحظة',
    in_vehicle = 'ليس داخل المركبة: انزلا أولًا',
    down = 'لا يمكن تقييد شخص مصاب على الأرض',
    no_cuffs = 'ليس معك أصفاد (خذها من مستودع الأسلحة)',
    escorting = 'أنت تصطحب شخصًا آخر، اتركه أولًا',
    not_cuffed = 'قيّده أولًا',
    taken = 'شرطي آخر يصطحبه',
    no_vehicle = 'لا توجد مركبة قريبة',
    not_in_vehicle = 'ليس داخل مركبة',
    nothing = 'ليس معه أسلحة',
}
for k, v in pairs(STREET_ERRORS) do POL.ERRORS[k] = v end

local function myBag() return ('player:%s'):format(cache.serverId) end

-- the ped of another player, only when he is really around (otherwise the natives answer with yourself)
local function pedOfServerId(serverId)
    if not serverId then return nil end
    local pid = GetPlayerFromServerId(serverId)
    if pid == -1 or pid == cache.playerId or not NetworkIsPlayerActive(pid) then return nil end
    local ped = GetPlayerPed(pid)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

---------------------------------------------------------------------------
-- being cuffed
---------------------------------------------------------------------------
local amCuffed = false
local CUFF_DICT, CUFF_ANIM = 'mp_arresting', 'idle'

-- what a cuffed person cannot do (walking is fine)
local BLOCKED = { 21, 22, 23, 24, 25, 36, 37, 44, 45, 47, 58, 75, 140, 141, 142, 143, 257, 263, 264 }

local function phoneOff(off)
    pcall(function()
        if off and exports.npwd:isPhoneVisible() then exports.npwd:setPhoneVisible(false) end
        exports.npwd:setPhoneDisabled(off)
    end)
end

local function cuffLoop()
    CreateThread(function()
        lib.requestAnimDict(CUFF_DICT)
        while amCuffed do
            local ped = cache.ped
            if not cache.vehicle and not IsEntityDead(ped) and not POL.isDown()
                and not IsEntityPlayingAnim(ped, CUFF_DICT, CUFF_ANIM, 3) then
                TaskPlayAnim(ped, CUFF_DICT, CUFF_ANIM, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
            DisablePlayerFiring(cache.playerId, true)
            Wait(0)
        end
    end)
end

local function applyCuffed(on)
    if amCuffed == on then return end
    amCuffed = on
    local ped = cache.ped
    SetEnableHandcuffs(ped, on)
    SetPedCanPlayGestureAnims(ped, not on)
    if on then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        pcall(function() exports.ox_inventory:closeInventory() end)
        phoneOff(true)
        cuffLoop()
    else
        phoneOff(false)
        if IsEntityPlayingAnim(ped, CUFF_DICT, CUFF_ANIM, 3) then StopAnimTask(ped, CUFF_DICT, CUFF_ANIM, 1.0) end
    end
end

AddStateBagChangeHandler('cuffed', nil, function(bag, _, value)
    if bag ~= myBag() then return end
    applyCuffed(value == true)
end)

-- a new body (character change, some respawns): the cuffs follow
lib.onCache('ped', function()
    if amCuffed then
        SetTimeout(200, function()
            SetEnableHandcuffs(cache.ped, true)
            SetPedCanPlayGestureAnims(cache.ped, false)
        end)
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(2500, function() applyCuffed(LocalPlayer.state.cuffed == true) end)
end)
-- a script restart: the server may have set the bag before this file was running
SetTimeout(1000, function() if LocalPlayer.state.cuffed == true then applyCuffed(true) end end)

-- character switch: the next character starts free
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    applyCuffed(false)
    if escortedBy then
        escortedBy = nil
        DetachEntity(cache.ped, true, false)
    end
end)

---------------------------------------------------------------------------
-- the cuffing animation (both sides)
---------------------------------------------------------------------------
local PAIR = 'mp_arrest_paired'
local cuffAnimRunning = false

RegisterNetEvent('exti_police:client:cuffAnim', function(role, turningOn, otherId)
    local ped = cache.ped
    if turningOn == nil then -- cancelled
        ClearPedTasks(ped)
        cuffAnimRunning = false
        return
    end
    cuffAnimRunning = true
    -- face each other
    local other = pedOfServerId(otherId)
    if other then
        local a, b = GetEntityCoords(ped), GetEntityCoords(other)
        SetEntityHeading(ped, GetHeadingFromVector_2d(b.x - a.x, b.y - a.y))
    end
    local ms = math.floor(S.cuffSeconds * 1000)
    if role == 'cop' then
        if turningOn then
            lib.requestAnimDict(PAIR)
            TaskPlayAnim(ped, PAIR, 'cop_p2_back_left', 8.0, -8.0, ms, 48, 0.0, false, false, false)
        else
            lib.requestAnimDict('mp_arresting')
            TaskPlayAnim(ped, 'mp_arresting', 'a_uncuff', 8.0, -8.0, ms, 48, 0.0, false, false, false)
        end
        lib.progressBar({
            duration = ms, label = turningOn and 'جارٍ التقييد...' or 'جارٍ فك القيد...',
            useWhileDead = false, canCancel = false,
            disable = { move = true, car = true, combat = true, mouse = false },
        })
    else
        if turningOn then
            lib.requestAnimDict(PAIR)
            TaskPlayAnim(ped, PAIR, 'crook_p2_back_left', 8.0, -8.0, ms, 0, 0.0, false, false, false)
        end
        -- the person cannot walk away during the animation (the server checks the distance after)
        local until_ = GetGameTimer() + ms
        CreateThread(function()
            while cuffAnimRunning and GetGameTimer() < until_ do
                DisableControlAction(0, 30, true) DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true) DisableControlAction(0, 22, true)
                DisableControlAction(0, 23, true) DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true) DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
                DisablePlayerFiring(cache.playerId, true)
                Wait(0)
            end
            cuffAnimRunning = false
        end)
    end
end)

---------------------------------------------------------------------------
-- being escorted: attached to the officer
---------------------------------------------------------------------------
local escortedBy = nil

local function attachTo(copPed)
    AttachEntityToEntity(cache.ped, copPed, 11816, 0.48, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
end

local function escortLoop()
    CreateThread(function()
        local missing = 0
        while escortedBy do
            if cache.vehicle then break end -- put in a car: the attach is over
            local copPed = pedOfServerId(escortedBy)
            if not copPed then
                missing = missing + 1
                if missing >= 4 then -- 2 s without the officer: he is gone
                    TriggerServerEvent('exti_police:server:lostEscort')
                    break
                end
            else
                missing = 0
                if not IsEntityAttachedToEntity(cache.ped, copPed) then attachTo(copPed) end
            end
            Wait(500)
        end
    end)
end

AddStateBagChangeHandler('escortedBy', nil, function(bag, _, value)
    if bag ~= myBag() then return end
    local cop = type(value) == 'number' and value or nil
    if cop and not escortedBy then
        escortedBy = cop
        escortLoop()
    elseif not cop and escortedBy then
        escortedBy = nil
        DetachEntity(cache.ped, true, false)
    end
end)

---------------------------------------------------------------------------
-- put in a vehicle / taken out (the person's game does it)
---------------------------------------------------------------------------
RegisterNetEvent('exti_police:client:enterVehicle', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if escortedBy then
        escortedBy = nil
        DetachEntity(cache.ped, true, false)
    end
    local order = { 1, 2, 0 }
    local max = GetVehicleMaxNumberOfPassengers(veh)
    for seat = 3, max - 1 do order[#order + 1] = seat end
    for _, seat in ipairs(order) do
        if seat < max and IsVehicleSeatFree(veh, seat) then
            TaskWarpPedIntoVehicle(cache.ped, veh, seat)
            return
        end
    end
    POL.notify('error', 'المركبة ممتلئة')
end)

RegisterNetEvent('exti_police:client:leaveVehicle', function()
    local veh = cache.vehicle
    if not veh then return end
    TaskLeaveVehicle(cache.ped, veh, 16)
    SetTimeout(1500, function()
        if cache.vehicle == veh then
            -- the door was stuck: step out next to the car
            local c = GetOffsetFromEntityInWorldCoords(veh, -2.0, 0.0, 0.0)
            SetEntityCoords(cache.ped, c.x, c.y, c.z, false, false, false, false)
        end
    end)
end)

---------------------------------------------------------------------------
-- the officer's side
---------------------------------------------------------------------------
local function closestPlayer(radius)
    local pc = GetEntityCoords(cache.ped)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= cache.playerId then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - pc)
                if d <= radius and (not bestD or d < bestD) then best, bestD = pid, d end
            end
        end
    end
    return best and GetPlayerServerId(best) or nil, best and GetPlayerPed(best) or nil
end

local function closestVehicle()
    if cache.vehicle then return nil end
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), S.vehicleReach, false)
    return veh and veh ~= 0 and veh or nil
end

local function act(action, target, extra)
    if cache.vehicle then return POL.error('in_vehicle') end
    local ok, err, r = lib.callback.await('exti_police:server:street', false, action, target, extra)
    if not ok then return POL.error(err) end
    if action == 'seize' then
        POL.notify('success', ('صودرت أسلحته (%d)'):format(r and r.count or 0))
    elseif action == 'escort' then
        POL.notify('inform', r and r.on and 'أنت تصطحبه' or 'تركته')
    end
end

RegisterNetEvent('exti_police:client:street', function(action, target)
    if not POL.onDuty() then return POL.error('off_duty') end
    if action == 'charge' then
        if cache.vehicle then return POL.error('in_vehicle') end
        return POL.openCharge(target)
    end
    if action == 'vehicleIn' then
        local veh = closestVehicle()
        if not veh then return POL.error('no_vehicle') end
        return act(action, target, NetworkGetNetworkIdFromEntity(veh))
    end
    act(action, target)
end)

-- the escort ends by itself when the officer gets into a car or goes down
lib.onCache('vehicle', function(value)
    if value and LocalPlayer.state.escorting then TriggerServerEvent('exti_police:server:dropEscort') end
end)
CreateThread(function()
    while true do
        Wait(1000)
        if LocalPlayer.state.escorting and POL.isDown() then TriggerServerEvent('exti_police:server:dropEscort') end
    end
end)

-- the cuffed person next to you (the one you escort first): for the prison gate
function POL.closestCuffedPlayer()
    local escorting = LocalPlayer.state.escorting
    if type(escorting) == 'number' and pedOfServerId(escorting) then return escorting end
    local pc = GetEntityCoords(cache.ped)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= cache.playerId then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and DoesEntityExist(ped) then
                local sid = GetPlayerServerId(pid)
                local st = Player(sid).state
                local d = #(GetEntityCoords(ped) - pc)
                if st and st.cuffed == true and d <= S.reach + 1.0 and (not bestD or d < bestD) then best, bestD = sid, d end
            end
        end
    end
    return best
end

-- the "الشرطة" menu of the Z wheel (exti_radial asks for it when the wheel opens)
exports('RadialMenu', function()
    -- the police slice: for every officer. Off duty: just the tablet. On duty: the tablet, and the
    -- street actions for the person next to you (greyed out when nobody is there).
    local j = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not j or j.name ~= 'police' or amCuffed or cache.vehicle then return nil end
    local items = { { id = 'tablet', label = 'التابلت', icon = 'tablet-screen-button', action = 'event', arg = { name = 'exti_police:client:tablet' } } }
    if not POL.onDuty() then
        items[#items + 1] = { id = 'duty', label = 'ابدأ الدوام من المركز', icon = 'shield-halved', disabled = true }
        return { label = 'الشرطة', icon = 'handcuffs', items = items }
    end
    -- EX_Tii (Moe): impound the car next to you (nobody needs to be there)
    if closestVehicle() then
        items[#items + 1] = { id = 'impound', label = 'حجز المركبة', icon = 'truck-pickup', action = 'event', arg = { name = 'exti_police:client:impound' } }
    end
    local target, targetPed = closestPlayer(S.reach)
    local escorting = LocalPlayer.state.escorting
    if type(escorting) == 'number' then
        target = escorting
        targetPed = pedOfServerId(escorting)
    end
    if not target or not targetPed then
        items[#items + 1] = { id = 'nobody', label = 'لا أحد بجانبك', icon = 'user', disabled = true }
        return { label = 'الشرطة', icon = 'handcuffs', items = items }
    end
    local tState = Player(target).state
    local isCuffed = tState and tState.cuffed == true
    local inVeh = IsPedInAnyVehicle(targetPed, false)
    local nearVeh = closestVehicle() ~= nil
    local amEscorting = escorting == target
    local function ev(action) return { name = 'exti_police:client:street', data = { action, target } } end
    local street = {
        { id = 'cuff', label = isCuffed and 'فك القيد' or 'تقييد', icon = isCuffed and 'lock-open' or 'handcuffs',
          action = 'event', arg = ev('cuff'), disabled = inVeh },
        { id = 'escort', label = amEscorting and 'اتركه' or 'اصطحاب', icon = amEscorting and 'hand' or 'person-walking-arrow-right',
          action = 'event', arg = ev('escort'), disabled = not isCuffed or inVeh },
        { id = 'vehicle', label = inVeh and 'إخراج من المركبة' or 'إدخال إلى المركبة', icon = inVeh and 'person-walking-arrow-right' or 'car',
          action = 'event', arg = ev(inVeh and 'vehicleOut' or 'vehicleIn'), disabled = not isCuffed or (not inVeh and not nearVeh) },
        { id = 'search', label = 'تفتيش الحقيبة', icon = 'magnifying-glass', action = 'event', arg = ev('search'), disabled = inVeh },
        { id = 'seize', label = 'مصادرة الأسلحة', icon = 'gun', action = 'event', arg = ev('seize'), disabled = not isCuffed },
        { id = 'charge', label = 'مخالفة', icon = 'file-invoice-dollar', action = 'event', arg = ev('charge'), disabled = inVeh },
    }
    for _, it in ipairs(street) do items[#items + 1] = it end
    return { label = 'الشرطة', icon = 'handcuffs', items = items }
end)

---------------------------------------------------------------------------
-- the seized items room (the evidence spot)
---------------------------------------------------------------------------
function POL.openSeized(spot)
    local ok, err = lib.callback.await('exti_police:server:openSeized', false, spot.station)
    if not ok then POL.error(err) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if amCuffed then
        amCuffed = false
        SetEnableHandcuffs(cache.ped, false)
        SetPedCanPlayGestureAnims(cache.ped, true)
        ClearPedTasks(cache.ped)
        phoneOff(false)
    end
    if escortedBy then DetachEntity(cache.ped, true, false) end
end)

---------------------------------------------------------------------------
-- EX_Tii: impound the vehicle next to you: the fee the owner pays at the impound lot, and why
---------------------------------------------------------------------------
local IMPOUND_ERR = {
    vehicle = 'لا توجد مركبة قريبة', occupied = 'أنزل من في المركبة أولًا', fleet = 'هذه مركبة من أسطول الشرطة',
    kind = 'لا يمكن حجز القوارب والطائرات من هنا', reason = 'اكتب سبب الحجز', amount = 'اختر رسوم الإفراج',
}
AddEventHandler('exti_police:client:impound', function()
    local veh = closestVehicle()
    if not veh then return POL.notify('error', IMPOUND_ERR.vehicle) end
    local plate = GetVehicleNumberPlateText(veh):match('^%s*(.-)%s*$')
    local input = lib.inputDialog(('حجز المركبة %s'):format(plate), {
        { type = 'select', label = 'رسوم الإفراج (يدفعها المالك في ساحة الحجز)', required = true, default = '1000',
          options = { { value = '500', label = '500$' }, { value = '1000', label = '1,000$' }, { value = '2500', label = '2,500$' }, { value = '5000', label = '5,000$' } } },
        { type = 'input', label = 'سبب الحجز', placeholder = 'مثال: وقوف مخالف، مركبة مستعملة في جريمة', required = true, min = 3, max = 120 },
    })
    if not input then return end
    TaskTurnPedToFaceEntity(cache.ped, veh, 600)
    local done = lib.progressCircle({
        duration = 6000, label = 'تتصل بشركة السحب...', position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'random@arrests', clip = 'generic_radio_chatter', flag = 49 },
    })
    if not done then return end
    if not DoesEntityExist(veh) then return POL.notify('error', IMPOUND_ERR.vehicle) end
    local ok, err = lib.callback.await('exti_police:server:impound', false, NetworkGetNetworkIdFromEntity(veh), tonumber(input[1]), input[2])
    if not ok then
        if IMPOUND_ERR[err] then return POL.notify('error', IMPOUND_ERR[err]) end
        return POL.error(err)
    end
    POL.notify('success', ('حُجزت المركبة %s ونُقلت إلى ساحة الحجز'):format(err.plate))
end)
