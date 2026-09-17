--!strict
--[=[
	@class StickyBillboard
	World-space BillboardGui that stays on an adornee, faces the camera, and
	hosts any GuiObject. No public GitHub package existed for kartzrbx/stickybillboard;
	this is the Cluaupp implementation of that system.

	```lua
	local billboard = StickyBillboard.new(part, frame, {
		Size = UDim2.fromOffset(120, 40),
		StudsOffset = Vector3.new(0, 3, 0),
		MaxDistance = 80,
	})
	billboard:SetText("Hello")
	```
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StickyBillboard = {}
StickyBillboard.__index = StickyBillboard

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
}

export type StickyBillboard = typeof(setmetatable(
	{} :: {
		Adornee: Instance,
		Gui: GuiObject,
		Billboard: BillboardGui,
		_janitor: { () -> () },
		_alive: boolean,
	},
	StickyBillboard
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

--[=[
	@within StickyBillboard
	@param adornee Instance -- Part, Model, Attachment, or any Instance with a position
	@param gui GuiObject -- Frame / TextLabel cloned or reparented into the billboard
	@param options Options?
	@return StickyBillboard
]=]
function StickyBillboard.new(adornee: Instance, gui: GuiObject, options: Options?): StickyBillboard
	local opts = options or {}
	local billboard = Instance.new("BillboardGui")
	billboard.Name = opts.Name or "StickyBillboard"
	if adornee:IsA("BasePart") then
		billboard.Adornee = adornee
	elseif adornee:IsA("Attachment") then
		billboard.Adornee = adornee
	elseif adornee:IsA("Model") then
		billboard.Adornee = adornee
	end
	billboard.Size = opts.Size or UDim2.fromOffset(math.max(gui.AbsoluteSize.X, 80), math.max(gui.AbsoluteSize.Y, 32))
	billboard.StudsOffset = opts.StudsOffset or Vector3.new(0, 2, 0)
	billboard.StudsOffsetWorldSpace = opts.StudsOffsetWorldSpace or Vector3.zero
	billboard.MaxDistance = opts.MaxDistance or 120
	billboard.MinDistance = opts.MinDistance or 0
	billboard.AlwaysOnTop = if opts.AlwaysOnTop == nil then true else opts.AlwaysOnTop
	billboard.LightInfluence = opts.LightInfluence or 0
	billboard.ResetOnSpawn = false
	billboard.Active = true
	billboard.Parent = resolveParent(adornee, opts.Parent)

	gui.Parent = billboard

	local self = setmetatable({
		Adornee = adornee,
		Gui = gui,
		Billboard = billboard,
		_janitor = {} :: { () -> () },
		_alive = true,
	}, StickyBillboard)

	if billboard.Adornee == nil then
		local connection = RunService.Heartbeat:Connect(function()
			if not self._alive or not adornee.Parent then
				return
			end
			local part = adornee:FindFirstChildWhichIsA("BasePart", true)
			if part then
				billboard.Adornee = part
			end
		end)
		table.insert(self._janitor, function()
			connection:Disconnect()
		end)
	end

	table.insert(self._janitor, function()
		billboard:Destroy()
	end)

	return self
end

--[=[
	@within StickyBillboard
]=]
function StickyBillboard:SetText(text: string)
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
	@within StickyBillboard
]=]
function StickyBillboard:SetEnabled(enabled: boolean)
	self.Billboard.Enabled = enabled
end

--[=[
	@within StickyBillboard
]=]
function StickyBillboard:SetMaxDistance(distance: number)
	self.Billboard.MaxDistance = distance
end

--[=[
	@within StickyBillboard
]=]
function StickyBillboard:Destroy()
	if not self._alive then
		return
	end
	self._alive = false
	for _, cleanup in self._janitor do
		cleanup()
	end
	table.clear(self._janitor)
end

return StickyBillboard
