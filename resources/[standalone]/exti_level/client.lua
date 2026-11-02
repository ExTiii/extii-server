-- =====================================================================
-- EX_Tii Level (client): the XP card at the top of the screen after every gain (the level bar
-- filling up), a big "level up" with what it unlocked, and the level in the radial menu.
-- =====================================================================

RegisterNetEvent('exti_level:client:gain', function(card)
    if type(card) ~= 'table' then return end
    card.seconds = Config.cardSeconds
    SendNUIMessage({ action = 'gain', card = card })
    if card.up then PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true) end
end)

-- show the level card (from the radial menu or /level)
local function showLevel()
    local info = lib.callback.await('exti_level:server:info', false)
    if not info then return end
    SendNUIMessage({ action = 'show', card = {
        level = info.level, cur = info.cur, need = info.need, pct = info.pct, max = info.max, fromPct = info.pct,
        next = info.nextUnlock, seconds = Config.cardSeconds + 3,
    } })
end
RegisterNetEvent('exti_level:client:show', showLevel)
RegisterCommand('level', showLevel, false)

-- the radial menu (exti_radial provider): "المستوى 12" → show the card
exports('RadialMenu', function()
    local level = LocalPlayer.state.level or 1
    return {
        label = ('المستوى %d'):format(level), icon = 'gem',
        items = { { id = 'show', label = ('المستوى %d · عرض التقدم'):format(level), icon = 'gem', action = 'event', arg = { name = 'exti_level:client:show' } } },
    }
end)
