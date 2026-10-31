-- What you see in a tournament: the round intro card, 3-2-1-GO, the round
-- bar (timer and how many go through), the big QUALIFIED / ELIMINATED / CROWN
-- banners, the end card with your rewards, and the watch mode that follows
-- the runners still in once you're out.
--
-- Being knocked out: the screen flashes red with a big ELIMINATED and why
-- (who took the last spot, who bonked you off...) the moment it happens.
-- You see the rest of that round, then the camera follows the runners still
-- in, and your result card comes when the tournament ends or you stop watching.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Effects = require(script.Parent.Effects)
local T = UI.Theme

local TournamentHud = {}

local player = Players.LocalPlayer
local CROWN = utf8.char(9819) -- a chess queen, the closest thing to a crown in every font

local KIND_NAMES =
	{ race = "RACE", survival = "SURVIVAL", final = "FINAL", fight = "FIGHT", objective = "POINTS", team = "TEAM" }
local KIND_COLORS = {
	race = Color3.fromRGB(60, 170, 255),
	survival = Color3.fromRGB(255, 140, 60),
	final = T.Gold,
	fight = Color3.fromRGB(230, 80, 80),
	objective = Color3.fromRGB(80, 230, 255),
	team = Color3.fromRGB(150, 110, 255),
}

local roundBar, roundTitle, roundTimer, roundStatus, roundYou
local introCard, introKind, introName, introBlurb, introKeep
local countdownLabel, banner, bannerSub, outFlash
local endCard, endTitle, endBody, endButtons
local leaveButton, watchBar, watchName, watchResult

local pendingResult = nil -- your result, shown once you stop watching

local endsAt = nil
local goAt = nil
local roundText = ""
local watchingKey = nil
local watchedModel = nil

local function act(name, argument)
	local ok, message = State.Action(name, argument)
	if not ok and message then
		Notifications.Show(message, "warning")
	end
	return ok, message
end

local function ordinal(n)
	local last = n % 10
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = last == 1 and "st" or last == 2 and "nd" or last == 3 and "rd" or "th"
	end
	return n .. suffix
end

------------------------------------------------------------------ Big text
local bannerToken = 0
local function showBanner(text, sub, color, seconds, size)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color or T.Gold
	bannerSub.Text = sub or ""
	banner.Visible = true
	bannerSub.Visible = sub ~= nil
	local scale = banner:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.4
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = size or 1 }):Play()
	task.delay(seconds or 3, function()
		if bannerToken == token then
			banner.Visible = false
			bannerSub.Visible = false
		end
	end)
end

------------------------------------------------------------------ Watching
local function findRunner(key)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if character and character:GetAttribute("Runner") == key then
			return character
		end
	end
	local bots = Workspace:FindFirstChild("Bots")
	for _, model in ipairs(bots and bots:GetChildren() or {}) do
		if model:GetAttribute("Runner") == key then
			return model
		end
	end
	return nil
end

local function cameraHome()
	local camera = Workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
end

local watchToken = 0
local function watch(direction)
	watchToken += 1
	local token = watchToken
	local ok, key = State.Action("Spectate", direction)
	if token ~= watchToken then
		return
	end
	if not ok then
		watchingKey = nil
		watchedModel = nil
		watchName.Text = key or "Nobody to watch right now"
		cameraHome()
		return
	end
	watchingKey = key
	-- The runner can take a moment to load in
	for _ = 1, 30 do
		local model = findRunner(key)
		if model then
			watchedModel = model
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			Workspace.CurrentCamera.CameraSubject = humanoid or model.PrimaryPart
			local owner = Players:GetPlayerFromCharacter(model)
			watchName.Text = "Watching " .. (owner and owner.DisplayName or model.Name)
			return
		end
		task.wait(0.1)
		if token ~= watchToken then
			return
		end
	end
	watchName.Text = "Loading..."
end

local function stopWatching()
	watchToken += 1
	watchingKey = nil
	watchedModel = nil
	cameraHome()
end

