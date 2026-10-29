-- Objective and team rounds: nobody is out during the round. Fall off and you
-- are back on the arena a moment later (losing what you carried). When the
-- time runs out:
--   objective  the top scores go through (gems, tails, time on the hill)
--   team       the runners are split into teams; the team with the fewest
--              points is out (with 9 runners: 3 teams of 3, with 6: 2 of 3)
--
-- Arenas:
--   gems   Gem Grab: grab gems; bonked runners drop some of theirs
--   tails  Tail Tag: grab a tail from whoever has one; tails at the end go through
--   hill   King of the Hill: score while standing on the hill, bonk others off
--   eggs   Egg Scramble (team): carry eggs to your nest, steal from the others
--   ball   Ball Rush (team): push the giant ball into the other teams' goals

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Worlds = require(Shared.Worlds)
local Remotes = require(Shared.Remotes)

local BotService = require(script.Parent.BotService)
local CombatService = require(script.Parent.CombatService)
local ArenaKit = require(script.Parent.ArenaKit)

local GameRound = {}
GameRound.__index = GameRound

local ROOT_HEIGHT = ArenaKit.ROOT_HEIGHT
local flat, part, rootOf = ArenaKit.flat, ArenaKit.part, ArenaKit.rootOf
local random = Random.new()
local RESPAWN_SECONDS = 1.5

local TEAMS = {
	{ name = "Red", color = Color3.fromRGB(235, 70, 70) },
	{ name = "Blue", color = Color3.fromRGB(60, 140, 255) },
	{ name = "Yellow", color = Color3.fromRGB(255, 205, 40) },
	{ name = "Green", color = Color3.fromRGB(70, 200, 100) },
}

local function modelOf(entrant)
	return entrant.bot and entrant.bot.model or (entrant.player and entrant.player.Character)
end

local function near(entrant, position, distance, height)
	local root = rootOf(entrant)
	if not root then
		return false
	end
	local offset = root.Position - position
	return flat(offset).Magnitude <= distance and math.abs(offset.Y) <= (height or 6)
end

-- Runs a bot toward a point, a few studs at a time, so the brain can rethink
local function stepTo(bot, target, maxStep, close)
	local position = bot.root.Position
	local offset = flat(target - position)
	if offset.Magnitude <= math.max(close or 1, 1) then
		BotService.Wait(bot, 0.1)
		return
	end
	local goal = position + offset.Unit * math.min(maxStep or 6, offset.Magnitude)
	BotService.RunTo(bot, Vector3.new(goal.X, position.Y, goal.Z), bot.speed, 0.5)
end

-- Bonks the nearest rival if one is in reach (rivals = a list of entrants)
local function bonkNear(bot, entrant, rivals, chance)
	if not entrant.fighter then
		return false
	end
	local rival, distance = ArenaKit.nearest(bot.root.Position, rivals, entrant)
	local rivalRoot = rival and rootOf(rival)
	if rivalRoot and distance <= Config.BonkRange * 0.8 and random:NextNumber() < (chance or 1) then
		BotService.Face(bot, rivalRoot.Position)
		CombatService.TryBonk(entrant.fighter)
		BotService.Wait(bot, 0.2 + (1 - bot.skill) * 0.4)
		return true
	end
	return false
end

-- A low wall all round a round floor (gaps where skip(angle) says so)
local function rim(arena, radius, height, color, skip)
	local center = arena.origin.Position
	local count = 32
	for index = 1, count do
		local angle = (index - 0.5) / count * math.pi * 2
		if not (skip and skip(angle)) then
			local at = center + Vector3.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
			part({
				Name = "Rim",
				Size = Vector3.new(2 * math.pi * radius / count + 0.6, height, 1.5),
				CFrame = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.3,
				Parent = arena.folder,
			})
		end
	end
end

------------------------------------------------------------------ Gem Grab
local Arenas = {}

