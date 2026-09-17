const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

assert(RunService:IsServer(), "DataService.Server may only be required on the server")

local packages = script.Parent.Packages

const Janitor = require(script.Parent.Parent.Janitor)
const Signal = require(packages.signal)

const Data = require(script.Parent.Data)
const Enums = require(script.Parent.Enums)
const Path = require(script.Parent.Path)
const ProfileStore = require(script.Parent.ProfileStore)
const Replicator = require(script.Parent.Replicator).Server

type DataPath = Path.Path
type JanitorT = typeof(Janitor.new())

const DEFAULT_KEY_PREFIX = "Player_"

export type Options<T> = {
	Template: T,
	StoreName: string?,
	UseMock: boolean?,
	KeyPrefix: string?,
	Exclude: { DataPath }?,
	StrictPaths: boolean?,
	AutoCreateMissingTables: boolean?,
}

--[=[
	@interface InitOptions
	@within DataServiceServer
	.Template any -- Default player data template (required).
	.StoreName string? -- ProfileStore name. Default: `"PlayerData"`.
	.UseMock boolean? -- Use mock ProfileStore (no real DataStore).
	.KeyPrefix string? -- Profile key prefix before UserId. Default: `"Player_"`.
	.Exclude { Path }? -- Paths that must not replicate to the client.
	.StrictPaths boolean? -- Block writes to invalid paths. Default: `true`.
	.AutoCreateMissingTables boolean? -- Auto-create missing nested tables. Default: `false`.
]=]
export type ServerApi<T> = {
	Init: (self: ServerApi<T>, options: Options<T>) -> ServerApi<T>,
	WaitFor: (self: ServerApi<T>, player: Player) -> Data.Data<T>,
	Get: (self: ServerApi<T>, player: Player) -> Data.Data<T>?,
	HasData: (self: ServerApi<T>, player: Player) -> boolean,
	GetProfile: (self: ServerApi<T>, player: Player) -> ProfileStore.Profile<T>?,
	GetBufferStats: (self: ServerApi<T>, player: Player?) -> ReplicatorBufferStats?,
	Destroy: (self: ServerApi<T>) -> (),
	Paths: Path.PathTree<T>,
}
-- Alias util para documentar o retorno tipado de Init.
export type ServerApiFor<T> = ServerApi<T>

type ReplicatorBufferStats = {
	Bytes: number,
	Messages: number,
	LastPacketBytes: number,
	LastUtilization: number,
}

const Server = {
	_initialized = false,
	_options = nil,
	_janitor = nil :: JanitorT?,
	_store = nil,
	_data = {} :: { [Player]: Data.Data<never> },
	_profiles = {} :: { [Player]: ProfileStore.Profile<never> },
	_playerJanitors = {} :: { [Player]: JanitorT },
	_waitSignals = {} :: { [Player]: typeof(Signal.new()) },
	_ready = {} :: { [Player]: boolean },
	_excluded = {} :: { [string]: boolean },
	Paths = nil :: Path.PathTree<never>?,
}

const isExcluded = function(self, path: DataPath?): boolean
	if not path or #path == 0 then
		return false
	end
	for i = 1, #path do
		local prefix = table.create(i)
		for j = 1, i do
			prefix[j] = path[j]
		end
		if self._excluded[Path.toKey(prefix)] then
			return true
		end
	end
	return false
end

local function buildSnapshot(self, value: any, prefix: DataPath): any
	if isExcluded(self, prefix) then
		return nil
	end
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		local newPath = table.clone(prefix)
		newPath[#newPath + 1] = k
		if not isExcluded(self, newPath) then
			out[k] = buildSnapshot(self, v, newPath)
		end
	end
	return out
end

--[=[
	@method Init
	@within DataServiceServer
	@param options InitOptions
	@tag Lifecycle
	Initializes the server singleton. Call once at boot.

	```lua
	DataServiceServer:Init({
		Template = DataTemplate,
		StoreName = "PlayerDataV2",
		StrictPaths = true,
	})
	```
]=]
function Server:Init<T>(options: Options<T>)
	assert(not self._initialized, "DataService.Server already initialized")
	assert(options and options.Template, "DataService.Server:Init requires options.Template")
	self._initialized = true
	self._options = options
	self._janitor = Janitor.new()
	self.Paths = Path.createTemplatePaths(options.Template)

	local store = ProfileStore.New(options.StoreName or "PlayerData", options.Template :: any)
	self._store = if options.UseMock then store.Mock else store

	self._excluded = {}
	local excludes = options.Exclude
	if excludes then
		for _, p in excludes do
			self._excluded[Path.toKey(p)] = true
		end
	end

	local onReadyConnection = Replicator.OnReady:Connect(function(player)
		self._ready[player] = true
		if self._data[player] then
			self:_sendInit(player)
		end
	end)
	self._janitor:Add(function()
		onReadyConnection:Disconnect()
	end, true)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_playerAdded(player)
		end)
	end
	self._janitor:Add(Players.PlayerAdded:Connect(function(p)
		self:_playerAdded(p)
	end), "Disconnect")
	self._janitor:Add(Players.PlayerRemoving:Connect(function(p)
		self:_playerRemoving(p)
	end), "Disconnect")
end

function Server:_profileKey(player: Player): string
	local opts: any = self._options
	return (opts.KeyPrefix or DEFAULT_KEY_PREFIX) .. tostring(player.UserId)
end

