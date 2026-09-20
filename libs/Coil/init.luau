--!native
--!optimize 2
--!strict
-- Coil — Fraktality damped spring. Frequency is Hz.
-- Gleam.Spring: Coil.new, :Set, :Get, :Step — do not rename those.

local Coil = {}
Coil.__index = Coil

local TAU = 2 * math.pi
local SNAP_DT = 1
local DECAY_SNAP = 50
local CRITICAL_EPS = 1e-5

export type Coil = typeof(setmetatable(
	{} :: {
		Damping: number,
		Frequency: number,
		Goal: any,
		Position: any,
		Velocity: any,
	},
	Coil
))

local function pack(value: any): { number }
	local kind = typeof(value)
	if kind == "number" then
		return { value }
	elseif kind == "Vector3" then
		return { value.X, value.Y, value.Z }
	elseif kind == "Vector2" then
		return { value.X, value.Y }
	elseif kind == "Color3" then
		return { value.R, value.G, value.B }
	elseif kind == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "UDim" then
		return { value.Scale, value.Offset }
	end
	error("Coil: expected number, Vector3, Vector2, Color3, UDim2, or UDim")
end

local function unpackKind(kind: string, components: { number }): any
	if kind == "number" then
		return components[1]
	elseif kind == "Vector3" then
		return Vector3.new(components[1], components[2], components[3])
	elseif kind == "Vector2" then
		return Vector2.new(components[1], components[2])
	elseif kind == "Color3" then
		return Color3.new(components[1], components[2], components[3])
	elseif kind == "UDim2" then
		return UDim2.new(components[1], components[2], components[3], components[4])
	elseif kind == "UDim" then
		return UDim.new(components[1], components[2])
	end
	return components[1]
end

local function zeroLike(value: any): any
	local kind = typeof(value)
	if kind == "number" then
		return 0
	elseif kind == "Vector3" then
		return Vector3.zero
	elseif kind == "Vector2" then
		return Vector2.zero
	elseif kind == "Color3" then
		return Color3.new(0, 0, 0)
	elseif kind == "UDim2" then
		return UDim2.new()
	elseif kind == "UDim" then
		return UDim.new()
	end
	return 0
end

local function stepScalar(position: number, velocity: number, goal: number, damping: number, omega: number, dt: number): (number, number)
	if omega <= 0 then
		return position, velocity
	end
	local envelope = damping * omega * dt
	if dt >= SNAP_DT or envelope > DECAY_SNAP then
		return goal, 0
	end
	local x = position - goal
	local v = velocity
	if damping < 1 - CRITICAL_EPS then
		local wd = omega * math.sqrt(1 - damping * damping)
		if wd == 0 then
			return goal, 0
		end
		local e = math.exp(-damping * omega * dt)
		local c1 = x
		local c2 = (v + damping * omega * x) / wd
		local wt = wd * dt
		local cos = math.cos(wt)
		local sin = math.sin(wt)
		return goal + e * (c1 * cos + c2 * sin),
			-e * ((c1 * damping * omega - c2 * wd) * cos + (c1 * wd + c2 * damping * omega) * sin)
	elseif damping <= 1 + CRITICAL_EPS then
		local e = math.exp(-omega * dt)
		return goal + e * (x + (v + omega * x) * dt), e * (v * (1 - omega * dt) - omega * omega * x * dt)
	end
	local disc = math.sqrt(damping * damping - 1)
	local r1 = -omega * (damping - disc)
	local r2 = -omega * (damping + disc)
	local denom = r2 - r1
	if denom == 0 then
		local e = math.exp(-omega * dt)
		return goal + e * (x + (v + omega * x) * dt), e * (v * (1 - omega * dt) - omega * omega * x * dt)
	end
	local c2 = (v - r1 * x) / denom
	local c1 = x - c2
	local e1 = math.exp(r1 * dt)
	local e2 = math.exp(r2 * dt)
	return goal + c1 * e1 + c2 * e2, c1 * r1 * e1 + c2 * r2 * e2
end

function Coil.new(dampingRatio: number, frequency: number, position: any): Coil
	return setmetatable({
		Damping = dampingRatio,
		Frequency = frequency,
		Goal = position,
		Position = position,
		Velocity = zeroLike(position),
	}, Coil)
end

function Coil.Vector(dampingRatio: number, frequency: number, position: Vector3): Coil
	return Coil.new(dampingRatio, frequency, position)
end

function Coil.UDim(dampingRatio: number, frequency: number, position: UDim2): Coil
	return Coil.new(dampingRatio, frequency, position)
end

Coil.UDim2 = Coil.UDim

function Coil.Color(dampingRatio: number, frequency: number, position: Color3): Coil
	return Coil.new(dampingRatio, frequency, position)
end

function Coil:Set(goal: any)
	self.Goal = goal
end

Coil.SetGoal = Coil.Set

function Coil:Get(): any
	return self.Position
end

function Coil:Impulse(velocity: any)
	local kind = typeof(self.Position)
	if kind == "number" then
		self.Velocity += velocity
		return
	end
	local current = pack(self.Velocity)
	if typeof(velocity) == "number" then
		for i = 1, #current do
			current[i] += velocity
		end
	else
		local delta = pack(velocity)
		local n = math.min(#current, #delta)
		for i = 1, n do
			current[i] += delta[i]
		end
	end
	self.Velocity = unpackKind(kind, current)
end

function Coil:Step(dt: number)
	if dt ~= dt or dt <= 0 then
		return
	end
	local omega = self.Frequency * TAU
	if omega <= 0 then
		return
	end
	local kind = typeof(self.Position)
	if kind == "number" then
		local position, velocity = stepScalar(self.Position, self.Velocity, self.Goal, self.Damping, omega, dt)
		self.Position = position
		self.Velocity = velocity
		return
	end
	local p = pack(self.Position)
	local v = pack(self.Velocity)
	local g = pack(self.Goal)
	local n = math.min(#p, #v, #g)
	for i = 1, n do
		local nextP, nextV = stepScalar(p[i], v[i], g[i], self.Damping, omega, dt)
		p[i] = nextP
		v[i] = nextV
	end
	self.Position = unpackKind(kind, p)
	self.Velocity = unpackKind(kind, v)
end

function Coil:Update(dt: number): any
	self:Step(dt)
	return self.Position
end

Coil.New = Coil.new

return Coil
