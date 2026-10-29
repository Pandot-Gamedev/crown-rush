-- The menus: Courses (a world's Adventure courses), Shop (Robux), Locker (your
-- cosmetics and the coin shop) and Quests.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Cosmetics)
local Shop = require(Shared.Shop)
local Courses = require(Shared.Courses)
local Worlds = require(Shared.Worlds)
local Remotes = require(Shared.Remotes)
local Quests = require(Shared.Quests)
local Level = require(Shared.Level)
local Format = require(Shared.Format)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local T = UI.Theme

local player = Players.LocalPlayer
local Panels = {}

local function act(actionName, argument)
	local ok, message = State.Action(actionName, argument)
	if not ok and message then
		Notifications.Show(message, "warning")
	end
	return ok
end

-- Robux prices come from Roblox, so they always match the Creator Dashboard
local priceCache = {}
local function robuxPrice(id, infoType, onReady)
	local key = tostring(infoType) .. id
	if priceCache[key] then
		onReady(priceCache[key])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, infoType)
		end)
		if not ok then
			ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
		end
		if ok and info and info.PriceInRobux then
			priceCache[key] = info.PriceInRobux
			onReady(info.PriceInRobux)
		end
	end)
end

local function row(parent, height, order)
	return UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = T.Card,
		LayoutOrder = order or 0,
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

local function note(parent, text, order)
	UI.label(text, {
		Size = UDim2.new(1, -8, 0, 20),
		Font = T.BodyFont,
		TextColor3 = T.Muted,
		TextWrapped = true,
		LayoutOrder = order,
		Parent = parent,
	})
end

-- A small colour swatch so you can tell items apart at a glance
-- An item's name on its card, all at the same size whether it's short or long
local function itemName(card, text, width)
	local label = UI.label(text, {
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(width, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 20, Parent = label })
	return label
end

local function swatch(card, item)
	local color = item.head or item.color or (item.colors and item.colors[1]) or T.Muted
	UI.new("Frame", {
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = color,
		Parent = card,
	}, { UI.corner(14), UI.stroke(T.Background, 2) })
end

local function cardButton(card, text, color, onClick)
	return UI.button(text, color, onClick, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 36),
		Parent = card,
	})
end

