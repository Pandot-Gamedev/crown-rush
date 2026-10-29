-- Bonking, dashing and knockback for everyone who can be bonked: players, bots
-- and the practice dummies. Each of them is an "entity" with a damage %.
--
-- The server decides every hit (who is in front of you and close enough), so
-- nobody can bonk people from across the map. A bonked player's own computer
-- moves their character (Roblox lets players move their own character), so the
-- server tells it how fast to fly with the Launch remote.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PowerUps = require(Shared.PowerUps)
local Remotes = require(Shared.Remotes)

local CosmeticService = require(script.Parent.CosmeticService)

local CombatService = {}

local entities = {} -- [model] = entity
local byPlayer = {} -- [player] = entity of their current character
local hitListeners = {}
local bonkListeners = {}
local random = Random.new()

-- Who an entity can hit. MatchService gives entities in a match a "space" with
-- a Targets() function; everyone else can only hit the practice dummies.
local function targetsFor(entity)
	if entity.space then
		return entity.space:Targets()
	end
	local list = {}
	for _, other in pairs(entities) do
		if other.kind == "dummy" then
			table.insert(list, other)
		end
	end
	return list
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function alive(entity)
	return entity.root ~= nil
		and entity.root:IsDescendantOf(workspace)
		and entity.humanoid ~= nil
		and entity.humanoid.Health > 0
end
CombatService.IsAlive = alive

function CombatService.Register(model, info)
	local entity = {
		kind = info.kind, -- "player", "bot" or "dummy"
		player = info.player,
		model = model,
		root = model:FindFirstChild("HumanoidRootPart"),
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		name = info.name,
		key = info.key,
		baseSpeed = info.walkSpeed or Config.WalkSpeed,
		damage = 0,
		space = nil,
		lastBonk = 0,
		lastDash = 0,
		stunUntil = 0,
		stunToken = 0,
		frozen = false,
		shield = 0,
		giantUntil = 0,
		speedUntil = 0,
		ironUntil = 0,
		magnetUntil = 0,
		lastHit = nil, -- { by = entity, time = os.clock() }
	}
	if entity.humanoid then
		entity.humanoid.UseJumpPower = false
		entity.humanoid.JumpHeight = Config.JumpHeight
		entity.humanoid.WalkSpeed = entity.baseSpeed
	end
	entities[model] = entity
	if info.player then
		byPlayer[info.player] = entity
	end
	model:SetAttribute("Damage", 0)
	model.Destroying:Connect(function()
		CombatService.Unregister(model)
	end)
	return entity
end

function CombatService.Unregister(model)
	local entity = entities[model]
	if not entity then
		return
	end
	entities[model] = nil
	if entity.player and byPlayer[entity.player] == entity then
		byPlayer[entity.player] = nil
	end
end

function CombatService.Get(model)
	return entities[model]
end

function CombatService.GetByPlayer(player)
	return byPlayer[player]
end

-- Called with (attacker, target) after every landed bonk
function CombatService.OnHit(listener)
	table.insert(hitListeners, listener)
end

-- Called with (entity) whenever someone swings
function CombatService.OnBonk(listener)
	table.insert(bonkListeners, listener)
end

function CombatService.Effect(kind, position, extra)
	Remotes.Effect:FireAllClients(kind, position, extra)
end

------------------------------------------------------------------ Damage and movement
function CombatService.SetDamage(entity, value)
	entity.damage = math.clamp(value, 0, Config.MaxDamage)
	entity.model:SetAttribute("Damage", math.floor(entity.damage))
end

-- Walk speed and jumping, from frozen / speed boots / normal
function CombatService.UpdateMovement(entity)
	local humanoid = entity.humanoid
	if not humanoid or not humanoid.Parent then
		return
	end
	if entity.frozen then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = entity.speedUntil > os.clock() and PowerUps.SpeedWalkSpeed or entity.baseSpeed
		humanoid.JumpHeight = Config.JumpHeight
	end
end

-- Frozen entities can't move, bonk or be bonked (the countdown before a round)
function CombatService.Freeze(entity, frozen)
	entity.frozen = frozen
	CombatService.UpdateMovement(entity)
end

-- Clears damage and power-ups, for a fresh round
function CombatService.Reset(entity)
	CombatService.SetDamage(entity, 0)
	entity.lastHit = nil
	entity.stunUntil = 0
	entity.shield = 0
	entity.giantUntil = 0
	entity.speedUntil = 0
	entity.ironUntil = 0
	entity.magnetUntil = 0
	local wasGiant = entity.model:GetAttribute("GiantHammer")
	entity.model:SetAttribute("GiantHammer", nil)
	for _, name in ipairs({ "BonkShield", "IronBoots" }) do
		local item = entity.model:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
	if entity.player then
		CosmeticService.RefreshHammer(entity.player, 1)
	elseif wasGiant and entity.hammerItem then
		CosmeticService.BuildHammer(entity.model, entity.hammerItem, 1)
	end
	CombatService.UpdateMovement(entity)
	if entity.humanoid then
		entity.humanoid.PlatformStand = false
	end
end

