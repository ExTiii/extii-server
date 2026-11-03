-- =====================================================================
-- EX_Tii Police (client): evidence. Officers on duty see small marks on the ground near them (blue =
-- a partial print, red = blood, gold = a shell casing) and bag them with E (one evidence bag each, from
-- the armory). At the seized items room they hand the bags in to the lab. Everyone: blood where you
-- get hurt, gloves (worn or not) on your state for the robbery scripts.
-- =====================================================================
local E = Config.evidence
local marks = {}          -- { id, k, x, y, z } from the server
local COLORS = { print = { 70, 150, 255 }, blood = { 190, 20, 30 }, casing = { 230, 180, 60 } }

RegisterNetEvent('exti_police:client:evidence', function(list)
    marks = {}
    for _, m in ipairs(type(list) == 'table' and list or {}) do
        if tonumber(m.x) then marks[#marks + 1] = { id = m.id, k = m.k, c = vec3(m.x, m.y, m.z) } end
    end
end)

-- coming on duty (or the resource starting): ask for the marks
local function hello() if POL.onDuty() then TriggerServerEvent('exti_police:server:evidenceHello') else marks = {} end end
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() SetTimeout(500, hello) end)
RegisterNetEvent('QBCore:Client:SetDuty', function() SetTimeout(500, hello) end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(2500, hello) end)
AddEventHandler('onResourceStart', function(res) if res == GetCurrentResourceName() then SetTimeout(2500, hello) end end)

