--!strict
-- Services
-- Packages
local Option = require(script.option)

-- Types

type Option<V> = Option.Option<V>
export type DisplayConfig = {
	sortKeys: boolean,
	useMetatable: boolean,
	indentWith: string
}
type OverrideCallback = (
	value: unknown?,
	baseIndent: number,
	display: Display,
	log: { [any]: true? }
) -> string?
type Callback = (value: unknown?, baseIndent: number, display: Display, log: { [any]: true? }) -> string
type DisplayStruct =  {
	sortKeys: boolean,
	useMetatable: boolean,
	indentWith: string,
	override: OverrideCallback,
	callback: Callback
}

type DisplayImpl = {
	__index: DisplayImpl,
	display: (self: Display, value: unknown?, baseIndent: number?, log: { [any]: true? }?) -> string,
	builder: (self: Display) -> DisplayBuilder
}
export type Display = typeof(setmetatable({} :: DisplayStruct, {} :: DisplayImpl))
type DisplayBuilderImpl = {
	__index: DisplayBuilderImpl,
	setSortKeys: (self: DisplayBuilder, sortKeys: boolean) -> DisplayBuilder,
	setIndentWith: (self: DisplayBuilder, character: string) -> DisplayBuilder,
	setUseMetatable: (self: DisplayBuilder, useMetatable: boolean) -> DisplayBuilder,
	setCallback: (self: DisplayBuilder, callback: Callback) -> DisplayBuilder,
	setOverride: (self: DisplayBuilder, callback: OverrideCallback) -> DisplayBuilder,
	build: (self: DisplayBuilder) -> Display,
	display: (self: DisplayBuilder, value: unknown?, baseIndent: number?, log: { [any]: true? }?) -> string
}
export type DisplayBuilder = typeof(setmetatable({} :: {}, {} :: DisplayBuilderImpl))
-- Constants
-- Variables
-- References
-- Private Functions
function constructFrom(struct: DisplayStruct, set: (mutStruct: DisplayStruct) -> ()): DisplayStruct
	local out = table.clone(struct) :: Display
	set(out)
	table.freeze(out)
	return out
end
-- Class
local Display = {} :: DisplayImpl
Display["__index"] = Display

local DisplayBuilder = {} :: DisplayBuilderImpl
DisplayBuilder["__index"] = DisplayBuilder

function newDisplayBuilder(struct: DisplayStruct): DisplayBuilder
	local self = table.clone(struct) :: any
	setmetatable(self, DisplayBuilder)
	table.freeze(self)
	return self
end
function newDisplay(struct: DisplayStruct): Display
	local self = table.clone(struct) :: Display
	setmetatable(self, Display)
	table.freeze(self)
	return self
end

function Display:display(value: unknown?, baseIndent: number?, logs: { [any]: true? }?): string
	local override = self.override(value, baseIndent or 0, self, logs or {})
	if override ~= nil then
		return override
	end
	return self.callback(value, baseIndent or 0, self, logs or {})
end

function Display:builder(): DisplayBuilder
	return newDisplayBuilder(self :: DisplayStruct)
end

function DisplayBuilder:build(): Display
	return newDisplay(self :: DisplayStruct)
end

function DisplayBuilder:setSortKeys(sortKeys: boolean): DisplayBuilder
	return newDisplayBuilder(constructFrom(self, function(mutStruct)
		mutStruct.sortKeys = sortKeys
	end)) :: DisplayBuilder
end

function DisplayBuilder:setUseMetatable(useMetatable): DisplayBuilder
	return newDisplayBuilder(constructFrom(self, function(mutStruct)
		mutStruct.useMetatable = useMetatable
	end)) :: DisplayBuilder
end
function DisplayBuilder:setIndentWith(text: string): DisplayBuilder
	return newDisplayBuilder(constructFrom(self, function(mutStruct)
		mutStruct.indentWith = text
	end)) :: DisplayBuilder
end

function DisplayBuilder:setCallback(callback: Callback): DisplayBuilder
	return newDisplayBuilder(constructFrom(self, function(mutStruct)
		mutStruct.callback = callback
	end)) :: DisplayBuilder
