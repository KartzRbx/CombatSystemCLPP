--!nonstrict
-- Buffer codec for Net. Not part of the public --!strict surface.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local TAG_NIL = 0
local TAG_BOOL = 1
local TAG_NUM = 2
local TAG_STR = 3
local TAG_V3 = 4
local TAG_CF = 5
local TAG_COL = 6
local TAG_PLAYER = 7
local TAG_JSON = 8

local function estimate(value): number
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
		return 1 + 24
	elseif kind == "CFrame" then
		return 1 + 12 * 8
	elseif kind == "Color3" then
		return 1 + 24
	elseif kind == "Player" then
		return 1 + 8
	end
	return 5 + #HttpService:JSONEncode(value)
end

local function writeValue(buf: buffer, offset: number, value): number
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
	elseif kind == "Instance" and value:IsA("Player") then
		buffer.writeu8(buf, offset, TAG_PLAYER)
		buffer.writef64(buf, offset + 1, value.UserId)
		return offset + 9
	end
	local encoded = HttpService:JSONEncode(value)
	buffer.writeu8(buf, offset, TAG_JSON)
	buffer.writeu32(buf, offset + 1, #encoded)
	buffer.writestring(buf, offset + 5, encoded)
	return offset + 5 + #encoded
end

local function encode(values): buffer
	local size = 1
	for _, value in values do
		size += estimate(value)
	end
	local buf = buffer.create(size)
	buffer.writeu8(buf, 0, #values)
	local offset = 1
	for _, value in values do
		offset = writeValue(buf, offset, value)
	end
	return buf
end

local function readValue(buf: buffer, offset: number)
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
		local x = buffer.readf64(buf, offset)
		local y = buffer.readf64(buf, offset + 8)
		local z = buffer.readf64(buf, offset + 16)
		return Vector3.new(x, y, z), offset + 24
	elseif tag == TAG_CF then
		local c = table.create(12)
		for i = 1, 12 do
			c[i] = buffer.readf64(buf, offset + (i - 1) * 8)
		end
		return CFrame.new(table.unpack(c)), offset + 96
	elseif tag == TAG_COL then
		return Color3.new(buffer.readf64(buf, offset), buffer.readf64(buf, offset + 8), buffer.readf64(buf, offset + 16)), offset + 24
	elseif tag == TAG_PLAYER then
		local userId = buffer.readf64(buf, offset)
		return Players:GetPlayerByUserId(userId), offset + 8
	elseif tag == TAG_JSON then
		local len = buffer.readu32(buf, offset)
		local encoded = buffer.readstring(buf, offset + 4, len)
		return HttpService:JSONDecode(encoded), offset + 4 + len
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
