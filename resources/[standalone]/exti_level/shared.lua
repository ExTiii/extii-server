-- The curve (shared by the game and the server): XP needed from level 1 to reach `level`.
LVL = LVL or {}

-- the anchors (Config.anchors), sorted: { level, total XP }; between two anchors every level costs the same
local A = {}
for _, a in ipairs(Config.anchors) do A[#A + 1] = { math.floor(a[1]), math.floor(a[2]) } end
table.sort(A, function(x, y) return x[1] < y[1] end)
if A[1][1] ~= 1 then table.insert(A, 1, { 1, 0 }) end
if A[#A][1] < Config.maxLevel then A[#A + 1] = { Config.maxLevel, A[#A][2] } end
local TOTAL = A[#A][2]

function LVL.xpFor(level)
    level = math.max(1, math.min(Config.maxLevel, math.floor(level)))
    if level <= 1 then return 0 end
    for i = 2, #A do
        local lo, hi = A[i - 1], A[i]
        if level <= hi[1] then
            return math.floor(lo[2] + (hi[2] - lo[2]) * (level - lo[1]) / (hi[1] - lo[1]) + 0.5)
        end
    end
    return TOTAL
end

function LVL.levelOf(xp)
    xp = math.max(0, math.floor(tonumber(xp) or 0))
    local lo, hi = 1, Config.maxLevel
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if LVL.xpFor(mid) <= xp then lo = mid else hi = mid - 1 end
    end
    return lo
end

-- everything a screen needs: level, XP inside this level, how much this level needs, %
function LVL.info(xp)
    xp = math.max(0, math.floor(tonumber(xp) or 0))
    local level = LVL.levelOf(xp)
    local from = LVL.xpFor(level)
    local max = level >= Config.maxLevel
    local to = max and from or LVL.xpFor(level + 1)
    local inLevel, need = xp - from, to - from
    return {
        level = level, xp = xp, max = max,
        cur = inLevel, need = need,
        pct = max and 100 or math.floor(inLevel / math.max(1, need) * 1000) / 10,
    }
end

LVL.TOTAL = TOTAL
