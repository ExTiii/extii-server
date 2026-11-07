-- =====================================================================
-- EX_Tii heists (game side): banks. The steps' [E] prompts, the minigames, the vault door swinging open
-- (every game near the bank turns the door the same way, from GlobalState), the time-lock bar, the
-- deposit boxes.
-- =====================================================================
local C = Config
local state = {}
local lockEnds = {}   -- [id] = GetGameTimer() when the time lock ends
local fuseEnds = {}   -- [id] = GetGameTimer() when a C4 on the vault blows
local function setState(v)
    state = v or {}
    for id, s in pairs(state) do
        if s.lockLeft and s.lockLeft > 0 then lockEnds[id] = GetGameTimer() + s.lockLeft * 1000 else lockEnds[id] = nil end
        if s.fuseLeft and s.fuseLeft > 0 then fuseEnds[id] = GetGameTimer() + s.fuseLeft * 1000 else fuseEnds[id] = nil end
    end
end
-- where a step / a box really is (an admin's /heistspot fix wins)
local fixes = GlobalState['exti_heists:spotfix'] or {}
AddStateBagChangeHandler('exti_heists:spotfix', 'global', function(_, _, v) fixes = v or {} end)
local function fixAt(id, key, default)
    local f = fixes[('%s:%s'):format(id, key)]
    return f and vec3(f.x, f.y, f.z) or default
end
setState(GlobalState['exti_heists:vaults'])
AddStateBagChangeHandler('exti_heists:vaults', 'global', function(_, _, v) setState(v) end)

local busy = false

---------------------------------------------------------------------------
-- the doors: closed or open, as the server says (the game rebuilds map objects when you come back)
---------------------------------------------------------------------------
local turning = {}   -- [id..key] = current heading while it swings
local baseHead = {}  -- [id..key] = the map's own heading of a door we turn by `swing`
local function doorObj(d) return GetClosestObjectOfType(d.pos.x, d.pos.y, d.pos.z, d.radius or 3.0, d.model, false, false, false) end
local function headDiff(a, b) return (a - b + 540) % 360 - 180 end
CreateThread(function()
    while true do
        local sleep = 1500
        local me = GetEntityCoords(cache.ped)
        for id, v in pairs(C.vaults) do
            if #(me - v.center) < 90.0 then
                sleep = 250
                local s = state[id] or {}
                for key, d in pairs(v.doors or {}) do
                    local obj = doorObj(d)
                    if obj ~= 0 then
                        FreezeEntityPosition(obj, true)
                        local tk = id .. key
                        if d.swing and not baseHead[tk] then baseHead[tk] = GetEntityHeading(obj) end
                        local closedH = d.closed or baseHead[tk]
                        local openH = d.open or (baseHead[tk] + (d.swing or 90.0))
                        local want = (s.doors and s.doors[key]) and openH or closedH
                        local cur = GetEntityHeading(obj)
                        local diff = headDiff(want, cur)
                        if math.abs(diff) > 0.6 then
                            -- a heavy door: slow at first, a steady swing
                            local tk = id .. key
                            turning[tk] = true
                            SetEntityHeading(obj, cur + math.max(-0.7, math.min(0.7, diff)))
                            sleep = 0
                        else
                            turning[id .. key] = nil
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- the bar for the time lock
---------------------------------------------------------------------------
CreateThread(function()
    local shown = false
    while true do
        local sleep = 1000
        local me = GetEntityCoords(cache.ped)
        local show
        for id, v in pairs(C.vaults) do
            local e = lockEnds[id]
            local f = fuseEnds[id]
            if f and f > GetGameTimer() and #(me - v.center) < 60.0 then
                show = { kind = 'fuse', seconds = math.ceil((f - GetGameTimer()) / 1000) }
                break
            elseif e and e > GetGameTimer() and #(me - v.center) < 40.0 then
                show = { kind = 'lock', seconds = math.ceil((e - GetGameTimer()) / 1000) }
                break
            end
        end
        if show and not (HC.hunted and HC.hunted()) then SendNUIMessage({ action = 'hud', state = show }); shown = true
        elseif shown and not (HC.hunted and HC.hunted()) then SendNUIMessage({ action = 'hud', state = nil }); shown = false end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- the prompts: the next step, then the boxes
---------------------------------------------------------------------------
local function doStep(id, k, step)
    busy = true
    HC.prompt(nil)
    local ok, token, game, params = lib.callback.await('exti_heists:server:vaultStepBegin', false, id, k)
    if not ok then busy = false; if token then HC.notify(token, 'error') end return end
    local dict = (game == 'hack' or game == 'keypad') and 'anim@heists@prison_heiststation@cop_reactions' or 'mini@repair'
    local clip = (game == 'hack' or game == 'keypad') and 'cop_b_idle' or 'fixing_a_ped'
    HC.anim(cache.ped, dict, clip, 1)
    local passed = HC.play(game, params, step.label:gsub('^%[E%]%s*', ''))
    ClearPedTasks(cache.ped)
    local done, lock, blast = lib.callback.await('exti_heists:server:vaultStepEnd', false, token, game, passed)
    if done then
        if blast then HC.notify(('الفتيل يعمل: %d ثانية. ابتعد عن الباب!'):format(blast), 'warning', 7000)
        else HC.notify(lock and ('تم. قفل الوقت يعمل: الباب يُفتح بعد %d ثانية'):format(lock) or 'تم', 'success') end
    elseif lock == 'failed' then
        HC.notify('فشلت: رنّ الإنذار', 'error')
    end
    busy = false
end

local function doBox(id, i)
    busy = true
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:vaultBoxBegin', false, id, i)
    if not ok then busy = false; if token then HC.notify(token, 'error') end return end
    local passed = HC.play('drill', params, 'صندوق الأمانات')
    local done, res = lib.callback.await('exti_heists:server:vaultBoxEnd', false, token, passed)
    if done and res then
        HC.notify(('فتحت الصندوق: %s$%d%s'):format(res.item == 'marked_bills' and 'أوراق معلّمة ' or '', res.money, res.usb and ' + فلاشة' or ''), 'success', 6000)
    elseif res == 'bit' then
        HC.notify('انكسر رأس المثقاب', 'error')
    end
    busy = false
end

CreateThread(function()
    while true do
        local sleep = 800
        local text, action
        if not busy and HC.canAct() then
            local me = GetEntityCoords(cache.ped)
            for id, v in pairs(C.vaults) do
                if #(me - v.center) < (v.radius or 18.0) + 15.0 then
                    sleep = 250
                    local s = state[id] or { phase = 'idle', step = 0 }
                    if s.phase ~= 'done' and s.phase ~= 'open' and not fuseEnds[id] then
                        for k, step in ipairs(v.steps) do
                            if k > (s.step or 0) and #(me - fixAt(id, k, step.at)) < 1.4 then
                                text, action = step.label, function() doStep(id, k, step) end
                                break
                            end
                        end
                    elseif s.phase == 'open' then
                        for i, pos in ipairs(v.lockers) do
                            if not (s.lockers and (s.lockers[i] or s.lockers[tostring(i)])) and #(me - fixAt(id, 'box' .. i, pos)) < 1.2 then
                                text, action = '[E] اثقب صندوق الأمانات', function() doBox(id, i) end
                                break
                            end
                        end
                    end
                    if text then sleep = 0 end
                end
                if text then break end
            end
        end
        HC.prompt(text, 'vault')
        if action and (IsControlJustPressed(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then CreateThread(action); Wait(400) end
        Wait(sleep)
    end
end)

RegisterNetEvent('exti_heists:client:vaultAlarm', function()
    PlaySoundFrontend(-1, 'Bed', 'WastedSounds', false)
    HC.notify('رنّ إنذار البنك!', 'error', 6000)
end)
RegisterNetEvent('exti_heists:client:vaultOpen', function()
    PlaySoundFrontend(-1, 'Door_Open', 'GTAO_Biker_Ent_Fuse_Sounds', false)
    HC.notify('انتهى قفل الوقت: الخزنة مفتوحة', 'success', 6000)
end)
RegisterNetEvent('exti_heists:client:vaultReset', function() end)