------------------------------------------------------------------ Building
local function build(screenGui)
	-- Round bar, top center: kept small so it doesn't cover the course.
	-- Round name on the left and the timer on the right, then the status line.
	roundBar = UI.new("Frame", {
		Name = "RoundBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(400, 56),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = screenGui,
	}, { UI.corner(12), UI.stroke(T.Gold, 1.5) })
	roundTitle = UI.label("", {
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -90, 0, 22),
		TextColor3 = T.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = roundBar,
	})
	roundTimer = UI.label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 3),
		Size = UDim2.fromOffset(70, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = roundBar,
	})
	roundStatus = UI.label("", {
		Position = UDim2.fromOffset(12, 31),
		Size = UDim2.new(1, -24, 0, 18),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		Parent = roundBar,
	})
	-- Your own line (score, team, tail) under the status, when a round has one
	roundYou = UI.label("", {
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 0, 18),
		TextColor3 = T.Text,
		Visible = false,
		Parent = roundBar,
	})

	-- Intro card, middle of the screen
	introCard = UI.new("Frame", {
		Name = "RoundIntro",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(460, 196),
		BackgroundColor3 = T.Panel,
		Visible = false,
		Parent = screenGui,
	}, { UI.corner(18), UI.stroke(T.Gold, 3), UI.padding(16), UI.list(8), UI.new("UIScale") })
	introKind = UI.label("", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = introCard })
	introName = UI.label("", { Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 2, Parent = introCard })
	introBlurb = UI.label("", {
		Size = UDim2.new(1, 0, 0, 44),
		Font = T.BodyFont,
		TextWrapped = true,
		LayoutOrder = 3,
		Parent = introCard,
	})
	introKeep =
		UI.label("", { Size = UDim2.new(1, 0, 0, 26), TextColor3 = T.Gold, LayoutOrder = 4, Parent = introCard })

	-- 3-2-1-GO
	countdownLabel = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(220, 120),
		TextStrokeTransparency = 0,
		Visible = false,
		Parent = screenGui,
	})

	-- Banners: QUALIFIED!, OUT!, the winner
	-- A red flash over the whole screen the moment you're out
	outFlash = UI.new("Frame", {
		Name = "OutFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Bad,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screenGui,
	})

	-- Banners sit high, above the runner, and go quickly
	banner = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(560, 64),
		TextStrokeTransparency = 0,
		Visible = false,
		Parent = screenGui,
	})
	UI.new("UIScale", { Parent = banner })
	bannerSub = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.24, 36),
		Size = UDim2.fromOffset(640, 28),
		Font = T.Font,
		TextStrokeTransparency = 0.3,
		Visible = false,
		Parent = screenGui,
	})

	-- End card: your result and rewards
	endCard = UI.new("Frame", {
		Name = "TournamentEnd",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 280),
		BackgroundColor3 = T.Panel,
		Visible = false,
		Active = true,
		ZIndex = 5,
		Parent = screenGui,
	}, { UI.corner(18), UI.stroke(T.Gold, 3), UI.padding(16), UI.list(10) })
	endTitle = UI.label("", { Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1, ZIndex = 5, Parent = endCard })
	endBody = UI.label("", {
		Size = UDim2.new(1, 0, 0, 120),
		Font = T.BodyFont,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 22,
		LayoutOrder = 2,
		ZIndex = 5,
		Parent = endCard,
	})
	endButtons = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 5,
		Parent = endCard,
	}, { UI.list(10, Enum.FillDirection.Horizontal) })
	endButtons:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Leave, bottom left
	local confirmUntil = 0
	leaveButton = UI.button("Leave tournament", T.Bad, function()
		if os.clock() > confirmUntil then
			confirmUntil = os.clock() + 3
			leaveButton.Text = "Tap again to leave"
			task.delay(3, function()
				leaveButton.Text = "Leave tournament"
			end)
			return
		end
		confirmUntil = 0
		leaveButton.Text = "Leave tournament"
		act("LeaveTournament")
	end, {
		-- bottom left, or under the stats on touch screens (the thumbstick lives bottom left)
		AnchorPoint = UI.Touch and Vector2.new(1, 0) or Vector2.new(0, 1),
		Position = UI.Touch and UDim2.new(1, -16, 0, 166) or UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(180, 44),
		Visible = false,
		Parent = screenGui,
	})

	-- Your result, just above the watch bar while you watch the rest
	watchResult = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.fromOffset(520, 26),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.3,
		TextColor3 = T.Bad,
		Visible = false,
		Parent = screenGui,
	})
	UI.corner(8).Parent = watchResult

	-- Watch bar, bottom center
	watchBar = UI.new("Frame", {
		Name = "WatchBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(520, 56),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screenGui,
	}, { UI.corner(12), UI.padding(6) })
	UI.button("<", T.Accent, function()
		task.spawn(watch, "prev")
	end, { Size = UDim2.fromOffset(44, 44), Parent = watchBar })
	watchName = UI.label("", {
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -250, 1, 0),
		Parent = watchBar,
	})
	UI.button(">", T.Accent, function()
		task.spawn(watch, "next")
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 0),
		Size = UDim2.fromOffset(44, 44),
		Parent = watchBar,
	})
	UI.button("Stop watching", T.Bad, function()
		stopWatching()
		act("LeaveTournament")
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(140, 44),
		Parent = watchBar,
	})
