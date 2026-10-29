-- Creates the Crown Rush game pass and developer products through Roblox Open
-- Cloud, with their prices and icons, so nobody has to make them by hand.
-- The products are every Robux cosmetic in src/shared/Cosmetics.luau, and the
-- icons come from store/ (drawn by tools/make_store_art.py).
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
local Cosmetics = require(game:GetService("ReplicatedStorage").Shared.Cosmetics)
local Shop = require(game:GetService("ReplicatedStorage").Shared.Shop)

local UNIVERSE = 0
local MAKE_PASSES = true
local ICONS =
	"https://raw.githubusercontent.com/Pandot-Gamedev/crown-rush/refs/heads/claude/project-thread-5pvzuk/store/"
local key = HttpService:GetSecret("ShopKey")

local PASSES = {}
for _, pass in ipairs(Shop.Passes) do
	table.insert(
		PASSES,
		{ pass.name, pass.suggestedPrice, pass.description, "pass_" .. string.lower(pass.id) .. ".png" }
	)
end

-- What each kind of cosmetic does, for the product descriptions
local WHAT = {
	trail = "A %s trail behind you as you run. Looks only.",
	celebrate = "%s when you cross a finish line or qualify. Looks only.",
	hammer = "The %s for fight rounds. Looks only, every hammer hits the same.",
	title = 'Shows "%s" above your head.',
}
local PRODUCTS = {}
for _, item in ipairs(Cosmetics.List) do
	if item.source == "robux" then
		local kind = item.kind
		local name = kind == "title" and ("Title: " .. item.text) or item.name
		table.insert(PRODUCTS, {
			name,
			item.suggestedPrice,
			string.format(WHAT[kind] or "%s. Looks only.", kind == "title" and item.text or item.name),
			"product_" .. item.id .. ".png",
			item.id,
		})
	end
end

assert(UNIVERSE ~= 0, "Set UNIVERSE to game.GameId first")

-- A multipart/form-data body with text fields and one PNG file
local function form(fields, fileField, fileName, png)
	local boundary = "CrownRush" .. HttpService:GenerateGUID(false):gsub("-", "")
	local parts = {}
	for _, field in ipairs(fields) do
		table.insert(
			parts,
			string.format(
				'--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n',
				boundary,
				field[1],
				tostring(field[2])
			)
		)
	end
	if png then
		table.insert(
			parts,
			string.format(
				'--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: image/png\r\n\r\n',
				boundary,
				fileField,
				fileName
			)
				.. png
				.. "\r\n"
		)
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
		local result, problem =
			post(string.format("/game-passes/v1/universes/%d/game-passes", UNIVERSE), body, contentType)
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
		local result, problem =
			post(string.format("/developer-products/v2/universes/%d/developer-products", UNIVERSE), body, contentType)
		if result then
			print("ITEM product", product[5], result.productId or result.id or HttpService:JSONEncode(result))
		else
			warn("FAILED product " .. product[1] .. ": " .. problem)
		end
		task.wait(1)
	end
end
print("ITEM done")
