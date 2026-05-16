-- Gamepass Handler Server Script
-- Handles gamepass ownership checks and effects

local Players = game:GetService("Players")
local GamePassService = game:GetService("GamePassService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataService = require(ReplicatedStorage.shared.Server.Services.DataService)

local networkFolder = ReplicatedStorage.shared:FindFirstChild("Network")
if not networkFolder then
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "Network"
    networkFolder.Parent = ReplicatedStorage.shared
end

-- Load gamepass configuration
local GamepassConfig = require(ReplicatedStorage:WaitForChild("GamepassConfig"))

-- Track which players own which gamepasses
local PlayerGamepasses = {}

-- Track toggle states for auto features (stored per player)
local PlayerAutoRebirthEnabled = {}
local PlayerAutoThrowEnabled = {}

-- Create remote events for gamepass communication
local gamepassCheckEvent = networkFolder:FindFirstChild("GamepassCheckEvent")
if not gamepassCheckEvent then
    gamepassCheckEvent = Instance.new("RemoteEvent")
    gamepassCheckEvent.Name = "GamepassCheckEvent"
    gamepassCheckEvent.Parent = networkFolder
end

local gamepassPurchaseEvent = networkFolder:FindFirstChild("GamepassPurchaseEvent")
if not gamepassPurchaseEvent then
    gamepassPurchaseEvent = Instance.new("RemoteEvent")
    gamepassPurchaseEvent.Name = "GamepassPurchaseEvent"
    gamepassPurchaseEvent.Parent = networkFolder
end

-- Function to load gamepass data from DataStore
local function loadGamepassData(player)
    local profileData = DataService.getData(player)
    if profileData then
        profileData.Gamepasses = profileData.Gamepasses or {}
        print("Loaded profile gamepass data for", player.Name)
        return profileData.Gamepasses
    end

    warn("[GamepassHandler] Profile data not loaded for " .. player.Name)
    return {}
end

-- Function to load toggle states from DataStore
local function loadToggleStates(player)
    local profileData = DataService.getData(player)
    if profileData then
        profileData.Settings = profileData.Settings or {}
        print("Loaded profile toggle states for", player.Name)
        return {
            autoRebirth = profileData.Settings.AutoRebirth == true,
            autoThrow = profileData.Settings.AutoThrow == true,
        }
    end

    warn("[GamepassHandler] Profile settings not loaded for " .. player.Name)
    return {autoRebirth = false, autoThrow = false}
end

-- Function to save gamepass data to profile
local function saveGamepassData(player)
    local profileData = DataService.getData(player)
    if profileData and PlayerGamepasses[player.UserId] then
        profileData.Gamepasses = PlayerGamepasses[player.UserId]
        print("Saved profile gamepass data for", player.Name)
    end
end

-- Function to save toggle states to profile
local function saveToggleStates(player)
    local profileData = DataService.getData(player)
    if profileData then
        profileData.Settings = profileData.Settings or {}
        profileData.Settings.AutoRebirth = PlayerAutoRebirthEnabled[player.UserId] == true
        profileData.Settings.AutoThrow = PlayerAutoThrowEnabled[player.UserId] == true
        print("Saved profile toggle states for", player.Name)
    end
end

local function sendGamepassState(player)
    gamepassCheckEvent:FireClient(player, {
        gamepasses = PlayerGamepasses[player.UserId] or {},
        autoRebirthEnabled = PlayerAutoRebirthEnabled[player.UserId] or false,
        autoThrowEnabled = PlayerAutoThrowEnabled[player.UserId] or false
    })
end

local function grantGamepass(player, gamepassName, enableAfterPurchase)
    if not PlayerGamepasses[player.UserId] then
        PlayerGamepasses[player.UserId] = {}
    end

    PlayerGamepasses[player.UserId][gamepassName] = true

    if enableAfterPurchase then
        if gamepassName == "AutoRebirth" then
            PlayerAutoRebirthEnabled[player.UserId] = true
        elseif gamepassName == "AutoThrow" then
            PlayerAutoThrowEnabled[player.UserId] = true
        end
    end

    saveGamepassData(player)
    saveToggleStates(player)
    sendGamepassState(player)
end

local function getRequestedToggleState(value)
    if value == true or value == "true" then
        return true
    end

    if value == false or value == "false" then
        return false
    end

    return nil
end

-- Function to check if a player owns a gamepass
local function playerOwnsGamepass(player, gamepassId)
    -- Check if player has purchased (from saved data or this session)
    if PlayerGamepasses[player.UserId] then
        for name, id in pairs(GamepassConfig.IDs) do
            if id == gamepassId and PlayerGamepasses[player.UserId][name] then
                return true
            end
        end
    end
    return false
end

-- Function to check all gamepasses for a player
local function checkAllGamepasses(player)
    -- If no data loaded yet, load from DataStore
    if not PlayerGamepasses[player.UserId] then
        PlayerGamepasses[player.UserId] = loadGamepassData(player)
    end
    return PlayerGamepasses[player.UserId]
end

-- Function to get money multiplier for a player (stacks with rebirths)
local function getMoneyMultiplier(player)
    local owned = PlayerGamepasses[player.UserId]
    if not owned then
        owned = checkAllGamepasses(player)
    end
    
    local multiplier = 1
    
    -- Apply 2x Money gamepass
    if owned.DoubleMoney then
        multiplier = multiplier * 2
    end
    
    return multiplier
end

-- Function to check if player has auto-rebirth
local function hasAutoRebirth(player)
    local owned = PlayerGamepasses[player.UserId]
    if not owned then
        owned = checkAllGamepasses(player)
    end
    return owned.AutoRebirth or false
end

-- Function to check if player has auto-throw
local function hasAutoThrow(player)
    local owned = PlayerGamepasses[player.UserId]
    if not owned then
        owned = checkAllGamepasses(player)
    end
    return owned.AutoThrow or false
end

-- Function to check if player has VIP
local function hasVIP(player)
    local owned = PlayerGamepasses[player.UserId]
    if not owned then
        owned = checkAllGamepasses(player)
    end
    return owned.VIP or false
end

-- Expose functions globally for other scripts to use
_G.GetMoneyMultiplier = getMoneyMultiplier
_G.HasAutoRebirth = hasAutoRebirth
_G.HasAutoThrow = hasAutoThrow
_G.HasVIP = hasVIP
_G.CheckAllGamepasses = checkAllGamepasses
_G.SetPlayerGamepassData = function(player, data)
    PlayerGamepasses[player.UserId] = data
end

-- Handle player joining
local function onPlayerAdded(player)
    -- Load saved gamepass data from DataStore
    PlayerGamepasses[player.UserId] = loadGamepassData(player)
    
    -- Load saved toggle states from DataStore
    local toggleStates = loadToggleStates(player)
    PlayerAutoRebirthEnabled[player.UserId] = toggleStates.autoRebirth or false
    PlayerAutoThrowEnabled[player.UserId] = toggleStates.autoThrow or false
    
    print(player.Name, "loaded toggle states - AutoRebirth:", PlayerAutoRebirthEnabled[player.UserId], "AutoThrow:", PlayerAutoThrowEnabled[player.UserId])
    
    -- CRITICAL: Check actual Roblox gamepass ownership and sync with DataStore
    -- This fixes the issue where gamepasses bought outside the game aren't detected
    local ownershipChanged = false
    for gamepassName, gamepassId in pairs(GamepassConfig.IDs) do
        local success, ownsGamepass = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
        end)
        
        if success and ownsGamepass then
            if not PlayerGamepasses[player.UserId][gamepassName] then
                PlayerGamepasses[player.UserId][gamepassName] = true
                ownershipChanged = true
                print(player.Name, "owns", gamepassName, "(synced from Roblox)")
            end
        end
    end
    
    -- Save updated ownership if any new gamepasses were detected
    if ownershipChanged then
        saveGamepassData(player)
    end
    
    -- Send gamepass ownership status AND toggle states to client
    print("Sending gamepass data to", player.Name)
    for k, v in pairs(PlayerGamepasses[player.UserId]) do
        print("  " .. k .. " = " .. tostring(v))
    end
    
    -- Send both gamepass ownership and toggle states
    sendGamepassState(player)
