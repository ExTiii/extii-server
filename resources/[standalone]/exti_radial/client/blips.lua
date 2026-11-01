-- EX_Tii radial menu: the Map menu, hide or show the map icons by type.
-- The choice is kept on this computer (KVP), so it stays after a relog.

RAD = RAD or {}
RAD.actions = RAD.actions or {}

local hidden = {}   -- [groupId] = true
local KVP = 'exti_radial_hidden_blips'

do
    local raw = GetResourceKvpString(KVP)
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then hidden = data end
end

local function save()
    SetResourceKvp(KVP, json.encode(hidden))
end

local function groupById(id)
    for _, g in ipairs(Config.blipGroups) do
        if g.id == id then return g end
    end
end

-- every blip of these sprites: shown or hidden
local function applyGroup(g, hide)
    for _, sprite in ipairs(g.sprites) do
        local blip = GetFirstBlipInfoId(sprite)
        while DoesBlipExist(blip) do
            SetBlipDisplay(blip, hide and 0 or 4)
            blip = GetNextBlipInfoId(sprite)
        end
    end
end

local function applyAll()
    for _, g in ipairs(Config.blipGroups) do
        if hidden[g.id] then applyGroup(g, true) end
    end
end

function RAD.blipMenu()
    local out = {}
    for _, g in ipairs(Config.blipGroups) do
        local off = hidden[g.id] == true
        out[#out + 1] = { id = 'blip_' .. g.id, label = g.label .. (off and ' (مخفي)' or ''), icon = off and 'eye-slash' or g.icon, action = 'blipToggle', arg = g.id }
    end
    return out
end

RAD.actions.blipToggle = function(id)
    local g = groupById(id)
    if not g then return end
    if hidden[id] then
        hidden[id] = nil
        applyGroup(g, false)
    else
        hidden[id] = true
        applyGroup(g, true)
    end
    save()
    return 'stay'
end

-- scripts make their blips again after a restart or a new job, so hide them again every few seconds
CreateThread(function()
    while true do
        Wait(3000)
        if next(hidden) then applyAll() end
    end
end)
