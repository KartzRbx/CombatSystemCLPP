--!native
--!optimize 2
--!strict
-- Hive — archetype ECS. Component ids are u8. Authoritative worlds refuse client writes.

local RunService = game:GetService("RunService")

local Hive = {}
Hive.__index = Hive

export type HiveWorld = typeof(setmetatable(
	{} :: {
		Next: number,
		Entities: { [number]: boolean },
		Columns: { [number]: { [number]: any } },
		Schema: any,
		Authoritative: boolean,
	},
	Hive
))

local TYPE = { Nil = 0, Bool = 1, Number = 2, String = 3, Table = 4 }

local function grow(buf: buffer, need: number): buffer
	if buffer.len(buf) >= need then
		return buf
	end
	local nextBuf = buffer.create(math.max(need, buffer.len(buf) * 2))
	buffer.copy(nextBuf, 0, buf, 0, buffer.len(buf))
	return nextBuf
end

local writeValue: (buffer, number, any) -> (buffer, number)

writeValue = function(buf: buffer, cursor: number, value: any): (buffer, number)
	local kind = typeof(value)
	buf = grow(buf, cursor + 16)
	if value == nil then
		buffer.writeu8(buf, cursor, TYPE.Nil)
		return buf, cursor + 1
	end
	if kind == "boolean" then
		buffer.writeu8(buf, cursor, TYPE.Bool)
		buffer.writeu8(buf, cursor + 1, if value then 1 else 0)
		return buf, cursor + 2
	end
	if kind == "number" then
		buffer.writeu8(buf, cursor, TYPE.Number)
		buffer.writef64(buf, cursor + 1, value)
		return buf, cursor + 9
	end
	if kind == "string" then
		buffer.writeu8(buf, cursor, TYPE.String)
		buf = grow(buf, cursor + 3 + #value)
		buffer.writeu16(buf, cursor + 1, #value)
		buffer.writestring(buf, cursor + 3, value)
		return buf, cursor + 3 + #value
	end
	if kind == "Instance" then
		if value:IsA("Player") then
			buffer.writeu8(buf, cursor, TYPE.Number)
			buffer.writef64(buf, cursor + 1, value.UserId)
			return buf, cursor + 9
		end
		buffer.writeu8(buf, cursor, TYPE.Nil)
		return buf, cursor + 1
	end
	if kind == "table" then
		buffer.writeu8(buf, cursor, TYPE.Table)
		cursor += 1
		local count = 0
		for _ in value do
			count += 1
		end
		buf = grow(buf, cursor + 2)
		buffer.writeu16(buf, cursor, count)
		cursor += 2
		for key, item in value do
			buf, cursor = writeValue(buf, cursor, key)
			buf, cursor = writeValue(buf, cursor, item)
		end
		return buf, cursor
	end
	buffer.writeu8(buf, cursor, TYPE.Nil)
	return buf, cursor + 1
end

function Hive.World(schema: any, authoritative: boolean?): HiveWorld
	return setmetatable({
		Next = 1,
		Entities = {},
		Columns = {},
		Schema = schema,
		Authoritative = if authoritative ~= nil then authoritative else true,
	}, Hive)
end

function Hive.AuthoritativeWorld(schema: any): HiveWorld
	return Hive.World(schema, true)
end

local function canWrite(self: any): boolean
	if not self.Authoritative then
		return true
	end
	return RunService:IsServer()
end

function Hive:Entity(): number
	if not canWrite(self) then
		return 0
	end
	local id = self.Next
	self.Next += 1
	self.Entities[id] = true
	return id
end

function Hive:Set(entity: number, componentId: number, value: any)
	if not canWrite(self) then
		return
	end
	local column = self.Columns[componentId]
	if not column then
		column = {}
		self.Columns[componentId] = column
	end
	column[entity] = value
end

function Hive:Get(entity: number, componentId: number): any
	local column = self.Columns[componentId]
	return column and column[entity]
end

function Hive:Remove(entity: number, componentId: number)
	if not canWrite(self) then
		return
	end
	local column = self.Columns[componentId]
	if column then
		column[entity] = nil
	end
end

function Hive:Despawn(entity: number)
	if not canWrite(self) then
		return
	end
	self.Entities[entity] = nil
	for _, column in self.Columns do
		column[entity] = nil
	end
end

function Hive:Has(entity: number, componentId: number): boolean
	local column = self.Columns[componentId]
	return column ~= nil and column[entity] ~= nil
end

function Hive:Query(...: number): () -> (...any)
	local ids = { ... }
	if #ids == 0 then
		local entity: number? = nil
		return function()
			entity = next(self.Entities, entity)
			return entity
		end
	end
	local first = ids[1]
	local column = if first then self.Columns[first] or {} else {}
	local entity: number? = nil
	local count = #ids
	return function()
		while true do
			entity = next(column, entity)
			if entity == nil then
				return nil
			end
			local values = table.create(count)
			local ok = true
			for index = 1, count do
				local col = self.Columns[ids[index]]
				local value = col and col[entity]
				if value == nil then
					ok = false
					break
				end
				values[index] = value
			end
			if ok then
				return entity, table.unpack(values, 1, count)
			end
		end
	end
end

function Hive:Snapshot(componentId: number): buffer
	local column = self.Columns[componentId] or {}
	local count = 0
	for _ in column do
		count += 1
	end
	local buf = buffer.create(math.max(64, 5 + count * 16))
	buffer.writeu8(buf, 0, componentId)
	buffer.writeu32(buf, 1, count)
	local cursor = 5
	for entity, value in column do
		buf = grow(buf, cursor + 4)
		buffer.writeu32(buf, cursor, entity)
		cursor += 4
		buf, cursor = writeValue(buf, cursor, value)
	end
	local trimmed = buffer.create(cursor)
	buffer.copy(trimmed, 0, buf, 0, cursor)
	return trimmed
end

return Hive
