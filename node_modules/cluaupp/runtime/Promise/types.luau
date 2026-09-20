--!strict
-- Cluaupp Promise types. Implementation is evaera/roblox-lua-promise in _impl.

export type Status = "Started" | "Resolved" | "Rejected" | "Cancelled"

export type Promise<T...> = {
	andThen: (self: Promise<T...>, successHandler: (T...) -> ...unknown, failureHandler: ((...unknown) -> ...unknown)?) -> Promise<...unknown>,
	Then: (self: Promise<T...>, successHandler: (T...) -> ...unknown, failureHandler: ((...unknown) -> ...unknown)?) -> Promise<...unknown>,
	catch: (self: Promise<T...>, failureHandler: (...unknown) -> ...unknown) -> Promise<...unknown>,
	Catch: (self: Promise<T...>, failureHandler: (...unknown) -> ...unknown) -> Promise<...unknown>,
	finally: (self: Promise<T...>, finallyHandler: (status: Status) -> ...unknown) -> Promise<...unknown>,
	Finally: (self: Promise<T...>, finallyHandler: (status: Status) -> ...unknown) -> Promise<...unknown>,
	await: (self: Promise<T...>) -> (boolean, T...),
	Await: (self: Promise<T...>) -> (boolean, T...),
	cancel: (self: Promise<T...>) -> (),
	Cancel: (self: Promise<T...>) -> (),
	getStatus: (self: Promise<T...>) -> Status,
	GetStatus: (self: Promise<T...>) -> Status,
}

export type TypedPromise<T...> = Promise<T...>

export type PromiseStatic = {
	Status: {
		Started: "Started",
		Resolved: "Resolved",
		Rejected: "Rejected",
		Cancelled: "Cancelled",
	},
	new: <T...>(
		executor: (
			resolve: (T...) -> (),
			reject: (...unknown) -> (),
			onCancel: ((abortHandler: (() -> ())?) -> boolean)?
		) -> ()
	) -> Promise<T...>,
	delay: (seconds: number) -> Promise<number>,
	resolve: <T...>(T...) -> Promise<T...>,
	reject: (...unknown) -> Promise<...unknown>,
	try: (callback: () -> ()) -> Promise<unknown>,
	all: <T>(list: { Promise<T> }) -> Promise<{ T }>,
	race: <T>(list: { Promise<T> }) -> Promise<T>,
	retry: (callback: () -> Promise<unknown>, times: number) -> Promise<unknown>,
}

return {}