end

-- Handle player leaving
local function onPlayerRemoving(player)
    -- Save gamepass data before player leaves
    saveGamepassData(player)
    -- Save toggle states before player leaves
    saveToggleStates(player)
    PlayerGamepasses[player.UserId] = nil
    PlayerAutoRebirthEnabled[player.UserId] = nil
    PlayerAutoThrowEnabled[player.UserId] = nil
end

-- Handle gamepass check requests from client
gamepassCheckEvent.OnServerEvent:Connect(function(player, data)
    print("GamepassCheckEvent received from", player.Name, "data:", type(data))
    
    if type(data) == "table" then
        -- Handle toggle events
        if data.autoRebirthToggle ~= nil then
            local requestedState = getRequestedToggleState(data.autoRebirthToggle)
            if requestedState ~= nil then
                PlayerAutoRebirthEnabled[player.UserId] = requestedState and hasAutoRebirth(player) or false
                print(player.Name, "set autoRebirth to", requestedState, "stored:", PlayerAutoRebirthEnabled[player.UserId])
                sendGamepassState(player)
                task.spawn(function()
                    saveToggleStates(player)
                end)
            end
        end
        if data.autoThrowToggle ~= nil then
            local requestedState = getRequestedToggleState(data.autoThrowToggle)
            if requestedState ~= nil then
                PlayerAutoThrowEnabled[player.UserId] = requestedState and hasAutoThrow(player) or false
                print(player.Name, "set autoThrow to", requestedState, "stored:", PlayerAutoThrowEnabled[player.UserId])
                sendGamepassState(player)
                task.spawn(function()
                    saveToggleStates(player)
                end)
            end
        end
    else
        -- Regular gamepass check request - verify Roblox ownership and send current state
        if not PlayerGamepasses[player.UserId] then
            PlayerGamepasses[player.UserId] = loadGamepassData(player)
        end
        
        -- Re-check Roblox ownership in case player bought gamepass while in-game
        local ownershipChanged = false
        for gamepassName, gamepassId in pairs(GamepassConfig.IDs) do
            local success, ownsGamepass = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
            end)
            
            if success and ownsGamepass then
                if not PlayerGamepasses[player.UserId][gamepassName] then
                    PlayerGamepasses[player.UserId][gamepassName] = true
                    ownershipChanged = true
                    print(player.Name, "now owns", gamepassName, "(detected on recheck)")
                end
            end
        end
        
        if ownershipChanged then
            saveGamepassData(player)
        end
        
        print("Sending gamepass data to", player.Name, "(request)")
        -- Send both gamepass ownership and toggle states
        sendGamepassState(player)
    end
