--!native
--!optimize 2
--!strict
-- Roster — Cluaupp table util (Bomb-Click API, PascalCase) + tagged buffer pack.
-- No JSONEncode / HttpService. Grow doubles like Keep.
--
-- Pack tags (u8):
--   0 Nil
--   1 Bool     u8 0|1
--   2 Number   f64
--   3 String   u16 len + bytes
--   4 Table    u16 count + (key, value)*     dictionary / mixed keys
--   5 Array    u16 len + values*             dense 1..n
--   6 Vector3  f32 x,y,z
--   7 CFrame   12 f32 components
--   8 Color3   u8 r,g,b

local Roster = {}
Roster.__index = Roster

export type Roster<T = any> = typeof(setmetatable({} :: { Data: { T } }, Roster))

local TYPE = {
	Nil = 0,
	Bool = 1,
	Number = 2,
	String = 3,
	Table = 4,
	Array = 5,
	Vector3 = 6,
	CFrame = 7,
	Color3 = 8,
}

Roster.TYPE = TYPE

local function grow(buf: buffer, need: number): buffer
	if buffer.len(buf) >= need then
		return buf
	end
	local nextBuf = buffer.create(math.max(need, buffer.len(buf) * 2))
	buffer.copy(nextBuf, 0, buf, 0, buffer.len(buf))
	return nextBuf
end

local function unwrap(source: any): { [any]: any }
	if typeof(source) ~= "table" then
		return {}
	end
	if getmetatable(source) == Roster then
		return source.Data
	end
	return source
end

local function asRoster(source: any, data: { [any]: any }): any
	if typeof(source) == "table" and getmetatable(source) == Roster then
		return source
	end
	return Roster.new(data)
end

