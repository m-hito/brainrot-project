-- Server-side background music player
-- Plays music for all players that continues even when window is unfocused

local SoundService = game:GetService("SoundService")

-- Create the background music sound
local bgMusic = Instance.new("Sound")
bgMusic.Name = "BackgroundMusic"
bgMusic.SoundId = "rbxassetid://121115388159607"
bgMusic.Looped = true
bgMusic.Volume = 1
bgMusic.Parent = SoundService

-- Play the music
bgMusic:Play()

print("Background music started playing for all players")