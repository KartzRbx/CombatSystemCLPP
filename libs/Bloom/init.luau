--!native
--!optimize 2
--!strict
-- Bloom — GUI manager + effects. ColorSequence paths are kept. One Heartbeat.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Bloom = {}
Bloom.__index = Bloom

Bloom.Shine = "Shine"
Bloom.Rainbow = "Rainbow"
Bloom.ChromeStroke = "ChromeStroke"
Bloom.Grow = "Grow"
Bloom.Lift = "Lift"
Bloom.Bounce = "Bounce"
Bloom.Shrink = "Shrink"
Bloom.Punch = "Punch"

export type Options = {
	Speed: number?,
	Size: number?,
	Gradient: ColorSequence | Color3 | UIGradient?,
	Transparency: NumberSequence | number?,
}

export type BloomHandle = typeof(setmetatable(
	{} :: {
		Instance: GuiObject,
		Pause: (self: any) -> (),
		Resume: (self: any) -> (),
		Destroy: (self: any) -> (),
	},
	Bloom
))

local active: { any } = {}
local stepped: RBXScriptConnection? = nil

local function asSequence(color: ColorSequence | Color3 | UIGradient?): ColorSequence
	if color == nil then
		return ColorSequence.new(Color3.new(1, 1, 1))
	end
	if typeof(color) == "ColorSequence" then
		return color
	end
	if typeof(color) == "Color3" then
		return ColorSequence.new(color)
	end
	if typeof(color) == "Instance" and color:IsA("UIGradient") then
		return color.Color
	end
	return ColorSequence.new(Color3.new(1, 1, 1))
end

local function ensureStepped()
	if stepped then
		return
	end
	stepped = RunService.Heartbeat:Connect(function(dt)
		for _, job in active do
			if job.Paused or not job.Tick then
				continue
			end
			job:Tick(dt)
		end
	end)
end

local function visible(object: Instance): boolean
	if object.Parent == nil then
		return false
	end
	local current: Instance? = object
	while current and current ~= game do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if (current:IsA("LayerCollector")) and (current :: LayerCollector).Enabled == false then
			return false
		end
		current = current.Parent
	end
	return true
end

local MOTION: { [string]: { Peak: number, Lift: number, Bounce: boolean } } = {
	Grow = { Peak = 1.08, Lift = 0, Bounce = false },
	Lift = { Peak = 1.04, Lift = 8, Bounce = false },
	Bounce = { Peak = 1.06, Lift = 0, Bounce = true },
	Shrink = { Peak = 0.96, Lift = 0, Bounce = false },
	Punch = { Peak = 0.92, Lift = 0, Bounce = true },
}

local CHROME = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 172, 186)),
	ColorSequenceKeypoint.new(0.22, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(148, 156, 176)),
	ColorSequenceKeypoint.new(0.78, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 172, 186)),
})

local function scaleSize(original: UDim2, scale: number): UDim2
	return UDim2.new(original.X.Scale * scale, original.X.Offset * scale, original.Y.Scale * scale, original.Y.Offset * scale)
end

local function bindHandle(job: any): BloomHandle
	table.insert(active, job)
	ensureStepped()
	return setmetatable(job, Bloom)
end

function Bloom.Stop(t: number, color: Color3): ColorSequenceKeypoint
	return ColorSequenceKeypoint.new(t, color)
end

function Bloom.Gradient(...: ColorSequenceKeypoint): ColorSequence
	return ColorSequence.new({ ... })
end

