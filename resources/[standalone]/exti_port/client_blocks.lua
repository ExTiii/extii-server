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
                local p = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0 + (mx.y - mn.y) / 2, 0.0)
                local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 2.0, false)
                lookObj = CreateObjectNoOffset(h, p.x, p.y, (ok and gz or p.z - 1.0) - mn.z, false, false, false)
                SetEntityHeading(lookObj, GetEntityHeading(cache.ped))
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
