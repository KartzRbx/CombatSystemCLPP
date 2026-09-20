--!optimize 2
--!strict
-- Lens — debug UI. Window is a scope; there is no End().

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

export type Lens = {
	Init: () -> (),
	Window: (title: string, draw: () -> ()) -> (),
	Text: (text: string) -> (),
	Button: (label: string, onClick: (() -> ())?) -> boolean,
	Checkbox: (label: string, value: boolean?) -> boolean,
	Slider: (label: string, value: number, minOrMax: number?, maybeMax: number?) -> number,
	Tree: (label: string, draw: (() -> ())?) -> boolean,
	Table: (title: string, rows: { { any } }?) -> (),
	Plot: (label: string, values: { number }) -> (),
	Search: (query: string) -> (),
	Copy: (value: any) -> (),
	Value: (label: string, value: any) -> (),
}

local Lens = {} :: any

if RunService:IsServer() then
	function Lens.Window(_title: string, draw: () -> ())
		draw()
	end
	function Lens.Text(_text: string) end
	function Lens.Button(_label: string, _onClick: (() -> ())?): boolean
		return false
	end
	function Lens.Checkbox(_label: string, value: boolean?): boolean
		return value == true
	end
	function Lens.Slider(_label: string, value: number, _a: number?, _b: number?): number
		return value
	end
	function Lens.Tree(_label: string, draw: (() -> ())?): boolean
		if draw then
			draw()
		end
		return true
	end
	function Lens.Table(_title: string, _rows: { { any } }?) end
	function Lens.Plot(_label: string, _values: { number }) end
	function Lens.Search(_query: string) end
	function Lens.Copy(_value: any) end
	function Lens.Value(_label: string, _value: any) end
	function Lens.Init() end
	return Lens :: Lens
end

local Trace = require(script.Parent.Trace)

type WindowState = {
	frame: Frame,
	header: TextButton,
	searchBox: TextBox,
	body: ScrollingFrame,
	title: string,
}

type WidgetState = {
	checked: { [string]: boolean },
	slider: { [string]: number },
	tree: { [string]: boolean },
	clicked: { [string]: boolean },
}

local host: ScreenGui? = nil
local windows: { [string]: WindowState } = {}
local widgetState: { [string]: WidgetState } = {}
local searchQuery = ""
local copyBuffer = ""
local parentStack: { GuiObject } = {}
local activeTitle: string? = nil
local dragging: {
	frame: Frame,
	origin: Vector2,
	start: Vector2,
}? = nil

local BG = Color3.fromRGB(18, 18, 22)
local HEADER = Color3.fromRGB(32, 32, 40)
local ROW = Color3.fromRGB(40, 40, 52)
local ACCENT = Color3.fromRGB(40, 90, 180)
local TEXT = Color3.fromRGB(230, 230, 235)
local MUTED = Color3.fromRGB(160, 160, 170)

local function localPlayer(): Player?
	return Players.LocalPlayer
end

local function ensure(): ScreenGui?
	if host and host.Parent then
		return host
	end
	local player = localPlayer()
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
	screen.Name = "Lens"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 1200
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = gui
	host = screen
	return screen
end

local function currentParent(): GuiObject?
	return parentStack[#parentStack]
end

local function stateFor(title: string): WidgetState
	local stored = widgetState[title]
	if stored then
		return stored
	end
	stored = {
		checked = {},
		slider = {},
		tree = {},
		clicked = {},
	}
	widgetState[title] = stored
	return stored
end

local function matchesSearch(text: string): boolean
	if searchQuery == "" then
		return true
	end
	return string.find(string.lower(text), string.lower(searchQuery), 1, true) ~= nil
end

local function tag(object: GuiObject, text: string)
	object:SetAttribute("LensText", text)
	object.Visible = matchesSearch(text)
end

local function applyFilter(root: Instance)
	for _, child in root:GetDescendants() do
		if child:IsA("GuiObject") then
			local text = child:GetAttribute("LensText")
			if typeof(text) == "string" then
				child.Visible = matchesSearch(text)
			end
		end
	end
end

local function styleText(label: TextLabel | TextButton | TextBox)
	label.TextColor3 = TEXT
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
end

local function clearBody(body: ScrollingFrame)
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function bindDrag(header: TextButton, frame: Frame)
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = {
				frame = frame,
				origin = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset),
				start = UserInputService:GetMouseLocation(),
			}
		end
	end)
