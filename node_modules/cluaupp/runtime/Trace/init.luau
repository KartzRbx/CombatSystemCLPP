--!optimize 2
--!strict
-- Trace — pretty-print values.

local Trace = {}

local DEFAULT_DEPTH = 4
local DEFAULT_INDENT = "  "

local function formatNumber(value: number): string
	if value ~= value then
		return "nan"
	end
	if value == math.huge then
		return "inf"
	end
	if value == -math.huge then
		return "-inf"
	end
	return tostring(value)
end

local function formatVector(prefix: string, ...: number): string
	local parts = { prefix, "(" }
	local count = select("#", ...)
	for i = 1, count do
		if i > 1 then
			table.insert(parts, ", ")
		end
		table.insert(parts, formatNumber(select(i, ...)))
	end
	table.insert(parts, ")")
	return table.concat(parts)
end

local function isArray(value: { [any]: any }): boolean
	local count = 0
	for key in value do
		if typeof(key) ~= "number" or key ~= math.floor(key) or key < 1 then
			return false
		end
		count += 1
	end
	return count == #value
end

local function formatValue(value: any, depth: number, maxDepth: number, indentWith: string, seen: { [any]: boolean }): string
	local kind = typeof(value)
	if kind == "string" then
		return string.format("%q", value)
	end
	if kind == "number" then
		return formatNumber(value)
	end
	if kind == "boolean" or kind == "nil" then
		return tostring(value)
	end
	if kind == "Instance" then
		local ok, fullName = pcall(function()
			return value:GetFullName()
		end)
		if ok then
			return `{value.ClassName}({fullName})`
		end
		return `{value.ClassName}({value.Name})`
	end
	if kind == "Vector3" then
		return formatVector("Vector3", value.X, value.Y, value.Z)
	end
	if kind == "Vector2" then
		return formatVector("Vector2", value.X, value.Y)
	end
	if kind == "Vector3int16" then
		return formatVector("Vector3int16", value.X, value.Y, value.Z)
	end
	if kind == "Vector2int16" then
		return formatVector("Vector2int16", value.X, value.Y)
	end
	if kind == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
		return formatVector("CFrame", x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	end
	if kind == "Color3" then
		return formatVector("Color3", value.R, value.G, value.B)
	end
	if kind == "UDim" then
		return formatVector("UDim", value.Scale, value.Offset)
	end
	if kind == "UDim2" then
		return formatVector("UDim2", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	end
	if kind == "Rect" then
		return formatVector("Rect", value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
	end
	if kind == "NumberRange" then
		return formatVector("NumberRange", value.Min, value.Max)
	end
	if kind == "BrickColor" then
		return `BrickColor({string.format("%q", value.Name)})`
	end
	if kind == "EnumItem" then
		return tostring(value)
	end
	if kind == "buffer" then
		return `buffer({buffer.len(value)})`
	end
	if kind == "table" then
		if seen[value] then
			return "<circular>"
		end
		if depth >= maxDepth then
			return "{...}"
		end
		seen[value] = true
		local pad = string.rep(indentWith, depth)
		local inner = string.rep(indentWith, depth + 1)
		local parts = { "{" }
		if isArray(value) then
			if #value == 0 then
				seen[value] = nil
				return "{}"
			end
			for index, child in ipairs(value) do
				table.insert(parts, `\n{inner}[{index}] = {formatValue(child, depth + 1, maxDepth, indentWith, seen)},`)
			end
		else
			local keys = {}
			for key in value do
				table.insert(keys, key)
			end
			table.sort(keys, function(a, b)
				if typeof(a) == "number" and typeof(b) == "number" then
					return a < b
				end
				if typeof(a) == "string" and typeof(b) == "string" then
					return a < b
				end
				return tostring(a) < tostring(b)
			end)
			if #keys == 0 then
				seen[value] = nil
				return "{}"
			end
			for _, key in keys do
				table.insert(
					parts,
					`\n{inner}[{formatValue(key, depth + 1, maxDepth, indentWith, seen)}] = {formatValue(value[key], depth + 1, maxDepth, indentWith, seen)},`
				)
			end
		end
		table.insert(parts, `\n{pad}}`)
		seen[value] = nil
		return table.concat(parts)
	end
	return `{kind}({tostring(value)})`
end

local function stringify(value: any, level: number?, maxDepth: number?, indentWith: string?): string
	return formatValue(value, level or 0, maxDepth or DEFAULT_DEPTH, indentWith or DEFAULT_INDENT, {})
end

function Trace.display(value: any, level: number?): string
	return stringify(value, level, DEFAULT_DEPTH, DEFAULT_INDENT)
end

function Trace.Display(value: any, level: number?): string
	return stringify(value, level, DEFAULT_DEPTH, DEFAULT_INDENT)
end

function Trace.Print(value: any)
	print(Trace.Display(value))
end

Trace.Dump = Trace.Print

function Trace.builder()
	local maxDepth = DEFAULT_DEPTH
	local indentWith = DEFAULT_INDENT
	local builder = {}

	function builder:MaxDepth(depth: number)
		maxDepth = math.max(0, depth)
		return self
	end

	function builder:Indent(indent: string)
		indentWith = indent
		return self
	end

	function builder:Display(value: any, level: number?): string
		return stringify(value, level, maxDepth, indentWith)
	end

	function builder:display(value: any, level: number?): string
		return stringify(value, level, maxDepth, indentWith)
	end

	function builder:Print(value: any)
		print(self:Display(value))
	end

	function builder:build()
		return self
	end

	return builder
end

return Trace
