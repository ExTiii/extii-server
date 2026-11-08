return {

    idCardSettings = {
        -- EX_Tii: the card never takes the mouse or keyboard, so you can keep playing while it is shown.
        -- It closes by itself after `showTime` milliseconds, or right away with Backspace.
        showTime = 8000,
    },

    -- accent = the colour line of each card (server design kit colours)
    licenses = {
        ['id_card'] = {
            header = 'بطاقة الهوية',
            accent = '#20c997',
            prop = 'prop_franklin_dl'
        },
        ['driver_license'] = {
            header = 'رخصة القيادة',
            accent = '#62b3ff',
            prop = 'prop_franklin_dl',
        },
        ['truck_license'] = {
            header = 'رخصة قيادة الشاحنات',
            accent = '#f6a94a',
            prop = 'prop_franklin_dl',
        },
        ['boat_license'] = {
            header = 'رخصة قيادة القوارب',
            accent = '#3ddc97',
            prop = 'prop_franklin_dl',
        },
        ['heli_license'] = {
            header = 'رخصة الطيران',
            accent = '#c084fc',
            prop = 'prop_franklin_dl',
        },
        ['weaponlicense'] = {
            header = 'رخصة السلاح',
            accent = '#ff5f5f',
            prop = 'prop_franklin_dl',
        },
        ['lawyerpass'] = {
            header = 'تصريح المحاماة',
            accent = '#3ddc97',
            prop = 'prop_cs_r_business_card'
        }
    }
}
