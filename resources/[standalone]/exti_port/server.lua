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
    GlobalState.extiPortBlocks = data.blocks or {}
    GlobalState.extiPortBlockRows = data.blockRows or {}
    GlobalState.extiPortBlockModel = data.blockModel
end
local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(data, { indent = true }), -1)
    publish()
end
publish()
PORT = { data = function() return data end }

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
    help = 'Port (admin): corner / gate / door / undo / list / clear yes / fence / doormodel / height / checkpoint / boothmodel / gatemodel / gatetest / edge / block / blockpoint / blocknew / blockmodel / done',
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
    elseif what == 'edge' then
        -- stand at the road edge (by the wall) on one side, level with the gate: that side's gate reaches here
        local cp = data.checkpoint
        if not cp then return say(source, 'ضع نقطة التفتيش أولًا: /port checkpoint', 'error') end
        local r = math.rad(cp.h)
        local off = (c.x - cp.x) * math.cos(r) + (c.y - cp.y) * math.sin(r)   -- + = right of the road (into the port)
        local w = math.floor(math.abs(off) * 10 + 0.5) / 10
        if w < 3.0 or w > 30.0 then return say(source, ('أنت على بعد %.1f م من وسط الطريق: قف عند حافة الطريق بجانب الجدار'):format(w), 'error') end
        if off >= 0 then cp.wr = w else cp.wl = w end
        save()
        say(source, ('حافة الطريق %s: %.1f م من الكشك'):format(off >= 0 and 'اليمنى' or 'اليسرى', w), 'success')
    elseif what == 'block' then
        -- concrete blocks: one in front of you
        data.blocks = data.blocks or {}
        if args.confirm == 'undo' then
            local last = table.remove(data.blocks)
            save()
            return say(source, last and ('حُذفت آخر كتلة (باقي %d)'):format(#data.blocks) or 'لا توجد كتل', last and 'success' or 'error')
        elseif args.confirm == 'clear' then
            data.blocks = {}
            data.blockRows = {}
            save()
            return say(source, 'حُذفت كل الكتل', 'success')
        end
        -- its long side runs the way you face (so a row is easy to line up). Next to the last block and facing
        -- the same way: it goes right on the end of it, in a straight line
        local f = GetEntityHeading(ped)
        local r = math.rad(f)
        local x, y = c.x - math.sin(r) * 1.6, c.y + math.cos(r) * 1.6
        local last = data.blocks[#data.blocks]
        local snapped = false
        if last and last.f then
            local diff = math.abs(((f - last.f) + 180.0) % 360.0 - 180.0)
            local len = Config.blocks.length
            if diff < 35.0 and #(vec2(x, y) - vec2(last.x, last.y)) < len * 2.5 then
                local lr = math.rad(last.f)
                x, y, f = last.x - math.sin(lr) * len, last.y + math.cos(lr) * len, last.f
                snapped = true
            end
        end
        data.blocks[#data.blocks + 1] = {
            x = math.floor(x * 100) / 100, y = math.floor(y * 100) / 100,
            z = mark.z, h = math.floor((f + 90.0) * 10) / 10, f = math.floor(f * 10) / 10,
        }
        save()
        say(source, ('كتلة رقم %d %s'):format(#data.blocks, snapped and 'وُضعت في نهاية السابقة' or 'وُضعت أمامك'), 'success')
    elseif what == 'blockpoint' then
        -- a wall of blocks like the fence: mark points, the blocks fill the line from one point to the next
        data.blockRows = data.blockRows or {}
        if args.confirm == 'undo' then
            local row = data.blockRows[#data.blockRows]
            if row then table.remove(row) if #row == 0 then table.remove(data.blockRows) end end
            save()
            return say(source, row and 'حُذفت آخر نقطة' or 'لا توجد نقاط', row and 'success' or 'error')
        end
        local row = data.blockRows[#data.blockRows]
        if not row or data.blockRowNew then
            row = {}
            data.blockRows[#data.blockRows + 1] = row
            data.blockRowNew = false
        end
        row[#row + 1] = { x = mark.x, y = mark.y, z = mark.z }
        save()
        say(source, #row == 1 and 'أول نقطة للصف: اذهب للنقطة التالية واكتب /port blockpoint' or ('نقطة رقم %d: الكتل امتلأت حتى هنا'):format(#row), 'success')
    elseif what == 'blocknew' then
        data.blockRowNew = true
        save()
        say(source, 'النقطة القادمة تبدأ صفًا جديدًا (لا يتصل بالسابق)', 'success')
    elseif what == 'blockmodel' then
        local m = tonumber(args.confirm)
        if not m then return say(source, 'اكتب: /port blockmodel <الرقم من /portpick وأنت تنظر إلى كتلة>', 'error') end
        data.blockModel = math.floor(m)
        save()
        say(source, 'الكتل الآن من هذا النوع', 'success')
    elseif what == 'gatetest' then
        GlobalState.extiPortGateTest = not GlobalState.extiPortGateTest
        say(source, GlobalState.extiPortGateTest and 'البوابة مغلقة للتجربة (اكتب /port gatetest مرة ثانية للرجوع)' or 'رجعت البوابة لوضعها العادي', 'success')
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
GlobalState.extiPortGateTest = false
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