end

UserInputService.InputChanged:Connect(function(input)
	local drag = dragging
	if not drag then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local delta = mouse - drag.start
	local x = math.max(0, drag.origin.X + delta.X)
	local y = math.max(0, drag.origin.Y + delta.Y)
	drag.frame.Position = UDim2.fromOffset(x, y)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = nil
	end
end)

local function makeWindow(screen: ScreenGui, title: string): WindowState
	local index = 0
	for _ in windows do
		index += 1
	end
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.Size = UDim2.fromOffset(300, 280)
	frame.Position = UDim2.fromOffset(16 + 24 * index, 72 + 18 * index)
	frame.BackgroundColor3 = BG
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 72)
	stroke.Thickness = 1
	stroke.Parent = frame

	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundColor3 = HEADER
	header.BorderSizePixel = 0
	header.AutoButtonColor = false
	header.Text = title
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.Parent = frame
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(22, 22)
	close.Position = UDim2.new(1, -26, 0, 3)
	close.BackgroundColor3 = Color3.fromRGB(70, 40, 44)
	close.Text = "x"
	close.TextColor3 = TEXT
	close.Font = Enum.Font.GothamBold
	close.TextSize = 12
	close.AutoButtonColor = true
	close.Parent = header
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = close
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "Search"
	searchBox.Size = UDim2.new(1, -12, 0, 22)
	searchBox.Position = UDim2.fromOffset(6, 30)
	searchBox.BackgroundColor3 = ROW
	searchBox.PlaceholderText = "search"
	searchBox.PlaceholderColor3 = MUTED
	searchBox.Text = searchQuery
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = frame
	styleText(searchBox)
	searchBox.BackgroundTransparency = 0
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 4)
	searchCorner.Parent = searchBox
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchQuery = searchBox.Text
		local body = frame:FindFirstChild("Body")
		if body then
			applyFilter(body)
		end
	end)

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -56)
	body.Position = UDim2.fromOffset(0, 56)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	bindDrag(header, frame)

	return {
		frame = frame,
		header = header,
		searchBox = searchBox,
		body = body,
		title = title,
	}
end

function Lens.Window(title: string, draw: () -> ())
	local screen = ensure()
	if not screen then
		return
	end
	local existing = windows[title]
	if not existing or existing.frame.Parent == nil then
		existing = makeWindow(screen, title)
		windows[title] = existing
	end
	existing.frame.Visible = true
	existing.searchBox.Text = searchQuery
	clearBody(existing.body)
	activeTitle = title
	table.clear(parentStack)
	table.insert(parentStack, existing.body)
	local ok, err = pcall(draw)
	table.clear(parentStack)
	activeTitle = nil
	applyFilter(existing.body)
	if not ok then
		warn("[Lens]", err)
	end
end

function Lens.Text(text: string)
	local parent = currentParent()
	if not parent then
		return
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Text = text
	styleText(label)
	label.Parent = parent
	tag(label, text)
end

function Lens.Button(label: string, onClick: (() -> ())?): boolean
	local parent = currentParent()
	if not parent or not activeTitle then
		return false
	end
	local store = stateFor(activeTitle)
	local clicked = store.clicked[label] == true
	store.clicked[label] = false
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 24)
	button.BackgroundColor3 = ROW
	button.AutoButtonColor = true
	button.Text = label
	styleText(button)
	button.BackgroundTransparency = 0
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	button.Activated:Connect(function()
		store.clicked[label] = true
		if onClick then
			onClick()
		end
	end)
	tag(button, label)
	return clicked
end

function Lens.Checkbox(label: string, value: boolean?): boolean
	local parent = currentParent()
	if not parent or not activeTitle then
		return value == true
	end
	local store = stateFor(activeTitle)
	if store.checked[label] == nil then
		store.checked[label] = value == true
	end
	local checked = store.checked[label]
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 20)
	button.AutoButtonColor = false
	button.Text = `{if checked then "[x]" else "[ ]"} {label}`
	styleText(button)
	button.Parent = parent
	button.Activated:Connect(function()
		store.checked[label] = not store.checked[label]
		button.Text = `{if store.checked[label] then "[x]" else "[ ]"} {label}`
	end)
	tag(button, label)
	return checked
