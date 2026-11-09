-- =====================================================================
-- EX_Tii builder (client): /build (admins). Search any GTA object, a see-through copy follows where you look,
-- turn / tilt / raise it, click to place it for everyone. Delete or move what you built.
-- The objects are only made near you (like the port fence), so a big build never fills the game up.
-- =====================================================================
local RES = GetCurrentResourceName()
local names = nil          -- every object name (loaded the first time you search)
local spawned = {}         -- [id] = { obj, sig }
local byEntity = {}        -- [obj] = id
local myLast = {}          -- ids I placed this session (for undo)
local lastModel, lastName = nil, nil
local busy = false         -- placing or deleting right now

local function notify(text, kind) lib.notify({ description = text, type = kind or 'inform' }) end

local function loadModel(m)
    m = tonumber(m) or joaat(m)
    if not IsModelInCdimage(m) or not IsModelValid(m) then return nil end
    RequestModel(m)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(m) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(m) and m or nil
end

local function make(m, x, y, z)
    local o = CreateObjectNoOffset(m, x, y, z, false, false, false)
    if o == 0 then o = CreateObjectNoOffset(m, x, y, z, false, false, true) end   -- (gates and doors only spawn as doors)
    return o
end

---------------------------------------------------------------------------
-- the placed objects, made when you are near
---------------------------------------------------------------------------
local function sigOf(b) return ('%s|%.3f|%.3f|%.3f|%.2f|%.2f|%.2f'):format(b.m, b.x, b.y, b.z, b.rx, b.ry, b.rz) end

local function drop(id)
    local s = spawned[id]
    if not s then return end
    if DoesEntityExist(s.obj) then DeleteEntity(s.obj) end
    byEntity[s.obj] = nil
    spawned[id] = nil
end

CreateThread(function()
    Wait(1500)
    while true do
        local list = type(GlobalState.extiBuilds) == 'table' and GlobalState.extiBuilds or {}
        local me = GetEntityCoords(cache.ped)
        local keep, madeNow = {}, 0
        for _, b in ipairs(list) do
            keep[b.id] = true
            local d = #(me - vec3(b.x, b.y, b.z))
            local s = spawned[b.id]
            if s and s.sig ~= sigOf(b) then drop(b.id) s = nil end   -- (it was moved)
            if d < Config.streamDistance and not s and madeNow < 40 then
                local m = loadModel(b.m)
                if m then
                    local o = make(m, b.x, b.y, b.z)
                    if o ~= 0 then
                        SetEntityRotation(o, b.rx + 0.0, b.ry + 0.0, b.rz + 0.0, 2, true)
                        SetEntityCoordsNoOffset(o, b.x, b.y, b.z, false, false, false)
                        FreezeEntityPosition(o, true)
                        SetEntityInvincible(o, true)
                        spawned[b.id] = { obj = o, sig = sigOf(b) }
                        byEntity[o] = b.id
                        madeNow = madeNow + 1
                    end
                    SetModelAsNoLongerNeeded(m)
                end
            elseif s and d > Config.streamDistance + 30.0 then
                drop(b.id)
            end
        end
        for id in pairs(spawned) do if not keep[id] then drop(id) end end   -- (removed by an admin)
        Wait(madeNow >= 40 and 0 or 1000)
    end
end)

AddStateBagChangeHandler('extiBuilds', 'global', function() end)   -- (the loop above picks the change up)

---------------------------------------------------------------------------
-- where the camera looks (the map and objects, up to 40 m)
---------------------------------------------------------------------------
local function aim(flags, ignore)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vec3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = cam + dir * 40.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, flags, ignore or cache.ped, 0)
    local _, hit, at, _, ent = GetShapeTestResult(ray)
    if hit == 1 then return at, ent end
end

---------------------------------------------------------------------------
-- placing
---------------------------------------------------------------------------
local HELP = table.concat({
    '[الفأرة] المكان  ·  [العجلة] تدوير',
    '[↑ ↓] إمالة للأمام  ·  [← →] إمالة للجانب',
    '[PageUp / PageDown] رفع وإنزال  ·  [G] على الأرض تلقائيًا',
    '[Shift] ببطء  ·  [زر أيسر] ضع  ·  [زر أيمن] خروج',
}, '  \n')

