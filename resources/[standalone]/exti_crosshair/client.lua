-- =====================================================================
-- EX_Tii crosshair: while you hold a gun, GTA's big crosshair is hidden and a small white dot sits
-- in the middle of the screen (NoPixel style). Melee weapons, the flashlight, throwables and an
-- empty hand show nothing. Sniper scopes keep their own view.
-- =====================================================================

local Config = {
    size = 3.0,              -- the dot in pixels (on a 1080p screen)
    color = { 255, 255, 255 }, -- white
    alpha = 235,
    outline = true,          -- a thin dark ring so the dot shows on bright walls
    onlyWhenAiming = false,  -- true = the dot only appears while aiming (right mouse)
}

-- the weapon groups that are guns (pistol, SMG, rifle, MG, shotgun, sniper, heavy, stun gun)
local GUN_GROUPS = {
    [`GROUP_PISTOL`] = true, [`GROUP_SMG`] = true, [`GROUP_RIFLE`] = true, [`GROUP_MG`] = true,
    [`GROUP_SHOTGUN`] = true, [`GROUP_SNIPER`] = true, [`GROUP_HEAVY`] = true, [`GROUP_STUNGUN`] = true,
}

local function holdingGun(ped)
    local ok, weapon = GetCurrentPedWeapon(ped, true)
    if not ok or weapon == `WEAPON_UNARMED` then return false end
    return GUN_GROUPS[GetWeapontypeGroup(weapon)] == true
end

local function drawDot()
    local sw, sh = GetActiveScreenResolution()
    local w = Config.size / sw * (sh / 1080)
    local h = Config.size / sh * (sh / 1080)
    if Config.outline then
        DrawRect(0.5, 0.5, w + 2.0 / sw, h + 2.0 / sh, 0, 0, 0, 150)
    end
    DrawRect(0.5, 0.5, w, h, Config.color[1], Config.color[2], Config.color[3], Config.alpha)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if holdingGun(ped) then
            -- every frame while a gun is out
            while holdingGun(ped) do
                HideHudComponentThisFrame(14) -- GTA's reticle
                local aiming = IsPlayerFreeAiming(PlayerId()) or IsControlPressed(0, 25)
                local scoped = IsFirstPersonAimCamActive() and GetWeapontypeGroup(select(2, GetCurrentPedWeapon(ped, true))) == `GROUP_SNIPER`
                if not scoped and (not Config.onlyWhenAiming or aiming) and not IsPauseMenuActive() then
                    drawDot()
                end
                Wait(0)
                ped = PlayerPedId()
            end
        end
        Wait(250)
    end
end)
