--!optimize 2
--!strict
--[=[
	@class Pin
	World-space BillboardGui that stays on an adornee, faces the camera, and
	hosts any GuiObject.

	```lua
	local billboard = Pin.new(part, frame, {
		Size = UDim2.fromOffset(120, 40),
		StudsOffset = Vector3.new(0, 3, 0),
		MaxDistance = 80,
		Occlude = true,
	})
	billboard:SetText("Hello")
	```
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Pin = {}
Pin.__index = Pin

local occludeModule: any = nil
do
	local sibling = script.Parent:FindFirstChild("Occlude")
	if sibling and sibling:IsA("ModuleScript") then
		local ok, result = pcall(require, sibling)
		if ok then
			occludeModule = result
		end
	end
end

export type Options = {
	Name: string?,
	Size: UDim2?,
	StudsOffset: Vector3?,
	StudsOffsetWorldSpace: Vector3?,
	MaxDistance: number?,
	MinDistance: number?,
	AlwaysOnTop: boolean?,
	LightInfluence: number?,
	Parent: Instance?,
	Occlude: boolean?,
	Fade: boolean?,
	Scale: boolean?,
}

export type Pin = typeof(setmetatable(
	{} :: {
		Adornee: Instance,
		Gui: GuiObject,
		Billboard: BillboardGui,
		_janitor: { () -> () },
		_alive: boolean,
		_enabled: boolean,
		_occluded: boolean,
		_occlude: boolean,
		_fade: boolean,
		_scale: boolean,
		_baseSize: UDim2,
		_canvas: CanvasGroup,
	},
	Pin
))

local function resolveParent(adornee: Instance, explicit: Instance?): Instance
	if explicit then
		return explicit
	end
	if adornee:IsA("BasePart") or adornee:IsA("Model") or adornee:IsA("Attachment") then
		return adornee
	end
	if RunService:IsClient() then
		local player = Players.LocalPlayer
		local gui = player and player:FindFirstChildOfClass("PlayerGui")
		if gui then
			return gui
		end
	end
	return Workspace
end

local function worldPosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	local part = instance:FindFirstChildWhichIsA("BasePart", true)
	if part then
		return part.Position
	end
	return nil
end

local function occludeIgnore(target: Instance): { Instance }
	local list = { target }
	if RunService:IsClient() then
		local player = Players.LocalPlayer
		local character = player and player.Character
		if character then
			table.insert(list, character)
		end
	end
	return list
end

local function isOccluded(origin: Vector3, goal: Vector3, target: Instance): boolean
	if occludeModule then
		local checker = occludeModule.IsOccluded or occludeModule.Check or occludeModule.Raycast
		if typeof(checker) == "function" then
			local ok, blocked = pcall(checker, origin, goal, target)
			if ok and typeof(blocked) == "boolean" then
				return blocked
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = occludeIgnore(target)
	params.FilterType = Enum.RaycastFilterType.Exclude
	local delta = goal - origin
	if delta.Magnitude < 0.05 then
		return false
	end
	local hit = Workspace:Raycast(origin, delta, params)
	if hit == nil then
		return false
	end
	return (hit.Position - goal).Magnitude >= 2
end

--[=[
	@within Pin
	@param adornee Instance -- Part, Model, Attachment, or any Instance with a position
	@param gui GuiObject -- Frame / TextLabel cloned or reparented into the billboard
	@param options Options?
	@return Pin
]=]
function Pin.new(adornee: Instance, gui: GuiObject, options: Options?): Pin
	local opts = options or {}
	local billboard = Instance.new("BillboardGui")
	billboard.Name = opts.Name or "Pin"
	if adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model") then
		billboard.Adornee = adornee
	end
	local baseSize = opts.Size
		or UDim2.fromOffset(math.max(gui.AbsoluteSize.X, 80), math.max(gui.AbsoluteSize.Y, 32))
	billboard.Size = baseSize
	billboard.StudsOffset = opts.StudsOffset or Vector3.new(0, 2, 0)
	billboard.StudsOffsetWorldSpace = opts.StudsOffsetWorldSpace or Vector3.zero
	billboard.MaxDistance = opts.MaxDistance or 120
	billboard.MinDistance = opts.MinDistance or 0
	billboard.AlwaysOnTop = if opts.AlwaysOnTop == nil then true else opts.AlwaysOnTop
	billboard.LightInfluence = opts.LightInfluence or 0
	billboard.ResetOnSpawn = false
	billboard.Active = true
	billboard.ClipsDescendants = false
	billboard.Parent = resolveParent(adornee, opts.Parent)

	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "PinCanvas"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.GroupTransparency = 0
	canvas.Parent = billboard
	gui.Parent = canvas

	local self = setmetatable({
		Adornee = adornee,
		Gui = gui,
		Billboard = billboard,
		_janitor = {} :: { () -> () },
		_alive = true,
		_enabled = true,
		_occluded = false,
		_occlude = if opts.Occlude == nil then true else opts.Occlude,
		_fade = if opts.Fade == nil then true else opts.Fade,
		_scale = if opts.Scale == nil then true else opts.Scale,
		_baseSize = baseSize,
		_canvas = canvas,
	}, Pin)

	local function applyEnabled()
		billboard.Enabled = self._enabled and not self._occluded
	end

	local connection = RunService.Heartbeat:Connect(function()
		if not self._alive or not adornee.Parent then
			return
		end
		if billboard.Adornee == nil then
			local part = adornee:FindFirstChildWhichIsA("BasePart", true)
			if part then
				billboard.Adornee = part
			end
		end
		local camera = Workspace.CurrentCamera
		local goal = worldPosition(billboard.Adornee or adornee)
		if not camera or not goal then
			return
		end
		local origin = camera.CFrame.Position
		local distance = (goal - origin).Magnitude
		local maxDistance = billboard.MaxDistance
		if maxDistance <= 0 then
			maxDistance = 1e9
		end
		local minDistance = billboard.MinDistance

		if self._occlude then
			self._occluded = isOccluded(origin, goal, billboard.Adornee or adornee)
		else
			self._occluded = false
		end
		applyEnabled()

		if self._scale then
			local scale = math.clamp(1 - (distance / maxDistance) * 0.65, 0.35, 1)
			billboard.Size = UDim2.new(
				self._baseSize.X.Scale * scale,
				self._baseSize.X.Offset * scale,
				self._baseSize.Y.Scale * scale,
				self._baseSize.Y.Offset * scale
			)
		else
			billboard.Size = self._baseSize
		end

		if self._fade then
			local fadeStart = maxDistance * 0.65
			local nearFade = if minDistance > 0 then minDistance else 0
			local alpha = 0
			if distance >= maxDistance then
				alpha = 1
			elseif distance > fadeStart then
				alpha = (distance - fadeStart) / math.max(maxDistance - fadeStart, 0.01)
			elseif nearFade > 0 and distance < nearFade + 4 then
				alpha = 1 - math.clamp((distance - nearFade) / 4, 0, 1)
			end
			canvas.GroupTransparency = math.clamp(alpha, 0, 1)
		else
			canvas.GroupTransparency = 0
		end
	end)
	table.insert(self._janitor, function()
		connection:Disconnect()
	end)
	table.insert(self._janitor, function()
		billboard:Destroy()
	end)

	return self
end

--[=[
	@within Pin
]=]
function Pin:SetText(text: string)
	if self.Gui:IsA("TextLabel") or self.Gui:IsA("TextButton") or self.Gui:IsA("TextBox") then
		(self.Gui :: TextLabel).Text = text
		return
	end
	local label = self.Gui:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = text
	end
end

--[=[
	@within Pin
]=]
function Pin:SetEnabled(enabled: boolean)
	self._enabled = enabled
	self.Billboard.Enabled = enabled and not self._occluded
end

--[=[
	@within Pin
]=]
function Pin:SetMaxDistance(distance: number)
	self.Billboard.MaxDistance = distance
end

--[=[
	@within Pin
]=]
function Pin:Destroy()
	if not self._alive then
		return
	end
	self._alive = false
	for _, cleanup in self._janitor do
		cleanup()
	end
	table.clear(self._janitor)
end

return Pin
