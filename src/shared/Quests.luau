-- Daily quests: three small goals per player per day. Finishing one pays coins
-- and XP right away.

local Quests = {}

-- stat: what counts toward the goal (services report these with each reward)
-- needs: "stars" / "gems" = only offered while the player still has some to find
Quests.Pool = {
	{ id = "courses", stat = "courses", text = "Finish %d Adventure courses", goal = { 2, 5 }, coins = 100 },
	{ id = "stars", stat = "stars", text = "Earn %d new stars", goal = { 1, 3 }, coins = 120, needs = "stars" },
	{ id = "gems", stat = "gems", text = "Find %d hidden gems", goal = { 1, 3 }, coins = 100, needs = "gems" },
	{ id = "tournaments", stat = "tournaments", text = "Play %d tournaments", goal = { 2, 4 }, coins = 100 },
	{ id = "rounds", stat = "rounds", text = "Survive %d tournament rounds", goal = { 3, 8 }, coins = 100 },
	{ id = "qualified", stat = "qualified", text = "Qualify in %d races", goal = { 2, 4 }, coins = 90 },
	{ id = "crowns", stat = "crowns", text = "Win %d tournament", goal = { 1, 1 }, coins = 150 },
	{ id = "kos", stat = "kos", text = "Knock %d rivals out in fight rounds", goal = { 3, 6 }, coins = 90 },
}

Quests.ById = {}
for _, quest in ipairs(Quests.Pool) do
	Quests.ById[quest.id] = quest
end

Quests.PerDay = 3
Quests.XpShare = 0.5 -- XP reward = coins * this

function Quests.Today(now)
	return math.floor(now / 86400)
end

-- Week number for the weekly leaderboard; weeks start Monday 00:00 UTC
-- (1 Jan 1970 was a Thursday). Also returns the seconds left in the week.
local WEEK = 7 * 86400
local MONDAY_OFFSET = 4 * 86400
function Quests.Week(now)
	return math.floor((now - MONDAY_OFFSET) / WEEK), WEEK - ((now - MONDAY_OFFSET) % WEEK)
end

-- The same three quests for a player all day, picked from the pool.
-- left = { stars = n, gems = n }: how many the player can still find.
function Quests.Generate(userId, day, left)
	left = left or { stars = 99, gems = 99 }
	local random = Random.new(userId % 1000003 * 977 + day)
	local pool = {}
	for _, quest in ipairs(Quests.Pool) do
		if not quest.needs or (left[quest.needs] or 0) >= quest.goal[2] then
			table.insert(pool, quest)
		end
	end
	local list = {}
	while #list < Quests.PerDay and #pool > 0 do
		local quest = table.remove(pool, random:NextInteger(1, #pool))
		table.insert(list, {
			id = quest.id,
			goal = random:NextInteger(quest.goal[1], quest.goal[2]),
			progress = 0,
			done = false,
		})
	end
	return list
end

function Quests.Text(entry)
	local quest = Quests.ById[entry.id]
	local text = string.format(quest.text, entry.goal)
	if entry.goal ~= 1 then
		return (text:gsub("Win (%d+) tournament$", "Win %1 tournaments"))
	end
	-- "Finish 1 Adventure courses" -> "Finish 1 Adventure course"
	return (
		text:gsub("courses", "course")
			:gsub("stars", "star")
			:gsub("gems", "gem")
			:gsub("tournaments", "tournament")
			:gsub("rounds", "round")
			:gsub("races", "race")
			:gsub("rivals", "rival")
	)
end

return Quests
