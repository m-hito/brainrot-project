-- Auto Switch Handler - Handles existing ON/OFF switches for auto features

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = script.Parent
local networkFolder = ReplicatedStorage.shared:WaitForChild("Network")

-- Get the existing switch frames
local autoRebirthSwitch = screenGui:FindFirstChild("AutoRebirthSwitch")
local autoThrowSwitch = screenGui:FindFirstChild("AutoThrowSwitch")

-- Get remote events (wait for it to be created by server)
local gamepassCheckEvent = networkFolder:WaitForChild("GamepassCheckEvent", 5)

-- Load gamepass configuration
local GamepassConfig = require(ReplicatedStorage:WaitForChild("GamepassConfig"))

-- Track owned gamepasses and toggle states
local ownedGamepasses = {}
local autoRebirthEnabled = false
local autoThrowEnabled = false
local gamepassDataReceived = false

-- Animation settings
local TWEEN_TIME = 0.15

-- Colors for the switch states
local OFF_COLOR = Color3.fromRGB(200, 50, 50) -- Red for off
local ON_COLOR = Color3.fromRGB(50, 200, 50) -- Green for on

-- Function to update switch appearance with sliding animation
local function updateSwitch(switchFrame, isEnabled, animate)
    if not switchFrame then return end
    
    local background = switchFrame:FindFirstChild("Background")
    local uiStroke = switchFrame:FindFirstChild("UIStroke")
    local onFrame = switchFrame:FindFirstChild("Switch") and switchFrame.Switch:FindFirstChild("On")
    local offFrame = switchFrame:FindFirstChild("Switch") and switchFrame.Switch:FindFirstChild("Off")
    
    -- Target colors based on state
    local targetColor = isEnabled and ON_COLOR or OFF_COLOR
    
    if background then
        -- Background slides: left (0.25) = OFF, right (0.75) = ON
        local targetPosition = isEnabled and UDim2.new(0.75, 0, 0.5, 0) or UDim2.new(0.25, 0, 0.5, 0)
        
        if animate then
            -- Animate position
            local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local positionTween = TweenService:Create(background, tweenInfo, {Position = targetPosition})
            positionTween:Play()
            
            -- Update gradient color directly (cannot tween ColorSequence)
            local gradient = background:FindFirstChild("Gradient")
            if gradient then
                gradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, targetColor),
                    ColorSequenceKeypoint.new(1, targetColor:Lerp(Color3.new(1, 1, 1), 0.2))
                })
            end
        else
            background.Position = targetPosition
            local gradient = background:FindFirstChild("Gradient")
            if gradient then
                gradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, targetColor),
                    ColorSequenceKeypoint.new(1, targetColor:Lerp(Color3.new(1, 1, 1), 0.2))
                })
            end
        end
    end
    
    -- Update UIStroke color (border)
    if uiStroke then
        if animate then
            local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local strokeTween = TweenService:Create(uiStroke, tweenInfo, {Color = targetColor})
            strokeTween:Play()
        else
            uiStroke.Color = targetColor
        end
    end
    
    -- Update title colors - ON side is bright when enabled, OFF side is bright when disabled
    if onFrame then
        local onTitle = onFrame:FindFirstChild("Title")
        if onTitle then
            onTitle.TextColor3 = isEnabled and Color3.new(1, 1, 1) or Color3.fromRGB(80, 80, 80)
        end
    end
    
    if offFrame then
        local offTitle = offFrame:FindFirstChild("Title")
        if offTitle then
            offTitle.TextColor3 = isEnabled and Color3.fromRGB(80, 80, 80) or Color3.new(1, 1, 1)
        end
    end
end

-- Function to update switches visibility and state
local function updateSwitches()
    -- Always show switches - they will prompt purchase if player doesn't own gamepass
    if autoRebirthSwitch then
        autoRebirthSwitch.Visible = true
        updateSwitch(autoRebirthSwitch, autoRebirthEnabled, false)
    end
    
    if autoThrowSwitch then
        autoThrowSwitch.Visible = true
        updateSwitch(autoThrowSwitch, autoThrowEnabled, false)
    end
