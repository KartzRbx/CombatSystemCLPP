--!native
--!optimize 2
--!strict
-- Axiom — Cluaupp math. 113 formulas grouped; .axiom tree-shakes unused groups.
-- Every public function returns a concrete type. No any. No nil on the math path.

local Axiom = {}

function Axiom._ease(kind: string, mode: string, t: number): number
	local x = t
	if kind == "Sine" then
		x = if mode == "In" then 1 - math.cos((t * math.pi) / 2) elseif mode == "Out" then math.sin((t * math.pi) / 2) else -(math.cos(math.pi * t) - 1) / 2
	elseif kind == "Quad" then
		x = if mode == "In" then t * t elseif mode == "Out" then 1 - (1 - t) * (1 - t) else (if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2)
	elseif kind == "Cubic" then
		x = if mode == "In" then t ^ 3 elseif mode == "Out" then 1 - (1 - t) ^ 3 else (if t < 0.5 then 4 * t ^ 3 else 1 - (-2 * t + 2) ^ 3 / 2)
	elseif kind == "Quart" then
		x = if mode == "In" then t ^ 4 elseif mode == "Out" then 1 - (1 - t) ^ 4 else (if t < 0.5 then 8 * t ^ 4 else 1 - (-2 * t + 2) ^ 4 / 2)
	elseif kind == "Quint" then
		x = if mode == "In" then t ^ 5 elseif mode == "Out" then 1 - (1 - t) ^ 5 else (if t < 0.5 then 16 * t ^ 5 else 1 - (-2 * t + 2) ^ 5 / 2)
	elseif kind == "Expo" then
		x = if t == 0 then 0 elseif t == 1 then 1 elseif mode == "In" then 2 ^ (10 * t - 10) elseif mode == "Out" then 1 - 2 ^ (-10 * t) else (if t < 0.5 then 2 ^ (20 * t - 10) / 2 else (2 - 2 ^ (-20 * t + 10)) / 2)
	elseif kind == "Circ" then
		x = if mode == "In" then 1 - math.sqrt(1 - t ^ 2) elseif mode == "Out" then math.sqrt(1 - (t - 1) ^ 2) else (if t < 0.5 then (1 - math.sqrt(1 - (2 * t) ^ 2)) / 2 else (math.sqrt(1 - (-2 * t + 2) ^ 2) + 1) / 2)
	elseif kind == "Back" then
		local c1, c3 = 1.70158, 2.70158
		x = if mode == "In" then c3 * t ^ 3 - c1 * t ^ 2 elseif mode == "Out" then 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2 else (if t < 0.5 then ((2 * t) ^ 2 * ((c1 * 1.525 + 1) * 2 * t - c1 * 1.525)) / 2 else ((2 * t - 2) ^ 2 * ((c1 * 1.525 + 1) * (t * 2 - 2) + c1 * 1.525) + 2) / 2)
	elseif kind == "Elastic" then
		x = if t == 0 then 0 elseif t == 1 then 1 elseif mode == "In" then -2 ^ (10 * t - 10) * math.sin((t * 10 - 10.75) * ((2 * math.pi) / 3)) elseif mode == "Out" then 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * ((2 * math.pi) / 3)) + 1 else (if t < 0.5 then -(2 ^ (20 * t - 10) * math.sin((20 * t - 11.125) * ((2 * math.pi) / 4.5))) / 2 else (2 ^ (-20 * t + 10) * math.sin((20 * t - 11.125) * ((2 * math.pi) / 4.5))) / 2 + 1)
	elseif kind == "Bounce" then
		local function out(v: number): number
			local n1, d1 = 7.5625, 2.75
			if v < 1 / d1 then return n1 * v * v elseif v < 2 / d1 then v -= 1.5 / d1 return n1 * v * v + 0.75 elseif v < 2.5 / d1 then v -= 2.25 / d1 return n1 * v * v + 0.9375 else v -= 2.625 / d1 return n1 * v * v + 0.984375 end
		end
		x = if mode == "In" then 1 - out(1 - t) elseif mode == "Out" then out(t) else (if t < 0.5 then (1 - out(1 - 2 * t)) / 2 else (1 + out(2 * t - 1)) / 2)
	end
	return x
end

function Axiom.Clamp(value: number, min: number, max: number): number
	return math.clamp(value, min, max)
end

