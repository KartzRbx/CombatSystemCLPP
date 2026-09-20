--!strict
-- Compiled by CL++ — C++ × Luau

const Sweep = require(script.Parent.Parent.Sweep)
const Engine = require(script.Parent.Engine)

local DataServiceServer = {}

DataServiceServer.janitor = nil

DataServiceServer.initialized = nil

DataServiceServer.Paths = nil

DataServiceServer.options = nil

DataServiceServer.store = nil

DataServiceServer.sessions = nil

DataServiceServer.profiles = nil

DataServiceServer.sessionJanitors = nil

DataServiceServer.waiters = nil

DataServiceServer.ready = nil

DataServiceServer.excluded = nil

const DEFAULT_KEY_PREFIX: string = "Player_"

function DataServiceServer:Init(options: DataServiceOptions): DataServiceServer
	local runService: RunService = game:GetService("RunService")
	if runService:IsServer() == false then
		error("DataService.Server may only be used on the server")
		return self
	end
	if self.initialized then
		error("DataService.Server already initialized")
		return self
	end
	if not (options.Template ~= nil) then
		error("DataService.Server.Init requires options.Template")
		return self
	end
	self.initialized = true
	self.options = options
	self.janitor = Sweep.new()
	self.Paths = Engine:createTemplatePaths(options.Template)
	local storeName: string = "PlayerData"
	if options.StoreName ~= nil then
		storeName = options.StoreName
	end
	local created = Engine:profileStoreNew(storeName, options.Template)
	if options.UseMock then
		self.store = created.Mock
	else
		self.store = created
	end
	self.sessions = Engine:mapNew()
	self.profiles = Engine:mapNew()
	self.sessionJanitors = Engine:mapNew()
	self.waiters = Engine:mapNew()
	self.ready = Engine:mapNew()
	self.excluded = Engine:mapNew()
	local excludes: {DataPath} = options.Exclude
	if excludes ~= nil then
		for _, path in excludes do
			local key: string = Engine:toKey(path)
			Engine:mapSet(self.excluded, key, true)
		end
	end
	local players: Players = game:GetService("Players")
	self.janitor:Add(Engine.Replicator.OnReady:Connect(function(player: Player)
	Engine:mapSet(self.ready, player, true)
	if Engine:mapGet(self.sessions, player) ~= nil then
		self:SendInit(player)
	end
end), "Disconnect")
	for _, player in players:GetPlayers() do
		task.spawn(function()
			self:OnAdded(player)
		end)
	end
	self.janitor:Add(players.PlayerAdded:Connect(function(...) self:OnAdded(...) end), "Disconnect")
	self.janitor:Add(players.PlayerRemoving:Connect(function(...) self:OnRemoving(...) end), "Disconnect")
	return self
end

function DataServiceServer:ProfileKey(player: Player): string
	local prefix: string = self.options.KeyPrefix
	if prefix == nil then
		prefix = DEFAULT_KEY_PREFIX
	end
	return prefix .. tostring(player.UserId)
end

function DataServiceServer:SendInit(player: Player)
	local session: Data = Engine:mapGet(self.sessions, player)
	if not (session ~= nil) then
		return
	end
	local snapshot = Engine:buildSnapshot(self.excluded, session:Get(), Engine:emptyPath())
	Engine:replicatorSend(player, Engine.Enums.Init, nil, snapshot)
end

