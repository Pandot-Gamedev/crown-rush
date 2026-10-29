-- Crown Rush server. Starts every service in order.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Courses = require(Shared.Courses)

local MapBuilder = require(script.MapBuilder)
local DataService = require(script.DataService)
local ShopService = require(script.ShopService)
local CosmeticService = require(script.CosmeticService)
local TutorialService = require(script.TutorialService)
local ProgressService = require(script.ProgressService)
local CourseService = require(script.CourseService)
local AdventureService = require(script.AdventureService)
local WorldService = require(script.WorldService)

-- Players' screens can't check who owns a private server, so share it
if game.PrivateServerId ~= "" then
	game:GetService("ReplicatedStorage"):SetAttribute("PrivateServerOwnerId", game.PrivateServerOwnerId)
end

MapBuilder.Build()

local random = Random.new()
local function lobbySpawn()
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawnLocation and spawnLocation.CFrame or CFrame.new(0, 3, 60)
	return base * CFrame.new(random:NextNumber(-4, 4), 3.5, random:NextNumber(-4, 4))
end

-- Services that react to players loading must start before DataService
ShopService.Start()
CosmeticService.Start()
TutorialService.Start()
ProgressService.Start()
CourseService.Start()
AdventureService.Start(lobbySpawn)
WorldService.Start(lobbySpawn)
DataService.Start()

-- Test helpers for Roblox Studio only (never in the live game). In the command
-- bar, with the Server view selected:
--   game.ServerStorage.CrownRushTest:Invoke("coins", 5000)
--   game.ServerStorage.CrownRushTest:Invoke("xp", 10000)
--   game.ServerStorage.CrownRushTest:Invoke("course", "candy_3") -- play any course, locked or not
--   game.ServerStorage.CrownRushTest:Invoke("unlock") -- finish every course (3 stars each)
--   game.ServerStorage.CrownRushTest:Invoke("checkpoint", 2) -- jump to a checkpoint on your course
if RunService:IsStudio() then
	local test = Instance.new("BindableFunction")
	test.Name = "CrownRushTest"
	test.OnInvoke = function(command, amount)
		local player = Players:GetPlayers()[1]
		if command == "course" then
			local course = Courses.ById[amount]
			if not course or not player then
				return "unknown course"
			end
			local instance = CourseService.Open(course)
			CourseService.Enter(player, instance, { mode = "adventure" })
			return "ok"
		elseif command == "checkpoint" then
			local run = player and CourseService.Get(player)
			local checkpoint = run and run.instance.course.checkpoints[amount]
			if checkpoint then
				run.checkpoint = amount
				player.Character:PivotTo(checkpoint.spawn)
				player:SetAttribute("KillY", checkpoint.killY)
				run.killY = checkpoint.killY
			end
			return "ok"
		end
		for _, each in ipairs(Players:GetPlayers()) do
			DataService.Update(each, function(data)
				if command == "coins" then
					data.coins += amount
				elseif command == "xp" then
					data.xp += amount
				elseif command == "unlock" then
					for _, course in ipairs(Courses.List) do
						data.adventure[course.id] = { done = true, stars = 7, gems = 7, runs = 1, best = 60 }
					end
					data.stats.stars = Courses.TotalStars(data.adventure)
				end
			end)
		end
		return "ok"
	end
	test.Parent = game:GetService("ServerStorage")
end

print("[" .. Config.GameName .. "] Server ready")
