const Path = {}

export type Path = { string | number }

type function PathOf(templateType: type): type
	local function unwrapOptional(valueType: type): type
		if not valueType:is("union") then
			return valueType
		end

		local resolved = nil
		for _, component in valueType:components() do
			if not (component:is("singleton") and component:value() == nil) then
				resolved = if resolved then types.unionof(resolved, component) else component
			end
		end

		return resolved or valueType
	end

	local function mapValue(valueType: type): type
		valueType = unwrapOptional(valueType)

		if valueType:is("any") or valueType:is("unknown") then
			return types.newtable()
		end

		if valueType:is("union") then
			for _, component in valueType:components() do
				if component:is("table") then
					return mapValue(component)
				end
			end
			return types.newtable()
		end

		if valueType:is("intersection") then
			local mapped = types.newtable()
			local hasMembers = false

			for _, component in valueType:components() do
				if component:is("table") then
					local sub = mapValue(component)
					for key in sub:properties() do
						local childType = sub:readproperty(key)
						if childType then
							mapped:setproperty(key, childType)
							hasMembers = true
						end
					end

					local indexerInfo = sub:indexer()
					if indexerInfo then
						mapped:setindexer(indexerInfo.index, indexerInfo.readresult)
						hasMembers = true
					end
				end
			end

			if hasMembers then
				return mapped
			end
		end

		if not valueType:is("table") then
			local token = types.newtable()
			token:setproperty("__pathValue", valueType)
			return token
		end

		local mapped = types.newtable()
		local hasMembers = false

		for key in valueType:properties() do
			local childType = valueType:readproperty(key)
			if childType then
				mapped:setproperty(key, mapValue(unwrapOptional(childType)))
				hasMembers = true
			end
		end

		local indexerInfo = valueType:indexer()
		if indexerInfo then
			mapped:setindexer(indexerInfo.index, mapValue(indexerInfo.readresult))
			hasMembers = true
		end

		if hasMembers then
			return mapped
		end

		return types.newtable()
	end

	return mapValue(templateType)
end

-- PathTree<T> mirrors the template shape for navigation (Paths).
export type PathTree<T> = PathOf<T>
-- PathToken<V> is the typed handle for a leaf path targeting value type V.
export type PathToken<V> = { __pathValue: V }
export type TemplatePaths<T> = PathTree<T>

local ROOT_TOKEN: PathTree<{}>? = nil

const clone = function(path: Path?): Path
	if not path then
		return {}
	end
	local out = table.create(#path)
	for i, v in path do
		out[i] = v
	end
	return out
end

local function createToken(segments: Path): any
	local token = {}
	rawset(token, "__kdsv2_path_token", true)
	rawset(token, "__segments", table.freeze(clone(segments)))
	rawset(token, "__children", nil)

	return setmetatable(token, {
		__index = function(self, key)
			if type(key) ~= "string" and type(key) ~= "number" then
				return nil
			end

			local children = rawget(self, "__children")
			if not children then
				children = {}
				rawset(self, "__children", children)
			end

			local cached = children[key]
			if cached then
				return cached
			end

			local nextSegments = clone(rawget(self, "__segments"))
			nextSegments[#nextSegments + 1] = key
			local child = createToken(nextSegments)
			children[key] = child
			return child
		end,
	})
end

function Path.rootToken(): PathTree<{}>
	if not ROOT_TOKEN then
		ROOT_TOKEN = createToken({})
	end
	return ROOT_TOKEN :: PathTree<{}>
end

function Path.createTemplatePaths<T>(template: T, currentSegments: Path?): PathTree<T>
	local token = createToken(clone(currentSegments))

	if type(template) ~= "table" then
		rawset(token, "__pathValue", template)
		return token :: PathTree<T>
	end

	local children = {}
	rawset(token, "__children", children)

	for key, value in template do
		local keyType = type(key)
		if keyType == "string" or keyType == "number" then
			local nextSegments = clone(currentSegments)
			nextSegments[#nextSegments + 1] = key

			local child = Path.createTemplatePaths(value, nextSegments)
			children[key] = child
			rawset(token, key, child)
		end
	end

	return token :: PathTree<T>
end

function Path.isToken(value: any): boolean
	return type(value) == "table" and rawget(value, "__kdsv2_path_token") == true
end

function Path.toArray(path: Path | PathTree<{}>?): Path?
	if path == nil then
		return nil
	end
	if Path.isToken(path) then
		return clone(rawget(path :: any, "__segments"))
	end
	return clone(path :: Path)
end

function Path.validate(path: Path?): boolean
	if not path then
		return true
	end
	for _, segment in path do
		local kind = type(segment)
		if kind ~= "string" and kind ~= "number" then
			return false
		end
	end
	return true
end

function Path.toKey(path: Path?): string
	if not path or #path == 0 then
		return ""
	end
	local parts = table.create(#path)
	for i, v in path do
		if type(v) == "string" then
			parts[i] = "s\1" .. v
		else
			parts[i] = "n\1" .. tostring(v)
		end
	end
	return table.concat(parts, "\0")
end

function Path.clone(path: Path?): Path
	return clone(path)
end

function Path.parent(path: Path): Path
	local out = table.create(math.max(#path - 1, 0))
	for i = 1, #path - 1 do
		out[i] = path[i]
	end
	return out
end

return Path
