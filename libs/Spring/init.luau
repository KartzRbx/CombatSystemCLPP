--!strict
-- Cluaupp Spring — typed border over nightcycle/spring (_impl).

local Impl = require(script._impl)

export type Spring = {
	Damping: number,
	Frequency: number,
	Goal: number,
	Position: number,
	Velocity: number,
	Set: (self: Spring, goal: number) -> (),
	Get: (self: Spring) -> number,
	Step: (self: Spring, deltaTime: number) -> (),
	Impulse: (self: Spring, velocity: number) -> (),
	SetGoal: (self: Spring, target: number) -> (),
	Update: (self: Spring, dt: number) -> number,
}

type SpringStatic = {
	new: (dampingRatio: number, frequency: number, position: number) -> Spring,
}

return Impl :: SpringStatic
