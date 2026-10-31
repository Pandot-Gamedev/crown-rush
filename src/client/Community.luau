-- The "Free Gift" menu: Play buttons for our other games, each of which gives
-- a free, looks-only welcome gift to players who arrive from another of our
-- games (and, once we have one, a Join button for our community). This file is the same in all four games;
-- what differs is passed to Community.Init. Also two friendly reminders per
-- visit (a short message, never a pop-up window).

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OurGames = require(Shared.OurGames)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local T = UI.Theme

local player = Players.LocalPlayer
local Community = {}

local GIFT_REMINDER = 90 -- seconds into a visit
local GAMES_REMINDER = 12 * 60

local remote = nil
local options = nil -- { gameId, rewardText, key }
local busy = false

local function call(request, argument)
	if not remote then
		return false, "Connection problem, try again"
	end
	local ok, success, message = pcall(function()
		return remote:InvokeServer(request, argument)
	end)
	if not ok then
		return false, "Connection problem, try again"
	end
	return success, message
end

local function claimed()
	local data = State.data
	return data ~= nil and data.community ~= nil and data.community.claimed == true
end

local function isMember()
	return player:GetAttribute("CommunityMember") == true
end

local function card(parent, height, order)
	return UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = T.Card,
		LayoutOrder = order,
		Parent = parent,
	}, { UI.corner(10) })
end

local function heading(parent, text, order)
	UI.label(text, {
		Size = UDim2.new(1, -8, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.Gold,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function icon(parent, image)
	UI.new("ImageLabel", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = T.Background,
		Image = image,
		ScaleType = Enum.ScaleType.Crop,
		Parent = parent,
	}, { UI.corner(10) })
end

local function texts(parent, title, body, width)
	UI.label(title, {
		Position = UDim2.fromOffset(86, 8),
		Size = UDim2.new(width, -86, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	UI.label(body, {
		Position = UDim2.fromOffset(86, 38),
		Size = UDim2.new(width, -86, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		Parent = parent,
	})
end

local function sideButton(parent, text, color, onClick)
	return UI.button(text, color, onClick, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(130, 42),
		Parent = parent,
	})
end

local function claim()
	local ok, message = call("claim")
	if not ok and message then
		Notifications.Show(message, "warning")
	end
	if Community.window then
		Community.window.refresh()
	end
end

local function join()
	if busy then
		return
	end
	busy = true
	local ok, status = pcall(function()
		return GroupService:PromptJoinAsync(OurGames.CommunityId)
	end)
	if not ok then
		Notifications.Show("Couldn't open the join window. Search for " .. OurGames.CommunityName .. " on Roblox.", "warning")
	else
		-- Closed without joining: nothing to claim (the server checks again anyway)
		local known, closed = pcall(function()
			return status == Enum.GroupMembershipStatus.None
		end)
		if not (known and closed) then
			claim()
		end
	end
	busy = false
end

local function render(body)
	UI.list(8).Parent = body

	-- This game's welcome gift
	heading(body, "Free welcome gift in every game", 1)
	local gift = card(body, 84, 2)
	local here = OurGames.ById[options.gameId]
	if here then
		icon(gift, OurGames.Icon(here))
	end
	texts(
		gift,
		"Your gift here",
		"Come here from one of our other games and get " .. options.rewardText .. ". Looks only, yours to keep.",
		0.74
	)
	sideButton(gift, claimed() and "Claimed" or "Not yet", T.Card)

	-- Our community (only once there is one)
	if OurGames.CommunityId ~= 0 then
		local community = card(body, 84, 3)
		icon(community, OurGames.CommunityIcon())
		texts(community, OurGames.CommunityName, "Join our community for free and get the same gift.", 0.74)
		if claimed() then
			sideButton(community, "Claimed", T.Card)
		elseif isMember() then
			sideButton(community, "Claim", T.Good, function()
				task.spawn(claim)
			end)
		else
			sideButton(community, "Join", T.Good, function()
				task.spawn(join)
			end)
		end
	end

	-- Our other games
	heading(body, "Play our other games (a free gift in each)", 4)
	for index, entry in ipairs(OurGames.Others(options.gameId)) do
		local row = card(body, 84, 4 + index)
		icon(row, OurGames.Icon(entry))
		texts(row, entry.name, entry.blurb, 0.74)
		local button
		button = sideButton(row, "Play", T.Accent, function()
			button.Text = "Going..."
			local ok, message = call("play", entry.id)
			if not ok then
				button.Text = "Play"
				if message then
					Notifications.Show(message, "warning")
				end
			end
		end)
	end
end

local function shortcut()
	return UserInputService.KeyboardEnabled and (" (" .. options.key.Name .. ")") or ""
end

-- options: { gameId = "crown", rewardText = "the Pandot Crew title and ...", key = Enum.KeyCode.G }
-- Opened with Community.window.toggle() (the Hud's Free Gift button).
function Community.Init(screenGui, initOptions)
	options = initOptions
	Community.window = UI.window(screenGui, "Free Gift", render)

	task.spawn(function()
		remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Community")
	end)

	-- Show the right button after the server checks membership or the reward lands
	player:GetAttributeChangedSignal("CommunityMember"):Connect(function()
		Community.window.refresh()
	end)
	State.Changed:Connect(function()
		Community.window.refresh()
	end)

	-- Two friendly reminders per visit
	task.delay(GIFT_REMINDER, function()
		Notifications.Show("Free gifts! Play our other games from Free Gift" .. shortcut() .. ": each one gives you a gift.", "rare")
	end)
	task.delay(GAMES_REMINDER, function()
		local others = OurGames.Others(options.gameId)
		local pick = others[math.random(1, #others)]
		Notifications.Show("Try " .. pick.name .. " too! Open Free Gift" .. shortcut() .. " to play.", "info")
	end)
end

return Community