function Server:_playerAdded(player: Player)
	if self._playerJanitors[player] then
		self._playerJanitors[player]:Cleanup()
	end
	local playerJanitor = Janitor.new()
	self._playerJanitors[player] = playerJanitor

	local key = self:_profileKey(player)
	local profile = self._store:StartSessionAsync(key, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Data load failed - please rejoin")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	local sessionEndConnection = profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		if player.Parent then
			player:Kick("Data session ended - please rejoin")
		end
	end)
	playerJanitor:Add(function()
		sessionEndConnection:Disconnect()
	end, true)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	self._profiles[player] = profile
	local data = Data.new(profile.Data, true, {
		StrictPaths = if self._options and self._options.StrictPaths ~= nil then self._options.StrictPaths else true,
		AutoCreateMissingTables = if self._options and self._options.AutoCreateMissingTables ~= nil then self._options.AutoCreateMissingTables else false,
		Template = if self._options then self._options.Template else profile.Data,
	})
	self._data[player] = data

	local dataChangedConnection = data.Changed:Connect(function(action, path, ...)
		if not self._ready[player] then
			return
		end
		if isExcluded(self, path) then
			return
		end
		Replicator:Send(player, action, path, ...)
	end)
	playerJanitor:Add(function()
		dataChangedConnection:Disconnect()
	end, true)

	local sig = self._waitSignals[player]
	if sig then
		sig:Fire()
		sig:Destroy()
		self._waitSignals[player] = nil
	end

	if self._ready[player] then
		self:_sendInit(player)
	end
end

function Server:_sendInit(player: Player)
	local data = self._data[player]
	if not data then
		return
	end
	local snapshot = buildSnapshot(self, data:Get(), {})
	Replicator:Send(player, Enums.Init, nil, snapshot)
end

function Server:_playerRemoving(player: Player)
	local playerJanitor = self._playerJanitors[player]
	if playerJanitor then
		playerJanitor:Cleanup()
		self._playerJanitors[player] = nil
	end

	local data = self._data[player]
	if data then
		data:Destroy()
		self._data[player] = nil
	end

	local profile = self._profiles[player]
	if profile then
		profile:EndSession()
		self._profiles[player] = nil
	end

	Replicator:ForgetPlayer(player)

	self._ready[player] = nil

	local sig = self._waitSignals[player]
	if sig then
		sig:Destroy()
		self._waitSignals[player] = nil
	end
end

--[=[
	@method WaitFor
	@within DataServiceServer
	@yields
	@param player Player
	@return Data
	Yields until player data is loaded and returns the `Data` instance.
]=]
function Server:WaitFor<T>(player: Player): Data.Data<T>
	if self._data[player] then
		return self._data[player]
	end
	if not player:IsDescendantOf(Players) then
		error("DataService.Server:WaitFor called for a player that is not in Players")
	end
	local sig = self._waitSignals[player]
	if not sig then
		sig = Signal.new()
		self._waitSignals[player] = sig
	end
	sig:Wait()
	local loaded = self._data[player]
	assert(loaded ~= nil, "DataService.Server: player data was not available after wait")
	return loaded :: Data.Data<T>
end

--[=[
	@method Get
	@within DataServiceServer
	@param player Player
	@return Data?
	Returns player data if already loaded, otherwise `nil`.
]=]
function Server:Get(player: Player) 
	return self._data[player]
end

--[=[
	@method HasData
	@within DataServiceServer
	@param player Player
	@return boolean
	Whether the player session has finished loading.
]=]
function Server:HasData(player: Player): boolean
	return self._data[player] ~= nil
end

--[=[
	@method GetProfile
	@within DataServiceServer
	@param player Player
	@return Profile?
	Returns the underlying ProfileStore profile.
]=]
function Server:GetProfile(player: Player): any
	return self._profiles[player]
end

--[=[
	@method Destroy
	@within DataServiceServer
	Cleans up sessions, profiles, and service connections.
]=]
function Server:Destroy()
	for player in self._data do
		self:_playerRemoving(player)
	end
	if self._janitor then
		self._janitor:Cleanup()
		self._janitor = nil
	end
	Replicator:Destroy()
end

--[=[
	@class DataServiceServer
	Server singleton. Access via `require(Packages.dataservicev2).Server`.
	After `Init`, use `.Paths` for typed template paths.
]=]
local PublicServer: ServerApi<never>
PublicServer = {
	Init = function<T>(self: ServerApi<T>, options: Options<T>): ServerApi<T>
		Server:Init(options)
		self.Paths = Server.Paths
		return self :: ServerApi<T>
	end,
	WaitFor = function<T>(_, player: Player): Data.Data<T>
		return Server:WaitFor(player)
	end,
	Get = function<T>(_, player: Player): Data.Data<T>?
		return Server:Get(player)
	end,
	HasData = function(_, player: Player): boolean
		return Server:HasData(player)
	end,
	GetProfile = function(_, player: Player)
		return Server:GetProfile(player)
	end,
	GetBufferStats = function(_, player: Player?)
		return Replicator:GetBufferStats(player)
	end,
	Destroy = function(_)
		Server:Destroy()
	end,
	Paths = Path.rootToken(),
}

--[=[
	@method GetBufferStats
	@within DataServiceServer
	@param player Player?
	@return table?
	Returns QuickNet replication buffer metrics.
]=]

--[=[
	@prop Paths PathTree
	@within DataServiceServer
	Typed path tree. Available after `Init`.
]=]

setmetatable(PublicServer, {
	__index = function(_, key)
		if key == "Paths" then
			return Server.Paths
		end
		return nil
	end,
})

return PublicServer
