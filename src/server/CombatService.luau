-- Foam hammers for fight, objective and team rounds. Players and bots who are
-- in such a round are "fighters". Every bonk adds to the target's damage %,
-- and the higher it is, the further they fly (nobody gets hurt: it's all
-- about knocking rivals off the arena or making them drop what they carry).
--
-- The server decides every hit (who is in front of you and close enough), so
-- nobody can bonk people from across the map. A bonked player's own computer
-- moves their character, so the server tells it how fast to fly with the
-- Launch remote. Bots are moved by BotService.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CosmeticService = require(script.Parent.CosmeticService)
local BotService = require(script.Parent.BotService)

local CombatService = {}

local fighters = {} -- [key] = fighter
local hitListeners = {}
local random = Random.new()

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function rootOf(fighter)
	if fighter.bot then
		return fighter.bot.root
	end
	local character = fighter.player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
CombatService.RootOf = rootOf

local function modelOf(fighter)
	return fighter.bot and fighter.bot.model or fighter.player.Character
end

local function keyOf(entrant)
	return entrant.bot and entrant.bot.key or ("p" .. entrant.player.UserId)
end

------------------------------------------------------------------ Joining
-- Gives an entrant (a tournament runner) a hammer for this round. space is
-- the round: space:Targets() lists the fighters this one can hit.
function CombatService.Join(entrant, space)
	local fighter = {
		key = keyOf(entrant),
		entrant = entrant,
		player = entrant.player,
		bot = entrant.bot,
		name = entrant.name,
		space = space,
		damage = 0,
		lastBonk = 0,
		stunUntil = 0,
		lastHit = nil, -- { by = fighter, time = os.clock() }
	}
	fighters[fighter.key] = fighter
	entrant.fighter = fighter
	local model = modelOf(fighter)
	if model then
		model:SetAttribute("Damage", 0)
		model:SetAttribute("ShowDamage", true)
		CosmeticService.SetHammer(model, true, fighter.player)
	end
	return fighter
end

function CombatService.Leave(entrant)
	local fighter = entrant.fighter
	if not fighter then
		return
	end
	entrant.fighter = nil
	if fighters[fighter.key] == fighter then
		fighters[fighter.key] = nil
	end
	local model = modelOf(fighter)
	if model then
		model:SetAttribute("Damage", nil)
		model:SetAttribute("ShowDamage", nil)
		CosmeticService.SetHammer(model, false)
	end
end

-- Called with (attacker, target) after every landed bonk
function CombatService.OnHit(listener)
	table.insert(hitListeners, listener)
	return function()
		local index = table.find(hitListeners, listener)
		if index then
			table.remove(hitListeners, index)
		end
	end
end

-- Who knocked this fighter last, if it was in the last few seconds
function CombatService.LastHitBy(fighter, seconds)
	local hit = fighter and fighter.lastHit
	if hit and os.clock() - hit.time <= (seconds or 5) then
		return hit.by
	end
	return nil
end

------------------------------------------------------------------ Knocks
-- Sends a fighter (or any runner) flying
function CombatService.Launch(fighter, velocity, stun)
	fighter.stunUntil = math.max(fighter.stunUntil or 0, os.clock() + stun)
	if fighter.bot then
		BotService.Push(fighter.bot, velocity)
		return
	end
	local spinAxis = flat(velocity).Magnitude > 0.1 and flat(velocity).Unit:Cross(Vector3.yAxis) or Vector3.xAxis
	Remotes.Launch:FireClient(fighter.player, velocity, stun, spinAxis * random:NextNumber(4, 9))
end

-- The right shoulder joint and the axis that lifts the arm forward. Older rigs
-- use a Motor6D (turn its C0); newer avatars an AnimationConstraint (turn the
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
local function swing(fighter)
	local model = modelOf(fighter)
	local target, property, axis = nil, nil, nil
	if model then
		target, property, axis = shoulder(model)
	end
	if not target then
		return
	end
	if fighter.shoulder ~= target then
		fighter.shoulder = target
		fighter.shoulderBase = target[property]
	end
	local base = fighter.shoulderBase
	local function at(degrees)
		return base * CFrame.fromAxisAngle(axis, math.rad(degrees))
	end
	fighter.swingToken = (fighter.swingToken or 0) + 1
	local token = fighter.swingToken
	TweenService:Create(target, TweenInfo.new(0.07), { [property] = at(165) }):Play()
	task.delay(0.07, function()
		if fighter.swingToken ~= token or not target.Parent then
			return
		end
		TweenService:Create(target, TweenInfo.new(0.07), { [property] = at(55) }):Play()
		task.delay(0.22, function()
			if fighter.swingToken == token and target.Parent then
				TweenService:Create(target, TweenInfo.new(0.2), { [property] = base }):Play()
			end
		end)
	end)
end

-- One landed bonk: adds damage and sends the target flying away
function CombatService.Hit(attacker, target)
	local attackerRoot, targetRoot = rootOf(attacker), rootOf(target)
	if not attackerRoot or not targetRoot then
		return false
	end
	local away = flat(targetRoot.Position - attackerRoot.Position)
	if away.Magnitude < 0.1 then
		away = flat(attackerRoot.CFrame.LookVector)
	end
	away = away.Unit
	local amount = random:NextInteger(Config.BonkDamageMin, Config.BonkDamageMax)
	target.damage += amount
	local model = modelOf(target)
	if model then
		model:SetAttribute("Damage", target.damage)
	end
	local speed, up = Config.Knockback(target.damage)
	target.lastHit = { by = attacker, time = os.clock() }
	CombatService.Launch(target, away * speed + Vector3.yAxis * up, Config.Stun(target.damage))
	Remotes.Effect:FireAllClients("hit", targetRoot.Position, { damage = amount, total = target.damage })
	for _, listener in ipairs(hitListeners) do
		task.spawn(listener, attacker, target)
	end
	return true
end

local function resolveBonk(fighter)
	local root = rootOf(fighter)
	if fighters[fighter.key] ~= fighter or not root or fighter.stunUntil > os.clock() then
		return -- left the round, or got bonked during the swing
	end
	local origin = root.Position
	local look = flat(root.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local minDot = math.cos(math.rad(Config.BonkArc / 2))
	for _, target in ipairs(fighter.space:Targets(fighter)) do
		local targetRoot = target ~= fighter and rootOf(target)
		if targetRoot then
			local offset = targetRoot.Position - origin
			local distance = flat(offset).Magnitude
			if distance <= Config.BonkRange and math.abs(offset.Y) <= 6 then
				if distance < 2.5 or look:Dot(flat(offset).Unit) >= minDot then
					CombatService.Hit(fighter, target)
				end
			end
		end
	end
end

-- Starts a swing if the fighter is allowed to. The hit lands a moment later.
function CombatService.TryBonk(fighter)
	local now = os.clock()
	local root = rootOf(fighter)
	if not root or now < fighter.stunUntil or now - fighter.lastBonk < Config.BonkCooldown then
		return false
	end
	fighter.lastBonk = now
	swing(fighter)
	Remotes.Effect:FireAllClients("swing", root.Position)
	task.delay(Config.BonkImpactDelay, resolveBonk, fighter)
	return true
end

function CombatService.Start()
	Remotes.Bonk.OnServerEvent:Connect(function(player)
		local fighter = fighters["p" .. player.UserId]
		if fighter then
			CombatService.TryBonk(fighter)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		fighters["p" .. player.UserId] = nil
	end)
end

return CombatService
