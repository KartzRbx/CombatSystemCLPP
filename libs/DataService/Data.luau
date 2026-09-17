local packages = script.Parent.Packages

const Signal = require(packages.signal)

const Path = require(script.Parent.Path)
const Enums = require(script.Parent.Enums)
const PackageEnum = require(script.Parent.Enum)

type SignalT = typeof(Signal.new())
type AnyConnection = RBXScriptConnection
type TypedSignal<T...> = {
	Connect: (self: TypedSignal<T...>, fn: (T...) -> ()) -> AnyConnection,
	Once: (self: TypedSignal<T...>, fn: (T...) -> ()) -> AnyConnection,
	Wait: (self: TypedSignal<T...>) -> T...,
}

const Data = {}

--[=[
	@class Data
	Per-player data instance. Writable on the server, read-only on the client.
	Use `Get()` for merged reads and `GetPersisted()` for saved ProfileStore values.
]=]
const ROOT_KEY = {}
const WRITABLE_KEY = {}
const STRICT_PATHS_KEY = {}
const AUTO_CREATE_KEY = {}
const CHANGED_MAP_KEY = {}
const INDEX_CHANGED_MAP_KEY = {}
const ARRAY_INSERTED_MAP_KEY = {}
const ARRAY_REMOVED_MAP_KEY = {}
const TRANSIENT_KEY = {}

export type DataPath = Path.Path
export type DataPathLike = Path.Path | Path.PathToken<never>
export type DataOptions<T = never> = {
	StrictPaths: boolean?,
	AutoCreateMissingTables: boolean?,
	Template: T?,
}
export type OrderedListOrder = typeof(PackageEnum.OrderList.Asc) | typeof(PackageEnum.OrderList.Desc) | "asc" | "desc"
export type OrderedListOptions = {
	key: string,
	order: OrderedListOrder?,
	limit: number?,
}
export type OrderedListEntry<V> = {
	index: number,
	value: V,
	priority: any,
}
type TypedPath<V> = Path.PathToken<V>
type ChangedSignal<V> = TypedSignal<V, V>
type IndexChangedSignal<V> = TypedSignal<string | number, V, V>
type ArrayInsertedSignal<V> = TypedSignal<number, V>
type ArrayRemovedSignal<V> = TypedSignal<number, V>
type DataCore<T> = {
	Changed: SignalT,
	Destroyed: boolean,
	Typed: <V>(self: DataCore<T>, path: DataPathLike) -> TypedPath<V>,
	Get: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike?) -> V,
	GetPersisted: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike?) -> V,
	GetTransient: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike?) -> V?,
	HasTransient: (self: DataCore<T>, path: DataPathLike?) -> boolean,
	Set: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike, value: V) -> (),
	SetTransient: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike, value: V) -> (),
	Update: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike, fn: (V) -> V) -> V,
	UpdateTransient: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike, fn: (V) -> V) -> V,
	ClearTransient: (self: DataCore<T>, path: DataPathLike?) -> (),
	ArrayInsert: <V>(self: DataCore<T>, path: TypedPath<{ V }> | DataPathLike, value: V, index: number?) -> (),
	ArrayInsertTransient: <V>(self: DataCore<T>, path: TypedPath<{ V }> | DataPathLike, value: V, index: number?) -> (),
	ArrayRemove: <V>(self: DataCore<T>, path: TypedPath<{ V }> | DataPathLike, index: number) -> V,
	ArrayRemoveTransient: <V>(self: DataCore<T>, path: TypedPath<{ V }> | DataPathLike, index: number) -> V,
	GetOrderedList: <V>(self: DataCore<T>, path: TypedPath<{ V }> | DataPathLike, options: OrderedListOptions) -> { OrderedListEntry<V> },
	GetOrderedListWithPriority: <V>(
		self: DataCore<T>,
		path: TypedPath<{ V }> | DataPathLike,
		key: string,
		order: OrderedListOrder?
	) -> { OrderedListEntry<V> },
	GetChangedSignal: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike) -> ChangedSignal<V>,
	GetPathChangedSignal: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike) -> ChangedSignal<V>,
	GetIndexChangedSignal: <V>(self: DataCore<T>, path: TypedPath<V> | DataPathLike) -> IndexChangedSignal<V>,
	GetArrayInsertedSignal: <V>(self: DataCore<T>, path: TypedPath<{ V }> | DataPathLike) -> ArrayInsertedSignal<V>,
	GetArrayRemovedSignal: <V>(self: DataCore<T>, path: TypedPath<{ V }> | DataPathLike) -> ArrayRemovedSignal<V>,
	Destroy: (self: DataCore<T>) -> (),
}
export type Data<T> = DataCore<T>

