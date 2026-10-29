-- What you see while on a course: the timer, checkpoints, gems, the Leave /
-- Restart / Skip buttons, and the results card at the finish. Also dresses the
-- sky in the course's world colours (and low gravity in space).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Courses = require(Shared.Courses)
local Worlds = require(Shared.Worlds)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Movement = require(script.Parent.Movement)
local Ghost = require(script.Parent.Ghost)
local T = UI.Theme

local RunHud = {}

local STAR = utf8.char(9733) -- a filled star
local GEM = utf8.char(9670) -- a diamond
local DEFAULT_GRAVITY = 196.2

local run = nil -- the latest summary from the server
local GHOST_CHOICES = { "mine", "record", "off" }
local GHOST_NAMES = { mine = "Ghost: My best", record = "Ghost: Record", off = "Ghost: Off" }
local ghostChoice = "mine"
local ghostButton
local ghostToken = 0
local bar, nameLabel, timerLabel, parLabel, checkpointLabel, gemLabels
local buttons, skipButton
local resultCard, resultBody

------------------------------------------------------------------ Helpers
-- 83.456 -> "1:23.45"
function RunHud.Time(seconds)
	seconds = math.max(0, seconds)
	local whole = math.floor(seconds)
	local hundredths = math.floor((seconds - whole) * 100)
	return string.format("%d:%02d.%02d", math.floor(whole / 60), whole % 60, hundredths)
end

local function act(name, argument)
	local ok, message = State.Action(name, argument)
	if not ok and message then
		Notifications.Show(message, "warning")
	end
	return ok
end

function RunHud.IsOnCourse()
	return run ~= nil
end

------------------------------------------------------------------ World look
local plazaLook = nil
local atmosphere = nil

local function applyWorld(worldId)
	if not plazaLook then
		plazaLook = {
			ambient = Lighting.OutdoorAmbient,
			fogColor = Lighting.FogColor,
			fogEnd = Lighting.FogEnd,
			clock = Lighting.ClockTime,
		}
		atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	end
	local world = worldId and Worlds.ById[worldId]
	local info = TweenInfo.new(1.2)
	if world then
		TweenService:Create(Lighting, info, {
			OutdoorAmbient = world.sky.ambient,
			FogColor = world.sky.fog,
			FogEnd = 2500,
			ClockTime = world.id == "space" and 0 or 14,
		}):Play()
		if atmosphere then
			TweenService:Create(atmosphere, info, { Color = world.sky.top, Decay = world.sky.fog }):Play()
		end
		Workspace.Gravity = world.gravity or DEFAULT_GRAVITY
	else
		TweenService:Create(Lighting, info, {
			OutdoorAmbient = plazaLook.ambient,
			FogColor = plazaLook.fogColor,
			FogEnd = plazaLook.fogEnd,
			ClockTime = plazaLook.clock,
		}):Play()
		if atmosphere then
			TweenService
				:Create(
					atmosphere,
					info,
					{ Color = Color3.fromRGB(199, 220, 255), Decay = Color3.fromRGB(106, 112, 125) }
				)
				:Play()
		end
		Workspace.Gravity = DEFAULT_GRAVITY
	end
end

------------------------------------------------------------------ Ghosts
local function loadGhost()
	ghostToken += 1
	local token = ghostToken
	Ghost.Clear()
	if not run or run.mode ~= "adventure" or ghostChoice == "off" then
		return
	end
	local courseId, origin = run.courseId, run.origin
	task.spawn(function()
		local ok, ghost = pcall(function()
			return Remotes.Ask:InvokeServer("Ghost", { courseId = courseId, which = ghostChoice })
		end)
		if token ~= ghostToken or not run or run.courseId ~= courseId then
			return
		end
		if ok and ghost and typeof(origin) == "CFrame" then
			Ghost.Load(ghost, origin)
			Ghost.SetStart(run.started)
		elseif ghostChoice == "mine" then
			Notifications.Show("No ghost yet: finish this course to make one.", "info")
		end
	end)
end

