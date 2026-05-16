-- Shop Handler - Handles gamepass purchases from the shop UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local networkFolder = ReplicatedStorage.shared:WaitForChild("Network")

local screenGui = script.Parent
local shopFrame = screenGui:FindFirstChild("ShopFrame")

-- Get remote events
local gamepassCheckEvent = networkFolder:WaitForChild("GamepassCheckEvent")
local gamepassPurchaseEvent = networkFolder:WaitForChild("GamepassPurchaseEvent")

-- Load gamepass configuration
local GamepassConfig = require(ReplicatedStorage:WaitForChild("GamepassConfig"))

-- Track owned gamepasses
local ownedGamepasses = {}
local gamepassDataReceived = false

-- Function to set initial prices from config
local function setInitialPrices()
    if not shopFrame then return end
    
    local scrollingFrame = shopFrame:FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return end
    
    for _, itemFrame in ipairs(scrollingFrame:GetChildren()) do
        if itemFrame:IsA("Frame") then
            local itemName = itemFrame.Name
            local buyButton = nil
            for _, child in ipairs(itemFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    buyButton = child
                    break
                end
            end
            local priceLabel = buyButton and buyButton:FindFirstChild("TextLabel")
            
            local gamepassName = nil
            if itemName == "2xMoney" then
                gamepassName = "DoubleMoney"
            elseif itemName == "V.I.P" then
                gamepassName = "VIP"
            elseif itemName == "AutoRebirth" then
                gamepassName = "AutoRebirth"
            elseif itemName == "AutoThrow" then
                gamepassName = "AutoThrow"
            end
            
            if gamepassName and priceLabel then
                local price = GamepassConfig.Prices[gamepassName] or 0
                priceLabel.Text = "R$ " .. price
            end
        end
    end
end

-- Function to update shop UI based on ownership
local function updateShopUI()
    if not shopFrame then return end
    
    local scrollingFrame = shopFrame:FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return end
    
    -- Update each shop item
    for _, itemFrame in ipairs(scrollingFrame:GetChildren()) do
        if itemFrame:IsA("Frame") then
            local itemName = itemFrame.Name
            -- Find the buy button (named BuyXXX or just any TextButton)
            local buyButton = nil
            for _, child in ipairs(itemFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    buyButton = child
                    break
                end
            end
            local priceLabel = buyButton and buyButton:FindFirstChild("TextLabel")
            
            -- Map shop item names to gamepass names and display names
            local gamepassName = nil
            if itemName == "2xMoney" then
                gamepassName = "DoubleMoney"
            elseif itemName == "V.I.P" then
                gamepassName = "VIP"
            elseif itemName == "AutoRebirth" then
                gamepassName = "AutoRebirth"
            elseif itemName == "AutoThrow" then
                gamepassName = "AutoThrow"
            end
            
            if gamepassName and ownedGamepasses[gamepassName] then
                -- Player owns this gamepass - show "Owned"
                if priceLabel then
                    priceLabel.Text = "Owned"
                    priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
                if buyButton then
                    buyButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                end
            elseif gamepassName then
                -- Player doesn't own - show the price in Robux
                local price = GamepassConfig.Prices[gamepassName] or 0
                if priceLabel then
                    priceLabel.Text = "R$ " .. price
                    priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
                if buyButton then
                    buyButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0) -- Green buy button
                end
            end
        end
    end
end

-- Function to handle buy button click
local function onBuyButtonClicked(itemFrame, gamepassName)
    local gamepassId = GamepassConfig.IDs[gamepassName]
    if not gamepassId then
        warn("Gamepass ID not found for: " .. gamepassName)
        return
    end
    
    -- Check if already owned
    if ownedGamepasses[gamepassName] then
        return -- Already owned
    end
    
    -- Prompt purchase
    MarketplaceService:PromptGamePassPurchase(player, gamepassId)
end

local function getGamepassNameFromId(gamepassId)
    for gamepassName, id in pairs(GamepassConfig.IDs) do
        if id == gamepassId then
            return gamepassName
        end
    end

    return nil
end

-- Setup buy buttons
local function setupBuyButtons()
    if not shopFrame then return end
    
    local scrollingFrame = shopFrame:FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return end
    
    for _, itemFrame in ipairs(scrollingFrame:GetChildren()) do
        if itemFrame:IsA("Frame") then
            local itemName = itemFrame.Name
            -- Find the buy button (named BuyXXX or just any TextButton)
            local buyButton = nil
            for _, child in ipairs(itemFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    buyButton = child
                    break
                end
            end
            
            if buyButton then
                -- Map shop item names to gamepass names
                local gamepassName = nil
                if itemName == "2xMoney" then
                    gamepassName = "DoubleMoney"
                elseif itemName == "V.I.P" then
                    gamepassName = "VIP"
                elseif itemName == "AutoRebirth" then
                    gamepassName = "AutoRebirth"
                elseif itemName == "AutoThrow" then
                    gamepassName = "AutoThrow"
                end
                
                if gamepassName then
                    buyButton.MouseButton1Click:Connect(function()
                        onBuyButtonClicked(itemFrame, gamepassName)
                    end)
                end
            end
        end
    end
end

-- Handle gamepass ownership updates from server
gamepassCheckEvent.OnClientEvent:Connect(function(data)
    -- Only handle gamepass ownership updates here
    -- Auto-throw is handled by AutoSwitchHandler
    if type(data) == "table" and not data.autoThrow then
        -- Handle new format with gamepasses key
        if data.gamepasses then
            ownedGamepasses = {}
            for k, v in pairs(data.gamepasses) do
                ownedGamepasses[k] = v
            end
        else
            -- Legacy format
            ownedGamepasses = {}
            for k, v in pairs(data) do
                ownedGamepasses[k] = v
            end
        end
        gamepassDataReceived = true
        updateShopUI()
        print("ShopHandler - Gamepass data updated")
        for k, v in pairs(ownedGamepasses) do
            print("  " .. k .. " = " .. tostring(v))
        end
        
        -- Check if player owns all gamepasses
        local allOwned = true
        for name, _ in pairs(GamepassConfig.IDs) do
            if not ownedGamepasses[name] then
                allOwned = false
                break
            end
        end
        if allOwned then
            print("Player owns ALL gamepasses!")
        end
    end
end)

-- Initialize
setInitialPrices()
setupBuyButtons()

-- Request current gamepass status
gamepassCheckEvent:FireServer()

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasePlayer, gamepassId, wasPurchased)
    if purchasePlayer ~= player or not wasPurchased then return end

    local gamepassName = getGamepassNameFromId(gamepassId)
    if not gamepassName then return end

    ownedGamepasses[gamepassName] = true
    updateShopUI()
    gamepassCheckEvent:FireServer()
end)

print("ShopHandler loaded successfully!")
