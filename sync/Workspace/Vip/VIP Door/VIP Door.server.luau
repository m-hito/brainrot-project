--------------------
--| WaitForChild |--
--------------------

-- Waits for parent.child to exist, then returns it
local function WaitForChild(parent, childName)
	assert(parent, "ERROR: WaitForChild: parent is nil")
	while not parent:FindFirstChild(childName) do parent.ChildAdded:wait() end
	return parent[childName]
end

-----------------
--| Variables |--
-----------------

local GamePassService = Game:GetService('GamePassService')
local PlayersService = Game:GetService('Players')

local VipDoor = script.Parent

local GamePassIdObject = WaitForChild(script, 'GamePassId')

local JustTouched = {}

-----------------
--| Functions |--
-----------------

-- Finds out which side the player is on and teleports them to the other
local function TeleportToOtherSide(character, hitPart)
	local bottomOfDoor = VipDoor.CFrame.p - Vector3.new(0, VipDoor.Size.Y / 2, 0)
	local inFrontOfDoor = bottomOfDoor + VipDoor.CFrame.lookVector * 3
	local behindDoor = bottomOfDoor - VipDoor.CFrame.lookVector * 3
	
	local distanceToFront = (inFrontOfDoor - hitPart.Position).magnitude
	local distanceToBack = (behindDoor - hitPart.Position).magnitude
	if distanceToFront < distanceToBack then
		character:MoveTo(behindDoor)
	else
		character:MoveTo(inFrontOfDoor)
	end
end

-- When a player with the game pass touches the door, teleport them to the other side
local function OnTouched(otherPart)
	if otherPart and otherPart.Parent and otherPart.Parent:FindFirstChild('Humanoid') then
		local player = PlayersService:GetPlayerFromCharacter(otherPart.Parent)
		if player and not JustTouched[player] then
			JustTouched[player] = time()
			if GamePassService:PlayerHasPass(player, GamePassIdObject.Value) then
				TeleportToOtherSide(player.Character, otherPart)
			end
		end
	end
end

-- Removes old entries in JustTouched
local function RemoveOldTouches()
	for player, touchTime in pairs(JustTouched) do
		if time() > touchTime + 0.3 then
			JustTouched[player] = nil
		end
	end
end

--------------------
--| Script Logic |--
--------------------

VipDoor.Touched:connect(OnTouched)

while true do
	RemoveOldTouches()
	wait(1/30)
end
