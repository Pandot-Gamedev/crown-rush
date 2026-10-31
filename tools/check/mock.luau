-- A small stand-in for Roblox, so the game's scripts can run outside Studio
-- with Lune (https://lune-org.github.io/docs). Only what the course builders
-- and checks need: instances with properties, attributes and tags, a few
-- services, Random, and require() that follows the Rojo layout in src/.
--
-- Lune gives the real maths types (CFrame, Vector3, Color3, Enum...).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Mock = {}
Mock.Sent = {}
Mock.Warnings = {}

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

------------------------------------------------------------------ Signals
local function signal()
	local handlers = {}
	local s = {}
	function s:Connect(fn)
		table.insert(handlers, fn)
		return {
			Disconnect = function()
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
	end
	s.Once = s.Connect
	local waiting = {}
	function s:Wait()
		table.insert(waiting, coroutine.running())
		return coroutine.yield()
	end
	function s:Fire(...)
		for _, fn in ipairs(table.clone(handlers)) do
			fn(...)
		end
		local threads = waiting
		waiting = {}
		for _, thread in ipairs(threads) do
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, ...)
			end
		end
	end
	return s
end
Mock.Signal = signal

------------------------------------------------------------------ Instances
local PARTS =
	{ Part = true, TrussPart = true, SpawnLocation = true, WedgePart = true, MeshPart = true, CornerWedgePart = true }
local SUPER = {
	BasePart = PARTS,
	GuiObject = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ScrollingFrame = true },
	LuaSourceContainer = { Script = true, LocalScript = true, ModuleScript = true },
	PVInstance = {
		Model = true,
		Part = true,
		TrussPart = true,
		SpawnLocation = true,
		WedgePart = true,
		MeshPart = true,
	},
}

local tags = setmetatable({}, { __mode = "k" }) -- [instance] = { [tag] = true }
local tagAdded, tagRemoved = {}, {}

local Inst = {}
local methods = {}
local mt = {}

local function isInstance(value)
	return type(value) == "table" and getmetatable(value) == mt
end
Mock.IsInstance = isInstance

function Inst.new(className, parent)
	local self = setmetatable({}, mt)
	rawset(self, "_class", className)
	rawset(self, "_props", { Name = className })
	rawset(self, "_attrs", {})
	rawset(self, "_children", {})
	rawset(self, "_signals", {})
	local props = rawget(self, "_props")
	if className == "ProximityPrompt" then
		props.Triggered = signal()
		props.PromptShown = signal()
		props.PromptHidden = signal()
	end
	if className == "TeleportOptions" then
		props.SetTeleportData = function(options, data)
			rawget(options, "_props")._data = data
		end
	end
	if PARTS[className] then
		props.Size = className == "SpawnLocation" and Vector3.new(12, 1, 12) or Vector3.new(4, 1, 2)
		props.CFrame = CFrame.new()
		props.Anchored = false
		props.CanCollide = true
		props.CanQuery = true
		props.CanTouch = true
		props.Transparency = 0
		props.Shape = roblox.Enum.PartType.Block
		props.Color = roblox.Color3.fromRGB(163, 162, 165)
		props.AssemblyLinearVelocity = Vector3.zero
		props.AssemblyAngularVelocity = Vector3.zero
	end
	if className == "Humanoid" then
		props.Health = 100
		props.WalkSpeed = 16
		props.SetStateEnabled = function() end
		props.ChangeState = function() end
		props.MoveTo = function() end
	end
	if className == "RemoteEvent" then
		props.OnServerEvent = signal()
		props.OnClientEvent = signal()
		-- What the server sent to players: Mock.Sent[remoteName] = { {player, ...}, ... }
		props.FireClient = function(self, player, ...)
			local name = rawget(self, "_props").Name
			Mock.Sent[name] = Mock.Sent[name] or {}
			table.insert(Mock.Sent[name], table.pack(player, ...))
		end
		props.FireAllClients = function(self, ...)
			local name = rawget(self, "_props").Name
			Mock.Sent[name] = Mock.Sent[name] or {}
			table.insert(Mock.Sent[name], table.pack("all", ...))
		end
		props.FireServer = function() end
	elseif className == "RemoteFunction" then
		props.InvokeServer = function() end
		props.InvokeClient = function() end
	elseif className == "BindableEvent" then
		local event = signal()
		props.Event = event
		props.Fire = function(_, ...)
			event:Fire(...)
		end
	elseif className == "BindableFunction" then
		props.Invoke = function(this, ...)
			return rawget(this, "_props").OnInvoke(...)
		end
	end
	if parent then
		self.Parent = parent
	end
	return self
