Config = {}

--[[
    ================================================================
    CHANGE THESE TWO LINES FIRST
    ================================================================
]]
Config.serverName = 'EX_Tii Roleplay'       -- your server name (shows in the welcome + guide)
Config.discord    = 'discord.gg/a7G6aWrUyH' -- EX_Tii Roleplay Discord (never expires, gives the Citizen role)

--[[
    ================================================================
    COMMANDS
    ================================================================
]]
Config.guideCommand = 'guide'         -- players type /guide to open the guide
Config.staffCommand = 'newplayers'    -- staff type /newplayers to see new players online
Config.staffGroup   = 'group.support' -- who can use the staff command (support, mod and admin all can)

--[[
    ================================================================
    STARTER KIT (given once per new character)
    Qbox gives every new character a phone and the starting money
    (no ID card, no licence: those are bought). This adds food and water.
    ================================================================
]]
Config.starterKit = {
    enabled = true,
    items = {
        { name = 'water',  count = 3 },
        { name = 'burger', count = 3 },
    },
}

--[[
    ================================================================
    NEW PLAYER TAG
    Shows a tag above a new player's head for their first hours of play,
    so others know to go easy on them.
    Arabic works here thanks to the support-arabic resource.
    ================================================================
]]
Config.newPlayerTag = {
    enabled  = false,  -- turned off (the owner asked): no tag over anyone's head
    hours    = 5,      -- how many hours of playtime the tag stays
    text     = 'جديد',
    distance = 12.0,   -- how close you need to be to see it (metres)
}

--[[
    ================================================================
    SAFE ZONES (no shooting or fighting inside)
    ================================================================
]]
Config.safeZones = {
    enabled = true,
    ignoreJobs = { police = true, ambulance = true }, -- these jobs can still use weapons inside
    zones = {
        { label = 'Job Center',       coords = vec3(-232.44, -915.57, 32.30),   radius = 35.0 }, -- job center
        { label = 'New Players',      coords = vec3(-265.49, -962.85, 31.22),   radius = 25.0 }, -- new-player spawn (touches the job center zone: safe all the way)
        { label = 'Legion Square',    coords = vec3(195.17, -933.77, 29.7),  radius = 45.0 },
        { label = 'Pillbox Hospital', coords = vec3(308.19, -595.35, 43.29), radius = 40.0 },
    },
}

-- Where the "mark the job center on my map" button points (same place as qbx_cityhall)
Config.cityHall = vec3(-232.44, -915.57, 32.30)

--[[
    ================================================================
    TEXT (Arabic) — edit freely
    ================================================================
]]
Config.text = {
    safeZoneEnter  = 'منطقة آمنة — يُمنع القتال',
    waypointSet    = 'تم تحديد مركز التوظيف على الخريطة',

    staffTitle     = 'اللاعبون الجدد المتصلون',
    staffNone      = 'لا يوجد لاعبون جدد متصلون الآن',
    staffMinutes   = '%d دقيقة من اللعب',
}

