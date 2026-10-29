-- Bots fill the empty spots in a match so nobody waits alone. They are a bit
-- slower and less accurate than people, their name tags say BOT, and knocking
-- them out is worth less. When a real player joins, a bot steps aside for them
-- (see MatchService).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmetics = require(Shared.Cosmetics)

local CombatService = require(script.Parent.CombatService)
local CosmeticService = require(script.Parent.CosmeticService)

local BotService = {}

local NAMES = {
	"Bonky",
	"Thumper",
	"Wobbles",
	"Sir Bonks",
	"Noodle",
	"Pip",
	"Biscuit",
	"Clank",
	"Mallet Max",
	"Tumble",
	"Boing",
	"Dizzy",
}
local SHIRTS = {
	Color3.fromRGB(230, 80, 80),
	Color3.fromRGB(80, 150, 230),
	Color3.fromRGB(90, 200, 110),
	Color3.fromRGB(240, 190, 60),
	Color3.fromRGB(170, 100, 230),
	Color3.fromRGB(240, 130, 60),
}
local SKINS = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(140, 95, 65),
	Color3.fromRGB(255, 215, 180),
}
local BOT_HAMMERS = { "hammer_foam", "hammer_blue", "hammer_green", "hammer_purple", "hammer_mallet" }

BotService.WalkSpeed = 15
local REACH = 6.5
-- Roblox's own R15 animations, so bots walk and jump like players do
local ANIMATIONS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
}

local random = Random.new()
local folder
local nameIndex = 0
local botCount = 0

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Plays the idle, walk, jump and fall animations to match what the bot is doing
local function animate(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks = {}
	for name, id in pairs(ANIMATIONS) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = name ~= "jump"
			tracks[name] = track
		end
	end
	local current = nil
	local function play(name, speed)
		local track = tracks[name]
		if track ~= current then
			if current then
				current:Stop(0.2)
			end
			current = track
			if track then
				track:Play(0.2)
			end
		end
		if track and speed then
			track:AdjustSpeed(speed)
		end
	end
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			play("walk", math.clamp(speed / 14, 0.6, 1.6))
		else
			play("idle")
		end
	end)
	humanoid.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Jumping then
			play("jump")
		elseif state == Enum.HumanoidStateType.Freefall then
			play("fall")
		end
	end)
	play("idle")
end

