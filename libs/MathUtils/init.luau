--!strict
--[=[
	@class MathUtils
	Numbers and vectors used in gameplay: lerp, map, clamp, angles.
]=]
local MathUtils = {}

--[=[
	@within MathUtils
]=]
function MathUtils.Lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

--[=[
	@within MathUtils
	Remap `value` from [inMin, inMax] into [outMin, outMax].
]=]
function MathUtils.Map(value: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	if inMax == inMin then
		return outMin
	end
	return outMin + (outMax - outMin) * ((value - inMin) / (inMax - inMin))
end

--[=[
	@within MathUtils
]=]
function MathUtils.Clamp(value: number, min: number, max: number): number
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

--[=[
	@within MathUtils
]=]
function MathUtils.Round(value: number, digits: number?): number
	local places = digits or 0
	local m = 10 ^ places
	return math.floor(value * m + 0.5) / m
end

--[=[
	@within MathUtils
	Shortest signed difference from `a` to `b` in radians.
]=]
function MathUtils.AngleDiff(a: number, b: number): number
	local diff = (b - a + math.pi) % (math.pi * 2) - math.pi
	return diff
end

--[=[
	@within MathUtils
]=]
function MathUtils.LerpAngle(a: number, b: number, alpha: number): number
	return a + MathUtils.AngleDiff(a, b) * alpha
end

--[=[
	@within MathUtils
]=]
function MathUtils.Random(min: number, max: number): number
	return min + math.random() * (max - min)
end

--[=[
	@within MathUtils
	@param weights {number}
	@return number -- 1-based index
]=]
function MathUtils.Weighted(weights: { number }): number
	local total = 0
	for _, w in weights do
		total += w
	end
	local pick = math.random() * total
	local acc = 0
	for index, w in weights do
		acc += w
		if pick <= acc then
			return index
		end
	end
	return #weights
end

--[=[
	@within MathUtils
]=]
function MathUtils.LerpVector(a: Vector3, b: Vector3, alpha: number): Vector3
	return a:Lerp(b, alpha)
end

export type MathUtils = typeof(MathUtils)

return MathUtils
