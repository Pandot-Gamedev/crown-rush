-- Runner level. Courses, tournaments and quests give XP.
-- Your level shows above your head, pays coins each time it goes up, and some
-- levels unlock a free cosmetic (see Cosmetics.luau, source = "level").

local Level = {}

Level.CoinsPerLevel = 10 -- reward for reaching level N is N * this
Level.Max = 50

-- Total XP needed to reach a level (level 1 needs 0)
function Level.XpFor(level)
	return math.floor(60 * (level - 1) ^ 1.5)
end

function Level.FromXp(xp)
	local level = 1
	while level < Level.Max and Level.XpFor(level + 1) <= xp do
		level += 1
	end
	return level
end

-- How far through the current level, from 0 to 1
function Level.Progress(xp)
	local level = Level.FromXp(xp)
	if level >= Level.Max then
		return 1, level
	end
	local from, to = Level.XpFor(level), Level.XpFor(level + 1)
	return (xp - from) / (to - from), level
end

return Level
