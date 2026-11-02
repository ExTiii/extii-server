return {
    ['testburger'] = {
        label = 'برغر تجريبي (Test Burger)',
        weight = 220,
        degrade = 60,
        client = {
            image = 'burger_chicken.png',
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            export = 'ox_inventory_examples.testburger'
        },
        server = {
            export = 'ox_inventory_examples.testburger',
            test = 'what an amazingly delicious burger, amirite?'
        },
        buttons = {
            {
                label = 'لعقه',
                action = function(slot)
                    print('You licked the burger')
                end
            },
            {
                label = 'اعصره',
                action = function(slot)
                    print('You squeezed the burger :(')
                end
            },
            {
                label = 'ماذا تسمي برغر نباتي؟',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('A misteak.')
                end
            },
            {
                label = 'ماذا تحب الضفادع أن تأكل مع البرغر؟',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('French flies.')
                end
            },
            {
                label = 'لماذا كان البرغر والبطاطس يركضان؟',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('Because they\'re fast food.')
                end
            }
        },
        consume = 0.3
    },

    -- EX_Tii: the hospital pharmacies sell these three instead of the bandage (what they do is in
    -- modules/items/client.lua). The bandage below still works for anyone who already has one,
    -- but no shop sells it any more.
    ['gauze'] = {
        label = 'شاش طبي (Gauze)',
        description = 'يعيد ربع صحتك خلال 3 ثوانٍ',
        allowArmed = true,
        weight = 60,
        client = {
            anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
            prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
            disable = { move = false, car = false, combat = true },
            usetime = 3000,
            label = 'جارٍ وضع الشاش...',
        },
    },

    -- EX_Tii medical treatment (exti_medical): EMS supplies from the ambulance supply cabinet.
    -- They are used by the medic's treatment (not by using them from the inventory).
    ['pressure_bandage'] = {
        label = 'ضماد ضاغط (Pressure Bandage)',
        description = 'يوقف النزيف القوي — يستعمله المسعف أثناء العلاج',
        weight = 120,
    },

    ['quickclot'] = {
        label = 'كويك كلوت (QuikClot)',
        description = 'شاش يوقف النزيف بسرعة — يستعمله المسعف أثناء العلاج',
        weight = 80,
    },

    ['tourniquet'] = {
        label = 'عاصبة (Tourniquet)',
        description = 'توقف نزيف الذراع أو الرجل مؤقتًا — بعدها لازم ضماد',
        weight = 150,
    },

    ['blood_bag'] = {
        label = 'كيس دم (Blood Bag)',
        description = 'نقل دم لمريض فقد دمًا كثيرًا — يرفع الضغط',
        weight = 500,
    },

    ['saline'] = {
        label = 'محلول ملحي (Saline)',
        description = 'محلول في الوريد — يرفع الضغط قليلًا',
        weight = 500,
    },

    ['ibuprofen'] = {
        label = 'إيبوبروفين (Ibuprofen)',
        description = 'مسكّن للألم الخفيف والمتوسط — يعطيه المسعف',
        weight = 30,
    },

    ['morphine'] = {
        label = 'مورفين (Morphine)',
        description = 'مسكّن قوي للألم الشديد — يعطيه المسعف',
        weight = 30,
    },

    ['forceps'] = {
        label = 'ملقط جراحي (Forceps)',
        description = 'أداة المسعف لإخراج الرصاص والشظايا — لا تُستهلك',
        weight = 150,
        stack = false,
    },

    ['bvm'] = {
        label = 'كيس التنفس (أمبو)',
        description = 'أداة المسعف لإعطاء الأكسجين وأنفاس الإنقاذ — لا تُستهلك',
        weight = 400,
        stack = false,
    },

    ['defibrillator'] = {
        label = 'جهاز الصدمات (Defibrillator)',
        description = 'يعيد النبض أثناء الإنعاش القلبي — لا يُستهلك',
        weight = 2500,
        stack = false,
    },

    ['medikit'] = {
        label = 'حقيبة إسعافات (First Aid Kit)',
        description = 'يعيد صحتك كاملة، يحتاج 10 ثوانٍ وأنت واقف',
        weight = 1200,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d', flag = 1 },
            disable = { move = true, car = true, combat = true },
            usetime = 10000,
            label = 'جارٍ استخدام حقيبة الإسعافات...',
        },
    },

    -- EX_Tii: given for free at the hospital check-up; the details are written on the report itself
    ['medreport'] = {
        label = 'تقرير طبي (Medical Report)',
        description = 'تقرير من المستشفى عن حالتك الصحية',
        weight = 20,
        stack = false,
        close = false,
    },

    ['bandage'] = {
        label = 'ضمادة (Bandage)',
        allowArmed = true, -- EX_Tii: usable even with a weapon in hand
        weight = 115,
        -- EX_Tii: the inventory handles the bandage itself now (+25 health, see modules/items/client.lua),
        -- so it keeps working even when the ambulance job script is restarted or stopped
        client = {
            anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
            prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
            disable = { move = false, car = false, combat = true },
            usetime = 3500,
            label = 'جارٍ وضع الضمادة...',
        },
    },

    ['burger'] = {
        label = 'برغر (Burger)',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'أكلت برغر لذيذًا'
        },
    },

    -- EX_Tii: energy drink — 1 minute of sprinting without getting tired (modules/items/client.lua)
    ['redbull'] = {
        label = 'ريد بول (Red Bull)',
        description = 'طاقة فورية: اركض بلا تعب لمدة دقيقة',
        weight = 300,
        client = {
            status = { thirst = 100000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
        }
    },

    ['sprunk'] = {
        label = 'مشروب سبرنك (Sprunk)',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'أرويت عطشك بمشروب سبرنك'
        }
    },

    ['parachute'] = {
        label = 'مظلة هبوط (Parachute)',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'قمامة (Garbage)',
    },

    ['paperbag'] = {
        label = 'كيس ورقي (Paper Bag)',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'ملابس داخلية (Knickers)',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'أداة فتح أقفال (Lockpick)',
        weight = 160,
    },

    ['phone'] = {
        label = 'جوال (Phone)',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            add = function(total)
                if total > 0 then
                    pcall(function() return exports.npwd:setPhoneDisabled(false) end)
                end
            end,

            remove = function(total)
                if total < 1 then
                    pcall(function() return exports.npwd:setPhoneDisabled(true) end)
                end
            end
        }
    },

    ['mustard'] = {
        label = 'خردل (Mustard)',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'لقد... شربت خردلًا'
        }
    },

    ['water'] = {
        label = 'ماء (Water)',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'شربت ماءً منعشًا'
        }
    },

    ['armour'] = {
        label = 'سترة واقية من الرصاص (Bulletproof Vest)',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'ملابس (Clothing)',
        consume = 0,
    },

    ['money'] = {
        label = 'نقود (Money)',
    },

    ['black_money'] = {
        label = 'أموال غير نظيفة (Dirty Money)',
    },

    ['id_card'] = {
        label = 'بطاقة الهوية (Identification Card)',
    },

    ['driver_license'] = {
        label = 'رخصة القيادة (Driver License)',
    },

    ['truck_license'] = {
        label = 'رخصة قيادة الشاحنات (Truck License)',
    },

    ['boat_license'] = {
        label = 'رخصة قيادة القوارب (Boat License)',
    },

    ['heli_license'] = {
        label = 'رخصة الطيران (Helicopter License)',
    },

    ['weaponlicense'] = {
        label = 'رخصة السلاح (Weapon License)',
    },

    ['lawyerpass'] = {
        label = 'تصريح المحاماة (Lawyer Pass)',
    },

    ['radio'] = {
        label = 'جهاز لاسلكي (Radio)',
        weight = 1000,
        allowArmed = true,
        consume = 0,
        client = {
            event = 'mm_radio:client:use'
        }
    },

    ['jammer'] = {
        label = 'جهاز تشويش (Radio Jammer)',
        weight = 10000,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:usejammer'
        }
    },

    ['radiocell'] = {
        label = 'بطاريات (AAA Cells)',
        weight = 1000,
        stack = true,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:recharge'
        }
    },

    ['advancedlockpick'] = {
        label = 'أداة فتح أقفال متطورة (Advanced Lockpick)',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'طقم مفكات (Screwdriver Set)',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'عدة إلكترونيات (Electronic Kit)',
        weight = 500,
    },

    ['cleaningkit'] = {
        label = 'عدة تنظيف (Cleaning Kit)',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'عدة إصلاح (Repair Kit)',
        weight = 2500,
    },

    ['advancedrepairkit'] = {
        label = 'عدة إصلاح متطورة (Advanced Repair Kit)',
        weight = 4000,
        client = { image = 'advancedkit.png' }, -- EX_Tii: picture in the inventory (full fix: engine + body)
    },

    ['diamond'] = {
        label = 'ألماس (Diamond)',
        weight = 1500,
    },

    ['diamond_ring'] = {
        label = 'خاتم ألماس (Diamond Ring)',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'ساعة ذهبية (Golden Watch)',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'سبيكة ذهب (Gold Bar)',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'سلسلة ذهبية (Golden Chain)',
        weight = 1500,
    },

    ['10kgoldchain'] = {
        label = 'سلسلة ذهب عيار 10 (10k Gold Chain)',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'كيس كراك (Crack Baggy)',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'كيس كوكايين (Bag of Coke)',
        weight = 100,
    },

    ['coke_brick'] = {
        label = 'طوبة كوكايين (Coke Brick)',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'طرد كوكايين (Coke Package)',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'كيس حبوب إكستاسي (Bag of Ecstasy)',
        weight = 100,
    },

    ['meth'] = {
        label = 'ميثامفيتامين (Methamphetamine)',
        weight = 100,
    },

    ['oxy'] = {
        label = 'أوكسيكودون (Oxycodone)',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'حشيش AK47 2غ (AK47 2g)',
        weight = 200,
    },

    ['weed_ak47_seed'] = {
        label = 'بذرة AK47 (AK47 Seed)',
        weight = 1,
    },

    ['weed_skunk'] = {
        label = 'حشيش سكنك 2غ (Skunk 2g)',
        weight = 200,
    },

    ['weed_skunk_seed'] = {
        label = 'بذرة سكنك (Skunk Seed)',
        weight = 1,
    },

    ['weed_amnesia'] = {
        label = 'حشيش أمنيزيا 2غ (Amnesia 2g)',
        weight = 200,
    },

    ['weed_amnesia_seed'] = {
        label = 'بذرة أمنيزيا (Amnesia Seed)',
        weight = 1,
    },

    ['weed_og-kush'] = {
        label = 'حشيش أو جي كوش 2غ (OG Kush 2g)',
        weight = 200,
    },

    ['weed_og-kush_seed'] = {
        label = 'بذرة أو جي كوش (OG Kush Seed)',
        weight = 1,
    },

    ['weed_white-widow'] = {
        label = 'حشيش وايت ويدو 2غ (White Widow 2g)',
        weight = 200,
    },

    ['weed_white-widow_seed'] = {
        label = 'بذرة وايت ويدو (White Widow Seed)',
        weight = 1,
    },

    ['weed_purple-haze'] = {
        label = 'حشيش بربل هيز 2غ (Purple Haze 2g)',
        weight = 200,
    },

    ['weed_purple-haze_seed'] = {
        label = 'بذرة بربل هيز (Purple Haze Seed)',
        weight = 1,
    },

    ['weed_brick'] = {
        label = 'طوبة حشيش (Weed Brick)',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'سماد نباتات (Plant Fertilizer)',
        weight = 2000,
    },

    ['joint'] = {
        label = 'سيجارة حشيش (Joint)',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'ورق لف (Rolling Paper)',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'كيس فارغ (Empty Weed Bag)',
        weight = 0,
    },

    ['firstaid'] = {
        label = 'إسعافات أولية (First Aid)',
        allowArmed = true, -- EX_Tii: usable even with a weapon in hand
        weight = 2500,
    },

    ['ifaks'] = {
        label = 'حقيبة إسعافات شخصية (IFAK)',
        allowArmed = true, -- EX_Tii: usable even with a weapon in hand
        weight = 2500,
    },

    ['painkillers'] = {
        label = 'مسكنات (Painkillers)',
        description = 'يعيد صحتك شيئًا فشيئًا خلال 40 ثانية',
        allowArmed = true, -- EX_Tii: usable even with a weapon in hand
        weight = 100,
        -- EX_Tii: the inventory handles painkillers now (modules/items/client.lua)
        client = {
            anim = { dict = 'mp_suicide', clip = 'pill' },
            disable = { move = false, car = false, combat = true },
            usetime = 2500,
            label = 'جارٍ تناول المسكنات...',
        },
    },

    ['firework1'] = {
        label = 'ألعاب نارية الأخوين (2Brothers)',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'ألعاب نارية بوبلرز (Poppelers)',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'ألعاب نارية وايب آوت (WipeOut)',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'ألعاب نارية الصفصاف (Weeping Willow)',
        weight = 1000,
    },

    ['steel'] = {
        label = 'فولاذ (Steel)',
        weight = 100,
    },

    ['rubber'] = {
        label = 'مطاط (Rubber)',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'خردة معدنية (Metal Scrap)',
        weight = 100,
    },

    ['iron'] = {
        label = 'حديد (Iron)',
        weight = 100,
    },

    ['copper'] = {
        label = 'نحاس (Copper)',
        weight = 100,
    },

    ['aluminum'] = {
        label = 'ألمنيوم (Aluminium)',
        weight = 100,
    },

    ['plastic'] = {
        label = 'بلاستيك (Plastic)',
        weight = 100,
    },

    ['glass'] = {
        label = 'زجاج (Glass)',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'جهاز اختراق البوابات (Gatecrack)',
        weight = 1000,
    },

    ['cryptostick'] = {
        label = 'شريحة عملة رقمية (Crypto Stick)',
        weight = 100,
    },

    ['trojan_usb'] = {
        label = 'فلاشة اختراق (Trojan USB)',
        weight = 100,
    },

    ['toaster'] = {
        label = 'محمصة خبز (Toaster)',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'تلفاز صغير (Small TV)',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'بطاقة أمن A (Security Card A)',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'بطاقة أمن B (Security Card B)',
        weight = 100,
    },

    ['drill'] = {
        label = 'مثقاب (Drill)',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'ثيرمايت (Thermite)',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'معدات غوص (Diving Gear)',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'أسطوانة غوص (Diving Tube)',
        weight = 3000,
    },

    ['antipatharia_coral'] = {
        label = 'مرجان أسود (Antipatharia)',
        weight = 1000,
    },

    ['dendrogyra_coral'] = {
        label = 'مرجان عمودي (Dendrogyra)',
        weight = 1000,
    },

    ['jerry_can'] = {
        label = 'جالون وقود (Jerrycan)',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'نيتروس (Nitrous)',
        weight = 1000,
    },

    ['wine'] = {
        label = 'نبيذ (Wine)',
        weight = 500,
    },

    ['grape'] = {
        label = 'عنب (Grape)',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'عصير عنب (Grape Juice)',
        weight = 200,
    },

    ['coffee'] = {
        label = 'قهوة (Coffee)',
        weight = 200,
    },

    ['vodka'] = {
        label = 'فودكا (Vodka)',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'ويسكي (Whiskey)',
        weight = 200,
    },

    ['beer'] = {
        label = 'بيرة (Beer)',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'ساندويتش (Sandwich)',
        weight = 200,
    },

    ['walking_stick'] = {
        label = 'عصا مشي (Walking Stick)',
        weight = 1000,
    },

    ['lighter'] = {
        label = 'ولاعة (Lighter)',
        weight = 200,
    },

    ['binoculars'] = {
        label = 'منظار (Binoculars)',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'ورقة ملاحظات (Sticky Note)',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'كيس أدلة فارغ (Empty Evidence Bag)',
        weight = 200,
    },

    ['filled_evidence_bag'] = {
        label = 'كيس أدلة ممتلئ (Filled Evidence Bag)',
        weight = 200,
    },

    ['harness'] = {
        label = 'حزام سباق (Harness)',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'أصفاد (Handcuffs)',
        weight = 200,
    },

    -- EX_Tii mechanic: car parts (the pictures live in exti_mechanic/html/items)
    ['engine_oil'] = {
        label = 'زيت محرك (Engine Oil)',
        weight = 1500,
        client = { image = 'nui://exti_mechanic/html/items/engine_oil.png' },
    },

    ['air_filter'] = {
        label = 'فلتر هواء (Air Filter)',
        weight = 500,
        client = { image = 'nui://exti_mechanic/html/items/air_filter.png' },
    },

    ['coolant'] = {
        label = 'سائل تبريد (Coolant)',
        weight = 1500,
        client = { image = 'nui://exti_mechanic/html/items/coolant.png' },
    },

    ['spark_plugs'] = {
        label = 'شمعات إشعال (Spark Plugs)',
        weight = 400,
        client = { image = 'nui://exti_mechanic/html/items/spark_plugs.png' },
    },

    ['brake_pads'] = {
        label = 'فحمات فرامل (Brake Pads)',
        weight = 1200,
        client = { image = 'nui://exti_mechanic/html/items/brake_pads.png' },
    },

    ['brake_fluid'] = {
        label = 'سائل فرامل (Brake Fluid)',
        weight = 800,
        client = { image = 'nui://exti_mechanic/html/items/brake_fluid.png' },
    },

    ['clutch_kit'] = {
        label = 'طقم قابض (Clutch Kit)',
        weight = 6000,
        client = { image = 'nui://exti_mechanic/html/items/clutch_kit.png' },
    },

    ['transmission_fluid'] = {
        label = 'زيت ناقل الحركة (Transmission Fluid)',
        weight = 1500,
        client = { image = 'nui://exti_mechanic/html/items/transmission_fluid.png' },
    },

    ['car_tire'] = {
        label = 'إطار سيارة (Tire)',
        weight = 8000,
        client = { image = 'nui://exti_mechanic/html/items/car_tire.png' },
    },

    ['ev_battery'] = {
        label = 'بطارية سيارة كهربائية (EV Battery)',
        weight = 20000,
        client = { image = 'nui://exti_mechanic/html/items/ev_battery.png' },
    },

    ['ev_motor'] = {
        label = 'محرك كهربائي (EV Motor)',
        weight = 15000,
        client = { image = 'nui://exti_mechanic/html/items/ev_motor.png' },
    },

    ['car_soap'] = {
        label = 'صابون سيارات (Car Soap)',
        weight = 800,
        client = { image = 'nui://exti_mechanic/html/items/car_soap.png' },
    },

    ['car_wax'] = {
        label = 'واكس تلميع (Car Wax)',
        weight = 600,
        client = { image = 'nui://exti_mechanic/html/items/car_wax.png' },
    },

    -- EX_Tii mechanic: tuning parts (part C)
    ['engine_kit'] = {
        label = 'قطع ترقية المحرك (Engine Kit)',
        weight = 4000,
        client = { image = 'nui://exti_mechanic/html/items/engine_kit.png' },
    },

    ['brake_kit'] = {
        label = 'طقم فرامل رياضية (Brake Kit)',
        weight = 3000,
        client = { image = 'nui://exti_mechanic/html/items/brake_kit.png' },
    },

    ['trans_kit'] = {
        label = 'طقم ناقل حركة رياضي (Transmission Kit)',
        weight = 3500,
        client = { image = 'nui://exti_mechanic/html/items/trans_kit.png' },
    },

    ['susp_kit'] = {
        label = 'طقم تعليق رياضي (Suspension Kit)',
        weight = 3000,
        client = { image = 'nui://exti_mechanic/html/items/susp_kit.png' },
    },

    ['turbo_kit'] = {
        label = 'تيربو (Turbo Kit)',
        weight = 5000,
        client = { image = 'nui://exti_mechanic/html/items/turbo_kit.png' },
    },

    ['paint_can'] = {
        label = 'علبة صبغ (Paint Can)',
        weight = 1500,
        client = { image = 'nui://exti_mechanic/html/items/paint_can.png' },
    },

    ['wheel_set'] = {
        label = 'طقم جنوط (Wheel Set)',
        weight = 8000,
        client = { image = 'nui://exti_mechanic/html/items/wheel_set.png' },
    },

    ['body_kit'] = {
        label = 'قطعة هيكل (Body Part)',
        weight = 3000,
        client = { image = 'nui://exti_mechanic/html/items/body_kit.png' },
    },

    ['tint_film'] = {
        label = 'فيلم تظليل (Window Tint)',
        weight = 300,
        client = { image = 'nui://exti_mechanic/html/items/tint_film.png' },
    },

    ['neon_kit'] = {
        label = 'طقم نيون (Neon Kit)',
        weight = 1200,
        client = { image = 'nui://exti_mechanic/html/items/neon_kit.png' },
    },

    ['xenon_kit'] = {
        label = 'لمبات زينون (Xenon Kit)',
        weight = 400,
        client = { image = 'nui://exti_mechanic/html/items/xenon_kit.png' },
    },

    ['nitro_kit'] = {
        label = 'نظام نيترو (Nitro Kit)',
        weight = 6000,
        client = { image = 'nui://exti_mechanic/html/items/nitro_kit.png' },
    },

    ['nitro_bottle'] = {
        label = 'أسطوانة نيترو (Nitro Bottle)',
        weight = 4000,
        client = { image = 'nui://exti_mechanic/html/items/nitro_bottle.png' },
    },

    ['engine_crate'] = {
        label = 'محرك للتبديل (Engine Crate)',
        weight = 25000,
        client = { image = 'nui://exti_mechanic/html/items/engine_crate.png' },
    },

    -- EX_Tii level jobs (exti_jobs): chicken, raisins
    ['live_chicken'] = {
        label = 'دجاجة حية (Live Chicken)',
        weight = 3000,
        description = 'من عُدد الدواجن في الحظيرة، تُذبح عند طاولة الذبح. لا تُخزّن، تُحمل فقط',
        client = { image = 'nui://exti_jobs/html/items/live_chicken.png' },
    },

    ['slaughtered_chicken'] = {
        label = 'دجاجة مذبوحة (Slaughtered Chicken)',
        weight = 2500,
        description = 'تُعبّأ عند خط التعبئة. لا تُخزّن، تُحمل فقط',
        client = { image = 'nui://exti_jobs/html/items/slaughtered_chicken.png' },
    },

    ['packed_chicken'] = {
        label = 'صينية دجاج معبأ (Packed Chicken)',
        weight = 2000,
        description = 'تُباع لتاجر الدواجن. لا تُخزّن، تُحمل فقط',
        client = { image = 'nui://exti_jobs/html/items/packed_chicken.png' },
    },

    ['packing_tray'] = {
        label = 'صينية تغليف (Packing Tray)',
        weight = 100,
        description = 'لم تعد مطلوبة لوظيفة الدواجن',
        client = { image = 'nui://exti_jobs/html/items/packing_tray.png' },
    },

    ['poultry_kit'] = {
        label = 'عدة دواجن (Poultry Kit)',
        weight = 3500,
        description = 'لوظيفة الدواجن: كل عدة تصبح دجاجة واحدة في الحظيرة',
        client = { image = 'nui://exti_jobs/html/items/poultry_kit.png' },
    },

    ['grape_kit'] = {
        label = 'عدة قطف عنب (Grape Kit)',
        weight = 2800,
        description = 'لوظيفة الزبيب: كل عدة تصبح عنقودًا واحدًا في الكروم',
        client = { image = 'nui://exti_jobs/html/items/grape_kit.png' },
    },

    ['grape_bunch'] = {
        label = 'عنقود عنب (Grape Bunch)',
        weight = 2500,
        description = 'تقطفه من كروم مارلو ويجفّف عند المناشر (لا يُخزّن)',
        client = { image = 'nui://exti_jobs/html/items/grape_bunch.png' },
    },

    ['raisins'] = {
        label = 'زبيب (Raisins)',
        weight = 2000,
        description = 'يُفرز ويُعبّأ في كراتين عند طاولة التعبئة (لا يُخزّن)',
        client = { image = 'nui://exti_jobs/html/items/raisins.png' },
    },

    ['raisin_box'] = {
        label = 'كرتونة زبيب (Raisin Box)',
        weight = 1800,
        description = 'تُباع لتاجر الزبيب (لا تُخزّن)',
        client = { image = 'nui://exti_jobs/html/items/raisin_box.png' },
    },

    ['empty_carton'] = {
        label = 'كرتونة فارغة (Empty Carton)',
        weight = 150,
        description = 'لوظيفة الزبيب: كرتونة لكل 5 زبيب',
        client = { image = 'nui://exti_jobs/html/items/empty_carton.png' },
    },

    -- EX_Tii gangs: the Chop Shop's part (from the shared collection point) and C4 (only from chops)
    ['chop_tools'] = {
        label = 'أدوات تفكيك (Chop Tools)',
        weight = 1500,
        description = 'قطعة عصابة ورشة التفكيك: تُستعمل لتفكيك السيارات وصنع مفاتيح الفتح',
    },

    ['c4'] = {
        label = 'متفجرات C4',
        weight = 1000,
        description = 'لا تأتي إلا من ورشة التفكيك. مطلوبة لعمليات السطو الكبيرة',
    },

    -- EX_Tii gangs: the Money Wash's part (from the shared collection point): 1 per $1,000 washed
    ['wash_supplies'] = {
        label = 'مواد غسيل (Wash Supplies)',
        weight = 1200,
        description = 'قطعة عصابة غسيل الأموال: منظّف وأشرطة رزم. واحدة لكل 1,000$ تُغسل',
    },
}
