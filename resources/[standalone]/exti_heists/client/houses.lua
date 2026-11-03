-- =====================================================================
-- EX_Tii heists (game side): house burglary. The lead from the fence (a yellow house on the map), the
-- front door (lockpick it quiet, or break a window loud), inside: search, the wall safe, the big item
-- carried out at walking speed to a car, the noise meter, the owner and the guard dog.
-- =====================================================================
local C = Config
local HS = C.house

local lead = nil        -- my lead from the fence: { id, pos, label, area, size, phase, expires }
local leadBlip = nil
local inHouse = nil     -- { id, size, it, spots = {k=true}, searched = {}, safeDone, pickupTaken, noise, alarm }
local openDoors = GlobalState['exti_heists:houses'] or {}
AddStateBagChangeHandler('exti_heists:houses', 'global', function(_, _, v) openDoors = v or {} end)
local carry = nil       -- { prop, item }

local function v3(t) return vec3(t.x + 0.0, t.y + 0.0, t.z + 0.0) end
function HC.insideHouse() return inHouse ~= nil end

---------------------------------------------------------------------------
-- the lead
---------------------------------------------------------------------------
local function clearLead()
    if leadBlip and DoesBlipExist(leadBlip) then RemoveBlip(leadBlip) end
    leadBlip, lead = nil, nil
end

RegisterNetEvent('exti_heists:client:houseLead', function(l)
    clearLead()
    lead = l
    lead.pos = v3(l.pos)
    lead.until_ = GetGameTimer() + (l.expires or 3600) * 1000
    leadBlip = AddBlipForCoord(lead.pos.x, lead.pos.y, lead.pos.z)
    SetBlipSprite(leadBlip, 40); SetBlipColour(leadBlip, 5); SetBlipScale(leadBlip, 0.95); SetBlipAsShortRange(leadBlip, false)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(('بيت · %s'):format(l.label)); EndTextCommandSetBlipName(leadBlip)
    SetBlipRoute(leadBlip, true); SetBlipRouteColour(leadBlip, 5)
    HC.notify(('عندك بيت: %s في %s · بالليل فقط (10 مساءً - 5 صباحًا)'):format(l.label, l.area), 'success', 9000)
end)

RegisterNetEvent('exti_heists:client:waypoint', function(p) if p and p.x then SetNewWaypoint(p.x + 0.0, p.y + 0.0) end end)

RegisterNetEvent('exti_heists:client:houseDone', function(id, why)
    if lead and lead.id == id then
        if why == 'expired' then HC.notify('انتهت مهلة البيت. اطلب غيره من المصرّف', 'error', 7000) end
        clearLead()
    end
end)

---------------------------------------------------------------------------
-- the noise meter (inside only): running, jumping and mistakes make noise; quiet steps let it fall
---------------------------------------------------------------------------
local lastSent = 0
local function addNoise(n)
    if not inHouse then return end
    inHouse.noise = math.min(100, inHouse.noise + n)
