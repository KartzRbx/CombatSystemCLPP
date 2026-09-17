--!strict
-- Cluaupp DataService — typed Path tokens on the public border.
-- Engine: KartzRbx/dataservicev2 (Server / Client / Data / Path).
-- Cleanup uses the sibling CluauppLibs.Janitor, never Packages.janitor.

--[=[
	@class DataService
	ProfileStore persistence, typed Paths, and Data signals (`GetChangedSignal`, …).
]=]

local RunService = game:GetService("RunService")

local Path = require(script.Path)
local Data = require(script.Data)
local EnumModule = require(script.Enum)

export type Path<V = unknown> = Path.PathToken<V>
export type PathArray = Path.Path
export type PathLike<V = unknown> = Path<V> | PathArray
export type PathTree<T> = Path.PathTree<T>
export type Data<T> = Data.Data<T>
export type OrderedListOptions = Data.OrderedListOptions
export type OrderedListEntry<V> = Data.OrderedListEntry<V>
export type DataBufferStats = {
	Bytes: number,
	Messages: number,
	LastPacketBytes: number,
	LastUtilization: number,
}

export type ServerApi<T> = {
	Init: (
		self: ServerApi<T>,
		options: {
			Template: T,
			StoreName: string?,
			UseMock: boolean?,
			KeyPrefix: string?,
			Exclude: { PathArray }?,
			StrictPaths: boolean?,
			AutoCreateMissingTables: boolean?,
		}
	) -> ServerApi<T>,
	WaitFor: (self: ServerApi<T>, player: Player) -> Data<T>,
	Get: (self: ServerApi<T>, player: Player) -> Data<T>?,
	HasData: (self: ServerApi<T>, player: Player) -> boolean,
	GetProfile: (self: ServerApi<T>, player: Player) -> unknown?,
	GetBufferStats: (self: ServerApi<T>, player: Player?) -> DataBufferStats?,
	Destroy: (self: ServerApi<T>) -> (),
	Paths: PathTree<T>,
}

export type ClientApi<T> = {
	Init: (self: ClientApi<T>) -> Data<T>,
	WaitForData: (self: ClientApi<T>) -> Data<T>,
	Get: (self: ClientApi<T>) -> Data<T>?,
	GetBufferStats: (self: ClientApi<T>) -> DataBufferStats?,
	Destroy: (self: ClientApi<T>) -> (),
	Paths: PathTree<T>,
}

local function createUnavailableContext(contextName: string)
	local rootPaths = Path.rootToken()

	return {
		Init = function()
			error(`DataService.{contextName}:Init is not available in this runtime context`, 2)
		end,
		WaitFor = function()
			error(`DataService.{contextName}:WaitFor is not available in this runtime context`, 2)
		end,
		WaitForData = function()
			error(`DataService.{contextName}:WaitForData is not available in this runtime context`, 2)
		end,
		Get = function()
			error(`DataService.{contextName}:Get is not available in this runtime context`, 2)
		end,
		HasData = function()
			error(`DataService.{contextName}:HasData is not available in this runtime context`, 2)
		end,
		GetProfile = function()
			error(`DataService.{contextName}:GetProfile is not available in this runtime context`, 2)
		end,
		GetBufferStats = function()
			return nil
		end,
		Destroy = function() end,
		Paths = rootPaths,
	}
end

local DataService = {
	Paths = Path.rootToken(),
	Enum = EnumModule,
	Server = nil :: ServerApi<unknown>?,
	Client = nil :: ClientApi<unknown>?,
}

if RunService:IsServer() then
	DataService.Server = require(script.Server) :: ServerApi<unknown>
	DataService.Client = createUnavailableContext("Client") :: ClientApi<unknown>
	DataService.Paths = DataService.Server.Paths
else
	DataService.Client = require(script.Client) :: ClientApi<unknown>
	DataService.Server = createUnavailableContext("Server") :: ServerApi<unknown>
	DataService.Paths = DataService.Client.Paths
end

local function sessionOf(player: Player?): Data<unknown>?
	if RunService:IsServer() then
		if player == nil or DataService.Server == nil then
			return nil
		end
		return DataService.Server:Get(player)
	end
	if DataService.Client == nil then
		return nil
	end
	return DataService.Client:Get()
end

function DataService.Get<V>(player: Player, path: PathLike<V>): V?
	local data = sessionOf(player)
	if data == nil then
		return nil
	end
	return data:Get(path) :: V
end

function DataService.GetPersisted<V>(player: Player, path: PathLike<V>): V?
	local data = sessionOf(player)
	if data == nil then
		return nil
	end
	return data:GetPersisted(path) :: V
end

function DataService.Set<V>(player: Player, path: PathLike<V>, value: V)
	local data = sessionOf(player)
	if data then
		data:Set(path, value)
	end
end

function DataService.SetTransient<V>(player: Player, path: PathLike<V>, value: V)
	local data = sessionOf(player)
	if data then
		data:SetTransient(path, value)
	end
end

function DataService.UpdateTransient<V>(player: Player, path: PathLike<V>, value: V)
	local data = sessionOf(player)
	if data then
		data:UpdateTransient(path, function()
			return value
		end)
	end
end

function DataService.ClearTransient(player: Player, path: PathLike<unknown>)
	local data = sessionOf(player)
	if data then
		data:ClearTransient(path)
	end
end

function DataService.GetOrderedList<V>(player: Player, path: PathLike<{ V }>): { Data.OrderedListEntry<V> }?
	local data = sessionOf(player)
	if data == nil then
		return nil
	end
	return data:GetOrderedList(path, { key = "Priority" })
end

function DataService.GetOrderedListWithPriority<V>(player: Player, path: PathLike<{ V }>): { Data.OrderedListEntry<V> }?
	local data = sessionOf(player)
	if data == nil then
		return nil
	end
	return data:GetOrderedListWithPriority(path, "Priority")
end

function DataService.WaitFor<T>(player: Player): Data<T>
	if RunService:IsServer() then
		assert(DataService.Server, "DataService.Server is unavailable")
		return DataService.Server:WaitFor(player) :: Data<T>
	end
	assert(DataService.Client, "DataService.Client is unavailable")
	return DataService.Client:WaitForData() :: Data<T>
end

function DataService.Observe<V>(
	player: Player,
	path: PathLike<V>,
	callback: (newValue: V, oldValue: V) -> ()
): RBXScriptConnection
	local data = DataService.WaitFor(player)
	return data:GetChangedSignal(path):Connect(callback)
end

export type DataService = typeof(DataService)

return DataService
