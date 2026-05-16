local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local createSignal = require(ReplicatedStorage.shared.Package.Signal)
local Trove = require(ReplicatedStorage.shared.Package.Trove)

local PowerService = {}
PowerService.PowerCollected = createSignal()

local powerTemplate = ReplicatedStorage:WaitForChild("Resources")
	:WaitForChild("Models")
	:WaitForChild("Power")

local pickupFolder = Workspace:FindFirstChild("PowerPickups")
if not pickupFolder then
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "PowerPickups"
	pickupFolder.Parent = Workspace
end

local AREAS = {
	Common = {
		Names = {"CommonPowerArea", "PowerCommonArea", "CommonArea", "Common Area", "Baseplate", "SpawnLocation"},
		FallbackCFrame = CFrame.new(0, 5, 0),
		FallbackSize = Vector3.new(90, 1, 90),
		MaxPickups = 6,
		RespawnTime = 28,
		PowerAmount = 1,
	},
	VIP = {
		Names = {"VIPPowerArea", "VipPowerArea", "PowerVipArea", "VIP Area", "Vip Area", "VIP", "Vip"},
		FallbackCFrame = CFrame.new(120, 5, 0),
		FallbackSize = Vector3.new(180, 1, 180),
		MaxPickups = 14,
		RespawnTime = 14,
		PowerAmount = 2,
	},
}

local activePickups = {
	Common = 0,
	VIP = 0,
}

local function getParts(container)
	local parts = {}

	if container:IsA("BasePart") then
		table.insert(parts, container)
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function getBounds(container, fallbackCFrame, fallbackSize)
	if not container then
		return fallbackCFrame, fallbackSize
	end

	if container:IsA("BasePart") then
		return container.CFrame, container.Size
	end

	if container:IsA("Model") then
		local cframe, size = container:GetBoundingBox()
		return cframe, size
	end

	local parts = getParts(container)
	if #parts == 0 then
		return fallbackCFrame, fallbackSize
	end

	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		local half = part.Size / 2
		local low = part.Position - half
		local high = part.Position + half
		min = Vector3.new(math.min(min.X, low.X), math.min(min.Y, low.Y), math.min(min.Z, low.Z))
		max = Vector3.new(math.max(max.X, high.X), math.max(max.Y, high.Y), math.max(max.Z, high.Z))
	end

	local center = (min + max) / 2
	local size = max - min
	return CFrame.new(center), size
end

local function findArea(names)
	for _, name in ipairs(names) do
		local instance = Workspace:FindFirstChild(name, true)
		if instance then
			return instance
		end
	end

	return nil
end

local function getRandomSpawn(areaConfig)
	local area = findArea(areaConfig.Names)
	local cframe, size = getBounds(area, areaConfig.FallbackCFrame, areaConfig.FallbackSize)
	local x = (math.random() - 0.5) * size.X
	local z = (math.random() - 0.5) * size.Z
	local y = math.max(size.Y / 2, 0) + 3
	return cframe * CFrame.new(x, y, z)
end

local function preparePickup(instance)
	local parts = getParts(instance)
	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = true
	end
	return parts
end

local function spawnPickup(areaName)
	local areaConfig = AREAS[areaName]
	if not areaConfig then return end
	if activePickups[areaName] >= areaConfig.MaxPickups then return end

	activePickups[areaName] += 1

	local pickupTrove = Trove.new()
	local pickup = pickupTrove:Clone(powerTemplate)
	pickup.Name = areaName .. "Power"
	pickup.Parent = pickupFolder

	local parts = preparePickup(pickup)
	if #parts == 0 then
		warn("[PowerService] Power model has no BaseParts")
		pickupTrove:Destroy()
		activePickups[areaName] -= 1
		return
	end

	pickup:PivotTo(getRandomSpawn(areaConfig))

	local collected = false
	local function cleanupAndRespawn()
		pickupTrove:Destroy()
		activePickups[areaName] = math.max(0, activePickups[areaName] - 1)
		task.delay(areaConfig.RespawnTime, function()
			spawnPickup(areaName)
		end)
	end

	for _, part in ipairs(parts) do
		pickupTrove:Connect(part.Touched, function(hit)
			if collected then return end

			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then return end

			if areaName == "VIP" and _G.HasVIP and not _G.HasVIP(player) then
				return
			end

			if not _G.AddPlayerPower then
				warn("[PowerService] _G.AddPlayerPower is not ready")
				return
			end

			local added, newPower = _G.AddPlayerPower(player, areaConfig.PowerAmount)
			if not added then return end

			collected = true
			PowerService.PowerCollected:Fire(player, areaConfig.PowerAmount, newPower, areaName)
			print("power collected")
			cleanupAndRespawn()
		end)
	end

	pickupTrove:Connect(RunService.Heartbeat, function(dt)
		if pickup.Parent then
			pickup:PivotTo(pickup:GetPivot() * CFrame.Angles(0, math.rad(90) * dt, 0))
		end
	end)
end

for areaName, areaConfig in pairs(AREAS) do
	for _ = 1, areaConfig.MaxPickups do
		task.spawn(spawnPickup, areaName)
	end
end

print("[PowerService] Loaded power pickup spawns")