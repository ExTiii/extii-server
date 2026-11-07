-- =====================================================================
-- EX_Tii weapons (server): shots fired -> a police call (chance by area, one per area per minute).
-- =====================================================================
local S = Config.shots
local CITY, TOWN = {}, {}
for _, z in ipairs(S.cityZones) do CITY[z] = true end
for _, z in ipairs(S.townZones) do TOWN[z] = true end

local lastPlayer = {}  -- [src] = os.time()
local streak = {}       -- [src] = { n = bursts not reported, at = last burst }
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
    -- a shell casing on the ground (evidence: the gun's serial, or none)
    if GetResourceState('exti_police') == 'started' and GetPlayerRoutingBucket(src) == 0 then
        pcall(function() exports.exti_police:Casing(src, here) end)
    end
    local cell = ('%d:%d'):format(math.floor(here.x / S.areaSize), math.floor(here.y / S.areaSize))
    if (lastArea[cell] or 0) + S.areaSeconds > now then return end
    zone = type(zone) == 'string' and zone or ''
    local chance = CITY[zone] and S.city or TOWN[zone] and S.town or S.wild
    if silenced == true then chance = chance * S.suppressor end
    -- EX_Tii (Moe): someone who keeps shooting gets reported sooner or later: every burst that wasn't
    -- reported in the last 45 s adds to the chance (non-stop loud shooting in Sandy = a call after a few bursts)
    local st = streak[src]
    if not st or now - st.at > 45 then st = { n = 0 } end
    st.at = now
    chance = math.min(1.0, chance + st.n * (S.streakStep or 0.25) * (silenced == true and 0.5 or 1.0))
    if math.random() >= chance then st.n = st.n + 1; streak[src] = st; return end
    streak[src] = nil
    lastArea[cell] = now
    if GetResourceState('exti_police') ~= 'started' then return end
    local where = clean(street, 60)
    pcall(function()
        exports.exti_police:AddCall({ kind = 'alarm', label = 'إطلاق نار', coords = { x = here.x, y = here.y, z = here.z },
            text = ('إطلاق نار%s%s'):format(where and (' · ' .. where) or '', silenced == true and ' · صوت مكتوم' or ''), number = 'نظام الرصد', suspect = src })
    end)
end)

AddEventHandler('playerDropped', function() lastPlayer[source] = nil; streak[source] = nil end)

CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        for cell, t in pairs(lastArea) do if now - t > 600 then lastArea[cell] = nil end end
    end
end)

-- admins (testing): /dmgtest turns on a line for every hit you land: how much health it took
lib.addCommand('dmgtest', { help = 'Weapons: show the damage of every hit you land (admin)', restricted = 'group.admin' }, function(source)
    TriggerClientEvent('exti_weapons:client:dmgtest', source)
end)
