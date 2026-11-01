-- EX_Tii clock (client): the in-game time in a small gold clock, top-left, always on while you play.
-- The time comes from the game clock that Renewed-Weathersync keeps in sync for everyone
-- (the same clock the phone, the radio and the police cameras show).

local shown
local last = {}

-- only in the city: not before the character is loaded, not on the character screens, not in the pause menu
local function allowed()
    local state = LocalPlayer.state
    return state.isLoggedIn and not state.characterScreen and not IsPauseMenuActive()
        and not IsPlayerSwitchInProgress() and not IsScreenFadedOut()
end

local function weatherName()
    local w = GlobalState.weather
    return type(w) == 'table' and w.weather or nil
end

CreateThread(function()
    while true do
        local show = allowed() and true or false
        if show ~= shown then
            shown = show
            SendNUIMessage({ action = 'show', value = show })
        end
        if show then
            local hour, minute = GetClockHours(), GetClockMinutes()
            local weather = weatherName()
            if hour ~= last.hour or minute ~= last.minute or weather ~= last.weather then
                last.hour, last.minute, last.weather = hour, minute, weather
                SendNUIMessage({ action = 'time', hour = hour, minute = minute, weather = weather })
            end
        end
        Wait(500)
    end
end)
