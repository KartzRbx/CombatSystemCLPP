--!native
--!optimize 2
--!strict
--[=[
	@class ArrayIndexer
	Dense reusable indices for ECS-like ids. Acquire pops a free slot (or
	grows); Release returns the id to the pool and swap-removes it from the
	packed live list.

	Type function `Table` — pick one or more keys from a service manifest.
	`Table<Manifest, "CurrencyService">` is the service, not a generic table.
]=]
type ManifestExample = {
	CurrencyService: { AddCash: () -> (), SubtractCash: () -> () },
	DataService: { FetchData: () -> (), ClearData: () -> () },
	PlayerService: { RespawnChar: () -> (), RemoveChar: () -> () },
}

export type function Table(list: type, id: type): type
	if not list:is("table") then
		error(`[ArrayIndexer] list must be the manifest table, got {list.tag}`)
	end

	if id:is("any") or id:is("unknown") or id:is("never") then
		return types.any
	end

	local function availableNames(): { string }
		local names = {}
		for key in list:properties() do
			table.insert(names, tostring(key:value()))
		end
		table.sort(names)
		return names
	end

	-- How many options a type describes (narrower wins on intersection).
	local function width(t: type): number?
		local target = t
		if target:is("table") then
			local indexer = target:readindexer()
			if not indexer then
				return nil
			end
			target = indexer.result
		end
		if target:is("singleton") then
			return 1
		end
		if target:is("union") then
			local n = 0
			for _ in target:components() do
				n += 1
			end
			return n
		end
		return nil
	end

	if id:is("intersection") then
		local best: type? = nil
		local smallest = math.huge
		for _, branch in id:components() do
			local w = width(branch)
			if w and w < smallest then
				smallest = w
				best = branch
			end
		end
		if not best then
			error("[ArrayIndexer] intersection has no usable branch (need a singleton, union, or array of those)")
		end
		id = best
	end

	local fromArray = false
	if id:is("table") then
		local indexer = id:readindexer()
		if not indexer then
			error("[ArrayIndexer] expected an array of keys, got a table with no indexer")
		end
		fromArray = true
		id = indexer.result
	end

	if id:is("string") then
		error('[ArrayIndexer] keys widened to `string`. Use `:: { "A" | "B" }` on the literal, or pass the union directly')
	end

	if id:is("singleton") and not fromArray then
		local name = id:value()
		local prop = list:readproperty(id)
		if prop then
			return prop
		end
		error(`[ArrayIndexer] "{name}" is not in the manifest. Available: {table.concat(availableNames(), ", ")}`)
	end

	local requested = {}
	if id:is("singleton") then
		requested[id:value()] = true
	elseif id:is("union") then
		for _, component in id:components() do
			if not component:is("singleton") then
				error(`[ArrayIndexer] union components must be singletons, got {component.tag}`)
			end
			requested[component:value()] = true
		end
	else
		error(`[ArrayIndexer] id must be a singleton, a union of singletons, or an array of those. Got {id.tag}`)
	end

	local result = types.newtable()
	for key, prop in list:properties() do
		local name = key:value()
		if type(name) == "string" and requested[name] then
			requested[name] = nil
			if prop.read then
				result:setreadproperty(key, prop.read)
			end
			if prop.write then
				result:setwriteproperty(key, prop.write)
			end
		end
	end

	local missing = {}
	for name in requested do
		table.insert(missing, name)
	end
	if #missing > 0 then
		table.sort(missing)
		error(
			`[ArrayIndexer] missing: {table.concat(missing, ", ")}. Available: {table.concat(availableNames(), ", ")}`
		)
	end

	return result
end

type CurrencyService = Table<ManifestExample, "CurrencyService"> --> AddCash: () -> (), SubtractCash: () -> ()
type TwoServices = Table<ManifestExample, "PlayerService" | "DataService"> --> {RespawnChar: () -> (), RemoveChar: () -> ()}, {FetchData: () -> (), ClearData: () -> ()}

local ArrayIndexer = {}
ArrayIndexer.__index = ArrayIndexer

export type ArrayIndexer = typeof(setmetatable(
	{} :: {
		Next: number,
		Free: { number },
		Dense: { number },
		Index: { [number]: number },
	},
	ArrayIndexer
))

function ArrayIndexer.New(): ArrayIndexer
	return setmetatable({
		Next = 1,
		Free = {} :: { number },
		Dense = {} :: { number },
		Index = {} :: { [number]: number },
	}, ArrayIndexer)
end

function ArrayIndexer:Acquire(): number
	local free = self.Free
	local last = #free
	local id = free[last]
	if id ~= nil then
		free[last] = nil
	else
		id = self.Next
		self.Next += 1
	end
	local dense = self.Dense
	local pos = #dense + 1
	dense[pos] = id
	self.Index[id] = pos
	return id
end

function ArrayIndexer:Release(id: number)
	local pos = self.Index[id]
	if pos == nil then
		return
	end
	local dense = self.Dense
	local lastPos = #dense
	local last = dense[lastPos]
	if pos ~= lastPos then
		dense[pos] = last
		self.Index[last] = pos
	end
	dense[lastPos] = nil
	self.Index[id] = nil
	local free = self.Free
	free[#free + 1] = id
end

function ArrayIndexer:Has(id: number): boolean
	return self.Index[id] ~= nil
end

function ArrayIndexer:Living(): { number }
	return self.Dense
end

return ArrayIndexer
