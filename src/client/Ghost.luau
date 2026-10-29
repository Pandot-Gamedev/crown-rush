-- The see-through runner you race on Adventure courses: your own best run, or
-- the course record. It replays the saved path from the moment your timer
-- starts, so you can see exactly where you're ahead or behind.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ghost = {}

local model = nil
local parts = {}
local label = nil
local path = nil -- { times = {}, spots = {} } in world space
local startedAt = nil

local function piece(name, size, offset, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.55
	p.Parent = model
	table.insert(parts, { part = p, offset = offset })
	return p
end

local function build(color)
	if model then
		model:Destroy()
	end
	parts = {}
	model = Instance.new("Model")
	model.Name = "Ghost"
	piece("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), color)
	local head = piece("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), color)
	head.Shape = Enum.PartType.Ball
	piece("LeftLeg", Vector3.new(0.9, 2, 0.9), CFrame.new(-0.5, -2, 0), color)
	piece("RightLeg", Vector3.new(0.9, 2, 0.9), CFrame.new(0.5, -2, 0), color)
	piece("LeftArm", Vector3.new(0.8, 1.8, 0.8), CFrame.new(-1.45, 0.1, 0), color)
	piece("RightArm", Vector3.new(0.8, 1.8, 0.8), CFrame.new(1.45, 0.1, 0), color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 30)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Adornee = head
	gui.Parent = model
	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	model.Parent = Workspace
end

-- ghost = { t, p = { t, x, y, z, ... }, name, mine } from the server.
-- origin = the course's CFrame on this server.
function Ghost.Load(ghost, origin)
	Ghost.Clear()
	if not ghost or type(ghost.p) ~= "table" or #ghost.p < 8 then
		return
	end
	path = { times = {}, spots = {} }
	for index = 1, #ghost.p - 3, 4 do
		table.insert(path.times, ghost.p[index])
		table.insert(
			path.spots,
			origin:PointToWorldSpace(Vector3.new(ghost.p[index + 1], ghost.p[index + 2], ghost.p[index + 3]))
		)
	end
	local color = ghost.mine and Color3.fromRGB(120, 220, 255) or Color3.fromRGB(255, 210, 80)
	build(color)
	label.Text = ghost.mine and "Your best" or ("Record: " .. tostring(ghost.name))
	Ghost.Place(0)
end

function Ghost.Clear()
	if model then
		model:Destroy()
		model = nil
	end
	path = nil
	startedAt = nil
end

-- started = the server time your timer started (nil = waiting at the start)
function Ghost.SetStart(started)
	startedAt = started
end

local function spotAt(t)
	local times, spots = path.times, path.spots
	if t <= times[1] then
		return spots[1], spots[2] or spots[1]
	end
	local n = #times
	if t >= times[n] then
		return spots[n], nil
	end
	-- Binary search for the two saved spots around t
	local low, high = 1, n
	while high - low > 1 do
		local middle = (low + high) // 2
		if times[middle] <= t then
			low = middle
		else
			high = middle
		end
	end
	local share = (t - times[low]) / math.max(0.001, times[high] - times[low])
	return spots[low]:Lerp(spots[high], share), spots[high]
end

function Ghost.Place(t)
	if not path or not model then
		return
	end
	local at, ahead = spotAt(t)
	local look = ahead and Vector3.new(ahead.X - at.X, 0, ahead.Z - at.Z) or Vector3.zero
	local base = look.Magnitude > 0.05 and CFrame.lookAt(at, at + look) or CFrame.new(at)
	local finished = t > path.times[#path.times] + 2
	for _, item in ipairs(parts) do
		item.part.CFrame = base * item.offset
		item.part.Transparency = finished and 1 or 0.55
	end
	if label then
		label.Visible = not finished
	end
end

function Ghost.Init()
	RunService.RenderStepped:Connect(function()
		if path and model then
			local t = startedAt and (Workspace:GetServerTimeNow() - startedAt) or 0
			Ghost.Place(t)
		end
	end)
end

return Ghost
