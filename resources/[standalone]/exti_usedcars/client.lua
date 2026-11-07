-- EX_Tii used cars (game side): the buyer, his map icon, [E] to sell the car you parked next to him.
local ped, blip, prompt = nil, nil, false

local function spot() return GlobalState['exti_usedcars:spot'] or Config.spot end

local function makeBlip()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    local s = spot()
    blip = AddBlipForCoord(s.x, s.y, s.z)
    SetBlipSprite(blip, Config.blip.sprite)
    SetBlipColour(blip, Config.blip.colour)
    SetBlipScale(blip, Config.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.blip.label)
    EndTextCommandSetBlipName(blip)
end

local function removePed()
    if ped and DoesEntityExist(ped) then DeletePed(ped) end
    ped = nil
end

local function spawnPed()
    if ped and DoesEntityExist(ped) then return end
    local s = spot()
    local model = joaat(Config.ped)
    if not lib.requestModel(model, 5000) then return end
    RequestCollisionAtCoord(s.x, s.y, s.z)
    local found, gz = GetGroundZFor_3dCoord(s.x, s.y, s.z + 0.6, false)
    ped = CreatePed(0, model, s.x, s.y, found and math.abs(gz - s.z) < 3.0 and gz or s.z - 1.0, s.w, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
end

AddStateBagChangeHandler('exti_usedcars:spot', 'global', function()
    SetTimeout(100, function() removePed(); makeBlip() end)
end)

local ERR = {
    far = 'اقترب من التاجر',
    inside = 'انزل من المركبة أولًا',
    nocar = 'أوقف مركبتك قرب التاجر أولًا (آخر مركبة قدتها)',
    people = 'أنزل الركاب من المركبة أولًا',
    notyours = 'هذه المركبة ليست ملكك',
    financed = 'لا يمكن بيع مركبة عليها أقساط',
    unknown = 'التاجر لا يشتري هذا النوع من المركبات',
    failed = 'تعذّر البيع، حاول مرة أخرى',
}

local busy = false
local function sell()
    busy = true
    local veh = GetPlayersLastVehicle()
    if veh == 0 or not DoesEntityExist(veh) then busy = false; return lib.notify({ type = 'error', description = ERR.nocar }) end
    local ok, q = lib.callback.await('exti_usedcars:server:quote', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then busy = false; return lib.notify({ type = 'error', description = ERR[q] or ERR.failed }) end
    if ped and DoesEntityExist(ped) then PlayPedAmbientSpeechNative(ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE_NORMAL') end
    local answer = lib.alertDialog({
        header = 'بيع المركبة',
        content = ('يعرض عليك التاجر **%s$** مقابل **%s** (اللوحة %s).\n\nبعد البيع تختفي المركبة من مرآبك نهائيًا.'):format(
            lib.math.groupdigits(q.price), q.label, q.plate),
        centered = true, cancel = true, labels = { confirm = 'بِعها', cancel = 'لا' },
    })
    if answer ~= 'confirm' then busy = false; return end
    local done, res = lib.callback.await('exti_usedcars:server:sell', false, q.token)
    if done then
        lib.notify({ type = 'success', description = ('بعت مركبتك بـ %s$ (في حسابك البنكي)'):format(lib.math.groupdigits(res)), duration = 7000 })
    else
        lib.notify({ type = 'error', description = ERR[res] or ERR.failed })
    end
    busy = false
end

CreateThread(function()
    makeBlip()
    while true do
        local s = spot()
        local me = GetEntityCoords(cache.ped)
        local d = #(me - s.xyz)
        local sleep = 1000
        if d < 100.0 then spawnPed() elseif d > 130.0 then removePed() end
        if d < 10.0 then
            sleep = 0
            local here = d < 2.2 and not cache.vehicle and not busy
            if here then
                if not prompt then prompt = true; lib.showTextUI('[E] بِع مركبتك المستعملة'); LocalPlayer.state:set('extiJobPrompt', true, false) end
                if IsControlJustPressed(0, 38) then
                    prompt = false; lib.hideTextUI(); LocalPlayer.state:set('extiJobPrompt', false, false)
                    CreateThread(sell)
                end
            elseif prompt then
                prompt = false; lib.hideTextUI(); LocalPlayer.state:set('extiJobPrompt', false, false)
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removePed()
    if prompt then lib.hideTextUI() end
end)
