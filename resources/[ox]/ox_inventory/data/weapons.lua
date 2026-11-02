return {
	Weapons = {
		-- EX_Tii: the gun rework. 36 weapons (legal at Ammu-Nation, the Weapons gang, the police, heist loot only, melee, tools).
		-- Every other GTA weapon was removed: an item that is not defined here is dropped from inventories by ox_inventory.
		-- durability = what one shot wears off (0.1 = about 1,000 shots). Police guns (0) never wear.

		['WEAPON_APPISTOL'] = {
			label = 'مسدس خارق للدروع (AP Pistol)',
			weight = 1400,
			durability = 0.0667,
			ammoname = 'ammo-9',
		},
		['WEAPON_ASSAULTRIFLE'] = {
			label = 'بندقية هجومية (Assault Rifle)',
			weight = 4500,
			durability = 0.05,
			ammoname = 'ammo-rifle2',
		},
		['WEAPON_BAT'] = {
			label = 'مضرب بيسبول (Bat)',
			weight = 1134,
			durability = 0.1,
		},
		['WEAPON_CARBINERIFLE'] = {
			label = 'بندقية كاربين (Carbine Rifle)',
			weight = 3100,
			durability = 0,
			ammoname = 'ammo-rifle'
		},
		['WEAPON_COMBATPISTOL'] = {
			label = 'مسدس قتالي (Combat Pistol)',
			weight = 785,
			durability = 0,
			ammoname = 'ammo-9'
		},
		['WEAPON_COMPACTRIFLE'] = {
			label = 'بندقية صغيرة (Compact Rifle)',
			weight = 3600,
			durability = 0.05,
			ammoname = 'ammo-rifle2'
		},
		['WEAPON_CROWBAR'] = {
			label = 'عتلة (Crowbar)',
			weight = 2500,
			durability = 0.1,
		},
		['WEAPON_DBSHOTGUN'] = {
			label = 'بندقية صيد بماسورتين (Double Barrel Shotgun)',
			weight = 3175,
			durability = 0.1,
			ammoname = 'ammo-shotgun'
		},
		['WEAPON_FIREEXTINGUISHER'] = {
			label = 'طفاية حريق (Fire Extinguisher)',
			weight = 8616,
            durability = 0.006
		},
		['WEAPON_FLASHLIGHT'] = {
			label = 'كشاف (Flashlight)',
			weight = 125,
			durability = 0.1,
		},
		['WEAPON_GOLFCLUB'] = {
			label = 'مضرب غولف (Golf Club)',
			weight = 330,
			durability = 0.1,
		},
		['WEAPON_GRENADE'] = {
			label = 'قنبلة يدوية (Grenade)',
			weight = 400,
			throwable = true,
		},
		['WEAPON_HAMMER'] = {
			label = 'مطرقة (Hammer)',
			weight = 1200,
			durability = 0.1,
		},
		['WEAPON_HATCHET'] = {
			label = 'فأس صغير (Hatchet)',
			weight = 1000,
			durability = 0.1,
		},
		['WEAPON_HEAVYPISTOL'] = {
			label = 'مسدس ثقيل (Heavy Pistol)',
			weight = 1100,
			durability = 0.1,
			ammoname = 'ammo-45'
		},
		['WEAPON_KNIFE'] = {
			label = 'سكين (Knife)',
			weight = 300,
			durability = 0.1,
		},
		['WEAPON_KNUCKLE'] = {
			label = 'قبضة حديدية (Knuckle Dusters)',
			weight = 300,
			durability = 0.1,
		},
		['WEAPON_MACHETE'] = {
			label = 'ساطور (Machete)',
			weight = 1000,
			durability = 0.1,
		},
		['WEAPON_MACHINEPISTOL'] = {
			label = 'مسدس رشاش (Machine Pistol)',
			weight = 1400,
			durability = 0.0667,
			ammoname = 'ammo-9'
		},
		['WEAPON_MICROSMG'] = {
			label = 'رشاش صغير جدًا (Micro SMG)',
			weight = 3000,
			durability = 0.0667,
			ammoname = 'ammo-45'
		},
		['WEAPON_MINISMG'] = {
			label = 'رشاش مصغّر (Mini SMG)',
			weight = 1270,
			durability = 0.0667,
			ammoname = 'ammo-9'
		},
		['WEAPON_MUSKET'] = {
			label = 'بندقية قديمة (Musket)',
			weight = 4500,
			durability = 0.1,
			ammoname = 'ammo-musket'
		},
		['WEAPON_NIGHTSTICK'] = {
			label = 'هراوة (Nightstick)',
			weight = 1000,
			durability = 0.1,
		},
		['WEAPON_PETROLCAN'] = {
			label = 'جالون وقود (Jerry Can)',
			weight = 4000,
		},
		['WEAPON_PISTOL'] = {
			label = 'مسدس (Pistol)',
			weight = 1130,
			durability = 0.1,
			ammoname = 'ammo-9',
		},
		['WEAPON_PUMPSHOTGUN'] = {
			label = 'بندقية صيد مضخية (Pump Shotgun)',
			weight = 3400,
			durability = 0,
			ammoname = 'ammo-shotgun'
		},
		['WEAPON_REVOLVER'] = {
			label = 'مسدس دوّار (Revolver)',
			weight = 2260,
			durability = 0.1,
			ammoname = 'ammo-44'
		},
		['WEAPON_SAWNOFFSHOTGUN'] = {
			label = 'بندقية صيد مقصوصة (Sawn Off Shotgun)',
			weight = 2380,
			durability = 0.1,
			ammoname = 'ammo-shotgun'
		},
		['WEAPON_SMG'] = {
			label = 'رشاش صغير (SMG)',
			weight = 3084,
			durability = 0,
			ammoname = 'ammo-9'
		},
		['WEAPON_SNIPERRIFLE'] = {
			label = 'بندقية قنص (Sniper Rifle)',
			weight = 5000,
			durability = 0,
			ammoname = 'ammo-sniper'
		},
		['WEAPON_SNSPISTOL'] = {
			label = 'مسدس جيب (SNS Pistol)',
			weight = 465,
			durability = 0.1,
			ammoname = 'ammo-45'
		},
		['WEAPON_SPECIALCARBINE'] = {
			label = 'كاربين خاص (Special Carbine)',
			weight = 3000,
			durability = 0.05,
			ammoname = 'ammo-rifle'
		},
		['WEAPON_STUNGUN'] = {
			label = 'مسدس صاعق (Taser)',
			weight = 227,
			durability = 0,
		},
		['WEAPON_SWITCHBLADE'] = {
			label = 'مطواة (Switchblade)',
			weight = 300,
			durability = 0.1,
			anim = { 'anim@melee@switchblade@holster', 'unholster', 200, 'anim@melee@switchblade@holster', 'holster', 600 },
		},
		['WEAPON_VINTAGEPISTOL'] = {
			label = 'مسدس قديم (Vintage Pistol)',
			weight = 700,
			durability = 0.1,
			ammoname = 'ammo-9'
		},
		['WEAPON_WRENCH'] = {
			label = 'مفتاح ربط (Wrench)',
			weight = 2500,
			durability = 0.1,
		},
	},

	Components = {
		['at_flashlight'] = {
			label = 'كشاف تكتيكي (Tactical Flashlight)',
			weight = 120,
			type = 'flashlight',
			client = {
				component = {
					`COMPONENT_AT_AR_FLSH`,
					`COMPONENT_AT_AR_FLSH_REH`,
					`COMPONENT_AT_PI_FLSH`,
					`COMPONENT_AT_PI_FLSH_02`,
					`COMPONENT_AT_PI_FLSH_03`,
				},
				usetime = 2500
			}
		},

		['at_suppressor_light'] = {
			label = 'كاتم صوت (Suppressor)',
			weight = 280,
			type = 'muzzle',
			client = {
                image = 'at_suppressor.png',
				component = {
					`COMPONENT_AT_PI_SUPP`,
					`COMPONENT_AT_PI_SUPP_02`,
					`COMPONENT_CERAMICPISTOL_SUPP`,
					`COMPONENT_PISTOLXM3_SUPP`
				},
				usetime = 2500
			}
		},

		['at_suppressor_heavy'] = {
			label = 'كاتم صوت تكتيكي (Tactical Suppressor)',
			weight = 280,
			type = 'muzzle',
			client = {
                image = 'at_suppressor.png',
				component = {
					`COMPONENT_AT_AR_SUPP`,
					`COMPONENT_AT_AR_SUPP_02`,
					`COMPONENT_AT_SR_SUPP`,
					`COMPONENT_AT_SR_SUPP_03`,
				},
				usetime = 2500
			}
		},

		['at_grip'] = {
			label = 'مقبض (Grip)',
			type = 'grip',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_AR_AFGRIP`,
					`COMPONENT_AT_AR_AFGRIP_02`
				},
				usetime = 2500
			}
		},

		['at_barrel'] = {
			label = 'ماسورة ثقيلة (Heavy Barrel)',
			type = 'barrel',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_AR_BARREL_02`,
					`COMPONENT_AT_BP_BARREL_02`,
					`COMPONENT_AT_CR_BARREL_02`,
					`COMPONENT_AT_MG_BARREL_02`,
					`COMPONENT_AT_MRFL_BARREL_02`,
					`COMPONENT_AT_SB_BARREL_02`,
					`COMPONENT_AT_SC_BARREL_02`,
					`COMPONENT_AT_SR_BARREL_02`,
				},
				usetime = 2500
			}
		},

		['at_clip_extended_pistol'] = {
			label = 'مخزن مسدس ممتد (Extended Pistol Clip)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_extended.png',
				component = {
					`COMPONENT_APPISTOL_CLIP_02`,
					`COMPONENT_CERAMICPISTOL_CLIP_02`,
					`COMPONENT_COMBATPISTOL_CLIP_02`,
					`COMPONENT_HEAVYPISTOL_CLIP_02`,
					`COMPONENT_PISTOL_CLIP_02`,
					`COMPONENT_PISTOL_MK2_CLIP_02`,
					`COMPONENT_PISTOL50_CLIP_02`,
					`COMPONENT_SNSPISTOL_CLIP_02`,
					`COMPONENT_SNSPISTOL_MK2_CLIP_02`,
					`COMPONENT_VINTAGEPISTOL_CLIP_02`,
                    `COMPONENT_TECPISTOL_CLIP_02`,
				},
				usetime = 2500
			}
		},

		['at_clip_extended_smg'] = {
			label = 'مخزن رشاش ممتد (Extended SMG Clip)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_extended.png',
				component = {
					`COMPONENT_ASSAULTSMG_CLIP_02`,
					`COMPONENT_COMBATPDW_CLIP_02`,
					`COMPONENT_MACHINEPISTOL_CLIP_02`,
					`COMPONENT_MICROSMG_CLIP_02`,
					`COMPONENT_MINISMG_CLIP_02`,
					`COMPONENT_SMG_CLIP_02`,
					`COMPONENT_SMG_MK2_CLIP_02`,
				},
				usetime = 2500
			}
		},

		['at_clip_extended_shotgun'] = {
			label = 'مخزن بندقية صيد ممتد (Extended Shotgun Clip)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_extended2.png',
				component = {
					`COMPONENT_ASSAULTSHOTGUN_CLIP_02`,
					`COMPONENT_HEAVYSHOTGUN_CLIP_02`,
				},
				usetime = 2500
			}
		},

		['at_clip_extended_rifle'] = {
			label = 'مخزن بندقية ممتد (Extended Rifle Clip)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_extended2.png',
				component = {
					`COMPONENT_ADVANCEDRIFLE_CLIP_02`,
					`COMPONENT_ASSAULTRIFLE_CLIP_02`,
					`COMPONENT_ASSAULTRIFLE_MK2_CLIP_02`,
					`COMPONENT_BULLPUPRIFLE_CLIP_02`,
					`COMPONENT_BULLPUPRIFLE_MK2_CLIP_02`,
					`COMPONENT_CARBINERIFLE_CLIP_02`,
					`COMPONENT_CARBINERIFLE_MK2_CLIP_02`,
					`COMPONENT_COMPACTRIFLE_CLIP_02`,
					`COMPONENT_HEAVYRIFLE_CLIP_02`,
					`COMPONENT_MILITARYRIFLE_CLIP_02`,
					`COMPONENT_SPECIALCARBINE_CLIP_02`,
					`COMPONENT_SPECIALCARBINE_MK2_CLIP_02`,
					`COMPONENT_TACTICALRIFLE_CLIP_02`,
					`COMPONENT_BATTLERIFLE_CLIP_02`,
				},
				usetime = 2500
			}
		},

		['at_clip_extended_mg'] = {
			label = 'مخزن رشاش ثقيل ممتد (Extended MG Clip)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_drum.png',
				component = {
					`COMPONENT_GUSENBERG_CLIP_02`,
					`COMPONENT_MG_CLIP_02`,
					`COMPONENT_COMBATMG_CLIP_02`,
					`COMPONENT_COMBATMG_MK2_CLIP_02`,
				},
				usetime = 2500
			}
		},

		['at_clip_extended_sniper'] = {
			label = 'مخزن قناصة ممتد (Extended Sniper Clip)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_extended2.png',
				component = {
					`COMPONENT_HEAVYSNIPER_MK2_CLIP_02`,
					`COMPONENT_MARKSMANRIFLE_CLIP_02`,
					`COMPONENT_MARKSMANRIFLE_MK2_CLIP_02`,
				},
				usetime = 2500
			}
		},

		['at_clip_drum_smg'] = {
			label = 'مخزن دائري للرشاش (SMG Drum)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_drum.png',
				component = {
					`COMPONENT_COMBATPDW_CLIP_03`,
					`COMPONENT_MACHINEPISTOL_CLIP_03`,
					`COMPONENT_SMG_CLIP_03`,
				},
				usetime = 2500
			}
		},

		['at_clip_drum_shotgun'] = {
			label = 'مخزن دائري لبندقية الصيد (Shotgun Drum)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_drum.png',
				component = {
					`COMPONENT_HEAVYSHOTGUN_CLIP_03`
				},
				usetime = 2500
			}
		},

		['at_clip_drum_rifle'] = {
			label = 'مخزن دائري للبندقية (Rifle Drum)',
			type = 'magazine',
			weight = 280,
			client = {
                image = 'at_clip_drum.png',
				component = {
					`COMPONENT_ASSAULTRIFLE_CLIP_03`,
					`COMPONENT_COMPACTRIFLE_CLIP_03`,
					`COMPONENT_CARBINERIFLE_CLIP_03`,
					`COMPONENT_SPECIALCARBINE_CLIP_03`,
				},
				usetime = 2500
			}
		},

		['at_compensator'] = {
			label = 'معوّض ارتداد (Compensator)',
			type = 'muzzle',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_PI_COMP`,
					`COMPONENT_AT_PI_COMP_02`,
					`COMPONENT_AT_PI_COMP_03`
				},
				usetime = 2500
			}
		},

		['at_scope_macro'] = {
			label = 'منظار ماكرو (Macro Scope)',
			type = 'sight',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_SCOPE_MACRO`,
					`COMPONENT_AT_SCOPE_MACRO_02`,
					`COMPONENT_AT_SCOPE_MACRO_MK2`,
					`COMPONENT_AT_SCOPE_MACRO_02_MK2`,
					`COMPONENT_AT_SCOPE_MACRO_02_SMG_MK2`
				},
				usetime = 2500
			}
		},

		['at_scope_small'] = {
			label = 'منظار صغير (Small Scope)',
			type = 'sight',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_SCOPE_SMALL`,
					`COMPONENT_AT_SCOPE_SMALL_02`,
					`COMPONENT_AT_SCOPE_SMALL_MK2`,
					`COMPONENT_AT_SCOPE_SMALL_SMG_MK2`
				},
				usetime = 2500
			}
		},

		['at_scope_medium'] = {
			label = 'منظار متوسط (Medium Scope)',
			type = 'sight',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_SCOPE_MEDIUM`,
					`COMPONENT_AT_SCOPE_MEDIUM_MK2`
				},
				usetime = 2500
			}
		},

		['at_scope_large'] = {
			label = 'منظار كبير (Large Scope)',
			type = 'sight',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_SCOPE_LARGE_MK2`
				},
				usetime = 2500
			}
		},

		['at_scope_advanced'] = {
			label = 'منظار متطور (Advanced Scope)',
			type = 'sight',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_SCOPE_MAX`
				},
				usetime = 2500
			}
		},

		['at_scope_nv'] = {
			label = 'منظار رؤية ليلية (NV Scope)',
			type = 'sight',
			weight = 420,
			client = {
				component = {
					`COMPONENT_AT_SCOPE_NV`
				},
				usetime = 2500
			}
		},

		['at_scope_thermal'] = {
			label = 'منظار حراري (Thermal Scope)',
			type = 'sight',
			weight = 420,
			client = {
				component = {
					`COMPONENT_AT_SCOPE_THERMAL`
				},
				usetime = 2500
			}
		},

		['at_scope_holo'] = {
			label = 'منظار هولوغرافي (Holographic Sight)',
			type = 'sight',
			weight = 280,
			client = {
				component = {
					`COMPONENT_AT_PI_RAIL`,
					`COMPONENT_AT_PI_RAIL_02`,
					`COMPONENT_AT_SIGHTS`,
					`COMPONENT_AT_SIGHTS_SMG`
				},
				usetime = 2500
			}
		},

		['at_muzzle_flat'] = {
			label = 'فوهة مسطحة (Flat Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_01`
				},
				usetime = 2500
			}
		},

		['at_muzzle_tactical'] = {
			label = 'فوهة تكتيكية (Tactical Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_02`
				},
				usetime = 2500
			}
		},

		['at_muzzle_fat'] = {
			label = 'فوهة عريضة (Fat Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_03`
				},
				usetime = 2500
			}
		},

		['at_muzzle_precision'] = {
			label = 'فوهة دقيقة (Precision Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_04`
				},
				usetime = 2500
			}
		},

		['at_muzzle_heavy'] = {
			label = 'فوهة ثقيلة (Heavy Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_05`
				},
				usetime = 2500
			}
		},

		['at_muzzle_slanted'] = {
			label = 'فوهة مائلة (Slanted Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_06`
				},
				usetime = 2500
			}
		},

		['at_muzzle_split'] = {
			label = 'فوهة مشقوقة (Split Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_07`
				},
				usetime = 2500
			}
		},

		['at_muzzle_squared'] = {
			label = 'فوهة مربعة (Squared Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_08`
				},
				usetime = 2500
			}
		},

		['at_muzzle_bell'] = {
			label = 'فوهة جرسية (Bell Muzzle)',
			type = 'muzzle',
			weight = 80,
			client = {
				component = {
					`COMPONENT_AT_MUZZLE_09`
				},
				usetime = 2500
			}
		},

		['at_skin_luxe'] = {
			label = 'طلاء سلاح فاخر (Luxury Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_VARMOD_LUXE`,
					`COMPONENT_ASSAULTSMG_VARMOD_LOWRIDER`,
					`COMPONENT_CARBINERIFLE_VARMOD_LUXE`,
					`COMPONENT_COMBATPISTOL_VARMOD_LOWRIDER`,
					`COMPONENT_MARKSMANRIFLE_VARMOD_LUXE`,
					`COMPONENT_MG_VARMOD_LOWRIDER`,
					`COMPONENT_MICROSMG_VARMOD_LUXE`,
					`COMPONENT_PISTOL_VARMOD_LUXE`,
					`COMPONENT_PUMPSHOTGUN_VARMOD_LOWRIDER`,
					`COMPONENT_SMG_VARMOD_LUXE`
				},
				usetime = 2500
			}
		},

		['at_skin_wood'] = {
			label = 'طلاء سلاح خشبي (Wood Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_HEAVYPISTOL_VARMOD_LUXE`,
					`COMPONENT_SNIPERRIFLE_VARMOD_LUXE`,
					`COMPONENT_SNSPISTOL_VARMOD_LOWRIDER`
				},
				usetime = 2500
			}
		},

		['at_skin_metal'] = {
			label = 'طلاء سلاح معدني (Metal Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ADVANCEDRIFLE_VARMOD_LUXE`,
					`COMPONENT_APPISTOL_VARMOD_LUXE`,
					`COMPONENT_BULLPUPRIFLE_VARMOD_LOW`,
					`COMPONENT_SAWNOFFSHOTGUN_VARMOD_LUXE`,
					`COMPONENT_SPECIALCARBINE_VARMOD_LOWRIDER`
				},
				usetime = 2500
			}
		},

		['at_skin_pearl'] = {
			label = 'طلاء سلاح لؤلؤي (Pearl Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_PISTOL50_VARMOD_LUXE`
				},
				usetime = 2500
			}
		},

		['at_skin_ballas'] = {
			label = 'طلاء سلاح بالاس (Ballas Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_BALLAS`
				},
				usetime = 2500
			}
		},

		['at_skin_diamond'] = {
			label = 'طلاء سلاح ألماسي (Diamond Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_DIAMOND`
				},
				usetime = 2500
			}
		},

		['at_skin_dollar'] = {
			label = 'طلاء سلاح الدولار (Dollar Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_DOLLAR`
				},
				usetime = 2500
			}
		},

		['at_skin_hate'] = {
			label = 'طلاء سلاح الكره (Hate Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_HATE`
				},
				usetime = 2500
			}
		},

		['at_skin_king'] = {
			label = 'طلاء سلاح الملك (King Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_KING`
				},
				usetime = 2500
			}
		},

		['at_skin_love'] = {
			label = 'طلاء سلاح الحب (Love Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_LOVE`
				},
				usetime = 2500
			}
		},

		['at_skin_pimp'] = {
			label = 'طلاء سلاح فاخر لامع (Pimp Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_PIMP`
				},
				usetime = 2500
			}
		},

		['at_skin_player'] = {
			label = 'طلاء سلاح اللاعب (Player Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_PLAYER`
				},
				usetime = 2500
			}
		},

		['at_skin_vagos'] = {
			label = 'طلاء سلاح فاغوس (Vagos Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_KNUCKLE_VARMOD_VAGOS`
				},
				usetime = 2500
			}
		},

		['at_skin_blagueurs'] = {
			label = 'طلاء سلاح بلاغور (Blagueurs Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3`
				},
				usetime = 2500
			}
		},

		['at_skin_splatter'] = {
			label = 'طلاء سلاح مرشوش (Splatter Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_01`
				},
				usetime = 2500
			}
		},

		['at_skin_bulletholes'] = {
			label = 'طلاء سلاح ثقوب الرصاص (Bullet Holes Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_02`
				},
				usetime = 2500
			}
		},

		['at_skin_burgershot'] = {
			label = 'طلاء سلاح برغر شوت (Burger Shot Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_03`
				},
				usetime = 2500
			}
		},

		['at_skin_cluckinbell'] = {
			label = 'طلاء سلاح كلوكن بيل (Cluckin Bell Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_04`
				},
				usetime = 2500
			}
		},

		['at_skin_fatalincursion'] = {
			label = 'طلاء سلاح الغزو (Fatal Incursion Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_05`
				},
				usetime = 2500
			}
		},

		['at_skin_luchalibre'] = {
			label = 'طلاء سلاح المصارعة (Lucha Libre Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_06`
				},
				usetime = 2500
			}
		},

		['at_skin_trippy'] = {
			label = 'طلاء سلاح ملوّن (Trippy Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_07`
				},
				usetime = 2500
			}
		},

		['at_skin_tiedye'] = {
			label = 'طلاء سلاح مصبوغ (Tie-Dye Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_08`
				},
				usetime = 2500
			}
		},

		['at_skin_wall'] = {
			label = 'طلاء سلاح الجدار (Wall Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_BAT_VARMOD_XM3_09`
				},
				usetime = 2500
			}
		},

		['at_skin_vip'] = {
			label = 'طلاء سلاح كبار الشخصيات (VIP Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_REVOLVER_VARMOD_BOSS`,
					`COMPONENT_SWITCHBLADE_VARMOD_VAR1`
				},
				usetime = 2500
			}
		},

		['at_skin_bodyguard'] = {
			label = 'طلاء سلاح الحارس الشخصي (Bodyguard Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_REVOLVER_VARMOD_GOON`,
					`COMPONENT_SWITCHBLADE_VARMOD_VAR2`
				},
				usetime = 2500
			}
		},

		['at_skin_festive'] = {
			label = 'طلاء سلاح الأعياد (Festive Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_RAYPISTOL_VARMOD_XMAS18`
				},
				usetime = 2500
			}
		},

		['at_skin_security'] = {
			label = 'طلاء سلاح الأمن (Security Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_APPISTOL_VARMOD_SECURITY`,
					`COMPONENT_MICROSMG_VARMOD_SECURITY`,
				},
				usetime = 2500
			}
		},

		['at_skin_camo'] = {
			label = 'طلاء سلاح مموّه (Camo Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO`,
					`COMPONENT_COMBATMG_MK2_CAMO`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO`,
					`COMPONENT_PISTOL_MK2_CAMO`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO`,
					`COMPONENT_REVOLVER_MK2_CAMO`,
					`COMPONENT_SMG_MK2_CAMO`,
					`COMPONENT_SNSPISTOL_MK2_CAMO`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO`,
				},
				usetime = 2500
			}
		},

		['at_skin_brushstroke'] = {
			label = 'طلاء سلاح ضربات الفرشاة (Brushstroke Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_02`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_02`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_02`,
					`COMPONENT_COMBATMG_MK2_CAMO_02`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_02`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_02`,
					`COMPONENT_PISTOL_MK2_CAMO_02`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_02`,
					`COMPONENT_REVOLVER_MK2_CAMO_02`,
					`COMPONENT_SMG_MK2_CAMO_02`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_02`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_02`,
				},
				usetime = 2500
			}
		},

		['at_skin_woodland'] = {
			label = 'طلاء سلاح الغابة (Woodland Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_03`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_03`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_03`,
					`COMPONENT_COMBATMG_MK2_CAMO_03`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_03`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_03`,
					`COMPONENT_PISTOL_MK2_CAMO_03`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_03`,
					`COMPONENT_REVOLVER_MK2_CAMO_03`,
					`COMPONENT_SMG_MK2_CAMO_03`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_03`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_03`,
				},
				usetime = 2500
			}
		},

		['at_skin_skull'] = {
			label = 'طلاء سلاح الجمجمة (Skull Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_04`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_04`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_04`,
					`COMPONENT_COMBATMG_MK2_CAMO_04`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_04`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_04`,
					`COMPONENT_PISTOL_MK2_CAMO_04`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_04`,
					`COMPONENT_REVOLVER_MK2_CAMO_04`,
					`COMPONENT_SMG_MK2_CAMO_04`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_04`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_04`,
				},
				usetime = 2500
			}
		},

		['at_skin_sessanta'] = {
			label = 'طلاء سلاح سيسانتا (Sessanta Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_05`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_05`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_05`,
					`COMPONENT_COMBATMG_MK2_CAMO_05`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_05`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_05`,
					`COMPONENT_PISTOL_MK2_CAMO_05`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_05`,
					`COMPONENT_REVOLVER_MK2_CAMO_05`,
					`COMPONENT_SMG_MK2_CAMO_05`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_05`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_05`,
				},
				usetime = 2500
			}
		},

		['at_skin_perseus'] = {
			label = 'طلاء سلاح بيرسيوس (Perseus Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_06`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_06`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_06`,
					`COMPONENT_COMBATMG_MK2_CAMO_06`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_06`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_06`,
					`COMPONENT_PISTOL_MK2_CAMO_06`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_06`,
					`COMPONENT_REVOLVER_MK2_CAMO_06`,
					`COMPONENT_SMG_MK2_CAMO_06`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_06`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_06`,
				},
				usetime = 2500
			}
		},

		['at_skin_leopard'] = {
			label = 'طلاء سلاح الفهد (Leopard Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_07`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_07`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_07`,
					`COMPONENT_COMBATMG_MK2_CAMO_07`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_07`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_07`,
					`COMPONENT_PISTOL_MK2_CAMO_07`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_07`,
					`COMPONENT_REVOLVER_MK2_CAMO_07`,
					`COMPONENT_SMG_MK2_CAMO_07`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_07`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_07`,
				},
				usetime = 2500
			}
		},

		['at_skin_zebra'] = {
			label = 'طلاء سلاح الحمار الوحشي (Zebra Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_08`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_08`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_08`,
					`COMPONENT_COMBATMG_MK2_CAMO_08`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_08`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_08`,
					`COMPONENT_PISTOL_MK2_CAMO_08`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_08`,
					`COMPONENT_REVOLVER_MK2_CAMO_08`,
					`COMPONENT_SMG_MK2_CAMO_08`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_08`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_08`,
				},
				usetime = 2500
			}
		},

		['at_skin_geometric'] = {
			label = 'طلاء سلاح هندسي (Geometric Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_09`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_09`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_09`,
					`COMPONENT_COMBATMG_MK2_CAMO_09`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_09`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_09`,
					`COMPONENT_PISTOL_MK2_CAMO_09`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_09`,
					`COMPONENT_REVOLVER_MK2_CAMO_09`,
					`COMPONENT_SMG_MK2_CAMO_09`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_09`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_09`,
				},
				usetime = 2500
			}
		},

		['at_skin_boom'] = {
			label = 'طلاء سلاح الانفجار (Boom Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_10`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_10`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_10`,
					`COMPONENT_COMBATMG_MK2_CAMO_10`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_10`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_10`,
					`COMPONENT_PISTOL_MK2_CAMO_10`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_10`,
					`COMPONENT_REVOLVER_MK2_CAMO_10`,
					`COMPONENT_SMG_MK2_CAMO_10`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_10`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_10`,
				},
				usetime = 2500
			}
		},

		['at_skin_patriotic'] = {
			label = 'طلاء سلاح وطني (Patriotic Weapon Kit)',
			type = 'skin',
			weight = 50,
			client = {
				component = {
					`COMPONENT_ASSAULTRIFLE_MK2_CAMO_IND_01`,
					`COMPONENT_BULLPUPRIFLE_MK2_CAMO_IND_01`,
					`COMPONENT_CARBINERIFLE_MK2_CAMO_IND_01`,
					`COMPONENT_COMBATMG_MK2_CAMO_IND_01`,
					`COMPONENT_HEAVYSNIPER_MK2_CAMO_IND_01`,
					`COMPONENT_MARKSMANRIFLE_MK2_CAMO_IND_01`,
					`COMPONENT_PISTOL_MK2_CAMO_IND_01`,
					`COMPONENT_PUMPSHOTGUN_MK2_CAMO_IND_01`,
					`COMPONENT_REVOLVER_MK2_CAMO_IND_01`,
					`COMPONENT_SMG_MK2_CAMO_IND_01`,
					`COMPONENT_SNSPISTOL_MK2_CAMO_IND_01`,
					`COMPONENT_SPECIALCARBINE_MK2_CAMO_IND_01`,
				},
				usetime = 2500
			}
		},
	},

	Ammo = {
		['ammo-22'] = {
			label = 'ذخيرة (.22 LR)',
			weight = 3,
		},

		['ammo-38'] = {
			label = 'ذخيرة (.38 LC)',
			weight = 15,
		},

		['ammo-44'] = {
			label = 'ذخيرة (.44 Magnum)',
			weight = 16,
		},

		['ammo-45'] = {
			label = 'ذخيرة (.45 ACP)',
			weight = 15,
		},

		['ammo-50'] = {
			label = 'ذخيرة (.50 AE)',
			weight = 45,
		},

		['ammo-9'] = {
			label = 'ذخيرة (9mm)',
			weight = 7,
		},

		['ammo-firework'] = {
			label = 'ألعاب نارية (Firework)',
			weight = 200,
		},

		['ammo-flare'] = {
			label = 'طلقة إشارة (Flare Round)',
			weight = 38,
		},

		['ammo-grenade'] = {
			label = 'قذيفة متفجرة (40mm)',
			weight = 400,
		},

		['ammo-heavysniper'] = {
			label = 'ذخيرة (.50 BMG)',
			weight = 51,
		},

		['ammo-laser'] = {
			label = 'شحنة ليزر (Laser Charge)',
			weight = 1,
		},

		['ammo-musket'] = {
			label = 'ذخيرة كروية (.50)',
			weight = 38,
		},

		['ammo-railgun'] = {
			label = 'شحنة المدفع الكهرومغناطيسي (Railgun Charge)',
			weight = 150,
		},

		['ammo-rifle'] = {
			label = 'ذخيرة (5.56x45)',
			weight = 4,
		},

		['ammo-rifle2'] = {
			label = 'ذخيرة (7.62x39)',
			weight = 8,
		},

		['ammo-rocket'] = {
			label = 'صاروخ (Rocket)',
			weight = 500,
		},

		['ammo-shotgun'] = {
			label = 'ذخيرة صيد (12 Gauge)',
			weight = 38,
		},

		['ammo-sniper'] = {
			label = 'ذخيرة (7.62x51)',
			weight = 9,
		},

		['ammo-emp'] = {
			label = 'قذيفة نبض كهرومغناطيسي (EMP Round)',
			weight = 400,
		},
	}
}
