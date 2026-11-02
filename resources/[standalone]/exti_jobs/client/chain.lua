-- =====================================================================
-- EX_Tii level jobs (chicken, raisins, ...): collect -> process -> sell
--   gold circles at every place of the job, [E] = animation + progress bar + skill check,
--   the map shows every place and the gold line goes to the step you should do next
--   (from what is in your pockets). The server checks and does everything with the items.
-- =====================================================================
local config = EXJ.config
local spots = require 'config.spots'

local REACH = 1.2     -- how close to the middle of a circle you must stand
local SHOW = 70.0     -- circles are drawn from this far

local labels = {}     -- item name -> its label (from ox_inventory)
local function itemLabel(name)
    if labels[name] then return labels[name] end
    local ok, items = pcall(function() return exports.ox_inventory:Items() end)
    if ok and type(items) == 'table' then
        for k, v in pairs(items) do labels[k] = v.label end
    end
    local l = labels[name] or name
    return (l:gsub('%s*%b()', ''))
end

local function counts(names)
    local ok, result = pcall(function() return exports.ox_inventory:Search('count', names) end)
    if not ok or type(result) ~= 'table' then return {} end
    return result
end

---------------------------------------------------------------------------
-- the skill check (waits if another one is still on screen)
---------------------------------------------------------------------------
function EXJ.skill(levels)
    if not levels or #levels == 0 then return true end
    local untilTime = GetGameTimer() + 3000
    while lib.skillCheckActive() and GetGameTimer() < untilTime do Wait(50) end
    for _ = 1, 3 do
        local result = lib.skillCheck(levels, { 'e' })
        if result ~= nil then return result end
        Wait(150)
    end
    return false
end

---------------------------------------------------------------------------
-- one level job at a time
---------------------------------------------------------------------------
local C = { name = nil, job = nil, blips = {}, routeStep = nil, running = false, busy = false, rest = {}, have = {}, buyer = nil }

