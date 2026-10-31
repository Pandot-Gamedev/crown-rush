-- Checks the Free Gift menu's server side outside Roblox: the community reward
-- (not for non-members, once for members, on arrival or by pressing Claim),
-- the Play buttons (teleport to the right place, never to this game) and the
-- welcome for players coming over from our other games.
--
-- Usage (needs Lune):  lune run tools/check/community.luau
-- The same file runs in all four game repos (it reads the game id from the
-- server script).

local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")
local Mock = require("./mock")

Mock.Mount(process.cwd)
local game = Mock.game
local Shared = game:GetService("ReplicatedStorage").Shared
local OurGames = Mock.require(Shared.OurGames)
OurGames.CommunityId = 777

local serverSource = fs.readFile(process.cwd .. "/src/server/init.server.luau")
local gameId = string.match(serverSource, 'gameId = "(%w+)"')
local rewards = {}
local rewardList = string.match(serverSource, "rewards = {([^}]*)}")
for id in string.gmatch(rewardList or "", '"([%w_]+)"') do
	table.insert(rewards, id)
end

local server = game:GetService("ServerScriptService").Server
Mock.require(server)
local DataService = Mock.require(server.DataService)

local failures = 0
local function expect(condition, text)
	if not condition then
		failures += 1
		print("  FAIL: " .. text)
	end
end

local function waitLoaded(player)
	for _ = 1, 100 do
		if DataService.IsLoaded(player) then
			break
		end
		task.wait(0.05)
	end
	task.wait(0.6) -- the community check runs just after the save loads
	expect(DataService.IsLoaded(player), player.Name .. "'s data loads")
end

local function ownsAll(player)
	local data = DataService.Get(player)
	for _, id in ipairs(rewards) do
		if not data.cosmetics.owned[id] then
			return false
		end
	end
	return true
end

local function notes(player, needle)
	local count = 0
	for _, sent in ipairs(Mock.Sent.Notify or {}) do
		if sent[1] == player and string.find(sent[2], needle, 1, true) then
			count += 1
		end
	end
	return count
end

local function main()
	print(string.format("Game %s, rewards: %s", tostring(gameId), table.concat(rewards, ", ")))
	expect(gameId ~= nil and OurGames.ById[gameId] ~= nil, "server passes a known game id")
	expect(#rewards >= 1, "server lists the rewards")

	local remote = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Community")
	expect(remote ~= nil, "Community remote exists")
	local invoke = rawget(remote, "_props").OnServerInvoke

	-- Not a member: nothing
	local alice = Mock.AddPlayer(2001, "Alice")
	waitLoaded(alice)
	expect(alice:GetAttribute("CommunityMember") == false, "non-member is marked as not in the community")
	expect(not ownsAll(alice), "non-member gets no reward")
	task.wait(3.1)
	local ok, message = invoke(alice, "claim")
	expect(ok == false and type(message) == "string", "Claim without joining says to join first")
	expect(not ownsAll(alice), "still no reward without joining")

	-- Joins in game, presses Claim: reward once
	Mock.Groups[2001] = { [777] = true }
	ok = invoke(alice, "claim")
	expect(ok == false, "Claim right away is held back by the cooldown")
	task.wait(3.1)
	ok = invoke(alice, "claim")
	expect(ok == true, "Claim after joining works")
	expect(ownsAll(alice), "member gets every reward")
	local data = DataService.Get(alice)
	expect(data.community and data.community.claimed == true, "reward is saved as claimed")
	expect(alice:GetAttribute("CommunityMember") == true, "member is marked as in the community")
	local equipped = 0
	for _, id in pairs(data.cosmetics.equipped) do
		for _, reward in ipairs(rewards) do
			if id == reward then
				equipped += 1
			end
		end
	end
	expect(equipped >= 1, "a reward is put on right away")
	expect(notes(alice, "Thanks for joining") == 1, "thank-you message once")
	task.wait(3.1)
	invoke(alice, "claim")
	expect(notes(alice, "Thanks for joining") == 1, "no second reward or message")

	-- Already a member, arrives from another of our games: welcome + reward on arrival
	local other = OurGames.Others(gameId)[1]
	Mock.Groups[2002] = { [777] = true }
	local bob = Mock.AddPlayer(2002, "Bob", { TeleportData = { from = other.id } })
	waitLoaded(bob)
	expect(ownsAll(bob), "member who joined on the website gets the reward on arrival")
	expect(notes(bob, "Welcome over from " .. other.name) == 1, "welcome message for players from our games")

	-- Play buttons
	Mock.Studio = true
	ok, message = invoke(alice, "play", other.id)
	expect(ok == false and string.find(message or "", "Studio", 1, true), "no teleport in Studio, with a reason")
	Mock.Studio = false
	ok = invoke(alice, "play", gameId)
	expect(ok == false, "can't teleport to this same game")
	ok = invoke(alice, "play", "nope")
	expect(ok == false, "unknown game refused")
	ok = invoke(alice, "play", other.id)
	expect(ok == true, "Play works")
	local last = Mock.Teleports[#Mock.Teleports]
	expect(last and last.placeId == other.placeId, "teleports to the other game's place")
	expect(last and last.players[1] == alice, "teleports the right player")
	expect(last and last.data and last.data.from == gameId, "tells the other game where the player came from")
	ok = invoke(alice, "play", other.id)
	expect(ok == false and #Mock.Teleports == 1, "double press doesn't teleport twice")

	local names = {}
	for _, event in ipairs(Mock.Events) do
		names[event.name] = true
	end
	expect(names.CommunityReward and names.PlayOtherGame and names.ArrivedFromOurGame, "analytics events are logged")

	if failures == 0 then
		print("Community check passed")
		process.exit(0)
	end
	print(failures .. " check(s) failed")
	process.exit(1)
end

local ok, err = pcall(main)
if not ok then
	print("Community check crashed: " .. tostring(err))
	process.exit(1)
end
