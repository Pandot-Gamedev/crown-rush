-- Plays the game outside Roblox: starts the server, adds a pretend player,
-- and walks them through Adventure courses and the Daily Challenge by
-- teleporting along each course's path. Checks the save after each one:
-- finished, stars, best time, ghost, coins.
--
-- Usage (needs Lune):  lune run tools/check/play.luau

local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Mock = require("./mock")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

Mock.Mount(process.cwd)
local game = Mock.game
local server = game:GetService("ServerScriptService").Server
Mock.require(server)

local Shared = game:GetService("ReplicatedStorage").Shared
local Courses = Mock.require(Shared.Courses)
local DataService = Mock.require(server.DataService)
local CourseService = Mock.require(server.CourseService)
local TrialService = Mock.require(server.TrialService)
local Remotes = Mock.require(Shared.Remotes)
local RunService = game:GetService("RunService")

local function main()
	local failures = 0
	local function expect(condition, text)
		if not condition then
			failures += 1
			print("  FAIL: " .. text)
		end
	end

	local player = Mock.AddPlayer(1001, "Tester")
	for _ = 1, 50 do
		if DataService.IsLoaded(player) then
			break
		end
		task.wait(0.05)
	end
	expect(DataService.IsLoaded(player), "save loaded")

	local action = rawget(Remotes.Action, "_props").OnServerInvoke
	local ask = rawget(Remotes.Ask, "_props").OnServerInvoke
	local root = player.Character.HumanoidRootPart
	local clock = 1790000000

	local function step(seconds)
		clock += seconds
		Mock.SetClock(clock)
		RunService.Heartbeat:Fire(seconds)
	end

	-- Walks the course path: every node's target, a few steps between each
	local function runCourse(run, speed)
		local course = run.instance.course
		local position = course.start.spawn.Position
		local function moveTo(target)
			local distance = (target - position).Magnitude
			local steps = math.max(1, math.ceil(distance / 4))
			for i = 1, steps do
				local at = position:Lerp(target, i / steps)
				root.CFrame = CFrame.new(at + Vector3.new(0, 3, 0))
				step(4 / speed)
			end
			position = target
		end
		-- Grab the gems (teleporting; the course checker proves they can be reached)
		for _, gem in ipairs(course.gems) do
			root.CFrame = CFrame.new(gem)
			step(0.05)
		end
		if process.env.DEBUG then
			print(
				"  gems this run",
				run.gems[1],
				run.gems[2],
				run.gems[3],
				"falls",
				run.falls,
				"respawning",
				run.respawning,
				"cp",
				run.checkpoint
			)
		end
		root.CFrame = CFrame.new(course.start.spawn.Position)
		step(0.05)
		for _, node in ipairs(course.nodes) do
			local target = node.to or node.exit or node.past
			if not target and node.choices then
				target = node.choices[1]
			end
			if typeof(target) == "Vector3" then
				moveTo(target)
			elseif node.kind == "checkpoint" then
				local checkpoint = course.checkpoints[node.index]
				moveTo(checkpoint.spawn.Position - Vector3.new(0, 3.5, 0))
			end
		end
		-- Past the finish line
		moveTo(course.finish.stand.Position - Vector3.new(0, 3.5, 0))
		step(0.1)
		task.wait(0.05)
	end

	local function play(courseId)
		local ok, message = action(player, "PlayCourse", courseId)
		expect(ok, "PlayCourse " .. courseId .. ": " .. tostring(message))
		local run = CourseService.Get(player)
		expect(run ~= nil, "on the course " .. courseId)
		if run then
			runCourse(run, 24)
		end
		return run
	end

	-- Course 1 opens, course 2 is locked until course 1 is done
	local ok = action(player, "PlayCourse", "candy_2")
	expect(not ok, "candy_2 locked at first")

	for _, course in ipairs(Courses.ByWorld.candy) do
		local run = play(course.id)
		local record = DataService.Get(player).adventure[course.id]
		expect(record and record.done, course.id .. " saved as done")
		expect(run and run.finished, course.id .. " finished")
		if record then
			print(
				string.format(
					"  %s finished in %.2fs (par %ds), stars %d, gems %d",
					course.id,
					record.best or -1,
					run.instance.course.par,
					Courses.CountStars(record.stars),
					record.gems
				)
			)
		end
		action(player, "LeaveCourse")
	end

	local data = DataService.Get(player)
	print(
		string.format(
			"After Candy Clouds: %d stars, %d coins, %d xp",
			Courses.TotalStars(data.adventure),
			data.coins,
			data.xp
		)
	)
	expect(Courses.WorldUnlocked(data.adventure, "jungle"), "Jungle Ruins opens")

	-- Ghost and best times
	local ghost = ask(player, "Ghost", { courseId = "candy_1", which = "mine" })
	expect(ghost and #ghost.p > 8, "own ghost saved for candy_1")
	local record = ask(player, "Ghost", { courseId = "candy_1", which = "record" })
	task.wait(0.1)
	record = ask(player, "Ghost", { courseId = "candy_1", which = "record" })
	expect(record ~= nil, "record ghost saved for candy_1")
	local times = ask(player, "Times", "candy_1")
	task.wait(0.1)
	times = ask(player, "Times", "candy_1")
	expect(times and #times.top == 1, "best time on the board")

	-- Daily Challenge
	local daily = ask(player, "Daily")
	expect(daily and daily.courseId, "daily course")
	local coinsBefore = DataService.Get(player).coins
	local okDaily = action(player, "PlayDaily")
	expect(okDaily, "PlayDaily")
	local run = CourseService.Get(player)
	if run then
		runCourse(run, 24)
	end
	expect(DataService.Get(player).daily.best > 0, "daily time saved")
	expect(DataService.Get(player).coins > coinsBefore, "daily coins paid")
	print(
		"Daily: "
			.. tostring(daily and daily.name)
			.. ", coins "
			.. coinsBefore
			.. " -> "
			.. DataService.Get(player).coins
	)
	action(player, "LeaveCourse")

	print(failures == 0 and "All play checks passed" or (failures .. " play checks failed"))
	process.exit(failures == 0 and 0 or 1)
end

local ok, err = pcall(main)
if not ok then
	print("Play test crashed: " .. tostring(err))
	process.exit(1)
end