function DataServiceServer:OnAdded(player: Player)
	if not (player ~= nil) then
		return
	end
	local existingJanitor = Engine:mapGet(self.sessionJanitors, player)
	if existingJanitor ~= nil then
		existingJanitor:Cleanup()
	end
	local sessionJanitor = Sweep.new()
	Engine:mapSet(self.sessionJanitors, player, sessionJanitor)
	local players: Players = game:GetService("Players")
	local key: string = self:ProfileKey(player)
	local profile = Engine:startSession(self.store, key, player, players)
	if profile == nil then
		player:Kick("Data load failed - please rejoin")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	local sessionEndConnection = profile.OnSessionEnd:Connect(function()
	Engine:mapClear(self.profiles, player)
	if player.Parent ~= nil then
		player:Kick("Data session ended - please rejoin")
	end
end)
	sessionJanitor:Add(function()
	sessionEndConnection:Disconnect()
end, true)
	if player:IsDescendantOf(players) == false then
		Engine:abortActiveTrade(profile)
		profile:EndSession()
		return
	end
	Engine:mapSet(self.profiles, player, profile)
	local strictPaths: boolean = true
	if self.options.StrictPaths == false then
		strictPaths = false
	end
	local autoCreate: boolean = false
	if self.options.AutoCreateMissingTables then
		autoCreate = true
	end
	local tmpl = self.options.Template
	if tmpl == nil then
		tmpl = profile.Data
	end
	local session: Data = Engine:dataNew(profile.Data, true, strictPaths, autoCreate, tmpl)
	Engine:mapSet(self.sessions, player, session)
	local dataChangedConnection = Engine:watchData(session, player, self.ready, self.excluded)
	sessionJanitor:Add(function()
	dataChangedConnection:Disconnect()
end, true)
	local sig = Engine:mapGet(self.waiters, player)
	if sig ~= nil then
		sig:Fire()
		sig:Destroy()
		Engine:mapClear(self.waiters, player)
	end
	if Engine:mapGet(self.ready, player) then
		self:SendInit(player)
	end
end

function DataServiceServer:OnRemoving(player: Player)
	local sessionJanitor = Engine:mapGet(self.sessionJanitors, player)
	if sessionJanitor ~= nil then
		sessionJanitor:Cleanup()
		Engine:mapClear(self.sessionJanitors, player)
	end
	local session: Data = Engine:mapGet(self.sessions, player)
	if session ~= nil then
		session:Destroy()
		Engine:mapClear(self.sessions, player)
	end
	local profile = Engine:mapGet(self.profiles, player)
	if profile ~= nil then
		Engine:abortActiveTrade(profile)
		profile:EndSession()
		Engine:mapClear(self.profiles, player)
	end
	Engine:replicatorForgetPlayer(player)
	Engine:mapClear(self.ready, player)
	local sig = Engine:mapGet(self.waiters, player)
	if sig ~= nil then
		sig:Destroy()
		Engine:mapClear(self.waiters, player)
	end
end

function DataServiceServer:WaitFor(player: Player): Data
	local loaded: Data = Engine:mapGet(self.sessions, player)
	if loaded ~= nil then
		return loaded
	end
	local players: Players = game:GetService("Players")
	if not (player:IsDescendantOf(players)) then
		error("DataService.Server.WaitFor called for a player that is not in Players")
		return nil
	end
	local sig = Engine:mapGet(self.waiters, player)
	if sig == nil then
		sig = Engine:signalNew()
		Engine:mapSet(self.waiters, player, sig)
	end
	sig:Wait()
	local after: Data = Engine:mapGet(self.sessions, player)
	if not (after ~= nil) then
		error("DataService.Server: player data was not available after wait")
		return nil
	end
	return after
end

function DataServiceServer:Get(player: Player): Data
	return Engine:mapGet(self.sessions, player)
end

function DataServiceServer:HasData(player: Player): boolean
	return Engine:mapGet(self.sessions, player) ~= nil
end

function DataServiceServer:GetProfile(player: Player): DataProfile
	return Engine:mapGet(self.profiles, player)
end

function DataServiceServer:GetBufferStats(player: Player): DataBufferStats
	return Engine:replicatorGetBufferStats(player)
end

function DataServiceServer:Destroy()
	local players: Players = game:GetService("Players")
	for _, player in players:GetPlayers() do
		if Engine:mapGet(self.sessions, player) ~= nil then
			self:OnRemoving(player)
		end
	end
	if self.janitor ~= nil then
		self.janitor:Cleanup()
		self.janitor = nil
	end
	Engine:replicatorDestroy()
end

return DataServiceServer
