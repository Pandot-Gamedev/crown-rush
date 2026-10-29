-- Small messages that pop up on the right side of the screen.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local T = UI.Theme

local Notifications = {}

local COLORS = {
	success = T.Good,
	warning = T.Bad,
	coins = T.Gold,
	rare = Color3.fromRGB(255, 120, 200),
	info = T.Accent,
}

local container

function Notifications.Init(screenGui)
	container = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 70),
		Size = UDim2.fromOffset(320, 400),
		BackgroundTransparency = 1,
		ZIndex = 20, -- above open windows
		Parent = screenGui,
	}, { UI.list(6) })

	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		Notifications.Show(text, kind)
	end)
end

function Notifications.Show(text, kind)
	if not container then
		return
	end
	local toast = UI.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.1,
		Text = text,
		TextColor3 = COLORS[kind or "info"] or T.Text,
		Font = T.Font,
		TextScaled = true,
		TextWrapped = true,
		Parent = container,
	}, { UI.corner(10), UI.padding(6) })

	task.delay(4, function()
		local tween =
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)

	-- Keep at most 6 on screen
	local toasts = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 6 then
		toasts[1]:Destroy()
	end
end

return Notifications
