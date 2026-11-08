-- =====================================================================
-- EX_Tii gangs: /fencespots (admins): the fence's daily spots, in a menu
-- =====================================================================
local function zoneName(p)
    local z = GetNameOfZone(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    local l = z and GetLabelText(z)
    return (l and l ~= '' and l ~= 'NULL') and l or z or ''
end

local function act(what, i, label)
    local ok, msg = lib.callback.await('exti_gangs:server:fenceSpots', false, what, i, label)
    lib.notify({ description = msg or (ok and 'تم' or 'لم ينجح'), type = ok and 'success' or 'error' })
end

local function goTo(p)
    local ped = PlayerPedId()
    DoScreenFadeOut(300); Wait(300)
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false)
    if p.h then SetEntityHeading(ped, p.h + 0.0) end
    RequestCollisionAtCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 3000 do Wait(0) end
    DoScreenFadeIn(300)
end

RegisterNetEvent('exti_gangs:client:fenceSpots', function(list, todayOverride)
    local opts = {
        { title = 'أضف مكانًا حيث أقف', description = 'قف حيث يجب أن يقف المصرّف ووجهك كما تريده', icon = 'plus',
          onSelect = function()
              local input = lib.inputDialog('مكان جديد للمصرّف', { { type = 'input', label = 'اسم للمكان (اختياري)', placeholder = 'مثلًا: خلف الميناء' } })
              act('add', nil, input and input[1] or nil)
          end },
        { title = todayOverride and 'المصرّف مثبّت هنا اليوم: ألغِ' or 'ضعه حيث أقف لليوم فقط', icon = 'calendar-day',
          description = todayOverride and 'يرجع إلى مكان اليوم من القائمة' or 'لا يغيّر القائمة، ينتهي منتصف الليل',
          onSelect = function() act(todayOverride and 'today_clear' or 'today') end },
    }
    for i, p in ipairs(list) do
        local name = p.label or zoneName(p)
        opts[#opts + 1] = {
            title = ('%d) %s%s'):format(i, name, p.today and '  ← اليوم' or ''),
            description = ('%.0f, %.0f'):format(p.x, p.y),
            icon = p.today and 'location-dot' or 'map-pin',
            iconColor = p.today and '#e8b547' or nil,
            arrow = true,
            onSelect = function()
                lib.registerContext({ id = 'exti_fence_spot', title = ('%d) %s'):format(i, name), menu = 'exti_fence_spots', options = {
                    { title = 'اذهب إليه', icon = 'person-walking-arrow-right', onSelect = function() goTo(p) end },
                    { title = 'انقله إلى حيث أقف', icon = 'arrows-up-down-left-right', onSelect = function() act('move', i) end },
                    { title = 'احذفه من القائمة', icon = 'trash', iconColor = '#e05252', onSelect = function()
                        local yes = lib.alertDialog({ header = 'حذف المكان؟', content = ('%d) %s'):format(i, name), centered = true, cancel = true })
                        if yes == 'confirm' then act('remove', i) end
                    end },
                } })
                lib.showContext('exti_fence_spot')
            end,
        }
    end
    lib.registerContext({ id = 'exti_fence_spots', title = 'أماكن المصرّف اليومية', options = opts })
    lib.showContext('exti_fence_spots')
end)
