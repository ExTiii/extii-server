-- EX_Tii shops (server): everything is checked here — which shop, how close you are,
-- what that shop sells, prices, how many, licence, room in your bag and money.
-- The panel only says "this shop, these items, pay with cash/bank".

local busy = {}

local function copy(t)
    if type(t) ~= 'table' then return nil end
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

local function oxItem(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and type(item) == 'table' and item or nil
end

---@return table? store, table? kind
local function storeNear(src, index)
    if math.type(index) ~= 'integer' then return end
    local store = Config.stores[index]
    local kind = store and Config.types[store.type]
    if not kind then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local circle = Config.circleOf(store)
    if #(GetEntityCoords(ped) - circle) > Config.useDistance then return end
    return store, kind
end

local function hasLicence(player, licence)
    if not licence then return true end
    local licences = player.PlayerData.metadata and player.PlayerData.metadata.licences
    return licences and licences[licence] and true or false
end

local function imageOf(item, name)
    local image = item.client and item.client.image
    return type(image) == 'string' and image or (name .. '.png')
end

local function money(player)
    local m = player.PlayerData.money or {}
    return math.floor(tonumber(m.cash) or 0), math.floor(tonumber(m.bank) or 0)
end

--- what the panel shows
lib.callback.register('exti_shops:server:open', function(source, index)
    local store, kind = storeNear(source, index)
    if not store or not kind.products then return false end
    local player = getPlayer(source)
    if not player then return false end

    local products = {}
    for i = 1, #kind.products do
        local p = kind.products[i]
        local item = oxItem(p.name)
        if item then
            products[#products + 1] = {
                name = p.name,
                label = item.label or p.name,
                description = item.description,
                desc = p.desc, -- EX_Tii: the short "what it does" line on the card (pharmacy)
                price = p.price,
                category = p.category or 'tools',
                max = p.max or 25,
                step = p.step or 1,
                image = p.image or imageOf(item, p.name),
                licence = p.licence or p.license,
                licensed = hasLicence(player, p.licence or p.license),
            }
        end
    end

    local cash, bank = money(player)
    return {
        index = index,
        type = store.type,
        icon = kind.icon,
        label = kind.label,
        area = store.area,
        greeting = kind.greeting,
        clerkTitle = kind.clerkTitle, -- EX_Tii: e.g. الصيدلي instead of البائع
        notice = kind.notice,         -- EX_Tii: a banner over the shelf (Ammu-Nation)
        products = products,
        cash = cash,
        bank = bank,
    }
end)

-- EX_Tii: what each character bought today (for products with a daily limit), kept across restarts
DAILY = {}
do
    local function key(cid, name) return ('daily:%s:%s:%s'):format(os.date('%Y-%m-%d'), cid, name) end
    function DAILY.get(cid, name) return GetResourceKvpInt(key(cid, name)) end
    function DAILY.add(cid, name, n) SetResourceKvpInt(key(cid, name), DAILY.get(cid, name) + n) end
    -- yesterday's counts are thrown away when the resource starts
    local today = 'daily:' .. os.date('%Y-%m-%d') .. ':'
    local handle = StartFindKvp('daily:')
    if handle ~= -1 then
        local old = {}
        repeat
            local k = FindKvp(handle)
            if k and k:sub(1, #today) ~= today then old[#old + 1] = k end
        until not k
        EndFindKvp(handle)
        for _, k in ipairs(old) do DeleteResourceKvp(k) end
    end
end

---@param cart { name: string, count: integer }[]
---@return table? lines, string? errorCode
local function readCart(kind, cart, player)
    if type(cart) ~= 'table' then return nil, 'failed' end
    local byName = {}
    for i = 1, #kind.products do byName[kind.products[i].name] = kind.products[i] end

    local lines, seen = {}, {}
    for i = 1, math.min(#cart, 20) do
        local entry = cart[i]
        local name = type(entry) == 'table' and entry.name
        local count = type(entry) == 'table' and entry.count
        local product = type(name) == 'string' and byName[name]
        if not product or seen[name] then return nil, 'failed' end
        if math.type(count) ~= 'integer' or count < 1 or count > (product.max or 25) then return nil, 'failed' end
        if not hasLicence(player, product.licence or product.license) then return nil, 'no_license' end
        -- EX_Tii: a daily limit per character (ammo)
        if product.daily and (DAILY.get(player.PlayerData.citizenid, name) + count) > product.daily then return nil, 'daily_limit' end
        local item = oxItem(name)
        if not item then return nil, 'failed' end
        seen[name] = true
        lines[#lines + 1] = { product = product, item = item, count = count, cost = product.price * count }
    end
    if #lines == 0 then return nil, 'empty' end
    return lines
end

---@return boolean ok, string? errorCode, table? result
lib.callback.register('exti_shops:server:buy', function(source, index, cart, account)
    local src = source
    if busy[src] then return false, 'busy' end
    if account ~= 'cash' and account ~= 'bank' then return false, 'failed' end

    local store, kind = storeNear(src, index)
    if not store then return false, 'too_far' end
    if not kind.products then return false, 'failed' end
    local player = getPlayer(src)
    if not player then return false, 'failed' end

    local lines, err = readCart(kind, cart, player)
    if not lines then return false, err end

    local total, weight = 0, 0
    for i = 1, #lines do
        local l = lines[i]
        total = total + l.cost
        -- (a product can give its real weight: a full jerry can weighs more than the empty item)
        weight = weight + (tonumber(l.product.weight) or tonumber(l.item.weight) or 0) * l.count
    end
    if total <= 0 then return false, 'failed' end

    -- room in the bag (all items together, then each item for free slots)
    local okWeight, canWeight = pcall(function() return exports.ox_inventory:CanCarryWeight(src, weight) end)
    if okWeight and canWeight == false then return false, 'cant_carry' end
    for i = 1, #lines do
        local l = lines[i]
        local okCarry, canCarry = pcall(function()
            return exports.ox_inventory:CanCarryItem(src, l.product.name, l.count, l.product.metadata)
        end)
        if not okCarry or not canCarry then return false, 'cant_carry' end
    end

    local cash, bank = money(player)
    if (account == 'cash' and cash or bank) < total then return false, 'no_money' end

    busy[src] = true
    local ok, result = pcall(function()
        if not player.Functions.RemoveMoney(account, total, ('shop-%s'):format(store.type)) then
            return { code = 'no_money' }
        end

        local refund, bought = 0, {}
        for i = 1, #lines do
            local l = lines[i]
            local given = 0
            if l.item.weapon then
                -- weapons one by one so each gets its own serial number
                for _ = 1, l.count do
                    local metadata = copy(l.product.metadata)
                    if exports.ox_inventory:AddItem(src, l.product.name, 1, metadata) then given = given + 1 end
                end
            else
                local metadata = copy(l.product.metadata)
                if exports.ox_inventory:AddItem(src, l.product.name, l.count, metadata) then given = l.count end
            end
            if given < l.count then refund = refund + (l.count - given) * l.product.price end
            if given > 0 and l.product.daily then DAILY.add(player.PlayerData.citizenid, l.product.name, given) end
            if given > 0 then bought[#bought + 1] = ('%dx %s'):format(given, l.product.name) end
        end

        if refund > 0 then player.Functions.AddMoney(account, refund, 'shop-refund') end
        if #bought == 0 then return { code = 'cant_carry' } end

        lib.print.info(('%s (%s) bought %s at %s %s for $%d (%s)'):format(GetPlayerName(src),
            player.PlayerData.citizenid, table.concat(bought, ', '), store.type, index, total - refund, account))
        return { code = refund > 0 and 'partial' or nil, paid = total - refund }
    end)
    busy[src] = nil

    if not ok then
        lib.print.error(('[exti_shops] buy failed for %s: %s'):format(src, tostring(result)))
        return false, 'failed'
    end
    if result.paid == nil then return false, result.code or 'failed' end

    player = getPlayer(src) or player
    local newCash, newBank = money(player)
    return true, result.code, { paid = result.paid, cash = newCash, bank = newBank }
end)

--- is this player standing at a shop of this type? (used by exti_bank for the bank tellers)
---@return string|boolean? area
exports('NearStore', function(src, storeType, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local p = GetEntityCoords(ped)
    for i = 1, #Config.stores do
        local store = Config.stores[i]
        if store.type == storeType and #(p - Config.circleOf(store)) <= (maxDist or Config.useDistance) then
            return store.area or true
        end
    end
    return nil
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)

--- Stores() -> stores, types : the places and their kinds (the police CCTV builds its camera list from them)
exports('Stores', function()
    return Config.stores, Config.types
end)

---------------------------------------------------------------------------
-- the Ammu-Nation notice on the wall: admins can move it with /ammusign (kept across restarts)
---------------------------------------------------------------------------
do
    local signs = json.decode(GetResourceKvpString('ammu_signs') or '{}') or {}
    GlobalState['exti_shops:signs'] = signs

    lib.addCommand('ammusign', {
        help = 'Put the Ammu-Nation notice on the wall you look at (reset = automatic place)',
        params = { { name = 'reset', type = 'string', optional = true } },
        restricted = 'group.admin',
    }, function(source, args)
        TriggerClientEvent('exti_shops:client:placeSign', source, args.reset == 'reset')
    end)

    RegisterNetEvent('exti_shops:server:placeSign', function(spot)
        local src = source
        if not IsPlayerAceAllowed(src, 'group.admin') and not IsPlayerAceAllowed(src, 'command.ammusign') then return end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        local here = GetEntityCoords(ped)
        local best, bestD
        for i, s in ipairs(Config.stores) do
            if s.type == 'ammunation' then
                local d = #(here - vec3(s.clerk.x, s.clerk.y, s.clerk.z))
                if d < 25.0 and (not bestD or d < bestD) then best, bestD = i, d end
            end
        end
        local function tell(t, kind) TriggerClientEvent('ox_lib:notify', src, { description = t, type = kind }) end
        if not best then return tell('أنت لست داخل محل Ammu-Nation', 'error') end
        if spot == false then
            signs[tostring(best)] = nil
            tell('رجعت اللافتة إلى مكانها التلقائي', 'success')
        else
            if type(spot) ~= 'table' then return end
            local x, y, z, nx, ny = tonumber(spot.x), tonumber(spot.y), tonumber(spot.z), tonumber(spot.nx), tonumber(spot.ny)
            if not (x and y and z and nx and ny) or #(vec3(x, y, z) - here) > 10.0 then return tell('الجدار بعيد جدًا', 'error') end
            local len = math.sqrt(nx * nx + ny * ny)
            if len < 0.1 then return end
            signs[tostring(best)] = { x = x, y = y, z = z, nx = nx / len, ny = ny / len }
            tell('وُضعت اللافتة هنا', 'success')
        end
        SetResourceKvp('ammu_signs', json.encode(signs))
        GlobalState['exti_shops:signs'] = signs
    end)
end
