-- =====================================================================
-- EX_Tii jobs: settings shared by the game and the server
-- Three jobs to start with: tow, garbage, delivery.
-- Money (Moe's hard grind, rank 1): starter jobs ~$1,600 an hour, poultry $2,100, raisins $2,600, bread $3,200,
-- fishing $3,900, metals $4,700, fabrics $5,600. Every rank in a job adds 10% (up to +40%).
-- XP: every job gives about 600 XP an hour (exti_level: level 40 after about 60 hours).
-- =====================================================================
-- EX_Tii (Moe): the level jobs have no mini games any more. Every station = an animation with a progress
-- circle, then a short skill check ([E] when the marker is in the zone). Fail = nothing is lost, you just
-- do the station again. One stage = { label, ms, skill levels, what the [E] does, anim, prop }.
-- =====================================================================
local A = {
    chase  = { dict = 'anim@mp_snowball', clip = 'pickup_snowball' },
    bin    = { dict = 'amb@prop_human_bum_bin@base', clip = 'base' },
    cut    = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter' },
    bench  = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    meter  = { dict = 'amb@prop_human_parking_meter@male@base', clip = 'base' },
    plant  = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
    kneel  = { dict = 'amb@medic@standing@kneel@base', clip = 'base' },
    fish   = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c' },
    mine   = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' },
    weld   = { dict = 'amb@world_human_welding@male@base', clip = 'base' },
}
local P = {
    -- the head of the pickaxe points forward and down, the handle in the right hand
    pickaxe = { model = 'prop_tool_pickaxe', bone = 57005, pos = vec3(0.08, -0.1, -0.04), rot = vec3(78.0, -20.0, 175.0) },
    rod     = { model = 'prop_fishing_rod_01', bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
}
local function st(label, ms, skill, hint, anim, prop) return { label = label, ms = ms, skill = skill, hint = hint, anim = anim, prop = prop } end
local E1, E2, EM, M1, M2, MH = { 'easy' }, { 'easy', 'easy' }, { 'easy', 'medium' }, { 'medium' }, { 'medium', 'medium' }, { 'medium', 'hard' }
local S = {
    catch     = { st('تطارد الدجاج في الحظيرة...', 10000, E2, 'امسك الدجاجة', A.chase), st('تضع الدجاج في الأقفاص...', 8000, E1, 'أغلق القفص', A.bin) },
    slaughter = { st('تثبّت الدجاج على الطاولة...', 8000, E1, 'ثبّت الدجاجة', A.cut), st('تذبح الدجاج...', 10000, EM, 'اذبح بضربة واحدة', A.cut) },
    pack      = { st('ترتّب الدجاج في الصواني...', 9000, E2, 'ضع الدجاجة في الصينية', A.bin), st('تغلّف الصواني...', 8000, E1, 'أغلق الغلاف', A.bench) },
    pick      = { st('تقطف عناقيد العنب...', 10000, E2, 'اقطع العنقود', A.plant), st('تجمع العنب في السلال...', 8000, E1, 'ضع العنقود في السلة', A.bin) },
    dry       = { st('تفرش العنب على المناشر...', 9000, E1, 'افرش العنب', A.bench), st('تقلّب العنب حتى يجفّ...', 9000, E2, 'قلّب العنب', A.bench) },
    box       = { st('تملأ الكراتين بالزبيب...', 9000, E2, 'اغرف الزبيب', A.bin), st('تغلق الكراتين بالشريط...', 8000, E1, 'ألصق الشريط', A.bench) },
    harvest   = { st('تحصد القمح بالمنجل...', 10000, EM, 'اضرب بالمنجل', A.plant), st('تربط حزم القمح...', 8000, E1, 'اربط الحزمة', A.kneel) },
    mill      = { st('تصبّ القمح في المطحنة...', 9000, E1, 'افتح الفتحة', A.meter), st('تطحن القمح وتعبّئ الدقيق...', 9000, EM, 'أوقف الحجر', A.meter) },
    bake      = { st('تعجن العجين وتشكّل الأرغفة...', 9000, EM, 'اعجن', A.bench), st('تخبز الأرغفة في الفرن...', 9000, M1, 'أخرج الخبز في وقته', A.meter) },
    fish      = { st('ترمي الصنارة وتنتظر...', 10000, EM, 'اسحب حين تعلق السمكة', A.fish, P.rod), st('تلفّ الخيط وتخرج السمك...', 8000, M1, 'شدّ الخيط', A.fish, P.rod) },
    fillet    = { st('تنظّف السمك بالسكين...', 9000, EM, 'اقطع على الخط', A.cut), st('تقطّع الشرائح...', 9000, M1, 'افصل الشريحة', A.cut) },
    icepack   = { st('ترصّ السمك في الصواني...', 9000, EM, 'ضع السمكة', A.bin), st('تغطّي السمك بالثلج وتختم العلب...', 8000, M1, 'اختم العلبة', A.bench) },
    mine      = { st('تحفر جدار المنجم...', 10000, M2, 'اضرب الصخرة', A.mine, P.pickaxe), st('تكسر الصخور الكبيرة...', 9000, M1, 'اضرب بقوة', A.mine, P.pickaxe) },
    sort_ore  = { st('تفرز الخام على الحزام...', 9000, M2, 'ارمِ الحجر الفارغ', A.bench), st('تغسل الخام...', 8000, M1, 'اغسل الخام', A.bin) },
    smelt     = { st('تحمّي الفرن وتذيب الخام...', 9000, M1, 'ارفع الحرارة', A.weld), st('تصبّ المعدن في القوالب...', 9000, MH, 'أوقف الصبّ عند الخط', A.bench) },
    shear     = { st('تثبّت الخروف...', 8000, M1, 'ثبّت الخروف', A.kneel), st('تجزّ الصوف...', 10000, M2, 'مرّر المجزّة', A.kneel) },
    weave     = { st('تجهّز خيوط النول...', 8000, M1, 'شدّ الخيط', A.meter), st('تنسج القماش...', 10000, MH, 'ارمِ المكوك', A.meter) },
    sew       = { st('تقصّ القماش...', 8000, M1, 'قصّ على الخط', A.bench), st('تخيط الملابس...', 10000, MH, 'ثبّت الإبرة على الخط', A.meter) },
}


local CONFIG = {
    deposit = 250,          -- paid when the work vehicle is taken, given back when it is returned
    licence = 'driver',     -- every job with a work vehicle needs the car licence (from the driving school; nobody starts with one)

    -- levels: tasks done in that job -> pay raise
    levelNames = { 'مبتدئ', 'متمرّس', 'محترف', 'خبير', 'نخبة' },
    levelBonus = { 0.0, 0.10, 0.20, 0.30, 0.40 },

    -- bonus for bringing the work vehicle back at the end of the shift:
    -- base + per finished round (up to max), times how healthy the vehicle is
    returnBonus = { base = 42, perRound = 21, max = 170 },

    -- jobs anyone may switch away from at the job center (police, EMS and other team jobs can't)
    freeJobs = { unemployed = true, tow = true, garbage = true, delivery = true, chicken = true, raisin = true, bread = true, fishing = true, metals = true, fabrics = true, taxi = true, bus = true, trucker = true, reporter = true, vineyard = true },

    -- the order on the tablet
    order = { 'delivery', 'garbage', 'tow', 'chicken', 'raisin', 'bread', 'fishing', 'metals', 'fabrics' },

    -- EX_Tii level system (exti_level): the starter jobs need no level. The level jobs (chicken, raisins
    -- below in `jobs`) need a level and supplies from the 24/7 store. These four are still being built:
    -- shown as "قريبًا" in the job centre until their update arrives. minLevel = the player level needed.
    upcoming = {},

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
            payText = 'حوالي 80$ لكل مركبة',
            hourText = '1,600$',
            taskWord = { 'مركبة', 'مركبات' },
            levelSteps = { 0, 25, 70, 140, 240 },
            pay = { base = 74, perMeter = 0.013, maxDistance = 45 }, -- cars are 300-950 m away: about 78-86$ each
            abandonedPay = 104,
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
            payText = '17$ لكل كيس (حوالي 42$ لكل حاوية)',
            hourText = '1,600$',
            taskWord = { 'حاوية', 'حاويات' },
            levelSteps = { 0, 45, 120, 240, 420 },
            pay = { perBag = 17 },
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
            payText = 'حوالي 45$ لكل طرد (أكثر للمسافات الأبعد)',
            hourText = '1,600$',
            taskWord = { 'طرد', 'طرود' },
            levelSteps = { 0, 45, 120, 240, 420 },
            pay = { base = 38, perMeter = 0.015, maxDistance = 40 },
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
            -------------------------------------------------------------------
        -- EX_Tii level jobs: 3 stops (collect -> process -> sell), a skill check at every step,
        -- real items in the inventory, supplies from the 24/7 store used up every run.
        -- Every place can be moved in game by an admin with /jobspots (saved in data/spots.json).
        -- chain: the steps. kind = collect | process | sell.
        --   collect: spots (several, each rests `rest` seconds after you used it), give = { item, min, max }, cap = most you may carry
        --   process: take = { item = count }, give = { item = count } (one press = one batch)
        --   sell:    take = { item = count }, price = $ per batch, perHour = most batches bought from you in an hour
        -------------------------------------------------------------------
        chicken = {
            label = 'عامل دواجن',
            company = 'مزارع كلاكن بيل - باليتو',
            icon = 'chicken',
            minLevel = 3,
            -- EX_Tii (Moe's design): clock in with the supervisor = the uniform, no vehicle, no deposit.
            -- 1 poultry kit (24/7) = 1 chicken. The kit is heavy (3.5 kg): pockets (85 kg) carry about 20 = one batch.
            -- Every step does ALL you carry at once with its own mini game (28 s); the score decides how many survive.
            -- The chickens can't be put in a trunk, glovebox, stash or on the ground (only given to a player).
            noVehicle = true,
            noStore = { 'live_chicken', 'slaughtered_chicken', 'packed_chicken' },
            short = 'اشترِ عُدد الدواجن من بقالة 24/7، حوّلها إلى دجاج حي في الحظيرة، اذبحه وعبّئه ثم بِعه للتاجر.',
            steps = {
                'تحدّث مع المشرف لتسجّل دخولك، فتلبس زي العمل تلقائيًا.',
                'اشترِ عُدد الدواجن من بقالة 24/7: كل عدة = دجاجة واحدة (العدة ثقيلة، تحمل حوالي 20).',
                'في الحظيرة تمسك الدجاج وتضعه في الأقفاص: كل العُدد التي معك تصير دجاجًا حيًا.',
                'عند طاولة الذبح تذبح كل الدجاج مرة واحدة، ثم تعبّئه في الصواني عند خط التعبئة.',
                'بِع كل الدجاج المعبأ لتاجر الدواجن: البيعة الكاملة (نصف حمولة على الأقل) = جولة.',
            },
            extra = 'في كل محطة اضغط E وانتظر: حركة العمل وشريط التقدّم ينجزان كل ما تحمله. البيعة الصغيرة (أقل من نصف حمولة) لا تُحسب جولة.',
            payText = '33$ لكل دجاجة معبأة',
            hourText = '2,100$',
            taskWord = { 'جولة', 'جولات' },
            levelSteps = { 0, 15, 40, 80, 140 }, -- (counted in runs: a sale of at least half a load)
            perRound = 20,
            roundMinutes = 17,
            xpRate = 0.286,
            supplies = { 'poultry_kit' },
            hq = {
                label = 'مزرعة الدواجن',
                place = 'باليتو باي',
                blip = { sprite = 126, colour = 0, scale = 0.75, name = 'مزرعة الدواجن' },
                supervisor = { model = 'a_m_m_farmer_01', coords = vec4(-59.10, 6244.70, 31.09, 130.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف حمدان' },
                spawns = {},
                returnRadius = 45.0,
            },
            chain = {
                { id = 'catch', kind = 'batch', label = 'اصطد الدجاج', place = 'حظيرة الدجاج', blip = 126,
                  spot = vec3(-62.90, 6241.46, 31.09),
                  take = 'poultry_kit', give = 'live_chicken', game = 'catch', stages = S.catch, seconds = 0,
                  anim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball' },
                  done = 'صار معك %d دجاجة حية', lost = 'هرب منك %d' },
                { id = 'slaughter', kind = 'batch', label = 'اذبح الدجاج', place = 'طاولة الذبح', blip = 273,
                  spot = vec3(-77.99, 6229.06, 31.09),
                  take = 'live_chicken', give = 'slaughtered_chicken', game = 'slaughter', stages = S.slaughter, seconds = 0,
                  anim = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter' },
                  done = 'ذبحت %d دجاجة', lost = 'تلف منك %d' },
                { id = 'pack', kind = 'batch', label = 'عبّئ الدجاج', place = 'خط التعبئة', blip = 478,
                  spot = vec3(-101.98, 6208.80, 31.03),
                  take = 'slaughtered_chicken', give = 'packed_chicken', game = 'pack', stages = S.pack, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  done = 'عبّأت %d دجاجة', lost = 'سقط منك %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الدجاج', place = 'تاجر الدواجن', blip = 431,
                  spot = vec3(-596.16, -889.32, 25.51),
                  take = 'packed_chicken', price = 33, seconds = 12,
                  anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'تسلّم الدجاج للتاجر وتعدّ الصناديق...', sold = 'بعت %d دجاجة' },
            },
        },

        -------------------------------------------------------------------
        raisin = {
            label = 'عامل زبيب',
            company = 'مزارع مارلو للعنب',
            icon = 'grapes',
            minLevel = 8,
            -- EX_Tii (Moe's design, like chicken): clock in = the uniform, no vehicle. 1 grape kit (24/7) = 1 grape.
            -- The kit weighs 2.8 kg: pockets (85 kg) carry about 30 = one batch. Every step does ALL you carry at
            -- once with its own mini game (28 s); the score decides how many survive. The grapes can't be stored.
            noVehicle = true,
            noStore = { 'grape_bunch', 'raisins', 'raisin_box' },
            short = 'اشترِ عُدد العنب من بقالة 24/7، اقطف العنب من كروم مارلو، جفّفه وعبّئ الزبيب في كراتين ثم بِعه للتاجر.',
            steps = {
                'تحدّث مع المشرف في مزارع مارلو لتسجّل دخولك، فتلبس زي العمل تلقائيًا.',
                'اشترِ عُدد العنب من بقالة 24/7: كل عدة = عنقود واحد (تحمل حوالي 30).',
                'عند الكروم تقطف كل العناقيد مرة واحدة وتجمعها في السلال.',
                'عند مناشر التجفيف تفرش العنب وتقلّبه حتى يصير زبيبًا، ثم تعبّئه في الكراتين عند طاولة التعبئة.',
                'بِع الكراتين لتاجر الزبيب: البيعة الكاملة (نصف حمولة على الأقل) = جولة.',
            },
            extra = 'في كل محطة اضغط E وانتظر: حركة العمل وشريط التقدّم ينجزان كل ما تحمله. البيعة الصغيرة (أقل من نصف حمولة) لا تُحسب جولة.',
            payText = '22$ لكل كرتونة زبيب',
            hourText = '2,600$',
            taskWord = { 'جولة', 'جولات' },
            levelSteps = { 0, 15, 40, 80, 140 }, -- (counted in runs)
            perRound = 30,
            roundMinutes = 13,
            xpRate = 0.23,
            supplies = { 'grape_kit' },
            hq = {
                label = 'مزارع مارلو للعنب',
                place = 'تونغفا هيلز',
                blip = { sprite = 85, colour = 0, scale = 0.75, name = 'مزارع العنب' },
                supervisor = { model = 'a_m_m_farmer_01', coords = vec4(-1928.81, 2059.53, 140.84, 260.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف مروان' },
                spawns = {},
                returnRadius = 45.0,
            },
            chain = {
                { id = 'pick', kind = 'batch', label = 'اقطف العنب', place = 'كروم العنب', blip = 85,
                  spot = vec3(-1875.41, 2100.37, 138.86),
                  take = 'grape_kit', give = 'grape_bunch', game = 'pick', stages = S.pick, seconds = 0,
                  anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
                  done = 'قطفت %d عنقودًا', lost = 'سقط منك %d' },
                { id = 'dry', kind = 'batch', label = 'جفّف العنب', place = 'مناشر التجفيف', blip = 478,
                  spot = vec3(-1881.50, 2062.60, 135.92),
                  take = 'grape_bunch', give = 'raisins', game = 'dry', stages = S.dry, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  done = 'جفّفت %d', lost = 'احترق أو فسد %d' },
                { id = 'box', kind = 'batch', label = 'عبّئ الزبيب', place = 'طاولة التعبئة', blip = 478,
                  spot = vec3(-1876.00, 2061.30, 135.92),
                  take = 'raisins', give = 'raisin_box', game = 'box', stages = S.box, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  done = 'عبّأت %d كرتونة', lost = 'رميت %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الزبيب', place = 'تاجر الزبيب', blip = 431,
                  spot = vec3(-596.16, -889.32, 25.51),
                  pedModel = 'a_m_m_farmer_01', take = 'raisin_box', price = 22, seconds = 12,
                  anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'تسلّم الكراتين للتاجر...', sold = 'بعت %d كرتونة زبيب' },
            },
        },
        -------------------------------------------------------------------
        -- EX_Tii: the four level jobs that were "coming soon" (built like chicken / raisin).
        -- Places are a first guess: move any of them in game with /jobspots.
        -------------------------------------------------------------------
        bread = {
            label = 'خبّاز',
            company = 'مخابز لوس سانتوس',
            icon = 'wheat',
            minLevel = 15,
            noVehicle = true,
            noStore = { 'wheat_bundle', 'flour_bag', 'bread_loaf' },
            short = 'اشترِ الخميرة من بقالة 24/7، احصد القمح في حقول غريبسيد، اطحنه في المطحنة واخبز الخبز ثم بِعه.',
            steps = {
                'تحدّث مع المشرف في مزرعة غريبسيد لتسجّل دخولك، فتلبس زي العمل تلقائيًا.',
                'اشترِ أكياس الخميرة من بقالة 24/7: كل كيس = رغيف واحد (تحمل حوالي 25).',
                'في الحقل تحصد القمح بالمنجل وتربطه حزمًا.',
                'في المطحنة تطحن القمح وتعبّئ الدقيق، ثم تعجن وتخبز الأرغفة في الفرن.',
                'بِع الخبز لتاجر الخبز: البيعة الكاملة (نصف حمولة على الأقل) = جولة.',
            },
            extra = 'في كل محطة اضغط E وانتظر: حركة العمل وشريط التقدّم ينجزان كل ما تحمله. البيعة الصغيرة (أقل من نصف حمولة) لا تُحسب جولة.',
            payText = '33$ لكل رغيف',
            hourText = '3,200$',
            taskWord = { 'جولة', 'جولات' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 25,
            roundMinutes = 14,
            xpRate = 0.19,
            supplies = { 'yeast_pack' },
            hq = {
                label = 'مزرعة القمح', place = 'غريبسيد',
                blip = { sprite = 285, colour = 46, scale = 0.75, name = 'مزرعة القمح' },
                supervisor = { model = 'a_m_m_farmer_01', coords = vec4(2029.95, 4980.42, 42.10, 225.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف سعيد' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'harvest', kind = 'batch', label = 'احصد القمح', place = 'حقل القمح', blip = 285, spot = vec3(2080.00, 4930.00, 40.90),
                  take = 'yeast_pack', give = 'wheat_bundle', game = 'harvest', stages = S.harvest, seconds = 0,
                  anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' }, done = 'حصدت %d حزمة', lost = 'سقط منك %d' },
                { id = 'mill', kind = 'batch', label = 'اطحن القمح', place = 'المطحنة', blip = 478, spot = vec3(2016.00, 4973.00, 41.60),
                  take = 'wheat_bundle', give = 'flour_bag', game = 'mill', stages = S.mill, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'طحنت %d كيس دقيق', lost = 'فسد %d' },
                { id = 'bake', kind = 'batch', label = 'اخبز الخبز', place = 'الفرن', blip = 478, spot = vec3(2005.00, 4986.00, 42.00),
                  take = 'flour_bag', give = 'bread_loaf', game = 'bake', stages = S.bake, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'خبزت %d رغيفًا', lost = 'احترق %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الخبز', place = 'تاجر الخبز', blip = 431, spot = vec3(-593.00, -893.00, 25.50),
                  pedModel = 's_m_y_chef_01', take = 'bread_loaf', price = 33, seconds = 12, anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'تسلّم الخبز للتاجر...', sold = 'بعت %d رغيفًا' },
            },
        },

        fishing = {
            label = 'صياد سمك',
            company = 'سوق السمك في لوس سانتوس',
            icon = 'fish',
            minLevel = 22,
            noVehicle = true,
            noStore = { 'raw_fish', 'fish_fillet', 'fish_pack' },
            short = 'اشترِ الطُعم من بقالة 24/7، اصطد السمك بالصنارة من رصيف ديل بيرو، نظّفه وعبّئه على الثلج ثم بِعه في سوق السمك.',
            steps = {
                'تحدّث مع المشرف عند رصيف ديل بيرو لتسجّل دخولك.',
                'اشترِ علب الطُعم من بقالة 24/7: كل علبة = سمكة واحدة (تحمل حوالي 24).',
                'في آخر الرصيف ترمي الصنارة وتخرج السمك.',
                'على طاولة التنظيف تنظّف السمك وتقطّعه شرائح، ثم ترصّه على الثلج وتختم العلب.',
                'بِع العلب في سوق السمك: البيعة الكاملة (نصف حمولة على الأقل) = جولة.',
            },
            extra = 'في كل محطة اضغط E وانتظر: حركة العمل وشريط التقدّم ينجزان كل ما تحمله. البيعة الصغيرة (أقل من نصف حمولة) لا تُحسب جولة.',
            payText = '41$ لكل علبة سمك',
            hourText = '3,900$',
            taskWord = { 'جولة', 'جولات' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 24,
            roundMinutes = 14,
            xpRate = 0.154,
            supplies = { 'fish_bait' },
            hq = {
                label = 'رصيف الصيد', place = 'ديل بيرو',
                blip = { sprite = 68, colour = 3, scale = 0.75, name = 'رصيف الصيد' },
                supervisor = { model = 's_m_m_dockwork_01', coords = vec4(-1612.60, -1068.00, 13.02, 140.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف بحري' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'fish', kind = 'batch', label = 'اصطد السمك', place = 'آخر الرصيف', blip = 68, spot = vec3(-1850.50, -1248.80, 8.62),
                  take = 'fish_bait', give = 'raw_fish', game = 'fish', stages = S.fish, seconds = 0,
                  anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c' }, done = 'اصطدت %d سمكة', lost = 'هربت %d' },
                { id = 'clean', kind = 'batch', label = 'نظّف السمك', place = 'طاولة التنظيف', blip = 478, spot = vec3(-1670.00, -1110.00, 13.15),
                  take = 'raw_fish', give = 'fish_fillet', game = 'fillet', stages = S.fillet, seconds = 0,
                  anim = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter' }, done = 'نظّفت %d سمكة', lost = 'تلف %d' },
                { id = 'pack', kind = 'batch', label = 'عبّئ السمك', place = 'صناديق الثلج', blip = 478, spot = vec3(-1665.00, -1105.00, 13.15),
                  take = 'fish_fillet', give = 'fish_pack', game = 'icepack', stages = S.icepack, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'عبّأت %d علبة', lost = 'فسد %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع السمك', place = 'سوق السمك', blip = 431, spot = vec3(-1038.90, -1396.70, 5.55),
                  pedModel = 's_m_y_dockwork_01', take = 'fish_pack', price = 41, seconds = 12, anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'تسلّم علب السمك...', sold = 'بعت %d علبة سمك' },
            },
        },

        metals = {
            label = 'عامل معادن',
            company = 'منجم ديفيس كوارتز',
            icon = 'pickaxe',
            minLevel = 30,
            noVehicle = true,
            noStore = { 'ore_rock', 'washed_ore', 'copper_bar', 'iron_bar', 'gold_bar' },
            short = 'اشترِ بطاريات مصباح الرأس من بقالة 24/7، احفر الصخور في منجم ديفيس كوارتز، افرز الخام واصهره في المسبك ثم بِع النحاس والحديد والذهب.',
            steps = {
                'تحدّث مع المشرف في منجم ديفيس كوارتز لتسجّل دخولك.',
                'اشترِ بطاريات مصباح الرأس من بقالة 24/7: كل بطارية = صخرة واحدة (الصخور ثقيلة، تحمل حوالي 20).',
                'عند جدار المنجم تحفر الصخور بالفأس.',
                'عند حزام الفرز تفرز الخام وتغسله، ثم تصهره وتصبّه في القوالب في المسبك.',
                'بِع السبائك في مكتب المسبك (نحاس وحديد، وأحيانًا ذهب): البيعة الكاملة = جولة.',
            },
            extra = 'في كل محطة اضغط E وانتظر: حركة العمل وشريط التقدّم ينجزان كل ما تحمله. البيعة الصغيرة (أقل من نصف حمولة) لا تُحسب جولة.',
            payText = 'نحاس 54$ · حديد 48$ · ذهب 280$',
            hourText = '4,700$',
            taskWord = { 'جولة', 'جولات' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 20,
            roundMinutes = 15,
            xpRate = 0.128,
            supplies = { 'headlamp_battery' },
            hq = {
                label = 'منجم ديفيس كوارتز', place = 'سان شيانسكي',
                blip = { sprite = 618, colour = 5, scale = 0.75, name = 'المنجم' },
                supervisor = { model = 's_m_y_construct_01', coords = vec4(2569.80, 2719.60, 42.86, 210.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف صخر' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'mine', kind = 'batch', label = 'احفر الصخور', place = 'جدار المنجم', blip = 618, spot = vec3(2950.00, 2790.00, 40.90),
                  take = 'headlamp_battery', give = 'ore_rock', game = 'mine', stages = S.mine, seconds = 0,
                  anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' }, done = 'حفرت %d صخرة', lost = 'تفتّت %d' },
                { id = 'sort', kind = 'batch', label = 'افرز الخام', place = 'حزام الفرز', blip = 478, spot = vec3(2964.00, 2753.00, 43.30),
                  take = 'ore_rock', give = 'washed_ore', game = 'sort_ore', stages = S.sort_ore, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'فرزت %d', lost = 'رميت %d صخرًا بلا معدن' },
                { id = 'smelt', kind = 'batch', label = 'اصهر الخام', place = 'المسبك', blip = 478, spot = vec3(1083.50, -1974.00, 31.00),
                  take = 'washed_ore', give = 'copper_bar', game = 'smelt', stages = S.smelt, seconds = 0,
                  giveMix = { { 'copper_bar', 60 }, { 'iron_bar', 35 }, { 'gold_bar', 5 } },
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'صببت %d سبيكة', lost = 'فسد %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع السبائك', place = 'مكتب المسبك', blip = 431, spot = vec3(1090.00, -1993.00, 30.90),
                  pedModel = 's_m_y_construct_02', take = 'copper_bar', price = 54, takeAlso = { iron_bar = 48, gold_bar = 280 }, seconds = 12,
                  anim = { dict = 'mp_common', clip = 'givetake1_a' }, progress = 'يزن التاجر السبائك...', sold = 'بعت %d سبيكة' },
            },
        },

        fabrics = {
            label = 'عامل أقمشة',
            company = 'مصنع نسيج لوس سانتوس',
            icon = 'spool',
            minLevel = 40,
            noVehicle = true,
            noStore = { 'raw_wool', 'fabric_roll', 'sewn_clothes' },
            short = 'اشترِ بكرات الخيط من بقالة 24/7، اجمع الصوف من مزرعة غريبسيد، انسج القماش وخِط الملابس في المصنع ثم بِعها.',
            steps = {
                'تحدّث مع المشرف في مصنع النسيج في لا ميسا لتسجّل دخولك.',
                'اشترِ بكرات الخيط من بقالة 24/7: كل بكرة = قطعة ملابس واحدة (تحمل حوالي 24).',
                'في مزرعة غريبسيد تثبّت الخراف وتجزّ صوفها.',
                'في المصنع تنسج القماش على النول، ثم تقصّه وتخيط الملابس على الماكينة.',
                'بِع الملابس لمتجر بينكو: البيعة الكاملة (نصف حمولة على الأقل) = جولة.',
            },
            extra = 'في كل محطة اضغط E وانتظر: حركة العمل وشريط التقدّم ينجزان كل ما تحمله. البيعة الصغيرة (أقل من نصف حمولة) لا تُحسب جولة.',
            payText = '63$ لكل قطعة',
            hourText = '5,600$',
            taskWord = { 'جولة', 'جولات' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 22,
            roundMinutes = 14,
            xpRate = 0.107,
            supplies = { 'thread_spool' },
            hq = {
                label = 'مصنع النسيج', place = 'لا ميسا',
                blip = { sprite = 366, colour = 27, scale = 0.75, name = 'مصنع النسيج' },
                supervisor = { model = 's_f_y_factory_01', coords = vec4(713.40, -967.70, 30.40, 180.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرفة سلمى' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'shear', kind = 'batch', label = 'جزّ الصوف', place = 'حظيرة الخراف', blip = 141, spot = vec3(2441.60, 4976.40, 46.80),
                  take = 'thread_spool', give = 'raw_wool', game = 'shear', stages = S.shear, seconds = 0,
                  anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' }, done = 'جززت %d', lost = 'ضاع %d' },
                { id = 'weave', kind = 'batch', label = 'انسج القماش', place = 'النول', blip = 478, spot = vec3(716.00, -962.00, 30.40),
                  take = 'raw_wool', give = 'fabric_roll', game = 'weave', stages = S.weave, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'نسجت %d لفة', lost = 'تمزّق %d' },
                { id = 'sew', kind = 'batch', label = 'خِط الملابس', place = 'ماكينة الخياطة', blip = 478, spot = vec3(710.00, -960.00, 30.40),
                  take = 'fabric_roll', give = 'sewn_clothes', game = 'sew', stages = S.sew, seconds = 0,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'خِطت %d قطعة', lost = 'أفسدت %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الملابس', place = 'متجر بينكو', blip = 431, spot = vec3(425.60, -806.30, 29.50),
                  pedModel = 's_f_y_shop_low', take = 'sewn_clothes', price = 63, seconds = 12, anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'يعدّ المتجر القطع...', sold = 'بعت %d قطعة' },
            },
        },
    },
}

-- every station takes as long as its stages (the server checks this time really passed)
for _, job in pairs(CONFIG.jobs) do
    for _, step in ipairs(job.chain or {}) do
        if step.stages then
            local ms = 0
            for _, sg in ipairs(step.stages) do ms = ms + sg.ms end
            step.seconds = math.floor(ms / 1000)
        end
    end
end

return CONFIG