Arenas.gems = function(arena, world)
	local round = arena.round
	local center = arena.origin.Position
	local radius = 34
	ArenaKit.disc(arena, radius, 0, world.floor[1], world.material)
	arena.killY = center.Y - 25
	arena.spawns = ArenaKit.ring(center + Vector3.new(0, ROOT_HEIGHT, 0), 22, 12)
	arena.label = "gems"

	local gems = {}
	local function placeGem(gem, at)
		gem.at = at
		gem.part.CFrame = CFrame.new(at + Vector3.new(0, 2, 0))
		gem.part.Transparency = 0
		gem.live = true
	end
	local function newGem(at, temporary)
		local gem = {
			part = part({
				Name = "Gem",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.2, 2.2, 2.2),
				Color = Color3.fromRGB(80, 230, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = arena.folder,
			}),
			temporary = temporary,
		}
		placeGem(gem, at)
		table.insert(gems, gem)
		return gem
	end
	for _ = 1, 14 do
		newGem(ArenaKit.randomOnDisc(random, center, radius, 5))
	end

	-- Drops some of a runner's gems around where they are
	local function drop(entrant, count, position)
		count = math.min(count, round.scores[entrant] or 0)
		round:AddScore(entrant, -count)
		for _ = 1, count do
			local at = position + Vector3.new(random:NextNumber(-7, 7), 0, random:NextNumber(-7, 7))
			if flat(at - center).Magnitude > radius - 3 then
				at = ArenaKit.randomOnDisc(random, center, radius, 5)
			end
			newGem(Vector3.new(at.X, center.Y, at.Z), true)
		end
	end
	round:OnHit(function(_, target)
		local root = rootOf(target.entrant)
		if root then
			drop(target.entrant, 2, root.Position)
		end
	end)
	function arena.onFall(entrant)
		drop(entrant, 2, ArenaKit.randomOnDisc(random, center, radius, 5))
	end

	function arena.update(standing)
		for _, gem in ipairs(gems) do
			if gem.live then
				for _, entrant in ipairs(standing) do
					if near(entrant, gem.at, 3.5, 6) then
						gem.live = false
						gem.part.Transparency = 1
						round:AddScore(entrant, 1)
						Remotes.Effect:FireAllClients("gem", gem.at + Vector3.new(0, 2, 0), { quiet = true })
						if gem.temporary then
							gem.part:Destroy()
							gem.dead = true
						else
							task.delay(1.5, function()
								if arena.folder.Parent then
									placeGem(gem, ArenaKit.randomOnDisc(random, center, radius, 5))
								end
							end)
						end
						break
					end
				end
			end
		end
		for index = #gems, 1, -1 do
			if gems[index].dead then
				table.remove(gems, index)
			end
		end
	end

	function arena.brain(bot, entrant)
		while true do
			if not bonkNear(bot, entrant, round:Standing(), 0.5) then
				local best, bestDistance = nil, math.huge
				local position = bot.root.Position
				for _, gem in ipairs(gems) do
					if gem.live then
						local distance = flat(gem.at - position).Magnitude + random:NextNumber(0, 6)
						if distance < bestDistance then
							best, bestDistance = gem, distance
						end
					end
				end
				if best then
					stepTo(bot, best.at + Vector3.new(0, ROOT_HEIGHT, 0), 8, 1)
				else
					BotService.Wait(bot, 0.2)
				end
			end
		end
	end
end

