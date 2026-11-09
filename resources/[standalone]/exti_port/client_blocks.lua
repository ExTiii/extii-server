-- =====================================================================
-- EX_Tii (Moe): the concrete blocks placed with /port block (shared with everyone, made when you are near).
-- Solid: cars and people can't move them.
-- =====================================================================
local B = Config.blocks
local made, objs, model = false, {}, nil

local function pickModel()
    local list = {}
    if tonumber(GlobalState.extiPortBlockModel) then list[1] = tonumber(GlobalState.extiPortBlockModel) end
    for _, n in ipairs(B.models) do list[#list + 1] = joaat(n) end
    for _, h in ipairs(list) do
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
end

local function clear()
    for _, o in ipairs(objs) do if DoesEntityExist(o) then DeleteEntity(o) end end
    objs, made = {}, false
end

local function build()
    clear()
    made = true
    local list = GlobalState.extiPortBlocks
    if type(list) ~= 'table' or #list == 0 then return end
    model = pickModel()
    if not model then return print('^3[exti_port] no concrete block model found^0') end
    local mn = GetModelDimensions(model)
    for _, b in ipairs(list) do
        local ok, gz = GetGroundZFor_3dCoord(b.x, b.y, b.z + 2.0, false)
        local z = (ok and math.abs(gz - b.z) < 3.0) and gz or b.z
        local o = CreateObjectNoOffset(model, b.x, b.y, z - mn.z, false, false, false)
        if o ~= 0 then
            SetEntityHeading(o, b.h or 0.0)
            FreezeEntityPosition(o, true)
            SetEntityInvincible(o, true)
            objs[#objs + 1] = o
        end
    end
end

-- how far the nearest block is
local function nearest()
    local list = GlobalState.extiPortBlocks
    if type(list) ~= 'table' or #list == 0 then return nil end
    local p, best = GetEntityCoords(cache.ped).xy, nil
    for _, b in ipairs(list) do
        local d = #(p - vector2(b.x, b.y))
        if not best or d < best then best = d end
    end
    return best
end

AddStateBagChangeHandler('extiPortBlocks', 'global', function() SetTimeout(0, function() if made then build() end end) end)
AddStateBagChangeHandler('extiPortBlockModel', 'global', function() SetTimeout(0, function() if made then build() end end) end)

CreateThread(function()
    Wait(1000)
    while true do
        local d = nearest()
        if d then
            if d < B.distance and not made then build()
            elseif d > B.distance + 40.0 and made then clear() end
        elseif made then clear() end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
