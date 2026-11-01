-- EX_Tii GPS: the line settings for everyone (GlobalState 'exti_gps'), saved on the server.
-- /gpsline (admin):  /gpsline 6  = width 6   |   /gpsline gta = GTA's old line   |   /gpsline thin = thin line
--                    /gpsline reset = back to config.lua   |   /gpsline = show how it is now

local KEY = 'exti_gps'
local KVP_ON, KVP_WIDTH = 'exti_gps:on', 'exti_gps:width'

local function current()
    local on = Config.enabled
    local saved = GetResourceKvpString(KVP_ON)
    if saved == 'thin' then on = true elseif saved == 'gta' then on = false end
    local width = GetResourceKvpInt(KVP_WIDTH)
    if not width or width < Config.minWidth or width > Config.maxWidth then width = Config.width end
    return on, width
end

local function publish()
    local on, width = current()
    GlobalState:set(KEY, { on = on, width = width }, true)
    return on, width
end

publish()

local function tell(source, text, kind)
    if source and source > 0 then
        TriggerClientEvent('ox_lib:notify', source, { title = 'خط الـGPS', description = text, type = kind or 'inform' })
    else
        print(('[exti_gps] %s'):format(text))
    end
end

local function describe(on, width)
    if on then return ('الخط الرفيع، العرض %d'):format(width) end
    return 'خط اللعبة القديم'
end

lib.addCommand('gpsline', {
    help = ('خط الـGPS: رقم من %d إلى %d للعرض، gta لخط اللعبة القديم، thin للخط الرفيع، reset للإعداد الأصلي')
        :format(Config.minWidth, Config.maxWidth),
    params = {
        -- no type: ox_lib's 'string' type refuses numbers, and this one takes a number or a word
        { name = 'value', help = ('%d-%d / gta / thin / reset'):format(Config.minWidth, Config.maxWidth), optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local value = args.value and tostring(args.value):lower() or nil

    if not value then
        tell(source, describe(current()))
        return
    end

    if value == 'gta' then
        SetResourceKvp(KVP_ON, 'gta')
    elseif value == 'thin' then
        SetResourceKvp(KVP_ON, 'thin')
    elseif value == 'reset' then
        DeleteResourceKvp(KVP_ON)
        DeleteResourceKvp(KVP_WIDTH)
    elseif tonumber(value) then
        local width = math.floor(tonumber(value))
        if width < Config.minWidth or width > Config.maxWidth then
            tell(source, ('العرض من %d إلى %d'):format(Config.minWidth, Config.maxWidth), 'error')
            return
        end
        SetResourceKvpInt(KVP_WIDTH, width)
        SetResourceKvp(KVP_ON, 'thin')
    else
        tell(source, ('اكتب رقمًا من %d إلى %d، أو gta، أو thin، أو reset'):format(Config.minWidth, Config.maxWidth), 'error')
        return
    end

    local on, width = publish()
    tell(source, ('تم: %s (للجميع)'):format(describe(on, width)), 'success')
    lib.print.info(('[gpsline] %s set it to: %s'):format(source > 0 and GetPlayerName(source) or 'console', on and ('thin ' .. width) or 'gta'))
end)
