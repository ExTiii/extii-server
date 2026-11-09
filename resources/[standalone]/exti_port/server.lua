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
    help = 'Port fence (admin): corner / gate / door / undo / list / clear yes / fence <number> / done',
    params = { { name = 'what', type = 'string', help = 'corner, gate, door, undo, list, clear, done' },
               { name = 'confirm', type = 'string', optional = true } },
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
        save()
        say(source, last and ('حُذف آخر شيء (%s)'):format(last.kind) or 'لا شيء لحذفه')
    elseif what == 'list' then
        say(source, ('أركان: %d · بوابة: %d · أبواب: %d'):format(count('corner'), count('gate'), count('door')))
    elseif what == 'clear' then
        if args.confirm ~= 'yes' then return say(source, 'لمسح كل شيء اكتب: /port clear yes', 'error') end
        data.marks = {}
        save()
        say(source, 'مُسح كل شيء', 'success')
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