---------------------------------------------------------------------------
-- drawing the marks (only what is close, only on duty)
---------------------------------------------------------------------------
local near = {}           -- the marks within showDistance (refreshed twice a second)
CreateThread(function()
    while true do
        local list = {}
        if #marks > 0 and POL.onDuty() then
            local p = GetEntityCoords(cache.ped)
            for _, m in ipairs(marks) do
                local d = #(p - m.c)
                if d < E.showDistance then list[#list + 1] = { m = m, d = d } end
            end
        end
        near = list
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        if #near > 0 then
            for _, it in ipairs(near) do
                local m, col = it.m, COLORS[it.m.k] or COLORS.print
                -- a small flat ring with a dot in it, just above the floor
                DrawMarker(25, m.c.x, m.c.y, m.c.z - 0.96, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.32, 0.32, 0.32, col[1], col[2], col[3], 150, false, false, 2, false, nil, nil, false)
                DrawMarker(28, m.c.x, m.c.y, m.c.z - 0.92, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.035, 0.035, 0.035, col[1], col[2], col[3], 220, false, false, 2, false, nil, nil, false)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- the closest mark within reach: the main loop shows its "[E]" (client/main.lua asks this)
local function placeName(c)
    local s1 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = s1 and GetStreetNameFromHashKey(s1) or ''
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if zone == 'NULL' then zone = '' end
    if street ~= '' and zone ~= '' then return street .. '، ' .. zone end
    return street ~= '' and street or zone
end

function POL.evidencePrompt(p)
    if #near == 0 or cache.vehicle then return nil end
    local best, bd
    for _, it in ipairs(near) do
        local d = #(p - it.m.c)
        if d < E.pickDistance and (not bd or d < bd) then best, bd = it.m, d end
    end
    if not best then return nil end
    local m = best
    return ('[E] اجمع الدليل: %s'):format(E.labels[m.k] or ''), function()
        if exports.ox_inventory:Search('count', E.bagItem) < 1 then return POL.notify('error', 'تحتاج كيس أدلة (من مستودع الأسلحة)') end
        if not lib.progressCircle({ duration = 3500, label = 'تجمع الدليل...', position = 'bottom', canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 } }) then return end
        local ok, why = lib.callback.await('exti_police:server:evidencePick', false, m.id, placeName(m.c))
        if ok then POL.notify('success', ('وضعت %s في كيس'):format(why))
        else POL.notify('error', ({ no_bag = 'تحتاج كيس أدلة', full = 'حقيبتك ممتلئة', gone = 'لم يعد هنا' })[why] or POL.ERRORS[why] or POL.ERRORS.failed) end
    end
end

---------------------------------------------------------------------------
-- the lab (at the seized items room)
---------------------------------------------------------------------------
local function fmtLeft(s) return ('%d:%02d'):format(s // 60, s % 60) end

function POL.openLab()
    local info = lib.callback.await('exti_police:server:labInfo', false)
    if not info then return POL.error('too_far') end
    local opts = {}
    for _, b in ipairs(info.bags) do
        opts[#opts + 1] = { title = b.label, description = b.description, icon = 'flask',
            onSelect = function()
                local caseOpts = { { title = 'بلا قضية', description = 'النتيجة على هاتفك فقط', icon = 'ban',
                    onSelect = function()
                        local ok, mins = lib.callback.await('exti_police:server:labSubmit', false, b.slot, nil)
                        if ok then POL.notify('success', ('سلّمت الدليل للمختبر. النتيجة بعد %d دقائق'):format(mins)) else POL.error(mins) end
                    end } }
                for _, c in ipairs(info.cases) do
                    caseOpts[#caseOpts + 1] = { title = ('#%d · %s'):format(c.id, c.title), icon = 'folder-open',
                        onSelect = function()
                            local ok, mins = lib.callback.await('exti_police:server:labSubmit', false, b.slot, c.id)
                            if ok then POL.notify('success', ('سلّمت الدليل. النتيجة بعد %d دقائق على القضية #%d'):format(mins, c.id)) else POL.error(mins) end
                        end }
                end
                lib.registerContext({ id = 'exti_police_lab_case', title = 'على أي قضية؟', menu = 'exti_police_lab', options = caseOpts })
                lib.showContext('exti_police_lab_case')
            end }
    end
    if #info.bags == 0 then opts[#opts + 1] = { title = 'لا أكياس أدلة معك', description = 'اجمع الأدلة من مكان الجريمة أولًا', icon = 'circle-info', disabled = true } end
    if #info.results > 0 then
        local res = {}
        for _, r in ipairs(info.results) do
            res[#res + 1] = { title = ('#%d · %s · %s'):format(r.id, r.label, r.place or ''), icon = r.result and 'check' or 'hourglass-half',
                description = r.result or ('في المختبر · باقٍ %s'):format(fmtLeft(r.left)) .. (r.case and (' · القضية #%d'):format(r.case) or '') }
        end
        lib.registerContext({ id = 'exti_police_lab_results', title = 'نتائج المختبر', menu = 'exti_police_lab', options = res })
        opts[#opts + 1] = { title = 'نتائج المختبر', description = 'آخر 15 دليلًا', icon = 'list-check', menu = 'exti_police_lab_results' }
    end
    lib.registerContext({ id = 'exti_police_lab', title = ('مختبر الأدلة (%d دقائق لكل دليل)'):format(info.minutes), options = opts })
    lib.showContext('exti_police_lab')
end

---------------------------------------------------------------------------
-- everyone: blood where you get hurt
---------------------------------------------------------------------------
CreateThread(function()
    local last = GetEntityHealth(cache.ped)
    while true do
        Wait(1000)
        local ped = cache.ped
        local h = GetEntityHealth(ped)
        if h < last - E.blood.minDamage and h > 0 and HasPedBeenDamagedByWeapon(ped, 0, 2) and not cache.vehicle then
            ClearPedLastWeaponDamage(ped)
            local c = GetEntityCoords(ped)
            TriggerServerEvent('exti_police:server:blood', { x = c.x, y = c.y, z = c.z })
        end
        last = h
    end
end)

---------------------------------------------------------------------------
-- everyone: gloves on or off (for the robbery scripts: no gloves = prints)
---------------------------------------------------------------------------
local bare = { [`mp_m_freemode_01`] = {}, [`mp_f_freemode_01`] = {} }
for _, n in ipairs(E.noGloves.male) do bare[`mp_m_freemode_01`][n] = true end
for _, n in ipairs(E.noGloves.female) do bare[`mp_f_freemode_01`][n] = true end
CreateThread(function()
    local last
    while true do
        local ped = cache.ped
        local list = bare[GetEntityModel(ped)]
        local gloves = list ~= nil and not list[GetPedDrawableVariation(ped, 3)]
        if gloves ~= last then last = gloves; LocalPlayer.state:set('exti_gloves', gloves, true) end
        Wait(2500)
    end
end)

---------------------------------------------------------------------------
-- officers: the marked bills trace (a circle that fades)
---------------------------------------------------------------------------
RegisterNetEvent('exti_police:client:trace', function(t)
    if not POL.onDuty() or type(t) ~= 'table' or not tonumber(t.x) then return end
    local b = AddBlipForRadius(t.x + 0.0, t.y + 0.0, 0.0, (t.radius or 160.0) + 0.0)
    SetBlipColour(b, 1); SetBlipAlpha(b, 110)
    local c = AddBlipForCoord(t.x + 0.0, t.y + 0.0, 0.0)
    SetBlipSprite(c, 500); SetBlipColour(c, 1); SetBlipScale(c, 0.8)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('أوراق معلّمة (تتبّع البنك)'); EndTextCommandSetBlipName(c)
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
    SetTimeout((t.seconds or 50) * 1000, function()
        if DoesBlipExist(b) then RemoveBlip(b) end
        if DoesBlipExist(c) then RemoveBlip(c) end
    end)
end)