function Axiom.Map(value: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	if inMax == inMin then return outMin end
	return outMin + (outMax - outMin) * ((value - inMin) / (inMax - inMin))
end

function Axiom.Wrap(value: number, min: number, max: number): number
	local range = max - min
	if range == 0 then return min end
	local wrapped = (value - min) % range
	if wrapped < 0 then wrapped += range end
	return min + wrapped
end

function Axiom.Sign(value: number): number
	if value > 0 then return 1 elseif value < 0 then return -1 end
	return 0
end

function Axiom.Round(value: number, places: number?): number
	local factor = 10 ^ (places or 0)
	return math.floor(value * factor + 0.5) / factor
end

function Axiom.Snap(value: number, step: number): number
	if step == 0 then return value end
	return math.floor(value / step + 0.5) * step
end

function Axiom.PingPong(t: number, length: number): number
	local doubled = t / math.max(length, 1e-8)
	return length - math.abs(doubled % 2 * length - length)
end

function Axiom.Saturate(value: number): number
	return math.clamp(value, 0, 1)
end

function Axiom.Fract(value: number): number
	return value - math.floor(value)
end

function Axiom.InvLerp(from: number, to: number, value: number): number
	if from == to then return 0 end
	return (value - from) / (to - from)
end

function Axiom.Approach(current: number, target: number, maxDelta: number): number
	return current + math.clamp(target - current, -maxDelta, maxDelta)
end

function Axiom.IsFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function Axiom.Abs(value: number): number
	return math.abs(value)
end

function Axiom.Min(a: number, b: number): number
	return math.min(a, b)
end

function Axiom.Max(a: number, b: number): number
	return math.max(a, b)
end

function Axiom.Pow(base: number, exp: number): number
	return base ^ exp
end

function Axiom.Sqrt(value: number): number
	return math.sqrt(value)
end

function Axiom.Cbrt(value: number): number
	return if value < 0 then -((-value) ^ (1 / 3)) else value ^ (1 / 3)
end

function Axiom.Hypot(a: number, b: number): number
	return math.sqrt(a * a + b * b)
end

function Axiom.Log(value: number): number
	return math.log(value)
end

function Axiom.Exp(value: number): number
	return math.exp(value)
end

function Axiom.Smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / math.max(edge1 - edge0, 1e-8), 0, 1)
	return t * t * (3 - 2 * t)
end

function Axiom.Smootherstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / math.max(edge1 - edge0, 1e-8), 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

function Axiom.Gcd(a: number, b: number): number
	a, b = math.abs(a), math.abs(b)
	while b ~= 0 do a, b = b, a % b end
	return a
end

function Axiom.Lcm(a: number, b: number): number
	local g = Axiom.Gcd(a, b)
	if g == 0 then return 0 end
	return math.abs(a * b) / g
end

function Axiom.IsEven(value: number): boolean
	return value % 2 == 0
end

function Axiom.IsOdd(value: number): boolean
	return value % 2 ~= 0
end

function Axiom.Factorial(n: number): number
	local f = 1
	for i = 2, math.floor(n) do f *= i end
	return f
end

function Axiom.Scale(value: number, index: number): number
	local n = math.floor(index)
	local k = (n % 50) + 1
	return value * k / 50
end

function Axiom.Lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

function Axiom.LerpClamped(from: number, to: number, alpha: number): number
	return from + (to - from) * math.clamp(alpha, 0, 1)
end

function Axiom.LerpVector2(from: Vector2, to: Vector2, alpha: number): Vector2
	return from:Lerp(to, alpha)
end

function Axiom.LerpVector3(from: Vector3, to: Vector3, alpha: number): Vector3
	return from:Lerp(to, alpha)
end

function Axiom.LerpColor3(from: Color3, to: Color3, alpha: number): Color3
	return from:Lerp(to, alpha)
end

function Axiom.LerpCFrame(from: CFrame, to: CFrame, alpha: number): CFrame
	return from:Lerp(to, alpha)
end

function Axiom.LerpUDim2(from: UDim2, to: UDim2, alpha: number): UDim2
	return from:Lerp(to, alpha)
end

function Axiom.LerpAngle(from: number, to: number, alpha: number): number
	return from + Axiom.DeltaAngle(from, to) * alpha
end

function Axiom.Inverse(from: number, to: number, value: number): number
	return Axiom.InvLerp(from, to, value)
end

function Axiom.Project(a: Vector3, b: Vector3): Vector3
	local d = b.Magnitude
	if d < 1e-8 then return Vector3.zero end
	return b.Unit * a:Dot(b.Unit)
end

function Axiom.Reject(a: Vector3, b: Vector3): Vector3
	return a - Axiom.Project(a, b)
end

function Axiom.Reflect(incident: Vector3, normal: Vector3): Vector3
	return incident - 2 * incident:Dot(normal) * normal
