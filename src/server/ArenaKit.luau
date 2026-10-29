-- Small building helpers shared by the tournament arenas (survival, fight,
-- objective and team rounds).

local CollectionService = game:GetService("CollectionService")

local ArenaKit = {}

ArenaKit.ROOT_HEIGHT = 3 -- a runner's root sits this far above the floor
ArenaKit.UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder to stand on its end

function ArenaKit.flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- A part from a table of properties (plus Tags, Attributes and Parent)
function ArenaKit.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
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
	p.Parent = props.Parent
	return p
end

-- A round floor (a cylinder on its end) with its top at height y
function ArenaKit.disc(arena, radius, y, color, material, thickness)
	thickness = thickness or 3
	return ArenaKit.part({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = arena.origin * CFrame.new(0, y - thickness / 2, 0) * ArenaKit.UPRIGHT,
		Color = color,
		Material = material,
		Parent = arena.folder,
	})
end

function ArenaKit.rootOf(entrant)
	if entrant.bot then
		return entrant.bot.root
	end
	local character = entrant.player and entrant.player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Spots in a ring, facing the middle
function ArenaKit.ring(center, radius, count)
	local list = {}
	for index = 1, count do
		local angle = (index - 0.5) / count * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		table.insert(list, CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)))
	end
	return list
end

-- A random point on a round floor, at least margin in from the edge
function ArenaKit.randomOnDisc(random, center, radius, margin)
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(random:NextNumber()) * math.max(0, radius - (margin or 4))
	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

-- The stands: a glass box above the arena where runners who are out watch.
-- Sets arena.stands (where to put them, looking down at the middle).
function ArenaKit.stands(arena)
	local origin = arena.origin
	local stands = origin * CFrame.new(0, 110, 70)
	ArenaKit.part({
		Name = "Stands",
		Size = Vector3.new(40, 1, 16),
		CFrame = stands,
		Color = Color3.fromRGB(240, 240, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Parent = arena.folder,
	})
	for _, offset in ipairs({ CFrame.new(0, 4, -8), CFrame.new(0, 4, 8), CFrame.new(-20, 4, 0), CFrame.new(20, 4, 0) }) do
		ArenaKit.part({
			Name = "StandsWall",
			Size = (offset.Position.X == 0) and Vector3.new(40, 8, 1) or Vector3.new(1, 8, 16),
			CFrame = stands * offset,
			Transparency = 1,
			Parent = arena.folder,
		})
	end
	arena.stands = CFrame.lookAt((stands * CFrame.new(0, 4, 0)).Position, origin.Position)
end

-- A random spot in the stands
function ArenaKit.standsSpot(arena, random)
	return arena.stands * CFrame.new(random:NextNumber(-14, 14), 0, random:NextNumber(-4, 4))
end

-- The closest runner in list to position (skipping skip), and how far
function ArenaKit.nearest(position, list, skip)
	local best, bestDistance = nil, math.huge
	for _, entrant in ipairs(list) do
		if entrant ~= skip then
			local root = ArenaKit.rootOf(entrant)
			if root then
				local distance = ArenaKit.flat(root.Position - position).Magnitude
				if distance < bestDistance then
					best, bestDistance = entrant, distance
				end
			end
		end
	end
	return best, bestDistance
end

return ArenaKit
