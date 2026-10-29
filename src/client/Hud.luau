-- Always-on screen info: level, coins, stars and crowns, the tournament queue
-- banner and the menu buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Level = require(Shared.Level)
local Format = require(Shared.Format)
local Courses = require(Shared.Courses)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Panels = require(script.Parent.Panels)
local RunHud = require(script.Parent.RunHud)
local T = UI.Theme

local Hud = {}

local player = Players.LocalPlayer
local STAR = utf8.char(9733)

function Hud.Init(screenGui)
	-- Stats, top left
	local stats = UI.new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.fromOffset(230, 96),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { UI.corner(12), UI.padding(10), UI.list(4) })
	local levelLine = UI.label("Lv 1 Runner", {
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Color3.fromRGB(150, 220, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = stats,
	})
	local xpBack = UI.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = T.Card, LayoutOrder = 2, Parent = stats },
		{ UI.corner(3) }
	)
	local xpFill = UI.new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(150, 220, 255), Parent = xpBack },
		{ UI.corner(3) }
	)
	local coins = UI.label("0 coins", {
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = T.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		Parent = stats,
	})
	local record = UI.label("", {
		Size = UDim2.new(1, 0, 0, 16),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 4,
		Parent = stats,
	})

	local function update(data)
		local progress, level = Level.Progress(data.xp or 0)
		levelLine.Text = string.format("Lv %d Runner", level)
		xpFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		coins.Text = Format.Number(data.coins) .. " coins"
		record.Text = string.format(
			"%s %s stars  -  %s crowns",
			STAR,
			Format.Number(Courses.TotalStars(data.adventure)),
			Format.Number(data.stats.crowns)
		)
	end
	State.Changed:Connect(update)
	if State.data then
		update(State.data)
	end

	-- Queue banner, top center, while you stand on a tournament pad
	local queueBanner = UI.new("Frame", {
		Name = "QueueBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(520, 56),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screenGui,
	}, { UI.corner(12), UI.stroke(T.Gold, 2), UI.padding(6), UI.list(2) })
	local queueLine = UI.label("", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = T.Gold, Parent = queueBanner })
	UI.label(
		"Step off the pad to leave the queue",
		{ Size = UDim2.new(1, 0, 0, 16), Font = T.BodyFont, TextColor3 = T.Muted, Parent = queueBanner }
	)

	-- Menu buttons, left side under the stats, with keyboard shortcuts
	local menu = UI.new("Frame", {
		Name = "Menu",
		Position = UDim2.fromOffset(16, 166),
		Size = UDim2.fromOffset(130, 5 * 48),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, { UI.list(6) })
	local buttons = {
		{ "Courses", "Courses", Color3.fromRGB(255, 120, 180), Enum.KeyCode.C },
		{ "Shop", "Shop", Color3.fromRGB(70, 200, 110), Enum.KeyCode.P },
		{ "Locker", "Locker", Color3.fromRGB(90, 140, 220), Enum.KeyCode.L },
		{ "Quests", "Quests", Color3.fromRGB(200, 150, 70), Enum.KeyCode.N },
	}
	local shortcuts = {}
	for index, info in ipairs(buttons) do
		local keyName = UserInputService.KeyboardEnabled and (" (" .. info[4].Name .. ")") or ""
		UI.button(info[1] .. keyName, info[3], function()
			Panels[info[2]].toggle()
		end, { Size = UDim2.fromOffset(130, 42), LayoutOrder = index, Parent = menu })
		shortcuts[info[4]] = info[2]
	end

	-- On a course or in a tournament the course bar and its buttons take over
	task.spawn(function()
		while true do
			local busy = RunHud.IsOnCourse() or player:GetAttribute("InTournament") ~= nil
			menu.Visible = not busy
			local pad = player:GetAttribute("QueuePad")
			queueBanner.Visible = pad ~= nil and not busy
			if pad then
				queueLine.Text = ReplicatedStorage:GetAttribute("PadStatus" .. pad) or "Waiting..."
			end
			task.wait(0.2)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or RunHud.IsOnCourse() then
			return
		end
		local panel = shortcuts[input.KeyCode]
		if panel then
			Panels[panel].toggle()
		end
	end)
end

return Hud
