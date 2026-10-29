-- Every Adventure course, as a list of obstacle kit pieces (see Server/Kit).
-- A course is built when someone plays it, so adding one is just adding a list.
--
-- Each course has 3 hidden gems: put gem = true on 3 pieces. Stars:
--   1 for finishing, 1 for beating par time, 1 for having found all 3 gems.
-- par is worked out from the course's length unless you set it.

local Worlds = require(script.Parent.Worlds)

local Courses = {}

Courses.List = {
	------------------------------------------------------------------ Candy Clouds
	{
		id = "candy_1",
		world = "candy",
		name = "Sugar Steps",
		pieces = {
			{ "start" },
			{ "run", len = 20 },
			{ "stairs", steps = 5 },
			{ "gaps", count = 3, gap = 4, gem = true },
			{ "run", len = 14 },
			{ "checkpoint" },
			{ "ramp", len = 24, rise = 6 },
			{ "spinner", r = 14, speed = 1.0 },
			{ "run", len = 16, gem = true },
			{ "bounce", rise = 14, gem = true },
			{ "finish" },
		},
	},
	{
		id = "candy_2",
		world = "candy",
		name = "Lollipop Loop",
		pieces = {
			{ "start" },
			{ "run", len = 16 },
			{ "turn", dir = "left" },
			{ "gaps", count = 4, gap = 4, drift = 4 },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.2, gem = true },
			{ "turn", dir = "right" },
			{ "movers", count = 2, axis = "forward", dist = 12, period = 5, gem = true },
			{ "checkpoint" },
			{ "ramp", len = 20, rise = 5 },
			{ "run", len = 16, gem = true },
			{ "finish" },
		},
	},
	{
		id = "candy_3",
		world = "candy",
		name = "Marshmallow Hop",
		pieces = {
			{ "start" },
			{ "gaps", count = 5, gap = 4, climb = 1.5, gem = true },
			{ "checkpoint" },
			{ "bounce", rise = 16 },
			{ "movers", count = 3, axis = "side", dist = 14, period = 5, gem = true },
			{ "checkpoint" },
			{ "spinner", r = 15, speed = 1.1, bars = 2 },
			{ "run", len = 14, gem = true },
			{ "stairs", steps = 4 },
			{ "finish" },
		},
	},
	{
		id = "candy_4",
		world = "candy",
		name = "Gumdrop Gauntlet",
		pieces = {
			{ "start" },
			{ "conveyor", len = 36, speed = -8, gem = true },
			{ "checkpoint" },
			{ "spinner", r = 15, speed = 1.3 },
			{ "gaps", count = 4, gap = 5, drift = 5 },
			{ "checkpoint" },
			{ "discs", count = 1, r = 13, speed = 0.5, gem = true },
			{ "turn", dir = "left" },
			{ "bounce", rise = 16, gem = true },
			{ "finish" },
		},
	},
	{
		id = "candy_5",
		world = "candy",
		name = "Cotton Candy Climb",
		pieces = {
			{ "start" },
			{ "stairs", steps = 6 },
			{ "bounce", rise = 14 },
			{ "gaps", count = 4, gap = 4, climb = 2, gem = true },
			{ "checkpoint" },
			{ "movers", count = 3, axis = "forward", dist = 12, period = 5.5 },
			{ "ramp", len = 22, rise = 6 },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.3, bars = 2, gem = true },
			{ "bounce", rise = 18 },
			{ "run", len = 14, gem = true },
			{ "finish" },
		},
	},
	{
		id = "candy_6",
		world = "candy",
		name = "Candy Castle",
		boss = true,
		pieces = {
			{ "start" },
			{ "run", len = 14 },
			{ "gaps", count = 4, gap = 5, drift = 3 },
			{ "spinner", r = 16, speed = 1.3 },
			{ "checkpoint" },
			{ "movers", count = 3, axis = "side", dist = 14, period = 4.5, gem = true },
			{ "bounce", rise = 16 },
			{ "checkpoint" },
			{ "discs", count = 2, r = 13, speed = 0.6 },
			{ "conveyor", len = 32, speed = -10, gem = true },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.5, bars = 2, reverse = true },
			{ "turn", dir = "right" },
			{ "gaps", count = 5, gap = 5, drift = 4, climb = 1, gem = true },
			{ "bounce", rise = 18 },
			{ "finish" },
		},
	},
}

Courses.ById = {}
Courses.ByWorld = {}
for _, course in ipairs(Courses.List) do
	Courses.ById[course.id] = course
	Courses.ByWorld[course.world] = Courses.ByWorld[course.world] or {}
	table.insert(Courses.ByWorld[course.world], course)
	course.number = #Courses.ByWorld[course.world]
end

-- The course before this one in its world (it must be finished first), or nil
function Courses.Previous(courseId)
	local course = Courses.ById[courseId]
	if not course or course.number == 1 then
		return nil
	end
	return Courses.ByWorld[course.world][course.number - 1]
end

-- The next course in the same world, or the first of the next world
function Courses.Next(courseId, worldOrder)
	local course = Courses.ById[courseId]
	if not course then
		return nil
	end
	local list = Courses.ByWorld[course.world]
	if list[course.number + 1] then
		return list[course.number + 1]
	end
	for index, worldId in ipairs(worldOrder) do
		if worldId == course.world and worldOrder[index + 1] then
			local nextList = Courses.ByWorld[worldOrder[index + 1]]
			return nextList and nextList[1] or nil
		end
	end
	return nil
end

-- Star bits saved per course
Courses.StarFinish = 1
Courses.StarTime = 2
Courses.StarGems = 4

function Courses.CountStars(bits)
	bits = bits or 0
	local count = 0
	for _, bit in ipairs({ 1, 2, 4 }) do
		if bit32.band(bits, bit) ~= 0 then
			count += 1
		end
	end
	return count
end

-- Total stars across every course in a save
function Courses.TotalStars(adventure)
	local total = 0
	for _, record in pairs(adventure or {}) do
		total += Courses.CountStars(record.stars)
	end
	return total
end

-- Worlds open with stars; courses in a world open one after another
function Courses.WorldUnlocked(adventure, worldId)
	local world = Worlds.ById[worldId]
	return world ~= nil and Courses.TotalStars(adventure) >= world.stars
end

function Courses.Unlocked(adventure, courseId)
	local course = Courses.ById[courseId]
	if not course or not Courses.WorldUnlocked(adventure, course.world) then
		return false
	end
	local previous = Courses.Previous(courseId)
	return previous == nil or (adventure[previous.id] ~= nil and adventure[previous.id].done == true)
end

return Courses