local function cycleGhost()
	local index = table.find(GHOST_CHOICES, ghostChoice) or 1
	ghostChoice = GHOST_CHOICES[index % #GHOST_CHOICES + 1]
	ghostButton.Text = GHOST_NAMES[ghostChoice]
	loadGhost()
end

------------------------------------------------------------------ The bar
local function refreshBar()
	-- In a tournament race the round bar (TournamentHud) takes the top spot
	bar.Visible = run ~= nil and run.mode ~= "race"
	buttons.Visible = run ~= nil and not resultCard.Visible
	if not run then
		return
	end
	nameLabel.Text = run.name
	checkpointLabel.Text = string.format("Checkpoint %d/%d", run.checkpoint, run.checkpoints)
	parLabel.Text = run.mode == "adventure" and ("Par " .. RunHud.Time(run.par)) or ""
	for index, label in ipairs(gemLabels) do
		local now = run.gems[index]
		local before = run.savedGems[index]
		label.TextColor3 = now and Color3.fromRGB(80, 230, 255)
			or (before and Color3.fromRGB(60, 120, 150) or Color3.fromRGB(70, 80, 100))
	end
	gemLabels[1].Parent.Visible = run.mode == "adventure"
	skipButton.Visible = run.canSkip == true and not run.skipped
	ghostButton.Visible = run.mode == "adventure"
	-- In a tournament the tournament screen has its own Leave button
	buttons.Visible = buttons.Visible and run.mode ~= "race"
	Movement.SetGems({
		run.gems[1] or run.savedGems[1],
		run.gems[2] or run.savedGems[2],
		run.gems[3] or run.savedGems[3],
	})
end

local function buildBar(screenGui)
	bar = UI.new("Frame", {
		Name = "RunBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(420, 92),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screenGui,
	}, { UI.corner(14), UI.stroke(T.Gold, 2) })
	nameLabel = UI.label(
		"",
		{ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 20), TextColor3 = T.Gold, Parent = bar }
	)
	timerLabel =
		UI.label("0:00.00", { Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 38), Parent = bar })
	checkpointLabel = UI.label("", {
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(0.4, 0, 0, 18),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})
	parLabel = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.new(0.3, 0, 0, 18),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		Parent = bar,
	})
	local gemRow = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 64),
		Size = UDim2.fromOffset(78, 22),
		BackgroundTransparency = 1,
		Parent = bar,
	}, { UI.list(4, Enum.FillDirection.Horizontal) })
	gemLabels = {}
	for index = 1, 3 do
		gemLabels[index] = UI.label(GEM, { Size = UDim2.fromOffset(22, 22), LayoutOrder = index, Parent = gemRow })
	end

	-- Left side under the stats; one row on touch screens, above the thumbstick
	buttons = UI.new("Frame", {
		Name = "RunButtons",
		Position = UDim2.fromOffset(16, 166),
		Size = UI.Touch and UDim2.fromOffset(4 * 106, 40) or UDim2.fromOffset(130, 4 * 48),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screenGui,
	}, { UI.list(6, UI.Touch and Enum.FillDirection.Horizontal or nil) })
	local buttonSize = UI.Touch and UDim2.fromOffset(100, 40) or UDim2.fromOffset(130, 42)
	local keys = UserInputService.KeyboardEnabled
	UI.button(keys and "Restart (R)" or "Restart", T.Accent, function()
		act("RetryCourse")
	end, { Size = buttonSize, LayoutOrder = 1, Parent = buttons })
	UI.button("Leave", T.Bad, function()
		act("LeaveCourse")
	end, { Size = buttonSize, LayoutOrder = 2, Parent = buttons })
	skipButton = UI.button("Skip ahead", Color3.fromRGB(170, 100, 255), function()
		act("SkipSection")
	end, { Size = buttonSize, LayoutOrder = 3, Visible = false, Parent = buttons })
	ghostButton = UI.button(GHOST_NAMES[ghostChoice], Color3.fromRGB(90, 110, 150), cycleGhost, {
		Size = buttonSize,
		LayoutOrder = 4,
		Parent = buttons,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and input.KeyCode == Enum.KeyCode.R
			and run
			and (run.mode == "adventure" or run.mode == "daily")
			and not resultCard.Visible
		then
			act("RetryCourse")
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not run then
			return
		end
		if run.finalTime then
			timerLabel.Text = RunHud.Time(run.finalTime)
		elseif run.started then
			local elapsed = Workspace:GetServerTimeNow() - run.started
			timerLabel.Text = RunHud.Time(elapsed)
			timerLabel.TextColor3 = (run.mode == "adventure" and elapsed > run.par) and Color3.fromRGB(255, 170, 120)
				or T.Text
		else
			timerLabel.Text = RunHud.Time(0)
			timerLabel.TextColor3 = T.Text
		end
	end)
end

------------------------------------------------------------------ Results
local showDailyResult

local function showResult(result)
	if result.mode == "daily" then
		showDailyResult(result)
		return
	end
	UI.clear(resultBody)
	UI.list(6).Parent = resultBody
	resultBody:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	UI.label(
		result.skipped and "Finished (skipped)" or "Course complete!",
		{ Size = UDim2.new(1, 0, 0, 36), TextColor3 = T.Gold, LayoutOrder = nextOrder(), Parent = resultBody }
	)
	UI.label(result.name, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		LayoutOrder = nextOrder(),
		Parent = resultBody,
	})

	-- Three stars, the new ones pop in
	local starRow = UI.new(
		"Frame",
		{ Size = UDim2.fromOffset(200, 60), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = resultBody },
		{ UI.list(10, Enum.FillDirection.Horizontal) }
	)
	starRow:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	for index = 1, 3 do
		local have = index <= result.stars
		local star = UI.label(STAR, {
			Size = UDim2.fromOffset(56, 56),
			TextColor3 = have and T.Gold or Color3.fromRGB(70, 80, 100),
			LayoutOrder = index,
			Parent = starRow,
		})
		if have and index > result.starsBefore then
			local scale = UI.new("UIScale", { Scale = 0.1, Parent = star })
			task.delay(0.25 * (index - result.starsBefore), function()
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end)
		end
	end
	local why = {}
	table.insert(why, "Finish")
	table.insert(why, "Beat par " .. RunHud.Time(result.par))
	local gems = 0
	for index = 0, 2 do
		gems += bit32.band(bit32.rshift(result.gems or 0, index), 1)
	end
	table.insert(why, string.format("All 3 gems (%d/3)", gems))
	UI.label(table.concat(why, "   " .. STAR .. "   "), {
		Size = UDim2.new(1, 0, 0, 18),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		LayoutOrder = nextOrder(),
		Parent = resultBody,
	})

	local timeText = "Time " .. RunHud.Time(result.time)
	if result.newBest then
		timeText ..= "  -  New best!"
	elseif result.best then
		timeText ..= "  -  Best " .. RunHud.Time(result.best)
	end
	UI.label(timeText, {
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = result.newBest and T.Good or T.Text,
		LayoutOrder = nextOrder(),
		Parent = resultBody,
	})
	if result.skipped then
		UI.label("Skipped runs don't give stars. Try again without skipping!", {
			Size = UDim2.new(1, 0, 0, 18),
			Font = T.BodyFont,
			TextColor3 = T.Muted,
			LayoutOrder = nextOrder(),
			Parent = resultBody,
		})
	end
	UI.label(
		string.format("+%s coins   +%s XP", Format.Number(result.coins or 0), Format.Number(result.xp or 0)),
		{ Size = UDim2.new(1, 0, 0, 26), TextColor3 = T.Gold, LayoutOrder = nextOrder(), Parent = resultBody }
	)

	local row = UI.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = resultBody },
		{ UI.list(10, Enum.FillDirection.Horizontal) }
	)
	row:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function close()
		resultCard.Visible = false
		refreshBar()
	end
	local nextCourse = result.nextCourse and Courses.ById[result.nextCourse]
	if nextCourse and State.data and Courses.Unlocked(State.data.adventure, nextCourse.id) then
		UI.button("Next: " .. nextCourse.name, T.Good, function()
			close()
			act("PlayCourse", nextCourse.id)
		end, { Size = UDim2.fromOffset(220, 44), LayoutOrder = 1, Parent = row })
	end
	UI.button("Play again", T.Accent, function()
		close()
		act("PlayCourse", result.courseId)
	end, { Size = UDim2.fromOffset(150, 44), LayoutOrder = 2, Parent = row })
	UI.button("Plaza", T.Card, function()
		close()
		act("LeaveCourse")
	end, { Size = UDim2.fromOffset(110, 44), LayoutOrder = 3, Parent = row })

	resultCard.Visible = true
	refreshBar()
