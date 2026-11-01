-- EX_Tii tools: repair kits (see client.lua, moved here from the old mechanic job) and lockpicks.

-- lockpicks (sold at the tool shop): the car keys script does the lockpicking itself
for name, advanced in pairs({ lockpick = false, advancedlockpick = true }) do
    exports.qbx_core:CreateUseableItem(name, function(source)
        TriggerClientEvent('lockpicks:UseLockpick', source, advanced)
        TriggerEvent('lockpicks:UseLockpick', source, advanced)
    end)
end

-- repair kits: the old mechanic job had these; while it is still on the server it keeps doing them
if GetResourceState('qbx_mechanicjob'):find('start') then return end

local function useKit(source, item)
    if exports.ox_inventory:Search(source, 'count', item.name) < 1 then return end
    local success = lib.callback.await('exti_repairkit:client:use', source, item.name)
    if success then
        exports.ox_inventory:RemoveItem(source, item.name, 1)
    end
end

exports.qbx_core:CreateUseableItem('repairkit', useKit)
exports.qbx_core:CreateUseableItem('advancedrepairkit', useKit)
