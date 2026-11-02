-- =====================================================================
-- EX_Tii jobs: settings shared by the game and the server
-- Three jobs to start with: tow, garbage, delivery.
-- Money: about $2,300-2,600 an hour at level 1, ~$3,500 at level 5 (plus the $50 paycheck every 10 minutes).
-- (EX_Tii economy: pay cut 35% so a nice car takes real work)
-- =====================================================================
return {
    deposit = 250,          -- paid when the work vehicle is taken, given back when it is returned
    licence = 'driver',     -- every job here needs a driver's licence (new players start with one)

    -- levels: tasks done in that job -> pay raise
    levelNames = { 'مبتدئ', 'متمرّس', 'محترف', 'خبير', 'نخبة' },
    levelBonus = { 0.0, 0.10, 0.20, 0.30, 0.40 },

    -- bonus for bringing the work vehicle back at the end of the shift:
    -- base + per finished round (up to max), times how healthy the vehicle is
    returnBonus = { base = 65, perRound = 33, max = 260 },

    -- jobs anyone may switch away from at the job center (police, EMS and other team jobs can't)
    freeJobs = { unemployed = true, tow = true, garbage = true, delivery = true, taxi = true, bus = true, trucker = true, reporter = true, vineyard = true },

    -- the order on the tablet
    order = { 'delivery', 'garbage', 'tow' },

    -- EX_Tii level system (exti_level): the starter jobs above need no level. These jobs need a level
    -- and supplies from the 24/7 store; they are being built one phase at a time (soon = shown as
    -- "قريبًا" in the job centre until its update arrives). minLevel = the player level needed.
    upcoming = {
        { name = 'fishing', label = 'صياد سمك', company = 'سوق السمك في لوس سانتوس', icon = 'fish', minLevel = 3, hourText = '2,700$',
          short = 'اصطد السمك من الرصيف أو بالقارب وبِعه في سوق السمك. كل نوع بسعر.', supplies = { 'صنارة', 'طُعم' }, soon = true },
        { name = 'hotdog', label = 'بائع نقانق', company = 'عربات شانكي للنقانق', icon = 'hotdog', minLevel = 8, hourText = '2,900$',
          short = 'جهّز العربة وقدّم النقانق للزبائن في الشوارع المزدحمة.', supplies = { 'نقانق', 'خبز', 'صلصة' }, soon = true },
        { name = 'windows', label = 'منظف نوافذ', company = 'بُرج كلين', icon = 'window', minLevel = 15, hourText = '3,100$',
          short = 'نظّف واجهات الأبراج من المنصة المعلّقة.', supplies = { 'ممسحة زجاج', 'صابون زجاج' }, soon = true },
        { name = 'pizza', label = 'عامل بيتزا', company = 'بيتزا ذيس', icon = 'pizza', minLevel = 22, hourText = '3,300$',
          short = 'اخبز البيتزا في المطعم ثم أوصلها بالدراجة ساخنة.', supplies = { 'عجينة', 'جبن' }, soon = true },
        { name = 'farming', label = 'مزارع', company = 'مزارع غريبسيد', icon = 'leaf', minLevel = 30, hourText = '3,500$',
          short = 'ازرع واسقِ واحصد المحصول وبِعه.', supplies = { 'بذور', 'سماد' }, soon = true },
        { name = 'bus', label = 'سائق حافلة', company = 'حافلات لوس سانتوس', icon = 'bus', minLevel = 40, hourText = '3,700$',
          short = 'قُد الحافلة على خطوط المدينة وأوصل الركاب.', supplies = { 'لفة تذاكر' }, soon = true },
        { name = 'lumber', label = 'حطّاب', company = 'منشرة بوليتو', icon = 'tree', minLevel = 55, hourText = '4,000$',
          short = 'اقطع الأشجار وحمّل الجذوع وأوصلها إلى المنشرة.', supplies = { 'فأس', 'قفازات' }, soon = true },
        { name = 'mining', label = 'عامل منجم', company = 'منجم ديفيس كوارتز', icon = 'pickaxe', minLevel = 70, hourText = '4,300$',
          short = 'احفر الصخور، اصهر الخام وبِع المعادن.', supplies = { 'معول', 'بطاريات مصباح الرأس' }, soon = true },
        { name = 'recycling', label = 'عامل إعادة التدوير', company = 'مصنع إعادة التدوير', icon = 'recycle', minLevel = 90, hourText = '4,600$',
          short = 'افرز المواد في المصنع واكبسها وجهّزها للبيع.', supplies = { 'قفازات عمل', 'أكياس قمامة' }, soon = true },
        { name = 'trucker', label = 'سائق شاحنة', company = 'نقل سان أندرياس', icon = 'truck', minLevel = 110, hourText = '5,000$',
          short = 'انقل المقطورات لمسافات طويلة بين المدن.', supplies = { 'أحزمة ربط', 'مشاعل طريق' }, soon = true },
        { name = 'electrician', label = 'كهربائي', company = 'كهرباء لوس سانتوس', icon = 'bolt', minLevel = 140, hourText = '5,400$',
          short = 'أصلح صناديق الكهرباء المعطلة في أنحاء المدينة.', supplies = { 'لفة أسلاك', 'فيوزات' }, soon = true },
        { name = 'scuba', label = 'غوّاص إنقاذ', company = 'إنقاذ بحري', icon = 'dive', minLevel = 175, hourText = '5,800$',
          short = 'اغطس إلى حطام السفن وانتشل البضائع.', supplies = { 'تعبئة أكسجين', 'مصباح غوص' }, soon = true },
        { name = 'oil', label = 'فني حقول النفط', company = 'نفط ساندي شورز', icon = 'oil', minLevel = 220, hourText = '6,200$',
          short = 'صِن المضخات وخطوط الأنابيب في حقول النفط.', supplies = { 'حشوات', 'شحم صمامات' }, soon = true },
    },

    -- EX_Tii: team jobs: you join them here, but they are run by their own script (EMS = exti_ems).
    -- You can only take one if your current job is a free one (above); you leave with "استقالة".
    -- EX_Tii: EMS is no longer joined here (hiring is done by the EMS chief, like police and mechanic)
    teamOrder = {},
    teamJobs = {
        ambulance = {
            label = 'مسعف',
            company = 'إسعاف EX_Tii',
            icon = 'medic',
            short = 'أنقذ الناس في المدينة: البلاغات تصلك على التابلت، تنعش من سقط مصابًا، تعالج الجرحى، وتنقلهم بالنقالة وسيارة الإسعاف إلى المستشفى.',
            steps = {
                'قدّم هنا، ثم اذهب إلى مستشفى بيلبوكس أو مركز باليتو الطبي.',
                'في غرفة الطاقم اضغط E لتبدأ المناوبة وتلبس زي الإسعاف.',
                'خذ المستلزمات مجانًا من خزانة المستلزمات، وسيارة الإسعاف من المرآب.',
                'افتح التابلت بزر F6 واستلم بلاغًا: الخط الذهبي يأخذك إلى المريض.',
                'قف بجانب المريض واضغط E: أنعشه إن كان على الأرض، أو عالج جروحه.',
                'انقله بالنقالة إلى سيارة الإسعاف ثم إلى سرير في المستشفى.',
            },
            extra = 'تبدأ مستجدًا، والترقية يمنحها قائد الإسعاف. كل رتبة براتب أعلى كل 10 دقائق.',
            payText = '300$ لكل إنعاش و150$ لكل علاج',
            vehicle = { model = 'ambulance', label = 'سيارة إسعاف + مروحية' },
            hq = { label = 'مستشفى بيلبوكس', place = 'بيلبوكس هيل · ومركز باليتو الطبي', coords = vec3(311.18, -599.25, 43.29) },
        },
    },

    jobs = {
        -------------------------------------------------------------------
        tow = {
            label = 'سائق سحب',
            company = 'شركة هايز للسحب',
            icon = 'tow',
            short = 'اسحب المركبات المعطلة في شوارع المدينة إلى ساحات التسليم، وأبعد السيارات المتروكة عن الطرق.',
            steps = {
                'اذهب إلى مقر السحب وقف في الدائرة الذهبية أمام المشرف، ثم اضغط E.',
                'ابدأ المناوبة لتستلم شاحنة السحب المسطّحة.',
                'اتبع العلامة على الخريطة إلى المركبة المعطلة.',
                'ترجّل وقف بجانبها، ثم اضغط E لرفعها على الشاحنة.',
                'أوصلها إلى ساحة التسليم الأقرب، واضغط E داخل الدائرة الذهبية لإنزالها.',
                'كل جولة 3 مركبات، وبعدها تصلك جولة جديدة مباشرة.',
            },
            extra = 'المركبات التي تُترك دون سائق أكثر من 10 دقائق يمكنك سحبها إلى ساحة الحجز، ويدفع صاحبها رسوم الاستلام.',
            payText = 'حوالي 125$ لكل مركبة',
            hourText = '2,300$ – 2,600$',
            taskWord = { 'مركبة', 'مركبات' },
            levelSteps = { 0, 25, 70, 140, 240 },
            pay = { base = 114, perMeter = 0.02, maxDistance = 45 }, -- cars are 300-950 m away: about 120-135$ each
            abandonedPay = 160,
            impoundFee = 500,
            abandonedMinutes = 10, -- tow drivers may take a car left this long (the impound staff take it at 15)
            perRound = 3,
            -- the broken-down cars (ordinary city cars, one picked at random each time)
            brokenModels = { 'asea', 'stanier', 'washington', 'primo', 'premier', 'intruder', 'emperor', 'ingot', 'fugitive', 'tailgater', 'oracle', 'zion', 'felon', 'buffalo', 'dilettante', 'blista', 'issi2', 'baller2', 'fq2', 'serrano' },
            vehicle = { model = 'flatbed', label = 'شاحنة سحب مسطّحة', plate = 'TOW', blipName = 'شاحنة السحب' },
            hq = {
                label = 'مقر السحب',
                place = 'هايز ديبو',
                blip = { sprite = 68, colour = 0, scale = 0.75 }, -- EX_Tii map icon plan: work = white
                supervisor = { model = 's_m_m_autoshop_02', coords = vec4(489.60, -1321.50, 29.30, 270.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف سالم' }, -- by the shed at the end of the lane, facing the lane
                spawns = { vec4(489.65, -1331.82, 29.33, 306.5), vec4(497.30, -1335.44, 29.33, 306.5) },
                returnPoint = vec3(489.65, -1331.82, 29.33),
                returnRadius = 30.0,
            },
            -- where towed cars are left (garage = the impound lot an abandoned player car goes to)
            drops = {
                { label = 'ساحة هايز', coords = vec3(491.00, -1312.00, 29.25), garage = 'impoundlot' },
                { label = 'ساحة الحجز - مِشن رو', coords = vec3(407.20, -1645.58, 29.31), garage = 'impoundlot' },
            },
            dropRadius = 5.5,
        },

        -------------------------------------------------------------------
        garbage = {
            label = 'عامل نظافة',
            company = 'بلدية لوس سانتوس',
            icon = 'trash',
            short = 'اجمع أكياس القمامة من حاويات الأحياء بشاحنة البلدية، وحافظ على نظافة المدينة.',
            steps = {
                'اذهب إلى مستودع النظافة وقف في الدائرة الذهبية أمام المشرف، ثم اضغط E.',
                'ابدأ المناوبة لتستلم شاحنة النفايات.',
                'اتبع العلامة إلى الحاوية، ثم ترجّل وقف في الدائرة الذهبية بجانبها.',
                'اضغط E لأخذ كيس القمامة، واحمله إلى خلف الشاحنة، ثم اضغط E لرميه فيها.',
                'كل حاوية فيها كيسان أو ثلاثة، وكل جولة 6 حاويات قريبة من بعضها.',
                'بعد آخر حاوية عد إلى المستودع وادخل بالشاحنة الدائرة الذهبية لتفريغها، فتبدأ جولة جديدة.',
            },
            payText = '26$ لكل كيس (حوالي 65$ لكل حاوية)',
            hourText = '2,300$ – 2,600$',
            taskWord = { 'حاوية', 'حاويات' },
            levelSteps = { 0, 45, 120, 240, 420 },
            pay = { perBag = 26 },
            bags = { 2, 3 },
            perRound = 6,
            vehicle = { model = 'trash', label = 'شاحنة نفايات', plate = 'LSC', blipName = 'شاحنة النفايات' },
            truckBack = -4.6, -- metres behind the middle of the truck where the bags go in
            hq = {
                label = 'مستودع النظافة',
                place = 'ستروبيري',
                blip = { sprite = 318, colour = 0, scale = 0.75 },
                supervisor = { model = 's_m_y_garbage', coords = vec4(-313.84, -1522.82, 27.56, 260.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف خالد' },
                spawns = { vec4(-333.84, -1527.28, 27.28, 1.97), vec4(-327.55, -1527.69, 27.25, 359.43) },
                returnPoint = vec3(-330.70, -1527.50, 27.27),
                returnRadius = 30.0,
                dock = vec3(-330.70, -1527.50, 27.27), -- drive the truck in here to empty it (and get a new round)
                dockRadius = 4.5,
            },
        },

        -------------------------------------------------------------------
        delivery = {
            label = 'عامل توصيل',
            company = 'شركة GoPostal',
            icon = 'box',
            short = 'وزّع طرود شركة GoPostal على المتاجر والمحلات في المدينة، وسلّم كل طرد يدًا بيد عند المحاسب.',
            steps = {
                'اذهب إلى مستودع GoPostal وقف في الدائرة الذهبية أمام المشرف، ثم اضغط E.',
                'ابدأ المناوبة لتستلم شاحنة التوصيل.',
                'أوقف الشاحنة في دائرة التحميل الذهبية واضغط E لتحميل 6 طرود.',
                'اتبع العلامة إلى المتجر، وخذ الطرد من خلف الشاحنة بالضغط على E.',
                'ادخل المتجر وقف في الدائرة الذهبية عند المحاسب، ثم اضغط E لتسليم الطرد.',
                'بعد آخر طرد عد إلى المستودع لتحميل جولة جديدة.',
            },
            payText = 'حوالي 70$ لكل طرد (أكثر للمسافات الأبعد)',
            hourText = '2,300$ – 2,600$',
            taskWord = { 'طرد', 'طرود' },
            levelSteps = { 0, 45, 120, 240, 420 },
            pay = { base = 58, perMeter = 0.023, maxDistance = 40 },
            perRound = 6,
            vehicle = { model = 'boxville2', label = 'شاحنة توصيل GoPostal', plate = 'GOP', blipName = 'شاحنة التوصيل' },
            vanBack = -3.6, -- metres behind the middle of the van where the parcels are taken out
            hq = {
                label = 'مستودع GoPostal',
                place = 'داونتاون فاينوود',
                blip = { sprite = 616, colour = 0, scale = 0.75, name = 'مستودع التوصيل' }, -- (map name in Arabic only)
                -- the parking lot beside the GoPostal gate (Downtown Vinewood)
                supervisor = { model = 's_m_m_postal_01', coords = vec4(67.80, 100.80, 79.60, 250.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف فيصل' },
                spawns = { vec4(78.70, 97.70, 79.20, 71.0), vec4(84.50, 96.00, 79.20, 71.0) },
                returnPoint = vec3(76.00, 94.00, 79.20),
                returnRadius = 30.0,
                dock = vec3(72.00, 98.30, 79.20), -- park the van here to load the parcels (the lot entrance)
                dockRadius = 4.0,
            },
        },
    },
}
