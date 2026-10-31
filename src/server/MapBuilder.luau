-- Builds Crown Plaza (the hub) when the place has no folder called "Map" in
-- Workspace, so the game is playable the moment you press Play. Courses and
-- tournament rounds are built separately, when someone plays them.
-- To use your own scenery later, the game only cares about parts with these attributes:
--   WorldGate = "candy"     walking into it opens that world's course list
--   DailyGate = true        walking into it starts the Daily Challenge
--   TournamentPad = 1       a pad that queues players for tournament 1
--   Station = "CrownsBoard" / "StarsBoard" / "HowTo"
--   GuideTarget = "FirstGate" / "Pads"   where the first-time guide points
--   LobbyFloor = true       the plaza (players who fall off it come back)

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Worlds = require(Shared.Worlds)

local MapBuilder = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local PLAZA_RADIUS = 100

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

local function disc(folder, name, position, radius, thickness, color, material)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(position - Vector3.new(0, thickness / 2, 0)) * UPRIGHT,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = folder,
	})
end

local function sign(parentPart, text, face, color, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = parentPart
	return label
end

local function bothSides(parentPart, text, color, pixelsPerStud)
	sign(parentPart, text, Enum.NormalId.Front, color, pixelsPerStud)
	return sign(parentPart, text, Enum.NormalId.Back, color, pixelsPerStud)
end

local function cloud(folder, position, size, random)
	for _ = 1, 4 do
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * random:NextNumber(0.6, 1),
			Position = position + Vector3.new(
				random:NextNumber(-size, size),
				random:NextNumber(-size / 4, size / 4),
				random:NextNumber(-size / 2, size / 2)
			),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = folder,
		})
	end
end

