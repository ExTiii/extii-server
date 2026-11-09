-- =====================================================================
-- EX_Tii gangs (game side): the Weed gang. Pots + plants (props that grow), care, harvest, the table,
-- and corner selling (use a bag of weed on a street corner; locals walk up to buy).
-- =====================================================================
local WD = C.weed
local state = GlobalState['exti_gangs:plants'] or { list = {} }
local props = {}   -- [gang:pot] = { pot = entity, plant = entity, stage }

local offset = 0   -- server clock - this game's clock (the server sends its time with the plants)
local function now() return GetCloudTimeAsInt() + offset end
local function plantOf(gang, pot) return state.list and state.list[gang] and state.list[gang][tostring(pot)] end
GC.plantOf = plantOf

local STAGE_MODELS = { `bkr_prop_weed_01_small_01a`, `bkr_prop_weed_med_01a`, `bkr_prop_weed_lrg_01a` }
local POT_MODEL = `bkr_prop_weed_bucket_01a`

local function stageOf(pl)
    if not pl then return 0 end
    local f = (now() - pl.planted) / WD.growSeconds
    return f < 0.33 and 1 or f < 0.8 and 2 or 3
end

local function load(m)
    if not IsModelInCdimage(m) then return false end
    RequestModel(m)
    local t = GetGameTimer()
    while not HasModelLoaded(m) and GetGameTimer() - t < 4000 do Wait(20) end
    return HasModelLoaded(m)
end

local function del(e) if e and DoesEntityExist(e) then DeleteEntity(e) end end

local refreshing = false
local doRefresh
local function refreshProps()
    if refreshing then return end   -- (the 15 s loop and a state change could both run it)
    refreshing = true
    local ok, err = pcall(doRefresh)
    refreshing = false
    if not ok then print('[exti_gangs] weed props: ' .. tostring(err)) end
end
doRefresh = function()
    local spots = GC.spots()
    local want = {}
    for gang, set in pairs(spots.hq or {}) do
        for i, p in ipairs(set.pots or {}) do
            local key = gang .. ':' .. i
            want[key] = true
            local pr = props[key] or {}
            props[key] = pr
            if not pr.pot or not DoesEntityExist(pr.pot) or pr.x ~= p.x or pr.y ~= p.y then
                del(pr.pot); del(pr.plant); pr.plant, pr.stage = nil, nil
                if load(POT_MODEL) then
                    pr.pot = CreateObject(POT_MODEL, p.x, p.y, p.z - 1.0, false, false, false)
                    PlaceObjectOnGroundProperly(pr.pot); FreezeEntityPosition(pr.pot, true)
                end
                pr.x, pr.y = p.x, p.y
            end
            local st = stageOf(plantOf(gang, i))
            if st ~= pr.stage then
                del(pr.plant); pr.plant = nil
                if st > 0 and load(STAGE_MODELS[st]) and pr.pot then
                    local c = GetEntityCoords(pr.pot)
                    pr.plant = CreateObject(STAGE_MODELS[st], c.x, c.y, c.z + 0.15, false, false, false)
                    FreezeEntityPosition(pr.plant, true)
                end
                pr.stage = st
            end
        end
    end
    for key, pr in pairs(props) do
        if not want[key] then del(pr.pot); del(pr.plant); props[key] = nil end
    end
end

if state.now then offset = state.now - GetCloudTimeAsInt() end
AddStateBagChangeHandler('exti_gangs:plants', 'global', function(_, _, v)
    state = v or { list = {} }
    if state.now then offset = state.now - GetCloudTimeAsInt() end
    SetTimeout(0, refreshProps)
end)
CreateThread(function()
    Wait(3000)
    while true do refreshProps(); Wait(15000) end   -- the plants grow
end)
AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    for _, pr in pairs(props) do del(pr.pot); del(pr.plant) end
end)

