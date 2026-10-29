-- Runs courses: builds them on demand in their own spot in the sky, and keeps
-- track of everyone running one (a "run"): the timer, checkpoints, gems,
-- falling and coming back, the finish. Adventure (solo play) and tournament
-- races both use it; they pass callbacks for what happens at the finish.
--
-- A course built for Adventure is shared: everyone playing that course on the
-- server runs on the same copy (each with their own timer). Tournament races get
-- their own copy.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CourseBuilder = require(script.Parent.CourseBuilder)

local CourseService = {}

local SLOT_ORIGIN = Vector3.new(4000, 300, 0)
local SLOT_SPACING = 1400
local GEM_RADIUS = 4.5
local TRAIL_STEP = 0.1 -- seconds between saved spots on a ghost path
local TRAIL_MAX = 6000 -- numbers kept (about 2.5 minutes of running)

local folder
local slots = {} -- [index] = instance or nil
local instances = {} -- [key] = instance
local runs = {} -- [runner key] = run
local random = Random.new()

local function now()
	return Workspace:GetServerTimeNow()
end

------------------------------------------------------------------ Course instances
local function freeSlot()
	for index = 1, Config.CourseSlots do
		if not slots[index] then
			return index
		end
	end
	return nil
end

-- Builds a course (or returns the copy already built under that key)
function CourseService.Open(courseData, key, themeId)
	key = key or courseData.id
	local existing = instances[key]
	if existing then
		existing.emptySince = nil
		return existing
	end
	local slot = freeSlot()
	if not slot then
		return nil, "The game is busy, try again in a moment"
	end
	local origin = CFrame.new(SLOT_ORIGIN + Vector3.new((slot - 1) * SLOT_SPACING, 0, 0))
	local course = CourseBuilder.Build(courseData, origin, folder, themeId)
	local instance = {
		key = key,
		slot = slot,
		course = course,
		emptySince = nil,
		shared = key == courseData.id,
	}
	slots[slot] = instance
	instances[key] = instance
	return instance
end

function CourseService.Close(instance)
	if instances[instance.key] ~= instance then
		return
	end
	for runnerKey, run in pairs(runs) do
		if run.instance == instance then
			runs[runnerKey] = nil
		end
	end
	instances[instance.key] = nil
	slots[instance.slot] = nil
	instance.course.folder:Destroy()
end

local function runnersIn(instance)
	local list = {}
	for _, run in pairs(runs) do
		if run.instance == instance then
			table.insert(list, run)
		end
	end
	return list
end

------------------------------------------------------------------ Runs
local function rootOf(run)
	if run.player then
		local character = run.player.Character
		return character and character:FindFirstChild("HumanoidRootPart")
	end
	return run.bot and run.bot.root
end

local function send(run, event, info)
	if run.player then
		Remotes.Run:FireClient(run.player, event, info)
	end
end

-- { true, false, true }: remotes drop gaps in number-keyed tables, so no nils
local function gemList(set)
	return { set[1] == true, set[2] == true, set[3] == true }
end

-- What a player's screen needs to show their run
local function summary(run)
	local course = run.instance.course
	return {
		courseId = course.id,
		name = course.data.name,
		world = course.theme.id,
		mode = run.mode,
		started = run.started,
		checkpoint = run.checkpoint,
		checkpoints = #course.checkpoints,
		gems = gemList(run.gems),
		savedGems = gemList(run.savedGems),
		falls = run.falls,
		canSkip = run.fallsHere >= Config.SkipAfterFalls and run.mode == "adventure",
		skipped = run.skipped,
		par = course.par,
		finished = run.finished,
		origin = course.origin,
	}
end
CourseService.Summary = summary

local function placeRunner(run, cframe)
	local root = rootOf(run)
	if not root then
		return
	end
	if run.player then
		local character = run.player.Character
		pcall(function()
			run.player:RequestStreamAroundAsync(cframe.Position, 2)
		end)
		character:PivotTo(cframe)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	elseif run.onPlaceBot then
		run.onPlaceBot(run, cframe)
	end
