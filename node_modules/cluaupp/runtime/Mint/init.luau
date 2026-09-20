--!native
--!optimize 2
--!strict
-- Mint — Cluaupp number display. Schema .mint bakes formatters; this kernel is the fallback.
-- Codegen (compileMint): Mint.Compact(value, { Fraction, Suffixes = { {threshold, label} } }),
-- Mint.Percent(value, fraction), Mint.Group(value, fraction). Do not rename those.

local Mint = {}

local DEFAULT_SUFFIXES = {
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
	"Sxd",
	"Spd",
	"Ocd",
	"Nod",
	"Vg",
	"Uvg",
	"Dvg",
	"Tvg",
	"Qavg",
	"Qivg",
	"Sxvg",
	"Spvg",
	"Ocvg",
	"Novg",
}

export type SuffixPair = { number | string }
export type SuffixList = { SuffixPair }
export type CompactOptions = { Fraction: number?, Suffixes: SuffixList? }

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function special(value: number): string?
	if value == value then
		if value == math.huge then
			return "∞"
		end
		if value == -math.huge then
			return "-∞"
		end
		return nil
	end
	return "NaN"
end

local function group(digits: string): string
	local sign = ""
	if string.sub(digits, 1, 1) == "-" then
		sign = "-"
		digits = string.sub(digits, 2)
	end
	local whole, frac = string.match(digits, "^(%d+)(%.%d+)$")
	if not whole then
		whole = digits
		frac = ""
	end
	local built = {}
	local n = #whole
	local start = n % 3
	if start == 0 then
		start = 3
	end
	table.insert(built, string.sub(whole, 1, start))
	for i = start + 1, n, 3 do
		table.insert(built, string.sub(whole, i, i + 2))
	end
	return sign .. table.concat(built, ",") .. frac
end

local function trimFraction(value: number, places: number): string
	if not isFinite(value) then
		return special(value) :: string
	end
	if places <= 0 then
		return tostring(math.floor(value + (if value >= 0 then 0.5 else -0.5)))
	end
	local m = 10 ^ places
	local rounded = math.floor(value * m + (if value >= 0 then 0.5 else -0.5)) / m
	local text = string.format("%." .. places .. "f", rounded)
	text = string.gsub(text, "%.?0+$", "")
	return text
end

function Mint.Suffixes(labels: { string }): SuffixList
	local baked: SuffixList = {}
	for i, label in labels do
		table.insert(baked, { 10 ^ (i * 3), label })
	end
	return baked
end

local function defaultSuffixes(): SuffixList
	return Mint.Suffixes(DEFAULT_SUFFIXES)
end

local function asSuffixList(suffixes: SuffixList?): SuffixList
	if suffixes == nil then
		return defaultSuffixes()
	end
	if #suffixes == 0 then
		return suffixes
	end
	if type(suffixes[1]) == "string" then
		return Mint.Suffixes(suffixes :: any)
	end
	return suffixes
end

function Mint.Group(value: number, fraction: number?): string
	local text = special(value)
	if text then
		return text
	end
	local places = fraction or 0
	return group(trimFraction(value, places))
end

function Mint.Comma(value: number): string
	return Mint.Group(value, 0)
end

function Mint.Compact(value: number, options: (CompactOptions | number)?): string
	local text = special(value)
	if text then
		return text
	end
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	local fraction = 1
	local suffixInput: SuffixList? = nil
	if type(options) == "number" then
		fraction = options
	elseif type(options) == "table" then
		fraction = (options :: CompactOptions).Fraction or 1
		suffixInput = (options :: CompactOptions).Suffixes
	end
	local suffixes = asSuffixList(suffixInput)
	local chosen: SuffixPair? = nil
	local best = 0
	for i = 1, #suffixes do
		local threshold = suffixes[i][1] :: number
		if threshold > 0 and n >= threshold and threshold >= best then
			best = threshold
			chosen = suffixes[i]
		end
	end
	if not chosen then
		return sign .. trimFraction(n, fraction)
	end
	local scaled = n / (chosen[1] :: number)
	local places = 10 ^ fraction
	scaled = math.floor(scaled * places) / places
	return sign .. trimFraction(scaled, fraction) .. (chosen[2] :: string)
end

function Mint.Abbreviate(value: number, digits: number?): string
	return Mint.Compact(value, { Fraction = digits or 1 })
end

function Mint.Percent(value: number, fraction: number?): string
	local text = special(value)
	if text then
		return text
	end
	return trimFraction(value * 100, fraction or 1) .. "%"
end

function Mint.Scientific(value: number, fraction: number?): string
	local text = special(value)
	if text then
		return text
	end
	local places = fraction or 1
	if value == 0 then
		return "0e+0"
	end
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	local exp = math.floor(math.log(n, 10))
	local mantissa = n / (10 ^ exp)
	if places <= 0 then
		mantissa = math.floor(mantissa + 0.5)
	else
		local m = 10 ^ places
		mantissa = math.floor(mantissa * m + 0.5) / m
	end
	if mantissa >= 10 then
		mantissa /= 10
		exp += 1
	end
	local expSign = if exp >= 0 then "+" else ""
	return sign .. trimFraction(mantissa, places) .. "e" .. expSign .. tostring(exp)
end

function Mint.To(value: number, fraction: number?): string
	return Mint.Group(value, fraction)
end

local function suffixFactor(label: string, suffixes: SuffixList): number?
	if label == "" then
		return nil
	end
	local lower = string.lower(label)
	for i = #suffixes, 1, -1 do
		local pair = suffixes[i]
		local name = pair[2] :: string
		if name and string.lower(name) == lower then
			return pair[1] :: number
		end
	end
	return nil
end

function Mint.From(text: string, suffixes: SuffixList?): number
	local trimmed = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
	if trimmed == "" then
		return 0 / 0
	end
	if trimmed == "NaN" or trimmed == "nan" then
		return 0 / 0
	end
	if trimmed == "∞" or trimmed == "inf" or trimmed == "Inf" or trimmed == "Infinity" then
		return math.huge
	end
	if trimmed == "-∞" or trimmed == "-inf" or trimmed == "-Inf" or trimmed == "-Infinity" then
		return -math.huge
	end
	local percent = false
	if string.sub(trimmed, -1) == "%" then
		percent = true
		trimmed = string.sub(trimmed, 1, -2)
	end
	local stripped = string.gsub(trimmed, ",", "")
	local numberPart, suffixPart = string.match(stripped, "^([%+%-]?%d*%.?%d+[eE][%+%-]?%d+)(.*)$")
	if not numberPart then
		numberPart, suffixPart = string.match(stripped, "^([%+%-]?%d*%.?%d+)(.*)$")
	end
	if not numberPart then
		return 0 / 0
	end
	local n = tonumber(numberPart)
	if not n then
		return 0 / 0
	end
	suffixPart = string.gsub(suffixPart or "", "%s+", "")
	if suffixPart ~= "" then
		local factor = suffixFactor(suffixPart, asSuffixList(suffixes))
		if not factor then
			return 0 / 0
		end
		n *= factor
	end
	if percent then
		n /= 100
	end
	return n
end

Mint.Format = Mint.Group

return Mint
