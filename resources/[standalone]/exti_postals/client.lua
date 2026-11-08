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

-- the minimap of this map is drawn from its pictures at this zoom (at GTA's own zoom it shows only a flat
-- colour), so the radar is held at it every frame, like the map's own release does
CreateThread(function()
    while true do
        if IsMinimapRendering() then SetRadarZoom(1100); Wait(0) else Wait(500) end
    end
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
local MAP_H = 0.241                  -- the minimap's height under the bar
local BX, BY = 0.0028, 0.005         -- frame thickness (sides, bottom)
CreateThread(function()
    local W, H = 0.216, 0.032       -- as wide as the minimap: a header bar over its top edge
    while true do
        if current and loggedIn() and not IsRadarHidden() and not IsPauseMenuActive() and IsMinimapRendering() then
            local mid = X + W / 2
            DrawRect(mid, Y + H / 2, W, H, 10, 10, 12, 195)
            -- the same dark colour as a frame round the minimap (the bar is its top side)
            local top, bot = Y + H, Y + H + MAP_H
            DrawRect(X + BX / 2, (top + bot) / 2, BX, bot - top, 10, 10, 12, 195)            -- left
            DrawRect(X + W - BX / 2, (top + bot) / 2, BX, bot - top, 10, 10, 12, 195)        -- right
            DrawRect(mid, bot - BY / 2, W, BY, 10, 10, 12, 195)                                -- bottom
            DrawRect(X + 0.0013, Y + H / 2, 0.0026, H, 232, 181, 71, 235)
            -- in the middle: the gold number, then the word
            SetTextFont(4); SetTextScale(0.0, NUM_S); SetTextColour(232, 181, 71, 255); SetTextDropShadow()
            SetTextJustification(2); SetTextWrap(X, mid - 0.004)
            BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(current)
            EndTextCommandDisplayText(X, Y + 0.0005)
            SetTextFont(4); SetTextScale(0.0, LBL_S); SetTextColour(255, 255, 255, 220); SetTextDropShadow()
            BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(LABEL)
            EndTextCommandDisplayText(mid + 0.004, Y + 0.0045)
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
