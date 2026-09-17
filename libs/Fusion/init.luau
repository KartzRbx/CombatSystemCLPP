--!strict
-- Cluaupp Fusion — typed border over dphfox/Fusion (_impl).

local Impl = require(script._impl)

export type Animatable = Impl.Animatable
export type UsedAs<T> = Impl.UsedAs<T>
export type Child = Impl.Child
export type Computed<T> = Impl.Computed<T>
export type Contextual<T> = Impl.Contextual<T>
export type GraphObject = Impl.GraphObject
export type For<KO, VO> = Impl.For<KO, VO>
export type Observer = Impl.Observer
export type PropertyTable = Impl.PropertyTable
export type Scope<T> = Impl.Scope<T>
export type ScopedObject = Impl.ScopedObject
export type SpecialKey = Impl.SpecialKey
export type Spring<T> = Impl.Spring<T>
export type StateObject<T> = Impl.StateObject<T>
export type Task = Impl.Task
export type Tween<T> = Impl.Tween<T>
export type Use = Impl.Use
export type Value<T, S = T> = Impl.Value<T, S>
export type Version = Impl.Version
export type Fusion = typeof(Impl)

return Impl
