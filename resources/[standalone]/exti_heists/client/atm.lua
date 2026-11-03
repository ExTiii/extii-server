-- =====================================================================
-- EX_Tii heists (game side): the ATM pull. Hook a tow chain from a pickup to a wall ATM, floor it, the
-- ATM tears off and drags behind the truck. Unhook it somewhere quiet and drill it open.
-- =====================================================================
local C = Config
local AT = C.atm
local MODELS = {}
for _, m in ipairs(AT.models) do MODELS[#MODELS + 1] = { name = m, hash = joaat(m) } end
local TRUCK = {}
for _, m in ipairs(AT.trucks) do TRUCK[joaat(m)] = true end

local atms = GlobalState['exti_heists:atms'] or {}
AddStateBagChangeHandler('exti_heists:atms', 'global', function(_, _, v) atms = v or {} end)

local hidden = {}   -- [key] = true: the wall ATM is hidden in my game
local ripSent = {}

local function v3(t) return vec3(t.x + 0.0, t.y + 0.0, t.z + 0.0) end
local function ent(netId) if not netId then return nil end local e = NetworkGetEntityFromNetworkId(netId); return (e ~= 0 and DoesEntityExist(e)) and e or nil end

local function closestAtm(here)
    local best, bd, bm
    for _, m in ipairs(MODELS) do
        local o = GetClosestObjectOfType(here.x, here.y, here.z, 1.8, m.hash, false, false, false)
        if o ~= 0 then
            local d = #(GetEntityCoords(o) - here)
            if not bd or d < bd then best, bd, bm = o, d, m.name end
        end
    end
    return best, bm
end

local function rearOf(veh)
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, mn.y - 0.1, 0.1), mn, mx
end

---------------------------------------------------------------------------
-- the chain
---------------------------------------------------------------------------
local function hook(obj, model, veh)
    HC.prompt(nil)
    TaskTurnPedToFaceEntity(cache.ped, obj, 800); Wait(800)
    local done = lib.progressBar({
        duration = AT.hookSeconds * 1000, label = 'تربط سلسلة السحب بالجهاز...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
    })
    if not done then return end
    local p = GetEntityCoords(obj)
    local ok, why = lib.callback.await('exti_heists:server:atmHook', false, { x = p.x, y = p.y, z = p.z }, model, NetworkGetNetworkIdFromEntity(veh))
    if not ok then if why then HC.notify(why, 'error', 6000) end return end
    HC.notify('السلسلة مربوطة: ادخل الشاحنة وانطلق بقوة', 'success', 7000)
end

---------------------------------------------------------------------------
-- tearing it out and dragging it (the driver's game makes the ATM that hangs on the chain)
---------------------------------------------------------------------------
RegisterNetEvent('exti_heists:client:atmDrag', function(key)
    local a = atms[key]; if not a then return end
    local veh = ent(a.veh); if not veh then return end
    local m = joaat(a.model)
    if not pcall(lib.requestModel, m, 5000) then return end
    local _, mn = rearOf(veh)
    local obj = CreateObject(m, a.x, a.y, a.z, true, true, false)
    SetModelAsNoLongerNeeded(m)
    SetEntityAsMissionEntity(obj, true, true)
    AttachEntityToEntity(obj, veh, 0, 0.0, mn.y - 1.9, -0.35, 90.0, 0.0, 0.0, false, false, true, false, 2, true)
    TriggerServerEvent('exti_heists:server:atmObject', key, NetworkGetNetworkIdFromEntity(obj))
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.4)
    PlaySoundFromEntity(-1, 'Crash', veh, 'DLC_Exec_Office_Non_Player_Sounds', false, 0)
    HC.notify('اقتلعت الجهاز! الإنذار يرن · اسحبه بعيدًا ثم افصله واثقبه', 'warning', 9000)
end)

