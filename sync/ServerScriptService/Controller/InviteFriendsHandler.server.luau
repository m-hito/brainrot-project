local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local networkFolder = ReplicatedStorage.shared:FindFirstChild("Network")
if not networkFolder then
	networkFolder = Instance.new("Folder")
	networkFolder.Name = "Network"
	networkFolder.Parent = ReplicatedStorage.shared
end

-- Create the remote event if it doesn't exist
local inviteEvent = networkFolder:FindFirstChild("InviteFriendsEvent")
if not inviteEvent then
	inviteEvent = Instance.new("RemoteEvent")
	inviteEvent.Name = "InviteFriendsEvent"
	inviteEvent.Parent = networkFolder
end

-- Handle invite requests from clients
inviteEvent.OnServerEvent:Connect(function(player)
	SocialService:PromptGameInvite(player)
end)

print("InviteFriendsHandler loaded!")
