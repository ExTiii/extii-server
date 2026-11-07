-- =====================================================================
-- EX_Tii used cars: one buyer. Drive your own car next to him, get out, talk to him (E).
-- He pays `share` of the car's dealership price, times its condition (a wreck gets `minCondition`).
-- Admins: /usedcarspot = the buyer stands where you stand, looking where you look (saved).
-- =====================================================================
Config = {
    spot = vec4(1224.80, 2727.70, 38.00, 180.0),   -- Larry's RV Sales, Sandy Shores (move it with /usedcarspot)
    ped = 'a_m_m_salton_02',
    blip = { sprite = 225, colour = 46, scale = 0.75, label = 'شراء المركبات المستعملة' },
    carReach = 15.0,      -- your car must be parked this close to the buyer
    share = 0.50,         -- half the dealership price
    minCondition = 0.70,  -- a badly damaged car still gets 70% of that
}
