--!native
--!optimize 2
--!strict
-- Spark — engine-grade yield-safe signal.
-- Intrusive doubly-linked list (O(1) Disconnect, Fire-safe unhook).
-- Pooled runner threads (GoodSignal). Reentrant Fire is queued, not stacked.
-- Destroy seals the signal. ConnectParallel never reuses the serial runner.

export type SparkConnection = {
	Connected: boolean,
	Disconnect: (self: SparkConnection) -> (),
	Destroy: (self: SparkConnection) -> (),
}

export type Connection = SparkConnection

export type Spark<T...> = {
	Fire: (self: Spark<T...>, T...) -> (),
	FireDeferred: (self: Spark<T...>, T...) -> (),
	Connect: (self: Spark<T...>, fn: (T...) -> ()) -> SparkConnection,
	ConnectParallel: (self: Spark<T...>, fn: (T...) -> ()) -> SparkConnection,
	Once: (self: Spark<T...>, fn: (T...) -> ()) -> SparkConnection,
	OnceParallel: (self: Spark<T...>, fn: (T...) -> ()) -> SparkConnection,
	ConnectOnce: (self: Spark<T...>, fn: (T...) -> ()) -> SparkConnection,
	DisconnectAll: (self: Spark<T...>) -> (),
	GetConnections: (self: Spark<T...>) -> { SparkConnection },
	Destroy: (self: Spark<T...>) -> (),
	IsDestroyed: (self: Spark<T...>) -> boolean,
	Wait: (self: Spark<T...>) -> T...,
}

type Handler = (...any) -> ()
type Packed = { n: number, [number]: any }

type ConnectionNode = {
	Connected: boolean,
	_signal: SparkImpl?,
	_fn: Handler?,
	_next: ConnectionNode?,
	_prev: ConnectionNode?,
	_once: boolean,
	_parallel: boolean,
	Disconnect: (self: ConnectionNode) -> (),
	Destroy: (self: ConnectionNode) -> (),
}

type SparkImpl = {
	_head: ConnectionNode?,
	_tail: ConnectionNode?,
	_count: number,
	_destroyed: boolean,
	_firing: boolean,
	_queue: { Packed },
	_queueN: number,
	_proxyHandler: RBXScriptConnection?,
	_yieldedThreads: { [thread]: boolean }?,
	Fire: (self: SparkImpl, ...any) -> (),
	FireDeferred: (self: SparkImpl, ...any) -> (),
	Connect: (self: SparkImpl, fn: Handler) -> ConnectionNode,
	ConnectParallel: (self: SparkImpl, fn: Handler) -> ConnectionNode,
	Once: (self: SparkImpl, fn: Handler) -> ConnectionNode,
	OnceParallel: (self: SparkImpl, fn: Handler) -> ConnectionNode,
	ConnectOnce: (self: SparkImpl, fn: Handler) -> ConnectionNode,
	DisconnectAll: (self: SparkImpl) -> (),
	GetConnections: (self: SparkImpl) -> { SparkConnection },
	Destroy: (self: SparkImpl) -> (),
	IsDestroyed: (self: SparkImpl) -> boolean,
	Wait: (self: SparkImpl) -> ...any,
}

local MAX_CONNECTIONS = 4096
local MAX_REENTRY = 64
local PACK_POOL_CAP = 16
local SNAP_POOL_CAP = 8

local freeRunnerThread: thread? = nil
local packPool: { Packed } = {}
local packPoolN = 0
local snapPool: { { ConnectionNode } } = {}
local snapPoolN = 0

local function acquirePack(...: any): Packed
	local packed: Packed
	if packPoolN > 0 then
		packed = packPool[packPoolN]
		packPool[packPoolN] = nil
		packPoolN -= 1
	else
		packed = table.pack(...)
		return packed
	end
	local n = select("#", ...)
	packed.n = n
	for i = 1, n do
		packed[i] = select(i, ...)
	end
	return packed
end

local function releasePack(packed: Packed)
	for i = 1, packed.n do
		packed[i] = nil
	end
	packed.n = 0
	if packPoolN < PACK_POOL_CAP then
		packPoolN += 1
		packPool[packPoolN] = packed
	end
end

