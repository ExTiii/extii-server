-- =====================================================================
-- EX_Tii radial menu (the Z wheel), in the style of the "NoPixel V" wheel: everything a player
-- does often, one tap away. Replaces qbx_radialmenu.
--
-- Each item: id, label (Arabic), icon (a name from html/icons.js), and either
--   items = { ... }           a submenu
--   action = 'name', arg = x  something the client does (client/actions.lua)
-- Items with  when = 'vehicle'  only show when you are in or next to a car.
-- The Vehicle, Map and Work menus are built in code (they change with the car / your job).
-- =====================================================================

Config = {}

Config.key = 'Z'              -- players can change it in GTA settings > key bindings > FiveM
Config.vehicleReach = 5.0     -- meters: how close a car must be for the vehicle menu to show
Config.flipTime = 5000        -- ms: how long flipping a car takes

-- the main wheel (Vehicle, Map and Work are added in code after these)
Config.menu = {
    {
        id = 'citizen', label = 'المواطن', icon = 'user',
        items = {
            { id = 'idcard', label = 'بطاقة الهوية', icon = 'id-card', action = 'useItem', arg = 'id_card' },
            { id = 'license', label = 'رخصة القيادة', icon = 'id-card', action = 'useItem', arg = 'driver_license' },
            { id = 'walk', label = 'طريقة المشي', icon = 'person-walking', action = 'walkMenu' },
            { id = 'keys', label = 'إعطاء المفتاح', icon = 'key', action = 'giveKeys', when = 'vehicle' },
        },
    },
    {
        id = 'clothing', label = 'الملابس', icon = 'shirt',
        items = {
            { id = 'hat', label = 'القبعة', icon = 'hat-cowboy', action = 'toggleProp', arg = 'hat' },
            { id = 'glasses', label = 'النظارة', icon = 'glasses', action = 'toggleProp', arg = 'glasses' },
            { id = 'mask', label = 'القناع', icon = 'mask', action = 'toggleCloth', arg = 'mask' },
            { id = 'vest', label = 'السترة الواقية', icon = 'vest', action = 'toggleCloth', arg = 'vest' },
            { id = 'bag', label = 'الحقيبة', icon = 'bag-shopping', action = 'toggleCloth', arg = 'bag' },
            { id = 'neck', label = 'الرقبة', icon = 'gem', action = 'toggleCloth', arg = 'neck' },
            { id = 'shirt', label = 'القميص', icon = 'shirt', action = 'toggleCloth', arg = 'shirt' },
            { id = 'pants', label = 'البنطال', icon = 'socks', action = 'toggleCloth', arg = 'pants' },
            { id = 'shoes', label = 'الحذاء', icon = 'shoe-prints', action = 'toggleCloth', arg = 'shoes' },
            { id = 'ear', label = 'سماعة الأذن', icon = 'headphones', action = 'toggleProp', arg = 'ear' },
            { id = 'watch', label = 'الساعة', icon = 'clock', action = 'toggleProp', arg = 'watch' },
            { id = 'bracelet', label = 'السوار', icon = 'gem', action = 'toggleProp', arg = 'bracelet' },
        },
    },
}

-- taking clothes off and putting them back (ped components and props; the "off" drawables are the
-- GTA ones for the multiplayer peds: male / female)
Config.props = {
    hat = { index = 0, anim = { dict = 'missheist_agency2ahelmet', clip = 'take_off_helmet_stand', ms = 1200 } },
    glasses = { index = 1, anim = { dict = 'clothingspecs', clip = 'take_off', ms = 1400 } },
    ear = { index = 2, anim = { dict = 'mp_cp_stolen_tut', clip = 'b_think', ms = 900 } },
    watch = { index = 6, anim = { dict = 'nmt_3_rcm-10', clip = 'cs_nigel_dual-10', ms = 1200 } },
    bracelet = { index = 7, anim = { dict = 'nmt_3_rcm-10', clip = 'cs_nigel_dual-10', ms = 1200 } },
}
Config.cloth = {
    mask = { component = 1, off = { male = 0, female = 0 }, anim = { dict = 'mp_masks@standard_car@ds@', clip = 'put_on_mask', ms = 800 } },
    vest = { component = 9, off = { male = 0, female = 0 }, anim = { dict = 'clothingtie', clip = 'try_tie_negative_a', ms = 1200 } },
    bag = { component = 5, off = { male = 0, female = 0 }, anim = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'intro', ms = 1600 } },
    neck = { component = 7, off = { male = 0, female = 0 }, anim = { dict = 'clothingtie', clip = 'try_tie_positive_a', ms = 2100 } },
    shoes = { component = 6, off = { male = 34, female = 35 }, anim = { dict = 'random@domestic', clip = 'pickup_low', ms = 1200, move = false } },
    pants = { component = 4, off = { male = 61, female = 14 }, anim = { dict = 're@construction', clip = 'out_of_breath', ms = 1300 } },
    -- the top: the jacket goes, and the undershirt, torso and decals go with it (they come back together)
    shirt = { component = 11, off = { male = 252, female = 74 }, anim = { dict = 'clothingtie', clip = 'try_tie_negative_a', ms = 1200 },
        also = { { component = 8, off = 15 }, { component = 3, off = 15 }, { component = 10, off = 0 } } },
}

