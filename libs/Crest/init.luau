--!optimize 2
--!strict
-- Crest — topbar icons (TopbarPlus successor), Gleam-friendly.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Crest = {}
Crest.__index = Crest

export type Crest = typeof(setmetatable(
	{} :: {
		_button: ImageButton,
		_label: TextLabel,
		_notice: Frame,
		_selected: boolean,
		_items: { GuiObject },
		_events: { [string]: { (...any) -> () } },
		_autoDeselect: boolean,
		_idleColor: Color3,
		_activeColor: Color3,
		_alive: boolean,
	},
	Crest
))

local orderCounter = 0
local host: ScreenGui? = nil
local icons: { Crest } = {}
local insetConn: RBXScriptConnection? = nil
local viewportConn: RBXScriptConnection? = nil

local ICON = 44
local GAP = 6

local function isClient(): boolean
	return RunService:IsClient()
end

local function readInset(): (number, number, number)
	local top = 8
	local height = ICON
	local left = 12
	local ok, rect = pcall(function()
		return (GuiService :: any).TopbarInset
	end)
	if ok and typeof(rect) == "Rect" then
		top = rect.Min.Y
		if rect.Height > 0 then
			height = rect.Height
		end
	else
		top = GuiService:GetGuiInset().Y
	end
	if height < ICON then
		top = math.max(0, top - math.floor((ICON - height) / 2))
	end
	return left, top, height
end

local function layoutHost()
	local screen = host
	if not screen then
		return
	end
	local leftPad, top, _height = readInset()
	local left = screen:FindFirstChild("Left")
	local mid = screen:FindFirstChild("Mid")
	local right = screen:FindFirstChild("Right")
	if left and left:IsA("Frame") then
		left.Position = UDim2.fromOffset(leftPad, top)
		left.Size = UDim2.new(0.4, 0, 0, ICON)
	end
	if mid and mid:IsA("Frame") then
		mid.AnchorPoint = Vector2.new(0.5, 0)
		mid.Position = UDim2.new(0.5, 0, 0, top)
		mid.Size = UDim2.new(0.4, 0, 0, ICON)
	end
	if right and right:IsA("Frame") then
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(1, -leftPad, 0, top)
		right.Size = UDim2.new(0.4, 0, 0, ICON)
	end
end

local function watchInset()
	if insetConn then
		return
	end
	pcall(function()
		insetConn = (GuiService :: any):GetPropertyChangedSignal("TopbarInset"):Connect(layoutHost)
	end)
	local camera = Workspace.CurrentCamera
	if camera and not viewportConn then
		viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutHost)
	end
end

local function makeStrip(name: string, align: Enum.HorizontalAlignment): Frame
	local list = Instance.new("Frame")
	list.Name = name
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(0.4, 0, 0, ICON)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = align
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

local function ensureHost(): ScreenGui?
	if not isClient() then
		return nil
	end
	if host and host.Parent then
		return host
	end
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		gui = player:WaitForChild("PlayerGui", 8) :: PlayerGui?
	end
	if not gui then
		return nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "Crest"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 1000
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = gui
	makeStrip("Left", Enum.HorizontalAlignment.Left).Parent = screen
	makeStrip("Mid", Enum.HorizontalAlignment.Center).Parent = screen
	makeStrip("Right", Enum.HorizontalAlignment.Right).Parent = screen
	host = screen
	layoutHost()
	watchInset()
	return screen
end

local function fire(self: Crest, eventName: string, ...: any)
	local list = self._events[eventName]
	if not list then
		return
	end
	for _, callback in list do
		callback(...)
	end
end

function Crest.new(): Crest
	orderCounter += 1
	local screen = ensureHost()
	local button = Instance.new("ImageButton")
	button.Name = "CrestIcon"
	button.Size = UDim2.fromOffset(ICON, ICON)
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	button.AutoButtonColor = false
	button.LayoutOrder = orderCounter
	button.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Selection"
	stroke.Color = Color3.fromRGB(80, 140, 255)
	stroke.Thickness = 0
	stroke.Parent = button
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = ""
	label.ZIndex = 2
	label.Parent = button
	local notice = Instance.new("Frame")
	notice.Name = "Notice"
	notice.Size = UDim2.fromOffset(10, 10)
	notice.Position = UDim2.new(1, -8, 0, -2)
	notice.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	notice.Visible = false
	notice.ZIndex = 3
	notice.Parent = button
	local noticeCorner = Instance.new("UICorner")
	noticeCorner.CornerRadius = UDim.new(1, 0)
	noticeCorner.Parent = notice
	if screen then
		button.Parent = screen:FindFirstChild("Left")
	end
	local icon = setmetatable({
		_button = button,
		_label = label,
		_notice = notice,
		_selected = false,
		_items = {} :: { GuiObject },
		_events = {} :: { [string]: { (...any) -> () } },
		_autoDeselect = true,
		_idleColor = Color3.fromRGB(20, 20, 24),
		_activeColor = Color3.fromRGB(40, 90, 180),
		_alive = true,
	}, Crest)
	table.insert(icons, icon)
	button.Activated:Connect(function()
		if not icon._alive then
			return
		end
		if icon._selected then
			icon:deselect()
		else
			icon:select()
		end
		fire(icon, "toggled", icon._selected)
		fire(icon, "Activated")
	end)
	button.MouseEnter:Connect(function()
		fire(icon, "hoverStarted")
	end)
	button.MouseLeave:Connect(function()
		fire(icon, "hoverEnded")
	end)
	return icon
