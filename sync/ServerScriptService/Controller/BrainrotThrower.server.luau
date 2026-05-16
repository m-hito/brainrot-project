-- Server Script for Brainrot Throwing Game (Polished)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local DataService = require(ReplicatedStorage.shared.Server.Services.DataService)

local networkFolder = ReplicatedStorage.shared:FindFirstChild("Network")
if not networkFolder then
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "Network"
    networkFolder.Parent = ReplicatedStorage.shared
end

-- Create events
local events = {
    "ThrowBrainrotEvent",
    "DistanceEvent",
    "FollowBrainrotEvent",
    "NextBrainrotEvent",
    "UpgradePowerEvent",
    "RebirthEvent",
    "ShopDataEvent",
    "PlayAnimEvent",
    "PlaySoundEvent",
    "SetMovementEvent",
    "ThrowCountEvent"
}
for _, eventName in ipairs(events) do
    if not networkFolder:FindFirstChild(eventName) then
        Instance.new("RemoteEvent", networkFolder).Name = eventName
    end
end


local throwEvent = networkFolder:WaitForChild("ThrowBrainrotEvent")
local distanceEvent = networkFolder:WaitForChild("DistanceEvent")
local followEvent = networkFolder:WaitForChild("FollowBrainrotEvent")
local nextBrainrotEvent = networkFolder:WaitForChild("NextBrainrotEvent")

local upgradeEvent = networkFolder.UpgradePowerEvent
local rebirthEvent = networkFolder.RebirthEvent
local shopDataEvent = networkFolder.ShopDataEvent
local playAnimEvent = networkFolder.PlayAnimEvent
local playSoundEvent = networkFolder.PlaySoundEvent
local setMovementEvent = networkFolder.SetMovementEvent
local throwCountEvent = networkFolder.ThrowCountEvent

-- YeetZone reference
local yeetZone = Workspace:WaitForChild("YeetZone")

-- Track player data
local PlayerMoney = {}
local PlayerThrows = {}
local PlayerMaxDistance = {}
local PlayerTotalDistance = {} -- Track total distance accumulated
local PlayerRebirths = {}
local PlayerPower = {}
-- Removed PlayerMaxThrows - single throw only
local PlayerSelected = {}
local PlayerActiveThrows = {} -- Track active throws per player

-- Anti-autoclick tracking
local PlayerClickTimes = {} -- Track recent click times per player
local AUTOCLICK_THRESHOLD = 10 -- Number of clicks (increased from 5)
local AUTOCLICK_TIMEFRAME = 2 -- Seconds to check within
local AUTOCLICK_MIN_INTERVAL = 100 -- Minimum time between clicks (30ms - very fast clicks)

-- Check if player has AutoThrow gamepass
local function hasAutoThrowGamepass(player)
    if _G.HasAutoThrow then
        return _G.HasAutoThrow(player)
    end
    return false
end

