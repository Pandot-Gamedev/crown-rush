-- Moves every obstacle on this player's screen, and handles what obstacles do
-- to this player's own character: riding moving platforms, conveyor belts and
-- slides, bounce pads, wind, ziplines, getting knocked by spinners and hammers,
-- and touching lava or lasers.
--
-- Obstacles move from the server clock (Shared/Motion), so everyone sees them
-- in the same place, and they move perfectly smoothly. Your character is moved
-- by your own computer (that's how Roblox works), so doing these here means no
-- lag between seeing a hammer hit you and flying.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Motion = require(Shared.Motion)
local Remotes = require(Shared.Remotes)

local Movement = {}

local player = Players.LocalPlayer
local ANIMATE_RANGE = 700 -- obstacles farther than this from the camera wait
local HIT_COOLDOWN = 0.7
local KILL_COOLDOWN = 1.2
local ZIP_SPEED = 48

local movers = {} -- [part] = { spec, transparency, collide, state }
local tagged = { Hit = {}, Kill = {}, Bounce = {}, Wind = {}, Zip = {}, Gem = {} }
local lastHit = 0
local lastFell = 0
local lastBounce = 0
local stunToken = 0
local stunnedUntil = 0
local zipping = nil
local ownedGems = {} -- [index] = true for the course you're on
local onLaunch = Instance.new("BindableEvent")
Movement.Launched = onLaunch.Event

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function parts()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

function Movement.IsStunned()
	return os.clock() < stunnedUntil or zipping ~= nil
end

-- Sends your character tumbling with a velocity (obstacle hits, foam hammers)
function Movement.Launch(velocity, stun, spin)
	local root, humanoid = parts()
	if not root then
		return
	end
	if zipping then
		zipping = nil
	end
	stunToken += 1
	local token = stunToken
	stunnedUntil = os.clock() + stun
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = spin or Vector3.zero
	onLaunch:Fire()
	task.delay(stun, function()
		if stunToken ~= token or not humanoid.Parent then
			return
		end
		humanoid.PlatformStand = false
		root.AssemblyAngularVelocity = Vector3.zero
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.1 then
			look = Vector3.new(0, 0, -1)
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end)
end

local function fell()
	local now = os.clock()
	if now - lastFell < KILL_COOLDOWN then
		return
	end
	lastFell = now
	Remotes.Fell:FireServer()
end

------------------------------------------------------------------ Tracking tagged parts
local function addMover(part)
	if part:IsA("BasePart") then
		movers[part] =
			{ spec = Motion.Read(part), transparency = part.Transparency, collide = part.CanCollide, state = "solid" }
		-- Some obstacles change mid-round (sweepers speeding up, lava starting)
		part.AttributeChanged:Connect(function()
			local info = movers[part]
			if info then
				info.spec = Motion.Read(part)
			end
		end)
	end
end

local function track(tag, set, onAdd)
	for _, item in ipairs(CollectionService:GetTagged(tag)) do
		set[item] = true
		if onAdd then
			onAdd(item)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(item)
		set[item] = true
		if onAdd then
			onAdd(item)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(item)
		set[item] = nil
		if tag == Motion.Tag then
			movers[item] = nil
		end
	end)
end

------------------------------------------------------------------ Checks
-- Is any part of the body (feet, middle, head) inside a part's box?
local function touches(cframe, size, root, margin)
	local base = root.Position
	for _, height in ipairs({ -2.2, 0, 1.6 }) do
		local offset = cframe:PointToObjectSpace(base + Vector3.new(0, height, 0))
		if
			math.abs(offset.X) <= size.X / 2 + margin
			and math.abs(offset.Y) <= size.Y / 2 + margin
			and math.abs(offset.Z) <= size.Z / 2 + margin
		then
			return true, base + Vector3.new(0, height, 0)
		end
	end
	return false
end

