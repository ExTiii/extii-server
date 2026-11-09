-- =====================================================================
-- EX_Tii heists (game side): the jewelry store. The security box on the roof (green USB + laptop hack =
-- cameras and alarm off for 3 minutes), the 20 cases: cut quietly with the glass cutter in that window,
-- or smashed (loud).
-- =====================================================================
local C = Config
local J = C.jewelry

local st = GlobalState['exti_heists:jewel'] or { cases = {} }
AddStateBagChangeHandler('exti_heists:jewel', 'global', function(_, _, v) st = v or { cases = {} } end)

local function rayfire(i)
    local cs = J.cases[i]
    if not cs.ray then return end
    local obj = GetRayfireMapObject(cs.pos.x, cs.pos.y, cs.pos.z, 1.4, cs.ray)
    if obj ~= 0 then SetStateOfRayfireMapObject(obj, 4); Wait(100); SetStateOfRayfireMapObject(obj, 6) end
end
local function smashFx(i, ped)
    local cs = J.cases[i]
    CreateThread(function()
        Wait(350)
        rayfire(i)
        if pcall(lib.requestNamedPtfxAsset, 'scr_jewelheist', 3000) then
            UseParticleFxAsset('scr_jewelheist')
            StartParticleFxNonLoopedAtCoord('scr_jewel_cab_smash', cs.pos.x, cs.pos.y, cs.pos.z + 0.2, 0.0, 0.0, 0.0, 1.0, false, false, false)
            RemoveNamedPtfxAsset('scr_jewelheist')
        end
        PlaySoundFromCoord(-1, 'Glass_Smash', cs.pos.x, cs.pos.y, cs.pos.z, '', false, 0, false)
    end)
end
RegisterNetEvent('exti_heists:client:jewelSmashFx', function(i, by)
    if by == cache.serverId then return end
    if #(GetEntityCoords(cache.ped) - J.cases[i].pos) < 80.0 then smashFx(i) end
end)

local quietShown = false
RegisterNetEvent('exti_heists:client:jewelAlarm', function()
    HC.notify('الإنذار يرن في المحل! الشرطة في الطريق', 'error', 8000)
end)
-- the store is ready again: the smashed cases are whole again in my game
RegisterNetEvent('exti_heists:client:jewelReset', function()
    for _, cs in ipairs(J.cases) do
        if cs.ray then
            local obj = GetRayfireMapObject(cs.pos.x, cs.pos.y, cs.pos.z, 1.4, cs.ray)
            if obj ~= 0 then SetStateOfRayfireMapObject(obj, 2) end
        end
    end
end)

