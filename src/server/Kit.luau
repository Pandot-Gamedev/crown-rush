-- The obstacle kit: every piece a course can be made of. Each builder lays one
-- piece down in front of a cursor (a CFrame in the middle of the path, at floor
-- level, facing the way you run) and returns where the next piece starts.
--
-- Moving obstacles don't move on the server: they carry Motion attributes (see
-- Shared/Motion) and every player's computer moves them from the shared clock.
-- Tags tell players' computers what a part does:
--   Moving   moves by its Motion attributes
--   Hit      knocks you back when it touches you (Low = true: low enough to jump)
--   Kill     sends you back to your checkpoint (lava, lasers, spikes)
--   Bounce   launches you with its Launch attribute (a velocity)
--   Belt     floor that carries you along its Belt attribute (conveyors, slides)
--   Wind     a zone that pushes you by Push while its gust is on
--   Zip      the start of a zipline (ends at its ZipTo attribute)
-- and these are handled by the server:
--   FallTile tiles that drop a moment after someone steps on them
--   FakeDoor doors you can run straight through
--
-- Builders also return "nodes": the path bots follow (see BotService).

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Motion = require(Shared.Motion)
local Crown = require(Shared.Crown)

local Kit = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's length runs up and down

------------------------------------------------------------------ Helpers
-- A piece being built: knows the cursor, the theme and the course's folder
local Piece = {}
Piece.__index = Piece

local function newPiece(ctx, cursor)
	return setmetatable({
		ctx = ctx,
		cursor = cursor,
		theme = ctx.theme,
		random = ctx.random,
		folder = ctx.folder,
		nodes = {},
		minY = cursor.Position.Y,
		gemSpot = nil,
		shade = 0,
	}, Piece)
end

-- World point from local x (right), y (up), z (forward)
function Piece:P(x, y, z)
	return self.cursor:PointToWorldSpace(Vector3.new(x, y, -z))
end

function Piece:C(x, y, z)
	return self.cursor * CFrame.new(x, y, -z)
end

function Piece:Part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = self.theme.material
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Tags" and key ~= "Attributes" then
			p[key] = value
		end
	end
	for name, value in pairs(props.Attributes or {}) do
		p:SetAttribute(name, value)
	end
	for _, tag in ipairs(props.Tags or {}) do
		CollectionService:AddTag(p, tag)
	end
	p.Parent = props.Parent or self.folder
	return p
end