local function lamp(folder, position, color)
	part({
		Name = "LampPost",
		Size = Vector3.new(0.6, 9, 0.6),
		Position = position + Vector3.new(0, 4.5, 0),
		Color = Color3.fromRGB(60, 60, 75),
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	local bulb = part({
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Position = position + Vector3.new(0, 9.4, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.5
	light.Color = color
	light.Parent = bulb
end

local function board(folder, name, cframe, size, station)
	local p = part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = Color3.fromRGB(30, 40, 60),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	p:SetAttribute("Station", station)
	local postHeight = cframe.Position.Y - size.Y / 2 + 0.5
	for _, x in ipairs({ -size.X / 2 + 1, size.X / 2 - 1 }) do
		local at = (cframe * CFrame.new(x, 0, 0)).Position
		part({
			Name = "BoardPost",
			Size = Vector3.new(0.8, postHeight, 0.8),
			Position = Vector3.new(at.X, postHeight / 2, at.Z),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal,
			Parent = folder,
		})
	end
	return p
end

-- A floating island of a world's colours, seen through its gate
local function worldIsland(folder, world, position, random)
	disc(folder, world.id .. "IslandTop", position, 14, 3, world.floor[1], world.material)
	for index, shrink in ipairs({ 0.85, 0.6, 0.35 }) do
		disc(
			folder,
			world.id .. "IslandRock" .. index,
			position - Vector3.new(0, 3 + (index - 1) * 5, 0),
			14 * shrink,
			5,
			world.edge:Lerp(Color3.new(0, 0, 0), 0.25 + index * 0.1),
			Enum.Material.Rock
		)
	end
	-- A few blocks of the world's obstacles for a taste
	for index = 1, 3 do
		local angle = random:NextNumber(0, math.pi * 2)
		local at = position + Vector3.new(math.cos(angle) * 7, 2 + index, math.sin(angle) * 7)
		part({
			Name = "Deco",
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(at) * CFrame.Angles(0, angle, 0.3),
			Color = index == 1 and world.hazard or (index == 2 and world.mover or world.accent),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = folder,
		})
	end
end

-- A world gate: an arch with a glowing doorway, the world's name and the stars it needs
local function worldGate(folder, world, cframe)
	local width, height = 14, 16
	local color = world.edge
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "GatePillar",
			Size = Vector3.new(2.5, height, 2.5),
			CFrame = cframe * CFrame.new(side * (width / 2 + 1.25), height / 2, 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		part({
			Name = "GateCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.4, 3.4, 3.4),
			CFrame = cframe * CFrame.new(side * (width / 2 + 1.25), height + 2, 0),
			Color = world.accent,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end
	local top = part({
		Name = "GateTop",
		Size = Vector3.new(width + 5, 4, 3),
		CFrame = cframe * CFrame.new(0, height + 2, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	sign(top, world.name, Enum.NormalId.Back, Color3.new(1, 1, 1), 30)
	sign(top, world.name, Enum.NormalId.Front, Color3.new(1, 1, 1), 30)
	local portal = part({
		Name = "Portal",
		Size = Vector3.new(width, height, 1),
		CFrame = cframe * CFrame.new(0, height / 2, 0),
		Color = world.mover,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		Parent = folder,
	})
	portal:SetAttribute("WorldGate", world.id)
	local starSign = part({
		Name = "StarSign",
		Size = Vector3.new(10, 2.6, 0.4),
		CFrame = cframe * CFrame.new(0, 2, 1.6),
		Color = Color3.fromRGB(30, 35, 55),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	local starText = world.stars == 0 and "Open to all" or string.format("Needs %d stars", world.stars)
	sign(starSign, starText, Enum.NormalId.Back, Color3.fromRGB(255, 230, 120), 30)
	-- A path tile in front of the gate
	part({
		Name = "GateMat",
		Size = Vector3.new(width, 0.2, 10),
		CFrame = cframe * CFrame.new(0, 0.1, 7),
		Color = world.floor[1],
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = folder,
	})
	return portal
end

-- A tournament pad: queue here for a knockout tournament
local function tournamentPad(folder, slot, position, color)
	local pad =
		disc(folder, "TournamentPad" .. slot, position + Vector3.new(0, 0.4, 0), 9, 0.4, color, Enum.Material.Neon)
	pad.CanCollide = false
	pad:SetAttribute("TournamentPad", slot)
	disc(
		folder,
		"PadRim" .. slot,
		position + Vector3.new(0, 0.3, 0),
		10,
		0.3,
		Color3.fromRGB(40, 45, 60),
		Enum.Material.Metal
	)
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2
		part({
			Name = "PadLight",
			Size = Vector3.new(0.6, 6, 0.6),
			Position = position + Vector3.new(math.cos(angle) * 9.5, 3, math.sin(angle) * 9.5),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
			CanQuery = false,
			Parent = folder,
		})
	end
	local look = CFrame.lookAt(position, Vector3.new(0, 0, 0))
	local signPart = part({
		Name = "PadSign" .. slot,
		Size = Vector3.new(16, 6, 0.6),
		CFrame = look * CFrame.new(0, 12, 11),
		Color = Color3.fromRGB(25, 30, 45),
		Parent = folder,
	})
	signPart:SetAttribute("PadSign", slot)
	local label = sign(signPart, "TOURNAMENT", Enum.NormalId.Front, color, 30)
	label.Name = "Status"
	for _, x in ipairs({ -7.4, 7.4 }) do
		part({
			Name = "SignPost",
			Size = Vector3.new(0.6, 10, 0.6),
			CFrame = look * CFrame.new(x, 5, 11),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal,
			Parent = folder,
		})
	end
	return pad
end

function MapBuilder.Build()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.GlobalShadows = true

	if Workspace:FindFirstChild("Map") then
		return -- the creator made their own map
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = map
	local random = Random.new(11)

	-- The plaza island: a big round floor with coloured rings, rock underneath
	local top = disc(
		scenery,
		"PlazaTop",
		Vector3.new(0, 0, 0),
		PLAZA_RADIUS,
		3,
		Color3.fromRGB(245, 240, 230),
		Enum.Material.Concrete
	)
	top:SetAttribute("LobbyFloor", true)
	disc(
		scenery,
		"PlazaRing",
		Vector3.new(0, 0.05, 0),
		46,
		0.1,
		Color3.fromRGB(255, 205, 90),
		Enum.Material.SmoothPlastic
	).CanCollide =
		false
	disc(scenery, "PlazaInner", Vector3.new(0, 0.1, 0), 40, 0.1, Color3.fromRGB(250, 245, 235), Enum.Material.Concrete).CanCollide =
		false
	for index, shrink in ipairs({ 0.9, 0.72, 0.5, 0.28 }) do
		disc(
			scenery,
			"PlazaRock" .. index,
			Vector3.new(0, -3 - (index - 1) * 7, 0),
			PLAZA_RADIUS * shrink,
			7,
			Color3.fromRGB(150, 135, 125):Lerp(Color3.fromRGB(90, 80, 75), index / 4),
			Enum.Material.Rock
		)
	end
	for index = 0, 35 do
		local angle = index / 36 * math.pi * 2
		local at = Vector3.new(math.cos(angle) * (PLAZA_RADIUS - 1), 4, math.sin(angle) * (PLAZA_RADIUS - 1))
		part({
			Name = "EdgeWall",
			Size = Vector3.new(1, 8, 19),
			CFrame = CFrame.lookAt(at, Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Transparency = 1,
			Parent = map,
		})
		if index % 2 == 0 then
			part({
				Name = "Fence",
				Size = Vector3.new(0.6, 2.5, 17.5),
				CFrame = CFrame.lookAt(Vector3.new(at.X, 1.25, at.Z), Vector3.new(0, 1.25, 0))
					* CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.SmoothPlastic,
				Parent = scenery,
			})
		end
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlazaSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 62), Vector3.new(0, 0.5, 0))
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Color = Color3.fromRGB(255, 200, 60)
	spawnLocation.Duration = 0
	spawnLocation.Parent = map

	-- The crown fountain in the middle
	disc(scenery, "FountainRim", Vector3.new(0, 2, 0), 12, 2, Color3.fromRGB(230, 225, 215), Enum.Material.Marble)
	disc(scenery, "FountainWater", Vector3.new(0, 2.1, 0), 10.5, 0.4, Color3.fromRGB(90, 190, 255), Enum.Material.Glass).Transparency =
		0.3
	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 4, 4),
		CFrame = CFrame.new(0, 4, 0) * UPRIGHT,
		Color = Color3.fromRGB(240, 235, 225),
		Material = Enum.Material.Marble,
		Parent = scenery,
	})
	local crownBase = part({
		Name = "CrownBand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 9, 9),
		CFrame = CFrame.new(0, 10, 0) * UPRIGHT,
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Parent = scenery,
	})
	for index = 0, 4 do
		local angle = index / 5 * math.pi * 2
		part({
			Name = "CrownPoint",
			Size = Vector3.new(2, 4, 2),
			CFrame = CFrame.new(math.cos(angle) * 3.6, 13, math.sin(angle) * 3.6)
				* CFrame.Angles(0, -angle, 0)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = Color3.fromRGB(255, 200, 40),
			Material = Enum.Material.Foil,
			Parent = scenery,
		})
		part({
			Name = "CrownJewel",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = Vector3.new(math.cos(angle) * 4.5, 10, math.sin(angle) * 4.5),
			Color = Color3.fromRGB(255, 60, 90),
			Material = Enum.Material.Neon,
			Parent = scenery,
		})
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 220, 120)
	glow.Range = 24
	glow.Parent = crownBase

	-- World gates in an arc to the north, each facing the fountain
	for index, world in ipairs(Worlds.List) do
		local angle = math.rad(-150 + (index - 1) * 30)
		local at = Vector3.new(math.cos(angle) * 74, 0, math.sin(angle) * 74)
		local cframe = CFrame.lookAt(at, Vector3.new(0, 0, 0)) * CFrame.Angles(0, math.pi, 0)
		local portal = worldGate(map, world, cframe)
		if index == 1 then
			portal:SetAttribute("GuideTarget", "FirstGate")
		end
		worldIsland(scenery, world, at * 1.45 + Vector3.new(0, 18 + index * 3, 0), random)
	end

	-- Tournament pads to the west
	tournamentPad(map, 1, Vector3.new(-62, 0, 28), Color3.fromRGB(255, 180, 40))
	tournamentPad(map, 2, Vector3.new(-48, 0, 56), Color3.fromRGB(255, 90, 160))
	local padsTarget = part({
		Name = "PadsTarget",
		Size = Vector3.new(2, 1, 2),
		Position = Vector3.new(-55, 1, 42),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = map,
	})
	padsTarget:SetAttribute("GuideTarget", "Pads")

	-- The Daily Challenge gate to the east
	local dailyCFrame = CFrame.lookAt(Vector3.new(66, 0, 34), Vector3.new(0, 0, 0)) * CFrame.Angles(0, math.pi, 0)
	local daily = worldGate(map, {
		id = "daily",
		name = "Daily Challenge",
		stars = 0,
		edge = Color3.fromRGB(70, 200, 255),
		accent = Color3.fromRGB(255, 255, 255),
		mover = Color3.fromRGB(110, 230, 255),
		floor = { Color3.fromRGB(200, 240, 255) },
	}, dailyCFrame)
	daily:SetAttribute("WorldGate", nil)
	daily:SetAttribute("DailyGate", true)

	-- Leaderboards and the how-to-play board, near the spawn
	board(
		map,
		"CrownsBoard",
		CFrame.lookAt(Vector3.new(40, 11, 72), Vector3.new(0, 11, 30)),
		Vector3.new(22, 16, 1),
		"CrownsBoard"
	)
	board(
		map,
		"StarsBoard",
		CFrame.lookAt(Vector3.new(-30, 11, 80), Vector3.new(0, 11, 30)),
		Vector3.new(22, 16, 1),
		"StarsBoard"
	)
	local howTo = board(
		map,
		"HowToBoard",
		CFrame.lookAt(Vector3.new(16, 8, 84), Vector3.new(0, 8, 40)),
		Vector3.new(18, 11, 1),
		"HowTo"
	)
	local howToText =
		"HOW TO PLAY\n\nAdventure: walk into a world gate\nTournament: step on a glowing pad\n\nRun, jump (Space) and dash (Q)\nGet stars and find hidden gems\nWin tournaments for crowns!"
	bothSides(howTo, howToText, Color3.fromRGB(255, 240, 200), 30)

	local title = part({
		Name = "TitleSign",
		Size = Vector3.new(56, 11, 1.5),
		Position = Vector3.new(0, 44, -96),
		Color = Color3.fromRGB(255, 120, 60),
		Material = Enum.Material.SmoothPlastic,
		Parent = scenery,
	})
	bothSides(title, string.upper(Config.GameName), Color3.new(1, 1, 1))
	for _, x in ipairs({ -26, 26 }) do
		part({
			Name = "TitlePost",
			Size = Vector3.new(1.4, 44, 1.4),
			Position = Vector3.new(x, 22, -96),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal,
			Parent = scenery,
		})
	end

	-- Bunting, lamps and clouds
	local colors = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(90, 200, 255),
		Color3.fromRGB(140, 230, 120),
		Color3.fromRGB(200, 120, 255),
	}
	for index = 0, 11 do
		local angle = index / 12 * math.pi * 2
		local at = Vector3.new(math.cos(angle) * 44, 0, math.sin(angle) * 44)
		lamp(scenery, at, colors[(index % #colors) + 1])
	end
	for _ = 1, 14 do
		local angle = random:NextNumber(0, math.pi * 2)
		cloud(
			scenery,
			Vector3.new(
				math.cos(angle) * random:NextNumber(140, 260),
				random:NextNumber(-70, -20),
				math.sin(angle) * random:NextNumber(140, 260)
			),
			random:NextNumber(14, 26),
			random
		)
	end

	map.Parent = Workspace
end

return MapBuilder
