-- =====================================================================
-- EX_Tii postals: every block of the city has a number (on the map). The nearest one shows above the
-- minimap; /postal 123 puts a waypoint on it, /postal alone clears it. Other scripts:
--   exports.exti_postals:Get(x, y) -> '123', distance      exports.exti_postals:Nearest() -> '123', distance
-- =====================================================================
local postals = {}
do
    local ok, list = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), 'data/postals.json') or '')
    if ok and type(list) == 'table' then postals = list end
end

local function nearest(x, y)
    local best, bd
    for i = 1, #postals do
        local p = postals[i]
        local dx, dy = x - p.x, y - p.y
        local d = dx * dx + dy * dy
        if not bd or d < bd then best, bd = p, d end
    end
    if not best then return nil end
    return best.c, math.sqrt(bd)
end
exports('Get', function(x, y) return nearest(x + 0.0, y + 0.0) end)

local current, currentDist = nil, 0
exports('Nearest', function() return current, currentDist end)

-- the map zoom levels that go with this map (from the release)
CreateThread(function()
    SetMapZoomDataLevel(0, 0.96, 0.9, 0.08, 0.0, 0.0)
    SetMapZoomDataLevel(1, 1.6, 0.9, 0.08, 0.0, 0.0)
    SetMapZoomDataLevel(2, 8.6, 0.9, 0.08, 0.0, 0.0)
    SetMapZoomDataLevel(3, 12.3, 0.9, 0.08, 0.0, 0.0)
    SetMapZoomDataLevel(4, 22.3, 0.9, 0.08, 0.0, 0.0)
end)

-- where I am
CreateThread(function()
    while true do
        local c = GetEntityCoords(PlayerPedId())
        current, currentDist = nearest(c.x, c.y)
        Wait(600)
    end
end)

-- the badge just above the minimap: a dark strip with the gold number and the word next to it
local function loggedIn() return LocalPlayer.state.isLoggedIn ~= false end
local function textWidth(str, scale)
    SetTextFont(4); SetTextScale(0.0, scale)
    BeginTextCommandGetWidth('STRING'); AddTextComponentSubstringPlayerName(str)
    return EndTextCommandGetWidth(true)
end
local LABEL = 'رمز المنطقة'
local X, Y = 0.0155, 0.722          -- left edge of the minimap, a little above its top
local NUM_S, LBL_S = 0.40, 0.33
CreateThread(function()
    local wFor, wNum, wLbl = nil, 0, 0
    while true do
        if current and loggedIn() and not IsRadarHidden() and not IsPauseMenuActive() and IsMinimapRendering() then
            if wFor ~= current then wFor = current; wNum = textWidth(current, NUM_S); wLbl = textWidth(LABEL, LBL_S) end
            local pad, gap = 0.005, 0.005
            local w = pad + wNum + gap + wLbl + pad
            DrawRect(X + w / 2, Y + 0.016, w, 0.030, 10, 10, 12, 170)
            DrawRect(X + 0.0012, Y + 0.016, 0.0024, 0.030, 232, 181, 71, 230)
            SetTextFont(4); SetTextScale(0.0, NUM_S); SetTextColour(232, 181, 71, 255); SetTextDropShadow()
            BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(current)
            EndTextCommandDisplayText(X + pad, Y + 0.0005)
            SetTextFont(4); SetTextScale(0.0, LBL_S); SetTextColour(255, 255, 255, 215); SetTextDropShadow()
            BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(LABEL)
            EndTextCommandDisplayText(X + pad + wNum + gap, Y + 0.0045)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- /postal 123: waypoint on it.  /postal: no waypoint
RegisterCommand('postal', function(_, args)
    local code = args[1] and tostring(args[1]):gsub('%s', '') or nil
    if not code or code == '' then
        SetWaypointOff()
        lib.notify({ description = 'أُزيلت العلامة', type = 'inform' })
        return
    end
    for i = 1, #postals do
        local p = postals[i]
        if p.c == code then
            SetNewWaypoint(p.x, p.y)
            lib.notify({ description = ('علامة على الرمز %s'):format(code), type = 'success' })
            return
        end
    end
    lib.notify({ description = ('لا يوجد رمز %s'):format(code), type = 'error' })
end, false)
TriggerEvent('chat:addSuggestion', '/postal', 'ضع علامة على رمز منطقة (بدون رقم: أزل العلامة)', { { name = 'رقم', help = 'مثلًا 123' } })
