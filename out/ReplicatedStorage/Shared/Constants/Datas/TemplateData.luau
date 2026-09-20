--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

export type PlayerTemplate = {
	Currencies: Currencies,
	Combat: PlayerCombat,
	Rebirths: number,
	Rank: number,
	Inventory: PlayerInventory,
	Trade: PlayerTrade,
	Settings: PlayerSettings,
	Codes: PlayerCodes,
}

const function PlayerTemplate()
	return {
		Currencies = { Coins = 0, Gems = 0, Points = 0 },
		Combat = { Damage = 0 },
		Rebirths = 0,
		Rank = 0,
		Inventory = { Slots = 20 },
		Trade = { DayKey = nil, TradesToday = 0, LastTradeAt = 0, ActiveTradeId = nil },
		Settings = { GameMusic = 100, Effects = 100 },
		Codes = { RedeemedCount = 0 },
	}
end

return PlayerTemplate
