--!native
--!optimize 2
--!strict
-- Stage — ViewportFrame 3D (Module3D successor).

local Sweep = require(script.Parent.Sweep)

local Stage = {}
Stage.__index = Stage

export type Stage = typeof(setmetatable(
	{} :: {
		Object3D: Model,
		AdornFrame: GuiObject,
		Camera: Camera,
		Visible: boolean,
		Viewport: ViewportFrame,
		World: WorldModel,
	},
	Stage
))

local function wrapModel(source: Instance): Model
	local clone = source:Clone()
	if clone:IsA("Model") then
		if clone.PrimaryPart == nil then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		return clone
	end
	local wrap = Instance.new("Model")
	wrap.Name = clone.Name
	clone.Parent = wrap
	if clone:IsA("BasePart") then
		wrap.PrimaryPart = clone
	else
		wrap.PrimaryPart = wrap:FindFirstChildWhichIsA("BasePart", true)
	end
	return wrap
end

local function fit(model: Model): (Vector3, number)
	local cf, size = model:GetBoundingBox()
	local extent = math.max(size.X, size.Y, size.Z)
	return cf.Position, math.max(extent, 1)
end

local function distance(extent: number, camera: Camera, depth: number): number
	local fov = math.rad(camera.FieldOfView)
	local half = math.tan(fov * 0.5)
	if half <= 1e-4 then
		half = 1e-4
	end
	return ((extent * 0.5) / half) * 1.25 * math.max(depth, 0.05)
end

local function look(self: any)
	local model = self.Object3D
	if not model or not model.Parent then
		return
	end
	local center, extent = fit(model)
	self._center = center
	local dist = distance(extent, self.Camera, self._depth or 1)
	local relative: CFrame = self._relative or CFrame.identity
	local offset = relative:VectorToWorldSpace(Vector3.new(0, extent * 0.12, dist))
	self.Camera.CFrame = CFrame.lookAt(center + offset, center)
end

function Stage.Attach(frame: GuiObject, model: Instance): Stage
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Stage"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(186, 186, 186)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = frame

	local camera = Instance.new("Camera")
	camera.FieldOfView = 70
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local world = Instance.new("WorldModel")
	world.Name = "StageWorld"
	world.Parent = viewport

	local clone = wrapModel(model)
	clone.Parent = world

	local sweep = Sweep.new()
	sweep:Add(viewport)
	sweep:LinkToInstance(frame)

	local self = setmetatable({
		Object3D = clone,
		AdornFrame = frame,
		Camera = camera,
		Visible = true,
		Viewport = viewport,
		World = world,
		_depth = 1,
		_relative = CFrame.identity,
		_orbit = 0,
		_center = Vector3.zero,
		_sweep = sweep,
	}, Stage)
	look(self)
	return self
end

Stage.new = function(model: Instance): Stage
	local holder = Instance.new("Frame")
	holder.Name = "Stage"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	return Stage.Attach(holder, model)
end

function Stage:SetCFrame(newCF: CFrame)
	self._relative = newCF
	self._orbit = 0
	if self.Visible then
		look(self)
	end
end

function Stage:GetCFrame(): CFrame
	return self._relative or CFrame.identity
end

function Stage:SetDepthMultiplier(multiplier: number)
	self._depth = multiplier
	if self.Visible then
		look(self)
	end
end

function Stage:GetDepthMultiplier(): number
	return self._depth or 1
end

function Stage:SetActive(active: boolean)
	self.Viewport.Visible = active
	self.Visible = active
end

function Stage:GetActive(): boolean
	return self.Visible
end

function Stage:Update(dt: number?)
	if not self.Visible then
		return
	end
	if typeof(dt) == "number" then
		self._orbit += dt
		self._relative = CFrame.Angles(0, self._orbit, 0)
	end
	look(self)
end

function Stage:Destroy()
	local sweep = self._sweep
	if sweep then
		sweep:Destroy()
		self._sweep = nil
	elseif self.Viewport then
		self.Viewport:Destroy()
	end
	self.Visible = false
end

Stage.End = Stage.Destroy
Stage.Attach3D = Stage.Attach

return Stage
