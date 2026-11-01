-- EX_Tii radial menu: taking clothes and props off and putting them back on

RAD = RAD or {}
RAD.actions = RAD.actions or {}

local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`
local last = {}       -- what you took off, so it can come back: last[key] = { drawable, texture }
local busy = false

local function notify(text, kind) exports.qbx_core:Notify(text, kind or 'inform') end

local function gender()
    local model = GetEntityModel(cache.ped)
    if model == MALE then return 'male' elseif model == FEMALE then return 'female' end
    return nil
end

-- a short animation while you change (the clothes change half way through)
local function animate(anim, change)
    if busy then return end
    busy = true
    CreateThread(function()
        local ok = anim and pcall(lib.requestAnimDict, anim.dict, 1000)
        if ok then
            TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, anim.ms or 1200, anim.move == false and 0 or 51, 0, false, false, false)
            Wait(math.floor((anim.ms or 1200) / 2))
        end
        change()
        if ok then Wait(math.floor((anim.ms or 1200) / 2)) end
        busy = false
    end)
end

RAD.actions.toggleProp = function(key)
    local def = Config.props[key]
    if not def then return end
    local idx = def.index
    local now = GetPedPropIndex(cache.ped, idx)
    if now ~= -1 then
        animate(def.anim, function()
            last['prop' .. idx] = { drawable = now, texture = GetPedPropTextureIndex(cache.ped, idx) }
            ClearPedProp(cache.ped, idx)
        end)
        return
    end
    local back = last['prop' .. idx]
    if not back then notify('لا يوجد شيء لخلعه', 'error') return end
    animate(def.anim, function()
        SetPedPropIndex(cache.ped, idx, back.drawable, back.texture, true)
        last['prop' .. idx] = nil
    end)
end

RAD.actions.toggleCloth = function(key)
    local def = Config.cloth[key]
    if not def then return end
    local g = gender()
    if not g then notify('هذا يعمل مع شخصيات اللعبة الأساسية فقط', 'error') return end
    local comp = def.component
    local off = def.off[g]
    local now = GetPedDrawableVariation(cache.ped, comp)
    if now ~= off then
        -- wearing something: take it off (and what goes with it) and remember it
        animate(def.anim, function()
            last['comp' .. comp] = { drawable = now, texture = GetPedTextureVariation(cache.ped, comp) }
            SetPedComponentVariation(cache.ped, comp, off, 0, 0)
            for _, extra in ipairs(def.also or {}) do
                last['comp' .. extra.component] = { drawable = GetPedDrawableVariation(cache.ped, extra.component), texture = GetPedTextureVariation(cache.ped, extra.component) }
                SetPedComponentVariation(cache.ped, extra.component, extra.off, 0, 0)
            end
        end)
        return
    end
    local back = last['comp' .. comp]
    if not back then notify('لا يوجد شيء لخلعه', 'error') return end
    -- put it back on (and whatever came off with it)
    animate(def.anim, function()
        SetPedComponentVariation(cache.ped, comp, back.drawable, back.texture, 0)
        last['comp' .. comp] = nil
        for _, extra in ipairs(def.also or {}) do
            local b = last['comp' .. extra.component]
            if b then
                SetPedComponentVariation(cache.ped, extra.component, b.drawable, b.texture, 0)
                last['comp' .. extra.component] = nil
            end
        end
    end)
end

-- a new look from the clothing shop or a uniform: forget what was taken off before it
AddEventHandler('illenium-appearance:client:appearanceApplied', function() last = {} end)
RegisterNetEvent('exti_radial:client:forgetClothes', function() last = {} end)
lib.onCache('ped', function() last = {} end)
