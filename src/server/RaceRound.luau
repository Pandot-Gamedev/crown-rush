-- A race round (and the final, Crown Climb): everyone lines up at the start,
-- 3-2-1-GO, and the first ones over the line go through. The round ends when
-- enough have finished, or when the time runs out (then whoever got furthest
-- is ranked by checkpoint and distance).

local Workspace = game:GetService("Workspace")

local CourseService = require(script.Parent.CourseService)
local BotService = require(script.Parent.BotService)

local RaceRound = {}
RaceRound.__index = RaceRound

local function runnerOf(entrant)
	return entrant.player or entrant.bot
end

-- t = the tournament (TournamentService), round = data from Shared/Rounds
function RaceRound.new(t, round, entrants, keep, number)
	local self = setmetatable({
		t = t,
		round = round,
		entrants = entrants,
		keep = keep,
		finished = {},
		runs = {},
		done = false,
	}, RaceRound)
	local courseData = { id = round.id, name = round.name, world = round.world, pieces = round.pieces }
	local instance, err = CourseService.Open(courseData, "t" .. t.id .. "r" .. number, round.world)
	if not instance then
		error("No room for the race: " .. tostring(err))
	end
	self.instance = instance
	self.course = instance.course
	self.limit = round.limit or math.max(60, math.floor(self.course.par * 3 + 20))
	for _, entrant in ipairs(entrants) do
		local options = {
			mode = "race",
			frozen = true,
			onFinish = function(run)
				self:onFinish(entrant, run)
			end,
		}
		if entrant.bot then
			options.onPlaceBot = function(run, cframe)
				BotService.Respawned(entrant.bot, run, cframe)
			end
		end
		self.runs[entrant] = CourseService.Enter(runnerOf(entrant), instance, options)
		t:SetInRound(entrant, true)
	end
	return self
end

function RaceRound:onFinish(entrant, run)
	if self.done or table.find(self.finished, entrant) then
		return
	end
	table.insert(self.finished, entrant)
	local place = #self.finished
	self.t:SetInRound(entrant, false)
	if place <= self.keep then
		self.t:Qualified(entrant, place, run.time)
	end
	if #self.finished >= self.keep then
		self.done = true
	end
end

-- How far along a runner is (for ranking those who didn't finish)
function RaceRound:progress(entrant)
	local run = self.runs[entrant]
	if not run then
		return -math.huge
	end
	local root = run.player and run.player.Character and run.player.Character:FindFirstChild("HumanoidRootPart")
		or (run.bot and run.bot.root)
	local course = self.course
	local target = course.checkpoints[run.checkpoint + 1]
	local goal = target and target.spawn.Position or course.finish.stand.Position
	local distance = root and (root.Position - goal).Magnitude or 9999
	return run.checkpoint * 100000 - distance
end

-- Runs the round to the end. Returns qualified (in order) and eliminated (best first).
function RaceRound:Play()
	local t = self.t
	t:Freeze(self.entrants, true)
	local goAt = Workspace:GetServerTimeNow() + t.timing.countdown
	t:Announce("countdown", { goAt = goAt })
	task.wait(t.timing.countdown)
	t:Freeze(self.entrants, false)
	local endsAt = Workspace:GetServerTimeNow() + self.limit
	t:Announce("timer", { endsAt = endsAt, text = string.format("First %d over the line go through!", self.keep) })
	for entrant, run in pairs(self.runs) do
		CourseService.Release(run)
		if entrant.bot then
			BotService.Race(entrant.bot, run)
		end
	end

	while not self.done and Workspace:GetServerTimeNow() < endsAt do
		task.wait(0.2)
		-- Every real player is through (or gone): rank the bots where they are
		local playersRacing = false
		for _, entrant in ipairs(self.entrants) do
			if entrant.player and not entrant.left and not table.find(self.finished, entrant) then
				playersRacing = true
			end
		end
		if not playersRacing then
			break
		end
		t:Status(string.format("%d / %d through", math.min(#self.finished, self.keep), self.keep))
	end
	self.done = true

	-- Fill the spots left by progress, then everyone else is out
	local rest = {}
	for _, entrant in ipairs(self.entrants) do
		if not table.find(self.finished, entrant) and not entrant.left then
			table.insert(rest, entrant)
		end
	end
	table.sort(rest, function(a, b)
		return self:progress(a) > self:progress(b)
	end)
	local qualified = {}
	for index = 1, math.min(#self.finished, self.keep) do
		table.insert(qualified, self.finished[index])
	end
	local eliminated = {}
	for index = self.keep + 1, #self.finished do
		table.insert(eliminated, self.finished[index])
	end
	for _, entrant in ipairs(rest) do
		if #qualified < self.keep then
			-- Out of time: whoever got furthest takes the last spots
			table.insert(qualified, entrant)
			t:Qualified(entrant, #qualified, nil)
		else
			table.insert(eliminated, entrant)
		end
	end
	return qualified, eliminated
end

function RaceRound:Cleanup()
	for entrant in pairs(self.runs) do
		if entrant.bot then
			BotService.Stop(entrant.bot)
		end
		CourseService.Leave(runnerOf(entrant))
		self.t:SetInRound(entrant, false)
	end
	CourseService.Close(self.instance)
end

return RaceRound