end

function DisplayBuilder:setOverride(callback: OverrideCallback): DisplayBuilder
	return newDisplayBuilder(constructFrom(self, function(mutStruct)
		mutStruct.override = callback
	end)) :: DisplayBuilder
end

function DisplayBuilder:display(value, baseIndent, logs): string
	return self:build():display(value, baseIndent, logs)
end

function newJsonDisplayBuilder(): DisplayBuilder
	return newDisplayBuilder({
		sortKeys = false,
		indentWith = "",
		useMetatable = false,
		override = function(
			value: unknown?,
			baseIndent: number,
			display: Display,
			log: { [any]: true? }
		): string?
			return nil
		end,
		callback = function(
			value: unknown?,
			baseIndent: number,
			display: Display,
			log: { [any]: true? }
		): string
			local ov = display.override(value, baseIndent, display, log)
			if ov ~= nil then
				return ov
			end
			if type(value) == "string" then
				return '"' .. value:gsub('"', '\\"') .. '"'
			elseif type(value) == "number" then
				if value ~= value then
					return '"NaN"'
				elseif math.abs(value) == math.huge then
					return '"Inf"'
				end
				return tostring(value)
			elseif type(value) == "boolean" then
				return tostring(value)
			elseif type(value) == "table" then
				if log[value] then
					return '"<circular>"'
				end
				log[value] = true
				local meta: { [any]: any? }? = nil
				pcall(function()
					meta = getmetatable(value :: any)
				end)
				if display.useMetatable and meta and rawget(meta, "__tostring") ~= nil then
					local str: string?
					local tostringSuccess, _ = pcall(function()
						str = tostring(value)
					end)
					if tostringSuccess then
						return `"{str}"`
					end
				end
				local out = {}
				local isArray = true
				local keyCount = 0
				for k, v in pairs(value :: any) do
					keyCount += 1
					if type(k) ~= "number" then
						isArray = false
						break
					end
				end
				if #(value :: any) == keyCount and isArray then
					for _, v in ipairs(value :: any) do
						table.insert(out, display:display(v, baseIndent + 1, log))
					end
					if display.indentWith:len() ~= 0 then
						if #out == 0 then
							return "[]"
						end
						local msg = "["
						for i, row in ipairs(out) do
							msg ..= "\n" .. string.rep(display.indentWith, baseIndent + 1) .. row
							if i ~= #out then
								msg ..= ","
							end
						end
						msg ..= "\n" .. string.rep(display.indentWith, baseIndent) .. "]"
						return msg
					else
						return "[" .. table.concat(out, ",") .. "]"
					end
				else
					local keyList = {}
					for k, _ in pairs(value :: any) do
						table.insert(keyList, k)
					end
					if display.sortKeys then
						table.sort(keyList)
					end
					for i, k in ipairs(keyList) do
						local v = (value :: any)[k]
						if Option.isOption(v) then
							local vOpt: Option<unknown> = v
							if vOpt:isSome() then
								table.insert(
									out,
									display:display(tostring(k), baseIndent + 1, log)
										.. ": "
										.. display:display(v, baseIndent + 1, log)
								)
							else
								table.insert(
									out,
									display:display(tostring(k), baseIndent + 1, log) .. ": null"
								)
							end
							continue
						end
						table.insert(
							out,
							display:display(tostring(k), baseIndent + 1, log)
								.. ": "
								.. display:display(v, baseIndent + 1, log)
						)
					end
					if display.indentWith:len() ~= 0 then
						if #out == 0 then
							return "{}"
						end
						local msg = "{"
						for i, row in ipairs(out) do
							msg ..= "\n" .. string.rep(display.indentWith, baseIndent + 1) .. row
							if i ~= #out then
								msg ..= ","
							end
						end
						msg ..= "\n" .. string.rep(display.indentWith, baseIndent + 1) .. "}"
						return msg
					else
						return "{" .. table.concat(out, ",") .. "}"
					end
				end
			else
				return `"{tostring(value)}"`
			end
		end,
	})
end

return {
	JSON = {
		new = newJsonDisplayBuilder,
	},
}
