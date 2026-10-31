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
local ROWS = 10

local function label(props)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.TextWrapped = false
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Font = Enum.Font.GothamMedium
	text.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(props) do
		text[key] = value
	end
	return text
end

-- One face of a board: a title, then a row per rank (rank, name, score) so a
-- long name gets cut short instead of pushing the score onto the next line.
-- Returns a function(title, rows or message).
local function makeBoardFace(boardPart, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = gui
	local title = label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0.16, 0),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Parent = gui,
	})
	local message = label({
		Name = "Message",
		Position = UDim2.new(0, 0, 0.2, 0),
		Size = UDim2.new(1, 0, 0.3, 0),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = "Loading...",
		Parent = gui,
	})
	local rows = {}
	local height = 0.8 / ROWS
	for index = 1, ROWS do
		local y = UDim2.new(0, 0, 0.19 + (index - 1) * height, 0)
		local row = {
			rank = label({
				Position = y,
				Size = UDim2.new(0.12, 0, height * 0.86, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(255, 220, 120),
				Font = Enum.Font.FredokaOne,
				Parent = gui,
			}),
			name = label({
				Position = y + UDim2.new(0.12, 0, 0, 0),
				Size = UDim2.new(0.6, 0, height * 0.86, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = gui,
			}),
			score = label({
				Position = y + UDim2.new(0.74, 0, 0, 0),
				Size = UDim2.new(0.26, 0, height * 0.86, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = Enum.Font.FredokaOne,
				Parent = gui,
			}),
		}
		-- Rows share one text size, so short lines don't come out huge
		for _, text in pairs(row) do
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 34
			limit.Parent = text
		end
		rows[index] = row
	end
	gui.Parent = boardPart
	return function(titleText, content)
		title.Text = titleText
		local list = type(content) == "table" and content or {}
		message.Text = type(content) == "string" and content or ""
		message.Visible = type(content) == "string"
		for index, row in ipairs(rows) do
			local entry = list[index]
			row.rank.Text = entry and (index .. ".") or ""
			row.name.Text = entry and entry.name or ""
			row.score.Text = entry and entry.score or ""
		end
	end
end

-- Boards show the same text on both sides. Returns a function(title, rows or message).
local function makeBoardGui(boardPart)
	local front = makeBoardFace(boardPart, Enum.NormalId.Front)
	local back = makeBoardFace(boardPart, Enum.NormalId.Back)
	return function(title, content)
		front(title, content)
		back(title, content)
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
	local rows = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(rows, { name = nameFor(tonumber(entry.key)), score = Format.Number(entry.value) })
	end
	return #rows > 0 and rows or emptyText
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
		setText("This Week's Crowns  (new week in " .. Format.Duration(weekLeft - os.time()) .. ")", weekly)
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