end

local function closeEnd()
	endCard.Visible = false
end

local function showEnd(title, color, body, withWatch, okText)
	endTitle.Text = title
	endTitle.TextColor3 = color
	endBody.Text = body
	UI.clear(endButtons)
	UI.list(10, Enum.FillDirection.Horizontal).Parent = endButtons
	endButtons:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	if withWatch then
		UI.button("Watch the rest", T.Accent, function()
			closeEnd()
			task.spawn(watch, "next")
		end, { Size = UDim2.fromOffset(180, 44), ZIndex = 5, Parent = endButtons })
		UI.button("Back to plaza", T.Good, function()
			closeEnd()
			stopWatching()
			act("LeaveTournament")
		end, { Size = UDim2.fromOffset(180, 44), ZIndex = 5, Parent = endButtons })
	else
		UI.button(
			okText or "Nice!",
			T.Good,
			closeEnd,
			{ Size = UDim2.fromOffset(180, 44), ZIndex = 5, Parent = endButtons }
		)
	end
	endCard.Visible = true
end

local function rewardLine(info)
	return string.format("+%s coins   +%s XP", Format.Number(info.coins or 0), Format.Number(info.xp or 0))
end

------------------------------------------------------------------ Events
local handlers = {}

function handlers.start(info)
	closeEnd()
	pendingResult = nil
	local bots = info.bots > 0 and string.format(" and %d bots", info.bots) or ""
	Notifications.Show(string.format("Tournament on! %d players%s", info.players, bots), "info")
end

function handlers.intro(info)
	endsAt = nil
	roundText = string.format("Round %d/%d  -  %s", info.number, info.total, info.name)
	roundStatus.Text = ""
	roundYou.Text = ""
	roundYou.Visible = false
	roundYou.TextColor3 = T.Text
	introKind.Text = string.format("ROUND %d of %d:  %s", info.number, info.total, KIND_NAMES[info.kind] or "")
	introKind.TextColor3 = KIND_COLORS[info.kind] or T.Accent
	introName.Text = info.name
	introBlurb.Text = info.blurb or ""
	introKeep.Text = info.kind == "final" and (CROWN .. "  One crown. Grab it first!  " .. CROWN)
		or string.format("%d runners, %d go through", info.count, info.keep)
	introCard.Visible = true
	local scale = introCard:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(4.6, function()
		introCard.Visible = false
	end)
end

-- Your score or job in this round
function handlers.you(info)
	roundYou.Text = info.text or ""
	roundYou.Visible = info.text ~= nil and info.text ~= ""
end

function handlers.team(info)
	roundYou.Text = "You're on the " .. info.name .. " team"
	roundYou.TextColor3 = info.color
	roundYou.Visible = true
	showBanner(string.upper(info.name) .. " TEAM", "Score the most on your team to be safe!", info.color, 3)
end

function handlers.flash(info)
	showBanner(info.text, nil, T.Gold, 2)
end

function handlers.countdown(info)
	introCard.Visible = false
	goAt = info.goAt
end

function handlers.timer(info)
	endsAt = info.endsAt
	roundStatus.Text = info.text or ""
end

function handlers.status(info)
	if info.text ~= "" then
		roundStatus.Text = info.text
	end
end

function handlers.qualified(info)
	local timeText = info.time and string.format("  (%.2fs)", info.time) or ""
	showBanner("QUALIFIED!", ordinal(info.place) .. timeText, T.Good, 2.5)
	Effects.Sound("ding")
end

function handlers.crown(_info)
	showBanner(CROWN .. " YOU GOT THE CROWN! " .. CROWN, nil, T.Gold, 4)
	Effects.Sound("win")
end

