-- =====================================================================
-- EX_Tii heists: the fence's daily contracts. Every day (from 06:00 server time) each character gets 3 small
-- jobs by text from the fence: "rob 2 stores", "pull an ATM", "bring me 3 watches"... Done = bonus Rep XP and
-- dirty money, paid the moment the last step is done. Text him "مهام" to see where you are.
-- =====================================================================
local C = Config
local CT = C.contracts

local function dayKey()
    local t = os.time() - (CT.dayStartsHour or 6) * 3600
    return os.date('%Y-%m-%d', t)
end

-- [cid] = { day, list = { { id, text, kind, need, have, done } } }
local function load(cid)
    local ok, v = pcall(json.decode, GetResourceKvpString('contracts:' .. cid) or '')
    return ok and type(v) == 'table' and v or nil
end
local function save(cid, v) SetResourceKvp('contracts:' .. cid, json.encode(v)) end

local function roll(src)
    local lv = H.repLevel(src)
    local pool = {}
    for _, c in ipairs(CT.pool) do if lv >= (c.minRep or 1) then pool[#pool + 1] = c end end
    for i = #pool, 2, -1 do local j = math.random(i); pool[i], pool[j] = pool[j], pool[i] end
    local list = {}
    for k = 1, math.min(CT.perDay, #pool) do
        local c = pool[k]
        local need = type(c.need) == 'table' and math.random(c.need[1], c.need[2]) or c.need
        list[#list + 1] = { id = c.id, kind = c.kind, item = c.item, need = need, have = 0, done = false, text = c.text:format(need) }
    end
    return list
end

local function mine(src, create)
    local cid = H.cid(src); if not cid then return nil end
    local v = load(cid)
    if (not v or v.day ~= dayKey()) and create then
        v = { day = dayKey(), list = roll(src) }
        save(cid, v)
        local lines = {}
        for i, c in ipairs(v.list) do lines[#lines + 1] = ('%d) %s'):format(i, c.text) end
        H.text(src, 'شغل اليوم:\n' .. table.concat(lines, '\n') .. '\nخلّصها وأدفع لك. اضغط "مهام اليوم" لترى أين وصلت.')
    end
    return v, cid
end

-- robberies tell us what happened: H.contract(src, 'store'), H.contract(src, 'sell', { item = 'rolex', n = 2 })
function H.contract(src, kind, data)
    local v, cid = mine(src, false)
    if not v or v.day ~= dayKey() then return end
    local changed = false
    for _, c in ipairs(v.list) do
        if not c.done and c.kind == kind and (not c.item or (data and data.item == c.item)) then
            c.have = math.min(c.need, c.have + ((data and data.n) or 1))
            changed = true
            if c.have >= c.need then
                c.done = true
                local cash = math.random(CT.reward.money[1], CT.reward.money[2])
                exports.ox_inventory:AddItem(src, 'black_money', cash)
                H.addXP(src, CT.reward.xp, 'contract ' .. c.id)
                H.text(src, ('تمام: "%s". أرسلت لك %d$. '):format(c.text, cash))
                H.log(src, 'contract_done', ('%s · $%d'):format(c.id, cash))
            end
        end
    end
    if changed then save(cid, v) end
end

function H.contractStatus(src)
    local v = mine(src, true)
    if not v then return end
    local lines = {}
    for i, c in ipairs(v.list) do lines[#lines + 1] = ('%d) %s · %s'):format(i, c.text, c.done and 'تم' or ('%d/%d'):format(c.have, c.need)) end
    H.text(src, table.concat(lines, '\n'))
end

-- the first time a character is in the city on a new day: today's contracts by text (non-cops only)
local function greet(src)
    SetTimeout(math.random(45, 90) * 1000, function()
        if not GetPlayerName(src) or H.isCopOnDuty(src) then return end
        -- only those who know him: some Rep, or he gave them his number
        local r, cid = H.rec(src)
        if not cid or not ((r and r.xp > 0) or GetResourceKvpInt('fencemet:' .. cid) == 1) then return end
        mine(src, true)
    end)
end
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() greet(source) end)
CreateThread(function()
    local last = dayKey()
    while true do
        Wait(60000)
        if dayKey() ~= last then
            last = dayKey()
            for _, s in ipairs(GetPlayers()) do greet(tonumber(s)) end
        end
    end
end)
