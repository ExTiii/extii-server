---Job names must be lower case (top level table key)
---@type table<string, Job>
return {
    ['unemployed'] = {
        label = 'مدني',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'عامل حر',
                payment = 10
            },
        },
    },
    ['police'] = {
        label = 'شرطة لوس سانتوس (LSPD)',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مستجد',
                payment = 50
            },
            [1] = {
                name = 'ضابط',
                payment = 75
            },
            [2] = {
                name = 'رقيب',
                payment = 100
            },
            [3] = {
                name = 'ملازم',
                payment = 125
            },
            [4] = {
                name = 'قائد',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['bcso'] = {
        label = 'شرطة مقاطعة بلين (BCSO)',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مستجد',
                payment = 50
            },
            [1] = {
                name = 'ضابط',
                payment = 75
            },
            [2] = {
                name = 'رقيب',
                payment = 100
            },
            [3] = {
                name = 'ملازم',
                payment = 125
            },
            [4] = {
                name = 'قائد',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['sasp'] = {
        label = 'شرطة ولاية سان أندرياس (SASP)',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مستجد',
                payment = 50
            },
            [1] = {
                name = 'ضابط',
                payment = 75
            },
            [2] = {
                name = 'رقيب',
                payment = 100
            },
            [3] = {
                name = 'ملازم',
                payment = 125
            },
            [4] = {
                name = 'قائد',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['ambulance'] = {
        label = 'الإسعاف (EMS)',
        type = 'ems',
        defaultDuty = false, -- EX_Tii: medics clock in at the hospital (exti_ems)
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مستجد',
                payment = 50
            },
            [1] = {
                name = 'مسعف',
                payment = 75
            },
            [2] = {
                name = 'طبيب',
                payment = 100
            },
            [3] = {
                name = 'جرّاح',
                payment = 125
            },
            [4] = {
                name = 'قائد',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['realestate'] = {
        label = 'العقارات',
        type = 'realestate',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مستجد',
                payment = 50
            },
            [1] = {
                name = 'مبيعات المنازل',
                payment = 75
            },
            [2] = {
                name = 'مبيعات تجارية',
                payment = 100
            },
            [3] = {
                name = 'وسيط',
                payment = 125
            },
            [4] = {
                name = 'مدير',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['taxi'] = {
        label = 'سيارات الأجرة',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مستجد',
                payment = 50
            },
            [1] = {
                name = 'سائق',
                payment = 75
            },
            [2] = {
                name = 'سائق مناسبات',
                payment = 100
            },
            [3] = {
                name = 'مبيعات',
                payment = 125
            },
            [4] = {
                name = 'مدير',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['bus'] = {
        label = 'الحافلات',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'سائق',
                payment = 50
            },
        },
    },
    ['cardealer'] = {
        label = 'معرض المركبات',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مستجد',
                payment = 50
            },
            [1] = {
                name = 'مبيعات المعرض',
                payment = 75
            },
            [2] = {
                name = 'مبيعات تجارية',
                payment = 100
            },
            [3] = {
                name = 'التمويل',
                payment = 125
            },
            [4] = {
                name = 'مدير',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['mechanic'] = {
        label = 'ورشة الميكانيكي',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'متدرب',
                payment = 50
            },
            [1] = {
                name = 'ميكانيكي',
                payment = 75
            },
            [2] = {
                name = 'فني',
                payment = 100
            },
            [3] = {
                name = 'مشرف',
                payment = 125
            },
            [4] = {
                name = 'مدير',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['judge'] = {
        label = 'فخري',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'قاضٍ',
                payment = 100
            },
        },
    },
    ['lawyer'] = {
        label = 'مكتب المحاماة',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'محامٍ مساعد',
                payment = 50
            },
        },
    },
    ['reporter'] = {
        label = 'الأخبار',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'صحفي',
                payment = 50
            },
        },
    },
    ['trucker'] = {
        label = 'النقل بالشاحنات',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'سائق',
                payment = 50
            },
        },
    },
    ['tow'] = {
        label = 'السحب',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'سائق',
                payment = 50
            },
        },
    },
    ['garbage'] = {
        label = 'النظافة',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'عامل جمع',
                payment = 50
            },
        },
    },
    ['delivery'] = { -- EX_Tii: GoPostal delivery driver (exti_jobs)
        label = 'التوصيل',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'عامل توصيل',
                payment = 50
            },
        },
    },
    ['chicken'] = { -- EX_Tii: level job (exti_jobs), player level 3
        label = 'الدواجن',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'عامل دواجن',
                payment = 50
            },
        },
    },
    ['raisin'] = { -- EX_Tii: level job (exti_jobs), player level 8
        label = 'الزبيب',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'عامل زبيب',
                payment = 50
            },
        },
    },
    ['bread'] = { -- EX_Tii: level job (exti_jobs), player level 15
        label = 'المخابز',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'خبّاز',
                payment = 50
            },
        },
    },
    ['fishing'] = { -- EX_Tii: level job (exti_jobs), player level 22
        label = 'الصيد',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'صياد سمك',
                payment = 50
            },
        },
    },
    ['metals'] = { -- EX_Tii: level job (exti_jobs), player level 30
        label = 'المعادن',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'عامل معادن',
                payment = 50
            },
        },
    },
    ['fabrics'] = { -- EX_Tii: level job (exti_jobs), player level 40
        label = 'النسيج',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'عامل أقمشة',
                payment = 50
            },
        },
    },
    ['vineyard'] = {
        label = 'مزرعة العنب',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'قاطف',
                payment = 50
            },
        },
    },
    ['hotdog'] = {
        label = 'عربة النقانق',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'مبيعات',
                payment = 50
            },
        },
    },
}