end
CreateThread(function()
    while true do
        if inHouse and not inHouse.alarm then
            local ped = cache.ped
            if IsPedSprinting(ped) then addNoise(HS.noise.sprint * 0.25) elseif IsPedRunning(ped) then addNoise(HS.noise.run * 0.25) end
            if IsPedJumping(ped) then addNoise(HS.noise.jump * 0.25) end
            if IsPedShooting(ped) then addNoise(100) end
            inHouse.noise = math.max(0, inHouse.noise - HS.noise.decay * 0.25)
            SendNUIMessage({ action = 'noise', value = math.floor(inHouse.noise) })
            if inHouse.noise >= 100 or (inHouse.noise >= 60 and GetGameTimer() - lastSent > 3000) then
                lastSent = GetGameTimer()
                TriggerServerEvent('exti_heists:server:houseNoise', inHouse.id, inHouse.noise)
            end
            Wait(250)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- the owner and the dog
---------------------------------------------------------------------------
local locals = {}
local function spawnLocal(model, pos, heading)
    local m = joaat(model)
    if not pcall(lib.requestModel, m, 5000) then return nil end
    local ped = CreatePed(28, m, pos.x, pos.y, pos.z - 1.0, heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(m)
    locals[#locals + 1] = ped
    return ped
end
local function clearLocals() for _, p in ipairs(locals) do if DoesEntityExist(p) then DeleteEntity(p) end end locals = {} end

local function ownerWakes()
    if not inHouse then return end
    local it = HS.interiors[inHouse.interior]
    local spot = it.spots[#it.spots]
    local ped = spawnLocal(inHouse.size == 'mansion' and 'a_m_y_bevhills_01' or 'a_m_m_eastsa_02', spot, 0.0)
    if ped then
        SetBlockingOfNonTemporaryEvents(ped, true)
        PlayPedAmbientSpeechNative(ped, 'GENERIC_SHOCKED_HIGH', 'SPEECH_PARAMS_FORCE_SHOUTED')
        CreateThread(function()
            Wait(800)
            if DoesEntityExist(ped) then
                TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE_UPRIGHT', 0, true)
                Wait(6000)
                if DoesEntityExist(ped) then TaskSmartFleePed(ped, cache.ped, 60.0, -1, false, false) end
            end
        end)
    end
end

local dog = nil
local function spawnDog()
    local it = HS.interiors[inHouse.interior]
    if not it.dog then return end
    dog = spawnLocal('a_c_rottweiler', it.dog, 0.0)
    if not dog then return end
    SetPedRelationshipGroupHash(dog, `HATES_PLAYER`)
    SetEntityHealth(dog, 250)
    TaskStartScenarioInPlace(dog, 'WORLD_DOG_SITTING_ROTTWEILER', 0, true)
    CreateThread(function()
        local woke = false
        while inHouse and DoesEntityExist(dog) and not IsPedDeadOrDying(dog, true) do
            local d = #(GetEntityCoords(cache.ped) - GetEntityCoords(dog))
            if not woke and (d < 4.0 or inHouse.noise > 40 or inHouse.alarm) then
                woke = true
                PlayPedAmbientSpeechNative(dog, 'BARK', 'SPEECH_PARAMS_FORCE_SHOUTED')
                TaskCombatPed(dog, cache.ped, 0, 16)
                addNoise(40)
            end
            Wait(400)
        end
    end)
end

RegisterNetEvent('exti_heists:client:houseAlarm', function(id, why)
    if not inHouse or inHouse.id ~= id then return end
    inHouse.alarm = true
    SendNUIMessage({ action = 'noise', value = 100, alarm = true })
    HC.notify(('%s! الشرطة في الطريق · اخرج الآن'):format(why or 'الإنذار'), 'error', 9000)
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
    ownerWakes()
end)

RegisterNetEvent('exti_heists:client:houseSearched', function(id, k) if inHouse and inHouse.id == id then inHouse.searched[k] = true end end)
RegisterNetEvent('exti_heists:client:houseSafeDone', function(id) if inHouse and inHouse.id == id then inHouse.safeDone = true end end)
RegisterNetEvent('exti_heists:client:housePickedUp', function(id) if inHouse and inHouse.id == id then inHouse.pickupTaken = true end end)

---------------------------------------------------------------------------
-- carrying the big item
---------------------------------------------------------------------------
local function dropCarry(silent)
    if not carry then return end
    if DoesEntityExist(carry.prop) then DeleteEntity(carry.prop) end
    ClearPedTasks(cache.ped)
    carry = nil
    TriggerServerEvent('exti_heists:server:houseDropCarry')
    if not silent then HC.notify('أسقطته: ضاع', 'error') end
end

local function attachCarry(model)
    local m = joaat(model)
    if not pcall(lib.requestModel, m, 5000) then return end
    local here = GetEntityCoords(cache.ped)
    local prop = CreateObject(m, here.x, here.y, here.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(m)
    local tv = model:find('tv') ~= nil
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, 28422), tv and 0.0 or 0.05, tv and -0.18 or -0.12, tv and -0.1 or -0.25,
        tv and 0.0 or 10.0, 0.0, tv and 0.0 or 90.0, true, true, false, true, 1, true)
    HC.anim(cache.ped, 'anim@heists@box_carry@', 'idle', 49)
    return prop
end

CreateThread(function()
    while true do
        if carry then
            DisableControlAction(0, 21, true)   -- sprint
            DisableControlAction(0, 22, true)   -- jump
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)   -- attack, aim
            DisableControlAction(0, 23, true)   -- enter vehicle
            if not IsEntityPlayingAnim(cache.ped, 'anim@heists@box_carry@', 'idle', 3) then HC.anim(cache.ped, 'anim@heists@box_carry@', 'idle', 49) end
            if HC.isDown() then dropCarry() end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------
local function breakIn(how)
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:houseBreakBegin', false, lead.id, how)
    if not ok then if token then HC.notify(token, 'error', 6000) end return end
    if token == 'open' then
        HC.anim(cache.ped, 'melee@unarmed@streamed_core_fps', 'ground_attack_0_psycho', 0, 1200)
        PlaySoundFromCoord(-1, 'Glass_Smash', lead.pos.x, lead.pos.y, lead.pos.z, '', false, 0, false)
        HC.notify('كسرت النافذة: الجيران سمعوا · ادخل بسرعة', 'warning', 7000)
        lead.phase = 'open'
        return
    end
    HC.anim(cache.ped, 'mp_common_heist', 'pick_door', 1)
    local passed = HC.play('lockpick', params, 'قفل الباب الأمامي')
    ClearPedTasks(cache.ped)
    local res, why = lib.callback.await('exti_heists:server:houseBreakEnd', false, token, passed)
    if res then lead.phase = 'open'; HC.notify('فُتح الباب. ادخل بهدوء', 'success')
    elseif why == 'broke' then HC.notify('انكسر مفتاح الفتح', 'error')
    elseif why == 'failed' then HC.notify('لم يُفتح القفل', 'error') end
end

local function enter(id)
    HC.prompt(nil)
    local ok, info = lib.callback.await('exti_heists:server:houseEnter', false, id)
    if not ok then return end
    local it = HS.interiors[info.interior]
    DoScreenFadeOut(400); Wait(450)
    local spots = {}
    for _, k in ipairs(info.spots) do spots[k] = true end
    local searched = {}
    for k, v in pairs(info.searched or {}) do searched[tonumber(k) or k] = v end
    inHouse = { id = info.id, size = info.size, interior = info.interior, spots = spots, searched = searched, safeDone = info.safeDone,
                pickupTaken = info.pickupTaken, noise = info.noise or 0, alarm = info.alarm }
    RequestCollisionAtCoord(it.exit.x, it.exit.y, it.exit.z)
    SetEntityCoords(cache.ped, it.exit.x, it.exit.y, it.exit.z - 0.9, false, false, false, false)
    SetEntityHeading(cache.ped, (it.exit.w + 180.0) % 360)
    local t = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < t do Wait(50) end
    Wait(300); DoScreenFadeIn(500)
    SendNUIMessage({ action = 'noise', value = math.floor(inHouse.noise), show = true, alarm = inHouse.alarm })
    if info.dog then spawnDog() end
    if inHouse.alarm then ownerWakes() end
end

RegisterNetEvent('exti_heists:client:houseOut', function(p)
    local wasCarrying = carry and carry.model
    if carry and DoesEntityExist(carry.prop) then DeleteEntity(carry.prop) end
    inHouse = nil; dog = nil
    clearLocals()
    SendNUIMessage({ action = 'noise', show = false })
    DoScreenFadeOut(300); Wait(350)
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoords(cache.ped, p.x + 0.0, p.y + 0.0, p.z - 0.9, false, false, false, false)
    local t = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < t do Wait(50) end
    Wait(200); DoScreenFadeIn(400)
    -- the big item comes out with him (made again in the street, so everyone sees it)
    if wasCarrying and carry then carry.prop = attachCarry(wasCarrying) end
end)

local function leave()
    HC.prompt(nil)
    lib.callback.await('exti_heists:server:houseLeave', false, inHouse.id)
end

local function search(k)
    HC.prompt(nil)
    local ok, secs = lib.callback.await('exti_heists:server:houseSearchBegin', false, inHouse.id, k)
    if not ok then return end
    addNoise(HS.noise.search)
    local done = lib.progressBar({
        duration = secs * 1000, label = 'تفتّش بهدوء...', canCancel = true, disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search', flag = 1 },
    })
    if not done then return end
    local res, found = lib.callback.await('exti_heists:server:houseSearchEnd', false)
    if not res then return end
    inHouse.searched[k] = true
    if #found == 0 then HC.notify('لا شيء هنا', 'inform', 2500) return end
    local parts = {}
    for _, f in ipairs(found) do
        local it = exports.ox_inventory:Items(f.item)
        parts[#parts + 1] = f.item == 'black_money' and ('%d$'):format(f.n) or ((f.n > 1 and (f.n .. 'x ') or '') .. ((it and it.label) or f.item))
    end
    HC.notify('وجدت: ' .. table.concat(parts, ' · '), 'success', 5000)
end

local function crack()
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:houseSafeBegin', false, inHouse.id)
    if not ok then return end
    HC.anim(cache.ped, 'mini@safe_cracking', 'idle_base', 1)
    local passed = HC.play('safedial', params, 'خزنة الحائط')
    ClearPedTasks(cache.ped)
    local res, info = lib.callback.await('exti_heists:server:houseSafeEnd', false, token, passed)
    if res then
        inHouse.safeDone = true
        HC.notify(('فتحت الخزنة: %d$%s%s'):format(info.money, info.extra and ' + مجوهرات' or '', info.usb and ' · ووجدت فلاشة خضراء!' or ''), 'success', 8000)
    elseif passed == false then addNoise(HS.noise.safeFail); HC.notify('أفلت الرقم', 'error') end
end

local function pickup()
    HC.prompt(nil)
    local ok, model, item = lib.callback.await('exti_heists:server:housePickup', false, inHouse.id)
    if not ok then return end
    inHouse.pickupTaken = true
    carry = { model = model, item = item }
    carry.prop = attachCarry(model)
    HC.notify('احمله إلى سيارتك (ببطء) وضعه فيها · [X] تسقطه', 'inform', 8000)
end

local function stow(veh)
    HC.prompt(nil)
    local ok, item = lib.callback.await('exti_heists:server:houseStow', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then return end
    if carry and DoesEntityExist(carry.prop) then DeleteEntity(carry.prop) end
    ClearPedTasks(cache.ped)
    carry = nil
    HC.notify('وضعته في السيارة · بِعه للمصرّف', 'success')
end

---------------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 700
        local text, act, alt = nil, nil, nil
        local here = GetEntityCoords(cache.ped)

        if inHouse then
            sleep = 0
            local it = HS.interiors[inHouse.interior]
            if HC.canAct() and not carry then
                local best, bd
                for k, p in ipairs(it.spots) do
                    if not inHouse.searched[k] then
                        local d = #(here - p)
                        if d < 1.4 and (not bd or d < bd) then best, bd = k, d end
                        if d < 8.0 then DrawMarker(2, p.x, p.y, p.z + 0.35, 0, 0, 0, 0, 180.0, 0, 0.12, 0.12, 0.12, 232, 181, 71, 140, false, true, 2, false, nil, nil, false) end
                    end
                end
                if best then text, act = '[E] فتّش', function() search(best) end end
                if it.safe and HS.sizes[inHouse.size].safe and not inHouse.safeDone and #(here - it.safe) < 1.4 then text, act = '[E] افتح خزنة الحائط', crack end
                if it.pickup and not inHouse.pickupTaken and #(here - it.pickup.pos) < 1.6 then
                    text, act = ('[E] احمل %s'):format(HS.sizes[inHouse.size].pickup == 'painting' and 'اللوحة' or 'التلفاز'), pickup
                end
            end
            if #(here - vec3(it.exit.x, it.exit.y, it.exit.z)) < 1.5 and HC.canAct() then text, act = '[E] اخرج', leave end
        else
            -- the door of my lead
            if lead and #(here - lead.pos) < 2.0 and HC.canAct() and not carry then
                sleep = 0
                if lead.phase == 'lead' then
                    if HC.count('lockpick') > 0 then text, act = '[E] افتح القفل · [G] اكسر النافذة', function() breakIn('pick') end
                    else text, act = '[G] اكسر النافذة (صاخب)', nil end
                    alt = function() breakIn('window') end
                end
            end
            -- any open door (the crew): come in
            for id, d in pairs(openDoors) do
                if #(here - v3(d)) < 2.0 and HC.canAct() and not carry then
                    sleep = 0
                    text, act, alt = '[E] ادخل البيت', function() enter(id) end, nil
                end
            end
            -- carrying: a car nearby
            if carry then
                sleep = 0
                local veh = lib.getClosestVehicle(here, 3.5, false)
                if veh then text, act = '[E] ضعه في السيارة', function() stow(veh) end
                else text = 'تحمل غرضًا ثقيلًا · اذهب إلى سيارتك · [X] تسقطه' end
                if IsControlJustReleased(0, 73) then dropCarry() end
            end
        end
        HC.prompt(text, 'houses')
        if act and IsControlJustReleased(0, 38) then act() end
        if alt and IsControlJustReleased(0, 47) then alt() end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearLead(); clearLocals()
    if carry and DoesEntityExist(carry.prop) then DeleteEntity(carry.prop) end
end)
