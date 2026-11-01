-- =====================================================================
-- EX_Tii EMS: stretcher and wheelchair (medics on duty).
-- The medic pushes it, puts a patient on it, loads the stretcher into the back of an
-- ambulance, takes it out again, puts the patient on a hospital bed or in a car seat.
-- The server keeps who pushes what and who lies / sits on what.
-- =====================================================================

EMS = EMS or {}
local EQ = Config.equipment
local pushing      -- { netId, kind } what I am pushing
local mounted      -- { netId, kind } what I am lying / sitting on (as the patient)
local menuOpen = false

function EMS.isPushing() return pushing ~= nil end

local MODELS = {}
for kind, e in pairs(EQ) do
    if type(e) == 'table' and e.model then MODELS[joaat(e.model)] = kind end
end
local AMBULANCES = {}
for _, m in ipairs(EQ.ambulances or {}) do AMBULANCES[m] = true end

local function entityOf(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return nil end
    local e = NetworkGetEntityFromNetworkId(netId)
    if e ~= 0 and DoesEntityExist(e) then return e end
end

local function control(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    local untilAt = GetGameTimer() + 2000
    repeat
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    until NetworkHasControlOfEntity(entity) or GetGameTimer() > untilAt
    return NetworkHasControlOfEntity(entity)
end

local function playPushAnim()
    local a = EQ.pushAnim
    if not IsEntityPlayingAnim(cache.ped, a.dict, a.clip, 3) then
        lib.requestAnimDict(a.dict, 3000)
        TaskPlayAnim(cache.ped, a.dict, a.clip, 8.0, 8.0, -1, 49, 0, false, false, false)
    end
end

local function stopPushAnim()
    local a = EQ.pushAnim
    if IsEntityPlayingAnim(cache.ped, a.dict, a.clip, 3) then StopAnimTask(cache.ped, a.dict, a.clip, 2.0) end
end

local function attachToMe(entity, kind)
    local o = EQ[kind].push
    AttachEntityToEntity(entity, cache.ped, 0, o.pos.x, o.pos.y, o.pos.z, o.rot.x, o.rot.y, o.rot.z, false, false, false, false, 2, true)
end

local function startPushing(netId, entity, kind)
    if not control(entity) then return EMS.error('failed') end
    FreezeEntityPosition(entity, false)
    DetachEntity(entity, true, false)
    attachToMe(entity, kind)
    pushing = { netId = netId, kind = kind }
    playPushAnim()
end

local function letGo(placeOnGround)
    if not pushing then return end
    local entity = entityOf(pushing.netId)
    pushing = nil
    stopPushAnim()
    if entity and control(entity) then
        DetachEntity(entity, true, false)
        if placeOnGround ~= false then
            PlaceObjectOnGroundProperly(entity)
            FreezeEntityPosition(entity, true)
        end
    end
end

---------------------------------------------------------------------------
-- taking one out (garage or the back of an ambulance)
---------------------------------------------------------------------------
function EMS.takeEquipment(kind)
    if pushing then return EMS.notify('error', 'أنت تدفع شيئًا بالفعل') end
    if not EMS.onDuty() then return EMS.error('off_duty') end
    local model = joaat(EQ[kind].model)
    if not pcall(lib.requestModel, model, 5000) then return EMS.error('failed') end
    local p = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.4, -0.5)
    local entity = CreateObject(model, p.x, p.y, p.z, true, true, false)
    SetModelAsNoLongerNeeded(model)
    if not entity or entity == 0 then return EMS.error('failed') end
    local found, netId = pcall(lib.waitFor, function()
        if NetworkGetEntityIsNetworked(entity) then return NetworkGetNetworkIdFromEntity(entity) end
    end, nil, 3000)
    if not found or not netId then DeleteEntity(entity) return EMS.error('failed') end
    SetNetworkIdCanMigrate(netId, true)
    if not lib.callback.await('exti_ems:server:registerEquipment', false, netId, kind) then
        DeleteEntity(entity)
        return EMS.error('failed')
    end
    startPushing(netId, entity, kind)
    EMS.notify('inform', ('معك %s: اضغط E للخيارات'):format(EQ[kind].label))
end

---------------------------------------------------------------------------
-- what's around
---------------------------------------------------------------------------
local nearbyCache = { at = 0 }

-- a stretcher / wheelchair lying around (not pushed, not in a car)
local function looseEquipment(p)
    local now = GetGameTimer()
    if now - nearbyCache.at < 300 then return nearbyCache.entity, nearbyCache.kind end
    nearbyCache.at = now
    nearbyCache.entity, nearbyCache.kind = nil, nil
    local best
    for _, obj in ipairs(GetGamePool('CObject')) do
        local kind = MODELS[GetEntityModel(obj)]
        if kind and NetworkGetEntityIsNetworked(obj) and not IsEntityAttached(obj) then
            local d = #(p - GetEntityCoords(obj))
            if d < 2.2 and (not best or d < best) then
                best, nearbyCache.entity, nearbyCache.kind = d, obj, kind
            end
        end
    end
    return nearbyCache.entity, nearbyCache.kind
end

-- the back doors of an ambulance next to you
local function ambulanceBehind(p)
    local veh = lib.getClosestVehicle(p, 7.0, false)
    if not veh or not AMBULANCES[GetEntityModel(veh)] then return end
    local min = GetModelDimensions(GetEntityModel(veh))
    local rear = GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.6, 0.0)
    if #(p.xy - rear.xy) < 1.9 then return veh end
