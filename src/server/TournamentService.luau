-- Tournaments: step on a glowing pad in the plaza to queue. When the countdown
-- ends, everyone queued (up to 12) plays 4 rounds, and bots fill any empty
-- spots. Each round knocks some runners out (12 -> 9 -> 6 -> 3) and the final,
-- Crown Climb, crowns the winner. Bots never take a real player's spot: they
-- only fill what's left when a tournament starts.
--
-- Players who are out go back to the plaza with coins for every round they
-- survived, and can keep watching the rest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rounds = require(Shared.Rounds)
local Remotes = require(Shared.Remotes)

local CourseService = require(script.Parent.CourseService)
local ProgressService = require(script.Parent.ProgressService)
local CosmeticService = require(script.Parent.CosmeticService)
local TutorialService = require(script.Parent.TutorialService)
local BotService = require(script.Parent.BotService)
local RaceRound = require(script.Parent.RaceRound)
local SurvivalRound = require(script.Parent.SurvivalRound)
local GameRound = require(script.Parent.GameRound)

local TournamentService = {}

local PAD_RADIUS = 9
local CHAMPION_STAND = CFrame.new(0, Config.ChampionStandY + 3, 0) -- standing in the plaza crown (root 3 studs up)

-- Seconds (the offline checks shorten these)
local Timing = {
	wait = 25, -- once someone is on a pad
	full = 4, -- once the pad is full
	intro = 5, -- the round's name card
	countdown = 3, -- 3-2-1-GO
	between = 6, -- after a round, before the next one (time to see who got through)
}
TournamentService.Timing = Timing
local ARENA_ORIGIN = Vector3.new(-3000, 300, 0)
local ARENA_SPACING = 1000

local ROUND_TYPES = {
	race = RaceRound,
	final = RaceRound,
	survival = SurvivalRound,
	fight = SurvivalRound,
	objective = GameRound,
	team = GameRound,
}

local pads = {} -- [slot] = pad
local tournaments = {} -- [id] = tournament
local nextId = 0
local lobbySpawn = nil
local random = Random.new()

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind)
end

local function rootOf(entrant)
	if entrant.bot then
		return entrant.bot.root
	end
	local character = entrant.player and entrant.player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function keyOf(entrant)
	return entrant.bot and entrant.bot.key or ("p" .. entrant.player.UserId)
end

local function modelOf(entrant)
	if entrant.bot then
		return entrant.bot.model
	end
	return entrant.player and entrant.player.Character
end

------------------------------------------------------------------ A tournament
local Tournament = {}
Tournament.__index = Tournament

-- Real players who should hear about this tournament (still in, or watching)
function Tournament:Audience()
	local list = {}
	for _, entrant in ipairs(self.entrants) do
		local player = entrant.player
		if player and player.Parent and not entrant.left then
			if player:GetAttribute("InTournament") == self.id or player:GetAttribute("Watching") == self.id then
				table.insert(list, player)
			end
		end
	end
	return list
end

function Tournament:Announce(kind, info)
	info = info or {}
	info.tournament = self.id
	for _, player in ipairs(self:Audience()) do
		Remotes.Announce:FireClient(player, kind, info)
	end
end

-- Is a knocked-out player watching (or still in the stands of the round they
-- fell out of)? Then the bots play on for them, even with no real players left in.
function Tournament:Watched()
	for _, entrant in ipairs(self.entrants) do
		local player = entrant.player
		if player and player.Parent and not entrant.left then
			if
				player:GetAttribute("Watching") == self.id
				or (entrant.toldOut and player:GetAttribute("InTournament") == self.id)
			then
				return true
			end
		end
	end
	return false
end

function Tournament:Status(text)
	if text ~= self.lastStatus then
		self.lastStatus = text
		self:Announce("status", { text = text })
	end
end

-- Marks who's still running this round, so screens can follow them
function Tournament:SetInRound(entrant, on)
	local model = modelOf(entrant)
	if model then
		model:SetAttribute("Tournament", on and self.id or nil)
		model:SetAttribute("Runner", keyOf(entrant))
	end
end

function Tournament:Place(entrant, cframe)
	if entrant.bot then
		BotService.Place(entrant.bot, cframe)
		return
	end
	local character = entrant.player and entrant.player.Character
	if character then
		pcall(function()
			entrant.player:RequestStreamAroundAsync(cframe.Position, 2)
		end)
		character:PivotTo(cframe)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

