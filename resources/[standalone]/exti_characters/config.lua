-- EX_Tii Roleplay — character screens (choose, create, design your look, arrive in the city).
return {
    -- where your character stands while you choose (the camera measures the character and frames it by itself)
    scene = {
        ped = vec4(969.25, 74.00, 115.20, 276.55), -- open floor in front of the window (the floor is also measured in game)
        clock = { hour = 19, minute = 10 }, -- golden evening light while choosing
        fov = 40.0,
    },

    -- brand-new players: one spawn only, next to the job center
    newPlayer = {
        spawn = vec4(-265.49, -962.85, 31.22, 201.26),        -- where new players appear (Moe's /savespot newspawn), a short walk from the job center
        jobCenter = vec4(-232.44, -915.57, 32.30, 334.49), -- the employee by the PostOP Couriers door (Moe's /savespot jobcenter, same as qbx_cityhall)
        -- the arrival camera picks its own spots (checked in game: out in the open, never through a building)
    },

    -- the look editor for new characters (illenium-appearance): every section open, no exit button
    editor = {
        ped = true,
        headBlend = true,
        faceFeatures = true,
        headOverlays = true,
        components = true,
        componentConfig = {
            masks = true, upperBody = true, lowerBody = true, bags = true, shoes = true,
            scarfAndChains = true, bodyArmor = true, shirts = true, decals = true, jackets = true,
        },
        props = true,
        propConfig = { hats = true, glasses = true, ear = true, watches = true, bracelets = true },
        tattoos = true,
        enableExit = false,
        hasTracker = false,
        automaticFade = false,
    },

    -- names: Arabic or English letters, spaces, - and '
    nameMin = 2,
    nameMax = 16,

    birthYearMin = 1950,
    birthYearMax = 2006,

    -- shown in Arabic; stored as written here (feminine form is made automatically for female characters)
    nationalities = {
        'سعودي', 'إماراتي', 'كويتي', 'قطري', 'بحريني', 'عُماني', 'يمني', 'عراقي', 'سوري', 'لبناني',
        'أردني', 'فلسطيني', 'مصري', 'سوداني', 'ليبي', 'تونسي', 'جزائري', 'مغربي', 'موريتاني', 'صومالي',
        'أمريكي', 'كندي', 'مكسيكي', 'برازيلي', 'أرجنتيني', 'كولومبي', 'بريطاني', 'إيرلندي', 'فرنسي', 'ألماني',
        'إيطالي', 'إسباني', 'برتغالي', 'هولندي', 'سويدي', 'روسي', 'أوكراني', 'تركي', 'إيراني', 'أفغاني',
        'باكستاني', 'هندي', 'صيني', 'ياباني', 'كوري', 'فلبيني', 'إندونيسي', 'نيجيري', 'إثيوبي', 'أسترالي',
    },
}