function Bloom.Play(target: GuiObject, preset: string, options: Options?): BloomHandle
	local opts = options or {}
	local motion = MOTION[preset]
	if motion then
		local original = target.Size
		local originPos = target.Position
		local speed = opts.Speed or if motion.Bounce then 1.6 else 1.1
		local peak = motion.Peak
		local lift = motion.Lift
		local job
		job = {
			Instance = target,
			Paused = false,
			Offset = 0,
			Tick = function(self, dt: number)
				if not visible(target) then
					return
				end
				self.Offset += dt * speed
				local wave = math.sin(self.Offset * math.pi * 2)
				if motion.Bounce then
					wave = math.abs(wave)
				else
					wave = (wave + 1) * 0.5
				end
				target.Size = scaleSize(original, 1 + (peak - 1) * wave)
				if lift ~= 0 then
					target.Position = originPos - UDim2.fromOffset(0, lift * wave)
				end
			end,
			Pause = function(self)
				self.Paused = true
			end,
			Resume = function(self)
				self.Paused = false
			end,
			Destroy = function(self)
				if self._dead then
					return
				end
				self._dead = true
				self.Paused = true
				self.Tick = nil
				if target.Parent then
					target.Size = original
					target.Position = originPos
				end
				local index = table.find(active, self)
				if index then
					table.remove(active, index)
				end
			end,
		}
		target.Destroying:Once(function()
			job:Destroy()
		end)
		return bindHandle(job)
	end
	local sequence = asSequence(opts.Gradient)
	if preset == Bloom.Rainbow and opts.Gradient == nil then
		sequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 127, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 127, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(139, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		})
	elseif preset == Bloom.ChromeStroke and opts.Gradient == nil then
		sequence = CHROME
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = sequence
	if typeof(opts.Transparency) == "NumberSequence" then
		gradient.Transparency = opts.Transparency
	elseif typeof(opts.Transparency) == "number" then
		gradient.Transparency = NumberSequence.new(opts.Transparency)
	end
	if typeof(opts.Gradient) == "Instance" and (opts.Gradient :: UIGradient):IsA("UIGradient") then
		gradient.Transparency = (opts.Gradient :: UIGradient).Transparency
		gradient.Rotation = (opts.Gradient :: UIGradient).Rotation
	end
	gradient.Parent = target
	local stroke: UIStroke? = nil
	if string.find(preset, "Stroke", 1, true) then
		stroke = Instance.new("UIStroke")
		stroke.Thickness = opts.Size or 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = target
		gradient.Parent = stroke
	end
	local speed = opts.Speed or 0.4
	local job
	job = {
		Instance = target,
		Paused = false,
		Offset = 0,
		Tick = function(self, dt: number)
			if not visible(target) then
				return
			end
			self.Offset = (self.Offset + dt * speed) % 2
			gradient.Offset = Vector2.new(self.Offset - 1, 0)
		end,
		Pause = function(self)
			self.Paused = true
		end,
		Resume = function(self)
			self.Paused = false
		end,
		Destroy = function(self)
			if self._dead then
				return
			end
			self._dead = true
			self.Paused = true
			self.Tick = nil
			gradient:Destroy()
			if stroke then
				stroke:Destroy()
			end
			local index = table.find(active, self)
			if index then
				table.remove(active, index)
			end
		end,
	}
	target.Destroying:Once(function()
		job:Destroy()
	end)
	return bindHandle(job)
end

function Bloom.Fade(element: GuiObject, show: boolean, speed: number?)
	element.Visible = true
	local tween = game:GetService("TweenService"):Create(element, TweenInfo.new(speed or 0.25), {
		BackgroundTransparency = if show then 0 else 1,
	})
	tween:Play()
	if not show then
		task.delay(speed or 0.25, function()
			element.Visible = false
		end)
	end
end

function Bloom.Slide(element: GuiObject, show: boolean, speed: number?)
	Bloom.Fade(element, show, speed)
end

function Bloom.Zoom(element: GuiObject, show: boolean, speed: number?)
	local original = element.Size
	if show then
		element.Visible = true
		element.Size = UDim2.new(original.X.Scale * 0.9, original.X.Offset, original.Y.Scale * 0.9, original.Y.Offset)
		game:GetService("TweenService"):Create(element, TweenInfo.new(speed or 0.25), { Size = original }):Play()
	else
		game:GetService("TweenService")
			:Create(element, TweenInfo.new(speed or 0.25), {
				Size = UDim2.new(original.X.Scale * 0.9, original.X.Offset, original.Y.Scale * 0.9, original.Y.Offset),
			})
			:Play()
	end
end

function Bloom.Bounce(element: GuiObject, speed: number?)
	local original = element.Size
	local up = UDim2.new(original.X.Scale * 1.06, original.X.Offset, original.Y.Scale * 1.06, original.Y.Offset)
	local tween = game:GetService("TweenService"):Create(element, TweenInfo.new(speed or 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = up })
	tween:Play()
	tween.Completed:Once(function()
		game:GetService("TweenService"):Create(element, TweenInfo.new(speed or 0.12), { Size = original }):Play()
	end)
end

