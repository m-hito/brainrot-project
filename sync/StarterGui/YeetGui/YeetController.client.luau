-- Client Script for Brainrot Throwing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local networkFolder = ReplicatedStorage:WaitForChild("Network")

local throwEvent = networkFolder:WaitForChild("ThrowBrainrotEvent")
local distanceEvent = networkFolder:WaitForChild("DistanceEvent")
local followEvent = networkFolder:WaitForChild("FollowBrainrotEvent")
local nextBrainrotEvent = networkFolder:WaitForChild("NextBrainrotEvent")
local playAnimEvent = networkFolder:WaitForChild("PlayAnimEvent")
local playSoundEvent = networkFolder:WaitForChild("PlaySoundEvent")
local throwCountEvent = networkFolder:WaitForChild("ThrowCountEvent")
local shopDataEvent = networkFolder:WaitForChild("ShopDataEvent")

-- UI Elements
local screenGui = script.Parent
local distanceFrame = screenGui:FindFirstChild("DistanceFrame")
local distanceLabel = distanceFrame and distanceFrame:FindFirstChild("DistanceLabel")
local moneyFrame = screenGui:FindFirstChild("MoneyFrame")
local moneyLabel = moneyFrame and moneyFrame:FindFirstChild("MoneyLabel")

-- State
local currentBrainrot = nil
local currentRarity = nil
local currentColor = nil
local currentMultiplier = 1
local followingBrainrot = nil
local originalCameraSubject = nil
local camera = Workspace.CurrentCamera
local currentMoney = 0
local activeThrows = 0
local maxThrows = 1
local humanoid = nil

-- Animation
local throwAnimation = nil
local animationTrack = nil

-- YeetZone reference
local yeetZone = Workspace:WaitForChild("YeetZone")

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

-- Update money display (just update the text, no scaling)
local function updateMoneyDisplay(money)
    if not moneyLabel then return end
    currentMoney = money
    moneyLabel.Text = "$" .. formatNumber(money)
    -- Ensure money label is at original size
end

-- Play throw animation
local function playThrowAnimation()
    if not character then return end
    
    humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    
    -- Load and play throw animation
    local throwAnim = ReplicatedStorage:FindFirstChild("ThrowAnimation")
    if throwAnim then
        if animationTrack then
            animationTrack:Stop()
        end
        animationTrack = animator:LoadAnimation(throwAnim)
        animationTrack:Play()
    end
end

-- Play sound
local function playSound(soundName)
    local sfxFolder = SoundService:FindFirstChild("SFX")
    if not sfxFolder then return end
    
    local sound = sfxFolder:FindFirstChild(soundName)
    if sound then
        -- Create a local sound for the player
        local localSound = sound:Clone()
        localSound.Parent = SoundService
        localSound.PlayOnRemove = false
        localSound:Play()
        
        -- Destroy after playing
        task.delay(localSound.TimeLength + 0.1, function()
            if localSound and localSound.Parent then
                localSound:Destroy()
            end
        end)
    end
end

-- Handle animation event
playAnimEvent.OnClientEvent:Connect(function(animName)
    if animName == "Throw" then
        playThrowAnimation()
    end
end)

-- Handle sound event
playSoundEvent.OnClientEvent:Connect(function(soundName)
    playSound(soundName)
end)

-- Handle throw count event
throwCountEvent.OnClientEvent:Connect(function(active, max)
    activeThrows = active
    maxThrows = max
end)

-- Handle shop data event to update money display after rebirth
shopDataEvent.OnClientEvent:Connect(function(currentPower, upgradeCost, currentMoney, canUpgrade, rebirths, totalThrows, maxDistance, totalDistance)
    -- Update money display when data is received (important after rebirth)
    updateMoneyDisplay(currentMoney)
end)

-- Check if player is in YeetZone
local function isInYeetZone()
    local character = player.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local pos = hrp.Position
    local zonePos = yeetZone.Position
    local zoneSize = yeetZone.Size
    
    -- Check if player is within the zone bounds
    local halfSize = zoneSize / 2
    local inX = pos.X >= zonePos.X - halfSize.X and pos.X <= zonePos.X + halfSize.X
    local inZ = pos.Z >= zonePos.Z - halfSize.Z and pos.Z <= zonePos.Z + halfSize.Z
    
    return inX and inZ
