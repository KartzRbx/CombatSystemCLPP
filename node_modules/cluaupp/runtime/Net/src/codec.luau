--!nonstrict
-- Buffer codec for Net. Tagged values — never JSON on the hot path.

local Players = game:GetService("Players")

local TAG_NIL = 0
local TAG_BOOL = 1
local TAG_NUM = 2
local TAG_STR = 3
local TAG_V3 = 4
local TAG_CF = 5
local TAG_COL = 6
local TAG_PLAYER = 7
local TAG_TABLE = 8
local TAG_V2 = 9
local TAG_UDIM = 10
local TAG_UDIM2 = 11

local MAX_DEPTH = 16

local estimate: (any, number) -> number
local writeValue: (buffer, number, any, number) -> number
local readValue: (buffer, number) -> (any, number)

estimate = function(value, depth: number): number
	if depth > MAX_DEPTH then
		return 1
	end
	local kind = typeof(value)
	if value == nil then
		return 1
	elseif kind == "boolean" then
		return 2
	elseif kind == "number" then
		return 9
	elseif kind == "string" then
		return 5 + #value
	elseif kind == "Vector3" then
		return 25
	elseif kind == "Vector2" then
		return 17
	elseif kind == "CFrame" then
		return 1 + 96
	elseif kind == "Color3" then
		return 25
	elseif kind == "UDim" then
		return 13
	elseif kind == "UDim2" then
		return 25
	elseif kind == "Instance" and value:IsA("Player") then
		return 9
	elseif kind == "table" then
		local size = 5
		for key, child in value do
			size += estimate(key, depth + 1) + estimate(child, depth + 1)
		end
		return size
	end
	return 1
end

