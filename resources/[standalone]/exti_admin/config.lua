-- =====================================================================
-- EX_Tii admin tablet: settings
-- =====================================================================
Config = {}

-- the key (players can change it in GTA Settings > Key Bindings > FiveM)
Config.key = 'F1'

-- EX_Tii (Moe): 5 staff ranks. Each rank can do everything the rank below it can, plus its own list.
-- "owner" = anyone with group.admin in server.cfg (you), or a staff member you made owner in the panel.
Config.roleOrder = { 'helper', 'moderator', 'admin', 'senior', 'owner' }
Config.roles = {
    helper    = { level = 1, label = 'مساعد',     desc = 'انتقال، نوكليب، إنعاش وعلاج، رسائل، البلاغات',
                  can = { 'view', 'goto', 'tp', 'noclip', 'revive', 'heal', 'message', 'reports' } },
    moderator = { level = 2, label = 'مشرف',      desc = '+ جلب، مراقبة، تجميد، إنذار، طرد، حظر قصير (حتى 3 أيام)',
                  can = { 'bring', 'spectate', 'freeze', 'warn', 'kick', 'ban', 'names' } },
    admin     = { level = 3, label = 'أدمن',      desc = '+ مال وأغراض وسيارات (بحد يومي)، وظائف، عصابة لاعب، الطقس والوقت، إعلانات، التجربة، حظر حتى 30 يومًا',
                  can = { 'money', 'item', 'car', 'givecar', 'licence', 'job', 'gang', 'world', 'announce', 'me', 'test', 'clearcars' } },
    senior    = { level = 4, label = 'أدمن أول',  desc = '+ إدارة العصابات، فتح الحقائب وتفريغها، حظر دائم وفك الحظر، السجل، إنعاش الجميع',
                  can = { 'gangs', 'inventory', 'clearinv', 'unban', 'logs', 'reviveall' } },
    owner     = { level = 5, label = 'المالك',    desc = 'كل شيء: الطاقم والرتب، إعادة تشغيل الموارد، بلا حدود',
                  can = '*' },
}
-- the longest ban each rank may give, in hours (0 = permanent allowed)
Config.banMax = { moderator = 72, admin = 720, senior = 0, owner = 0 }
-- what each rank may hand out in one day (to anyone, themselves included). nil = no limit
Config.limits = {
    admin  = { money = 100000, items = 50, kits = 5, cars = 3 },
    senior = { money = 1000000, items = 500, kits = 30, cars = 15 },
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
