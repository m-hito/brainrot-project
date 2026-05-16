local Players = game:GetService("Players")
local sss = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local profileservice = require(sss:FindFirstChild("ProfileService"))
local template = require(script.Template)

local Settings = require(game:GetService("ReplicatedStorage").Settings)
local dataKey = Settings.DataKey
local profileStore = profileservice.GetProfileStore(dataKey, template)

local dataManager = {}
dataManager.Profiles = {}

local oldStores = {
	Money = {Store = DataStoreService:GetDataStore("BrainrotMoney_V2"), Key = "Money_"},
	Throws = {Store = DataStoreService:GetDataStore("BrainrotThrows_V2"), Key = "Throws_"},
	MaxDistance = {Store = DataStoreService:GetDataStore("BrainrotMaxDistance_V2"), Key = "MaxDistance_"},
	TotalDistance = {Store = DataStoreService:GetDataStore("BrainrotTotalDistance_V2"), Key = "TotalDistance_"},
	Rebirths = {Store = DataStoreService:GetDataStore("BrainrotRebirths_V2"), Key = "Rebirths_"},
	Power = {Store = DataStoreService:GetDataStore("BrainrotPower_V2"), Key = "Power_"},
}

local oldGamepassStore = DataStoreService:GetDataStore("GamepassData_v1")

local function migrateOldData(player, profile)
	if profile.Data.MigratedOldData then
		return
	end

	for dataKey, oldStoreInfo in pairs(oldStores) do
		local success, value = pcall(function()
			return oldStoreInfo.Store:GetAsync(oldStoreInfo.Key .. player.UserId)
		end)

		if success and value ~= nil then
			profile.Data[dataKey] = value
		elseif not success then
			warn("[DataManager] Failed to migrate " .. dataKey .. " for " .. player.Name .. ": " .. tostring(value))
		end
	end

	local gamepassSuccess, gamepasses = pcall(function()
		return oldGamepassStore:GetAsync("Player_" .. player.UserId)
	end)

	if gamepassSuccess and type(gamepasses) == "table" then
		profile.Data.Gamepasses = gamepasses
	elseif not gamepassSuccess then
		warn("[DataManager] Failed to migrate gamepasses for " .. player.Name .. ": " .. tostring(gamepasses))
	end

	local toggleSuccess, toggles = pcall(function()
		return oldGamepassStore:GetAsync("Player_Toggles_" .. player.UserId)
	end)

	if toggleSuccess and type(toggles) == "table" then
		profile.Data.Settings.AutoRebirth = toggles.autoRebirth == true
		profile.Data.Settings.AutoThrow = toggles.autoThrow == true
	elseif not toggleSuccess then
		warn("[DataManager] Failed to migrate toggles for " .. player.Name .. ": " .. tostring(toggles))
	end

	profile.Data.MigratedOldData = true
	print("[DataManager] Migrated old data for " .. player.Name)
end

local function playerAdded(player)
	assert(player)
	local profile = profileStore:LoadProfileAsync(tostring(player.UserId) .. "_playerdata")

	-- Admins are immune to bans - clear any ban data for admins
	--local isAdmin = false
	--for _, adminId in ipairs(Settings.Admins) do
	--	if player.UserId == adminId then
	--		isAdmin = true
	--		break
	--	end
	--end

	--if isAdmin then
	--	print("Admin " .. player.Name .. " joined - clearing any ban data")
	--	profile.Data.BanData.Banned = false
	--	profile.Data.BanData.Reason = nil
	--end

	if profile ~= nil then
		print(profile)
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		migrateOldData(player, profile)

		profile:ListenToRelease(function()
			dataManager.Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			dataManager.Profiles[player] = profile
		else
			profile:Release()
		end
	else
		player:Kick()
	end
end

local function playerRemoving(player)
	local profile = dataManager.Profiles[player]

	if profile ~= nil then
		profile:Release()
	end
end

function dataManager.GetProfile(player)
	return dataManager.Profiles[player]
end

function dataManager.GetData(player)
	local profile = dataManager.GetProfile(player)
	return profile and profile.Data or nil
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(playerAdded, player)
end

Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)

return dataManager
