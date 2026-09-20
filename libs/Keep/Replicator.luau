--!native
--!optimize 2
--!strict
-- Keep replicator — tagged buffers (Ready / Snapshot / Delta). No JSON, no QuickNet.

local RunService = game:GetService("RunService")
local Spark = require(script.Parent.Parent.Spark)
local Ward = require(script.Parent.Parent.Ward)

local TAG = {
	Ready = 1,
	Snapshot = 2,
	Delta = 3,
	Init = 4,
	Set = 5,
	ArrayInsert = 6,
	ArrayRemove = 7,
	TransientSet = 8,
}

local ACTION_TAG = {
	i = TAG.Init,
	s = TAG.Set,
	ai = TAG.ArrayInsert,
	ar = TAG.ArrayRemove,
	ts = TAG.TransientSet,
	ready = TAG.Ready,
	snapshot = TAG.Snapshot,
	delta = TAG.Delta,
}

local TAG_ACTION = {}
for name, id in ACTION_TAG do
	TAG_ACTION[id] = name
end

local TYPE = { Nil = 0, Bool = 1, Number = 2, String = 3, Table = 4 }

local function grow(buf: buffer, need: number): buffer
	if buffer.len(buf) >= need then
		return buf
	end
	local nextBuf = buffer.create(math.max(need, buffer.len(buf) * 2))
	buffer.copy(nextBuf, 0, buf, 0, buffer.len(buf))
	return nextBuf
end

