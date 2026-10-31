-- Big round DASH and BONK buttons for phones and tablets, placed around
-- Roblox's own jump button so the right thumb can reach all three. DASH sits
-- just left of jump (jump, then slide over to dash); BONK sits above jump and
-- only shows while you hold a foam hammer. They fill up from the bottom while
-- the move recharges. Hold BONK to keep swinging.
-- They live inside Roblox's touch controls, so they hide whenever those hide.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)
local Controls = require(script.Parent.Controls)
local T = UI.Theme

local TouchButtons = {}

local player = Players.LocalPlayer

-- size and offset are in jump-button sizes, measured from the jump button's center
local LAYOUT = {
	dive = { text = "DASH", color = Color3.fromRGB(60, 170, 255), size = 1.05, offset = Vector2.new(-1.3, -0.15) },
	bonk = { text = "BONK", color = Color3.fromRGB(255, 90, 60), size = 1.25, offset = Vector2.new(-0.35, -1.4) },
}

local function makeButton(info)
	local button = UI.new("TextButton", {
		Name = "CrownRush" .. info.text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		Text = info.text,
		TextColor3 = T.Text,
		TextStrokeTransparency = 0.4,
		Font = T.Font,
		TextScaled = true,
		AutoButtonColor = false,
		Active = true,
	}, {
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UI.new("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = 3,
			Transparency = 0.2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0.3, 0),
			PaddingBottom = UDim.new(0.3, 0),
			PaddingLeft = UDim.new(0.14, 0),
			PaddingRight = UDim.new(0.14, 0),
		}),
		UI.new("UITextSizeConstraint", { MaxTextSize = 30 }),
	})
	local fill = UI.new("UIGradient", { Rotation = -90, Parent = button })
	local press = UI.new("UIScale", { Parent = button })
	return button, fill, press
end

-- Colors the button up to `ready` (0 to 1) from the bottom; the rest is dim
local function setFill(fill, color, ready)
	local dim = color:Lerp(Color3.fromRGB(30, 30, 40), 0.65)
	if ready >= 1 then
		fill.Color = ColorSequence.new(color)
	elseif ready <= 0 then
		fill.Color = ColorSequence.new(dim)
	else
		fill.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(ready, color),
			ColorSequenceKeypoint.new(math.min(ready + 0.001, 1), dim),
			ColorSequenceKeypoint.new(1, dim),
		})
	end
end

function TouchButtons.Init()
	if not UI.Touch then
		return
	end
	local buttons = {}
	local holdingBonk = false

	local held = {} -- [touch] = button id, for fingers still on a button
	for id, info in pairs(LAYOUT) do
		local button, fill, press = makeButton(info)
		buttons[id] = { button = button, fill = fill, press = press, info = info }
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseButton1
			then
				return
			end
			held[input] = id
			press.Scale = 0.88
			if id == "bonk" then
				holdingBonk = true
				Controls.Bonk()
			else
				Controls.Dive()
			end
		end)
	end
	-- A finger can slide off the button before it lifts, so watch every touch end
	UserInputService.InputEnded:Connect(function(input)
		local id = held[input]
		if not id then
			return
		end
		held[input] = nil
		buttons[id].press.Scale = 1
		if id == "bonk" then
			holdingBonk = false
			for _, other in pairs(held) do
				if other == "bonk" then
					holdingBonk = true
				end
			end
		end
	end)

	-- Sit the buttons around the jump button whenever Roblox (re)builds it
	local frame, jump = nil, nil
	local function place()
		if not frame or not jump or not jump.Parent then
			return
		end
		local size = jump.AbsoluteSize.X
		if size <= 0 then
			return
		end
		local center = jump.AbsolutePosition + jump.AbsoluteSize / 2 - frame.AbsolutePosition
		for _, entry in pairs(buttons) do
			local info = entry.info
			local spot = center + info.offset * size
			entry.button.Size = UDim2.fromOffset(size * info.size, size * info.size)
			entry.button.Position = UDim2.fromOffset(spot.X, spot.Y)
			entry.button.Parent = frame
		end
	end
	local watching = {}
	local function watchJump(button)
		jump = button
		for _, connection in ipairs(watching) do
			connection:Disconnect()
		end
		watching = {
			button:GetPropertyChangedSignal("AbsolutePosition"):Connect(place),
			button:GetPropertyChangedSignal("AbsoluteSize"):Connect(place),
		}
		place()
	end
	-- Roblox only makes its touch controls (TouchGui) on touch screens
	local function attach(touchGui)
		frame = touchGui:WaitForChild("TouchControlFrame")
		frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		frame.ChildAdded:Connect(function(child)
			if child.Name == "JumpButton" then
				watchJump(child)
			end
		end)
		local current = frame:FindFirstChild("JumpButton")
		if current then
			watchJump(current)
		end
	end
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "TouchGui" then
			attach(child)
		end
	end)
	if playerGui:FindFirstChild("TouchGui") then
		task.spawn(attach, playerGui.TouchGui)
	end

	RunService.Heartbeat:Connect(function()
		if not frame then
			return
		end
		local hammer = Controls.HasHammer()
		buttons.bonk.button.Visible = hammer
		if not hammer then
			holdingBonk = false
		elseif holdingBonk then
			Controls.Bonk()
		end
		local bonkReady, diveReady = Controls.Cooldowns()
		setFill(buttons.bonk.fill, buttons.bonk.info.color, bonkReady)
		setFill(buttons.dive.fill, buttons.dive.info.color, diveReady)
	end)
end

return TouchButtons
