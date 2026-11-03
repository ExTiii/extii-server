-- =====================================================================
-- EX_Tii heists (game side): prep missions. The car (and its men) appear when you come near; the
-- route and a blip on it; [E] at the driver's door: the lockpick, the car alarm, the men turn on you.
-- =====================================================================
local C = Config
local P = C.preps
local preps = GlobalState['exti_heists:preps'] or {}
AddStateBagChangeHandler('exti_heists:preps', 'global', function(_, _, v) preps = v or {} end)

local myBlip
local function ground(x, y, z)
    for _, dz in ipairs({ 2.0, 6.0, 15.0, 40.0 }) do
        local ok, g = GetGroundZFor_3dCoord(x, y, z + dz, false)
        if ok then return g end
    end
    return z
end

RegisterNetEvent('exti_heists:client:prepSpawn', function(sp, model, nGuards, guardModel, weapon)
    CreateThread(function()
        local vm = joaat(model)
        if not pcall(lib.requestModel, vm, 10000) then return end
        local z = ground(sp.x, sp.y, sp.z)
        local veh = CreateVehicle(vm, sp.x, sp.y, z + 0.3, sp.w or 0.0, true, false)
        if veh == 0 then return end
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleAlarm(veh, true)
        SetModelAsNoLongerNeeded(vm)
        local guards = {}
        if nGuards > 0 and guardModel then
            local gm = joaat(guardModel)
            if pcall(lib.requestModel, gm, 10000) then
                for g = 1, nGuards do
                    local off = GetOffsetFromEntityInWorldCoords(veh, (g == 1) and -2.2 or 2.2, 1.0, 0.0)
                    local ped = CreatePed(4, gm, off.x, off.y, ground(off.x, off.y, off.z), (sp.w or 0.0) + 180.0, true, false)
                    if ped ~= 0 then
                        SetEntityAsMissionEntity(ped, true, true)
                        GiveWeaponToPed(ped, joaat(weapon or 'WEAPON_PISTOL'), 200, false, false)
                        SetPedRelationshipGroupHash(ped, joaat(C.guards.rel))
                        SetPedAccuracy(ped, C.guards.accuracy); SetPedArmour(ped, 30)
                        SetPedCombatAttributes(ped, 46, true); SetPedKeepTask(ped, true)
                        TaskStartScenarioInPlace(ped, g == 1 and 'WORLD_HUMAN_SMOKING' or 'WORLD_HUMAN_STAND_MOBILE', 0, true)
                        guards[#guards + 1] = NetworkGetNetworkIdFromEntity(ped)
                    end
                end
                SetModelAsNoLongerNeeded(gm)
            end
        end
        Wait(600)   -- (until the server knows them)
        TriggerServerEvent('exti_heists:server:prepSpawned', NetworkGetNetworkIdFromEntity(veh), guards)
    end)
end)

-- the alarm: the car shouts, the men fight the one at the door
RegisterNetEvent('exti_heists:client:prepAlarm', function(vehNet, guardNets, robber)
    local veh = NetworkDoesNetworkIdExist(vehNet) and NetToVeh(vehNet) or 0
    if veh ~= 0 and NetworkHasControlOfEntity(veh) then StartVehicleAlarm(veh) end
    local pl = GetPlayerFromServerId(robber)
    local tgt = pl ~= -1 and GetPlayerPed(pl) or 0
    for _, n in ipairs(guardNets or {}) do
        if NetworkDoesNetworkIdExist(n) then
            local ped = NetToPed(n)
            if ped ~= 0 and NetworkHasControlOfEntity(ped) and tgt ~= 0 then ClearPedTasks(ped); TaskCombatPed(ped, tgt, 0, 16) end
        end
    end
end)

-- the prompt and the blip for MY prep car
local busy = false
CreateThread(function()
    while true do
        local sleep = 1000
        local text
        local cid = QBX and QBX.PlayerData and QBX.PlayerData.citizenid
        local mine = cid and preps[cid]
        local veh = mine and NetworkDoesNetworkIdExist(mine.veh) and NetToVeh(mine.veh) or 0
        if veh ~= 0 and DoesEntityExist(veh) then
            if not myBlip or not DoesBlipExist(myBlip) then
                myBlip = AddBlipForEntity(veh); SetBlipSprite(myBlip, 225); SetBlipColour(myBlip, 5); SetBlipScale(myBlip, 0.85)
                BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('سيارة التحضير'); EndTextCommandSetBlipName(myBlip)
            end
            local door = GetWorldPositionOfEntityBone(veh, GetEntityBoneIndexByName(veh, 'door_dside_f'))
            if door.x == 0.0 and door.y == 0.0 then door = GetEntityCoords(veh) end
            local d = #(GetEntityCoords(cache.ped) - door)
            if d < 25.0 then sleep = 250 end
            if d < 1.6 and not busy and HC.canAct() then
                sleep = 0
                text = '[E] افتح الباب (مفتاح فتح)'
                if IsControlJustPressed(0, 38) then
                    busy = true; HC.prompt(nil)
                    CreateThread(function()
                        local ok, token, params = lib.callback.await('exti_heists:server:prepBegin', false)
                        if not ok then busy = false; if token then HC.notify(token, 'error') end return end
                        TaskTurnPedToFaceEntity(cache.ped, veh, 600); Wait(600)
                        HC.anim(cache.ped, 'veh@break_in@0h@p_m_one@', 'low_force_entry_ds', 1)
                        local passed = HC.play('lockpick', params, 'باب السيارة')
                        ClearPedTasks(cache.ped)
                        local done, label = lib.callback.await('exti_heists:server:prepEnd', false, token, passed)
                        if done then
                            HC.notify(('أخذت: %s'):format(label), 'success', 7000)
                            if myBlip and DoesBlipExist(myBlip) then RemoveBlip(myBlip) end
                        elseif label == 'broke' then HC.notify('انكسر مفتاح الفتح', 'error') end
                        busy = false
                    end)
                end
            end
        elseif myBlip and DoesBlipExist(myBlip) then
            RemoveBlip(myBlip); myBlip = nil
        end
        HC.prompt(text, 'prep')
        Wait(sleep)
    end
end)
