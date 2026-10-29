-- The first-time guide on screen: the current goal at the top, and a golden
-- line from you to where you need to go.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Tutorial)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local T = UI.Theme

local Guide = {}

local player = Players.LocalPlayer
local card, cardText
local beam, beamFrom, beamTo, marker, follower

local function findTarget(name)
	if not name then
		return nil
	end
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("GuideTarget") == name then
			return item
		end
	end
	return nil
end

local function currentStep()
	local data = State.data
	if not data or not data.tutorial or data.tutorial >= Tutorial.Done then
		return nil, nil
	end
	return Tutorial.Steps[data.tutorial], data.tutorial
end

local function update()
	local step, index = currentStep()
	if player:GetAttribute("InTournament") then
		step = nil
	end
	card.Visible = step ~= nil
	if not step then
		beam.Enabled = false
		marker.Enabled = false
		return
	end
	cardText.Text = string.format("(%d/%d) %s", index, #Tutorial.Steps, step.text)

	local target = findTarget(step.target)
	if target then
		beamTo.Parent = target
		beam.Enabled = true
		marker.Adornee = target
		marker.Enabled = true
	else
		beam.Enabled = false
		marker.Enabled = false
	end
end

function Guide.Init(screenGui)
	card = UI.new("Frame", {
		Name = "GuideCard",
		AnchorPoint = Vector2.new(0.5, 0),
		-- on touch screens, below the menu row
		Position = UDim2.new(0.5, 0, 0, UI.Touch and 216 or 120),
		Size = UDim2.fromOffset(560, 56),
		BackgroundColor3 = Color3.fromRGB(255, 244, 214),
		Visible = false,
		Parent = screenGui,
	}, { UI.corner(12), UI.stroke(T.Gold, 3), UI.padding(8) })
	cardText = UI.label("", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(60, 40, 20),
		Font = T.BodyFont,
		TextWrapped = true,
		Parent = card,
	})

	-- An invisible part that follows the player carries the start of the line
	follower = Instance.new("Part")
	follower.Name = "GuideFollower"
	follower.Anchored = true
	follower.CanCollide = false
	follower.CanQuery = false
	follower.CanTouch = false
	follower.Transparency = 1
	follower.Size = Vector3.one * 0.2
	follower.Parent = Workspace
	beamFrom = Instance.new("Attachment")
	beamFrom.Name = "GuideFrom"
	beamFrom.Parent = follower
	beamTo = Instance.new("Attachment")
	beamTo.Name = "GuideTo"
	beamTo.Position = Vector3.new(0, 3, 0)
	beam = Instance.new("Beam")
	beam.Attachment0 = beamFrom
	beam.Attachment1 = beamTo
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(T.Gold)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
	beam.LightEmission = 1
	beam.Enabled = false
	beam.Parent = beamFrom

	marker = UI.new("BillboardGui", {
		Name = "GuideMarker",
		Size = UDim2.fromOffset(80, 80),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local arrow = UI.label(
		"V",
		{ Size = UDim2.fromScale(1, 1), TextColor3 = T.Gold, TextStrokeTransparency = 0, Parent = marker }
	)

	RunService.RenderStepped:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			follower.Position = root.Position - Vector3.new(0, 1.5, 0)
		end
		if marker.Enabled then
			marker.StudsOffset = Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.6, 0)
			arrow.TextTransparency = 0
		end
	end)

	State.Changed:Connect(update)
	player:GetAttributeChangedSignal("InTournament"):Connect(update)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		update()
	end)
	update()
end

return Guide
