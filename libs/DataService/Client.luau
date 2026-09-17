const RunService = game:GetService("RunService")

assert(RunService:IsClient(), "DataService.Client may only be required on the client")

local packages = script.Parent.Packages

const Janitor = require(script.Parent.Parent.Janitor)
const Signal = require(packages.signal)

const Data = require(script.Parent.Data)
const Enums = require(script.Parent.Enums)
const Path = require(script.Parent.Path)
const Replicator = require(script.Parent.Replicator).Client
type JanitorT = typeof(Janitor.new())
export type ClientApi<T> = {
	Init: (self: ClientApi<T>) -> Data.Data<T>,
	WaitForData: (self: ClientApi<T>) -> Data.Data<T>,
	Get: (self: ClientApi<T>) -> Data.Data<T>?,
	GetBufferStats: (self: ClientApi<T>) -> ClientBufferStats?,
	Destroy: (self: ClientApi<T>) -> (),
	Paths: Path.PathTree<T>,
}

type ClientBufferStats = {
	Bytes: number,
	Messages: number,
	LastPacketBytes: number,
	LastUtilization: number,
}

const Client = {
	_initialized = false,
	_data = nil :: Data.Data<never>?,
	Paths = nil :: Path.PathTree<never>?,
	_janitor = nil :: JanitorT?,
	_bufferStats = nil :: ClientBufferStats?,
	_loaded = Signal.new(),
}

--[=[
	@method Init
	@within DataServiceClient
	@yields
	@return Data
	Initializes the client and yields for the initial server snapshot.
]=]
function Client:Init()
	if not self._initialized then
		self._initialized = true
		self._janitor = Janitor.new()
		self._janitor:Add(self._loaded, "Destroy")
		local bufferChangedConnection = Replicator.BufferChanged:Connect(function(stats)
			self._bufferStats = stats
		end)
		self._janitor:Add(function()
			bufferChangedConnection:Disconnect()
		end, true)

		Replicator:On(Enums.Init, function(_path, snapshot)
			if self._data then
				self._data:Destroy()
			end
			self._data = Data.new(snapshot, false, {
				Template = snapshot,
			}) :: Data.Data<typeof(snapshot)>
			self.Paths = Path.createTemplatePaths(snapshot)
			self._loaded:Fire()
		end)

		Replicator:On(Enums.Set, function(path, value)
			if self._data then
				Data._applySet(self._data, path, value)
			end
		end)

		Replicator:On(Enums.ArrayInsert, function(path, value, index)
			if self._data then
				Data._applyArrayInsert(self._data, path, value, index)
			end
		end)

		Replicator:On(Enums.ArrayRemove, function(path, index)
			if self._data then
				Data._applyArrayRemove(self._data, path, index)
			end
		end)

		Replicator:On(Enums.SetTransient, function(path, value)
			if self._data then
				Data._applyTransientSet(self._data, path, value)
			end
		end)

		Replicator:On(Enums.ArrayInsertTransient, function(path, value, index)
			if self._data then
				Data._applyTransientArrayInsert(self._data, path, value, index)
			end
		end)

		Replicator:On(Enums.ArrayRemoveTransient, function(path, index)
			if self._data then
				Data._applyTransientArrayRemove(self._data, path, index)
			end
		end)

		Replicator:On(Enums.ClearTransient, function(path)
			if self._data then
				Data._applyTransientClear(self._data, path)
			end
		end)

		Replicator:NotifyReady()
	end

	return self:WaitForData()
end

--[=[
	@method WaitForData
	@within DataServiceClient
	@yields
	@return Data
	Yields until replicated data is available.
]=]
function Client:WaitForData<T>(): Data.Data<T>
	if self._data then
		return self._data :: Data.Data<T>
	end
	self._loaded:Wait()
	return self._data :: Data.Data<T>
end

--[=[
	@method Get
	@within DataServiceClient
	@return Data?
	Returns data if the snapshot was already received.
]=]
function Client:Get()
	return self._data
end

--[=[
	@method GetBufferStats
	@within DataServiceClient
	@return table?
	Returns QuickNet replication buffer metrics.
]=]
function Client:GetBufferStats()
	return self._bufferStats or Replicator:GetBufferStats()
end

--[=[
	@method Destroy
	@within DataServiceClient
	Cleans up client connections and listeners.
]=]
function Client:Destroy()
	if self._data then
		self._data:Destroy()
		self._data = nil
	end
	if self._janitor then
		self._janitor:Cleanup()
		self._janitor = nil
	end
	Replicator:Destroy()
end

--[=[
	@class DataServiceClient
	Client singleton. Access via `require(Packages.dataservicev2).Client`.
	Data is read-only — mutations must happen on the server.
]=]
const PublicClient: ClientApi<never> = {
	Init = function<T>(self: ClientApi<T>): Data.Data<T>
		return Client:Init() :: Data.Data<T>
	end,
	WaitForData = function<T>(self: ClientApi<T>): Data.Data<T>
		return Client:WaitForData() :: Data.Data<T>
	end,
	Get = function<T>(self: ClientApi<T>): Data.Data<T>?
		return Client:Get()
	end,
	GetBufferStats = function(_): ClientBufferStats?
		return Client:GetBufferStats()
	end,
	Destroy = function(_)
		Client:Destroy()
	end,
	Paths = Path.rootToken(),
}

--[=[
	@prop Paths PathTree
	@within DataServiceClient
	Typed path tree. Available after `Init`.
]=]

setmetatable(PublicClient, {
	__index = function(_, key)
		if key == "Paths" then
			return Client.Paths
		end
		return nil
	end,
})

return PublicClient
