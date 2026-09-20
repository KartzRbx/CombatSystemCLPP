--!native
--!optimize 2
-- cluaupp generated — do not edit.

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Hive = require(ReplicatedStorage.CluauppLibs.Hive)
local PlayerECS = {
	Fighter = { Id = 1, Fields = { { Type = "i32", Name = "userId" } } },
	Health = { Id = 2, Fields = { { Type = "i32", Name = "current" }, { Type = "i32", Name = "max" } } },
	Cooldown = { Id = 3, Fields = { { Type = "f64", Name = "lastHit" } } },
	Combo = { Id = 4, Fields = { { Type = "i32", Name = "stage" } } },
	Alive = { Id = 5, Fields = { { Type = "i32", Name = "flag" } } },
}

function PlayerECS.New()
	return Hive.World(PlayerECS)
end

return PlayerECS
