--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Bloom = require(ReplicatedStorage.CluauppLibs.Bloom)
const Gleam = require(ReplicatedStorage.CluauppLibs.Gleam)
const Janitor = require(ReplicatedStorage.CluauppLibs.Sweep)
const Keep = require(ReplicatedStorage.CluauppLibs.Keep)
const Mint = require(ReplicatedStorage.CluauppLibs.Mint)
const Net = require(ReplicatedStorage.Shared.Net.Net)

local ClickHud = {}
ClickHud.players = game:GetService("Players")
ClickHud.me = nil
ClickHud.Session = nil
ClickHud.PointsSource = nil
ClickHud.HudGui = nil
ClickHud.PointsLabel = nil
ClickHud.ClickButton = nil
ClickHud.HUD_NAME = "ClickHud"
ClickHud.BUTTON_TEXT = "CLICK"
ClickHud.POPUP_TEXT = "+1"
ClickHud.POPUP_LIFE = 0.45
ClickHud.POPUP_START_OFFSET = -108
ClickHud.BAR_HEIGHT = 96
ClickHud.BAR_BOTTOM = -18
ClickHud.BUTTON_HEIGHT = 52
ClickHud.BUTTON_COLOR_R = 0.92
ClickHud.BUTTON_COLOR_G = 0.22
ClickHud.BUTTON_COLOR_B = 0.28
ClickHud.BAR_COLOR_R = 0.08
ClickHud.BAR_COLOR_G = 0.08
ClickHud.BAR_COLOR_B = 0.12

-- ClickHud.client.clpp:10
function ClickHud:RefreshPointsLabel(): boolean
	if not (self and self.PointsLabel and self.PointsSource) then
		return false
	end

	self.PointsLabel.Text = Mint.Compact(self.PointsSource:Get())
	return true
end

-- ClickHud.client.clpp:19
function ClickHud:OnPointsReplicated(points: number): boolean
	if not (self and self.PointsSource) then
		return false
	end

	self.PointsSource:Set(points)
	self:RefreshPointsLabel()
	return true
end

-- ClickHud.client.clpp:29
function ClickHud:OnClickAck(points: number, damage: number): boolean
	if not (self and self.PointsSource and damage >= 0) then
		return false
	end

	self.PointsSource:Set(points)
	self:RefreshPointsLabel()
	return true
end

-- ClickHud.client.clpp:39
function ClickHud:CreatePopupLabel(): TextLabel
	local popup: TextLabel = Gleam.TextLabel({ Name = "ClickPopup", Text = self.POPUP_TEXT, TextScaled = true, BackgroundTransparency = 1, Size = UDim2.new(0, 88, 0, 40), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, self.POPUP_START_OFFSET), TextColor3 = Color3.new(1, 0.92, 0.28), ZIndex = 8 })
	return popup
end

-- ClickHud.client.clpp:54
function ClickHud:EmitClickPopup(): boolean
	if not (self and self.HudGui) then
		return false
	end

	local popup: TextLabel = self:CreatePopupLabel()
	Gleam.Mount(popup, self.HudGui)
	Bloom.Bounce(popup)
	task.spawn(function()
		task.wait(self.POPUP_LIFE)
		popup:Destroy()
	end)

	return true
end

-- ClickHud.client.clpp:69
function ClickHud:OnClickPressed(): boolean
	if not (self and self.me and self.ClickButton) then
		return false
	end

	Bloom.Press(self.ClickButton, Bloom.Punch)
	Bloom.Ripple(self.ClickButton)
	self:EmitClickPopup()
	Net.ClickIntent:FireServer()
	return true
end

-- ClickHud.client.clpp:81
function ClickHud:BindClickButton(): boolean
	if not (self and self.ClickButton) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(self.ClickButton.MouseButton1Click:Connect(function()
		self:OnClickPressed()
	end), "Disconnect")

	return true
end

-- ClickHud.client.clpp:92
function ClickHud:BindClickAck(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(Net.ClickAck:Connect(function(points: number, damage: number)
		self:OnClickAck(points, damage)
	end), "Disconnect")

	return true
end

-- ClickHud.client.clpp:103
function ClickHud:BindPointsReplication(): boolean
	if not (self and self.Session) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(self.Session:GetChangedSignal(Keep.Client.Paths.Currencies.Points):Connect(function(points: number)
		self:OnPointsReplicated(points)
	end), "Disconnect")

	return true
end

-- ClickHud.client.clpp:114
function ClickHud:BuildHud(): boolean
	if not (self and self.me and self.me.PlayerGui) then
		return false
	end

	self.HudGui = Gleam.ScreenGui({ Name = self.HUD_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 })
	local bar: Frame = Gleam.Frame({ Name = "ClickBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, self.BAR_BOTTOM), Size = UDim2.new(0.4, 0, 0, self.BAR_HEIGHT), BackgroundColor3 = Color3.new(self.BAR_COLOR_R, self.BAR_COLOR_G, self.BAR_COLOR_B), BorderSizePixel = 0 })
	self.PointsLabel = Gleam.TextLabel({ Name = "Points", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.9, 0, 0, 28), TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "0" })
	self.ClickButton = Gleam.TextButton({ Name = "ClickButton", Text = self.BUTTON_TEXT, TextScaled = true, AutoButtonColor = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.86, 0, 0, self.BUTTON_HEIGHT), BackgroundColor3 = Color3.new(self.BUTTON_COLOR_R, self.BUTTON_COLOR_G, self.BUTTON_COLOR_B), TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	Gleam.Mount(self.HudGui, self.me.PlayerGui)
	Gleam.Mount(bar, self.HudGui)
	Gleam.Mount(self.PointsLabel, bar)
	Gleam.Mount(self.ClickButton, bar)
	Bloom.Hover(self.ClickButton, Bloom.Lift)
	self:RefreshPointsLabel()
	return true
end

-- ClickHud.client.clpp:168
function ClickHud:BindKeep(): boolean
	if not (self) then
		return false
	end

	if self.Session then
		return true
	end

	self.Session = Keep.Client:Init()

	if not (self.Session) then
		return false
	end

	local points: number = self.Session:Get(Keep.Client.Paths.Currencies.Points)
	self.PointsSource = Gleam.Source(points)
	return true
end

-- ClickHud.client.clpp:187
function ClickHud:OnCharacterSpawned(character: Model): boolean
	if not (self and self.me and character) then
		return false
	end

	if self.HudGui and self.HudGui.Parent then
		return true
	end

	if not self.Session then
		return self:SetupClickHud()
	end

	self.HudGui = nil
	self.PointsLabel = nil
	self.ClickButton = nil

	if not (self:BuildHud()) then
		return false
	end

	self:BindClickButton()
	return true
end

-- ClickHud.client.clpp:210
function ClickHud:BindCharacter(): boolean
	if not (self and self.me) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(self.me.CharacterAdded:Connect(function(character: Model)
		self:OnCharacterSpawned(character)
	end), "Disconnect")

	if self.me.Character then
		self:OnCharacterSpawned(self.me.Character)
	end

	return true
end

-- ClickHud.client.clpp:224
function ClickHud:SetupClickHud(): boolean
	if not (self and self.me) then
		return false
	end

	if not (self:BindKeep()) then
		return false
	end

	if not (self:BuildHud()) then
		return false
	end

	self:BindClickButton()
	self:BindClickAck()
	self:BindPointsReplication()
	return true
end

-- ClickHud.client.clpp:241
const function init()
	local hud = ClickHud
	hud.me = hud.players.LocalPlayer
	hud:BindCharacter()
end

init()
