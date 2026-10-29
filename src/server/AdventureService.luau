-- Adventure: the solo courses. Walk into a world gate in the plaza to pick a
-- course. Courses in a world open one after another; worlds open with stars.
-- Stars: finish the course, beat its par time, and find all 3 gems (gems you
-- found stay found, even if you fall or leave).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Courses = require(Shared.Courses)
local Worlds = require(Shared.Worlds)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local CourseService = require(script.Parent.CourseService)
local ProgressService = require(script.Parent.ProgressService)
local TutorialService = require(script.Parent.TutorialService)
local CosmeticService = require(script.Parent.CosmeticService)

local AdventureService = {}

local WORLD_ORDER = {}
for _, world in ipairs(Worlds.List) do
	table.insert(WORLD_ORDER, world.id)
end

local gates = {} -- { part, worldId }
local nearGate = {} -- [player] = worldId they are standing at (so the menu opens once)
local lobbySpawnFn = nil

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind)
end

------------------------------------------------------------------ Unlocks
function AdventureService.WorldUnlocked(data, worldId)
	return Courses.WorldUnlocked(data.adventure, worldId)
end

function AdventureService.CourseUnlocked(data, courseId)
	return Courses.Unlocked(data.adventure, courseId)
end

local function gemBits(record)
	return record and record.gems or 0
end

local function savedGems(data, courseId)
	local bits = gemBits(data.adventure[courseId])
	local list = {}
	for index = 1, 3 do
		if bit32.band(bits, bit32.lshift(1, index - 1)) ~= 0 then
			list[index] = true
		end
	end
	return list
end

------------------------------------------------------------------ Playing
local onFinish, onGem

local function toLobby(player)
	CourseService.Leave(player)
	local character = player.Character
	if character and lobbySpawnFn then
		character:PivotTo(lobbySpawnFn())
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end
AdventureService.ToLobby = toLobby

function AdventureService.Play(player, courseId)
	local data = DataService.Get(player)
	local course = Courses.ById[courseId or ""]
	if not data or not course then
		return false, "Unknown course"
	end
	if player:GetAttribute("InTournament") then
		return false, "Finish your tournament first"
	end
	if not AdventureService.CourseUnlocked(data, courseId) then
		local world = Worlds.ById[course.world]
		if not AdventureService.WorldUnlocked(data, course.world) then
			return false, string.format("%s opens at %d stars", world.name, world.stars)
		end
		return false, "Finish the course before it first"
	end
	local instance, err = CourseService.Open(course)
	if not instance then
		return false, err
	end
	CourseService.Enter(player, instance, {
		mode = "adventure",
		savedGems = savedGems(data, courseId),
		onFinish = onFinish,
		onGem = onGem,
	})
	TutorialService.Event(player, "Course")
	return true
end

onGem = function(run, index)
	local player = run.player
	if not player then
		return
	end
	local courseId = run.instance.course.id
	local isNew = false
	DataService.Update(player, function(data)
		local record = data.adventure[courseId] or { done = false, stars = 0, gems = 0, runs = 0 }
		data.adventure[courseId] = record
		local bit = bit32.lshift(1, index - 1)
		if bit32.band(record.gems, bit) == 0 then
			record.gems = bit32.bor(record.gems, bit)
			data.stats.gems += 1
			isNew = true
		end
	end)
	if isNew then
		run.savedGems[index] = true
		ProgressService.AddResult(
			player,
			{
				coins = Config.CourseRewards.gem,
				xp = Config.CourseXp.gem,
				stats = {},
				quest = { gems = 1 },
				quiet = true,
			}
		)
		-- All three found on a course already finished: the gem star right away
		local starNow = false
		DataService.Update(player, function(data)
			local record = data.adventure[courseId]
			if record and record.done and record.gems == 7 and bit32.band(record.stars, Courses.StarGems) == 0 then
				record.stars = bit32.bor(record.stars, Courses.StarGems)
				data.stats.stars = Courses.TotalStars(data.adventure)
				starNow = true
			end
		end)
		if starNow then
			ProgressService.AddResult(
				player,
				{
					coins = Config.CourseRewards.star,
					xp = Config.CourseXp.star,
					stats = {},
					quest = { stars = 1 },
					quiet = true,
				}
			)
			notify(player, "All 3 gems: +1 star!", "rare")
		end
		notify(
			player,
			string.format(
				"Gem found! (%d/3)",
				(function()
					local count = 0
					for i = 1, 3 do
						if run.savedGems[i] then
							count += 1
						end
					end
					return count
				end)()
			),
			"rare"
		)
	end
end

