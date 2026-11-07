-- EX_Tii used-car lot (game side): the manager, the red icon, the cars on the lot (a copy in every game),
-- [E] to put your car up for sale, to buy a car on the lot, or to take yours back.
local ped, blip = nil, nil
local shown = {}          -- [listing id] = vehicle (this game's copy)
local busy = false
local prompt = nil

local function spot() return GlobalState['exti_usedcars:spot'] or Config.spot end
local function slots() return GlobalState['exti_usedcars:slots'] or {} end
local function list() return GlobalState['exti_usedcars:list'] or {} end
local function money(n) return lib.math.groupdigits(n) end
local function notify(kind, text, ms) lib.notify({ type = kind, description = text, duration = ms }) end

local function showPrompt(text)
    if prompt == text then return end
    prompt = text
    lib.showTextUI(text)
    LocalPlayer.state:set('extiJobPrompt', true, false)
end
local function hidePrompt()
    if not prompt then return end
    prompt = nil
    lib.hideTextUI()
    LocalPlayer.state:set('extiJobPrompt', false, false)
end

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

-- the cars on the lot: a still, locked copy in this game
local function removeCar(id)
    local v = shown[id]
    if v and DoesEntityExist(v) then DeleteEntity(v) end
    shown[id] = nil
end

local function showCar(l)
    local s = slots()[l.slot]
    if not s or (shown[l.id] and DoesEntityExist(shown[l.id])) then return end
    local model = l.props and l.props.model
    if not model or not IsModelInCdimage(model) or not lib.requestModel(model, 8000) then return end
    RequestCollisionAtCoord(s.x, s.y, s.z)
    local v = CreateVehicle(model, s.x, s.y, s.z, s.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if v == 0 then return end
    lib.setVehicleProperties(v, l.props)
    SetVehicleOnGroundProperly(v)
    SetVehicleDirtLevel(v, 0.0)
    FreezeEntityPosition(v, true)
    SetEntityInvincible(v, true)
    SetEntityCanBeDamaged(v, false)
    SetVehicleDoorsLocked(v, 2)
    SetVehicleUndriveable(v, true)
    shown[l.id] = v
end

local function refreshCars()
    local me = GetEntityCoords(cache.ped)
    local alive = {}
    for _, l in ipairs(list()) do
        local s = slots()[l.slot]
        if s then
            local d = #(me - s.xyz)
            if d < 150.0 then alive[l.id] = true; showCar(l) end
        end
    end
    for id in pairs(shown) do if not alive[id] then removeCar(id) end end
end

-- EX_Tii: no GTA traffic or parked cars on the lot: the car generators there are off, and an ambient car
-- that still ends up on a lot space is removed (never a player's car: those are script cars, not ambient)
local genBox = nil
local function lotBox()
    local list = {}
    for _, sl in ipairs(slots()) do list[#list + 1] = sl.xyz end
    list[#list + 1] = spot().xyz
    local mn, mx = vec3(1e9, 1e9, 1e9), vec3(-1e9, -1e9, -1e9)
    for _, p in ipairs(list) do
        mn = vec3(math.min(mn.x, p.x), math.min(mn.y, p.y), math.min(mn.z, p.z))
        mx = vec3(math.max(mx.x, p.x), math.max(mx.y, p.y), math.max(mx.z, p.z))
    end
    return mn - vec3(15.0, 15.0, 6.0), mx + vec3(15.0, 15.0, 6.0)
end
local function generatorsOff()
    if genBox then SetAllVehicleGeneratorsActiveInArea(genBox[1].x, genBox[1].y, genBox[1].z, genBox[2].x, genBox[2].y, genBox[2].z, true, true) end
    local mn, mx = lotBox()
    genBox = { mn, mx }
    SetAllVehicleGeneratorsActiveInArea(mn.x, mn.y, mn.z, mx.x, mx.y, mx.z, false, false)
    RemoveVehiclesFromGeneratorsInArea(mn.x, mn.y, mn.z, mx.x, mx.y, mx.z)
end

local function clearSpaces()
    local mine = {}
    for _, v in pairs(shown) do mine[v] = true end
    for _, sl in ipairs(slots()) do
        for _, v in ipairs(lib.getNearbyVehicles(sl.xyz, 3.0, true)) do
            local veh = v.vehicle
            local pop = GetEntityPopulationType(veh)
            if not mine[veh] and pop ~= 7 and pop ~= 0 and not IsEntityAMissionEntity(veh) and GetPedInVehicleSeat(veh, -1) == 0 then
                if NetworkGetEntityIsNetworked(veh) and not NetworkHasControlOfEntity(veh) then
                    NetworkRequestControlOfEntity(veh)
                else
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                end
            end
        end
    end
end

CreateThread(function()
    Wait(2000)
    generatorsOff()
    while true do
        if #(GetEntityCoords(cache.ped) - spot().xyz) < 250.0 then
            RemoveVehiclesFromGeneratorsInArea(genBox[1].x, genBox[1].y, genBox[1].z, genBox[2].x, genBox[2].y, genBox[2].z)
            clearSpaces()
        end
        Wait(3000)
    end
end)

AddStateBagChangeHandler('exti_usedcars:list', 'global', function() SetTimeout(50, refreshCars) end)
AddStateBagChangeHandler('exti_usedcars:slots', 'global', function()
    SetTimeout(50, function() for id in pairs(shown) do removeCar(id) end refreshCars(); generatorsOff() end)
end)
AddStateBagChangeHandler('exti_usedcars:spot', 'global', function() SetTimeout(100, function() removePed(); makeBlip() end) end)

-- the name and price floating over each car
local function text3d(x, y, z, line)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.36, 0.36)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(line)
    EndTextCommandDisplayText(sx, sy)
end

---------------------------------------------------------------------------
-- the actions
---------------------------------------------------------------------------
local ERR = {
    far = 'اقترب أكثر', inside = 'انزل من المركبة أولًا',
    nocar = 'أوقف سيارتك قرب مدير المعرض أولًا (آخر سيارة قدتها)', people = 'أنزل الركاب من السيارة أولًا',
    notyours = 'هذه السيارة ليست ملكك', financed = 'لا يمكن بيع سيارة عليها أقساط',
    unknown = 'المعرض لا يقبل هذا النوع من المركبات', many = ('لك %d سيارات في المعرض، وهذا الحد'):format(Config.perSeller),
    full = 'المعرض ممتلئ الآن، عد لاحقًا', noslots = 'المعرض لم يُجهَّز بعد: لا توجد أماكن للسيارات (الإدارة: /usedcarslot)', price = 'السعر خارج الحد المسموح', money = 'ليس معك مال كافٍ (في البنك أو نقدًا)',
    own = 'هذه سيارتك: اسحبها من مدير المعرض', gone = 'بيعت هذه السيارة للتو', wait = 'لحظة...', failed = 'حدث خطأ، حاول مرة أخرى',
}
local function fail(code) notify('error', ERR[code] or ERR.failed) end

local function sellMine()
    local veh = GetPlayersLastVehicle()
    if veh == 0 or not DoesEntityExist(veh) then return fail('nocar') end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local ok, q = lib.callback.await('exti_usedcars:server:quote', false, netId)
    if not ok then return fail(q) end
    local input = lib.inputDialog(('اعرض %s للبيع'):format(q.label), {
        { type = 'number', label = 'سعر البيع ($)', required = true, default = q.price, min = q.min, max = q.max, step = 50,
          description = ('سعرها في المعرض الجديد %s$ · تستطيع أن تطلب بين %s$ و%s$'):format(money(q.price), money(q.min), money(q.max)) },
    })
    if not input then return end
    local price = tonumber(input[1])
    if not price then return end
    local sure = lib.alertDialog({
        header = 'عرض السيارة للبيع',
        content = ('ستقف **%s** (اللوحة %s) في المعرض بسعر **%s$**.\n\nتخرج من مرآبك الآن. حين يشتريها أحد يصل المبلغ إلى حسابك البنكي، وتستطيع سحبها من مدير المعرض متى شئت.'):format(q.label, q.plate, money(price)),
        centered = true, cancel = true, labels = { confirm = 'اعرضها', cancel = 'لا' },
    })
    if sure ~= 'confirm' then return end
    local done, r = lib.callback.await('exti_usedcars:server:list', false, netId, price)
    if not done then return fail(r) end
    notify('success', ('سيارتك %s معروضة الآن في المعرض بـ %s$'):format(r.label, money(r.price)), 8000)
end

local function takeBack(l)
    local sure = lib.alertDialog({ header = 'سحب السيارة', content = ('تسحب %s من المعرض وتستلمها مكانها؟'):format(l.label or ''), centered = true, cancel = true,
        labels = { confirm = 'اسحبها', cancel = 'لا' } })
    if sure ~= 'confirm' then return end
    local ok, r = lib.callback.await('exti_usedcars:server:takeBack', false, l.id)
    if not ok then return fail(r) end
    notify('success', ('استلمت %s، المفتاح معك'):format(r.label or ''), 7000)
end

local function managerMenu()
    local cid = QBX and QBX.PlayerData and QBX.PlayerData.citizenid
    local opts = {
        { title = 'اعرض سيارتك للبيع', icon = 'tag', description = 'أوقفها قرب المدير وانزل منها، ثم حدّد سعرك (75% إلى 125% من سعرها الأصلي)', onSelect = function() CreateThread(sellMine) end },
    }
    for _, l in ipairs(list()) do
        if l.seller == cid then
            opts[#opts + 1] = { title = ('%s · %s$'):format(l.label or '', money(l.price)), icon = 'car', description = 'سيارتك في المعرض: اضغط لسحبها',
                onSelect = function() CreateThread(function() takeBack(l) end) end }
        end
    end
    lib.registerContext({ id = 'exti_usedcars', title = 'معرض السيارات المستعملة', options = opts })
    lib.showContext('exti_usedcars')
end

local function buy(l)
    local sure = lib.alertDialog({
        header = 'شراء السيارة',
        content = ('تشتري **%s** بـ **%s$**؟\n\nيُدفع من حسابك البنكي (أو نقدًا إن لم يكفِ البنك)، وتستلم السيارة ومفتاحها هنا.'):format(l.label or '', money(l.price)),
        centered = true, cancel = true, labels = { confirm = 'اشترِها', cancel = 'لا' },
    })
    if sure ~= 'confirm' then return end
    local ok, r = lib.callback.await('exti_usedcars:server:buy', false, l.id)
    if not ok then return fail(r) end
    notify('success', ('مبروك! اشتريت %s بـ %s$، المفتاح معك'):format(r.label or '', money(r.price)), 8000)
end

---------------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------------
CreateThread(function()
    makeBlip()
    local lastCars = 0
    while true do
        local s = spot()
        local me = GetEntityCoords(cache.ped)
        local d = #(me - s.xyz)
        local sleep = 1000
        if d < 100.0 then spawnPed() elseif d > 130.0 then removePed() end
        if GetGameTimer() - lastCars > 2000 then lastCars = GetGameTimer(); refreshCars() end
        local want = nil
        if d < 160.0 then
            sleep = 250
            local cid = QBX and QBX.PlayerData and QBX.PlayerData.citizenid
            local onFoot = not cache.vehicle
            -- the manager
            if onFoot and d < 2.2 then want = { text = '[E] تحدّث مع مدير المعرض', run = managerMenu } end
            -- the cars
            for _, l in ipairs(list()) do
                local v = shown[l.id]
                if v and DoesEntityExist(v) then
                    local c = GetEntityCoords(v)
                    local dc = #(me - c)
                    if dc < 12.0 then
                        sleep = 0
                        text3d(c.x, c.y, c.z + 1.2, ('%s~n~~g~$%s'):format(l.label or '', money(l.price)))
                    end
                    if onFoot and not want and dc < 3.2 then
                        if l.seller == cid then
                            want = { text = 'سيارتك معروضة · اسحبها من مدير المعرض' }
                        else
                            want = { text = ('[E] اشترِ %s · %s$'):format(l.label or '', money(l.price)), run = function() buy(l) end }
                        end
                    end
                end
            end
            if want then sleep = 0 end
        end
        if want and not busy then
            showPrompt(want.text)
            if want.run and (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then
                hidePrompt()
                busy = true
                CreateThread(function() want.run(); busy = false end)
            end
        else
            hidePrompt()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removePed()
    for id in pairs(shown) do removeCar(id) end
    if genBox then SetAllVehicleGeneratorsActiveInArea(genBox[1].x, genBox[1].y, genBox[1].z, genBox[2].x, genBox[2].y, genBox[2].z, true, true) end
    if prompt then lib.hideTextUI() end
end)
