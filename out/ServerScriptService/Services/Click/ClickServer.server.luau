--!nonstrict
-- Compiled by CL++ — C++ × Luau

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Ward = require(ReplicatedStorage.CluauppLibs.Ward)

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const Janitor = require(ReplicatedStorage.CluauppLibs.Sweep)
const Keep = require(ReplicatedStorage.CluauppLibs.Keep)
const Net = require(ReplicatedStorage.Shared.Net.Net)

local ClickServer = {}
ClickServer.CLICK_POINTS = 1
ClickServer.CLICK_DAMAGE = 1
ClickServer.CLICK_RATE = 20
ClickServer.CLICK_BURST = 40
ClickServer.CLICK_CHANNEL = "click"

-- ClickServer.server.clpp:7
function ClickServer:BindClickRemote(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(Net.ClickIntent:Connect(function(player: Player)
		self:OnClick(player)
	end), "Disconnect")

	return true
end

-- ClickServer.server.clpp:18
function ClickServer:BroadcastClickAck(player: Player, points: number, damage: number): boolean
	if not (self and player) then
		return false
	end

	Net.ClickAck:Fire(player, points, damage)
	return true
end

-- So math values
-- Compile values
-- ClickServer.server.clpp:27
function ClickServer:GrantClick(player: Player): boolean
	if not (self and player) then
		return false
	end

	local data = Keep.Server:WaitFor(player)

	if not (data) then
		return false
	end

	local points: number = data:Get(Keep.Server.Paths.Currencies.Points) + self.CLICK_POINTS
	local damage: number = data:Get(Keep.Server.Paths.Combat.Damage) + self.CLICK_DAMAGE
	data:Set(Keep.Server.Paths.Currencies.Points, points)
	data:Set(Keep.Server.Paths.Combat.Damage, damage)
	self:BroadcastClickAck(player, points, damage)
	return true
end

-- ClickServer.server.clpp:48
function ClickServer:OnClick(player: Player): boolean
	if not (self and player) then
		return false
	end

	if not (Ward.Allow(player, self.CLICK_CHANNEL, self.CLICK_RATE, self.CLICK_BURST)) then
		return false
	end

	return self:GrantClick(player)
end

-- ClickServer.server.clpp:59
const function init()
	ClickServer:BindClickRemote()
end

init()