onFinish = function(run)
	local player = run.player
	if not player then
		return
	end
	local course = run.instance.course
	local courseId = course.id
	local time = run.time
	local valid = not run.skipped and time >= course.par * Config.MinTimeShare
	local result = {
		courseId = courseId,
		name = course.data.name,
		time = time,
		par = course.par,
		skipped = run.skipped,
		newBest = false,
		starsBefore = 0,
		stars = 0,
		newStars = 0,
		firstFinish = false,
		coins = 0,
		xp = 0,
	}
	local worldsBefore = {}
	local data = DataService.Get(player)
	if not data then
		return
	end
	for _, world in ipairs(Worlds.List) do
		worldsBefore[world.id] = AdventureService.WorldUnlocked(data, world.id)
	end

	DataService.Update(player, function(saved)
		local record = saved.adventure[courseId] or { done = false, stars = 0, gems = 0, runs = 0 }
		saved.adventure[courseId] = record
		record.runs = (record.runs or 0) + 1
		result.starsBefore = Courses.CountStars(record.stars)
		result.firstFinish = not record.done
		record.done = true
		if valid then
			local bits = bit32.bor(record.stars, Courses.StarFinish)
			if time <= course.par then
				bits = bit32.bor(bits, Courses.StarTime)
			end
			if gemBits(record) == 7 then
				bits = bit32.bor(bits, Courses.StarGems)
			end
			record.stars = bits
			if not record.best or time < record.best then
				record.best = math.floor(time * 100) / 100
				result.newBest = true
			end
		end
		result.stars = Courses.CountStars(record.stars)
		result.newStars = result.stars - result.starsBefore
		result.best = record.best
		result.gems = gemBits(record)
		saved.stats.stars = Courses.TotalStars(saved.adventure)
	end)

	local coins = Config.CourseRewards.finish + result.newStars * Config.CourseRewards.star
	local xp = Config.CourseXp.finish + result.newStars * Config.CourseXp.star
	if result.firstFinish then
		coins += Config.CourseRewards.firstFinish
		xp += Config.CourseXp.firstFinish
	end
	result.coins, result.xp = ProgressService.AddResult(player, {
		coins = coins,
		xp = xp,
		stats = { courses = 1, falls = run.falls },
		quest = { courses = 1, stars = result.newStars, ["courses_" .. course.world] = 1 },
		quiet = true,
	})
	local nextCourse = Courses.Next(courseId, WORLD_ORDER)
	result.nextCourse = nextCourse and nextCourse.id or nil
	Remotes.Run:FireClient(player, "result", result)
	local celebrate = CosmeticService.Equipped(player, "celebrate")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = root and root.Position or course.finish.lineCFrame.Position
	Remotes.Effect:FireAllClients("finish", at, { effect = celebrate and celebrate.id or nil })
	TutorialService.Event(player, "Finish")

	-- Newly opened worlds
	local after = DataService.Get(player)
	if after then
		for _, world in ipairs(Worlds.List) do
			if not worldsBefore[world.id] and AdventureService.WorldUnlocked(after, world.id) then
				notify(player, world.name .. " is open! Find its gate in the plaza.", "rare")
			end
		end
	end
end

------------------------------------------------------------------ Actions
local function play(player, courseId)
	return AdventureService.Play(player, courseId)
end

local function leave(player)
	if not CourseService.Get(player) then
		return false, "You're not on a course"
	end
	toLobby(player)
	return true
end

local function retry(player)
	local run = CourseService.Get(player)
	if not run or run.mode ~= "adventure" then
		return false, "You're not on a course"
	end
	CourseService.Restart(run)
	return true
end

local function skip(player)
	local run = CourseService.Get(player)
	if not run or run.mode ~= "adventure" then
		return false, "You're not on a course"
	end
	if not CourseService.Skip(run) then
		return false, string.format("The skip appears after %d falls in one section", Config.SkipAfterFalls)
	end
	notify(player, "Skipped ahead. This run won't give stars, but finishing opens the next course.", "info")
	return true
end

------------------------------------------------------------------ World gates
local function findGates()
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("WorldGate") then
			table.insert(gates, { part = item, worldId = item:GetAttribute("WorldGate") })
		end
	end
end

local function gateAt(position)
	for _, gate in ipairs(gates) do
		local offset = gate.part.CFrame:PointToObjectSpace(position)
		local size = gate.part.Size
		if
			math.abs(offset.X) < size.X / 2 + 1
			and math.abs(offset.Z) < size.Z / 2 + 3
			and offset.Y > -size.Y / 2 - 4
			and offset.Y < size.Y / 2
		then
			return gate.worldId
		end
	end
	return nil
end

function AdventureService.Start(lobbySpawn)
	lobbySpawnFn = lobbySpawn
	findGates()
	ProgressService.AddAction("PlayCourse", play)
	ProgressService.AddAction("LeaveCourse", leave)
	ProgressService.AddAction("RetryCourse", retry)
	ProgressService.AddAction("SkipSection", skip)

	Players.PlayerRemoving:Connect(function(player)
		nearGate[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local worldId = root and not CourseService.Get(player) and gateAt(root.Position) or nil
				if worldId ~= nearGate[player] then
					nearGate[player] = worldId
					if worldId then
						local data = DataService.Get(player)
						if data and not AdventureService.WorldUnlocked(data, worldId) then
							local world = Worlds.ById[worldId]
							notify(
								player,
								string.format(
									"%s opens at %d stars. You have %s.",
									world.name,
									world.stars,
									Format.Number(Courses.TotalStars(data.adventure))
								),
								"warning"
							)
						end
						Remotes.OpenPanel:FireClient(player, "Courses", worldId)
						TutorialService.Event(player, "Gate")
					end
				end
			end
		end
	end)
end

return AdventureService
