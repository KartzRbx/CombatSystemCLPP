--!optimize 2
--!strict
-- Keep Store — ProfileStore session contract (MadStudio algorithm), PascalCase, Spark signals.
-- Improvements: trade messages are first-class; UpdateAsync is serialized per key;
-- LastSavedData is the receipt source of truth; Mock never touches live DataStores.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Spark = require(script.Parent.Parent.Spark)
local Trade = require(script.Parent.Trade)

local AUTO_SAVE_PERIOD = 300
local LOAD_REPEAT_PERIOD = 10
local FIRST_LOAD_REPEAT = 5
local SESSION_STEAL = 40
local ASSUME_DEAD = 630
local START_SESSION_TIMEOUT = 120
local CRITICAL_STATE_ERROR_COUNT = 5
local CRITICAL_STATE_ERROR_EXPIRE = 120
local CRITICAL_STATE_EXPIRE = 120
local MAX_MESSAGE_QUEUE = 1000

local PlaceId = game.PlaceId
local JobId = if game.JobId ~= "" then game.JobId else "Studio"
local IsStudio = RunService:IsStudio()

local ActiveSessionCheck: { [string]: any } = {}
local AutoSaveList: { any } = {}
local AutoSaveIndex = 1
local LastAutoSave = os.clock()
local IssueQueue: { number } = {}
local UpdateQueue: { [string]: { any } } = {}
local ActiveProfileLoadJobs = 0
local ActiveProfileSaveJobs = 0
local CriticalStateStart = 0
local MockStore: { [string]: any } = {}
local UserMockStore: { [string]: any } = {}
local MockFlag = false

local Store = {}
Store.__index = Store
Store.IsClosing = false
Store.IsCriticalState = false
Store.OnError = Spark.new()
Store.OnOverwrite = Spark.new()
Store.OnCriticalToggle = Spark.new()
Store.DataStoreState = "NotReady"

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value do
		out[key] = deepCopy(item)
	end
	return out
end

local function reconcile(data: any, template: any)
	if typeof(template) ~= "table" then
		return data
	end
	if typeof(data) ~= "table" then
		return deepCopy(template)
	end
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif typeof(value) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function thisSession(session: any): boolean
	return typeof(session) == "table" and session.PlaceId == PlaceId and session.JobId == JobId
end

local function sessionToken(storeName: string, key: string): string
	return storeName .. "/" .. key
end

local function uniqueId(): string
	return HttpService:GenerateGUID(false)
end

local function requestEnd(session: any)
	if typeof(session) ~= "table" or typeof(session.UniqueSessionId) ~= "string" or session.UniqueSessionId == "" then
		return
	end
	pcall(function()
		MessagingService:PublishAsync("Keep_" .. session.UniqueSessionId, { EndSession = true })
	end)
end

local function registerIssue()
	local now = os.clock()
	table.insert(IssueQueue, now)
	while IssueQueue[1] and now - IssueQueue[1] > CRITICAL_STATE_ERROR_EXPIRE do
		table.remove(IssueQueue, 1)
	end
	if #IssueQueue >= CRITICAL_STATE_ERROR_COUNT then
		Store.IsCriticalState = true
		CriticalStateStart = now
		Store.OnCriticalToggle:Fire(true)
	end
end

local function emptyPayload(template: any)
	return {
		Data = deepCopy(template),
		MetaData = {
			ProfileCreateTime = os.time(),
			SessionLoadCount = 0,
			ActiveSession = nil,
			ForceLoadSession = nil,
			LastUpdate = os.time(),
			UniqueSessionId = "",
		},
		RobloxMetaData = {},
		UserIds = {},
		GlobalUpdates = { 0, {} },
	}
end

local function mockBucket(userMock: boolean)
	return if userMock then UserMockStore else MockStore
end

local function readMock(userMock: boolean, name: string, key: string)
	local bucket = mockBucket(userMock)
	bucket[name] = bucket[name] or {}
	return bucket[name][key]
end

local function writeMock(userMock: boolean, name: string, key: string, payload: any)
	local bucket = mockBucket(userMock)
	bucket[name] = bucket[name] or {}
	bucket[name][key] = payload
	return payload
end

local function waitQueue(token: string)
	UpdateQueue[token] = UpdateQueue[token] or {}
	local waiters = UpdateQueue[token]
	local thread = coroutine.running()
	table.insert(waiters, thread)
	if waiters[1] ~= thread then
		coroutine.yield()
	end
end

local function releaseQueue(token: string)
	local waiters = UpdateQueue[token]
	if not waiters then
		return
	end
	table.remove(waiters, 1)
	local nextThread = waiters[1]
	if nextThread then
		task.spawn(nextThread)
	else
		UpdateQueue[token] = nil
	end
end

