-- Builds every Adventure course outside Roblox and checks it can be beaten:
-- from the start and from every checkpoint you must be able to reach the
-- finish, and every gem must be reachable. It works out where you can stand
-- (the tops of floors, moving platforms at several moments, bounce pads,
-- ziplines, trusses) and which of those spots a jump can link.
--
-- Usage (needs Lune):  lune run tools/check/courses.luau [courseId]
--
-- "needs a dive" means the course can only be beaten with Q-dives somewhere:
-- fine in later worlds, not in the first ones.

local process = require("@lune/process")
local Mock = require("./mock")

local ROOT = process.cwd
Mock.Mount(ROOT)
local game = Mock.game
local Shared = game:GetService("ReplicatedStorage").Shared
local Server = game:GetService("ServerScriptService").Server
local CollectionService = game:GetService("CollectionService")

local Config = Mock.require(Shared.Config)
local Courses = Mock.require(Shared.Courses)
local Worlds = Mock.require(Shared.Worlds)
local Motion = Mock.require(Shared.Motion)
local CourseBuilder = Mock.require(Server.CourseBuilder)

local CFrame = require("@lune/roblox").CFrame
local Vector3 = require("@lune/roblox").Vector3
local Enum = require("@lune/roblox").Enum

local SPACING = 2.5
local CELL = 12
local WALK = Config.WalkSpeed
local DIVE_EXTRA = (Config.DiveSpeed - Config.WalkSpeed) * 0.32 * 0.85
local MAX_SLOPE = math.cos(math.rad(50))
local SAMPLES = 8 -- moments sampled for each moving platform

------------------------------------------------------------------ Standing spots
local function upFace(cframe, size, shape)
	-- Which local axis points most up, and the face's half extents on the other two
	local axes = { cframe.RightVector, cframe.UpVector, -cframe.LookVector }
	local best, bestDot = 1, 0
	for index, axis in ipairs(axes) do
		if math.abs(axis.Y) > math.abs(bestDot) then
			best, bestDot = index, axis.Y
		end
	end
	local sizes = { size.X, size.Y, size.Z }
	return best, bestDot, sizes
end

local function facePoints(cframe, size, shape, out, extra)
	local axisIndex, dot, sizes = upFace(cframe, size, shape)
	if math.abs(dot) < MAX_SLOPE then
		return
	end
	local sign = dot > 0 and 1 or -1
	local others = {}
	for index = 1, 3 do
		if index ~= axisIndex then
			table.insert(others, index)
		end
	end
	local function localPoint(u, v)
		local values = { 0, 0, 0 }
		values[axisIndex] = sign * sizes[axisIndex] / 2
		values[others[1]] = u
		values[others[2]] = v
		-- local z is backwards in CFrame space
		return cframe:PointToWorldSpace(Vector3.new(values[1], values[2], values[3]))
	end
	local half1 = math.max(0, sizes[others[1]] / 2 - 0.6)
	local half2 = math.max(0, sizes[others[2]] / 2 - 0.6)
	local round = shape == Enum.PartType.Cylinder and axisIndex == 1
	local n1 = math.max(1, math.floor(half1 * 2 / SPACING) + 1)
	local n2 = math.max(1, math.floor(half2 * 2 / SPACING) + 1)
	for i = 0, n1 - 1 do
		local u = n1 == 1 and 0 or -half1 + i * (half1 * 2) / (n1 - 1)
		for j = 0, n2 - 1 do
			local v = n2 == 1 and 0 or -half2 + j * (half2 * 2) / (n2 - 1)
			if not round or (u * u + v * v) <= half1 * half1 + 0.01 then
				local point = { pos = localPoint(u, v) }
				for key, value in pairs(extra or {}) do
					point[key] = value
				end
				table.insert(out, point)
			end
		end
	end
end

local SKIP_TAGS = { "Hit", "Kill", "Gem", "FakeDoor", "Wind" }