local CONTROLS = { 24, 25, 14, 15, 16, 17, 37, 140, 141, 142, 257, 263, 241, 242, 172, 173, 174, 175, 10, 11, 47, 58 }

local function place(model, name)
    local m = loadModel(model)
    if not m then return notify('هذا الموديل غير موجود في اللعبة', 'error') end
    busy = true
    lastModel, lastName = m, name
    local mn = GetModelDimensions(m)
    local p = GetEntityCoords(cache.ped)
    local ghost = make(m, p.x, p.y, p.z - 50.0)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    local turn, pitch, roll, lift, ground = 0.0, 0.0, 0.0, 0.0, true
    lib.showTextUI(HELP)
    notify(('تضع: %s'):format(name or tostring(m)))
    while busy do
        for _, c in ipairs(CONTROLS) do DisableControlAction(0, c, true) end
        local slow = IsControlPressed(0, 21)
        local step = slow and 1.0 or 7.5
        if IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15) then turn = turn + step end
        if IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14) then turn = turn - step end
        local tilt = slow and 0.5 or 2.5
        if IsDisabledControlPressed(0, 172) then pitch = pitch + tilt * 0.4 ground = false end
        if IsDisabledControlPressed(0, 173) then pitch = pitch - tilt * 0.4 ground = false end
        if IsDisabledControlPressed(0, 174) then roll = roll - tilt * 0.4 ground = false end
        if IsDisabledControlPressed(0, 175) then roll = roll + tilt * 0.4 ground = false end
        local up = slow and 0.005 or 0.03
        if IsDisabledControlPressed(0, 10) then lift = lift + up ground = false end
        if IsDisabledControlPressed(0, 11) then lift = lift - up ground = false end
        if IsDisabledControlJustPressed(0, 47) then
            ground = not ground
            if ground then pitch, roll, lift = 0.0, 0.0, 0.0 end
        end
        local at = aim(1 + 16, ghost)
        if at then
            local h = (GetGameplayCamRot(2).z + turn) % 360.0
            SetEntityVisible(ghost, true, false)
            SetEntityCoordsNoOffset(ghost, at.x, at.y, at.z - mn.z + lift, false, false, false)
            SetEntityRotation(ghost, pitch, roll, h, 2, true)
            if ground then PlaceObjectOnGroundProperly(ghost) end
            if IsDisabledControlJustPressed(0, 24) then
                local c, r = GetEntityCoords(ghost), GetEntityRotation(ghost, 2)
                local id = lib.callback.await('exti_builder:add', false, m, name, c.x, c.y, c.z, r.x, r.y, r.z)
                if id then myLast[#myLast + 1] = id else notify('لم يُحفظ (أنت بعيد أو لست أدمن)', 'error') end
            end
        else
            SetEntityVisible(ghost, false, false)
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 177) or IsEntityDead(cache.ped) then busy = false end
        Wait(0)
    end
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    SetModelAsNoLongerNeeded(m)
    lib.hideTextUI()
end

---------------------------------------------------------------------------
-- deleting / moving what was built
---------------------------------------------------------------------------
local function editMode()
    busy = true
    lib.showTextUI('[زر أيسر] احذف  ·  [R] انقل  ·  [زر أيمن] خروج  (انظر إلى قطعة بنيتها)')
    local lit = nil
    while busy do
        for _, c in ipairs({ 24, 25, 45, 140, 141, 142, 257, 263 }) do DisableControlAction(0, c, true) end
        local _, ent = aim(16)
        local id = ent and byEntity[ent]
        if lit and lit ~= ent and DoesEntityExist(lit) then SetEntityDrawOutline(lit, false) end
        lit = nil
        if id then
            SetEntityDrawOutline(ent, true)
            SetEntityDrawOutlineColor(32, 201, 151, 255)
            lit = ent
            if IsDisabledControlJustPressed(0, 24) then
                if lib.callback.await('exti_builder:remove', false, id) then notify('حُذفت', 'success') end
            elseif IsDisabledControlJustPressed(0, 45) then
                local model = GetEntityModel(ent)
                local name
                for _, b in ipairs(GlobalState.extiBuilds or {}) do if b.id == id then name = b.n end end
                if lib.callback.await('exti_builder:remove', false, id) then
                    if DoesEntityExist(ent) then SetEntityDrawOutline(ent, false) end
                    lib.hideTextUI()
                    busy = false
                    return place(model, name)
                end
            end
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 177) or IsEntityDead(cache.ped) then busy = false end
        Wait(0)
    end
    if lit and DoesEntityExist(lit) then SetEntityDrawOutline(lit, false) end
    lib.hideTextUI()