local function transformUpdate(store: any, key: string, transform: (any) -> any): (any, any)
	local token = sessionToken(store.Name, key)
	waitQueue(token)
	local payload
	local keyInfo
	if store._store and not store._mockFlag then
		local ok, result, info = pcall(function()
			return store._store:UpdateAsync(key, function(old, info)
				keyInfo = info
				return transform(old)
			end)
		end)
		if ok then
			payload = result
		else
			registerIssue()
			Store.OnError:Fire(tostring(result), store.Name, key)
		end
	else
		local old = readMock(store._userMock, store.Name, key)
		payload = transform(old)
		if payload ~= nil then
			writeMock(store._userMock, store.Name, key, payload)
		end
	end
	releaseQueue(token)
	return payload, keyInfo
end

local Profile = {}
Profile.__index = Profile

function Profile:IsActive(): boolean
	return ActiveSessionCheck[self._token] == self and not Store.IsClosing
end

function Profile:Reconcile()
	self.Data = reconcile(self.Data, self._store.Template)
end

function Profile:AddUserId(userId: number)
	if typeof(userId) ~= "number" then
		return
	end
	if table.find(self.UserIds, userId) == nil then
		table.insert(self.UserIds, userId)
	end
end

function Profile:RemoveUserId(userId: number)
	local index = table.find(self.UserIds, userId)
	if index then
		table.remove(self.UserIds, index)
	end
end

function Profile:MessageHandler(fn: (any, () -> ()) -> ())
	table.insert(self._handlers, fn)
	for _, update in self._updates do
		local index = update[1]
		if not self._locked[index] then
			local processed = false
			fn(deepCopy(update[2]), function()
				processed = true
				self._locked[index] = true
			end)
			if processed then
				break
			end
		end
	end
end

local saveProfileAsync

function Profile:Save()
	if self._view then
		error("Keep: Save is not valid in view mode; use SetAsync")
	end
	if not self:IsActive() then
		return
	end
	task.spawn(saveProfileAsync, self, false, "Manual")
end

function Profile:SaveWait(): boolean
	if self._view then
		error("Keep: SaveWait is not valid in view mode; use SetAsync")
	end
	while self._saving do
		task.wait()
	end
	if not self:IsActive() then
		return false
	end
	return saveProfileAsync(self, false, "Manual") == true
end

function Profile:SetAsync()
	if not self._view then
		error("Keep: SetAsync is only valid in view mode")
	end
	saveProfileAsync(self, true, "Manual")
end

function Profile:EndSession()
	if self._view then
		return
	end
	saveProfileAsync(self, true, "Manual")
end

saveProfileAsync = function(profile: any, ending: boolean, reason: string): boolean
	while profile._saving do
		task.wait()
	end
	if profile._ended then
		return false
	end
	if ending then
		if not profile._view then
			Trade.AbortIfActive(profile)
		end
	elseif not profile:IsActive() then
		return false
	end
	profile._saving = true
	ActiveProfileSaveJobs += 1
	profile.OnSave:Fire()
	if ending then
		profile.OnLastSave:Fire(if Store.IsClosing then "Shutdown" else reason)
	end
	local stealRequested = false
	local payload = transformUpdate(profile._store, profile.Key, function(old)
		old = old or emptyPayload(profile._store.Template)
		old.MetaData = old.MetaData or {}
		local incoming = (old.GlobalUpdates and old.GlobalUpdates[2]) or {}
		for _, update in incoming do
			local index = update[1]
			local exists = false
			for _, have in profile._updates do
				if have[1] == index then
					exists = true
					break
				end
			end
			if not exists then
				table.insert(profile._updates, update)
				profile._updateIndex = math.max(profile._updateIndex, index or 0)
			end
		end
		for _, update in profile._updates do
			if not profile._locked[update[1]] then
				for _, fn in profile._handlers do
					local processed = false
					fn(deepCopy(update[2]), function()
						processed = true
						profile._locked[update[1]] = true
					end)
					if processed then
						break
					end
				end
			end
		end
		local remaining = {}
		for _, update in profile._updates do
			if not profile._locked[update[1]] then
				table.insert(remaining, update)
			end
		end
		profile._updates = remaining
		stealRequested = typeof(old.MetaData.ForceLoadSession) == "table" and not thisSession(old.MetaData.ForceLoadSession)
		if ending or stealRequested then
			if thisSession(old.MetaData.ActiveSession) then
				old.MetaData.ActiveSession = nil
			end
		else
			old.MetaData.ActiveSession = {
				PlaceId = PlaceId,
				JobId = JobId,
				UniqueSessionId = profile._sessionId,
			}
		end
		old.Data = profile.Data
		old.RobloxMetaData = profile.RobloxMetaData
		old.UserIds = profile.UserIds
		old.MetaData.LastUpdate = os.time()
		old.GlobalUpdates = { profile._updateIndex, remaining }
		return old
	end)
	if payload then
		profile.LastSavedData = deepCopy(payload.Data)
		profile.OnAfterSave:Fire(profile.LastSavedData)
	end
	if ending or stealRequested then
		if not profile._view then
			profile._ended = true
			ActiveSessionCheck[profile._token] = nil
			for index, item in AutoSaveList do
				if item == profile then
					table.remove(AutoSaveList, index)
					break
				end
			end
			profile.OnSessionEnd:Fire()
		end
	end
	profile._saving = false
	ActiveProfileSaveJobs -= 1
	return payload ~= nil
