-- Bots fill the empty spots in a tournament so nobody waits for players.
-- They always try their best: they run the course's real path, time laser
-- gates, ride moving platforms and pick doors. But they run a little slower
-- than you, can get knocked by spinners and hammers, and fall like anyone else.
-- Their name tags say BOT, and they never take a real player's spot: they only
-- fill what's left when a tournament starts.
--
-- Bots are moved by the server (their root is anchored and follows a path),
-- so they never lag or get stuck on a wall. The rest of the body is animated.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Motion = require(Shared.Motion)

local CosmeticService = require(script.Parent.CosmeticService)
local CourseService = require(script.Parent.CourseService)

local BotService = {}

local NAMES = {
	"Zippy",
	"Bouncer",
	"Wobbles",
	"Speedy Sue",
	"Noodle",
	"Pip",
	"Biscuit",
	"Turbo",
	"Jumpy Jo",
	"Tumble",
	"Boing",
	"Dizzy",
	"Sprinkles",
	"Rocket",
	"Gizmo",
	"Pogo",
	"Marbles",
	"Flash",
	"Doodle",
	"Waffles",
	"Skipper",
	"Peanut",
	"Comet",
	"Bubbles",
}
local SHIRTS = {
	Color3.fromRGB(230, 80, 80),
	Color3.fromRGB(80, 150, 230),
	Color3.fromRGB(90, 200, 110),
	Color3.fromRGB(240, 190, 60),
	Color3.fromRGB(170, 100, 230),
	Color3.fromRGB(240, 130, 60),
	Color3.fromRGB(255, 120, 190),
	Color3.fromRGB(60, 200, 200),
}
local SKINS = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(140, 95, 65),
	Color3.fromRGB(255, 215, 180),
}
-- Roblox's own R15 animations, so bots run and jump like players do
local ANIMATIONS = {
	idle = "rbxassetid://507766388",
	run = "rbxassetid://913376220",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
	climb = "rbxassetid://507765644",
}

