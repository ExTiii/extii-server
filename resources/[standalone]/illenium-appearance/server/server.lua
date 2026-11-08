local outfitCache = {}
local uniformCache = {}

local function getMoneyForShop(shopType)
    local money = 0
    if shopType == "clothing" then
        money = Config.ClothingCost
    elseif shopType == "barber" then
        money = Config.BarberCost
    elseif shopType == "tattoo" then
        money = Config.TattooCost
    elseif shopType == "surgeon" then
        money = Config.SurgeonCost
    end

    return money
end

local function getOutfitsForPlayer(citizenid)
    outfitCache[citizenid] = {}
    local result = Database.PlayerOutfits.GetAllByCitizenID(citizenid)
    for i = 1, #result, 1 do
        outfitCache[citizenid][#outfitCache[citizenid] + 1] = {
            id = result[i].id,
            name = result[i].outfitname,
            model = result[i].model,
            components = json.decode(result[i].components),
            props = json.decode(result[i].props)
        }
    end
end

local function GenerateUniqueCode()
    local code, exists
    repeat
        code = GenerateNanoID(Config.OutfitCodeLength)
        exists = Database.PlayerOutfitCodes.GetByCode(code)
    until not exists
    return code
end

-- Callback(s)

lib.callback.register("illenium-appearance:server:generateOutfitCode", function(_, outfitID)
    local existingOutfitCode = Database.PlayerOutfitCodes.GetByOutfitID(outfitID)
    if not existingOutfitCode then
        local code = GenerateUniqueCode()
        local id = Database.PlayerOutfitCodes.Add(outfitID, code)
        if not id then
            print("Something went wrong while generating outfit code")
            return
        end
        return code
    end
    return existingOutfitCode.code
end)

lib.callback.register("illenium-appearance:server:importOutfitCode", function(source, outfitName, outfitCode)
    local citizenID = Framework.GetPlayerID(source)
    local existingOutfitCode = Database.PlayerOutfitCodes.GetByCode(outfitCode)
    if not existingOutfitCode then
        return nil
    end

    local playerOutfit = Database.PlayerOutfits.GetByID(existingOutfitCode.outfitid)
    if not playerOutfit then
        return
    end

    if playerOutfit.citizenid == citizenID then return end -- Validation when someone tried to duplicate own outfit
    if Database.PlayerOutfits.GetByOutfit(outfitName, citizenID) then return end -- Validation duplicate outfit name, if validate on local id, someone can "spam error" server-sided

    local id = Database.PlayerOutfits.Add(citizenID, outfitName, playerOutfit.model, playerOutfit.components, playerOutfit.props)

    if not id then
        print("Something went wrong while importing the outfit")
        return
    end

    outfitCache[citizenID][#outfitCache[citizenID] + 1] = {
        id = id,
        name = outfitName,
        model = playerOutfit.model,
        components = json.decode(playerOutfit.components),
        props = json.decode(playerOutfit.props)
    }

    return true
end)

lib.callback.register("illenium-appearance:server:getAppearance", function(source, model)
    local citizenID = Framework.GetPlayerID(source)
    return Framework.GetAppearance(citizenID, model)
end)

lib.callback.register("illenium-appearance:server:hasMoney", function(source, shopType)
    local money = getMoneyForShop(shopType)
    if Framework.HasMoney(source, "cash", money) then
        return true, money
    else
        return false, money
    end
end)

lib.callback.register("illenium-appearance:server:payForTattoo", function(source, tattoo)
    local src = source
    if type(tattoo) ~= "table" then return false end
    local cost = tonumber(tattoo.cost) or Config.TattooCost
    -- EX_Tii: cash first, then the bank card
    if Framework.RemoveMoney(src, "cash", cost) or Framework.RemoveMoney(src, "bank", cost) then
        lib.notify(src, {
            title = _L("purchase.tattoo.success.title"),
            description = string.format(_L("purchase.tattoo.success.description"), tattoo.label, cost),
            type = "success",
            position = Config.NotifyOptions.position
        })
        return true
    else
        lib.notify(src, {
            title = _L("purchase.tattoo.failure.title"),
            description = _L("purchase.tattoo.failure.description"),
            type = "error",
            position = Config.NotifyOptions.position
        })
        return false
    end
end)

lib.callback.register("illenium-appearance:server:getOutfits", function(source)
    local citizenID = Framework.GetPlayerID(source)
    if outfitCache[citizenID] == nil then
        getOutfitsForPlayer(citizenID)
    end
    return outfitCache[citizenID]
end)