local function acquireSnap(): { ConnectionNode }
	if snapPoolN > 0 then
		local snap = snapPool[snapPoolN]
		snapPool[snapPoolN] = nil
		snapPoolN -= 1
		return snap
	end
	return {}
end

local function releaseSnap(snap: { ConnectionNode }, n: number)
	for i = 1, n do
		snap[i] = nil
	end
	if snapPoolN < SNAP_POOL_CAP then
		snapPoolN += 1
		snapPool[snapPoolN] = snap
	end
end

local function acquireRunnerThreadAndCallEventHandler(fn: Handler, ...: any)
	local acquired = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	freeRunnerThread = acquired
end

local function runEventHandlerInFreeThread(...: any)
	acquireRunnerThreadAndCallEventHandler(...)
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

local function runParallelHandler(fn: Handler, ...: any)
	local desynced = pcall(task.desynchronize)
	fn(...)
	if desynced then
		pcall(task.synchronize)
	end
end

local function expectFunction(method: string, fn: Handler)
	if type(fn) ~= "function" then
		error(`Spark.{method} expected function, got {typeof(fn)}`, 4)
	end
end

local Connection = {}
Connection.__index = Connection

local function unlink(node: ConnectionNode)
	local signal = node._signal
	if not signal then
		return
	end
	local prev = node._prev
	local next = node._next
	if prev then
		prev._next = next
	elseif signal._head == node then
		signal._head = next
	end
	if next then
		next._prev = prev
	elseif signal._tail == node then
		signal._tail = prev
	end
	node._prev = nil
	-- Keep _next so an in-flight Fire iterator can continue.
	if node.Connected then
		signal._count -= 1
		if signal._count < 0 then
			signal._count = 0
		end
	end
end

local function clearNode(node: ConnectionNode)
	node._fn = nil
	node._signal = nil
	node._once = false
	node._parallel = false
end

function Connection.Disconnect(self: ConnectionNode)
	if not self.Connected then
		return
	end
	unlink(self)
	self.Connected = false
	clearNode(self)
end

Connection.Destroy = Connection.Disconnect

local function deadConnection(): ConnectionNode
	return setmetatable({
		Connected = false,
		_signal = nil,
		_fn = nil,
		_next = nil,
		_prev = nil,
		_once = false,
		_parallel = false,
	}, Connection) :: any
end

local Spark = {}
Spark.__index = Spark

local function invoke(conn: ConnectionNode, ...: any)
	local fn = conn._fn
	if not fn then
		return
	end
	local parallel = conn._parallel
	if conn._once then
		conn:Disconnect()
	end
	if parallel then
		task.spawn(runParallelHandler, fn, ...)
		return
	end
	if not freeRunnerThread then
		freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
	end
	task.spawn(freeRunnerThread :: thread, fn, ...)
end

local function dispatchList(self: SparkImpl, ...: any)
	local item = self._head
	while item do
		if item.Connected then
			invoke(item, ...)
		end
		item = item._next
	end
end

local function bind(self: SparkImpl, fn: Handler, once: boolean, parallel: boolean): ConnectionNode
	if self._destroyed then
		return deadConnection()
	end
	expectFunction(if parallel then "ConnectParallel" else "Connect", fn)
	if self._count >= MAX_CONNECTIONS then
		warn(`Spark: connection cap ({MAX_CONNECTIONS}) reached; refusing Connect`)
		return deadConnection()
	end

	local node = setmetatable({
		Connected = true,
		_signal = self,
		_fn = fn,
		_next = self._head,
		_prev = nil,
		_once = once,
		_parallel = parallel,
	}, Connection) :: ConnectionNode

	if self._head then
		self._head._prev = node
	else
		self._tail = node
	end
	self._head = node
	self._count += 1
	return node
end

function Spark.new<T...>(): Spark<T...>
	return setmetatable({
		_head = nil,
		_tail = nil,
		_count = 0,
		_destroyed = false,
		_firing = false,
		_queue = {},
		_queueN = 0,
		_proxyHandler = nil,
		_yieldedThreads = nil,
	}, Spark) :: any
end

Spark.New = Spark.new

