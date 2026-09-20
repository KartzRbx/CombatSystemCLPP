--!strict
-- Compiled by CL++ — C++ × Luau

const Sweep = require(script.Parent.Parent.Sweep)
const Engine = require(script.Parent.Engine)

local DataServiceClient = {}

DataServiceClient.janitor = nil

DataServiceClient.initialized = nil

DataServiceClient.Paths = nil

DataServiceClient.session = nil

DataServiceClient.bufferStats = nil

DataServiceClient.loaded = nil

function DataServiceClient:Init(): Data
	local runService: RunService = game:GetService("RunService")
	if runService:IsClient() == false then
		error("DataService.Client may only be used on the client")
		return self.session
	end
	if self.initialized ~= true then
		self.initialized = true
		self.janitor = Sweep.new()
		self.loaded = Engine:signalNew()
		self.janitor:Add(self.loaded, "Destroy")
		self.janitor:Add(Engine.Replicator.BufferChanged:Connect(function(stats: DataBufferStats)
	self.bufferStats = stats
end), "Disconnect")
		Engine:replicatorOn(Engine.Enums.Init, function(path: DataPath, snapshot)
	if self.session ~= nil then
		self.session:Destroy()
	end
	self.session = Engine:dataNew(snapshot, false, false, false, snapshot)
	self.Paths = Engine:createTemplatePaths(snapshot)
	self.loaded:Fire()
end)
		Engine:replicatorOn(Engine.Enums.Set, function(path: DataPath, value)
	if self.session ~= nil then
		Engine:applySet(self.session, path, value)
	end
end)
		Engine:replicatorOn(Engine.Enums.ArrayInsert, function(path: DataPath, value, index: number)
	if self.session ~= nil then
		Engine:applyArrayInsert(self.session, path, value, index)
	end
end)
		Engine:replicatorOn(Engine.Enums.ArrayRemove, function(path: DataPath, index: number)
	if self.session ~= nil then
		Engine:applyArrayRemove(self.session, path, index)
	end
end)
		Engine:replicatorOn(Engine.Enums.SetTransient, function(path: DataPath, value)
	if self.session ~= nil then
		Engine:applyTransientSet(self.session, path, value)
	end
end)
		Engine:replicatorOn(Engine.Enums.ArrayInsertTransient, function(path: DataPath, value, index: number)
	if self.session ~= nil then
		Engine:applyTransientArrayInsert(self.session, path, value, index)
	end
end)
		Engine:replicatorOn(Engine.Enums.ArrayRemoveTransient, function(path: DataPath, index: number)
	if self.session ~= nil then
		Engine:applyTransientArrayRemove(self.session, path, index)
	end
end)
		Engine:replicatorOn(Engine.Enums.ClearTransient, function(path: DataPath)
	if self.session ~= nil then
		Engine:applyTransientClear(self.session, path)
	end
end)
		Engine:replicatorNotifyReady()
	end
	return self:WaitForData()
end

function DataServiceClient:WaitForData(): Data
	if self.session ~= nil then
		return self.session
	end
	self.loaded:Wait()
	return self.session
end

function DataServiceClient:Get(): Data
	return self.session
end

function DataServiceClient:GetBufferStats(): DataBufferStats
	if self.bufferStats ~= nil then
		return self.bufferStats
	end
	return Engine:replicatorGetBufferStats(nil)
end

function DataServiceClient:Destroy()
	if self.session ~= nil then
		self.session:Destroy()
		self.session = nil
	end
	if self.janitor ~= nil then
		self.janitor:Cleanup()
		self.janitor = nil
	end
	Engine:replicatorDestroy()
end

return DataServiceClient