end

-- Function to enable/disable switch buttons (for loading state)
local function setSwitchesEnabled(enabled)
    for _, switchFrame in ipairs({autoRebirthSwitch, autoThrowSwitch}) do
        if switchFrame then
            local switchFolder = switchFrame:FindFirstChild("Switch")
            if switchFolder then
                for _, side in ipairs({"On", "Off"}) do
                    local sideFrame = switchFolder:FindFirstChild(side)
                    if sideFrame then
                        local clickButton = sideFrame:FindFirstChild("Click")
                        if clickButton then
                            clickButton.Active = enabled
                        end
                    end
                end
            end
        end
    end
end

-- Function to setup switch button events
local function setupSwitch(switchFrame, gamepassName, getEnabled, setEnabled)
    if not switchFrame then return end
    
    local switchFolder = switchFrame:FindFirstChild("Switch")
    local onFrame = switchFolder and switchFolder:FindFirstChild("On")
    local offFrame = switchFolder and switchFolder:FindFirstChild("Off")
    local onButton = onFrame and onFrame:FindFirstChild("Click")
    local offButton = offFrame and offFrame:FindFirstChild("Click")
    
    print("Setting up switch for", gamepassName, "- onButton:", onButton, "offButton:", offButton)
    
    local function setToggleState(newState)
        print("Switch clicked for", gamepassName, "new state:", newState)
        print("Gamepass data received:", gamepassDataReceived)
        print("Owned gamepasses table:", ownedGamepasses)
        print("Checking ownedGamepasses[" .. gamepassName .. "]:", ownedGamepasses[gamepassName])
        
        -- If gamepass data hasn't been received yet, wait a moment and retry
        if not gamepassDataReceived then
            print("Waiting for gamepass data...")
            task.wait(0.5)
        end
        
        if ownedGamepasses[gamepassName] then
            -- Player owns the gamepass - set the requested feature state
            setEnabled(newState)
            updateSwitch(switchFrame, newState, true)
            if gamepassCheckEvent then
                local toggleKey = gamepassName == "AutoRebirth" and "autoRebirthToggle" or "autoThrowToggle"
                print("Sending toggle to server:", toggleKey, newState)
                gamepassCheckEvent:FireServer({[toggleKey] = newState})
            end
        else
            -- Player doesn't own - prompt purchase directly
            print("Player doesn't own", gamepassName, "- prompting purchase")
            local gamepassId = GamepassConfig.IDs[gamepassName]
            if gamepassId then
                MarketplaceService:PromptGamePassPurchase(player, gamepassId)
            end
        end
    end
    
    -- ON and OFF are explicit states, not blind toggles. This keeps the switch from
    -- flipping back on when the player is trying to turn it off.
    if onButton then
        onButton.MouseButton1Click:Connect(function()
            setToggleState(true)
        end)
    end
    
    if offButton then
        offButton.MouseButton1Click:Connect(function()
            setToggleState(false)
        end)
    end
end

local function getGamepassNameFromId(gamepassId)
    for gamepassName, id in pairs(GamepassConfig.IDs) do
        if id == gamepassId then
            return gamepassName
        end
    end

    return nil
end

-- Setup switches
setupSwitch(autoRebirthSwitch, "AutoRebirth", function() return autoRebirthEnabled end, function(val) autoRebirthEnabled = val end)
setupSwitch(autoThrowSwitch, "AutoThrow", function() return autoThrowEnabled end, function(val) autoThrowEnabled = val end)

-- Disable switches until gamepass data is received
setSwitchesEnabled(false)

