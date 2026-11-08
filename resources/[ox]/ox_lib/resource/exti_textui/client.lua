-- EX_Tii: every script's text prompt (lib.showTextUI / hideTextUI / isTextUIOpen) goes to exti_interact,
-- which shows them together (a list you pick from with the mouse wheel when there are several).
-- Without exti_interact everything works like normal ox_lib. Each script only hides its own prompt.
CreateThread(function()
    Wait(0)   -- (after ox_lib's own textui.lua is loaded)
    local origShow, origHide, origOpen = lib.showTextUI, lib.hideTextUI, lib.isTextUIOpen
    local function on() return GetResourceState('exti_interact') == 'started' end
    local function who() return GetInvokingResource() or cache.resource end

    local function show(text, options)
        if on() then
            local res = who()
            local ok = pcall(function() exports.exti_interact:Show(res, text, options) end)
            -- (a line ox_lib drew by itself while exti_interact was down must not stay behind the new one)
            if ok then origHide() return end
        end
        return origShow(text, options)
    end
    local function hide()
        -- always: ox_lib's own box too (it may hold a line shown while exti_interact was restarting)
        origHide()
        if on() then
            local res = who()
            pcall(function() exports.exti_interact:Hide(res) end)
        end
    end
    local function isOpen()
        if on() then
            local res = who()
            local ok, open, text = pcall(function() return exports.exti_interact:IsOpen(res) end)
            if ok then return open, text end
        end
        return origOpen()
    end

    rawset(lib, 'showTextUI', show)
    rawset(lib, 'hideTextUI', hide)
    rawset(lib, 'isTextUIOpen', isOpen)
    exports('showTextUI', show)
    exports('hideTextUI', hide)
    exports('isTextUIOpen', isOpen)
end)