-- walk styles (GTA movement clipsets). The first one puts the normal walk back.
Config.walkStyles = {
    { id = 'default', label = 'عادي', clipset = false },
    { id = 'confident', label = 'واثق', clipset = 'move_m@confident' },
    { id = 'brave', label = 'شجاع', clipset = 'move_m@brave' },
    { id = 'business', label = 'رجل أعمال', clipset = 'move_m@business@a' },
    { id = 'casual', label = 'مرتاح', clipset = 'move_m@casual@a' },
    { id = 'casual2', label = 'مرتاح 2', clipset = 'move_m@casual@b' },
    { id = 'tough', label = 'قوي', clipset = 'move_m@tough_guy@' },
    { id = 'muscle', label = 'عضلات', clipset = 'move_m@muscle@a' },
    { id = 'swagger', label = 'متباهي', clipset = 'move_m@swagger' },
    { id = 'hurry', label = 'مستعجل', clipset = 'move_m@hurry@a' },
    { id = 'quick', label = 'سريع', clipset = 'move_m@quick' },
    { id = 'hipster', label = 'هيبستر', clipset = 'move_m@hipster@a' },
    { id = 'posh', label = 'راقي', clipset = 'move_m@posh@' },
    { id = 'money', label = 'غني', clipset = 'move_m@money' },
    { id = 'gangster', label = 'عصابات', clipset = 'move_m@gangster@var_a' },
    { id = 'shady', label = 'مريب', clipset = 'move_m@shadyped@a' },
    { id = 'sad', label = 'حزين', clipset = 'move_m@sad@a' },
    { id = 'tired', label = 'متعب', clipset = 'move_m@buzzed' },
    { id = 'injured', label = 'مصاب', clipset = 'move_m@injured' },
    { id = 'heavy', label = 'ثقيل', clipset = 'move_m@fat@a' },
    { id = 'femme', label = 'أنثوي', clipset = 'move_f@femme@' },
    { id = 'chichi', label = 'شيشي', clipset = 'move_f@chichi' },
    { id = 'flee', label = 'خائف', clipset = 'move_m@flee@a' },
}

-- the Map menu: map icons you can hide, by their GTA sprite numbers (taken from our scripts' configs)
Config.blipGroups = {
    { id = 'shops', label = 'المتاجر', icon = 'cart-shopping', sprites = { 59, 93, 402 } },           -- exti_shops: 24/7, liquor, tools
    { id = 'style', label = 'الملابس والحلاق', icon = 'shirt', sprites = { 73, 71, 75 } },            -- clothing, barber, tattoo
    { id = 'fuel', label = 'محطات الوقود', icon = 'gas-pump', sprites = { 361 } },                   -- exti_fuel
    { id = 'banks', label = 'البنوك', icon = 'building-columns', sprites = { 108, 500 } },           -- exti_shops bank + ATMs
    { id = 'health', label = 'المستشفيات', icon = 'hospital', sprites = { 61 } },                    -- hospitals / pharmacy
    { id = 'garages', label = 'المرائب', icon = 'warehouse', sprites = { 524, 357 } },               -- qbx_garages
    { id = 'dealers', label = 'معارض السيارات', icon = 'car-side', sprites = { 326, 225, 523 } },     -- vehicle shops
    { id = 'jobs', label = 'الوظائف', icon = 'briefcase', sprites = { 68, 318, 616, 457 } },        -- exti_jobs HQs, job center
}

-- the Work menu, by job
-- other scripts that add a menu to the wheel: the wheel asks their export when it opens; the export
-- answers { label, icon, items } (or nothing when the menu should not show right now)
Config.providers = {
    { resource = 'exti_police', export = 'RadialMenu' },
    { resource = 'exti_mechanic', export = 'RadialMenu' },
}

Config.work = {
    police = {
        { id = 'tablet', label = 'التابلت', icon = 'tablet-screen-button', action = 'command', arg = 'policetablet' },
        { id = 'hq', label = 'الطريق إلى المركز', icon = 'location-dot', action = 'goto', arg = { x = 441.0, y = -981.0, z = 30.7, label = 'مركز شرطة مِشن رو' } },
    },
    ambulance = {
        { id = 'tablet', label = 'التابلت', icon = 'tablet-screen-button', action = 'command', arg = 'emstablet' },
        { id = 'hq', label = 'الطريق إلى المستشفى', icon = 'location-dot', action = 'goto', arg = { x = 311.18, y = -599.25, z = 43.29, label = 'مستشفى بيلبوكس' } },
    },
    tow = {
        { id = 'hq', label = 'الطريق إلى المقر', icon = 'location-dot', action = 'goto', arg = { x = 489.60, y = -1321.50, z = 29.30, label = 'مقر السحب' } },
    },
    garbage = {
        { id = 'hq', label = 'الطريق إلى المستودع', icon = 'location-dot', action = 'goto', arg = { x = -313.84, y = -1522.82, z = 27.56, label = 'مستودع النظافة' } },
    },
    delivery = {
        { id = 'hq', label = 'الطريق إلى المستودع', icon = 'location-dot', action = 'goto', arg = { x = 67.80, y = 100.80, z = 79.60, label = 'مستودع GoPostal' } },
    },
}
