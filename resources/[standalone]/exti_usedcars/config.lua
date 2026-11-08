-- =====================================================================
-- EX_Tii used-car lot (Moe's design):
--   * the SELLER parks his own car next to the lot manager, gets out, presses E and sets a price between
--     75% and 125% of the car's dealership price. The car leaves his garage and stands on the lot.
--   * any other player walks up to a car on the lot, sees the name and the price, presses E and buys it:
--     the money goes to the seller's bank (even if he is away), the car is the buyer's, he drives it away.
--   * the seller can take his car back from the lot manager at any time (free).
-- Admins: /usedcarspot   = the manager stands where you stand, looking where you look
--         /usedcarslot   = a parking place for a car on the lot (sit in a car parked right, or stand there)
--         /usedcarslot clear = remove every parking place (cars already there stay listed)
-- =====================================================================
Config = {
    spot = vec4(1224.80, 2727.70, 38.00, 180.0),   -- Larry's RV Sales, Sandy Shores (move it with /usedcarspot)
    ped = 'a_m_m_salton_02',
    blip = { sprite = 810, colour = 1, scale = 0.675, label = 'معرض السيارات المستعملة' },   -- the dealership icon, red
    carReach = 15.0,      -- the seller's car must be parked this close to the manager
    minShare = 0.75,      -- the lowest price allowed: 75% of the dealership price
    maxShare = 1.25,      -- the highest: 125%
    perSeller = 2,        -- cars one person may have on the lot at once
}
