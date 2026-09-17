--!strict
-- Cluaupp FormatNumber — typed border. Compact/Abbreviate are number -> string.

--[=[
	@class FormatNumber
	Abbreviate, Comma, and Compact number formatters.
]=]

local Impl = require(script._impl)

export type FormatNumber = {
	Abbreviate: (value: number, digits: number?) -> string,
	Comma: (value: number) -> string,
	Compact: (value: number) -> string,
	Main: typeof(Impl.Main),
	Simple: typeof(Impl.Simple),
	Version: typeof(Impl.Version),
}

return Impl :: FormatNumber