-- Sends an entity flying. Players' computers move their own characters; the
-- server moves bots and dummies itself.
function CombatService.Launch(entity, velocity, stun)
	if not alive(entity) then
		return
	end
	local now = os.clock()
	entity.stunUntil = math.max(entity.stunUntil, now + stun)
	local spinAxis = flat(velocity).Magnitude > 0.1 and flat(velocity).Unit:Cross(Vector3.yAxis) or Vector3.xAxis
	local spin = spinAxis * random:NextNumber(4, 9)
	if entity.player then
		Remotes.Launch:FireClient(entity.player, velocity, stun, spin)
		return
	end
	entity.stunToken += 1
	local token = entity.stunToken
	entity.humanoid.PlatformStand = true
	entity.root.AssemblyLinearVelocity = velocity
	entity.root.AssemblyAngularVelocity = spin
	task.delay(stun, function()
		if entity.stunToken == token and entity.humanoid.Parent then
			entity.humanoid.PlatformStand = false
			entity.root.AssemblyAngularVelocity = Vector3.zero
			-- Stand back up straight
			local position = entity.root.Position
			local look = flat(entity.root.CFrame.LookVector)
			if look.Magnitude < 0.1 then
				look = Vector3.new(0, 0, -1)
			end
			entity.root.CFrame = CFrame.lookAt(position, position + look)
		end
	end)
end

-- A push that doesn't come from a bonk (bouncy walls, the sweeper bar, a banana).
-- by = the entity that caused it, if any, so a fall still counts as their knockout.
function CombatService.Push(entity, velocity, stun, addDamage, by)
	if not alive(entity) or entity.frozen then
		return
	end
	if addDamage and addDamage > 0 then
		CombatService.SetDamage(entity, entity.damage + addDamage)
	end
	if entity.ironUntil > os.clock() then
		velocity = Vector3.new(velocity.X * PowerUps.IronShare, velocity.Y, velocity.Z * PowerUps.IronShare)
	end
	if by then
		entity.lastHit = { by = by, time = os.clock() }
	end
	CombatService.Launch(entity, velocity, stun)
end

------------------------------------------------------------------ Bonking
-- The right shoulder joint and the axis that lifts the arm forward. Older rigs
-- use a Motor6D (turn its C0); newer ones an AnimationConstraint (turn the
-- shoulder attachment on the torso instead).
local function shoulder(model)
	local joint, axis = nil, nil
	local arm = model:FindFirstChild("RightUpperArm")
	if arm and arm:FindFirstChild("RightShoulder") then
		joint, axis = arm.RightShoulder, Vector3.xAxis
	else
		local torso = model:FindFirstChild("Torso")
		if torso and torso:FindFirstChild("Right Shoulder") then
			joint, axis = torso["Right Shoulder"], Vector3.zAxis
		end
	end
	if not joint then
		return nil
	end
	if joint:IsA("Motor6D") then
		return joint, "C0", axis
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then
		return joint.Attachment0, "CFrame", axis
	end
	return nil
end

-- Swings the right arm (and the hammer in that hand) up and down
local function swing(entity)
	local target, property, axis = shoulder(entity.model)
	if not target then
		return
	end
	if entity.shoulderTarget ~= target then
		entity.shoulderTarget = target
		entity.shoulderBase = target[property]
	end
	local base = entity.shoulderBase
	local function at(degrees)
		return base * CFrame.fromAxisAngle(axis, math.rad(degrees))
	end
	entity.swingToken = (entity.swingToken or 0) + 1
	local token = entity.swingToken
	TweenService:Create(target, TweenInfo.new(0.07), { [property] = at(165) }):Play()
	task.delay(0.07, function()
		if entity.swingToken ~= token or not target.Parent then
			return
		end
		TweenService
			:Create(
				target,
				TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ [property] = at(55) }
			)
			:Play()
		task.delay(0.22, function()
			if entity.swingToken ~= token or not target.Parent then
				return
			end
			TweenService:Create(target, TweenInfo.new(0.2), { [property] = base }):Play()
		end)
	end)
end

-- One landed bonk: adds damage and sends the target flying away from the attacker.
-- options.power multiplies the push (Giant Hammer).
function CombatService.Hit(attacker, target, options)
	options = options or {}
	if not alive(target) or target.frozen then
		return false
	end
	local now = os.clock()
	local away = flat(target.root.Position - attacker.root.Position)
	if away.Magnitude < 0.1 then
		away = flat(attacker.root.CFrame.LookVector)
	end
	away = away.Unit

	if target.shield > 0 then
		target.shield -= 1
		if target.shield <= 0 then
			local bubble = target.model:FindFirstChild("BonkShield")
			if bubble then
				bubble:Destroy()
			end
		end
		CombatService.Effect("block", target.root.Position)
		-- The shield bounces the attacker back a little
		CombatService.Launch(attacker, -away * 35 + Vector3.yAxis * 20, 0.3)
		return false
	end

	local power = options.power or 1
	local amount = random:NextInteger(Config.BonkDamageMin, Config.BonkDamageMax)
	if power > 1 then
		amount = math.floor(amount * 1.25)
	end
	CombatService.SetDamage(target, target.damage + amount)
	local speed, up = Config.Knockback(target.damage)
	if target.ironUntil > now then
		power *= PowerUps.IronShare
	end
	local velocity = away * speed * power + Vector3.yAxis * up * math.max(power, 0.7)
	target.lastHit = { by = attacker, time = now }
	CombatService.Launch(target, velocity, Config.Stun(target.damage))
	CombatService.Effect(
		"hit",
		target.root.Position,
		{ damage = amount, total = math.floor(target.damage), big = power > 1 }
	)
	for _, listener in ipairs(hitListeners) do
		task.spawn(listener, attacker, target)
	end
	return true