end

mt.__index = function(self, key)
	local own = rawget(self, "_props")[key]
	if type(own) == "function" then
		return own -- a service's own version of a method (CollectionService:AddTag)
	end
	local method = methods[key]
	if method then
		return method
	end
	local props = rawget(self, "_props")
	if key == "ClassName" then
		return rawget(self, "_class")
	elseif key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "Position" and props.CFrame then
		return props.CFrame.Position
	elseif
		key == "Destroying"
		or key == "AncestryChanged"
		or key == "Changed"
		or key == "DescendantAdded"
		or key == "DescendantRemoving"
		or key == "ChildAdded"
		or key == "ChildRemoved"
		or key == "AttributeChanged"
	then
		local list = rawget(self, "_signals")
		list[key] = list[key] or signal()
		return list[key]
	elseif key == "Orientation" and props.CFrame then
		local x, y, z = props.CFrame:ToOrientation()
		return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
	end
	local value = props[key]
	if value ~= nil then
		return value
	end
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").Name == key then
			return child
		end
	end
	return nil
end

mt.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	elseif key == "Position" and props.CFrame then
		props.CFrame = props.CFrame.Rotation + value
		return
	end
	props[key] = value
	local changed = rawget(self, "_signals")["prop:" .. key]
	if changed then
		changed:Fire()
	end
end

mt.__tostring = function(self)
	return rawget(self, "_props").Name
end

function methods:IsA(className)
	local own = rawget(self, "_class")
	if own == className or className == "Instance" then
		return true
	end
	local set = SUPER[className]
	return set ~= nil and set[own] == true
end

function methods:GetChildren()
	return table.clone(rawget(self, "_children"))
end

function methods:GetDescendants()
	local out = {}
	local function walk(item)
		for _, child in ipairs(rawget(item, "_children")) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function methods:FindFirstChild(name, recursive)
	local list = recursive and self:GetDescendants() or rawget(self, "_children")
	for _, child in ipairs(list) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

function methods:WaitForChild(name)
	local found = self:FindFirstChild(name)
	if not found then
		error("WaitForChild would wait forever: " .. self:GetFullName() .. "." .. name, 2)
	end
	return found
end

function methods:FindFirstChildOfClass(className)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_class") == className then
			return child
		end
	end
	return nil
end

function methods:FindFirstChildWhichIsA(className, recursive)
	local list = recursive and self:GetDescendants() or rawget(self, "_children")
	for _, child in ipairs(list) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

function methods:FindFirstAncestorWhichIsA(className)
	local item = rawget(self, "_parent")
	while item do
		if item:IsA(className) then
			return item
		end
		item = rawget(item, "_parent")
	end
	return nil
end

function methods:GetFullName()
	local names = {}
	local item = self
	while item and rawget(item, "_class") ~= "DataModel" do
		table.insert(names, 1, item.Name)
		item = rawget(item, "_parent")
	end
	return table.concat(names, ".")
end

function methods:Destroy()
	self.Parent = nil
	for _, child in ipairs(self:GetChildren()) do
		child:Destroy()
	end
	rawset(self, "_destroyed", true)
end

function methods:ClearAllChildren()
	for _, child in ipairs(self:GetChildren()) do
		child:Destroy()
	end
end

function methods:Clone()
	local copy = Inst.new(rawget(self, "_class"))
	for key, value in pairs(rawget(self, "_props")) do
		rawget(copy, "_props")[key] = value
	end
	for key, value in pairs(rawget(self, "_attrs")) do
		rawget(copy, "_attrs")[key] = value
	end
	for tag in pairs(tags[self] or {}) do
		Mock.AddTag(copy, tag)
	end
	for _, child in ipairs(rawget(self, "_children")) do
		child:Clone().Parent = copy
	end
	return copy
end

function methods:SetAttribute(name, value)
	rawget(self, "_attrs")[name] = value
	local changed = rawget(self, "_signals")["attr:" .. name]
	if changed then
		changed:Fire()
	end
	local any = rawget(self, "_signals").AttributeChanged
	if any then
		any:Fire(name)
	end
end

function methods:GetAttribute(name)
	return rawget(self, "_attrs")[name]
end

function methods:GetAttributes()
	return table.clone(rawget(self, "_attrs"))
end

local function namedSignal(self, key)
	local list = rawget(self, "_signals")
	list[key] = list[key] or signal()
	return list[key]
end

function methods:GetAttributeChangedSignal(name)
	return namedSignal(self, "attr:" .. name)
end

function methods:GetPropertyChangedSignal(name)
	return namedSignal(self, "prop:" .. name)
