-- All the messages between server and players. The server creates them;
-- players wait for them to appear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"DataUpdate", -- server -> player: the player's full save data
	"Notify", -- server -> player: a toast message
	"OpenPanel", -- server -> player: open a menu (e.g. a world's course list)
	"Announce", -- server -> player: big text in the middle of the screen
	"Effect", -- server -> players: confetti, a fall, a gem, a hit...
	"Launch", -- server -> player: you got knocked, fly with this velocity
	"Run", -- server -> player: your course run changed (timer, checkpoint, finish)
	"Fell", -- player -> server: I touched lava / a laser, or fell below the course
	"Dive", -- player -> server: I just dived (for effects)
	"Bonk", -- player -> server: swing the hammer (fight rounds)
	"Tournaments", -- server -> everyone: the state of every tournament
}

local FUNCTIONS = {
	"Action", -- player -> server: play a course, buy or equip a cosmetic...
	"Ask", -- player -> server: questions with answers (a ghost run, leaderboards)
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in ipairs(EVENTS) do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in ipairs(FUNCTIONS) do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
