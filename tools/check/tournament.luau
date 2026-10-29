-- Plays a whole tournament outside Roblox: two pretend players step on a pad,
-- bots fill the other 10 spots, and every round runs to the end. Player 1
-- runs each race (teleporting along the path), player 2 stands still. Checks
-- that nothing errors, the bots really move, someone is crowned, the players
-- are paid, and the pad is free again afterwards.
--
-- Usage (needs Lune):  lune run tools/check/tournament.luau
-- The first rounds can be forced:  ROUNDS=door_dash,tile_fall,sweeper lune run ...

local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Mock = require("./mock")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

Mock.Mount(process.cwd)
local game = Mock.game
local server = game:GetService("ServerScriptService").Server
local Shared = game:GetService("ReplicatedStorage").Shared
local Rounds = Mock.require(Shared.Rounds)
local TournamentService = Mock.require(server.TournamentService)

-- Short waits so the check runs in about a minute
local Timing = TournamentService.Timing
Timing.wait, Timing.full, Timing.intro, Timing.countdown, Timing.between = 0.5, 0.2, 0.1, 0.1, 0.1

-- Optionally force the first rounds
if process.env.ROUNDS then
	local pick = Rounds.Pick
	Rounds.Pick = function(random)
		local plan = pick(random)
		local index = 1
		for id in string.gmatch(process.env.ROUNDS, "[^,]+") do
			for _, round in ipairs(Rounds.List) do
				if round.id == id then
					plan[index] = round
				end
			end
			index += 1
		end
		return plan
	end
end

Mock.require(server)