BotService.Folder = nil
local ROOT_HEIGHT = 3 -- the root's middle sits this far above the floor
local GRAVITY = 196.2
local ZIP_SPEED = 48
local HOP_HEIGHT = 6 -- a hop over a low bar or boulder while running (players jump about 7)
local HOP_TIME = 0.6
local random = Random.new()
local nameIndex = random:NextInteger(1, #NAMES)
local botCount = 0
local rayParams = RaycastParams.new()
-- Which Start each bot thread belongs to. A thread whose bot was stopped (or
-- started again) ends at its next frame, even when it was the one that
-- stopped it (a bot that falls in lava stops itself).
local threadGeneration = setmetatable({}, { __mode = "k" })
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

------------------------------------------------------------------ Making bots
local function loadAnimations(bot)
	local animator = bot.humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = bot.humanoid
	end
	bot.tracks = {}
	for name, id in pairs(ANIMATIONS) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = name ~= "jump"
			bot.tracks[name] = track
		end
	end
end

-- Plays one of the bot's animations (idle, run, jump, fall, climb)
function BotService.Animate(bot, name, speed)
	if bot.playing == name then
		return
	end
	local old = bot.tracks and bot.tracks[bot.playing or ""]
	if old then
		old:Stop(0.15)
	end
	bot.playing = name
	local track = bot.tracks and bot.tracks[name]
	if track then
		track:Play(0.15)
		if speed then
			track:AdjustSpeed(speed)
		end
	end
end

-- A plain blocky body, if Roblox can't make a proper one (Studio offline, tests)
local function simpleModel(skin, shirt)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local function limb(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.CFrame = offset
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	limb("Torso", Vector3.new(2, 2, 1), CFrame.new(), shirt)
	limb("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), skin)
	limb("LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0), shirt:Lerp(Color3.new(), 0.5))
	limb("RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0), shirt:Lerp(Color3.new(), 0.5))
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- Makes a bot standing at cframe. skill 0..1: how fast and careful it is.
function BotService.Create(cframe, skill)
	nameIndex = nameIndex % #NAMES + 1
	local name = NAMES[nameIndex]
	local skin = SKINS[random:NextInteger(1, #SKINS)]
	local shirt = SHIRTS[random:NextInteger(1, #SHIRTS)]
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = shirt
		description.LeftLegColor = shirt:Lerp(Color3.new(0, 0, 0), 0.5)
		description.RightLegColor = shirt:Lerp(Color3.new(0, 0, 0), 0.5)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		model = simpleModel(skin, shirt)
	end
	botCount += 1
	model.Name = "Bot " .. name
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.Anchored = item == root
			item.CollisionGroup = "Runners"
		end
	end
	local oldAnimate = model:FindFirstChild("Animate")
	if oldAnimate then
		oldAnimate:Destroy()
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:PivotTo(cframe)
	model:SetAttribute("Bot", true)
	model.Parent = BotService.Folder
	skill = skill or random:NextNumber(0.55, 1)
	local bot = {
		key = "bot" .. botCount,
		name = name,
		model = model,
		root = root,
		humanoid = humanoid,
		skill = skill,
		speed = Config.WalkSpeed * (0.8 + 0.17 * skill), -- 16 to 19.4, players run at 20
		thread = nil,
		playing = nil,
	}
	pcall(loadAnimations, bot)
	BotService.Animate(bot, "idle")
	CosmeticService.Tag(model, { name = name, nameColor = Color3.fromRGB(210, 210, 210), subtitle = "BOT" })
	return bot
end

function BotService.Remove(bot)
	BotService.Stop(bot)
	if bot.model then
		bot.model:Destroy()
	end
end

-- Stands the bot at cframe (its feet on the floor below it)
function BotService.Place(bot, cframe)
	local position = cframe.Position
	local look = flat(cframe.LookVector)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	bot.root.CFrame = CFrame.lookAt(position, position + look)
	bot.vy = 0
end

------------------------------------------------------------------ Moving
-- The floor under a point (its height), looking a little up and down
local function floorAt(position, up, down)
	rayParams.FilterDescendantsInstances = { BotService.Folder }
	rayParams.CollisionGroup = "Runners" -- passes through players and bots
	rayParams.RespectCanCollide = true -- and through bounce pads, lasers, gems
	local hit = Workspace:Raycast(
		position + Vector3.new(0, up or 2, 0),
		Vector3.new(0, -((up or 2) + (down or 6)), 0),
		rayParams
	)
	return hit and hit.Position.Y or nil
end
BotService.FloorAt = floorAt

local function face(bot, position, direction)
	direction = flat(direction)
	if direction.Magnitude > 0.05 then
		bot.root.CFrame = CFrame.lookAt(position, position + direction)
	else
		bot.root.CFrame = CFrame.new(position) * bot.root.CFrame.Rotation
	end
end

local function step()
	return RunService.Heartbeat:Wait()
end

-- Hops over low bars (spinner bars, logs) that are about to reach the bot.
-- bot.hazards is set by HazardCheck. Returns how high the bot is in its hop.
local function hopHeight(bot, base, velocity)
	local t = Motion.Clock()
	if bot.hopStart and t - bot.hopStart < HOP_TIME then
		local share = (t - bot.hopStart) / HOP_TIME
		return 4 * HOP_HEIGHT * share * (1 - share)
	end
	bot.hopStart = nil
	-- Sharp bots see it coming; others sometimes jump a bit early or late
	local lead = 0.12 + random:NextNumber(-0.1, 0.1) * (1.2 - (bot.skill or 0.5))
	for _, hazard in ipairs(bot.hazards or {}) do
		if hazard.low and hazard.spec and BotService.Touching(hazard, base + velocity * lead, t + lead) then
			bot.hopStart = t
			BotService.Animate(bot, "jump")
			return 0
		end
	end
	return 0
end

local function stopHop(bot)
	bot.hopStart = nil
	bot.hopNow = 0
end

-- Things that happen to a bot every frame (set by whoever drives it):
-- bot.onFrame(bot) returns true when the bot was knocked or fell and should stop
local function frame(bot)
	local dt = step()
	local generation = threadGeneration[coroutine.running()]
	if generation and generation ~= bot.generation then
		error("bot stopped", 0)
	end
	-- Bonked by someone's hammer (see BotService.Push)
	local push = bot.pendingPush
	if push and not bot.flying then
		bot.pendingPush = nil
		BotService.Knock(bot, push, flat(push).Magnitude, push.Y)
		error("bot interrupted", 0)
	end
	if bot.onFrame and bot.onFrame(bot) then
		error("bot interrupted", 0)
	end
	return dt
end

-- Falls straight down until it lands (or forever, if there's nothing below)
function BotService.Fall(bot, push)
	stopHop(bot)
	bot.vy = bot.vy or 0
	push = push or Vector3.zero
	BotService.Animate(bot, "fall")
	while true do
		local dt = frame(bot)
		bot.vy -= GRAVITY * dt
		local old = bot.root.Position
		local position = old + push * dt + Vector3.new(0, bot.vy * dt, 0)
		-- Look from just above where the feet were down to where they are now,
		-- so a fast fall can't skip through a thin floor between two frames
		local floor = bot.vy < 0 and floorAt(position, old.Y - position.Y + 1, ROOT_HEIGHT)
		if floor and position.Y - ROOT_HEIGHT <= floor + 0.2 then
			bot.vy = 0
			face(bot, Vector3.new(position.X, floor + ROOT_HEIGHT, position.Z), push)
			return
		end
		face(bot, position, push)
	end
end

-- Runs in a straight line to target, keeping to the floor. Falls if the
-- floor disappears (a dropped tile, a moving platform that left).
function BotService.RunTo(bot, target, speed, close)
	speed = speed or bot.speed
	close = close or 1
	if flat(target - bot.root.Position).Magnitude <= close then
		frame(bot) -- already there: still let a frame pass, so callers' loops always yield
		return
	end
	BotService.Animate(bot, "run", speed / 16)
	while true do
		-- Where the bot would be without its hop
		local position = bot.root.Position - Vector3.new(0, bot.hopNow or 0, 0)
		local offset = flat(target - position)
		if offset.Magnitude <= close then
			if (bot.hopNow or 0) > 0 then
				-- Land the hop before moving on
				face(bot, position, offset)
			end
			stopHop(bot)
			return
		end
		local dt = frame(bot)
		local move = offset.Unit * math.min(offset.Magnitude, speed * dt)
		local nextPosition = position + move
		-- Steps up to 3 studs up, and follows slopes and steps down to 1.5 below the feet
		local floor = floorAt(nextPosition, 3, ROOT_HEIGHT + 1.5)
		if floor then
			nextPosition = Vector3.new(nextPosition.X, floor + ROOT_HEIGHT, nextPosition.Z)
		else
			-- Nothing underfoot: keep running onto the target's height if it's close, else fall
			local expected = target.Y
			if math.abs(nextPosition.Y - ROOT_HEIGHT - expected) > 1.5 then
				face(bot, nextPosition + Vector3.new(0, bot.hopNow or 0, 0), offset)
				stopHop(bot)
				bot.vy = 0
				BotService.Fall(bot, offset.Unit * speed * 0.5)
				return
			end
		end
		bot.hopNow = hopHeight(bot, nextPosition, offset.Unit * speed)
		face(bot, nextPosition + Vector3.new(0, bot.hopNow, 0), offset)
	end
end

-- Jumps in an arc to target (a floor point). Lands on whatever is there.
-- exact = true lands right on target without looking for the floor (moving
-- platforms only move on players' screens, so the server can't see them)
function BotService.JumpTo(bot, target, extraHeight, speed, exact)
	stopHop(bot)
	local from = bot.root.Position
	local to = target + Vector3.new(0, ROOT_HEIGHT, 0)
	local distance = flat(to - from).Magnitude
	speed = speed or bot.speed
	local duration = math.max(0.35, distance / speed)
	local rise = math.max(0, to.Y - from.Y)
	local apex = rise + (extraHeight or 3)
	BotService.Animate(bot, "jump")
	local t = 0
	while t < duration do
		local dt = frame(bot)
		t = math.min(duration, t + dt)
		local share = t / duration
		local along = from:Lerp(to, share)
		-- A parabola through both ends that peaks apex above the start
		local height = from.Y + (to.Y - from.Y) * share + 4 * (apex - rise / 2) * share * (1 - share)
		face(bot, Vector3.new(along.X, height, along.Z), to - from)
	end
	local floor = exact and target.Y or floorAt(bot.root.Position, 1, ROOT_HEIGHT + 1.5)
	if floor then
		face(bot, Vector3.new(to.X, floor + ROOT_HEIGHT, to.Z), to - from)
		BotService.Animate(bot, "run", bot.speed / 16)
	else
		bot.vy = 0
		BotService.Fall(bot, flat(to - from).Unit * 2)
	end
end

-- Waits a moment, standing still
function BotService.Wait(bot, seconds)
	BotService.Animate(bot, "idle")
	local t = 0
	while t < seconds do
		t += frame(bot)
	end
end

-- Waits a moment after a knock before carrying on. Another knock during the
-- wait has already happened (the bot flew and landed), so it just ends the wait.
function BotService.Recover(bot, seconds)
	local ok, err = pcall(BotService.Wait, bot, seconds)
	if not ok and err ~= "bot interrupted" then
		error(err, 0)
	end
end

-- Knocked by an obstacle (or a hammer): flies away, then lands or falls.
-- Same knock as a player gets, so bots fly off edges just like you do.
function BotService.Knock(bot, push, speed, up)
	BotService.Animate(bot, "fall")
	local direction = flat(push)
	direction = direction.Magnitude > 0.1 and direction.Unit or -flat(bot.root.CFrame.LookVector)
	bot.vy = up or Config.HitUp
	local saved = bot.onFrame
	bot.onFrame = nil -- no second knock in the air
	bot.flying = true
	local ok, err = pcall(BotService.Fall, bot, direction * (speed or Config.HitSpeed))
	bot.flying = false
	bot.pendingPush = nil
	bot.onFrame = saved
	if not ok then
		error(err, 0)
	end
end

-- Turns the bot to look at a point
function BotService.Face(bot, target)
	face(bot, bot.root.Position, target - bot.root.Position)
end

-- A hammer hit: the bot flies off with this velocity on its next frame
function BotService.Push(bot, velocity)
	bot.pendingPush = velocity
end

-- Runs fn(bot) in its own thread (stops any earlier one)
function BotService.Start(bot, fn, ...)
	BotService.Stop(bot)
	local generation = bot.generation
	bot.thread = task.spawn(function(...)
		threadGeneration[coroutine.running()] = generation
		local ok, err = pcall(fn, bot, ...)
		if not ok and err ~= "bot interrupted" and err ~= "bot stopped" then
			warn("[BotService] " .. bot.name .. ": " .. tostring(err))
		end
	end, ...)
end

function BotService.Stop(bot)
	bot.generation = (bot.generation or 0) + 1
	if bot.thread and bot.thread ~= coroutine.running() then
		pcall(task.cancel, bot.thread)
	end
	bot.thread = nil
	bot.onFrame = nil
	bot.pendingPush = nil
	bot.flying = false
	bot.hazards = nil
	bot.onSpec = nil
	stopHop(bot)
end

------------------------------------------------------------------ Racing a course
-- The obstacles that matter to a bot in a course or arena (anything with a
-- folder), found once and kept on it
local function hazardsOf(course)
	if course.botHazards then
		return course.botHazards
	end
	local list = {}
	for _, part in ipairs(course.folder:GetDescendants()) do
		if part:IsA("BasePart") then
			local hit = CollectionService:HasTag(part, "Hit")
			local kill = CollectionService:HasTag(part, "Kill")
			if hit or kill then
				local moving = CollectionService:HasTag(part, Motion.Tag)
				local hazard = {
					part = part,
					spec = moving and Motion.Read(part) or nil,
					hit = hit,
					size = part.Size,
					ball = part.Shape == Enum.PartType.Ball,
					low = part:GetAttribute("Low") == true,
				}
				if moving then
					-- The sweeper speeds up by changing its attributes
					part.AttributeChanged:Connect(function()
						hazard.spec = Motion.Read(part)
					end)
				end
				table.insert(list, hazard)
			end
		end
	end
	course.botHazards = list
	return list
end

BotService.Hazards = hazardsOf

-- Is the bot touching this hazard right now? Returns the push direction.
local function touching(hazard, position, t)
	local cframe, state = hazard.part.CFrame, "solid"
	if hazard.spec then
		cframe, state = Motion.At(hazard.spec, t)
	end
	if state == "gone" then
		return nil
	end
	local size = hazard.size
	if (cframe.Position - position).Magnitude > math.max(size.X, size.Y, size.Z) + 4 then
		return nil
	end
	for _, height in ipairs({ -2, 0, 1.5 }) do
		local point = position + Vector3.new(0, height, 0)
		local inside
		if hazard.ball then
			inside = (point - cframe.Position).Magnitude < size.X / 2 + 1
		else
			local offset = cframe:PointToObjectSpace(point)
			inside = math.abs(offset.X) <= size.X / 2 + 0.6
				and math.abs(offset.Y) <= size.Y / 2 + 0.6
				and math.abs(offset.Z) <= size.Z / 2 + 0.6
		end
		if inside then
			local push = hazard.spec and Motion.VelocityAt(hazard.spec, t, point) or Vector3.zero
			if flat(push).Magnitude < 3 then
				push = position - cframe.Position
			end
			return push
		end
	end
	return nil
end

BotService.Touching = touching

-- Checks a bot against hazards every frame: knocks it on a hit, calls onKill
-- on lava or a laser. Use as bot.onFrame.
function BotService.HazardCheck(holder, onKill)
	local hazards = hazardsOf(holder)
	return function(bot)
		bot.hazards = hazards -- for hopping over low bars (see RunTo)
		local position = bot.root.Position
		local t = Motion.Clock()
		for _, hazard in ipairs(hazards) do
			local push = touching(hazard, position, t)
			if push then
				if hazard.hit then
					BotService.Knock(bot, push)
				else
					onKill(bot)
				end
				return true
			end
		end
		return false
	end
end

-- Where the bot picks up the path after a checkpoint (or the start)
local function nodeAfterCheckpoint(nodes, checkpoint)
	if checkpoint <= 0 then
		return 1
	end
	for index, node in ipairs(nodes) do
		if node.kind == "checkpoint" and node.index == checkpoint then
			return index + 1
		end
	end
	return 1
end

local function platformAt(spec, t)
	local cframe, state = Motion.At(spec, t)
	return cframe, state
end

-- Would running from one point to another at this speed, starting now, get
-- the bot hit by a moving obstacle? (Low bars don't count: bots hop those.)
local function pathIsClear(bot, from, to, speed)
	local hazards = bot.hazards
	if not hazards then
		return true
	end
	local t0 = Motion.Clock()
	local distance = (to - from).Magnitude
	local duration = distance / speed
	local step = 0.05
	local time = 0
	while time <= duration + 0.2 do
		local position = from:Lerp(to, math.min(1, time / math.max(duration, 0.01)))
		for _, hazard in ipairs(hazards) do
			if hazard.spec and not hazard.low and touching(hazard, position, t0 + time) then
				return false
			end
		end
		time += step
	end
	return true
end

-- Waits for a clear moment to run from where the bot is to target. Sharp
-- bots wait for a really clear run; hasty ones sometimes just go for it.
local function waitForGap(bot, target, speed, patience)
	if random:NextNumber() > bot.skill + 0.35 then
		patience = math.min(patience, random:NextNumber(0.3, 1.5))
	end
	local waited = 0
	while waited < patience do
		if pathIsClear(bot, bot.root.Position, target, speed) then
			return
		end
		BotService.Animate(bot, "idle")
		waited += frame(bot)
	end
end

-- Follows one path node. run = the bot's CourseService run.
local function follow(bot, _run, node)
	local kind = node.kind
	local now = Motion.Clock
	if kind == "jump" then
		BotService.JumpTo(bot, node.to, 3)
	elseif kind == "bounce" then
		BotService.JumpTo(bot, node.to, 9, bot.speed * 1.3)
	elseif kind == "climb" then
		-- Up the truss
		BotService.Animate(bot, "climb")
		local from = bot.root.Position
		local to = node.to + Vector3.new(0, ROOT_HEIGHT, 0)
		local base = Vector3.new(to.X, from.Y, to.Z)
		BotService.RunTo(bot, base - flat(to - from).Unit * 2, bot.speed, 1)
		BotService.Animate(bot, "climb")
		local y = bot.root.Position.Y
		while y < to.Y do
			y = math.min(to.Y, y + 12 * frame(bot))
			face(bot, Vector3.new(bot.root.Position.X, y, bot.root.Position.Z), to - from)
		end
		BotService.JumpTo(bot, node.to, 2)
	elseif kind == "slide" then
		BotService.RunTo(
			bot,
			node.to + Vector3.new(random:NextNumber(-node.dodge, node.dodge), ROOT_HEIGHT, 0),
			bot.speed * 1.4,
			2
		)
	elseif kind == "zip" then
		BotService.RunTo(bot, node.from - Vector3.new(0, 7 - ROOT_HEIGHT, 0), bot.speed, 2)
		BotService.Animate(bot, "climb")
		local along, total = 0, (node.to - node.from).Magnitude
		while along < total do
			along += ZIP_SPEED * frame(bot)
			face(bot, node.from:Lerp(node.to, math.min(1, along / total)), node.to - node.from)
		end
		bot.vy = 8
		BotService.Fall(bot, flat(node.to - node.from).Unit * 18)
	elseif kind == "wait" then
		-- A laser gate: walk up, wait for it to switch off, then go
		BotService.RunTo(bot, node.at + Vector3.new(0, ROOT_HEIGHT, 0))
		local patience = 0
		while true do
			local _, state = platformAt(node.spec, now())
			local u = (now() + node.spec.phase) % node.spec.period
			local offLeft = node.spec.period - u
			-- Careful bots wait for the very start of the gap; hasty ones guess
			if state == "gone" and (offLeft > 0.6 or random:NextNumber() > bot.skill) then
				break
			end
			patience += frame(bot)
			if patience > node.spec.period * 2 then
				break
			end
		end
		BotService.RunTo(bot, node.past + Vector3.new(0, ROOT_HEIGHT, 0), bot.speed * 1.1)
	elseif kind == "ride" then
		if node.rock or node.spin then
			BotService.RunTo(bot, node.enter + Vector3.new(0, ROOT_HEIGHT, 0))
			BotService.RunTo(bot, node.exit + Vector3.new(0, ROOT_HEIGHT, 0))
			return
		end
		-- Moving platforms: hop on when one comes close, ride it, and hop off
		-- (or straight onto the next platform) when the way on is in reach
		local spec = node.spec
		local top = node.enter.Y
		local function topOf(platformSpec, t)
			local position = platformAt(platformSpec, t).Position
			return Vector3.new(position.X, top, position.Z)
		end
		local nextNode = bot.nextNode
		local nextSpec = nextNode and nextNode.kind == "ride" and not (nextNode.rock or nextNode.spin) and nextNode.spec
		local function jumpOnto(platformSpec)
			local reach = flat(topOf(platformSpec, now() + 0.4) - bot.root.Position).Magnitude
			local duration = math.max(0.35, reach / bot.speed)
			BotService.JumpTo(bot, topOf(platformSpec, now() + duration), 2, nil, true)
		end
		if bot.onSpec ~= spec then
			BotService.RunTo(bot, node.enter + Vector3.new(0, ROOT_HEIGHT, 0))
			local waited = 0
			while waited < spec.period * 1.5 do
				if flat(topOf(spec, now() + 0.4) - node.enter).Magnitude < 8 then
					break
				end
				waited += frame(bot)
			end
			jumpOnto(spec)
		end
		bot.onSpec = nil
		local onPlatform = platformAt(spec, now()):ToObjectSpace(bot.root.CFrame)
		local ridden = 0
		while ridden < spec.period * 2 do
			local t = now()
			bot.root.CFrame = platformAt(spec, t) * onPlatform
			-- (a jump of up to about 16 studs, like a running player's)
			local goal = nextSpec and topOf(nextSpec, t + 0.8) or node.exit
			if flat(goal - bot.root.Position).Magnitude < (nextSpec and 16.5 or 12) then
				if nextSpec then
					jumpOnto(nextSpec)
					bot.onSpec = nextSpec
				else
					BotService.JumpTo(bot, node.exit, 3)
				end
				return
			end
			ridden += frame(bot)
		end
		BotService.JumpTo(bot, node.exit, 3)
	elseif kind == "doors" then
		-- Guess a door; a solid one bonks you back and you try a fake one
		local pick = node.all[random:NextInteger(1, #node.all)]
		local fake = nil
		for _, choice in ipairs(node.choices) do
			if flat(choice - pick).Magnitude < 5 then
				fake = choice
			end
		end
		BotService.RunTo(bot, pick + Vector3.new(0, ROOT_HEIGHT, 0))
		if not fake then
			-- Bonk! Back off and run at a fake one
			BotService.Wait(bot, 0.4)
			fake = node.choices[random:NextInteger(1, #node.choices)]
			for _, front in ipairs(node.all) do
				if flat(front - fake).Magnitude < 5 then
					BotService.RunTo(bot, front + Vector3.new(0, ROOT_HEIGHT, 0))
				end
			end
		end
		BotService.RunTo(bot, fake + Vector3.new(0, ROOT_HEIGHT, 0))
	elseif kind == "tiles" then
		-- Blinking tiles: hop onto one that will still be solid when we land.
		-- Sharp bots wait for a good one; others sometimes just go for it.
		local landIn = 0.6
		local best = nil
		for _ = 1, 40 do
			local t = now() + landIn
			local options = {}
			for _, choice in ipairs(node.choices) do
				local _, state = platformAt(choice.spec, t)
				local _, later = platformAt(choice.spec, t + 0.5)
				if state == "solid" and later ~= "gone" then
					table.insert(options, choice)
				end
			end
			if #options > 0 then
				best = options[random:NextInteger(1, #options)]
				break
			elseif random:NextNumber() > bot.skill + 0.3 then
				break
			end
			BotService.Wait(bot, 0.1)
		end
		best = best or node.choices[random:NextInteger(1, #node.choices)]
		BotService.JumpTo(bot, best.at, 2)
	elseif kind == "dodge" then
		-- A boulder lane: run up the lane with the farthest boulder
		local lanes = node.lanes or { 0 }
		local x = lanes[random:NextInteger(1, #lanes)]
		local cursor = node.cursor
		-- In the piece's own space (forward is -Z, as in Kit's Piece:P)
		local length = -cursor:PointToObjectSpace(node.to).Z
		local up = Vector3.new(0, ROOT_HEIGHT, 0)
		local function at(laneX, z, y)
			return cursor:PointToWorldSpace(Vector3.new(laneX, y or 0, -z)) + up
		end
		local rise = node.rise or 0
		local function onRamp(laneX, z)
			return at(laneX, z, rise * math.clamp(z / length, 0, 1))
		end
		-- Will this spot (moving up the ramp from z) be clear for the next few moments?
		local function clearFor(laneX, z, seconds)
			local t = now()
			local time = 0
			while time <= seconds do
				local spot = onRamp(laneX, z + bot.speed * time)
				for _, hazard in ipairs(bot.hazards or {}) do
					if hazard.spec and touching(hazard, spot, t + time) then
						return false, time
					end
				end
				time += 0.05
			end
			return true, seconds
		end
		-- Wait a little back from the bottom (boulders roll on past it), then
		-- run up, stepping into another lane whenever a boulder is coming.
		-- Sharp bots look further ahead.
		local look = 0.35 + 0.45 * bot.skill
		local back = -14
		BotService.RunTo(bot, onRamp(x, back))
		local waited = 0
		while waited < 4 and not clearFor(x, back, look * 1.5) do
			BotService.Animate(bot, "idle")
			waited += frame(bot)
		end
		local z = back
		while z < length - 0.5 do
			local here = cursor:PointToObjectSpace(bot.root.Position)
			z = math.max(z, -here.Z)
			local best, bestTime = x, -1
			local ordered = table.clone(lanes)
			table.sort(ordered, function(a, b)
				return math.abs(a - here.X) < math.abs(b - here.X)
			end)
			for _, laneX in ipairs(ordered) do
				local clear, time = clearFor(laneX, z, look)
				if clear then
					best = laneX
					break
				elseif time > bestTime then
					best, bestTime = laneX, time
				end
			end
			x = best
			BotService.RunTo(bot, onRamp(x, math.min(length, z + 2.5)), bot.speed, 0.8)
			z = math.min(length, z + 2.5)
		end
		BotService.RunTo(bot, onRamp(x, length))
	elseif kind == "fall" then
		-- Falling tiles: row by row, onto the nearest tile that isn't falling
		for _, row in ipairs(node.rows) do
			local waited = 0
			local pick = nil
			while not pick do
				local x = bot.root.Position
				local bestDistance = math.huge
				for _, tile in ipairs(row) do
					if not tile.part:GetAttribute("Falling") then
						local distance = flat(tile.at - x).Magnitude
						if distance < bestDistance then
							pick, bestDistance = tile, distance
						end
					end
				end
				if not pick then
					if waited > 3 then
						pick = row[random:NextInteger(1, #row)]
					else
						BotService.Animate(bot, "idle")
						waited += frame(bot)
					end
				end
			end
			BotService.RunTo(bot, pick.at + Vector3.new(0, ROOT_HEIGHT, 0), bot.speed, 1.5)
		end
	elseif node.to then
		-- "go" and anything else with a target: run there. Past moving
		-- obstacles, wait for a gap first.
		local target = node.to + Vector3.new(0, ROOT_HEIGHT, 0)
		if node.hazard then
			waitForGap(bot, target, bot.speed, 5)
		end
		BotService.RunTo(bot, target)
	end
end

-- The path node closest to the bot, from the last checkpoint on
local function nearestNode(nodes, from, position)
	local best, bestDistance = from, math.huge
	for index = from, #nodes do
		local target = nodes[index].to or nodes[index].enter or nodes[index].at or nodes[index].from
		if typeof(target) == "Vector3" then
			local distance = (target - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

-- Races a course run until it finishes. Picks up again after every knock and fall.
function BotService.Race(bot, run, fromNode)
	local course = run.instance.course
	local nodes = course.nodes
	local function drive(first)
		local check = BotService.HazardCheck(course, function()
			CourseService.Respawn(run)
		end)
		bot.onFrame = function()
			return not run.finished and check(bot)
		end
		while run.frozen do
			BotService.Animate(bot, "idle")
			step()
		end
		for index = first, #nodes do
			bot.model:SetAttribute("PathNode", index) -- shows where a bot is in Studio's Properties
			bot.nextNode = nodes[index + 1]
			follow(bot, run, nodes[index])
		end
		-- Past the finish: stop and wait
		bot.onFrame = nil
		BotService.Animate(bot, "idle")
	end
	BotService.Start(bot, function()
		local first = fromNode or nodeAfterCheckpoint(nodes, run.checkpoint)
		while true do
			local ok, err = pcall(drive, first)
			if ok then
				return
			elseif err ~= "bot interrupted" then
				error(err, 0)
			end
			-- Knocked but landed: shake it off and carry on from the closest bit
			-- of path. (A fall below the course comes back through Respawned.)
			bot.onFrame = nil
			if run.finished or run.respawning then
				return
			end
			BotService.Recover(bot, 0.3)
			first = nearestNode(nodes, nodeAfterCheckpoint(nodes, run.checkpoint), bot.root.Position)
		end
	end)
end

-- CourseService put the bot back at a checkpoint (onPlaceBot)
function BotService.Respawned(bot, run, cframe)
	BotService.Stop(bot)
	BotService.Place(bot, cframe)
	if not run.finished then
		BotService.Race(bot, run)
	end
end

-- Runners (players and bots) pass through each other, so nobody blocks a
-- narrow beam and the anchored bots can't trap anyone
local function joinRunners(character)
	local function set(item)
		if item:IsA("BasePart") then
			item.CollisionGroup = "Runners"
		end
	end
	for _, item in ipairs(character:GetDescendants()) do
		set(item)
	end
	character.DescendantAdded:Connect(set)
end

function BotService.Init()
	BotService.Folder = Instance.new("Folder")
	BotService.Folder.Name = "Bots"
	BotService.Folder.Parent = Workspace
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Runners")
	end)
	PhysicsService:CollisionGroupSetCollidable("Runners", "Runners", false)
	local function watch(player)
		player.CharacterAdded:Connect(joinRunners)
		if player.Character then
			joinRunners(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return BotService
