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

-- EX_Tii (Moe): guns are never dropped on the ground: in your trunk or glove box, or handed to someone.
-- (ammo, attachments and everything else drop as usual)
CreateThread(function()
    Wait(3000)
    local guns = {}
    local okI, items = pcall(function() return exports.ox_inventory:Items() end)
    if okI and type(items) == 'table' then
        for name in pairs(items) do
            if type(name) == 'string' and name:find('^WEAPON_') then guns[name] = true end
        end
    end
    if not next(guns) then return end
    local ok, err = pcall(function()
        exports.ox_inventory:registerHook('swapItems', function(payload)
            if payload.fromType == 'player' and (payload.toType == 'drop' or payload.toType == 'newdrop') then
                pcall(function()
                    TriggerClientEvent('ox_lib:notify', payload.source, { description = 'لا تُرمى الأسلحة على الأرض: ضعها في صندوق سيارتك أو درجها، أو أعطها لشخص', type = 'error', duration = 5000 })
                end)
                return false
            end
            return true
        end, { itemFilter = guns })
    end)
    if not ok then print('^1[exti_weapons] swapItems hook: ' .. tostring(err) .. '^0') end
end)

-- EX_Tii (Moe): the protective helmet. Put on = taken out of the bag and kept on the character (metadata
-- `extihelmet`) until a headshot breaks it. The state bag `extiHelmet` tells the player's game and the HUD.
local function setHelmet(src, on)
    Player(src).state:set('extiHelmet', on == true, true)
    local player = exports.qbx_core:GetPlayer(src)
    if player then player.Functions.SetMetaData('extihelmet', on == true) end
end

RegisterNetEvent('exti_weapons:server:wearHelmet', function(slot)
    local src = source
    if Player(src).state.extiHelmet then return end
    if not exports.qbx_core:GetPlayer(src) then return end
    slot = tonumber(slot)
    local removed = exports.ox_inventory:RemoveItem(src, Config.helmet.item, 1, nil, slot)
        or exports.ox_inventory:RemoveItem(src, Config.helmet.item, 1)
    if not removed then return end
    setHelmet(src, true)
    TriggerClientEvent('ox_lib:notify', src, { description = 'لبست الخوذة الواقية: تحميك من رصاصة واحدة في الرأس', type = 'success' })
    lib.logger(src, 'weapons', 'put on a protective helmet')
end)

RegisterNetEvent('exti_weapons:server:helmetBroke', function()
    local src = source
    if not Player(src).state.extiHelmet then return end
    setHelmet(src, false)
    lib.logger(src, 'weapons', 'helmet broke on a headshot')
end)

-- the character's helmet comes back with him (relog, restart); another character starts without it
local function loadHelmet(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if not src then return end
    local meta = player.PlayerData.metadata or {}
    Player(src).state:set('extiHelmet', meta.extihelmet == true, true)
end
AddEventHandler('QBCore:Server:PlayerLoaded', loadHelmet)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    Player(src).state:set('extiHelmet', false, true)
end)
CreateThread(function()
    Wait(1000)
    local ok, players = pcall(function() return exports.qbx_core:GetQBPlayers() end)
    for _, player in pairs(ok and players or {}) do loadHelmet(player) end
end)

-- admins: try a head prop on yourself (to pick the helmet's look)
lib.addCommand('extihelmetlook', {
    help = 'Weapons: try a head prop on yourself (admin) - number, colour',
    params = { { name = 'number', type = 'number' }, { name = 'colour', type = 'number', optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('exti_weapons:client:helmetLook', source, args.number, args.colour or 0)
end)