------------------------------------------------------------------ Shop (Robux)
local function renderShop(body)
	local data = State.data
	if not data then
		return
	end
	UI.list(8).Parent = body
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	note(body, "Everything here is looks only. Nothing you buy helps you win.", nextOrder())

	heading(body, "Game pass (yours forever)", nextOrder())
	for _, pass in ipairs(Shop.Passes) do
		local card = row(body, 64, nextOrder())
		UI.label(pass.name, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.6, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		UI.label(pass.description, {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(0.68, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = T.BodyFont,
			TextColor3 = T.Muted,
			Parent = card,
		})
		local button = cardButton(card, "...", T.Good)
		if State.HasPass(pass.id) then
			button.Text = "Owned"
			button.BackgroundColor3 = T.Card
		elseif pass.gamePassId == 0 then
			button.Text = "Coming soon"
			button.BackgroundColor3 = T.Card
		else
			robuxPrice(pass.gamePassId, Enum.InfoType.GamePass, function(price)
				button.Text = "R$ " .. price
			end)
			button.Activated:Connect(function()
				MarketplaceService:PromptGamePassPurchase(player, pass.gamePassId)
			end)
		end
	end

	for _, kind in ipairs(Cosmetics.Kinds) do
		local items = {}
		for _, item in ipairs(Cosmetics.List) do
			if item.kind == kind.id and item.source == "robux" then
				table.insert(items, item)
			end
		end
		if #items > 0 then
			heading(body, kind.name, nextOrder())
			for _, item in ipairs(items) do
				local card = row(body, 52, nextOrder())
				swatch(card, item)
				itemName(card, item.name, 0.6)
				local owned = data.cosmetics.owned[item.id]
				local equipped = data.cosmetics.equipped[item.kind] == item.id
				local button = cardButton(card, "...", T.Good)
				if owned then
					button.Text = equipped and "Equipped" or "Equip"
					button.BackgroundColor3 = equipped and T.Card or T.Accent
					button.Activated:Connect(function()
						act("EquipCosmetic", item.id)
					end)
				elseif item.productId == 0 then
					button.Text = "Coming soon"
					button.BackgroundColor3 = T.Card
				else
					robuxPrice(item.productId, Enum.InfoType.Product, function(price)
						button.Text = "R$ " .. price
					end)
					button.Activated:Connect(function()
						MarketplaceService:PromptProductPurchase(player, item.productId)
					end)
				end
			end
		end
	end
end

------------------------------------------------------------------ Locker
local lockerTab = "trail"

local function howToGet(item, data)
	if item.source == "level" then
		return string.format("Reach level %d", item.level)
	elseif item.source == "earned" then
		local have = data.stats[item.rule] or 0
		local what = ({ stars = "stars", crowns = "crowns", gems = "gems", kos = "knockouts" })[item.rule] or item.rule
		return string.format("%d/%d %s", math.min(have, item.amount), item.amount, what)
	elseif item.source == "vip" then
		return "VIP pass"
	elseif item.source == "robux" then
		return "In the Shop"
	end
	return ""
end

local function renderLocker(body)
	local data = State.data
	if not data then
		return
	end
	UI.list(8).Parent = body
	local vip = State.HasPass("VIP")

	-- Tabs, one per kind of cosmetic
	local tabs = UI.new(
		"Frame",
		{ Size = UDim2.new(1, -8, 0, 36), BackgroundTransparency = 1, LayoutOrder = 0, Parent = body },
		{ UI.list(6, Enum.FillDirection.Horizontal) }
	)
	for _, kind in ipairs(Cosmetics.Kinds) do
		UI.button(kind.short, kind.id == lockerTab and T.Accent or T.Card, function()
			lockerTab = kind.id
			Panels.Locker.refresh()
		end, { Size = UDim2.fromOffset(104, 34), Parent = tabs })
	end
	note(
		body,
		string.format(
			"You have %s coins. Finish courses, find gems, play tournaments and do quests to earn more.",
			Format.Number(data.coins)
		),
		1
	)

	local order = 1
	for _, item in ipairs(Cosmetics.List) do
		if item.kind == lockerTab then
			order += 1
			local owns = Cosmetics.Owns(data, item, vip)
			local equipped = Cosmetics.Equipped(data, item.kind, vip)
			local isEquipped = equipped and equipped.id == item.id
			local card = row(body, 52, order)
			swatch(card, item)
			itemName(card, item.name, 0.55)
			if owns then
				local canTakeOff = isEquipped and not Cosmetics.Defaults[item.kind]
				cardButton(
					card,
					isEquipped and (canTakeOff and "Take off" or "Equipped") or "Equip",
					isEquipped and T.Card or T.Accent,
					function()
						if not isEquipped or canTakeOff then
							act("EquipCosmetic", item.id)
						end
					end
				)
			elseif item.source == "coins" then
				cardButton(
					card,
					Format.Number(item.price) .. " coins",
					data.coins >= item.price and T.Good or T.Card,
					function()
						act("BuyCosmetic", item.id)
					end
				)
			else
				cardButton(card, howToGet(item, data), T.Card, function()
					if item.source == "robux" or item.source == "vip" then
						Panels.Shop.open()
					end
				end)
			end
		end
	end
end

------------------------------------------------------------------ Quests
local function renderQuests(body)
	local data = State.data
	if not data then
		return
	end
	UI.list(8).Parent = body
	local resetIn = 86400 - (os.time() % 86400)
	note(body, string.format("Three new quests every day. New quests in %s.", Format.Duration(resetIn)), 0)
	for index, entry in ipairs(data.quests.list) do
		local quest = Quests.ById[entry.id]
		if quest then
			local card = row(body, 64, index)
			UI.label(Quests.Text(entry), {
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(0.62, 0, 0, 26),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = entry.done and T.Good or T.Text,
				Parent = card,
			})
			local back = UI.new("Frame", {
				Position = UDim2.fromOffset(12, 40),
				Size = UDim2.new(0.62, 0, 0, 12),
				BackgroundColor3 = T.Background,
				Parent = card,
			}, { UI.corner(6) })
			UI.new("Frame", {
				Size = UDim2.fromScale(math.clamp(entry.progress / entry.goal, 0, 1), 1),
				BackgroundColor3 = entry.done and T.Good or T.Accent,
				Parent = back,
			}, { UI.corner(6) })
			UI.label(
				entry.done and "Done!" or string.format("%d/%d  -  %d coins", entry.progress, entry.goal, quest.coins),
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(170, 26),
					TextColor3 = entry.done and T.Good or T.Gold,
					Parent = card,
				}
			)
		end
	end
	heading(body, "Your record", 10)
	local stats = data.stats
	local _, level = Level.Progress(data.xp)
	note(
		body,
		string.format(
			"Level %d  -  %d stars  -  %d gems  -  %d courses finished",
			level,
			stats.stars,
			stats.gems,
			stats.courses
		),
		11
	)
	note(
		body,
		string.format(
			"%d tournaments  -  %d crowns  -  %d rounds survived  -  %d knockouts",
			stats.tournaments,
			stats.crowns,
			stats.rounds,
			stats.kos
		),
		12
	)
	note(body, string.format("Daily login streak: %d day%s", data.dailyStreak, data.dailyStreak == 1 and "" or "s"), 13)
end

------------------------------------------------------------------ Courses
local STAR = utf8.char(9733)
local GEM = utf8.char(9670)
local worldTab = "candy"

local function countBits(bits)
	local count = 0
	for index = 0, 2 do
		count += bit32.band(bit32.rshift(bits or 0, index), 1)
	end
	return count
end

local function clock(seconds)
	local whole = math.floor(seconds)
	return string.format("%d:%02d.%02d", math.floor(whole / 60), whole % 60, math.floor((seconds - whole) * 100))
end

-- Answers from the server, fetched in the background and cached for a minute
local answers = {}
local function ask(name, argument, onReady)
	local key = name .. ":" .. tostring(argument)
	local cached = answers[key]
	if cached and os.clock() - cached.at < 60 then
		return cached.value
	end
	if not cached or not cached.loading then
		answers[key] = { at = cached and cached.at or 0, value = cached and cached.value, loading = true }
		task.spawn(function()
			local ok, value = pcall(function()
				return Remotes.Ask:InvokeServer(name, argument)
			end)
			answers[key] = { at = os.clock(), value = ok and value or nil }
			onReady()
		end)
	end
	return cached and cached.value or nil
end

local timesFor = nil -- a course id: the window shows its best times

local function renderTimes(body, course)
	UI.list(8).Parent = body
	UI.button("< Back", T.Card, function()
		timesFor = nil
		Panels.Courses.refresh()
	end, { Size = UDim2.fromOffset(110, 34), LayoutOrder = 0, Parent = body })
	heading(body, "Best times: " .. course.name, 1)
	local answer = ask("Times", course.id, function()
		Panels.Courses.refresh()
	end)
	if not answer then
		note(body, "Loading...", 2)
		return
	end
	if #answer.top == 0 then
		note(body, "No times yet. Set the first one!", 2)
	end
	for rank, entry in ipairs(answer.top) do
		local card = row(body, 36, rank + 2)
		UI.label(string.format("%d. %s", rank, entry.name), {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rank == 1 and T.Gold or T.Text,
			Parent = card,
		})
		UI.label(clock(entry.time), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0.3, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})
	end
	note(body, answer.mine and ("Your best: " .. clock(answer.mine)) or "You haven't finished this course yet.", 20)
	note(body, "On the course, the Ghost button races your best run or the record.", 21)
