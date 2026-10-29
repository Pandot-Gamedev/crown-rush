-- Turns a course (a list of kit pieces, see Shared/Courses) into parts in the
-- world, and works out everything the game needs to run it: where you start,
-- the checkpoints, the finish, the gems, how low you can fall in each section,
-- the path bots follow and a par time.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Worlds = require(Shared.Worlds)
local Motion = require(Shared.Motion)

local Kit = require(script.Parent.Kit)

local CourseBuilder = {}

local function sign(parentPart, text)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		gui.Parent = parentPart
	end
end
CourseBuilder.Sign = sign

-- A spinning gem. Its index (1 to 3) lets each player's screen dim the gems
-- they already found.
local function makeGem(folder, courseId, index, position)
	local gem = Instance.new("Part")
	gem.Name = "Gem" .. index
	gem.Size = Vector3.new(1.6, 2.4, 1.6)
	gem.Color = Color3.fromRGB(80, 230, 255)
	gem.Material = Enum.Material.Neon
	gem.Anchored = true
	gem.CanCollide = false
	gem.CanQuery = false
	gem.CanTouch = false
	gem:SetAttribute("Motion", "spin")
	gem:SetAttribute("Home", CFrame.new(position))
	gem:SetAttribute("Offset", CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(45), 0, 0))
	gem:SetAttribute("Speed", 2)
	gem:SetAttribute("GemIndex", index)
	gem:SetAttribute("CourseId", courseId)
	gem.CFrame = CFrame.new(position)
	CollectionService:AddTag(gem, Motion.Tag)
	CollectionService:AddTag(gem, "Gem")
	local light = Instance.new("PointLight")
	light.Color = gem.Color
	light.Range = 10
	light.Parent = gem
	gem.Parent = folder
	return gem
end

-- Rough time for a good run along the bot path (for par)
local function estimateTime(nodes, start)
	local seconds = 0
	local last = start
	for _, node in ipairs(nodes) do
		-- (door choices are points; blinking tile choices are { spec, at })
		local choice = node.choices and node.choices[1]
		if type(choice) == "table" then
			choice = choice.at
		end
		local target = node.to or node.exit or node.past or choice or node.z
		if typeof(target) == "Vector3" and last then
			seconds += (target - last).Magnitude / Config.WalkSpeed
			last = target
		end
		if node.kind == "ride" then
			seconds += node.spec.period * 0.6
		elseif node.kind == "wait" then
			seconds += node.spec.period * 0.3
		elseif node.kind == "tiles" then
			seconds += 0.6
		elseif node.kind == "lava" or node.kind == "zip" then
			seconds += 1
		end
	end
	return seconds
end

-- Builds a course with its start at origin (a CFrame facing the way the course
-- runs). theme = a world id, for colours. Returns the course object.
function CourseBuilder.Build(courseData, origin, parent, themeId)
	local folder = Instance.new("Model")
	folder.Name = "Course_" .. courseData.id
	local theme = Worlds.ById[themeId or courseData.world] or Worlds.List[1]
	local ctx = {
		folder = folder,
		theme = theme,
		random = Random.new(courseData.seed or #courseData.id * 7919 + string.byte(courseData.id, -1)),
		sign = sign,
	}

	local course = {
		id = courseData.id,
		data = courseData,
		folder = folder,
		theme = theme,
		origin = origin,
		start = nil,
		checkpoints = {}, -- [1..n] = { spawn, center, size, killY }
		finish = nil,
		gems = {}, -- [1..3] = Vector3
		gemParts = {},
		nodes = {},
		sections = {}, -- [0..n] = lowest floor height in that section
		fallTiles = {},
		fakeDoors = {},
		windZones = {},
	}

	local cursor = origin
	local section = 0
	course.sections[0] = origin.Position.Y
	for index, entry in ipairs(courseData.pieces) do
		local kind = entry[1]
		local result = Kit.Build(kind, ctx, cursor, entry)
		if result.start then
			course.start = result.start
		end
		if result.checkpoint then
			section += 1
			course.sections[section] = result.minY
			table.insert(course.checkpoints, result.checkpoint)
			table.insert(course.nodes, { kind = "checkpoint", index = section })
		else
			course.sections[section] = math.min(course.sections[section], result.minY)
		end
		if result.finish then
			course.finish = result.finish
		end
		if result.gemSpot and #course.gems < 3 then
			table.insert(course.gems, result.gemSpot)
		end
		for _, node in ipairs(result.nodes) do
			node.piece = index
			table.insert(course.nodes, node)
		end
		cursor = result.cursor
	end
	course.endCursor = cursor

	for index, checkpoint in ipairs(course.checkpoints) do
		checkpoint.killY = course.sections[index] - Config.FallBelow
	end
	course.startKillY = course.sections[0] - Config.FallBelow
	for index, position in ipairs(course.gems) do
		course.gemParts[index] = makeGem(folder, courseData.id, index, position)
	end

	for _, item in ipairs(folder:GetDescendants()) do
		if CollectionService:HasTag(item, "FallTile") then
			table.insert(course.fallTiles, { part = item, home = item.CFrame, state = "up" })
		elseif CollectionService:HasTag(item, "FakeDoor") then
			table.insert(course.fakeDoors, { part = item, home = item.CFrame, broken = false })
		end
	end

	local estimate = estimateTime(course.nodes, course.start and course.start.spawn.Position)
	course.par = courseData.par or math.max(10, math.floor(estimate * 1.3 + 4))

	folder:SetAttribute("CourseId", courseData.id)
	folder:SetAttribute("World", theme.id)
	folder.Parent = parent
	return course
end

-- The lowest a player in a section can be before it counts as a fall
function CourseBuilder.KillY(course, checkpointIndex)
	if checkpointIndex <= 0 then
		return course.startKillY
	end
	local checkpoint = course.checkpoints[checkpointIndex]
	return checkpoint and checkpoint.killY or course.startKillY
end

-- True if a world position is inside a box (cframe + size)
function CourseBuilder.InBox(position, cframe, size)
	local offset = cframe:PointToObjectSpace(position)
	return math.abs(offset.X) <= size.X / 2 and math.abs(offset.Y) <= size.Y / 2 and math.abs(offset.Z) <= size.Z / 2
end

return CourseBuilder
