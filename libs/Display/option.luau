--!strict
-- https://doc.rust-lang.org/std/option/enum.Option.html
-- Services
-- Packages
-- Modules
-- Types
type State = "S" | "N"
type OptionStruct<V> = {
	_state: string, --"N" | "S", --replaced for performance reasons
	_value: V?,
}
type Self = any
type OptionImpl<V> = {
	-- __index: OptionImpl<V>,
	-- __tostring: (self: Self) -> string,
	-- __eq: (self: Self, other: Option<V>) -> boolean,
	isSome: (self: Self) -> boolean,
	isNone: (self: Self) -> boolean,
	inspect: (self: Self, fn: (value: V) -> ()) -> (),
	match: (self: Self, some: (some: V) -> V, none: () -> V) -> V,
	map: (self: Self, fn: (some: V) -> V) -> Option<V>, --type swapping with map stuff is technically okay, but I can't get the type engine to recognize that
	unwrap: (self: Self) -> V,
	unwrapOr: (self: Self, alt: V) -> V,
	unwrapOrElse: (self: Self, fn: () -> V) -> V,
	asNullable: (self: Self) -> V?,
	expect: (self: Self, msg: string) -> V,
}

export type Option<V> = OptionImpl<V> -- keeps type simple
-- typeof(setmetatable(
-- 	{} :: {
-- 		_state: string, --"N" | "S", --replaced for performance reasons
-- 		_value: V?,
-- 	},
-- 	{} :: OptionImpl<V>
-- ))

-- Constants
local STATE_SOME: "S" = "S"
local STATE_NONE: "N" = "N"
-- Variables
-- References
-- Private Functions
-- Class
local Option = {} :: OptionImpl<unknown>

-- Constructors
local asNone = function(): Option<any> --ideally would be variadic, but this causes so many snags in reality
	local self: any = setmetatable({
		_state = STATE_NONE :: string,
		_value = nil,
	}, Option :: OptionImpl<any>)
	table.freeze(self)
	return self
end

local asSome = function<V>(some: V): Option<V>
	assert(typeof(some) ~= "nil", "some() value cannot be nil")
	local self: any = setmetatable({
		_state = STATE_SOME :: string,
		_value = some,
	}, Option :: OptionImpl<any>)
	table.freeze(self)
	return self
end

-- returns true if the option is some, false if it is none
function Option:isSome(): boolean
	return self._state == STATE_SOME
end

-- returns true if the option is none, false if it is some
function Option:isNone(): boolean
	return self._state == STATE_NONE
end

-- allows for the reading of the value if it exists
function Option:inspect(fn: (value: unknown) -> ())
	if self:isSome() then
		fn(self._value)
	end
	return self
end

-- allows for the safe handling of each state
function Option:match<O>(some: (some: unknown) -> unknown, none: () -> O): unknown
	if self:isSome() then
		return some(self._value)
	else
		assert(self:isNone())
		return none()
	end
end

-- allows for construction of a new option using the value of the current option
-- it works for type switching, but try explaining that to the type engine
function Option:map(fn: (some: unknown) -> unknown): Option<unknown>
	if self:isSome() then
		return asSome(fn(self._value))
	end
	return asNone()
end

-- this assumes that the value is some, erroring if it is
function Option:unwrap()
	if self:isSome() then
		return self._value
	end
	error("Option is none")
end

-- new quality of life method for interfacing with non-option based systems
function Option:asNullable()
	if self:isSome() then
		return self._value
	end
	return nil
end

-- unwrapOr() allows for swapping in the value if the option is none()
function Option:unwrapOr(alt: unknown): unknown
	if self:isSome() then
		return self._value
	end
	return alt
end

-- unpack() but with a custom error message
function Option:expect(msg: string)
	if self:isSome() then
		return self._value
	end
	error(msg)
end

function Option:unwrapOrElse(fn: () -> unknown): unknown
	if self:isSome() then
		return self._value
	end
	return fn()
end

-- these work fine, but add a lot of complexity to the type system and aren't used much
local DeprecatedOption = Option :: any
DeprecatedOption.__index = Option

-- used for debug readability
function DeprecatedOption:__tostring()
	if self:isSome() then
		return "Some<" .. tostring(self._value) .. ">"
	end
	return "None"
end

-- allows for equality checking between options
function DeprecatedOption:__eq(other: Option<unknown>): boolean
	if self:isSome() and other:isSome() then
		local ot: any = other
		return self._value == ot._value
	end
	return self:isNone() and other:isNone()
end

function DeprecatedOption:mapOr(mapFn: (some: unknown) -> unknown, alt: unknown): Option<unknown>
	if self:isSome() then
		return asSome(mapFn(self._value))
	end
	return asSome(alt)
end

function DeprecatedOption:mapOrElse(mapFn: (some: unknown) -> unknown, elseFn: () -> unknown): Option<unknown>
	if self:isSome() then
		return asSome(mapFn(self._value))
	end
	return asSome(elseFn())
end

-- original name for asNullable, kept for backwards compatibility
function DeprecatedOption:unpack()
	return self:asNullable()
end

return {
	none = asNone,
	some = asSome,
	match = function<VI, VO>(self: Option<VI>, some: (some: VI) -> VO, none: () -> VO): VO
		if self:isSome() then
			return some(self:unwrap())
		else
			return none()
		end
	end,
	map = function<VI, VO>(self: Option<VI>, fn: (some: VI) -> VO): Option<VO> -- allows support for type swapping
		if self:isSome() then
			return asSome(fn(self:unwrap()))
		else
			return asNone()
		end
	end,
	isOption = function(value: unknown?): boolean
		if typeof(value) == "table" then
			return getmetatable(value :: any) == Option
		end
		return false
	end,
	-- constructs a runtime type-checker with the same format as osyrisrblx/t
	type = function<V>(someType: (value: V) -> (boolean, string?)): (value: unknown?) -> (boolean, string?)
		return function(value: unknown?): (boolean, string?)
			if typeof(value) == "table" then
				local mt = getmetatable(value :: any)
				if mt == Option then
					local valOpt: Option<V> = value :: Option<V>
					if valOpt:isSome() then
						return someType(valOpt:unwrap())
					end
					return true, nil
				end
			end
			return false, "Value is not an option"
		end
	end,
	try = function<V>(fn: () -> V | nil): Option<V>
		local out = fn()
		if typeof(out) == "nil" then
			return asNone()
		else
			return asSome(out)
		end
	end,
	from = function<V>(v: V | nil): Option<V>
		if typeof(v) == "nil" then
			return asNone()
		else
			return asSome(v)
		end
	end,
}