const READ_ONLY_ERROR = "DataService: Data on the client is read-only. Mutations are server-driven."
const INVALID_PATH_ERROR = "DataService: invalid data path %q"

const pathToString = function(path: DataPath): string
	if #path == 0 then
		return "<root>"
	end
	local parts = table.create(#path)
	for i, segment in path do
		parts[i] = tostring(segment)
	end
	return table.concat(parts, ".")
end

const normalizePath = function(pathLike: DataPathLike?, allowNil: boolean?): DataPath?
	local resolved = Path.toArray(pathLike)
	if resolved == nil then
		if allowNil then
			return nil
		end
		error("DataService: path is required")
	end
	if not Path.validate(resolved) then
		error(string.format(INVALID_PATH_ERROR, pathToString(resolved)))
	end
	return resolved
end

const pathFromKey = function(key: string): DataPath
	if key == "" then
		return {}
	end
	local path = table.create(4)
	for part in string.gmatch(key, "[^\0]+") do
		local kind = string.sub(part, 1, 1)
		local value = string.sub(part, 3)
		if kind == "s" then
			path[#path + 1] = value
		elseif kind == "n" then
			path[#path + 1] = tonumber(value)
		end
	end
	return path
end

const isDescendantPath = function(childKey: string, parentKey: string): boolean
	if parentKey == "" then
		return childKey ~= ""
	end
	return childKey == parentKey or string.sub(childKey, 1, #parentKey + 1) == parentKey .. "\0"
end

local function deepCopyTable(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopyTable(v)
	end
	return out
end

const setAtPath = function(root: any, path: DataPath, value: any)
	if #path == 0 then
		return
	end
	local parent = root
	for i = 1, #path - 1 do
		local k = path[i]
		local nextValue = rawget(parent, k)
		if type(nextValue) ~= "table" then
			nextValue = {}
			rawset(parent, k, nextValue)
		end
		parent = nextValue
	end
	rawset(parent, path[#path], value)
end

const getPersistedAt = function(root: any, path: DataPath?): any
	if not path or #path == 0 then
		return root
	end
	local cur: any = root
	for _, k in path do
		if type(cur) ~= "table" then
			return nil
		end
		cur = rawget(cur, k)
	end
	return cur
end

const getMergedValue = function(self: any, path: DataPath): any
	local transient = self[TRANSIENT_KEY]
	local key = Path.toKey(path)
	local direct = transient[key]
	if direct ~= nil then
		return direct
	end

	if #path == 0 then
		local persisted = self[ROOT_KEY]
		local out = if type(persisted) == "table" then deepCopyTable(persisted) else {}
		for tKey, tVal in transient do
			setAtPath(out, pathFromKey(tKey), tVal)
		end
		return out
	end

	local persisted = getPersistedAt(self[ROOT_KEY], path)
	local hasDescendant = false
	for tKey in transient do
		if isDescendantPath(tKey, key) then
			hasDescendant = true
			break
		end
	end
	if not hasDescendant then
		return persisted
	end

	local out = if type(persisted) == "table" then deepCopyTable(persisted) else {}
	for tKey, tVal in transient do
		if isDescendantPath(tKey, key) then
			local tPath = pathFromKey(tKey)
			local relative = table.create(math.max(#tPath - #path, 0))
			for i = #path + 1, #tPath do
				relative[#relative + 1] = tPath[i]
			end
			if #relative > 0 then
				setAtPath(out, relative, tVal)
			end
		end
	end
	return out
end

const copyArray = function(value: any): { any }
	local out = table.create(#value)
	for index, item in value do
		out[index] = if type(item) == "table" then deepCopyTable(item) else item
	end
	return out
end

function Data.new<T>(initial: T, writable: boolean?, options: DataOptions<T>?): Data<T>
	local self: any
	self = {
		Get = function(a, b)
			local path = if a == self then b else a
			return Data.Get(self, path)
		end,
		GetPersisted = function(a, b)
			local path = if a == self then b else a
			return Data.GetPersisted(self, path)
		end,
		GetTransient = function(a, b)
			local path = if a == self then b else a
			return Data.GetTransient(self, path)
		end,
		HasTransient = function(a, b)
			local path = if a == self then b else a
			return Data.HasTransient(self, path)
		end,
		Set = function(a, b, c)
			local path = if a == self then b else a
			local value = if a == self then c else b
			return Data.Set(self, path, value)
		end,
		SetTransient = function(a, b, c)
			local path = if a == self then b else a
			local value = if a == self then c else b
			return Data.SetTransient(self, path, value)
		end,
		Update = function(a, b, c)
			local path = if a == self then b else a
			local fn = if a == self then c else b
			return Data.Update(self, path, fn)
		end,
		UpdateTransient = function(a, b, c)
			local path = if a == self then b else a
			local fn = if a == self then c else b
			return Data.UpdateTransient(self, path, fn)
		end,
		ClearTransient = function(a, b)
			local path = if a == self then b else a
			return Data.ClearTransient(self, path)
		end,
		ArrayInsert = function(a, b, c, d)
			local path = if a == self then b else a
			local value = if a == self then c else b
			local index = if a == self then d else c
			return Data.ArrayInsert(self, path, value, index)
		end,
		ArrayInsertTransient = function(a, b, c, d)
			local path = if a == self then b else a
			local value = if a == self then c else b
			local index = if a == self then d else c
			return Data.ArrayInsertTransient(self, path, value, index)
		end,
		ArrayRemove = function(a, b, c)
			local path = if a == self then b else a
			local index = if a == self then c else b
			return Data.ArrayRemove(self, path, index)
		end,
		ArrayRemoveTransient = function(a, b, c)
			local path = if a == self then b else a
			local index = if a == self then c else b
			return Data.ArrayRemoveTransient(self, path, index)
		end,
		GetOrderedList = function(a, b, c)
			local path = if a == self then b else a
			local options = if a == self then c else b
			return Data.GetOrderedList(self, path, options)
		end,
		GetOrderedListWithPriority = function(a, b, c, d)
			local path = if a == self then b else a
			local key = if a == self then c else b
			local order = if a == self then d else c
			return Data.GetOrderedListWithPriority(self, path, key, order)
		end,
		GetChangedSignal = function(a, b)
			local path = if a == self then b else a
			return Data.GetChangedSignal(self, path)
		end,
		GetPathChangedSignal = function(a, b)
			local path = if a == self then b else a
			return Data.GetPathChangedSignal(self, path)
		end,
		GetIndexChangedSignal = function(a, b)
			local path = if a == self then b else a
			return Data.GetIndexChangedSignal(self, path)
		end,
		GetArrayInsertedSignal = function(a, b)
			local path = if a == self then b else a
			return Data.GetArrayInsertedSignal(self, path)
		end,
		GetArrayRemovedSignal = function(a, b)
			local path = if a == self then b else a
			return Data.GetArrayRemovedSignal(self, path)
		end,
		Typed = function(a, b)
			local path = if a == self then b else a
			return Data.Typed(self, path)
		end,
		Destroy = function()
			return Data.Destroy(self)
		end,
		[ROOT_KEY] = initial,
		[WRITABLE_KEY] = writable ~= false,
		[STRICT_PATHS_KEY] = if options and options.StrictPaths ~= nil then options.StrictPaths else true,
		[AUTO_CREATE_KEY] = if options and options.AutoCreateMissingTables ~= nil then options.AutoCreateMissingTables else false,
		[CHANGED_MAP_KEY] = {} :: { [string]: SignalT },
		[INDEX_CHANGED_MAP_KEY] = {} :: { [string]: SignalT },
		[ARRAY_INSERTED_MAP_KEY] = {} :: { [string]: SignalT },
		[ARRAY_REMOVED_MAP_KEY] = {} :: { [string]: SignalT },
		[TRANSIENT_KEY] = {} :: { [string]: any },
		Changed = Signal.new(),
		Destroyed = false,
	}

	return (self :: any) :: Data<T>
end

const descend = function(root: any, path: DataPath?, ensureLeaf: boolean): (any?, any?)
	if not path or #path == 0 then
		return nil, nil
	end
	local parent = root
	for i = 1, #path - 1 do
		local k = path[i]
		local nextValue = rawget(parent, k)
		if type(nextValue) ~= "table" then
			if ensureLeaf then
				rawset(parent, k, {})
				nextValue = rawget(parent, k)
			else
				return nil, nil
			end
		end
		parent = nextValue
	end
	return parent, path[#path]
end

--[=[
	@method Get
	@within Data
	@param path PathToken? -- Path tipado ou array legado. Omita para a raiz merged.
	@return any
	Reads the merged value (persisted + transient overlay). Omit path for the full root.
]=]
function Data:Get(path: DataPathLike?): any
	local normalized = normalizePath(path, true) or {}
	return getMergedValue(self, normalized)
end

--[=[
	@method GetPersisted
	@within Data
	@tag Query
	@param path PathToken?
	@return any
	Reads the saved ProfileStore value only (ignores transient overlay).
]=]
function Data:GetPersisted(path: DataPathLike?): any
	local normalized = normalizePath(path, true)
	if not normalized or #normalized == 0 then
		return self[ROOT_KEY]
	end
	return getPersistedAt(self[ROOT_KEY], normalized)
end

--[=[
	@method GetTransient
	@within Data
	@tag Query
	@param path PathToken?
	@return any?
	Reads the transient overlay at path, if present.
]=]
function Data:GetTransient(path: DataPathLike?): any
	local normalized = normalizePath(path, true) or {}
	return self[TRANSIENT_KEY][Path.toKey(normalized)]
end

--[=[
	@method HasTransient
	@within Data
	@tag Query
	@param path PathToken?
	@return boolean
	Returns whether a transient overlay exists at or below the path.
]=]
function Data:HasTransient(path: DataPathLike?): boolean
	local normalized = normalizePath(path, true) or {}
	local key = Path.toKey(normalized)
	local transient = self[TRANSIENT_KEY]
	if transient[key] ~= nil then
		return true
	end
	for tKey in transient do
		if isDescendantPath(tKey, key) then
			return true
		end
	end
	return false
end

--[=[
	@method Typed
	@within Data
	@param path PathToken
	@return PathToken
	Type helper for stronger inference in signals and read/write calls.
]=]
function Data:Typed(path: DataPathLike): any
	return path :: any
end

function Data:_fireChanged(path: DataPath, newValue: any, oldValue: any)
	if newValue == oldValue then
		return
	end
	local key = Path.toKey(path)
	local sig = self[CHANGED_MAP_KEY][key]
	if sig then
		sig:Fire(newValue, oldValue)
	end
	if #path > 0 then
		local parentKey = Path.toKey(Path.parent(path))
		local idx = self[INDEX_CHANGED_MAP_KEY][parentKey]
		if idx then
			idx:Fire(path[#path], newValue, oldValue)
		end
	end
end

function Data:_applySet(path: DataPath, value: any)
	assert(path and #path > 0, "Data: path must be non-empty")
	local parent, key = descend(self[ROOT_KEY], path, self[AUTO_CREATE_KEY])
	assert(parent ~= nil and key ~= nil, string.format(INVALID_PATH_ERROR, pathToString(path)))
	local old = rawget(parent, key)
	if self[STRICT_PATHS_KEY] and not self[AUTO_CREATE_KEY] and old == nil and type(key) ~= "number" then
		error(string.format(INVALID_PATH_ERROR, pathToString(path)))
	end
	rawset(parent, key, value)
	Data._fireChanged(self, path, value, old)
end

function Data._applyTransientSet(self: any, path: DataPath, value: any)
	local oldMerged = Data.Get(self, path)
	self[TRANSIENT_KEY][Path.toKey(path)] = value
	local newMerged = Data.Get(self, path)
	Data._fireChanged(self, path, newMerged, oldMerged)
end

function Data._applyTransientArrayInsert(self: any, path: DataPath, value: any, index: number?)
	local current = Data.Get(self, path)
	local arr = if type(current) == "table" then copyArray(current) else {}
	if index then
		table.insert(arr, index, value)
	else
		table.insert(arr, value)
		index = #arr
	end
	Data._applyTransientSet(self, path, arr)
	local sig = self[ARRAY_INSERTED_MAP_KEY][Path.toKey(path)]
	if sig then
		sig:Fire(index, value)
	end
end

function Data._applyTransientArrayRemove(self: any, path: DataPath, index: number): any
	local current = Data.Get(self, path)
	local arr = if type(current) == "table" then copyArray(current) else {}
	local removed = table.remove(arr, index)
	Data._applyTransientSet(self, path, arr)
	local sig = self[ARRAY_REMOVED_MAP_KEY][Path.toKey(path)]
	if sig then
		sig:Fire(index, removed)
	end
	return removed
end

function Data._applyTransientClear(self: any, path: DataPath?)
	if path then
		local key = Path.toKey(path)
		if self[TRANSIENT_KEY][key] == nil then
			return
		end
		local oldMerged = Data.Get(self, path)
		self[TRANSIENT_KEY][key] = nil
		local newMerged = Data.Get(self, path)
		Data._fireChanged(self, path, newMerged, oldMerged)
		return
	end

	if next(self[TRANSIENT_KEY]) == nil then
		return
	end
	table.clear(self[TRANSIENT_KEY])
end

function Data:_applyArrayInsert(path: DataPath, value: any, index: number?)
	local arr = getPersistedAt(self[ROOT_KEY], path)
	assert(type(arr) == "table", "Data: ArrayInsert requires an array path")
	if index then
		table.insert(arr, index, value)
	else
		table.insert(arr, value)
		index = #arr
	end
	local sig = self[ARRAY_INSERTED_MAP_KEY][Path.toKey(path)]
	if sig then
		sig:Fire(index, value)
	end
end

function Data:_applyArrayRemove(path: DataPath, index: number): any
	local arr = getPersistedAt(self[ROOT_KEY], path)
	assert(type(arr) == "table", "Data: ArrayRemove requires an array path")
	local removed = table.remove(arr, index)
	local sig = self[ARRAY_REMOVED_MAP_KEY][Path.toKey(path)]
	if sig then
		sig:Fire(index, removed)
	end
	return removed
end

--[=[
	@method Set
	@within Data
	@tag Mutation
	@param path PathToken
	@param value any
	Writes and persists to ProfileStore. **Server only.**
]=]
function Data:Set(path: DataPathLike, value: any)
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	Data._applySet(self, normalized, value)
	self.Changed:Fire(Enums.Set, normalized, value)
end

--[=[
	@method SetTransient
	@within Data
	@tag Mutation
	@param path PathToken
	@param value any
	Writes a transient overlay visible in `Get()` but **not saved**. **Server only.**
]=]
function Data:SetTransient(path: DataPathLike, value: any)
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	Data._applyTransientSet(self, normalized, value)
	self.Changed:Fire(Enums.SetTransient, normalized, value)
end

--[=[
	@method Update
	@within Data
	@tag Mutation
	@param path PathToken
	@param fn (any) -> any
	Updates the persisted value using a callback. **Server only.**
]=]
function Data:Update(path: DataPathLike, fn: (any) -> any): any
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	local current = self:GetPersisted(normalized)
	local new = fn(current)
	self:Set(normalized, new)
	return new
end

--[=[
	@method UpdateTransient
	@within Data
	@tag Mutation
	@param path PathToken
	@param fn (any) -> any
	Updates the merged value through a transient overlay. **Server only.**
]=]
function Data:UpdateTransient(path: DataPathLike, fn: (any) -> any): any
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	local current = self:Get(normalized)
	local new = fn(current)
	self:SetTransient(normalized, new)
	return new
end

--[=[
	@method ClearTransient
	@within Data
	@tag Mutation
	@param path PathToken?
	Clears transient overlay at path, or all overlays when `path` is omitted. **Server only.**
]=]
function Data:ClearTransient(path: DataPathLike?)
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	if path ~= nil then
		local normalized = normalizePath(path, false) :: DataPath
		Data._applyTransientClear(self, normalized)
		self.Changed:Fire(Enums.ClearTransient, normalized)
		return
	end
	Data._applyTransientClear(self, nil)
	self.Changed:Fire(Enums.ClearTransient, nil)
end

--[=[
	@method ArrayInsert
	@within Data
	@tag Mutation
	@param path PathToken
	@param value any
	@param index number?
	Inserts into a persisted array. **Server only.**
]=]
function Data:ArrayInsert(path: DataPathLike, value: any, index: number?)
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	local arr = getPersistedAt(self[ROOT_KEY], normalized)
	assert(type(arr) == "table", "Data:ArrayInsert requires an array path")
	if index then
		table.insert(arr, index, value)
	else
		table.insert(arr, value)
		index = #arr
	end
	local sig = self[ARRAY_INSERTED_MAP_KEY][Path.toKey(normalized)]
	if sig then
		sig:Fire(index, value)
	end
	self.Changed:Fire(Enums.ArrayInsert, normalized, value, index)
end

--[=[
	@method ArrayInsertTransient
	@within Data
	@tag Mutation
	Inserts into an array through transient overlay. **Server only.**
]=]
function Data:ArrayInsertTransient(path: DataPathLike, value: any, index: number?)
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	Data._applyTransientArrayInsert(self, normalized, value, index)
	self.Changed:Fire(Enums.ArrayInsertTransient, normalized, value, index)
end

--[=[
	@method ArrayRemove
	@within Data
	@tag Mutation
	@param path PathToken
	@param index number
	Removes from a persisted array and returns the removed value. **Server only.**
]=]
function Data:ArrayRemove(path: DataPathLike, index: number): any
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	local arr = getPersistedAt(self[ROOT_KEY], normalized)
	assert(type(arr) == "table", "Data:ArrayRemove requires an array path")
	local removed = table.remove(arr, index)
	local sig = self[ARRAY_REMOVED_MAP_KEY][Path.toKey(normalized)]
	if sig then
		sig:Fire(index, removed)
	end
	self.Changed:Fire(Enums.ArrayRemove, normalized, index)
	return removed
end

--[=[
	@method ArrayRemoveTransient
	@within Data
	@tag Mutation
	Removes from an array through transient overlay. **Server only.**
]=]
function Data:ArrayRemoveTransient(path: DataPathLike, index: number): any
	assert(self[WRITABLE_KEY], READ_ONLY_ERROR)
	local normalized = normalizePath(path, false) :: DataPath
	local removed = Data._applyTransientArrayRemove(self, normalized, index)
	self.Changed:Fire(Enums.ArrayRemoveTransient, normalized, index)
	return removed
end

const normalizeOrder = function(order: OrderedListOrder?): string
	if order == nil then
		return PackageEnum.OrderList.Desc
	end
	if order == PackageEnum.OrderList.Asc or order == "asc" then
		return PackageEnum.OrderList.Asc
	end
	return PackageEnum.OrderList.Desc
end

--[=[
	@method GetOrderedList
	@within Data
	@tag Query
	@param path PathToken
	@param options OrderedListOptions
	@return { OrderedListEntry }
	Collects and sorts table entries by `options.key`. Supports `order` and `limit`.
]=]
function Data:GetOrderedList(path: DataPathLike, options: OrderedListOptions): { OrderedListEntry<any> }
	local normalized = normalizePath(path, false) :: DataPath
	local list = self:Get(normalized)
	assert(type(list) == "table", "Data:GetOrderedList requires a table path")

	local key = options.key
	local order = normalizeOrder(options.order)
	local entries = table.create(#list)

	for index, item in list do
		if type(item) == "table" then
			entries[#entries + 1] = {
				index = index,
				value = item,
				priority = item[key],
			}
		end
	end

	table.sort(entries, function(a, b)
		local left = a.priority
		local right = b.priority
		if order == PackageEnum.OrderList.Desc then
			return (left or 0) > (right or 0)
		end
		return (left or 0) < (right or 0)
	end)

	local limit = options.limit
	if limit and limit < #entries then
		local trimmed = table.create(limit)
		for i = 1, limit do
			trimmed[i] = entries[i]
		end
		return trimmed
	end

	return entries
end

--[=[
	@method GetOrderedListWithPriority
	@within Data
	@tag Query
	@param path PathToken
	@param key string
	@param order OrderedListOrder?
	Shortcut for `GetOrderedList` sorted by one field. Default order: `Enum.OrderList.Desc`.
]=]
function Data:GetOrderedListWithPriority(path: DataPathLike, key: string, order: OrderedListOrder?): { OrderedListEntry<any> }
	return self:GetOrderedList(path, {
		key = key,
		order = order or PackageEnum.OrderList.Desc,
	})
end

const ensureSignal = function(map: { [string]: SignalT }, key: string): SignalT
	if not map[key] then
		map[key] = Signal.new()
	end
	return map[key]
end

--[=[
	@method GetChangedSignal
	@within Data
	@tag Signals
	@param path PathToken
	@return Signal
	Fires when the merged value at path changes `(newValue, oldValue)`.
]=]
function Data:GetChangedSignal<V>(path: TypedPath<V> | DataPathLike): ChangedSignal<V>
	local normalized = normalizePath(path, false) :: DataPath
	return ensureSignal(self[CHANGED_MAP_KEY], Path.toKey(normalized)) :: ChangedSignal<V>
end

--[=[
	@method GetPathChangedSignal
	@within Data
	@tag Signals
	Alias of `GetChangedSignal`.
]=]
function Data:GetPathChangedSignal<V>(path: TypedPath<V> | DataPathLike): ChangedSignal<V>
	return self:GetChangedSignal(path)
end

--[=[
	@method GetIndexChangedSignal
	@within Data
	@tag Signals
	Fires when a direct child changes `(key, newValue, oldValue)`.
]=]
function Data:GetIndexChangedSignal<V>(path: TypedPath<V> | DataPathLike): IndexChangedSignal<V>
	local normalized = normalizePath(path, false) :: DataPath
	return ensureSignal(self[INDEX_CHANGED_MAP_KEY], Path.toKey(normalized)) :: IndexChangedSignal<V>
end

--[=[
	@method GetArrayInsertedSignal
	@within Data
	@tag Signals
	Fires when an item is inserted `(index, value)`.
]=]
function Data:GetArrayInsertedSignal<V>(path: TypedPath<{ V }> | DataPathLike): ArrayInsertedSignal<V>
	local normalized = normalizePath(path, false) :: DataPath
	return ensureSignal(self[ARRAY_INSERTED_MAP_KEY], Path.toKey(normalized)) :: ArrayInsertedSignal<V>
end

--[=[
	@method GetArrayRemovedSignal
	@within Data
	@tag Signals
	Fires when an item is removed `(index, removedValue)`.
]=]
function Data:GetArrayRemovedSignal<V>(path: TypedPath<{ V }> | DataPathLike): ArrayRemovedSignal<V>
	local normalized = normalizePath(path, false) :: DataPath
	return ensureSignal(self[ARRAY_REMOVED_MAP_KEY], Path.toKey(normalized)) :: ArrayRemovedSignal<V>
end

--[=[
	@method Destroy
	@within Data
	@tag Lifecycle
	Destroys internal signals and clears transient state.
]=]
function Data:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	table.clear(self[TRANSIENT_KEY])
	for _, s in self[CHANGED_MAP_KEY] do
		s:Destroy()
	end
	for _, s in self[INDEX_CHANGED_MAP_KEY] do
		s:Destroy()
	end
	for _, s in self[ARRAY_INSERTED_MAP_KEY] do
		s:Destroy()
	end
	for _, s in self[ARRAY_REMOVED_MAP_KEY] do
		s:Destroy()
	end
	self.Changed:Destroy()
end

return Data
