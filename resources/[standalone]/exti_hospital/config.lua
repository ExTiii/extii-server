-- EX_Tii hospitals (both open 24/7).
-- The receptionist (exti_shops) opens this panel: free treatment in a bed, a free check-up that
-- gives you a medical report, and calling a medic. The pharmacist next to her sells the medicine.

Config = {}

-- name = the hospital's name in qbx_ambulancejob (its beds and check-in)
-- reception = where you stand at the reception counter (same spot as in exti_shops)
Config.hospitals = {
    pillbox = {
        label = 'مستشفى بيلبوكس',
        reception = vec3(308.13, -595.24, 43.33),
    },
    paleto = {
        label = 'مركز باليتو الطبي',
        reception = vec3(-254.24, 6331.54, 32.42),
    },
}

Config.reach = 3.0              -- how close to the reception counter you must be (meters)
Config.treatTime = 20           -- seconds in bed until the doctor has treated you (same as qbx_ambulancejob)
Config.checkupTime = 8          -- seconds the check-up takes
Config.checkupCooldown = 10     -- minutes before the same person can get another check-up
Config.callCooldown = 2         -- minutes between two "call a medic" from the same person

-- the doctors who sign the medical reports
Config.doctors = {
    'د. سامي الحربي', 'د. ليلى منصور', 'د. خالد العمري',
    'د. نورة القحطاني', 'د. ياسر حداد', 'د. ريم الشمري',
}