-- Makes a bot model standing at cframe. Returns its combat entity.
function BotService.Create(cframe)
	nameIndex = nameIndex % #NAMES + 1
	local name = NAMES[nameIndex]
	local skin = SKINS[random:NextInteger(1, #SKINS)]
	local shirt = SHIRTS[random:NextInteger(1, #SHIRTS)]
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = shirt:Lerp(Color3.new(0, 0, 0), 0.5)
	description.RightLegColor = shirt:Lerp(Color3.new(0, 0, 0), 0.5)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[BotService] Couldn't make a bot: " .. tostring(model))
		return nil
	end
	botCount += 1
	model.Name = "Bot " .. name
	model:PivotTo(cframe)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local oldAnimate = model:FindFirstChild("Animate")
	if oldAnimate then
		oldAnimate:Destroy()
	end
	pcall(animate, model:FindFirstChildOfClass("Humanoid"))
	local entity = CombatService.Register(
		model,
		{ kind = "bot", name = name .. " (bot)", key = "b" .. botCount, walkSpeed = BotService.WalkSpeed }
	)
	entity.hammerItem = Cosmetics.ById[BOT_HAMMERS[random:NextInteger(1, #BOT_HAMMERS)]]
	entity.nextThink = 0
	entity.nextBonk = 0
	CosmeticService.BuildHammer(model, entity.hammerItem)
	CosmeticService.Tag(model, { name = name, nameColor = Color3.fromRGB(200, 200, 200), subtitle = "BOT" })
	return entity
end

function BotService.Remove(entity)
	if entity and entity.model then
		entity.model:Destroy()
	end
end

-- Moves a bot (or a dummy) and keeps the server in charge of its physics
function BotService.Place(entity, cframe)
	if entity.model.Parent then
		entity.model:PivotTo(cframe)
		entity.root.AssemblyLinearVelocity = Vector3.zero
		entity.root.AssemblyAngularVelocity = Vector3.zero
		entity.humanoid.PlatformStand = false
		pcall(function()
			entity.root:SetNetworkOwner(nil)
		end)
	end
end

-- Something solid right in front of the bot's feet (a step up) means jump
local function stepAhead(entity, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.model }
	local origin = entity.root.Position - Vector3.new(0, 1.8, 0)
	local hit = Workspace:Raycast(origin, direction * 3, params)
	return hit ~= nil and hit.Instance.CanCollide
end

-- One decision for one bot in a match. space = the match (MatchService) with
-- its arena, alive entities and power-ups.
local function think(entity, space)
	local now = os.clock()
	if entity.frozen or now < entity.stunUntil or not CombatService.IsAlive(entity) then
		return
	end
	local arena = space.arena
	if not arena then
		return
	end
	local humanoid, root = entity.humanoid, entity.root
	local position = root.Position
	local center = Vector3.new(arena.center.X, position.Y, arena.center.Z)
	local fromCenter = flat(position - arena.center)
	local safeRadius = arena:SafeRadius()

	local goal
	-- Back to safety first
	if fromCenter.Magnitude > safeRadius then
		goal = center + (fromCenter.Magnitude > 0.1 and fromCenter.Unit * math.max(0, safeRadius - 6) or Vector3.zero)
	else
		-- A power-up close by is worth grabbing
		local bestPowerUp, bestPowerDistance = nil, 22
		for _, powerUp in ipairs(space:PowerUpPositions()) do
			local distance = (flat(powerUp - position)).Magnitude
			if distance < bestPowerDistance and flat(powerUp - arena.center).Magnitude < safeRadius then
				bestPowerUp, bestPowerDistance = powerUp, distance
			end
		end
		-- Otherwise chase someone, but never off the edge
		if
			not entity.target
			or now > (entity.retarget or 0)
			or not CombatService.IsAlive(entity.target)
			or not entity.target.space
		then
			entity.target = nil
			local best = math.huge
			for _, other in ipairs(space:Targets()) do
				if other ~= entity and CombatService.IsAlive(other) then
					local distance = (other.root.Position - position).Magnitude + random:NextNumber(0, 12)
					if distance < best then
						best = distance
						entity.target = other
					end
				end
			end
			entity.retarget = now + random:NextNumber(2, 4)
		end
		local target = entity.target
		if bestPowerUp and (not target or bestPowerDistance < (target.root.Position - position).Magnitude) then
			goal = bestPowerUp
		elseif target then
			local targetPosition = target.root.Position
			local offset = flat(targetPosition - position)
			if offset.Magnitude <= REACH and math.abs(targetPosition.Y - position.Y) < 5 then
				-- Face them and swing (with a little delay, so bots can be beaten)
				root.CFrame = CFrame.lookAt(position, Vector3.new(targetPosition.X, position.Y, targetPosition.Z))
				if now >= entity.nextBonk then
					if CombatService.TryBonk(entity) then
						entity.nextBonk = now + random:NextNumber(0.8, 1.5)
					end
				end
				goal = position
			else
				goal = targetPosition
				local targetFromCenter = flat(targetPosition - arena.center)
				if targetFromCenter.Magnitude > safeRadius then
					goal = Vector3.new(arena.center.X, targetPosition.Y, arena.center.Z)
						+ targetFromCenter.Unit * math.max(0, safeRadius - 2)
				end
				if offset.Magnitude > 9 and offset.Magnitude < 16 and random:NextNumber() < 0.08 then
					CombatService.Dash(entity, offset)
				end
			end
		end
	end

	if goal then
		humanoid:MoveTo(goal)
		local direction = flat(goal - position)
		if direction.Magnitude > 1 and stepAhead(entity, direction.Unit) then
			humanoid.Jump = true
		end
	end
	if arena:ShouldJump(position) and random:NextNumber() < 0.75 then
		humanoid.Jump = true
	end
end

-- space:Bots() lists the bots in a match; this runs them all
function BotService.Think(space)
	for _, entity in ipairs(space:Bots()) do
		local ok, err = pcall(think, entity, space)
		if not ok then
			warn("[BotService] " .. tostring(err))
		end
	end
end

function BotService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = Workspace
end

return BotService