local function standingSpots(course)
	local points = {}
	for _, part in ipairs(course.folder:GetDescendants()) do
		if
			part:IsA("BasePart")
			and (part.CanCollide or CollectionService:HasTag(part, "Bounce") or CollectionService:HasTag(part, "Zip"))
		then
			local skip = false
			for _, tag in ipairs(SKIP_TAGS) do
				if CollectionService:HasTag(part, tag) then
					skip = true
				end
			end
			if not skip then
				local extra = { part = part }
				if CollectionService:HasTag(part, "Bounce") then
					extra.launch = part:GetAttribute("Launch")
				end
				if CollectionService:HasTag(part, "Zip") then
					extra.zipTo = part:GetAttribute("ZipTo")
				end
				if part.ClassName == "TrussPart" then
					extra.truss = true
				end
				if CollectionService:HasTag(part, Motion.Tag) then
					local spec = Motion.Read(part)
					local period = spec.period
					if spec.kind == "spin" then
						period = math.pi * 2 / math.max(0.05, math.abs(spec.speed))
					end
					for k = 0, SAMPLES - 1 do
						local cframe, state = Motion.At(spec, period * k / SAMPLES)
						if state ~= "gone" then
							extra.moving = true
							facePoints(cframe, part.Size, part.Shape, points, extra)
						end
					end
				else
					facePoints(part.CFrame, part.Size, part.Shape, points, extra)
				end
			end
		end
	end
	return points
end

------------------------------------------------------------------ Jumps
-- Can you get from spot a to spot b? Returns "walk", "jump", "dive" or nil.
local function link(a, b, gravity)
	local delta = b.pos - a.pos
	local dy = delta.Y
	local dh = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if a.part == b.part and not a.moving and dh <= SPACING * 1.5 + 0.1 and math.abs(dy) < 3 then
		return "walk"
	end
	if dh <= 3.7 and math.abs(dy) <= 1.2 then
		return "walk"
	end
	local up, speed = math.sqrt(2 * gravity * (Config.JumpHeight - 0.4)), WALK
	if a.launch then
		up = a.launch.Y
		speed = WALK + Vector3.new(a.launch.X, 0, a.launch.Z).Magnitude
	elseif a.zipEnd then
		up, speed = 10 + math.sqrt(2 * gravity * (Config.JumpHeight - 0.4)), WALK + 15
	end
	local peak = up * up / (2 * gravity)
	if dy > peak * 0.95 then
		return nil
	end
	local fall = math.sqrt(math.max(0, up * up - 2 * gravity * dy))
	local t = (up + fall) / gravity
	local reach = speed * t * 0.88
	if dh <= reach then
		return "jump"
	elseif dh <= reach + DIVE_EXTRA then
		return "dive"
	end
	return nil
end

------------------------------------------------------------------ Search
local function grid(points)
	local cells = {}
	for index, point in ipairs(points) do
		local key = math.floor(point.pos.X / CELL) .. "," .. math.floor(point.pos.Z / CELL)
		cells[key] = cells[key] or {}
		table.insert(cells[key], index)
	end
	return cells
end

local function near(cells, position, radius)
	local out = {}
	local cx, cz = math.floor(position.X / CELL), math.floor(position.Z / CELL)
	local r = math.ceil(radius / CELL)
	for x = cx - r, cx + r do
		for z = cz - r, cz + r do
			for _, index in ipairs(cells[x .. "," .. z] or {}) do
				table.insert(out, index)
			end
		end
	end
	return out
end

-- Everything reachable from the given start spots. allowDive: count dives.
local function search(points, cells, starts, gravity, allowDive, trusses)
	local seen = {}
	local queue = {}
	for _, index in ipairs(starts) do
		seen[index] = true
		table.insert(queue, index)
	end
	local head = 1
	while head <= #queue do
		local a = points[queue[head]]
		head += 1
		local radius = a.launch and 80 or 40
		for _, index in ipairs(near(cells, a.pos, radius)) do
			if not seen[index] then
				local kind = link(a, points[index], gravity)
				if kind == "walk" or kind == "jump" or (kind == "dive" and allowDive) then
					seen[index] = true
					table.insert(queue, index)
				end
			end
		end
		-- Ziplines carry you to their far end
		if a.zipTo then
			for _, index in ipairs(near(cells, a.zipTo, 12)) do
				local b = points[index]
				if not seen[index] and b.zipEnd then
					seen[index] = true
					table.insert(queue, index)
				end
			end
		end
		-- Trusses: climb from beside them to their top
		for _, truss in ipairs(trusses) do
			local offset = truss.CFrame:PointToObjectSpace(a.pos)
			if
				math.abs(offset.X) < truss.Size.X / 2 + 3
				and math.abs(offset.Z) < truss.Size.Z / 2 + 3
				and a.pos.Y < truss.Position.Y + truss.Size.Y / 2
			then
				for _, index in ipairs(near(cells, truss.Position, math.max(truss.Size.X, truss.Size.Z) + 4)) do
					if not seen[index] and points[index].part == truss then
						seen[index] = true
						table.insert(queue, index)
					end
				end
			end
		end
	end
	return seen
