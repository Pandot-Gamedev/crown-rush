-- Survival rounds: stay on the arena. Anyone who falls (or touches the lava)
-- is out and watches from the stands above. The round ends when only enough
-- runners are left to fill the spots, or when time runs out (then everyone
-- still standing goes through).
--
-- Arenas:
--   tiles    three floors of tiles that drop a moment after you step on them
--   lava     a spiral of platforms around a tower while the lava rises
--   sweeper  a round platform with spinning logs to jump, getting faster
--
-- Fight rounds are survival rounds with foam hammers: bonk rivals off.
--   ring     a round ring whose outer edge falls away in two waves
--   bowl     a round floor with big bumper balls rolling round it

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Motion = require(Shared.Motion)
local Worlds = require(Shared.Worlds)

local BotService = require(script.Parent.BotService)
local ArenaKit = require(script.Parent.ArenaKit)
local CombatService = require(script.Parent.CombatService)

local SurvivalRound = {}
SurvivalRound.__index = SurvivalRound

local ROOT_HEIGHT = ArenaKit.ROOT_HEIGHT
local UPRIGHT = ArenaKit.UPRIGHT
local flat, part, rootOf, ring = ArenaKit.flat, ArenaKit.part, ArenaKit.rootOf, ArenaKit.ring
local random = Random.new()

------------------------------------------------------------------ Tile Fall
local Arenas = {}

