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

local pending = {}   -- blocks not yet sat on the road: { o, x, y, z } (the ground far away isn't loaded yet)

local function clear()
    for _, o in ipairs(objs) do if DoesEntityExist(o) then DeleteEntity(o) end end
    objs, made, pending = {}, false, {}
end

-- sit a block on the road under it, tilted with the slope (a ramp, a bridge, a curb). Only works once the
-- ground there is loaded (close to you): until then it waits in the pending list
local function settle(p)
    if not DoesEntityExist(p.o) then return true end
    local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 8.0, false)   -- (from just above: on a bridge = the bridge)
    if not ok or gz < p.z - 12.0 then return false end
    local mn = GetModelDimensions(GetEntityModel(p.o))
    FreezeEntityPosition(p.o, false)
    SetEntityCoordsNoOffset(p.o, p.x, p.y, gz - mn.z, false, false, false)
    SetEntityHeading(p.o, p.h)
    PlaceObjectOnGroundProperly(p.o)
    FreezeEntityPosition(p.o, true)
    return true
end

-- every block to make: the single ones, and the rows filled from point to point
local function allBlocks()
    local out = {}
    for _, b in ipairs(type(GlobalState.extiPortBlocks) == 'table' and GlobalState.extiPortBlocks or {}) do out[#out + 1] = b end
    for _, row in ipairs(type(GlobalState.extiPortBlockRows) == 'table' and GlobalState.extiPortBlockRows or {}) do
        for i = 1, #row - 1 do
            local a, b = row[i], row[i + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local D = math.sqrt(dx * dx + dy * dy)
            if D > 0.3 then
                local n = math.max(1, math.ceil(D / B.length))    -- (evenly spread: no gap anywhere)
                local step = D / n
                local h = math.deg(math.atan(dy, dx))              -- the line's direction: the block's long side along it
                for k = 0, n - 1 do
                    local t = (k + 0.5) * step / D
                    out[#out + 1] = { x = a.x + dx * t, y = a.y + dy * t, z = a.z + (b.z - a.z) * t, h = h }
                end
            end
        end
    end
    return out
end

local function build()
    clear()
    made = true
    local list = allBlocks()
    if #list == 0 then return end
    model = pickModel()
    if not model then return print('^3[exti_port] no concrete block model found^0') end
    local mn = GetModelDimensions(model)
    for _, b in ipairs(list) do
        local o = CreateObjectNoOffset(model, b.x, b.y, b.z - mn.z, false, false, false)
        if o ~= 0 then
            SetEntityHeading(o, b.h or 0.0)
            FreezeEntityPosition(o, true)
            SetEntityInvincible(o, true)
            objs[#objs + 1] = o
            local p = { o = o, x = b.x, y = b.y, z = b.z, h = b.h or 0.0 }
            if not settle(p) then pending[#pending + 1] = p end
        end
    end
end

-- how far the nearest block is
local function nearest()
    local list = {}
    for _, b in ipairs(type(GlobalState.extiPortBlocks) == 'table' and GlobalState.extiPortBlocks or {}) do list[#list + 1] = b end
    for _, row in ipairs(type(GlobalState.extiPortBlockRows) == 'table' and GlobalState.extiPortBlockRows or {}) do
        for _, p in ipairs(row) do list[#list + 1] = p end
    end
    if #list == 0 then return nil end
    local p, best = GetEntityCoords(cache.ped).xy, nil
    for _, b in ipairs(list) do
        local d = #(p - vector2(b.x, b.y))
        if not best or d < best then best = d end
    end
    return best
end

AddStateBagChangeHandler('extiPortBlocks', 'global', function() SetTimeout(0, function() if made then build() end end) end)
AddStateBagChangeHandler('extiPortBlockRows', 'global', function() SetTimeout(0, function() if made then build() end end) end)
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

-- the ones still waiting: sat on the road as you come close (the ground loads around you)
CreateThread(function()
    while true do
        if #pending > 0 then
            local me = GetEntityCoords(cache.ped).xy
            for i = #pending, 1, -1 do
                local p = pending[i]
                if #(me - vector2(p.x, p.y)) < 150.0 and settle(p) then table.remove(pending, i) end
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)

-- /portblocks (admin look): shows the concrete pieces GTA has, one at a time in front of you. Type it again for
-- the next one; when you like one, /port blockmodel <the number it shows>
local LOOK = {
    'prop_mp_barrier_02b', 'prop_mp_barrier_02', 'prop_mp_conc_barrier_01',
    'prop_barier_conc_01a', 'prop_barier_conc_01b', 'prop_barier_conc_01c',
    'prop_barier_conc_02a', 'prop_barier_conc_02b', 'prop_barier_conc_02c',
    'prop_barier_conc_03a', 'prop_barier_conc_04a',
    'prop_barier_conc_05a', 'prop_barier_conc_05b', 'prop_barier_conc_05c',
    'prop_conc_blocks01a', 'prop_conc_blocks01b', 'prop_conc_blocks01c',
    'prop_byard_block_01', 'prop_const_fence01a', 'prop_const_fence02a',
    'prop_sea_wall_01', 'prop_sea_wall_02', 'prop_dock_wall_01',
    'prop_conc_wall_01', 'prop_conc_wall_02', 'prop_sec_conc_wall',
}
local lookAt, lookObj = 0, nil
RegisterCommand('portblocks', function()
    if lookObj and DoesEntityExist(lookObj) then DeleteEntity(lookObj) end
    lookObj = nil
    for _ = 1, #LOOK do
        lookAt = lookAt % #LOOK + 1
        local name = LOOK[lookAt]
        local h = joaat(name)
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then
                local mn, mx = GetModelDimensions(h)
                local p = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.0 + (mx.x - mn.x) / 2, 0.0)
                local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 2.0, false)
                lookObj = CreateObjectNoOffset(h, p.x, p.y, (ok and gz or p.z - 1.0) - mn.z, false, false, false)
                SetEntityHeading(lookObj, GetEntityHeading(cache.ped) + 90.0)   -- (long side the way you face, like /port block)
                FreezeEntityPosition(lookObj, true)
                SetModelAsNoLongerNeeded(h)
                local msg = ('%d) %s  ·  /port blockmodel %d  ·  %.1f م طول، %.1f م ارتفاع'):format(lookAt, name, h, mx.x - mn.x, mx.z - mn.z)
                print('[exti_port] ' .. msg)
                lib.notify({ description = msg, type = 'inform', duration = 10000 })
                return
            end
        end
    end
    lib.notify({ description = 'لم أجد أي قطعة', type = 'error' })
end, false)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and lookObj and DoesEntityExist(lookObj) then DeleteEntity(lookObj) end
end)

-- =====================================================================
-- checkpoints without a gate (/port booth): just the guard booth, made when you are near
-- =====================================================================
local booths = {}   -- [index] = object
local function boothModel()
    local list = {}
    if tonumber(GlobalState.extiPortBoothModel) then list[1] = tonumber(GlobalState.extiPortBoothModel) end
    for _, n in ipairs(Config.checkpoint.boothModels) do list[#list + 1] = joaat(n) end
    for _, h in ipairs(list) do
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
end
local function clearBooths()
    for _, o in pairs(booths) do if DoesEntityExist(o) then DeleteEntity(o) end end
    booths = {}
end
AddStateBagChangeHandler('extiPortBooths', 'global', function() SetTimeout(0, clearBooths) end)
AddStateBagChangeHandler('extiPortBoothModel', 'global', function() SetTimeout(0, clearBooths) end)
CreateThread(function()
    Wait(1500)
    while true do
        local list = type(GlobalState.extiPortBooths) == 'table' and GlobalState.extiPortBooths or {}
        local me = GetEntityCoords(cache.ped).xy
        for i, b in ipairs(list) do
            local d = #(me - vector2(b.x, b.y))
            if d < 250.0 and not booths[i] then
                local m = boothModel()
                if m then
                    local mn = GetModelDimensions(m)
                    local ok, gz = GetGroundZFor_3dCoord(b.x, b.y, b.z + 2.0, false)
                    local z = (ok and math.abs(gz - b.z) < 3.0) and gz or b.z
                    local o = CreateObjectNoOffset(m, b.x, b.y, z - mn.z, false, false, false)
                    if o ~= 0 then
                        SetEntityHeading(o, b.h or 0.0)
                        FreezeEntityPosition(o, true)
                        SetEntityInvincible(o, true)
                        booths[i] = o
                    end
                end
            elseif d > 290.0 and booths[i] then
                if DoesEntityExist(booths[i]) then DeleteEntity(booths[i]) end
                booths[i] = nil
            end
        end
        for i, o in pairs(booths) do
            if not list[i] then if DoesEntityExist(o) then DeleteEntity(o) end booths[i] = nil end
        end
        Wait(1500)
    end
end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clearBooths() end end)
