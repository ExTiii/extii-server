-- =====================================================================
-- EX_Tii jobs: work clothes for each job (GTA online characters, male and female)
-- components = { [slot] = { drawable, texture } }   props = { [slot] = { drawable, texture } } (-1 = none)
-- slots: 3 arms, 4 legs, 6 shoes, 8 undershirt, 11 top   props: 0 hat
-- =====================================================================
EXJ.uniforms = {
    garbage = {
        male = {
            components = { [3] = { 0, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 59, 1 }, [11] = { 56, 0 } }, -- orange work vest over a grey shirt
            props = { [0] = { -1 } },
        },
        female = {
            components = { [3] = { 14, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 36, 0 }, [11] = { 49, 0 } },
            props = { [0] = { -1 } },
        },
    },
    tow = {
        male = {
            components = { [3] = { 0, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 66, 0 } },
            props = { [0] = { -1 } },
        },
        female = {
            components = { [3] = { 14, 0 }, [4] = { 39, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 60, 0 } },
            props = { [0] = { -1 } },
        },
    },
    -- EX_Tii: the chicken farm (butcher look): white shirt, dark work trousers, work boots, a cap
    chicken = {
        male = {
            components = { [3] = { 0, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 146, 0 } },
            props = { [0] = { 2, 0 } },
        },
        female = {
            components = { [3] = { 14, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 141, 0 } },
            props = { [0] = { 4, 0 } },
        },
    },
    -- EX_Tii: the vineyard (farm look, same work clothes as the farm, with a wide hat against the sun)
    raisin = {
        male = {
            components = { [3] = { 0, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 146, 0 } },
            props = { [0] = { 13, 0 } },
        },
        female = {
            components = { [3] = { 14, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 141, 0 } },
            props = { [0] = { 13, 0 } },
        },
    },
    -- EX_Tii: the four newer level jobs (farm / dock / mine / factory looks; change them with /jobcloth)
    bread = {
        male = { components = { [3] = { 0, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 146, 0 } }, props = { [0] = { 13, 0 } } },
        female = { components = { [3] = { 14, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 141, 0 } }, props = { [0] = { 13, 0 } } },
    },
    fishing = {
        male = { components = { [3] = { 0, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 146, 0 } }, props = { [0] = { 2, 0 } } },
        female = { components = { [3] = { 14, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 141, 0 } }, props = { [0] = { 4, 0 } } },
    },
    metals = {
        male = { components = { [3] = { 0, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 59, 0 }, [11] = { 146, 0 } }, props = { [0] = { 145, 0 } } },
        female = { components = { [3] = { 14, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 36, 0 }, [11] = { 141, 0 } }, props = { [0] = { 144, 0 } } },
    },
    fabrics = {
        male = { components = { [3] = { 0, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 146, 0 } }, props = { [0] = { -1 } } },
        female = { components = { [3] = { 14, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 141, 0 } }, props = { [0] = { -1 } } },
    },
    delivery = {
        male = {
            components = { [3] = { 0, 0 }, [4] = { 10, 0 }, [6] = { 7, 0 }, [8] = { 15, 0 }, [11] = { 0, 0 } },
            props = { [0] = { 2, 0 } },
        },
        female = {
            components = { [3] = { 14, 0 }, [4] = { 6, 0 }, [6] = { 10, 0 }, [8] = { 14, 0 }, [11] = { 0, 0 } }, -- light tee, black trousers
            props = { [0] = { 4, 0 } }, -- black cap, like the men's
        },
    },
}

-- admins: try the work clothes without a shift (/jobfit garbage, /jobfit off) and single pieces
-- (/jobcloth 11 56 0 = slot drawable texture, /jobcloth p0 2 0 = hat)
local trying = nil
RegisterCommand('jobfit', function(_, args)
    if not lib.callback.await('exti_jobs:server:isAdmin', false) then return end
    local name = args[1]
    if name == 'off' or not EXJ.uniforms[name or ''] then
        if trying then pcall(function() exports['illenium-appearance']:setPedAppearance(cache.ped, trying) end) end
        trying = nil
        return
    end
    if not trying then
        local ok, look = pcall(function() return exports['illenium-appearance']:getPedAppearance(cache.ped) end)
        trying = ok and look or nil
    end
    local model = GetEntityModel(cache.ped)
    local set = EXJ.uniforms[name][(model == `mp_f_freemode_01`) and 'female' or 'male']
    for comp, v in pairs(set.components) do SetPedComponentVariation(cache.ped, comp, v[1], v[2] or 0, 0) end
    for prop, v in pairs(set.props or {}) do
        if v[1] < 0 then ClearPedProp(cache.ped, prop) else SetPedPropIndex(cache.ped, prop, v[1], v[2] or 0, true) end
    end
end, false)

RegisterCommand('jobcloth', function(_, args)
    if not lib.callback.await('exti_jobs:server:isAdmin', false) then return end
    local slot, drawable, texture = args[1], tonumber(args[2]), tonumber(args[3]) or 0
    if not slot or not drawable then return end
    if slot:sub(1, 1) == 'p' then
        local prop = tonumber(slot:sub(2))
        if drawable < 0 then ClearPedProp(cache.ped, prop) else SetPedPropIndex(cache.ped, prop, drawable, texture, true) end
    else
        SetPedComponentVariation(cache.ped, tonumber(slot), drawable, texture, 0)
    end
    print(('[jobcloth] slot %s = %d / %d (of %d)'):format(slot, drawable, texture,
        slot:sub(1, 1) == 'p' and GetNumberOfPedPropDrawableVariations(cache.ped, tonumber(slot:sub(2))) or GetNumberOfPedDrawableVariations(cache.ped, tonumber(slot))))
end, false)