end

---------------------------------------------------------------------------
-- the menu
---------------------------------------------------------------------------
local function loadNames()
    if names then return names end
    names = {}
    local raw = LoadResourceFile(RES, 'data/objects.txt') or ''
    for line in raw:gmatch('[^\r\n]+') do names[#names + 1] = line end
    return names
end

local function search()
    local input = lib.inputDialog('ابحث عن قطعة', {
        { type = 'input', label = 'كلمة من اسمها بالإنجليزي (مثل: panel, sign, container, light, barrier, table)', required = true, min = 2 },
    })
    local word = input and tostring(input[1] or ''):lower():gsub('%s+', '_')
    if not word or #word < 2 then return end
    local found, options = 0, {}
    for _, n in ipairs(loadNames()) do
        if n:find(word, 1, true) and IsModelInCdimage(joaat(n)) then
            found = found + 1
            if found <= Config.maxResults then
                options[#options + 1] = { title = n, icon = 'cube', onSelect = function() CreateThread(function() place(n, n) end) end }
            end
        end
    end
    if found == 0 then return notify('لا يوجد شيء بهذا الاسم، جرّب كلمة أخرى', 'error') end
    lib.registerContext({
        id = 'exti_builder_results',
        title = found > Config.maxResults and ('%d نتيجة (أول %d، اكتب كلمة أدق)'):format(found, Config.maxResults) or ('%d نتيجة'):format(found),
        menu = 'exti_builder',
        options = options,
    })
    lib.showContext('exti_builder_results')
end

local function copyLooked()
    local _, ent = aim(16)
    if not ent or ent == 0 or GetEntityType(ent) ~= 3 then return notify('انظر إلى قطعة (ليست جزءًا من الخريطة نفسها) من قريب', 'error') end
    local ok, m = pcall(GetEntityModel, ent)
    if not ok or not m or m == 0 then return notify('لم أقرأ هذه القطعة', 'error') end
    CreateThread(function() place(m, ('model %d'):format(m)) end)
end

local function undo()
    local id = table.remove(myLast)
    if not id then return notify('لا يوجد شيء لتتراجع عنه', 'error') end
    if lib.callback.await('exti_builder:remove', false, id) then notify('تراجعت عن آخر قطعة', 'success') end
end

RegisterNetEvent('exti_builder:open', function()
    if busy then return end
    local list = GlobalState.extiBuilds or {}
    local options = {
        { title = 'ابحث عن قطعة', description = 'اكتب كلمة، اختر من القائمة، ثم ضعها', icon = 'magnifying-glass', onSelect = search },
        { title = 'انسخ القطعة التي تنظر إليها', description = 'أي قطعة في العالم (ليست جزءًا من الخريطة)', icon = 'eye-dropper', onSelect = copyLooked },
    }
    if lastModel then
        options[#options + 1] = { title = 'نفس القطعة مرة أخرى', description = lastName or tostring(lastModel), icon = 'clone',
            onSelect = function() CreateThread(function() place(lastModel, lastName) end) end }
    end
    options[#options + 1] = { title = 'احذف أو انقل قطعة', description = 'انظر إليها واضغط', icon = 'trash',
        onSelect = function() CreateThread(editMode) end }
    options[#options + 1] = { title = 'تراجع عن آخر قطعة', icon = 'rotate-left', disabled = #myLast == 0, onSelect = function() CreateThread(undo) end }
    lib.registerContext({ id = 'exti_builder', title = ('البنّاء · %d قطعة'):format(#list), options = options })
    lib.showContext('exti_builder')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    busy = false
    for id in pairs(spawned) do drop(id) end
end)