end

local function attachAutosave(profile: any)
	table.insert(AutoSaveList, profile)
end

local function makeProfile(store: any, key: string, payload: any, view: boolean)
	local token = sessionToken(store.Name, key)
	local profile = setmetatable({
		Data = payload.Data,
		LastSavedData = deepCopy(payload.Data),
		FirstSessionTime = payload.MetaData.ProfileCreateTime or os.time(),
		SessionLoadCount = payload.MetaData.SessionLoadCount or 0,
		Session = payload.MetaData.ActiveSession,
		RobloxMetaData = payload.RobloxMetaData or {},
		UserIds = payload.UserIds or {},
		Key = key,
		IsActive = Profile.IsActive,
		_store = store,
		_token = token,
		_view = view,
		_sessionId = payload.MetaData.UniqueSessionId or uniqueId(),
		_handlers = {},
		_locked = {},
		_updates = (payload.GlobalUpdates and payload.GlobalUpdates[2]) or {},
		_updateIndex = (payload.GlobalUpdates and payload.GlobalUpdates[1]) or 0,
		_saving = false,
		_ended = false,
		OnSave = Spark.new(),
		OnLastSave = Spark.new(),
		OnSessionEnd = Spark.new(),
		OnAfterSave = Spark.new(),
	}, Profile)
	profile.ProfileStore = store
	return profile
end

function Store.SetConstant(name: string, value: number)
	if name == "AUTO_SAVE_PERIOD" then
		AUTO_SAVE_PERIOD = value
	elseif name == "LOAD_REPEAT_PERIOD" then
		LOAD_REPEAT_PERIOD = value
	elseif name == "FIRST_LOAD_REPEAT" then
		FIRST_LOAD_REPEAT = value
	elseif name == "SESSION_STEAL" then
		SESSION_STEAL = value
	elseif name == "ASSUME_DEAD" then
		ASSUME_DEAD = value
	elseif name == "START_SESSION_TIMEOUT" then
		START_SESSION_TIMEOUT = value
	elseif name == "MAX_MESSAGE_QUEUE" then
		MAX_MESSAGE_QUEUE = value
	end
end

function Store.New(name: string, template: any)
	local self = setmetatable({
		Name = name,
		Template = template or {},
		_store = nil :: GlobalDataStore?,
		_mockFlag = false,
		_userMock = false,
		Mock = nil :: any,
	}, Store)
	local ok = pcall(function()
		self._store = DataStoreService:GetDataStore("Keep_" .. name)
		Store.DataStoreState = "Access"
	end)
	if not ok or self._store == nil then
		self._mockFlag = IsStudio
		Store.DataStoreState = if IsStudio then "Access" else "NoAccess"
	end
	self.Mock = setmetatable({
		Name = name,
		Template = self.Template,
		_store = nil,
		_mockFlag = true,
		_userMock = true,
		Mock = nil,
	}, Store)
	self.Mock.Mock = self.Mock
	return self
end