local DataService = Mock.require(server.DataService)
local CourseService = Mock.require(server.CourseService)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function main()
	local failures = 0
	local function expect(condition, text)
		if not condition then
			failures += 1
			print("  FAIL: " .. text)
		end
	end

	local runner = Mock.AddPlayer(1001, "Runner")
	local idler = Mock.AddPlayer(1002, "Idler")
	for _ = 1, 50 do
		if DataService.IsLoaded(runner) and DataService.IsLoaded(idler) then
			break
		end
		task.wait(0.05)
	end

	-- The game clock: 1/30 s of game time per frame, as fast as we can
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

	-- Onto pad 1
	local pad
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("TournamentPad") == 1 then
			pad = item
		end
	end
	expect(pad ~= nil, "pad 1 exists")
	runner.Character.HumanoidRootPart.CFrame = CFrame.new(pad.Position + Vector3.new(-2, 3, 0))
	idler.Character.HumanoidRootPart.CFrame = CFrame.new(pad.Position + Vector3.new(2, 3, 0))

	local t
	for _ = 1, 100 do
		t = TournamentService.Get(runner)
		if t then
			break
		end
		task.wait(0.05)
	end
	expect(t ~= nil, "the tournament started")
	if not t then
		running = false
		return failures
	end
	local plan = {}
	for _, round in ipairs(t.plan) do
		table.insert(plan, round.id)
	end
	print("Tournament " .. t.id .. ": " .. table.concat(plan, ", "))
	expect(#t.entrants == Rounds.Players, "12 runners (bots fill the rest)")

	-- Player 1 runs every race: along the path, a little each frame
	local botMoved = false
	local lastRound = 0
	local startedAt = os.clock()
	local deadline = os.clock() + 240
	while not t.over and os.clock() < deadline do
		if t.roundNumber ~= lastRound then
			lastRound = t.roundNumber
			local alive = 0
			for _, entrant in ipairs(t.entrants) do
				alive += entrant.alive and 1 or 0
			end
			print(
				string.format(
					"  round %d: %s, %d still in (%.0fs)",
					lastRound,
					t.round and t.round.id or "?",
					alive,
					os.clock() - startedAt
				)
			)
		end
		if process.env.DEBUG and t.match and t.match.arena and os.clock() > (t.debugAt or 0) then
			t.debugAt = os.clock() + 2
			local origin = t.match.arena.origin.Position
			local parts = {}
			for _, entrant in ipairs(t.match.entrants) do
				if entrant.bot then
					local p = entrant.bot.root.Position - origin
					table.insert(parts, string.format("%s(%.0f,%.0f,%.0f)", entrant.name, p.X, p.Y, p.Z))
				end
			end
			local ball = t.match.arena.folder:FindFirstChild("Ball")
			if ball then
				local p = ball.Position - origin
				table.insert(parts, string.format("BALL(%.0f,%.0f)", p.X, p.Z))
			end
			print("    bots: " .. table.concat(parts, " "))
		end
		-- Are the bots really moving?
		for _, entrant in ipairs(t.entrants) do
			local bot = entrant.bot
			if bot and bot.root and bot.lastSeen then
				if (bot.root.Position - bot.lastSeen).Magnitude > 5 and bot.root.Position.Y > 0 then
					botMoved = true
				end
			end
			if bot and bot.root then
				bot.lastSeen = bot.lastSeen or bot.root.Position
			end
		end
		-- Objective and team rounds: the runner can't really play them here, so
		-- they "score" enough to go through, and the round's result is printed
		local match = t.match
		if match and match.scores and not match.checked then
			match.checked = true
			local me
			for _, entrant in ipairs(match.entrants) do
				if entrant.player == runner then
					me = entrant
				end
			end
			if me then
				local myTeam = match.teamOf and match.teamOf[me]
				match.scores[me] = 1000
				function match.SetScore(self, entrant, value)
					self.scores[entrant] = entrant == me and 1000 or value
				end
				function match.AddScore(self, entrant, amount)
					self.scores[entrant] = entrant == me and 1000 or (self.scores[entrant] or 0) + amount
				end
				function match.SetTeamScore(_, team, value)
					team.real = value
					team.score = team == myTeam and 1000 or value
				end
				if myTeam then
					myTeam.score = 1000
				end
			end
			local cleanup = match.Cleanup
			function match.Cleanup(self)
				print("    " .. self.round.id .. " result: " .. self:StatusText())
				local scored = 0
				for entrant, value in pairs(self.scores) do
					if entrant.bot and value > 0 then
						scored += 1
					end
				end
				if self.teams then
					for _, team in ipairs(self.teams) do
						if (team.real or 0) ~= 0 then
							scored += 1
						end
					end
				end
				expect(scored > 0, self.round.id .. ": bots scored")
				return cleanup(self)
			end
		end
		local run = CourseService.Get(runner)
		if run and not run.frozen and not run.finished then
			local course = run.instance.course
			local root = runner.Character.HumanoidRootPart
			local points = {}
			for _, node in ipairs(course.nodes) do
				local target = node.to or node.exit or node.past or (node.choices and node.choices[1])
				if typeof(target) == "Vector3" then
					table.insert(points, target)
				elseif node.kind == "checkpoint" then
					table.insert(points, course.checkpoints[node.index].spawn.Position - Vector3.new(0, 3.5, 0))
				end
			end
			table.insert(points, course.finish.stand.Position - Vector3.new(0, 3.5, 0))
			local position = root.Position - Vector3.new(0, 3, 0)
			for _, target in ipairs(points) do
				local steps = math.max(1, math.ceil((target - position).Magnitude / 3))
				for i = 1, steps do
					if CourseService.Get(runner) ~= run or run.finished then
						break
					end
					root.CFrame = CFrame.new(position:Lerp(target, i / steps) + Vector3.new(0, 3, 0))
					task.wait()
				end
				position = target
			end
		end
		task.wait(0.05)
	end
	running = false
	task.wait(0.2)

	expect(t.over, "the tournament finished in time")
	local winner
	for _, entrant in ipairs(t.entrants) do
		if entrant.place == 1 then
			winner = entrant
		end
	end
	print("  winner: " .. (winner and winner.name or "none"))
	expect(winner ~= nil, "someone won the crown")
	expect(botMoved, "bots moved")

	for _, player in ipairs({ runner, idler }) do
		local data = DataService.Get(player)
		print(
			string.format(
				"  %s: %d coins, rounds %d, crowns %d",
				player.Name,
				data.coins,
				data.stats.rounds,
				data.stats.crowns
			)
		)
		expect(data.stats.tournaments == 1, player.Name .. " counted 1 tournament")
		expect(player:GetAttribute("InTournament") == nil, player.Name .. " is out of the tournament")
		expect(player:GetAttribute("Watching") == nil, player.Name .. " stopped watching")
		expect(CourseService.Get(player) == nil, player.Name .. " is off the course")
	end
	local bots = Workspace:FindFirstChild("Bots")
	expect(bots and #bots:GetChildren() == 0, "the bots are gone")
	expect(TournamentService.Get(runner) == nil, "nothing left running")

	local sent = Mock.Sent.Announce or {}
	local kinds = {}
	for _, message in ipairs(sent) do
		kinds[message[2]] = (kinds[message[2]] or 0) + 1
	end
	for _, kind in ipairs({ "start", "intro", "countdown", "timer" }) do
		expect(kinds[kind], "announced " .. kind)
	end
	expect(kinds.champion or kinds.eliminated, "the players heard how they did")

	expect(#Mock.Warnings == 0, #Mock.Warnings .. " warnings")
	return failures
end

local ok, failures = pcall(main)
if not ok then
	print("Tournament check crashed: " .. tostring(failures))
	process.exit(1)
elseif failures > 0 then
	print(failures .. " tournament checks failed")
	process.exit(1)
end
print("All tournament checks passed")
process.exit(0)