end

function methods:AddTag(tag)
	Mock.AddTag(self, tag)
end

function methods:HasTag(tag)
	return tags[self] ~= nil and tags[self][tag] == true
end

function methods:RemoveTag(tag)
	if tags[self] then
		tags[self][tag] = nil
	end
end

-- Models
function methods:GetPivot()
	local primary = rawget(self, "_props").PrimaryPart
	if primary then
		return primary.CFrame
	end
	if rawget(self, "_props").CFrame then
		return rawget(self, "_props").CFrame
	end
	local part = self:FindFirstChildWhichIsA("BasePart", true)
	return part and part.CFrame or CFrame.new()
end

function methods:PivotTo(cframe)
	local from = self:GetPivot()
	local move = cframe * from:Inverse()
	if rawget(self, "_props").CFrame then
		self.CFrame = cframe
	end
	for _, item in ipairs(self:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CFrame = move * item.CFrame
		end
	end
end

function methods:BindToClose() end
function methods:Play() end
function methods:Stop() end
function methods:Emit() end

Mock.Instance = Inst

function Mock.AddTag(item, tag)
	tags[item] = tags[item] or {}
	if not tags[item][tag] then
		tags[item][tag] = true
		if tagAdded[tag] then
			tagAdded[tag]:Fire(item)
		end
	end
end

------------------------------------------------------------------ Random
-- Deterministic, not the same numbers as Roblox (that's fine for checks)
local MockRandom = {}
MockRandom.__index = MockRandom

function MockRandom.new(seed)
	return setmetatable({ state = math.floor(math.abs(seed or os.clock() * 1e6)) % 2147483647 + 1 }, MockRandom)
end

function MockRandom:_next()
	self.state = (self.state * 16807) % 2147483647
	return self.state / 2147483647
end

function MockRandom:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_next()
end

function MockRandom:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

Mock.Random = MockRandom

------------------------------------------------------------------ Services
local game = Inst.new("DataModel")
game.Name = "Game"
Mock.game = game
local clock = 1000

local SERVICES = {}

-- The parts rays can hit, gathered once per clock tick
local rayCache, rayClock = nil, nil
local function rayParts(workspace)
	if rayClock ~= clock or not rayCache then
		rayCache = {}
		for _, item in ipairs(workspace:GetDescendants()) do
			if item:IsA("BasePart") then
				table.insert(rayCache, item)
			end
		end
		rayClock = clock
	end
	return rayCache
end

local function service(name, extra)
	local s = Inst.new(name)
	s.Name = name
	for key, value in pairs(extra or {}) do
		rawget(s, "_props")[key] = value
	end
	s.Parent = game
	SERVICES[name] = s
	return s
end

service("Workspace", {
	Gravity = 196.2,
	GetServerTimeNow = function()
		return clock
	end,
	-- Rays against every part as a box (good enough for floors and walls)
	Raycast = function(self, origin, direction, params)
		params = params or {}
		local parts = rayParts(self)
		local excluded = {}
		for _, item in ipairs(params.FilterDescendantsInstances or {}) do
			excluded[item] = true
		end
		local best, bestT = nil, 1
		for _, part in ipairs(parts) do
			local props = rawget(part, "_props")
			local skip = props.CanQuery == false
				or (params.RespectCanCollide and props.CanCollide == false)
				or (params.CollisionGroup == "Runners" and props.CollisionGroup == "Runners")
			if not skip then
				local item = part
				while item and not skip do
					skip = excluded[item] == true
					item = rawget(item, "_props").Parent
				end
			end
			if not skip then
				local cf, size = props.CFrame, props.Size
				local o = cf:PointToObjectSpace(origin)
				local d = cf:VectorToObjectSpace(direction)
				local half = size / 2
				local tMin, tMax = 0, bestT
				for _, axis in ipairs({ "X", "Y", "Z" }) do
					local oa, da, h = o[axis], d[axis], half[axis]
					if math.abs(da) < 1e-9 then
						if oa < -h or oa > h then
							tMin, tMax = 1, 0
						end
					else
						local t1, t2 = (-h - oa) / da, (h - oa) / da
						if t1 > t2 then
							t1, t2 = t2, t1
						end
						tMin, tMax = math.max(tMin, t1), math.min(tMax, t2)
					end
				end
				if tMin <= tMax and tMin < bestT then
					best, bestT = part, tMin
				end
			end
		end
		if not best then
			return nil
		end
		local position = origin + direction * bestT
		return {
			Instance = best,
			Position = position,
			Distance = (direction * bestT).Magnitude,
			Normal = Vector3.new(0, 1, 0),
		}
	end,
})
service("ReplicatedStorage")
-- Terrain (water and sand in the fishing and digging games): accepts and ignores fills
do
	local terrain = Inst.new("Terrain")
	terrain.Name = "Terrain"
	rawget(terrain, "_props").FillBlock = function() end
	rawget(terrain, "_props").FillBall = function() end
	rawget(terrain, "_props").FillCylinder = function() end
	terrain.Parent = SERVICES.Workspace
end
service("ServerScriptService")
service("ServerStorage")
service("StarterPlayer")
service("Lighting", { ClockTime = 14 })
service("CollectionService", {
	AddTag = function(_, item, tag)
		Mock.AddTag(item, tag)
	end,
	RemoveTag = function(_, item, tag)
		item:RemoveTag(tag)
	end,
	HasTag = function(_, item, tag)
		return item:HasTag(tag)
	end,
	GetTagged = function(_, tag)
		local out = {}
		for item, set in pairs(tags) do
			if set[tag] and not rawget(item, "_destroyed") then
				table.insert(out, item)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		tagAdded[tag] = tagAdded[tag] or signal()
		return tagAdded[tag]
	end,
	GetInstanceRemovedSignal = function(_, tag)
		tagRemoved[tag] = tagRemoved[tag] or signal()
		return tagRemoved[tag]
	end,
})
service("RunService", {
	Heartbeat = signal(),
	Stepped = signal(),
	RenderStepped = signal(),
	PreSimulation = signal(),
	IsStudio = function()
		return Mock.Studio
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
})
local players = service("Players", {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
})
rawget(players, "_props").GetPlayers = function()
	local list = {}
	for _, child in ipairs(rawget(players, "_children")) do
		if rawget(child, "_class") == "Player" then
			table.insert(list, child)
		end
	end
	return list
end
rawget(players, "_props").GetPlayerByUserId = function(_, userId)
	for _, player in ipairs(players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end
rawget(players, "_props").GetNameFromUserIdAsync = function(_, userId)
	return "Player" .. userId
end

-- Communities: Mock.Groups[userId] = { [groupId] = true }
Mock.Groups = {}
Mock.Studio = true -- RunService:IsStudio()
Mock.Teleports = {} -- { placeId, players, data } for every TeleportAsync
Mock.Events = {} -- { player, name, field } for every AnalyticsService custom event
service("GroupService", {
	GetGroupsAsync = function(_, userId)
		local list = {}
		for groupId in pairs(Mock.Groups[userId] or {}) do
			table.insert(list, { Id = groupId, Name = "Group" .. groupId, Rank = 1 })
		end
		return list
	end,
})
service("TeleportService", {
	TeleportInitFailed = signal(),
	TeleportAsync = function(_, placeId, list, options)
		table.insert(Mock.Teleports, { placeId = placeId, players = list, data = options and options._data })
	end,
})
service("AnalyticsService", {
	LogCustomEvent = function(_, player, name, _value, fields)
		table.insert(Mock.Events, { player = player, name = name, fields = fields })
	end,
})

-- A pretend player with a character standing at a position
function Mock.AddPlayer(userId, name, joinData)
	local player = Inst.new("Player")
	local props = rawget(player, "_props")
	props.Name = name
	props.DisplayName = name
	props.UserId = userId
	props.CharacterAdded = signal()
	props.CharacterRemoving = signal()
	props.Kick = function(_, reason)
		print("KICKED: " .. tostring(reason))
	end
	props.RequestStreamAroundAsync = function() end
	props.IsInGroupAsync = function(_, groupId)
		return (Mock.Groups[userId] or {})[groupId] == true
	end
	props.GetJoinData = function()
		return joinData or {}
	end
	props.LoadCharacter = function() end
	local character = Inst.new("Model")
	character.Name = name
	local root = Inst.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Parent = character
	local head = Inst.new("Part")
	head.Name = "Head"
	head.Parent = character
	local humanoid = Inst.new("Humanoid")
	rawget(humanoid, "_props").Health = 100
	rawget(humanoid, "_props").WalkSpeed = 16
	humanoid.Parent = character
	character.PrimaryPart = root
	character.Parent = SERVICES.Workspace
	props.Character = character
	local backpack = Inst.new("Backpack")
	backpack.Name = "Backpack"
	backpack.Parent = player
	player.Parent = players
	players.PlayerAdded:Fire(player)
	return player
end
service("TweenService", {
	Create = function()
		return { Play = function() end, Cancel = function() end, Completed = signal() }
	end,
})
service("Debris", { AddItem = function() end })
service("MarketplaceService", {
	PromptGamePassPurchaseFinished = signal(),
	PromptProductPurchaseFinished = signal(),
	UserOwnsGamePassAsync = function()
		return false
	end,
	GetProductInfo = function()
		return { PriceInRobux = 0 }
	end,
})

-- Saved data lives in memory for one run
local stores = {}
local function store(name, ordered)
	local key = (ordered and "o:" or "d:") .. name
	if stores[key] then
		return stores[key]
	end
	local values = {}
	local s = {}
	function s:GetAsync(k)
		return values[k]
	end
	function s:SetAsync(k, v)
		values[k] = v
	end
	function s:UpdateAsync(k, fn)
		local new = fn(values[k])
		if new ~= nil then
			values[k] = new
		end
		return values[k]
	end
	function s:RemoveAsync(k)
		values[k] = nil
	end
	function s:GetSortedAsync(ascending, size)
		local list = {}
		for k, v in pairs(values) do
			table.insert(list, { key = k, value = v })
		end
		table.sort(list, function(x, y)
			if ascending then
				return x.value < y.value
			end
			return x.value > y.value
		end)
		local page = {}
		for i = 1, math.min(size, #list) do
			page[i] = list[i]
		end
		return {
			GetCurrentPage = function()
				return page
			end,
		}
	end
	stores[key] = s
	return s
end
service("DataStoreService", {
	GetDataStore = function(_, name)
		return store(name, false)
	end,
	GetOrderedDataStore = function(_, name)
		return store(name, true)
	end,
})

service("PhysicsService", {
	RegisterCollisionGroup = function() end,
	CollisionGroupSetCollidable = function() end,
})

function methods:GetService(name)
	return SERVICES[name] or service(name)
end

function Mock.SetClock(seconds)
	clock = seconds
end

------------------------------------------------------------------ Scripts and require
local env

local function typeofMock(value)
	if isInstance(value) then
		return "Instance"
	end
	if getmetatable(value) == MockRandom then
		return "Random"
	end
	return typeof(value)
end

local loaded = {}
local function requireMock(module)
	if type(module) == "string" then
		return require(module)
	end
	if loaded[module] ~= nil then
		return loaded[module]
	end
	local path = rawget(module, "_props").SourcePath
	assert(path, "not a script: " .. tostring(module))
	local source = fs.readFile(path)
	local chunk = luau.load(
		source,
		{ debugName = path, environment = setmetatable({ script = module }, { __index = env }), injectGlobals = false }
	)
	local result = chunk()
	loaded[module] = result
	return result
end

env = {
	warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		local text = table.concat(parts, " ")
		table.insert(Mock.Warnings, text)
		print("WARN: " .. text)
	end,
	game = game,
	workspace = SERVICES.Workspace,
	require = requireMock,
	typeof = typeofMock,
	Instance = { new = Inst.new },
	Random = MockRandom,
	task = task,
	tick = os.clock,
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	BrickColor = roblox.BrickColor,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Font = roblox.Font,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	PhysicalProperties = roblox.PhysicalProperties,
	TweenInfo = {
		new = function(...)
			return { ... }
		end,
	},
	RaycastParams = {
		new = function()
			return {}
		end,
	},
	OverlapParams = {
		new = function()
			return {}
		end,
	},
}
setmetatable(env, { __index = getfenv() })
Mock.require = requireMock

-- Puts src/<folder>/*.luau under a parent like Rojo does (init.*.luau = the folder's own script)
local function mount(srcFolder, parent, name)
	local initFile = nil
	for _, file in ipairs(fs.readDir(srcFolder)) do
		if file:match("^init%.") then
			initFile = file
		end
	end
	local holder
	if initFile then
		local className = initFile:match("server") and "Script"
			or (initFile:match("client") and "LocalScript" or "ModuleScript")
		holder = Inst.new(className)
		rawget(holder, "_props").SourcePath = srcFolder .. "/" .. initFile
	else
		holder = Inst.new("Folder")
	end
	holder.Name = name
	holder.Parent = parent
	for _, file in ipairs(fs.readDir(srcFolder)) do
		if file:match("%.luau$") and not file:match("^init%.") then
			local module = Inst.new("ModuleScript")
			module.Name = file:gsub("%.luau$", "")
			rawget(module, "_props").SourcePath = srcFolder .. "/" .. file
			module.Parent = holder
		end
	end
	return holder
end

function Mock.Mount(root)
	local shared = mount(root .. "/src/shared", SERVICES.ReplicatedStorage, "Shared")
	local server = mount(root .. "/src/server", SERVICES.ServerScriptService, "Server")
	return shared, server
end

return Mock
