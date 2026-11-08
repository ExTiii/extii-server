-- EX_Tii tools: repair kits (see client.lua, moved here from the old mechanic job) and lockpicks.

-- lockpicks (sold at the tool shop): the car keys script does the lockpicking itself
for name, advanced in pairs({ lockpick = false, advancedlockpick = true }) do
    exports.qbx_core:CreateUseableItem(name, function(source)
        TriggerClientEvent('lockpicks:UseLockpick', source, advanced)
        TriggerEvent('lockpicks:UseLockpick', source, advanced)
    end)
end

-- EX_Tii (Moe): handing an item to someone asks them first. The receiver sees a window ("X offers you 3 water":
-- accept / refuse) and has 15 seconds; nothing moves until they accept. The giver is told if it was refused.
local function nameOf(src)
    local p = exports.qbx_core:GetPlayer(src)
    local ci = p and p.PlayerData and p.PlayerData.charinfo
    if ci and ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
    return GetPlayerName(src) or ('#' .. tostring(src))
end
CreateThread(function()
    Wait(2000)
    local ok, err = pcall(function()
        exports.ox_inventory:registerHook('swapItems', function(payload)
            if payload.action ~= 'give' or payload.toType ~= 'player' or payload.fromType ~= 'player' then return true end
            local from, to = tonumber(payload.fromInventory), tonumber(payload.toInventory)
            if not from or not to or from == to then return true end
            local slot = payload.fromSlot or {}
            local label = slot.label or slot.name or 'غرض'
            local okI, items = pcall(function() return exports.ox_inventory:Items(slot.name) end)
            if okI and type(items) == 'table' and items.label then label = items.label end
            TriggerClientEvent('ox_lib:notify', from, { description = ('عرضت %d × %s على %s… بانتظار الرد'):format(payload.count or 1, label, nameOf(to)), type = 'inform', duration = 4000 })
            local okA, accepted = pcall(lib.callback.await, 'exti_tools:give:ask', to, { from = nameOf(from), label = label, count = payload.count or 1 })
            if okA and accepted == true then return true end
            TriggerClientEvent('ox_lib:notify', from, { description = ('%s لم يقبل %s'):format(nameOf(to), label), type = 'error', duration = 5000 })
            return false
        end)
    end)
    if not ok then print('^1[exti_tools] give hook: ' .. tostring(err) .. '^0') end
end)

-- repair kits: the old mechanic job had these; while it is still on the server it keeps doing them
if GetResourceState('qbx_mechanicjob'):find('start') then return end

-- EX_Tii (Moe): anyone can use a repair kit on his own car now (kits are sold in the shops).
-- Set MECHANIC_ONLY = true to go back to on-duty mechanics only.
local MECHANIC_ONLY = false
local function mechanicOnly(source)
    if not MECHANIC_ONLY then return true end
    if GetResourceState('exti_mechanic') ~= 'started' then return true end
    local ok, allowed = pcall(function() return exports.exti_mechanic:CanUseKit(source) end)
    if ok and allowed then return true end
    TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'عُدة الإصلاح للميكانيكي فقط (في المناوبة). اطلب ميكانيكيًا أو اذهب إلى الورشة' })
    return false
end

local function useKit(source, item)
    if exports.ox_inventory:Search(source, 'count', item.name) < 1 then return end
    if not mechanicOnly(source) then return end
    local success = lib.callback.await('exti_repairkit:client:use', source, item.name)
    if success then
        exports.ox_inventory:RemoveItem(source, item.name, 1)
    end
end

exports.qbx_core:CreateUseableItem('repairkit', useKit)
exports.qbx_core:CreateUseableItem('advancedrepairkit', useKit)
