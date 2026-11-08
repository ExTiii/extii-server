-- EX_Tii (Moe): clothes that come with other clothes. In GTA every jacket (and some other pieces) carries,
-- in the game's own clothing data, the arms piece (component 3) and the undershirt (component 8) that
-- fit it — that is how GTA Online's stores swap them when you try a jacket on. Without it the arms show
-- skin through the sleeves or the wrong shirt bleeds through the jacket. Nothing here is a hand-made table:
-- it all comes from the game, so every piece of the base game and the DLCs is covered; add-on clothes
-- without that data are simply left as they are.
local found = {}   -- [model .. ':' .. nameHash] = { comp, drawable, texture } (a named piece, once looked up)

-- a forced piece given by name: find which drawable/texture of that slot carries this name
local function byName(ped, comp, nameHash)
    local key = GetEntityModel(ped) .. ':' .. nameHash
    local hit = found[key]
    if hit ~= nil then return hit or nil end
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
                piece = byName(ped, slot, nameHash)
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
