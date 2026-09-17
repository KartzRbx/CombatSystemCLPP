--!strict
-- Cluaupp Chrono — typed border over Parihsz/Chrono (_impl).

local Impl = require(script._impl)

export type SnapshotData<Value, Velocity> = Impl.SnapshotData<Value, Velocity>
export type Signal<fx, T...> = Impl.Signal<fx, T...>
export type Connection = Impl.Connection
export type Event<fx, T...> = Impl.Event<fx, T...>
export type Snapshot<Value, Velocity> = Impl.Snapshot<Value, Velocity>
export type Entity = Impl.Entity
export type Chrono = typeof(Impl)

return Impl
