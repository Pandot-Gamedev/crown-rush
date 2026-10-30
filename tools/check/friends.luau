-- Checks the friend bonus: two Roblox friends in one server both get it,
-- a stranger doesn't, and it stops when the friend leaves.
--
-- Usage (needs Lune):  lune run tools/check/friends.luau

local process = require("@lune/process")
local task = require("@lune/task")
local Mock = require("./mock")

Mock.Mount(process.cwd)
local game = Mock.game
local server = game:GetService("ServerScriptService").Server
Mock.require(server)

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = Mock.require(Shared.Config)
local DataService = Mock.require(server.DataService)
local ProgressService = Mock.require(server.ProgressService)
local Players = game:GetService("Players")

local function main()
	local failures = 0
	local function expect(condition, text)
		if not condition then
			failures += 1
			print("  FAIL: " .. text)
		end
	end
	local function loaded(player)
		for _ = 1, 50 do
			if DataService.IsLoaded(player) then
				return
			end
			task.wait(0.05)
		end
	end

	Mock.Friends["2001:2002"] = true
	local alex = Mock.AddPlayer(2001, "Alex")
	loaded(alex)
	local base = 100
	local coins = ProgressService.AddResult(alex, { coins = base, quiet = true })
	expect(coins == base, "no bonus alone (got " .. tostring(coins) .. ")")

	local sam = Mock.AddPlayer(2002, "Sam")
	local stranger = Mock.AddPlayer(2003, "Stranger")
	loaded(sam)
	loaded(stranger)
	local bonus = math.floor(base * (1 + Config.FriendCoinBonus))
	expect(alex:GetAttribute("FriendsHere") == 1, "Alex sees 1 friend")
	expect(sam:GetAttribute("FriendsHere") == 1, "Sam sees 1 friend")
	expect((stranger:GetAttribute("FriendsHere") or 0) == 0, "the stranger has no friends here")
	coins = ProgressService.AddResult(alex, { coins = base, quiet = true })
	expect(coins == bonus, "Alex gets the friend bonus (got " .. tostring(coins) .. ")")
	coins = ProgressService.AddResult(sam, { coins = base, quiet = true })
	expect(coins == bonus, "Sam gets the friend bonus (got " .. tostring(coins) .. ")")
	coins = ProgressService.AddResult(stranger, { coins = base, quiet = true })
	expect(coins == base, "the stranger gets no bonus (got " .. tostring(coins) .. ")")

	local toasts = 0
	for _, sent in ipairs(Mock.Sent.Notify or {}) do
		if string.find(tostring(sent[2]), "is here!", 1, true) then
			toasts += 1
		end
	end
	expect(toasts == 2, "one 'friend is here' toast each (got " .. toasts .. ")")

	Players.PlayerRemoving:Fire(sam)
	sam.Parent = nil
	coins = ProgressService.AddResult(alex, { coins = base, quiet = true })
	expect(coins == base, "bonus ends when the friend leaves (got " .. tostring(coins) .. ")")
	expect(alex:GetAttribute("FriendsHere") == 0, "Alex sees 0 friends after Sam leaves")

	if failures == 0 then
		print("Friend bonus: all checks passed")
	end
	process.exit(failures == 0 and 0 or 1)
end

task.spawn(main)