-- Handle gamepass ownership updates from server
if gamepassCheckEvent then
    gamepassCheckEvent.OnClientEvent:Connect(function(data)
        print("AutoSwitchHandler received data:", type(data))
        
        if type(data) == "table" then
            if data.autoThrow then
                -- Auto-throw notification - attempt to throw
                print("Auto-throw notification received, attempting throw")
                local throwEvent = networkFolder:FindFirstChild("ThrowBrainrotEvent")
                if throwEvent then
                    print("Firing ThrowBrainrotEvent with power 100")
                    throwEvent:FireServer(100) -- Full power
                else
                    warn("ThrowBrainrotEvent not found!")
                end
            elseif data.gamepasses then
                -- New format: {gamepasses = {...}, autoRebirthEnabled = bool, autoThrowEnabled = bool}
                ownedGamepasses = {}
                for k, v in pairs(data.gamepasses) do
                    ownedGamepasses[k] = v
                end
                
                -- Update toggle states from server
                if data.autoRebirthEnabled ~= nil then
                    autoRebirthEnabled = data.autoRebirthEnabled
                    print("Loaded saved AutoRebirth toggle state:", autoRebirthEnabled)
                end
                if data.autoThrowEnabled ~= nil then
                    autoThrowEnabled = data.autoThrowEnabled
                    print("Loaded saved AutoThrow toggle state:", autoThrowEnabled)
                end
                
                gamepassDataReceived = true
                updateSwitches()
                setSwitchesEnabled(true) -- Enable switches after data received
                
                -- Debug: Print owned gamepasses
                print("Owned gamepasses updated:")
                for k, v in pairs(ownedGamepasses) do
                    print("  " .. k .. " = " .. tostring(v))
                end
                
                -- Check if player owns AutoThrow
                if ownedGamepasses.AutoThrow then
                    print("Player owns AutoThrow - toggle will work!")
                end
                if ownedGamepasses.AutoRebirth then
                    print("Player owns AutoRebirth - toggle will work!")
                end
            elseif data.autoRebirthToggle == nil and data.autoThrowToggle == nil then
                -- Legacy format: just gamepass ownership
                ownedGamepasses = {}
                for k, v in pairs(data) do
                    ownedGamepasses[k] = v
                end
                gamepassDataReceived = true
                updateSwitches()
                setSwitchesEnabled(true)
                
                print("Owned gamepasses updated (legacy format):")
                for k, v in pairs(ownedGamepasses) do
                    print("  " .. k .. " = " .. tostring(v))
                end
            end
        end
    end)
    
    -- Request current gamepass status
    gamepassCheckEvent:FireServer()

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasePlayer, gamepassId, wasPurchased)
        if purchasePlayer ~= player or not wasPurchased then return end

        local gamepassName = getGamepassNameFromId(gamepassId)
        if not gamepassName then return end

        ownedGamepasses[gamepassName] = true

        if gamepassName == "AutoRebirth" then
            autoRebirthEnabled = true
            gamepassCheckEvent:FireServer({autoRebirthToggle = true})
        elseif gamepassName == "AutoThrow" then
            autoThrowEnabled = true
            gamepassCheckEvent:FireServer({autoThrowToggle = true})
        else
            gamepassCheckEvent:FireServer()
        end

        gamepassDataReceived = true
        updateSwitches()
        setSwitchesEnabled(true)
    end)
    
    -- Fallback: Set initial state after a short delay if no response
    task.delay(2, function()
        if not gamepassDataReceived then
            -- No gamepass data received, assume player doesn't own any
            ownedGamepasses = {}
            gamepassDataReceived = true
            updateSwitches()
            setSwitchesEnabled(true)
            print("Fallback: No gamepass data, assuming none owned")
        end
    end)
else
    -- No gamepass system - make toggles always visible and functional
    ownedGamepasses = {AutoRebirth = true, AutoThrow = true}
    gamepassDataReceived = true
    updateSwitches()
    setSwitchesEnabled(true)
end

-- Set initial visual state immediately
updateSwitches()

print("AutoSwitchHandler loaded successfully!")