local function itemsText(got)
    local parts = {}
    for _, f in ipairs(got or {}) do
        local it = exports.ox_inventory:Items(f.item)
        parts[#parts + 1] = ((f.n > 1 and (f.n .. 'x ') or '') .. ((it and it.label) or f.item):gsub(' %(.*%)', ''))
    end
    return table.concat(parts, ' · ')
end

local function hack()
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:jewelHackBegin', false)
    if not ok then if token then HC.notify(token, 'error', 6000) end return end
    SetEntityHeading(cache.ped, J.panel.w)
    HC.anim(cache.ped, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 1)
    local passed = HC.play('hack', params, 'لوحة أمن فانجيليكو')
    ClearPedTasks(cache.ped)
    local res, info = lib.callback.await('exti_heists:server:jewelHackEnd', false, token, passed)
    if res then HC.notify(('الكاميرات والإنذار معطّلة %d ثانية · اقطع الخزائن الآن'):format(info), 'success', 8000)
    elseif info == 'again' then HC.notify('رُفض الاختراق: محاولة أخيرة', 'warning', 6000)
    elseif info == 'alarm' then HC.notify('كُشف الاختراق: الإنذار يرن!', 'error', 8000) end
end

local function cut(i)
    HC.prompt(nil)
    local ok, token, params = lib.callback.await('exti_heists:server:jewelCaseBegin', false, i, 'cut')
    if not ok then if token then HC.notify(token, 'error', 6000) end return end
    TaskAchieveHeading(cache.ped, J.cases[i].h, 900); Wait(900)
    HC.anim(cache.ped, 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', 'weed_crouch_checkingleaves_idle_01_inspector', 1)
    local passed = HC.play('glasscut', params, 'خزانة العرض')
    ClearPedTasks(cache.ped)
    local res, got = lib.callback.await('exti_heists:server:jewelCutEnd', false, token, passed)
    if res then HC.notify('أخذت: ' .. itemsText(got), 'success', 6000)
    elseif got == 'cracked' then smashFx(i); HC.notify('انكسر الزجاج بصوت عالٍ: الإنذار!', 'error', 7000) end
end

local SMASH = { 'smash_case_tray_a', 'smash_case_d', 'smash_case_e' }
local function smash(i)
    HC.prompt(nil)
    local ok, why = lib.callback.await('exti_heists:server:jewelCaseBegin', false, i, 'smash')
    if not ok then if why then HC.notify(why, 'error', 6000) end return end
    TaskAchieveHeading(cache.ped, J.cases[i].h, 900); Wait(900)
    local dict = 'missheist_jewel'
    if pcall(lib.requestAnimDict, dict, 3000) then
        TaskPlayAnim(cache.ped, dict, SMASH[math.random(#SMASH)], 3.0, 3.0, -1, 2, 0, false, false, false)
    end
    smashFx(i, cache.ped)
    Wait(3800)
    ClearPedTasks(cache.ped)
    local res, got = lib.callback.await('exti_heists:server:jewelSmashEnd', false)
    if res then HC.notify('أخذت: ' .. itemsText(got), 'success', 6000) end
end

CreateThread(function()
    while true do
        local sleep = 1000
        local here = GetEntityCoords(cache.ped)
        local text, act = nil, nil
        local near = #(here - J.area) < 30.0 or #(here - vec3(J.panel.x, J.panel.y, J.panel.z)) < 20.0
        if near then
            sleep = 0
            local quiet = (st.quietUntil or 0) > GetCloudTimeAsInt()
            if HC.canAct() then
                -- the security box
                if #(here - vec3(J.panel.x, J.panel.y, J.panel.z)) < 1.6 and not quiet and not st.alarm then
                    if HC.count('usb_green') > 0 or st.phase == 'on' then text, act = '[E] ركّب الفلاشة الخضراء في لوحة الأمن', hack
                    else text = 'لوحة الأمن: تحتاج فلاشة اختراق خضراء' end
                end
                -- the cases
                local best, bd
                for i, cs in ipairs(J.cases) do
                    if not (st.cases and (st.cases[i] or st.cases[tostring(i)])) then
                        local d = #(here - cs.pos)
                        if d < 1.15 and (not bd or d < bd) then best, bd = i, d end
                    end
                end
                if best then
                    if quiet then text, act = '[E] اقطع الزجاج بهدوء', function() cut(best) end
                    elseif IsPedArmed(cache.ped, 7) then text, act = '[E] حطّم الخزانة (صاخب)', function() smash(best) end
                    else text = 'تحتاج شيئًا في يدك لتحطّم الزجاج (أو عطّل الكاميرات من السطح)' end
                end
            end
        end
        -- the quiet window on the bar at the top, near the store only (unless the NPC chase is using it)
        local showQuiet = near and (st.quietUntil or 0) > GetCloudTimeAsInt()
        if showQuiet and not (HC.hunted and HC.hunted()) then
            SendNUIMessage({ action = 'hud', state = { kind = 'quiet', seconds = (st.quietUntil or 0) - GetCloudTimeAsInt() } })
        elseif quietShown and not (HC.hunted and HC.hunted()) then
            SendNUIMessage({ action = 'hud', state = nil })
        end
        quietShown = showQuiet
        HC.prompt(text, 'jewel')
        if act and (IsControlJustReleased(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) and HC.lineIs(text) then act() end
        Wait(sleep)
    end
end)
