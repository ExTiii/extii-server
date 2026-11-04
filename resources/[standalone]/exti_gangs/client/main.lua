-- =====================================================================
-- EX_Tii gangs (game side): E prompts at the HQ (laptop, stash, hand-in, locker, bench),
-- the shared collection point, the fence, invites, the car alarm, /gangspots.
-- The game only asks; the server decides.
-- =====================================================================
C = require 'config'
GC = {}                          -- shared with client/chop.lua
local my = nil                   -- my gang (name, type, rank, color, tag, label, locked) or nil
local spots = GlobalState['exti_gangs:spots'] or { hq = {}, collect = { crates = {} } }
local crates = {}                -- spawned crate props [i] = entity
local fencePed = nil
local bmPed = nil
local busy = false
GC.my = function() return my end
GC.spots = function() return spots end

local function notify(text, kind, duration)
    lib.notify({ description = text, type = kind or 'inform', position = 'top', duration = duration or 5000 })
end
GC.notify = notify

local function v3(p) return p and vec3(p.x, p.y, p.z) or nil end

---------------------------------------------------------------------------
-- who am I
---------------------------------------------------------------------------
local function refresh()
    local r = lib.callback.await('exti_gangs:server:myGang', false)
    my = r and r.mine or nil
    SendNUIMessage({ action = 'me', gang = my })
end
GC.refresh = refresh
RegisterNetEvent('exti_gangs:client:refresh', function() SetTimeout(300, refresh) end)
RegisterNetEvent('exti_gangs:client:gangsChanged', function() SetTimeout(300, refresh) end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(1500, refresh) end)
RegisterNetEvent('QBCore:Client:OnGangUpdate', function() SetTimeout(500, refresh) end)
CreateThread(function()
    Wait(1500)
    if LocalPlayer.state.isLoggedIn then refresh() end
end)

AddStateBagChangeHandler('exti_gangs:spots', 'global', function(_, _, value)
    spots = value or { hq = {}, collect = { crates = {} } }
    GC.rebuild()
end)

---------------------------------------------------------------------------
-- props: the collection crates and the fence
---------------------------------------------------------------------------
local function loadModel(m)
    local h = type(m) == 'number' and m or joaat(m)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 5000 do Wait(20) end
    return HasModelLoaded(h) and h or nil
end

