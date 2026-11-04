-- EX_Tii: admins can replay the character-screen camera moves to check them in game
--   /arrivaltest       the new-player arrival (you are moved to the new-player spawn)
--   /arrivaltest back  the "welcome back" flight down to where you stand now
lib.addCommand('arrivaltest', {
    help = 'معاينة كاميرا الوصول (للإدارة)',
    params = {
        { name = 'kind', type = 'string', help = 'back = كاميرا العودة', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('exti_characters:client:preview', source, args.kind == 'back' and 'back' or 'arrival')
end)

-- EX_Tii: a character was deleted: take it out of its gang and heist crew. Each script checks the
-- character is really gone from the database first, so this cannot remove anyone who still exists.
local deletedAsked = {}
RegisterNetEvent('exti_characters:server:deleted', function(citizenid)
    local src = source
    if type(citizenid) ~= 'string' or #citizenid > 60 then return end
    if (deletedAsked[src] or 0) > GetGameTimer() then return end
    deletedAsked[src] = GetGameTimer() + 2000
    for _, res in ipairs({ 'exti_gangs', 'exti_heists' }) do
        if GetResourceState(res) == 'started' then
            pcall(function() exports[res]:RemoveDeletedCharacter(citizenid) end)
        end
    end
end)
AddEventHandler('playerDropped', function() deletedAsked[source] = nil end)

-- EX_Tii: players can't delete their own character (one per player). Admins do it here:
--   /delcharacter <server id>      a player who is online
--   /delcharacter <citizenid>      anyone, also offline (the id is on the admin panel / database)
-- The admin is asked to confirm with the character's name first.
local pendingDelete = {}

local function cleanupDeleted(citizenid)
    SetTimeout(5000, function() -- qbx_core deletes in the background; the gang/crew scripts check it is gone
        for _, res in ipairs({ 'exti_gangs', 'exti_heists' }) do
            if GetResourceState(res) == 'started' then
                pcall(function() exports[res]:RemoveDeletedCharacter(citizenid) end)
            end
        end
    end)
end

local function tell(src, text, kind)
    if src == 0 then return print(text) end
    TriggerClientEvent('ox_lib:notify', src, { description = text, type = kind or 'inform', position = 'top' })
end

lib.addCommand('delcharacter', {
    help = 'احذف شخصية لاعب نهائيًا (للإدارة)',
    params = {
        { name = 'target', type = 'string', help = 'رقم اللاعب في السيرفر، أو الـ citizenid' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local target = tostring(args.target or '')
    local citizenid
    local sid = tonumber(target)
    if sid and #target <= 4 then
        local p = exports.qbx_core:GetPlayer(sid)
        citizenid = p and p.PlayerData.citizenid
        if not citizenid then return tell(source, 'لا يوجد لاعب داخل المدينة بهذا الرقم', 'error') end
    else
        citizenid = target
    end
    if #citizenid < 3 or #citizenid > 60 then return tell(source, 'رقم غير صحيح', 'error') end
    local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { citizenid })
    if not row then return tell(source, 'لا توجد شخصية بهذا الرقم', 'error') end
    local ok, info = pcall(json.decode, row.charinfo or '')
    info = ok and type(info) == 'table' and info or {}
    local name = ('%s %s'):format(info.firstname or '?', info.lastname or '')
    if source == 0 then -- the server console: no box to confirm in
        exports.qbx_core:DeleteCharacter(citizenid)
        cleanupDeleted(citizenid)
        return print(('[exti_characters] deleted %s (%s)'):format(name, citizenid))
    end
    pendingDelete[source] = { citizenid = citizenid, name = name, at = os.time() }
    TriggerClientEvent('exti_characters:client:confirmDelete', source, citizenid, name)
end)

RegisterNetEvent('exti_characters:server:confirmDelete', function(citizenid)
    local src = source
    local p = pendingDelete[src]
    pendingDelete[src] = nil
    if not p or p.citizenid ~= citizenid or os.time() - p.at > 120 then return end
    if not IsPlayerAceAllowed(src, 'command.delcharacter') then return end
    exports.qbx_core:DeleteCharacter(citizenid)
    cleanupDeleted(citizenid)
    tell(src, ('حُذفت شخصية %s'):format(p.name), 'success')
    lib.print.info(('%s deleted the character %s (%s)'):format(GetPlayerName(src), p.name, citizenid))
end)

AddEventHandler('playerDropped', function() pendingDelete[source] = nil end)