Arenas.tiles = function(arena, world)
	local size, gap, count = 7, 0.6, 8
	local layers = 3
	local spacing = 22
	local width = count * (size + gap)
	local tiles = {}
	for layer = 1, layers do
		local y = -(layer - 1) * spacing
		local color = world.floor[(layer % #world.floor) + 1]
		for row = 1, count do
			for column = 1, count do
				local x = -width / 2 + (column - 0.5) * (size + gap)
				local z = -width / 2 + (row - 0.5) * (size + gap)
				local tile = part({
					Name = "Tile",
					Size = Vector3.new(size, 1.5, size),
					CFrame = arena.origin * CFrame.new(x, y - 0.75, z),
					Color = (row + column) % 2 == 0 and color or color:Lerp(Color3.new(1, 1, 1), 0.3),
					Material = world.material,
					Parent = arena.folder,
				})
				table.insert(
					tiles,
					{ part = tile, home = tile.CFrame, state = "up", color = tile.Color, layer = layer }
				)
			end
		end
	end
	arena.tiles = tiles
	arena.killY = arena.origin.Y - (layers - 1) * spacing - 25
	arena.spawns = ring(arena.origin.Position + Vector3.new(0, ROOT_HEIGHT, 0), width / 2 - 8, 12)

	local function drop(tile)
		tile.state = "shaking"
		tile.part.Color = tile.color:Lerp(Color3.new(1, 1, 1), 0.6)
		task.delay(0.55, function()
			tile.state = "down"
			tile.part.CanCollide = false
			tile.part.CanQuery = false
			tile.part.Transparency = 1
		end)
	end

	function arena.update(positions)
		for _, tile in ipairs(tiles) do
			if tile.state == "up" then
				for _, position in ipairs(positions) do
					local offset = tile.home:PointToObjectSpace(position)
					if
						math.abs(offset.X) < size / 2 + 0.4
						and math.abs(offset.Z) < size / 2 + 0.4
						and offset.Y > 0
						and offset.Y < 5
					then
						drop(tile)
						break
					end
				end
			end
		end
	end

	-- Bots hop to a nearby tile that's still up, preferring ones with lots of
	-- neighbours still up (the safest), and never stand still for long
	function arena.brain(bot)
		while true do
			local position = bot.root.Position
			if not BotService.FloorAt(position, 1, 1.5) then
				bot.vy = 0
				BotService.Fall(bot)
				position = bot.root.Position
			end
			local best, bestScore = nil, -math.huge
			for _, tile in ipairs(tiles) do
				if tile.state == "up" then
					local distance = flat(tile.home.Position - position).Magnitude
					local sameLayer = math.abs(tile.home.Position.Y + 0.75 - (position.Y - ROOT_HEIGHT)) < 2
					if sameLayer and distance > 3 and distance < 17 then
						local score = random:NextNumber(0, 6) - distance * 0.15
						for _, other in ipairs(tiles) do
							if
								other.state == "up"
								and other.layer == tile.layer
								and (other.home.Position - tile.home.Position).Magnitude < 9
							then
								score += 1
							end
						end
						if score > bestScore then
							best, bestScore = tile, score
						end
					end
				end
			end
			if best then
				local target = best.home.Position + Vector3.new(0, 0.75, 0)
				if flat(target - position).Magnitude > 9 then
					BotService.JumpTo(bot, target, 2)
				else
					BotService.RunTo(bot, target + Vector3.new(0, ROOT_HEIGHT, 0), bot.speed, 1)
				end
				-- Slower bots sometimes dither, which is how they fall through
				if random:NextNumber() > 0.6 + bot.skill * 0.4 then
					BotService.Wait(bot, 0.7)
				end
			else
				BotService.Wait(bot, 0.2)
			end
		end
	end
end

------------------------------------------------------------------ Lava Rise
Arenas.lava = function(arena, world, seconds)
	local origin = arena.origin
	-- Ground floor, then a spiral of platforms around a tower
	part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 64, 64),
		CFrame = origin * CFrame.new(0, -1, 0) * UPRIGHT,
		Color = world.floor[1],
		Material = world.material,
		Parent = arena.folder,
	})
	part({
		Name = "Tower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(90, 14, 14),
		CFrame = origin * CFrame.new(0, 45, 0) * UPRIGHT,
		Color = world.edge,
		Material = Enum.Material.Metal,
		Parent = arena.folder,
	})
	local steps = {}
	local turns = 2.6
	local count = 26
	for index = 1, count do
		local share = index / count
		local angle = share * turns * math.pi * 2
		local radius = 17 + (index % 3) * 3
		local y = 3 + share * 72
		local at = origin * CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
		local platform = part({
			Name = "Step",
			Size = Vector3.new(7, 1.5, 7),
			CFrame = at * CFrame.new(0, -0.75, 0),
			Color = world.floor[(index % #world.floor) + 1],
			Material = world.material,
			Parent = arena.folder,
		})
		table.insert(steps, platform.Position + Vector3.new(0, 0.75, 0))
	end
	-- The top: a wide ring to stand on at the end
	part({
		Name = "Top",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 30, 30),
		CFrame = origin * CFrame.new(0, 90, 0) * UPRIGHT,
		Color = world.accent,
		Material = world.material,
		Parent = arena.folder,
	})
	-- The lava climbs from the floor to just under the top over the round
	local lavaHeight = 4
	local climb = 84
	local period = seconds * 2
	local startAt = math.huge -- set at GO
	local home = origin * CFrame.new(0, -lavaHeight / 2 - 1, 0)
	local lava = part({
		Name = "Lava",
		Size = Vector3.new(200, lavaHeight, 200),
		CFrame = home,
		Color = world.hazard,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
		Parent = arena.folder,
		Tags = { "Kill", Motion.Tag },
		Attributes = {
			Motion = "slide",
			Home = home,
			Axis = Vector3.yAxis,
			Dist = climb,
			Period = period,
			Hold = 0,
			Phase = 0,
		},
	})
	local spec = Motion.Read(lava)
	-- At GO: line the lava's cycle up so it starts climbing right now
	function arena.start()
		startAt = Motion.Clock()
		lava:SetAttribute("Phase", -startAt % period)
		spec = Motion.Read(lava)
	end
	arena.killY = origin.Y - 30
	arena.spawns = ring(origin.Position + Vector3.new(0, ROOT_HEIGHT, 0), 24, 12)

	local function lavaTop()
		local t = Motion.Clock()
		if t < startAt then
			return home.Position.Y + lavaHeight / 2
		end
		if t > startAt + period / 2 then
			return home.Position.Y + climb + lavaHeight / 2
		end
		return Motion.At(spec, t).Position.Y + lavaHeight / 2
	end
	arena.lavaTop = lavaTop
	function arena.isOut(position)
		return position.Y - ROOT_HEIGHT < lavaTop() - 0.5
	end
	arena.outText = "The lava got you!"
	function arena.update() end

	-- Bots climb the spiral step by step, a little ahead of the lava
	function arena.brain(bot)
		local nearest, bestDistance = 1, math.huge
		for index, step in ipairs(steps) do
			local distance = (step - bot.root.Position).Magnitude
			if distance < bestDistance then
				nearest, bestDistance = index, distance
			end
		end
		if bestDistance > 12 then
			-- Still on the ground: run under the first step, then hop up
			local outward = flat(steps[1] - origin.Position).Unit
			local below = Vector3.new(steps[1].X, origin.Y, steps[1].Z) + outward * 6
			BotService.RunTo(bot, below + Vector3.new(0, ROOT_HEIGHT, 0), bot.speed, 1.5)
			nearest = 0
		end
		for index = nearest + 1, #steps do
			-- Wait a little while the lava is far below (careful bots rest more)
			while steps[index].Y - lavaTop() > 10 + bot.skill * 8 do
				BotService.Wait(bot, 0.3)
			end
			local target = steps[index]
			if random:NextNumber() < (1 - bot.skill) * 0.08 then
				-- A slip: the jump comes up short
				target = bot.root.Position:Lerp(target, 0.55) - Vector3.new(0, 6, 0)
			end
			BotService.JumpTo(bot, target, 3)
		end
		BotService.JumpTo(bot, origin.Position + Vector3.new(0, 90 + 1, 6), 4)
		BotService.Wait(bot, 999)
	end
end

------------------------------------------------------------------ Sweeper
Arenas.sweeper = function(arena, world, seconds)
	local origin = arena.origin
	local radius = 32
	part({
		Name = "Platform",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, radius * 2, radius * 2),
		CFrame = origin * CFrame.new(0, -1.5, 0) * UPRIGHT,
		Color = world.floor[1],
		Material = world.material,
		Parent = arena.folder,
	})
	part({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 7, 7),
		CFrame = origin * CFrame.new(0, 2, 0) * UPRIGHT,
		Color = world.edge,
		Material = Enum.Material.Metal,
		Parent = arena.folder,
	})
	-- Two logs, end to end, sweeping round at ankle height. They speed up.
	local speeds = { 0.9, 1.15, 1.4, 1.7, 2.0 }
	local arms = {}
	for index = 0, 1 do
		local home = origin * CFrame.new(0, 1, 0)
		local offset = CFrame.Angles(0, index * math.pi, 0)
			* CFrame.new(radius / 2 + 1.5, 0, 0)
			* CFrame.Angles(0, 0, 0)
		local log = part({
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(radius - 3, 2, 2),
			CFrame = home * offset,
			Color = world.hazard,
			Material = Enum.Material.Wood,
			CanCollide = false,
			Parent = arena.folder,
			Tags = { "Hit", Motion.Tag },
			Attributes = { Motion = "spin", Home = home, Offset = offset, Speed = speeds[1], Phase = 0, Low = true },
		})
		table.insert(arms, { part = log, angle = index * math.pi })
	end
	arena.killY = origin.Y - 20
	arena.spawns = ring(origin.Position + Vector3.new(0, ROOT_HEIGHT, 0), radius * 0.6, 12)

	local level = 1
	local startedAt = math.huge
	function arena.start()
		startedAt = Motion.Clock()
	end
	-- Changing speed keeps the logs where they are (phase makes up the difference)
	local function setSpeed(newSpeed)
		local t = Motion.Clock()
		for _, arm in ipairs(arms) do
			local old = arm.part:GetAttribute("Speed")
			local phase = arm.part:GetAttribute("Phase")
			arm.part:SetAttribute("Phase", (old - newSpeed) * t + phase)
			arm.part:SetAttribute("Speed", newSpeed)
		end
	end
	function arena.update()
		local wanted = math.clamp(math.floor((Motion.Clock() - startedAt) / (seconds / #speeds)) + 1, 1, #speeds)
		if wanted ~= level then
			level = wanted
			setSpeed(speeds[level])
		end
	end

	-- Angle of a point round the middle, the way the logs turn
	local function angleOf(position)
		local offset = origin:PointToObjectSpace(position)
		return math.atan2(-offset.Z, offset.X)
	end

	-- Bots jump just before a log reaches them (careful bots time it better)
	function arena.brain(bot)
		local wander = os.clock() + random:NextNumber(1, 3)
		while true do
			local t = Motion.Clock()
			local position = bot.root.Position
			local mine = angleOf(position)
			local speed = arms[1].part:GetAttribute("Speed")
			local phase = arms[1].part:GetAttribute("Phase")
			local soonest = math.huge
			for _, arm in ipairs(arms) do
				local armAngle = speed * t + phase + arm.angle
				local ahead = (mine - armAngle) % (math.pi * 2)
				soonest = math.min(soonest, ahead / speed)
			end
			local timing = 0.16 + random:NextNumber(-0.12, 0.12) * (1.2 - bot.skill)
			if soonest < timing then
				BotService.JumpTo(bot, position - Vector3.new(0, ROOT_HEIGHT, 0), 3.5)
			elseif os.clock() > wander and soonest > 0.9 then
				-- Shuffle somewhere else on the platform, away from the edge
				local angle = random:NextNumber(0, math.pi * 2)
				local distance = random:NextNumber(6, radius - 9)
				local target = origin.Position
					+ Vector3.new(math.cos(angle) * distance, ROOT_HEIGHT, math.sin(angle) * distance)
				local step = flat(target - position)
				target = position + (step.Magnitude > 6 and step.Unit * 6 or step)
				BotService.RunTo(bot, target, bot.speed * 0.6, 1)
				wander = os.clock() + random:NextNumber(1, 3)
			else
				BotService.Wait(bot, 0.03)
			end
		end
	end
end

------------------------------------------------------------------ Fights
-- Bots in a fight keep away from the edge, walk up to the nearest rival and
-- bonk. Sharp bots react faster.
local function fightBrain(arena)
	return function(bot)
		local round = arena.round
		local entrant = round.byBot[bot]
		local center = arena.origin.Position
		while true do
			local position = bot.root.Position
			local edge = arena.safeRadius()
			local fromCenter = flat(position - center)
			local rival, distance = ArenaKit.nearest(position, round.alive, entrant)
			local rivalRoot = rival and rootOf(rival)
			if fromCenter.Magnitude > edge - 5 then
				-- Too close to the edge: back towards the middle
				local goal = center + (fromCenter.Magnitude > 0.1 and fromCenter.Unit or Vector3.xAxis) * (edge - 12)
				BotService.RunTo(bot, Vector3.new(goal.X, position.Y, goal.Z), bot.speed, 2)
			elseif not rivalRoot then
				BotService.Wait(bot, 0.3)
			elseif distance <= Config.BonkRange * 0.8 then
				BotService.Face(bot, rivalRoot.Position)
				if entrant.fighter then
					CombatService.TryBonk(entrant.fighter)
				end
				BotService.Wait(bot, 0.25 + (1 - bot.skill) * 0.5)
			else
				local step = flat(rivalRoot.Position - position)
				local goal = position + step.Unit * math.min(6, step.Magnitude - 3)
				local fromGoal = flat(goal - center)
				if fromGoal.Magnitude > edge - 4 then
					goal = center + fromGoal.Unit * (edge - 6)
				end
				BotService.RunTo(bot, Vector3.new(goal.X, position.Y, goal.Z), bot.speed, 1)
			end
		end
	end
end

-- A ring: a solid middle, and an outer edge in 12 pieces that falls away in
-- two waves (flashing first)
Arenas.ring = function(arena, world, seconds)
	local origin = arena.origin
	local inner, outer = 16, 34
	ArenaKit.disc(arena, inner, 0, world.accent, world.material)
	local pieces = {}
	for index = 1, 12 do
		local angle = (index - 0.5) / 12 * math.pi * 2
		local middle = (inner + outer) / 2
		local piece = part({
			Name = "Edge",
			Size = Vector3.new(2 * math.pi * middle / 12 + 1, 3, outer - inner + 1),
			CFrame = origin * CFrame.Angles(0, -angle, 0) * CFrame.new(0, -1.5, -middle),
			Color = world.floor[(index % #world.floor) + 1],
			Material = world.material,
			Parent = arena.folder,
		})
		table.insert(pieces, { part = piece, color = piece.Color, wave = index % 2 == 0 and 1 or 2, state = "up" })
	end
	arena.killY = origin.Y - 25
	arena.spawns = ArenaKit.ring(origin.Position + Vector3.new(0, ROOT_HEIGHT, 0), 24, 12)

	local startedAt = math.huge
	local waves = { seconds * 0.4, seconds * 0.65 }
	local dropped = 0
	function arena.start()
		startedAt = Motion.Clock()
	end
	function arena.safeRadius()
		return dropped >= 1 and inner or outer
	end
	function arena.update()
		local elapsed = Motion.Clock() - startedAt
		for _, piece in ipairs(pieces) do
			local dropAt = waves[piece.wave]
			if piece.state ~= "down" and elapsed >= dropAt then
				piece.state = "down"
				piece.part.CanCollide = false
				piece.part.CanQuery = false
				piece.part.Transparency = 1
				dropped = math.max(dropped, piece.wave)
			elseif piece.state == "up" and elapsed >= dropAt - 3 then
				piece.state = "warn"
			end
			if piece.state == "warn" then
				-- Flash between its colour and the hazard colour
				local on = math.floor(elapsed * 4) % 2 == 0
				piece.part.Color = on and world.hazard or piece.color
			end
		end
	end
	arena.brain = fightBrain(arena)
end

-- A bowl: a round floor with three big bumper balls rolling round it
Arenas.bowl = function(arena, world)
	local origin = arena.origin
	local radius = 30
	ArenaKit.disc(arena, radius, 0, world.floor[1], world.material)
	ArenaKit.disc(arena, 7, 0.4, world.accent, world.material, 0.8)
	for index = 0, 2 do
		local home = origin * CFrame.new(0, 3.5, 0)
		local offset = CFrame.Angles(0, index * math.pi * 2 / 3, 0) * CFrame.new(15, 0, 0)
		part({
			Name = "Bumper",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 7, 7),
			CFrame = home * offset,
			Color = world.hazard,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = arena.folder,
			Tags = { "Hit", Motion.Tag },
			Attributes = { Motion = "spin", Home = home, Offset = offset, Speed = 0.7, Phase = 0 },
		})
	end
	arena.killY = origin.Y - 25
	arena.spawns = ArenaKit.ring(origin.Position + Vector3.new(0, ROOT_HEIGHT, 0), 23, 12)
	function arena.safeRadius()
		return radius
	end
	function arena.update() end
	arena.brain = fightBrain(arena)
end

------------------------------------------------------------------ The round
-- origin = where this tournament's arenas are built (a CFrame)
function SurvivalRound.new(t, round, entrants, keep, _number, origin)
	local world = Worlds.ById[round.world] or Worlds.List[1]
	local folder = Instance.new("Model")
	folder.Name = "Arena_" .. round.id
	local arena = { folder = folder, origin = origin }
	Arenas[round.arena](arena, world, round.seconds)
	folder.Parent = Workspace

	ArenaKit.stands(arena)

	local self = setmetatable({
		t = t,
		round = round,
		entrants = entrants,
		keep = keep,
		arena = arena,
		alive = {},
		out = {},
		byBot = {},
		reasons = {},
	}, SurvivalRound)
	arena.round = self
	for index, entrant in ipairs(entrants) do
		if entrant.bot then
			self.byBot[entrant.bot] = entrant
		end
		local spot = arena.spawns[(index - 1) % #arena.spawns + 1]
		t:Place(entrant, spot)
		table.insert(self.alive, entrant)
		t:SetInRound(entrant, true)
	end
	return self
end

function SurvivalRound:knockOut(entrant)
	local index = table.find(self.alive, entrant)
	if not index then
		return
	end
	table.remove(self.alive, index)
	table.insert(self.out, entrant)
	self.t:SetInRound(entrant, false)
	local reason = self.arena.outText or "You fell off!"
	if entrant.fighter then
		local by = CombatService.LastHitBy(entrant.fighter, 6)
		self.t:KnockedOut(by and by.entrant, entrant)
		CombatService.Leave(entrant)
		if by and by.entrant ~= entrant then
			reason = by.entrant.name .. " bonked you off!"
		end
	end
	reason ..= string.format("  %d still standing", #self.alive)
	if entrant.bot then
		BotService.Stop(entrant.bot)
		BotService.Place(entrant.bot, ArenaKit.standsSpot(self.arena, random))
	else
		self.t:Place(entrant, ArenaKit.standsSpot(self.arena, random))
	end
	self.t:OutOfRound(entrant, #self.alive + 1, reason)
end

function SurvivalRound:Play()
	local t = self.t
	local arena = self.arena
	t:Freeze(self.entrants, true)
	t:Announce("countdown", { goAt = Workspace:GetServerTimeNow() + t.timing.countdown })
	task.wait(t.timing.countdown)
	t:Freeze(self.entrants, false)
	if arena.start then
		arena.start()
	end
	if self.round.hammers then
		for _, entrant in ipairs(self.alive) do
			CombatService.Join(entrant, self)
		end
	end
	local endsAt = Workspace:GetServerTimeNow() + self.round.seconds
	local goal = self.round.hammers and "Bonk them off! %d go through" or "Survive! %d go through"
	t:Announce("timer", { endsAt = endsAt, text = string.format(goal, self.keep) })
	for _, entrant in ipairs(self.entrants) do
		if entrant.bot then
			local bot = entrant.bot
			bot.onFrame = nil
			BotService.Start(bot, function()
				bot.onFrame = BotService.HazardCheck(arena, function()
					self:knockOut(entrant)
				end)
				while true do
					local ok, err = pcall(arena.brain, bot)
					if not ok and err ~= "bot interrupted" then
						error(err, 0)
					end
					-- Knocked and landed: get going again
					BotService.Recover(bot, 0.2)
				end
			end)
		end
	end

	while #self.alive > self.keep and Workspace:GetServerTimeNow() < endsAt do
		task.wait(0.1)
		local positions = {}
		for _, entrant in ipairs(table.clone(self.alive)) do
			local root = rootOf(entrant)
			if entrant.left or not root then
				self:knockOut(entrant)
			else
				local position = root.Position
				if position.Y < arena.killY or (arena.isOut and arena.isOut(position)) then
					self:knockOut(entrant)
				else
					table.insert(positions, position)
				end
			end
		end
		arena.update(positions)
		local playersIn = false
		for _, entrant in ipairs(self.alive) do
			if entrant.player then
				playersIn = true
			end
		end
		if not playersIn then
			break -- only bots left standing: no need to watch them
		end
		t:Status(string.format("%d left  -  %d go through", #self.alive, self.keep))
	end

	-- Everyone still standing goes through (they could be more than keep if
	-- time ran out). The last ones out are ranked best.
	local qualified = {}
	for _, entrant in ipairs(self.alive) do
		table.insert(qualified, entrant)
	end
	-- Only bots left standing (every player is out): trim them to the spots
	local anyPlayer = false
	for _, entrant in ipairs(qualified) do
		anyPlayer = anyPlayer or entrant.player ~= nil
	end
	while not anyPlayer and #qualified > self.keep do
		table.insert(self.out, table.remove(qualified))
	end
	for place, entrant in ipairs(qualified) do
		self.t:Qualified(entrant, place, nil)
	end
	local eliminated = {}
	for index = #self.out, 1, -1 do
		table.insert(eliminated, self.out[index])
	end
	return qualified, eliminated
end

-- The fighters a hammer can hit: everyone still in
function SurvivalRound:Targets()
	local list = {}
	for _, entrant in ipairs(self.alive) do
		if entrant.fighter then
			table.insert(list, entrant.fighter)
		end
	end
	return list
end

function SurvivalRound:Cleanup()
	for _, entrant in ipairs(self.entrants) do
		CombatService.Leave(entrant)
		if entrant.bot then
			BotService.Stop(entrant.bot)
		end
		self.t:SetInRound(entrant, false)
	end
	self.arena.folder:Destroy()
end

return SurvivalRound