--[[
    ================================================================
    THE GUIDE SCREEN (/guide, and opened by itself the first time)
    Each page: a title, an icon, a short line on top, then cards.
    A card: title, text, and an optional small tag (a price, a level...).
    Icons: start, briefcase, key, scale, help, map, bag, cash, car, id,
    level, shop, chicken, grape, bread, fish, pick, thread, trash, box,
    truck, cross, badge, wrench
    ================================================================
]]
Config.guide = {
    title = 'دليل المدينة',
    welcomeTitle = 'أهلًا بك في EX_Tii Roleplay',
    welcomeLine = 'هذا أول يوم لك في لوس سانتوس. اقرأ هذه الصفحة، ثم اذهب إلى مركز التوظيف.',

    pages = {
        {
            id = 'start', title = 'ابدأ هنا', icon = 'start',
            intro = 'خطواتك الأولى في المدينة، بالترتيب.',
            steps = true,
            cards = {
                { icon = 'bag', title = 'تفقّد حقيبتك', text = 'اضغط TAB. معك هاتف، و3 قوارير ماء و3 برغر.' },
                { icon = 'cash', title = 'مالك', text = 'تبدأ بـ 500 دولار نقدًا و2,000 دولار في البنك. المال هنا صعب، فاصرفه بعقل.' },
                { icon = 'car', title = 'رخصة السيارات أولًا', text = 'اذهب إلى مدرسة تعليم القيادة (روكفورد بلازا). اختبار نظري ثم عملي. كل الوظائف الأولى تحتاج هذه الرخصة.', tag = '250 دولار' },
                { icon = 'briefcase', title = 'خذ وظيفة', text = 'من مركز التوظيف (الحقيبة على الخريطة): توصيل، أو نظافة، أو سحب سيارات. تدفع تأمينًا على مركبة العمل ويعود لك عندما تعيدها.', tag = 'تأمين 250 دولار' },
                { icon = 'id', title = 'هويتك', text = 'اشترِ بطاقة الهوية من موظف مركز التوظيف. الشرطة قد تطلبها منك.', tag = '50 دولار' },
                { icon = 'level', title = 'ارفع مستواك', text = 'كل عمل تقوم به يرفع مستواك، والمستويات تفتح وظائف أفضل ودخلًا أعلى.' },
                { icon = 'shop', title = 'اشترِ سيارتك', text = 'من معرض السيارات عندما يكتمل معك المبلغ.' },
            },
        },
        {
            id = 'jobs', title = 'الوظائف', icon = 'briefcase',
            intro = 'كل وظائف المدينة. تختار الوظائف الحرة من مركز التوظيف، والمستوى يفتح الأعلى أجرًا.',
            cards = {
                { icon = 'box', title = 'عامل توصيل', text = 'توصل طرود GoPostal إلى البيوت والمحلات بشاحنة التوصيل.', tag = 'رخصة سيارات' },
                { icon = 'trash', title = 'عامل نظافة', text = 'تمرّ على الحاويات وترمي الأكياس في شاحنة النفايات.', tag = 'رخصة سيارات' },
                { icon = 'truck', title = 'سائق سحب', text = 'تسحب السيارات المعطلة والمتروكة إلى ساحة الحجز.', tag = 'رخصة سيارات' },
                { icon = 'chicken', title = 'عامل دواجن', text = 'تصطاد الدجاج وتذبحه وتعبّئه ثم تبيعه. العُدد من متجر 24/7.', tag = 'المستوى 3' },
                { icon = 'grape', title = 'عامل زبيب', text = 'تقطف العنب في مزارع مارلو وتجفّفه وتعبّئه ثم تبيعه.', tag = 'المستوى 8' },
                { icon = 'bread', title = 'خبّاز', text = 'تحصد القمح في غريبسيد وتطحنه وتخبزه ثم تبيع الخبز.', tag = 'المستوى 15' },
                { icon = 'fish', title = 'صياد سمك', text = 'تصطاد من رصيف الصيد وتنظّف السمك وتعبّئه ثم تبيعه.', tag = 'المستوى 22' },
                { icon = 'pick', title = 'عامل معادن', text = 'تحفر الصخور في منجم ديفيس كوارتز وتفرزها وتصهرها ثم تبيع السبائك.', tag = 'المستوى 30' },
                { icon = 'thread', title = 'عامل أقمشة', text = 'تجزّ الصوف وتنسجه وتخيط الملابس ثم تبيعها.', tag = 'المستوى 40' },
                { icon = 'cross', title = 'مسعف', text = 'تنقذ المصابين وتعالجهم. التوظيف عن طريق رئيس الإسعاف.', tag = 'بالتوظيف' },
                { icon = 'badge', title = 'الشرطة', text = 'تحمي المدينة. قدّم طلبك من مكتب الاستقبال في مركز شرطة مِشن رو.', tag = 'بالتوظيف' },
                { icon = 'wrench', title = 'ميكانيكي', text = 'تصلح السيارات وتعدّلها في الورشة. التوظيف عن طريق صاحب الورشة.', tag = 'بالتوظيف' },
            },
        },
        {
            id = 'keys', title = 'الأزرار', icon = 'key',
            intro = 'الأزرار التي تحتاجها كل يوم. تستطيع تغييرها من إعدادات اللعبة.',
            keys = true,
            cards = {
                { key = 'TAB', title = 'الحقيبة', text = 'أغراضك' },
                { key = '1 - 5', title = 'الأغراض السريعة', text = 'ما وضعته في الخانات الأولى' },
                { key = 'E', title = 'التفاعل', text = 'عندما يظهر الزر على الشاشة' },
                { key = 'Z', title = 'القائمة الدائرية', text = 'كل ما تستطيع فعله الآن' },
                { key = 'M', title = 'الهاتف', text = 'الرسائل والاتصال والتطبيقات' },
                { key = 'X', title = 'ارفع يديك', text = 'عند التهديد بسلاح' },
                { key = 'T', title = 'المحادثة', text = 'والأوامر مثل /guide' },
                { key = 'N', title = 'الميكروفون', text = 'اضغط مطوّلًا لتتكلم (إن كان الضغط للتحدث مفعّلًا)' },
                { key = '~', title = 'مدى الصوت', text = 'الزر الذي تحت Esc: همس، عادي، صراخ' },
            },
        },
        {
            id = 'rules', title = 'القوانين', icon = 'scale',
            intro = 'اقرأها قبل أن تلعب. القوانين الكاملة في الديسكورد: discord.gg/a7G6aWrUyH',
            cards = {
                { title = 'الاحترام أولًا', text = 'يُمنع سب الدين أو الأهل، وتُمنع العنصرية.' },
                { title = 'لا قتل عشوائي', text = 'لا تقتل أحدًا أو تدهسه دون سبب في القصة.' },
                { title = 'التزم بشخصيتك', text = 'لا تخلط أمور الواقع بأحداث اللعب.' },
                { title = 'لا غش ولا استغلال للثغرات', text = 'وجدت ثغرة؟ أبلغ الإدارة.' },
                { title = 'المناطق الآمنة', text = 'يُمنع القتال عند مركز التوظيف ومكان وصول اللاعبين الجدد وساحة ليجن والمستشفى.' },
                { title = 'قرار الإدارة نهائي', text = 'أي اعتراض يكون في الديسكورد وبأدب.' },
            },
        },
        {
            id = 'help', title = 'المساعدة', icon = 'help',
            intro = 'لا تبقَ وحدك إذا علقت.',
            cards = {
                { title = 'ديسكورد EX_Tii', text = 'discord.gg/a7G6aWrUyH  ·  الأخبار، القوانين، التقديم على الوظائف، والدعم.' },
                { title = 'تحتاج الإدارة؟', text = 'افتح تذكرة من قناة "افتح تذكرة" في الديسكورد.' },
                { title = 'وجدت خللًا؟', text = 'أبلغ عنه في الديسكورد واذكر ما حدث بالتفصيل.' },
                { title = 'نسيت الطريق؟', text = 'اضغط زر "حدّد مركز التوظيف" في أسفل هذه الشاشة.' },
            },
        },
    },
}
