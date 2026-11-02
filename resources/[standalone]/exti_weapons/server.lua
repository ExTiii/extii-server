-- =====================================================================
-- EX_Tii weapons (server): shots fired -> a police call (chance by area, one per area per minute).
-- =====================================================================
local S = Config.shots
local CITY, TOWN = {}, {}
for _, z in ipairs(S.cityZones) do CITY[z] = true end
for _, z in ipairs(S.townZones) do TOWN[z] = true end

local lastPlayer = {}  -- [src] = os.time()
local lastArea = {}    -- [cell] = os.time()

local function isCop(src)
    local p = exports.qbx_core:GetPlayer(src)
    local j = p and p.PlayerData.job
    return j and j.name == 'police' and j.onduty == true
end

local function clean(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c<>~^\\]', ''):sub(1, max)
    return s ~= '' and s or nil
end

RegisterNetEvent('exti_weapons:server:shots', function(c, street, zone, silenced)
    local src = source
    local now = os.time()
    if (lastPlayer[src] or 0) + 4 > now then return end
    lastPlayer[src] = now
    if type(c) ~= 'table' or not tonumber(c.x) or not tonumber(c.y) or not tonumber(c.z) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local here = GetEntityCoords(ped)
    if #(here - vec3(c.x, c.y, c.z)) > 30.0 then return end     -- (he must be where he says)
    if isCop(src) then return end
    local cell = ('%d:%d'):format(math.floor(here.x / S.areaSize), math.floor(here.y / S.areaSize))
    if (lastArea[cell] or 0) + S.areaSeconds > now then return end
    zone = type(zone) == 'string' and zone or ''
    local chance = CITY[zone] and S.city or TOWN[zone] and S.town or S.wild
    if silenced == true then chance = chance * S.suppressor end
    if math.random() >= chance then return end
    lastArea[cell] = now
    if GetResourceState('exti_police') ~= 'started' then return end
    local where = clean(street, 60)
    pcall(function()
        exports.exti_police:AddCall({ kind = 'alarm', label = 'إطلاق نار', coords = { x = here.x, y = here.y, z = here.z },
            text = ('إطلاق نار%s%s'):format(where and (' · ' .. where) or '', silenced == true and ' · صوت مكتوم' or ''), number = 'نظام الرصد' })
    end)
end)

AddEventHandler('playerDropped', function() lastPlayer[source] = nil end)

CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        for cell, t in pairs(lastArea) do if now - t > 600 then lastArea[cell] = nil end end
    end
end)
