-- =====================================================================
-- EX_Tii heists (game side): the cartel stash. The crates in the barn (each game puts its own, the server
-- says which are open), the gate camera box, the crowbar.
-- =====================================================================
local C = Config
local S = C.stash
local state = GlobalState['exti_heists:stash'] or { phase = 'idle', crates = {} }
AddStateBagChangeHandler('exti_heists:stash', 'global', function(_, _, v) state = v or { phase = 'idle', crates = {} } end)

local props = {}
local function opened(i) local c = state.crates or {}; return c[i] or c[tostring(i)] end
local function ground(x, y, z) local ok, g = GetGroundZFor_3dCoord(x, y, z + 3.0, false); return ok and g or z end

CreateThread(function()
    local model = joaat(S.crateModel)
    while true do
        local me = GetEntityCoords(cache.ped)
        local want = state.phase ~= 'idle' and #(me - S.center) < 150.0
        for i, c in ipairs(S.crates) do
            local p = props[i]
            if want and not opened(i) and not p then
                if pcall(lib.requestModel, model, 5000) then
                    p = CreateObject(model, c.x, c.y, ground(c.x, c.y, c.z), false, false, false)
                    SetEntityHeading(p, c.w); PlaceObjectOnGroundProperly(p); FreezeEntityPosition(p, true)
                    props[i] = p
                end
            elseif p and (not want or opened(i)) then
                DeleteEntity(p); props[i] = nil
            end
        end
        Wait(1000)
    end
end)

local busy = false
local function cam()
    busy = true; HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:stashCamBegin', false)
    if not ok then busy = false; if token then HC.notify(token, 'error') end return end
    HC.anim(cache.ped, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 1)
    local passed = HC.play('hack', params, 'كاميرا البوابة')
    ClearPedTasks(cache.ped)
    local done = lib.callback.await('exti_heists:server:stashCamEnd', false, token, passed)
    HC.notify(done and 'الكاميرات مطفأة: الحرّاس نصف عميان' or 'فشلت: انتبهوا لك!', done and 'success' or 'error', 6000)
    busy = false
end
local function crate(i)
    busy = true; HC.prompt(nil)
    local ok, secs = lib.callback.await('exti_heists:server:stashCrateBegin', false, i)
    if not ok then busy = false return end
    local done = lib.progressCircle({ duration = secs * 1000, label = 'تكسر الصندوق بالعتلة...', position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { dict = 'missheist_agency2ahands_up', clip = 'handsup_anxious', flag = 1 },
        prop = { model = `prop_ing_crowbar`, bone = 57005, pos = vec3(0.1, 0.0, 0.0), rot = vec3(-90.0, 0.0, 0.0) } })
    if done then
        local got, res = lib.callback.await('exti_heists:server:stashCrateEnd', false)
        if got and res then HC.notify(('$%d%s · بقي %d'):format(res.money, res.usb and ' + فلاشة حمراء' or '', res.left), 'success', 5000) end
    end
    busy = false
end

CreateThread(function()
    while true do
        local sleep = 1000
        local text, action
        if state.phase == 'on' then
            local me = GetEntityCoords(cache.ped)
            if #(me - S.center) < 160.0 then
                sleep = 300
                if not busy and HC.canAct() then
                    if not state.blind and #(me - S.camera) < 1.6 then
                        text, action = '[E] اخترق كاميرا البوابة (فلاشة زرقاء)', cam
                    else
                        for i, c in ipairs(S.crates) do
                            if not opened(i) and #(me - vec3(c.x, c.y, c.z)) < 1.7 then text, action = '[E] اكسر الصندوق', function() crate(i) end break end
                        end
                    end
                    if text then sleep = 0 end
                end
            end
        end
        HC.prompt(text, 'stash')
        if action and IsControlJustPressed(0, 38) then CreateThread(action); Wait(400) end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(props) do if DoesEntityExist(p) then DeleteEntity(p) end end
end)
