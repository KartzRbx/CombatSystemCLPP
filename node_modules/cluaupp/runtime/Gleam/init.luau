--!native
--!optimize 2
--!strict
-- Gleam — Cluaupp declarative UI (Vide-style sources + create). Scope = Sweep.

local RunService = game:GetService("RunService")

local Sweep = require(script.Parent.Sweep)
local Coil = require(script.Parent.Coil)

local Gleam = {}
Gleam.__index = Gleam

type Scope = {
	Sweep: any,
	Deps: { [any]: boolean },
	Alive: boolean,
	Tracking: boolean,
	Fn: () -> (),
	Running: boolean,
	Dirty: boolean,
}

export type Source<T> = {
	Get: (self: Source<T>) -> T,
	Set: (self: Source<T>, value: T) -> (),
	Listen: (self: Source<T>, fn: () -> ()) -> () -> (),
}

export type Action = {
	_gleamAction: boolean,
	Run: (instance: Instance) -> (),
}

local stack: { Scope } = {}
local untrackDepth = 0
local batchDepth = 0
local flushing = false
local pending: { [Scope]: boolean } = {}

local SETTLE = 0.0005

local ACTION_FLAG = "_gleamAction"
-- cluaupp: weak-table Sweep (Instance cannot take _gleamSweep)
local sweeps: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any

local function getSweep(instance: Instance): any?
	return sweeps[instance]
end

local function setSweep(instance: Instance, sweep: any)
	sweeps[instance] = sweep
end

