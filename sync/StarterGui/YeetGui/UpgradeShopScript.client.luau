-- Upgrade Shop Client Script

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local networkFolder = ReplicatedStorage.shared:WaitForChild("Network")

-- Remote Events
local upgradeEvent = networkFolder:WaitForChild("UpgradePowerEvent")
local rebirthEvent = networkFolder:WaitForChild("RebirthEvent")
local shopDataEvent = networkFolder:WaitForChild("ShopDataEvent")

-- UI Elements
local screenGui = script.Parent
local shopFrame = screenGui:FindFirstChild("UpgradeShopFrame")
local powerLabel = shopFrame and shopFrame:FindFirstChild("PowerSection") and shopFrame.PowerSection:FindFirstChild("PowerLabel")
local powerCostLabel = shopFrame and shopFrame:FindFirstChild("PowerSection") and shopFrame.PowerSection:FindFirstChild("PowerCostLabel")
local upgradeBtn = shopFrame and shopFrame:FindFirstChild("PowerSection") and shopFrame.PowerSection:FindFirstChild("UpgradeButton")
local rebirthLabel = shopFrame and shopFrame:FindFirstChild("RebirthSection") and shopFrame.RebirthSection:FindFirstChild("RebirthLabel")
local rebirthCostLabel = shopFrame and shopFrame:FindFirstChild("RebirthSection") and shopFrame.RebirthSection:FindFirstChild("RebirthCostLabel")
local rebirthBtn = shopFrame and shopFrame:FindFirstChild("RebirthSection") and shopFrame.RebirthSection:FindFirstChild("RebirthButton")
local closeBtn = shopFrame and shopFrame:FindFirstChild("CloseButton")
local yourMoneyLabel = shopFrame and shopFrame:FindFirstChild("YourMoneyLabel")

-- Removed Max Throws UI - single throw only

-- Upgrade zone reference - use the UpgradeSign part
local upgradeZone = Workspace:FindFirstChild("Upgrades Shop") and Workspace["Upgrades Shop"]:FindFirstChild("UpgradeSign")

-- State
local isInShopZone = false
local shopData = {
    power = 0,
    upgradeCost = 100,
    money = 0,
    canUpgrade = false,
    rebirths = 0,
    totalThrows = 0
}

-- Format number
local function formatNumber(num)
    if num == nil then return "0" end
    local absNum = math.abs(num)
    local sign = num < 0 and "-" or ""
    if absNum >= 1e15 then
        return sign .. string.format("%.2fQA", absNum / 1e15):gsub("%.00", ""):gsub("(%.%d)0", "%1")
    elseif absNum >= 1e12 then
        return sign .. string.format("%.2fT", absNum / 1e12):gsub("%.00", ""):gsub("(%.%d)0", "%1")
    elseif absNum >= 1e9 then
        return sign .. string.format("%.2fB", absNum / 1e9):gsub("%.00", ""):gsub("(%.%d)0", "%1")
    elseif absNum >= 1e6 then
        return sign .. string.format("%.2fM", absNum / 1e6):gsub("%.00", ""):gsub("(%.%d)0", "%1")
    elseif absNum >= 1e3 then
        return sign .. string.format("%.2fk", absNum / 1e3):gsub("%.00", ""):gsub("(%.%d)0", "%1")
    else
        return tostring(math.floor(absNum))
    end
end

-- Update UI
local function updateUI()
    if not shopFrame then return end
    
    -- Power section
    if powerLabel then
        powerLabel.Text = "Power Level: " .. shopData.power .. "/100"
    end
    if powerCostLabel then
        if shopData.power >= 100 then
            powerCostLabel.Text = "MAX POWER REACHED!"
            powerCostLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
        else
            powerCostLabel.Text = "Cost: $" .. formatNumber(shopData.upgradeCost)
            powerCostLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        end
    end
    if upgradeBtn then
        if shopData.power >= 100 then
            upgradeBtn.Text = "MAXED!"
            upgradeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        elseif shopData.canUpgrade then
            upgradeBtn.Text = "UPGRADE POWER"
            upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        else
            upgradeBtn.Text = "NOT ENOUGH MONEY"
            upgradeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        end
    end
    
    -- Rebirth section
    local rebirthCost = 10000 * (2 ^ shopData.rebirths)
    if rebirthLabel then
        rebirthLabel.Text = "Rebirths: " .. shopData.rebirths
    end
    if rebirthCostLabel then
        rebirthCostLabel.Text = "Cost: $" .. formatNumber(rebirthCost)
    end
    if rebirthBtn then
        if shopData.money >= rebirthCost then
            rebirthBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
        else
            rebirthBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        end
    end
    
    -- Money label
    if yourMoneyLabel then
        yourMoneyLabel.Text = "Your Money: $" .. formatNumber(shopData.money)
    end
end

-- Receive shop data from server (simplified - no max throws)
shopDataEvent.OnClientEvent:Connect(function(power, upgradeCost, money, canUpgrade, rebirths, totalThrows, maxDistance, totalDistance)
    shopData.power = power
    shopData.upgradeCost = upgradeCost
    shopData.money = money
    shopData.canUpgrade = canUpgrade
    shopData.rebirths = rebirths
    shopData.totalThrows = totalThrows or 0
    -- maxDistance and totalDistance are used by ButtonHandler for rebirth panel
    updateUI()
end)

-- Check if in upgrade zone
local function checkInZone()
    if not upgradeZone then return false end
    
    local char = player.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local pos = hrp.Position
    local zonePos = upgradeZone.Position
    local zoneSize = upgradeZone.Size
    
    local halfSize = zoneSize / 2
    local inX = pos.X >= zonePos.X - halfSize.X and pos.X <= zonePos.X + halfSize.X
    local inZ = pos.Z >= zonePos.Z - halfSize.Z and pos.Z <= zonePos.Z + halfSize.Z
    local inY = pos.Y >= zonePos.Y - halfSize.Y - 5 and pos.Y <= zonePos.Y + halfSize.Y + 5
    
    return inX and inZ and inY
end

-- Toggle shop visibility
local function toggleShop(show)
    if not shopFrame then return end
    
    if show then
        shopFrame.Visible = true
        shopFrame.Position = UDim2.new(0.5, -175, 0.5, -220)
        shopFrame.Size = UDim2.new(0, 350, 0, 440)
        -- Disable movement when shop is open
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 0
            end
        end
    else
        shopFrame.Visible = false
        -- Re-enable movement when shop closes
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
            end
        end
    end
end

-- Update loop
RunService.Heartbeat:Connect(function()
    local wasInZone = isInShopZone
    isInShopZone = checkInZone()
    
    -- Show/hide shop based on zone
    if isInShopZone and not wasInZone then
        toggleShop(true)
    elseif not isInShopZone and wasInZone then
        toggleShop(false)
    end
end)

-- Button handlers
if upgradeBtn then
    upgradeBtn.MouseButton1Click:Connect(function()
        if shopData.canUpgrade and shopData.power < 100 then
            upgradeEvent:FireServer("power")
        end
    end)
end

-- Removed max throws button handler

if rebirthBtn then
    rebirthBtn.MouseButton1Click:Connect(function()
        local rebirthCost = 10000 * (2 ^ shopData.rebirths)
        if shopData.money >= rebirthCost then
            rebirthEvent:FireServer()
        end
    end)
end

if closeBtn then
    closeBtn.MouseButton1Click:Connect(function()
        toggleShop(false)
    end)
end

-- Character respawn handling
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
end)

print("Upgrade Shop Script loaded!")