-- You're out: make it impossible to miss, and say why
function handlers.out(info)
	local place = info.place and info.of and string.format("%s of %d", ordinal(info.place), info.of) or nil
	showBanner("ELIMINATED!", info.reason or place, T.Bad, 5, 1.35)
	Effects.Sound("fall")
	outFlash.Visible = true
	outFlash.BackgroundTransparency = 0.4
	local tween = TweenService:Create(outFlash, TweenInfo.new(1.6), { BackgroundTransparency = 1 })
	tween.Completed:Connect(function()
		outFlash.Visible = false
	end)
	tween:Play()
end

local function resultCard(info)
	local rounds = info.rounds == 1 and "1 round" or (info.rounds .. " rounds")
	showEnd(
		"Eliminated",
		T.Bad,
		string.format(
			"You came %s of %d and survived %s.\n%s\n\nHead back and queue again!",
			ordinal(info.place),
			info.of,
			rounds,
			rewardLine(info)
		),
		false,
		"OK"
	)
end

-- Back from the round: follow the runners still in (no clicking needed);
-- the result card waits until you stop watching
function handlers.eliminated(info)
	endsAt = nil
	if info.watchable then
		pendingResult = info
		watchResult.Text = string.format(
			"You're out: %s of %d   %s   Now watching the rest",
			ordinal(info.place),
			info.of,
			rewardLine(info)
		)
		task.spawn(watch, "next")
	else
		resultCard(info)
	end
end

function handlers.winner(info)
	endsAt = nil
	if info.userId ~= player.UserId then
		showBanner(
			CROWN .. " " .. info.name .. " wins the crown! " .. CROWN,
			info.bot and "A bot this time. Get them next round!" or nil,
			T.Gold,
			5
		)
	end
end

function handlers.champion(info)
	stopWatching()
	showEnd(CROWN .. " CHAMPION! " .. CROWN, T.Gold, "You won the tournament crown!\n" .. rewardLine(info), false)
	Effects.Sound("win")
end

------------------------------------------------------------------ Start
function TournamentHud.Init(screenGui)
	build(screenGui)

	Remotes.Announce.OnClientEvent:Connect(function(kind, info)
		local handler = handlers[kind]
		if handler then
			handler(info or {})
		end
	end)

	local lastShown = nil
	RunService.RenderStepped:Connect(function()
		local inTournament = player:GetAttribute("InTournament") ~= nil
		local watching = player:GetAttribute("Watching") ~= nil
		roundBar.Visible = inTournament or (watching and watchingKey ~= nil)
		leaveButton.Visible = inTournament
		watchBar.Visible = watching and not inTournament and not endCard.Visible
		watchResult.Visible = watchBar.Visible and pendingResult ~= nil
		roundTitle.Text = roundText
		roundBar.Size = UDim2.fromOffset(400, roundYou.Visible and 74 or 56)
		local now = Workspace:GetServerTimeNow()

		if endsAt then
			local left = math.max(0, endsAt - now)
			roundTimer.Text = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
			roundTimer.TextColor3 = left < 10 and T.Bad or T.Text
		else
			roundTimer.Text = ""
		end

		if goAt and (inTournament or watching) then
			local left = goAt - now
			local shown = left > 0 and tostring(math.ceil(left)) or "GO!"
			if left < -0.8 then
				goAt = nil
				shown = nil
			end
			countdownLabel.Visible = shown ~= nil
			if shown and shown ~= lastShown then
				countdownLabel.Text = shown
				countdownLabel.TextColor3 = shown == "GO!" and T.Good or T.Gold
				Effects.Sound(shown == "GO!" and "boing" or "ding")
			end
			lastShown = shown
		else
			countdownLabel.Visible = false
			lastShown = nil
		end

		-- The runner we follow got knocked out: follow the next one
		if watching and watchedModel then
			if not watchedModel.Parent or watchedModel:GetAttribute("Tournament") == nil then
				watchedModel = nil
				task.spawn(watch, "next")
			end
		end
	end)

	player:GetAttributeChangedSignal("Watching"):Connect(function()
		if player:GetAttribute("Watching") == nil then
			stopWatching()
			-- Done watching (the tournament ended, or you left): now your result
			if pendingResult then
				local info = pendingResult
				pendingResult = nil
				task.delay(1.5, resultCard, info)
			end
		end
	end)
	player:GetAttributeChangedSignal("InTournament"):Connect(function()
		if player:GetAttribute("InTournament") == nil then
			goAt = nil
			introCard.Visible = false
			if player:GetAttribute("Watching") == nil then
				endsAt = nil
			end
		end
	end)
end

return TournamentHud
