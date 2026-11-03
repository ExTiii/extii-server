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
                'في الحظيرة تتحوّل كل العُدد التي معك إلى دجاج حي: امسك الدجاج الهارب في اللعبة.',
                'عند طاولة الذبح تذبح كل الدجاج مرة واحدة: اضغط في اللحظة الصحيحة.',
                'عند خط التعبئة اسحب الدجاج إلى الصواني، ثم بِع كل الدجاج المعبأ للتاجر.',
            },
            extra = 'كلما أتقنت الألعاب خسرت دجاجًا أقل. الدجاج لا يوضع في صندوق السيارة أو المخزن أو على الأرض.',
            payText = '50$ لكل دجاجة معبأة',
            hourText = '2,700$',
            taskWord = { 'دجاجة', 'دجاجات' },
            levelSteps = { 0, 15, 40, 80, 140 }, -- (counted in sales)
            perRound = 20,
            roundMinutes = 17,
            xpRate = 0.20,
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
                  take = 'poultry_kit', give = 'live_chicken', game = 'catch', seconds = 28,
                  anim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball' },
                  done = 'صار معك %d دجاجة حية', lost = 'هرب منك %d' },
                { id = 'slaughter', kind = 'batch', label = 'اذبح الدجاج', place = 'طاولة الذبح', blip = 273,
                  spot = vec3(-77.99, 6229.06, 31.09),
                  take = 'live_chicken', give = 'slaughtered_chicken', game = 'slaughter', seconds = 28,
                  anim = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter' },
                  done = 'ذبحت %d دجاجة', lost = 'تلف منك %d' },
                { id = 'pack', kind = 'batch', label = 'عبّئ الدجاج', place = 'خط التعبئة', blip = 478,
                  spot = vec3(-101.98, 6208.80, 31.03),
                  take = 'slaughtered_chicken', give = 'packed_chicken', game = 'pack', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  done = 'عبّأت %d دجاجة', lost = 'سقط منك %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الدجاج', place = 'تاجر الدواجن', blip = 431,
                  spot = vec3(-596.16, -889.32, 25.51),
                  take = 'packed_chicken', price = 50, seconds = 20,
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
                'عند الكروم تقطف كل العناقيد مرة واحدة: اضغط الحرف الظاهر على كل عنقود بسرعة.',
                'عند مناشر التجفيف حافظ على الحرارة في المنطقة الذهبية (اضغط مسافة للتسخين).',
                'عند طاولة التعبئة اصنع الكراتين: ارفع الجوانب، املأها بالمغرفة، وأغلقها بالشريط، ثم بِعها للتاجر.',
            },
            extra = 'كلما أتقنت الألعاب خسرت أقل. العنب والزبيب لا يوضعان في صندوق السيارة أو المخزن أو على الأرض.',
            payText = '38$ لكل كرتونة زبيب',
            hourText = '2,900$',
            taskWord = { 'كرتونة', 'كراتين' },
            levelSteps = { 0, 15, 40, 80, 140 }, -- (counted in sales)
            perRound = 30,
            roundMinutes = 13,
            xpRate = 0.18,
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
                  take = 'grape_kit', give = 'grape_bunch', game = 'pick', seconds = 28,
                  anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
                  done = 'قطفت %d عنقودًا', lost = 'سقط منك %d' },
                { id = 'dry', kind = 'batch', label = 'جفّف العنب', place = 'مناشر التجفيف', blip = 478,
                  spot = vec3(-1881.50, 2062.60, 135.92),
                  take = 'grape_bunch', give = 'raisins', game = 'dry', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  done = 'جفّفت %d', lost = 'احترق أو فسد %d' },
                { id = 'box', kind = 'batch', label = 'عبّئ الزبيب', place = 'طاولة التعبئة', blip = 478,
                  spot = vec3(-1876.00, 2061.30, 135.92),
                  take = 'raisins', give = 'raisin_box', game = 'box', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                  done = 'عبّأت %d كرتونة', lost = 'رميت %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الزبيب', place = 'تاجر الزبيب', blip = 431,
                  spot = vec3(-596.16, -889.32, 25.51),
                  take = 'raisin_box', price = 38, seconds = 20,
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
                'في الحقل احصد السنابل الذهبية الناضجة بالمنجل قبل أن تسقط.',
                'في المطحنة أبقِ سرعة حجر الطاحون في المنطقة الخضراء ليصير الدقيق ناعمًا.',
                'في الفرن أخرج كل رغيف حين يصير ذهبيًا (لا نيئًا ولا محروقًا)، ثم بِع الخبز للتاجر.',
            },
            extra = 'كلما أتقنت الألعاب خسرت أقل. القمح والدقيق والخبز لا توضع في صندوق السيارة أو المخزن.',
            payText = '38$ لكل رغيف',
            hourText = '3,100$',
            taskWord = { 'رغيف', 'أرغفة' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 25,
            roundMinutes = 14,
            xpRate = 0.20,
            supplies = { 'yeast_pack' },
            hq = {
                label = 'مزرعة القمح', place = 'غريبسيد',
                blip = { sprite = 285, colour = 46, scale = 0.75, name = 'مزرعة القمح' },
                supervisor = { model = 'a_m_m_farmer_01', coords = vec4(2029.95, 4980.42, 42.10, 225.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف سعيد' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'harvest', kind = 'batch', label = 'احصد القمح', place = 'حقل القمح', blip = 285, spot = vec3(2080.00, 4930.00, 40.90),
                  take = 'yeast_pack', give = 'wheat_bundle', game = 'harvest', seconds = 28,
                  anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' }, done = 'حصدت %d حزمة', lost = 'سقط منك %d' },
                { id = 'mill', kind = 'batch', label = 'اطحن القمح', place = 'المطحنة', blip = 478, spot = vec3(2016.00, 4973.00, 41.60),
                  take = 'wheat_bundle', give = 'flour_bag', game = 'mill', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'طحنت %d كيس دقيق', lost = 'فسد %d' },
                { id = 'bake', kind = 'batch', label = 'اخبز الخبز', place = 'الفرن', blip = 478, spot = vec3(2005.00, 4986.00, 42.00),
                  take = 'flour_bag', give = 'bread_loaf', game = 'bake', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'خبزت %d رغيفًا', lost = 'احترق %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الخبز', place = 'تاجر الخبز', blip = 431, spot = vec3(-593.00, -893.00, 25.50),
                  take = 'bread_loaf', price = 38, seconds = 20, anim = { dict = 'mp_common', clip = 'givetake1_a' },
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
                'في آخر الرصيف ارمِ الصنارة: حين يغطس العوّام اضغط بسرعة، ثم أبقِ الشدّ في المنطقة الخضراء حتى تخرج السمكة.',
                'على طاولة التنظيف مرّر السكين على خط البطن لكل سمكة.',
                'رتّب السمك على الثلج في الصندوق قبل أن يسخن، ثم بِعه في سوق السمك.',
            },
            extra = 'كلما أتقنت الألعاب خسرت أقل. السمك لا يوضع في صندوق السيارة أو المخزن.',
            payText = '42$ لكل علبة سمك',
            hourText = '3,300$',
            taskWord = { 'علبة', 'علب' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 24,
            roundMinutes = 14,
            xpRate = 0.20,
            supplies = { 'fish_bait' },
            hq = {
                label = 'رصيف الصيد', place = 'ديل بيرو',
                blip = { sprite = 68, colour = 3, scale = 0.75, name = 'رصيف الصيد' },
                supervisor = { model = 's_m_m_dockwork_01', coords = vec4(-1612.60, -1068.00, 13.02, 140.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف بحري' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'fish', kind = 'batch', label = 'اصطد السمك', place = 'آخر الرصيف', blip = 68, spot = vec3(-1850.50, -1248.80, 8.62),
                  take = 'fish_bait', give = 'raw_fish', game = 'fish', seconds = 28,
                  anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c' }, done = 'اصطدت %d سمكة', lost = 'هربت %d' },
                { id = 'clean', kind = 'batch', label = 'نظّف السمك', place = 'طاولة التنظيف', blip = 478, spot = vec3(-1670.00, -1110.00, 13.15),
                  take = 'raw_fish', give = 'fish_fillet', game = 'fillet', seconds = 28,
                  anim = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter' }, done = 'نظّفت %d سمكة', lost = 'تلف %d' },
                { id = 'pack', kind = 'batch', label = 'عبّئ السمك', place = 'صناديق الثلج', blip = 478, spot = vec3(-1665.00, -1105.00, 13.15),
                  take = 'fish_fillet', give = 'fish_pack', game = 'icepack', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'عبّأت %d علبة', lost = 'فسد %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع السمك', place = 'سوق السمك', blip = 431, spot = vec3(-1038.90, -1396.70, 5.55),
                  take = 'fish_pack', price = 42, seconds = 20, anim = { dict = 'mp_common', clip = 'givetake1_a' },
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
                'في جدار المنجم اضرب النقاط اللامعة بالفأس قبل أن تختفي.',
                'عند حزام الفرز ضع كل حجر في صندوقه الصحيح (1 نحاس · 2 حديد · 3 صخر).',
                'في المسبك صبّ المعدن في القوالب وأوقف عند الخط، ثم بِع السبائك: نحاس وحديد، وأحيانًا ذهب.',
            },
            extra = 'السبائك تخرج مختلطة: أغلبها نحاس وحديد، والذهب نادر وسعره أعلى بكثير.',
            payText = 'نحاس 50$ · حديد 45$ · ذهب 260$',
            hourText = '3,500$',
            taskWord = { 'سبيكة', 'سبائك' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 20,
            roundMinutes = 15,
            xpRate = 0.22,
            supplies = { 'headlamp_battery' },
            hq = {
                label = 'منجم ديفيس كوارتز', place = 'سان شيانسكي',
                blip = { sprite = 618, colour = 5, scale = 0.75, name = 'المنجم' },
                supervisor = { model = 's_m_y_construct_01', coords = vec4(2569.80, 2719.60, 42.86, 210.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرف صخر' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'mine', kind = 'batch', label = 'احفر الصخور', place = 'جدار المنجم', blip = 618, spot = vec3(2950.00, 2790.00, 40.90),
                  take = 'headlamp_battery', give = 'ore_rock', game = 'mine', seconds = 28,
                  anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' }, done = 'حفرت %d صخرة', lost = 'تفتّت %d' },
                { id = 'sort', kind = 'batch', label = 'افرز الخام', place = 'حزام الفرز', blip = 478, spot = vec3(2964.00, 2753.00, 43.30),
                  take = 'ore_rock', give = 'washed_ore', game = 'sort_ore', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'فرزت %d', lost = 'رميت %d صخرًا بلا معدن' },
                { id = 'smelt', kind = 'batch', label = 'اصهر الخام', place = 'المسبك', blip = 478, spot = vec3(1083.50, -1974.00, 31.00),
                  take = 'washed_ore', give = 'copper_bar', game = 'smelt', seconds = 28,
                  giveMix = { { 'copper_bar', 60 }, { 'iron_bar', 35 }, { 'gold_bar', 5 } },
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'صببت %d سبيكة', lost = 'فسد %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع السبائك', place = 'مكتب المسبك', blip = 431, spot = vec3(1090.00, -1993.00, 30.90),
                  take = 'copper_bar', price = 50, takeAlso = { iron_bar = 45, gold_bar = 260 }, seconds = 20,
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
                'في مزرعة غريبسيد جزّ صوف الخراف: مرّر المجزّة على كل الصوف.',
                'في المصنع على النول اضغط في اللحظة التي يصل فيها المكوك إلى الطرف.',
                'على ماكينة الخياطة أبقِ الإبرة على خط الخياطة، ثم بِع الملابس للمتجر.',
            },
            extra = 'كلما أتقنت الألعاب خسرت أقل. الصوف والقماش والملابس لا توضع في صندوق السيارة أو المخزن.',
            payText = '51$ لكل قطعة',
            hourText = '3,700$',
            taskWord = { 'قطعة', 'قطع' },
            levelSteps = { 0, 15, 40, 80, 140 },
            perRound = 22,
            roundMinutes = 14,
            xpRate = 0.22,
            supplies = { 'thread_spool' },
            hq = {
                label = 'مصنع النسيج', place = 'لا ميسا',
                blip = { sprite = 366, colour = 27, scale = 0.75, name = 'مصنع النسيج' },
                supervisor = { model = 's_f_y_factory_01', coords = vec4(713.40, -967.70, 30.40, 180.0), scenario = 'WORLD_HUMAN_CLIPBOARD', name = 'المشرفة سلمى' },
                spawns = {}, returnRadius = 45.0,
            },
            chain = {
                { id = 'shear', kind = 'batch', label = 'جزّ الصوف', place = 'حظيرة الخراف', blip = 141, spot = vec3(2441.60, 4976.40, 46.80),
                  take = 'thread_spool', give = 'raw_wool', game = 'shear', seconds = 28,
                  anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' }, done = 'جززت %d', lost = 'ضاع %d' },
                { id = 'weave', kind = 'batch', label = 'انسج القماش', place = 'النول', blip = 478, spot = vec3(716.00, -962.00, 30.40),
                  take = 'raw_wool', give = 'fabric_roll', game = 'weave', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'نسجت %d لفة', lost = 'تمزّق %d' },
                { id = 'sew', kind = 'batch', label = 'خِط الملابس', place = 'ماكينة الخياطة', blip = 478, spot = vec3(710.00, -960.00, 30.40),
                  take = 'fabric_roll', give = 'sewn_clothes', game = 'sew', seconds = 28,
                  anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, done = 'خِطت %d قطعة', lost = 'أفسدت %d' },
                { id = 'sell', kind = 'sellall', label = 'بِع الملابس', place = 'متجر بينكو', blip = 431, spot = vec3(425.60, -806.30, 29.50),
                  take = 'sewn_clothes', price = 51, seconds = 20, anim = { dict = 'mp_common', clip = 'givetake1_a' },
                  progress = 'يعدّ المتجر القطع...', sold = 'بعت %d قطعة' },
            },
        },
    },
}