end

local function spotsNear(points, position, radius, below)
	local out = {}
	for index, point in ipairs(points) do
		local delta = point.pos - position
		if Vector3.new(delta.X, 0, delta.Z).Magnitude <= radius and delta.Y <= 1 and delta.Y >= -(below or 6) then
			table.insert(out, index)
		end
	end
	return out
end

local function anySeen(seen, list)
	for _, index in ipairs(list) do
		if seen[index] then
			return true
		end
	end
	return false
end

------------------------------------------------------------------ Check one course
local function check(courseData)
	local origin = CFrame.new(0, 500, 0)
	local course = CourseBuilder.Build(courseData, origin, game:GetService("Workspace"), courseData.world)
	local world = Worlds.ById[courseData.world]
	local gravity = world.gravity or 196.2
	local points = standingSpots(course)

	-- Zipline ends are spots in the air you drop from
	for _, point in ipairs(table.clone(points)) do
		if point.zipTo then
			table.insert(points, { pos = point.zipTo, zipEnd = true })
		end
	end
	local trusses = {}
	for _, part in ipairs(course.folder:GetDescendants()) do
		if part.ClassName == "TrussPart" then
			table.insert(trusses, part)
		end
	end
	local cells = grid(points)
	if process.env.DEBUG then
		local bouncy = 0
		for _, point in ipairs(points) do
			if point.launch then
				bouncy += 1
			end
		end
		print("  spots", #points, "on bounce pads", bouncy)
	end
	local problems = {}
	local notes = {}

	local starts = spotsNear(points, course.start.spawn.Position, 6)
	local finish = spotsNear(points, course.finish.stand.Position, 8)
	if #starts == 0 then
		table.insert(problems, "no floor under the start")
	end
	if #finish == 0 then
		table.insert(problems, "no floor at the finish")
	end

	local easy = search(points, cells, starts, gravity, false, trusses)
	local dive = search(points, cells, starts, gravity, true, trusses)
	if not anySeen(dive, finish) then
		table.insert(problems, "the finish can't be reached from the start")
		if process.env.DEBUG then
			-- Where the search got stuck: the reached spot closest to the finish
			local best, bestDistance = nil, math.huge
			for index in pairs(dive) do
				local distance = (points[index].pos - course.finish.stand.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = points[index], distance
				end
			end
			local at = best.pos
			print(
				string.format(
					"  stuck at %s on %s (size %s)",
					tostring(at),
					best.part and best.part.Name or "?",
					best.part and tostring(best.part.Size) or ""
				)
			)
			for _, part in ipairs(course.folder:GetDescendants()) do
				if part:IsA("BasePart") and (part.Position - at).Magnitude < 40 then
					print(
						string.format(
							"    %-12s pos %s size %s collide %s tags %s",
							part.Name,
							tostring(part.Position - at),
							tostring(part.Size),
							tostring(part.CanCollide),
							table.concat(CollectionService:GetTagged("Moving")[1] and {} or {}, ",")
						)
					)
				end
			end
		end
	elseif not anySeen(easy, finish) then
		table.insert(notes, "needs a dive to finish")
	end

	for index, checkpoint in ipairs(course.checkpoints) do
		local here = spotsNear(points, checkpoint.spawn.Position, 6)
		if not anySeen(dive, here) then
			table.insert(problems, string.format("checkpoint %d can't be reached", index))
		end
		local from = search(points, cells, here, gravity, true, trusses)
		if not anySeen(from, finish) then
			table.insert(problems, string.format("stuck after checkpoint %d (finish unreachable from it)", index))
		end
		if checkpoint.killY >= checkpoint.spawn.Position.Y - 4 then
			table.insert(problems, string.format("checkpoint %d is below its own fall line", index))
		end
	end

	if #course.gems ~= 3 and not courseData.race then
		table.insert(problems, string.format("%d gems (needs 3)", #course.gems))
	end
	for index, gem in ipairs(course.gems) do
		local found, foundEasy = false, false
		for spot, point in ipairs(points) do
			if dive[spot] then
				local delta = gem - (point.pos + Vector3.new(0, 3, 0))
				local reachUp = point.launch and point.launch.Y ^ 2 / (2 * gravity) + 3 or Config.JumpHeight + 3
				if Vector3.new(delta.X, 0, delta.Z).Magnitude <= 4 and delta.Y >= -4.5 and delta.Y <= reachUp then
					found = true
					foundEasy = foundEasy or easy[spot] == true
				end
			end
		end
		-- Grabbed while riding a zipline (your middle follows the line)
		for spot, point in ipairs(points) do
			if not foundEasy and dive[spot] and point.zipTo and point.part then
				local from = point.part:GetAttribute("ZipFrom")
				for k = 0, 40 do
					local at = from:Lerp(point.zipTo, k / 40)
					if (at - gem).Magnitude <= 4.5 then
						found = true
						foundEasy = foundEasy or easy[spot] == true
					end
				end
			end
		end
		if not foundEasy then
			-- Grabbed in mid-air while jumping from one reached spot to another
			local close = near(cells, gem, 16)
			for _, i in ipairs(close) do
				for _, j in ipairs(close) do
					local a, b = points[i], points[j]
					if not foundEasy and dive[i] and dive[j] and link(a, b, gravity) == "jump" then
						local flat = Vector3.new(b.pos.X - a.pos.X, 0, b.pos.Z - a.pos.Z)
						local toGem = Vector3.new(gem.X - a.pos.X, 0, gem.Z - a.pos.Z)
						local along = flat.Magnitude > 0 and math.clamp(toGem:Dot(flat.Unit), 0, flat.Magnitude) or 0
						local closest = a.pos + (flat.Magnitude > 0 and flat.Unit * along or Vector3.zero)
						local side = (Vector3.new(gem.X, 0, gem.Z) - Vector3.new(closest.X, 0, closest.Z)).Magnitude
						local height = gem.Y - (math.max(a.pos.Y, b.pos.Y) + 3)
						if side <= 4 and height <= Config.JumpHeight and height >= -4.5 then
							found = true
							foundEasy = easy[i] == true and easy[j] == true
						end
					end
				end
			end
		end
		if not found then
			table.insert(problems, string.format("gem %d can't be reached", index))
		elseif not foundEasy then
			table.insert(notes, string.format("gem %d needs a dive", index))
		end
	end

	local parts = 0
	for _, item in ipairs(course.folder:GetDescendants()) do
		if item:IsA("BasePart") then
			parts += 1
		end
	end
	local length = (course.endCursor.Position - origin.Position).Magnitude
	course.folder:Destroy()
	return problems,
		notes,
		{ par = course.par, parts = parts, checkpoints = #course.checkpoints, length = length, spots = #points }
end

------------------------------------------------------------------ Run
local only = process.args[1]
local failed = 0
local total = 0
-- Adventure courses, then the tournament's race courses
local Rounds = Mock.require(Shared.Rounds)
local all = table.clone(Courses.List)
for _, round in ipairs(Rounds.List) do
	if round.pieces then
		table.insert(all, { id = round.id, name = round.name, world = round.world, pieces = round.pieces, race = true })
	end
end
for _, courseData in ipairs(all) do
	if not only or courseData.id == only or courseData.world == only then
		total += 1
		local ok, problems, notes, info = pcall(check, courseData)
		if not ok then
			failed += 1
			print(string.format("ERROR %-10s %s", courseData.id, tostring(problems)))
		else
			local status = #problems == 0 and "ok   " or "FAIL "
			if #problems > 0 then
				failed += 1
			end
			print(
				string.format(
					"%s %-10s %-24s par %3ds  %d checkpoints  %4d parts  %4d studs",
					status,
					courseData.id,
					courseData.name,
					info.par,
					info.checkpoints,
					info.parts,
					math.floor(info.length)
				)
			)
			for _, text in ipairs(problems) do
				print("        problem: " .. text)
			end
			for _, text in ipairs(notes) do
				print("        note: " .. text)
			end
		end
	end
end
print(string.format("%d of %d courses passed", total - failed, total))
process.exit(failed == 0 and 0 or 1)
