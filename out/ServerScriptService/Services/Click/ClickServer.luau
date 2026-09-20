--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Keep = require(ReplicatedStorage.CluauppLibs.Keep)
const Net = require(ReplicatedStorage.Shared.Net.Net)

export type ClickServer = {
	CLICK_POINTS: number,
	CLICK_DAMAGE: number,
	CLICK_RATE: number,
	CLICK_BURST: number,
	CLICK_CHANNEL: string,
	BindClickRemote: (self: ClickServer) -> boolean,
	OnClick: (self: ClickServer, player: Player) -> boolean,
	GrantClick: (self: ClickServer, player: Player) -> boolean,
	BroadcastClickAck: (self: ClickServer, player: Player, points: number, damage: number) -> boolean,
}

const function ClickServer()
	return {
		CLICK_POINTS = 1,
		CLICK_DAMAGE = 1,
		CLICK_RATE = 20,
		CLICK_BURST = 40,
		CLICK_CHANNEL = "click",
	}
end

return ClickServer
