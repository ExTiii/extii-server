-- EX_Tii: glue between the game and the new black & gold appearance screen (web/ex)
-- - tells the screen which shop it is in (clothing, barber, tattoo, surgeon, wardrobe) and the prices
-- - the clothing cart: the server prices every changed piece and takes cash or bank
-- - turning the character with the mouse / A and D
-- - the wardrobe (saved outfits): save, wear, delete, from inside a clothing store or from a house closet

local client = client

ExtiShop = nil -- set while a shop or the wardrobe is open; nil for uniforms, the character creator, etc.

local function outfitList(outfits)
    local out = {}
    for i = 1, #(outfits or {}) do
        out[#out + 1] = { id = outfits[i].id, name = outfits[i].name }
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end

RegisterNUICallback("exti_get_shop", function(_, cb)
    local shop = ExtiShop
    if not shop then return cb({}) end
    local wallet = lib.callback.await("illenium-appearance:server:extiWallet", false) or {}
    local data = { shopType = shop.shopType, cash = wallet.cash or 0, bank = wallet.bank or 0 }
    if shop.wardrobe then
        data.wardrobe = true
        data.outfits = outfitList(lib.callback.await("illenium-appearance:server:getOutfits", false))
    elseif shop.shopType == "clothing" then
        data.prices = Config.ExtiPrices
    elseif shop.shopType == "barber" then
        data.flatCost = Config.BarberCost
    elseif shop.shopType == "surgeon" then
        data.flatCost = Config.SurgeonCost
    elseif shop.shopType == "tattoo" then
        data.tattooCost = Config.TattooCost
    end
    cb(data)
end)

RegisterNUICallback("exti_pay_cart", function(data, cb)
    if not ExtiShop or ExtiShop.shopType ~= "clothing" or ExtiShop.isPedMenu then
        return cb({ ok = false, msg = "لا يوجد ما تدفعه هنا" })
    end
    local method = data and data.method == "bank" and "bank" or "cash"
    local res = lib.callback.await("illenium-appearance:server:extiPayCart", false, method, data and data.appearance, data and data.expected)
    if res and res.ok then ExtiShop.paid = true end
    cb(res or { ok = false, msg = "لم يتم الدفع، حاول مرة أخرى" })
end)

-- turn the character in place (the camera stays where it is)
RegisterNUICallback("exti_rotate", function(data, cb)
    cb(1)
    local deg = tonumber(data and data.deg) or 0
    if deg == 0 then return end
    deg = math.max(-180.0, math.min(180.0, deg + 0.0))
    SetEntityHeading(cache.ped, (GetEntityHeading(cache.ped) + deg) % 360.0)
end)

-- wardrobe ------------------------------------------------------------------------------------
RegisterNUICallback("exti_outfit_list", function(_, cb)
    cb({ outfits = outfitList(lib.callback.await("illenium-appearance:server:getOutfits", false)) })
end)

RegisterNUICallback("exti_outfit_save", function(data, cb)
    local name = data and type(data.name) == "string" and data.name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return cb({ msg = "اكتب اسمًا للزي" }) end
    -- always save what the character really has on (the screen's copy could be edited)
    local res = lib.callback.await("illenium-appearance:server:extiOutfitSave", false, (utf8.len(name) and utf8.len(name) > 30) and name:sub(1, utf8.offset(name, 31) - 1) or name,
        client.getPedModel(cache.ped), client.getPedComponents(cache.ped), client.getPedProps(cache.ped))
    if res and res.outfits then res.outfits = outfitList(res.outfits) end
    cb(res or { msg = "لم يُحفظ، حاول مرة أخرى" })
end)

RegisterNUICallback("exti_outfit_wear", function(data, cb)
    local id = data and tonumber(data.id)
    local outfits = lib.callback.await("illenium-appearance:server:getOutfits", false) or {}
    local outfit
    for i = 1, #outfits do
        if outfits[i].id == id then outfit = outfits[i] break end
    end
    if not outfit then return cb({ msg = "هذا الزي غير موجود" }) end
    if outfit.model and outfit.model ~= client.getPedModel(cache.ped) then
        return cb({ msg = "هذا الزي لشخصية بجسم مختلف" })
    end
    client.setPedComponents(cache.ped, outfit.components)
    client.setPedProps(cache.ped, outfit.props)
    local appearance = client.getPedAppearance(cache.ped)
    -- the outfit is yours: it is saved right away and becomes the look you "came in" with,
    -- so the clothing store does not charge for it and leaving the screen keeps it on
    client.setBaseAppearance(appearance)
    lib.callback.await("illenium-appearance:server:extiSaveLook", false, appearance) -- wait, so paying right after sees it
    cb({ appearance = appearance })
end)

RegisterNUICallback("exti_outfit_delete", function(data, cb)
    local res = lib.callback.await("illenium-appearance:server:extiOutfitDelete", false, data and tonumber(data.id))
    if res and res.outfits then res.outfits = outfitList(res.outfits) end
    cb(res or {})
end)

-- the wardrobe on its own (house closets, or any other script): free, your saved outfits only
function OpenWardrobe()
    if ExtiShop then return end
    local config = GetDefaultConfig()
    config.components = true
    config.props = true
    ExtiShop = { wardrobe = true }
    client.startPlayerCustomization(function(appearance)
        ExtiShop = nil
        if appearance then
            TriggerServerEvent("illenium-appearance:server:saveAppearance", appearance)
        end
        Framework.CachePed()
    end, config)
end
RegisterNetEvent("illenium-appearance:client:openWardrobe", OpenWardrobe)
exports("openWardrobe", OpenWardrobe)
