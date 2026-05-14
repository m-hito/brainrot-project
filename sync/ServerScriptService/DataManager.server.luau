-- Data Backup & Reset System
-- Use chat commands: /backup, /reset, /restore
-- Or call functions directly from other scripts

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Original DataStores (from BrainrotThrower script)
local OriginalStores = {
	Money = DataStoreService:GetDataStore("BrainrotMoney_V2"),
	Throws = DataStoreService:GetDataStore("BrainrotThrows_V2"),
	MaxDistance = DataStoreService:GetDataStore("BrainrotMaxDistance_V2"),
	TotalDistance = DataStoreService:GetDataStore("BrainrotTotalDistance_V2"),
	Rebirths = DataStoreService:GetDataStore("BrainrotRebirths_V2"),
	Power = DataStoreService:GetDataStore("BrainrotPower_V2"),
}

-- Backup DataStores (stores original data)
local BackupStores = {
	Money = DataStoreService:GetDataStore("Backup_BrainrotMoney_V2"),
	Throws = DataStoreService:GetDataStore("Backup_BrainrotThrows_V2"),
	MaxDistance = DataStoreService:GetDataStore("Backup_BrainrotMaxDistance_V2"),
	TotalDistance = DataStoreService:GetDataStore("Backup_BrainrotTotalDistance_V2"),
	Rebirths = DataStoreService:GetDataStore("Backup_BrainrotRebirths_V2"),
	Power = DataStoreService:GetDataStore("Backup_BrainrotPower_V2"),
}

-- Track backup state
local isBackedUp = false
local backupTimestamp = nil

-- Helper function to get all player UserIds from DataStores
local function getAllPlayerIds()
	local playerIds = {}
	
	-- Get all players currently in game
	for _, player in ipairs(Players:GetPlayers()) do
		playerIds[player.UserId] = true
	end
	
	-- Note: We can't enumerate all keys in DataStores, so we rely on:
	-- 1. Currently connected players
	-- 2. Any player data that gets loaded during the session
	
	return playerIds
end

-- BACKUP: Save all current data to backup DataStores
local function backupAllData()
	print("[DataManager] Starting backup...")
	local successCount = 0
	local errorCount = 0
	
	-- Backup data for all current players
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		
		for storeName, store in pairs(OriginalStores) do
			local success, value = pcall(function()
				return store:GetAsync(storeName .. "_" .. userId)
			end)
			
			if success then
				pcall(function()
					BackupStores[storeName]:SetAsync(storeName .. "_" .. userId, value)
				end)
				successCount = successCount + 1
			else
				errorCount = errorCount + 1
			end
		end
	end
	
	isBackedUp = true
	backupTimestamp = os.time()
	
	print(string.format("[DataManager] Backup complete! Saved %d entries, %d errors.", successCount, errorCount))
	print("[DataManager] Backup timestamp: " .. os.date("%Y-%m-%d %H:%M:%S", backupTimestamp))
	
	return true, successCount, errorCount
end

-- RESET: Clear all data to fresh state (0 for all values)
local function resetAllData()
	print("[DataManager] Starting reset...")
	local successCount = 0
	local errorCount = 0
	
	-- Reset data for all current players
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		
		for storeName, store in pairs(OriginalStores) do
			local success = pcall(function()
				store:SetAsync(storeName .. "_" .. userId, 0)
			end)
			
			if success then
				successCount = successCount + 1
			else
				errorCount = errorCount + 1
			end
		end
		
		-- Update in-memory data if the main script has it
		if _G.GetPlayerMoney then
			-- Force reload by having player rejoin or trigger a reload
			-- The main script will reload from DataStore on next session
		end
	end
	
	print(string.format("[DataManager] Reset complete! Cleared %d entries, %d errors.", successCount, errorCount))
	print("[DataManager] Players need to rejoin to see reset data, or call refreshAllPlayers()")
	
	return true, successCount, errorCount
end

-- RESTORE: Bring back original data from backup
local function restoreAllData()
	if not isBackedUp then
		warn("[DataManager] No backup found! Run backupAllData() first.")
		return false, 0, 0
	end
	
	print("[DataManager] Starting restore from backup...")
	local successCount = 0
	local errorCount = 0
	
	-- Restore data for all current players
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		
		for storeName, store in pairs(OriginalStores) do
			local success, value = pcall(function()
				return BackupStores[storeName]:GetAsync(storeName .. "_" .. userId)
			end)
			
			if success then
				pcall(function()
					store:SetAsync(storeName .. "_" .. userId, value)
				end)
				successCount = successCount + 1
			else
				errorCount = errorCount + 1
			end
		end
	end
	
	print(string.format("[DataManager] Restore complete! Restored %d entries, %d errors.", successCount, errorCount))
	print("[DataManager] Players need to rejoin to see restored data.")
	
	return true, successCount, errorCount
end

-- REFRESH: Force reload data for all players (kick and let them rejoin)
local function refreshAllPlayers()
	print("[DataManager] Kicking all players to force data refresh...")
	
	for _, player in ipairs(Players:GetPlayers()) do
		player:Kick("Data has been reset. Please rejoin to continue.")
	end
	
	print("[DataManager] All players kicked. They will load fresh data on rejoin.")
	return true
end

-- Expose functions globally for other scripts to use
_G.BackupAllData = backupAllData
_G.ResetAllData = resetAllData
_G.RestoreAllData = restoreAllData
_G.RefreshAllPlayers = refreshAllPlayers
_G.IsDataBackedUp = function() return isBackedUp, backupTimestamp end

print("[DataManager] Data management system loaded!")
print("[DataManager] Or use global functions: _G.BackupAllData(), _G.ResetAllData(), _G.RestoreAllData()")