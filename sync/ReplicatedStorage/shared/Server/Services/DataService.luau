local DataService = {}
local RPS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local DataManager = require(SSS:WaitForChild("DataManager"))

local function getNetwork()
	local shared = RPS:FindFirstChild("shared")
	if not shared then
		shared = Instance.new("Folder")
		shared.Name = "shared"
		shared.Parent = RPS
	end

	local network = shared:FindFirstChild("Network")
	if not network then
		network = Instance.new("Folder")
		network.Name = "Network"
		network.Parent = shared
	end

	return network
end

local function getOrCreateRemoteFunction(name)
	local network = getNetwork()
	local remote = network:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = network
	end
	return remote
end

function DataService.loadServer()
	getOrCreateRemoteFunction("GetData").OnServerInvoke = function(player, key)
		local profile = DataService.getProfile(player)
		if not profile or type(key) ~= "string" then
			return nil
		end
		return profile.Data[key]
	end
end

function DataService.getProfile(player : Player)
	while player and player.Parent and not DataManager.Profiles[player] do
		task.wait()
	end

	if player then
		return DataManager.Profiles[player]
	end
end

function DataService.getData(player : Player)
	local profile = DataService.getProfile(player)
	return profile and profile.Data or nil
end

return DataService
