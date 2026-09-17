--!strict
-- Cluaupp Janitor — typed border. Engine: howmanysmall/Janitor (_impl).
-- Public type and return value are the implementation. Promise is required
-- inside _impl as CluauppLibs.Promise (`script.Parent.Parent.Promise`).

--[=[
	@class Janitor
	Cleans up connections, instances, promises, and threads.
]=]

local Impl = require(script._impl)

export type Janitor = Impl.Janitor

return Impl