function GC.rebuild()
    for _, e in pairs(crates) do if DoesEntityExist(e) then DeleteEntity(e) end end
    crates = {}
    if fencePed and DoesEntityExist(fencePed) then DeleteEntity(fencePed) end
    fencePed = nil
    if bmPed and DoesEntityExist(bmPed) then DeleteEntity(bmPed) end
    bmPed = nil
    if spots.blackmarket then
        local bh = loadModel(C.blackMarket.model)
        if bh then
            bmPed = CreatePed(4, bh, spots.blackmarket.x, spots.blackmarket.y, spots.blackmarket.z - 1.0, spots.blackmarket.h or 0.0, false, false)
            SetEntityInvincible(bmPed, true); FreezeEntityPosition(bmPed, true); SetBlockingOfNonTemporaryEvents(bmPed, true)
            TaskStartScenarioInPlace(bmPed, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        end
    end
    local h = loadModel(C.collect.crateModel)
    for i, c in ipairs(spots.collect and spots.collect.crates or {}) do
        if h then
            local e = CreateObject(h, c.x, c.y, c.z - 1.0, false, false, false)
            SetEntityHeading(e, c.h or 0.0); PlaceObjectOnGroundProperly(e); FreezeEntityPosition(e, true)
            crates[i] = e
        end
    end
    if spots.fence then
        local ph = loadModel(C.fence.model)
        if ph then
            local f = spots.fence
            fencePed = CreatePed(4, ph, f.x, f.y, f.z - 1.0, f.h or 0.0, false, false)
            if f.snap then
                -- (a spot from the daily list: when you come close, he is stood on the real ground there)
                local ped = fencePed
                CreateThread(function()
                    while DoesEntityExist(ped) do
                        if #(GetEntityCoords(cache.ped) - vec3(f.x, f.y, f.z)) < 150.0 then
                            RequestCollisionAtCoord(f.x, f.y, f.z)
                            for _ = 1, 40 do
                                local found, gz = GetGroundZFor_3dCoord(f.x, f.y, f.z + 25.0, false)
                                if found and math.abs(gz - f.z) < 30.0 then SetEntityCoordsNoOffset(ped, f.x, f.y, gz + 1.0, false, false, false) break end
                                Wait(100)
                            end
                            return
                        end
                        Wait(2000)
                    end
                end)
            end
            SetEntityInvincible(fencePed, true); FreezeEntityPosition(fencePed, true); SetBlockingOfNonTemporaryEvents(fencePed, true)
            TaskStartScenarioInPlace(fencePed, 'WORLD_HUMAN_SMOKING', 0, true)
        end
    end
end
CreateThread(function() Wait(2000); GC.rebuild() end)
AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    for _, e in pairs(crates) do if DoesEntityExist(e) then DeleteEntity(e) end end
    if fencePed and DoesEntityExist(fencePed) then DeleteEntity(fencePed) end
    if bmPed and DoesEntityExist(bmPed) then DeleteEntity(bmPed) end
end)

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------
local ERR = {
    nogang = 'ليس لك شيء هنا', soon = 'نوع عصابتك لم يُفتح بعد (قريبًا)', far = 'اقترب أكثر', cooldown = 'انتظر قبل الجولة التالية',
    crate = 'هذا الصندوق فارغ الآن، جرّب صندوقًا آخر', daily = 'وصلت حدك اليومي من القطع', full = 'حقيبتك ممتلئة',
    skill = 'فشلت: لم تحصل على شيء', fast = 'أسرع من اللازم', failed = 'حدث خطأ', locked = 'المقر مقفل: الإيجار غير مدفوع',
    closed = 'الزعيم أوقف تسليم القطع', none = 'ليس معك قطع لعصابتك', gangcap = 'العصابة وصلت حدها اليومي من القطع',
    mecap = 'وصلت حدك اليومي من التسليم', bank = 'بنك العصابة لا يكفي لدفع أجرك', stashfull = 'مخزن العصابة ممتلئ',
    rank = 'رتبتك لا تسمح', tools = 'لا توجد أدوات تفكيك في المخزن',
    notmine = 'تُدفع فقط القطع التي جمعتها بنفسك (ضع غيرها في المخزن)',
    tiesdaily = 'العصابة وصلت حدها اليومي من صنع الأربطة', tiesparts = 'لا توجد قطع كافية في مخزن العصابة',
}
GC.ERR = ERR
local function fail(why, extra)
    local t = ERR[why] or why or ERR.failed
    if why == 'cooldown' or why == 'crate' then t = ('%s (%d:%02d)'):format(t, (extra or 0) // 60, (extra or 0) % 60) end
    if why == 'bank' and extra then t = ('%s ($%d مطلوب)'):format(t, extra) end
    notify(t, 'error')
end
GC.fail = fail

local function doCrate(i)
    local ok, info, extra = lib.callback.await('exti_gangs:server:collectBegin', false, i)
    if not ok then return fail(info, extra) end
    local part = info.seconds / (info.checks + 1)
    local passed = true
    for k = 0, info.checks do
        local done = lib.progressBar({
            duration = math.floor(part * 1000), label = 'تفتّش الصندوق...', canCancel = true, position = 'bottom',
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
        })
        if not done then TriggerServerEvent('exti_gangs:server:collectCancel'); return notify('أُلغيت', 'error') end
        if k < info.checks and not lib.skillCheck({ 'easy', 'medium' }, { 'e' }) then passed = false break end
    end
    if not passed then Wait(0) end
    local fin, res = lib.callback.await('exti_gangs:server:collectFinish', false, info.token, passed)
    if not fin then return fail(res) end
    notify(('حصلت على %d قطع. سلّمها في مقر العصابة'):format(res.count), 'success')
end

local function doDeposit()
    local ok, res, extra = lib.callback.await('exti_gangs:server:deposit', false)
    if not ok then return fail(res, extra) end
    if res.paid > 0 then
        notify(('سلّمت %d قطعة · +$%d في جيبك'):format(res.count, res.paid), 'success', 6000)
    else
        notify(('سلّمت %d قطعة إلى المخزن'):format(res.count), 'success')
    end
    if res.left > 0 then notify(('بقي معك %d (وصلت الحد)'):format(res.left), 'inform') end
end

local function doStash()
    local id, why = lib.callback.await('exti_gangs:server:openStash', false)
    if not id then return fail(why) end
    exports.ox_inventory:openInventory('stash', id)
end

-- the stash also makes zip ties and blindfolds (from the gang's own parts)
local function makeTies(item)
    local T = C.ties
    local inp = lib.inputDialog(item == 'zip_ties' and 'صنع أربطة بلاستيكية' or 'صنع عصابات عيون', {
        { type = 'slider', label = ('كم قطعة؟ (القطعة = %d)'):format(T[item].per), min = 1, max = T.maxParts, default = 1 },
    })
    local parts = inp and tonumber(inp[1])
    if not parts then return end
    local ok, need, count = lib.callback.await('exti_gangs:server:tiesBegin', false, item, parts)
    if not ok then return fail(need) end
    local done = lib.progressBar({ duration = need * 1000, label = ('تصنع %d %s...'):format(count, T[item].label), canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped' } })
    local res, got = lib.callback.await('exti_gangs:server:tiesEnd', false, done == true)
    if res then notify(('صنعت %d %s · في حقيبتك'):format(got, T[item].label), 'success') elseif done then notify(ERR.failed, 'error') end
end
local function stashMenu()
    local T = C.ties
    lib.registerContext({ id = 'exti_gang_stash', title = 'مخزن العصابة', options = {
        { title = 'افتح المخزن', icon = 'box-open', onSelect = doStash },
        { title = 'اصنع أربطة بلاستيكية', description = ('قطعة واحدة من قطع العصابة = %d أربطة'):format(T.zip_ties.per), icon = 'link', onSelect = function() makeTies('zip_ties') end },
        { title = 'اصنع عصابات عيون', description = ('قطعة واحدة = %d عصابات'):format(T.blindfold.per), icon = 'eye-slash', onSelect = function() makeTies('blindfold') end },
    } })
    lib.showContext('exti_gang_stash')
end

local function sellParts()
    local ok, res = lib.callback.await('exti_gangs:server:fence', false)
    if not ok then return notify(res == 'none' and 'ليس معك قطع أبيعها' or ERR[res] or ERR.failed, 'error') end
    notify(('بعت %d قطعة بـ $%d (مال غير نظيف)'):format(res.count, res.money), 'success')
end
-- the fence: car parts (the gangs) and, with exti_heists, stolen goods and house leads
local function doFence()
    if GetResourceState('exti_heists') ~= 'started' then return sellParts() end
    local opts = { { title = 'بِع قطع السيارات المسروقة', icon = 'car-burst', onSelect = sellParts } }
    local prices = lib.callback.await('exti_heists:server:fencePrices', false) or {}
    local desc, have = {}, 0
    for _, p in ipairs(prices) do
        if p.have > 0 then have = have + p.have end
        local it = exports.ox_inventory:Items(p.item)
        desc[#desc + 1] = ('%s %d$%s'):format((it and it.label or p.item):gsub(' %(.*%)', ''), p.price, p.left == 0 and ' (اكتفى اليوم)' or '')
    end
    opts[#opts + 1] = { title = 'بِع المسروقات والمجوهرات', description = have > 0 and table.concat(desc, ' · ') or 'ليس معك ما يشتريه', icon = 'gem', disabled = have == 0,
        onSelect = function()
            local ok, res = lib.callback.await('exti_heists:server:fenceGoods', false)
            if not ok then return notify(res == 'limit' and 'اكتفى من هذا اليوم: تعال غدًا' or 'ليس معك ما يشتريه', 'error') end
            notify(('بعت المسروقات بـ $%d (مال غير نظيف)%s'):format(res.money, res.limited and ' · بعض الأشياء لم يأخذها: اكتفى اليوم' or ''), 'success', 7000)
        end }
    opts[#opts + 1] = { title = 'عندك شغل؟', description = 'بيت فاضٍ للسرقة (بالليل فقط)', icon = 'house-chimney-crack',
        onSelect = function()
            local ok, res = lib.callback.await('exti_heists:server:fenceLead', false)
            if not ok then return notify(type(res) == 'string' and #res > 10 and res or 'لا شيء لك الآن', 'error', 6000) end
        end }
    opts[#opts + 1] = { title = 'خذ رقمي', description = 'يرسل لك رسالة على الهاتف', icon = 'mobile-screen',
        onSelect = function()
            local num = lib.callback.await('exti_heists:server:fenceHello', false)
            if num then notify(('رقم المصرّف: %s · وصلتك رسالة منه'):format(num), 'success', 8000) end
        end }
    lib.registerContext({ id = 'exti_gang_fence', title = C.fence.name, options = opts })
    lib.showContext('exti_gang_fence')
end

local function doBench()
    local ok, info = lib.callback.await('exti_gangs:server:benchBegin', false)
    if not ok then return fail(info) end
    local done = lib.progressBar({
        duration = info.seconds * 1000, label = 'تصنع مفاتيح فتح من أدوات التفكيك...', canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', clip = 'weed_spraybottle_crouch_base_inspector', flag = 1 },
    })
    if not done then return notify('أُلغيت', 'error') end
    local fin, n = lib.callback.await('exti_gangs:server:benchFinish', false, info.token)
    if not fin then return fail(n) end
    notify(('صنعت %d مفاتيح فتح إلى المخزن'):format(n), 'success')
end

-- the gang outfit
local function readOutfit()
    local ped = PlayerPedId()
    local comps, props = {}, {}
    for i = 0, 11 do comps[tostring(i)] = { GetPedDrawableVariation(ped, i), GetPedTextureVariation(ped, i) } end
    for i = 0, 7 do props[tostring(i)] = { GetPedPropIndex(ped, i), math.max(0, GetPedPropTextureIndex(ped, i)) } end
    return { sex = GetEntityModel(ped) == `mp_f_freemode_01` and 'female' or 'male', components = comps, props = props }
end
local function wearOutfit(o)
    local ped = PlayerPedId()
    for k, v in pairs(o.components or {}) do
        local i = tonumber(k)
        if i ~= 0 and i ~= 2 then SetPedComponentVariation(ped, i, v[1], v[2], 0) end -- (never the face or hair)
    end
    for k, v in pairs(o.props or {}) do
        local i = tonumber(k)
        if v[1] < 0 then ClearPedProp(ped, i) else SetPedPropIndex(ped, i, v[1], v[2], true) end
    end
end
local function doLocker()
    local opts = {
        { title = 'ارتدِ زي العصابة', icon = 'shirt', onSelect = function()
            local sex = GetEntityModel(PlayerPedId()) == `mp_f_freemode_01` and 'female' or 'male'
            local o = lib.callback.await('exti_gangs:server:getOutfit', false, sex)
            if not o then return notify('الزعيم لم يحفظ زيًا للعصابة بعد', 'error') end
            wearOutfit(o); notify('لبست زي العصابة', 'success')
        end },
    }
    if my and my.rank == 3 then
        opts[#opts + 1] = { title = 'احفظ ما ألبسه كزي العصابة', description = 'للرجال والنساء كلٌّ على حدة', icon = 'floppy-disk', onSelect = function()
            local ok = lib.callback.await('exti_gangs:server:saveOutfit', false, readOutfit())
            notify(ok and 'حُفظ زي العصابة' or ERR.failed, ok and 'success' or 'error')
        end }
    end
    lib.registerContext({ id = 'exti_gang_locker', title = 'خزانة العصابة', options = opts })
    lib.showContext('exti_gang_locker')
end

-- the laptop (NUI)
local laptopOpen = false
local function laptopData()
    local data, why = lib.callback.await('exti_gangs:server:laptop', false)
    return data, why
end
local function openLaptop()
    local data, why = laptopData()
    if not data then return fail(why or 'far') end
    laptopOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'laptop', data = data })
    CreateThread(function()
        local dict = 'amb@world_human_seat_wall_tablet@female@base'
        lib.requestAnimDict(dict)
        TaskPlayAnim(PlayerPedId(), dict, 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
        while laptopOpen do Wait(250) end
        StopAnimTask(PlayerPedId(), dict, 'base', 1.0)
    end)
end

RegisterNUICallback('close', function(_, cb)
    laptopOpen = false
    SetNuiFocus(false, false)
    cb(true)
end)

-- every laptop button: { name, args } -> server -> fresh data
local ACTIONS = {
    invite = function(a) return lib.callback.await('exti_gangs:server:invite', false, a.id) end,
    rank = function(a) return lib.callback.await('exti_gangs:server:setRank', false, a.cid, a.rank) end,
    kick = function(a) return lib.callback.await('exti_gangs:server:kick', false, a.cid) end,
    transfer = function(a) return lib.callback.await('exti_gangs:server:transfer', false, a.cid, a.c1 == true, a.c2 == true) end,
    leave = function() return lib.callback.await('exti_gangs:server:leave', false) end,
    bank = function(a) return lib.callback.await('exti_gangs:server:bank', false, a.kind, a.amount) end,
    settings = function(a) return lib.callback.await('exti_gangs:server:settings', false, a.settings) end,
}
RegisterNUICallback('act', function(req, cb)
    local f = ACTIONS[req and req.name]
    if not f then return cb({ ok = false }) end
    local ok, why, extra = f(req.args or {})
    local data = laptopData()
    if req.name == 'leave' and ok then laptopOpen = false; SetNuiFocus(false, false); refresh() end
    cb({ ok = ok == true, why = why, extra = extra, data = data })
end)

-- top-center prompts (invite, car alarm): answered with [Y] / [U], never taking the mouse
-- (so they can't freeze an open laptop, a mini game or a fight)
local promptCb = nil
local function answerPrompt(yes)
    local f = promptCb; promptCb = nil
    SendNUIMessage({ action = 'promptClose' })
    if f then f(yes) end
end
RegisterNUICallback('prompt', function(req, cb) answerPrompt(req and req.yes == true); cb(true) end)
local function prompt(p, onAnswer)
    if promptCb then answerPrompt(nil) end -- a new prompt replaces it: counts as no answer
    promptCb = onAnswer
    SendNUIMessage({ action = 'prompt', prompt = p })
    local mine = promptCb
    CreateThread(function()
        local untilT = GetGameTimer() + (p.timeout or 20) * 1000
        while promptCb == mine and GetGameTimer() < untilT do
            if IsControlJustPressed(0, 246) then return answerPrompt(true) end   -- Y
            if IsControlJustPressed(0, 303) then return answerPrompt(false) end  -- U (N is push-to-talk)
            Wait(0)
        end
        if promptCb == mine then answerPrompt(nil) end -- no answer
    end)
end
GC.prompt = prompt

RegisterNetEvent('exti_gangs:client:invite', function(inv)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
    prompt({ title = ('دعوة إلى عصابة %s'):format(inv.gang), text = ('%s يدعوك إلى %s · تبدأ عدّاءً'):format(inv.from, inv.type),
             color = inv.color, tag = inv.tag, yes = 'انضمام', no = 'رفض', timeout = 30 },
        function(yes) TriggerServerEvent('exti_gangs:server:inviteAnswer', yes == true) end)
end)

-- my car's alarm: where it was on my map for a moment, and the police were told (the plate is flagged)
RegisterNetEvent('exti_gangs:client:carAlarm', function(a)
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', false)
    if a.coords then
        local blip = AddBlipForCoord(a.coords.x, a.coords.y, a.coords.z)
        SetBlipSprite(blip, 225); SetBlipColour(blip, 1); SetBlipScale(blip, 0.9); SetBlipFlashes(blip, true); SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('سيارتك: الإنذار'); EndTextCommandSetBlipName(blip)
        SetTimeout((a.blip or 30) * 1000, function() if DoesBlipExist(blip) then RemoveBlip(blip) end end)
    end
    local text = a.flagged
        and ('أحدهم يعبث بسيارتك (%s). الشرطة أُبلغت واللوحة مطلوبة. هل هي مسروقة فعلًا؟'):format(a.plate)
        or ('أحدهم يعبث بسيارتك (%s). هل تبلّغ الشرطة أنها مسروقة؟'):format(a.plate)
    prompt({ title = 'إنذار سيارتك انطلق!', text = text, color = '#e5484d', tag = '!',
             yes = 'نعم، مسروقة', no = a.flagged and 'لا، ألغِ البلاغ' or 'تجاهل', timeout = 25 },
        function(yes) if yes ~= nil then TriggerServerEvent('exti_gangs:server:reportStolen', a.plate, yes == true) end end)
end)

---------------------------------------------------------------------------
-- the E prompts
---------------------------------------------------------------------------
local LABELS = {
    laptop = '[E] حاسوب العصابة', stash = '[E] مخزن العصابة', deposit = '[E] سلّم القطع', locker = '[E] خزانة الملابس',
    bench = '[E] صنع مفاتيح فتح (1 أدوات = 2 مفاتيح)', crate = '[E] فتّش الصندوق', fence = '[E] كلّم المصرّف',
}
local function points()
    local list = {}
    if my and spots.hq and spots.hq[my.name] then
        for kind, p in pairs(spots.hq[my.name]) do
            if LABELS[kind] and (kind ~= 'bench' or (my.type == 'chop' and my.rank >= 1)) then
                list[#list + 1] = { kind = kind, pos = v3(p) }
            end
        end
    end
    -- the HQ front doors (every gang: anyone can knock, the police can breach)
    for name, set in pairs(spots.hq or {}) do
        if set.door_out and set.door_in then
            local mine = my and my.name == name
            list[#list + 1] = { kind = 'door_out', gang = name, pos = v3(set.door_out),
                                label = mine and '[E] ادخل المقر' or (GC.isCop and GC.isCop() and '[E] الباب (اطرق / اقتحم)' or '[E] اطرق الباب') }
            list[#list + 1] = { kind = 'door_in', gang = name, pos = v3(set.door_in), label = '[E] اخرج' }
        end
        -- real doors (locked for everyone but the gang)
        for i, d in ipairs(set.doors or {}) do
            local mine = my and my.name == name
            local open = GC.realDoorOpen and GC.realDoorOpen(name, i)
            local label = mine and (open and '[E] اقفل الباب' or '[E] افتح الباب')
                or (not open and (GC.isCop and GC.isCop() and '[E] باب مقفل (اطرق / اقتحم)' or '[E] باب مقفل (اطرق)')) or nil
            if label then list[#list + 1] = { kind = 'rdoor', gang = name, i = i, pos = v3(d), label = label, reach = 2.0 } end
        end
    end
    -- the Money Wash drop boxes (anyone) and my gang's machine
    for name, set in pairs(spots.hq or {}) do
        if set.dropbox then list[#list + 1] = { kind = 'dropbox', gang = name, pos = v3(set.dropbox), label = '[E] صندوق الغسيل' } end
    end
    if my and my.type == 'wash' and my.rank >= 1 and spots.hq and spots.hq[my.name] and spots.hq[my.name].washer then
        list[#list + 1] = { kind = 'washer', pos = v3(spots.hq[my.name].washer), label = '[E] آلة الغسيل' }
    end
    -- the production stations of my gang
    local mine = my and spots.hq and spots.hq[my.name]
    if mine and my.rank >= 1 and my.type == 'ammo' and mine.press then list[#list + 1] = { kind = 'craft', pos = v3(mine.press), label = '[E] مكبس الذخيرة' } end
    if mine and my.rank >= 1 and my.type == 'weapons' and mine.workbench then list[#list + 1] = { kind = 'craft', pos = v3(mine.workbench), label = '[E] طاولة الأسلحة' } end
    if mine and my.type == 'weed' then
        if mine.weedtable then list[#list + 1] = { kind = 'weedtable', pos = v3(mine.weedtable), label = '[E] طاولة التقليم والتعبئة' } end
        for i, p in ipairs(mine.pots or {}) do list[#list + 1] = { kind = 'pot', i = i, pos = v3(p), label = GC.potLabel and GC.potLabel(i) or '[E] أصيص' } end
    end
    if spots.blackmarket then list[#list + 1] = { kind = 'blackmarket', pos = v3(spots.blackmarket), label = '[E] تكلّم مع الرجل' } end
    -- the police clean graffiti
    if GC.turfPoints then for _, pt in ipairs(GC.turfPoints()) do list[#list + 1] = pt end end
    for i, c in ipairs(spots.collect and spots.collect.crates or {}) do list[#list + 1] = { kind = 'crate', i = i, pos = v3(c) } end
    if spots.fence then list[#list + 1] = { kind = 'fence', pos = (fencePed and DoesEntityExist(fencePed)) and GetEntityCoords(fencePed) or v3(spots.fence) } end
    return list
end

local shown = nil
local function showPrompt(text)
    local open, cur = lib.isTextUIOpen()
    if shown == text and (not text or (open and cur == text)) then return end
    local mine = shown
    shown = text
    if text then lib.showTextUI(text, { position = 'left-center' })
    elseif mine and open and cur == mine then lib.hideTextUI() end   -- (never someone else's text)
end
GC.textUI = showPrompt   -- (one owner for the left [E] line: weed selling uses it too)

CreateThread(function()
    while true do
        local sleep = 600
        local ped = PlayerPedId()
        local here = GetEntityCoords(ped)
        local best, bestD = nil, 999.0
        if not busy and not laptopOpen and not IsPedInAnyVehicle(ped, false) then
            for _, pt in ipairs(points()) do
                local d = #(here - pt.pos)
                if d < 12.0 then sleep = 0 end
                if d < (pt.reach or (pt.kind == 'crate' and 1.8 or 1.5)) and d < bestD then best, bestD = pt, d end
                if d < 12.0 and pt.kind ~= 'crate' and pt.kind ~= 'fence' and pt.kind ~= 'rdoor' and pt.kind ~= 'tag' and pt.kind ~= 'pot' and pt.kind ~= 'blackmarket' then
                    DrawMarker(20, pt.pos.x, pt.pos.y, pt.pos.z - 0.55, 0, 0, 0, 0, 180.0, 0, 0.32, 0.32, 0.22, 232, 181, 71, 140, true, true, 2, false, nil, nil, false)
                end
            end
        end
        if not GC.holdText then showPrompt(best and (best.label or LABELS[best.kind]) or nil) end
        if best and IsControlJustReleased(0, 38) then
            busy = true; showPrompt(nil)
            local k = best.kind
            if k == 'laptop' then openLaptop()
            elseif k == 'stash' then stashMenu()
            elseif k == 'deposit' then doDeposit()
            elseif k == 'locker' then doLocker()
            elseif k == 'bench' then doBench()
            elseif k == 'crate' then doCrate(best.i)
            elseif k == 'fence' then doFence()
            elseif k == 'door_out' then GC.doorOut(best.gang)
            elseif k == 'door_in' then GC.doorIn(best.gang)
            elseif k == 'rdoor' then GC.realDoor(best.gang, best.i)
            elseif k == 'dropbox' then GC.dropBox(best.gang)
            elseif k == 'washer' then GC.washer()
            elseif k == 'tag' then GC.scrubTag(best.tag)
            elseif k == 'craft' then GC.craft()
            elseif k == 'weedtable' then GC.weedTable()
            elseif k == 'pot' then GC.pot(best.i)
            elseif k == 'blackmarket' then GC.blackMarket() end
            busy = false
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- /gangspots (admins): stand where it goes, pick it
---------------------------------------------------------------------------
local KIND_LABEL = { press = 'مكبس الذخيرة', workbench = 'طاولة الأسلحة', weedtable = 'طاولة التقليم والتعبئة', dropbox = 'صندوق الغسيل (خارج المقر، للجميع)', washer = 'آلة الغسيل (داخل المقر)', door_out = 'باب المقر من الخارج', door_in = 'باب المقر من الداخل', laptop = 'الحاسوب (الإدارة)', stash = 'المخزن', deposit = 'تسليم القطع', locker = 'خزانة الملابس', bench = 'طاولة المفاتيح (التفكيك)', garage = 'مركز ورشة التفكيك (التفكيك)' }
local function save(what, a, b, msg)
    local ok, why = lib.callback.await('exti_gangs:server:spotSave', false, what, a, b)
    notify(ok and (msg or 'حُفظ المكان') or (why == 'max' and 'وصلت الحد' or 'لم يُحفظ'), ok and 'success' or 'error')
end
RegisterNetEvent('exti_gangs:client:spotsMenu', function(gangList)
    local opts = {}
    for _, g in ipairs(gangList) do
        local sub = {}
        local ONLY = { bench = 'chop', garage = 'chop', dropbox = 'wash', washer = 'wash', press = 'ammo', workbench = 'weapons', weedtable = 'weed' }
        for _, kind in ipairs({ 'door_out', 'door_in', 'laptop', 'stash', 'deposit', 'locker', 'bench', 'garage', 'dropbox', 'washer', 'press', 'workbench', 'weedtable' }) do
            local only = ONLY[kind]
            if not only or g.type == only then
                sub[#sub + 1] = { title = KIND_LABEL[kind] .. ' هنا', icon = 'location-dot', onSelect = function() save('hq', g.name, kind) end }
            end
        end
        if g.type == 'weed' then
            local pots = spots.hq and spots.hq[g.name] and spots.hq[g.name].pots or {}
            sub[#sub + 1] = { title = ('أصيص هنا (%d من %d)'):format(#pots, C.weed.pots), icon = 'seedling', onSelect = function() save('pot_add', g.name, nil, 'أُضيف الأصيص') end }
            sub[#sub + 1] = { title = 'احذف أقرب أصيص', icon = 'trash', onSelect = function()
                local here, best, bd = GetEntityCoords(PlayerPedId()), nil, 999.0
                for i, p in ipairs(pots) do local d = #(here - v3(p)); if d < bd then best, bd = i, d end end
                if not best or bd > 5.0 then return notify('لا يوجد أصيص قريب', 'error') end
                save('pot_remove', g.name, best, 'حُذف الأصيص')
            end }
            sub[#sub + 1] = { title = 'احذف كل الأصص', icon = 'trash', onSelect = function() save('pots_clear', g.name, nil, 'مُسحت') end }
        end
        sub[#sub + 1] = { title = 'باب حقيقي: انظر إليه ثم اختر هذا', description = 'يُقفل للجميع إلا العصابة (الباب المزدوج: كل جهة على حدة)', icon = 'door-closed', onSelect = function()
            local model, c = GC.aimDoor()
            if not model then return notify('انظر مباشرة إلى الباب (من مسافة قريبة) ثم اختر', 'error') end
            local ok, n = lib.callback.await('exti_gangs:server:realDoorAdd', false, g.name, model, c)
            notify(ok and ('أُضيف الباب رقم %d: مقفل الآن'):format(n) or (n == 'max' and 'الحد 8 أبواب' or n == 'dupe' and 'هذا الباب مضاف من قبل' or 'لم يُضف'), ok and 'success' or 'error')
        end }
        sub[#sub + 1] = { title = 'امسح الأبواب الحقيقية لهذا المقر', icon = 'door-open', onSelect = function()
            local ok = lib.callback.await('exti_gangs:server:realDoorClear', false, g.name)
            notify(ok and 'مُسحت الأبواب' or 'لم يُمسح', ok and 'success' or 'error')
        end }
        sub[#sub + 1] = { title = 'امسح كل أماكن هذا المقر', icon = 'trash', onSelect = function() save('hq_clear', g.name, nil, 'مُسح') end }
        lib.registerContext({ id = 'exti_gs_' .. g.name, title = g.label, menu = 'exti_gs_main', options = sub })
        opts[#opts + 1] = { title = ('مقر %s'):format(g.label), description = C.types[g.type] and C.types[g.type].label or g.type, menu = 'exti_gs_' .. g.name, icon = 'house' }
    end
    opts[#opts + 1] = { title = 'نقطة الجمع: صندوق هنا', description = ('%d صناديق الآن'):format(#(spots.collect and spots.collect.crates or {})), icon = 'box', onSelect = function() save('crate_add') end }
    opts[#opts + 1] = { title = 'نقطة الجمع: احذف أقرب صندوق', icon = 'box-open', onSelect = function()
        local here, best, bd = GetEntityCoords(PlayerPedId()), nil, 999.0
        for i, c in ipairs(spots.collect and spots.collect.crates or {}) do local d = #(here - v3(c)); if d < bd then best, bd = i, d end end
        if not best or bd > 10.0 then return notify('لا يوجد صندوق قريب', 'error') end
        save('crate_remove', best, nil, 'حُذف الصندوق')
    end }
    opts[#opts + 1] = { title = 'نقطة الجمع: احذف كل الصناديق', icon = 'trash', onSelect = function() save('crates_clear', nil, nil, 'مُسحت') end }
    opts[#opts + 1] = { title = 'المصرّف (يشتري القطع المسروقة) هنا', icon = 'user-secret', onSelect = function() save('fence') end }
    opts[#opts + 1] = { title = 'السوق السوداء (يشتري ذخيرة وأسلحة العصابات) هنا', icon = 'user-ninja', onSelect = function() save('blackmarket') end }
    -- the luxury houses: go and look (it takes you inside: leave through the wall with noclip to set the outside door)
    local houses = {}
    for _, h in ipairs(C.houses or {}) do
        houses[#houses + 1] = { title = h.label, icon = 'house-chimney', onSelect = function()
            GC.teleport({ x = h.coords.x, y = h.coords.y, z = h.coords.z + 1.0, h = 0.0 })
            notify(('أنت داخل %s'):format(h.label), 'inform')
        end }
    end
    lib.registerContext({ id = 'exti_gs_houses', title = 'المنازل الفاخرة', menu = 'exti_gs_main', options = houses })
    opts[#opts + 1] = { title = 'المنازل الفاخرة (انتقل وشاهد)', description = ('%d منازل'):format(#houses), icon = 'house-chimney', menu = 'exti_gs_houses' }
    lib.registerContext({ id = 'exti_gs_main', title = 'أماكن العصابات', options = opts })
    lib.showContext('exti_gs_main')
end)
