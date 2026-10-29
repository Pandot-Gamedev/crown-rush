-- Races bots alone through courses outside Roblox and checks they get to the
-- finish in time: every tournament race and the final by default, every
-- Adventure course too with COURSES=all. A bot that gets stuck (stands still
-- for good, or its thread dies after a knock) shows up here as "did not finish".
--
-- Usage (needs Lune):  lune run tools/check/bots.luau
--   COURSES=all lune run tools/check/bots.luau      (also every Adventure course)
--   COURSES=spinner_gauntlet,candy_3 lune run ...   (just these)

local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Mock = require("./mock")
local CFrame = roblox.CFrame

local BOTS = 6

Mock.Mount(process.cwd)
local game = Mock.game
local server = game:GetService("ServerScriptService").Server
local Shared = game:GetService("ReplicatedStorage").Shared
local Rounds = Mock.require(Shared.Rounds)
local Courses = Mock.require(Shared.Courses)
Mock.require(server)
local CourseService = Mock.require(server.CourseService)
local BotService = Mock.require(server.BotService)
local RunService = game:GetService("RunService")

local clock = 1790000000
local running = true
task.spawn(function()
	while running do
		clock += 1 / 30
		Mock.SetClock(clock)
		RunService.Heartbeat:Fire(1 / 30)
		task.wait()
	end
end)

-- Which courses
local list = {}
for _, round in ipairs(Rounds.List) do
	if round.kind == "race" or round.kind == "final" then
		table.insert(list, { id = round.id, name = round.name, world = round.world, pieces = round.pieces })
	end
end
local wanted = process.env.COURSES
if wanted == "all" then
	for _, course in ipairs(Courses.List) do
		table.insert(list, course)
	end
elseif wanted then
	local chosen = {}
	for id in string.gmatch(wanted, "[^,]+") do
		for _, course in ipairs(Rounds.List) do
			if course.id == id then
				table.insert(
					chosen,
					{ id = course.id, name = course.name, world = course.world, pieces = course.pieces }
				)
			end
		end
		if Courses.ById[id] then
			table.insert(chosen, Courses.ById[id])
		end
	end
	list = chosen
end

local failures = 0
for number, data in ipairs(list) do
	local instance = CourseService.Open(data, "bots" .. number, data.world)
	local course = instance.course
	local limit = math.max(60, math.floor(course.par * 3 + 20))
	local startedAt = clock
	local done = {}
	local bots = {}
	for index = 1, BOTS do
		local bot = BotService.Create(CFrame.new(0, 500, 0), (index - 1) / (BOTS - 1))
		local run = CourseService.Enter(bot, instance, {
			mode = "race",
			onFinish = function()
				done[bot] = clock - startedAt
			end,
			onPlaceBot = function(run, cframe)
				BotService.Respawned(bot, run, cframe)
			end,
		})
		BotService.Race(bot, run)
		table.insert(bots, bot)
	end
	while clock - startedAt < limit do
		local count = 0
		for _ in pairs(done) do
			count += 1
		end
		if count == BOTS then
			break
		end
		if process.env.DEBUG and clock > (data.debugAt or 0) then
			data.debugAt = clock + (tonumber(process.env.DEBUG) or 3)
			local parts = {}
			for _, bot in ipairs(bots) do
				local p = course.origin:PointToObjectSpace(bot.root.Position)
				table.insert(
					parts,
					string.format(
						"%s#%s(%.0f,%.0f,%.0f)",
						bot.name,
						tostring(bot.model:GetAttribute("PathNode")),
						p.X,
						p.Y,
						p.Z
					)
				)
			end
			print(string.format("  %3.0fs  %s", clock - startedAt, table.concat(parts, " ")))
			local run = CourseService.Get(bots[1])
			if run then
				print("    run", run.started, run.checkpoint, run.respawning, run.frozen, run.finished)
			end
			if not data.shown then
				data.shown = true
				for i, cp in ipairs(course.checkpoints) do
					local c = course.origin:PointToObjectSpace(cp.center.Position)
					print(
						string.format(
							"    checkpoint %d at (%.0f,%.0f,%.0f) size %s",
							i,
							c.X,
							c.Y,
							c.Z,
							tostring(cp.size)
						)
					)
				end
				local f = course.origin:PointToObjectSpace(course.finish.lineCFrame.Position)
				print(string.format("    finish at (%.0f,%.0f,%.0f)", f.X, f.Y, f.Z))
				local l = course.origin:PointToObjectSpace(course.start.lineCFrame.Position)
				print(string.format("    start line at (%.0f,%.0f,%.0f)", l.X, l.Y, l.Z))
				for i, node in ipairs(course.nodes) do
					local target = node.to or node.at or node.enter
					local tt = typeof(target) == "Vector3" and course.origin:PointToObjectSpace(target) or nil
					print("    node", i, node.kind, tt and string.format("(%.0f,%.0f,%.0f)", tt.X, tt.Y, tt.Z) or "")
				end
			end
		end
		task.wait(0.05)
	end
	local times, stuck = {}, {}
	for _, bot in ipairs(bots) do
		if done[bot] then
			table.insert(times, done[bot])
		else
			local run = CourseService.Get(bot)
			table.insert(stuck, string.format("%s at checkpoint %d", bot.name, run and run.checkpoint or -1))
		end
	end
	table.sort(times)
	local line = string.format("%-18s par %3.0fs  limit %3ds  finished %d/%d", data.id, course.par, limit, #times, BOTS)
	if #times > 0 then
		line ..= string.format("  (first %.0fs, middle %.0fs)", times[1], times[math.ceil(#times / 2)])
	end
	print(line)
	if #stuck > 0 then
		print("    did not finish: " .. table.concat(stuck, ", "))
	end
	-- Most bots should make it; the weakest may run out of time
	if #times < BOTS - 2 then
		failures += 1
		print("  FAIL: too few bots finished " .. data.id)
	end
	for _, bot in ipairs(bots) do
		CourseService.Leave(bot)
		BotService.Remove(bot)
	end
	CourseService.Close(instance)
end
running = false

if #Mock.Warnings > 0 then
	failures += 1
	print("  FAIL: " .. #Mock.Warnings .. " warnings: " .. tostring(Mock.Warnings[1]))
end
if failures > 0 then
	print(failures .. " bot checks failed")
	process.exit(1)
end
print("All bot checks passed")
process.exit(0)