end

function Lens.Slider(label: string, value: number, minOrMax: number?, maybeMax: number?): number
	local parent = currentParent()
	local minValue = 0
	local maxValue = 1
	if maybeMax ~= nil and minOrMax ~= nil then
		minValue = minOrMax
		maxValue = maybeMax
	elseif minOrMax ~= nil then
		maxValue = minOrMax
	end
	if maxValue == minValue then
		maxValue = minValue + 1
	end
	if not parent or not activeTitle then
		return math.clamp(value, minValue, maxValue)
	end
	local store = stateFor(activeTitle)
	if store.slider[label] == nil then
		store.slider[label] = math.clamp(value, minValue, maxValue)
	end
	local current = store.slider[label]

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundTransparency = 1
	row.Parent = parent
	tag(row, label)

	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, 0, 0, 16)
	caption.Text = `{label}: {string.format("%.2f", current)}`
	styleText(caption)
	caption.Parent = row

	local bar = Instance.new("TextButton")
	bar.Name = "Track"
	bar.Size = UDim2.new(1, 0, 0, 10)
	bar.Position = UDim2.fromOffset(0, 20)
	bar.BackgroundColor3 = ROW
	bar.AutoButtonColor = false
	bar.Text = ""
	bar.Parent = row
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(math.clamp((current - minValue) / (maxValue - minValue), 0, 1), 0, 1, 0)
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local function apply(alpha: number)
		local nextValue = minValue + (maxValue - minValue) * math.clamp(alpha, 0, 1)
		store.slider[label] = nextValue
		fill.Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)
		caption.Text = `{label}: {string.format("%.2f", nextValue)}`
	end

	local sliding = false
	local function fromInput(input: InputObject)
		local width = math.max(bar.AbsoluteSize.X, 1)
		apply((input.Position.X - bar.AbsolutePosition.X) / width)
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			fromInput(input)
		end
	end)
	bar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)
	local slideConn = UserInputService.InputChanged:Connect(function(input)
		if not sliding or bar.Parent == nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			fromInput(input)
		end
	end)
	bar.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			slideConn:Disconnect()
			sliding = false
		end
	end)

	return current
end

function Lens.Tree(label: string, draw: (() -> ())?): boolean
	local parent = currentParent()
	if not parent or not activeTitle then
		if draw then
			draw()
		end
		return true
	end
	local store = stateFor(activeTitle)
	if store.tree[label] == nil then
		store.tree[label] = true
	end
	local open = store.tree[label]

	local header = Instance.new("TextButton")
	header.Size = UDim2.new(1, 0, 0, 20)
	header.AutoButtonColor = false
	header.Text = `{if open then "v" else ">"} {label}`
	styleText(header)
	header.Parent = parent
	tag(header, label)

	local body = Instance.new("Frame")
	body.Name = label
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Visible = open
	body.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	header.Activated:Connect(function()
		store.tree[label] = not store.tree[label]
		local now = store.tree[label]
		body.Visible = now
		header.Text = `{if now then "v" else ">"} {label}`
	end)

	if draw then
		table.insert(parentStack, body)
		draw()
		table.remove(parentStack)
	end

	return open
end

function Lens.Table(title: string, rows: { { any } }?)
	Lens.Text(title)
	if rows then
		for _, item in rows do
			Lens.Text(Trace.display(item))
		end
	end
end

function Lens.Plot(label: string, values: { number })
	local max = 1
	for _, value in values do
		if value > max then
			max = value
		end
	end
	local bars = {}
	for _, value in values do
		table.insert(bars, if value / max > 0.66 then "|" elseif value / max > 0.33 then ":" else ".")
	end
	Lens.Text(`{label} {table.concat(bars)}`)
end

function Lens.Search(query: string)
	searchQuery = query
	for _, window in windows do
		window.searchBox.Text = query
		applyFilter(window.body)
	end
end

function Lens.Copy(value: any)
	copyBuffer = Trace.display(value)
end

function Lens.Value(label: string, value: any)
	Lens.Text(`{label}: {Trace.display(value)}`)
end

function Lens.Init()
	ensure()
end

return Lens :: Lens
