-- Button Handler for UI Panels

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local networkFolder = ReplicatedStorage:WaitForChild("Network")

local screenGui = script.Parent
local buttonPanel = screenGui:WaitForChild("Buttons")

-- Get all panels
local rebirthPanel = screenGui:FindFirstChild("RebirthFrame")
local shopPanel = screenGui:FindFirstChild("ShopFrame")
local gearPanel = screenGui:FindFirstChild("GearShopFrame")

-- Get all buttons
local rebirthButton = buttonPanel:FindFirstChild("RebirthButton")
local inviteButton = buttonPanel:FindFirstChild("InviteButton")
local shopButton = buttonPanel:FindFirstChild("ShopButton")
local gearButton = buttonPanel:FindFirstChild("GearButton")

-- Get remote events
local rebirthEvent = networkFolder:FindFirstChild("RebirthEvent")
local inviteFriendsEvent = networkFolder:WaitForChild("InviteFriendsEvent")
local shopDataEvent = networkFolder:WaitForChild("ShopDataEvent")

-- Rebirth requirements (scales with each rebirth)
local REBIRTH_REWARDS = {
    [1] = {multiplier = 1.5, name = "1.5x Money"},
    [2] = {multiplier = 2, name = "2x Money"},
    [3] = {multiplier = 2.5, name = "2.5x Money"},
    [4] = {multiplier = 3, name = "3x Money"},
    [5] = {multiplier = 3.5, name = "3.5x Money"},
    [6] = {multiplier = 4, name = "4x Money"},
    [7] = {multiplier = 4.5, name = "4.5x Money"},
    [8] = {multiplier = 5, name = "5x Money"},
    [9] = {multiplier = 5.5, name = "5.5x Money"},
    [10] = {multiplier = 6, name = "6x Money"},
}

-- Format number for display
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

