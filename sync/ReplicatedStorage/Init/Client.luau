local Client = {}
local RPS = game:GetService("ReplicatedStorage")
--local Cmdr = require(RPS:WaitForChild("CmdrClient"))

-- Configurable, and you can choose multiple keys
--Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt, })
--Cmdr.Registry:RegisterHook("BeforeRun", require(RPS.Types.CmdrHooks:WaitForChild("BeforeRun")))

function Client.load()
	task.spawn(function()
		repeat
			task.wait()
		until game.Players.LocalPlayer.PlayerGui:FindFirstChild("HUD")

		for _, module in pairs(RPS.shared:GetDescendants()) do
			task.spawn(function()
				if module:IsA("ModuleScript") and not module:IsDescendantOf(RPS.shared:WaitForChild("Server")) then
					local m = require(module)
					if typeof(m) == "table" and typeof(m.loadClient) == "function" then
						m.loadClient()
					end
				end
			end)
		end
	end)
end


return Client
