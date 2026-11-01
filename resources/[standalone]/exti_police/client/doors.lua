-- =====================================================================
-- EX_Tii Police (client): the locked doors (the armory). The game's door system keeps the door
-- shut; the "[E]" line next to it lets the right officers unlock / lock it.
-- =====================================================================

local list = GlobalState.exti_police_doors
local known = {}   -- [id] = { hash, model, coords }

local function hashOf(id) return joaat('exti_police_door_' .. id) end

local function apply()
    if type(list) ~= 'table' then return end
    for _, d in ipairs(list) do
        local model = joaat(d.model)
        local k = known[d.id]
        if not k or k.x ~= d.x or k.y ~= d.y or k.z ~= d.z then
            -- the door object next to the configured place (the numbers may be a little off)
            local obj = GetClosestObjectOfType(d.x, d.y, d.z, 4.0, model, false, false, false)
            local c = obj ~= 0 and GetEntityCoords(obj) or vec3(d.x, d.y, d.z)
            local hash = hashOf(d.id)
            if k and IsDoorRegisteredWithSystem(hash) then RemoveDoorFromSystem(hash) end
            AddDoorToSystem(hash, model, c.x, c.y, c.z, false, false, false)
            known[d.id] = { id = d.id, hash = hash, x = d.x, y = d.y, z = d.z, coords = c, label = d.label, minGrade = d.minGrade, minGradeLabel = d.minGradeLabel }
            k = known[d.id]
        end
        k.locked = d.locked
        -- 1 = locked, 0 = unlocked; a locked door also swings shut
        DoorSystemSetDoorState(k.hash, d.locked and 1 or 0, false, true)
        if d.locked then DoorSystemSetOpenRatio(k.hash, 0.0, false, true) end
    end
end

AddStateBagChangeHandler('exti_police_doors', 'global', function(_, _, value)
    if type(value) == 'table' then list = value apply() end
end)
CreateThread(function()
    while type(list) ~= 'table' do Wait(1000) list = GlobalState.exti_police_doors end
    apply()
    -- the door object may stream in later: re-apply now and then
    while true do
        Wait(5000)
        apply()
    end
end)

-- the "[E]" line at the door, for the police
local function job() return QBX and QBX.PlayerData and QBX.PlayerData.job end
local function myGrade() local j = job() return j and j.grade and j.grade.level or 0 end

CreateThread(function()
    local shown = false
    while true do
        local sleep = 700
        if POL.isCop() and not cache.vehicle and not IsNuiFocused() then
            local me = GetEntityCoords(cache.ped)
            local nearest, nd
            for _, k in pairs(known) do
                local d = #(me - k.coords)
                if d < 10.0 then sleep = 0 end
                if d < 1.8 and (not nd or d < nd) then nearest, nd = k, d end
            end
            if nearest then
                local can = POL.onDuty() and myGrade() >= (nearest.minGrade or 0)
                local text = can and ('[E] %s %s'):format(nearest.locked and 'فتح' or 'قفل', nearest.label)
                    or ('%s مقفلة · %s'):format(nearest.label, nearest.minGradeLabel and ('من رتبة %s فما فوق'):format(nearest.minGradeLabel) or 'للشرطة فقط')
                lib.showTextUI(text, { icon = nearest.locked and 'lock' or 'lock-open', position = 'top-center' })
                shown = true
                if can and IsControlJustPressed(0, 38) then
                    TriggerServerEvent('exti_police:server:door', nearest.id)
                    Wait(400)
                end
            elseif shown then
                lib.hideTextUI()
                shown = false
            end
        elseif shown then
            lib.hideTextUI()
            shown = false
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    for _, k in pairs(known) do
        if IsDoorRegisteredWithSystem(k.hash) then
            DoorSystemSetDoorState(k.hash, 0, false, true)
            RemoveDoorFromSystem(k.hash)
        end
    end
end)