local function writeString(buf: buffer, cursor: number, text: string): (buffer, number)
	buf = grow(buf, cursor + 2 + #text)
	buffer.writeu16(buf, cursor, #text)
	buffer.writestring(buf, cursor + 2, text)
	return buf, cursor + 2 + #text
end

local function readString(buf: buffer, cursor: number): (string, number)
	local length = buffer.readu16(buf, cursor)
	return buffer.readstring(buf, cursor + 2, length), cursor + 2 + length
end

local writeValue: (buffer, number, any) -> (buffer, number)
local readValue: (buffer, number) -> (any, number)

writeValue = function(buf: buffer, cursor: number, value: any): (buffer, number)
	local kind = typeof(value)
	buf = grow(buf, cursor + 16)
	if value == nil then
		buffer.writeu8(buf, cursor, TYPE.Nil)
		return buf, cursor + 1
	end
	if kind == "boolean" then
		buffer.writeu8(buf, cursor, TYPE.Bool)
		buffer.writeu8(buf, cursor + 1, if value then 1 else 0)
		return buf, cursor + 2
	end
	if kind == "number" then
		buffer.writeu8(buf, cursor, TYPE.Number)
		buffer.writef64(buf, cursor + 1, value)
		return buf, cursor + 9
	end
	if kind == "string" then
		buffer.writeu8(buf, cursor, TYPE.String)
		return writeString(buf, cursor + 1, value)
	end
	if kind == "table" then
		buffer.writeu8(buf, cursor, TYPE.Table)
		cursor += 1
		local count = 0
		for _ in value do
			count += 1
		end
		buf = grow(buf, cursor + 2)
		buffer.writeu16(buf, cursor, count)
		cursor += 2
		for key, item in value do
			buf, cursor = writeValue(buf, cursor, key)
			buf, cursor = writeValue(buf, cursor, item)
		end
		return buf, cursor
	end
	buffer.writeu8(buf, cursor, TYPE.Nil)
	return buf, cursor + 1
end

readValue = function(buf: buffer, cursor: number): (any, number)
	local kind = buffer.readu8(buf, cursor)
	cursor += 1
	if kind == TYPE.Nil then
		return nil, cursor
	end
	if kind == TYPE.Bool then
		return buffer.readu8(buf, cursor) == 1, cursor + 1
	end
	if kind == TYPE.Number then
		return buffer.readf64(buf, cursor), cursor + 8
	end
	if kind == TYPE.String then
		return readString(buf, cursor)
	end
	if kind == TYPE.Table then
		local count = buffer.readu16(buf, cursor)
		cursor += 2
		local out = {}
		for _ = 1, count do
			local key
			key, cursor = readValue(buf, cursor)
			local item
			item, cursor = readValue(buf, cursor)
			out[key] = item
		end
		return out, cursor
	end
	return nil, cursor
end

local function pack(action: string, path: any, payload: { any }): buffer
	local buf = buffer.create(64)
	buffer.writeu8(buf, 0, ACTION_TAG[action] or TAG.Delta)
	local cursor = 1
	buf, cursor = writeValue(buf, cursor, path)
	buf, cursor = writeValue(buf, cursor, payload)
	local trimmed = buffer.create(cursor)
	buffer.copy(trimmed, 0, buf, 0, cursor)
	return trimmed
end

local function unpackPacket(buf: buffer): (string, any, { any })
	local tag = buffer.readu8(buf, 0)
	local path
	local cursor
	path, cursor = readValue(buf, 1)
	local payload
	payload, cursor = readValue(buf, cursor)
	return TAG_ACTION[tag] or "s", path, if typeof(payload) == "table" then payload else { payload }
end

local function folder(): Folder
	local rs = game:GetService("ReplicatedStorage")
	local existing = rs:FindFirstChild("KeepNet")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "KeepNet"
	created.Parent = rs
	local reliable = Instance.new("RemoteEvent")
	reliable.Name = "Reliable"
	reliable.Parent = created
	return created
end

local net = folder()
local remote = net:WaitForChild("Reliable") :: RemoteEvent

local function emptyStats()
	return {
		Bytes = 0,
		Messages = 0,
		LastPacketBytes = 0,
		LastUtilization = 0,
		TotalBytes = 0,
		TotalMessages = 0,
		ByPlayer = {},
	}
end

local Server = {
	OnReady = Spark.new(),
	BufferChanged = Spark.new(),
	_stats = emptyStats(),
	_handlers = {} :: { [string]: (...any) -> () },
	_ready = {} :: { [Player]: boolean },
}

local Client = {
	OnReady = Spark.new(),
	BufferChanged = Spark.new(),
	_stats = emptyStats(),
	_handlers = {} :: { [string]: (...any) -> () },
}

if RunService:IsServer() then
	remote.OnServerEvent:Connect(function(player: Player, packed: buffer?)
		if typeof(packed) ~= "buffer" then
			Ward.Strike(player, "keep:type")
			return
		end
		if not Ward.Packet(player, buffer.len(packed), 256) then
			return
		end
		if not Ward.Allow(player, "keep", 4, 8) then
			return
		end
		local ok, action = pcall(unpackPacket, packed)
		if not ok or action ~= "ready" then
			Ward.Strike(player, "keep:action")
			return
		end
		if Server._ready[player] then
			return
		end
		Server._ready[player] = true
		Server.OnReady:Fire(player)
	end)

	function Server:On(action: string, handler: (...any) -> ())
		self._handlers[action] = handler
	end

	function Server:Send(player: Player, action: string, path: any, ...)
		local payload = table.pack(...)
		local packed = pack(action, path, payload)
		local bytes = buffer.len(packed)
		local byPlayer = self._stats.ByPlayer[player]
		if not byPlayer then
			byPlayer = emptyStats()
			self._stats.ByPlayer[player] = byPlayer
		end
		byPlayer.Bytes += bytes
		byPlayer.Messages += 1
		byPlayer.LastPacketBytes = bytes
		byPlayer.LastUtilization = math.clamp(bytes / 1024, 0, 1)
		self._stats.TotalBytes += bytes
		self._stats.TotalMessages += 1
		self._stats.LastPacketBytes = bytes
		remote:FireClient(player, packed)
	end

	function Server:GetBufferStats(player: Player?)
		if player then
			return self._stats.ByPlayer[player]
		end
		return self._stats
	end

	function Server:ForgetPlayer(player: Player)
		self._stats.ByPlayer[player] = nil
		self._ready[player] = nil
	end

	function Server:Destroy()
		Server.OnReady:Destroy()
		Server.BufferChanged:Destroy()
	end
else
	function Client:On(action: string, handler: (...any) -> ())
		self._handlers[action] = handler
	end

	function Client:NotifyReady()
		remote:FireServer(pack("ready", {}, {}))
	end

	remote.OnClientEvent:Connect(function(packed: buffer)
		local action, path, payload = unpackPacket(packed)
		Client._stats.LastPacketBytes = buffer.len(packed)
		Client._stats.Bytes += Client._stats.LastPacketBytes
		Client._stats.Messages += 1
		Client.BufferChanged:Fire(Client._stats)
		local handler = Client._handlers[action]
		if handler then
			handler(path, table.unpack(payload, 1, payload.n or #payload))
		end
		if action == "ready" or action == "i" then
			Client.OnReady:Fire()
		end
	end)

	function Client:GetBufferStats()
		return Client._stats
	end

	function Client:Destroy()
		Client.OnReady:Destroy()
		Client.BufferChanged:Destroy()
	end
end

return { Server = Server, Client = Client, TAG = TAG }
