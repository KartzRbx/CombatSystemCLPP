const HttpService = game:GetService("HttpService")
const RunService = game:GetService("RunService")

local packages = script.Parent.Packages
const Signal = require(packages.signal)
const QuickNet = require(packages.quicknet)

const DATA_EVENT = "DataServiceV2/Data"
const READY_EVENT = "DataServiceV2/Ready"
const BUFFER_EVENT = "DataServiceV2/Buffer"
const MAX_PACKET_BYTES = 1024

type Packet = {
	Action: string,
	Path: any,
	Payload: { any },
}

const Replicator: { [string]: any } = {}
const quickNetData = QuickNet.Data
const dataEvent = QuickNet:register(DATA_EVENT, quickNetData.Any)
const readyEvent = QuickNet:register(READY_EVENT, quickNetData.Boolean)
const bufferEvent = QuickNet:register(BUFFER_EVENT, quickNetData.Any)

const estimatePacketBytes = function(packet: Packet): number
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(packet)
	end)
	if not ok then
		return 0
	end
	return #encoded
end

if RunService:IsServer() then
	local _cleanupTasks: { any } = {}
	const Server = {
		OnReady = Signal.new(),
		_stats = {
			TotalBytes = 0,
			TotalMessages = 0,
			ByPlayer = {} :: { [Player]: { Bytes: number, Messages: number, LastPacketBytes: number, LastUtilization: number } },
		},
	}

	table.insert(_cleanupTasks, { Server.OnReady, "Destroy" })
	table.insert(_cleanupTasks, {
		readyEvent.OnServerEvent:Connect(function(player: Player, ready: boolean?)
			if ready then
				Server.OnReady:Fire(player)
			end
		end),
		"Disconnect",
	})

	function Server:Send(player: Player, action: string, path: any, ...)
		local payload = table.pack(...)
		local packet: Packet = {
			Action = action,
			Path = path,
			Payload = payload,
		}

		local bytes = estimatePacketBytes(packet)
		local utilization = if MAX_PACKET_BYTES > 0 then math.clamp(bytes / MAX_PACKET_BYTES, 0, 1) else 0
		local byPlayer = self._stats.ByPlayer[player]
		if not byPlayer then
			byPlayer = {
				Bytes = 0,
				Messages = 0,
				LastPacketBytes = 0,
				LastUtilization = 0,
			}
			self._stats.ByPlayer[player] = byPlayer
		end
		byPlayer.Bytes += bytes
		byPlayer.Messages += 1
		byPlayer.LastPacketBytes = bytes
		byPlayer.LastUtilization = utilization
		self._stats.TotalBytes += bytes
		self._stats.TotalMessages += 1

		dataEvent:FireClient(player, packet)
		bufferEvent:FireClient(player, {
			Bytes = byPlayer.Bytes,
			Messages = byPlayer.Messages,
			LastPacketBytes = byPlayer.LastPacketBytes,
			LastUtilization = byPlayer.LastUtilization,
		})
	end

	function Server:GetBufferStats(player: Player?): any
		if player then
			return self._stats.ByPlayer[player]
		end
		return self._stats
	end

	function Server:ForgetPlayer(player: Player)
		self._stats.ByPlayer[player] = nil
	end

	function Server:Destroy()
		for _, task in _cleanupTasks do
			local obj, method = task[1], task[2]
			if obj and type(obj[method]) == "function" then
				obj[method](obj)
			end
		end
		table.clear(_cleanupTasks)
	end

	Replicator.Server = Server
else
	local handlers: { [string]: (any, ...any) -> () } = {}
	local _cleanupTasks: { any } = {}
	const Client = {
		BufferChanged = Signal.new(),
		_stats = {
			Bytes = 0,
			Messages = 0,
			LastPacketBytes = 0,
			LastUtilization = 0,
		},
	}

	table.insert(_cleanupTasks, { Client.BufferChanged, "Destroy" })
	table.insert(_cleanupTasks, {
		dataEvent.OnClientEvent:Connect(function(packet: Packet)
			local h = handlers[packet.Action]
			if h then
				local payload = packet.Payload
				h(packet.Path, table.unpack(payload, 1, payload.n or #payload))
			end
		end),
		"Disconnect",
	})
	table.insert(_cleanupTasks, {
		bufferEvent.OnClientEvent:Connect(function(stats)
			Client._stats = stats or Client._stats
			Client.BufferChanged:Fire(Client._stats)
		end),
		"Disconnect",
	})

	function Client:On(action: string, fn: (any, ...any) -> ())
		handlers[action] = fn
	end

	function Client:NotifyReady()
		readyEvent:FireServer(true)
	end

	function Client:GetBufferStats()
		return self._stats
	end

	function Client:Destroy()
		table.clear(handlers)
		for _, task in _cleanupTasks do
			local obj, method = task[1], task[2]
			if obj and type(obj[method]) == "function" then
				obj[method](obj)
			end
		end
		table.clear(_cleanupTasks)
	end

	Replicator.Client = Client
end

return Replicator