end

local function spawnFor(run)
	local course = run.instance.course
	if run.checkpoint > 0 then
		return course.checkpoints[run.checkpoint].spawn
	end
	return course.start.spawn
end

local function setKillY(run)
	run.killY = CourseBuilder.KillY(run.instance.course, run.checkpoint)
	if run.player then
		run.player:SetAttribute("KillY", run.killY)
	end
end

-- Puts a runner on a course. options:
--   mode = "adventure" | "race"
--   savedGems = { [1..3] = true } gems found on earlier runs (they still show, dimmed)
--   onFinish(run), onFall(run), onCheckpoint(run), onGem(run, index), onLeave(run)
--   frozen = true: wait at the start until CourseService.Release(run)
function CourseService.Enter(runner, instance, options)
	options = options or {}
	local key = typeof(runner) == "Instance" and ("p" .. runner.UserId) or runner.key
	local old = runs[key]
	if old and old.onLeave then
		task.spawn(old.onLeave, old)
	end
	local run = {
		key = key,
		player = typeof(runner) == "Instance" and runner or nil,
		bot = typeof(runner) ~= "Instance" and runner or nil,
		instance = instance,
		mode = options.mode or "adventure",
		started = nil,
		finished = false,
		checkpoint = 0,
		falls = 0,
		fallsHere = 0,
		gems = {},
		savedGems = options.savedGems or {},
		skipped = false,
		respawning = false,
		lastSafe = 0,
		options = options,
		onFinish = options.onFinish,
		onFall = options.onFall,
		onCheckpoint = options.onCheckpoint,
		onGem = options.onGem,
		onLeave = options.onLeave,
		onPlaceBot = options.onPlaceBot,
		frozen = options.frozen == true,
		trail = options.record and {} or nil, -- { t, x, y, z, t, x, ... } for a ghost
	}
	runs[key] = run
	instance.emptySince = nil
	setKillY(run)
	if run.player then
		run.player:SetAttribute("Course", instance.course.id)
		run.player:SetAttribute("CourseWorld", instance.course.theme.id)
	end
	local spot = instance.course.start.spawn * CFrame.new(random:NextNumber(-6, 6), 0, random:NextNumber(-2, 3))
	placeRunner(run, spot)
	send(run, "enter", summary(run))
	return run
end

