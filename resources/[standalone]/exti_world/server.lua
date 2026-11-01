-- EX_Tii world rules (server side)

---------------------------------------------------------------------------
-- armed / military vehicles and GTA cop peds can't be spawned
-- (the planes, helicopters and trucks our dealers sell are NOT on this list)
---------------------------------------------------------------------------
local BLOCKED = {}
for _, name in ipairs({
    'lazer', 'hydra', 'buzzard', 'annihilator', 'savage', 'hunter', 'akula', 'rhino', 'khanjali',
    'oppressor', 'oppressor2', 'technical3', 'insurgent3', 'apc', 'tampa3', 'trailersmall2', 'halftrack',
    'vigilante', 'barrage', 'caracara', 'menacer', 'scramjet', 'strikeforce', 'cerberus', 'cerberus2',
    'cerberus3', 'scarab', 'scarab2', 'scarab3', 'rrocket', 'ruiner2', 'deluxo', 'blimp3', 'firetruk',
    's_m_y_ranger_01', 's_m_y_sheriff_01', 's_m_y_cop_01', 's_f_y_sheriff_01', 's_f_y_cop_01', 's_m_y_hwaycop_01',
}) do
    BLOCKED[joaat(name)] = true
end

-- same rule as before: only needed when routing-bucket lockdown is off (server.cfg qbx:bucketLockdownMode)
if GetConvar('qbx:bucketlockdownmode', 'relaxed') == 'inactive' then
    AddEventHandler('entityCreating', function(handle)
        if BLOCKED[GetEntityModel(handle)] then CancelEvent() end
    end)

    AddEventHandler('serverEntityCreated', function(handle)
        if DoesEntityExist(handle) and BLOCKED[GetEntityModel(handle)] then DeleteEntity(handle) end
    end)
end

---------------------------------------------------------------------------
-- cuffs and jail time are exti_police's job now (it keeps them across relogs). This only cleans
-- old flags when exti_police is not running, so nobody is stuck from before.
---------------------------------------------------------------------------
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if GetResourceState('exti_police'):find('start') or GetResourceState('xt-prison'):find('start') or GetResourceState('qbx_police'):find('start') then return end
    local meta = player and player.PlayerData and player.PlayerData.metadata
    if not meta then return end
    if (tonumber(meta.injail) or 0) > 0 then player.Functions.SetMetaData('injail', 0) end
    if meta.ishandcuffed then player.Functions.SetMetaData('ishandcuffed', false) end
end)