end

-- Check if player is facing south (positive X direction in this world)
local function isFacingNorth()
    local character = player.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local lookVector = hrp.CFrame.LookVector
    -- South is positive X direction, check if looking mostly south (within 45 degrees)
    return lookVector.X > 0.7
end

-- Handle next brainrot event
nextBrainrotEvent.OnClientEvent:Connect(function(brainrotName, rarityName, rarityColor, multiplier)
    currentBrainrot = brainrotName
    currentRarity = rarityName
    currentColor = rarityColor
    currentMultiplier = multiplier
end)

-- Handle distance event
distanceEvent.OnClientEvent:Connect(function(distance, brainrotName, rarityName, rarityColor, totalMoney, finished)
    if distanceLabel then
        if finished then
            distanceLabel.Text = "Final Distance: " .. distance .. "m"
            -- Reset camera to player when finished
            if originalCameraSubject then
                camera.CameraSubject = originalCameraSubject
            end
            followingBrainrot = nil
        else
            distanceLabel.Text = "Distance: " .. distance .. "m"
        end
    end
    
    -- Update money with scaling animation
    updateMoneyDisplay(totalMoney, finished)
end)

-- Handle follow event - camera follows brainrot
followEvent.OnClientEvent:Connect(function(throwId)
    -- Wait for the brainrot to be replicated
    local brainrot = nil
    for i = 1, 20 do
        brainrot = Workspace:FindFirstChild(throwId)
        if brainrot then
            -- Try to find PrimaryPart or any part
            local primaryPart = brainrot.PrimaryPart or brainrot:FindFirstChild("RootPart") or brainrot:FindFirstChild("FakeRootPart")
            if primaryPart then
                break
            end
            -- Check for any BasePart in the model
            for _, part in ipairs(brainrot:GetDescendants()) do
                if part:IsA("BasePart") then
                    break
                end
            end
        end
        task.wait(0.05)
    end
    
    if brainrot then
        followingBrainrot = throwId
        
        -- Save original camera subject
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            originalCameraSubject = humanoid
        end
    end
end)

-- Camera following loop
RunService.RenderStepped:Connect(function()
    if followingBrainrot then
        local brainrot = Workspace:FindFirstChild(followingBrainrot)
        if brainrot then
            -- Try to find PrimaryPart or wait for it
            local primaryPart = brainrot.PrimaryPart or brainrot:FindFirstChild("RootPart") or brainrot:FindFirstChild("FakeRootPart")
            if primaryPart and primaryPart.Parent then
                camera.CameraSubject = primaryPart
            else
                -- Look for any part in the model
                for _, part in ipairs(brainrot:GetDescendants()) do
                    if part:IsA("BasePart") and part.Parent then
                        camera.CameraSubject = part
                        break
                    end
                end
            end
        else
            -- Brainrot destroyed, reset camera
            if originalCameraSubject then
                camera.CameraSubject = originalCameraSubject
            end
            followingBrainrot = nil
        end
    end
end)

-- Throw instantly (no charging)
local function throwBrainrot()
    -- Only allow throwing if in YeetZone
    if not isInYeetZone() then
        return
    end
    
    -- Must be facing north to throw
    if not isFacingNorth() then
        return
    end
    
    -- Check if can throw (not at max throws)
    if activeThrows >= maxThrows then
        return
    end
    
    -- Throw with full power instantly
    throwEvent:FireServer(100)
end

-- Input handling - instant throw on click
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.E then
        throwBrainrot()
    end
end)

-- Character respawn handling
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    followingBrainrot = nil
    originalCameraSubject = nil
    -- Don't reset activeThrows here - server is authoritative
    
    -- Get humanoid for animations
    humanoid = character:WaitForChild("Humanoid")
end)

-- Initial setup
humanoid = character:FindFirstChildOfClass("Humanoid")

print("YeetController loaded!")
