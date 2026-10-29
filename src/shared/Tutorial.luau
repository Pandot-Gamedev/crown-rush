-- The first-time guide. Each step points at a place in the world (a part with the
-- matching "GuideTarget" attribute) and finishes on a game event.

local Tutorial = {}

Tutorial.Steps = {
	{ event = "Gate", text = "Welcome to Crown Rush! Walk into the pink Candy Clouds gate.", target = "FirstGate" },
	{ event = "Course", text = "Pick Sugar Steps to play your first course.", target = nil },
	{ event = "Finish", text = "Run to the finish! If you fall, you pop back at the last checkpoint.", target = nil },
	{ event = "Queue", text = "Ready to race other players? Step on a glowing tournament pad.", target = "Pads" },
	{ event = "Tournament", text = "Survive every round and grab the crown in the final!", target = nil },
}

Tutorial.Done = #Tutorial.Steps + 1
Tutorial.RewardCoins = 200

return Tutorial
