-- A proper royal crown, built from parts: a hollow gold band with rims, a ring
-- of pointed spikes with pearls on the tips, colored jewels round the band, a
-- red velvet cap inside and a gold orb with a cross on top.
--
-- Crown.Pieces(size, detail) lists every piece with its place relative to the
-- crown's center (the middle of the band). `size` is the band's width in
-- studs. `detail` is "full" (big crowns you look at), "statue" (full, but
-- no orb and cross, so a champion can stand in it) or "small" (worn on a
-- head, fewer parts).
-- Crown.Make(piece) turns one piece into an unparented, anchored part.
-- Crown.Build(parent, cframe, size, detail) does the lot and returns a Model.

local Crown = {}

Crown.Gold = Color3.fromRGB(255, 196, 46)
Crown.DarkGold = Color3.fromRGB(214, 146, 24)
local PEARL = Color3.fromRGB(255, 248, 230)
local VELVET = Color3.fromRGB(165, 18, 42)
local JEWELS = {
	Color3.fromRGB(235, 35, 60), -- ruby
	Color3.fromRGB(40, 120, 255), -- sapphire
	Color3.fromRGB(30, 200, 110), -- emerald
}

local TAU = math.pi * 2

-- Facing outwards at an angle round the crown: local X points away from the
-- middle, local Z runs along the band
local function around(angle, radius, y)
	return CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
end

-- A ring of short flat blocks, so the middle stays hollow
local function ring(list, name, radius, y, height, thickness, segments, color)
	local length = 2 * (radius + thickness / 2) * math.tan(math.pi / segments) + 0.02
	for index = 1, segments do
		table.insert(list, {
			name = name,
			size = Vector3.new(thickness, height, length),
			cframe = around((index - 0.5) / segments * TAU, radius, y),
			color = color,
			material = Enum.Material.Foil,
		})
	end
end

function Crown.Pieces(size, detail)
	local full = detail ~= "small"
	local s = size / 2 -- everything below is for a crown 2 studs wide
	local list = {}
	local radius = 0.9 * s
	local bandHeight = 0.7 * s
	local top = bandHeight / 2
	local segments = full and 16 or 10
	local points = full and 8 or 5

	ring(list, "CrownBand", radius, 0, bandHeight, 0.12 * s, segments, Crown.Gold)
	ring(list, "CrownRim", radius + 0.04 * s, -top + 0.08 * s, 0.17 * s, 0.22 * s, segments, Crown.DarkGold)
	if full then
		ring(list, "CrownRim", radius + 0.02 * s, top - 0.05 * s, 0.1 * s, 0.18 * s, segments, Crown.DarkGold)
	end

	-- Spikes: two wedges back to back make a triangle pointing up
	local spikeWidth = TAU * radius / points * 0.78
	local spikeHeight = (full and 0.8 or 0.7) * s
	for index = 1, points do
		local angle = (index - 1) / points * TAU
		local base = around(angle, radius, top + spikeHeight / 2)
		local half = Vector3.new(0.1 * s, spikeHeight, spikeWidth / 2)
		table.insert(list, {
			name = "CrownSpike",
			class = "WedgePart",
			size = half,
			cframe = base * CFrame.new(0, 0, spikeWidth / 4) * CFrame.Angles(0, math.pi, 0),
			color = Crown.Gold,
			material = Enum.Material.Foil,
		})
		table.insert(list, {
			name = "CrownSpike",
			class = "WedgePart",
			size = half,
			cframe = base * CFrame.new(0, 0, -spikeWidth / 4),
			color = Crown.Gold,
			material = Enum.Material.Foil,
		})
		table.insert(list, {
			name = "CrownPearl",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 0.22 * s,
			cframe = around(angle, radius, top + spikeHeight + 0.06 * s),
			color = PEARL,
			material = Enum.Material.SmoothPlastic,
		})
		table.insert(list, {
			name = "CrownJewel",
			shape = Enum.PartType.Ball,
			size = Vector3.one * (full and 0.26 or 0.3) * s,
			cframe = around(angle, radius + 0.07 * s, 0.02 * s),
			color = JEWELS[(index - 1) % #JEWELS + 1],
			material = Enum.Material.Neon,
		})
	end

	-- The velvet cap fills the band and bulges up between the spikes
	table.insert(list, {
		name = "CrownVelvet",
		size = Vector3.new(radius * 1.9, (full and 1.3 or 1.1) * s, radius * 1.9),
		cframe = CFrame.new(0, top - 0.05 * s, 0),
		color = VELVET,
		material = Enum.Material.Fabric,
		mesh = Enum.MeshType.Sphere,
	})
	local capTop = top - 0.05 * s + (full and 0.65 or 0.55) * s
	table.insert(list, {
		name = "CrownOrb",
		shape = Enum.PartType.Ball,
		size = Vector3.one * 0.3 * s,
		cframe = CFrame.new(0, capTop + 0.08 * s, 0),
		color = Crown.Gold,
		material = Enum.Material.Foil,
	})
	if detail == "statue" then
		table.remove(list) -- no orb: the champion stands there
	elseif full then
		table.insert(list, {
			name = "CrownCross",
			size = Vector3.new(0.09, 0.4, 0.09) * s,
			cframe = CFrame.new(0, capTop + 0.4 * s, 0),
			color = Crown.Gold,
			material = Enum.Material.Foil,
		})
		table.insert(list, {
			name = "CrownCross",
			size = Vector3.new(0.26, 0.09, 0.09) * s,
			cframe = CFrame.new(0, capTop + 0.45 * s, 0),
			color = Crown.Gold,
			material = Enum.Material.Foil,
		})
	end
	return list
end

function Crown.Make(piece)
	local part = Instance.new(piece.class or "Part")
	if piece.shape then
		part.Shape = piece.shape
	end
	part.Name = piece.name
	part.Size = piece.size
	part.Color = piece.color
	part.Material = piece.material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if piece.mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = piece.mesh
		mesh.Parent = part
	end
	return part
end

-- Height of the velvet cap's top above the crown's center
function Crown.CapTop(size, detail)
	local s = size / 2
	return 0.3 * s + (detail == "small" and 0.55 or 0.65) * s
end

function Crown.Build(parent, cframe, size, detail)
	local model = Instance.new("Model")
	model.Name = "Crown"
	for _, piece in ipairs(Crown.Pieces(size, detail)) do
		local part = Crown.Make(piece)
		part.CFrame = cframe * piece.cframe
		part.Parent = model
	end
	model.Parent = parent
	return model
end

return Crown
