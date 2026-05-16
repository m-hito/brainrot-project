local Server = {}
local RPS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

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

--local Cmdr = require(RPS.Packages.Cmdr)
--local Hooks = RPS.Types.CmdrHooks

--Cmdr:RegisterDefaultCommands()
--Cmdr:RegisterCommandsIn(RPS.Types.Commands)
--Cmdr.Registry:RegisterHook("AfterRun", require(Hooks.AfterRun))
--Cmdr.Registry:RegisterHook("BeforeRun", require(Hooks.BeforeRun))

function Server.load()
	getNetwork()

	task.spawn(function()
		for _, module in pairs(RPS.shared:GetDescendants()) do
			task.spawn(function()
				if module:IsA("ModuleScript") then
					local m = require(module)
					if typeof(m) == "table" and typeof(m.loadServer) == "function" then
						m.loadServer()
					end
				end
			end)
		end
	end)
end

function Server.loadPlayer(player : Player)
	if not player or player:FindFirstChild("HumanoidRootPart") then return end

	local profile = require(RPS.shared.Server.Services.DataService).getProfile(player)
	if profile then

	end
end

return Server