function Store:StartSessionAsync(key: string, params: any)
	params = params or {}
	local steal = params.Steal == true
	local cancel = params.Cancel
	local started = os.clock()
	local firstWait = true
	ActiveProfileLoadJobs += 1
	local profile
	while true do
		if typeof(cancel) == "function" and cancel() then
			break
		end
		if os.clock() - started > START_SESSION_TIMEOUT then
			break
		end
		local sessionId = uniqueId()
		local payload = transformUpdate(self, key, function(old)
			old = old or emptyPayload(self.Template)
			old.MetaData = old.MetaData or {}
			local lock = old.MetaData.ActiveSession
			local last = old.MetaData.LastUpdate or 0
			local dead = os.time() - last >= ASSUME_DEAD
			if lock and not thisSession(lock) and not dead and not steal then
				old.MetaData.ForceLoadSession = { PlaceId = PlaceId, JobId = JobId }
				return old
			end
			old.Data = reconcile(old.Data or {}, self.Template)
			old.MetaData.SessionLoadCount = (old.MetaData.SessionLoadCount or 0) + 1
			old.MetaData.UniqueSessionId = sessionId
			old.MetaData.ActiveSession = { PlaceId = PlaceId, JobId = JobId, UniqueSessionId = sessionId }
			old.MetaData.ForceLoadSession = nil
			old.MetaData.LastUpdate = os.time()
			old.GlobalUpdates = old.GlobalUpdates or { 0, {} }
			return old
		end)
		if payload and thisSession(payload.MetaData.ActiveSession) then
			profile = makeProfile(self, key, payload, false)
			ActiveSessionCheck[profile._token] = profile
			attachAutosave(profile)
			pcall(function()
				MessagingService:SubscribeAsync("Keep_" .. profile._sessionId, function(message)
					if typeof(message.Data) == "table" and message.Data.EndSession and profile:IsActive() then
						saveProfileAsync(profile, true, "External")
					end
				end)
			end)
			break
		end
		if payload then
			requestEnd(payload.MetaData.ActiveSession)
		end
		task.wait(if firstWait then FIRST_LOAD_REPEAT else LOAD_REPEAT_PERIOD)
		firstWait = false
		if os.clock() - started > SESSION_STEAL then
			steal = true
		end
	end
	ActiveProfileLoadJobs -= 1
	return profile
end

function Store:GetAsync(key: string): any
	local payload
	if self._store and not self._mockFlag then
		local ok, result = pcall(function()
			return self._store:GetAsync(key)
		end)
		if ok then
			payload = result
		end
	else
		payload = readMock(self._userMock, self.Name, key)
	end
	if not payload then
		return nil
	end
	return makeProfile(self, key, payload, true)
end

function Store:MessageAsync(key: string, message: any): boolean
	if typeof(message) ~= "table" then
		return false
	end
	local payload = transformUpdate(self, key, function(old)
		old = old or emptyPayload(self.Template)
		old.GlobalUpdates = old.GlobalUpdates or { 0, {} }
		local index = (old.GlobalUpdates[1] or 0) + 1
		old.GlobalUpdates[1] = index
		old.GlobalUpdates[2] = old.GlobalUpdates[2] or {}
		if #old.GlobalUpdates[2] >= MAX_MESSAGE_QUEUE then
			table.remove(old.GlobalUpdates[2], 1)
		end
		table.insert(old.GlobalUpdates[2], { index, message })
		return old
	end)
	return payload ~= nil
end

function Store:RemoveAsync(key: string): boolean
	if self._store and not self._mockFlag then
		local ok = pcall(function()
			self._store:RemoveAsync(key)
		end)
		return ok
	end
	local bucket = mockBucket(self._userMock)
	if bucket[self.Name] then
		bucket[self.Name][key] = nil
	end
	return true
end

function Store:VersionQuery(key: string, sortDirection: any, minDate: any, maxDate: any)
	local versions = {}
	local cursor = 0
	if self._store and not self._mockFlag then
		pcall(function()
			local pages = self._store:ListVersionsAsync(key, sortDirection, minDate, maxDate)
			if pages then
				for _, item in pages:GetCurrentPage() do
					table.insert(versions, item)
				end
			end
		end)
	end
	return {
		Get = function(_self, index: number)
			return versions[index]
		end,
		List = function()
			return versions
		end,
		Next = function()
			cursor += 1
			return versions[cursor]
		end,
		NextAsync = function()
			cursor += 1
			local info = versions[cursor]
			if not info then
				return nil
			end
			return self:GetAsync(key)
		end,
	}
end

if RunService:IsServer() then
	task.spawn(function()
		while true do
			task.wait(1)
			if Store.IsCriticalState and os.clock() - CriticalStateStart > CRITICAL_STATE_EXPIRE then
				Store.IsCriticalState = false
				Store.OnCriticalToggle:Fire(false)
			end
			if os.clock() - LastAutoSave >= 1 and #AutoSaveList > 0 then
				local period = AUTO_SAVE_PERIOD / math.max(#AutoSaveList, 1)
				if os.clock() - LastAutoSave >= period then
					LastAutoSave = os.clock()
					local profile = AutoSaveList[AutoSaveIndex]
					AutoSaveIndex += 1
					if AutoSaveIndex > #AutoSaveList then
						AutoSaveIndex = 1
					end
					if profile and profile:IsActive() then
						task.spawn(saveProfileAsync, profile, false, "Manual")
					end
				end
			end
		end
	end)
	game:BindToClose(function()
		Store.IsClosing = true
		for _, profile in table.clone(AutoSaveList) do
			if profile:IsActive() then
				saveProfileAsync(profile, true, "Shutdown")
			end
		end
		local deadline = os.clock() + 20
		while (ActiveProfileSaveJobs > 0 or ActiveProfileLoadJobs > 0) and os.clock() < deadline do
			task.wait()
		end
	end)
end

return Store
