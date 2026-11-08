-- =====================================================================
-- EX_Tii gangs (game side): Turf & graffiti.
--   * the tags are drawn on the walls (each gang's tag is a spray-paint texture made by html/tag.html)
--   * use a spray can (inventory): look at a wall in a zone -> 20 s of spraying, the tag fades in
--   * use a scrub brush near a rival tag (police on duty: [E] at any tag, no brush) -> 15 s
--   * entering a zone tells gang members and police whose turf it is
--   * /turfzone (admins): walk the corners, name it
-- =====================================================================
local T = C.turf
local RES = GetCurrentResourceName()
local turf = GlobalState['exti_gangs:turf'] or { zones = {}, tags = {} }
local cleanTextures   -- (below)
AddStateBagChangeHandler('exti_gangs:turf', 'global', function(_, _, v) turf = v or { zones = {}, tags = {} }; if cleanTextures then cleanTextures() end end)

---------------------------------------------------------------------------
-- textures: one per gang tag + colour (made once, kept)
---------------------------------------------------------------------------
local TXD = 'exti_gang_tags'
local txd = CreateRuntimeTxd(TXD)
local textures = {}   -- [key] = { name, dui, ready }
local function texOf(tag, color)
    local key = (tag or 'GANG') .. (color or '')
    local t = textures[key]
    if t then return t.ready and t.name or nil end
    local name = 'tag_' .. key:gsub('[^%w]', '')
    local url = ('nui://%s/html/tag.html?t=%s&c=%s'):format(RES, tag or 'GANG', (color or '#20c997'):gsub('#', '%%23'))
    local dui = CreateDui(url, 512, 256)
    t = { name = name, dui = dui, ready = false }
    textures[key] = t
    CreateThread(function()
        local tries = 0
        while not IsDuiAvailable(dui) and tries < 100 do Wait(50); tries = tries + 1 end
        CreateRuntimeTextureFromDuiHandle(txd, name, GetDuiHandle(dui))
        Wait(800) -- let the page draw the tag
        t.ready = true
    end)
    return nil
end

AddEventHandler('onResourceStop', function(r)
    if r ~= RES then return end
    for _, t in pairs(textures) do if t.dui then DestroyDui(t.dui) end end
end)

-- a tag / colour nobody uses any more: its page goes
cleanTextures = function()
    local used = {}
    for _, t in ipairs(turf.tags or {}) do used[(t.tag or 'GANG') .. (t.color or '')] = true end
    local my = GC.my and GC.my()
    if my then used[(my.tag or 'GANG') .. (my.color or '')] = true end
    for key, t in pairs(textures) do
        if not used[key] and t.ready then DestroyDui(t.dui); textures[key] = nil end
    end
end

---------------------------------------------------------------------------
-- drawing a tag on a wall
---------------------------------------------------------------------------
local function quad(p, n, w, h)
    local right = vec3(-n.y, n.x, 0.0)
    local len = #right
    right = len > 0.001 and right / len or vec3(1.0, 0.0, 0.0)
    local up = vec3(0.0, 0.0, 1.0)
    local c = vec3(p.x, p.y, p.z) + vec3(n.x, n.y, n.z) * 0.03
    local hw, hh = right * (w / 2), up * (h / 2)
    return c - hw + hh, c + hw + hh, c + hw - hh, c - hw - hh   -- top left, top right, bottom right, bottom left
end

local function drawTag(p, n, texName, alpha)
    local tl, tr, br, bl = quad(p, n, T.tagSize[1], T.tagSize[2])
    local a = math.floor(255 * (alpha or 1.0))
    -- both windings, so it shows whichever way the wall faces
    DrawSpritePoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, br.x, br.y, br.z, 255, 255, 255, a, TXD, texName, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
    DrawSpritePoly(tl.x, tl.y, tl.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, 255, 255, 255, a, TXD, texName, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawSpritePoly(br.x, br.y, br.z, tr.x, tr.y, tr.z, tl.x, tl.y, tl.z, 255, 255, 255, a, TXD, texName, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
    DrawSpritePoly(bl.x, bl.y, bl.z, br.x, br.y, br.z, tl.x, tl.y, tl.z, 255, 255, 255, a, TXD, texName, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0)
end

local ghost = nil   -- the tag being sprayed / scrubbed: { p, n, tag, color, start, dur, fadeOut, hide }

CreateThread(function()
    while true do
        local sleep = 500
        local here = GetEntityCoords(PlayerPedId())
        for _, t in ipairs(turf.tags or {}) do
            local d = #(here - vec3(t.x, t.y, t.z))
            if d < T.drawDistance then
                local name = texOf(t.tag, t.color)
                if name then
                    sleep = 0
                    local alpha = 1.0
                    if ghost and ghost.hide == t.id then
                        alpha = math.max(0.0, 1.0 - (GetGameTimer() - ghost.start) / ghost.dur)
                    end
                    drawTag(t, { x = t.nx, y = t.ny, z = t.nz }, name, alpha)
                end
            end
        end
        if ghost and not ghost.hide then
            local name = texOf(ghost.tag, ghost.color)
            if name then
                sleep = 0
                drawTag(ghost.p, ghost.n, name, math.min(1.0, (GetGameTimer() - ghost.start) / ghost.dur))
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- spraying
---------------------------------------------------------------------------
local ERR = {
    nogang = 'لست في عصابة', wall = 'انظر مباشرة إلى جدار', far = 'اقترب من الجدار', nozone = 'هذا المكان ليس منطقة نفوذ',
    cooldown = 'انتظر قبل علامة أخرى', full = 'المنطقة فيها 5 علامات: امسح علامة لعصابة أخرى أولًا', close = 'هناك علامة قريبة جدًا',
    nocan = 'ليس معك علبة رش', gone = 'العلامة لم تعد هنا', own = 'هذه علامة عصابتك', nobrush = 'ليس معك فرشاة تنظيف',
}
local function tfail(why, extra)
    local t = ERR[why] or 'لم ينجح'
    if why == 'cooldown' and extra then t = ('%s (%d:%02d)'):format(t, extra // 60, extra % 60) end
    GC.notify(t, 'error')
end

local working = false

local function sprayFx(ped, ms)
    CreateThread(function()
        lib.requestNamedPtfxAsset('scr_playerlamgraff')
        UseParticleFxAsset('scr_playerlamgraff')
        local fx = StartParticleFxLoopedOnEntity('scr_lamgraff_paint_spray', ped, 0.12, 0.45, 0.4, 0.0, 0.0, 0.0, 1.0, false, false, false)
        local untilT = GetGameTimer() + ms
        while working and GetGameTimer() < untilT do Wait(100) end
        StopParticleFxLooped(fx, false)
    end)
end

local function useSpray()
    if working then return end
    local my = GC.my()
    if not my then return tfail('nogang') end
    -- (the ray starts at the camera, which in third person is a few metres behind you)
    local camDist = #(GetFinalRenderedCamCoord() - GetEntityCoords(PlayerPedId()))
    local hit, _, coords, normal = lib.raycast.cam(1 | 16, 4, 3.0 + camDist)
    if not hit or not coords or not normal then return tfail('wall') end
    local ok, info, extra = lib.callback.await('exti_gangs:server:tagBegin', false,
        { x = coords.x, y = coords.y, z = coords.z }, { x = normal.x, y = normal.y, z = normal.z })
    if not ok then return tfail(info, extra) end
    working = true
    local ped = PlayerPedId()
    SetEntityHeading(ped, GetHeadingFromVector_2d(-normal.x, -normal.y))
    ghost = { p = coords, n = normal, tag = my.tag, color = my.color, start = GetGameTimer(), dur = info.seconds * 1000 }
    sprayFx(ped, info.seconds * 1000)
    local done = lib.progressBar({
        duration = info.seconds * 1000, label = ('ترسم علامة العصابة · %s'):format(info.zone), canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar', flag = 1 },
        prop = { model = 'prop_cs_spray_can', bone = 28422, pos = vec3(0.0, 0.0, 0.07), rot = vec3(0.0, 0.0, 0.0) },
    })
    working = false
    ClearPedTasks(ped)
    if not done then ghost = nil; return GC.notify('أُلغيت', 'error') end
    local fin, res = lib.callback.await('exti_gangs:server:tagFinish', false, info.token, GC.witnessSaw and GC.witnessSaw() or false)
    ghost = nil
    if not fin then return tfail(res) end
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    GC.notify(res.owner and ('رسمت علامتكم · %s لكم الآن'):format(res.zone) or ('رسمت علامتكم في %s'):format(res.zone), 'success')
end
exports('useSpray', function() CreateThread(useSpray) end)

---------------------------------------------------------------------------
-- scrubbing (a rival with a brush, or the police with nothing)
---------------------------------------------------------------------------
local function nearestTag(maxD, notGang)
    local here = GetEntityCoords(PlayerPedId())
    local best, bd = nil, maxD
    for _, t in ipairs(turf.tags or {}) do
        local d = #(here - vec3(t.x, t.y, t.z))
        if d < bd and t.gang ~= notGang then best, bd = t, d end
    end
    return best
end

local function scrub(t)
    if working then return end
    local ok, info = lib.callback.await('exti_gangs:server:scrubBegin', false, t.id)
    if not ok then return tfail(info) end
    working = true
    local ped = PlayerPedId()
    SetEntityHeading(ped, GetHeadingFromVector_2d(-t.nx, -t.ny))
    ghost = { hide = t.id, start = GetGameTimer(), dur = info.seconds * 1000 }
    local done = lib.progressBar({
        duration = info.seconds * 1000, label = info.cop and 'تنظّف الجدار...' or 'تمسح علامة العصابة...', canCancel = true, position = 'bottom',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base', flag = 1 },
        prop = { model = 'prop_sponge_01', bone = 28422, pos = vec3(0.0, 0.0, -0.01), rot = vec3(90.0, 0.0, 0.0) },
    })
    working = false
    ClearPedTasks(ped)
    if not done then ghost = nil; return GC.notify('أُلغيت', 'error') end
    local fin, res = lib.callback.await('exti_gangs:server:scrubFinish', false, info.token)
    ghost = nil
    if not fin then return tfail(res) end
    GC.notify(('مُسحت العلامة · %s'):format(res.zone), 'success')
end
GC.scrubTag = scrub

exports('useBrush', function()
    CreateThread(function()
        local my = GC.my()
        local t = nearestTag(2.8, my and my.name or nil)
        if not t then return GC.notify('لا توجد علامة لعصابة أخرى قريبة منك', 'error') end
        scrub(t)
    end)
end)

-- the police: an [E] at any tag (client/main.lua asks for these points)
function GC.turfPoints()
    if not (GC.isCop and GC.isCop()) then return {} end
    local out = {}
    local here = GetEntityCoords(PlayerPedId())
    for _, t in ipairs(turf.tags or {}) do
        local p = vec3(t.x, t.y, t.z)
        if #(here - p) < 12.0 then out[#out + 1] = { kind = 'tag', tag = t, pos = p, label = '[E] نظّف العلامة (شرطة)', reach = 2.5 } end
    end
    return out
end

---------------------------------------------------------------------------
-- whose turf am I in?
---------------------------------------------------------------------------
local function insideZone(z, x, y)
    local pts, c = z.points, false
    local j = #pts
    for i = 1, #pts do
        local a, b = pts[i], pts[j]
        local dy = (b.y - a.y) ~= 0 and (b.y - a.y) or 1e-9
        if ((a.y > y) ~= (b.y > y)) and (x < (b.x - a.x) * (y - a.y) / dy + a.x) then c = not c end
        j = i
    end
    return c
end

CreateThread(function()
    local current = nil
    while true do
        Wait(1500)
        local here = GetEntityCoords(PlayerPedId())
        local now = nil
        for _, z in ipairs(turf.zones or {}) do if insideZone(z, here.x, here.y) then now = z break end end
        local key = now and (now.id .. ':' .. tostring(now.owner)) or nil
        if key ~= current then
            current = key
            if now and (GC.my() or (GC.isCop and GC.isCop())) then
                local mine = GC.my() and now.owner == GC.my().name
                lib.notify({ title = now.name, description = now.owner and (mine and 'منطقتكم' or ('منطقة %s'):format(now.ownerLabel or now.owner)) or 'منطقة بلا سيطرة',
                             type = mine and 'success' or (now.owner and 'warning' or 'inform'), position = 'top', duration = 4000 })
            end
        end
    end
end)

---------------------------------------------------------------------------
-- /turfzone (admins): walk the corners
---------------------------------------------------------------------------
local showZones = false

local function drawWalls(points, r, g, b)
    for i = 1, #points do
        local a, c = points[i], points[i % #points + 1]
        local z1, z2 = (a.z or 0) - 2.0, (a.z or 0) + 25.0
        DrawPoly(a.x, a.y, z1, c.x, c.y, z1, c.x, c.y, z2, r, g, b, 60)
        DrawPoly(c.x, c.y, z2, a.x, a.y, z2, a.x, a.y, z1, r, g, b, 60)
        DrawPoly(c.x, c.y, z2, c.x, c.y, z1, a.x, a.y, z1, r, g, b, 60)
        DrawPoly(a.x, a.y, z1, a.x, a.y, z2, c.x, c.y, z2, r, g, b, 60)
        DrawLine(a.x, a.y, a.z or 0, c.x, c.y, c.z or 0, r, g, b, 255)
    end
end

CreateThread(function()
    while true do
        if showZones then
            for _, z in ipairs(turf.zones or {}) do
                local pts = {}
                for i, p in ipairs(z.points) do pts[i] = { x = p.x, y = p.y, z = z.z } end
                drawWalls(pts, 60, 160, 255)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function drawZone(id, oldName)
    local points = {}
    local drawing = true
    lib.showTextUI('[E] نقطة هنا · [X] احذف الأخيرة · [G] احفظ · [H] إلغاء', { position = 'top-center' })
    while drawing do
        local here = GetEntityCoords(PlayerPedId())
        lib.showTextUI('[E] نقطة هنا · [X] احذف الأخيرة · [G] احفظ · [H] إلغاء', { position = 'top-center' })   -- (renewed: you walk far while drawing)
        for _, p in ipairs(points) do DrawMarker(1, p.x, p.y, p.z - 1.0, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 2.0, 229, 72, 77, 160, false, false, 2, false, nil, nil, false) end
        if #points >= 2 then
            local open = {}
            for i, p in ipairs(points) do open[i] = p end
            open[#open + 1] = { x = here.x, y = here.y, z = here.z }   -- the next corner follows you
            drawWalls(open, 229, 72, 77)
        end
        if (IsControlJustReleased(0, 38) and (LocalPlayer.state.interactSel == nil or LocalPlayer.state.interactSel == GetCurrentResourceName())) then                                  -- E
            if #points >= T.maxPoints then GC.notify(('الحد %d نقطة'):format(T.maxPoints), 'error')
            else points[#points + 1] = { x = here.x, y = here.y, z = here.z }; PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false) end
        elseif IsControlJustReleased(0, 73) and #points > 0 then              -- X
            points[#points] = nil
        elseif IsControlJustReleased(0, 47) then                              -- G
            if #points < 3 then GC.notify('تحتاج 3 نقاط على الأقل', 'error') else drawing = false end
        elseif IsControlJustReleased(0, 74) then                              -- H
            lib.hideTextUI(); return GC.notify('أُلغي الرسم', 'inform')
        end
        Wait(0)
    end
    lib.hideTextUI()
    local input = lib.inputDialog('اسم المنطقة', { { type = 'input', label = 'الاسم', default = oldName or '', required = true, min = 2, max = 40 } })
    local name = input and input[1]
    if not name then return GC.notify('أُلغي الحفظ', 'inform') end
    local ok = lib.callback.await('exti_gangs:server:zoneSave', false, name, points, id)
    GC.notify(ok and ('حُفظت المنطقة: %s'):format(name) or 'لم تُحفظ', ok and 'success' or 'error')
end

RegisterNetEvent('exti_gangs:client:turfMenu', function()
    local opts = {
        { title = 'ارسم منطقة جديدة', description = 'امشِ إلى كل زاوية واضغط E', icon = 'draw-polygon', onSelect = function() CreateThread(function() drawZone(nil) end) end },
        { title = showZones and 'أخفِ المناطق' or 'أظهر كل المناطق', icon = 'eye', onSelect = function() showZones = not showZones end },
    }
    for _, z in ipairs(turf.zones or {}) do
        opts[#opts + 1] = { title = z.name, description = z.owner and ('لـ %s'):format(z.ownerLabel or z.owner) or 'بلا سيطرة', icon = 'map-location-dot', menu = 'exti_tz_' .. z.id }
        lib.registerContext({ id = 'exti_tz_' .. z.id, title = z.name, menu = 'exti_tz_main', options = {
            { title = 'اذهب إليها', icon = 'location-arrow', onSelect = function()
                local p = z.points[1]
                SetEntityCoords(PlayerPedId(), p.x, p.y, (z.z or 30.0) + 1.0, false, false, false, false)
            end },
            { title = 'أعد رسمها', icon = 'pen', onSelect = function() CreateThread(function() drawZone(z.id, z.name) end) end },
            { title = 'احذفها (وكل علاماتها)', icon = 'trash', onSelect = function()
                if lib.alertDialog({ header = 'حذف المنطقة؟', content = z.name, centered = true, cancel = true }) ~= 'confirm' then return end
                local ok = lib.callback.await('exti_gangs:server:zoneDelete', false, z.id)
                GC.notify(ok and 'حُذفت' or 'لم تُحذف', ok and 'success' or 'error')
            end },
        } })
    end
    lib.registerContext({ id = 'exti_tz_main', title = 'مناطق النفوذ', options = opts })
    lib.showContext('exti_tz_main')
end)
