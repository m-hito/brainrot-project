local Template = {
	Money = 0,
	Throws = 0,
	MaxDistance = 0,
	TotalDistance = 0,
	Rebirths = 0,
	Power = 0,

	StarsCollected = 0,
	JetpackLevel = 0,
	EquippedJetpack = nil,

	OwnedAuras = {},
	EquippedAura = nil,

	DiscoveredBrainrots = {},
	Settings = {
		AutoThrow = false,
		AutoRebirth = false,
	},

	Gamepasses = {},

	MigratedOldData = false,
}


return Template