lib.callback.register("illenium-appearance:server:getManagementOutfits", function(source, mType, gender)
    local job = Framework.GetJob(source)
    if mType == "Gang" then
        job = Framework.GetGang(source)
    end

    local grade = tonumber(job.grade.level)
    local managementOutfits = {}
    local result = Database.ManagementOutfits.GetAllByJob(mType, job.name, gender)

    for i = 1, #result, 1 do
        if grade >= result[i].minrank then
            managementOutfits[#managementOutfits + 1] = {
                id = result[i].id,
                name = result[i].name,
                model = result[i].model,
                gender = result[i].gender,
                components = json.decode(result[i].components),
                props = json.decode(result[i].props)
            }
        end
    end
    return managementOutfits
end)

lib.callback.register("illenium-appearance:server:getUniform", function(source)
    return uniformCache[Framework.GetPlayerID(source)]
end)

RegisterServerEvent("illenium-appearance:server:saveAppearance", function(appearance)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    if appearance ~= nil then
        Framework.SaveAppearance(appearance, citizenID)
    end
end)

RegisterServerEvent("illenium-appearance:server:chargeCustomer", function(shopType)
    local src = source
    local money = getMoneyForShop(shopType)
    if Framework.RemoveMoney(src, "cash", money) then
        lib.notify(src, {
            title = _L("purchase.store.success.title"),
            description = string.format(_L("purchase.store.success.description"), money, shopType),
            type = "success",
            position = Config.NotifyOptions.position
        })
    else
        lib.notify(src, {
            title = _L("purchase.store.failure.title"),
            description = _L("purchase.store.failure.description"),
            type = "error",
            position = Config.NotifyOptions.position
        })
    end
end)

RegisterNetEvent("illenium-appearance:server:saveOutfit", function(name, model, components, props)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    if outfitCache[citizenID] == nil then
        getOutfitsForPlayer(citizenID)
    end
    if model and components and props then
        local id = Database.PlayerOutfits.Add(citizenID, name, model, json.encode(components), json.encode(props))
        if not id then
            return
        end
        outfitCache[citizenID][#outfitCache[citizenID] + 1] = {
            id = id,
            name = name,
            model = model,
            components = components,
            props = props
        }
        lib.notify(src, {
            title = _L("outfits.save.success.title"),
            description = string.format(_L("outfits.save.success.description"), name),
            type = "success",
            position = Config.NotifyOptions.position
        })
    end
end)

RegisterNetEvent("illenium-appearance:server:updateOutfit", function(id, model, components, props)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    if outfitCache[citizenID] == nil then
        getOutfitsForPlayer(citizenID)
    end
    if model and components and props then
        if not Database.PlayerOutfits.Update(id, model, json.encode(components), json.encode(props)) then return end
        local outfitName = ""
        for i = 1, #outfitCache[citizenID], 1 do
            local outfit = outfitCache[citizenID][i]
            if outfit.id == id then
                outfit.model = model
                outfit.components = components
                outfit.props = props
                outfitName = outfit.name
                break
            end
        end
        lib.notify(src, {
            title = _L("outfits.update.success.title"),
            description = string.format(_L("outfits.update.success.description"), outfitName),
            type = "success",
            position = Config.NotifyOptions.position
        })
    end
end)

RegisterNetEvent("illenium-appearance:server:saveManagementOutfit", function(outfitData)
    local src = source
    local id = Database.ManagementOutfits.Add(outfitData)
    if not id then
        return
    end

    lib.notify(src, {
        title = _L("outfits.save.success.title"),
            description = string.format(_L("outfits.save.success.description"), outfitData.Name),
        type = "success",
        position = Config.NotifyOptions.position
    })
end)

RegisterNetEvent("illenium-appearance:server:deleteManagementOutfit", function(id)
    Database.ManagementOutfits.DeleteByID(id)
end)

RegisterNetEvent("illenium-appearance:server:syncUniform", function(uniform)
    local src = source
    uniformCache[Framework.GetPlayerID(src)] = uniform
end)

RegisterNetEvent("illenium-appearance:server:deleteOutfit", function(id)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    Database.PlayerOutfitCodes.DeleteByOutfitID(id)
    Database.PlayerOutfits.DeleteByID(id)

    for k, v in ipairs(outfitCache[citizenID]) do
        if v.id == id then
            table.remove(outfitCache[citizenID], k)
            break
        end
    end
end)

RegisterNetEvent("illenium-appearance:server:resetOutfitCache", function()
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    if citizenID then
        outfitCache[citizenID] = nil
    end
end)

RegisterNetEvent("illenium-appearance:server:ChangeRoutingBucket", function()
    local src = source
    SetPlayerRoutingBucket(src, src)
end)

RegisterNetEvent("illenium-appearance:server:ResetRoutingBucket", function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)

