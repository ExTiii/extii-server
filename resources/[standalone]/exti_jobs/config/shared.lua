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
    freeJobs = { unemployed = true, tow = true, garbage = true, delivery = true, chicken = true, raisin = true, taxi = true, bus = true, trucker = true, reporter = true, vineyard = true },

    -- the order on the tablet
    order = { 'delivery', 'garbage', 'tow', 'chicken', 'raisin' },

    -- EX_Tii level system (exti_level): the starter jobs need no level. The level jobs (chicken, raisins
    -- below in `jobs`) need a level and supplies from the 24/7 store. These four are still being built:
    -- shown as "قريبًا" in the job centre until their update arrives. minLevel = the player level needed.
    upcoming = {
        { name = 'bread', label = 'خبّاز', company = 'مخابز لوس سانتوس', icon = 'wheat', minLevel = 15, hourText = '3,100$',
          short = 'احصد القمح في حقول غريبسيد، اطحنه في المطحنة واخبز الخبز ثم بِعه.', supplies = { 'خميرة' }, soon = true },
        { name = 'fishing', label = 'صياد سمك', company = 'سوق السمك في لوس سانتوس', icon = 'fish', minLevel = 22, hourText = '3,300$',
          short = 'اصطد السمك بالقارب قرب الساحل، نظّفه ثم بِعه في سوق السمك.', supplies = { 'طُعم' }, soon = true },
        { name = 'metals', label = 'عامل معادن', company = 'منجم ديفيس كوارتز', icon = 'pickaxe', minLevel = 30, hourText = '3,500$',
          short = 'احفر الصخور في المنجم، اغسلها واصهرها في المسبك ثم بِع النحاس والحديد والذهب.', supplies = { 'بطاريات مصباح الرأس' }, soon = true },
        { name = 'fabrics', label = 'عامل أقمشة', company = 'مصنع نسيج لوس سانتوس', icon = 'spool', minLevel = 40, hourText = '3,700$',
          short = 'اجمع الصوف من مزرعة غريبسيد، انسج القماش وخِط الملابس ثم بِعها.', supplies = { 'بكرات خيط' }, soon = true },
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
            short = 'اصطد الدجاج الحي في مزرعة باليتو، اذبحه ونظّفه، عبّئه في صوانٍ ثم بِعه لتاجر الجملة في المدينة.',
            steps = {
                'اذهب إلى مزرعة الدواجن في باليتو وتحدّث مع المشرف لتبدأ المناوبة وتستلم شاحنة النقل.',
                'اصطد الدجاج في الحظيرة: قف في دائرة ذهبية، اضغط E ونجح في التحدي.',
                'عند طاولة الذبح حوّل كل 5 دجاجات حية إلى دجاج مذبوح.',
                'عند خط التعبئة عبّئ كل 5 دجاجات مذبوحة في صينية (تحتاج صينية تغليف لكل 5).',
                'قُد الشاحنة إلى تاجر الجملة في ليتل سول وبِع الصواني.',
            },
            extra = 'تحتاج من بقالة 24/7: صواني تغليف (صينية لكل 5 دجاجات). الدجاج في حقيبتك حقيقي: يمكن أن يُسرق منك.',
            payText = '200$ لكل صينية (5 دجاجات)',
            hourText = '2,700$',
            taskWord = { 'صينية', 'صوانٍ' },
            levelSteps = { 0, 30, 80, 160, 280 },
            perRound = 4,
            roundMinutes = 17,
            xpRate = 0.21,
            supplies = { 'packing_tray' },
            vehicle = { model = 'benson', label = 'شاحنة نقل الدواجن', plate = 'CLK', blipName = 'شاحنة الدواجن' },
            hq = {
                label = 'مزرعة الدواجن',
                place = 'باليتو باي',
                blip = { sprite = 126, colour = 0, scale = 0.75, name = 'مزرعة الدواجن' },
                supervisor = { model = 'a_m_m_farmer_01', coords = vec4(-59.10, 6244.70, 31.09, 130.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف حمدان' },
                spawns = {},            -- empty: the truck appears on the nearest road (or where /jobspots put it)
                returnRadius = 45.0,
            },
            chain = {
                { id = 'catch', kind = 'collect', label = 'اصطد الدجاج', place = 'حظيرة الدجاج', blip = 126,
                  spots = { vec3(-64.40, 6240.20, 31.09), vec3(-61.40, 6242.70, 31.09), vec3(-63.90, 6243.10, 31.09), vec3(-61.90, 6239.80, 31.09) },
                  give = { item = 'live_chicken', min = 2, max = 3 }, cap = 20, rest = 30,
                  time = 4500, skill = { 'easy', 'easy' }, anim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball' },
                  progress = 'تمسك الدجاجة...', fail = 'هربت الدجاجة! حاول مرة أخرى' },
                { id = 'slaughter', kind = 'process', label = 'اذبح الدجاج', place = 'طاولة الذبح', blip = 273,
                  spot = vec3(-77.99, 6229.06, 31.09),
                  take = { live_chicken = 5 }, give = { slaughtered_chicken = 5 },
                  time = 7000, skill = { 'easy', 'medium' }, anim = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter' },
                  progress = 'تذبح وتنظّف الدجاج...', fail = 'انزلقت السكين، أعد المحاولة' },
                { id = 'pack', kind = 'process', label = 'عبّئ الدجاج', place = 'خط التعبئة', blip = 478,
                  spot = vec3(-101.98, 6208.80, 31.03),
                  take = { slaughtered_chicken = 5, packing_tray = 1 }, give = { packed_chicken = 1 },
                  time = 7000, skill = { 'easy', 'medium' }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  progress = 'تعبّئ الدجاج في الصينية...', fail = 'تمزّق الغلاف، أعد المحاولة' },
                { id = 'sell', kind = 'sell', label = 'بِع الدجاج', place = 'تاجر الجملة - ليتل سول', blip = 431,
                  spot = vec3(-596.16, -889.32, 25.51),
                  take = { packed_chicken = 1 }, price = 200, perHour = 17,
                  time = 3500, skill = { 'easy' }, anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'تسلّم الصينية للتاجر...', fail = 'سقطت الصينية، التقطها وحاول مرة أخرى' },
            },
        },

        -------------------------------------------------------------------
        raisin = {
            label = 'عامل زبيب',
            company = 'مزارع مارلو للعنب',
            icon = 'grapes',
            minLevel = 8,
            short = 'اقطف العنب من كروم مارلو، جفّفه على المناشر في المعصرة، عبّئ الزبيب في كراتين ثم بِعه لتاجر الجملة.',
            steps = {
                'اذهب إلى مزارع مارلو للعنب وتحدّث مع المشرف لتبدأ المناوبة وتستلم الشاحنة.',
                'اقطف العنب بين صفوف الكروم: كل دائرة ذهبية تعطيك عناقيد، ثم ترتاح قليلًا.',
                'عند مناشر التجفيف حوّل كل 5 عناقيد إلى زبيب.',
                'عند طاولة التعبئة عبّئ كل 5 زبيب في كرتونة (تحتاج كرتونة فارغة لكل علبة).',
                'قُد الشاحنة إلى تاجر الجملة في ليتل سول وبِع الكراتين.',
            },
            extra = 'تحتاج من بقالة 24/7: كراتين فارغة (كرتونة لكل 5 زبيب). العنب والزبيب في حقيبتك حقيقيان: يمكن أن يُسرقا منك.',
            payText = '125$ لكل كرتونة زبيب',
            hourText = '2,900$',
            taskWord = { 'كرتونة', 'كراتين' },
            levelSteps = { 0, 45, 120, 240, 420 },
            perRound = 6,
            roundMinutes = 15,
            xpRate = 0.21,
            supplies = { 'empty_carton' },
            vehicle = { model = 'sadler', label = 'بيك أب المزرعة', plate = 'VIN', blipName = 'بيك أب المزرعة' },
            hq = {
                label = 'مزارع مارلو للعنب',
                place = 'تونغفا هيلز',
                blip = { sprite = 85, colour = 0, scale = 0.75, name = 'مزارع العنب' },
                supervisor = { model = 'a_m_m_farmer_01', coords = vec4(-1928.81, 2059.53, 140.84, 260.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف مروان' },
                spawns = {},
                returnRadius = 45.0,
            },
            chain = {
                { id = 'pick', kind = 'collect', label = 'اقطف العنب', place = 'كروم العنب', blip = 85,
                  spots = {
                      vec3(-1875.41, 2100.37, 138.86), vec3(-1908.69, 2107.48, 131.31), vec3(-1866.04, 2112.64, 134.41), vec3(-1907.76, 2125.35, 124.03),
                      vec3(-1850.31, 2142.95, 122.30), vec3(-1888.22, 2164.51, 114.81), vec3(-1835.52, 2180.59, 104.88), vec3(-1891.98, 2208.35, 94.56),
                      vec3(-1720.37, 2182.03, 106.18), vec3(-1808.52, 2173.14, 107.63), vec3(-1784.22, 2222.80, 92.86), vec3(-1889.13, 2250.05, 79.63),
                      vec3(-1861.16, 2254.32, 81.04), vec3(-1886.75, 2272.45, 70.81), vec3(-1845.49, 2274.63, 73.33), vec3(-1687.28, 2195.76, 97.87),
                      vec3(-1741.18, 2173.22, 114.39), vec3(-1743.17, 2141.11, 121.18), vec3(-1813.84, 2089.57, 134.21), vec3(-1698.71, 2150.65, 110.41),
                  },
                  give = { item = 'grape_bunch', min = 3, max = 4 }, cap = 30, rest = 240,
                  time = 5000, skill = { 'easy', 'easy' }, anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
                  progress = 'تقطف العناقيد...', fail = 'سقطت العناقيد على الأرض، حاول مرة أخرى' },
                { id = 'dry', kind = 'process', label = 'جفّف العنب', place = 'مناشر التجفيف', blip = 478,
                  spot = vec3(-1881.50, 2062.60, 135.92),
                  take = { grape_bunch = 5 }, give = { raisins = 5 },
                  time = 7000, skill = { 'easy', 'medium' }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  progress = 'تنشر العنب ليجفّ...', fail = 'تبعثر العنب، أعد المحاولة' },
                { id = 'box', kind = 'process', label = 'عبّئ الزبيب', place = 'طاولة التعبئة', blip = 478,
                  spot = vec3(-1876.00, 2061.30, 135.92),
                  take = { raisins = 5, empty_carton = 1 }, give = { raisin_box = 1 },
                  time = 6000, skill = { 'easy', 'medium' }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  progress = 'تعبّئ الزبيب في الكرتونة...', fail = 'انقلبت الكرتونة، أعد المحاولة' },
                { id = 'sell', kind = 'sell', label = 'بِع الزبيب', place = 'تاجر الجملة - ليتل سول', blip = 431,
                  spot = vec3(-596.16, -889.32, 25.51),
                  take = { raisin_box = 1 }, price = 125, perHour = 28,
                  time = 3500, skill = { 'easy' }, anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'تسلّم الكرتونة للتاجر...', fail = 'سقطت الكرتونة، التقطها وحاول مرة أخرى' },
            },
        },
    },
}
