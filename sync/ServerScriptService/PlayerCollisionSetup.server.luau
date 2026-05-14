local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

-- Set up collision groups on game start
pcall(function()
    PhysicsService:RegisterCollisionGroup("Players")
    PhysicsService:RegisterCollisionGroup("Brainrots")
    PhysicsService:RegisterCollisionGroup("Barrier")
end)

-- Set collision rules
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Players", "Barrier", true)  -- Players collide with barrier!
PhysicsService:CollisionGroupSetCollidable("Brainrots", "Barrier", false)  -- Brainrots go through barrier!
PhysicsService:CollisionGroupSetCollidable("Brainrots", "Players", false)  -- Don't hit players
PhysicsService:CollisionGroupSetCollidable("Players", "Default", true)  -- Players collide with default (YeetZone)

-- Set barrier to Barrier collision group
for _, barrier in ipairs(workspace:GetChildren()) do
    if barrier.Name == "Barrier" and barrier:IsA("BasePart") then
        barrier.CollisionGroup = "Barrier"
    end
end

-- Set player collision group when they join
local function setPlayerCollisionGroup(character)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Players"
        end
    end
    
    -- Also handle parts added later (like tools, accessories)
    character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            descendant.CollisionGroup = "Players"
        end
    end)
end

-- Handle existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        setPlayerCollisionGroup(player.Character)
    end
    player.CharacterAdded:Connect(setPlayerCollisionGroup)
end

-- Handle new players
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(setPlayerCollisionGroup)
end)
