-- Every tournament round. A tournament is 4 rounds for 12 runners:
--   round 1 is always a race (12 -> 9), rounds 2 and 3 are picked at random
--   from the other kinds (9 -> 6 -> 3), and the final is always Crown Climb.
--
-- kind:
--   "race"      first ones over the line go through (course pieces, like Courses)
--   "survival"  stay on the arena; the last ones standing go through
--   "fight"     a survival round with foam hammers: bonk rivals off
--   "objective" score points (gems, tails, time on the hill); the top scores go through
--   "team"      teams play for points; the team with the fewest is out (its top scorer is saved)
--   "final"     a race where only the winner counts: first to grab the crown

local Rounds = {}

Rounds.List = {
	------------------------------------------------------------------ Races
	{
		id = "slime_slide",
		kind = "race",
		name = "Slime Slide",
		world = "candy",
		blurb = "Slide down, steer round the holes and jump the sweepers!",
		pieces = {
			{ "start" },
			{ "slide", len = 60, drop = 18, w = 22, bumpers = 3, holes = 2, sweepers = 1 },
			{ "turn", dir = "left", size = 22 },
			{ "spinner", r = 16, speed = 1.2 },
			{ "checkpoint" },
			{ "slide", len = 72, drop = 22, w = 22, bumpers = 2, holes = 3, sweepers = 2 },
			{ "turn", dir = "right", size = 22 },
			{ "bounce", rise = 14 },
			{ "conveyor", len = 32, speed = -8, w = 16 },
			{ "checkpoint" },
			{ "slide", len = 60, drop = 18, w = 20, bumpers = 2, holes = 2, sweepers = 2 },
			{ "finish" },
		},
	},
	{
		id = "spinner_gauntlet",
		kind = "race",
		name = "Spinner Gauntlet",
		world = "jungle",
		blurb = "Spinners, hammers and boulders. Keep your feet!",
		pieces = {
			{ "start" },
			{ "spinner", r = 16, speed = 1.2 },
			{ "hammers", count = 3, period = 3.4, w = 12 },
			{ "checkpoint" },
			{ "balls", len = 50, rise = 8, lanes = 3, period = 3.6 },
			{ "spinner", r = 16, speed = 1.4, bars = 2 },
			{ "checkpoint" },
			{ "pushers", count = 4, period = 3, w = 14 },
			{ "finish" },
		},
	},
	{
		id = "door_dash",
		kind = "race",
		name = "Door Dash",
		world = "space",
		blurb = "Some doors are fake. Pick right and crash through!",
		pieces = {
			{ "start" },
			{ "run", len = 12, w = 24 },
			{ "doors", rows = 3, doors = 6 },
			{ "checkpoint" },
			{ "gaps", count = 4, gap = 7, size = 9, w = 20 },
			{ "doors", rows = 3, doors = 6 },
			{ "finish" },
		},
	},
	{
		id = "sky_hop",
		kind = "race",
		name = "Sky Hop",
		world = "frost",
		blurb = "Hop across floating islands. Don't look down!",
		pieces = {
			{ "start" },
			{ "gaps", count = 5, gap = 5, size = 9, drift = 5, w = 20 },
			{ "blink", rows = 4, cols = 4, period = 4 },
			{ "checkpoint" },
			{ "movers", count = 3, axis = "side", dist = 12, period = 4.6, size = 11 },
			{ "wind", len = 40, w = 10, push = 12 },
			{ "checkpoint" },
			{ "fall", rows = 4, cols = 5 },
			{ "finish" },
		},
	},

	------------------------------------------------------------------ Survival
	{
		id = "tile_fall",
		kind = "survival",
		name = "Tile Fall",
		world = "frost",
		blurb = "Tiles drop after you step on them. Keep moving and don't fall through!",
		arena = "tiles",
		seconds = 90,
	},
	{
		id = "lava_rise",
		kind = "survival",
		name = "Lava Rise",
		world = "lava",
		blurb = "The lava is rising. Climb, climb, climb!",
		arena = "lava",
		seconds = 80,
	},
	{
		id = "sweeper",
		kind = "survival",
		name = "Sweeper",
		world = "jungle",
		blurb = "Jump the sweeping logs. They get faster!",
		arena = "sweeper",
		seconds = 75,
	},

	------------------------------------------------------------------ Fight
	{
		id = "bonk_ring",
		kind = "fight",
		name = "Bonk Ring",
		world = "candy",
		blurb = "Bonk rivals off the ring with your hammer. The edge falls away!",
		arena = "ring",
		seconds = 90,
		hammers = true,
	},
	{
		id = "bumper_bowl",
		kind = "fight",
		name = "Bumper Bowl",
		world = "space",
		blurb = "Bonk rivals off the bowl, and watch out for the bumpers!",
		arena = "bowl",
		seconds = 90,
		hammers = true,
	},

	------------------------------------------------------------------ Objective
	{
		id = "gem_grab",
		kind = "objective",
		name = "Gem Grab",
		world = "jungle",
		blurb = "Grab the most gems! Bonk rivals to make them drop theirs.",
		arena = "gems",
		seconds = 75,
		hammers = true,
	},
	{
		id = "tail_tag",
		kind = "objective",
		name = "Tail Tag",
		world = "frost",
		blurb = "Grab a tail and keep it! Dash to snatch one from further away. Tails at the end go through.",
		arena = "tails",
		seconds = 75,
	},
	{
		id = "king_hill",
		kind = "objective",
		name = "King of the Hill",
		world = "lava",
		blurb = "Stand on the hill to score. Bonk everyone else off it!",
		arena = "hill",
		seconds = 75,
		hammers = true,
	},

	------------------------------------------------------------------ Team
	{
		id = "egg_scramble",
		kind = "team",
		name = "Egg Scramble",
		world = "candy",
		blurb = "Carry eggs to your nest. Bonk or dash into carriers to steal! Fewest eggs is out, but its top scorer is saved.",
		arena = "eggs",
		seconds = 90,
		hammers = true,
	},
	{
		id = "ball_rush",
		kind = "team",
		name = "Ball Rush",
		world = "space",
		blurb = "Run into the ball to kick it, dash for a power kick! Most goals let in is out, but its top scorer is saved.",
		arena = "ball",
		seconds = 90,
	},

	------------------------------------------------------------------ Final
	{
		id = "crown_climb",
		kind = "final",
		name = "Crown Climb",
		world = "candy",
		blurb = "Climb to the top. The first one to grab the crown wins it all!",
		pieces = {
			{ "start" },
			{ "stairs", steps = 6, w = 20 },
			{ "bounce", rise = 18 },
			{ "gaps", count = 4, gap = 5, climb = 2, size = 9, w = 20 },
			{ "checkpoint" },
			{ "spinner", r = 16, speed = 1.4, bars = 2 },
			{ "movers", count = 3, axis = "forward", dist = 12, period = 5, size = 10 },
			{ "checkpoint" },
			{ "truss", height = 16 },
			{ "hammers", count = 3, period = 3.2, w = 12 },
			{ "bounce", rise = 20 },
			{ "finish", crown = true },
		},
	},
}