end

local function resolveBonk(entity)
	if not alive(entity) or entity.frozen or entity.stunUntil > os.clock() then
		return -- got bonked during the swing
	end
	local now = os.clock()
	local giant = entity.giantUntil > now
	local magnet = entity.magnetUntil > now
	local range = Config.BonkRange + (giant and PowerUps.GiantReach or 0)
	if magnet then
		range = math.max(range, PowerUps.MagnetBonkRange)
		entity.magnetUntil = 0
		CombatService.Effect("shockwave", entity.root.Position, { range = range })
	end
	local origin = entity.root.Position
	local look = flat(entity.root.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local minDot = math.cos(math.rad(Config.BonkArc / 2))
	for _, target in ipairs(targetsFor(entity)) do
		if target ~= entity and alive(target) then
			local offset = target.root.Position - origin
			local flatOffset = flat(offset)
			local distance = flatOffset.Magnitude
			if distance <= range and math.abs(offset.Y) <= 6 then
				if magnet or distance < 2.5 or look:Dot(flatOffset.Unit) >= minDot then
					CombatService.Hit(entity, target, { power = giant and PowerUps.GiantPower or 1 })
				end
			end
		end
	end
end

-- Starts a swing if the entity is allowed to. The hit lands a moment later.
function CombatService.TryBonk(entity)
	local now = os.clock()
	if not alive(entity) or entity.frozen or now < entity.stunUntil or now - entity.lastBonk < Config.BonkCooldown then
		return false
	end
	entity.lastBonk = now
	swing(entity)
	CombatService.Effect("swing", entity.root.Position)
	for _, listener in ipairs(bonkListeners) do
		task.spawn(listener, entity)
	end
	task.delay(Config.BonkImpactDelay, resolveBonk, entity)
	return true
end

-- Bots dash on the server (players dash on their own computer, see Controls.luau)
function CombatService.Dash(entity, direction)
	local now = os.clock()
	if not alive(entity) or entity.frozen or now < entity.stunUntil or now - entity.lastDash < Config.DashCooldown then
		return false
	end
	entity.lastDash = now
	local dir = flat(direction or entity.root.CFrame.LookVector)
	if dir.Magnitude < 0.1 then
		return false
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = entity.root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "Dash"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	mover.VectorVelocity = dir.Unit * Config.DashSpeed
	mover.Parent = entity.root
	task.delay(Config.DashSeconds, function()
		mover:Destroy()
		attachment:Destroy()
	end)
	CombatService.Effect("dash", entity.root.Position)
	return true
end

function CombatService.All()
	return entities
end

function CombatService.Start()
	local function watch(player)
		player.CharacterRemoving:Connect(function(character)
			CombatService.Unregister(character)
		end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Humanoid", 10)
			if character.Parent then
				CombatService.Register(
					character,
					{ kind = "player", player = player, name = player.DisplayName, key = "p" .. player.UserId }
				)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
		if player.Character then
			CombatService.Register(
				player.Character,
				{ kind = "player", player = player, name = player.DisplayName, key = "p" .. player.UserId }
			)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		byPlayer[player] = nil
	end)

	-- Speed Boots and the Giant Hammer wear off
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, entity in pairs(entities) do
				if entity.speedEnds and now >= entity.speedUntil then
					entity.speedEnds = nil
					CombatService.UpdateMovement(entity)
				end
				if entity.model:GetAttribute("GiantHammer") and now >= entity.giantUntil then
					entity.model:SetAttribute("GiantHammer", nil)
					if entity.player then
						CosmeticService.RefreshHammer(entity.player, 1)
					else
						CosmeticService.BuildHammer(entity.model, entity.hammerItem, 1)
					end
				end
				if entity.ironUntil > 0 and now >= entity.ironUntil then
					entity.ironUntil = 0
					local boots = entity.model:FindFirstChild("IronBoots")
					if boots then
						boots:Destroy()
					end
				end
			end
		end
	end)

	Remotes.Bonk.OnServerEvent:Connect(function(player)
		local entity = byPlayer[player]
		if entity then
			CombatService.TryBonk(entity)
		end
	end)
	-- Players dash on their own computer; show the puff to everyone else
	Remotes.Dash.OnServerEvent:Connect(function(player)
		local entity = byPlayer[player]
		if entity and alive(entity) and os.clock() - entity.lastDash >= Config.DashCooldown * 0.8 then
			entity.lastDash = os.clock()
			CombatService.Effect("dash", entity.root.Position)
		end
	end)
end

return CombatService
