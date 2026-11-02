-- =====================================================================
-- EX_Tii shops (game side): the notice on the wall behind every Ammu-Nation clerk
-- ("we don't sell guns or ammo any more"). The page html/sign.html is drawn on the wall.
-- Where it goes: found by itself (the wall behind the clerk), or put by an admin with /ammusign.
-- =====================================================================
local RES = GetCurrentResourceName()
local TXD, TEX = 'exti_shop_sign', 'ammu_notice'
local W, H = 1.0, 0.75            -- metres (the page is 512 x 384)
local DRAW = 18.0                 -- shows from this close

local placed = GlobalState['exti_shops:signs'] or {}
AddStateBagChangeHandler('exti_shops:signs', 'global', function(_, _, v) placed = v or {} end)

local ready, dui = false, nil
local function texture()
    if ready then return true end
    if dui then return false end
    local txd = CreateRuntimeTxd(TXD)
    dui = CreateDui(('nui://%s/html/sign.html'):format(RES), 512, 384)
    CreateThread(function()
        local tries = 0
        while not IsDuiAvailable(dui) and tries < 100 do Wait(50); tries = tries + 1 end
        CreateRuntimeTextureFromDuiHandle(txd, TEX, GetDuiHandle(dui))
        Wait(800)   -- let the page draw
        ready = true
    end)
    return false
end
AddEventHandler('onResourceStop', function(r) if r == RES and dui then DestroyDui(dui) end end)

local function quad(p, n)
    local right = vec3(-n.y, n.x, 0.0)
    local len = #right
    right = len > 0.001 and right / len or vec3(1.0, 0.0, 0.0)
    local c = p + n * 0.02
    local hw, hh = right * (W / 2), vec3(0.0, 0.0, H / 2)
    return c - hw + hh, c + hw + hh, c + hw - hh, c - hw - hh
end

-- both windings (the same corners as the gang tags), so it shows whichever way the wall was hit
local function draw(p, n)
    local tl, tr, br, bl = quad(p, n)
    DrawSpritePoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, br.x, br.y, br.z, 255, 255, 255, 255, TXD, TEX, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
    DrawSpritePoly(tl.x, tl.y, tl.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, 255, 255, 255, 255, TXD, TEX, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawSpritePoly(br.x, br.y, br.z, tr.x, tr.y, tr.z, tl.x, tl.y, tl.z, 255, 255, 255, 255, TXD, TEX, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
    DrawSpritePoly(bl.x, bl.y, bl.z, br.x, br.y, br.z, tl.x, tl.y, tl.z, 255, 255, 255, 255, TXD, TEX, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0)
end

-- the shops that get the notice
local stores = {}
for i, s in ipairs(Config.stores) do
    if s.type == 'ammunation' then stores[#stores + 1] = { index = i, clerk = s.clerk } end
end

-- no admin spot yet: the wall behind the clerk (looked for once, from the clerk's chest backwards)
local function autoSpot(st)
    if st.auto ~= nil then return st.auto end
    local c = st.clerk
    local h = math.rad(c.w)
    local fwd = vec3(-math.sin(h), math.cos(h), 0.0)
    local from = vec3(c.x, c.y, c.z + 0.55)
    local to = from - fwd * 4.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, pos, normal = GetShapeTestResult(ray)
    if hit == 1 and #(pos - from) > 0.4 and math.abs(normal.z) < 0.4 then
        st.auto = { p = vec3(pos.x, pos.y, from.z + 0.25), n = vec3(normal.x, normal.y, 0.0) }
    else
        st.auto = { p = from - fwd * 1.2 + vec3(0.0, 0.0, 0.25), n = fwd }
    end
    return st.auto
end

local function spotOf(st)
    local s = placed[tostring(st.index)]
    if s then return { p = vec3(s.x, s.y, s.z), n = vec3(s.nx, s.ny, 0.0) } end
    return autoSpot(st)
end

CreateThread(function()
    while true do
        local sleep = 1000
        local here = GetEntityCoords(PlayerPedId())
        for _, st in ipairs(stores) do
            local c = st.clerk
            if #(here - vec3(c.x, c.y, c.z)) < DRAW then
                sleep = 0
                if texture() then
                    local s = spotOf(st)
                    draw(s.p, s.n)
                end
            end
        end
        Wait(sleep)
    end
end)

-- admins: look at the wall where the notice should go, /ammusign (or "/ammusign reset" for the automatic place)
RegisterNetEvent('exti_shops:client:placeSign', function(reset)
    if reset then return TriggerServerEvent('exti_shops:server:placeSign', false) end
    local hit, _, coords, normal = lib.raycast.cam(1 | 16, 4, 8.0)
    if not hit or math.abs(normal.z) > 0.4 then
        return lib.notify({ description = 'انظر مباشرة إلى جدار داخل محل Ammu-Nation', type = 'error' })
    end
    TriggerServerEvent('exti_shops:server:placeSign', { x = coords.x, y = coords.y, z = coords.z, nx = normal.x, ny = normal.y })
end)