function Bloom.Hover(element: GuiObject, kind: string?)
	local original = element.Size
	element.MouseEnter:Connect(function()
		local scale = if kind == Bloom.Lift then 1.04 else 1.08
		game:GetService("TweenService"):Create(element, TweenInfo.new(0.12), {
			Size = UDim2.new(original.X.Scale * scale, original.X.Offset, original.Y.Scale * scale, original.Y.Offset),
		}):Play()
	end)
	element.MouseLeave:Connect(function()
		game:GetService("TweenService"):Create(element, TweenInfo.new(0.12), { Size = original }):Play()
	end)
end

function Bloom.Press(element: GuiObject, kind: string?)
	if not element:IsA("GuiButton") then
		return
	end
	local original = element.Size
	element.MouseButton1Down:Connect(function()
		local scale = if kind == Bloom.Punch then 0.92 else 0.96
		game:GetService("TweenService"):Create(element, TweenInfo.new(0.08), {
			Size = UDim2.new(original.X.Scale * scale, original.X.Offset, original.Y.Scale * scale, original.Y.Offset),
		}):Play()
	end)
	element.MouseButton1Up:Connect(function()
		game:GetService("TweenService"):Create(element, TweenInfo.new(0.08), { Size = original }):Play()
	end)
end

function Bloom.Ripple(element: GuiObject)
	if not element:IsA("GuiButton") then
		return
	end
	element.MouseButton1Click:Connect(function()
		local ripple = Instance.new("Frame")
		ripple.BackgroundTransparency = 0.6
		ripple.BackgroundColor3 = Color3.new(1, 1, 1)
		ripple.Size = UDim2.fromOffset(8, 8)
		ripple.AnchorPoint = Vector2.new(0.5, 0.5)
		ripple.Position = UDim2.fromScale(0.5, 0.5)
		ripple.Parent = element
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ripple
		game:GetService("TweenService")
			:Create(ripple, TweenInfo.new(0.35), { Size = UDim2.fromScale(1.4, 1.4), BackgroundTransparency = 1 })
			:Play()
		task.delay(0.35, function()
			ripple:Destroy()
		end)
	end)
end

function Bloom.Tilt(element: GuiObject, degrees: number?)
	local max = degrees or 8
	local connection = RunService.RenderStepped:Connect(function()
		if not visible(element) then
			return
		end
		local player = Players.LocalPlayer
		local mouse = player and player:GetMouse()
		if not mouse then
			return
		end
		local pos = element.AbsolutePosition
		local size = element.AbsoluteSize
		local cx = pos.X + size.X / 2
		local cy = pos.Y + size.Y / 2
		local dx = ((mouse.X - cx) / math.max(size.X, 1)) * max
		local dy = ((mouse.Y - cy) / math.max(size.Y, 1)) * max
		element.Rotation = math.clamp(dx * 0.15, -max, max)
		local gradient = element:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Rotation = 45 + dy
		end
	end)
	return connection
end

function Bloom.Depth(element: GuiObject)
	Bloom.Hover(element, Bloom.Lift)
	local shadow = Instance.new("UIStroke")
	shadow.Thickness = 2
	shadow.Transparency = 0.6
	shadow.Parent = element
end

function Bloom.Flip(element: GuiObject, speed: number?)
	local original = element.Size
	local tween = game:GetService("TweenService"):Create(element, TweenInfo.new((speed or 0.2) / 2), {
		Size = UDim2.new(0, 0, original.Y.Scale, original.Y.Offset),
	})
	tween:Play()
	tween.Completed:Once(function()
		game:GetService("TweenService"):Create(element, TweenInfo.new((speed or 0.2) / 2), { Size = original }):Play()
	end)
end

function Bloom.Viewport(frame: GuiObject, model: Instance)
	local Stage = require(script.Parent.Stage)
	return Stage.Attach(frame, model)
end

function Bloom.Type(container: Frame, label: TextLabel, text: string)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	task.spawn(function()
		for i = 1, #text do
			label.MaxVisibleGraphemes = i
			task.wait(0.03)
		end
	end)
end

function Bloom.Sequence(steps: { { fn: any, args: { any }?, wait: number? } })
	task.spawn(function()
		for _, step in steps do
			if step.wait then
				task.wait(step.wait)
			end
			if step.fn then
				step.fn(table.unpack(step.args or {}))
			end
		end
	end)
end

Bloom.FrameSlide = Bloom.Slide
Bloom.FrameZoom = Bloom.Zoom
Bloom.FrameBounce = Bloom.Bounce
Bloom.SetButtonStyle = Bloom.Hover
Bloom.ShowText = Bloom.Type

return Bloom