end

function Axiom.Angle(a: Vector3, b: Vector3): number
	return math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))
end

function Axiom.Distance(a: Vector3, b: Vector3): number
	return (b - a).Magnitude
end

function Axiom.Distance2(a: Vector2, b: Vector2): number
	return (b - a).Magnitude
end

function Axiom.Orthonormal(forward: Vector3, up: Vector3?): CFrame
	local u = up or Vector3.yAxis
	local f = forward.Unit
	local r = f:Cross(u)
	if r.Magnitude < 1e-8 then r = f:Cross(Vector3.xAxis) end
	r = r.Unit
	return CFrame.fromMatrix(Vector3.zero, r, r:Cross(f), -f)
end

function Axiom.Slerp(a: Vector3, b: Vector3, t: number): Vector3
	local dot = math.clamp(a.Unit:Dot(b.Unit), -1, 1)
	local theta = math.acos(dot) * t
	local rel = (b.Unit - a.Unit * dot)
	if rel.Magnitude < 1e-8 then return a:Lerp(b, t) end
	return (a.Unit * math.cos(theta) + rel.Unit * math.sin(theta)) * ((1 - t) * a.Magnitude + t * b.Magnitude)
end

function Axiom.LookAt(from: Vector3, look: Vector3): CFrame
	return CFrame.lookAt(from, look)
end

function Axiom.SlerpCFrame(a: CFrame, b: CFrame, t: number): CFrame
	return a:Lerp(b, t)
end

function Axiom.Flat(cf: CFrame): CFrame
	local look = cf.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-8 then look = Vector3.zAxis end
	return CFrame.lookAt(cf.Position, cf.Position + look.Unit)
end

function Axiom.InSine(t: number): number
	return Axiom._ease("Sine", "In", math.clamp(t, 0, 1))
end

