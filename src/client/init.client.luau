-- Crown Rush player script. Builds the screen and starts the controls.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UI = require(script.UI)
local Notifications = require(script.Notifications)
local Movement = require(script.Movement)
local Controls = require(script.Controls)
local Effects = require(script.Effects)
local Panels = require(script.Panels)
local RunHud = require(script.RunHud)
local Hud = require(script.Hud)
local Guide = require(script.Guide)

local player = Players.LocalPlayer

local screenGui = UI.new("ScreenGui", {
	Name = "CrownRushUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Shrink the whole UI on small screens (phones)
local scale = UI.new("UIScale", { Parent = screenGui })
local function rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 700), 0.55, 1.2)
	end
end
while not Workspace.CurrentCamera do
	task.wait()
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

Notifications.Init(screenGui)
Movement.Init()
Controls.Init()
Effects.Init()
Panels.Init(screenGui)
RunHud.Init(screenGui)
Hud.Init(screenGui)
Guide.Init(screenGui)
