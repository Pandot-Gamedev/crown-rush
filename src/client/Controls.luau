-- Dive, jump help, and the hammer swing in fight rounds.
--   Dive: Q, X on a controller, or the DIVE button on phones.
--         A quick forward lunge, once per jump, to reach a ledge or grab a gem.
--   Jump help: you can still jump a moment after running off an edge, and a
--         jump pressed just before landing still counts. Phones need this most.
--   Bonk: click, F, R2 on a controller, or the BONK button on phones, only
--         while you hold a foam hammer (fight rounds). The server decides who
--         gets hit; this script only asks to swing.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Movement = require(script.Parent.Movement)

local Controls = {}

local player = Players.LocalPlayer
local DIVE_SECONDS = 0.32
local JUMP_BUFFER = 0.15

local lastBonk = 0
local lastDive = 0
local divedThisJump = false
local diving = nil
local lastGrounded = 0
local jumpedSinceGround = false
local jumpPressedAt = -1
local hammerShown = nil

local function parts()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function stopDive()
	if diving then
		diving.mover:Destroy()
		diving.attachment:Destroy()
		diving = nil
	end
end

function Controls.HasHammer()
	local character = player.Character
	return character ~= nil and character:GetAttribute("HasHammer") == true
end

function Controls.Bonk()
	local now = os.clock()
	if not Controls.HasHammer() or now - lastBonk < Config.BonkCooldown or Movement.IsStunned() or not parts() then
		return
	end
	lastBonk = now
	Remotes.Bonk:FireServer()
end

function Controls.Dive()
	local now = os.clock()
	local root, humanoid = parts()
	if not root or now - lastDive < Config.DiveCooldown or Movement.IsStunned() or humanoid.WalkSpeed <= 0 then
		return
	end
	local inAir = humanoid.FloorMaterial == Enum.Material.Air
	if inAir and divedThisJump then
		return
	end
	local direction = flat(humanoid.MoveDirection)
	if direction.Magnitude < 0.1 then
		direction = flat(root.CFrame.LookVector)
	end
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit
	lastDive = now
	divedThisJump = true
	stopDive()
	local attachment = Instance.new("Attachment")
	attachment.Name = "DiveAttachment"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "Dive"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	mover.VectorVelocity = direction * Config.DiveSpeed
	mover.Parent = root
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, 0) + Config.DiveUp, velocity.Z)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	if not inAir then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	local this = { mover = mover, attachment = attachment }
	diving = this
	task.delay(DIVE_SECONDS, function()
		if diving == this then
			stopDive()
		end
	end)
	Remotes.Dive:FireServer()
end

-- 0 to 1: how ready each move is (for the phone buttons)
function Controls.Cooldowns()
	local now = os.clock()
	return math.clamp((now - lastBonk) / Config.BonkCooldown, 0, 1),
		math.clamp((now - lastDive) / Config.DiveCooldown, 0, 1)
end

-- Jump a moment after leaving an edge, or just before landing
local function watchJumps(humanoid)
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			jumpedSinceGround = true
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			divedThisJump = false
			jumpedSinceGround = false
			lastGrounded = os.clock()
			if os.clock() - jumpPressedAt < JUMP_BUFFER then
				-- A tap just before landing: the normal jump already missed it
				jumpPressedAt = -1
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)
end

local function onJumpRequest()
	local root, humanoid = parts()
	if not root or Movement.IsStunned() then
		return
	end
	local now = os.clock()
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		lastGrounded = now
		return
	end
	if not jumpedSinceGround and now - lastGrounded < Config.CoyoteSeconds then
		jumpedSinceGround = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		return
	end
	jumpPressedAt = now
end

local function showBonkButton(on)
	if hammerShown == on then
		return
	end
	hammerShown = on
	if on then
		ContextActionService:BindAction("CrownRushBonk", function(_, state)
			if state == Enum.UserInputState.Begin then
				Controls.Bonk()
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle("CrownRushBonk", "BONK")
		ContextActionService:SetPosition("CrownRushBonk", UDim2.new(1, -150, 1, -150))
	else
		ContextActionService:UnbindAction("CrownRushBonk")
	end
end

local function onCharacter(character)
	stopDive()
	divedThisJump = false
	jumpedSinceGround = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = Config.WalkSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.JumpHeight
		watchJumps(humanoid)
	end
	showBonkButton(character:GetAttribute("HasHammer") == true)
	character:GetAttributeChangedSignal("HasHammer"):Connect(function()
		showBonkButton(character:GetAttribute("HasHammer") == true)
	end)
end

function Controls.Init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	ContextActionService:BindAction("CrownRushDive", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.Dive()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("CrownRushDive", "DIVE")
	ContextActionService:SetPosition("CrownRushDive", UDim2.new(1, -230, 1, -100))

	UserInputService.JumpRequest:Connect(onJumpRequest)
	Movement.Launched:Connect(function()
		stopDive()
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return Controls
