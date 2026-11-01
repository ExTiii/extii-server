Config = {}

--[[
    ================================================================
    CHANGE THESE TWO LINES FIRST
    ================================================================
]]
Config.serverName = 'المدينة'               -- your server name (shows in the welcome + guide)
Config.discord    = ''  -- EX_Tii: no invite link yet (the help page line was removed); put the real link here later

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
    Qbox already gives every new character a phone, ID card,
    driver licence, cash and bank money. This adds food and water.
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
    welcomeHeader  = ('أهلًا بك في %s'):format(Config.serverName),
    welcomeBody    = table.concat({
        'هذا أول دخول لك، ووضعنا لك **طعامًا وماءً** في حقيبتك (زر **TAB**).',
        '',
        '**أول خطوة:** اذهب إلى **مركز التوظيف (Job Center)**، الحقيبة الذهبية على الخريطة، واختر وظيفة لتكسب أول مال لك.',
        '',
        'يمكنك فتح الدليل في أي وقت بكتابة **/guide** في المحادثة (زر **T**).',
        '',
        'استمتع، واحترم الجميع. 🤝',
    }, '  \n'),
    welcomeConfirm = 'افتح الدليل',
    welcomeCancel  = 'لاحقًا',

    safeZoneEnter  = 'منطقة آمنة — يُمنع القتال',
    waypointSet    = 'تم تحديد مركز التوظيف على الخريطة',

    staffTitle     = 'اللاعبون الجدد المتصلون',
    staffNone      = 'لا يوجد لاعبون جدد متصلون الآن',
    staffMinutes   = '%d دقيقة من اللعب',
}

--[[
    ================================================================
    THE GUIDE MENU (/guide)
    Each page is a list of lines. Keep lines short.
    ================================================================
]]
Config.guide = {
    title = ('دليل اللاعب الجديد — %s'):format(Config.serverName),

    pages = {
        {
            id = 'start',
            title = 'خطواتك الأولى',
            description = 'ابدأ من هنا',
            icon = 'shoe-prints',
            lines = {
                { '1. تفقّد أغراضك', 'اضغط TAB: معك هاتف، وهوية، ورخصة قيادة، وطعام وماء' },
                { '2. مالك', 'معك مال نقدي ومال في البنك لتبدأ به' },
                { '3. اذهب إلى مركز التوظيف', 'الحقيبة الذهبية على الخريطة، اختر منه وظيفة' },
                { '4. اعمل واجمع المال', 'كلما عملت أكثر، كسبت أكثر' },
                { '5. اشترِ مركبتك', 'من معرض المركبات عندما يكتمل معك المبلغ' },
                { 'الدليل متاح دائمًا', 'اكتب /guide في المحادثة في أي وقت' },
            },
        },
        {
            id = 'money',
            title = 'كيف تكسب أول مال',
            description = 'وظائف سهلة تبدأ بها اليوم',
            icon = 'sack-dollar',
            lines = {
                { 'أين أجد وظيفة؟', 'في مركز التوظيف (Job Center): الحقيبة الذهبية على الخريطة' },
                -- EX_Tii: only the jobs the city really has (bus, taxi, trucker and reporter were removed)
                { 'عامل نظافة', 'أسهل بداية: تمرّ على الحاويات وترمي الأكياس في الشاحنة' },
                { 'عامل توصيل', 'توصل طرود GoPostal إلى البيوت والمحلات' },
                { 'سائق سحب', 'تسحب المركبات المعطلة والمتروكة إلى ساحة الحجز' },
                { 'مسعف', 'تنقذ المصابين وتعالجهم في المستشفى' },
                { 'الشرطة', 'قدّم طلب توظيف من مكتب الاستقبال في مركز شرطة مِشن رو' },
            },
            waypoint = true,
        },
        {
            id = 'keys',
            title = 'الأزرار المهمة',
            description = 'كل الأزرار التي تحتاجها',
            icon = 'keyboard',
            lines = {
                { 'TAB', 'الحقيبة (الأغراض)' },
                { '1 - 5', 'الأغراض السريعة' },
                { 'E', 'التفاعل: اضغطه عندما يظهر الزر على الشاشة' },
                { 'Z', 'القائمة الدائرية' },
                { 'M', 'الهاتف' },
                { 'T', 'المحادثة' },
                { 'N', 'التحدث عبر الميكروفون (إن لم تغيّره من الإعدادات)' },
                { '` (الزر الذي تحت Esc)', 'تغيير مدى الصوت: همس / عادي / صراخ' },
            },
        },
        {
            id = 'rules',
            title = 'القوانين باختصار',
            description = 'اقرأها قبل أن تلعب',
            icon = 'scale-balanced',
            lines = {
                { 'الاحترام أولًا', 'يُمنع سب الدين أو الأهل، وتُمنع العنصرية' },
                { 'يُمنع القتل العشوائي', 'لا تقتل أحدًا أو تدهسه دون سبب في القصة' },
                { 'التزم بشخصيتك', 'لا تخلط أمور الواقع بأحداث اللعب' },
                { 'يُمنع الغش واستغلال الثغرات', 'وجدت ثغرة؟ أبلغ عنها في الديسكورد' },
                { 'المناطق الآمنة', 'يُمنع القتال عند مركز التوظيف وفي المستشفى وساحة ليجن' },
                { 'قرار الإدارة نهائي', 'أي اعتراض يكون في الديسكورد وبأدب' },
                { 'القوانين الكاملة', 'موجودة في الديسكورد' },
            },
        },
        {
            id = 'help',
            title = 'هل تحتاج مساعدة؟',
            description = 'الإدارة والدعم',
            icon = 'circle-question',
            lines = {
                { 'تريد التحدث مع الإدارة؟', 'افتح تذكرة في قناة الدعم في الديسكورد' },
                { 'وجدت مشكلة أو خللًا؟', 'أبلغ عنها في قناة #bug-reports' },
            },
        },
    },
}
