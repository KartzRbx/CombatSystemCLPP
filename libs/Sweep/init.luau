--!native
--!optimize 2
--!strict
-- Sweep — Cluaupp zelador. Flare sends; Sweep clears.
-- Auto-detects Disconnect / Destroy / task.cancel / call / Promise cancel.
-- Indexed Add replaces and cleans the previous task.

local Sweep = {}
Sweep.__index = Sweep

export type Sweep = typeof(setmetatable(
	{} :: {
		CurrentlyCleaning: boolean,
		_frozen: boolean,
		_tasks: { any },
		_methods: { any },
		_indices: { [any]: number },
		_links: { RBXScriptConnection },
	},
	Sweep
))

local function typeofOk(value: any): string
	return typeof(value)
end

local function cleanupOne(object: any, method: any)
	if object == nil then
		return
	end
	local kind = typeofOk(object)
	if method == true or typeofOk(method) == "function" then
		local fn = if typeofOk(method) == "function" then method else object
		if typeofOk(fn) == "function" then
			fn()
		end
		return
	end
	if typeofOk(method) == "string" then
		local fn = object[method]
		if typeofOk(fn) == "function" then
			if method == "Destroy" and kind == "Instance" then
				pcall(fn, object)
			else
				fn(object)
			end
		end
		return
	end
	if kind == "RBXScriptConnection" then
		if object.Connected then
			object:Disconnect()
		end
		return
	end
	if kind == "Instance" then
		pcall(function()
			(object :: Instance):Destroy()
		end)
		return
	end
	if kind == "thread" then
		pcall(task.cancel, object)
		return
	end
	if kind == "function" then
		object()
		return
	end
	if kind == "table" then
		if typeofOk(object.Cancel) == "function" and object.getStatus then
			pcall(object.Cancel, object)
			return
		end
		if typeofOk(object.Destroy) == "function" then
			object:Destroy()
			return
		end
		if typeofOk(object.Disconnect) == "function" then
			object:Disconnect()
			return
		end
		if typeofOk(object.DisconnectAll) == "function" then
			object:DisconnectAll()
		end
	end
end

local function detect(object: any): any
	local kind = typeofOk(object)
	if kind == "RBXScriptConnection" then
		return "Disconnect"
	end
	if kind == "Instance" then
		return "Destroy"
	end
	if kind == "thread" then
		return true
	end
	if kind == "function" then
		return true
	end
	if kind == "table" then
		if typeofOk(object.Cancel) == "function" and object.getStatus then
			return "Cancel"
		end
		if typeofOk(object.Destroy) == "function" then
			return "Destroy"
		end
		if typeofOk(object.Disconnect) == "function" then
			return "Disconnect"
		end
		if typeofOk(object.DisconnectAll) == "function" then
			return "DisconnectAll"
		end
	end
	return "Destroy"
end

function Sweep.new(): Sweep
	return setmetatable({
		CurrentlyCleaning = false,
		_frozen = false,
		_tasks = {},
		_methods = {},
		_indices = {},
		_links = {},
	}, Sweep)
end

function Sweep:Add<T>(object: T, methodName: (boolean | string)?, index: any?): T
	if self._frozen or self.CurrentlyCleaning then
		return object
	end
	local method: any = methodName
	if method == nil then
		method = detect(object)
	end
	if index ~= nil then
		local previous = self._indices[index]
		if previous then
			local oldObject = self._tasks[previous]
			local oldMethod = self._methods[previous]
			self._tasks[previous] = nil
			self._methods[previous] = nil
			self._indices[index] = nil
			cleanupOne(oldObject, oldMethod)
		end
		table.insert(self._tasks, object)
		table.insert(self._methods, method)
		self._indices[index] = #self._tasks
		return object
	end
	table.insert(self._tasks, object)
	table.insert(self._methods, method)
	return object
end

function Sweep:Remove(index: any): Sweep
	local slot = self._indices[index]
	if not slot then
		return self
	end
	local object = self._tasks[slot]
	local method = self._methods[slot]
	self._tasks[slot] = nil
	self._methods[slot] = nil
	self._indices[index] = nil
	cleanupOne(object, method)
	return self
end

function Sweep:RemoveNoClean(index: any): Sweep
	local slot = self._indices[index]
	if not slot then
		return self
	end
	self._tasks[slot] = nil
	self._methods[slot] = nil
	self._indices[index] = nil
	return self
end

function Sweep:Get(index: any): any
	local slot = self._indices[index]
	if not slot then
		return nil
	end
	return self._tasks[slot]
end

function Sweep:Cleanup()
	if self.CurrentlyCleaning then
		return
	end
	self.CurrentlyCleaning = true
	for i = #self._tasks, 1, -1 do
		local object = self._tasks[i]
		local method = self._methods[i]
		self._tasks[i] = nil
		self._methods[i] = nil
		cleanupOne(object, method)
	end
	table.clear(self._indices)
	self.CurrentlyCleaning = false
end

function Sweep:Destroy()
	self:Cleanup()
	self._frozen = true
	for _, link in self._links do
		if link.Connected then
			link:Disconnect()
		end
	end
	table.clear(self._links)
end

function Sweep:LinkToInstance(object: Instance, allowMultiple: boolean?): RBXScriptConnection
	if self._frozen then
		return (nil :: any)
	end
	if not allowMultiple then
		self:Remove("LinkToInstance")
	end
	local function onGone()
		self:Destroy()
	end
	local destroying = object.Destroying:Connect(onGone)
	local ancestry = object.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			onGone()
		end
	end)
	table.insert(self._links, destroying)
	table.insert(self._links, ancestry)
	if not allowMultiple then
		self._indices["LinkToInstance"] = #self._links
	end
	return destroying
end

function Sweep.Is(value: any): boolean
	return typeof(value) == "table" and getmetatable(value) == Sweep
end

Sweep.AddPromise = function(self: Sweep, promise: any, index: any?): any
	return self:Add(promise, "Cancel", index)
end

Sweep.New = Sweep.new

setmetatable(Sweep, {
	__call = function()
		return Sweep.new()
	end,
})

return Sweep
