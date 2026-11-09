-- =====================================================================
-- EX_Tii (Moe): /portplace block | booth | checkpoint — a see-through copy follows where you look, you turn it
-- with the mouse wheel and click to put the real one there (admins only: the server checks).
-- Stays on after each click (for a row of blocks); right click or Backspace to stop.
-- =====================================================================
local placing = nil   -- { kind, model, ghost, turn }

local HELP = '[عجلة الفأرة] تدوير (مع Shift ببطء)  ·  [زر الفأرة الأيسر] ضع هنا  ·  [زر الفأرة الأيمن] خروج'

local function loadModel(list, override)
    local all = {}
    if tonumber(override) then all[1] = tonumber(override) end
    for _, n in ipairs(list) do all[#all + 1] = joaat(n) end
    for _, h in ipairs(all) do
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
end

-- where the camera looks, on the ground / road (up to 40 m)
local function aimPoint()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vec3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = cam + dir * 40.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, 1, cache.ped, 0)   -- (the map only)
    local _, hit, at = GetShapeTestResult(ray)
    if hit == 1 then return at end
end

local function stop()
    if not placing then return end
    if placing.ghost and DoesEntityExist(placing.ghost) then DeleteEntity(placing.ghost) end
    placing = nil
    lib.hideTextUI()
end

local function start(kind)
    stop()
    local model
    if kind == 'block' then
        model = loadModel(Config.blocks.models, GlobalState.extiPortBlockModel)
    else
        model = loadModel(Config.checkpoint.boothModels, GlobalState.extiPortBoothModel)
    end
    if not model then return lib.notify({ description = 'لم أجد الموديل', type = 'error' }) end
    local p = GetEntityCoords(cache.ped)
    local ghost = CreateObjectNoOffset(model, p.x, p.y, p.z - 50.0, false, false, false)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    placing = { kind = kind, model = model, ghost = ghost, turn = (kind == 'block') and 90.0 or 0.0 }
    lib.showTextUI(HELP)

    CreateThread(function()
        local mn = GetModelDimensions(model)
        while placing and placing.ghost == ghost do
            -- the mouse buttons and the wheel are ours while placing (no shooting, no weapon wheel)
            for _, c in ipairs({ 24, 25, 14, 15, 16, 17, 37, 140, 141, 142, 257, 263, 241, 242 }) do DisableControlAction(0, c, true) end
            local step = IsControlPressed(0, 21) and 1.0 or 7.5
            if IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15) then placing.turn = placing.turn + step end
            if IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14) then placing.turn = placing.turn - step end
            local at = aimPoint()
            local h = (GetGameplayCamRot(2).z + placing.turn) % 360.0
            if at then
                SetEntityCoordsNoOffset(ghost, at.x, at.y, at.z - mn.z, false, false, false)
                SetEntityHeading(ghost, h)
                PlaceObjectOnGroundProperly(ghost)
                SetEntityVisible(ghost, true, false)
                if IsDisabledControlJustPressed(0, 24) then
                    TriggerServerEvent('exti_port:server:place', placing.kind, at.x, at.y, at.z, h)
                    if placing.kind ~= 'block' then return stop() end   -- (a booth / the checkpoint: one at a time)
                end
            else
                SetEntityVisible(ghost, false, false)
            end
            if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 177) or IsEntityDead(cache.ped) then return stop() end
            Wait(0)
        end
    end)
end

RegisterCommand('portplace', function(_, args)
    local kind = tostring(args[1] or ''):lower()
    if kind ~= 'block' and kind ~= 'booth' and kind ~= 'checkpoint' then
        return lib.notify({ description = 'اكتب: /portplace block أو booth أو checkpoint', type = 'error' })
    end
    if placing and placing.kind == kind then return stop() end
    start(kind)
end, false)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then stop() end end)