Rounds.ById = {}
for _, round in ipairs(Rounds.List) do
	Rounds.ById[round.id] = round
end

Rounds.Players = 12 -- runners in a tournament (bots fill empty spots)
Rounds.Count = 4

-- How many go through after a round, for this many still in
function Rounds.Keep(alive, roundNumber)
	if roundNumber >= Rounds.Count then
		return 1
	elseif roundNumber == 1 then
		return math.max(2, math.ceil(alive * 0.75))
	elseif roundNumber == 2 then
		return math.max(2, math.ceil(alive * 2 / 3))
	end
	return math.max(2, math.ceil(alive / 2))
end

-- Picks the 4 rounds of a tournament
function Rounds.Pick(random)
	local races, middle = {}, {}
	for _, round in ipairs(Rounds.List) do
		if round.kind == "race" then
			table.insert(races, round)
		elseif round.kind ~= "final" then
			table.insert(middle, round)
		end
	end
	local plan = { races[random:NextInteger(1, #races)] }
	for _ = 2, Rounds.Count - 1 do
		if #middle == 0 then
			break
		end
		-- Two different kinds in the middle when possible
		local pick = table.remove(middle, random:NextInteger(1, #middle))
		table.insert(plan, pick)
		for index = #middle, 1, -1 do
			if middle[index].kind == pick.kind and #middle > 1 then
				table.remove(middle, index)
			end
		end
	end
	table.insert(plan, Rounds.ById.crown_climb)
	return plan
end

return Rounds