-- Function to update rebirth panel progress bars
local function updateRebirthPanel()
    if not rebirthPanel then return end
    
    local holderImage = rebirthPanel:FindFirstChild("Content", true)
    if not holderImage then return end
    
    local holder = rebirthPanel.Content:FindFirstChild("Holder")
    if not holder then return end
    
    local holderImageFrame = holder:FindFirstChild("HolderImage")
    if not holderImageFrame then return end
    
    local rYeet = holderImageFrame:FindFirstChild("RYeet")
    local rDistance = holderImageFrame:FindFirstChild("RDistance")
    local rMoney = holderImageFrame:FindFirstChild("RMoney")
    
    -- Get current stats from server (we'll receive these via event)
    -- For now, set default values
end

-- Update rebirth panel when shop data is received
shopDataEvent.OnClientEvent:Connect(function(currentPower, upgradeCost, currentMoney, canUpgrade, rebirths, totalThrows, maxDistance, totalDistance)
    if not rebirthPanel then return end
    
    local holder = rebirthPanel.Content and rebirthPanel.Content:FindFirstChild("Holder")
    if not holder then return end
    
    local holderImageFrame = holder:FindFirstChild("HolderImage")
    if not holderImageFrame then return end
    
    local rYeet = holderImageFrame:FindFirstChild("RYeet")
    local rDistance = holderImageFrame:FindFirstChild("RDistance")
    local rMoney = holderImageFrame:FindFirstChild("RMoney")
    
    -- Calculate requirements for next rebirth
    local nextRebirth = rebirths + 1
    local requiredThrows = 50 * nextRebirth
    local requiredDistance = 500 * nextRebirth
    local requiredMoney = 10000 * (2 ^ rebirths)
    
    -- Update progress bars
    if rYeet and rYeet:FindFirstChild("Bar") then
        local progress = rYeet.Bar:FindFirstChild("Progress")
        local progressText = rYeet.Bar:FindFirstChild("ProgressText")
        if progress then
            local percent = math.min(totalThrows / requiredThrows, 1)
            progress.Size = UDim2.new(percent, 0, 1, 0)
        end
        if progressText then
            progressText.Text = formatNumber(totalThrows) .. "/" .. formatNumber(requiredThrows) .. " (Yeets)"
        end
    end
    
    if rDistance and rDistance:FindFirstChild("Bar") then
        local progress = rDistance.Bar:FindFirstChild("Progress")
        local progressText = rDistance.Bar:FindFirstChild("ProgressText")
        totalDistance = totalDistance or 0
        if progress then
            local percent = math.min(totalDistance / requiredDistance, 1)
            progress.Size = UDim2.new(percent, 0, 1, 0)
        end
        if progressText then
            progressText.Text = formatNumber(totalDistance) .. "/" .. formatNumber(requiredDistance) .. " (Distance)"
        end
    end
    
    if rMoney and rMoney:FindFirstChild("Bar") then
        local progress = rMoney.Bar:FindFirstChild("Progress")
        local progressText = rMoney.Bar:FindFirstChild("ProgressText")
        if progress then
            local percent = math.min(currentMoney / requiredMoney, 1)
            progress.Size = UDim2.new(percent, 0, 1, 0)
        end
        if progressText then
            progressText.Text = "$" .. formatNumber(currentMoney) .. "/$" .. formatNumber(requiredMoney) .. " (Money)"
        end
    end
    
    -- Update unlock text
    local unlockable = rebirthPanel.Content and rebirthPanel.Content:FindFirstChild("Unlockable")
    if unlockable then
        local txt = unlockable:FindFirstChild("Txt")
        if txt then
            local unlocking = txt:FindFirstChild("Unlocking")
            if unlocking then
                local reward = REBIRTH_REWARDS[nextRebirth] or REBIRTH_REWARDS[10]
                unlocking.Text = reward.name
            end
        end
    end
end)

-- Function to close all panels
local function closeAllPanels()
    if rebirthPanel then rebirthPanel.Visible = false end
    if shopPanel then shopPanel.Visible = false end
    if gearPanel then gearPanel.Visible = false end
end

-- Function to toggle a panel
local function togglePanel(panel)
    if panel then
        local wasVisible = panel.Visible
        closeAllPanels()
        panel.Visible = not wasVisible
        
        -- Handle movement
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if panel.Visible then
                    humanoid.WalkSpeed = 0
                else
                    humanoid.WalkSpeed = 16
                end
            end
        end
    end
end

-- Connect button events
if rebirthButton then
    rebirthButton.MouseButton1Click:Connect(function()
        togglePanel(rebirthPanel)
        -- Request shop data to update progress bars
        if rebirthPanel and rebirthPanel.Visible then
            shopDataEvent:FireServer()
        end
    end)
end

if inviteButton then
    inviteButton.MouseButton1Click:Connect(function()
        -- Fire server to open Roblox's native invite menu
        inviteFriendsEvent:FireServer()
    end)
end

if shopButton then
    shopButton.MouseButton1Click:Connect(function()
        togglePanel(shopPanel)
    end)
end

if gearButton then
    gearButton.MouseButton1Click:Connect(function()
        togglePanel(gearPanel)
    end)
end

-- Connect close buttons for each panel
local function setupCloseButton(panel, closeBtnPath)
    if panel then
        local closeBtn = closeBtnPath and panel:FindFirstChild(closeBtnPath, true) or panel:FindFirstChild("CloseButton")
        if closeBtn then
            closeBtn.MouseButton1Click:Connect(function()
                panel.Visible = false
                -- Re-enable movement
                local character = player.Character
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.WalkSpeed = 16
                    end
                end
            end)
        end
    end
end

setupCloseButton(rebirthPanel, "Header.CloseButton")
setupCloseButton(shopPanel)
setupCloseButton(gearPanel)

-- Handle Rebirth panel button (the actual rebirth button inside the panel)
if rebirthPanel then
    local content = rebirthPanel:FindFirstChild("Content")
    if content then
        local rebirthBtn = content:FindFirstChild("Rebirth")
        if rebirthBtn and rebirthEvent then
            rebirthBtn.MouseButton1Click:Connect(function()
                rebirthEvent:FireServer()
                rebirthPanel.Visible = false
                -- Re-enable movement
                local character = player.Character
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.WalkSpeed = 16
                    end
                end
            end)
        end
    end
end

-- Removed custom invite panel - using Roblox's native invite menu

print("ButtonHandler loaded!")