local function peek(): Scope?
	return stack[#stack]
end

local function push(scope: Scope)
	table.insert(stack, scope)
end

local function pop()
	table.remove(stack)
end

local function isSource(value: any): boolean
	return typeof(value) == "table" and typeof(value.Get) == "function" and typeof(value.Set) == "function"
end

local function isAction(value: any): boolean
	return typeof(value) == "table" and value[ACTION_FLAG] == true and typeof(value.Run) == "function"
end

local function detach(scope: Scope)
	for src in scope.Deps do
		local effects = src._effects
		if effects then
			effects[scope] = nil
		end
	end
	table.clear(scope.Deps)
end

local function teardown(scope: Scope)
	if not scope.Alive then
		return
	end
	scope.Alive = false
	pending[scope] = nil
	detach(scope)
	scope.Sweep:Destroy()
end

local runScope: (scope: Scope) -> ()

local function flush()
	if flushing or batchDepth > 0 then
		return
	end
	flushing = true
	local n = 0
	local err: any = nil
	while true do
		local scope = next(pending)
		if not scope then
			break
		end
		pending[scope] = nil
		n += 1
		if n > 1000 then
			err = "Gleam effect loop"
			break
		end
		local ok, runErr = pcall(runScope, scope)
		if not ok then
			err = runErr
			break
		end
	end
	flushing = false
	if err ~= nil then
		error(err)
	end
end

local function schedule(scope: Scope)
	if not scope.Alive then
		return
	end
	if scope.Running then
		scope.Dirty = true
		return
	end
	pending[scope] = true
	flush()
end

runScope = function(scope: Scope)
	if not scope.Alive then
		return
	end
	if scope.Running then
		scope.Dirty = true
		return
	end
	scope.Running = true
	repeat
		scope.Dirty = false
		detach(scope)
		scope.Sweep:Cleanup()
		push(scope)
		local ok, err = pcall(scope.Fn)
		pop()
		if not ok then
			scope.Running = false
			error(err)
		end
	until not scope.Dirty or not scope.Alive
	scope.Running = false
end

local function subscribe(src: any, scope: Scope)
	if scope.Deps[src] then
		return
	end
	scope.Deps[src] = true
	src._effects[scope] = true
end

function Gleam.Source<T>(initial: T): Source<T>
	local src = {
		_value = initial,
		_effects = {} :: { [Scope]: boolean },
		_listens = {} :: { () -> () },
	}

	function src:Get(): T
		local scope = peek()
		if scope and scope.Tracking and untrackDepth == 0 then
			subscribe(src, scope)
		end
		return src._value
	end

	function src:Set(nextValue: T)
		if src._value == nextValue then
			return
		end
		src._value = nextValue
		batchDepth += 1
		local ok, err = pcall(function()
			for scope in src._effects do
				schedule(scope)
			end
			local listens = table.clone(src._listens)
			for _, fn in listens do
				fn()
			end
		end)
		batchDepth -= 1
		if not ok then
			flush()
			error(err)
		end
		flush()
	end

	function src:Listen(fn: () -> ()): () -> ()
		table.insert(src._listens, fn)
		return function()
			local index = table.find(src._listens, fn)
			if index then
				table.remove(src._listens, index)
			end
		end
	end

	return src :: any
end

function Gleam.Effect(fn: () -> ())
	local parent = peek()
	local sweep = Sweep.new()
	local scope: Scope = {
		Sweep = sweep,
		Deps = {},
		Alive = true,
		Tracking = true,
		Fn = fn,
		Running = false,
		Dirty = false,
	}
	if parent then
		parent.Sweep:Add(function()
			teardown(scope)
		end, true)
	end
	runScope(scope)
end

function Gleam.Derive<T>(compute: () -> T): Source<T>
	local derived = Gleam.Source((nil :: any) :: T)
	Gleam.Effect(function()
		derived:Set(compute())
	end)
	return derived
end

function Gleam.Untrack<T>(fn: () -> T): T
	untrackDepth += 1
	local ok, result = pcall(fn)
	untrackDepth -= 1
	if not ok then
		error(result)
	end
	return result
end

function Gleam.Batch(fn: () -> ())
	batchDepth += 1
	local ok, err = pcall(fn)
	batchDepth -= 1
	if not ok then
		flush()
		error(err)
	end
	flush()
end

function Gleam.Cleanup(fn: () -> ())
	local scope = peek()
	if scope then
		scope.Sweep:Add(fn, true)
	end
end

local function destroyNode(node: any)
	if node == nil then
		return
	end
	if typeof(node) == "Instance" then
		local sweep = getSweep(node)
		if sweep then
			sweeps[node] = nil
			sweep:Destroy()
		else
			node:Destroy()
		end
		return
	end
	if typeof(node) == "table" then
		if isSource(node) then
			destroyNode(node:Get())
			return
		end
		for _, child in node do
			destroyNode(child)
		end
	end
end

local function bindProperty(instance: Instance, key: any, value: any)
	if isSource(value) then
		Gleam.Effect(function()
			(instance :: any)[key] = value:Get()
		end)
		return
	end
	if typeof(value) == "function" then
		local ok, signal = pcall(function()
			return (instance :: any)[key]
		end)
		if ok and typeof(signal) == "RBXScriptSignal" then
			local scope = peek()
			if scope then
				scope.Sweep:Add(signal:Connect(value))
			else
				signal:Connect(value)
			end
			return
		end
		Gleam.Effect(function()
			(instance :: any)[key] = value()
		end)
		return
	end
	(instance :: any)[key] = value
end

local function unparentNode(node: any, parent: Instance)
	if typeof(node) == "Instance" then
		if node.Parent == parent then
			node.Parent = nil
		end
		return
	end
	if typeof(node) == "table" and not isSource(node) and not isAction(node) then
		for _, item in node do
			unparentNode(item, parent)
		end
	end
end

local adopt: (parent: Instance, child: any) -> ()

adopt = function(parent: Instance, child: any)
	if child == nil then
		return
	end
	if isAction(child) then
		(child :: Action).Run(parent)
		return
	end
	if isSource(child) then
		Gleam.Effect(function()
			local current = child:Get()
			Gleam.Cleanup(function()
				unparentNode(current, parent)
			end)
			adopt(parent, current)
		end)
		return
	end
	if typeof(child) == "function" then
		Gleam.Effect(function()
			local current = child()
			Gleam.Cleanup(function()
				unparentNode(current, parent)
			end)
			adopt(parent, current)
		end)
		return
	end
	if typeof(child) == "Instance" then
		child.Parent = parent
		return
	end
	if typeof(child) == "table" then
		for _, item in child do
			adopt(parent, item)
		end
	end
end

local function applyProps(instance: Instance, props: { [any]: any })
	local parentValue: any = nil
	local actions: { Action } = {}
	local children: { any } = {}

	for key, value in props do
		if isAction(value) then
			table.insert(actions, value)
		elseif key == "Parent" then
			parentValue = value
		elseif key == "Children" or typeof(key) == "number" then
			table.insert(children, value)
		else
			bindProperty(instance, key, value)
		end
	end

	for _, child in children do
		adopt(instance, child)
	end

	for _, action in actions do
		action.Run(instance)
	end

	if parentValue ~= nil then
		bindProperty(instance, "Parent", parentValue)
	end
end

local function pushSweepScope(sweep: any): Scope
	local scope: Scope = {
		Sweep = sweep,
		Deps = {},
		Alive = true,
		Tracking = false,
		Fn = function() end,
		Running = false,
		Dirty = false,
	}
	push(scope)
	return scope
end

function Gleam.Create(className: string, props: { [any]: any }?): Instance
	local instance = Instance.new(className)
	local sweep = Sweep.new()
	sweep:Add(instance, "Destroy")
	sweep:LinkToInstance(instance)
	setSweep(instance, sweep)

	local parent = peek()
	pushSweepScope(sweep)
	if props then
		applyProps(instance, props)
	end
	pop()

	if parent then
		parent.Sweep:Add(function()
			sweep:Destroy()
		end, true)
	end

	return instance
end

function Gleam.TextButton(props: { [any]: any }?): TextButton
	return Gleam.Create("TextButton", props) :: TextButton
end

function Gleam.TextLabel(props: { [any]: any }?): TextLabel
	return Gleam.Create("TextLabel", props) :: TextLabel
end

function Gleam.Frame(props: { [any]: any }?): Frame
	return Gleam.Create("Frame", props) :: Frame
end

function Gleam.ScreenGui(props: { [any]: any }?): ScreenGui
	return Gleam.Create("ScreenGui", props) :: ScreenGui
end

function Gleam.ImageLabel(props: { [any]: any }?): ImageLabel
	return Gleam.Create("ImageLabel", props) :: ImageLabel
end

function Gleam.ScrollingFrame(props: { [any]: any }?): ScrollingFrame
	return Gleam.Create("ScrollingFrame", props) :: ScrollingFrame
end

function Gleam.List(...: Instance): { Instance }
	return { ... }
end

function Gleam.Mount(instance: Instance, parent: Instance): () -> ()
	instance.Parent = parent
	local function unmount()
		destroyNode(instance)
	end
	local scope = peek()
	if scope then
		scope.Sweep:Add(unmount, true)
	end
	return unmount
end

function Gleam.Root(fn: () -> ()): () -> ()
	local sweep = Sweep.new()
	local scope: Scope = {
		Sweep = sweep,
		Deps = {},
		Alive = true,
		Tracking = false,
		Fn = fn,
		Running = false,
		Dirty = false,
	}
	push(scope)
	local ok, err = pcall(fn)
	pop()
	if not ok then
		teardown(scope)
		error(err)
	end
	return function()
		teardown(scope)
	end
end

function Gleam.Show<T>(source: Source<T>, render: (value: T) -> Instance?): Source<Instance?>
	local holder = Gleam.Source(nil :: Instance?)
	Gleam.Effect(function()
		local produced: Instance? = render(source:Get())
		Gleam.Cleanup(function()
			destroyNode(produced)
		end)
		holder:Set(produced)
	end)
	return holder
end

function Gleam.Switch<T>(source: Source<T>, map: { [any]: () -> Instance }): Source<Instance?>
	return Gleam.Show(source, function(value)
		local render = map[value]
		if render then
			return render()
		end
		return nil
	end)
end

function Gleam.Indexes<T>(source: Source<{ T }>, render: (item: Source<T>, index: number) -> Instance): Source<{ Instance }>
	local holder = Gleam.Source({} :: { Instance })
	Gleam.Effect(function()
		local items = source:Get()
		local result: { Instance } = {}
		if typeof(items) == "table" then
			for index, value in items do
				local item = Gleam.Source(value)
				result[index] = render(item, index)
			end
		end
		Gleam.Cleanup(function()
			destroyNode(result)
		end)
		holder:Set(result)
	end)
	return holder
end

function Gleam.Values<T>(source: Source<{ T }>, render: (item: Source<T>, value: T) -> Instance): Source<{ Instance }>
	local holder = Gleam.Source({} :: { Instance })
	Gleam.Effect(function()
		local items = source:Get()
		local result: { Instance } = {}
		if typeof(items) == "table" then
			for index, value in items do
				local item = Gleam.Source(value)
				result[index] = render(item, value)
			end
		end
		Gleam.Cleanup(function()
			destroyNode(result)
		end)
		holder:Set(result)
	end)
	return holder
end

local function coilSettled(spring: any): boolean
	return math.abs(spring.Position - spring.Goal) <= SETTLE and math.abs(spring.Velocity) <= SETTLE
end

local function makeCoils(value: any, damping: number, speed: number): ({ any }?, (coils: { any }) -> any, (goal: any, coils: { any }) -> ())
	local kind = typeof(value)
	if kind == "number" then
		return { Coil.new(damping, speed, value) }, function(coils)
			return coils[1]:Get()
		end, function(goal, coils)
			coils[1]:Set(goal)
		end
	end
	if kind == "Vector2" then
		return {
			Coil.new(damping, speed, value.X),
			Coil.new(damping, speed, value.Y),
		}, function(coils)
			return Vector2.new(coils[1]:Get(), coils[2]:Get())
		end, function(goal, coils)
			coils[1]:Set(goal.X)
			coils[2]:Set(goal.Y)
		end
	end
	if kind == "Vector3" then
		return {
			Coil.new(damping, speed, value.X),
			Coil.new(damping, speed, value.Y),
			Coil.new(damping, speed, value.Z),
		}, function(coils)
			return Vector3.new(coils[1]:Get(), coils[2]:Get(), coils[3]:Get())
		end, function(goal, coils)
			coils[1]:Set(goal.X)
			coils[2]:Set(goal.Y)
			coils[3]:Set(goal.Z)
		end
	end
	if kind == "UDim2" then
		return {
			Coil.new(damping, speed, value.X.Scale),
			Coil.new(damping, speed, value.X.Offset),
			Coil.new(damping, speed, value.Y.Scale),
			Coil.new(damping, speed, value.Y.Offset),
		}, function(coils)
			return UDim2.new(coils[1]:Get(), coils[2]:Get(), coils[3]:Get(), coils[4]:Get())
		end, function(goal, coils)
			coils[1]:Set(goal.X.Scale)
			coils[2]:Set(goal.X.Offset)
			coils[3]:Set(goal.Y.Scale)
			coils[4]:Set(goal.Y.Offset)
		end
	end
	if kind == "Color3" then
		return {
			Coil.new(damping, speed, value.R),
			Coil.new(damping, speed, value.G),
			Coil.new(damping, speed, value.B),
		}, function(coils)
			return Color3.new(coils[1]:Get(), coils[2]:Get(), coils[3]:Get())
		end, function(goal, coils)
			coils[1]:Set(goal.R)
			coils[2]:Set(goal.G)
			coils[3]:Set(goal.B)
		end
	end
	return nil, function()
		return value
	end, function() end
end

function Gleam.Spring<T>(source: Source<T>, speed: number?, damping: number?): Source<T>
	local freq = speed or 8
	local damp = damping or 1
	local start = Gleam.Untrack(function()
		return source:Get()
	end)
	local derived = Gleam.Source(start)
	local coils, unpackPos, packGoal = makeCoils(start, damp, freq)

	if coils == nil then
		Gleam.Effect(function()
			derived:Set(source:Get())
		end)
		return derived
	end

	Gleam.Effect(function()
		local goal = source:Get()
		packGoal(goal, coils)
		local allSettled = true
		for _, spring in coils do
			if not coilSettled(spring) then
				allSettled = false
				break
			end
		end
		if allSettled then
			derived:Set(unpackPos(coils))
			return
		end
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function(dt)
			local done = true
			for _, spring in coils do
				spring:Step(dt)
				if not coilSettled(spring) then
					done = false
				end
			end
			if done then
				for _, spring in coils do
					spring.Position = spring.Goal
					spring.Velocity = 0
				end
				derived:Set(unpackPos(coils))
				if conn.Connected then
					conn:Disconnect()
				end
			else
				derived:Set(unpackPos(coils))
			end
		end)
		local scope = peek()
		if scope then
			scope.Sweep:Add(conn)
		end
	end)

	return derived
end

function Gleam.Apply(instance: Instance): (props: { [any]: any }) -> Instance
	return function(props)
		local sweep = getSweep(instance)
		if not sweep then
			sweep = Sweep.new()
			sweep:LinkToInstance(instance)
			setSweep(instance, sweep)
		end
		pushSweepScope(sweep)
		applyProps(instance, props)
		pop()
		return instance
	end
end

function Gleam.Action(fn: (instance: Instance) -> ()): Action
	return {
		_gleamAction = true,
		Run = fn,
	}
end

return Gleam