RegisterNetEvent('exti_heists:client:atmDetach', function(key)
    local a = atms[key]; local obj = a and ent(a.obj)
    if not obj then return end
    NetworkRequestControlOfEntity(obj)
    DetachEntity(obj, true, true)
    local p = GetEntityCoords(obj)
    SetEntityCoords(obj, p.x, p.y, p.z + 0.4, false, false, false, false)
    SetEntityRotation(obj, -90.0, 0.0, GetEntityHeading(obj), 2, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
end)

local function drop(key)
    HC.prompt(nil)
    local ok, why = lib.callback.await('exti_heists:server:atmDrop', false, key)
    if not ok then if why then HC.notify(why, 'error', 6000) end return end
    HC.notify('فصلته: الآن اثقبه', 'success')
end

local function drillIt(key, obj)
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:atmDrillBegin', false, key)
    if not ok then if token then HC.notify(token, 'error', 6000) end return end
    TaskTurnPedToFaceEntity(cache.ped, obj, 800); Wait(800)
    HC.anim(cache.ped, 'anim@heists@fleeca_bank@drilling', 'drill_straight_idle', 1)
    local passed = HC.play('drill', params, 'جهاز الصراف')
    ClearPedTasks(cache.ped)
    local res, pay = lib.callback.await('exti_heists:server:atmDrillEnd', false, token, passed)
    if res then HC.notify(('فتحته: %d$ مالًا قذرًا · اختفِ'):format(pay), 'success', 8000)
    elseif pay == 'bit' then HC.notify('انكسر رأس المثقاب (أو توقفت): ضع رأسًا جديدًا وحاول', 'error', 6000) end
end

---------------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 800
        local here = GetEntityCoords(cache.ped)
        local text, act = nil, nil

        -- keep the pulled ATMs off the wall in my game
        for key, a in pairs(atms) do
            if a.phase ~= 'hooked' and not hidden[key] and a.model then
                CreateModelHide(a.x, a.y, a.z, 1.5, joaat(a.model), true); hidden[key] = { x = a.x, y = a.y, z = a.z, model = a.model }
            end
        end
        for key, h in pairs(hidden) do
            if not atms[key] then RemoveModelHide(h.x, h.y, h.z, 1.5, joaat(h.model), false); hidden[key] = nil end
        end

        for key, a in pairs(atms) do
            local pos = v3(a)
            local veh = ent(a.veh)
            if a.phase == 'hooked' and veh and #(here - pos) < 80.0 then
                sleep = 0
                -- the chain, from the ATM to the truck's hitch
                local rear = rearOf(veh)
                for k = 0, 2 do local o = vec3(0, 0, k * 0.012); DrawLine(pos.x + o.x, pos.y, pos.z - 0.3 + o.z, rear.x, rear.y, rear.z + o.z, 150, 150, 150, 255) end
                -- the driver floors it
                if cache.vehicle == veh and GetPedInVehicleSeat(veh, -1) == cache.ped and not ripSent[key] then
                    if #(rear - pos) > 5.0 and GetEntitySpeed(veh) > 2.0 then ripSent[key] = true; TriggerServerEvent('exti_heists:server:atmRip', key) end
                end
            elseif (a.phase == 'dragging' or a.phase == 'down') and a.obj then
                local obj = ent(a.obj)
                if obj and not cache.vehicle and HC.canAct() then
                    local d = #(here - GetEntityCoords(obj))
                    if d < 2.6 then
                        sleep = 0
                        if a.phase == 'dragging' then
                            local tv = veh and GetEntitySpeed(veh) or 0
                            if tv < 0.5 then text, act = '[E] افصل الجهاز عن السلسلة', function() drop(key) end end
                        else
                            text, act = '[E] اثقب الجهاز', function() drillIt(key, obj) end
                        end
                    end
                end
            end
        end

        -- a wall ATM in front of me, a chain in my bag, a pickup close by
        if not text and not cache.vehicle and HC.canAct() and HC.count('tow_chain') > 0 then
            local obj, model = closestAtm(here)
            if obj then
                sleep = 0
                local veh = lib.getClosestVehicle(here, 10.0, false)
                if veh and TRUCK[GetEntityModel(veh)] then text, act = '[E] اربط سلسلة السحب بالشاحنة', function() hook(obj, model, veh) end
                else text = 'تحتاج شاحنة بيك أب قريبة لتقتلع الجهاز' end
            end
        end
        HC.prompt(text, 'atm')
        if act and IsControlJustReleased(0, 38) then act() end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, h in pairs(hidden) do RemoveModelHide(h.x, h.y, h.z, 1.5, joaat(h.model), false) end
end)