end

-- the stretcher inside this ambulance (if any)
local function loadedStretcher(veh)
    for _, obj in ipairs(GetGamePool('CObject')) do
        if MODELS[GetEntityModel(obj)] == 'stretcher' and IsEntityAttachedToEntity(obj, veh) then return obj end
    end
end

local function closestOtherPlayer(maxDist)
    local player, ped = lib.getClosestPlayer(GetEntityCoords(cache.ped), maxDist or Config.reach, false)
    if not player then return end
    return GetPlayerServerId(player), ped
end

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------
local function act(netId, action, arg)
    local ok, err = lib.callback.await('exti_ems:server:equipment', false, netId, action, arg)
    if not ok then EMS.error(err) end
    return ok
end

local function grab(entity, kind)
    if not NetworkGetEntityIsNetworked(entity) then return end
    if not control(entity) then return EMS.error('taken') end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if act(netId, 'push') then startPushing(netId, entity, kind) end
end

local function loadInto(veh)
    if not pushing then return end
    local netId = pushing.netId
    local entity = entityOf(netId)
    if not entity then return end
    if not act(netId, 'load', NetworkGetNetworkIdFromEntity(veh)) then return end
    pushing = nil
    stopPushAnim()
    if control(entity) then
        local o = EQ.stretcher.vehicle
        DetachEntity(entity, true, false)
        AttachEntityToEntity(entity, veh, 0, o.pos.x, o.pos.y, o.pos.z, o.rot.x, o.rot.y, o.rot.z, false, false, false, false, 2, true)
    end
    SetVehicleDoorShut(veh, 2, false)
    SetVehicleDoorShut(veh, 3, false)
    EMS.notify('success', 'النقالة داخل سيارة الإسعاف')
end

local function unloadFrom(veh)
    if pushing then return EMS.notify('error', 'أنت تدفع شيئًا بالفعل') end
    local entity = loadedStretcher(veh)
    if not entity or not NetworkGetEntityIsNetworked(entity) then return EMS.notify('error', 'لا توجد نقالة في السيارة') end
    if not control(entity) then return EMS.error('failed') end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    SetVehicleDoorOpen(veh, 2, false, false)
    SetVehicleDoorOpen(veh, 3, false, false)
    if act(netId, 'unload') then startPushing(netId, entity, 'stretcher') end
end