if Config.EnablePedMenu then
    lib.addCommand("pedmenu", {
        help = _L("commands.pedmenu.title"),
        params = {
            {
                name = "playerID",
                type = "number",
                help = "Target player's server id",
                optional = true
            },
        },
        restricted = Config.PedMenuGroup
    }, function(source, args)
        local target = source
        if args.playerID then
            local citizenID = Framework.GetPlayerID(args.playerID)
            if citizenID then
                target = args.playerID
            else
                lib.notify(source, {
                    title = _L("commands.pedmenu.failure.title"),
                    description = _L("commands.pedmenu.failure.description"),
                    type = "error",
                    position = Config.NotifyOptions.position
                })
                return
            end
        end
        TriggerClientEvent("illenium-appearance:client:openClothingShopMenu", target, true)
    end)
end

if Config.EnableJobOutfitsCommand then
    lib.addCommand("joboutfits", { help = _L("commands.joboutfits.title"), }, function(source)
        TriggerClientEvent("illenium-apearance:client:outfitsCommand", source, true)
    end)

    lib.addCommand("gangoutfits", { help = _L("commands.gangoutfits.title"), }, function(source)
        TriggerClientEvent("illenium-apearance:client:outfitsCommand", source)
    end)
end

lib.addCommand("reloadskin", { help = _L("commands.reloadskin.title") }, function(source)
    TriggerClientEvent("illenium-appearance:client:reloadSkin", source)
end)

lib.addCommand("clearstuckprops", { help = _L("commands.clearstuckprops.title") }, function(source)
    TriggerClientEvent("illenium-appearance:client:ClearStuckProps", source)
end)

lib.versionCheck("iLLeniumStudios/illenium-appearance")

-- EX_Tii -----------------------------------------------------------------------------------------
-- wallet, the clothing cart (price per piece) and the wardrobe for the new appearance screen

local function extiPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

local function extiWallet(src)
    local player = extiPlayer(src)
    local money = player and player.PlayerData and player.PlayerData.money or {}
    return { cash = math.floor(money.cash or 0), bank = math.floor(money.bank or 0) }
end

lib.callback.register("illenium-appearance:server:extiWallet", function(source)
    return extiWallet(source)
end)

local function byId(list, key)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, v in pairs(list) do
        if type(v) == "table" and tonumber(v[key]) then out[tonumber(v[key])] = v end
    end
    return out
end

