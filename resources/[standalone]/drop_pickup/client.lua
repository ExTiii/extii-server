-- drop_pickup (client): عندما تقف بجانب كيس على الأرض يظهر زر [E] لالتقاط ما فيه مباشرة
local drops = {}       -- [dropId] = { coords = vector3, instance = any }
local nearest = nil    -- الكيس الذي يظهر له الزر الآن
local busy = false
local shownAt = 0       -- EX_Tii: the line is sent again every second (exti_interact drops a line its owner stopped renewing)
local summaries = {}   -- [dropId] = نص يصف ما في الكيس

local textStyle = { position = 'right-center', icon = 'hand', style = { direction = 'rtl' } }

local function addDrop(dropId, data)
    if type(dropId) ~= 'string' or type(data) ~= 'table' or not data.coords then return end
    local c = data.coords
    drops[dropId] = { coords = vec3(c.x, c.y, c.z), instance = data.instance }
end

local function hidePrompt()
    if nearest then
        nearest = nil
        lib.hideTextUI()
    end
end

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data)
    summaries[dropId] = nil
    addDrop(dropId, data)
end)

RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
    drops[dropId] = nil
    summaries[dropId] = nil
    if nearest == dropId then hidePrompt() end
end)

local function loadDrops()
    local list = lib.callback.await('drop_pickup:list', false) or {}
    drops = {}
    for dropId, data in pairs(list) do addDrop(dropId, data) end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', loadDrops)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    loadDrops()
end)

local lastSel, selSince = false, 0   -- which prompt line is picked, and since when (see the E check below)

local function promptText(summary)
    if not summary then return '[E] التقاط الأغراض' end
    local text = ('[E] التقاط %s (%d)'):format(summary.label, summary.count)
    if summary.more and summary.more > 0 then
        text = text .. ' وأغراض أخرى'
    end
    return text
end

local function showPrompt(dropId)
    nearest = dropId
    shownAt = GetGameTimer()
    lib.showTextUI(promptText(summaries[dropId]), textStyle)

    if summaries[dropId] then return end
    CreateThread(function()
        local summary = lib.callback.await('drop_pickup:peek', false, dropId)
        if not summary then return end
        summaries[dropId] = summary
        if nearest == dropId then
            lib.showTextUI(promptText(summary), textStyle)
        end
    end)
end

-- EX_Tii: nothing opens with E while you are down (bleeding out) or dead
local function isDown()
    local state = LocalPlayer.state['qbx_medical:deathState']
    return (state ~= nil and state ~= 1) or IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true)
end

local function canPickUp()
    if cache.vehicle or IsNuiFocused() or IsPauseMenuActive() then return false end
    if LocalPlayer.state.invOpen or LocalPlayer.state.invBusy then return false end
    if isDown() or IsPedRagdoll(cache.ped) or IsPedFalling(cache.ped) then return false end
    return true
end

local function pickUp(dropId)
    busy = true
    hidePrompt()

    if pcall(lib.requestAnimDict, 'pickup_object', 1000) then
        TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 1000, 48, 0.0, false, false, false)
        RemoveAnimDict('pickup_object')
    end
    Wait(500)

    local result = lib.callback.await('drop_pickup:take', false, dropId) or { ok = false, error = 'gone' }
    summaries[dropId] = nil

    -- ox_inventory يعرض بنفسه إشعار الأغراض المضافة، هنا نوضح فقط المشاكل
    if result.ok and result.left and result.left > 0 then
        lib.notify({ type = 'warning', description = 'التقطت ما يتسع في حقيبتك، وبقي الباقي على الأرض.' })
    elseif not result.ok then
        if result.error == 'full' then
            lib.notify({ type = 'error', description = 'حقيبتك ممتلئة، لا يمكنك حمل هذه الأغراض.' })
        elseif result.error == 'gone' then
            lib.notify({ type = 'error', description = 'لم يعد هناك شيء هنا.' })
        end
    end

    Wait(300)
    busy = false
end

CreateThread(function()
    while true do
        local sleep = 400

        if not busy and next(drops) and canPickUp() then
            local pos = GetEntityCoords(cache.ped)
            local instance = LocalPlayer.state.instance
            local bestId, bestDist

            for dropId, drop in pairs(drops) do
                if not drop.instance or drop.instance == instance then
                    local dist = #(pos - drop.coords)
                    if dist < Config.ShowDistance and (not bestDist or dist < bestDist) then
                        bestId, bestDist = dropId, dist
                    end
                end
            end

            if bestId then
                if bestId ~= nearest or GetGameTimer() - shownAt > 1000 then showPrompt(bestId) end
                sleep = 0
                -- EX_Tii: E only when OUR line is the picked one in the prompt list (a safe, a till or a shop
                -- right next to the bag must not fire together with it). On the press, not the release: the
                -- other script acts on the press and its line goes away, which would make ours the picked one
                -- by the time the key comes up. And the pick must have been ours for a moment already.
                local sel = LocalPlayer.state.interactSel
                if sel ~= lastSel then lastSel, selSince = sel, GetGameTimer() end
                local mine = (sel == nil or sel == GetCurrentResourceName()) and GetGameTimer() - selSince > 300
                if mine and IsControlJustPressed(0, Config.Key) then
                    pickUp(bestId)
                end
            else
                hidePrompt()
            end
        else
            hidePrompt()
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and nearest then
        lib.hideTextUI()
    end
end)