-- Takes a runner off their course (doesn't move them)
function CourseService.Leave(runner)
	local key = typeof(runner) == "Instance" and ("p" .. runner.UserId) or runner.key
	local run = runs[key]
	if not run then
		return
	end
	runs[key] = nil
	if run.player then
		run.player:SetAttribute("Course", nil)
		run.player:SetAttribute("CourseWorld", nil)
		run.player:SetAttribute("KillY", nil)
		send(run, "leave", nil)
	end
	if run.onLeave then
		task.spawn(run.onLeave, run)
	end
end

function CourseService.Get(runner)
	local key = typeof(runner) == "Instance" and ("p" .. runner.UserId) or runner.key
	return runs[key]
end

-- Starts a frozen run's timer (tournament races start everyone together)
function CourseService.Release(run)
	run.frozen = false
	run.started = now()
	send(run, "update", summary(run))
end

-- Back to the start with a fresh timer
function CourseService.Restart(run)
	run.started = nil
	run.finished = false
	run.checkpoint = 0
	run.falls = 0
	run.fallsHere = 0
	run.gems = {}
	run.skipped = false
	if run.trail then
		run.trail = {}
		run.trailLast = nil
	end
	setKillY(run)
	placeRunner(run, run.instance.course.start.spawn)
	send(run, "update", summary(run))
end

-- Back to the last checkpoint after a fall
function CourseService.Respawn(run, counts)
	if run.respawning or run.finished then
		return
	end
	run.respawning = true
	if counts ~= false then
		run.falls += 1
		run.fallsHere += 1
	end
	local root = rootOf(run)
	if root then
		Remotes.Effect:FireAllClients("fall", root.Position, {})
	end
	if run.onFall then
		task.spawn(run.onFall, run)
	end
	task.delay(Config.RespawnSeconds, function()
		run.respawning = false
		if runs[run.key] ~= run then
			return
		end
		placeRunner(run, spawnFor(run) * CFrame.new(random:NextNumber(-3, 3), 0, random:NextNumber(-1, 1)))
		send(run, "update", summary(run))
	end)
end

-- The free skip: jump to the next checkpoint (that run gets no stars)
function CourseService.Skip(run)
	local course = run.instance.course
	if run.fallsHere < Config.SkipAfterFalls or run.finished then
		return false
	end
	run.skipped = true
	run.fallsHere = 0
	if run.checkpoint < #course.checkpoints then
		run.checkpoint += 1
		setKillY(run)
		placeRunner(run, spawnFor(run))
	else
		placeRunner(run, course.finish.stand * CFrame.new(0, 0, 8))
	end
	if not run.started then
		run.started = now()
	end
	send(run, "update", summary(run))
	return true
end

local function finish(run)
	run.finished = true
	run.time = now() - (run.started or now())
	if run.onFinish then
		task.spawn(run.onFinish, run)
	end
	send(run, "update", summary(run))
end

-- One check of one runner: start line, checkpoints, gems, finish, falling
local function checkRun(run)
	if run.respawning then
		return
	end
	local root = rootOf(run)
	if not root then
		return
	end
	local course = run.instance.course
	local position = root.Position

	if not run.started and not run.frozen then
		local line = course.start.lineCFrame:PointToObjectSpace(position)
		if line.Z < -0.5 then
			run.started = now()
			send(run, "update", summary(run))
		end
	end

	-- The path for ghosts, in the course's own space (courses are built in different places)
	if run.trail and run.started and not run.finished and #run.trail < TRAIL_MAX then
		local t = now() - run.started
		if t - (run.trailLast or -1) >= TRAIL_STEP then
			run.trailLast = t
			local spot = course.origin:PointToObjectSpace(position)
			local trail = run.trail
			trail[#trail + 1] = math.floor(t * 100 + 0.5) / 100
			trail[#trail + 1] = math.floor(spot.X * 10 + 0.5) / 10
			trail[#trail + 1] = math.floor(spot.Y * 10 + 0.5) / 10
			trail[#trail + 1] = math.floor(spot.Z * 10 + 0.5) / 10
		end
	end

	if position.Y < run.killY then
		CourseService.Respawn(run)
		return
	end

	if run.finished then
		return
	end

	local nextCheckpoint = course.checkpoints[run.checkpoint + 1]
	if nextCheckpoint and CourseBuilder.InBox(position, nextCheckpoint.center, nextCheckpoint.size) then
		run.checkpoint += 1
		run.fallsHere = 0
		setKillY(run)
		if run.onCheckpoint then
			task.spawn(run.onCheckpoint, run)
		end
		Remotes.Effect:FireAllClients("checkpoint", position, {})
		send(run, "update", summary(run))
	end

	for index, gemPosition in ipairs(course.gems) do
		if not run.gems[index] and (gemPosition - position).Magnitude < GEM_RADIUS then
			run.gems[index] = true
			if run.onGem then
				task.spawn(run.onGem, run, index)
			end
			if run.player then
				Remotes.Effect:FireClient(run.player, "gem", gemPosition, { index = index })
			end
			send(run, "update", summary(run))
		end
	end

	if run.checkpoint >= #course.checkpoints and run.started then
		local finishLine = course.finish.lineCFrame:PointToObjectSpace(position)
		if
			finishLine.Z < 0.5
			and math.abs(finishLine.X) < course.finish.size.X / 2 + 2
			and math.abs(finishLine.Y) < 20
		then
			finish(run)
		end
	end
end

------------------------------------------------------------------ Falling tiles and fake doors
local function nearFeet(tile, position)
	local offset = tile.home:PointToObjectSpace(position)
	local size = tile.part.Size
	return math.abs(offset.X) < size.X / 2 + 0.5
		and math.abs(offset.Z) < size.Z / 2 + 0.5
		and offset.Y > 0
		and offset.Y < 5
end

local function dropTile(tile)
	tile.state = "shaking"
	local part = tile.part
	part.Color = part.Color:Lerp(Color3.new(1, 1, 1), 0.5)
	local original = tile.color or part.Color
	tile.color = tile.color or original
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < 0.55 and part.Parent do
			part.CFrame = tile.home * CFrame.new(random:NextNumber(-0.12, 0.12), 0, random:NextNumber(-0.12, 0.12))
			task.wait(0.05)
		end
		if not part.Parent then
			return
		end
		tile.state = "down"
		part.CanCollide = false
		TweenService:Create(
			part,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = tile.home * CFrame.new(0, -24, 0), Transparency = 1 }
		):Play()
		task.wait(5)
		if not part.Parent then
			return
		end
		part.CFrame = tile.home
		part.Transparency = 0
		part.CanCollide = true
		part.Color = tile.color
		tile.state = "up"
	end)
end

local function breakDoor(door)
	door.broken = true
	local part = door.part
	Remotes.Effect:FireAllClients("door", part.Position, {})
	part.Transparency = 1
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child.Enabled = false
		end
	end
	task.delay(4, function()
		if part.Parent then
			part.Transparency = 0
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("SurfaceGui") then
					child.Enabled = true
				end
			end
			door.broken = false
		end
	end)
end

local function checkWorld(instance, positions)
	local course = instance.course
	for _, tile in ipairs(course.fallTiles) do
		if tile.state == "up" then
			for _, position in ipairs(positions) do
				if nearFeet(tile, position) then
					dropTile(tile)
					break
				end
			end
		end
	end
	for _, door in ipairs(course.fakeDoors) do
		if not door.broken then
			for _, position in ipairs(positions) do
				if CourseBuilder.InBox(position, door.home, door.part.Size + Vector3.new(1, 0, 3)) then
					breakDoor(door)
					break
				end
			end
		end
	end
end

------------------------------------------------------------------ Start
function CourseService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Courses"
	folder.Parent = Workspace

	-- A player's own computer says when they touched lava or a laser (or fell
	-- below the course): bring them back to their checkpoint right away
	Remotes.Fell.OnServerEvent:Connect(function(player)
		local run = runs["p" .. player.UserId]
		if run and not run.finished then
			CourseService.Respawn(run)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		CourseService.Leave(player)
	end)

	-- A player who resets goes back to their checkpoint
	local function watch(player)
		player.CharacterAdded:Connect(function()
			local run = runs["p" .. player.UserId]
			if run then
				task.wait(0.2)
				placeRunner(run, spawnFor(run))
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end

	RunService.Heartbeat:Connect(function()
		for _, run in pairs(runs) do
			local ok, err = pcall(checkRun, run)
			if not ok then
				warn("[CourseService] " .. tostring(err))
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, instance in pairs(instances) do
				local list = runnersIn(instance)
				local positions = {}
				for _, run in ipairs(list) do
					local root = rootOf(run)
					if root then
						table.insert(positions, root.Position)
					end
				end
				pcall(checkWorld, instance, positions)
				if #list == 0 and instance.shared then
					instance.emptySince = instance.emptySince or os.clock()
					if os.clock() - instance.emptySince > Config.EmptyCourseSeconds then
						CourseService.Close(instance)
					end
				end
			end
		end
	end)
end

function CourseService.Instances()
	return instances
end

CourseService.RunnersIn = runnersIn

return CourseService