local function openAmbulanceMenu(veh)
    local options = {}
    -- one of the team's vehicles: its own trunk (what you left in it last shift is still there)
    if Entity(veh).state.exti_ems_fleet and EMS.openFleetTrunk then
        options[#options + 1] = { title = 'صندوق المركبة', icon = 'box-open', iconColor = '#e8b547', description = 'المستلزمات المحفوظة في هذه السيارة',
            onSelect = function() EMS.openFleetTrunk(veh) end }
    end
    if loadedStretcher(veh) then
        options[#options + 1] = { title = 'أنزل النقالة', icon = 'bed', description = 'تخرجها مع المريض الذي عليها', onSelect = function() unloadFrom(veh) end }
    else
        options[#options + 1] = { title = 'أخرج نقالة', icon = 'bed', onSelect = function() SetVehicleDoorOpen(veh, 2, false, false) SetVehicleDoorOpen(veh, 3, false, false) EMS.takeEquipment('stretcher') end }
    end
    options[#options + 1] = { title = 'أخرج كرسيًا متحركًا', icon = 'wheelchair', onSelect = function() EMS.takeEquipment('wheelchair') end }
    lib.registerContext({ id = 'exti_ems_ambulance', title = 'معدات سيارة الإسعاف', options = options })
    lib.showContext('exti_ems_ambulance')
end

local function openPushMenu()
    if not pushing then return end
    local netId, kind = pushing.netId, pushing.kind
    local state = lib.callback.await('exti_ems:server:equipmentState', false, netId)
    if not state then letGo() return EMS.error('gone') end
    local label = EQ[kind].label
    local p = GetEntityCoords(cache.ped)
    local options = {}

    if state.patient then
        local patient = state.patient
        options[#options + 1] = {
            title = 'افحص المريض (إنعاش / علاج)', icon = 'heart-pulse',
            description = ('تترك %s مكانها وتعتني بالمريض'):format(label),
            onSelect = function()
                if act(netId, 'release') then letGo() end
                Wait(300)
                EMS.openPatient(patient)
            end,
        }
        options[#options + 1] = { title = 'أنزل المريض', icon = 'person-walking', onSelect = function() act(netId, 'removePatient') end }
        local okBed, hospital = pcall(function() return exports.qbx_ambulancejob:GetNearestBed(p, 3.5) end)
        if okBed and hospital then
            options[#options + 1] = {
                title = 'ضع المريض على السرير', icon = 'bed-pulse',
                onSelect = function()
                    local patient = state.patient
                    if act(netId, 'removePatient') then
                        Wait(600)
                        EMS.putInBed(patient)
                    end
                end,
            }
        end
        if kind == 'wheelchair' then
            local veh = lib.getClosestVehicle(p, 5.0, false)
            if veh then
                options[#options + 1] = {
                    title = 'أجلس المريض في السيارة', icon = 'car-side',
                    onSelect = function() act(netId, 'seatPatient', NetworkGetNetworkIdFromEntity(veh)) end,
                }
            end
        end
    else
        local target = closestOtherPlayer(Config.reach + 0.5)
        options[#options + 1] = {
            title = kind == 'stretcher' and 'ضع المريض على النقالة' or 'أجلس المريض على الكرسي', icon = 'person-arrow-down-to-line',
            disabled = not target,
            description = not target and 'لا يوجد مريض بجانبك' or nil,
            onSelect = function() act(netId, 'putPatient', target) end,
        }
    end

    if kind == 'stretcher' then
        local veh = ambulanceBehind(p)
        if veh then
            options[#options + 1] = {
                title = 'أدخلها سيارة الإسعاف', icon = 'truck-medical',
                disabled = loadedStretcher(veh) ~= nil,
                description = loadedStretcher(veh) and 'في السيارة نقالة أخرى' or nil,
                onSelect = function() loadInto(veh) end,
            }
        end
    end

    options[#options + 1] = {
        title = ('اترك %s هنا'):format(label), icon = 'hand',
        onSelect = function() if act(netId, 'release') then letGo() end end,
    }
    if not state.patient then
        options[#options + 1] = {
            title = ('أعِد %s'):format(label), icon = 'rotate-left', description = 'تختفي، وتأخذ غيرها من المرآب أو سيارة الإسعاف',
            onSelect = function()
                local entity = entityOf(netId)
                if act(netId, 'store') then
                    pushing = nil
                    stopPushAnim()
                    if entity and DoesEntityExist(entity) then pcall(DeleteEntity, entity) end
                end
            end,
        }
    end
    lib.registerContext({ id = 'exti_ems_push', title = label, options = options })
    lib.showContext('exti_ems_push')
end

-- called by the main loop: what "[E]" to show for equipment (nil = nothing)
function EMS.equipmentPrompt(p)
    if not EMS.onDuty() then return end
    if pushing then
        return ('[E] خيارات %s'):format(EQ[pushing.kind].label), openPushMenu
    end
    if cache.vehicle then return end
    local entity, kind = looseEquipment(p)
    if entity then
        return ('[E] ادفع %s'):format(EQ[kind].label), function() grab(entity, kind) end
    end
    local veh = ambulanceBehind(p)
    if veh then
        return '[E] معدات سيارة الإسعاف', function() openAmbulanceMenu(veh) end
    end
end

-- while pushing: keep the hands on it, no running / jumping / fighting / getting in cars;
-- let go automatically if you go down, get in a car or go off duty
CreateThread(function()
    while true do
        if pushing then
            local entity = entityOf(pushing.netId)
            if not entity or EMS.isDown() or cache.vehicle or not EMS.onDuty() or not IsEntityAttachedToEntity(entity, cache.ped) then
                local netId = pushing.netId
                if entity and IsEntityAttachedToEntity(entity, cache.ped) then
                    letGo(true)
                else
                    pushing = nil -- someone else has it now (or it is gone)
                    stopPushAnim()
                end
                lib.callback.await('exti_ems:server:equipment', false, netId, 'release')
            else
                playPushAnim()
                DisableControlAction(0, 21, true) -- sprint
                DisableControlAction(0, 22, true) -- jump
                DisableControlAction(0, 23, true) -- enter vehicle
                DisableControlAction(0, 24, true) -- attack
                DisableControlAction(0, 25, true) -- aim
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- the patient's side
---------------------------------------------------------------------------
local function attachMe(entity, kind)
    local o = EQ[kind].patient
    AttachEntityToEntity(cache.ped, entity, 0, o.pos.x, o.pos.y, o.pos.z, o.rot.x, o.rot.y, o.rot.z, false, false, false, false, 2, true)
end

local function playPatientAnim(kind)
    if EMS.isDown() then return end -- down: the "lying hurt" animation of qbx_medical stays
    local o = EQ[kind].patient
    if not IsEntityPlayingAnim(cache.ped, o.dict, o.clip, 3) then
        lib.requestAnimDict(o.dict, 3000)
        TaskPlayAnim(cache.ped, o.dict, o.clip, 8.0, 8.0, -1, 1, 0, false, false, false)
    end
end

RegisterNetEvent('exti_ems:client:mount', function(netId, kind)
    if not EQ[kind] or not EQ[kind].model then return end
    local found, entity = pcall(lib.waitFor, function() return entityOf(netId) end, nil, 4000)
    -- it must really be that stretcher / wheelchair
    if not found or not entity or GetEntityModel(entity) ~= joaat(EQ[kind].model) then
        TriggerServerEvent('exti_ems:server:leftEquipment')
        return
    end
    mounted = { netId = netId, kind = kind }
    attachMe(entity, kind)
    playPatientAnim(kind)
    if not EMS.isDown() then EMS.notify('inform', ('أنت على %s. اضغط X للنزول'):format(EQ[kind].label)) end
end)

RegisterNetEvent('exti_ems:client:dismount', function(vehNet, stay)
    if not mounted then return end
    local kind, netId = mounted.kind, mounted.netId
    mounted = nil
    DetachEntity(cache.ped, true, false)
    local o = EQ[kind].patient
    if IsEntityPlayingAnim(cache.ped, o.dict, o.clip, 3) then StopAnimTask(cache.ped, o.dict, o.clip, 2.0) end
    if stay then return end -- being put in a hospital bed / respawned: someone else moves you
    local entity = entityOf(netId)
    if entity then
        local side = GetOffsetFromEntityInWorldCoords(entity, 1.0, 0.0, 0.0)
        SetEntityCoords(cache.ped, side.x, side.y, side.z, false, false, false, false)
    end
    if vehNet then
        local veh = entityOf(vehNet)
        if veh then
            for seat = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                if IsVehicleSeatFree(veh, seat) then
                    TaskWarpPedIntoVehicle(cache.ped, veh, seat)
                    break
                end
            end
        end
    end
end)

-- stay on it (and keep the pose) until the medic takes you off; X gets you off a wheelchair
CreateThread(function()
    while true do
        if mounted then
            local entity = entityOf(mounted.netId)
            if entity then
                if not IsEntityAttachedToEntity(cache.ped, entity) then attachMe(entity, mounted.kind) end
                playPatientAnim(mounted.kind)
                if not EMS.isDown() and IsControlJustPressed(0, 73) then
                    TriggerServerEvent('exti_ems:server:leaveEquipment')
                end
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 23, true)
                DisableControlAction(0, 24, true)
                Wait(0)
            else
                Wait(500)
            end
        else
            Wait(800)
        end
    end
end)

-- put in a hospital bed (by a medic, the reception, or after dying), or leaving the city:
-- off the stretcher / wheelchair right away, without moving
local function leaveQuietly()
    if mounted then
        mounted = nil
        DetachEntity(cache.ped, true, false)
        TriggerServerEvent('exti_ems:server:leftEquipment')
    end
end
RegisterNetEvent('qbx_ambulancejob:client:checkedIn', leaveQuietly)
RegisterNetEvent('qbx_ambulancejob:client:putPlayerInBed', leaveQuietly)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    leaveQuietly()
    if pushing then
        local entity = entityOf(pushing.netId)
        pushing = nil
        stopPushAnim()
        if entity then DetachEntity(entity, true, false) end
    end
end)

-- after a script restart: back on the stretcher if the server says so
CreateThread(function()
    Wait(2000)
    local netId, kind = lib.callback.await('exti_ems:server:myEquipment', false)
    if netId and kind then TriggerEvent('exti_ems:client:mount', netId, kind) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if pushing then stopPushAnim() end
    if mounted then DetachEntity(cache.ped, true, false) end
end)

---------------------------------------------------------------------------
-- admins: /emstune — move the stretcher / wheelchair you are pushing (or the stretcher in the
-- ambulance next to you) with the arrow keys, Page Up / Down for height, Shift + left/right to
-- turn it. Enter prints the numbers for config.lua (F8), Backspace stops.
---------------------------------------------------------------------------
local tuning = false
RegisterNetEvent('exti_ems:client:tune', function()
    if tuning then tuning = false return end
    tuning = true
    EMS.notify('inform', 'ضبط المعدات: الأسهم للتحريك، Page Up/Down للارتفاع، Shift للتدوير، Enter للطباعة، Backspace للإنهاء')
    CreateThread(function()
        while tuning do
            Wait(0)
            local target, o, attachTo
            if pushing then
                target, o, attachTo = entityOf(pushing.netId), EQ[pushing.kind].push, cache.ped
            else
                local veh = ambulanceBehind(GetEntityCoords(cache.ped))
                local obj = veh and loadedStretcher(veh)
                if obj then target, o, attachTo = obj, EQ.stretcher.vehicle, veh end
            end
            if target and o then
                local step, shift = 0.02, IsControlPressed(0, 21)
                local x, y, z, r = o.pos.x, o.pos.y, o.pos.z, o.rot.z
                if shift then
                    if IsControlPressed(0, 174) then r = r - 1.0 end
                    if IsControlPressed(0, 175) then r = r + 1.0 end
                else
                    if IsControlPressed(0, 174) then x = x - step end
                    if IsControlPressed(0, 175) then x = x + step end
                end
                if IsControlPressed(0, 172) then y = y + step end
                if IsControlPressed(0, 173) then y = y - step end
                if IsControlPressed(0, 10) then z = z + step end
                if IsControlPressed(0, 11) then z = z - step end
                if x ~= o.pos.x or y ~= o.pos.y or z ~= o.pos.z or r ~= o.rot.z then
                    o.pos, o.rot = vec3(x, y, z), vec3(o.rot.x, o.rot.y, r)
                    if control(target) then
                        DetachEntity(target, false, false)
                        AttachEntityToEntity(target, attachTo, 0, x, y, z, o.rot.x, o.rot.y, r, false, false, false, false, 2, true)
                    end
                    Wait(30)
                end
                if IsControlJustPressed(0, 191) then
                    print(('[exti_ems] pos = vec3(%.2f, %.2f, %.2f), rot = vec3(%.1f, %.1f, %.1f)'):format(x, y, z, o.rot.x, o.rot.y, r))
                    EMS.notify('success', ('pos %.2f, %.2f, %.2f  rot %.0f (F8)'):format(x, y, z, r))
                end
            end
            DisableControlAction(0, 172, true) DisableControlAction(0, 173, true)
            DisableControlAction(0, 174, true) DisableControlAction(0, 175, true)
            if IsControlJustPressed(0, 194) then tuning = false end
        end
        EMS.notify('inform', 'انتهى الضبط')
    end)
end)