------------------------------------------------------------------ Tail Tag
Arenas.tails = function(arena, world)
	local round = arena.round
	local center = arena.origin.Position
	local radius = 32
	ArenaKit.disc(arena, radius, 0, world.floor[1], world.material)
	rim(arena, radius, 6, world.edge)
	-- A few bumps to run round
	for index = 1, 4 do
		local angle = index * math.pi / 2 + math.pi / 4
		part({
			Name = "Bump",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 9, 9),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 15, 1, math.sin(angle) * 15)) * ArenaKit.UPRIGHT,
			Color = world.accent,
			Material = world.material,
			Parent = arena.folder,
		})
	end
	arena.killY = center.Y - 25
	arena.spawns = ArenaKit.ring(center + Vector3.new(0, ROOT_HEIGHT, 0), 22, 12)
	arena.label = "tail"

	local tails = {} -- [entrant] = the tail part
	local held = {} -- [entrant] = seconds holding a tail
	local immune = {} -- [entrant] = os.clock() until which their tail can't be taken
	local function giveTail(entrant)
		local root = rootOf(entrant)
		if not root then
			return
		end
		local tail = part({
			Name = "Tail",
			Size = Vector3.new(0.8, 0.8, 3.2),
			Color = Color3.fromRGB(255, 150, 40),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Massless = true,
			Anchored = false,
			CFrame = root.CFrame * CFrame.new(0, -0.6, 2.4) * CFrame.Angles(math.rad(-25), 0, 0),
			Parent = modelOf(entrant),
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = tail
		weld.Parent = tail
		tails[entrant] = tail
		round:SetScore(entrant, 1)
		round:You(entrant, "You have a tail! Keep it to go through")
	end
	local function takeTail(entrant)
		if tails[entrant] then
			tails[entrant]:Destroy()
			tails[entrant] = nil
		end
		round:SetScore(entrant, 0)
		round:You(entrant, "Grab a tail from someone who has one!")
	end
	arena.hasTail = function(entrant)
		return tails[entrant] ~= nil
	end

	-- As many tails as there are spots
	function arena.start()
		local list = table.clone(round.entrants)
		for index = #list, 2, -1 do
			local other = random:NextInteger(1, index)
			list[index], list[other] = list[other], list[index]
		end
		for index, entrant in ipairs(list) do
			if index <= round.keep then
				giveTail(entrant)
			else
				takeTail(entrant)
			end
		end
	end
	function arena.tiebreak(entrant)
		return held[entrant] or 0
	end
	-- A runner who falls keeps their tail (it's welded on), but a player who
	-- resets gets a new body: put it back on
	function arena.onRespawn(entrant)
		if tails[entrant] and not tails[entrant]:IsDescendantOf(Workspace) then
			tails[entrant] = nil
			giveTail(entrant)
		end
	end

	function arena.update(standing, dt)
		local now = os.clock()
		for entrant in pairs(tails) do
			held[entrant] = (held[entrant] or 0) + dt
		end
		for _, grabber in ipairs(standing) do
			if not tails[grabber] and (immune[grabber] or 0) < now then
				local root = rootOf(grabber)
				for holder in pairs(tails) do
					if
						holder ~= grabber
						and (immune[holder] or 0) < now
						and root
						and near(holder, root.Position, 4, 5)
					then
						takeTail(holder)
						giveTail(grabber)
						immune[grabber] = now + 2 -- a moment to get away
						immune[holder] = now + 1
						Remotes.Effect:FireAllClients("gem", root.Position, { quiet = true })
						break
					end
				end
			end
		end
	end

	function arena.brain(bot, entrant)
		while true do
			local position = bot.root.Position
			local standing = round:Standing()
			if tails[entrant] then
				-- Run away from the nearest runner without a tail
				local chasers = {}
				for _, other in ipairs(standing) do
					if not tails[other] then
						table.insert(chasers, other)
					end
				end
				local chaser, distance = ArenaKit.nearest(position, chasers, entrant)
				local chaserRoot = chaser and rootOf(chaser)
				if chaserRoot and distance < 18 then
					local away = flat(position - chaserRoot.Position)
					away = away.Magnitude > 0.1 and away.Unit or Vector3.xAxis
					local goal = position + away * 6
					local fromCenter = flat(goal - center)
					if fromCenter.Magnitude > radius - 5 then
						-- Cornered against the wall: run along it
						local along = Vector3.new(-fromCenter.Z, 0, fromCenter.X).Unit
						if along:Dot(away) < 0 then
							along = -along
						end
						goal = position + along * 6 - fromCenter.Unit * 2
					end
					stepTo(bot, goal, 6, 0.5)
				else
					BotService.Wait(bot, 0.15)
				end
			else
				local targets = {}
				for holder in pairs(tails) do
					if (immune[holder] or 0) < os.clock() then
						table.insert(targets, holder)
					end
				end
				local target = ArenaKit.nearest(position, targets, entrant)
				local targetRoot = target and rootOf(target)
				if targetRoot then
					stepTo(bot, targetRoot.Position, 5, 0.5)
				else
					BotService.Wait(bot, 0.2)
				end
			end
		end
	end
	function arena.cleanup()
		for entrant in pairs(tails) do
			takeTail(entrant)
		end
	end
end

------------------------------------------------------------------ King of the Hill
Arenas.hill = function(arena, world)
	local round = arena.round
	local center = arena.origin.Position
	local radius, hillRadius, hillHeight = 34, 9, 4
	ArenaKit.disc(arena, radius, 0, world.floor[1], world.material)
	local top = ArenaKit.disc(arena, hillRadius, hillHeight, world.accent, Enum.Material.Neon, hillHeight)
	top.Name = "Hill"
	-- Four ramps up
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local length = 12
		local slope = math.atan(hillHeight / length)
		part({
			Name = "Ramp",
			Size = Vector3.new(7, 1, length / math.cos(slope) + 1),
			CFrame = arena.origin
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, hillHeight / 2 - 0.4, -(hillRadius + length / 2 - 1))
				* CFrame.Angles(-slope, 0, 0),
			Color = world.floor[2] or world.floor[1],
			Material = world.material,
			Parent = arena.folder,
		})
	end
	arena.killY = center.Y - 25
	arena.spawns = ArenaKit.ring(center + Vector3.new(0, ROOT_HEIGHT, 0), 26, 12)
	arena.label = "seconds on the hill"
	arena.scoreScale = 0.5 -- points are half-seconds

	local function onHill(entrant)
		local root = rootOf(entrant)
		if not root then
			return false
		end
		local offset = root.Position - center
		return flat(offset).Magnitude <= hillRadius + 0.5 and offset.Y > hillHeight + 1
	end
	local tick = 0
	function arena.update(standing, dt)
		tick += dt
		if tick < 0.5 then
			return
		end
		tick -= 0.5
		for _, entrant in ipairs(standing) do
			if onHill(entrant) then
				round:AddScore(entrant, 1)
			end
		end
	end

	function arena.brain(bot, entrant)
		while true do
			local position = bot.root.Position
			if onHill(entrant) then
				if not bonkNear(bot, entrant, round:Standing(), 0.9) then
					-- Stay near the middle of the hill
					local spot = center
						+ Vector3.new(random:NextNumber(-4, 4), hillHeight + ROOT_HEIGHT, random:NextNumber(-4, 4))
					stepTo(bot, spot, 4, 1.5)
				end
			elseif bonkNear(bot, entrant, round:Standing(), 0.4) then
				continue
			else
				-- The nearest ramp, then up it
				local best, bestDistance = nil, math.huge
				for index = 0, 3 do
					local angle = index * math.pi / 2
					local foot = (arena.origin * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -(hillRadius + 13))).Position
					local distance = flat(foot - position).Magnitude
					if distance < bestDistance then
						best, bestDistance = foot, distance
					end
				end
				if bestDistance > 3 and flat(position - center).Magnitude > hillRadius + 3 then
					stepTo(bot, best + Vector3.new(0, ROOT_HEIGHT, 0), 8, 1.5)
				else
					BotService.RunTo(bot, center + Vector3.new(0, hillHeight + ROOT_HEIGHT, 0), bot.speed, 3)
				end
			end
		end
	end
end

------------------------------------------------------------------ Egg Scramble
Arenas.eggs = function(arena, world)
	local round = arena.round
	local center = arena.origin.Position
	local radius = 36
	ArenaKit.disc(arena, radius, 0, world.floor[1], world.material)
	arena.killY = center.Y - 25
	arena.label = "eggs"

	-- Nests round the edge, one per team
	local nests = {}
	for index, team in ipairs(round.teams) do
		local angle = (index - 1) / #round.teams * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * 26, 0, math.sin(angle) * 26)
		part({
			Name = "Nest",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 13, 13),
			CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * ArenaKit.UPRIGHT,
			Color = team.color,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			CanCollide = false,
			Parent = arena.folder,
		})
		nests[team] = at
		team.home = at
	end
	function arena.teamSpawn(team)
		local at = team.home + Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4))
		return CFrame.lookAt(at + Vector3.new(0, ROOT_HEIGHT, 0), Vector3.new(center.X, at.Y + ROOT_HEIGHT, center.Z))
	end

	-- Eggs: in the pile, loose, in a nest, or carried
	local eggs = {}
	local carrying = {} -- [entrant] = egg
	local function eggAt(egg, at)
		egg.at = at
		egg.part.Anchored = true
		egg.part.CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0))
	end
	for _ = 1, 30 do
		local egg = {
			part = part({
				Name = "Egg",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2, 2.4, 2),
				Color = Color3.fromRGB(255, 250, 235),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CanQuery = false,
				Parent = arena.folder,
			}),
			state = "pile",
		}
		eggAt(egg, ArenaKit.randomOnDisc(random, center, 7, 0))
		table.insert(eggs, egg)
	end
	local function count(team)
		local n = 0
		for _, egg in ipairs(eggs) do
			if egg.state == "nest" and egg.team == team then
				n += 1
			end
		end
		return n
	end
	local function recount()
		for _, team in ipairs(round.teams) do
			round:SetTeamScore(team, count(team))
		end
	end
	local function pickUp(entrant, egg)
		local root = rootOf(entrant)
		if not root then
			return
		end
		egg.state = "carried"
		egg.carrier = entrant
		egg.team = nil
		carrying[entrant] = egg
		egg.part.Anchored = false
		egg.part.Massless = true
		egg.part.CFrame = root.CFrame * CFrame.new(0, 3.6, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Name = "Carry"
		weld.Part0 = root
		weld.Part1 = egg.part
		weld.Parent = egg.part
		round:You(entrant, "Got one! Take it to your nest")
		recount()
	end
	local function putDown(entrant, state, at, team)
		local egg = carrying[entrant]
		if not egg then
			return
		end
		carrying[entrant] = nil
		local weld = egg.part:FindFirstChild("Carry")
		if weld then
			weld:Destroy()
		end
		egg.state = state
		egg.team = team
		egg.carrier = nil
		eggAt(egg, at)
		recount()
	end
	round:OnHit(function(_, target)
		local root = rootOf(target.entrant)
		if root and carrying[target.entrant] then
			putDown(target.entrant, "loose", Vector3.new(root.Position.X, center.Y, root.Position.Z))
		end
	end)
	function arena.onFall(entrant)
		putDown(entrant, "pile", ArenaKit.randomOnDisc(random, center, 7, 0))
	end

	function arena.update(standing)
		for _, entrant in ipairs(standing) do
			local team = round.teamOf[entrant]
			local egg = carrying[entrant]
			if egg then
				if near(entrant, nests[team], 6, 8) then
					putDown(
						entrant,
						"nest",
						nests[team] + Vector3.new(random:NextNumber(-3.5, 3.5), 0, random:NextNumber(-3.5, 3.5)),
						team
					)
					round:AddScore(entrant, 1)
					round:You(entrant, "Egg in the nest! Get another")
					Remotes.Effect:FireAllClients("gem", nests[team] + Vector3.new(0, 2, 0), { quiet = true })
				end
			else
				for _, other in ipairs(eggs) do
					local free = other.state == "pile"
						or other.state == "loose"
						or (other.state == "nest" and other.team ~= team)
					if free and near(entrant, other.at, 3.5, 6) then
						pickUp(entrant, other)
						break
					end
				end
			end
		end
	end

	function arena.brain(bot, entrant)
		local team = round.teamOf[entrant]
		while true do
			local position = bot.root.Position
			if carrying[entrant] then
				stepTo(bot, nests[team] + Vector3.new(0, ROOT_HEIGHT, 0), 8, 2)
			else
				-- Bonk an enemy carrier close by
				local carriers = {}
				for carrier in pairs(carrying) do
					if round.teamOf[carrier] ~= team then
						table.insert(carriers, carrier)
					end
				end
				local carrier, distance = ArenaKit.nearest(position, carriers, entrant)
				local carrierRoot = carrier and rootOf(carrier)
				if carrierRoot and distance < 10 and random:NextNumber() < 0.4 + bot.skill * 0.4 then
					if not bonkNear(bot, entrant, carriers, 1) then
						stepTo(bot, carrierRoot.Position, 5, 2)
					end
				else
					-- The nearest egg in the pile or on the floor, else steal from the richest nest
					local best, bestDistance = nil, math.huge
					local richest, most = nil, 0
					for _, other in ipairs(round.teams) do
						if other ~= team and count(other) > most then
							richest, most = other, count(other)
						end
					end
					for _, egg in ipairs(eggs) do
						local wanted = egg.state == "pile"
							or egg.state == "loose"
							or (egg.state == "nest" and egg.team == richest)
						if wanted then
							local distance2 = flat(egg.at - position).Magnitude
								+ (egg.state == "nest" and 15 or 0)
								+ random:NextNumber(0, 4)
							if distance2 < bestDistance then
								best, bestDistance = egg, distance2
							end
						end
					end
					if best then
						stepTo(bot, best.at + Vector3.new(0, ROOT_HEIGHT, 0), 8, 1)
					else
						BotService.Wait(bot, 0.3)
					end
				end
			end
		end
	end
	function arena.cleanup()
		for entrant in pairs(carrying) do
			putDown(entrant, "pile", center)
		end
	end
end

------------------------------------------------------------------ Ball Rush
Arenas.ball = function(arena, world)
	local round = arena.round
	local center = arena.origin.Position
	local radius = 40
	local ballRadius = 6
	local goalWidth = math.rad(36) -- the gap in the wall for each goal
	ArenaKit.disc(arena, radius + 8, 0, world.floor[1], world.material)
	arena.killY = center.Y - 25
	arena.label = "goals let in"

	local goalAngles = {}
	for index, team in ipairs(round.teams) do
		local angle = (index - 1) / #round.teams * math.pi * 2
		goalAngles[team] = angle
		local at = center + Vector3.new(math.cos(angle) * (radius + 3), 0, math.sin(angle) * (radius + 3))
		team.home = center + Vector3.new(math.cos(angle) * (radius - 10), 0, math.sin(angle) * (radius - 10))
		part({
			Name = "Goal",
			Size = Vector3.new(6, 0.6, 2 * radius * math.sin(goalWidth / 2)),
			CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, -angle, 0),
			Color = team.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = arena.folder,
		})
	end
	local function angleDiff(a, b)
		return math.abs((a - b + math.pi) % (math.pi * 2) - math.pi)
	end
	local function goalAt(angle)
		for team, goalAngle in pairs(goalAngles) do
			if angleDiff(angle, goalAngle) < goalWidth / 2 then
				return team
			end
		end
		return nil
	end
	rim(arena, radius, 7, world.edge, function(angle)
		return goalAt(angle) ~= nil
	end)
	function arena.teamSpawn(team, index)
		local side = (index % 3 - 1) * 5
		local inward = flat(center - team.home).Unit
		local across = Vector3.new(-inward.Z, 0, inward.X)
		local at = team.home + across * side + inward * (index > 2 and 4 or 0)
		return CFrame.lookAt(at + Vector3.new(0, ROOT_HEIGHT, 0), Vector3.new(center.X, at.Y + ROOT_HEIGHT, center.Z))
	end

	local ball = part({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(ballRadius * 2, ballRadius * 2, ballRadius * 2),
		Color = world.accent,
		Material = Enum.Material.SmoothPlastic,
		Parent = arena.folder,
	})
	local position = center
	local velocity = Vector3.zero
	local spin = CFrame.new()
	local pausedUntil = 0
	local function show()
		ball.CFrame = CFrame.new(position + Vector3.new(0, ballRadius, 0)) * spin
	end
	show()
	local conceded = {}
	for _, team in ipairs(round.teams) do
		conceded[team] = 0
		round:SetTeamScore(team, 0)
	end

	function arena.update(standing, dt)
		if os.clock() < pausedUntil then
			return
		end
		-- Runners touching the ball push it away from them
		for _, entrant in ipairs(standing) do
			local root = rootOf(entrant)
			if root then
				local offset = flat(position - root.Position)
				if offset.Magnitude < ballRadius + 2.6 and root.Position.Y < position.Y + ballRadius * 2 + 2 then
					local direction = offset.Magnitude > 0.1 and offset.Unit or Vector3.xAxis
					velocity += direction * 70 * dt
				end
			end
		end
		if velocity.Magnitude > 32 then
			velocity = velocity.Unit * 32
		end
		velocity *= math.max(0, 1 - 0.7 * dt)
		position += velocity * dt
		if velocity.Magnitude > 0.1 then
			local axis = velocity.Unit:Cross(-Vector3.yAxis)
			spin = CFrame.fromAxisAngle(axis, velocity.Magnitude * dt / ballRadius) * spin
		end
		-- The wall, or a goal
		local fromCenter = flat(position - center)
		if fromCenter.Magnitude > radius - ballRadius then
			local angle = math.atan2(fromCenter.Z, fromCenter.X)
			local team = goalAt(angle)
			if team and fromCenter.Magnitude > radius + 1 then
				conceded[team] += 1
				round:SetTeamScore(team, -conceded[team])
				round:Announce(string.format("GOAL! %s let one in", team.name))
				Remotes.Effect:FireAllClients("finish", position + Vector3.new(0, ballRadius, 0), {})
				position, velocity = center, Vector3.zero
				pausedUntil = os.clock() + 2
			elseif not team then
				local normal = fromCenter.Unit
				position = center + normal * (radius - ballRadius)
				velocity = (velocity - normal * 2 * velocity:Dot(normal)) * 0.7
			end
		end
		show()
	end

	function arena.brain(bot, entrant)
		local team = round.teamOf[entrant]
		local defender = round:IndexInTeam(entrant) == 1 and #round.teams <= 3
		while true do
			local me = bot.root.Position
			if defender and flat(position - team.home).Magnitude < 22 then
				-- Guard: get between the ball and our goal, and push it away
				local out = flat(position - team.home)
				local spot = position - (out.Magnitude > 0.1 and out.Unit or Vector3.xAxis) * (ballRadius + 2)
				stepTo(bot, spot + Vector3.new(0, ROOT_HEIGHT, 0), 6, 1)
				BotService.RunTo(bot, position + Vector3.new(0, ROOT_HEIGHT, 0), bot.speed, 1)
			elseif defender then
				stepTo(bot, team.home + flat(position - team.home).Unit * 10 + Vector3.new(0, ROOT_HEIGHT, 0), 6, 2)
			else
				-- Attack the goal of the team that has let in the fewest
				local target, fewest = nil, math.huge
				for _, other in ipairs(round.teams) do
					if other ~= team and conceded[other] < fewest then
						target, fewest = other, conceded[other]
					end
				end
				local goal = center
					+ Vector3.new(math.cos(goalAngles[target]), 0, math.sin(goalAngles[target])) * radius
				local toGoal = flat(goal - position).Unit
				local behind = position - toGoal * (ballRadius + 2.5)
				local offset = flat(behind - me)
				if offset.Magnitude > 3 then
					-- Go round the ball, not through it
					local toBall = flat(position - me)
					if toBall.Magnitude < offset.Magnitude and toBall.Unit:Dot(offset.Unit) > 0.5 then
						local across = Vector3.new(-toGoal.Z, 0, toGoal.X)
						behind = position + across * (ballRadius + 4) * (random:NextNumber() < 0.5 and 1 or -1)
					end
					stepTo(bot, behind + Vector3.new(0, ROOT_HEIGHT, 0), 6, 1.5)
				else
					BotService.RunTo(bot, position + toGoal * 4 + Vector3.new(0, ROOT_HEIGHT, 0), bot.speed, 1)
				end
			end
		end
	end
