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
	------------------------------------------------------------------ Jungle Ruins
	{
		id = "jungle_1",
		world = "jungle",
		name = "Vine Valley",
		pieces = {
			{ "start" },
			{ "run", len = 16 },
			{ "hammers", count = 2, period = 3.6, gem = true },
			{ "checkpoint" },
			{ "gaps", count = 4, gap = 4, drift = 3 },
			{ "zip", len = 50, drop = 12, gem = true },
			{ "checkpoint" },
			{ "stairs", steps = 5 },
			{ "seesaw", count = 2, period = 4.5, gem = true },
			{ "finish" },
		},
	},
	{
		id = "jungle_2",
		world = "jungle",
		name = "Boulder Run",
		pieces = {
			{ "start" },
			{ "balls", len = 50, rise = 8, lanes = 3, period = 4, gem = true },
			{ "checkpoint" },
			{ "turn", dir = "right" },
			{ "movers", count = 3, axis = "side", dist = 12, period = 5, gem = true },
			{ "checkpoint" },
			{ "hammers", count = 3, period = 3.4 },
			{ "run", len = 12, gem = true },
			{ "finish" },
		},
	},
	{
		id = "jungle_3",
		world = "jungle",
		name = "Temple Steps",
		pieces = {
			{ "start" },
			{ "truss", height = 14 },
			{ "gaps", count = 4, gap = 4, climb = 1.5, gem = true },
			{ "checkpoint" },
			{ "spinner", r = 15, speed = 1.3, high = true },
			{ "seesaw", count = 3, period = 4.2, gem = true },
			{ "checkpoint" },
			{ "zip", len = 56, drop = 14 },
			{ "hammers", count = 3, period = 3.2, gem = true },
			{ "finish" },
		},
	},
	{
		id = "jungle_4",
		world = "jungle",
		name = "Rolling Ruins",
		pieces = {
			{ "start" },
			{ "run", len = 12 },
			{ "balls", len = 60, rise = 10, lanes = 3, period = 3.6 },
			{ "checkpoint" },
			{ "gaps", count = 5, gap = 5, drift = 4, gem = true },
			{ "turn", dir = "left" },
			{ "hammers", count = 4, period = 3.0, gem = true },
			{ "checkpoint" },
			{ "movers", count = 3, axis = "forward", dist = 12, period = 5 },
			{ "zip", len = 50, drop = 12, gem = true },
			{ "finish" },
		},
	},
	{
		id = "jungle_5",
		world = "jungle",
		name = "Canopy Crossing",
		pieces = {
			{ "start" },
			{ "zip", len = 60, drop = 12 },
			{ "seesaw", count = 3, period = 4, gem = true },
			{ "checkpoint" },
			{ "truss", height = 18 },
			{ "gaps", count = 5, gap = 5, drift = 4, gem = true },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.4, bars = 2 },
			{ "zip", len = 56, drop = 14 },
			{ "movers", count = 3, axis = "side", dist = 14, period = 4.6, gem = true },
			{ "finish" },
		},
	},
	{
		id = "jungle_6",
		world = "jungle",
		name = "Lost Temple",
		boss = true,
		pieces = {
			{ "start" },
			{ "hammers", count = 3, period = 3.2 },
			{ "balls", len = 54, rise = 9, lanes = 3, period = 3.4, gem = true },
			{ "checkpoint" },
			{ "truss", height = 16 },
			{ "seesaw", count = 3, period = 3.8 },
			{ "zip", len = 56, drop = 14, gem = true },
			{ "checkpoint" },
			{ "turn", dir = "right" },
			{ "gaps", count = 5, gap = 5, drift = 5, climb = 1 },
			{ "spinner", r = 16, speed = 1.5, bars = 2 },
			{ "checkpoint" },
			{ "hammers", count = 4, period = 2.8, gem = true },
			{ "movers", count = 3, axis = "forward", dist = 12, period = 4.6 },
			{ "stairs", steps = 4 },
			{ "finish" },
		},
	},

	------------------------------------------------------------------ Frost Peak
	{
		id = "frost_1",
		world = "frost",
		name = "Snowy Start",
		pieces = {
			{ "start" },
			{ "run", len = 14 },
			{ "wind", len = 40, push = 12, gem = true },
			{ "checkpoint" },
			{ "fall", rows = 4, cols = 4 },
			{ "slide", len = 60, drop = 18, gem = true },
			{ "checkpoint" },
			{ "gaps", count = 4, gap = 4, gem = true },
			{ "finish" },
		},
	},
	{
		id = "frost_2",
		world = "frost",
		name = "Icicle Bridge",
		pieces = {
			{ "start" },
			{ "blink", rows = 4, cols = 3, period = 4.5, gem = true },
			{ "checkpoint" },
			{ "wind", len = 44, push = 14 },
			{ "turn", dir = "left" },
			{ "fall", rows = 5, cols = 4, gem = true },
			{ "checkpoint" },
			{ "seesaw", count = 2, period = 4.4 },
			{ "slide", len = 64, drop = 20, gem = true },
			{ "finish" },
		},
	},
	{
		id = "frost_3",
		world = "frost",
		name = "Avalanche Alley",
		pieces = {
			{ "start" },
			{ "slide", len = 70, drop = 22, bumpers = 6, gem = true },
			{ "checkpoint" },
			{ "balls", len = 54, rise = 8, lanes = 3, period = 3.8 },
			{ "wind", len = 44, push = 16, side = -1, gem = true },
			{ "checkpoint" },
			{ "fall", rows = 5, cols = 4 },
			{ "gaps", count = 4, gap = 5, drift = 4, gem = true },
			{ "finish" },
		},
	},
	{
		id = "frost_4",
		world = "frost",
		name = "Frozen Falls",
		pieces = {
			{ "start" },
			{ "gaps", count = 4, gap = 4, climb = 1.5 },
			{ "blink", rows = 5, cols = 3, period = 4, gem = true },
			{ "checkpoint" },
			{ "conveyor", len = 40, speed = -10, gem = true },
			{ "turn", dir = "right" },
			{ "wind", len = 48, push = 16 },
			{ "checkpoint" },
			{ "fall", rows = 6, cols = 4, gem = true },
			{ "slide", len = 60, drop = 18 },
			{ "finish" },
		},
	},
	{
		id = "frost_5",
		world = "frost",
		name = "Blizzard Pass",
		pieces = {
			{ "start" },
			{ "wind", len = 48, push = 18, gem = true },
			{ "spinner", r = 16, speed = 1.4 },
			{ "checkpoint" },
			{ "fall", rows = 6, cols = 3 },
			{ "seesaw", count = 3, period = 4, gem = true },
			{ "checkpoint" },
			{ "blink", rows = 5, cols = 3, period = 3.8 },
			{ "slide", len = 70, drop = 24, bumpers = 6 },
			{ "gaps", count = 4, gap = 5, drift = 4, gem = true },
			{ "finish" },
		},
	},
	{
		id = "frost_6",
		world = "frost",
		name = "Ice Palace",
		boss = true,
		pieces = {
			{ "start" },
			{ "slide", len = 64, drop = 20, gem = true },
			{ "wind", len = 44, push = 16 },
			{ "checkpoint" },
			{ "fall", rows = 6, cols = 4 },
			{ "blink", rows = 4, cols = 3, period = 3.6, gem = true },
			{ "checkpoint" },
			{ "turn", dir = "left" },
			{ "balls", len = 56, rise = 9, lanes = 3, period = 3.4 },
			{ "seesaw", count = 3, period = 3.8 },
			{ "checkpoint" },
			{ "wind", len = 48, push = 18, side = -1 },
			{ "gaps", count = 5, gap = 5, drift = 5, climb = 1, gem = true },
			{ "slide", len = 60, drop = 18, bumpers = 6 },
			{ "finish" },
		},
	},

	------------------------------------------------------------------ Lava Factory
	{
		id = "lava_1",
		world = "lava",
		name = "Hot Start",
		pieces = {
			{ "start" },
			{ "conveyor", len = 36, speed = -8, gem = true },
			{ "checkpoint" },
			{ "pushers", count = 3, period = 3.4 },
			{ "lasers", count = 2, period = 3.4, gem = true },
			{ "checkpoint" },
			{ "climb", tiers = 3, step = 5, period = 12, gem = true },
			{ "finish" },
		},
	},
	{
		id = "lava_2",
		world = "lava",
		name = "Piston Plant",
		pieces = {
			{ "start" },
			{ "pushers", count = 4, period = 3, gem = true },
			{ "checkpoint" },
			{ "turn", dir = "right" },
			{ "conveyor", len = 40, speed = -10 },
			{ "hammers", count = 3, period = 3.2, gem = true },
			{ "checkpoint" },
			{ "blink", rows = 4, cols = 3, period = 4 },
			{ "lasers", count = 3, period = 3.2, gem = true },
			{ "finish" },
		},
	},
	{
		id = "lava_3",
		world = "lava",
		name = "Magma Mill",
		pieces = {
			{ "start" },
			{ "climb", tiers = 4, step = 5, period = 11, gem = true },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.5, bars = 2 },
			{ "conveyor", len = 44, speed = 10, gem = true },
			{ "checkpoint" },
			{ "pushers", count = 4, period = 2.8 },
			{ "fall", rows = 5, cols = 4, gem = true },
			{ "finish" },
		},
	},
	{
		id = "lava_4",
		world = "lava",
		name = "Laser Lab",
		pieces = {
			{ "start" },
			{ "lasers", count = 3, period = 3, gem = true },
			{ "movers", count = 3, axis = "side", dist = 14, period = 4.6 },
			{ "checkpoint" },
			{ "turn", dir = "left" },
			{ "lasers", count = 4, period = 2.8 },
			{ "blink", rows = 5, cols = 3, period = 3.8, gem = true },
			{ "checkpoint" },
			{ "conveyor", len = 40, speed = -12 },
			{ "hammers", count = 3, period = 3, gem = true },
			{ "finish" },
		},
	},
	{
		id = "lava_5",
		world = "lava",
		name = "Conveyor Chaos",
		pieces = {
			{ "start" },
			{ "conveyor", len = 44, speed = -12, gem = true },
			{ "pushers", count = 4, period = 2.8 },
			{ "checkpoint" },
			{ "climb", tiers = 4, step = 5, period = 10 },
			{ "gaps", count = 4, gap = 5, drift = 4, gem = true },
			{ "checkpoint" },
			{ "turn", dir = "right" },
			{ "lasers", count = 3, period = 2.8 },
			{ "conveyor", len = 40, speed = 12, gem = true },
			{ "finish" },
		},
	},
	{
		id = "lava_6",
		world = "lava",
		name = "The Furnace",
		boss = true,
		pieces = {
			{ "start" },
			{ "pushers", count = 4, period = 2.8 },
			{ "conveyor", len = 40, speed = -10, gem = true },
			{ "checkpoint" },
			{ "climb", tiers = 4, step = 5, period = 10 },
			{ "lasers", count = 3, period = 2.8 },
			{ "checkpoint" },
			{ "turn", dir = "left" },
			{ "spinner", r = 16, speed = 1.6, bars = 2, gem = true },
			{ "blink", rows = 5, cols = 3, period = 3.6 },
			{ "checkpoint" },
			{ "hammers", count = 4, period = 2.8 },
			{ "fall", rows = 5, cols = 4, gem = true },
			{ "lasers", count = 4, period = 2.6 },
			{ "finish" },
		},
	},

	------------------------------------------------------------------ Star Station (low gravity)
	{
		id = "space_1",
		world = "space",
		name = "Moon Walk",
		pieces = {
			{ "start" },
			{ "gaps", count = 4, gap = 7, gem = true },
			{ "checkpoint" },
			{ "discs", count = 1, r = 13, speed = 0.5 },
			{ "bounce", rise = 18, gem = true },
			{ "checkpoint" },
			{ "doors", rows = 2, doors = 4 },
			{ "run", len = 14, gem = true },
			{ "finish" },
		},
	},
	{
		id = "space_2",
		world = "space",
		name = "Orbit Hop",
		pieces = {
			{ "start" },
			{ "discs", count = 2, r = 13, speed = 0.6, gem = true },
			{ "checkpoint" },
			{ "gaps", count = 5, gap = 8, drift = 5 },
			{ "turn", dir = "right" },
			{ "blink", rows = 4, cols = 3, period = 4, gem = true },
			{ "checkpoint" },
			{ "doors", rows = 3, doors = 5 },
			{ "bounce", rise = 20, gem = true },
			{ "finish" },
		},
	},
	{
		id = "space_3",
		world = "space",
		name = "Asteroid Belt",
		pieces = {
			{ "start" },
			{ "balls", len = 56, rise = 9, lanes = 3, period = 3.6, gem = true },
			{ "checkpoint" },
			{ "movers", count = 3, axis = "side", dist = 16, period = 5 },
			{ "gaps", count = 4, gap = 9, climb = 2, gem = true },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.5, bars = 2 },
			{ "lasers", count = 3, period = 3, gem = true },
			{ "finish" },
		},
	},
	{
		id = "space_4",
		world = "space",
		name = "Zero-G Gauntlet",
		pieces = {
			{ "start" },
			{ "doors", rows = 3, doors = 5, gem = true },
			{ "checkpoint" },
			{ "discs", count = 2, r = 13, speed = 0.7 },
			{ "bounce", rise = 22 },
			{ "checkpoint" },
			{ "turn", dir = "left" },
			{ "blink", rows = 5, cols = 3, period = 3.8, gem = true },
			{ "gaps", count = 5, gap = 9, drift = 5 },
			{ "movers", count = 3, axis = "forward", dist = 14, period = 4.8, gem = true },
			{ "finish" },
		},
	},
	{
		id = "space_5",
		world = "space",
		name = "Comet Chase",
		pieces = {
			{ "start" },
			{ "gaps", count = 5, gap = 9, drift = 4, climb = 1.5, gem = true },
			{ "lasers", count = 3, period = 2.8 },
			{ "checkpoint" },
			{ "discs", count = 2, r = 13, speed = 0.8, gem = true },
			{ "doors", rows = 3, doors = 5 },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.6, bars = 2 },
			{ "bounce", rise = 24 },
			{ "blink", rows = 5, cols = 3, period = 3.4, gem = true },
			{ "finish" },
		},
	},
	{
		id = "space_6",
		world = "space",
		name = "Crown Station",
		boss = true,
		pieces = {
			{ "start" },
			{ "doors", rows = 3, doors = 5 },
			{ "discs", count = 2, r = 13, speed = 0.7, gem = true },
			{ "checkpoint" },
			{ "gaps", count = 5, gap = 9, drift = 5, climb = 1 },
			{ "lasers", count = 4, period = 2.6 },
			{ "checkpoint" },
			{ "turn", dir = "right" },
			{ "balls", len = 56, rise = 9, lanes = 3, period = 3.2, gem = true },
			{ "bounce", rise = 24 },
			{ "checkpoint" },
			{ "blink", rows = 5, cols = 3, period = 3.4 },
			{ "spinner", r = 16, speed = 1.7, bars = 2 },
			{ "movers", count = 3, axis = "side", dist = 16, period = 4.4, gem = true },
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