local function allItems(job)
    local list, seen = {}, {}
    local function add(n) if n and not seen[n] then seen[n] = true list[#list + 1] = n end end
    for _, st in ipairs(job.chain) do
        if type(st.give) == 'table' and st.give.item then add(st.give.item) end
        if type(st.take) == 'table' then for item in pairs(st.take) do add(item) end end
        if st.kind == 'process' and type(st.give) == 'table' then for item in pairs(st.give) do add(item) end end
    end
    return list
end

-- (batch steps name one item: take = 'poultry_kit', give = 'live_chicken')
local function allItemsOf(job)
    local list = allItems(job)
    local seen = {}
    for _, n in ipairs(list) do seen[n] = true end
    for _, st in ipairs(job.chain) do
        for _, n in ipairs({ type(st.take) == 'string' and st.take or nil, type(st.give) == 'string' and st.give or nil }) do
            if n and not seen[n] then seen[n] = true list[#list + 1] = n end
        end
    end
    return list
end

local function hasAll(step)
    if type(step.take) == 'string' then
        return (C.have[step.take] or 0) >= 1, step.take, 1
    end
    for item, need in pairs(step.take or {}) do
        if (C.have[item] or 0) < need then return false, item, need end
    end
    return true
end

-- the step to do next: the last one in the chain you have everything for (sell first, collect last)
local function nextStep()
    local job = C.job
    for i = #job.chain, 1, -1 do
        local st = job.chain[i]
        if st.kind ~= 'collect' and hasAll(st) then return i end
    end
    -- nothing ready: go and collect (or buy the supplies when only they are missing)
    for i, st in ipairs(job.chain) do
        if st.kind == 'collect' then return i end
    end
    return 1
end

local function stepCenter(step)
    if step.ped then return step.ped.xyz end
    if step.kind ~= 'collect' then return step.spot end
    local x, y, z, n = 0.0, 0.0, 0.0, #step.spots
    for _, p in ipairs(step.spots) do x, y, z = x + p.x, y + p.y, z + p.z end
    return vec3(x / n, y / n, z / n)
end

local function clearBlips()
    for _, b in pairs(C.blips) do EXJ.removeBlip(b) end
    C.blips = {}
end

local function drawBlips(route)
    clearBlips()
    local job = C.job
    for i, st in ipairs(job.chain) do
        C.blips[i] = EXJ.blip(stepCenter(st), st.blip or 1, ('%s - %s'):format(st.label, st.place), i == route)
    end
    C.routeStep = route
end

-- the buyer at the sell place (when an admin put one there with /jobspots)
-- EX_Tii: the buyer of a level job is a person (no circle): walk up to him and press E.
-- He stands there for everyone, all the time (like the supervisors). Placed with /jobspots.
local buyers = {} -- [job .. ':' .. step id] = ped

local function removeBuyer(key)
    for k, ped in pairs(buyers) do
        if not key or k == key then
            if DoesEntityExist(ped) then DeletePed(ped) end
            buyers[k] = nil
        end
    end
end

local function spawnBuyer(key, step)
    if buyers[key] and DoesEntityExist(buyers[key]) then return end
    local model = joaat(step.pedModel or 's_m_m_linecook')
    if not EXJ.loadModel(model) then return end
    local p = step.ped
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.6, false)
    local ped = CreatePed(0, model, p.x, p.y, found and math.abs(gz - p.z) < 3.0 and gz or p.z - 1.0, p.w, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    buyers[key] = ped
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        for name, job in pairs(config.jobs) do
            for _, st in ipairs(job.chain or {}) do
                if st.ped then
                    local key = name .. ':' .. st.id
                    local d = #(me - st.ped.xyz)
                    if d < 100.0 then spawnBuyer(key, st) elseif d > 130.0 and buyers[key] then removeBuyer(key) end
                end
            end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then removeBuyer() end
end)

---------------------------------------------------------------------------
-- doing a step
---------------------------------------------------------------------------
local ERR = {
    far = 'قف داخل الدائرة الذهبية',
    fast = 'على مهلك، أكمل العمل أولًا',
    full = 'حقيبتك ممتلئة',
    noshift = 'ابدأ المناوبة عند المشرف أولًا',
    failed = 'حدث خطأ، حاول مرة أخرى',
}

local function act(index, spotIndex, spot)
    local job, step = C.job, C.job.chain[index]
    C.busy = true
    EXJ.clearPrompt('chain')
    TaskTurnPedToFaceCoord(cache.ped, spot.x, spot.y, spot.z, 600)
    Wait(400)
    local anim = step.anim and { dict = step.anim.dict, clip = step.anim.clip, flag = 1 } or nil
    local ok = lib.progressBar({
        duration = step.time,
        label = step.progress or step.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = anim,
    })
    if not ok then C.busy = false return end
    if not EXJ.skill(step.skill) then
        EXJ.notify(step.fail or 'فشلت، حاول مرة أخرى', 'error')
        C.busy = false
        return
    end
    local done, a, b, c, d = lib.callback.await('exti_jobs:server:chainAct', false, index, spotIndex)
    if done then
        if step.kind == 'collect' then
            C.rest[index .. ':' .. spotIndex] = GetGameTimer() + (a.rest or step.rest) * 1000
            EXJ.notify(('+%d %s'):format(a.got, itemLabel(a.item)), 'success', 3500)
        elseif step.kind == 'process' then
            local parts = {}
            for item, n in pairs(step.give) do parts[#parts + 1] = ('%d %s'):format(n, itemLabel(item)) end
            EXJ.notify(('أنجزت: %s'):format(table.concat(parts, '، ')), 'success', 3500)
        elseif step.kind == 'sell' and a and a.round then
            EXJ.setRound(a.round)
        end
    elseif a == 'rest' then
        C.rest[index .. ':' .. spotIndex] = GetGameTimer() + (tonumber(b) or 30) * 1000
        EXJ.notify(('هذا المكان فارغ الآن، جرّب دائرة أخرى (يعود بعد %d ثانية)'):format(tonumber(b) or 30), 'error')
    elseif a == 'cap' then
        EXJ.notify(('لا تستطيع حمل أكثر من %d. أكمل الخطوة التالية أولًا'):format(tonumber(b) or step.cap), 'error', 6000)
    elseif a == 'missing' then
        local isSupply = false
        for _, s in ipairs(job.supplies or {}) do if s == b then isSupply = true end end
        if isSupply then
            EXJ.notify(('تحتاج %s من بقالة 24/7'):format(itemLabel(b)), 'error', 7000)
        else
            EXJ.notify(('تحتاج %d %s (معك %d)'):format(tonumber(c) or 0, itemLabel(b), tonumber(d) or 0), 'error', 6000)
        end
    elseif a == 'hourcap' then
        EXJ.notify(('اشترى التاجر منك ما يكفي الآن. عد بعد %d دقيقة'):format(tonumber(b) or 10), 'error', 8000)
    else
        EXJ.notify(ERR[a] or ERR.failed, 'error')
    end
    C.busy = false
end

-- EX_Tii (Moe's design): everything you carry at once, with the step's own mini game
local gameWait = nil
RegisterNUICallback('gameDone', function(data, cb)
    cb(true)
    if gameWait then gameWait:resolve(tonumber(data and data.score) or 0) end
end)

function EXJ.playGame(game, count, seconds)
    gameWait = promise.new()
    SendNUIMessage({ action = 'game', game = game, count = count, seconds = seconds })
    SetNuiFocus(true, true)
    -- never stuck: the game ends by itself after its time (+ a margin)
    SetTimeout((seconds + 8) * 1000, function() if gameWait then gameWait:resolve(0) end end)
    local score = Citizen.Await(gameWait)
    gameWait = nil
    SetNuiFocus(false, false)
    return score
end

local function playAnim(anim)
    if not anim or not EXJ.loadDict(anim.dict) then return end
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function actBatch(index, spot)
    local step = C.job.chain[index]
    C.busy = true
    EXJ.clearPrompt('chain')
    TaskTurnPedToFaceCoord(cache.ped, spot.x, spot.y, spot.z, 600)
    Wait(400)
    local ok, info, item = lib.callback.await('exti_jobs:server:batchBegin', false, index)
    if not ok then
        if info == 'missing' then
            EXJ.notify(('تحتاج %s'):format(itemLabel(item)), 'error')
        else
            EXJ.notify(ERR[info] or ERR.failed, 'error')
        end
        C.busy = false
        return
    end
    local score = 1.0
    if step.kind == 'sellall' then
        local done = lib.progressBar({
            duration = info.seconds * 1000, label = step.progress or step.label, useWhileDead = false, canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = step.anim and { dict = step.anim.dict, clip = step.anim.clip, flag = 1 } or nil,
        })
        if not done then C.busy = false return end
    else
        playAnim(step.anim)
        FreezeEntityPosition(cache.ped, true)
        score = EXJ.playGame(step.game, info.count, info.seconds)
        FreezeEntityPosition(cache.ped, false)
        ClearPedTasks(cache.ped)
    end
    local done, r, why = lib.callback.await('exti_jobs:server:batchFinish', false, info.token, score)
    if done and step.kind == 'sellall' then
        EXJ.notify((step.sold or 'بعت %d'):format(r.sold), 'success', 5000)
    elseif done then
        local text = (step.done or 'أنجزت %d'):format(r.got)
        if r.lost > 0 then text = text .. ' · ' .. (step.lost or 'خسرت %d'):format(r.lost) end
        EXJ.notify(text, r.lost > 0 and 'inform' or 'success', 6000)
    elseif r == 'missing' then
        EXJ.notify(('تحتاج %s'):format(itemLabel(why)), 'error')
    else
        EXJ.notify(ERR[r] or ERR.failed, 'error')
    end
    C.busy = false
end

-- the "[E] ..." text for a step, or why it can't be done yet
local function promptFor(index)
    local job, step = C.job, C.job.chain[index]
    if step.kind == 'batch' or step.kind == 'sellall' then
        local n = C.have[step.take] or 0
        if n < 1 then
            local isSupply = false
            for _, s in ipairs(job.supplies or {}) do if s == step.take then isSupply = true end end
            return nil, isSupply and ('تحتاج %s من بقالة 24/7'):format(itemLabel(step.take)) or ('تحتاج %s'):format(itemLabel(step.take))
        end
        if step.kind == 'sellall' then
            return ('[E] %s (%d × %d$)'):format(step.label, n, step.price)
        end
        return ('[E] %s (%d %s)'):format(step.label, n, itemLabel(step.take))
    end
    if step.kind == 'collect' then
        local have = C.have[step.give.item] or 0
        if have >= step.cap then return nil, ('معك %d، الحد الأقصى. أكمل الخطوة التالية'):format(have) end
        return ('[E] %s (معك %d من %d)'):format(step.label, have, step.cap)
    end
    local ok, item, need = hasAll(step)
    if not ok then
        local isSupply = false
        for _, s in ipairs(job.supplies or {}) do if s == item then isSupply = true end end
        if isSupply then return nil, ('تحتاج %s من بقالة 24/7'):format(itemLabel(item)) end
        return nil, ('تحتاج %d %s (معك %d)'):format(need, itemLabel(item), C.have[item] or 0)
    end
    if step.kind == 'sell' then
        local item = next(step.take)
        return ('[E] %s (معك %d) · %d$'):format(step.label, C.have[item] or 0, step.price)
    end
    return ('[E] %s'):format(step.label)
end

---------------------------------------------------------------------------
-- the loop: circles, prompts, the gold line to the next step
---------------------------------------------------------------------------
local function loop()
    if C.running then return end
    C.running = true
    CreateThread(function()
        local items = allItemsOf(C.job)
        local lastCount = 0
        while EXJ.shift and C.job and EXJ.shift.job == C.name do
            local now = GetGameTimer()
            if now - lastCount > 1000 then
                lastCount = now
                C.have = counts(items)
                local route = nextStep()
                if route ~= C.routeStep then drawBlips(route) end
            end

            local sleep = 500
            local me = GetEntityCoords(cache.ped)
            local onFoot = not cache.vehicle
            local prompted = false
            for i, st in ipairs(C.job.chain) do
                local list = st.kind == 'collect' and st.spots or { st.spot }
                if st.ped then
                    -- the buyer: walk up to him and press E (no circle)
                    local h = math.rad(st.ped.w)
                    local front = vec3(st.ped.x - math.sin(h) * 1.1, st.ped.y + math.cos(h) * 1.1, st.ped.z)
                    if #(me - front) < SHOW then sleep = 0 end
                    if onFoot and not C.busy and not prompted and #(me.xy - front.xy) < 1.4 and math.abs(me.z - st.ped.z) < 2.5 then
                        local text, why = promptFor(i)
                        prompted = true
                        if text then
                            EXJ.prompt('chain', text)
                            if EXJ.pressedE() then
                                if st.kind == 'batch' or st.kind == 'sellall' then actBatch(i, st.ped.xyz) else act(i, nil, st.ped.xyz) end
                            end
                        else
                            EXJ.prompt('chain', why)
                        end
                    end
                    list = {}
                end
                for si, p in ipairs(list) do
                    local d = #(me - p)
                    if d < SHOW then
                        sleep = 0
                        local resting = st.kind == 'collect' and (C.rest[i .. ':' .. si] or 0) > now
                        if not resting then
                            local here = onFoot and #(me.xy - p.xy) < REACH
                            local z = EXJ.drawCircle(p, 0.9, here, false)
                            if here and not C.busy and not prompted and math.abs(me.z - z) < 2.5 then
                                local text, why = promptFor(i)
                                prompted = true
                                if text then
                                    EXJ.prompt('chain', text)
                                    if EXJ.pressedE() then
                                        if st.kind == 'batch' or st.kind == 'sellall' then actBatch(i, p) else act(i, st.kind == 'collect' and si or nil, p) end
                                    end
                                else
                                    EXJ.prompt('chain', why)
                                end
                            end
                        end
                    end
                end
            end
            if not prompted then EXJ.clearPrompt('chain') end
            Wait(sleep)
        end
        EXJ.clearPrompt('chain')
        C.running = false
    end)
end

local function stopJob()
    clearBlips()
    EXJ.clearPrompt('chain')
    C.name, C.job, C.routeStep, C.rest = nil, nil, nil, {}
end

-- one handler for every level job
for name, job in pairs(config.jobs) do
    if job.chain then
        EXJ.jobs[name] = {
            target = function()
                if C.name ~= name then return end
                local st = job.chain[nextStep()]
                return st.kind == 'collect' and st.spots[1] or st.spot, false
            end,
            start = function()
                C.name, C.job, C.rest = name, job, {}
                C.have = counts(allItemsOf(job))
                drawBlips(nextStep())
                local supplies = {}
                for _, item in ipairs(job.supplies or {}) do supplies[#supplies + 1] = itemLabel(item) end
                if job.noVehicle then
                    EXJ.notify(('سجّلت دخولك ولبست زي العمل. اشترِ %s من بقالة 24/7 ثم اتبع الخط الذهبي'):format(table.concat(supplies, '، ')), 'success', 10000)
                else
                    EXJ.notify(('بدأت المناوبة! خذ الشاحنة واتبع الخط الذهبي. لا تنسَ %s من بقالة 24/7'):format(table.concat(supplies, '، ')), 'success', 10000)
                end
                loop()
            end,
            update = function() end,
            stop = stopJob,
        }
    end
end

---------------------------------------------------------------------------
-- places moved in game (/jobspots): applied at once in every game
---------------------------------------------------------------------------
local function applySpots(value)
    spots.apply(config, value)
    -- the supervisors stand again where they should (the HQ loop puts them back)
    TriggerEvent('exti_jobs:client:respawnSupervisors')
    removeBuyer() -- they stand again where they should (the buyer loop puts them back)
    if C.job then drawBlips(nextStep()) end
end

AddStateBagChangeHandler('exti_jobs:spots', 'global', function(_, _, value)
    applySpots(value)
end)
CreateThread(function()
    applySpots(GlobalState['exti_jobs:spots'])
end)

-- the work vehicle of a level job: on the nearest road next to the supervisor (when no spot was set)
function EXJ.roadSpot(name)
    local job = config.jobs[name]
    if not job or not job.chain or (job.hq.spawns and job.hq.spawns[1]) then return nil end
    local s = job.hq.supervisor.coords
    for n = 1, 8 do
        local ok, pos, heading = GetNthClosestVehicleNodeWithHeading(s.x, s.y, s.z, n, 1, 3.0, 0)
        if ok and #(pos - s.xyz) < 150.0 and not IsAnyVehicleNearPoint(pos.x, pos.y, pos.z, 4.0) then
            return vec4(pos.x, pos.y, pos.z, heading)
        end
    end
end

---------------------------------------------------------------------------
-- admins: /jobspots [job] — move the places of a level job by standing where they should be
---------------------------------------------------------------------------
local SAVE_ERR = { many = 'وصلت 40 دائرة، احذف واحدة أولًا', admin = 'للإدارة فقط', nospot = 'لا توجد دائرة قريبة منك (6 أمتار)', last = 'لا يمكن حذف آخر دائرة', failed = 'تعذّر الحفظ' }
local showAll = false

local function save(name, what, stepId, action, okText)
    local ok, err = lib.callback.await('exti_jobs:server:spotSave', false, name, what, stepId, action)
    EXJ.notify(ok and okText or (SAVE_ERR[err] or SAVE_ERR.failed), ok and 'success' or 'error', 5000)
end

local function teleport(p)
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 2.0, false)
    SetEntityCoords(cache.ped, p.x, p.y, (found and gz or p.z) + 0.1, false, false, false, false)
end

local function openSpots(name)
    local job = config.jobs[name]
    local opts = {
        { title = ('المشرف يقف هنا (%s)'):format(job.hq.supervisor.name), icon = 'user', description = 'قف مكانه وانظر إلى الجهة التي يجب أن ينظر إليها',
          onSelect = function() save(name, 'supervisor', nil, nil, 'نُقل المشرف إلى مكانك') end },
    }
    if not job.noVehicle then
        opts[#opts + 1] = { title = 'مكان شاحنة العمل هنا', icon = 'truck', description = 'اجلس في مركبة على الطريق في الاتجاه الصحيح، أو قف مكانها',
            onSelect = function() save(name, 'vehicle', nil, nil, 'حُفظ مكان الشاحنة') end }
    end
    for _, st in ipairs(job.chain) do
        if st.kind == 'collect' then
            opts[#opts + 1] = { title = ('%s: أضف دائرة هنا (%d الآن)'):format(st.label, #st.spots), icon = 'plus',
                onSelect = function() save(name, 'step', st.id, 'add', 'أُضيفت دائرة في مكانك') end }
            opts[#opts + 1] = { title = ('%s: احذف أقرب دائرة'):format(st.label), icon = 'minus',
                onSelect = function() save(name, 'step', st.id, 'remove', 'حُذفت الدائرة') end }
            opts[#opts + 1] = { title = ('%s: امسح كل الدوائر وابدأ من هنا'):format(st.label), icon = 'eraser',
                onSelect = function() save(name, 'step', st.id, 'clear', 'بقيت دائرة واحدة في مكانك، أضف الباقي') end }
        else
            opts[#opts + 1] = { title = ('%s (%s): انقل الدائرة هنا'):format(st.label, st.place), icon = 'location-dot',
                onSelect = function() save(name, 'step', st.id, 'move', 'نُقلت الدائرة إلى مكانك') end }
            if st.kind == 'sell' or st.kind == 'sellall' then
                opts[#opts + 1] = { title = 'التاجر (شخص) يقف هنا', icon = 'user-tie', description = 'قف مكانه وانظر إلى الجهة التي يأتي منها الزبائن. لا دائرة بعدها: يمشي اللاعب إليه ويضغط E',
                    onSelect = function() save(name, 'step', st.id, 'ped', 'وُضع التاجر في مكانك') end }
            end
        end
    end
    opts[#opts + 1] = { title = showAll and 'أخفِ الدوائر' or 'أظهر كل الدوائر (حتى البعيدة)', icon = 'eye',
        onSelect = function() showAll = not showAll end }
    local go = {}
    go[#go + 1] = { title = 'المشرف', onSelect = function() teleport(job.hq.supervisor.coords) end }
    for _, st in ipairs(job.chain) do
        local p = st.kind == 'collect' and st.spots[1] or (st.ped and st.ped.xyz) or st.spot
        go[#go + 1] = { title = st.label, description = st.place, onSelect = function() teleport(p) end }
    end
    lib.registerContext({ id = 'exj_spots_go', title = 'انتقل إلى', menu = 'exj_spots', options = go })
    opts[#opts + 1] = { title = 'انتقل إلى...', icon = 'person-walking-arrow-right', menu = 'exj_spots_go' }
    opts[#opts + 1] = { title = 'أرجع كل الأماكن للأصل', icon = 'rotate-left', description = 'يمسح كل ما نقلته لهذه الوظيفة',
        onSelect = function()
            local sure = lib.alertDialog({ header = 'إرجاع الأماكن', content = 'متأكد؟ كل الأماكن التي نقلتها لهذه الوظيفة ستعود للأصل.', centered = true, cancel = true })
            if sure == 'confirm' then save(name, 'reset', nil, nil, 'رجعت كل الأماكن للأصل') end
        end }
    lib.registerContext({ id = 'exj_spots', title = ('أماكن وظيفة: %s'):format(job.label), options = opts })
    lib.showContext('exj_spots')
end

RegisterCommand('jobspots', function(_, args)
    if not lib.callback.await('exti_jobs:server:isAdmin', false) then return end
    local name = args[1]
    if name and config.jobs[name] and config.jobs[name].chain then return openSpots(name) end
    local opts = {}
    for _, n in ipairs(config.order) do
        local job = config.jobs[n]
        if job and job.chain then
            opts[#opts + 1] = { title = job.label, description = ('المستوى %d · %s'):format(job.minLevel or 1, job.hq.place), onSelect = function() openSpots(n) end }
        end
    end
    lib.registerContext({ id = 'exj_spots_jobs', title = 'أماكن الوظائف', options = opts })
    lib.showContext('exj_spots_jobs')
end, false)

-- admins: every circle of every level job, with its name (to check the places)
CreateThread(function()
    while true do
        if showAll then
            local me = GetEntityCoords(cache.ped)
            for _, job in pairs(config.jobs) do
                if job.chain then
                    local s = job.hq.supervisor.coords
                    if #(me - s.xyz) < 300.0 then
                        DrawMarker(2, s.x, s.y, s.z + 1.2, 0, 0, 0, 0, 180.0, 0, 0.4, 0.4, 0.4, 255, 255, 255, 200, false, true, 2, false, nil, nil, false)
                    end
                    for _, st in ipairs(job.chain) do
                        for _, p in ipairs(st.kind == 'collect' and st.spots or { st.spot }) do
                            if #(me - p) < 300.0 then EXJ.drawCircle(p, 0.9, false, false) end
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
