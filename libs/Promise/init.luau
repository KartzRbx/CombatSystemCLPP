--!strict
-- Cluaupp Promise — typed border. Engine: evaera/roblox-lua-promise (_impl).
-- C++ Then / Catch / Await / Cancel are aliases of andThen / catch / await / cancel.

local Types = require(script.types)
local Impl = require(script._impl) :: Types.PromiseStatic

export type Status = Types.Status
export type Promise<T...> = Types.Promise<T...>
export type TypedPromise<T...> = Types.TypedPromise<T...>
export type PromiseStatic = Types.PromiseStatic

return Impl
