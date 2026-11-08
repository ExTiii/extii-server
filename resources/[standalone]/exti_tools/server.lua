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
