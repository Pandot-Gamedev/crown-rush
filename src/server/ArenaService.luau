-- Builds the four arenas and runs what happens in them during a round:
--   Ice Floe       slippery ice tiles crack and sink from the edge inward
--   Spin Cycle     the floor spins faster and faster, a sweeper bar comes round
--   Lava Rise      lava climbs a stepped tower
--   Bounce House   bouncy walls push you back in, then fall away one by one
--
-- Every round gets a freshly built arena. ArenaService.Build returns an "arena"
-- object that MatchService and the bots use:
--   arena.spawns            up to 4 CFrames where players start
--   arena.floorY, .radius   floor height and how far the floor reaches
--   arena:SafeRadius()      how far from the middle is still safe right now
--   arena:IsOut(position)   true if that spot is deadly (lava)
--   arena:ShouldJump(pos)   true if a bot standing there should jump now
--   arena:RandomFloorPoint() somewhere safe to drop a power-up
--   arena:Start(), :SuddenDeath(), :Destroy()

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Arenas = require(Shared.Arenas)

local CombatService = require(script.Parent.CombatService)

local ArenaService = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder so it lies flat like a disc
local random = Random.new()

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function disc(folder, name, center, topY, radius, thickness, color, material)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, topY - thickness / 2, center.Z) * UPRIGHT,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = folder,
	})
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Spawn points around the middle, facing in
local function ringSpawns(center, y, radius)
	local spawns = {}
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local at = Vector3.new(center.X + math.cos(angle) * radius, y + 3.5, center.Z + math.sin(angle) * radius)
		table.insert(spawns, CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)))
	end
	return spawns
end

-- Shakes a floor piece, then lets it drop
local function crumble(tile, arena, delay)
	if tile:GetAttribute("Falling") then
		return
	end
	tile:SetAttribute("Falling", true)
	tile.Color = tile.Color:Lerp(Color3.new(1, 1, 1), 0.6)
	local home = tile.CFrame
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < (delay or 1.4) and tile.Parent do
			tile.CFrame = home * CFrame.new(random:NextNumber(-0.15, 0.15), 0, random:NextNumber(-0.15, 0.15))
			task.wait(0.05)
		end
		if not tile.Parent then
			return
		end
		tile.CFrame = home
		tile.Anchored = false
		task.delay(4, function()
			tile:Destroy()
		end)
	end)
	if arena and random:NextNumber() < 0.3 then
		CombatService.Effect("crack", tile.Position)
	end
end

local function baseArena(id, center)
	local info = Arenas.ById[id]
	local folder = Instance.new("Folder")
	folder.Name = info.name
	local arena = {
		id = id,
		name = info.name,
		center = center,
		floorY = center.Y,
		folder = folder,
		running = false,
		suddenDeath = false,
		started = 0,
		say = function() end, -- set by MatchService: shows a message to the players in this match
		entities = function()
			return {}
		end, -- set by MatchService: the entities still in the round
	}
	function arena:Elapsed()
		return self.running and os.clock() - self.started or 0
	end
	function arena:IsOut()
		return false
	end
	function arena:ShouldJump()
		return false
	end
	function arena:Start()
		self.running = true
		self.started = os.clock()
		if self.run then
			task.spawn(self.run, self)
		end
	end
	function arena:SuddenDeath()
		self.suddenDeath = true
		if self.onSuddenDeath then
			self:onSuddenDeath()
		end
	end
	function arena:Destroy()
		self.running = false
		if self.heartbeat then
			self.heartbeat:Disconnect()
		end
		folder:Destroy()
	end
	return arena
end

