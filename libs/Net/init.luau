--!strict
--[=[
	@class Net
	Buffer-packed RemoteEvent / RemoteFunction. Public API is generic; the codec is internal.
]=]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local codec = require(script.src.codec)

export type Event<T...> = {
	Fire: (self: Event<T...>, player: Player, T...) -> (),
	FireAll: (self: Event<T...>, T...) -> (),
	FireServer: (self: Event<T...>, T...) -> (),
	On: (self: Event<T...>, callback: (Player?, T...) -> ()) -> RBXScriptConnection,
}

export type Function<R, T...> = {
	On: (self: Function<R, T...>, callback: (Player?, T...) -> R) -> (),
	Invoke: (self: Function<R, T...>, player: Player, T...) -> R,
	InvokeServer: (self: Function<R, T...>, T...) -> R,
}

local function folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("CluauppNet")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "CluauppNet"
	created.Parent = ReplicatedStorage
	return created
end

local function remote(kind: "RemoteEvent" | "RemoteFunction", name: string): Instance
	local parent = folder()
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local inst = Instance.new(kind)
		inst.Name = name
		inst.Parent = parent
		return inst
	end
	return parent:WaitForChild(name)
end

local Event = {}
Event.__index = Event

function Event.new<T...>(name: string): Event<T...>
	return setmetatable({ _name = name, _remote = remote("RemoteEvent", name) :: RemoteEvent }, Event) :: Event<T...>
end

function Event:Fire<T...>(player: Player, ...: T...)
	assert(RunService:IsServer(), "Net.Event:Fire is server-only")
	self._remote:FireClient(player, codec.encode({ ... }))
end

function Event:FireAll<T...>(...: T...)
	assert(RunService:IsServer(), "Net.Event:FireAll is server-only")
	self._remote:FireAllClients(codec.encode({ ... }))
end

function Event:FireServer<T...>(...: T...)
	assert(RunService:IsClient(), "Net.Event:FireServer is client-only")
	self._remote:FireServer(codec.encode({ ... }))
end

function Event:On<T...>(callback: (Player?, T...) -> ()): RBXScriptConnection
	if RunService:IsServer() then
		return self._remote.OnServerEvent:Connect(function(player: Player, payload: buffer)
			callback(player, table.unpack(codec.decode(payload)))
		end)
	end
	return self._remote.OnClientEvent:Connect(function(payload: buffer)
		callback(nil, table.unpack(codec.decode(payload)))
	end)
end

local Fn = {}
Fn.__index = Fn

function Fn.new<R, T...>(name: string): Function<R, T...>
	return setmetatable({ _name = name, _remote = remote("RemoteFunction", name) :: RemoteFunction }, Fn) :: Function<R, T...>
end

function Fn:On<R, T...>(callback: (Player?, T...) -> R)
	if RunService:IsServer() then
		self._remote.OnServerInvoke = function(player: Player, payload: buffer)
			return codec.encode({ callback(player, table.unpack(codec.decode(payload))) })
		end
	else
		self._remote.OnClientInvoke = function(payload: buffer)
			return codec.encode({ callback(nil, table.unpack(codec.decode(payload))) })
		end
	end
end

function Fn:Invoke<R, T...>(player: Player, ...: T...): R
	assert(RunService:IsServer(), "Net.Function:Invoke is server-only")
	local reply = self._remote:InvokeClient(player, codec.encode({ ... }))
	return table.unpack(codec.decode(reply)) :: R
end

function Fn:InvokeServer<R, T...>(...: T...): R
	assert(RunService:IsClient(), "Net.Function:InvokeServer is client-only")
	local reply = self._remote:InvokeServer(codec.encode({ ... }))
	return table.unpack(codec.decode(reply)) :: R
end

local Net = {}

function Net.Event<T...>(name: string): Event<T...>
	return Event.new(name)
end

function Net.Function<R, T...>(name: string): Function<R, T...>
	return Fn.new(name)
end

export type Net = typeof(Net)

return Net
