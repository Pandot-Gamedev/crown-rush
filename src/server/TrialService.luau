-- Time trials, ghosts and the Daily Challenge.
--
-- Time trials: every Adventure course has a best-times board. A new personal
-- best posts your time there.
-- Ghosts: your best run's path is saved, and so is the course record's path,
-- so you can race a see-through runner doing either one (picked on your screen).
-- Daily Challenge: one course a day for everyone, locked or not, with its own
-- board and a coin reward for your first finish of the day.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Courses = require(Shared.Courses)
local Quests = require(Shared.Quests)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local CourseService = require(script.Parent.CourseService)
local ProgressService = require(script.Parent.ProgressService)
local CosmeticService = require(script.Parent.CosmeticService)

local TrialService = {}

local BOARD_CACHE_SECONDS = 60
local ghostStore = nil
pcall(function()
	ghostStore = DataStoreService:GetDataStore(Config.GhostStoreName)
end)

local boards = {} -- [storeName] = { at = os.clock(), list = { { name, time } } }
local ghosts = {} -- ["u<userId>_<courseId>" or "top_<courseId>"] = ghost (loaded or saved this server)
local names = {}

local function nameFor(userId)
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

------------------------------------------------------------------ Boards
-- Times are saved in hundredths of a second, lowest first
local function postTime(storeName, player, time)
	task.spawn(function()
		pcall(function()
			DataStoreService:GetOrderedDataStore(storeName):UpdateAsync(tostring(player.UserId), function(old)
				local value = math.floor(time * 100 + 0.5)
				if old and old <= value then
					return nil
				end
				return value
			end)
		end)
		boards[storeName] = nil
	end)
end

local function topTimes(storeName)
	local cached = boards[storeName]
	if cached and os.clock() - cached.at < BOARD_CACHE_SECONDS then
		return cached.list
	end
	local list = {}
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName):GetSortedAsync(true, 10)
	end)
	if ok then
		for _, entry in ipairs(pages:GetCurrentPage()) do
			table.insert(list, { name = nameFor(tonumber(entry.key)), time = entry.value / 100 })
		end
	end
	boards[storeName] = { at = os.clock(), list = list }
	return list
end

------------------------------------------------------------------ Ghosts
local function loadGhost(key)
	if ghosts[key] ~= nil then
		return ghosts[key] or nil
	end
	local ghost = nil
	if ghostStore then
		local ok, value = pcall(function()
			return ghostStore:GetAsync(key)
		end)
		if ok and type(value) == "table" then
			ghost = value
		end
	end
	ghosts[key] = ghost or false
	return ghost
end

local function saveGhost(player, courseId, time, trail)
	if not trail or #trail < 8 then
		return
	end
	local ghost = { t = time, p = trail, name = player.DisplayName, userId = player.UserId }
	local mine = "u" .. player.UserId .. "_" .. courseId
	ghosts[mine] = ghost
	if not ghostStore then
		return
	end
	task.spawn(function()
		pcall(function()
			ghostStore:SetAsync(mine, ghost)
		end)
		local top = "top_" .. courseId
		local record = ghosts[top]
		if record and record.t <= time then
			return
		end
		pcall(function()
			ghostStore:UpdateAsync(top, function(old)
				if type(old) == "table" and old.t <= time then
					ghosts[top] = old
					return nil
				end
				ghosts[top] = ghost
				return ghost
			end)
		end)
	end)
end

-- Called by AdventureService when someone finishes a course
function TrialService.Finished(player, run, newBest, valid)
	if not valid then
		return
	end
	local courseId = run.instance.course.id
	if newBest then
		postTime(Config.CourseTimesStorePrefix .. courseId, player, run.time)
		saveGhost(player, courseId, run.time, run.trail)
	end
end

------------------------------------------------------------------ Daily Challenge
function TrialService.Today()
	return Quests.Today(os.time())
end

-- The same course for everyone today. Never the same one two days running.
function TrialService.DailyCourse(day)
	day = day or TrialService.Today()
	local count = #Courses.List
	local index = (day * 7) % count + 1
	return Courses.List[index]
