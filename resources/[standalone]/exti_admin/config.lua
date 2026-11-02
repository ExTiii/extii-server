-- =====================================================================
-- EX_Tii admin tablet: settings
-- =====================================================================
Config = {}

-- the key (players can change it in GTA Settings > Key Bindings > FiveM)
Config.key = 'F1'

-- who can do what. "owner" = anyone with group.admin in server.cfg (you).
-- staff you add in the tablet get "admin" or "helper".
Config.roles = {
    helper = { label = 'مساعد', can = { 'view', 'goto', 'bring', 'spectate', 'freeze', 'revive', 'heal', 'kick', 'message', 'reports', 'noclip', 'tp' } },
    admin  = { label = 'أدمن', can = { 'view', 'goto', 'bring', 'spectate', 'freeze', 'revive', 'heal', 'kick', 'message', 'reports', 'noclip', 'tp',
                                       'ban', 'money', 'item', 'job', 'gang', 'inventory', 'me', 'car', 'world', 'announce', 'gangs', 'test', 'logs' } },
    owner  = { label = 'المالك', can = '*' },
}

-- resources the tablet will NOT restart (restarting them breaks everyone)
Config.noRestart = { monitor = true, qbx_medical = true, qbx_core = true, oxmysql = true, ox_lib = true, ox_inventory = true, exti_admin = true, sessionmanager = true, mapmanager = true, spawnmanager = true, chat = true }

-- the test kits (Test tab): items given to you
Config.kits = {
    { label = 'عدة ورشة التفكيك', items = { { 'chop_tools', 5 }, { 'lockpick', 5 } } },
    { label = 'عدة غسيل الأموال', items = { { 'black_money', 20000 }, { 'wash_supplies', 10 } } },
    { label = 'عدة الذخيرة', items = { { 'ammo_materials', 10 } } },
    { label = 'عدة الأسلحة', items = { { 'gun_parts', 20 } } },
    { label = 'عدة الحشيش', items = { { 'gang_weed_seeds', 10 }, { 'weed_nutrition', 5 } } },
    { label = 'عدة النفوذ', items = { { 'spray_can', 5 }, { 'scrub_brush', 3 } } },
    { label = 'متفجرات C4', items = { { 'c4', 2 } } },
}

-- the minigames (Test tab)
Config.minigames = {
    { 'bolts', 'البراغي' }, { 'lugnuts', 'الصواميل' }, { 'pry', 'العتلة' }, { 'torch', 'الشعلة' },
    { 'sort', 'فرز الأوراق' }, { 'drum', 'الغسالة' }, { 'band', 'عدّ الرزم' },
    { 'melt', 'صهر الرصاص' }, { 'press', 'المكبس' }, { 'boxfill', 'علبة الطلقات' },
    { 'file', 'برد الهيكل' }, { 'assemble', 'تركيب السلاح' }, { 'range', 'ميدان الرماية' },
    { 'trim', 'قص الحشيش' }, { 'weigh', 'الميزان' },
}

-- quick cars (Me & world tab); any other model can be typed in
Config.cars = { 'sultan', 'kuruma', 'police', 'police3', 'ambulance', 'adder', 'bati', 'sanchez', 'burrito3', 'flatbed', 'buzzard2' }

Config.weathers = { 'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'RAIN', 'THUNDER', 'FOGGY', 'SMOG', 'CLEARING', 'XMAS' }