local function touchesBall(part, root)
	local radius = part.Size.X / 2 + 1.2
	local base = root.Position
	for _, height in ipairs({ -2.2, 0, 1.6 }) do
		local point = base + Vector3.new(0, height, 0)
		if (point - part.Position).Magnitude < radius then
			return true, point
		end
	end
	return false
end

local function feetY(root, humanoid)
	return root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function floorUnder(root, humanoid, character)
	rayParams.FilterDescendantsInstances = { character }
	local depth = humanoid.HipHeight + root.Size.Y / 2 + 1.2
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -depth, 0), rayParams)
	return hit and hit.Instance
end

------------------------------------------------------------------ Every frame
local function step(dt)
	local t = Motion.Clock()
	local camera = Workspace.CurrentCamera
	local focus = camera and camera.CFrame.Position or Vector3.zero
	local root, humanoid, character = parts()

	-- What you stand on, before anything moves
	local floor, floorBefore = nil, nil
	if root and not zipping and humanoid.FloorMaterial ~= Enum.Material.Air then
		floor = floorUnder(root, humanoid, character)
		if floor and movers[floor] then
			floorBefore = floor.CFrame
		end
	end

	-- Move the obstacles
	for part, info in pairs(movers) do
		if part == floor or (part.Position - focus).Magnitude < ANIMATE_RANGE or info.spec.kind == "blink" then
			local cframe, state = Motion.At(info.spec, t)
			part.CFrame = cframe
			if state ~= info.state or state == "warn" then
				info.state = state
				if state == "gone" then
					part.Transparency = 1
					part.CanCollide = false
				elseif state == "warn" then
					part.Transparency = info.transparency + (1 - info.transparency) * (0.35 + 0.3 * math.sin(t * 25))
					part.CanCollide = info.collide
				else
					part.Transparency = info.transparency
					part.CanCollide = info.collide
				end
			end
		end
	end

	if not root then
		return
	end

	-- Ride whatever you stand on
	if floorBefore then
		local relative = floorBefore:ToObjectSpace(root.CFrame)
		local moved = floor.CFrame:ToWorldSpace(relative)
		local look = flat(moved.LookVector)
		if look.Magnitude < 0.1 then
			look = flat(root.CFrame.LookVector)
		end
		root.CFrame = CFrame.lookAt(moved.Position, moved.Position + look)
	end
	if floor then
		local belt = floor:GetAttribute("Belt")
		if typeof(belt) == "Vector3" then
			root.CFrame += belt * dt
		end
	end

	-- Ziplines
	if zipping then
		zipping.along += ZIP_SPEED * dt
		local total = (zipping.to - zipping.from).Magnitude
		local direction = (zipping.to - zipping.from).Unit
		if zipping.along >= total then
			humanoid.PlatformStand = false
			root.CFrame = CFrame.lookAt(zipping.to, zipping.to + flat(direction))
			root.AssemblyLinearVelocity = flat(direction) * 20 + Vector3.new(0, 10, 0)
			zipping = nil
		else
			local at = zipping.from + direction * zipping.along
			root.CFrame = CFrame.lookAt(at, at + flat(direction))
			root.AssemblyLinearVelocity = Vector3.zero
		end
		return
	end
	local feet = feetY(root, humanoid)
	for pad in pairs(tagged.Zip) do
		local offset = root.Position - pad.Position
		if flat(offset).Magnitude < 3.5 and math.abs(feet - pad.Position.Y) < 2 then
			local from, to = pad:GetAttribute("ZipFrom"), pad:GetAttribute("ZipTo")
			if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
				zipping = { from = from, to = to, along = 0 }
				humanoid.PlatformStand = true
				return
			end
		end
	end

	-- Bounce pads
	local now = os.clock()
	if now - lastBounce > 0.4 then
		for pad in pairs(tagged.Bounce) do
			local offset = root.Position - pad.Position
			local radius = math.max(pad.Size.Y, pad.Size.Z) / 2
			if flat(offset).Magnitude < radius and feet - pad.Position.Y < 1.5 and feet - pad.Position.Y > -1.5 then
				local launch = pad:GetAttribute("Launch")
				if typeof(launch) == "Vector3" then
					lastBounce = now
					root.AssemblyLinearVelocity = launch
					humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
					onLaunch:Fire("bounce")
				end
				break
			end
		end
	end

	-- Wind gusts
	for zone in pairs(tagged.Wind) do
		local push = zone:GetAttribute("Push")
		if typeof(push) == "Vector3" and (zone.Position - root.Position).Magnitude < zone.Size.Magnitude then
			local period = zone:GetAttribute("Period") or 4
			local on = zone:GetAttribute("On") or 2
			local blowing = (t + (zone:GetAttribute("Phase") or 0)) % period < on
			zone:SetAttribute("Blowing", blowing)
			if blowing and touches(zone.CFrame, zone.Size, root, 0) then
				root.CFrame += push * dt
			end
		end
	end

	-- Knocks from spinners, hammers, balls and pistons
	if now - lastHit > HIT_COOLDOWN and now > stunnedUntil then
		for part in pairs(tagged.Hit) do
			local info = movers[part]
			if
				info
				and info.state ~= "gone"
				and (part.Position - root.Position).Magnitude < math.max(part.Size.X, part.Size.Y, part.Size.Z) + 6
			then
				local hit, point
				if part.Shape == Enum.PartType.Ball then
					hit, point = touchesBall(part, root)
				else
					hit, point = touches(part.CFrame, part.Size, root, 0.9)
				end
				if hit then
					lastHit = now
					local push = flat(Motion.VelocityAt(info.spec, t, point))
					if push.Magnitude < 3 then
						push = flat(root.Position - part.Position)
					end
					if push.Magnitude < 0.1 then
						push = -flat(root.CFrame.LookVector)
					end
					Movement.Launch(
						push.Unit * Config.HitSpeed + Vector3.new(0, Config.HitUp, 0),
						Config.HitStun,
						push.Unit:Cross(Vector3.yAxis) * 6
					)
					onLaunch:Fire("hit")
					break
				end
			end
		end
	end

	-- Lava, lasers and spikes
	for part in pairs(tagged.Kill) do
		local info = movers[part]
		local live = not info or info.state ~= "gone"
		if live and (part.Position - root.Position).Magnitude < math.max(part.Size.X, part.Size.Z) + 10 then
			if touches(part.CFrame, part.Size, root, 0.2) then
				fell()
				break
			end
		end
	end

	-- Below the course
	local killY = player:GetAttribute("KillY")
	if killY and root.Position.Y < killY then
		fell()
	end
end

-- Dims the gems you already found on this course
local function refreshGems()
	local courseId = player:GetAttribute("Course")
	for gem in pairs(tagged.Gem) do
		local mine = gem:GetAttribute("CourseId") == courseId and ownedGems[gem:GetAttribute("GemIndex")]
		gem.LocalTransparencyModifier = mine and 0.75 or 0
	end
end

function Movement.SetGems(list)
	ownedGems = {}
	for index, value in pairs(list or {}) do
		if value then
			ownedGems[tonumber(index) or index] = true
		end
	end
	refreshGems()
end

function Movement.Init()
	track(Motion.Tag, {}, addMover)
	for name, set in pairs(tagged) do
		track(name, set, name == "Gem" and function()
			task.defer(refreshGems)
		end or nil)
	end
	local event = RunService.PreSimulation or RunService.Stepped
	if event == RunService.Stepped then
		event:Connect(function(_, dt)
			step(dt)
		end)
	else
		event:Connect(step)
	end
	player.CharacterAdded:Connect(function()
		stunToken += 1
		stunnedUntil = 0
		zipping = nil
	end)
	Remotes.Launch.OnClientEvent:Connect(Movement.Launch)
end

return Movement
