-- =====================================================================
-- EX_Tii heists (game side): the yacht. GTA's heist yacht is loaded for everyone; the steps' prompts,
-- the fuse bar, the blast, emptying the safe.
-- =====================================================================
local C = Config
local Y = C.yacht
for _, ipl in ipairs(Y.ipls) do RequestIpl(ipl) end

local state = GlobalState['exti_heists:yacht'] or { phase = 'idle', step = 0 }
local fuseEnd
local function setState(v)
    state = v or { phase = 'idle', step = 0 }
    fuseEnd = state.fuseLeft and state.fuseLeft > 0 and (GetGameTimer() + state.fuseLeft * 1000) or nil
end
setState(GlobalState['exti_heists:yacht'])
AddStateBagChangeHandler('exti_heists:yacht', 'global', function(_, _, v) setState(v) end)

local function stepAt(k)
    local fix = (GlobalState['exti_heists:spotfix'] or {})['yacht:' .. k]
    return fix and vec3(fix.x, fix.y, fix.z) or Y.steps[k].at
end

local busy = false
local function doStep(k, step)
    busy = true; HC.prompt(nil)
    local ok, token, game, params = lib.callback.await('exti_heists:server:yachtStepBegin', false, k)
    if not ok then busy = false; if token then HC.notify(token, 'error') end return end
    HC.anim(cache.ped, game == 'hack' and 'anim@heists@prison_heiststation@cop_reactions' or 'anim@heists@ornate_bank@thermal_charge', game == 'hack' and 'cop_b_idle' or 'thermal_charge', 1)
    local passed = HC.play(game, params, step.label:gsub('^%[E%]%s*', ''))
    ClearPedTasks(cache.ped)
    local done, blast = lib.callback.await('exti_heists:server:yachtStepEnd', false, token, game, passed)
    if done then HC.notify(blast and ('الفتيل يعمل: %d ثانية. ابتعد!'):format(blast) or 'تم', blast and 'warning' or 'success', 6000)
    elseif blast == 'failed' then HC.notify('فشلت: انتبهوا لك!', 'error') end
    busy = false
end

CreateThread(function()
    local barShown = false
    while true do
        local sleep = 1000
        local text, action, bar
        if state.phase == 'on' then
            local me = GetEntityCoords(cache.ped)
            if #(me - Y.center) < 120.0 then
                sleep = 250
                if fuseEnd and fuseEnd > GetGameTimer() then bar = { kind = 'fuse', seconds = math.ceil((fuseEnd - GetGameTimer()) / 1000) } end
                if not busy and HC.canAct() then
                    local k = (state.step or 0) + 1
                    local step = Y.steps[k]
                    if step and not fuseEnd and #(me - stepAt(k)) < 1.5 then
                        text, action = step.label, function() doStep(k, step) end
                    elseif not step and not state.emptied and #(me - stepAt(#Y.steps)) < 1.6 then
                        text, action = '[E] أفرغ الخزنة', function()
                            busy = true; HC.prompt(nil)
                            if lib.progressCircle({ duration = 10000, label = 'تفرغ الخزنة...', position = 'bottom', canCancel = true,
                                disable = { move = true, car = true, combat = true }, anim = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab', flag = 1 } }) then
                                local ok, res = lib.callback.await('exti_heists:server:yachtLoot', false)
                                if ok and res then HC.notify(('$%d + %d سبائك ذهب%s'):format(res.money, res.bars, res.usb and ' + فلاشة ذهبية' or ''), 'success', 8000) end
                            end
                            busy = false
                        end
                    end
                    if text then sleep = 0 end
                end
            end
        end
        HC.prompt(text, 'yacht')
        if action and IsControlJustPressed(0, 38) then CreateThread(action); Wait(400) end
        if bar and not (HC.hunted and HC.hunted()) then SendNUIMessage({ action = 'hud', state = bar }); barShown = true
        elseif barShown and not (HC.hunted and HC.hunted()) then SendNUIMessage({ action = 'hud', state = nil }); barShown = false end
        Wait(sleep)
    end
end)

-- a C4 blast (one game makes it, everyone hears it)
RegisterNetEvent('exti_heists:client:blast', function(p)
    AddExplosion(p.x, p.y, p.z, 2, 0.3, true, false, 1.0)
end)
