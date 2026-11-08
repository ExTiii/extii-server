-- drop_pickup (server): ينقل الأغراض من الكيس الموجود على الأرض إلى حقيبة اللاعب مباشرة
local inv = exports.ox_inventory
local lastUse = {}
local dropBucket = {}  -- [dropId] = routing bucket of the player who dropped it (apartments, etc.)

-- نحفظ "العالم" الذي رُمي فيه الكيس حتى لا يلتقطه لاعب في شقة أو عالم آخر بنفس الإحداثيات
inv:registerHook('swapItems', function(payload)
    if payload.toInventory == 'newdrop' and payload.dropId then
        dropBucket[payload.dropId] = GetPlayerRoutingBucket(payload.source)
    end
    return true
end, { inventoryFilter = { '^newdrop$' } })

-- يتأكد أن الكيس موجود وأن اللاعب قريب منه فعلًا
local function getNearbyDrop(source, dropId)
    if type(dropId) ~= 'string' or #dropId > 64 then return nil end

    local drop = inv:GetInventory(dropId)
    if not drop or drop.type ~= 'drop' or not drop.coords then return nil end

    local ped = GetPlayerPed(source)
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return nil end
    if #(GetEntityCoords(ped) - drop.coords) > Config.MaxDistance then return nil end

    local bucket = dropBucket[dropId]
    if bucket and bucket ~= GetPlayerRoutingBucket(source) then return nil end

    return drop
end

local function itemLabel(item)
    return (item.metadata and item.metadata.label) or item.label or item.name
end

-- قائمة الأكياس الموجودة الآن (يطلبها اللاعب عند دخوله)
lib.callback.register('drop_pickup:list', function()
    local list = {}
    for _, drop in pairs(inv:GetInventories('drop', true) or {}) do
        if drop.coords then
            list[drop.id] = { coords = drop.coords }
        end
    end
    return list
end)

-- ما الذي في الكيس (لعرضه بجانب زر E)
lib.callback.register('drop_pickup:peek', function(source, dropId)
    local drop = getNearbyDrop(source, dropId)
    if not drop then return nil end

    local first, kinds = nil, 0
    for _, item in pairs(drop.items or {}) do
        kinds += 1
        if not first then first = item end
    end
    if not first then return nil end

    return { label = itemLabel(first), count = first.count, more = kinds - 1 }
end)

-- الالتقاط: كل غرض يُنقل كما هو (بنفس بياناته)، وما لا يتسع يبقى في الكيس
lib.callback.register('drop_pickup:take', function(source, dropId)
    local now = GetGameTimer()
    if lastUse[source] and now - lastUse[source] < Config.Cooldown then
        return { ok = false, error = 'busy' }
    end
    lastUse[source] = now

    local drop = getNearbyDrop(source, dropId)
    if not drop then return { ok = false, error = 'gone' } end

    local taken, left = {}, 0

    for slot, item in pairs(drop.items or {}) do
        local count = item.count or 0
        local amount = count

        if not inv:CanCarryItem(source, item.name, amount, item.metadata) then
            amount = math.min(count, math.floor(inv:CanCarryAmount(source, item.name) or 0))
            if amount > 0 and not inv:CanCarryItem(source, item.name, amount, item.metadata) then
                amount = 0
            end
        end

        if amount > 0 and inv:RemoveItem(dropId, item.name, amount, item.metadata, slot) then
            if inv:AddItem(source, item.name, amount, item.metadata) then
                taken[#taken + 1] = { label = itemLabel(item), count = amount }
            else
                -- لم يتسع: نعيده إلى الكيس كما كان
                inv:AddItem(dropId, item.name, amount, item.metadata, slot)
                amount = 0
            end
        else
            amount = 0
        end

        left += count - amount
    end

    -- إذا فرغ الكيس ولم يكن أحد يفتحه، نزيله من الأرض
    local after = inv:GetInventory(dropId)
    if after and not next(after.items or {}) and not next(after.openedBy or {}) then
        inv:RemoveInventory(dropId)
        dropBucket[dropId] = nil
    end

    return { ok = #taken > 0, taken = taken, left = left, error = #taken == 0 and 'full' or nil }
end)

AddEventHandler('playerDropped', function()
    lastUse[source] = nil
end)
