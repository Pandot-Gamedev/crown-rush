-- Every cosmetic in the game. Cosmetics are looks only: they never change how
-- fast you run, how high you jump or anything else about winning.
--
-- kind:   "trail" (behind you as you run), "celebrate" (when you finish a course
--         or qualify), "dance" (when you win the crown), "hammer" (your foam
--         hammer in fight rounds), "title" (text above your head)
-- source: "default" (everyone has it), "coins" (buy with coins in the Locker),
--         "level" (free at that level), "robux" (developer product, see productId),
--         "vip" (comes with the VIP pass), "earned" (unlocked by playing, see rule),
--         "community" (free for joining our community, see Shared/OurGames)
--
-- A productId of 0 means "not set up yet": the item shows as "Coming soon".
-- tools/create_shop_items.luau makes the products and prints the ids to paste here.

local Cosmetics = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Cosmetics.Kinds = {
	{ id = "trail", name = "Trails", short = "Trails" },
	{ id = "celebrate", name = "Finish celebrations", short = "Celebrate" },
	{ id = "hammer", name = "Hammers", short = "Hammers" },
	{ id = "title", name = "Titles", short = "Titles" },
	{ id = "dance", name = "Crown dances", short = "Dances" },
}

Cosmetics.List = {
	-- Trails
	{
		id = "trail_bubble",
		kind = "trail",
		name = "Bubble Trail",
		source = "coins",
		price = 800,
		colors = { rgb(150, 220, 255), rgb(255, 255, 255) },
	},
	{
		id = "trail_leaf",
		kind = "trail",
		name = "Leaf Trail",
		source = "coins",
		price = 1600,
		colors = { rgb(110, 200, 90), rgb(220, 240, 120) },
	},
	{
		id = "trail_sparkle",
		kind = "trail",
		name = "Sparkle Trail",
		source = "coins",
		price = 3000,
		colors = { rgb(0, 170, 255), rgb(0, 255, 200) },
	},
	{
		id = "trail_candy",
		kind = "trail",
		name = "Candy Trail",
		source = "level",
		level = 5,
		colors = { rgb(255, 120, 200), rgb(255, 255, 255), rgb(255, 120, 200) },
	},
	{
		id = "trail_frost",
		kind = "trail",
		name = "Frost Trail",
		source = "earned",
		rule = "stars",
		amount = 45,
		colors = { rgb(200, 240, 255), rgb(120, 180, 255) },
	},
	{
		id = "trail_golden",
		kind = "trail",
		name = "Golden Trail",
		source = "vip",
		colors = { rgb(255, 230, 120), rgb(255, 170, 20) },
	},
	{
		id = "trail_crew",
		kind = "trail",
		name = "Crew Trail",
		source = "community",
		colors = { rgb(0, 230, 210), rgb(150, 80, 255) },
	},
	{
		id = "trail_rainbow",
		kind = "trail",
		name = "Rainbow Dash",
		source = "robux",
		productId = 3723594453,
		suggestedPrice = 99,
		colors = { rgb(255, 0, 0), rgb(255, 255, 0), rgb(0, 255, 0), rgb(0, 120, 255), rgb(200, 0, 255) },
	},
	{
		id = "trail_fire",
		kind = "trail",
		name = "Fire Streak",
		source = "robux",
		productId = 3723594468,
		suggestedPrice = 79,
		colors = { rgb(255, 220, 0), rgb(255, 40, 0) },
	},
	{
		id = "trail_stars",
		kind = "trail",
		name = "Star Dust",
		source = "robux",
		productId = 3723594483,
		suggestedPrice = 99,
		colors = { rgb(255, 255, 200), rgb(180, 140, 255), rgb(60, 40, 160) },
	},
	{
		id = "trail_bubblepop",
		kind = "trail",
		name = "Bubblegum",
		source = "robux",
		productId = 3723594495,
		suggestedPrice = 49,
		colors = { rgb(255, 150, 220), rgb(255, 210, 240) },
	},
	{
		id = "trail_lightning",
		kind = "trail",
		name = "Lightning",
		source = "robux",
		productId = 3723594512,
		suggestedPrice = 89,
		colors = { rgb(140, 220, 255), rgb(255, 255, 255), rgb(140, 220, 255) },
	},

	-- Finish celebrations
	{
		id = "cel_sparkles",
		kind = "celebrate",
		name = "Sparkles",
		source = "default",
		colors = { rgb(255, 255, 255), rgb(255, 230, 140) },
	},
	{
		id = "cel_bubbles",
		kind = "celebrate",
		name = "Bubbles",
		source = "coins",
		price = 1200,
		colors = { rgb(120, 220, 255), rgb(255, 255, 255) },
	},
	{
		id = "cel_hearts",
		kind = "celebrate",
		name = "Hearts",
		source = "level",
		level = 10,
		colors = { rgb(255, 80, 140), rgb(255, 170, 200) },
	},
	{
		id = "cel_confetti",
		kind = "celebrate",
		name = "Confetti Cannon",
		source = "robux",
		productId = 3723594526,
		suggestedPrice = 49,
		colors = { rgb(255, 70, 70), rgb(255, 220, 50), rgb(70, 200, 255), rgb(120, 255, 120), rgb(220, 100, 255) },
	},
	{
		id = "cel_star",
		kind = "celebrate",
		name = "Cartoon Star",
		source = "robux",
		productId = 3723594536,
		suggestedPrice = 59,
		colors = { rgb(255, 230, 40), rgb(255, 170, 0) },
	},
	{
		id = "cel_fireworks",
		kind = "celebrate",
		name = "Fireworks",
		source = "robux",
		productId = 3723594553,
		suggestedPrice = 79,
		colors = { rgb(255, 90, 60), rgb(80, 160, 255), rgb(255, 240, 120) },
	},
	{
		id = "cel_lightning",
		kind = "celebrate",
		name = "Lightning Strike",
		source = "robux",
		productId = 3723594561,
		suggestedPrice = 79,
		colors = { rgb(140, 220, 255), rgb(255, 255, 255) },
	},

	-- Hammers (fight rounds)
	{
		id = "hammer_foam",
		kind = "hammer",
		name = "Foam Hammer",
		source = "default",
		shape = "hammer",
		head = rgb(235, 60, 60),
		handle = rgb(255, 210, 60),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "hammer_blue",
		kind = "hammer",
		name = "Blue Foam Hammer",
		source = "coins",
		price = 800,
		shape = "hammer",
		head = rgb(60, 140, 255),
		handle = rgb(240, 240, 240),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "hammer_mallet",
		kind = "hammer",
		name = "Wooden Mallet",
		source = "coins",
		price = 2000,
		shape = "mallet",
		head = rgb(170, 120, 70),
		handle = rgb(120, 80, 45),
		material = Enum.Material.Wood,
	},
	{
		id = "hammer_silver",
		kind = "hammer",
		name = "Silver Hammer",
		source = "level",
		level = 15,
		shape = "hammer",
		head = rgb(200, 205, 215),
		handle = rgb(60, 60, 70),
		material = Enum.Material.Metal,
	},
	{
		id = "hammer_diamond",
		kind = "hammer",
		name = "Diamond Hammer",
		source = "level",
		level = 30,
		shape = "hammer",
		head = rgb(140, 240, 255),
		handle = rgb(255, 255, 255),
		material = Enum.Material.Glass,
	},
	{
		id = "hammer_royal",
		kind = "hammer",
		name = "Royal Hammer",
		source = "vip",
		shape = "hammer",
		head = rgb(255, 200, 40),
		handle = rgb(150, 20, 60),
		material = Enum.Material.Foil,
	},
	{
		id = "hammer_golden",
		kind = "hammer",
		name = "Golden Hammer",
		source = "robux",
		productId = 3723594573,
		suggestedPrice = 99,
		shape = "hammer",
		head = rgb(255, 190, 30),
		handle = rgb(255, 230, 120),
		material = Enum.Material.Foil,
	},
	{
		id = "hammer_neon",
		kind = "hammer",
		name = "Neon Hammer",
		source = "robux",
		productId = 3723594585,
		suggestedPrice = 75,
		shape = "hammer",
		head = rgb(255, 60, 200),
		handle = rgb(60, 255, 230),
		material = Enum.Material.Neon,
	},
	{
		id = "hammer_chicken",
		kind = "hammer",
		name = "Rubber Chicken",
		source = "robux",
		productId = 3723594598,
		suggestedPrice = 99,
		shape = "chicken",
		head = rgb(255, 225, 60),
		handle = rgb(255, 150, 40),
		material = Enum.Material.SmoothPlastic,
	},
	{
		id = "hammer_fish",
		kind = "hammer",
		name = "Big Fish",
		source = "robux",
		productId = 3723594610,
		suggestedPrice = 49,
		shape = "fish",
		head = rgb(80, 170, 220),
		handle = rgb(240, 120, 60),
		material = Enum.Material.SmoothPlastic,
	},

	-- Titles
	{
		id = "title_speedy",
		kind = "title",
		name = "Speedy",
		text = "Speedy",
		source = "level",
		level = 10,
		color = rgb(150, 220, 255),
	},
	{
		id = "title_star",
		kind = "title",
		name = "Course Star",
		text = "Course Star",
		source = "level",
		level = 25,
		color = rgb(255, 220, 90),
	},
	{
		id = "title_legend",
		kind = "title",
		name = "Crown Legend",
		text = "Crown Legend",
		source = "level",
		level = 50,
		color = rgb(255, 140, 40),
	},
	{
		id = "title_firstcrown",
		kind = "title",
		name = "First Crown",
		text = "First Crown",
		source = "earned",
		rule = "crowns",
		amount = 1,
		color = rgb(140, 230, 140),
	},
	{
		id = "title_champion",
		kind = "title",
		name = "Champion",
		text = "Champion",
		source = "earned",
		rule = "crowns",
		amount = 25,
		color = rgb(255, 200, 40),
	},
	{
		id = "title_collector",
		kind = "title",
		name = "Star Collector",
		text = "Star Collector",
		source = "earned",
		rule = "stars",
		amount = 90,
		color = rgb(255, 240, 120),
	},
	{
		id = "title_gemhunter",
		kind = "title",
		name = "Gem Hunter",
		text = "Gem Hunter",
		source = "earned",
		rule = "gems",
		amount = 90,
		color = rgb(80, 230, 255),
	},
	{
		id = "title_crew",
		kind = "title",
		name = "Pandot Crew",
		text = "Pandot Crew",
		source = "community",
		color = rgb(0, 230, 210),
	},
	{
		id = "title_obbymaster",
		kind = "title",
		name = "Obby Master",
		text = "Obby Master",
		source = "robux",
		productId = 3723594627,
		suggestedPrice = 49,
		color = rgb(120, 200, 255),
	},
	{
		id = "title_speeddemon",
		kind = "title",
		name = "Speed Demon",
		text = "Speed Demon",
		source = "robux",
		productId = 3723594638,
		suggestedPrice = 25,
		color = rgb(255, 90, 90),
	},
	{
		id = "title_royalty",
		kind = "title",
		name = "Crown Royalty",
		text = "Crown Royalty",
		source = "robux",
		productId = 3723594651,
		suggestedPrice = 49,
		color = rgb(255, 200, 60),
	},

	-- Crown dances (when you win a tournament)
	{ id = "dance_cheer", kind = "dance", name = "Cheer", source = "default" },
	{ id = "dance_jump", kind = "dance", name = "Victory Jump", source = "level", level = 20 },
	{ id = "dance_spin", kind = "dance", name = "Spin", source = "coins", price = 2500 },
	{ id = "dance_hop", kind = "dance", name = "Bunny Hop", source = "coins", price = 4000 },
	{ id = "dance_flip", kind = "dance", name = "Backflip", source = "coins", price = 6000 },
	{ id = "dance_heli", kind = "dance", name = "Helicopter", source = "earned", rule = "crowns", amount = 10 },
}

Cosmetics.Defaults = {
	hammer = "hammer_foam",
	celebrate = "cel_sparkles",
	dance = "dance_cheer",
}

Cosmetics.ById = {}
Cosmetics.ByProductId = {}
for index, item in ipairs(Cosmetics.List) do
	item.order = index
	Cosmetics.ById[item.id] = item
	if item.productId and item.productId ~= 0 then
		Cosmetics.ByProductId[item.productId] = item
	end
end

-- True if the player can use this item. vip = owns the VIP pass.
function Cosmetics.Owns(data, item, vip)
	if item.source == "default" then
		return true
	elseif item.source == "vip" then
		return vip == true
	end
	return data.cosmetics.owned[item.id] == true
end

-- The item the player shows for a kind (falls back to the free default)
function Cosmetics.Equipped(data, kind, vip)
	local item = Cosmetics.ById[data.cosmetics.equipped[kind] or ""]
	if item and Cosmetics.Owns(data, item, vip) then
		return item
	end
	return Cosmetics.ById[Cosmetics.Defaults[kind] or ""]
end

return Cosmetics
