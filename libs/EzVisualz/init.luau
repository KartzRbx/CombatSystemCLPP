--!strict
-- Cluaupp EzVisualz — typed border over arxkdev/ezVisualz (_impl).

local Impl = require(script._impl)

export type Effect<T...> = Impl.Effect<T...>
export type EzVisualz = typeof(Impl)

return Impl