end

function Crest:setName(name: string)
	self._button.Name = name
	return self
end

function Crest:setLabel(text: string)
	self._label.Text = text
	return self
end

function Crest:setImage(image: string)
	self._button.Image = image
	return self
end

function Crest:setEnabled(enabled: boolean)
	self._button.Visible = enabled
	self._button.Active = enabled
	return self
end

function Crest:setOrder(order: number)
	self._button.LayoutOrder = order
	return self
end

function Crest:setWidth(offset: number)
	self._button.Size = UDim2.fromOffset(offset, ICON)
	return self
end

function Crest:align(side: string)
	local screen = host or ensureHost()
	if not screen then
		return self
	end
	local bucket = "Left"
	local lower = string.lower(side)
	if lower == "mid" or lower == "center" or lower == "middle" then
		bucket = "Mid"
	elseif lower == "right" then
		bucket = "Right"
	end
	local frame = screen:FindFirstChild(bucket)
	if frame then
		self._button.Parent = frame
	end
	return self
end

function Crest:setLeft()
	return self:align("left")
end

function Crest:setMid()
	return self:align("mid")
end

function Crest:setRight()
	return self:align("right")
end

function Crest:bindEvent(eventName: string, callback: (...any) -> ())
	local list = self._events[eventName]
	if not list then
		list = {}
		self._events[eventName] = list
	end
	table.insert(list, callback)
	return self
end

function Crest:bindToggleItem(gui: GuiObject)
	table.insert(self._items, gui)
	gui.Visible = self._selected
	return self
end

function Crest:modifyTheme(modifications: any)
	if typeof(modifications) == "table" then
		if modifications.background or modifications.Background then
			self._idleColor = modifications.background or modifications.Background
			if not self._selected then
				self._button.BackgroundColor3 = self._idleColor
			end
		end
		if modifications.selected or modifications.Selected then
			self._activeColor = modifications.selected or modifications.Selected
			if self._selected then
				self._button.BackgroundColor3 = self._activeColor
			end
		end
	end
	return self
end

function Crest:setTheme(theme: any)
	return self:modifyTheme(theme)
end

function Crest:notify()
	self._notice.Visible = true
	fire(self, "notified")
	return self
end

function Crest:clearNotices()
	self._notice.Visible = false
	return self
end

function Crest:select()
	if self._selected then
		return self
	end
	if self._autoDeselect then
		for _, other in icons do
			if other ~= self and other._autoDeselect and other._selected then
				other:deselect()
			end
		end
	end
	self._selected = true
	self._button.BackgroundColor3 = self._activeColor
	local stroke = self._button:FindFirstChild("Selection")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Thickness = 1.5
	end
	for _, gui in self._items do
		gui.Visible = true
	end
	fire(self, "selected")
	fire(self, "viewOpened")
	return self
end

function Crest:deselect()
	if not self._selected then
		return self
	end
	self._selected = false
	self._button.BackgroundColor3 = self._idleColor
	local stroke = self._button:FindFirstChild("Selection")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Thickness = 0
	end
	for _, gui in self._items do
		gui.Visible = false
	end
	fire(self, "deselected")
	fire(self, "viewClosed")
	return self
end

function Crest:autoDeselect(enabled: boolean)
	self._autoDeselect = enabled
	return self
end

function Crest:Destroy()
	self._alive = false
	for index, icon in icons do
		if icon == self then
			table.remove(icons, index)
			break
		end
	end
	self._button:Destroy()
end

Crest.new_ = Crest.new
Crest.SetLabel = Crest.setLabel
Crest.SetImage = Crest.setImage
Crest.SetEnabled = Crest.setEnabled
Crest.SetName = Crest.setName
Crest.SetOrder = Crest.setOrder
Crest.Notify = Crest.notify
Crest.Select = Crest.select
Crest.Deselect = Crest.deselect
Crest.Align = Crest.align
Crest.BindEvent = Crest.bindEvent
Crest.BindToggleItem = Crest.bindToggleItem
Crest.ClearNotices = Crest.clearNotices

pcall(function()
	if RunService:IsClient() then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end
end)

return Crest