end

local function onDailyFinish(run)
	local player = run.player
	if not player then
		return
	end
	local course = run.instance.course
	local time = run.time
	local day = TrialService.Today()
	local valid = not run.skipped and time >= course.par * Config.MinTimeShare
	local result = {
		mode = "daily",
		courseId = course.id,
		name = course.data.name,
		time = time,
		par = course.par,
		skipped = run.skipped,
		newBest = false,
		firstToday = false,
		coins = 0,
		xp = 0,
	}
	DataService.Update(player, function(data)
		if data.daily.day ~= day then
			data.daily = { day = day, best = 0 }
		end
		result.firstToday = data.daily.best == 0
		if valid and (data.daily.best == 0 or time < data.daily.best) then
			data.daily.best = math.floor(time * 100) / 100
			result.newBest = true
		end
		result.best = data.daily.best > 0 and data.daily.best or nil
	end)
	if result.newBest then
		postTime(Config.DailyTimesStorePrefix .. day, player, time)
	end
	local coins, xp = 15, 20
	if result.firstToday and valid then
		coins, xp = Config.DailyChallengeCoins, Config.DailyChallengeXp
	end
	result.coins, result.xp = ProgressService.AddResult(player, {
		coins = coins,
		xp = xp,
		stats = { courses = 1, falls = run.falls },
		quest = { courses = 1 },
		quiet = true,
	})
	Remotes.Run:FireClient(player, "result", result)
	local celebrate = CosmeticService.Equipped(player, "celebrate")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		Remotes.Effect:FireAllClients("finish", root.Position, { effect = celebrate and celebrate.id or nil })
	end
end

local function playDaily(player)
	if player:GetAttribute("InTournament") then
		return false, "Finish your tournament first"
	end
	local course = TrialService.DailyCourse()
	local instance, err = CourseService.Open(course)
	if not instance then
		return false, err
	end
	CourseService.Enter(player, instance, { mode = "daily", onFinish = onDailyFinish })
	return true
end

------------------------------------------------------------------ Questions from players' screens
local function askTimes(player, courseId)
	if type(courseId) ~= "string" or not Courses.ById[courseId] then
		return nil
	end
	local data = DataService.Get(player)
	local record = data and data.adventure[courseId]
	return { top = topTimes(Config.CourseTimesStorePrefix .. courseId), mine = record and record.best or nil }
end

local function askGhost(player, request)
	if type(request) ~= "table" or type(request.courseId) ~= "string" or not Courses.ById[request.courseId] then
		return nil
	end
	local ghost
	if request.which == "record" then
		ghost = loadGhost("top_" .. request.courseId)
	else
		ghost = loadGhost("u" .. player.UserId .. "_" .. request.courseId)
	end
	if not ghost then
		return nil
	end
	return { t = ghost.t, p = ghost.p, name = ghost.name, mine = ghost.userId == player.UserId }
end

local function askDaily(player)
	local day = TrialService.Today()
	local course = TrialService.DailyCourse(day)
	local data = DataService.Get(player)
	local best = data and data.daily.day == day and data.daily.best > 0 and data.daily.best or nil
	return {
		courseId = course.id,
		name = course.name,
		world = course.world,
		best = best,
		top = topTimes(Config.DailyTimesStorePrefix .. day),
		endsIn = 86400 - (os.time() % 86400),
		coins = Config.DailyChallengeCoins,
	}
end

function TrialService.Start()
	ProgressService.AddAction("PlayDaily", playDaily)
	ProgressService.AddQuestion("Times", askTimes)
	ProgressService.AddQuestion("Ghost", askGhost)
	ProgressService.AddQuestion("Daily", askDaily)
	Players.PlayerRemoving:Connect(function(player)
		-- Keep the record ghosts; drop this player's own
		for key in pairs(ghosts) do
			if string.sub(key, 1, #tostring(player.UserId) + 2) == "u" .. player.UserId .. "_" then
				ghosts[key] = nil
			end
		end
	end)
end

return TrialService
