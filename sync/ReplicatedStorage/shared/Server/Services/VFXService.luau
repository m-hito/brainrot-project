local RPS = game:GetService("ReplicatedStorage")

local Packages = RPS.shared:WaitForChild("Packages")
local Services = RPS.shareds.Server:WaitForChild("Services")
local Network = RPS.shared:WaitForChild("Network")
--local Types = RPS:WaitForChild("Types")
local Settings = require(RPS:WaitForChild("Settings"))

local VFXService = {}

function VFXService.Play(Attachment : Attachment, Base : BasePart, Time : number)
	task.spawn(function()
		assert(Attachment, "attachment doesnt exist")
		assert(Base, "base doesnt exist")
		assert(Time, "time doesnt exist")
		local clone = Attachment:Clone()
		clone.Parent = Base
		for a, b in ipairs(clone:GetDescendants()) do
			task.spawn(function()
				if b and b:IsA("ParticleEmitter") or b:IsA("Beam") then
					if not b:GetAttribute("EmitCount") then
						b.Enabled = true
					else
						b.Enabled = false
						b:Emit(b:GetAttribute("EmitCount"))
					end
				end
			end)
		end
		wait(Time)
		clone:Destroy()
	end)
	
end

return VFXService
