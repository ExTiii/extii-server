-- =====================================================================
-- EX_Tii Level (client): every XP gain shows in the normal notification (ox_lib) with the level bar
-- inside it. A new gain while it is still on screen updates the same notification and the bar slides
-- on from where it was. A level up shows "مستوى جديد" and what it unlocked.
-- =====================================================================

local NOTIFY_ID = 'exti_level'
local last = { at = 0, level = 0, pct = 0, cur = 0, up = false, title = nil, text = nil }

local function fmt(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5))
    return (s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
end

-- "+50 XP" written left to right inside Arabic text (otherwise it shows as "XP 50+")
local function ltr(t) return '\u{2066}' .. t .. '\u{2069}' end

local function onScreen() return GetGameTimer() - last.at < Config.cardSeconds * 1000 end

local function notify(card, title, text, fromPct, prevCur, icon, up)
    local ms = math.floor((Config.cardSeconds + (up and 2 or 0)) * 1000)
    lib.notify({
        id = NOTIFY_ID, title = title, description = text, duration = ms,
        icon = icon, iconColor = '#e8b547',
        progress = card.max and { from = 100, to = 100 } or {
            from = fromPct, to = card.pct, prev = prevCur, cur = card.cur, need = card.need,
        },
    })
    last = { at = GetGameTimer() + (up and 2000 or 0), level = card.level, pct = card.pct, cur = card.cur, up = up, title = title, text = text }
end

RegisterNetEvent('exti_level:client:gain', function(card)
    if type(card) ~= 'table' then return end
    local gained = tonumber(card.gained) or 0
    local open = onScreen() and last.level == card.level

    if card.up then
        local unlocks = {}
        for _, u in pairs(card.unlocks or {}) do unlocks[#unlocks + 1] = u end
        local text = #unlocks > 0 and ('انفتح لك: %s'):format(table.concat(unlocks, '، '))
            or (gained > 0 and ltr(('+%s XP'):format(fmt(gained))) or nil)
        notify(card, ('مستوى جديد! المستوى %d'):format(card.level), text, 0, 0, 'trophy', true)
        PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
        return
    end

    -- the bar goes on from where it is now when the notification is still open on the same level
    local fromPct = open and last.pct or (tonumber(card.fromPct) or 0)
    local prevCur = open and last.cur or math.max(0, (card.cur or 0) - gained)
    -- a level up still on screen keeps its title and text; the bar keeps moving under it
    if open and last.up then
        notify(card, last.title, last.text, fromPct, prevCur, 'trophy', true)
        return
    end
    local text = gained > 0 and ltr(('+%s XP'):format(fmt(gained))) or nil
    if card.reason and card.reason ~= '' then text = text and (text .. ' · ' .. card.reason) or card.reason end
    notify(card, ('المستوى %d'):format(card.level), text, fromPct, prevCur, 'gem', false)
end)

-- show the level (from the radial menu or /level)
local function showLevel()
    local info = lib.callback.await('exti_level:server:info', false)
    if not info then return end
    local text = info.max and 'وصلت لأعلى مستوى في المدينة'
        or info.nextUnlock and ('التالي: %s في المستوى %d'):format(info.nextUnlock.label, info.nextUnlock.level) or nil
    notify(info, ('المستوى %d'):format(info.level), text, info.pct, info.cur, 'gem', false)
end
RegisterNetEvent('exti_level:client:show', showLevel)
RegisterCommand('level', showLevel, false)

-- the radial menu (exti_radial provider): "المستوى 12" → show the level
exports('RadialMenu', function()
    local level = LocalPlayer.state.level or 1
    return {
        label = ('المستوى %d'):format(level), icon = 'gem',
        items = { { id = 'show', label = ('المستوى %d · عرض التقدم'):format(level), icon = 'gem', action = 'event', arg = { name = 'exti_level:client:show' } } },
    }
end)