end

-- The buttons under a result: each is { text, color, width, onClick }
local function resultButtons(order, list)
	local row = UI.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = order, Parent = resultBody },
		{ UI.list(10, Enum.FillDirection.Horizontal) }
	)
	row:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	for index, info in ipairs(list) do
		UI.button(info[1], info[2], function()
			resultCard.Visible = false
			refreshBar()
			info[4]()
		end, { Size = UDim2.fromOffset(info[3], 44), LayoutOrder = index, Parent = row })
	end
end

showDailyResult = function(result)
	UI.clear(resultBody)
	UI.list(8).Parent = resultBody
	resultBody:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	UI.label(
		"Daily Challenge",
		{ Size = UDim2.new(1, 0, 0, 36), TextColor3 = T.Gold, LayoutOrder = 1, Parent = resultBody }
	)
	UI.label(result.name, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		LayoutOrder = 2,
		Parent = resultBody,
	})
	local timeText = "Time " .. RunHud.Time(result.time)
	if result.newBest then
		timeText ..= "  -  Your best today!"
	elseif result.best then
		timeText ..= "  -  Today's best " .. RunHud.Time(result.best)
	end
	UI.label(timeText, {
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = result.newBest and T.Good or T.Text,
		LayoutOrder = 3,
		Parent = resultBody,
	})
	UI.label(
		result.skipped and "Skipped runs don't count for the board."
			or "A new course every day. Beat your time and climb the board!",
		{
			Size = UDim2.new(1, 0, 0, 20),
			Font = T.BodyFont,
			TextColor3 = T.Muted,
			LayoutOrder = 4,
			Parent = resultBody,
		}
	)
	UI.label(
		string.format("+%s coins   +%s XP", Format.Number(result.coins or 0), Format.Number(result.xp or 0)),
		{ Size = UDim2.new(1, 0, 0, 28), TextColor3 = T.Gold, LayoutOrder = 5, Parent = resultBody }
	)
	resultButtons(6, {
		{
			"Try again",
			T.Accent,
			160,
			function()
				act("PlayDaily")
			end,
		},
		{
			"Plaza",
			T.Card,
			110,
			function()
				act("LeaveCourse")
			end,
		},
	})
	resultCard.Visible = true
	refreshBar()
