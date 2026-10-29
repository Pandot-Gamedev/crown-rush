-- Everything sold for Robux. Nothing here helps you win: only looks.
-- The cosmetics sold for Robux (source = "robux") are in Cosmetics.luau with their
-- developer product ids.
--
-- An id of 0 means "not set up yet": the pass shows as "Coming soon" in the shop.
-- tools/create_shop_items.luau makes the pass and prints its id to paste here.

local Shop = {}

Shop.Passes = {
	{
		id = "VIP",
		gamePassId = 2057687861,
		name = "VIP",
		suggestedPrice = 250,
		description = "Golden name tag, a crown, the Golden Trail, the Royal Hammer and +25% coins (coins only buy looks).",
	},
}

Shop.PassById = {}
for _, pass in ipairs(Shop.Passes) do
	Shop.PassById[pass.id] = pass
end

return Shop