function Spark.Wrap<T...>(rbxScriptSignal: RBXScriptSignal): Spark<T...>
	if typeof(rbxScriptSignal) ~= "RBXScriptSignal" then
		error("Spark.Wrap expected RBXScriptSignal, got " .. typeof(rbxScriptSignal), 2)
	end
	local spark = Spark.new() :: SparkImpl
	spark._proxyHandler = rbxScriptSignal:Connect(function(...: any)
		if not spark._destroyed then
			spark:Fire(...)
		end
	end)
	return spark :: any
end

function Spark.Is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Spark
end

function Spark.Connect(self: SparkImpl, fn: Handler): ConnectionNode
	return bind(self, fn, false, false)
end

function Spark.ConnectParallel(self: SparkImpl, fn: Handler): ConnectionNode
	return bind(self, fn, false, true)
end

function Spark.Once(self: SparkImpl, fn: Handler): ConnectionNode
	return bind(self, fn, true, false)
end

function Spark.OnceParallel(self: SparkImpl, fn: Handler): ConnectionNode
	return bind(self, fn, true, true)
end

function Spark.ConnectOnce(self: SparkImpl, fn: Handler): ConnectionNode
	return bind(self, fn, true, false)
end

function Spark.GetConnections(self: SparkImpl): { SparkConnection }
	local items = table.create(self._count)
	local i = 0
	local item = self._head
	while item do
		if item.Connected then
			i += 1
			items[i] = item
		end
		item = item._next
	end
	return items
end

function Spark.IsDestroyed(self: SparkImpl): boolean
	return self._destroyed
end

function Spark.DisconnectAll(self: SparkImpl)
	local item = self._head
	self._head = nil
	self._tail = nil
	self._count = 0
	while item do
		local next = item._next
		item.Connected = false
		clearNode(item)
		item = next
	end

	local yielded = self._yieldedThreads
	if not yielded then
		return
	end
	for thread in yielded do
		if coroutine.status(thread) == "suspended" then
			warn(debug.traceback(thread, "spark disconnected; yielded thread cancelled", 2))
			task.cancel(thread)
		end
	end
	table.clear(yielded)
end

function Spark.Fire(self: SparkImpl, ...: any)
	if self._destroyed or self._count == 0 then
		return
	end
	if self._firing then
		if self._queueN >= MAX_REENTRY then
			warn("Spark: reentrant Fire dropped (queue full)")
			return
		end
		self._queueN += 1
		self._queue[self._queueN] = acquirePack(...)
		return
	end

	self._firing = true
	dispatchList(self, ...)
	local i = 1
	while i <= self._queueN do
		local packed = self._queue[i]
		self._queue[i] = nil
		dispatchList(self, table.unpack(packed, 1, packed.n))
		releasePack(packed)
		i += 1
	end
	self._queueN = 0
	self._firing = false
end

local function deferredFlush(snap: { ConnectionNode }, n: number, packed: Packed)
	for i = 1, n do
		local conn = snap[i]
		if conn and conn.Connected then
			invoke(conn, table.unpack(packed, 1, packed.n))
		end
	end
	releaseSnap(snap, n)
	releasePack(packed)
end

function Spark.FireDeferred(self: SparkImpl, ...: any)
	if self._destroyed or self._count == 0 then
		return
	end
	local snap = acquireSnap()
	local n = 0
	local item = self._head
	while item do
		if item.Connected then
			n += 1
			snap[n] = item
		end
		item = item._next
	end
	if n == 0 then
		releaseSnap(snap, 0)
		return
	end
	task.defer(deferredFlush, snap, n, acquirePack(...))
end

function Spark.Wait(self: SparkImpl): ...any
	if self._destroyed then
		error("Spark.Wait on destroyed signal", 2)
	end

	local yielded = self._yieldedThreads
	if not yielded then
		yielded = {}
		self._yieldedThreads = yielded
	end

	local thread = coroutine.running()
	yielded[thread] = true
	local pending: Packed? = nil

	self:Once(function(...: any)
		yielded[thread] = nil
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		else
			pending = table.pack(...)
		end
	end)

	if pending then
		return table.unpack(pending, 1, pending.n)
	end
	return coroutine.yield()
end

function Spark.Destroy(self: SparkImpl)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:DisconnectAll()
	local proxy = self._proxyHandler
	if proxy then
		proxy:Disconnect()
		self._proxyHandler = nil
	end
	table.clear(self._queue)
	self._queueN = 0
end

Spark.Connection = Connection

return Spark