function Axiom.OutSine(t: number): number
	return Axiom._ease("Sine", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutSine(t: number): number
	return Axiom._ease("Sine", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InQuad(t: number): number
	return Axiom._ease("Quad", "In", math.clamp(t, 0, 1))
end

function Axiom.OutQuad(t: number): number
	return Axiom._ease("Quad", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutQuad(t: number): number
	return Axiom._ease("Quad", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InCubic(t: number): number
	return Axiom._ease("Cubic", "In", math.clamp(t, 0, 1))
end

function Axiom.OutCubic(t: number): number
	return Axiom._ease("Cubic", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutCubic(t: number): number
	return Axiom._ease("Cubic", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InQuart(t: number): number
	return Axiom._ease("Quart", "In", math.clamp(t, 0, 1))
end

function Axiom.OutQuart(t: number): number
	return Axiom._ease("Quart", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutQuart(t: number): number
	return Axiom._ease("Quart", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InQuint(t: number): number
	return Axiom._ease("Quint", "In", math.clamp(t, 0, 1))
end

function Axiom.OutQuint(t: number): number
	return Axiom._ease("Quint", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutQuint(t: number): number
	return Axiom._ease("Quint", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InExpo(t: number): number
	return Axiom._ease("Expo", "In", math.clamp(t, 0, 1))
end

function Axiom.OutExpo(t: number): number
	return Axiom._ease("Expo", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutExpo(t: number): number
	return Axiom._ease("Expo", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InCirc(t: number): number
	return Axiom._ease("Circ", "In", math.clamp(t, 0, 1))
end

function Axiom.OutCirc(t: number): number
	return Axiom._ease("Circ", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutCirc(t: number): number
	return Axiom._ease("Circ", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InBack(t: number): number
	return Axiom._ease("Back", "In", math.clamp(t, 0, 1))
end

function Axiom.OutBack(t: number): number
	return Axiom._ease("Back", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutBack(t: number): number
	return Axiom._ease("Back", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InElastic(t: number): number
	return Axiom._ease("Elastic", "In", math.clamp(t, 0, 1))
end

function Axiom.OutElastic(t: number): number
	return Axiom._ease("Elastic", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutElastic(t: number): number
	return Axiom._ease("Elastic", "InOut", math.clamp(t, 0, 1))
end

function Axiom.InBounce(t: number): number
	return Axiom._ease("Bounce", "In", math.clamp(t, 0, 1))
end

function Axiom.OutBounce(t: number): number
	return Axiom._ease("Bounce", "Out", math.clamp(t, 0, 1))
end

function Axiom.InOutBounce(t: number): number
	return Axiom._ease("Bounce", "InOut", math.clamp(t, 0, 1))
end

function Axiom.Linear(t: number): number
	return math.clamp(t, 0, 1)
end

function Axiom.CubicBezier(t: number, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3): Vector3
	local u = 1 - t
	return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
end

function Axiom.QuadraticBezier(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
	local u = 1 - t
	return u*u*p0 + 2*u*t*p1 + t*t*p2
end

function Axiom.Hover(elapsed: number, anchor: Vector3, look: Vector3): CFrame
	local bob = math.sin(elapsed * 1.6) * 0.22
	return CFrame.lookAt(anchor + Vector3.new(0, bob, 0), look)
end

function Axiom.Float(elapsed: number, anchor: Vector3, look: Vector3): CFrame
	local bob = math.sin(elapsed * 1.1) * 0.18
	return CFrame.lookAt(anchor + Vector3.new(0, bob, 0), look)
end

function Axiom.FloatSpin(elapsed: number, anchor: CFrame): CFrame
	local pos = anchor.Position
	local bob = math.sin(elapsed * 1.1) * 0.18
	return CFrame.new(pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, math.rad((elapsed * 50) % 360), 0)
end

function Axiom.AabbContains(point: Vector3, min: Vector3, max: Vector3): boolean
	return point.X >= min.X and point.X <= max.X and point.Y >= min.Y and point.Y <= max.Y and point.Z >= min.Z and point.Z <= max.Z
end

function Axiom.SphereContains(point: Vector3, center: Vector3, radius: number): boolean
	return (point - center).Magnitude <= radius
end

function Axiom.RayPlane(origin: Vector3, dir: Vector3, point: Vector3, normal: Vector3): Vector3
	local denom = dir:Dot(normal)
	if math.abs(denom) < 1e-8 then return Vector3.zero end
	local t = (point - origin):Dot(normal) / denom
	if t < 0 then return Vector3.zero end
	return origin + dir * t
end

function Axiom.Barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3): Vector3
	local v0, v1, v2 = b - a, c - a, p - a
	local d00, d01, d11, d20, d21 = v0:Dot(v0), v0:Dot(v1), v1:Dot(v1), v2:Dot(v0), v2:Dot(v1)
	local denom = d00 * d11 - d01 * d01
	if math.abs(denom) < 1e-8 then return Vector3.new(1, 0, 0) end
	local v = (d11 * d20 - d01 * d21) / denom
	local w = (d00 * d21 - d01 * d20) / denom
	return Vector3.new(1 - v - w, v, w)
end

function Axiom.ClosestPointOnSegment(p: Vector3, a: Vector3, b: Vector3): Vector3
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-8), 0, 1)
	return a + ab * t
end

function Axiom.Deg(rad: number): number
	return math.deg(rad)
end

function Axiom.Rad(deg: number): number
	return math.rad(deg)
end

function Axiom.DeltaAngle(from: number, to: number): number
	local delta = (to - from + math.pi) % (math.pi * 2) - math.pi
	return delta
end

function Axiom.DeltaAngleDegrees(from: number, to: number): number
	local delta = (to - from) % 360
	if delta > 180 then delta -= 360 end
	return delta
end

function Axiom.NormalizeAngle(angle: number): number
	return Axiom.Wrap(angle, -math.pi, math.pi)
end

function Axiom.Sin(x: number): number
	return math.sin(x)
end

function Axiom.Cos(x: number): number
	return math.cos(x)
end

function Axiom.Tan(x: number): number
	return math.tan(x)
end

function Axiom.Asin(x: number): number
	return math.asin(x)
end

function Axiom.Acos(x: number): number
	return math.acos(x)
end

function Axiom.Atan2(y: number, x: number): number
	return math.atan2(y, x)
end

function Axiom.RandomRange(min: number, max: number): number
	return min + (max - min) * math.random()
end

function Axiom.Weighted(weights: { number }): number
	if #weights == 0 then return 0 end
	local total = 0
	for _, w in weights do total += w end
	if total <= 0 then return 1 end
	local pick = math.random() * total
	local acc = 0
	for i, w in weights do acc += w
		if pick <= acc then return i end
	end
	return #weights
end

function Axiom.Gaussian(mean: number?, std: number?): number
	local u, v = math.random(), math.random()
	local mag = math.sqrt(-2 * math.log(math.max(u, 1e-8))) * math.cos(2 * math.pi * v)
	return (mean or 0) + mag * (std or 1)
end

function Axiom.Average(values: { number }): number
	if #values == 0 then return 0 end
	local sum = 0
	for _, v in values do sum += v end
	return sum / #values
end

function Axiom.Sum(values: { number }): number
	local total = 0
	for _, v in values do total += v end
	return total
end

function Axiom.HashU32(n: number): number
	local x = bit32.bxor(math.floor(n) * 374761393, bit32.rshift(math.floor(n), 13))
	return bit32.band(x * 1274126177, 0xffffffff)
end

function Axiom.Value1(x: number): number
	return Axiom.HashU32(x) / 4294967295
end

function Axiom.Value2(x: number, y: number): number
	return Axiom.HashU32(x * 374761 + y * 668265) / 4294967295
end

function Axiom.Value3(x: number, y: number, z: number): number
	return Axiom.HashU32(x * 374761 + y * 668265 + z * 1274126) / 4294967295
end

function Axiom.FromHSV(h: number, s: number, v: number): Color3
	return Color3.fromHSV(h, s, v)
end

function Axiom.Contrast(color: Color3, amount: number): Color3
	return Color3.new(math.clamp((color.R - 0.5) * amount + 0.5, 0, 1), math.clamp((color.G - 0.5) * amount + 0.5, 0, 1), math.clamp((color.B - 0.5) * amount + 0.5, 0, 1))
end

function Axiom.LerpHSV(a: Color3, b: Color3, t: number): Color3
	local ah, as, av = a:ToHSV()
	local bh, bs, bv = b:ToHSV()
	return Color3.fromHSV((ah + Axiom.DeltaAngle(ah * math.pi * 2, bh * math.pi * 2) / (math.pi * 2) * t) % 1, as + (bs - as) * t, av + (bv - av) * t)
end

Axiom.Groups = {
	Scalar = { "Clamp", "Map", "Wrap", "Sign", "Round", "Snap", "PingPong", "Saturate", "Fract", "InvLerp", "Approach", "IsFinite", "Abs", "Min", "Max", "Pow", "Sqrt", "Cbrt", "Hypot", "Log", "Exp", "Smoothstep", "Smootherstep", "Gcd", "Lcm", "IsEven", "IsOdd", "Factorial", "Scale" },
	Lerp = { "Lerp", "LerpClamped", "LerpVector2", "LerpVector3", "LerpColor3", "LerpCFrame", "LerpUDim2", "LerpAngle", "Inverse" },
	Vector = { "Project", "Reject", "Reflect", "Angle", "Distance", "Distance2", "Orthonormal", "Slerp", "LookAt" },
	CFrame = { "SlerpCFrame", "Flat" },
	Easing = { "InSine", "OutSine", "InOutSine", "InQuad", "OutQuad", "InOutQuad", "InCubic", "OutCubic", "InOutCubic", "InQuart", "OutQuart", "InOutQuart", "InQuint", "OutQuint", "InOutQuint", "InExpo", "OutExpo", "InOutExpo", "InCirc", "OutCirc", "InOutCirc", "InBack", "OutBack", "InOutBack", "InElastic", "OutElastic", "InOutElastic", "InBounce", "OutBounce", "InOutBounce", "Linear" },
	Bezier = { "CubicBezier", "QuadraticBezier", "Hover", "Float", "FloatSpin" },
	Geometry = { "AabbContains", "SphereContains", "RayPlane", "Barycentric", "ClosestPointOnSegment" },
	Trig = { "Deg", "Rad", "DeltaAngle", "DeltaAngleDegrees", "NormalizeAngle", "Sin", "Cos", "Tan", "Asin", "Acos", "Atan2" },
	Probability = { "RandomRange", "Weighted", "Gaussian", "Average", "Sum" },
	Noise = { "HashU32", "Value1", "Value2", "Value3" },
	Color = { "FromHSV", "Contrast", "LerpHSV" },
} :: { [string]: { string } }

function Axiom.Select(groupNames: { string }): typeof(Axiom)
	local selected: { [string]: unknown } = {}
	for _, group in groupNames do
		local names = Axiom.Groups[group]
		if not names then
			error(`[Axiom.Select] unknown group "{group}"`)
		end
		for _, name in names do
			selected[name] = Axiom[name]
		end
	end
	if selected.LerpVector3 ~= nil then
		selected.LerpVector = selected.LerpVector3
	end
	if selected.RandomRange ~= nil then
		selected.Random = selected.RandomRange
	end
	if selected.DeltaAngle ~= nil then
		selected.AngleDiff = selected.DeltaAngle
	end
	return selected :: typeof(Axiom)
end

Axiom.LerpVector = Axiom.LerpVector3
Axiom.Random = Axiom.RandomRange
Axiom.AngleDiff = Axiom.DeltaAngle
return Axiom
