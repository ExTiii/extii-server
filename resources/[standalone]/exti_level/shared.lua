-- The curve (shared by the game and the server): XP needed from level 1 to reach `level`.
LVL = LVL or {}

local TOTAL = Config.hoursToMax * Config.xpPerHour

function LVL.xpFor(level)
    level = math.max(1, math.min(Config.maxLevel, math.floor(level)))
    if level <= 1 then return 0 end
    return math.floor(TOTAL * ((level - 1) / (Config.maxLevel - 1)) ^ Config.curve + 0.5)
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
