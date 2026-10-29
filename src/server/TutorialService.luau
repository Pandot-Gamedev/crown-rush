-- Moves players through the first-time guide (see Shared/Tutorial).
-- Other services call TutorialService.Event(player, "Gate") etc. Doing a later
-- step first (like jumping straight into a match) skips the earlier ones.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Tutorial)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local TutorialService = {}

function TutorialService.Event(player, event)
	local data = DataService.Get(player)
	if not data or data.tutorial >= Tutorial.Done then
		return
	end
	local index = nil
	for stepIndex, step in ipairs(Tutorial.Steps) do
		if step.event == event then
			index = stepIndex
		end
	end
	if not index or index < data.tutorial then
		return
	end
	local finished = index + 1 >= Tutorial.Done
	DataService.Update(player, function(saved)
		saved.tutorial = index + 1
		if finished then
			saved.coins += Tutorial.RewardCoins
			saved.totalEarned += Tutorial.RewardCoins
		end
	end)
	if finished then
		Remotes.Notify:FireClient(
			player,
			string.format(
				"You're a natural! Here's %s coins. Spend them in the Locker.",
				Format.Number(Tutorial.RewardCoins)
			),
			"success"
		)
	end
end

function TutorialService.Start() end

return TutorialService
