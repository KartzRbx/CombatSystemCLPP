--!native
--!optimize 2
--!strict
--[[
	Flare — Cluaupp networker.
	Zap-style generated write/read, QuickNet-class buffers, ByteNet packets + queries.

	Games do not call this module to declare remotes. Write a .flare schema;
	cluaupp build generates Net.luau which opens a session here.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Ward = require(script.Parent.Ward)

type Cursor = {
	buf: buffer,
	offset: number,
	instances: { Instance },
	index: number,
}

type PacketSpec = {
	id: number,
	from: "client" | "server",
	reliable: boolean,
	write: (...any) -> Cursor,
	read: (Cursor) -> (...any),
}

type QuerySpec = {
	id: number,
	writeReq: (...any) -> Cursor,
	readReq: (Cursor) -> (...any),
	writeRes: (Cursor, any) -> Cursor,
	readRes: (Cursor) -> any,
}

type Queued = {
	id: number,
	cursor: Cursor,
}

local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local writeu32 = buffer.writeu32
local writei8 = buffer.writei8
local writei16 = buffer.writei16
local writei32 = buffer.writei32
local writef32 = buffer.writef32
local writef64 = buffer.writef64
local writestring = buffer.writestring
local readu8 = buffer.readu8
local readu16 = buffer.readu16
local readu32 = buffer.readu32
local readi8 = buffer.readi8
local readi16 = buffer.readi16
local readi32 = buffer.readi32
local readf32 = buffer.readf32
local readf64 = buffer.readf64
local readstring = buffer.readstring
local bufferCopy = buffer.copy
local bufferLen = buffer.len
local bufferCreate = buffer.create

local function ensure(cursor: Cursor, extra: number)
	local need = cursor.offset + extra
	local size = bufferLen(cursor.buf)
	if need <= size then
		return
	end
	local grown = bufferCreate(math.max(size * 2, need))
	bufferCopy(grown, 0, cursor.buf, 0, cursor.offset)
	cursor.buf = grown
end

local function cursor(size: number?): Cursor
	return {
		buf = bufferCreate(size or 64),
		offset = 0,
		instances = {},
		index = 1,
	}
end

local function fromBuffer(buf: buffer, instances: { Instance }?): Cursor
	return {
		buf = buf,
		offset = 0,
		instances = instances or {},
		index = 1,
	}
end

local function instanceCount(c: Cursor): number
	return c.index - 1
end

local function sliceCursor(c: Cursor): buffer
	local n = c.offset
	local buf = bufferCreate(n)
	if n > 0 then
		bufferCopy(buf, 0, c.buf, 0, n)
	end
	return buf
end

local Flare = {}

function Flare.cursor(size: number?): Cursor
	return cursor(size)
end

function Flare.writeu8(c: Cursor, value: number)
	ensure(c, 1)
	writeu8(c.buf, c.offset, value)
	c.offset += 1
end

function Flare.writeu16(c: Cursor, value: number)
	ensure(c, 2)
	writeu16(c.buf, c.offset, value)
	c.offset += 2
end

function Flare.writeu32(c: Cursor, value: number)
	ensure(c, 4)
	writeu32(c.buf, c.offset, value)
	c.offset += 4
end

function Flare.writei8(c: Cursor, value: number)
	ensure(c, 1)
	writei8(c.buf, c.offset, value)
	c.offset += 1
end

function Flare.writei16(c: Cursor, value: number)
	ensure(c, 2)
	writei16(c.buf, c.offset, value)
	c.offset += 2
end

function Flare.writei32(c: Cursor, value: number)
	ensure(c, 4)
	writei32(c.buf, c.offset, value)
	c.offset += 4
end

function Flare.writef32(c: Cursor, value: number)
	ensure(c, 4)
	writef32(c.buf, c.offset, value)
	c.offset += 4
end

function Flare.writef64(c: Cursor, value: number)
	ensure(c, 8)
	writef64(c.buf, c.offset, value)
	c.offset += 8
end

function Flare.writebool(c: Cursor, value: boolean)
	Flare.writeu8(c, if value then 1 else 0)
end

function Flare.writestring(c: Cursor, value: string)
	local n = #value
	if n > 65535 then
		error("Flare string exceeds 65535 bytes")
	end
	ensure(c, 2 + n)
	writeu16(c.buf, c.offset, n)
	writestring(c.buf, c.offset + 2, value)
	c.offset += 2 + n
end

function Flare.writeVector3(c: Cursor, value: Vector3)
	ensure(c, 12)
	writef32(c.buf, c.offset, value.X)
	writef32(c.buf, c.offset + 4, value.Y)
	writef32(c.buf, c.offset + 8, value.Z)
	c.offset += 12
end

function Flare.writeVector2(c: Cursor, value: Vector2)
	ensure(c, 8)
	writef32(c.buf, c.offset, value.X)
	writef32(c.buf, c.offset + 4, value.Y)
	c.offset += 8
end

function Flare.writeCFrame(c: Cursor, value: CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
	ensure(c, 48)
	writef32(c.buf, c.offset, x)
	writef32(c.buf, c.offset + 4, y)
	writef32(c.buf, c.offset + 8, z)
	writef32(c.buf, c.offset + 12, r00)
	writef32(c.buf, c.offset + 16, r01)
	writef32(c.buf, c.offset + 20, r02)
	writef32(c.buf, c.offset + 24, r10)
	writef32(c.buf, c.offset + 28, r11)
	writef32(c.buf, c.offset + 32, r12)
	writef32(c.buf, c.offset + 36, r20)
	writef32(c.buf, c.offset + 40, r21)
	writef32(c.buf, c.offset + 44, r22)
	c.offset += 48
end

function Flare.writeColor3(c: Cursor, value: Color3)
	ensure(c, 3)
	writeu8(c.buf, c.offset, math.floor(value.R * 255 + 0.5))
	writeu8(c.buf, c.offset + 1, math.floor(value.G * 255 + 0.5))
	writeu8(c.buf, c.offset + 2, math.floor(value.B * 255 + 0.5))
	c.offset += 3
end

function Flare.writeUDim(c: Cursor, value: UDim)
	ensure(c, 8)
	writef32(c.buf, c.offset, value.Scale)
	writei32(c.buf, c.offset + 4, value.Offset)
	c.offset += 8
end

function Flare.writeUDim2(c: Cursor, value: UDim2)
	Flare.writeUDim(c, value.X)
	Flare.writeUDim(c, value.Y)
end

function Flare.writeBrickColor(c: Cursor, value: BrickColor)
	Flare.writeu16(c, value.Number)
end

function Flare.writebuffer(c: Cursor, value: buffer)
	local n = bufferLen(value)
	if n > 65535 then
		error("Flare buffer exceeds 65535 bytes")
	end
	ensure(c, 2 + n)
	writeu16(c.buf, c.offset, n)
	bufferCopy(c.buf, c.offset + 2, value, 0, n)
	c.offset += 2 + n
end

function Flare.writeInstance(c: Cursor, value: Instance?)
	local slot = c.index
	if slot > 65535 then
		error("Flare instance slot exceeds 65535")
	end
	c.instances[slot] = value :: Instance
	c.index = slot + 1
	Flare.writeu16(c, slot)
end

function Flare.readu8(c: Cursor): number
	local value = readu8(c.buf, c.offset)
	c.offset += 1
	return value
end

function Flare.readu16(c: Cursor): number
	local value = readu16(c.buf, c.offset)
	c.offset += 2
	return value
end

function Flare.readu32(c: Cursor): number
	local value = readu32(c.buf, c.offset)
	c.offset += 4
	return value
end

function Flare.readi8(c: Cursor): number
	local value = readi8(c.buf, c.offset)
	c.offset += 1
	return value
end

function Flare.readi16(c: Cursor): number
	local value = readi16(c.buf, c.offset)
	c.offset += 2
	return value
end

function Flare.readi32(c: Cursor): number
	local value = readi32(c.buf, c.offset)
	c.offset += 4
	return value
end

function Flare.readf32(c: Cursor): number
	local value = readf32(c.buf, c.offset)
	c.offset += 4
	return value
end

function Flare.readf64(c: Cursor): number
	local value = readf64(c.buf, c.offset)
	c.offset += 8
	return value
end

function Flare.readbool(c: Cursor): boolean
	return Flare.readu8(c) == 1
end

function Flare.readstring(c: Cursor): string
	local n = readu16(c.buf, c.offset)
	local value = readstring(c.buf, c.offset + 2, n)
	c.offset += 2 + n
	return value
end

function Flare.readVector3(c: Cursor): Vector3
	local x = readf32(c.buf, c.offset)
	local y = readf32(c.buf, c.offset + 4)
	local z = readf32(c.buf, c.offset + 8)
	c.offset += 12
	return Vector3.new(x, y, z)
end

function Flare.readVector2(c: Cursor): Vector2
	local x = readf32(c.buf, c.offset)
	local y = readf32(c.buf, c.offset + 4)
	c.offset += 8
	return Vector2.new(x, y)
end

function Flare.readCFrame(c: Cursor): CFrame
	local x = readf32(c.buf, c.offset)
	local y = readf32(c.buf, c.offset + 4)
	local z = readf32(c.buf, c.offset + 8)
	local r00 = readf32(c.buf, c.offset + 12)
	local r01 = readf32(c.buf, c.offset + 16)
	local r02 = readf32(c.buf, c.offset + 20)
	local r10 = readf32(c.buf, c.offset + 24)
	local r11 = readf32(c.buf, c.offset + 28)
	local r12 = readf32(c.buf, c.offset + 32)
	local r20 = readf32(c.buf, c.offset + 36)
	local r21 = readf32(c.buf, c.offset + 40)
	local r22 = readf32(c.buf, c.offset + 44)
	c.offset += 48
	return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

function Flare.readColor3(c: Cursor): Color3
	local r = readu8(c.buf, c.offset)
	local g = readu8(c.buf, c.offset + 1)
	local b = readu8(c.buf, c.offset + 2)
	c.offset += 3
	return Color3.fromRGB(r, g, b)
end

function Flare.readUDim(c: Cursor): UDim
	local scale = readf32(c.buf, c.offset)
	local offset = readi32(c.buf, c.offset + 4)
	c.offset += 8
	return UDim.new(scale, offset)
end

function Flare.readUDim2(c: Cursor): UDim2
	return UDim2.new(Flare.readUDim(c), Flare.readUDim(c))
end

function Flare.readBrickColor(c: Cursor): BrickColor
	return BrickColor.new(Flare.readu16(c))
end

function Flare.readbuffer(c: Cursor): buffer
	local n = readu16(c.buf, c.offset)
	local copy = bufferCreate(n)
	bufferCopy(copy, 0, c.buf, c.offset + 2, n)
	c.offset += 2 + n
	return copy
end

function Flare.readInstance(c: Cursor): Instance?
	local slot = Flare.readu16(c)
	return c.instances[slot]
end

local function remotes(host: ModuleScript)
	local folder = host:FindFirstChild("Remotes")
	if folder and folder:IsA("Folder") then
		return folder
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		local reliable = Instance.new("RemoteEvent")
		reliable.Name = "Reliable"
		reliable.Parent = created
		local unreliable = Instance.new("UnreliableRemoteEvent")
		unreliable.Name = "Unreliable"
		unreliable.Parent = created
		local invoke = Instance.new("RemoteFunction")
		invoke.Name = "Invoke"
		invoke.Parent = created
		created.Parent = host
		return created
	end
	return host:WaitForChild("Remotes") :: Folder
end

local function packBatch(queue: { Queued }): (buffer, { Instance }, number)
	local instances = {}
	local instn = 0
	local size = 2
	for _, item in queue do
		size += 1 + 2 + item.cursor.offset
		local n = instanceCount(item.cursor)
		for i = 1, n do
			instn += 1
			instances[instn] = item.cursor.instances[i]
		end
	end
	if #queue > 65535 then
		error("Flare batch exceeds 65535 packets")
	end
	local buf = bufferCreate(size)
	writeu16(buf, 0, #queue)
	local offset = 2
	for _, item in queue do
		if item.cursor.offset > 65535 then
			error("Flare packet exceeds 65535 bytes")
		end
		writeu8(buf, offset, item.id)
		writeu16(buf, offset + 1, item.cursor.offset)
		bufferCopy(buf, offset + 3, item.cursor.buf, 0, item.cursor.offset)
		offset += 3 + item.cursor.offset
	end
	return buf, instances, instn
end

local function fireRemote(remote: Instance, isServer: boolean, player: Player?, buf: buffer, instances: { Instance }, count: number)
	if isServer then
		if player then
			(remote :: RemoteEvent):FireClient(player, buf, table.unpack(instances, 1, count))
		else
			(remote :: RemoteEvent):FireAllClients(buf, table.unpack(instances, 1, count))
		end
	else
		(remote :: RemoteEvent):FireServer(buf, table.unpack(instances, 1, count))
	end
end

function Flare.open(host: ModuleScript)
	local folder = remotes(host)
	local reliable = folder:WaitForChild("Reliable") :: RemoteEvent
	local unreliable = folder:WaitForChild("Unreliable") :: UnreliableRemoteEvent
	local invoke = folder:WaitForChild("Invoke") :: RemoteFunction
	local isServer = RunService:IsServer()

	local packetById: { [number]: PacketSpec } = {}
	local queryById: { [number]: QuerySpec } = {}
	local listeners: { [number]: { (any) -> () } } = {}
	local queryHandlers: { [number]: (any) -> any } = {}

	local clientQueueR: { Queued } = {}
	local clientQueueU: { Queued } = {}
	local serverQueueR: { [Player]: { Queued } } = {}
	local serverQueueU: { [Player]: { Queued } } = {}
	local broadcastR: { Queued } = {}
	local broadcastU: { Queued } = {}

	local function queueFor(reliableFlag: boolean, player: Player?): { Queued }
		if isServer then
			if player then
				local map = if reliableFlag then serverQueueR else serverQueueU
				local list = map[player]
				if not list then
					list = {}
					map[player] = list
				end
				return list
			end
			return if reliableFlag then broadcastR else broadcastU
		end
		return if reliableFlag then clientQueueR else clientQueueU
	end

	local function flushList(remote: Instance, list: { Queued }, player: Player?)
		if #list == 0 then
			return
		end
		local buf, instances, instn = packBatch(list)
		table.clear(list)
		fireRemote(remote, isServer, player, buf, instances, instn)
	end

	local function forgetPlayer(player: Player)
		serverQueueR[player] = nil
		serverQueueU[player] = nil
	end

	local function callListener(cb: (any) -> (), player: Player?, ...)
		if player then
			cb(player, ...)
		else
			cb(...)
		end
	end

	local function callHandler(handler: (any) -> any, player: Player, ...)
		return handler(player, ...)
	end

	local function dispatch(fromPlayer: Player?, buf: buffer, instances: { Instance })
		if fromPlayer then
			if typeof(buf) ~= "buffer" then
				Ward.Strike(fromPlayer, "flare:type")
				return
			end
			if not Ward.Packet(fromPlayer, buffer.len(buf)) then
				return
			end
			if not Ward.Allow(fromPlayer, "flare", 60, 120) then
				return
			end
		end
		local ok = pcall(function()
			local incoming = fromBuffer(buf, instances)
			local count = Flare.readu16(incoming)
			if count > 64 then
				if fromPlayer then
					Ward.Strike(fromPlayer, "flare:batch")
				end
				return
			end
			for _ = 1, count do
				local id = Flare.readu8(incoming)
				local size = Flare.readu16(incoming)
				if size > Ward.MaxPacketBytes then
					if fromPlayer then
						Ward.Strike(fromPlayer, "flare:size")
					end
					return
				end
				local payload = bufferCreate(size)
				bufferCopy(payload, 0, incoming.buf, incoming.offset, size)
				incoming.offset += size
				local spec = packetById[id]
				local cbs = listeners[id]
				if spec and fromPlayer and spec.from ~= "client" then
					Ward.Strike(fromPlayer, "flare:dir")
					continue
				end
				if spec and cbs then
					local inner = fromBuffer(payload, instances)
					local values = table.pack(spec.read(inner))
					for _, cb in cbs do
						callListener(cb, fromPlayer, table.unpack(values, 1, values.n))
					end
				end
			end
		end)
		if not ok and fromPlayer then
			Ward.Strike(fromPlayer, "flare:decode")
		end
	end

	if isServer then
		reliable.OnServerEvent:Connect(function(player: Player, buf: buffer, ...: Instance)
			dispatch(player, buf, table.pack(...) :: any)
		end)
		unreliable.OnServerEvent:Connect(function(player: Player, buf: buffer, ...: Instance)
			dispatch(player, buf, table.pack(...) :: any)
		end)
		invoke.OnServerInvoke = function(player: Player, buf: buffer, ...: Instance)
			if typeof(buf) ~= "buffer" then
				Ward.Strike(player, "flare:query-type")
				return bufferCreate(0)
			end
			if not Ward.Packet(player, buffer.len(buf)) then
				return bufferCreate(0)
			end
			if not Ward.Allow(player, "flare:query", 10, 20) then
				return bufferCreate(0)
			end
			local packedInstances = table.pack(...) :: any
			local results = table.pack(pcall(function()
				local incoming = fromBuffer(buf, packedInstances)
				local id = Flare.readu8(incoming)
				local spec = queryById[id]
				local handler = queryHandlers[id]
				if not spec or not handler then
					return bufferCreate(0)
				end
				local result = callHandler(handler, player, spec.readReq(incoming))
				local out = spec.writeRes(cursor(16), result)
				return sliceCursor(out), table.unpack(out.instances, 1, instanceCount(out))
			end))
			if results[1] ~= true then
				Ward.Strike(player, "flare:query-decode")
				return bufferCreate(0)
			end
			return table.unpack(results, 2, results.n)
		end
		Players.PlayerRemoving:Connect(forgetPlayer)
	else
		reliable.OnClientEvent:Connect(function(buf: buffer, ...: Instance)
			dispatch(nil, buf, table.pack(...) :: any)
		end)
		unreliable.OnClientEvent:Connect(function(buf: buffer, ...: Instance)
			dispatch(nil, buf, table.pack(...) :: any)
		end)
	end

	RunService.Heartbeat:Connect(function()
		if isServer then
			flushList(reliable, broadcastR, nil)
			flushList(unreliable, broadcastU, nil)
			for player, list in serverQueueR do
				flushList(reliable, list, player)
				serverQueueR[player] = nil
			end
			for player, list in serverQueueU do
				flushList(unreliable, list, player)
				serverQueueU[player] = nil
			end
		else
			flushList(reliable, clientQueueR, nil)
			flushList(unreliable, clientQueueU, nil)
		end
	end)

	local session = {}

	function session.packet(spec: PacketSpec)
		packetById[spec.id] = spec
		local api = {}
		local remote = if spec.reliable then reliable else unreliable

		local function enqueue(player: Player?, ...)
			local written = spec.write(cursor(32), ...)
			local item = { id = spec.id, cursor = written }
			if instanceCount(written) > 0 then
				flushList(remote, { item }, player)
				return
			end
			table.insert(queueFor(spec.reliable, player), item)
		end

		if spec.from == "client" then
			function api.FireServer(...)
				assert(not isServer, "FireServer is client-only")
				enqueue(nil, ...)
			end
		else
			function api.Fire(player: Player, ...)
				assert(isServer, "Fire is server-only")
				enqueue(player, ...)
			end
			function api.FireAll(...)
				assert(isServer, "FireAll is server-only")
				enqueue(nil, ...)
			end
		end

		function api.Connect(callback: (any) -> ()): RBXScriptConnection
			local list = listeners[spec.id]
			if not list then
				list = {}
				listeners[spec.id] = list
			end
			table.insert(list, callback)
			return {
				Connected = true,
				Disconnect = function(self)
					self.Connected = false
					local i = table.find(list, callback)
					if i then
						table.remove(list, i)
					end
				end,
			} :: any
		end

		return api
	end

	function session.query(spec: QuerySpec)
		queryById[spec.id] = spec
		local api = {}

		function api.Invoke(...)
			if isServer then
				error("query.Invoke is client-only")
			end
			local out = spec.writeReq(cursor(32), ...)
			local buf = bufferCreate(1 + out.offset)
			writeu8(buf, 0, spec.id)
			bufferCopy(buf, 1, out.buf, 0, out.offset)
			local packed = table.pack(invoke:InvokeServer(buf, table.unpack(out.instances, 1, instanceCount(out))))
			local reply = packed[1]
			local instances = {}
			for i = 2, packed.n do
				instances[i - 1] = packed[i]
			end
			if typeof(reply) ~= "buffer" then
				return nil
			end
			return spec.readRes(fromBuffer(reply :: buffer, instances :: { Instance }))
		end

		function api.On(callback: (any) -> any)
			assert(isServer, "query.On is server-only")
			queryHandlers[spec.id] = callback
		end

		return api
	end

	return session
end

return Flare