------------------------------------------------------------------ Ice Floe
local function buildIce(arena)
	local center, folder = arena.center, arena.folder
	local radius = 42
	arena.radius = radius
	local tiles = {}
	local ice = PhysicalProperties.new(0.9, 0.05, 0, 100, 1) -- slippery: you slide after a bonk
	for x = -radius, radius, 6 do
		for z = -radius, radius, 6 do
			local distance = math.sqrt(x * x + z * z)
			if distance <= radius then
				local shade = (math.floor(x / 6) + math.floor(z / 6)) % 2 == 0 and Color3.fromRGB(170, 225, 255)
					or Color3.fromRGB(150, 210, 245)
				local tile = part({
					Name = "Ice",
					Size = Vector3.new(5.8, 2, 5.8),
					Position = Vector3.new(center.X + x, arena.floorY - 1, center.Z + z),
					Material = Enum.Material.Ice,
					Color = shade,
					CustomPhysicalProperties = ice,
					Parent = folder,
				})
				table.insert(tiles, { part = tile, distance = distance })
			end
		end
	end
	-- Chunks of iceberg under the floe, for looks
	for _ = 1, 6 do
		local angle = random:NextNumber(0, math.pi * 2)
		local at = center
			+ Vector3.new(
				math.cos(angle) * random:NextNumber(5, 30),
				-random:NextNumber(8, 20),
				math.sin(angle) * random:NextNumber(5, 30)
			)
		part({
			Name = "Iceberg",
			Size = Vector3.new(random:NextNumber(8, 14), random:NextNumber(6, 12), random:NextNumber(8, 14)),
			CFrame = CFrame.new(at)
				* CFrame.Angles(random:NextNumber(-0.4, 0.4), random:NextNumber(0, 3), random:NextNumber(-0.4, 0.4)),
			Material = Enum.Material.Glacier,
			Color = Color3.fromRGB(190, 235, 255),
			CanCollide = false,
			CanQuery = false,
			Parent = folder,
		})
	end

	arena.spawns = ringSpawns(center, arena.floorY, 22)
	local safe = radius
	function arena:SafeRadius()
		return safe - 5
	end
	function arena:RandomFloorPoint()
		local choices = {}
		for _, tile in ipairs(tiles) do
			if tile.part.Parent and not tile.part:GetAttribute("Falling") and tile.distance < safe - 6 then
				table.insert(choices, tile.part)
			end
		end
		local pick = choices[random:NextInteger(1, math.max(1, #choices))]
		return pick and pick.Position + Vector3.new(0, 3.5, 0) or center + Vector3.new(0, 3.5, 0)
	end
	local function shrinkTo(newRadius)
		safe = newRadius
		for _, tile in ipairs(tiles) do
			if tile.distance > newRadius and tile.part.Parent then
				crumble(tile.part, arena)
			end
		end
	end
	local rings = { 36, 30, 24, 18, 12 }
	function arena.run(self)
		self.say("The ice is cracking from the edges!")
		local nextShrink = 12
		local index = 1
		while self.running and index <= #rings do
			if self:Elapsed() >= nextShrink then
				shrinkTo(rings[index])
				index += 1
				nextShrink += self.suddenDeath and 3 or 10
			end
			task.wait(0.25)
		end
	end
	function arena.onSuddenDeath(self)
		if self.running then
			shrinkTo(math.max(12, safe - 6))
		end
	end
end

------------------------------------------------------------------ Spin Cycle
local function buildSpin(arena)
	local center, folder = arena.center, arena.folder
	local radius = 36
	arena.radius = radius
	local floorY = arena.floorY

	local pin = part({
		Name = "Pin",
		Size = Vector3.new(4, 4, 4),
		Position = Vector3.new(center.X, floorY - 8, center.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	local spinner = part({
		Name = "Spinner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, floorY - 1, center.Z) * UPRIGHT,
		Color = Color3.fromRGB(255, 230, 190),
		Anchored = false,
		Parent = folder,
	})
	-- Coloured rings and stripes so you can see it turning
	local colors = {
		Color3.fromRGB(255, 150, 60),
		Color3.fromRGB(255, 230, 190),
		Color3.fromRGB(255, 110, 80),
		Color3.fromRGB(255, 230, 190),
		Color3.fromRGB(255, 200, 60),
	}
	for index, size in ipairs({ 70, 56, 42, 28, 12 }) do
		local ring = part({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, size, size),
			CFrame = CFrame.new(center.X, floorY + 0.02 * index, center.Z) * UPRIGHT,
			Color = colors[index],
			CanCollide = false,
			CanQuery = false,
			Anchored = false,
			Massless = true,
			Parent = folder,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = spinner
		weld.Part1 = ring
		weld.Parent = ring
	end
	for index = 0, 3 do
		local stripe = part({
			Name = "Stripe",
			Size = Vector3.new(0.6, 0.2, radius * 2 - 2),
			CFrame = CFrame.new(center.X, floorY + 0.12, center.Z) * CFrame.Angles(0, index * math.pi / 4, 0),
			Color = Color3.fromRGB(120, 60, 30),
			CanCollide = false,
			CanQuery = false,
			Anchored = false,
			Massless = true,
			Parent = folder,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = spinner
		weld.Part1 = stripe
		weld.Parent = stripe
	end
	local pinAttachment = Instance.new("Attachment")
	pinAttachment.CFrame = CFrame.new(0, 7, 0) * UPRIGHT
	pinAttachment.Parent = pin
	local spinAttachment = Instance.new("Attachment")
	spinAttachment.Parent = spinner
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = pinAttachment
	hinge.Attachment1 = spinAttachment
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.MotorMaxTorque = 1e12
	hinge.MotorMaxAcceleration = 1.5
	hinge.AngularVelocity = 0
	hinge.Parent = spinner

	-- The sweeper bar is drawn here and its hits are worked out with maths (more
	-- reliable than touching): it hits anyone low enough near its arm.
	local bar = part({
		Name = "Sweeper",
		Size = Vector3.new(radius, 1.4, 1.4),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Parent = folder,
	})
	local bar2 = part({
		Name = "Sweeper2",
		Size = Vector3.new(radius, 1.4, 1.4),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Parent = folder,
	})
	local sweeperOn, secondArm = false, false
	local angle, sweepSpeed = 0, 0.9
	local lastSwept = {}

	arena.spawns = ringSpawns(center, floorY, 18)
	function arena:SafeRadius()
		return radius - 7
	end
	function arena:RandomFloorPoint()
		local a = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(4, radius - 10)
		return Vector3.new(center.X + math.cos(a) * r, floorY + 3.5, center.Z + math.sin(a) * r)
	end
	local function armDirections()
		local first = CFrame.Angles(0, angle, 0) * Vector3.xAxis
		if secondArm then
			return { first, -first }
		end
		return { first }
	end
	function arena:ShouldJump(position)
		if not sweeperOn then
			return false
		end
		local rel = flat(position - center)
		for _, dir in ipairs(armDirections()) do
			local along = rel:Dot(dir)
			local ahead = Vector3.new(0, 1, 0):Cross(dir) -- the way the arm is moving
			local side = rel:Dot(ahead)
			if along > 0 and side > 0 and side < 7 then
				return true
			end
		end
		return false
	end

	arena.heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not arena.running then
			return
		end
		local elapsed = arena:Elapsed()
		hinge.AngularVelocity = arena.suddenDeath and 0.9 or math.min(0.7, 0.25 + elapsed * 0.008)
		if not sweeperOn then
			return
		end
		sweepSpeed = arena.suddenDeath and 2.2 or math.min(1.6, 0.9 + (elapsed - 12) * 0.015)
		angle += sweepSpeed * dt
		local base = CFrame.new(center.X, floorY + 1.6, center.Z)
		bar.CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(radius / 2, 0, 0)
		bar2.CFrame = base * CFrame.Angles(0, angle + math.pi, 0) * CFrame.new(radius / 2, 0, 0)
		local now = os.clock()
		for _, entity in ipairs(arena.entities()) do
			local root = entity.root
			if root and root.Parent and (lastSwept[entity] or 0) + 1 < now then
				local rel = root.Position - center
				local height = root.Position.Y - floorY
				if height < 4.6 and height > -2 then
					for _, dir in ipairs(armDirections()) do
						local flatRel = flat(rel)
						local along = flatRel:Dot(dir)
						local off = (flatRel - dir * along).Magnitude
						if along > 0 and along < radius + 1 and off < 2.2 then
							lastSwept[entity] = now
							local push = Vector3.new(0, 1, 0):Cross(dir)
							CombatService.Push(entity, push * 55 + Vector3.yAxis * 32, 0.6, 8)
							CombatService.Effect("hit", root.Position, { damage = 8 })
							break
						end
					end
				end
			end
		end
	end)

	function arena.run(self)
		task.wait(0.1)
		pcall(function()
			spinner:SetNetworkOwner(nil)
		end)
		self.say("The floor is spinning!")
		while self.running and self:Elapsed() < 12 do
			task.wait(0.25)
		end
		if not self.running then
			return
		end
		sweeperOn = true
		bar.Transparency = 0
		self.say("Sweeper bar! Jump over it!")
		while self.running and self:Elapsed() < 40 and not self.suddenDeath do
			task.wait(0.25)
		end
		if self.running then
			secondArm = true
			bar2.Transparency = 0
		end
	end
	function arena.onSuddenDeath()
		if sweeperOn then
			secondArm = true
			bar2.Transparency = 0
		end
	end
end

------------------------------------------------------------------ Lava Rise
local function buildLava(arena)
	local center, folder = arena.center, arena.folder
	local floorY = arena.floorY
	arena.radius = 40
	local tiers = {
		{ radius = 40, top = 0, color = Color3.fromRGB(70, 60, 60) },
		{ radius = 30, top = 5, color = Color3.fromRGB(95, 82, 78) },
		{ radius = 20, top = 10, color = Color3.fromRGB(120, 100, 92) },
		{ radius = 11, top = 15, color = Color3.fromRGB(150, 120, 100) },
	}
	for index, tier in ipairs(tiers) do
		disc(
			folder,
			"Tier" .. index,
			center,
			floorY + tier.top,
			tier.radius,
			tier.top + 4,
			tier.color,
			Enum.Material.Basalt
		)
		-- A glowing edge so the steps are easy to see
		disc(
			folder,
			"Edge" .. index,
			center,
			floorY + tier.top + 0.05,
			tier.radius + 0.2,
			0.3,
			Color3.fromRGB(255, 140, 50),
			Enum.Material.Neon
		).CanCollide =
			false
		disc(
			folder,
			"Top" .. index,
			center,
			floorY + tier.top + 0.1,
			tier.radius - 0.8,
			0.3,
			tier.color,
			Enum.Material.Basalt
		).CanCollide =
			false
	end
	local lavaTop = floorY - 8
	local lava = part({
		Name = "Lava",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 124, 124),
		CFrame = CFrame.new(center.X, lavaTop - 1, center.Z) * UPRIGHT,
		Color = Color3.fromRGB(255, 100, 20),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 40
	light.Brightness = 2
	light.Parent = lava

	local rises = { { at = 15, level = 1 }, { at = 35, level = 6 }, { at = 55, level = 11 } }
	local nextRise = 1
	arena.spawns = ringSpawns(center, floorY, 35)

	local function riseTo(level, seconds)
		local target = floorY + level
		TweenService:Create(
			lava,
			TweenInfo.new(seconds, Enum.EasingStyle.Sine),
			{ CFrame = CFrame.new(center.X, target - 1, center.Z) * UPRIGHT }
		):Play()
	end
	-- Read the lava's real height (it moves smoothly)
	local function currentTop()
		return lava.Position.Y + 1
	end
	function arena:IsOut(position)
		return position.Y < currentTop() + 2.5
	end
	function arena:SafeRadius()
		-- Head for the lowest step that will still be above the lava after the next rise
		local soon = currentTop()
		local upcoming = rises[nextRise]
		if upcoming and upcoming.at - self:Elapsed() < 10 then
			soon = math.max(soon, floorY + upcoming.level)
		end
		for _, tier in ipairs(tiers) do
			if floorY + tier.top > soon + 1 then
				return tier.radius - 3
			end
		end
		return tiers[#tiers].radius - 3
	end
	function arena:RandomFloorPoint()
		local safeTiers = {}
		for index, tier in ipairs(tiers) do
			if floorY + tier.top > currentTop() + 4 then
				table.insert(safeTiers, index)
			end
		end
		local index = safeTiers[random:NextInteger(1, math.max(1, #safeTiers))] or #tiers
		local tier = tiers[index]
		local inner = tiers[index + 1] and tiers[index + 1].radius + 2 or 0
		local a = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(inner, tier.radius - 2)
		return Vector3.new(center.X + math.cos(a) * r, floorY + tier.top + 3.5, center.Z + math.sin(a) * r)
	end
	function arena.run(self)
		self.say("The lava is coming up. Climb!")
		while self.running and nextRise <= #rises do
			local rise = rises[nextRise]
			if self:Elapsed() >= rise.at - 3 then
				self.say("Lava rising!")
				task.wait(3)
				if not self.running then
					return
				end
				riseTo(rise.level, 4)
				nextRise += 1
			end
			task.wait(0.25)
		end
	end
	function arena.onSuddenDeath()
		riseTo(12.5, 3)
		nextRise = #rises + 1
	end
	riseTo(-6, 0.1)
end

------------------------------------------------------------------ Bounce House
local function buildBounce(arena)
	local center, folder = arena.center, arena.folder
	local floorY = arena.floorY
	local half = 25
	arena.radius = 36
	local tiles = {}
	local colors = {
		Color3.fromRGB(255, 120, 200),
		Color3.fromRGB(255, 230, 90),
		Color3.fromRGB(110, 220, 255),
		Color3.fromRGB(255, 255, 255),
	}
	for ix = -2, 2 do
		for iz = -2, 2 do
			local tile = part({
				Name = "Floor",
				Size = Vector3.new(10, 2, 10),
				Position = Vector3.new(center.X + ix * 10, floorY - 1, center.Z + iz * 10),
				Color = colors[((ix + iz) % #colors) + 1],
				Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			})
			table.insert(tiles, { part = tile, outer = math.max(math.abs(ix), math.abs(iz)) == 2 })
		end
	end
	local walls = {}
	local sides = {
		{
			normal = Vector3.new(0, 0, 1),
			size = Vector3.new(half * 2 + 6, 5, 3),
			offset = Vector3.new(0, 0, -half - 1.5),
		},
		{
			normal = Vector3.new(0, 0, -1),
			size = Vector3.new(half * 2 + 6, 5, 3),
			offset = Vector3.new(0, 0, half + 1.5),
		},
		{ normal = Vector3.new(1, 0, 0), size = Vector3.new(3, 5, half * 2), offset = Vector3.new(-half - 1.5, 0, 0) },
		{ normal = Vector3.new(-1, 0, 0), size = Vector3.new(3, 5, half * 2), offset = Vector3.new(half + 1.5, 0, 0) },
	}
	for index, side in ipairs(sides) do
		local wall = part({
			Name = "BouncyWall",
			Size = side.size,
			Position = center + side.offset + Vector3.new(0, 2.5, 0),
			Color = index % 2 == 0 and Color3.fromRGB(255, 110, 200) or Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		local long = side.size.X > side.size.Z and side.size.X or side.size.Z
		local roll = part({
			Name = "WallTop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(long, 3.4, 3.4),
			CFrame = CFrame.new(wall.Position + Vector3.new(0, 2.5, 0))
				* (side.size.X > side.size.Z and CFrame.new() or CFrame.Angles(0, math.rad(90), 0)),
			Color = wall.Color:Lerp(Color3.new(1, 1, 1), 0.3),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		table.insert(walls, { part = wall, top = roll, normal = side.normal, up = true })
	end

	arena.spawns = ringSpawns(center, floorY, 14)
	local outerGone = false
	local lastBounce = {}
	function arena:SafeRadius()
		return outerGone and 11 or 19
	end
	function arena:RandomFloorPoint()
		local limit = outerGone and 10 or 18
		return Vector3.new(
			center.X + random:NextNumber(-limit, limit),
			floorY + 3.5,
			center.Z + random:NextNumber(-limit, limit)
		)
	end
	local function dropWall(wall)
		if not wall.up then
			return
		end
		wall.up = false
		for _, p in ipairs({ wall.part, wall.top }) do
			p.CanCollide = false
			TweenService
				:Create(p, TweenInfo.new(1.2), { Position = p.Position - Vector3.new(0, 12, 0), Transparency = 1 })
				:Play()
		end
		task.delay(1.3, function()
			wall.part:Destroy()
			wall.top:Destroy()
		end)
	end
	local function dropOuter()
		if outerGone then
			return
		end
		outerGone = true
		for _, tile in ipairs(tiles) do
			if tile.outer then
				crumble(tile.part, arena)
			end
		end
	end

	-- Bouncy walls throw you back in (worked out with maths, so fast hits never pass through)
	arena.heartbeat = RunService.Heartbeat:Connect(function()
		if not arena.running then
			return
		end
		local now = os.clock()
		for _, entity in ipairs(arena.entities()) do
			local root = entity.root
			if root and root.Parent and (lastBounce[entity] or 0) + 0.5 < now then
				local rel = root.Position - center
				if rel.Y - (floorY - center.Y) < 8 then
					for _, wall in ipairs(walls) do
						if wall.up and rel:Dot(wall.normal) + half < 2.4 then
							lastBounce[entity] = now
							CombatService.Push(entity, wall.normal * 55 + Vector3.yAxis * 25, 0.35, 0)
							CombatService.Effect("bounce", root.Position)
							break
						end
					end
				end
			end
		end
	end)

	function arena.run(self)
		self.say("Bounce off the walls... while they last!")
		local order = { 1, 2, 3, 4 }
		for index = #order, 2, -1 do
			local other = random:NextInteger(1, index)
			order[index], order[other] = order[other], order[index]
		end
		local dropAt = { 20, 30, 40, 50 }
		local nextDrop = 1
		while self.running do
			local elapsed = self:Elapsed()
			if nextDrop <= #order and elapsed >= dropAt[nextDrop] then
				if walls[order[nextDrop]].up then
					dropWall(walls[order[nextDrop]])
					self.say("A wall fell away!")
				end
				nextDrop += 1
			end
			if not outerGone and elapsed >= 60 then
				self.say("The floor is shrinking!")
				dropOuter()
			end
			if outerGone and nextDrop > #order then
				return
			end
			task.wait(0.25)
		end
	end
	function arena.onSuddenDeath()
		for _, wall in ipairs(walls) do
			dropWall(wall)
		end
		dropOuter()
	end
end

local BUILDERS = { ice = buildIce, spin = buildSpin, lava = buildLava, bounce = buildBounce }

-- Builds a fresh arena of that kind with its floor at center
function ArenaService.Build(arenaId, center, parent)
	local builder = BUILDERS[arenaId] or buildIce
	local arena = baseArena(Arenas.ById[arenaId] and arenaId or "ice", center)
	builder(arena)
	arena.folder.Parent = parent or Workspace
	-- The server moves the spinning floor, so no player's computer takes it over
	for _, item in ipairs(arena.folder:GetDescendants()) do
		if item:IsA("BasePart") and not item.Anchored then
			pcall(item.SetNetworkOwner, item, nil)
		end
	end
	return arena
end

return ArenaService
