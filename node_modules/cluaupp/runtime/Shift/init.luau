--!native
--!optimize 2
--!strict
-- Shift — compiled FSM/HSM. State ids are u8. No per-frame OnDataChanged.

local Shift = {}
Shift.__index = Shift

export type ShiftMachine = typeof(setmetatable(
	{} :: {
		State: number,
		Previous: number,
		History: { number },
		Ids: { [string]: number },
		Names: { [number]: string },
		Parents: { [string]: string },
		Transitions: { { From: string, To: string, Guard: string } },
		Data: { [string]: any },
		Alive: boolean,
		_guards: { [string]: () -> boolean },
		_enters: { [string]: () -> () },
		_leaves: { [string]: () -> () },
	},
	Shift
))

local function ancestorChain(self: ShiftMachine, name: string?): { string }
	local chain = {}
	local current = name
	local seen: { [string]: boolean } = {}
	while current and not seen[current] do
		seen[current] = true
		table.insert(chain, 1, current)
		current = self.Parents[current]
	end
	return chain
end

local function inBranch(self: ShiftMachine, name: string): boolean
	local current = self.Names[self.State]
	local seen: { [string]: boolean } = {}
	while current and not seen[current] do
		if current == name then
			return true
		end
		seen[current] = true
		current = self.Parents[current]
	end
	return false
end

local function edgeAllowed(self: ShiftMachine, fromName: string?, toName: string): boolean?
	if fromName == nil then
		return nil
	end
	for _, edge in self.Transitions do
		if edge.From == fromName and edge.To == toName then
			if edge.Guard == "" or edge.Guard == nil then
				return true
			end
			local guard = self._guards[edge.Guard]
			if not guard then
				return true
			end
			return guard()
		end
	end
	return nil
end

function Shift.New(ids: { [string]: number }, transitions: { any }, parents: { [string]: string }?): ShiftMachine
	local names = {}
	local initial = 0
	for name, id in ids do
		names[id] = name
		if id == 0 then
			initial = 0
		end
	end
	return setmetatable({
		State = initial,
		Previous = initial,
		History = { initial },
		Ids = ids,
		Names = names,
		Parents = parents or {},
		Transitions = transitions,
		Data = {},
		Alive = true,
		_guards = {} :: { [string]: () -> boolean },
		_enters = {} :: { [string]: () -> () },
		_leaves = {} :: { [string]: () -> () },
	}, Shift)
end

function Shift:Guard(name: string, fn: () -> boolean)
	self._guards[name] = fn
end

function Shift:OnEnter(name: string, fn: () -> ())
	self._enters[name] = fn
	if self.Alive and self.Names[self.State] == name then
		fn()
	end
end

function Shift:OnLeave(name: string, fn: () -> ())
	self._leaves[name] = fn
end

function Shift:CanEnter(toName: string, visiting: { [string]: boolean }?): boolean
	if not self.Alive then
		return false
	end
	if self.Ids[toName] == nil then
		return false
	end
	local fromName = self.Names[self.State]
	if fromName == toName then
		return false
	end
	local explicit = edgeAllowed(self, fromName, toName)
	if explicit ~= nil then
		return explicit
	end
	local parent = self.Parents[toName]
	if parent == nil then
		return false
	end
	if inBranch(self, parent) then
		return true
	end
	local seen = visiting or {}
	if seen[toName] then
		return false
	end
	seen[toName] = true
	return self:CanEnter(parent, seen)
end

local function switchTo(self: ShiftMachine, name: string, id: number)
	local fromName = self.Names[self.State]
	local leaveChain = ancestorChain(self, fromName)
	local enterChain = ancestorChain(self, name)
	local common = 0
	local limit = math.min(#leaveChain, #enterChain)
	for index = 1, limit do
		if leaveChain[index] == enterChain[index] then
			common = index
		else
			break
		end
	end
	for index = #leaveChain, common + 1, -1 do
		local fn = self._leaves[leaveChain[index]]
		if fn then
			fn()
		end
	end
	self.Previous = self.State
	self.State = id
	table.insert(self.History, id)
	for index = common + 1, #enterChain do
		local fn = self._enters[enterChain[index]]
		if fn then
			fn()
		end
	end
end

function Shift:ChangeState(name: string)
	if not self.Alive then
		return
	end
	local id = self.Ids[name]
	if id == nil then
		return
	end
	if self.State == id then
		return
	end
	if not self:CanEnter(name) then
		return
	end
	switchTo(self, name, id)
end

function Shift:GetState(): string
	return self.Names[self.State] or ""
end

function Shift:GetCurrentState(): string
	return self:GetState()
end

function Shift:GetPreviousState(): string
	return self.Names[self.Previous] or ""
end

function Shift:GetId(): number
	return self.State
end

function Shift:WriteId(): buffer
	local buf = buffer.create(1)
	buffer.writeu8(buf, 0, self.State)
	return buf
end

function Shift:ReadId(buf: buffer)
	if not self.Alive then
		return
	end
	local id = buffer.readu8(buf, 0)
	local name = self.Names[id]
	if name == nil or self.State == id then
		return
	end
	switchTo(self, name, id)
end

function Shift:GetData()
	return self.Data
end

function Shift:ChangeData(index: string, value: any)
	self.Data[index] = value
end

function Shift:Destroy()
	self.Alive = false
	table.clear(self.Data)
	table.clear(self._guards)
	table.clear(self._enters)
	table.clear(self._leaves)
end

return Shift
