--!strict
-- Cluaupp Iris — typed border over SirMallard/Iris (_impl).

local Impl = require(script._impl)
local Types = require(script._impl.Types)

export type State<T> = Types.State<T>
export type Widget = Types.Widget
export type Config = Types.Config
export type Iris = Types.Iris

return Impl :: Types.Iris
