--!strict
-- Kernel bridge for CL++ Server/Client. Path tokens, Keep Store, Data,
-- tagged-buffer replication, and Spark stay Luau — CL++ 0.3.2 cannot express
-- type functions, metatable path tokens, or rawset overlays.

local RunService = game:GetService("RunService")

local Path = require(script.Parent.Path)
local Data = require(script.Parent.Data)
local Enums = require(script.Parent.Enums)
local EnumModule = require(script.Parent.Enum)
local Store = require(script.Parent.Store)
local Trade = require(script.Parent.Trade)
local ReplicatorModule = require(script.Parent.Replicator)
local Spark = require(script.Parent.Parent.Spark)

local Engine = {}

Engine.Path = Path
Engine.Data = Data
Engine.ProfileStore = Store
Engine.Store = Store
Engine.Trade = Trade
Engine.Enums = Enums
Engine.Enum = EnumModule
Engine.Signal = Spark
Engine.Spark = Spark
Engine.Replicator = if RunService:IsServer() then ReplicatorModule.Server else ReplicatorModule.Client

function Engine:mapNew()
	return {}
end

function Engine:mapSet(map: any, key: any, value: any)
	if map then
		map[key] = value
	end
end

function Engine:mapGet(map: any, key: any): any
	if map == nil then
		return nil
	end
	return map[key]
end

function Engine:mapClear(map: any, key: any)
	if map then
		map[key] = nil
	end
end

function Engine:createTemplatePaths(tmpl: any)
	return Path.createTemplatePaths(tmpl)
end

function Engine:rootToken()
	return Path.rootToken()
end

function Engine:toKey(path: any): string
	return Path.toKey(path)
end

function Engine:parentPath(path: any)
	return Path.parent(path)
end

function Engine:emptyPath()
	return {}
end

function Engine:dataNew(initial: any, writable: boolean, strictPaths: boolean?, autoCreate: boolean?, tmpl: any)
	return Data.new(initial, writable, {
		StrictPaths = if strictPaths ~= nil then strictPaths else true,
		AutoCreateMissingTables = if autoCreate ~= nil then autoCreate else false,
		Template = if tmpl ~= nil then tmpl else initial,
	})
end

function Engine:applySet(data: any, path: any, value: any)
	Data._applySet(data, path, value)
end

function Engine:applyArrayInsert(data: any, path: any, value: any, index: number?)
	Data._applyArrayInsert(data, path, value, index)
end

function Engine:applyArrayRemove(data: any, path: any, index: number)
	Data._applyArrayRemove(data, path, index)
end

function Engine:applyTransientSet(data: any, path: any, value: any)
	Data._applyTransientSet(data, path, value)
end

function Engine:applyTransientArrayInsert(data: any, path: any, value: any, index: number?)
	Data._applyTransientArrayInsert(data, path, value, index)
end

function Engine:applyTransientArrayRemove(data: any, path: any, index: number)
	Data._applyTransientArrayRemove(data, path, index)
end

function Engine:applyTransientClear(data: any, path: any)
	Data._applyTransientClear(data, path)
end

function Engine:profileStoreNew(storeName: string, tmpl: any)
	return Store.New(storeName, tmpl)
end

function Engine:startSession(store: any, key: string, player: Player, players: Players)
	local profile = store:StartSessionAsync(key, {
		Cancel = function()
			return player.Parent ~= players
		end,
	})
	if profile then
		profile:AddUserId(player.UserId)
		Trade.Ensure(profile.Data)
		profile:MessageHandler(function(message, processed)
			Trade.HandleMessage(profile, message, processed)
		end)
	end
	return profile
end

function Engine:abortActiveTrade(profile: any)
	Trade.AbortIfActive(profile)
end

function Engine:signalNew()
	return Spark.new()
end

function Engine:isExcluded(excluded: { [string]: boolean }?, path: any): boolean
	if not path or #path == 0 then
		return false
	end
	if not excluded then
		return false
	end
	for i = 1, #path do
		local prefix = table.create(i)
		for j = 1, i do
			prefix[j] = path[j]
		end
		if excluded[Path.toKey(prefix)] then
			return true
		end
	end
	return false
end

function Engine:buildSnapshot(excluded: { [string]: boolean }?, value: any, prefix: any): any
	local path = prefix or {}
	if Engine:isExcluded(excluded, path) then
		return nil
	end
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		local newPath = table.clone(path)
		newPath[#newPath + 1] = k
		if not Engine:isExcluded(excluded, newPath) then
			out[k] = Engine:buildSnapshot(excluded, v, newPath)
		end
	end
	return out
end

function Engine:watchData(data: any, player: Player, ready: { [Player]: boolean }, excluded: { [string]: boolean })
	return data.Changed:Connect(function(action, path, ...)
		if not ready[player] then
			return
		end
		if Engine:isExcluded(excluded, path) then
			return
		end
		Engine.Replicator:Send(player, action, path, ...)
	end)
end

function Engine:replicatorOn(action: string, handler: any)
	Engine.Replicator:On(action, handler)
end

function Engine:replicatorNotifyReady()
	Engine.Replicator:NotifyReady()
end

function Engine:replicatorSend(player: Player, action: string, path: any, ...)
	Engine.Replicator:Send(player, action, path, ...)
end

function Engine:replicatorGetBufferStats(player: Player?)
	return Engine.Replicator:GetBufferStats(player)
end

function Engine:replicatorForgetPlayer(player: Player)
	Engine.Replicator:ForgetPlayer(player)
end

function Engine:replicatorDestroy()
	Engine.Replicator:Destroy()
end

return Engine