local FREE_OFF = { [1] = true, [5] = true, [7] = true, [9] = true, [10] = true } -- drawable 0 = nothing on
-- the "nothing on" piece of the other sections (GTA's own bare pieces), per body; taking them off is free too
local NONE_OF = {
    mp_m_freemode_01 = { [3] = 15, [4] = 14, [6] = 34, [8] = 15, [11] = 15 },
    mp_f_freemode_01 = { [3] = 15, [4] = 15, [6] = 35, [8] = 14, [11] = 15 },
}

local function cartTotal(old, new)
    local total = 0
    local none = NONE_OF[new.model or old.model] or {}
    local oc, nc = byId(old.components, "component_id"), byId(new.components, "component_id")
    local function differs(id)
        local o, n = oc[id], nc[id]
        return n ~= nil and (not o or tonumber(o.drawable) ~= tonumber(n.drawable) or tonumber(o.texture) ~= tonumber(n.texture))
    end
    -- EX_Tii (Moe): a jacket brings its own arms (3) and undershirt (8) with it (the game's clothing data),
    -- so when the jacket changes those two come free (the screen prices them the same way)
    -- (and the arms come with the undershirt too, when there is no jacket on)
    local withJacket, withShirt = differs(11), differs(8)
    for id, n in pairs(nc) do
        local price = Config.ExtiPrices["c" .. id] or 0
        local o = oc[id]
        local off = (tonumber(n.drawable) == 0 and FREE_OFF[id]) or tonumber(n.drawable) == none[id]
            or (withJacket and id == 8) or ((withJacket or withShirt) and id == 3)
        if price > 0 and not off and (not o or tonumber(o.drawable) ~= tonumber(n.drawable) or tonumber(o.texture) ~= tonumber(n.texture)) then
            total = total + price
        end
    end
    local op, np = byId(old.props, "prop_id"), byId(new.props, "prop_id")
    for id, n in pairs(np) do
        local price = Config.ExtiPrices["p" .. id] or 0
        local o = op[id] or { drawable = -1, texture = -1 }
        local d = tonumber(n.drawable) or -1
        if price > 0 and d ~= -1 and (tonumber(o.drawable) ~= d or tonumber(o.texture) ~= tonumber(n.texture)) then
            total = total + price
        end
    end
    return total
end

local paying = {}
lib.callback.register("illenium-appearance:server:extiPayCart", function(source, method, appearance, expected)
    local src = source
    if paying[src] then return { ok = false, msg = "لحظة..." } end
    if method ~= "cash" and method ~= "bank" then method = "cash" end
    if type(appearance) ~= "table" or type(appearance.components) ~= "table" or type(appearance.props) ~= "table" then
        return { ok = false, msg = "لم يتم الدفع، حاول مرة أخرى" }
    end
    local citizenID = Framework.GetPlayerID(src)
    if not citizenID then return { ok = false, msg = "لم يتم الدفع، حاول مرة أخرى" } end
    paying[src] = true
    local charged, chargedMethod = 0, method
    local ok, res = pcall(function()
        local old = Framework.GetAppearance(citizenID) or { components = {}, props = {} }
        local total = cartTotal(old, appearance)
        local wallet = extiWallet(src)
        -- the screen prices the cart against the clothes you walked in with; the server prices it against
        -- your saved look. They only differ when you walked in wearing something that was never saved
        -- (a work uniform): never charge for pieces the screen did not show
        expected = tonumber(expected)
        if expected and total > expected then
            return { ok = false, cash = wallet.cash, bank = wallet.bank,
                msg = "تلبس زيًا غير محفوظ (زي عمل؟). البس ملابسك العادية ثم عد للمتجر" }
        end
        if total > 0 then
            if (wallet[method] or 0) < total or not Framework.RemoveMoney(src, method, total) then
                return { ok = false, cash = wallet.cash, bank = wallet.bank,
                    msg = method == "cash" and "ليس معك مال كافٍ نقدًا" or "ليس في حسابك البنكي ما يكفي" }
            end
            charged = total
            lib.notify(src, { type = "success", position = "top", title = "متجر الملابس",
                description = ("دفعت $%d %s"):format(total, method == "cash" and "نقدًا" or "بالبطاقة") })
        end
        -- save the paid clothes right away (only clothes and accessories: the face and body stay as they were)
        -- (the screen does not save clothing itself, so only what was priced here is ever kept)
        if old.model then
            old.components = appearance.components
            old.props = appearance.props
            Framework.SaveAppearance(old, citizenID)
        elseif appearance.model then
            Framework.SaveAppearance(appearance, citizenID)
        end
        return { ok = true, total = total }
    end)
    paying[src] = nil
    if ok then return res end
    print(("^1[illenium-appearance] clothing payment failed for %s: %s^0"):format(src, tostring(res)))
    if charged > 0 then -- the money was taken but the clothes were not saved: give it back
        local player = extiPlayer(src)
        if player then player.Functions.AddMoney(chargedMethod, charged, "clothing refund") end
    end
    return { ok = false, msg = "لم يتم الدفع، حاول مرة أخرى" }
end)

AddEventHandler("playerDropped", function() paying[source] = nil end)

lib.callback.register("illenium-appearance:server:extiOutfitSave", function(source, name, model, components, props)
    local citizenID = Framework.GetPlayerID(source)
    if not citizenID or type(name) ~= "string" or name == "" or not model or type(components) ~= "table" or type(props) ~= "table" then
        return { msg = "لم يُحفظ، حاول مرة أخرى" }
    end
    if outfitCache[citizenID] == nil then getOutfitsForPlayer(citizenID) end
    local list = outfitCache[citizenID]
    if #list >= 30 then return { msg = "الخزانة ممتلئة (30 زيًا). احذف زيًا أولًا" } end
    for i = 1, #list do
        if tostring(list[i].name):lower() == name:lower() then return { msg = "عندك زي بهذا الاسم" } end
    end
    local id = Database.PlayerOutfits.Add(citizenID, name, model, json.encode(components), json.encode(props))
    if not id then return { msg = "لم يُحفظ، حاول مرة أخرى" } end
    list[#list + 1] = { id = id, name = name, model = model, components = components, props = props }
    return { outfits = list }
end)

lib.callback.register("illenium-appearance:server:extiOutfitDelete", function(source, id)
    local citizenID = Framework.GetPlayerID(source)
    if not citizenID then return {} end
    if outfitCache[citizenID] == nil then getOutfitsForPlayer(citizenID) end
    local list = outfitCache[citizenID]
    for k, v in ipairs(list) do
        if v.id == id then -- only your own outfits are in your list
            Database.PlayerOutfitCodes.DeleteByOutfitID(id)
            Database.PlayerOutfits.DeleteByID(id)
            table.remove(list, k)
            break
        end
    end
    return { outfits = list }
end)

-- the wardrobe saves the outfit you put on before answering, so a payment right after reads the new look
lib.callback.register("illenium-appearance:server:extiSaveLook", function(source, appearance)
    local citizenID = Framework.GetPlayerID(source)
    if citizenID and type(appearance) == "table" and appearance.model then
        Framework.SaveAppearance(appearance, citizenID)
    end
    return true
end)
