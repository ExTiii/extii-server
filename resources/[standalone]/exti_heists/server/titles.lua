-- =====================================================================
-- EX_Tii heists: titles (achievements) and the admins' spot fixer.
--   H.title(src, key, text): a title once per character (kept forever, shown in the Crew app)
--   /heistspot <bank or yacht> <step number>   stand where the [E] should be, then type it
--   /heistspot <bank> box <n>                  the same for a deposit box
--   /heistspot <bank or yacht> <step> clear    back to the config
-- The fixes live in KVP (a restart keeps them) and reach every game through GlobalState.
-- =====================================================================
local C = Config

function H.title(src, key, text)
    local cid = H.cid(src); if not cid then return end
    local k = ('title:%s:%s'):format(cid, key)
    if GetResourceKvpInt(k) == 1 then return end
    SetResourceKvpInt(k, 1)
    MySQL.insert('INSERT INTO `exti_heist_titles` (`cid`, `title`, `at`) VALUES (?, ?, ?)', { cid, text, os.time() })
    H.notify(src, ('لقب جديد: %s'):format(text), 'success', 9000)
    H.log(src, 'title', text)
end
-- the first in the whole city to do something
function H.firstEver(src, key, text)
    if GetResourceKvpInt('first:' .. key) == 1 then return end
    SetResourceKvpInt('first:' .. key, 1)
    H.title(src, 'first_' .. key, text)
end
-- a count per character (10 Big Scores, ...)
function H.countUp(src, key)
    local cid = H.cid(src); if not cid then return 0 end
    local k = ('count:%s:%s'):format(cid, key)
    local n = GetResourceKvpInt(k) + 1
    SetResourceKvpInt(k, n)
    return n
end

---------------------------------------------------------------------------
-- spot fixes
---------------------------------------------------------------------------
local fixes = {}
do local ok, v = pcall(json.decode, GetResourceKvpString('spotfix') or ''); if ok and type(v) == 'table' then fixes = v end end
local function publish() GlobalState['exti_heists:spotfix'] = fixes end
CreateThread(function() Wait(800); publish() end)
function H.spotFix(id, key)
    local f = fixes[('%s:%s'):format(id, tostring(key))]
    return f and vec3(f.x, f.y, f.z) or nil
end

lib.addCommand('heistspot', {
    help = 'Heists: put a bank / yacht [E] spot where you stand (admin)',
    params = {
        { name = 'id', help = 'fleeca_legion, fleeca_alta, fleeca_hawick, fleeca_delperro, fleeca_ocean, fleeca_route68, paleto, pacific, yacht' },
        { name = 'what', help = 'the step number, or box' },
        { name = 'n', help = 'the box number, or clear', optional = true },
    },
    restricted = 'group.admin',
}, function(src, args)
    local id, what, n = tostring(args.id), tostring(args.what), args.n and tostring(args.n)
    local isYacht = id == 'yacht'
    local v = isYacht and C.yacht or C.vaults[id]
    if not v then return H.notify(src, 'لا يوجد بهذا الاسم', 'error') end
    local key
    if what == 'box' then
        local i = math.tointeger(tonumber(n))
        if not i or not v.lockers or not v.lockers[i] then return H.notify(src, 'رقم صندوق خطأ', 'error') end
        key = 'box' .. i; n = nil
    else
        local k = math.tointeger(tonumber(what))
        if not k or not v.steps[k] then return H.notify(src, 'رقم خطوة خطأ', 'error') end
        key = tostring(k)
    end
    local full = ('%s:%s'):format(id, key)
    if n == 'clear' then fixes[full] = nil
    else
        local c = H.coords(src); if not c then return end
        fixes[full] = { x = math.floor(c.x * 100 + 0.5) / 100, y = math.floor(c.y * 100 + 0.5) / 100, z = math.floor(c.z * 100 + 0.5) / 100 }
    end
    SetResourceKvp('spotfix', json.encode(fixes))
    publish()
    H.log(src, 'heistspot', ('%s %s'):format(full, n == 'clear' and 'cleared' or json.encode(fixes[full])))
    H.notify(src, n == 'clear' and ('رجع %s لمكانه في الإعدادات'):format(full) or ('تم: %s هنا'):format(full), 'success')
end)
