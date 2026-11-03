-- =====================================================================
-- EX_Tii heists (game side): the laser grid in Pacific's downstairs hallway. Once the bank is being
-- robbed, red beams sweep up and down the hallway (across it, at different heights and speeds).
-- Touch one and the alarm goes. Crouch under the high ones, wait for the low ones to pass.
-- =====================================================================
local C = Config
local V = C.vaults.pacific
if not V or not V.laserArea then return end

local state = {}
AddStateBagChangeHandler('exti_heists:vaults', 'global', function(_, _, v) state = (v or {}).pacific or {} end)
state = (GlobalState['exti_heists:vaults'] or {}).pacific or {}

local A, B = V.laserArea.a, V.laserArea.b
local dir = vec3(B.x - A.x, B.y - A.y, 0.0)
local LEN = #dir
dir = dir / LEN
local side = vec3(-dir.y, dir.x, 0.0)       -- across the hallway
local HALF = 1.3                             -- half the hallway's width
-- the beams: height above the floor, speed (m/s along the hallway), phase
local BEAMS = {
    { h = 0.25, speed = 1.1, phase = 0.0 }, { h = 0.75, speed = 1.6, phase = 0.35 }, { h = 1.15, speed = 0.8, phase = 0.7 },
    { h = 1.55, speed = 1.9, phase = 0.15 }, { h = 0.45, speed = 2.3, phase = 0.55 },
}

local sent = 0
local function on()
    return state.phase == 'on' and (state.step or 0) >= 1 and not (state.doors and state.doors.vault)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if on() then
            local me = GetEntityCoords(cache.ped)
            local rel = vec3(me.x - A.x, me.y - A.y, 0.0)
            local along = rel.x * dir.x + rel.y * dir.y
            local across = rel.x * side.x + rel.y * side.y
            if along > -12.0 and along < LEN + 12.0 and math.abs(me.z - A.z) < 2.5 then
                sleep = 0
                local t = GetGameTimer() / 1000
                local crouch = GetPedStealthMovement(cache.ped) or IsPedDucking(cache.ped)
                local feet = me.z - 0.95
                local top = feet + (crouch and 1.15 or 1.75)
                for _, b in ipairs(BEAMS) do
                    -- back and forth along the hallway
                    local u = (math.sin(t * b.speed * 2 * math.pi / LEN + b.phase * 6.283) * 0.5 + 0.5) * LEN
                    local c = vec3(A.x + dir.x * u, A.y + dir.y * u, A.z - 0.95 + b.h)
                    local p1, p2 = c + side * HALF, c - side * HALF
                    DrawLine(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, 255, 20, 20, 230)
                    DrawLine(p1.x, p1.y, p1.z + 0.004, p2.x, p2.y, p2.z + 0.004, 255, 90, 90, 120)
                    -- touched? (my body is between my feet and my head, my place along the hallway near the beam)
                    if math.abs(along - u) < 0.22 and math.abs(across) < HALF and c.z > feet and c.z < top and GetGameTimer() > sent then
                        sent = GetGameTimer() + 5000
                        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
                        TriggerServerEvent('exti_heists:server:vaultLaser', 'pacific')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
