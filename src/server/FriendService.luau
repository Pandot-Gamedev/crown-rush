-- Playing with friends: a coin bonus while a Roblox friend is in your server,
-- and a toast when one joins. The Invite button (client Hud) opens Roblox's
-- own invite screen, so friends get a notification to join.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local FriendService = {}

local friendsHere = {} -- [player] = { [other player] = true }

local function isFriend(a, b)
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	return ok and result
end

local function count(player)
	local total = 0
	for _ in pairs(friendsHere[player] or {}) do
		total += 1
	end
	return total
end

local function refresh(player)
	if player.Parent then
		player:SetAttribute("FriendsHere", count(player))
	end
end

-- True while at least one Roblox friend is in the same server
function FriendService.HasFriendHere(player)
	return count(player) > 0
end

function FriendService.Start()
	local bonus = math.floor(Config.FriendCoinBonus * 100 + 0.5)
	local function added(player)
		friendsHere[player] = friendsHere[player] or {}
		for _, other in ipairs(Players:GetPlayers()) do
			if
				other ~= player
				and friendsHere[other]
				and isFriend(player, other)
				-- still here after the check, and not already paired by the other player's join
				and friendsHere[player]
				and friendsHere[other]
				and not friendsHere[player][other]
			then
				friendsHere[player][other] = true
				friendsHere[other][player] = true
				refresh(player)
				refresh(other)
				local text = "%s is here! You both get +%d%% coins while you play together."
				Remotes.Notify:FireClient(player, string.format(text, other.DisplayName, bonus), "success")
				Remotes.Notify:FireClient(other, string.format(text, player.DisplayName, bonus), "success")
			end
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(added, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for other in pairs(friendsHere[player] or {}) do
			if friendsHere[other] then
				friendsHere[other][player] = nil
				refresh(other)
			end
		end
		friendsHere[player] = nil
	end)
end

return FriendService
