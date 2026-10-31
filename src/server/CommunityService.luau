-- Our community and our other games (the "Free Gift" menu). This file is the
-- same in all four games; what differs is passed to CommunityService.Start.
--
-- Join our community: players who are in it (see Shared/OurGames) get a free,
-- looks-only reward once: the cosmetics in options.rewards. Leaving later
-- doesn't take it away.
-- Play our other games: the Play button teleports you to one of the others.
-- Players who arrive from one of our games get a short "welcome" message.
--
-- Custom events (Creator Dashboard > Analytics > Custom): CommunityReward,
-- PlayOtherGame and ArrivedFromOurGame, to see whether any of this works.

local AnalyticsService = game:GetService("AnalyticsService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OurGames = require(Shared.OurGames)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local CommunityService = {}

local CHECK_COOLDOWN = 3 -- seconds between membership checks for one player
local TELEPORT_COOLDOWN = 8

local options = nil -- { gameId, rewards = { cosmetic ids }, equip = { [kind] = id } }
local lastCheck = {} -- [player] = os.clock()
local lastTeleport = {}

local function log(player, eventName, field)
	pcall(function()
		-- "CustomField01" is Enum.AnalyticsCustomFieldKeys.CustomField01.Name
		AnalyticsService:LogCustomEvent(player, eventName, 1, field and { CustomField01 = field } or nil)
	end)
end

-- Asks Roblox whether the player is in our community
function CommunityService.IsMember(player)
	if OurGames.CommunityId == 0 then
		return false
	end
	local ok, member = pcall(function()
		return player:IsInGroupAsync(OurGames.CommunityId)
	end)
	if ok and member then
		return true
	end
	-- IsInGroupAsync can remember an old "no" (from before they joined), so
	-- ask for the player's communities fresh
	local found, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if found and type(groups) == "table" then
		for _, group in ipairs(groups) do
			if group.Id == OurGames.CommunityId then
				return true
			end
		end
	end
	return false
end

-- Hands out any community reward the player doesn't have yet.
-- Returns the number of new items.
local function grant(player)
	local added = DataService.Update(player, function(data)
		data.community = data.community or {}
		local count = 0
		for _, id in ipairs(options.rewards) do
			if not data.cosmetics.owned[id] then
				data.cosmetics.owned[id] = true
				count += 1
			end
		end
		-- Wear the new looks right away, unless something is already on
		for kind, id in pairs(options.equip or {}) do
			if count > 0 and data.cosmetics.equipped[kind] == nil then
				data.cosmetics.equipped[kind] = id
			end
		end
		data.community.claimed = true
		return count
	end)
	return added or 0
end

local function check(player, fromButton)
	if not DataService.IsLoaded(player) then
		return false, "Still loading, try again in a moment"
	end
	local now = os.clock()
	if lastCheck[player] and now - lastCheck[player] < CHECK_COOLDOWN then
		return false, "Checking... try again in a moment"
	end
	lastCheck[player] = now
	local member = CommunityService.IsMember(player)
	player:SetAttribute("CommunityMember", member)
	if not member then
		return false, fromButton and ("Join " .. OurGames.CommunityName .. " first, then press Claim") or nil
	end
	local added = grant(player)
	if added > 0 then
		Remotes.Notify:FireClient(
			player,
			"Thanks for joining " .. OurGames.CommunityName .. "! " .. options.rewardText .. " unlocked.",
			"rare"
		)
		log(player, "CommunityReward")
	end
	return true
end

local function play(player, id)
	local entry = OurGames.ById[id]
	if type(id) ~= "string" or not entry or entry.id == options.gameId then
		return false, "Unknown game"
	end
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < TELEPORT_COOLDOWN then
		return false, "Already on the way..."
	end
	if RunService:IsStudio() then
		return false, "Teleports only work in the live game, not in Studio"
	end
	lastTeleport[player] = now
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({ from = options.gameId })
	local ok = pcall(function()
		TeleportService:TeleportAsync(entry.placeId, { player }, teleportOptions)
	end)
	if not ok then
		lastTeleport[player] = nil
		return false, "Couldn't open " .. entry.name .. " right now. Try again soon."
	end
	log(player, "PlayOtherGame", entry.id)
	return true
end

local function onPlayerAdded(player)
	-- Came over from one of our other games?
	local joinData = player:GetJoinData()
	local from = type(joinData) == "table" and type(joinData.TeleportData) == "table" and joinData.TeleportData.from
	local fromGame = type(from) == "string" and OurGames.ById[from]

	if not DataService.WaitFor(player) then
		return
	end
	if fromGame and fromGame.id ~= options.gameId then
		Remotes.Notify:FireClient(player, "Welcome over from " .. fromGame.name .. "!", "rare")
		log(player, "ArrivedFromOurGame", fromGame.id)
	end
	-- Joined the community on the website? Hand out the reward on arrival.
	check(player, false)
end

-- options: { gameId = "crown", rewards = { ids }, equip = { [kind] = id }, rewardText = "..." }
function CommunityService.Start(startOptions)
	options = startOptions

	local folder = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Community"
	remote.OnServerInvoke = function(player, request, argument)
		if request == "claim" then
			return check(player, true)
		elseif request == "play" then
			return play(player, argument)
		end
		return false
	end
	remote.Parent = folder

	TeleportService.TeleportInitFailed:Connect(function(player)
		lastTeleport[player] = nil
		Remotes.Notify:FireClient(player, "That game couldn't open right now. Try again soon.", "warning")
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player) -- it waits for the save to load
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCheck[player] = nil
		lastTeleport[player] = nil
	end)
end

return CommunityService