-- Holds everyone still during the countdown
function Tournament:Freeze(entrants, on)
	for _, entrant in ipairs(entrants) do
		local character = entrant.player and entrant.player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = on and 0 or Config.WalkSpeed
			humanoid.JumpHeight = on and 0 or Config.JumpHeight
		end
	end
end

function Tournament:Qualified(entrant, place, time)
	if entrant.player and not entrant.left then
		local final = self.round and self.round.kind == "final"
		Remotes.Announce:FireClient(entrant.player, final and "crown" or "qualified", {
			tournament = self.id,
			place = place,
			time = time,
		})
		local root = rootOf(entrant)
		if root then
			local celebrate = CosmeticService.Equipped(entrant.player, "celebrate")
			Remotes.Effect:FireAllClients("qualify", root.Position, { effect = celebrate and celebrate.id or nil })
		end
	end
end

-- Out: told the moment it happens, with why (a survival fall, or the end of
-- a round). Rewards come when the round ends.
function Tournament:OutOfRound(entrant, place, reason)
	if entrant.player and not entrant.left and not entrant.toldOut then
		entrant.toldOut = true
		Remotes.Announce:FireClient(
			entrant.player,
			"out",
			{ tournament = self.id, place = place, of = #self.entrants, reason = reason }
		)
	end
end

-- by knocked victim off the arena with a hammer (by may be nil: a plain fall)
function Tournament:KnockedOut(by, victim)
	local root = rootOf(victim)
	if root then
		Remotes.Effect:FireAllClients("ko", root.Position)
	end
	if by and by.player and by.player.Parent and by ~= victim then
		by.kos = (by.kos or 0) + 1
		ProgressService.AddResult(by.player, { stats = { kos = 1 }, quiet = true })
		notify(by.player, "You knocked " .. victim.name .. " off!", "success")
	end
end

-- Coins and XP for a player whose tournament is over (out, left, or won)
function Tournament:Reward(entrant, won)
	local player = entrant.player
	if not player or entrant.rewarded or not player.Parent then
		return 0, 0
	end
	entrant.rewarded = true
	local rewards = Config.TournamentRewards
	local rounds = entrant.roundsSurvived or 0
	local coins = rewards.play + rounds * rewards.round + (won and rewards.win or 0)
	local xp = rewards.playXp + rounds * rewards.roundXp + (won and rewards.winXp or 0)
	local crowns = won and 1 or 0
	return ProgressService.AddResult(player, {
		coins = coins,
		xp = xp,
		stats = { tournaments = 1, rounds = rounds, qualified = entrant.racesQualified or 0, crowns = crowns },
		quest = { tournaments = 1, rounds = rounds, qualified = entrant.racesQualified or 0, crowns = crowns },
		crowns = crowns,
		quiet = true,
	})
end

-- Sends an out player back to the plaza (they can keep watching)
function Tournament:SendHome(entrant, place)
	local player = entrant.player
	if not player or not player.Parent then
		return
	end
	CourseService.Leave(player)
	player:SetAttribute("InTournament", nil)
	if not entrant.left then
		player:SetAttribute("Watching", self.id)
	end
	local character = player.Character
	if character and lobbySpawn then
		character:PivotTo(lobbySpawn())
	end
	self:Freeze({ entrant }, false)
	local coins, xp = self:Reward(entrant, false)
	if not entrant.left then
		-- Anyone still in (players or bots) can be watched: the bots play on
		-- while someone watches
		local others = false
		for _, other in ipairs(self.entrants) do
			if other.alive and not other.left and other ~= entrant then
				others = true
			end
		end
		Remotes.Announce:FireClient(player, "eliminated", {
			tournament = self.id,
			watchable = others,
			place = place,
			of = #self.entrants,
			rounds = entrant.roundsSurvived or 0,
			coins = coins,
			xp = xp,
		})
	end
	TutorialService.Event(player, "Tournament")
end

local function realPlayersIn(t)
	for _, entrant in ipairs(t.entrants) do
		if entrant.player and entrant.alive and not entrant.left then
			return true
		end
	end
	return false
end

local function arenaOrigin(t)
	return CFrame.new(ARENA_ORIGIN + Vector3.new(0, 0, (t.slot - 1) * ARENA_SPACING))
end

-- Plays every round, start to finish
local function run(t)
	local alive = {}
	for _, entrant in ipairs(t.entrants) do
		table.insert(alive, entrant)
	end
	local winner = nil
	for number, round in ipairs(t.plan) do
		if not realPlayersIn(t) and not t:Watched() then
			-- Only bots left and nobody watching: no need to play it out, one of them takes the crown
			winner = alive[random:NextInteger(1, #alive)]
			break
		end
		t.roundNumber = number
		t.round = round
		local keep = Rounds.Keep(#alive, number)
		local kind = ROUND_TYPES[round.kind]
		local ok, match = pcall(kind.new, t, round, alive, keep, number, arenaOrigin(t))
		if not ok then
			warn("[TournamentService] Couldn't build " .. round.id .. ": " .. tostring(match))
			break
		end
		t.match = match
		-- Everyone stands still from the moment they're placed until GO
		t:Freeze(alive, true)
		t:Announce("intro", {
			number = number,
			total = #t.plan,
			name = round.name,
			kind = round.kind,
			blurb = round.blurb,
			keep = keep,
			count = #alive,
		})
		task.wait(Timing.intro)
		local played, qualified, eliminated = pcall(match.Play, match)
		if not played then
			warn("[TournamentService] " .. round.id .. " failed: " .. tostring(qualified))
			qualified, eliminated = alive, {}
		end
		t:Status("")
		-- Places for those out this round: after everyone still in
		local nextPlace = #alive - #eliminated + 1
		for _, entrant in ipairs(eliminated) do
			entrant.alive = false
			entrant.place = nextPlace
			nextPlace += 1
			-- Anyone not told yet hears it now, while they can still see the round
			t:OutOfRound(entrant, entrant.place, match.reasons and match.reasons[entrant])
		end
		for _, entrant in ipairs(qualified) do
			entrant.roundsSurvived = (entrant.roundsSurvived or 0) + 1
			if round.kind == "race" then
				entrant.racesQualified = (entrant.racesQualified or 0) + 1
			end
		end
		task.wait(round.kind == "final" and 1 or Timing.between)
		pcall(match.Cleanup, match)
		for _, entrant in ipairs(eliminated) do
			if entrant.player then
				t:SendHome(entrant, entrant.place)
			elseif entrant.bot then
				BotService.Place(entrant.bot, CFrame.new(0, -500, 0))
			end
		end
		alive = qualified
		if round.kind == "final" then
			winner = qualified[1]
			break
		end
	end
	return winner, alive
end

local function finish(t, winner, alive)
	t.over = true
	if winner then
		winner.place = 1
		t:Announce(
			"winner",
			{ name = winner.name, bot = winner.bot ~= nil, userId = winner.player and winner.player.UserId }
		)
	end
	-- Everyone still in (the winner, and anyone left if it ended early)
	for _, entrant in ipairs(alive or {}) do
		if entrant.player and not entrant.left then
			local won = entrant == winner
			local coins, xp = t:Reward(entrant, won)
			local player = entrant.player
			player:SetAttribute("InTournament", nil)
			CourseService.Leave(player)
			t:Freeze({ entrant }, false)
			if won then
				Remotes.Announce:FireClient(player, "champion", { tournament = t.id, coins = coins, xp = xp })
				for _, other in ipairs(Players:GetPlayers()) do
					if other ~= player then
						notify(other, player.DisplayName .. " just won a tournament crown!", "rare")
					end
				end
			end
			TutorialService.Event(player, "Tournament")
			-- Back to the plaza, the champion dancing in the crown statue
			local character = player.Character
			if character and lobbySpawn then
				character:PivotTo(won and CHAMPION_STAND or lobbySpawn())
			end
			if won then
				local dance = CosmeticService.Equipped(player, "dance")
				task.delay(0.5, function()
					if character.Parent then
						pcall(CosmeticService.Dance, character, dance and dance.id, CHAMPION_STAND, 5)
					end
				end)
			end
		end
	end
	for _, entrant in ipairs(t.entrants) do
		if entrant.player then
			if entrant.player:GetAttribute("Watching") == t.id then
				entrant.player:SetAttribute("Watching", nil)
				entrant.player.ReplicationFocus = nil
			end
			if entrant.player:GetAttribute("InTournament") == t.id then
				entrant.player:SetAttribute("InTournament", nil)
			end
		elseif entrant.bot then
			BotService.Remove(entrant.bot)
		end
	end
	tournaments[t.id] = nil
	t.pad.tournament = nil
end

-- Studio tests can set the next tournament's rounds (a list of round ids)
TournamentService.NextPlan = nil

local function start(pad, players)
	nextId += 1
	local plan = Rounds.Pick(random)
	if TournamentService.NextPlan then
		plan = {}
		for _, id in ipairs(TournamentService.NextPlan) do
			table.insert(plan, Rounds.ById[id])
		end
		TournamentService.NextPlan = nil
	end
	local t = setmetatable({
		id = nextId,
		slot = pad.slot,
		pad = pad,
		entrants = {},
		plan = plan,
		roundNumber = 0,
		timing = Timing,
	}, Tournament)
	tournaments[t.id] = t
	pad.tournament = t
	for _, player in ipairs(players) do
		CourseService.Leave(player)
		player:SetAttribute("QueuePad", nil)
		player:SetAttribute("Watching", nil)
		player:SetAttribute("InTournament", t.id)
		table.insert(t.entrants, { player = player, name = player.DisplayName, alive = true })
	end
	-- Bots fill the rest: a few sharp ones, some average and some clumsy, so
	-- there's always someone to beat and someone to chase
	local holding = arenaOrigin(t) * CFrame.new(0, -200, 0)
	local skills = BotService.SkillMix(Rounds.Players - #t.entrants, random)
	for _, skill in ipairs(skills) do
		local bot = BotService.Create(holding, skill)
		table.insert(t.entrants, { bot = bot, name = bot.name, alive = true })
	end
	t:Announce("start", {
		rounds = (function()
			local names = {}
			for _, round in ipairs(t.plan) do
				table.insert(names, round.name)
			end
			return names
		end)(),
		players = #players,
		bots = Rounds.Players - #players,
	})
	task.spawn(function()
		task.wait(1)
		local ok, winner, alive = pcall(run, t)
		if not ok then
			warn("[TournamentService] " .. tostring(winner))
			winner, alive = nil, {}
		end
		local done, err = pcall(finish, t, winner, alive)
		if not done then
			warn("[TournamentService] finish: " .. tostring(err))
			tournaments[t.id] = nil
			pad.tournament = nil
		end
	end)
end

------------------------------------------------------------------ Leaving
local function leave(player, quiet)
	for _, t in pairs(tournaments) do
		for _, entrant in ipairs(t.entrants) do
			if entrant.player == player and entrant.alive and not entrant.left then
				entrant.left = true
				entrant.alive = false
				entrant.place = entrant.place or #t.entrants
				if not quiet then
					t:SendHome(entrant, entrant.place)
					notify(player, "You left the tournament.", "info")
				end
				return true
			end
		end
	end
	if player:GetAttribute("Watching") then
		player:SetAttribute("Watching", nil)
		player.ReplicationFocus = nil
		return true
	end
	return false, "You're not in a tournament"
end

------------------------------------------------------------------ Watching
-- Out players can follow the runners still in. The server moves what the
-- player's game loads (ReplicationFocus) to the runner, then the screen
-- points the camera at them. Answers with the runner's key.
local watchIndex = {} -- [player] = index into the runners still in
local function spectate(player, direction)
	local t = tournaments[player:GetAttribute("Watching") or 0]
	if not t then
		return false, "Nothing to watch"
	end
	local running = {}
	for _, entrant in ipairs(t.entrants) do
		local model = modelOf(entrant)
		if entrant.alive and model and model.Parent and model:GetAttribute("Tournament") == t.id then
			table.insert(running, entrant)
		end
	end
	if #running == 0 then
		return false, "Nobody to watch right now"
	end
	local index = (watchIndex[player] or 0) + (direction == "prev" and -1 or 1)
	index = (index - 1) % #running + 1
	watchIndex[player] = index
	local entrant = running[index]
	player.ReplicationFocus = rootOf(entrant)
	return true, keyOf(entrant)
end

------------------------------------------------------------------ Pads
local function padStatus(pad, now)
	local count = #pad.queue
	if pad.tournament then
		local t = pad.tournament
		return string.format("Tournament on: round %d of %d", math.max(1, t.roundNumber), #t.plan),
			count > 0 and string.format("%d waiting for the next one", count) or "Step on to play the next one"
	end
	if count == 0 then
		return "Step on to play a tournament!", "4 rounds, 12 runners, 1 crown"
	end
	local left = math.max(0, math.ceil((pad.countdownEnd or now) - now))
	return string.format("Starting in %ds", left),
		string.format("%d/%d players (bots fill the rest)", count, Rounds.Players)
end

local function updatePad(pad, now)
	-- Who's standing on it?
	local center = pad.part.Position
	local on = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - center
			local free = not player:GetAttribute("InTournament") and not CourseService.Get(player)
			if
				free
				and Vector3.new(offset.X, 0, offset.Z).Magnitude < PAD_RADIUS
				and offset.Y > -2
				and offset.Y < 9
			then
				on[player] = true
			end
		end
	end
	for index = #pad.queue, 1, -1 do
		local player = pad.queue[index]
		if not on[player] or not player.Parent then
			table.remove(pad.queue, index)
			if player.Parent and player:GetAttribute("QueuePad") == pad.slot then
				player:SetAttribute("QueuePad", nil)
			end
		end
	end
	for player in pairs(on) do
		if not table.find(pad.queue, player) and not player:GetAttribute("QueuePad") then
			table.insert(pad.queue, player)
			player:SetAttribute("QueuePad", pad.slot)
			TutorialService.Event(player, "Queue")
		end
	end

	-- The countdown
	if pad.tournament or #pad.queue == 0 then
		pad.countdownEnd = nil
	else
		pad.countdownEnd = pad.countdownEnd or (now + Timing.wait)
		if #pad.queue >= Rounds.Players then
			pad.countdownEnd = math.min(pad.countdownEnd, now + Timing.full)
		end
		if now >= pad.countdownEnd then
			local players = {}
			for index = 1, math.min(#pad.queue, Rounds.Players) do
				table.insert(players, pad.queue[index])
			end
			pad.queue = {}
			pad.countdownEnd = nil
			start(pad, players)
		end
	end

	local title, detail = padStatus(pad, now)
	ReplicatedStorage:SetAttribute("PadStatus" .. pad.slot, title .. "  -  " .. detail)
	if pad.label then
		pad.label.Text = title .. "\n" .. detail
	end
end

local function findPads()
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("TournamentPad") then
			local slot = item:GetAttribute("TournamentPad")
			pads[slot] = pads[slot] or { slot = slot, queue = {} }
			pads[slot].part = item
		end
	end
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("PadSign") and pads[item:GetAttribute("PadSign")] then
			local label = item:FindFirstChild("Status", true)
			pads[item:GetAttribute("PadSign")].label = label and label:IsA("TextLabel") and label or nil
		end
	end
end

------------------------------------------------------------------ Start
function TournamentService.Get(player)
	for _, t in pairs(tournaments) do
		for _, entrant in ipairs(t.entrants) do
			if entrant.player == player and entrant.alive and not entrant.left then
				return t, entrant
			end
		end
	end
	return nil
end

function TournamentService.Start(lobbySpawnFn)
	lobbySpawn = lobbySpawnFn
	BotService.Init()
	findPads()
	ProgressService.AddAction("LeaveTournament", function(player)
		return leave(player, false)
	end)
	ProgressService.AddAction("Spectate", spectate)
	-- Private servers: the owner can start the tournament on their pad right away
	ProgressService.AddAction("StartNow", function(player)
		if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= player.UserId then
			return false, "Only the owner of a private server can do that"
		end
		local pad = pads[player:GetAttribute("QueuePad") or 0]
		if not pad or not table.find(pad.queue, player) then
			return false, "Stand on a tournament pad first"
		end
		pad.countdownEnd = os.clock()
		return true
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player, true)
		watchIndex[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, pad in pairs(pads) do
				local ok, err = pcall(updatePad, pad, now)
				if not ok then
					warn("[TournamentService] pad: " .. tostring(err))
				end
			end
		end
	end)
end

return TournamentService
