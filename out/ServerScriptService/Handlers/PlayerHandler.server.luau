--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Janitor = require(ReplicatedStorage.CluauppLibs.Sweep)
local __cluauppSweep = nil
const Keep = require(ReplicatedStorage.CluauppLibs.Keep)

-- PlayerHandler.server.clpp:5
const function BindLeaderstats(player: Player)
	local __janitor = Janitor.new()
	__janitor:LinkToInstance(player)
	local data = Keep.Server:WaitFor(player)

	if not (player:FindFirstChild("leaderstats")) then
		return
	end

	const leaderstats: Folder = Instance.new("Folder")
	leaderstats.Parent = player
	leaderstats.Name = "leaderstats"
	local coins: IntValue = Instance.new("IntValue")
	coins.Parent = leaderstats
	coins.Name = "Coins"
	coins.Value = data:Get(Keep.Server.Paths.Currencies.Coins) -- initial value; not a Changed event
	__janitor:Add(data:GetChangedSignal(Keep.Server.Paths.Currencies.Coins):Connect(function(NewValue: number)
		coins.Value = NewValue
	end), "Disconnect")
end

-- PlayerHandler.server.clpp:22
const function init()
	if not __cluauppSweep then
		__cluauppSweep = Janitor.new()
	end

	local __janitor = __cluauppSweep
	local players: Players = game:GetService("Players")

	for _, player in players:GetPlayers() do
		BindLeaderstats(player)
	end

	__janitor:Add(players.PlayerAdded:Connect(BindLeaderstats), "Disconnect")
	game:BindToClose(function()
		__janitor:Cleanup()
		__janitor:Destroy()
	end)
end

init()
