-- EX_Tii (Moe): the port fence. The marks are kept in data/port.json and shared with everyone (GlobalState).
local FILE = 'data/port.json'

local function load()
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' and type(data.marks) == 'table' then return data end
    return { marks = {} }
end
local data = load()

local function publish()
    GlobalState.extiPort = data.marks
    GlobalState.extiPortModel = data.model
    GlobalState.extiPortHeight = data.height or 1
    GlobalState.extiPortDoorModel = data.doorModel
    GlobalState.extiPortCheckpoint = data.checkpoint
    GlobalState.extiPortBoothModel = data.boothModel
    GlobalState.extiPortArmModel = data.armModel
end
local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(data, { indent = true }), -1)
    publish()
end
publish()

local function count(kind)
    local n = 0
    for _, m in ipairs(data.marks) do if m.kind == kind then n = n + 1 end end
    return n
end

local function say(src, text, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = text, type = kind or 'inform', duration = 6000 })
end

-- /port corner | gate | door | undo | list | clear yes | done
lib.addCommand('port', {
    help = 'Port (admin): corner / gate / door / undo / list / clear yes / fence / doormodel / height / checkpoint / boothmodel / gatemodel / done',
    params = { { name = 'what', type = 'string', help = 'corner, gate, door, undo, list, clear, done' },
               { name = 'confirm', help = 'a number or yes', optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    local what = tostring(args.what or ''):lower()
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    local mark = { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor((c.z - 0.98) * 100) / 100 }
    if what == 'corner' or what == 'door' then
        mark.kind = what
        data.marks[#data.marks + 1] = mark
        save()
        GlobalState.extiPortEditing = true
        say(source, what == 'corner' and ('ركن رقم %d حُفظ'):format(count('corner')) or ('باب رقم %d حُفظ'):format(count('door')), 'success')
    elseif what == 'gate' then
        for i = #data.marks, 1, -1 do if data.marks[i].kind == 'gate' then table.remove(data.marks, i) end end
        mark.kind = 'gate'
        data.marks[#data.marks + 1] = mark
        save()
        GlobalState.extiPortEditing = true
        say(source, 'البوابة حُفظت هنا', 'success')
    elseif what == 'undo' then
        local last = table.remove(data.marks)
        GlobalState.extiPortEditing = true   -- (back to marking: the fence stays open until /port done)
        save()
        say(source, last and ('حُذف آخر شيء (%s)'):format(last.kind) or 'لا شيء لحذفه')
    elseif what == 'list' then
        say(source, ('أركان: %d · بوابة: %d · أبواب: %d'):format(count('corner'), count('gate'), count('door')))
    elseif what == 'clear' then
        if args.confirm ~= 'yes' then return say(source, 'لمسح كل شيء اكتب: /port clear yes', 'error') end
        data.marks = {}
        save()
        say(source, 'مُسح كل شيء', 'success')
    elseif what == 'height' then
        local n = math.floor(tonumber(args.confirm) or 0)
        if n < 1 or n > 4 then return say(source, 'اكتب: /port height 1 أو 2 أو 3 أو 4 (عدد الصفوف فوق بعض)', 'error') end
        data.height = n
        save()
        say(source, ('السياج الآن %d صفوف فوق بعض'):format(n), 'success')
    elseif what == 'checkpoint' then
        if args.confirm == 'remove' then
            data.checkpoint = nil
            save()
            return say(source, 'حُذفت نقطة التفتيش', 'success')
        end
        data.checkpoint = { x = mark.x, y = mark.y, z = mark.z, h = math.floor(GetEntityHeading(ped) * 10) / 10 }
        save()
        say(source, 'نقطة التفتيش هنا (الكشك في وسط الطريق، الحواجز على الجانبين)', 'success')
    elseif what == 'boothmodel' or what == 'armmodel' or what == 'gatemodel' then
        local m = tonumber(args.confirm)
        if not m then return say(source, ('اكتب: /port %s <الرقم من /portpick>'):format(what), 'error') end
        if what == 'boothmodel' then data.boothModel = math.floor(m) else data.armModel = math.floor(m) end
        save()
        say(source, 'تم التغيير', 'success')
    elseif what == 'doormodel' then
        local m = tonumber(args.confirm)
        if not m then return say(source, 'اكتب: /port doormodel <الرقم من /portpick وأنت تنظر إلى بوابة صغيرة>', 'error') end
        data.doorModel = math.floor(m)
        save()
        say(source, 'الأبواب الآن من هذا النوع', 'success')
    elseif what == 'fence' then
        local m = tonumber(args.confirm)
        if not m then return say(source, 'اكتب: /port fence <الرقم الذي أعطاك إياه /portpick>', 'error') end
        data.model = math.floor(m)
        save()
        say(source, 'السياج الآن من هذا النوع', 'success')
    elseif what == 'done' then
        GlobalState.extiPortEditing = false
        say(source, 'انتهى التحديد: العلامات اختفت والسياج باقٍ', 'success')
    else
        say(source, '/port corner · gate · door · undo · list · clear yes · done', 'error')
    end
    lib.logger(source, 'port', ('port %s'):format(what))
end)

-- the checkpoint barriers: police on duty at the booth raise / lower them (everyone sees the same)
GlobalState.extiPortBarrierOpen = false
local function isCop(src)
    local p = exports.qbx_core:GetPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job
    return job and job.name == Config.checkpoint.policeJob and job.onduty == true
end
RegisterNetEvent('exti_port:server:barrier', function()
    local src = source
    local c = data.checkpoint
    if not c or not isCop(src) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(c.x, c.y, c.z)) > Config.checkpoint.reach + 3.0 then return end
    GlobalState.extiPortBarrierOpen = not GlobalState.extiPortBarrierOpen
    lib.logger(src, 'port', GlobalState.extiPortBarrierOpen and 'raised the port barrier' or 'lowered the port barrier')
end)
-- how many police are on duty (none = the barriers stay up, so the jobs still work)
CreateThread(function()
    while true do
        local n = 0
        local ok, players = pcall(function() return exports.qbx_core:GetQBPlayers() end)
        for _, p in pairs(ok and players or {}) do
            local job = p.PlayerData and p.PlayerData.job
            if job and job.name == Config.checkpoint.policeJob and job.onduty then n = n + 1 end
        end
        if GlobalState.extiPortCops ~= n then GlobalState.extiPortCops = n end
        Wait(15000)
    end
end)
