--!native
--!optimize 2
--!strict
--[=[
	@class Occlude
	Raycast occlusion helper Pin can require. `WorldRoot:Raycast` from camera
	to adornee. Default filter excludes the adornee.

	Type function `Keys` — strip named fields from a table type.
	`Keys<PlayerData, "mana">` is `{ nome: string, hp: number }`, never `any`.
]=]
type Example = { nome: string, hp: number, mana: number }

export type function Keys(t: type, k: type)
	if not t:is("table") then
		error(`it should be table`)
	end

	local ocludded = {}
	local function register(ty: type)
		local value = ty:value()
		if type(value) ~= "string" then
			error(`singleton needs to be string`)
		end
		ocludded[value] = true
	end

	if k:is("union") then
		for _, ty in k:components() do
			if ty:is("singleton") then
				register(ty)
			end
		end
	elseif k:is("singleton") then
		register(k)
	else
		error(`k must be union or singleton`)
	end

	local result = types.copy(t)
	local remover = {}

	for index in result:properties() do
		local name = index:value()
		if type(name) == "string" and ocludded[name] then
			table.insert(remover, index)
		end
	end

	for _, index in remover do
		result:setproperty(index, nil)
	end

	return result
end

type _E3_14 = Keys<Example, "mana"> --> { nome: string, hp: number }

local Occlude = {}

local function adorneePosition(adornee: Instance): Vector3?
	if adornee:IsA("BasePart") then
		return adornee.Position
	end
	if adornee:IsA("Model") then
		return adornee:GetPivot().Position
	end
	if adornee:IsA("Attachment") then
		return adornee.WorldPosition
	end
	local part = adornee:FindFirstChildWhichIsA("BasePart", true)
	if part then
		return part.Position
	end
	return nil
end

local function rayParams(adornee: Instance, params: RaycastParams?): RaycastParams
	if params then
		return params
	end
	local created = RaycastParams.new()
	created.FilterDescendantsInstances = { adornee }
	created.FilterType = Enum.RaycastFilterType.Exclude
	return created
end

function Occlude.Position(adornee: Instance): Vector3?
	return adorneePosition(adornee)
end

function Occlude.Raycast(world: WorldRoot, camera: Camera, adornee: Instance, params: RaycastParams?): RaycastResult?
	local goal = adorneePosition(adornee)
	if not goal then
		return nil
	end
	local origin = camera.CFrame.Position
	return world:Raycast(origin, goal - origin, rayParams(adornee, params))
end

function Occlude.IsOccluded(world: WorldRoot, camera: Camera, adornee: Instance, params: RaycastParams?, slack: number?): boolean
	local goal = adorneePosition(adornee)
	if not goal then
		return true
	end
	local hit = Occlude.Raycast(world, camera, adornee, params)
	if hit == nil then
		return false
	end
	return (hit.Position - goal).Magnitude >= (slack or 2)
end

function Occlude.Visible(world: WorldRoot, camera: Camera, adornee: Instance, params: RaycastParams?, slack: number?): boolean
	return not Occlude.IsOccluded(world, camera, adornee, params, slack)
end

return Occlude