function Piece:FloorColor()
	self.shade += 1
	return self.theme.floor[(self.shade % #self.theme.floor) + 1]
end

-- A floor slab whose top is at local height y. Centre (x, z), width w, length l.
function Piece:Floor(x, y, z, w, l, props)
	props = props or {}
	local thickness = props.thickness or 2
	local p = self:Part({
		Name = props.Name or "Floor",
		Size = Vector3.new(w, thickness, l),
		CFrame = self:C(x, y - thickness / 2, z),
		Color = props.Color or self:FloorColor(),
		Material = props.Material or self.theme.material,
		Tags = props.Tags,
		Attributes = props.Attributes,
		Transparency = props.Transparency or 0,
	})
	local top = self:P(x, y, z).Y
	if top < self.minY then
		self.minY = top
	end
	return p
end

-- A round platform whose top is at local height y
function Piece:Disc(x, y, z, radius, props)
	props = props or {}
	local thickness = props.thickness or 2
	local p = self:Part({
		Name = props.Name or "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = self:C(x, y - thickness / 2, z) * UPRIGHT,
		Color = props.Color or self:FloorColor(),
		Material = props.Material or self.theme.material,
	})
	local top = self:P(x, y, z).Y
	if top < self.minY then
		self.minY = top
	end
	return p
end

-- A glowing frame round the top edge of a floor slab (see Floor), so a
-- platform floating over a drop stands out from the sky behind it
function Piece:Trim(x, y, z, w, l, color)
	local thickness = 0.5
	local edges = {
		{ 0, z - l / 2 + thickness / 2, w, thickness },
		{ 0, z + l / 2 - thickness / 2, w, thickness },
		{ -w / 2 + thickness / 2, z, thickness, l },
		{ w / 2 - thickness / 2, z, thickness, l },
	}
	for _, edge in ipairs(edges) do
		self:Part({
			Name = "Trim",
			Size = Vector3.new(edge[3], 0.3, edge[4]),
			CFrame = self:C(x + edge[1], y + 0.15, edge[2]),
			Color = color or self.theme.edge,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

-- A low glowing rim along both sides of a stretch of path, for looks
function Piece:Rails(y, z0, z1, w)
	for _, side in ipairs({ -1, 1 }) do
		self:Part({
			Name = "Rim",
			Size = Vector3.new(0.6, 0.6, math.abs(z1 - z0)),
			CFrame = self:C(side * (w / 2 - 0.3), y + 0.3, (z0 + z1) / 2),
			Color = self.theme.edge,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
end

-- A moving part. motion = attributes for Shared/Motion (Home in world space).
function Piece:Mover(props, motion, tags)
	local attributes = props.Attributes or {}
	for key, value in pairs(motion) do
		attributes[key] = value
	end
	props.Attributes = attributes
	props.Tags = props.Tags or {}
	table.insert(props.Tags, Motion.Tag)
	for _, tag in ipairs(tags or {}) do
		table.insert(props.Tags, tag)
	end
	local p = self:Part(props)
	local spec = Motion.Read(p)
	p.CFrame = Motion.At(spec, Motion.Clock())
	return p, spec
end

function Piece:Node(node)
	table.insert(self.nodes, node)
	return node
end

-- Walk to a local point (on the floor)
function Piece:Go(x, y, z, extra)
	local node = { kind = "go", to = self:P(x, y, z) }
	for key, value in pairs(extra or {}) do
		node[key] = value
	end
	return self:Node(node)
end

function Piece:Jump(x, y, z, extra)
	local node = { kind = "jump", to = self:P(x, y, z) }
	for key, value in pairs(extra or {}) do
		node[key] = value
	end
	return self:Node(node)
end

function Piece:Gem(x, y, z)
	self.gemSpot = self:P(x, y + 2.5, z)
end

-- Every builder ends with this: the cursor for the next piece
function Piece:Done(length, rise, turn)
	local nextCursor = self.cursor * CFrame.new(0, rise or 0, -length)
	if turn then
		nextCursor = nextCursor * CFrame.Angles(0, turn, 0)
	end
	return {
		cursor = nextCursor,
		nodes = self.nodes,
		minY = self.minY,
		gemSpot = self.gemSpot,
		checkpoint = self.checkpoint,
		finish = self.finish,
		start = self.start,
	}
end

------------------------------------------------------------------ Builders
local B = {}

-- The start platform with a starting arch. The timer starts when you leave it.
B.start = function(pc)
	local w, l = 24, 22
	pc:Floor(0, 0, l / 2, w, l, { Color = pc.theme.floor[2] })
	pc:Rails(0, 0, l, w)
	pc:Part({ Name = "BackWall", Size = Vector3.new(w, 10, 1), CFrame = pc:C(0, 5, -0.5), Transparency = 1 })
	for _, side in ipairs({ -1, 1 }) do
		pc:Part({
			Name = "ArchPost",
			Size = Vector3.new(1.6, 14, 1.6),
			CFrame = pc:C(side * (w / 2 - 1), 7, l - 1),
			Color = pc.theme.edge,
			Material = Enum.Material.SmoothPlastic,
		})
		pc:Part({
			Name = "SideWall",
			Size = Vector3.new(1, 10, l),
			CFrame = pc:C(side * (w / 2 + 0.5), 5, l / 2),
			Transparency = 1,
		})
	end
	local bar = pc:Part({
		Name = "StartBanner",
		Size = Vector3.new(w, 3, 1),
		CFrame = pc:C(0, 13, l - 1),
		Color = pc.theme.accent,
		Material = Enum.Material.SmoothPlastic,
	})
	pc.ctx.sign(bar, "START")
	pc:Part({
		Name = "StartLine",
		Size = Vector3.new(w, 0.1, 1.2),
		CFrame = pc:C(0, 0.05, l - 1),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	pc.start = { spawn = pc:C(0, 3.5, 6), lineCFrame = pc:C(0, 0, l - 1), size = Vector3.new(w, 20, 2) }
	pc:Go(0, 0, l)
	return pc:Done(l)
end

-- A checkpoint pad with flags. You come back here when you fall.
B.checkpoint = function(pc)
	local w, l = 22, 14
	pc:Floor(0, 0, l / 2, w, l, { Color = pc.theme.floor[2] })
	local pad = pc:Part({
		Name = "CheckpointPad",
		Size = Vector3.new(w - 4, 0.2, l - 4),
		CFrame = pc:C(0, 0.1, l / 2),
		Color = Color3.fromRGB(90, 230, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.4,
	})
	for _, side in ipairs({ -1, 1 }) do
		pc:Part({
			Name = "FlagPole",
			Size = Vector3.new(0.5, 9, 0.5),
			CFrame = pc:C(side * (w / 2 - 1), 4.5, l / 2),
			Color = Color3.fromRGB(230, 230, 230),
			Material = Enum.Material.Metal,
		})
		pc:Part({
			Name = "Flag",
			Size = Vector3.new(0.2, 2.4, 3.4),
			CFrame = pc:C(side * (w / 2 - 1), 7.6, l / 2 + 1.8),
			Color = Color3.fromRGB(90, 230, 120),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
	pc.checkpoint = { spawn = pc:C(0, 3.5, l / 2), center = pad.CFrame, size = Vector3.new(w, 20, l) }
	pc:Go(0, 0, l)
	return pc:Done(l)
end

-- The finish platform: an arch with a chequered line, confetti when you cross
B.finish = function(pc, o)
	local w, l = 28, 26
	pc:Floor(0, 0, l / 2, w, l, { Color = pc.theme.floor[2] })
	pc:Rails(0, 0, l, w)
	for _, side in ipairs({ -1, 1 }) do
		pc:Part({
			Name = "ArchPost",
			Size = Vector3.new(2, 16, 2),
			CFrame = pc:C(side * (w / 2 - 1.5), 8, 6),
			Color = pc.theme.accent,
			Material = Enum.Material.SmoothPlastic,
		})
		pc:Part({
			Name = "SideWall",
			Size = Vector3.new(1, 12, l),
			CFrame = pc:C(side * (w / 2 + 0.5), 6, l / 2),
			Transparency = 1,
		})
	end
	pc:Part({ Name = "BackWall", Size = Vector3.new(w, 12, 1), CFrame = pc:C(0, 6, l + 0.5), Transparency = 1 })
	local banner = pc:Part({
		Name = "FinishBanner",
		Size = Vector3.new(w, 4, 1),
		CFrame = pc:C(0, 15, 6),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	pc.ctx.sign(banner, o.crown and "GRAB THE CROWN!" or "FINISH")
	if o.crown then
		-- The tournament's crown, spinning over the line: first one through wins it
		local home = pc:C(0, 7.5, 6)
		for _, piece in ipairs(Crown.Pieces(5, "full")) do
			local p = Crown.Make(piece)
			p:SetAttribute("Motion", "spin")
			p:SetAttribute("Home", home)
			p:SetAttribute("Offset", piece.cframe)
			p:SetAttribute("Speed", 1.5)
			CollectionService:AddTag(p, Motion.Tag)
			p.CFrame = Motion.At(Motion.Read(p), Motion.Clock())
			p.Parent = pc.folder
			if piece.name == "CrownVelvet" then
				local light = Instance.new("PointLight")
				light.Color = Crown.Gold
				light.Range = 18
				light.Brightness = 3
				light.Parent = p
			end
		end
	end
	for index = 0, 13 do
		pc:Part({
			Name = "FinishLine",
			Size = Vector3.new(w / 14, 0.1, 1.6),
			CFrame = pc:C(-w / 2 + w / 28 + index * w / 14, 0.05, 6),
			Color = index % 2 == 0 and Color3.new(1, 1, 1) or Color3.new(0.1, 0.1, 0.1),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
	pc.finish = { lineCFrame = pc:C(0, 0, 6), size = Vector3.new(w, 24, 3), stand = pc:C(0, 3.5, 16) }
	pc:Go(0, 0, 10)
	return pc:Done(l)
end

-- A plain stretch. Good for breathing room between hard parts.
B.run = function(pc, o)
	local l, w = o.len or 24, o.w or 16
	pc:Floor(0, 0, l / 2, w, l)
	pc:Rails(0, 0, l, w)
	if o.gem then
		pc:Gem(w / 2 - 2, 0, l / 2)
	end
	pc:Go(0, 0, l)
	return pc:Done(l)
end

-- A slope up (or down with a negative rise)
B.ramp = function(pc, o)
	local l, w, rise = o.len or 30, o.w or 16, o.rise or 10
	local slope = math.sqrt(l * l + rise * rise)
	local angle = math.atan2(rise, l)
	pc:Part({
		Name = "Ramp",
		Size = Vector3.new(w, 2, slope),
		CFrame = pc:C(0, rise / 2, l / 2) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -1, 0),
		Color = pc:FloorColor(),
	})
	pc.minY = math.min(pc.minY, pc:P(0, math.min(0, rise), 0).Y)
	if o.gem then
		pc:Gem(-w / 2 + 2, rise / 2, l / 2)
	end
	pc:Go(0, rise, l)
	return pc:Done(l, rise)
end

-- Steps up
B.stairs = function(pc, o)
	local steps, rise, depth, w = o.steps or 6, o.rise or 1.5, o.depth or 4, o.w or 16
	for index = 1, steps do
		pc:Floor(0, index * rise, (index - 0.5) * depth, w, depth, { thickness = index * rise + 2 })
	end
	pc:Go(0, steps * rise, steps * depth)
	return pc:Done(steps * depth, steps * rise)
end

-- A corner: turns the course left or right
B.turn = function(pc, o)
	local size = o.size or 20
	pc:Floor(0, 0, size / 2, size, size)
	local turn = o.dir == "left" and math.rad(90) or math.rad(-90)
	pc:Go(0, 0, size / 2)
	-- The next piece starts at the side of this square
	local result = pc:Done(size / 2, 0, turn)
	result.cursor = result.cursor * CFrame.new(0, 0, -size / 2)
	return result
end

-- Stepping stones over a drop. drift moves each stone sideways (zigzag).
B.gaps = function(pc, o)
	local count, gap, size, drift, w = o.count or 4, o.gap or 5, o.size or 8, o.drift or 0, o.w or 16
	local z = 0
	local lastX = 0
	for index = 1, count do
		z += gap
		local x = drift * (index % 2 == 0 and 1 or -1)
		if index == count then
			x = 0
		end
		local y = (o.climb or 0) * index
		-- Bright stones that stand out from the sky (darker every other one)
		local stone = pc.theme.stone or pc.theme.accent
		pc:Floor(x, y, z + size / 2, size, size, { Color = index % 2 == 0 and stone:Lerp(Color3.new(), 0.18) or stone })
		pc:Trim(x, y, z + size / 2, size, size)
		pc:Jump(x, y, z + size / 2, { risk = 0.04 })
		lastX = x
		z += size
	end
	z += gap
	local endY = (o.climb or 0) * count
	pc:Floor(0, endY, z + 3, w, 6)
	pc:Trim(0, endY, z + 3, w, 6)
	pc:Jump(lastX * 0.5, endY, z + 3)
	if o.gem then
		pc:Floor(w / 2 + (o.gemOut or 6), endY, z - size / 2 - gap, 5, 5, { Color = pc.theme.accent })
		pc:Gem(w / 2 + (o.gemOut or 6), endY, z - size / 2 - gap)
	end
	return pc:Done(z + 6, endY)
end

-- Platforms that slide across a gap. axis "side" (left-right) or "forward".
B.movers = function(pc, o)
	local count, period, dist, size = o.count or 3, o.period or 5, o.dist or 14, o.size or 9
	local forward = o.axis == "forward"
	local z = 6
	pc:Floor(0, 0, 3, 16, 6)
	for index = 1, count do
		local gapBefore = forward and 4 or 5
		z += gapBefore
		local zCenter = z + size / 2
		local axis, home
		local phase = (index - 1) * period * 0.5
		if forward then
			axis = Vector3.new(0, 0, -1)
			home = pc:C(0, -1, zCenter)
		else
			axis = Vector3.xAxis
			home = pc:C(-dist / 2, -1, zCenter)
		end
		local _, spec = pc:Mover(
			{ Name = "MovingPlatform", Size = Vector3.new(size, 2, size), Color = pc.theme.mover },
			{
				Motion = "slide",
				Home = home,
				Axis = axis,
				Dist = forward and dist or dist,
				Period = period,
				Phase = phase,
				Hold = 0.25,
			}
		)
		pc:Node({
			kind = "ride",
			spec = spec,
			enter = pc:P(0, 0, z - gapBefore),
			-- just onto what comes next (forward platforms travel dist further first)
			exit = pc:P(0, 0, z + size + (forward and dist or 0) + 6),
			forward = forward,
		})
		z += size + (forward and dist or 0)
	end
	z += 5
	pc:Floor(0, 0, z + 4, 16, 8)
	pc:Go(0, 0, z + 4)
	if o.gem then
		pc:Floor(-12, 0, z + 4, 6, 6, { Color = pc.theme.accent })
		pc:Gem(-12, 0, z + 4)
	end
	return pc:Done(z + 8)
end

-- A round platform with a spinning bar at knee height: jump over it.
-- bars = 1 or 2, high = true adds a second, higher bar you must not jump into.
B.spinner = function(pc, o)
	local radius, speed, bars = o.r or 16, o.speed or 1.3, o.bars or 1
	local z = radius + 3
	pc:Floor(0, 0, 2, 12, 4)
	pc:Disc(0, 0, z, radius)
	local center = pc:C(0, 0, z)
	pc:Part({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 3, 3),
		CFrame = center * CFrame.new(0, 2, 0) * UPRIGHT,
		Color = pc.theme.edge,
		Material = Enum.Material.SmoothPlastic,
	})
	for index = 1, bars do
		local home = center * CFrame.new(0, 1.4, 0)
		pc:Mover({
			Name = "SpinnerBar",
			Size = Vector3.new(radius * 2 - 1, 1.2, 1.2),
			Color = pc.theme.hazard,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Attributes = { Low = true },
		}, {
			Motion = "spin",
			Home = home,
			Speed = speed * (o.reverse and -1 or 1),
			Phase = (index - 1) * math.pi / bars,
		}, { "Hit" })
	end
	if o.high then
		local home = center * CFrame.new(0, 6.5, 0)
		pc:Mover({
			Name = "HighBar",
			Size = Vector3.new(radius * 2 - 1, 1.2, 1.2),
			Color = pc.theme.hazard,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, { Motion = "spin", Home = home, Speed = -speed * 0.8, Phase = math.pi / 2 }, { "Hit" })
	end
	-- Bots cross off-centre: near the hub the bar is too slow to hop over
	local side = o.side or 1
	pc:Go(0, 0, z - radius + 2)
	pc:Go(side * radius * 0.45, 0, z - radius * 0.5, { hazard = true })
	pc:Go(side * radius * 0.45, 0, z + radius * 0.5, { hazard = true })
	pc:Go(0, 0, z + radius - 2, { hazard = true })
	pc:Floor(0, 0, z * 2 - 1, 12, 4)
	pc:Go(0, 0, z * 2)
	if o.gem then
		pc:Gem(radius - 3, 0, z)
	end
	return pc:Done(z * 2 + 1)
end

-- A narrow bridge with pendulum hammers swinging across it
B.hammers = function(pc, o)
	local count, period, w = o.count or 3, o.period or 3.2, o.w or 8
	local spacing = o.spacing or 14
	local l = count * spacing + 8
	pc:Floor(0, 0, l / 2, w, l, { Name = "Bridge" })
	for index = 1, count do
		local z = 4 + (index - 0.5) * spacing
		local pivot = pc:C(0, 18, z)
		pc:Part({
			Name = "HammerBeam",
			Size = Vector3.new(w + 10, 1.4, 1.4),
			CFrame = pivot * CFrame.new(0, 0.5, 0),
			Color = pc.theme.edge,
			Material = Enum.Material.Wood,
		})
		for _, side in ipairs({ -1, 1 }) do
			pc:Part({
				Name = "HammerPost",
				Size = Vector3.new(1.4, 20, 1.4),
				CFrame = pc:C(side * (w / 2 + 5), 9, z),
				Color = pc.theme.edge,
				Material = Enum.Material.Wood,
			})
		end
		local motion =
			{ Motion = "swing", Home = pivot, Amp = math.rad(65), Period = period, Phase = (index % 2) * period / 2 }
		pc:Mover(
			{
				Name = "HammerArm",
				Size = Vector3.new(0.8, 14, 0.8),
				Color = Color3.fromRGB(90, 70, 50),
				Material = Enum.Material.Wood,
				CanCollide = false,
			},
			(function()
				local m = table.clone(motion)
				m.Offset = CFrame.new(0, -7, 0)
				return m
			end)()
		)
		local head = table.clone(motion)
		head.Offset = CFrame.new(0, -15, 0) * CFrame.Angles(0, math.rad(90), 0) -- the head's length runs along the bridge
		pc:Mover({
			Name = "HammerHead",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 4.5, 4.5),
			Color = pc.theme.hazard,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, head, { "Hit" })
		-- Bots stop between hammers and time each dash
		pc:Go(0, 0, z + spacing / 2, { hazard = true })
	end
	pc:Rails(0, 0, l, w)
	pc:Go(0, 0, l)
	if o.gem then
		pc:Gem(0, 7, l - 6)
	end
	return pc:Done(l)
end

-- An uphill ramp with balls rolling down lanes
B.balls = function(pc, o)
	local l, rise, lanes, period = o.len or 60, o.rise or 10, o.lanes or 3, o.period or 3.6
	local laneWidth = 6
	local w = lanes * laneWidth + 2
	local angle = math.atan2(rise, l)
	local slope = math.sqrt(l * l + rise * rise)
	pc:Part({
		Name = "Ramp",
		Size = Vector3.new(w, 2, slope),
		CFrame = pc:C(0, rise / 2, l / 2) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -1, 0),
		Color = pc:FloorColor(),
	})
	for _, side in ipairs({ -1, 1 }) do
		pc:Part({
			Name = "RampWall",
			Size = Vector3.new(1, 3, slope),
			CFrame = pc:C(side * (w / 2 + 0.5), rise / 2 + 1, l / 2) * CFrame.Angles(angle, 0, 0),
			Color = pc.theme.edge,
		})
	end
	-- One boulder per lane at a time, staggered between lanes: dodge into
	-- another lane or jump it (they're low enough to jump)
	local radius = 2
	local lanesX = {}
	for lane = 1, lanes do
		local x = -w / 2 + 1 + (lane - 0.5) * laneWidth
		table.insert(lanesX, x)
		-- Balls start at the top and roll down: home faces down the ramp
		local top = pc:C(x, rise + radius, l)
		local home = CFrame.lookAt(top.Position, pc:P(x, radius, 0))
		pc:Mover({
			Name = "Ball",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * radius * 2,
			Color = pc.theme.hazard,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Attributes = { Low = true },
		}, {
			Motion = "ball",
			Home = home,
			Length = slope + 3,
			Travel = 2.6,
			Period = period,
			Phase = (lane - 1) * period / lanes,
			Radius = radius,
		}, { "Hit" })
	end
	pc:Node({
		kind = "dodge",
		from = pc:P(0, 0, 0),
		to = pc:P(0, rise, l),
		lanes = lanesX,
		cursor = pc.cursor,
		rise = rise,
		len = l,
	})
	pc:Floor(0, rise, l + 4, w, 8)
	pc:Go(0, rise, l + 6)
	if o.gem then
		pc:Gem(lanesX[1], rise * 0.6, l * 0.6)
	end
	return pc:Done(l + 8, rise)
end

-- A conveyor belt. speed < 0 runs against you.
B.conveyor = function(pc, o)
	local l, w, speed = o.len or 40, o.w or 12, o.speed or -10
	local belt = pc:Floor(
		0,
		0,
		l / 2,
		w,
		l,
		{ Name = "Belt", Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Fabric, Tags = { "Belt" } }
	)
	belt:SetAttribute("Belt", pc.cursor.LookVector * speed)
	-- Stripes so you can tell which way it runs (they don't move, the arrows say it)
	for z = 4, l - 2, 8 do
		pc:Part({
			Name = "Arrow",
			Size = Vector3.new(w - 4, 0.1, 1),
			CFrame = pc:C(0, 0.06, z),
			Color = pc.theme.accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	pc:Rails(0, 0, l, w)
	pc:Go(0, 0, l, { belt = speed })
	if o.gem then
		pc:Gem(0, 0, l * 0.75)
	end
	return pc:Done(l)
end

-- A grid of tiles that blink away and back on a timer
B.blink = function(pc, o)
	local rows, cols, period = o.rows or 4, o.cols or 3, o.period or 4
	local size = 7
	local gap = 1.5
	local w = cols * (size + gap)
	local l = rows * (size + gap) + 4
	pc:Floor(0, 0, 2, 16, 4)
	local tilesByRow = {}
	for row = 1, rows do
		tilesByRow[row] = {}
		for col = 1, cols do
			local x = -w / 2 + (col - 0.5) * (size + gap)
			local z = 4 + (row - 0.5) * (size + gap)
			local phase = ((row + col) % 3) * period / 3
			local _, spec = pc:Mover({
				Name = "BlinkTile",
				Size = Vector3.new(size, 1.5, size),
				Color = pc.theme.mover,
				Material = Enum.Material.SmoothPlastic,
			}, { Motion = "blink", Home = pc:C(x, -0.75, z), Period = period, On = period * 0.65, Phase = phase })
			table.insert(tilesByRow[row], { spec = spec, at = pc:P(x, 0, z) })
		end
	end
	for row = 1, rows do
		pc:Node({ kind = "tiles", choices = tilesByRow[row] })
	end
	pc:Floor(0, 0, l + 3, 16, 6)
	pc:Jump(0, 0, l + 3)
	if o.gem then
		pc:Gem(-w / 2 + size / 2 + gap / 2, 0, 4 + (rows - 0.5) * (size + gap))
	end
	return pc:Done(l + 6)
end

-- Tiles that drop a moment after someone steps on them (they come back later)
B.fall = function(pc, o)
	local rows, cols = o.rows or 5, o.cols or 4
	local size = o.size or 6
	local w = cols * size
	local l = rows * size + 4
	pc:Floor(0, 0, 2, 16, 4)
	local tileRows = {}
	for row = 1, rows do
		local tiles = {}
		for col = 1, cols do
			local x = -w / 2 + (col - 0.5) * size
			local z = 4 + (row - 0.5) * size
			local tile = pc:Part({
				Name = "FallTile",
				Size = Vector3.new(size - 0.3, 1.5, size - 0.3),
				CFrame = pc:C(x, -0.75, z),
				Color = (row + col) % 2 == 0 and pc.theme.floor[1] or pc.theme.floor[2],
				Tags = { "FallTile" },
			})
			table.insert(tiles, { part = tile, at = pc:P(x, 0, z) })
		end
		table.insert(tileRows, tiles)
	end
	-- Bots step from row to row onto tiles that haven't started to fall
	pc:Node({ kind = "fall", rows = tileRows, to = pc:P(0, 0, l) })
	pc:Floor(0, 0, l + 3, 16, 6)
	pc:Go(0, 0, l + 3)
	if o.gem then
		pc:Gem(w / 2 - size / 2, 0, 4 + size / 2)
	end
	return pc:Done(l + 6)
end

-- A bounce pad that throws you up to a higher ledge
B.bounce = function(pc, o)
	local rise = o.rise or 18
	pc:Floor(0, 0, 6, 16, 12)
	local speed = math.sqrt(2 * (pc.theme.gravity or workspace.Gravity) * (rise + 9))
	local pad = pc:Part({
		Name = "BouncePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 7, 7),
		CFrame = pc:C(0, 0.3, 8) * UPRIGHT,
		Color = pc.theme.accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Tags = { "Bounce" },
	})
	pad:SetAttribute("Launch", Vector3.new(0, speed, 0) + pc.cursor.LookVector * 14)
	pc:Go(0, 0, 8)
	pc:Node({ kind = "bounce", to = pc:P(0, rise, 16), speed = speed })
	pc:Floor(0, rise, 18, 16, 10)
	pc:Part({
		Name = "Wall",
		Size = Vector3.new(16, rise, 2),
		CFrame = pc:C(0, rise / 2 - 1, 12),
		Color = pc.theme.edge,
	})
	pc:Go(0, rise, 22)
	if o.gem then
		pc:Gem(0, rise + 9, 8)
	end
	return pc:Done(23, rise)
end

-- A narrow bridge with gusts of wind from the side
B.wind = function(pc, o)
	local l, w, push, period = o.len or 44, o.w or 6, o.push or 16, o.period or 4
	pc:Floor(0, 0, l / 2, w, l, { Name = "Bridge" })
	local side = o.side or 1
	local fanCount = math.max(1, math.floor(l / 14))
	for index = 1, fanCount do
		local z = (index - 0.5) * l / fanCount
		pc:Part({
			Name = "Fan",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 8, 8),
			CFrame = pc:C(-side * (w / 2 + 9), 3, z) * CFrame.Angles(0, 0, 0),
			Color = pc.theme.edge,
			Material = Enum.Material.Metal,
		})
	end
	local zone = pc:Part({
		Name = "WindZone",
		Size = Vector3.new(w + 16, 14, l),
		CFrame = pc:C(0, 6, l / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Tags = { "Wind" },
	})
	zone:SetAttribute("Push", pc.cursor.RightVector * push * side)
	zone:SetAttribute("Period", period)
	zone:SetAttribute("On", period * 0.5)
	zone:SetAttribute("Phase", pc.random:NextNumber(0, period))
	pc:Go(0, 0, l, { wind = zone })
	if o.gem then
		pc:Gem(side * (w / 2 - 1), 0, l / 2)
	end
	return pc:Done(l)
end

-- A slime slide down a slope: it carries you fast; steer round the bumpers.
-- holes = n: stretches where half the slide is missing (sides take turns), so
-- you have to steer to the other half in time. sweepers = n: low pucks that
-- slide across and knock you sideways (jump them or go round).
B.slide = function(pc, o)
	local l, drop, w = o.len or 70, o.drop or 24, o.w or 18
	local angle = math.atan2(-drop, l)
	local grade = drop / l
	local belt = (pc.cursor * CFrame.Angles(angle, 0, 0)).LookVector * (o.speed or 22)
	local function y(z)
		return -grade * z
	end
	local function slab(x, width, z0, z1)
		local length = (z1 - z0) * math.sqrt(1 + grade * grade)
		local z = (z0 + z1) / 2
		local surface = pc:Part({
			Name = "Slide",
			Size = Vector3.new(width, 2, length),
			CFrame = pc:C(x, y(z), z) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -1, 0),
			Color = Color3.fromRGB(120, 230, 120),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Tags = { "Belt" },
		})
		surface:SetAttribute("Belt", belt)
	end
	local holeLength = o.holeLength or 10
	local holes = {}
	for index = 1, o.holes or 0 do
		local z = l * index / ((o.holes or 0) + 1)
		table.insert(holes, { z0 = z - holeLength / 2, z1 = z + holeLength / 2, side = index % 2 == 0 and 1 or -1 })
	end
	local function nearHole(z, margin)
		for _, hole in ipairs(holes) do
			if z > hole.z0 - margin and z < hole.z1 + margin then
				return true
			end
		end
		return false
	end
	local z = 0
	for _, hole in ipairs(holes) do
		slab(0, w, z, hole.z0)
		-- Only the half away from the hole is left
		slab(-hole.side * w / 4, w / 2, hole.z0, hole.z1)
		z = hole.z1
	end
	slab(0, w, z, l)
	local slope = math.sqrt(l * l + drop * drop)
	for _, side in ipairs({ -1, 1 }) do
		pc:Part({
			Name = "SlideWall",
			Size = Vector3.new(1, 3, slope),
			CFrame = pc:C(side * (w / 2 + 0.5), -drop / 2 + 1, l / 2) * CFrame.Angles(angle, 0, 0),
			Color = pc.theme.edge,
		})
	end
	pc.minY = math.min(pc.minY, pc:P(0, -drop, 0).Y)
	-- Bumpers to steer round (none next to a hole)
	local bumpers = o.bumpers or 4
	for index = 1, bumpers do
		local share = index / (bumpers + 1)
		if not nearHole(l * share, 4) then
			local x = (index % 2 == 0 and 1 or -1) * (w / 4)
			pc:Part({
				Name = "Bumper",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(6, 4, 4),
				CFrame = pc:C(x, -drop * share + 2, l * share) * UPRIGHT,
				Color = pc.theme.hazard,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end
	-- Sweepers: halfway between holes (or spread out when there are none)
	local sweepers = o.sweepers or 0
	for index = 1, sweepers do
		local zs = l * (index - 0.5) / sweepers
		if nearHole(zs, 2) then
			zs += holeLength
		end
		zs = math.clamp(zs, 6, l - 6)
		pc:Mover({
			Name = "Sweeper",
			Size = Vector3.new(4, 2.4, 2.4),
			Color = pc.theme.hazard,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Attributes = { Low = true },
		}, {
			Motion = "slide",
			Home = pc:C(-(w / 2 - 2.5), y(zs) + 1.2, zs),
			Axis = Vector3.xAxis,
			Dist = w - 5,
			Period = o.sweepPeriod or 2.8,
			Phase = index * 1.3,
			Hold = 0.1,
		}, { "Hit" })
	end
	-- Bots steer to the open half before each hole
	local across = pc.cursor.RightVector
	for _, hole in ipairs(holes) do
		local x = -hole.side * w / 4
		pc:Node({ kind = "slide", to = pc:P(x, y(hole.z0 - 5), hole.z0 - 5), dodge = 1.5, across = across })
		pc:Node({ kind = "slide", to = pc:P(x, y(hole.z1 + 2), hole.z1 + 2), dodge = 0, across = across })
	end
	pc:Node({ kind = "slide", from = pc:P(0, 0, 0), to = pc:P(0, -drop, l), dodge = w / 4, across = across })
	pc:Floor(0, -drop, l + 5, w, 10)
	pc:Go(0, -drop, l + 8)
	if o.gem then
		pc:Gem(-w / 2 + 2, -drop * 0.5, l * 0.5)
	end
	return pc:Done(l + 10, -drop)
end

-- Rocking platforms that tilt back and forth
B.seesaw = function(pc, o)
	local count, period = o.count or 3, o.period or 4
	local size = 12
	local z = 4
	pc:Floor(0, 0, 2, 14, 4)
	for index = 1, count do
		z += 3
		local zCenter = z + size / 2
		local _, spec = pc:Mover({
			Name = "Seesaw",
			Size = Vector3.new(size, 1.5, size),
			Color = pc.theme.mover,
			Material = Enum.Material.SmoothPlastic,
		}, {
			Motion = "rock",
			Home = pc:C(0, -0.75, zCenter),
			Amp = math.rad(o.tilt or 14),
			Period = period,
			Phase = index * 0.9,
		})
		pc:Part({
			Name = "Pivot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(size, 1.4, 1.4),
			CFrame = pc:C(0, -2.2, zCenter),
			Color = pc.theme.edge,
			CanCollide = false,
		})
		pc:Node({
			kind = "ride",
			spec = spec,
			enter = pc:P(0, 0, z - 3),
			exit = pc:P(0, 0, zCenter + size / 2 + 3),
			rock = true,
		})
		z += size
	end
	z += 3
	pc:Floor(0, 0, z + 3, 14, 6)
	pc:Go(0, 0, z + 3)
	if o.gem then
		pc:Gem(size / 2 - 1.5, 0, 7 + size / 2)
	end
	return pc:Done(z + 6)
end

-- A wall of doors: some are fake and you can run through, the rest are solid
B.doors = function(pc, o)
	local rows, perRow = o.rows or 2, o.doors or 5
	local w = perRow * 6
	local spacing = 16
	local l = rows * spacing + 6
	pc:Floor(0, 0, l / 2, w, l)
	for row = 1, rows do
		local z = row * spacing - 4
		local fakes = {}
		local count = math.max(1, math.floor(perRow / 2))
		local pool = {}
		for index = 1, perRow do
			table.insert(pool, index)
		end
		for _ = 1, count do
			table.insert(fakes, table.remove(pool, pc.random:NextInteger(1, #pool)))
		end
		local openX = {}
		for index = 1, perRow do
			local x = -w / 2 + (index - 0.5) * 6
			local fake = table.find(fakes, index) ~= nil
			local door = pc:Part({
				Name = "Door",
				Size = Vector3.new(5.8, 9, 1.2),
				CFrame = pc:C(x, 4.5, z),
				Color = pc.theme.mover,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = not fake,
				Tags = fake and { "FakeDoor" } or nil,
			})
			pc.ctx.sign(door, "?")
			if fake then
				table.insert(openX, x)
			end
		end
		pc:Part({ Name = "DoorFrame", Size = Vector3.new(w, 2, 1.6), CFrame = pc:C(0, 10, z), Color = pc.theme.edge })
		pc:Node({
			kind = "doors",
			z = pc:P(0, 0, z),
			choices = (function()
				local list = {}
				for _, x in ipairs(openX) do
					table.insert(list, pc:P(x, 0, z + 2))
				end
				return list
			end)(),
			all = (function()
				local list = {}
				for index = 1, perRow do
					table.insert(list, pc:P(-w / 2 + (index - 0.5) * 6, 0, z - 2))
				end
				return list
			end)(),
		})
	end
	for _, side in ipairs({ -1, 1 }) do
		pc:Part({
			Name = "SideWall",
			Size = Vector3.new(1, 10, l),
			CFrame = pc:C(side * (w / 2 + 0.5), 5, l / 2),
			Color = pc.theme.edge,
			Transparency = 0.6,
		})
	end
	pc:Go(0, 0, l)
	if o.gem then
		pc:Gem(w / 2 - 3, 0, spacing + 2)
	end
	return pc:Done(l)
end

-- Laser gates that switch on and off. Touching a live one sends you back.
B.lasers = function(pc, o)
	local count, period, w = o.count or 3, o.period or 3, o.w or 14
	local spacing = 12
	local l = count * spacing + 6
	pc:Floor(0, 0, l / 2, w, l)
	for index = 1, count do
		local z = index * spacing - 3
		for _, side in ipairs({ -1, 1 }) do
			pc:Part({
				Name = "LaserPost",
				Size = Vector3.new(1.2, 10, 1.2),
				CFrame = pc:C(side * (w / 2 + 0.6), 5, z),
				Color = Color3.fromRGB(60, 60, 70),
				Material = Enum.Material.Metal,
			})
		end
		local _, spec = pc:Mover(
			{
				Name = "Laser",
				Size = Vector3.new(w, 8, 0.4),
				Color = Color3.fromRGB(255, 40, 40),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Transparency = 0.35,
			},
			{ Motion = "blink", Home = pc:C(0, 4, z), Period = period, On = period * 0.5, Phase = index * period / 3 },
			{ "Kill" }
		)
		pc:Node({ kind = "wait", spec = spec, at = pc:P(0, 0, z - 3), past = pc:P(0, 0, z + 3) })
	end
	pc:Rails(0, 0, l, w)
	pc:Go(0, 0, l)
	if o.gem then
		pc:Gem(-w / 2 + 2, 0, spacing * 1.5)
	end
	return pc:Done(l)
end

-- Big spinning discs to run across
B.discs = function(pc, o)
	local count, radius, speed = o.count or 2, o.r or 13, o.speed or 0.6
	local z = 4
	pc:Floor(0, 0, 2, 12, 4)
	for index = 1, count do
		z += 3 + radius
		local home = pc:C(0, -1, z)
		local _, spec = pc:Mover({
			Name = "SpinDisc",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, radius * 2, radius * 2),
			Color = pc.theme.mover,
			Material = Enum.Material.SmoothPlastic,
		}, { Motion = "spin", Home = home, Offset = UPRIGHT, Speed = speed * (index % 2 == 0 and -1 or 1) })
		-- Stripes on the disc so the spin is easy to see
		for stripe = 0, 1 do
			pc:Mover({
				Name = "DiscStripe",
				Size = Vector3.new(radius * 2 - 2, 0.2, 1),
				Color = pc.theme.accent,
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, {
				Motion = "spin",
				Home = home,
				Offset = CFrame.new(0, 1.05, 0) * CFrame.Angles(0, stripe * math.pi / 2, 0),
				Speed = speed * (index % 2 == 0 and -1 or 1),
			})
		end
		if o.bar then
			pc:Mover({
				Name = "DiscBar",
				Size = Vector3.new(radius * 2 - 3, 1.2, 1.2),
				Color = pc.theme.hazard,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Attributes = { Low = true },
			}, { Motion = "spin", Home = home * CFrame.new(0, 2.4, 0), Speed = -speed * 2.2 }, { "Hit" })
		end
		pc:Node({
			kind = "ride",
			spec = spec,
			enter = pc:P(0, 0, z - radius - 1),
			exit = pc:P(0, 0, z + radius + 2),
			spin = true,
		})
		z += radius
	end
	z += 3
	pc:Floor(0, 0, z + 3, 12, 6)
	pc:Go(0, 0, z + 3)
	if o.gem then
		pc:Gem(radius - 3, 0, 7 + radius)
	end
	return pc:Done(z + 6)
end

-- A climb up ledges while lava rises and drains below
B.climb = function(pc, o)
	local tiers, step, period = o.tiers or 4, o.step or 5, o.period or 10
	local z = 0
	local w = 16
	for index = 0, tiers do
		local y = index * step
		local depth = index == tiers and 10 or 7
		pc:Floor((index % 2 == 0) and -2 or 2, y, z + depth / 2, w - 4, depth, { thickness = y + 4 })
		if index > 0 then
			pc:Jump((index % 2 == 0) and -2 or 2, y, z + depth / 2)
		end
		z += depth + 1
	end
	local height = tiers * step
	local _, spec = pc:Mover({
		Name = "Lava",
		Size = Vector3.new(w + 6, 2, z + 6),
		Color = Color3.fromRGB(255, 100, 20),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.1,
	}, {
		Motion = "lava",
		Home = pc:C(0, -2, z / 2),
		Low = -1,
		High = height * 0.6,
		Period = period,
		Rise = period * 0.25,
	}, { "Kill" })
	pc:Node({ kind = "lava", spec = spec })
	pc:Go(0, height, z)
	if o.gem then
		pc:Floor(w / 2 + 4, height - step, z - 6, 5, 5, { Color = pc.theme.accent })
		pc:Gem(w / 2 + 4, height - step, z - 6)
	end
	return pc:Done(z, height)
end

-- A zipline down to a lower platform: step on the pad to grab it
B.zip = function(pc, o)
	local l, drop = o.len or 60, o.drop or 14
	pc:Floor(0, 0, 5, 14, 10)
	local from = pc:P(0, 7, 8)
	local to = pc:P(0, -drop + 4, l - 6)
	local pad = pc:Part({
		Name = "ZipPad",
		Size = Vector3.new(6, 0.3, 4),
		CFrame = pc:C(0, 0.15, 8),
		Color = pc.theme.accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Tags = { "Zip" },
	})
	pad:SetAttribute("ZipFrom", from)
	pad:SetAttribute("ZipTo", to)
	local length = (to - from).Magnitude
	pc:Part({
		Name = "ZipLine",
		Size = Vector3.new(0.3, 0.3, length),
		CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, 2, 0),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	for _, point in ipairs({ from, to }) do
		pc:Part({
			Name = "ZipPole",
			Size = Vector3.new(1, 10, 1),
			CFrame = CFrame.new(point + Vector3.new(0, -2, 0)),
			Color = pc.theme.edge,
			CanCollide = false,
		})
	end
	pc:Go(0, 0, 8)
	pc:Node({ kind = "zip", from = from, to = to })
	pc:Floor(0, -drop, l - 3, 16, 12)
	pc:Go(0, -drop, l + 2)
	if o.gem then
		pc:Gem(0, -drop + 10, l * 0.5)
	end
	return pc:Done(l + 3, -drop)
end

-- A tall climbing truss
B.truss = function(pc, o)
	local height = o.height or 16
	pc:Floor(0, 0, 4, 14, 8)
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = pc:C(0, height / 2, 9)
	truss.Color = pc.theme.edge
	truss.Parent = pc.folder
	pc:Part({
		Name = "Wall",
		Size = Vector3.new(14, height, 2),
		CFrame = pc:C(0, height / 2, 11),
		Color = pc.theme.floor[1],
	})
	pc:Go(0, 0, 7.5)
	pc:Node({ kind = "climb", to = pc:P(0, height + 0.5, 9) })
	pc:Floor(0, height, 16, 14, 10)
	pc:Go(0, height, 18)
	return pc:Done(21, height)
end

-- Pistons punch out from the walls of a bridge
B.pushers = function(pc, o)
	local count, period, w = o.count or 4, o.period or 3, o.w or 12
	local spacing = 10
	local l = count * spacing + 6
	pc:Floor(0, 0, l / 2, w, l)
	for index = 1, count do
		local z = index * spacing - 2
		local side = index % 2 == 0 and 1 or -1
		local home = pc:C(side * (w / 2 + 3), 2.5, z)
		pc:Part({
			Name = "PistonBox",
			Size = Vector3.new(6, 6, 7),
			CFrame = pc:C(side * (w / 2 + 6), 2.5, z),
			Color = pc.theme.edge,
		})
		pc:Mover({
			Name = "Pusher",
			Size = Vector3.new(6, 4.5, 6),
			Color = pc.theme.hazard,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, {
			Motion = "piston",
			Home = home,
			Axis = Vector3.new(-side, 0, 0),
			Dist = w - 3,
			Period = period,
			Phase = index * period / count,
		}, { "Hit" })
		pc:Go(0, 0, z + spacing / 2, { hazard = true })
	end
	pc:Go(0, 0, l)
	if o.gem then
		pc:Gem(0, 0, l - 4)
	end
	return pc:Done(l)
end

Kit.Builders = B

-- Builds one piece. ctx = { folder, theme, random, sign = function(part, text) }
function Kit.Build(kind, ctx, cursor, options)
	local builder = B[kind]
	if not builder then
		error("Unknown course piece: " .. tostring(kind))
	end
	local pc = newPiece(ctx, cursor)
	return builder(pc, options or {})
end

return Kit