end)

-- Handle gamepass purchase prompts
gamepassPurchaseEvent.OnServerEvent:Connect(function(player, gamepassName)
    local gamepassId = GamepassConfig.IDs[gamepassName]
    if gamepassId then
        MarketplaceService:PromptGamePassPurchase(player, gamepassId)
    end
end)

-- Handle gamepass purchases. ProcessReceipt is for developer products, not gamepasses.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
    if not wasPurchased then return end

    for gamepassName, id in pairs(GamepassConfig.IDs) do
        if id == gamepassId then
            print(player.Name, "purchased gamepass:", gamepassName)
            grantGamepass(player, gamepassName, true)
            break
        end
    end
end)

-- Initialize existing players
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("GamepassHandler loaded successfully!")

-- Studio testing: Grant all gamepasses command
-- In Studio, type in console: _G.GrantAllGamepasses(player)
_G.GrantAllGamepasses = function(player)
    if not PlayerGamepasses[player.UserId] then
        PlayerGamepasses[player.UserId] = {}
    end
    for name, _ in pairs(GamepassConfig.IDs) do
        PlayerGamepasses[player.UserId][name] = true
    end
    saveGamepassData(player)
    sendGamepassState(player)
    print("Granted all gamepasses to", player.Name)
end

-- Grant specific gamepass: _G.GrantGamepass(player, "AutoThrow")
_G.GrantGamepass = function(player, gamepassName)
    grantGamepass(player, gamepassName, false)
    print("Granted", gamepassName, "to", player.Name)
end

-- AUTO-REBIRTH LOGIC
-- Check for auto-rebirth every 3 seconds
task.spawn(function()
    while true do
        task.wait(3)
        
        for _, player in ipairs(Players:GetPlayers()) do
            local ownsAutoRebirth = hasAutoRebirth(player)
            local toggleEnabled = PlayerAutoRebirthEnabled[player.UserId]
            
            print(player.Name, "AutoRebirth check - owns:", ownsAutoRebirth, "toggle:", toggleEnabled)
            
            if ownsAutoRebirth and toggleEnabled then
                local rebirths = _G.GetPlayerRebirths and _G.GetPlayerRebirths(player) or 0
                local money = _G.GetPlayerMoney and _G.GetPlayerMoney(player) or 0
                local rebirthCost = 10000 * (2 ^ rebirths)
                
                print(player.Name, "AutoRebirth - money:", money, "cost:", rebirthCost)
                
                -- Check if player can afford rebirth
                if money >= rebirthCost then
                    -- Trigger rebirth directly using the exposed function
                    if _G.DoRebirth then
                        print(player.Name, "auto-rebirth triggered! Money:", money, "Cost:", rebirthCost)
                        _G.DoRebirth(player)
                    end
                end
            end
        end
    end
end)

-- AUTO-THROW LOGIC
task.spawn(function()
    while true do
        task.wait(0.5) -- Check every 0.5 seconds for faster response
        
        for _, player in ipairs(Players:GetPlayers()) do
            local ownsAutoThrow = hasAutoThrow(player)
            local toggleEnabled = PlayerAutoThrowEnabled[player.UserId]
            
            -- Debug: Log auto-throw status
            if toggleEnabled then
                print(player.Name, "AutoThrow check - owns:", ownsAutoThrow, "toggle:", toggleEnabled)
            end
            
            if ownsAutoThrow and toggleEnabled then
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if humanoid and humanoid.Health > 0 and _G.TryThrowBrainrot then
                    _G.TryThrowBrainrot(player, 100)
                end
            end
        end
    end
end)