end

local function buildResult(screenGui)
	resultCard = UI.new("Frame", {
		Name = "ResultCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(560, 360),
		BackgroundColor3 = T.Panel,
		Visible = false,
		Active = true,
		ZIndex = 5,
		Parent = screenGui,
	}, { UI.corner(16), UI.stroke(T.Gold, 3) })
	resultBody = UI.new("Frame", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 1, -28),
		BackgroundTransparency = 1,
		Parent = resultCard,
	})
end

------------------------------------------------------------------ Start
function RunHud.Init(screenGui)
	buildBar(screenGui)
	buildResult(screenGui)

	Remotes.Run.OnClientEvent:Connect(function(event, info)
		if event == "enter" then
			run = info
			resultCard.Visible = false
			applyWorld(info.world)
			loadGhost()
		elseif event == "update" then
			if run then
				local finalTime = run.finalTime
				run = info
				run.finalTime = info.finished and (finalTime or info.time) or nil
			else
				run = info
			end
			Ghost.SetStart(run.started)
		elseif event == "leave" then
			run = nil
			resultCard.Visible = false
			applyWorld(nil)
			Movement.SetGems({})
			ghostToken += 1
			Ghost.Clear()
		elseif event == "result" then
			if run then
				run.finalTime = info.time
			end
			showResult(info)
		end
		refreshBar()
	end)
end

return RunHud