local WERR = {
    nogang = 'ليس لك شيء هنا', far = 'اقترب أكثر', locked = 'المقر مقفل: الإيجار غير مدفوع', rank = 'للطاقم فما فوق', taken = 'في هذا الأصيص نبتة',
    noseed = 'لا توجد بذور في مخزن العصابة', empty = 'الأصيص فارغ', wet = 'التراب ما زال رطبًا', done = 'سُمّدت من قبل',
    nofert = 'ليس معك سماد نباتات', growing = 'لم تنضج بعد', stashfull = 'مخزن العصابة ممتلئ', busy = 'أحد يعمل على الطاولة',
    nobuds = 'لا توجد براعم في المخزن', nobags = 'ليس معك أكياس حشيش', daily = 'بعت ما يكفي اليوم', taken2 = 'أحد يبيع قريبًا من هنا',
    moved = 'ابتعدت عن زاويتك: توقف البيع', cantnow = 'لا تستطيع البيع الآن', full = 'حقيبتك ممتلئة', stashfull = 'مخزن العصابة ممتلئ',
}
local function wfail(why, extra)
    local t = WERR[why] or 'لم ينجح'
    if why == 'growing' and extra then t = ('%s (%d:%02d)'):format(t, extra // 60, extra % 60) end
    GC.notify(t, 'error')
end

local function act(i, action, anim, ms, label, prop)
    if anim then
        local done = lib.progressBar({ duration = ms, label = label, canCancel = true, position = 'bottom',
            disable = { move = true, car = true, combat = true }, anim = anim, prop = prop })
        ClearPedTasks(PlayerPedId())
        if not done then return GC.notify('أُلغيت', 'error') end
    end
    local ok, r, extra = lib.callback.await('exti_gangs:server:pot', false, i, action)
    if not ok then return wfail(r, extra) end
    return true, r
end

-- [E] at one of my gang's pots
function GC.pot(i)
    local my = GC.my()
    if not my then return end
    local pl = plantOf(my.name, i)
    local opts = {}
    if not pl then
        opts[#opts + 1] = { title = 'ازرع بذرة', description = 'بذرة من مخزن العصابة · تنضج بعد 30 دقيقة', icon = 'seedling', disabled = my.rank < 1, onSelect = function()
            if act(i, 'plant', { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }, 5000, 'تزرع البذرة...') then GC.notify('زرعت البذرة: اسقِها كل 10 دقائق', 'success') end
        end }
    else
        local t = now()
        local left = math.max(0, pl.planted + WD.growSeconds - t)
        local wet = math.max(0, pl.watered + WD.waterLasts - t)
        opts[#opts + 1] = { title = left > 0 and ('تنضج بعد %d:%02d'):format(left // 60, left % 60) or 'ناضجة!', icon = 'cannabis', readOnly = true,
                            progress = math.floor(math.min(1, (t - pl.planted) / WD.growSeconds) * 100), colorScheme = 'green' }
        opts[#opts + 1] = { title = wet > 0 and ('التراب رطب (%d:%02d)'):format(wet // 60, wet % 60) or 'التراب جاف! اسقِها', icon = 'droplet', readOnly = true,
                            progress = math.floor(wet / WD.waterLasts * 100), colorScheme = wet > 0 and 'blue' or 'red' }
        if left > 0 then
            opts[#opts + 1] = { title = 'اسقِ النبتة', icon = 'droplet', onSelect = function()
                if act(i, 'water', { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flag = 1 }, 4000, 'تسقي النبتة...',
                    { model = 'prop_wateringcan', bone = 28422, pos = vec3(0.4, 0.1, 0.0), rot = vec3(90.0, 180.0, 0.0) }) then GC.notify('سقيت النبتة', 'success') end
            end }
            opts[#opts + 1] = { title = pl.fert and 'مسمّدة ✓' or 'سمّدها (سماد نباتات من حقيبتك)', description = pl.fert and nil or ('+%d%% محصول'):format(math.floor(WD.fertBonus * 100)),
                icon = 'flask', disabled = pl.fert, onSelect = function()
                if act(i, 'fert', { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }, 4000, 'تضع السماد...') then GC.notify('سمّدت النبتة', 'success') end
            end }
        else
            opts[#opts + 1] = { title = 'احصد', icon = 'scissors', disabled = my.rank < 1, onSelect = function()
                local ok, buds = act(i, 'harvest', { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }, 8000, 'تحصد النبتة...')
                if ok then GC.notify(('حصدت %d براعم إلى مخزن العصابة'):format(buds), 'success') end
            end }
        end
    end
    lib.registerContext({ id = 'exti_gang_pot', title = ('الأصيص %d'):format(i), options = opts })
    lib.showContext('exti_gang_pot')
end

-- the label for the [E] prompt at a pot
function GC.potLabel(i)
    local my = GC.my()
    local pl = my and plantOf(my.name, i)
    if not pl then return '[E] أصيص فارغ' end
    local left = pl.planted + WD.growSeconds - now()
    if left <= 0 then return '[E] النبتة ناضجة: احصد' end
    local wet = pl.watered + WD.waterLasts - now()
    return ('[E] نبتة · %d:%02d%s'):format(left // 60, left % 60, wet <= 0 and ' · تحتاج ماء!' or '')
end

---------------------------------------------------------------------------
-- the table: trim + weigh
---------------------------------------------------------------------------
function GC.weedTable()
    local ok, info = lib.callback.await('exti_gangs:server:weedTableBegin', false)
    if not ok then return wfail(info) end
    local function stop()
        ClearPedTasks(PlayerPedId())
        lib.callback.await('exti_gangs:server:weedTableStop', false)
        GC.notify('توقفت: عادت البراعم إلى المخزن', 'inform')
    end
    local steps = { { game = 'trim', title = 'قصّ الأوراق عن البراعم', pad = 'تجمع البراعم...' }, { game = 'weigh', title = 'زِن كل كيس 2 غرام', pad = 'تغلق الأكياس...' } }
    for i, st in ipairs(steps) do
        local t0 = GetGameTimer()
        lib.requestAnimDict('anim@amb@business@weed@weed_sorting_seated@')
        TaskPlayAnim(PlayerPedId(), 'anim@amb@business@weed@weed_sorting_seated@', 'sorter_right_sort_v3_sorter02', 3.0, 3.0, -1, 1, 0, false, false, false)
        local done = GC.minigame(st.game, ('%s (%d/2)'):format(st.title, i), { label = 'طاولة الحشيش', bags = info.bags })
        ClearPedTasks(PlayerPedId())
        if not done then return stop() end
        local left = (info.seconds[i] or 10) - (GetGameTimer() - t0) / 1000 + 1
        if left > 0.5 and not lib.progressBar({ duration = math.floor(left * 1000), label = st.pad, canCancel = true, position = 'bottom',
            disable = { move = true, car = true, combat = true } }) then return stop() end
        local fine, res = lib.callback.await('exti_gangs:server:weedTableStage', false, info.token, i)
        if not fine and res == 'fast' then Wait(2500); fine, res = lib.callback.await('exti_gangs:server:weedTableStage', false, info.token, i) end
        if not fine then return stop() end
        if i == 2 then GC.notify(('عبّأت %d أكياس إلى مخزن العصابة'):format(res), 'success') end
    end
end

---------------------------------------------------------------------------
-- corner selling: use a bag of weed on a corner
---------------------------------------------------------------------------
local selling = false
local buyer = nil
local buyerSince = 0

local function release(ped)
    if ped and DoesEntityExist(ped) then
        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
        SetPedKeepTask(ped, true)
        SetPedAsNoLongerNeeded(ped)
    end
end

local function stopSelling(msg)
    if not selling then return end
    selling = false
    lib.callback.await('exti_gangs:server:cornerStop', false)
    release(buyer); buyer = nil
    if GC.holdText then GC.holdText = false; GC.textUI(nil) end
    if msg then GC.notify(msg, 'inform') end
end

local function findBuyer(here)
    local best, bd = nil, 40.0
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(ped) and IsPedHuman(ped) and not IsPedDeadOrDying(ped, true) and not IsPedInAnyVehicle(ped, false)
            and not IsEntityAMissionEntity(ped) and GetPedType(ped) ~= 6 and GetPedType(ped) ~= 27 then   -- (not cops / swat)
            local d = #(GetEntityCoords(ped) - here)
            if d > 6.0 and d < bd then best, bd = ped, d end
        end
    end
    return best
end

local function sellLoop(nextIn)
    local here0 = GetEntityCoords(PlayerPedId())
    local nextAt = GetGameTimer() + (nextIn or 20) * 1000
    while selling do
        local ped = PlayerPedId()
        local here = GetEntityCoords(ped)
        if #(here - here0) > WD.corner.radius or IsPedInAnyVehicle(ped, false) then return stopSelling(WERR.moved) end
        if IsEntityDead(ped) or IsPedCuffed(ped) then return stopSelling('توقف البيع') end
        if not buyer and GetGameTimer() >= nextAt then
            buyer = findBuyer(here)
            -- (an ambient ped may belong to another player's game: take control first, or skip him)
            if buyer then
                local t = GetGameTimer()
                NetworkRequestControlOfEntity(buyer)
                while not NetworkHasControlOfEntity(buyer) and GetGameTimer() - t < 1500 do Wait(50); NetworkRequestControlOfEntity(buyer) end
                if not NetworkHasControlOfEntity(buyer) then buyer = nil end
            end
            if buyer then
                SetEntityAsMissionEntity(buyer, true, true)
                ClearPedTasks(buyer)
                TaskGoToEntity(buyer, ped, -1, 1.2, 1.4, 1073741824, 0)
                buyerSince = GetGameTimer()
            else
                nextAt = GetGameTimer() + 8000
            end
        end
        if buyer then
            if not DoesEntityExist(buyer) or IsPedDeadOrDying(buyer, true) then buyer = nil; nextAt = GetGameTimer() + 8000
            elseif GetGameTimer() - buyerSince > 25000 and #(GetEntityCoords(buyer) - here) >= 2.0 then
                release(buyer); buyer = nil; nextAt = GetGameTimer() + 8000   -- he never made it: the next one
            else
                local d = #(GetEntityCoords(buyer) - here)
                if d < 2.0 then
                    TaskTurnPedToFaceEntity(buyer, ped, 1500)
                    GC.holdText = true
                    GC.textUI('[E] بِع · [G] اطرده')
                    local untilT = GetGameTimer() + 12000
                    local sold = nil
                    while GetGameTimer() < untilT and selling do
                        if (IsControlJustReleased(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) and GC.lineIs('[E] بِع · [G] اطرده') then sold = true break end
                        if IsControlJustReleased(0, 47) then sold = false break end
                        Wait(0)
                    end
                    GC.textUI(nil)
                    GC.holdText = false
                    if sold then
                        lib.requestAnimDict('mp_common')
                        TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 49, 0, false, false, false)
                        TaskPlayAnim(buyer, 'mp_common', 'givetake1_b', 8.0, -8.0, 2000, 49, 0, false, false, false)
                        Wait(1800)
                        local ok, r, extra = lib.callback.await('exti_gangs:server:cornerSell', false)
                        if ok then
                            PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', false)
                            GC.notify(('بعت %d أكياس بـ $%d (مال غير نظيف)'):format(r.bags, r.money), 'success')
                            nextAt = GetGameTimer() + (r.next or 25) * 1000
                            if r.left < 1 then release(buyer); buyer = nil; return stopSelling('خلصت أكياسك') end
                        elseif r == 'wait' then
                            nextAt = GetGameTimer() + (extra or 10) * 1000
                        else
                            release(buyer); buyer = nil
                            return stopSelling(WERR[r] or 'توقف البيع')
                        end
                    else
                        nextAt = GetGameTimer() + 15000
                    end
                    release(buyer); buyer = nil
                end
            end
        end
        Wait(250)
    end
end

exports('useBag', function()
    CreateThread(function()
        if selling then return stopSelling('أوقفت البيع') end
        if IsPedInAnyVehicle(PlayerPedId(), false) then return GC.notify('انزل من السيارة أولًا', 'error') end
        local ok, r = lib.callback.await('exti_gangs:server:cornerStart', false)
        if not ok then return wfail(r == 'taken' and 'taken2' or r) end
        selling = true
        local where = r.kind == 'own' and ' · في منطقتكم' or r.kind == 'rival' and ' · في منطقة عصابة أخرى!' or ''
        GC.notify(('تبيع على الزاوية%s. انتظر الزبائن (استعمل الكيس مرة ثانية للإيقاف)'):format(where), 'inform', 7000)
        sellLoop(r.first)
    end)
end)
