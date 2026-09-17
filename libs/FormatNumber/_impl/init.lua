local FormatNumber = { }

FormatNumber.Version = require(script.Version)

FormatNumber.Main = require(script.Main)
FormatNumber.Simple = require(script.Simple)

function FormatNumber.Abbreviate(value: number, digits: number?): string
	return FormatNumber.Simple.FormatCompact(value)
end

function FormatNumber.Comma(value: number): string
	return FormatNumber.Simple.Format(value, "group-on")
end

function FormatNumber.Compact(value: number): string
	return FormatNumber.Simple.FormatCompact(value)
end

return FormatNumber
