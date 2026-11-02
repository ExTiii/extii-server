-- EX_Tii Roleplay — dealership catalog.
-- Only the vehicles listed here can be bought or test driven. Everything else stays hidden.
-- To change a price, change `price`. (EX_Tii economy: supercars and luxury +30%) To remove a vehicle, delete its line.
-- `name` / `brand` are what players see (the 13 real-brand cars use GTA's own lookalike models).

return {
    -- order = order of the filter buttons in the panel; shop = which dealership sells it
    categories = {
        { id = 'sedans',      shop = 'pdm',   icon = 'car',   label = 'سيدان ومدمجة',     en = 'Sedans & Compacts' },
        { id = 'suvs',        shop = 'pdm',   icon = 'suv',   label = 'دفع رباعي',         en = 'SUVs & 4x4' },
        { id = 'sports',      shop = 'pdm',   icon = 'speed', label = 'رياضية',            en = 'Sports' },
        { id = 'luxury',      shop = 'pdm',   icon = 'crown', label = 'فاخرة',             en = 'Luxury & Exotic' },
        { id = 'tuner',       shop = 'pdm',   icon = 'tuner', label = 'معدّلة ويابانية',    en = 'Tuner & JDM' },
        { id = 'trucks',      shop = 'pdm',   icon = 'truck', label = 'شاحنات وتجارية',    en = 'Trucks & Commercial' },
        { id = 'motorcycles', shop = 'pdm',   icon = 'moto',  label = 'دراجات نارية',      en = 'Motorcycles' },
        { id = 'bicycles',    shop = 'pdm',   icon = 'bike',  label = 'دراجات هوائية',     en = 'Bicycles' },
        { id = 'offroad',     shop = 'pdm',   icon = 'mount', label = 'خاصة ووعرة',        en = 'Special & Off-road' },
        { id = 'more',        shop = 'pdm',   icon = 'star',  label = 'المزيد',            en = 'More' },
        { id = 'boats',       shop = 'boats', icon = 'boat',  label = 'قوارب',             en = 'Boats & Watercraft' },
        { id = 'air',         shop = 'air',   icon = 'heli',  label = 'طائرات ومروحيات',   en = 'Helicopters & Aircraft' },
    },

    vehicles = {
        -- Sedans & Compacts
        { model = 'primo',        price = 14000,   category = 'sedans',      name = 'Primo',              brand = 'Albany' },
        { model = 'issi7',        price = 18000,   category = 'sedans',      name = 'Issi Sport',         brand = 'Weeny' },
        { model = 'sentinel3',    price = 32000,   category = 'sedans',      name = 'Sentinel Classic',   brand = 'Übermacht' },
        { model = 'elegy2',       price = 45000,   category = 'sedans',      name = 'Elegy RH8',          brand = 'Annis' },
        { model = 'jester',       price = 55000,   category = 'sedans',      name = 'Jester',             brand = 'Dinka' },
        { model = 'sultanrs',     price = 65000,   category = 'sedans',      name = 'Sultan RS',          brand = 'Karin' },

        -- SUVs & 4x4 (GTA lookalikes, real names)
        { model = 'bjxl',         price = 48000,   category = 'suvs',        name = 'Land Cruiser',       brand = 'Toyota' },
        { model = 'terminus',     price = 55000,   category = 'suvs',        name = 'Bronco',             brand = 'Ford' },
        { model = 'baller3',      price = 85000,   category = 'suvs',        name = 'Range Rover Sport',  brand = 'Land Rover' },
        { model = 'dubsta',       price = 155000,  category = 'suvs',        name = 'G-Wagon',            brand = 'Mercedes' },

        -- Sports
        { model = 'vigero',       price = 40000,   category = 'sports',      name = 'Vigero',             brand = 'Declasse' },
        { model = 'rapidgt',      price = 110000,  category = 'sports',      name = 'Rapid GT',           brand = 'Dewbauchee' },
        { model = 'cheetah',      price = 235000,  category = 'sports',      name = 'Cheetah',            brand = 'Grotti' },
        { model = 'torero',       price = 285000,  category = 'sports',      name = 'Torero',             brand = 'Pegassi' }, -- the Toreador has missiles, so the Torero takes its place
        { model = 'turismor',     price = 340000,  category = 'sports',      name = 'Turismo R',          brand = 'Grotti' },
        { model = 'zentorno',     price = 390000,  category = 'sports',      name = 'Zentorno',           brand = 'Pegassi' },

        -- Luxury & Exotic (GTA lookalikes, real names)
        { model = 'paragon',      price = 310000,  category = 'luxury',      name = 'Continental',        brand = 'Bentley' },
        { model = 'toros',        price = 365000,  category = 'luxury',      name = 'Urus',               brand = 'Lamborghini' },
        { model = 'superd',       price = 455000,  category = 'luxury',      name = 'Ghost',              brand = 'Rolls Royce' },
        { model = 'jubilee',      price = 545000,  category = 'luxury',      name = 'Cullinan',           brand = 'Rolls Royce' },

        -- Tuner & JDM
        { model = 'sultan',       price = 30000,   category = 'tuner',       name = 'Sultan',             brand = 'Karin' },
        { model = 'futo2',        price = 38000,   category = 'tuner',       name = 'Futo GTX',           brand = 'Karin' },
        { model = 'schafter2',    price = 42000,   category = 'tuner',       name = 'Schafter',           brand = 'Benefactor' },
        { model = 'banshee',      price = 90000,   category = 'tuner',       name = 'Banshee',            brand = 'Bravado' },
        { model = 'comet2',       price = 95000,   category = 'tuner',       name = 'Comet',              brand = 'Pfister' },
        { model = 'jester4',      price = 120000,  category = 'tuner',       name = 'Jester RR',          brand = 'Dinka' },

        -- Trucks & Commercial
        { model = 'boxville',     price = 35000,   category = 'trucks',      name = 'Boxville',           brand = 'Brute' },
        { model = 'utillitruck3', price = 40000,   category = 'trucks',      name = 'Utility Truck',      brand = 'Vapid' },
        { model = 'mule',         price = 45000,   category = 'trucks',      name = 'Mule',               brand = 'Maibatsu' },
        { model = 'towtruck',     price = 60000,   category = 'trucks',      name = 'Tow Truck',          brand = 'Vapid' },

        -- Motorcycles (4 are GTA lookalikes, real names)
        { model = 'bagger',       price = 15000,   category = 'motorcycles', name = 'Bagger',             brand = 'Western' },
        { model = 'nemesis',      price = 20000,   category = 'motorcycles', name = 'Trident',            brand = 'Triumph' },
        { model = 'nightblade',   price = 22000,   category = 'motorcycles', name = 'Nightblade',         brand = 'Western' },
        { model = 'ruffian',      price = 26000,   category = 'motorcycles', name = 'Z1000',              brand = 'Kawasaki' },
        { model = 'diablous',     price = 28000,   category = 'motorcycles', name = 'Diavel',             brand = 'Ducati' },
        { model = 'hakuchou',     price = 35000,   category = 'motorcycles', name = 'Hayabusa',           brand = 'Suzuki' },

        -- Bicycles
        { model = 'bmx',          price = 500,     category = 'bicycles',    name = 'BMX',                brand = '' },
        { model = 'fixter',       price = 700,     category = 'bicycles',    name = 'Fixter',             brand = '' },
        { model = 'scorcher',     price = 900,     category = 'bicycles',    name = 'Scorcher',           brand = '' },
        { model = 'tribike3',     price = 1200,    category = 'bicycles',    name = 'Tri-Cycles',         brand = '' },

        -- Special & Off-road
        { model = 'sandking',     price = 55000,   category = 'offroad',     name = 'Sandking',           brand = 'Vapid' },
        { model = 'caracara2',    price = 70000,   category = 'offroad',     name = 'Raptor',             brand = 'Ford' },
        { model = 'patriot3',     price = 95000,   category = 'offroad',     name = 'Patriot Mil-Spec',   brand = 'Mammoth' },
        { model = 'trophytruck2', price = 120000,  category = 'offroad',     name = 'Desert Raid',        brand = 'Vapid' },

        -- More
        { model = 'inductor',     price = 1500,    category = 'more',        name = 'Inductor E-Bike',    brand = 'Coil' },
        { model = 'faggio',       price = 3500,    category = 'more',        name = 'Faggio',             brand = 'Pegassi' },
        { model = 'veto',         price = 6000,    category = 'more',        name = 'Go Kart',            brand = 'Dinka' },
        { model = 'ratbike',      price = 9000,    category = 'more',        name = 'Rat Bike',           brand = 'Western' },

        -- Boats & Watercraft (boat dock)
        { model = 'seashark',     price = 15000,   category = 'boats',       name = 'Jet Ski',            brand = 'Speedophile' },
        { model = 'dinghy',       price = 25000,   category = 'boats',       name = 'Dinghy',             brand = 'Nagasaki' },
        { model = 'squalo',       price = 45000,   category = 'boats',       name = 'Squalo',             brand = 'Shitzu' },
        { model = 'speeder',      price = 75000,   category = 'boats',       name = 'Speeder',            brand = 'Pegassi' },
        { model = 'marquis',      price = 150000,  category = 'boats',       name = 'Marquis',            brand = 'Dinka' },
        { model = 'submersible',  price = 350000,  category = 'boats',       name = 'Submarine',          brand = '' },

        -- Helicopters & Aircraft (airport) — unarmed only
        { model = 'maverick',     price = 650000,  category = 'air',         name = 'Maverick',           brand = 'Western' },
        { model = 'buzzard2',     price = 900000,  category = 'air',         name = 'Buzzard',            brand = 'Nagasaki' },
        { model = 'luxor',        price = 1500000, category = 'air',         name = 'Luxor',              brand = 'Buckingham' },
    },

    -- paint colours players can pick before buying (0 = factory colour)
    colours = {
        { label = 'أسود',    rgb = { 12, 12, 14 } },
        { label = 'أبيض',    rgb = { 236, 236, 232 } },
        { label = 'فضي',     rgb = { 168, 172, 178 } },
        { label = 'رمادي',   rgb = { 84, 88, 96 } },
        { label = 'كحلي',    rgb = { 16, 26, 62 } },
        { label = 'أزرق',    rgb = { 22, 64, 168 } },
        { label = 'سماوي',   rgb = { 70, 150, 220 } },
        { label = 'أخضر',    rgb = { 18, 104, 58 } },
        { label = 'ذهبي',    rgb = { 196, 156, 64 } },
        { label = 'أصفر',    rgb = { 236, 186, 20 } },
        { label = 'برتقالي', rgb = { 226, 106, 20 } },
        { label = 'أحمر',    rgb = { 176, 16, 22 } },
        { label = 'خمري',    rgb = { 92, 14, 26 } },
        { label = 'وردي',    rgb = { 218, 88, 150 } },
        { label = 'بنفسجي',  rgb = { 96, 40, 148 } },
        { label = 'بني',     rgb = { 96, 62, 38 } },
    },
}