writeValue = function(buf: buffer, offset: number, value, depth: number): number
	if depth > MAX_DEPTH then
		buffer.writeu8(buf, offset, TAG_NIL)
		return offset + 1
	end
	local kind = typeof(value)
	if value == nil then
		buffer.writeu8(buf, offset, TAG_NIL)
		return offset + 1
	elseif kind == "boolean" then
		buffer.writeu8(buf, offset, TAG_BOOL)
		buffer.writeu8(buf, offset + 1, if value then 1 else 0)
		return offset + 2
	elseif kind == "number" then
		buffer.writeu8(buf, offset, TAG_NUM)
		buffer.writef64(buf, offset + 1, value)
		return offset + 9
	elseif kind == "string" then
		buffer.writeu8(buf, offset, TAG_STR)
		buffer.writeu32(buf, offset + 1, #value)
		buffer.writestring(buf, offset + 5, value)
		return offset + 5 + #value
	elseif kind == "Vector3" then
		buffer.writeu8(buf, offset, TAG_V3)
		buffer.writef64(buf, offset + 1, value.X)
		buffer.writef64(buf, offset + 9, value.Y)
		buffer.writef64(buf, offset + 17, value.Z)
		return offset + 25
	elseif kind == "Vector2" then
		buffer.writeu8(buf, offset, TAG_V2)
		buffer.writef64(buf, offset + 1, value.X)
		buffer.writef64(buf, offset + 9, value.Y)
		return offset + 17
	elseif kind == "CFrame" then
		buffer.writeu8(buf, offset, TAG_CF)
		local components = { value:GetComponents() }
		for i = 1, 12 do
			buffer.writef64(buf, offset + 1 + (i - 1) * 8, components[i])
		end
		return offset + 1 + 96
	elseif kind == "Color3" then
		buffer.writeu8(buf, offset, TAG_COL)
		buffer.writef64(buf, offset + 1, value.R)
		buffer.writef64(buf, offset + 9, value.G)
		buffer.writef64(buf, offset + 17, value.B)
		return offset + 25
	elseif kind == "UDim" then
		buffer.writeu8(buf, offset, TAG_UDIM)
		buffer.writef32(buf, offset + 1, value.Scale)
		buffer.writei32(buf, offset + 5, value.Offset)
		return offset + 13
	elseif kind == "UDim2" then
		buffer.writeu8(buf, offset, TAG_UDIM2)
		buffer.writef32(buf, offset + 1, value.X.Scale)
		buffer.writei32(buf, offset + 5, value.X.Offset)
		buffer.writef32(buf, offset + 9, value.Y.Scale)
		buffer.writei32(buf, offset + 13, value.Y.Offset)
		return offset + 17
	elseif kind == "Instance" and value:IsA("Player") then
		buffer.writeu8(buf, offset, TAG_PLAYER)
		buffer.writef64(buf, offset + 1, value.UserId)
		return offset + 9
	elseif kind == "table" then
		local count = 0
		for _ in value do
			count += 1
		end
		buffer.writeu8(buf, offset, TAG_TABLE)
		buffer.writeu32(buf, offset + 1, count)
		offset += 5
		for key, child in value do
			offset = writeValue(buf, offset, key, depth + 1)
			offset = writeValue(buf, offset, child, depth + 1)
		end
		return offset
	end
	buffer.writeu8(buf, offset, TAG_NIL)
	return offset + 1
end

local function encode(values): buffer
	local size = 1
	for _, value in values do
		size += estimate(value, 0)
	end
	local buf = buffer.create(size)
	buffer.writeu8(buf, 0, #values)
	local offset = 1
	for _, value in values do
		offset = writeValue(buf, offset, value, 0)
	end
	return buf
end

readValue = function(buf: buffer, offset: number)
	local tag = buffer.readu8(buf, offset)
	offset += 1
	if tag == TAG_NIL then
		return nil, offset
	elseif tag == TAG_BOOL then
		return buffer.readu8(buf, offset) == 1, offset + 1
	elseif tag == TAG_NUM then
		return buffer.readf64(buf, offset), offset + 8
	elseif tag == TAG_STR then
		local len = buffer.readu32(buf, offset)
		return buffer.readstring(buf, offset + 4, len), offset + 4 + len
	elseif tag == TAG_V3 then
		return Vector3.new(buffer.readf64(buf, offset), buffer.readf64(buf, offset + 8), buffer.readf64(buf, offset + 16)), offset + 24
	elseif tag == TAG_V2 then
		return Vector2.new(buffer.readf64(buf, offset), buffer.readf64(buf, offset + 8)), offset + 16
	elseif tag == TAG_CF then
		local c = table.create(12)
		for i = 1, 12 do
			c[i] = buffer.readf64(buf, offset + (i - 1) * 8)
		end
		return CFrame.new(table.unpack(c)), offset + 96
	elseif tag == TAG_COL then
		return Color3.new(buffer.readf64(buf, offset), buffer.readf64(buf, offset + 8), buffer.readf64(buf, offset + 16)), offset + 24
	elseif tag == TAG_UDIM then
		return UDim.new(buffer.readf32(buf, offset), buffer.readi32(buf, offset + 4)), offset + 12
	elseif tag == TAG_UDIM2 then
		return UDim2.new(
			buffer.readf32(buf, offset),
			buffer.readi32(buf, offset + 4),
			buffer.readf32(buf, offset + 8),
			buffer.readi32(buf, offset + 12)
		),
			offset + 16
	elseif tag == TAG_PLAYER then
		local userId = buffer.readf64(buf, offset)
		return Players:GetPlayerByUserId(userId), offset + 8
	elseif tag == TAG_TABLE then
		local count = buffer.readu32(buf, offset)
		offset += 4
		local out = {}
		for _ = 1, count do
			local key
			key, offset = readValue(buf, offset)
			local child
			child, offset = readValue(buf, offset)
			out[key] = child
		end
		return out, offset
	end
	return nil, offset
end

local function decode(buf: buffer)
	local count = buffer.readu8(buf, 0)
	local offset = 1
	local values = table.create(count)
	for i = 1, count do
		local value
		value, offset = readValue(buf, offset)
		values[i] = value
	end
	return values
end

return {
	encode = encode,
	decode = decode,
}
