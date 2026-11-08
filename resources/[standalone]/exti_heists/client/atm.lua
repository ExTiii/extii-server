-- =====================================================================
-- EX_Tii heists (game side): the ATM pull. A tow chain from a wall ATM to the back of any car, floor it, the
-- ATM tears off and drags behind the truck. Unhook it somewhere quiet and drill it open.
-- =====================================================================
local C = Config
local AT = C.atm
local MODELS = {}
for _, m in ipairs(AT.models) do MODELS[#MODELS + 1] = { name = m, hash = joaat(m) } end

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
-- the chain: one end on the ATM (kneel at the wall), the other on a car's back (kneel at the bumper)
---------------------------------------------------------------------------
-- any normal car works (no bikes, bicycles, boats, aircraft, trains)
local NO_CLASS = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }
local function isCar(veh) return veh and veh ~= 0 and DoesEntityExist(veh) and not NO_CLASS[GetVehicleClass(veh)] end

local chain = nil   -- { obj, model, pos, untilAt }: the chain is on the ATM, I'm carrying the other end

local function chainAtm(obj, model)
    HC.prompt(nil)
    TaskTurnPedToFaceEntity(cache.ped, obj, 800); Wait(800)
    local done = lib.progressBar({
        duration = AT.hookSeconds * 1000, label = 'تلفّ سلسلة السحب حول الجهاز...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
    })
    if not done then return end
    chain = { obj = obj, model = model, pos = GetEntityCoords(obj), untilAt = GetGameTimer() + 120000 }
    HC.notify('السلسلة على الجهاز: اربط طرفها الآخر بمؤخرة سيارة (أقل من 12 م)', 'success', 8000)
end

local function chainCar(veh)
    local c = chain; if not c then return end
    HC.prompt(nil)
    local rear = GetOffsetFromEntityInWorldCoords(veh, 0.0, select(1, GetModelDimensions(GetEntityModel(veh))).y - 0.6, 0.0)
    TaskTurnPedToFaceCoord(cache.ped, rear.x, rear.y, rear.z, 800); Wait(800)
    local done = lib.progressBar({
        duration = (AT.carSeconds or 4) * 1000, label = 'تربط السلسلة بمؤخرة السيارة...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 },
    })
    if not done then return end
    local ok, why = lib.callback.await('exti_heists:server:atmHook', false, { x = c.pos.x, y = c.pos.y, z = c.pos.z }, c.model, NetworkGetNetworkIdFromEntity(veh))
    if not ok then if why then HC.notify(why, 'error', 6000) end chain = nil return end
    chain = nil
    HC.notify('السلسلة مربوطة: ادخل السيارة وانطلق بقوة', 'success', 7000)
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
    AttachEntityToEntity(obj, veh, 0, 0.0, mn.y - 1.9, -0.35, 90.0, 0.0, 0.0, false, false, false, false, 2, true)
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
                CreateModelHideExcludingScriptObjects(a.x, a.y, a.z, 1.5, joaat(a.model), true); hidden[key] = { x = a.x, y = a.y, z = a.z, model = a.model }
            end
        end
        for key, h in pairs(hidden) do
            if not atms[key] then RemoveModelHide(h.x, h.y, h.z, 1.5, joaat(h.model), false); hidden[key] = nil end
        end

        for key in pairs(ripSent) do if not atms[key] or atms[key].phase ~= 'hooked' then ripSent[key] = nil end end
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

        -- carrying the loose end: the chain from the ATM to my hand, and the car's back bumper
        if chain then
            sleep = 0
            local hand = GetPedBoneCoords(cache.ped, 57005, 0.0, 0.0, 0.0)
            for k = 0, 2 do DrawLine(chain.pos.x, chain.pos.y, chain.pos.z - 0.3 + k * 0.012, hand.x, hand.y, hand.z + k * 0.012, 150, 150, 150, 255) end
            if #(here - chain.pos) > 16.0 or GetGameTimer() > chain.untilAt or cache.vehicle or HC.isDown() or HC.count('tow_chain') < 1 then
                chain = nil
                HC.notify('أفلتّ السلسلة: لا تصل إلى هذا البعد', 'error')
            elseif not text and HC.canAct() then
                local veh = lib.getClosestVehicle(here, 6.0, false)
                if isCar(veh) then
                    local mn = GetModelDimensions(GetEntityModel(veh))
                    local rear = GetOffsetFromEntityInWorldCoords(veh, 0.0, mn.y - 0.6, 0.0)
                    if #(here - rear) < 1.6 then
                        if #(rear - chain.pos) > 12.0 then text = 'قرّب السيارة من الجهاز (أقل من 12 م)'
                        else text, act = '[E] اربط السلسلة بمؤخرة السيارة', function() chainCar(veh) end end
                    else
                        text = 'اذهب إلى مؤخرة السيارة لتربط السلسلة'
                    end
                else
                    text = 'اربط الطرف الآخر بمؤخرة سيارة قريبة'
                end
            end
        end

        -- a wall ATM in front of me and a chain in my bag
        if not text and not chain and not cache.vehicle and HC.canAct() and HC.count('tow_chain') > 0 then
            local obj, model = closestAtm(here)
            if obj then
                -- (an ATM already pulled out is hidden: no prompt for it)
                local op = GetEntityCoords(obj)
                for _, h in pairs(hidden) do if #(op - v3(h)) < 2.0 then obj = nil break end end
                for _, a in pairs(atms) do if #(op - v3(a)) < 2.0 then obj = nil break end end
            end
            if obj then
                sleep = 0
                text, act = '[E] لفّ سلسلة السحب حول الجهاز', function() chainAtm(obj, model) end
            end
        end
        HC.prompt(text, 'atm')
        if act and (IsControlJustReleased(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then act() end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, h in pairs(hidden) do RemoveModelHide(h.x, h.y, h.z, 1.5, joaat(h.model), false) end
end)
