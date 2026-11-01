-- EX_Tii radial menu: walk styles (saved on your character, back after a relog)

RAD = RAD or {}
RAD.actions = RAD.actions or {}

local currentId = 'default'

local function styleById(id)
    for _, s in ipairs(Config.walkStyles) do
        if s.id == id then return s end
    end
end

local function apply(style)
    if not style or not style.clipset then
        ResetPedMovementClipset(cache.ped, 0.3)
        return true
    end
    if not pcall(lib.requestAnimSet, style.clipset, 2000) then return false end
    SetPedMovementClipset(cache.ped, style.clipset, 0.3)
    return true
end

local function items()
    local out = {}
    for _, s in ipairs(Config.walkStyles) do
        out[#out + 1] = { id = 'walk_' .. s.id, label = s.label .. (s.id == currentId and ' ✓' or ''), icon = s.clipset and 'person-walking' or 'user', action = 'walkSet', arg = s.id }
    end
    return out
end

RAD.actions.walkMenu = function()
    return 'menu', items
end

RAD.actions.walkSet = function(id)
    local style = styleById(id)
    if not style then return end
    if not apply(style) then exports.qbx_core:Notify('تعذر تطبيق طريقة المشي', 'error') return end
    currentId = id
    TriggerServerEvent('exti_radial:server:walkStyle', id)
    return 'stay'
end

-- back after a relog / a new ped (the model change resets the walk)
local function restore()
    local meta = QBX and QBX.PlayerData and QBX.PlayerData.metadata
    local id = meta and meta.walkstyle
    currentId = (id and styleById(id)) and id or 'default'
    SetTimeout(1500, function() apply(styleById(currentId)) end)
end
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', restore)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() currentId = 'default' end)
lib.onCache('ped', function()
    if LocalPlayer.state.isLoggedIn and currentId ~= 'default' then SetTimeout(500, function() apply(styleById(currentId)) end) end
end)
AddEventHandler('onResourceStart', function(resource)
    if resource == cache.resource and LocalPlayer.state.isLoggedIn then restore() end
end)
