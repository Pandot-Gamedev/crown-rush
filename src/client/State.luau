-- The player's latest save data, as sent by the server.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = {
	data = nil,
	runtime = { passes = {} },
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

Remotes.DataUpdate.OnClientEvent:Connect(function(data, runtime)
	State.data = data
	State.runtime = runtime or State.runtime
	changed:Fire(data, State.runtime)
end)

function State.HasPass(passId)
	return State.runtime.passes ~= nil and State.runtime.passes[passId] == true
end

-- Calls a server action and shows its error message if it fails
function State.Action(actionName, argument)
	local ok, success, message = pcall(function()
		return Remotes.Action:InvokeServer(actionName, argument)
	end)
	if not ok then
		return false, "Connection problem, try again"
	end
	return success, message
end

return State