local function writeString(buf: buffer, cursor: number, text: string): (buffer, number)
	buf = grow(buf, cursor + 2 + #text)
	buffer.writeu16(buf, cursor, #text)
	buffer.writestring(buf, cursor + 2, text)
	return buf, cursor + 2 + #text
end

local function readString(buf: buffer, cursor: number): (string, number)
	local length = buffer.readu16(buf, cursor)
	return buffer.readstring(buf, cursor + 2, length), cursor + 2 + length
end

local function isArray(value: { [any]: any }): (boolean, number)
	local arrayLen = #value
	local count = 0
	local arrayLike = true
	for key in value do
		count += 1
		if arrayLike and (typeof(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > arrayLen) then
			arrayLike = false
		end
	end
	if arrayLike and count == arrayLen then
		return true, arrayLen
	end
	return false, count
end

local writeValue: (buffer, number, any) -> (buffer, number)
local readValue: (buffer, number) -> (any, number)

writeValue = function(buf: buffer, cursor: number, value: any): (buffer, number)
	if typeof(value) == "table" and getmetatable(value) == Roster then
		value = value.Data
	end
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
		return writeString(buf, cursor + 1, value)
	end
	if kind == "Vector3" then
		buffer.writeu8(buf, cursor, TYPE.Vector3)
		buffer.writef32(buf, cursor + 1, value.X)
		buffer.writef32(buf, cursor + 5, value.Y)
		buffer.writef32(buf, cursor + 9, value.Z)
		return buf, cursor + 13
	end
	if kind == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
		buf = grow(buf, cursor + 49)
		buffer.writeu8(buf, cursor, TYPE.CFrame)
		buffer.writef32(buf, cursor + 1, x)
		buffer.writef32(buf, cursor + 5, y)
		buffer.writef32(buf, cursor + 9, z)
		buffer.writef32(buf, cursor + 13, r00)
		buffer.writef32(buf, cursor + 17, r01)
		buffer.writef32(buf, cursor + 21, r02)
		buffer.writef32(buf, cursor + 25, r10)
		buffer.writef32(buf, cursor + 29, r11)
		buffer.writef32(buf, cursor + 33, r12)
		buffer.writef32(buf, cursor + 37, r20)
		buffer.writef32(buf, cursor + 41, r21)
		buffer.writef32(buf, cursor + 45, r22)
		return buf, cursor + 49
	end
	if kind == "Color3" then
		buffer.writeu8(buf, cursor, TYPE.Color3)
		buffer.writeu8(buf, cursor + 1, math.clamp(math.floor(value.R * 255 + 0.5), 0, 255))
		buffer.writeu8(buf, cursor + 2, math.clamp(math.floor(value.G * 255 + 0.5), 0, 255))
		buffer.writeu8(buf, cursor + 3, math.clamp(math.floor(value.B * 255 + 0.5), 0, 255))
		return buf, cursor + 4
	end
	if kind == "table" then
		local arrayLike, count = isArray(value)
		if arrayLike then
			buffer.writeu8(buf, cursor, TYPE.Array)
			cursor += 1
			buf = grow(buf, cursor + 2)
			buffer.writeu16(buf, cursor, count)
			cursor += 2
			for index = 1, count do
				buf, cursor = writeValue(buf, cursor, value[index])
			end
			return buf, cursor
		end
		buffer.writeu8(buf, cursor, TYPE.Table)
		cursor += 1
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

readValue = function(buf: buffer, cursor: number): (any, number)
	local kind = buffer.readu8(buf, cursor)
	cursor += 1
	if kind == TYPE.Nil then
		return nil, cursor
	end
	if kind == TYPE.Bool then
		return buffer.readu8(buf, cursor) == 1, cursor + 1
	end
	if kind == TYPE.Number then
		return buffer.readf64(buf, cursor), cursor + 8
	end
	if kind == TYPE.String then
		return readString(buf, cursor)
	end
	if kind == TYPE.Vector3 then
		return Vector3.new(
			buffer.readf32(buf, cursor),
			buffer.readf32(buf, cursor + 4),
			buffer.readf32(buf, cursor + 8)
		),
			cursor + 12
	end
	if kind == TYPE.CFrame then
		return CFrame.new(
			buffer.readf32(buf, cursor),
			buffer.readf32(buf, cursor + 4),
			buffer.readf32(buf, cursor + 8),
			buffer.readf32(buf, cursor + 12),
			buffer.readf32(buf, cursor + 16),
			buffer.readf32(buf, cursor + 20),
			buffer.readf32(buf, cursor + 24),
			buffer.readf32(buf, cursor + 28),
			buffer.readf32(buf, cursor + 32),
			buffer.readf32(buf, cursor + 36),
			buffer.readf32(buf, cursor + 40),
			buffer.readf32(buf, cursor + 44)
		),
			cursor + 48
	end
	if kind == TYPE.Color3 then
		return Color3.fromRGB(buffer.readu8(buf, cursor), buffer.readu8(buf, cursor + 1), buffer.readu8(buf, cursor + 2)),
			cursor + 3
	end
	if kind == TYPE.Array then
		local length = buffer.readu16(buf, cursor)
		cursor += 2
		local out = table.create(length)
		for index = 1, length do
			out[index], cursor = readValue(buf, cursor)
		end
		return out, cursor
	end
	if kind == TYPE.Table then
		local count = buffer.readu16(buf, cursor)
		cursor += 2
		local out = {}
		for _ = 1, count do
			local key
			key, cursor = readValue(buf, cursor)
			local item
			item, cursor = readValue(buf, cursor)
			out[key] = item
		end
		return out, cursor
	end
	return nil, cursor
end

local function deepClone(value: any, seen: { [any]: any }): any
	if typeof(value) ~= "table" then
		return value
	end
	if getmetatable(value) == Roster then
		value = value.Data
	end
	local existing = seen[value]
	if existing then
		return existing
	end
	local copy = {}
	seen[value] = copy
	for key, item in value do
		copy[deepClone(key, seen)] = deepClone(item, seen)
	end
	return copy
end

local function groupKey(value: any, index: any, keyOrMapper: any): any
	if typeof(keyOrMapper) == "function" then
		return keyOrMapper(value, index)
	end
	if typeof(value) == "table" then
		return value[keyOrMapper]
	end
	return value
end

function Roster.new<T>(initial: { T }?): Roster<T>
	return setmetatable({ Data = initial or {} }, Roster)
end

Roster.New = Roster.new

function Roster.Size(source: any): number
	local count = 0
	for _ in unwrap(source) do
		count += 1
	end
	return count
end

function Roster.Length(source: any): number
	return #unwrap(source)
end

function Roster.IsEmpty(source: any): boolean
	return next(unwrap(source)) == nil
end

function Roster.GetData<T>(self: Roster<T>): { T }
	return self.Data
end

function Roster.At(source: any, index: number): any
	local data = unwrap(source)
	local i = index
	if i < 0 then
		i = #data + i + 1
	end
	return data[i]
end

function Roster.Find(source: any, value: any, initPos: number?, maxPos: number?): number?
	local data = unwrap(source)
	local startAt = math.max(1, initPos or 1)
	local endAt = math.min(#data, maxPos or #data)
	for index = startAt, endAt do
		if data[index] == value then
			return index
		end
	end
	return nil
end

function Roster.Includes(source: any, value: any): boolean
	return Roster.Find(source, value) ~= nil
end

function Roster.Add(source: any, ...: any): number
	local data = unwrap(source)
	for index = 1, select("#", ...) do
		table.insert(data, select(index, ...))
	end
	return #data
end

Roster.Push = Roster.Add

function Roster.Pop(source: any): any
	return table.remove(unwrap(source))
end

function Roster.Shift(source: any): any
	return table.remove(unwrap(source), 1)
end

function Roster.Unshift(source: any, ...: any): number
	local data = unwrap(source)
	for index = select("#", ...), 1, -1 do
		table.insert(data, 1, select(index, ...))
	end
	return #data
end

function Roster.RemoveAt(source: any, index: number): any
	return table.remove(unwrap(source), index)
end

function Roster.Remove(source: any, key: any): any
	local data = unwrap(source)
	data[key] = nil
	return asRoster(source, data)
end

function Roster.Map(source: any, mapper: (value: any, index: any) -> any): any
	local data = unwrap(source)
	local result = {}
	for index, value in data do
		result[index] = mapper(value, index)
	end
	return Roster.new(result)
end

function Roster.Filter(source: any, predicate: (value: any, index: any) -> boolean): any
	local result = {}
	for index, value in unwrap(source) do
		if predicate(value, index) then
			table.insert(result, value)
		end
	end
	return Roster.new(result)
end

function Roster.Reduce(source: any, reducer: (acc: any, value: any, index: any) -> any, initial: any): any
	local acc = initial
	for index, value in unwrap(source) do
		acc = reducer(acc, value, index)
	end
	return acc
end

function Roster.Some(source: any, predicate: (value: any, index: any) -> boolean): boolean
	for index, value in unwrap(source) do
		if predicate(value, index) then
			return true
		end
	end
	return false
end

function Roster.Every(source: any, predicate: (value: any, index: any) -> boolean): boolean
	for index, value in unwrap(source) do
		if not predicate(value, index) then
			return false
		end
	end
	return true
end

function Roster.ForEach(source: any, callback: (value: any, index: any) -> ()): ()
	for index, value in unwrap(source) do
		callback(value, index)
	end
end

function Roster.Reverse(source: any): any
	local data = unwrap(source)
	local result = table.create(#data)
	for index = #data, 1, -1 do
		table.insert(result, data[index])
	end
	return Roster.new(result)
end

function Roster.Clear(source: any): any
	local data = unwrap(source)
	table.clear(data)
	return asRoster(source, data)
end

function Roster.Clone(source: any): any
	return Roster.new(table.clone(unwrap(source)))
end

function Roster.DeepClone(source: any): any
	return Roster.new(deepClone(unwrap(source), {}))
end

function Roster.Keys(source: any): any
	local result = {}
	for key in unwrap(source) do
		table.insert(result, key)
	end
	return Roster.new(result)
end

function Roster.Values(source: any): any
	local result = {}
	for _, value in unwrap(source) do
		table.insert(result, value)
	end
	return Roster.new(result)
end

function Roster.Set(source: any, key: any, value: any): any
	local data = unwrap(source)
	data[key] = value
	return asRoster(source, data)
end

function Roster.Get(source: any, key: any, defaultValue: any?): any
	local value = unwrap(source)[key]
	if value == nil then
		return defaultValue
	end
	return value
end

function Roster.Has(source: any, key: any): boolean
	return unwrap(source)[key] ~= nil
end

function Roster.Concat(source: any, ...: any): any
	local data = unwrap(source)
	local total = #data
	local parts = table.create(select("#", ...))
	for index = 1, select("#", ...) do
		local other = unwrap(select(index, ...))
		parts[index] = other
		total += #other
	end
	local result = table.create(total)
	table.move(data, 1, #data, 1, result)
	local dest = #data + 1
	for _, other in parts do
		local length = #other
		table.move(other, 1, length, dest, result)
		dest += length
	end
	return Roster.new(result)
end

function Roster.Slice(source: any, startAt: number?, endAt: number?): any
	local data = unwrap(source)
	local n = #data
	local i = startAt or 1
	local j = endAt or n
	if i < 0 then
		i = n + i + 1
	end
	if j < 0 then
		j = n + j + 1
	end
	i = math.max(1, i)
	j = math.min(n, j)
	if j < i then
		return Roster.new({})
	end
	local result = table.create(j - i + 1)
	table.move(data, i, j, 1, result)
	return Roster.new(result)
end

function Roster.Unique(source: any): any
	local seen = {}
	local result = {}
	for _, value in unwrap(source) do
		if not seen[value] then
			seen[value] = true
			table.insert(result, value)
		end
	end
	return Roster.new(result)
end

function Roster.Sort(source: any, comparator: ((a: any, b: any) -> boolean)?): any
	local data = unwrap(source)
	if comparator then
		table.sort(data, comparator)
	else
		table.sort(data)
	end
	return asRoster(source, data)
end

function Roster.Shuffle(source: any): any
	local data = unwrap(source)
	for index = #data, 2, -1 do
		local swap = math.random(1, index)
		data[index], data[swap] = data[swap], data[index]
	end
	return asRoster(source, data)
end

function Roster.IndexBy(source: any, keyOrMapper: any): any
	local result = {}
	for index, value in unwrap(source) do
		result[groupKey(value, index, keyOrMapper)] = value
	end
	return Roster.new(result)
end

function Roster.GroupBy(source: any, keyOrMapper: any): any
	local result = {}
	for index, value in unwrap(source) do
		local key = groupKey(value, index, keyOrMapper)
		local bucket = result[key]
		if not bucket then
			bucket = {}
			result[key] = bucket
		end
		table.insert(bucket, value)
	end
	return Roster.new(result)
end

function Roster.Merge(source: any, ...: any): any
	local result = table.clone(unwrap(source))
	for index = 1, select("#", ...) do
		for key, value in unwrap(select(index, ...)) do
			result[key] = value
		end
	end
	return Roster.new(result)
end

function Roster.Assign(source: any, ...: any): any
	local data = unwrap(source)
	for index = 1, select("#", ...) do
		for key, value in unwrap(select(index, ...)) do
			data[key] = value
		end
	end
	return asRoster(source, data)
end

function Roster.Flatten(source: any, depth: number?): any
	local maxDepth = if depth == nil then 1 else depth
	local function flatten(src: { [any]: any }, level: number): { any }
		local out = {}
		for index = 1, #src do
			local value = src[index]
			if typeof(value) == "table" and level < maxDepth then
				local inner = flatten(unwrap(value), level + 1)
				table.move(inner, 1, #inner, #out + 1, out)
			else
				table.insert(out, value)
			end
		end
		return out
	end
	return Roster.new(flatten(unwrap(source), 0))
end

function Roster.Pack(value: any): buffer
	if typeof(value) == "table" and getmetatable(value) == Roster then
		value = value.Data
	end
	local buf = buffer.create(64)
	local cursor
	buf, cursor = writeValue(buf, 0, value)
	local trimmed = buffer.create(cursor)
	buffer.copy(trimmed, 0, buf, 0, cursor)
	return trimmed
end

function Roster.Unpack(buf: buffer): any
	local value = readValue(buf, 0)
	return value
end

function Roster.WriteF64(values: { number }): buffer
	local buf = buffer.create(4 + #values * 8)
	buffer.writeu32(buf, 0, #values)
	for i, value in values do
		buffer.writef64(buf, 4 + (i - 1) * 8, value)
	end
	return buf
end

function Roster.ReadF64(buf: buffer): { number }
	local count = buffer.readu32(buf, 0)
	local values = table.create(count)
	for i = 1, count do
		values[i] = buffer.readf64(buf, 4 + (i - 1) * 8)
	end
	return values
end

function Roster.WriteI32(values: { number }): buffer
	local buf = buffer.create(4 + #values * 4)
	buffer.writeu32(buf, 0, #values)
	for i, value in values do
		buffer.writei32(buf, 4 + (i - 1) * 4, value)
	end
	return buf
end

function Roster.ReadI32(buf: buffer): { number }
	local count = buffer.readu32(buf, 0)
	local values = table.create(count)
	for i = 1, count do
		values[i] = buffer.readi32(buf, 4 + (i - 1) * 4)
	end
	return values
end

function Roster.WriteString(values: { string }): buffer
	local size = 4
	for _, value in values do
		size += 2 + #value
	end
	local buf = buffer.create(size)
	buffer.writeu32(buf, 0, #values)
	local cursor = 4
	for _, value in values do
		buffer.writeu16(buf, cursor, #value)
		cursor += 2
		buffer.writestring(buf, cursor, value)
		cursor += #value
	end
	return buf
end

function Roster.ReadString(buf: buffer): { string }
	local count = buffer.readu32(buf, 0)
	local values = table.create(count)
	local cursor = 4
	for i = 1, count do
		local len = buffer.readu16(buf, cursor)
		cursor += 2
		values[i] = buffer.readstring(buf, cursor, len)
		cursor += len
	end
	return values
end

return Roster
