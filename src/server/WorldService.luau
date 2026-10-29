-- The plaza: the global leaderboards, and catching players who fall off it.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Quests = require(Shared.Quests)
local Format = require(Shared.Format)

local CourseService = require(script.Parent.CourseService)

local WorldService = {}

local LEADERBOARD_REFRESH = 120
local lobbySpawn = nil

------------------------------------------------------------------ Leaderboards
local function makeBoardFace(boardPart, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Parent = gui
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0.18, 0)
	body.Size = UDim2.new(1, 0, 0.8, 0)
	body.BackgroundTransparency = 1
	body.Text = "Loading..."
	body.TextScaled = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Font = Enum.Font.GothamMedium
	body.TextColor3 = Color3.new(1, 1, 1)
	body.Parent = gui
	gui.Parent = boardPart
	return title, body
end

-- Boards show the same text on both sides. Returns a function(title, text).
local function makeBoardGui(boardPart)
	local frontTitle, frontBody = makeBoardFace(boardPart, Enum.NormalId.Front)
	local backTitle, backBody = makeBoardFace(boardPart, Enum.NormalId.Back)
	return function(title, text)
		frontTitle.Text = title
		backTitle.Text = title
		frontBody.Text = text
		backBody.Text = text
	end
end

local function findStation(name)
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("Station") == name then
			return item
		end
	end
	return nil
end

local nameCache = {}
local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Player " .. userId)
	return nameCache[userId]
end

local function topTen(storeName, emptyText)
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName):GetSortedAsync(false, 10)
	end)
	if not ok then
		return "Leaderboard unavailable right now."
	end
	local lines = {}
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(
			lines,
			string.format("%d. %s  -  %s", rank, nameFor(tonumber(entry.key)), Format.Number(entry.value))
		)
	end
	return #lines > 0 and table.concat(lines, "\n") or emptyText
end

-- The crowns board takes turns showing all-time crowns and this week's crowns
local function runCrownsBoard(boardPart)
	local setText = makeBoardGui(boardPart)
	local allTime, weekly, weekLeft = "Loading...", "Loading...", 0
	task.spawn(function()
		while true do
			local week, left = Quests.Week(os.time())
			allTime = topTen(Config.CrownsStoreName, "No crowns yet. Be the first!")
			weekly = topTen(Config.WeeklyCrownsStorePrefix .. week, "No crowns this week yet!")
			weekLeft = os.time() + left
			task.wait(LEADERBOARD_REFRESH)
		end
	end)
	while true do
		setText("Most Crowns", allTime)
		task.wait(12)
		setText("This Week's Crowns", weekly .. "\n\nNew week in " .. Format.Duration(weekLeft - os.time()))
		task.wait(12)
	end
end

local function runStarsBoard(boardPart)
	local setText = makeBoardGui(boardPart)
	while true do
		setText("Most Stars", topTen(Config.StarsStoreName, "No stars yet. Play a course!"))
		task.wait(LEADERBOARD_REFRESH)
	end
end

function WorldService.Start(spawnFn)
	lobbySpawn = spawnFn
	local crownsBoard = findStation("CrownsBoard")
	if crownsBoard then
		task.spawn(runCrownsBoard, crownsBoard)
	end
	local starsBoard = findStation("StarsBoard")
	if starsBoard then
		task.spawn(runStarsBoard, starsBoard)
	end

	-- Anyone who falls off the plaza comes back to the spawn
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					root
					and root.Position.Y < -40
					and root.Position.X < 1000
					and not CourseService.Get(player)
					and not player:GetAttribute("InTournament")
				then
					character:PivotTo(lobbySpawn())
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

return WorldService
