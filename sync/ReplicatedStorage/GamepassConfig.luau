-- Gamepass Configuration Module

local GamepassConfig = {}

-- GAMEPASS IDS (Replace these with your real gamepass IDs)
GamepassConfig.IDs = {
	VIP = 1823052915,          
	DoubleMoney = 1822729516, 
	AutoRebirth = 1822655538,   
	AutoThrow = 1822795316,   
}

-- GAMEPASS PRICES (in Robux)
GamepassConfig.Prices = {
	VIP = 50,
	DoubleMoney = 75,
	AutoRebirth = 100,
	AutoThrow = 100,
}

-- GAMEPASS EFFECTS
GamepassConfig.Effects = {
    DoubleMoney = {
        multiplier = 2,  -- 2x money multiplier
        name = "2x Money",
        description = "Double all money earned!"
    },
    VIP = {
        name = "VIP",
        description = "Access to VIP areas and perks!"
    },
    AutoRebirth = {
        name = "Auto Rebirth",
        description = "Automatically rebirth when requirements are met!"
    },
    AutoThrow = {
        name = "Auto Throw",
        description = "Automatically throw brainrots!"
    }
}

return GamepassConfig