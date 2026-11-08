-- EX_Tii (Moe): clothes that come with other clothes. In GTA every jacket (and some other pieces) carries,
-- in the game's own clothing data, the arms piece (component 3) and the undershirt (component 8) that
-- fit it — that is how GTA Online's stores swap them when you try a jacket on. Without it the arms show
-- skin through the sleeves or the wrong shirt bleeds through the jacket. Nothing here is a hand-made table:
-- it all comes from the game, so every piece of the base game and the DLCs is covered; add-on clothes
-- without that data are simply left as they are.
local found = {}   -- [model .. ':' .. nameHash] = { comp, drawable, texture } (a named piece, once looked up)

-- the game's shop record of a named piece (what GTA Online's stores read): which slot, drawable and
-- texture it is. The record is nine 8-byte-aligned ints written into a buffer; nil when it isn't for this slot
-- (the buffer must be a string.blob: natives write into those, not into ordinary strings)
local function readRecord(nameHash, plain)
    local buf = (plain or not string.blob) and string.rep('\0', 8 * 25) or string.blob(8 * 25)
    local ok = pcall(Citizen.InvokeNative, 0x74C0E2A57EC66760, nameHash, buf)   -- GET_SHOP_PED_COMPONENT
    if not ok then return nil end
    local v = {}
    for k = 0, 8 do v[#v + 1] = string.unpack('<i4', buf, k * 8 + 1) end
    return v   -- lockHash, nameHash, locate, drawable, texture, cost, compType, shopEnum, character
end
local function shopRecord(nameHash, slot)
    local v = readRecord(nameHash)
    if not v then return nil end
    local drawable, texture, compType = v[4], v[5], v[7]
    if compType ~= slot or drawable < 0 or drawable > 1000 or texture < 0 or texture > 64 then return nil end
    return { comp = slot, drawable = drawable, texture = texture }
end

-- the DLC pack (collection) whose name hashes to this: forced pieces are "piece N of pack X"
local packs = {}   -- [model .. ':' .. hash] = pack name | false
local function packByHash(ped, hash)
    local key = GetEntityModel(ped) .. ':' .. hash
    local hit = packs[key]
    if hit ~= nil then return hit or nil end
    local okN, n = pcall(GetPedCollectionsCount, ped)
    for i = 0, (okN and n or 0) - 1 do
        local okName, name = pcall(GetPedCollectionName, ped, i)
        if okName and name and name ~= '' and GetHashKey(name) == hash then
            packs[key] = name
            return name
        end
    end
    packs[key] = false
    return nil
end

-- how many pieces of a slot the base game has (the packs' pieces come after them)
local baseCounts = {}
local function baseCount(ped, comp)
    local key = GetEntityModel(ped) .. ':' .. comp
    if baseCounts[key] then return baseCounts[key] end
    local total = GetNumberOfPedDrawableVariations(ped, comp)
    local first = total
    local okN, n = pcall(GetPedCollectionsCount, ped)
    for i = 0, (okN and n or 0) - 1 do
        local okName, name = pcall(GetPedCollectionName, ped, i)
        if okName and name and name ~= '' then
            local okG, g = pcall(GetPedDrawableGlobalIndexFromCollection, ped, comp, name, 0)
            if okG and type(g) == 'number' and g >= 0 and g < first then first = g end
        end
    end
    baseCounts[key] = first
    return first
end

---a forced piece given as pack + local number: the global drawable of that slot. The pack is the one whose
---name hashes to packHash, else (the usual case) the pack the piece on top comes from
local function fromPack(ped, comp, packHash, localIndex, ownerComp)
    local pack = packByHash(ped, packHash)
    if not pack and ownerComp then
        local ok, name = pcall(GetPedDrawableVariationCollectionName, ped, ownerComp)
        if ok and name and name ~= '' then pack = name end
    end
    if not pack then return nil end
    local okC, count = pcall(GetNumberOfPedCollectionDrawableVariations, ped, comp, pack)
    if not okC or type(count) ~= 'number' or localIndex < 0 or localIndex >= count then return nil end
    local ok, global = pcall(GetPedDrawableGlobalIndexFromCollection, ped, comp, pack, localIndex)
    if not ok or type(global) ~= 'number' or global < 0 or global >= GetNumberOfPedDrawableVariations(ped, comp) then return nil end
    return { comp = comp, drawable = global, texture = 0, pack = pack }
end

-- a forced piece given by name: its shop record first, else which drawable/texture of that slot carries this name
local function byName(ped, comp, nameHash)
    local key = GetEntityModel(ped) .. ':' .. nameHash
    local hit = found[key]
    if hit ~= nil then return hit or nil end
    local rec = shopRecord(nameHash, comp)
    if rec and rec.drawable < GetNumberOfPedDrawableVariations(ped, comp) then
        found[key] = rec
        return rec
    end
    for d = 0, GetNumberOfPedDrawableVariations(ped, comp) - 1 do
        for t = 0, math.max(GetNumberOfPedTextureVariations(ped, comp, d), 1) - 1 do
            if GetHashNameForComponent(ped, comp, d, t) == nameHash then
                found[key] = { comp = comp, drawable = d, texture = t }
                return found[key]
            end
        end
    end
    found[key] = false
    return nil
end

---what the game says must change along with this piece
---@param ped number
---@param comp number component id (11 = jacket)
---@param drawable number
---@param texture number
---@return table[] list of { component_id, drawable, texture } (may be empty)
local function linkedComponents(ped, comp, drawable, texture)
    local out = {}
    local ok, hash = pcall(GetHashNameForComponent, ped, comp, drawable, texture or 0)
    if not ok or not hash or hash == 0 then return out end
    local n = GetShopPedApparelForcedComponentCount(hash)
    if not n or n <= 0 then return out end
    for i = 0, n - 1 do
        local nameHash, enumValue, slot = GetForcedComponent(hash, i)
        slot = tonumber(slot)
        if slot and slot ~= comp and slot >= 0 and slot <= 11 then
            local piece
            if nameHash == 0 or nameHash == nil then
                piece = { comp = slot, drawable = tonumber(enumValue) or 0, texture = 0 }
            else
                -- a shop item by name; else piece N of a pack (its own pack, or the one the top comes from);
                -- else (a pack with no pieces of that slot, e.g. mp_m_luxe_01) piece N of the base game
                local n = tonumber(enumValue) or 0
                piece = byName(ped, slot, nameHash) or fromPack(ped, slot, nameHash, n, comp)
                    or (n >= 0 and n < baseCount(ped, slot) and { comp = slot, drawable = n, texture = 0, pack = 'base' } or nil)
            end
            if piece and piece.drawable >= 0 and piece.drawable < GetNumberOfPedDrawableVariations(ped, slot) then
                out[#out + 1] = { component_id = slot, drawable = piece.drawable, texture = piece.texture or 0 }
            end
        end
    end
    return out
end
client.linkedComponents = linkedComponents

---set a piece and whatever the game links to it; returns the linked pieces that were applied
local function applyLinked(ped, comp, drawable, texture)
    local list = linkedComponents(ped, comp, drawable, texture)
    for _, c in ipairs(list) do
        SetPedComponentVariation(ped, c.component_id, c.drawable, c.texture, 0)
    end
    return list
end
client.applyLinked = applyLinked

-- the "nothing on" jacket of each body (same table as the screen's NONE_OF)
local NO_JACKET = { [`mp_m_freemode_01`] = 15, [`mp_f_freemode_01`] = 15 }
local function jacketOff(ped)
    local none = NO_JACKET[GetEntityModel(ped)]
    return none ~= nil and GetPedDrawableVariation(ped, 11) == none
end
client.jacketOff = jacketOff

---after a jacket or undershirt change: the arms (and undershirt) the game links to what is on top.
---With a jacket on, the jacket decides; with no jacket, the undershirt decides (its own sleeves).
---@return table[] the linked pieces applied
local function applyLinkedTop(ped, comp, drawable, texture)
    if comp == 11 then
        local list = applyLinked(ped, 11, drawable, texture)
        if jacketOff(ped) then
            local more = applyLinked(ped, 8, GetPedDrawableVariation(ped, 8), GetPedTextureVariation(ped, 8))
            for _, c in ipairs(more) do list[#list + 1] = c end
        end
        return list
    elseif comp == 8 and jacketOff(ped) then
        return applyLinked(ped, 8, drawable, texture)
    end
    return {}
end
client.applyLinkedTop = applyLinkedTop

-- /extilinked: what the game says about the jacket and undershirt you have on (F8 console; for fixing fits)
RegisterCommand('extilinked', function()
    local ped = PlayerPedId()
    for _, comp in ipairs({ 11, 8 }) do
        local d, t = GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp)
        local hash = GetHashNameForComponent(ped, comp, d, t)
        local n = hash ~= 0 and GetShopPedApparelForcedComponentCount(hash) or 0
        print(('[extilinked] comp %d: drawable %d texture %d hash %s forced %d'):format(comp, d, t, tostring(hash), n))
        if hash ~= 0 then
            local a, b = readRecord(hash), readRecord(hash, true)
            print(('[extilinked]   its own record (blob) [%s]  (plain) [%s]'):format(a and table.concat(a, ' ') or '-', b and table.concat(b, ' ') or '-'))
        end
        for i = 0, (n or 0) - 1 do
            local nameHash, enumValue, slot = GetForcedComponent(hash, i)
            local piece
            if nameHash ~= 0 and nameHash ~= nil then
                local sl, n = tonumber(slot) or 0, tonumber(enumValue) or 0
                piece = byName(ped, sl, nameHash) or fromPack(ped, sl, nameHash, n, comp)
                    or (n >= 0 and n < baseCount(ped, sl) and { comp = sl, drawable = n, texture = 0, pack = 'base' } or nil)
            end
            local rec = (nameHash ~= 0 and nameHash ~= nil) and readRecord(nameHash)
            local raw = rec and (' record[' .. table.concat(rec, ' ') .. ']') or ''
            print(('[extilinked]   forced %d: nameHash %s enumValue %s slot %s -> %s%s'):format(i, tostring(nameHash),
                tostring(enumValue), tostring(slot), piece and ('drawable %d texture %d%s'):format(piece.drawable, piece.texture,
                piece.pack and (' (pack ' .. piece.pack .. ')') or '') or (nameHash == 0 and 'by value' or 'NOT FOUND'), raw))
        end
    end
    do
        local okN, n = pcall(GetPedCollectionsCount, ped)
        local okP, jp = pcall(GetPedDrawableVariationCollectionName, ped, 11)
        local okL, jl = pcall(GetPedDrawableVariationCollectionLocalIndex, ped, 11)
        print(('[extilinked] packs on this body: %s · the jacket is from pack: %s (local #%s)'):format(okN and tostring(n) or 'n/a', okP and tostring(jp) or 'n/a', okL and tostring(jl) or 'n/a'))
        local parts = {}
        for i = 0, (okN and n or 0) - 1 do
            local okName, name = pcall(GetPedCollectionName, ped, i)
            if okName and name and name ~= '' then
                local okC, c = pcall(GetNumberOfPedCollectionDrawableVariations, ped, 3, name)
                local okG, g = pcall(GetPedDrawableGlobalIndexFromCollection, ped, 3, name, 0)
                parts[#parts + 1] = ('%s=%s arms:%s from:%s'):format(name, tostring(GetHashKey(name)), okC and tostring(c) or '?', okG and tostring(g) or '?')
            end
        end
        for i = 1, #parts, 4 do print('[extilinked]   packs: ' .. table.concat(parts, ' | ', i, math.min(i + 3, #parts))) end
    end
    print(('[extilinked] arms now: drawable %d texture %d · undershirt: drawable %d texture %d'):format(
        GetPedDrawableVariation(ped, 3), GetPedTextureVariation(ped, 3), GetPedDrawableVariation(ped, 8), GetPedTextureVariation(ped, 8)))
    lib.notify({ description = 'كُتبت التفاصيل في نافذة F8', type = 'inform' })
end, false)
