-- Loads, saves and hands out each player's save data.
-- Other scripts change data with DataService.Update(player, function(data) ... end)
-- so the player's screen and leaderboard always refresh afterwards.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Level = require(Shared.Level)

local DataService = {}

local LOCK_EXPIRES = 15 * 60 -- a lock older than this is from a crashed server

local function defaultData()
	return {
		coins = 0,
		totalEarned = 0,
		xp = 0,
		tutorial = 1, -- step of the first-time guide (Shared/Tutorial)
		adventure = {}, -- [courseId] = { done = true, best = seconds, stars = bits, gems = bits, runs = n }
		stats = {
			courses = 0, -- Adventure courses finished
			stars = 0,
			gems = 0,
			falls = 0,
			tournaments = 0,
			crowns = 0, -- tournaments won
			rounds = 0, -- tournament rounds survived
			races = 0,
			qualified = 0,
			kos = 0,
			bonks = 0,
		},
		weekly = { week = 0, crowns = 0 }, -- for the weekly leaderboard
		daily = { day = 0, best = 0 }, -- the Daily Challenge
		quests = { day = 0, list = {} },
		cosmetics = {
			owned = {}, -- [cosmeticId] = true
			equipped = {}, -- [kind] = cosmeticId
		},
		levelRewards = 1, -- highest level whose reward was paid
		purchases = {}, -- [receiptPurchaseId] = true
		lastDailyDay = 0,
		dailyStreak = 0,
	}
end

-- Fill in any fields missing from older saves
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = table.clone(value)
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local store = nil
local savingEnabled = true
local profiles = {} -- [player] = { data = {}, runtime = {} }
local listeners = {} -- functions called after any data change

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		savingEnabled = false
		warn("[DataService] DataStores unavailable, progress will not save: " .. tostring(result))
	end
end

local function keyFor(player)
	return "player_" .. player.UserId
end

local function loadData(player)
	if not store then
		return defaultData(), false
	end

	local key = keyFor(player)
	for attempt = 1, 6 do
		local lockedElsewhere = false
		local stealLock = attempt >= 4 -- after ~15 seconds, assume the old server is gone
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(saved)
				saved = saved or { data = defaultData() }
				local lock = saved.lock
				if lock and lock.jobId ~= game.JobId and os.time() - lock.time < LOCK_EXPIRES and not stealLock then
					lockedElsewhere = true
					return nil
				end
				saved.lock = { jobId = game.JobId, time = os.time() }
				return saved
			end)
		end)

		if ok and not lockedElsewhere and result then
			return reconcile(result.data or defaultData(), defaultData()), true
		end

		if not ok then
			local message = tostring(result)
			warn(string.format("[DataService] Load attempt %d failed for %s: %s", attempt, player.Name, message))
			if RunService:IsStudio() then
				-- Usually an unpublished place, or "Enable Studio Access to API Services" is off
				return defaultData(), false
			end
		end
		task.wait(5)
	end
	return nil, false
end

local function saveData(player, release)
	local profile = profiles[player]
	if not profile or not profile.canSave then
		return true
	end
	local data = profile.data
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(saved)
			saved = saved or {}
			if saved.lock and saved.lock.jobId ~= game.JobId then
				-- Another server took over this player; don't overwrite newer data
				return nil
			end
			saved.data = data
			saved.lock = (not release) and { jobId = game.JobId, time = os.time() } or nil
			return saved
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end

	-- Global leaderboards: most crowns, most stars, most crowns this week
	pcall(function()
		local key = tostring(player.UserId)
		DataStoreService:GetOrderedDataStore(Config.CrownsStoreName):SetAsync(key, data.stats.crowns)
		DataStoreService:GetOrderedDataStore(Config.StarsStoreName):SetAsync(key, data.stats.stars)
		if data.weekly.crowns > 0 then
			DataStoreService:GetOrderedDataStore(Config.WeeklyCrownsStorePrefix .. data.weekly.week)
				:SetAsync(key, data.weekly.crowns)
		end
	end)
	return ok
end

local function setupLeaderstats(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in ipairs({ "Level", "Stars", "Crowns" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

local function refresh(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Level.Value = Level.FromXp(data.xp)
		stats.Stars.Value = data.stats.stars
		stats.Crowns.Value = data.stats.crowns
	end
	for _, listener in ipairs(listeners) do
		task.spawn(listener, player, data, profile.runtime)
	end
	Remotes.DataUpdate:FireClient(player, data, profile.runtime)
end

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.data
end

-- Runtime info that is not saved (game passes owned, ...)
function DataService.GetRuntime(player)
	local profile = profiles[player]
	return profile and profile.runtime
end

function DataService.Update(player, change)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local results = table.pack(change(profile.data, profile.runtime))
	refresh(player)
	return table.unpack(results, 1, results.n)
end

function DataService.Refresh(player)
	refresh(player)
end

-- Called with (player, data, runtime) after every change
function DataService.OnChanged(listener)
	table.insert(listeners, listener)
end

function DataService.SaveNow(player)
	return saveData(player, false)
end

function DataService.IsLoaded(player)
	return profiles[player] ~= nil
end

-- Waits until the player's data has loaded (or they left)
function DataService.WaitFor(player)
	while player.Parent and not profiles[player] do
		task.wait(0.2)
	end
	return profiles[player] ~= nil
end

local loadedCallbacks = {}
-- callback(player, data, runtime) runs once per player, before the data is shared.
-- It may yield, but must not call DataService.Get/Update for that player.
function DataService.OnLoaded(callback)
	table.insert(loadedCallbacks, callback)
end

local function onPlayerAdded(player)
	setupLeaderstats(player)
	local data, canSave = loadData(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("We couldn't load your save. Please rejoin in a minute.")
		return
	end
	-- Loaded callbacks fill in runtime info (like game passes) before anything else sees the data
	local runtime = { passes = {} }
	for _, callback in ipairs(loadedCallbacks) do
		callback(player, data, runtime)
	end
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, runtime = runtime, canSave = canSave and savingEnabled }
	refresh(player)
	if not profiles[player].canSave then
		Remotes.Notify:FireClient(player, "Saving is off (in Studio, turn on API Services to test saving).", "warning")
	end
end

local function onPlayerRemoving(player)
	if profiles[player] then
		saveData(player, true)
		profiles[player] = nil
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in pairs(profiles) do
				task.spawn(saveData, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveData(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