end

local function dailyCard(body, order)
	local answer = ask("Daily", nil, function()
		Panels.Courses.refresh()
	end)
	local card = row(body, 64, order)
	card.BackgroundColor3 = Color3.fromRGB(70, 50, 110)
	if not answer then
		UI.label("Daily Challenge: loading...", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		return
	end
	local world = Worlds.ById[answer.world]
	UI.label("Daily Challenge: " .. answer.name, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.62, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.Gold,
		Parent = card,
	})
	local leader = answer.top[1]
	local detail = answer.best and ("Your best today " .. clock(answer.best))
		or string.format("First finish today: %d coins", answer.coins)
	if leader then
		detail ..= string.format("   Top: %s %s", leader.name, clock(leader.time))
	end
	UI.label(detail, {
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(0.62, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = T.BodyFont,
		TextColor3 = world and world.accent or T.Muted,
		Parent = card,
	})
	cardButton(card, "Play daily", Color3.fromRGB(170, 100, 255), function()
		if act("PlayDaily") then
			Panels.Courses.close()
		end
	end)
end

local function renderCourses(body)
	local data = State.data
	if not data then
		return
	end
	local timesCourse = timesFor and Courses.ById[timesFor]
	if timesCourse then
		renderTimes(body, timesCourse)
		return
	end
	UI.list(8).Parent = body
	local total = Courses.TotalStars(data.adventure)
	dailyCard(body, -1)

	local tabs = UI.new(
		"Frame",
		{ Size = UDim2.new(1, -8, 0, 36), BackgroundTransparency = 1, LayoutOrder = 0, Parent = body },
		{ UI.list(6, Enum.FillDirection.Horizontal) }
	)
	for _, world in ipairs(Worlds.List) do
		local open = Courses.WorldUnlocked(data.adventure, world.id)
		UI.button(world.name, world.id == worldTab and world.edge or T.Card, function()
			worldTab = world.id
			Panels.Courses.refresh()
		end, { Size = UDim2.fromOffset(108, 34), TextTransparency = open and 0 or 0.45, Parent = tabs })
	end

	local world = Worlds.ById[worldTab]
	local list = Courses.ByWorld[worldTab] or {}
	local worldStars = 0
	for _, course in ipairs(list) do
		local record = data.adventure[course.id]
		worldStars += record and Courses.CountStars(record.stars) or 0
	end
	if not Courses.WorldUnlocked(data.adventure, world.id) then
		note(
			body,
			string.format(
				"%s opens at %d stars. You have %d. Earn stars by finishing courses, beating par times and finding gems.",
				world.name,
				world.stars,
				total
			),
			1
		)
	else
		note(
			body,
			string.format(
				"%s  -  %s %d/%d in this world  -  %d stars in all",
				world.blurb,
				STAR,
				worldStars,
				#list * 3,
				total
			),
			1
		)
	end
	if #list == 0 then
		note(body, "Courses for this world are coming soon!", 2)
		return
	end

	for index, course in ipairs(list) do
		local record = data.adventure[course.id]
		local open = Courses.Unlocked(data.adventure, course.id)
		local card = row(body, 64, index + 1)
		UI.label(string.format("%d. %s%s", course.number, course.name, course.boss and "  (boss)" or ""), {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.5, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = open and (course.boss and world.accent or T.Text) or T.Muted,
			Parent = card,
		})
		local stars = record and Courses.CountStars(record.stars) or 0
		local gems = record and countBits(record.gems) or 0
		local detail =
			string.format("%s%s   %s %d/3", string.rep(STAR, stars), string.rep(utf8.char(9734), 3 - stars), GEM, gems)
		if record and record.best then
			detail ..= "   Best " .. clock(record.best)
		end
		UI.label(detail, {
			Position = UDim2.fromOffset(12, 36),
			Size = UDim2.new(0.5, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = T.BodyFont,
			TextColor3 = stars > 0 and T.Gold or T.Muted,
			Parent = card,
		})
		if open then
			cardButton(
				card,
				record and record.done and "Play again" or "Play",
				record and record.done and T.Accent or T.Good,
				function()
					if act("PlayCourse", course.id) then
						Panels.Courses.close()
					end
				end
			)
			UI.button("Times", T.Card, function()
				timesFor = course.id
				Panels.Courses.refresh()
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -170, 0.5, 0),
				Size = UDim2.fromOffset(76, 36),
				Parent = card,
			})
		else
			cardButton(card, "Locked", T.Card, function()
				local previous = Courses.Previous(course.id)
				if not Courses.WorldUnlocked(data.adventure, world.id) then
					Notifications.Show(string.format("%s opens at %d stars", world.name, world.stars), "warning")
				elseif previous then
					Notifications.Show("Finish " .. previous.name .. " first", "warning")
				end
			end)
		end
	end
end

function Panels.Init(screenGui)
	Panels.Shop = UI.window(screenGui, "Shop", renderShop)
	Panels.Locker = UI.window(screenGui, "Locker", renderLocker)
	Panels.Quests = UI.window(screenGui, "Daily Quests", renderQuests)
	Panels.Courses = UI.window(screenGui, "Adventure", renderCourses)

	State.Changed:Connect(function()
		for _, name in ipairs({ "Shop", "Locker", "Quests", "Courses" }) do
			Panels[name].refresh()
		end
	end)

	-- The server opens a menu, e.g. a world's courses when you walk into its gate
	Remotes.OpenPanel.OnClientEvent:Connect(function(name, argument)
		if name == "Courses" and Worlds.ById[argument or ""] then
			worldTab = argument
			timesFor = nil
		end
		local panel = Panels[name]
		if panel then
			panel.open()
		end
	end)
end

return Panels