end

------------------------------------------------------------------ The round
local function shuffle(list)
	for index = #list, 2, -1 do
		local other = random:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end

function GameRound.new(t, round, entrants, keep, _number, origin)
	local world = Worlds.ById[round.world] or Worlds.List[1]
	local folder = Instance.new("Model")
	folder.Name = "Arena_" .. round.id
	local self = setmetatable({
		t = t,
		round = round,
		entrants = entrants,
		keep = keep,
		scores = {},
		youText = {},
		byBot = {},
		hitListeners = {},
		respawning = {},
	}, GameRound)
	for _, entrant in ipairs(entrants) do
		self.scores[entrant] = 0
		if entrant.bot then
			self.byBot[entrant.bot] = entrant
		end
	end

	-- Teams: enough that one whole team going out leaves about `keep`
	if round.kind == "team" then
		local count = math.clamp(math.floor(#entrants / math.max(1, #entrants - keep) + 0.5), 2, #TEAMS)
		self.teams, self.teamOf = {}, {}
		for index = 1, count do
			table.insert(self.teams, { name = TEAMS[index].name, color = TEAMS[index].color, members = {}, score = 0 })
		end
		-- Players first, spread over the teams, then the bots
		local players, bots = {}, {}
		for _, entrant in ipairs(entrants) do
			table.insert(entrant.player and players or bots, entrant)
		end
		local order = shuffle(players)
		for _, bot in ipairs(shuffle(bots)) do
			table.insert(order, bot)
		end
		for index, entrant in ipairs(order) do
			local team = self.teams[(index - 1) % count + 1]
			table.insert(team.members, entrant)
			self.teamOf[entrant] = team
		end
	end

	local arena = { folder = folder, origin = origin, round = self }
	self.arena = arena
	Arenas[round.arena](arena, world, round.seconds)
	folder.Parent = Workspace

	for index, entrant in ipairs(entrants) do
		t:Place(entrant, self:SpawnFor(entrant, index))
		t:SetInRound(entrant, true)
		self:Mark(entrant)
	end
	return self
end

-- Where a runner (re)appears
function GameRound:SpawnFor(entrant, index)
	local arena = self.arena
	if self.teams and arena.teamSpawn then
		local team = self.teamOf[entrant]
		return arena.teamSpawn(team, index and (table.find(team.members, entrant) or 1) or random:NextInteger(1, 4))
	end
	return arena.spawns[index and ((index - 1) % #arena.spawns + 1) or random:NextInteger(1, #arena.spawns)]
end

-- Team colours on a runner's body
function GameRound:Mark(entrant)
	local team = self.teams and self.teamOf[entrant]
	local model = modelOf(entrant)
	if not team or not model then
		return
	end
	model:SetAttribute("Team", team.name)
	local old = model:FindFirstChild("TeamGlow")
	if not old then
		local glow = Instance.new("Highlight")
		glow.Name = "TeamGlow"
		glow.FillColor = team.color
		glow.FillTransparency = 0.65
		glow.OutlineColor = team.color
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = model
	end
end

function GameRound:Unmark(entrant)
	local model = modelOf(entrant)
	if model then
		model:SetAttribute("Team", nil)
		local glow = model:FindFirstChild("TeamGlow")
		if glow then
			glow:Destroy()
		end
	end
end

function GameRound:IndexInTeam(entrant)
	local team = self.teamOf and self.teamOf[entrant]
	return team and table.find(team.members, entrant) or 0
end

-- Runners who are in the arena right now (not falling back in)
function GameRound:Standing()
	local list = {}
	for _, entrant in ipairs(self.entrants) do
		if not entrant.left and not self.respawning[entrant] then
			table.insert(list, entrant)
		end
	end
	return list
end

-- The fighters a hammer can hit: everyone standing (not your own team)
function GameRound:Targets(fighter)
	local list = {}
	local myTeam = self.teamOf and self.teamOf[fighter.entrant]
	for _, entrant in ipairs(self:Standing()) do
		if entrant.fighter and (not myTeam or self.teamOf[entrant] ~= myTeam) then
			table.insert(list, entrant.fighter)
		end
	end
	return list
end

function GameRound:OnHit(listener)
	table.insert(
		self.hitListeners,
		CombatService.OnHit(function(attacker, target)
			if attacker.space == self and target.space == self then
				listener(attacker, target)
			end
		end)
	)
end

function GameRound:AddScore(entrant, amount)
	self.scores[entrant] = (self.scores[entrant] or 0) + amount
end

function GameRound:SetScore(entrant, value)
	self.scores[entrant] = value
end

function GameRound:SetTeamScore(team, value)
	team.score = value
end

-- A line just for this runner, under the round's status
function GameRound:You(entrant, text)
	if entrant.player and self.youText[entrant] ~= text then
		self.youText[entrant] = text
		Remotes.Announce:FireClient(entrant.player, "you", { tournament = self.t.id, text = text })
	end
end

-- A quick banner for everyone
function GameRound:Announce(text)
	self.t:Announce("flash", { text = text })
end

local function scoreText(self, value)
	local scale = self.arena.scoreScale or 1
	return tostring(math.floor(value * scale))
end

-- The status line: the top scores, or every team's score
function GameRound:StatusText()
	if self.teams then
		local parts = {}
		for _, team in ipairs(self.teams) do
			table.insert(parts, team.name .. " " .. tostring(math.abs(team.score)))
		end
		return string.format("%s:  %s", self.arena.label, table.concat(parts, "   "))
	end
	local order = self:Ranking()
	local parts = {}
	for index = 1, math.min(3, #order) do
		table.insert(parts, order[index].name .. " " .. scoreText(self, self.scores[order[index]]))
	end
	return string.format("Top %d go through  -  %s", self.keep, table.concat(parts, ", "))
end

-- Everyone still here, best first
function GameRound:Ranking()
	local list = {}
	for _, entrant in ipairs(self.entrants) do
		if not entrant.left then
			table.insert(list, entrant)
		end
	end
	local tiebreak = self.arena.tiebreak
	table.sort(list, function(a, b)
		local sa, sb = self.scores[a] or 0, self.scores[b] or 0
		if sa ~= sb then
			return sa > sb
		end
		if tiebreak then
			return tiebreak(a) > tiebreak(b)
		end
		return a.name < b.name
	end)
	return list
end

-- Fell off (or reset): back in a moment, after dropping what they carried
function GameRound:Fell(entrant)
	if self.respawning[entrant] or self.over then
		return
	end
	self.respawning[entrant] = true
	if entrant.fighter then
		local by = CombatService.LastHitBy(entrant.fighter, 6)
		if by then
			self.t:KnockedOut(by.entrant, entrant)
		end
	end
	if self.arena.onFall then
		self.arena.onFall(entrant)
	end
	if entrant.bot then
		BotService.Stop(entrant.bot)
	end
	task.delay(RESPAWN_SECONDS, function()
		if self.over or entrant.left then
			return
		end
		self.t:Place(entrant, self:SpawnFor(entrant))
		self.t:SetInRound(entrant, true)
		self:Mark(entrant)
		if self.round.hammers then
			CombatService.Leave(entrant)
			CombatService.Join(entrant, self)
		end
		if self.arena.onRespawn then
			self.arena.onRespawn(entrant)
		end
		self.respawning[entrant] = nil
		if entrant.bot then
			self:StartBot(entrant)
		end
	end)
end

function GameRound:StartBot(entrant)
	local bot = entrant.bot
	BotService.Start(bot, function()
		bot.onFrame = BotService.HazardCheck(self.arena, function()
			task.spawn(self.Fell, self, entrant)
		end)
		while true do
			local ok, err = pcall(self.arena.brain, bot, entrant)
			if not ok and err ~= "bot interrupted" then
				error(err, 0)
			end
			BotService.Wait(bot, 0.2)
		end
	end)
end

function GameRound:Play()
	local t = self.t
	local arena = self.arena
	t:Freeze(self.entrants, true)
	if self.teams then
		for _, team in ipairs(self.teams) do
			for _, entrant in ipairs(team.members) do
				if entrant.player then
					Remotes.Announce:FireClient(
						entrant.player,
						"team",
						{ tournament = t.id, name = team.name, color = team.color, teams = #self.teams }
					)
				end
			end
		end
	end
	t:Announce("countdown", { goAt = Workspace:GetServerTimeNow() + t.timing.countdown })
	task.wait(t.timing.countdown)
	t:Freeze(self.entrants, false)
	if arena.start then
		arena.start()
	end
	if self.round.hammers then
		for _, entrant in ipairs(self.entrants) do
			CombatService.Join(entrant, self)
		end
	end
	local endsAt = Workspace:GetServerTimeNow() + self.round.seconds
	local goal = self.teams and "The team with the fewest is out!" or string.format("Top %d go through!", self.keep)
	t:Announce("timer", { endsAt = endsAt, text = goal })
	for _, entrant in ipairs(self.entrants) do
		if entrant.bot then
			self:StartBot(entrant)
		end
		if self.teams then
			self:You(entrant, "You're on the " .. self.teamOf[entrant].name .. " team")
		end
	end

	local last = Workspace:GetServerTimeNow()
	while Workspace:GetServerTimeNow() < endsAt do
		task.wait(0.1)
		local now = Workspace:GetServerTimeNow()
		local dt = math.min(0.5, now - last)
		last = now
		local playersIn = false
		for _, entrant in ipairs(self.entrants) do
			if entrant.player and not entrant.left then
				playersIn = true
			end
			local root = rootOf(entrant)
			if not entrant.left and not self.respawning[entrant] and (not root or root.Position.Y < arena.killY) then
				task.spawn(self.Fell, self, entrant)
			end
		end
		if not playersIn then
			break
		end
		arena.update(self:Standing(), dt)
		t:Status(self:StatusText())
		if not self.teams then
			for place, entrant in ipairs(self:Ranking()) do
				if entrant.player and arena.label ~= "tail" then
					self:You(
						entrant,
						string.format(
							"You: %s %s  (%s)",
							scoreText(self, self.scores[entrant]),
							arena.label,
							place <= self.keep and "going through!" or "not in the top " .. self.keep .. " yet"
						)
					)
				end
			end
		end
	end
	self.over = true

	-- Who goes through
	local qualified, eliminated = {}, {}
	if self.teams then
		-- The team with the fewest points is out (a random one of them on a tie)
		local lowest = math.huge
		for _, team in ipairs(self.teams) do
			lowest = math.min(lowest, team.score)
		end
		local losers = {}
		for _, team in ipairs(self.teams) do
			if team.score == lowest then
				table.insert(losers, team)
			end
		end
		local loser = losers[random:NextInteger(1, #losers)]
		self.loser = loser
		t:Announce("flash", { text = loser.name .. " team is out!" })
		for _, entrant in ipairs(self:Ranking()) do
			table.insert(self.teamOf[entrant] == loser and eliminated or qualified, entrant)
		end
	else
		for index, entrant in ipairs(self:Ranking()) do
			table.insert(index <= self.keep and qualified or eliminated, entrant)
		end
	end
	for place, entrant in ipairs(qualified) do
		t:Qualified(entrant, place, nil)
	end
	return qualified, eliminated
end

function GameRound:Cleanup()
	self.over = true
	for _, stop in ipairs(self.hitListeners) do
		stop()
	end
	if self.arena.cleanup then
		pcall(self.arena.cleanup)
	end
	for _, entrant in ipairs(self.entrants) do
		CombatService.Leave(entrant)
		self:Unmark(entrant)
		if entrant.bot then
			BotService.Stop(entrant.bot)
		end
		self.t:SetInRound(entrant, false)
	end
	self.arena.folder:Destroy()
end

return GameRound
