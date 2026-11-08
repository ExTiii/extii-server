-- EX_Tii: the dealership only sells what is in config/catalog.lua
local catalog = require 'config.catalog'

local shopOfCategory = {}
for i = 1, #catalog.categories do
    local category = catalog.categories[i]
    shopOfCategory[category.id] = category.shop
end

local vehicles = {}
local byModel = {}
local count = 0

for i = 1, #catalog.vehicles do
    local entry = catalog.vehicles[i]
    local shopType = shopOfCategory[entry.category]
    local price = math.tointeger(entry.price)

    if not shopType then
        lib.print.warn(('Catalog vehicle "%s" has an unknown category "%s"'):format(entry.model, tostring(entry.category)))
    elseif not price or price < 0 then
        lib.print.warn(('Catalog vehicle "%s" has a bad price'):format(entry.model))
    elseif byModel[entry.model] then
        lib.print.warn(('Catalog vehicle "%s" is listed twice, only the first one is used'):format(entry.model))
    else
        count += 1
        local item = {
            shopType = shopType,
            category = entry.category,
            model = entry.model,
            price = price,
            name = entry.name,
            brand = entry.brand,
            level = math.tointeger(entry.level) or 1,     -- EX_Tii level needed
            storage = math.tointeger(entry.storage) or 20, -- trunk kg
        }
        vehicles[count] = item
        byModel[entry.model] = item
    end
end

return {
    vehicles = vehicles,
    byModel = byModel,
    count = count,
}
