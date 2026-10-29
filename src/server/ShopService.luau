-- Robux purchases: the VIP game pass and cosmetic developer products.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Shop = require(Shared.Shop)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local ShopService = {}

function ShopService.HasPass(player, passId)
	local runtime = DataService.GetRuntime(player)
	return runtime ~= nil and runtime.passes ~= nil and runtime.passes[passId] == true
end

local function checkPasses(player, runtime)
	runtime.passes = {}
	local testing = RunService:IsStudio() and Config.TestPassesInStudio
	for _, pass in ipairs(Shop.Passes) do
		if testing then
			runtime.passes[pass.id] = true
		elseif pass.gamePassId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.gamePassId)
			end)
			runtime.passes[pass.id] = ok and owns or false
		end
	end
end

local function onPassPurchased(player, gamePassId, purchased)
	if not purchased then
		return
	end
	for _, pass in ipairs(Shop.Passes) do
		if pass.gamePassId == gamePassId and pass.gamePassId ~= 0 then
			DataService.Update(player, function(_, runtime)
				runtime.passes[pass.id] = true
			end)
			Remotes.Notify:FireClient(player, "Thanks for buying " .. pass.name .. "!", "success")
		end
	end
end

-- Roblox calls this for every developer product purchase. It must only return
-- PurchaseGranted once the item is given AND saved, otherwise Roblox retries later.
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not DataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local item = Cosmetics.ByProductId[receipt.ProductId]
	if not item then
		warn("[ShopService] Unknown product id " .. tostring(receipt.ProductId) .. " - add it to Cosmetics.luau")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.Get(player)
	if data.purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	DataService.Update(player, function(saved)
		saved.purchases[receipt.PurchaseId] = true
		saved.cosmetics.owned[item.id] = true
		saved.cosmetics.equipped[item.kind] = item.id
	end)

	if not DataService.SaveNow(player) then
		-- Keep the item, Roblox will call again and the purchase id stops a double grant
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Remotes.Notify:FireClient(player, "You got " .. item.name .. "! It's equipped.", "success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Start()
	DataService.OnLoaded(function(player, _, runtime)
		checkPasses(player, runtime)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	MarketplaceService.ProcessReceipt = processReceipt
end

return ShopService