-- Detect autoclicking
local function isAutoclicking(player)
    local clickTimes = PlayerClickTimes[player.UserId] or {}
    local now = tick()
    
    -- Remove old clicks outside timeframe
    local recentClicks = {}
    for _, clickTime in ipairs(clickTimes) do
        if now - clickTime <= AUTOCLICK_TIMEFRAME then
            table.insert(recentClicks, clickTime)
        end
    end
    
    -- Check for rapid clicking pattern
    if #recentClicks >= AUTOCLICK_THRESHOLD then
        return true, "Rapid clicking detected (" .. #recentClicks .. " clicks in " .. AUTOCLICK_TIMEFRAME .. "s)"
    end
    
    -- Check for impossibly fast clicks
    if #clickTimes >= 2 then
        local lastClick = clickTimes[#clickTimes]
        if now - lastClick < AUTOCLICK_MIN_INTERVAL then
            return true, "Impossibly fast click detected"
        end
    end
    
    return false
end

-- Record a click and check for autoclick
local function recordClickAndCheck(player)
    if not PlayerClickTimes[player.UserId] then
        PlayerClickTimes[player.UserId] = {}
    end
    
    table.insert(PlayerClickTimes[player.UserId], tick())
    
    -- Keep only last 20 clicks
    if #PlayerClickTimes[player.UserId] > 20 then
        table.remove(PlayerClickTimes[player.UserId], 1)
    end
    
    -- Check for autoclicking (skip if player has AutoThrow gamepass)
    if not hasAutoThrowGamepass(player) then
        local isAuto, reason = isAutoclicking(player)
        if isAuto then
            return true, reason
        end
    end
    
    return false
end

-- Expose functions for other scripts to access player data
_G.GetPlayerMoney = function(player)
    return PlayerMoney[player.UserId] or 0
end

_G.GetPlayerRebirths = function(player)
    return PlayerRebirths[player.UserId] or 0
end

_G.GetPlayerPower = function(player)
    return PlayerPower[player.UserId] or 0
end

-- Format number function
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

-- Calculate upgrade costs
local function getUpgradeCost(currentPower)
    return math.floor(100 * (1.5 ^ currentPower))
end

-- Removed getMaxThrowsCost - single throw only

-- Calculate power bonus from upgrades
local function getPowerBonus(powerLevel)
    return powerLevel * 2
end

-- Calculate rebirth multiplier
local function getRebirthMultiplier(rebirths)
    -- Rebirth multipliers: 1=1.5x, 2=2x, 3=2.5x, etc.
    return 1 + (rebirths * 0.5)
end

-- Calculate total money multiplier (rebirth + gamepass)
local function getTotalMoneyMultiplier(player, rebirths)
    local rebirthMultiplier = getRebirthMultiplier(rebirths)
    local gamepassMultiplier = _G.GetMoneyMultiplier and _G.GetMoneyMultiplier(player) or 1
    return rebirthMultiplier * gamepassMultiplier
end

-- Update leaderboard
local function updateLeaderboard(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

	local stats = {
		{Name = "Money", Value = "$" .. formatNumber(PlayerMoney[player.UserId] or 0), Class = "StringValue"},
		{Name = "Throws", Value = PlayerThrows[player.UserId] or 0, Class = "IntValue"},
		{Name = "Max Distance", Value = PlayerMaxDistance[player.UserId] or 0, Class = "IntValue"},
		{Name = "Rebirths", Value = PlayerRebirths[player.UserId] or 0, Class = "IntValue"},
		{Name = "Power", Value = PlayerPower[player.UserId] or 0, Class = "IntValue"},
		
	}

    for _, stat in ipairs(stats) do
        local statObj = leaderstats:FindFirstChild(stat.Name)
        if not statObj then
            statObj = Instance.new(stat.Class)
            statObj.Name = stat.Name
            statObj.Parent = leaderstats
        end
        statObj.Value = stat.Value
    end
end

-- Load/Save player data
local function loadPlayerData(player)
    local profileData = DataService.getData(player)
    if not profileData then
        warn("[BrainrotThrower] Profile data not loaded for " .. player.Name)
        return false
    end

    PlayerMoney[player.UserId] = profileData.Money or 0
    PlayerThrows[player.UserId] = profileData.Throws or 0
    PlayerMaxDistance[player.UserId] = profileData.MaxDistance or 0
    PlayerTotalDistance[player.UserId] = profileData.TotalDistance or 0
    PlayerRebirths[player.UserId] = profileData.Rebirths or 0
    PlayerPower[player.UserId] = profileData.Power or 0
    
    PlayerActiveThrows[player.UserId] = 0
    return true
end

local function savePlayerData(player)
    local profileData = DataService.getData(player)
    if not profileData then return false end

    profileData.Money = PlayerMoney[player.UserId] or 0
    profileData.Throws = PlayerThrows[player.UserId] or 0
    profileData.MaxDistance = PlayerMaxDistance[player.UserId] or 0
    profileData.TotalDistance = PlayerTotalDistance[player.UserId] or 0
    profileData.Rebirths = PlayerRebirths[player.UserId] or 0
    profileData.Power = PlayerPower[player.UserId] or 0
    return true
end

local brainrotsFolder = ReplicatedStorage.Resources.Models:WaitForChild("Brainrots")

-- Rarity tiers
local RARITY_TIERS = {
    Mythic = { chance = 1, multiplier = 10, color = Color3.fromRGB(255, 50, 50), folder = "Mythic" },
    Legendary = { chance = 4, multiplier = 5, color = Color3.fromRGB(255, 215, 0), folder = "Legendary" },
    Epic = { chance = 10, multiplier = 3, color = Color3.fromRGB(180, 50, 255), folder = "Epic" },
    Rare = { chance = 15, multiplier = 2, color = Color3.fromRGB(50, 150, 255), folder = "Rare" },
    Uncommon = { chance = 25, multiplier = 1.5, color = Color3.fromRGB(50, 200, 50), folder = "Uncommon" },
    Common = { chance = 45, multiplier = 1, color = Color3.fromRGB(255, 255, 255), folder = "Common" }
}

local RARITY_ORDER = {"Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"}

-- Build brainrot lists
local allBrainrots = {}
local brainrotRarities = {}

for tierName, tier in pairs(RARITY_TIERS) do
    local folder = brainrotsFolder:FindFirstChild(tier.folder)
    if folder then
        tier.names = {}
        for _, item in ipairs(folder:GetChildren()) do
            if item:IsA("Model") then
                table.insert(tier.names, item.Name)
                brainrotRarities[item.Name] = {
                    rarity = tierName,
                    multiplier = tier.multiplier,
                    color = tier.color,
                    model = item
                }
                table.insert(allBrainrots, item)
            end
        end
    end
end

local function getRandomBrainrot()
    local roll = math.random(1, 100)
    local cumulative = 0

    for _, tierName in ipairs(RARITY_ORDER) do
        local tier = RARITY_TIERS[tierName]
        cumulative = cumulative + tier.chance
        if roll <= cumulative then
            local list = tier.names
            if list and #list > 0 then
                local name = list[math.random(1, #list)]
                local info = brainrotRarities[name]
                if info and info.model then
                    return info.model, name, tierName, tier.multiplier, tier.color
                end
            end
        end
    end

    if #allBrainrots > 0 then
        local fallback = allBrainrots[math.random(1, #allBrainrots)]
        local info = brainrotRarities[fallback.Name]
        if info then
            return fallback, fallback.Name, info.rarity, info.multiplier, info.color
        end
    end
    
    return nil, nil, "Common", 1, Color3.new(1, 1, 1)
end

local function selectNextBrainrotForPlayer(player)
    local brainrotModel, brainrotName, rarityName, rarityMultiplier, rarityColor = getRandomBrainrot()
    if not brainrotModel then return end
    PlayerSelected[player.UserId] = {
        name = brainrotName,
        rarityName = rarityName,
        multiplier = rarityMultiplier,
        color = rarityColor
    }
    nextBrainrotEvent:FireClient(player, brainrotName, rarityName, rarityColor, rarityMultiplier)
end

-- Send shop data to player
local function sendShopData(player)
    local currentPower = PlayerPower[player.UserId] or 0
    local currentMoney = PlayerMoney[player.UserId] or 0
    local upgradeCost = getUpgradeCost(currentPower)
    local canUpgrade = currentPower < 100 and currentMoney >= upgradeCost
    local rebirths = PlayerRebirths[player.UserId] or 0
    local totalThrows = PlayerThrows[player.UserId] or 0
    local maxDistance = PlayerMaxDistance[player.UserId] or 0
    local totalDistance = PlayerTotalDistance[player.UserId] or 0
    
    shopDataEvent:FireClient(player, currentPower, upgradeCost, currentMoney, canUpgrade, rebirths, totalThrows, maxDistance, totalDistance)
end

_G.AddPlayerPower = function(player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    if PlayerPower[player.UserId] == nil then
        if not loadPlayerData(player) then return false end
    end

    local currentPower = PlayerPower[player.UserId] or 0
    if currentPower >= 100 then return false end

    PlayerPower[player.UserId] = math.min(100, currentPower + amount)
    savePlayerData(player)
    updateLeaderboard(player)
    sendShopData(player)
    return true, PlayerPower[player.UserId]
end

local function initPlayer(player)
    if not loadPlayerData(player) then return end
    distanceEvent:FireClient(player, 0, nil, nil, nil, PlayerMoney[player.UserId] or 0, true)
    updateLeaderboard(player)
    selectNextBrainrotForPlayer(player)
    sendShopData(player)
    throwCountEvent:FireClient(player, PlayerActiveThrows[player.UserId] or 0, 1)
end

for _, player in ipairs(Players:GetPlayers()) do
    initPlayer(player)
end

Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    PlayerSelected[player.UserId] = nil
    PlayerMoney[player.UserId] = nil
    PlayerThrows[player.UserId] = nil
    PlayerMaxDistance[player.UserId] = nil
    PlayerTotalDistance[player.UserId] = nil
    PlayerRebirths[player.UserId] = nil
    PlayerPower[player.UserId] = nil
    -- Removed PlayerMaxThrows cleanup
    PlayerActiveThrows[player.UserId] = nil
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        savePlayerData(player)
    end
end)

task.spawn(function()
    while true do
        task.wait(60)
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayerData(player)
        end
    end
end)

-- Check if player is in YeetZone
local function isInYeetZone(character)
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local pos = hrp.Position
    local zonePos = yeetZone.Position
    local zoneSize = yeetZone.Size
    
    local halfSize = zoneSize / 2
    return pos.X >= zonePos.X - halfSize.X and pos.X <= zonePos.X + halfSize.X
       and pos.Z >= zonePos.Z - halfSize.Z and pos.Z <= zonePos.Z + halfSize.Z
end

-- Check if player is facing south (positive X direction in this world)
local function isFacingNorth(character)
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local lookVector = hrp.CFrame.LookVector
    -- South is positive X direction, check if looking mostly south (within 45 degrees)
    return lookVector.X > 0.7
end

-- Check if there are any brainrots on the track
local function hasBrainrotsOnTrack()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:find("Throw_") then
            return true
        end
    end
    return false
end

-- Handle power upgrade
upgradeEvent.OnServerEvent:Connect(function(player, upgradeType)
    local currentMoney = PlayerMoney[player.UserId] or 0
    
    if upgradeType == "power" then
        local currentPower = PlayerPower[player.UserId] or 0
        local upgradeCost = getUpgradeCost(currentPower)
        
        if currentPower < 100 and currentMoney >= upgradeCost then
            PlayerMoney[player.UserId] = currentMoney - upgradeCost
            PlayerPower[player.UserId] = currentPower + 1
            savePlayerData(player)
            updateLeaderboard(player)
            sendShopData(player)
        end
    end
end)

-- Handle rebirth
local function doRebirth(player)
    local currentRebirths = PlayerRebirths[player.UserId] or 0
    local currentMoney = PlayerMoney[player.UserId] or 0
    local rebirthCost = 10000 * (2 ^ currentRebirths)
    
    if currentMoney >= rebirthCost then
        PlayerRebirths[player.UserId] = currentRebirths + 1
        PlayerMoney[player.UserId] = 0
        PlayerPower[player.UserId] = 0
        savePlayerData(player)
        -- Don't reset throws, max distance, or total distance - keep them for stats
        updateLeaderboard(player)
        sendShopData(player)
        throwCountEvent:FireClient(player, 0, 1)
        return true
    end
    return false
end

-- Expose rebirth function for auto-rebirth
_G.DoRebirth = doRebirth

rebirthEvent.OnServerEvent:Connect(function(player)
    doRebirth(player)
end)

-- Handle shop data request
shopDataEvent.OnServerEvent:Connect(function(player)
    sendShopData(player)
end)

-- Function to throw a brainrot
local function throwBrainrot(player, power)
    power = power or 50

    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local selected = PlayerSelected[player.UserId]
    if not selected then
        selectNextBrainrotForPlayer(player)
        selected = PlayerSelected[player.UserId]
        if not selected then return end
    end

    -- Find brainrot model
    local brainrotModel = nil
    local info = brainrotRarities[selected.name]
    if info and info.model then
        brainrotModel = info.model
    else
        for _, tier in pairs(RARITY_TIERS) do
            local folder = brainrotsFolder:FindFirstChild(tier.folder)
            if folder then
                brainrotModel = folder:FindFirstChild(selected.name)
                if brainrotModel then break end
            end
        end
    end
    if not brainrotModel then return end

    local brainrotName = selected.name
    local rarityName = selected.rarityName
    local rarityMultiplier = selected.multiplier
    local rarityColor = selected.color
    local displayName = brainrotName:gsub("_", " ")

    -- Animation and sound are now played immediately when throw event is received

    local throwId = "Throw_" .. player.UserId .. "_" .. tostring(math.random(1, 999999))

    local clone = brainrotModel:Clone()
    clone.Name = throwId
    clone.Parent = workspace

    -- Remove VFX
    local toDestroy = {}
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("BasePart") then
            if descendant.Name == "VfxInstance" or descendant.Name:find("Vfx") then
                table.insert(toDestroy, descendant)
            end
        elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") or descendant:IsA("PointLight") then
            table.insert(toDestroy, descendant)
        end
    end
    for _, obj in ipairs(toDestroy) do
        if obj.Parent then obj:Destroy() end
    end

    task.wait()

    local allParts = {}
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(allParts, descendant)
        end
    end

    local rootPart = clone:FindFirstChild("RootPart") or clone:FindFirstChild("FakeRootPart")
    if not rootPart and #allParts > 0 then
        local largestPart = nil
        local largestSize = 0
        for _, part in ipairs(allParts) do
            local size = part.Size.X * part.Size.Y * part.Size.Z
            if size > largestSize then
                largestSize = size
                largestPart = part
            end
        end
        rootPart = largestPart
    end

    if not rootPart then
        rootPart = Instance.new("Part")
        rootPart.Name = "RootPart"
        rootPart.Size = Vector3.new(2, 2, 2)
        rootPart.Transparency = 1
        rootPart.CanCollide = false
        rootPart.Massless = true
        rootPart.Parent = clone
        table.insert(allParts, rootPart)
    end

    clone.PrimaryPart = rootPart

    for _, part in ipairs(allParts) do
        part.Anchored = false
        part.CanCollide = true
        part.Massless = true
        part.CollisionGroup = "Brainrots"
    end

    for _, part in ipairs(allParts) do
        if part ~= rootPart and part.Parent then
            for _, joint in ipairs(part:GetChildren()) do
                if joint:IsA("WeldConstraint") or joint:IsA("Weld") or joint:IsA("Motor6D") or joint:IsA("ManualWeld") then
                    joint:Destroy()
                end
            end
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = rootPart
            weld.Part1 = part
            weld.Parent = rootPart
        end
    end

    clone:ScaleTo(0.65)

    local throwPosition = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
    clone:PivotTo(CFrame.new(throwPosition))

    -- Follow the brainrot
    followEvent:FireClient(player, throwId)

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "NameTag"
    billboardGui.Size = UDim2.new(0, 300, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 5, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = clone.PrimaryPart or rootPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = rarityColor or Color3.new(1, 1, 1)
    nameLabel.Text = displayName
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.Parent = billboardGui

    -- Apply power bonus
    local powerBonus = getPowerBonus(PlayerPower[player.UserId] or 0)
    local adjustedPower = math.min(power + powerBonus, 100)

    -- Smoother throw physics
    local baseSpeed = 50
    local maxSpeed = 150
    local throwSpeed = baseSpeed + (adjustedPower / 100) * (maxSpeed - baseSpeed)
    local throwHeight = 30 + (adjustedPower / 100) * 40

    if rootPart then
        local throwDirection = humanoidRootPart.CFrame.LookVector
        -- Apply velocity more smoothly with gradual ramp-up
        local horizontalVelocity = throwDirection * throwSpeed
        local verticalVelocity = Vector3.new(0, throwHeight, 0)
        rootPart.AssemblyLinearVelocity = horizontalVelocity + verticalVelocity
        -- Gentler spin for smoother flight
        rootPart.AssemblyAngularVelocity = Vector3.new(math.random(-2, 2), math.random(-3, 3), math.random(-2, 2))
    end

    local startPos = clone:GetPivot().Position
    local maxDistance = 0
    local tracking = true
    local stoppedTime = 0
    local velocityThreshold = 0.5
    local barrierLineX = 76.75
    local slowSpeedThreshold = 15
    local maxThrows = 1

    task.spawn(function()
        while tracking and clone and clone.Parent do
            local currentPos = clone:GetPivot().Position
            local distance = math.floor((currentPos - startPos).Magnitude)
            local velocity = rootPart and rootPart.AssemblyLinearVelocity.Magnitude or 0

            local atBarrier = currentPos.X >= barrierLineX
            local isSlow = velocity < slowSpeedThreshold

            if atBarrier and isSlow then
                local rebirths = PlayerRebirths[player.UserId] or 0
                local totalMultiplier = getTotalMoneyMultiplier(player, rebirths)
                local earnedMoney = math.floor(maxDistance * rarityMultiplier * totalMultiplier)

                PlayerMoney[player.UserId] = PlayerMoney[player.UserId] + earnedMoney
                PlayerThrows[player.UserId] = PlayerThrows[player.UserId] + 1
                PlayerTotalDistance[player.UserId] = (PlayerTotalDistance[player.UserId] or 0) + maxDistance
                
                if maxDistance > (PlayerMaxDistance[player.UserId] or 0) then
                    PlayerMaxDistance[player.UserId] = maxDistance
                end
                
                savePlayerData(player)
                updateLeaderboard(player)
                sendShopData(player)

                -- Play completion sound
                playSoundEvent:FireClient(player, "ThrowComplete")

                distanceEvent:FireClient(player, maxDistance, displayName, rarityName, rarityColor, PlayerMoney[player.UserId], true)
                tracking = false

                -- Decrement active throws
                PlayerActiveThrows[player.UserId] = math.max(0, (PlayerActiveThrows[player.UserId] or 1) - 1)
                throwCountEvent:FireClient(player, PlayerActiveThrows[player.UserId], maxThrows)

                -- Re-enable movement if no more active throws
                if PlayerActiveThrows[player.UserId] == 0 then
                    setMovementEvent:FireClient(player, true)
                    if humanoid then humanoid.WalkSpeed = 16 end
                end

                if clone and clone.Parent then clone:Destroy() end
                selectNextBrainrotForPlayer(player)
                break
            end

            if velocity < velocityThreshold then
                stoppedTime = stoppedTime + 0.1
                if stoppedTime > 1 then
                    local rebirths = PlayerRebirths[player.UserId] or 0
                    local totalMultiplier = getTotalMoneyMultiplier(player, rebirths)
                    local earnedMoney = math.floor(maxDistance * rarityMultiplier * totalMultiplier)

                    PlayerMoney[player.UserId] = PlayerMoney[player.UserId] + earnedMoney
                    PlayerThrows[player.UserId] = PlayerThrows[player.UserId] + 1
                    PlayerTotalDistance[player.UserId] = (PlayerTotalDistance[player.UserId] or 0) + maxDistance
                    
                    if maxDistance > (PlayerMaxDistance[player.UserId] or 0) then
                        PlayerMaxDistance[player.UserId] = maxDistance
                    end
                    
                    savePlayerData(player)
                    updateLeaderboard(player)
                    sendShopData(player)

                    playSoundEvent:FireClient(player, "ThrowComplete")

                    distanceEvent:FireClient(player, maxDistance, displayName, rarityName, rarityColor, PlayerMoney[player.UserId], true)
                    tracking = false

                    PlayerActiveThrows[player.UserId] = math.max(0, (PlayerActiveThrows[player.UserId] or 1) - 1)
                    throwCountEvent:FireClient(player, PlayerActiveThrows[player.UserId], maxThrows)

                    if PlayerActiveThrows[player.UserId] == 0 then
                        setMovementEvent:FireClient(player, true)
                        if humanoid then humanoid.WalkSpeed = 16 end
                    end

                    if clone and clone.Parent then clone:Destroy() end
                    selectNextBrainrotForPlayer(player)
                    break
                end
            else
                stoppedTime = 0
            end

            if distance > maxDistance then
                maxDistance = distance
                local currentThrowMoney = math.floor(distance * rarityMultiplier)
                local totalMoney = PlayerMoney[player.UserId] + currentThrowMoney
                distanceEvent:FireClient(player, maxDistance, displayName, rarityName, rarityColor, totalMoney, false)
            end

            task.wait(0.1)
        end
    end)

    task.delay(30, function()
        tracking = false
        if clone and clone.Parent then
            clone:Destroy()
        end
        PlayerActiveThrows[player.UserId] = math.max(0, (PlayerActiveThrows[player.UserId] or 1) - 1)
        throwCountEvent:FireClient(player, PlayerActiveThrows[player.UserId], maxThrows)
        if PlayerActiveThrows[player.UserId] == 0 then
            setMovementEvent:FireClient(player, true)
            if humanoid then humanoid.WalkSpeed = 16 end
        end
    end)
end

local function tryStartThrow(player, power)
    power = power or 50

    -- Anti-autoclick check
    --local isAuto, reason = recordClickAndCheck(player)
    --if isAuto then
    --    warn("[AntiCheat] " .. player.Name .. " kicked for autoclick: " .. reason)
    --    player:Kick("Kicked for autoclick/exploit detection. Purchase AutoThrow gamepass for automatic throwing.")
    --    return
    --end

    -- Check if already throwing FIRST (before any other processing)
    local activeThrows = PlayerActiveThrows[player.UserId] or 0
    if activeThrows >= 1 then return false end

    -- Check if there are any brainrots on the track
    if hasBrainrotsOnTrack() then return false end

    local character = player.Character
    if not character then return false end

    if not isInYeetZone(character) then return false end
    
    -- Must be facing north to throw
    if not isFacingNorth(character) then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    -- Set active throw IMMEDIATELY to prevent rapid clicks
    PlayerActiveThrows[player.UserId] = 1
    throwCountEvent:FireClient(player, 1, 1)

    -- Play sound IMMEDIATELY when throw starts
    playSoundEvent:FireClient(player, "Throw")
    playAnimEvent:FireClient(player, "Throw")

    -- Disable movement
    setMovementEvent:FireClient(player, false)
    humanoid.WalkSpeed = 0

    -- Throw the brainrot
    throwBrainrot(player, power)
    return true
end

_G.TryThrowBrainrot = tryStartThrow

throwEvent.OnServerEvent:Connect(function(player, power)
    tryStartThrow(player, power)
end)

-- Player collision group
local function setPlayerCollisionGroup(player)
    player.CharacterAdded:Connect(function(character)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = "Players"
            end
        end
        
        -- Sync throw count when player respawns
        throwCountEvent:FireClient(player, PlayerActiveThrows[player.UserId] or 0, 1)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    setPlayerCollisionGroup(player)
end

Players.PlayerAdded:Connect(setPlayerCollisionGroup)
