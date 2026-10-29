-- Creates the Bonk Arena game pass and developer products through Roblox Open
-- Cloud, with their prices and icons, so nobody has to make them by hand.
--
-- One-time setup:
--   1. Creator Hub > Open Cloud > API Keys > Create API Key, with write access to
--      "game-passes" and "developer-products" for this experience only.
--   2. In Studio: File > Experience Settings > Security: turn on Allow HTTP Requests,
--      and under Local Secrets create one named ShopKey holding the key, domain
--      apis.roblox.com.
--   3. Set UNIVERSE below to the experience's universe id (game.GameId).
-- Then press Play, pick the Server view and paste this file into the command bar.
-- It prints one "ITEM" line per item with its new id. Developer products that
-- already exist (same name) are skipped, but the game pass is not, so set
-- MAKE_PASSES to false before running it a second time. Turn Allow HTTP Requests
-- off again afterwards, and put the ids in src/shared/Shop.luau and
-- src/shared/Cosmetics.luau.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local UNIVERSE = 10773598334
-- The VIP pass was created on 2026-10-29 (2060495027), so this stays false.
local MAKE_PASSES = false
local ICONS = "https://raw.githubusercontent.com/Pandot-Gamedev/bonk-arena/refs/heads/claude/project-thread-x8udij/store/"
local key = HttpService:GetSecret("ShopKey")

local PASSES = {
	{ "VIP", 250, "Golden name tag, a crown, the Royal Hammer and +25% coins. Coins only buy looks, never power.", "pass_vip.png" },
}
local PRODUCTS = {
	{ "Galaxy Hammer", 149, "A swirling galaxy look for your hammer. Looks only.", "product_hammer_galaxy.png", "hammer_galaxy" },
	{ "Rubber Chicken", 129, "Bonk with a squeaky rubber chicken. Looks only.", "product_hammer_chicken.png", "hammer_chicken" },
	{ "Golden Hammer", 99, "A shiny gold look for your hammer. Looks only.", "product_hammer_golden.png", "hammer_golden" },
	{ "Neon Hammer", 75, "A glowing neon look for your hammer. Looks only.", "product_hammer_neon.png", "hammer_neon" },
	{ "Big Fish", 49, "Bonk with a big floppy fish. Looks only.", "product_hammer_fish.png", "hammer_fish" },
	{ "Lightning Strike KO", 129, "Lightning strikes where you knock someone out. Looks only.", "product_ko_lightning.png", "ko_lightning" },
	{ "Fireworks KO", 99, "Fireworks go off where you knock someone out. Looks only.", "product_ko_fireworks.png", "ko_fireworks" },
	{ "Cartoon Star KO", 75, "A cartoon star pops where you knock someone out. Looks only.", "product_ko_star.png", "ko_star" },
	{ "Confetti Blast KO", 49, "Confetti bursts where you knock someone out. Looks only.", "product_ko_confetti.png", "ko_confetti" },
	{ "Helicopter Dance", 99, "Spin your hammer like a helicopter when you win. Looks only.", "product_dance_heli.png", "dance_heli" },
	{ "Backflip Dance", 75, "Do a backflip on the podium when you win. Looks only.", "product_dance_flip.png", "dance_flip" },
	{ "Bunny Hop Dance", 49, "Hop around the podium when you win. Looks only.", "product_dance_hop.png", "dance_hop" },
	{ "Spin Dance", 25, "Spin on the podium when you win. Looks only.", "product_dance_spin.png", "dance_spin" },
	{ "Title: Bonk Master", 99, "Shows \"Bonk Master\" above your head.", "product_title_bonkmaster.png", "title_bonkmaster" },
	{ "Title: Unbonkable", 49, "Shows \"Unbonkable\" above your head.", "product_title_unbonkable.png", "title_unbonkable" },
	{ "Title: Hammer Time", 25, "Shows \"Hammer Time\" above your head.", "product_title_hammertime.png", "title_hammertime" },
}

assert(UNIVERSE ~= 0, "Set UNIVERSE to game.GameId first")

-- A multipart/form-data body with text fields and one PNG file
local function form(fields, fileField, fileName, png)
	local boundary = "BonkArena" .. HttpService:GenerateGUID(false):gsub("-", "")
	local parts = {}
	for _, field in ipairs(fields) do
		table.insert(parts, string.format("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n", boundary, field[1], tostring(field[2])))
	end
	if png then
		table.insert(parts, string.format("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: image/png\r\n\r\n", boundary, fileField, fileName) .. png .. "\r\n")
	end
	table.insert(parts, "--" .. boundary .. "--\r\n")
	return table.concat(parts), "multipart/form-data; boundary=" .. boundary
end

local function icon(fileName)
	local ok, png = pcall(HttpService.GetAsync, HttpService, ICONS .. fileName)
	if not ok then
		warn("ICON missing " .. fileName .. ": " .. tostring(png))
		return nil
	end
	return png
end

local function post(path, body, contentType)
	local ok, response = pcall(HttpService.RequestAsync, HttpService, {
		Url = "https://apis.roblox.com" .. path,
		Method = "POST",
		Headers = { ["x-api-key"] = key, ["Content-Type"] = contentType },
		Body = body,
	})
	if not ok then
		return nil, tostring(response)
	end
	if not response.Success then
		return nil, response.StatusCode .. " " .. response.Body:sub(1, 300)
	end
	return HttpService:JSONDecode(response.Body)
end

-- Developer products that already exist, by name, so a second run skips them
local existingProducts = {}
local pages = MarketplaceService:GetDeveloperProductsAsync()
while true do
	for _, product in ipairs(pages:GetCurrentPage()) do
		existingProducts[product.Name] = product.ProductId
	end
	if pages.IsFinished then
		break
	end
	pages:AdvanceToNextPageAsync()
end

if MAKE_PASSES then
	for _, pass in ipairs(PASSES) do
		local body, contentType = form({
			{ "name", pass[1] },
			{ "description", pass[3] },
			{ "isForSale", "true" },
			{ "price", pass[2] },
			{ "isRegionalPricingEnabled", "true" },
		}, "imageFile", pass[4], icon(pass[4]))
		local result, problem = post(string.format("/game-passes/v1/universes/%d/game-passes", UNIVERSE), body, contentType)
		if result then
			print("ITEM pass", pass[1], result.gamePassId or result.id or HttpService:JSONEncode(result))
		else
			warn("FAILED pass " .. pass[1] .. ": " .. problem)
		end
		task.wait(1)
	end
end

for _, product in ipairs(PRODUCTS) do
	if existingProducts[product[1]] then
		print("ITEM product", product[5], existingProducts[product[1]], "(already there)")
	else
		local body, contentType = form({
			{ "name", product[1] },
			{ "description", product[3] },
			{ "isForSale", "true" },
			{ "price", product[2] },
			{ "isRegionalPricingEnabled", "true" },
		}, "imageFile", product[4], icon(product[4]))
		local result, problem = post(string.format("/developer-products/v2/universes/%d/developer-products", UNIVERSE), body, contentType)
		if result then
			print("ITEM product", product[5], result.productId or result.id or HttpService:JSONEncode(result))
		else
			warn("FAILED product " .. product[1] .. ": " .. problem)
		end
		task.wait(1)
	end
end
print("ITEM done")
