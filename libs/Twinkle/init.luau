--!strict
--[=[
	@class Twinkle
	UI motion without TweenService boilerplate: fade, slide, zoom, bounce, button styles.
	Inspired by [Twinkle](https://devforum.roblox.com/t/twinkle-free-powerful-ui-animator-module/4512304).
]=]
local TweenService = game:GetService("TweenService")

export type HoverType = "Lift" | "Bounce" | "Grow"
export type PressType = "Shrink" | "Punch"
export type TweenProps = {
	BackgroundTransparency: number?,
	TextTransparency: number?,
	Position: UDim2?,
	Size: UDim2?,
}

local Twinkle = {}

local function tween(inst: Instance, info: TweenInfo, props: TweenProps): Tween
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function infoOf(speed: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(speed or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
end

--[=[
	@within Twinkle
	@param element GuiObject
	@param show boolean
	@param speed number?
]=]
function Twinkle.Fade(element: GuiObject, show: boolean, speed: number?)
	element.Visible = true
	tween(element, infoOf(speed), { BackgroundTransparency = if show then 0 else 1 })
	if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
		tween(element, infoOf(speed), { TextTransparency = if show then 0 else 1 })
	end
	if not show then
		task.delay(speed or 0.25, function()
			element.Visible = false
		end)
	end
end

--[=[
	@within Twinkle
	@param element GuiObject
	@param show boolean
	@param speed number?
]=]
function Twinkle.FrameSlide(element: GuiObject, show: boolean, speed: number?)
	local original = element.Position
	if show then
		element.Visible = true
		element.Position = original + UDim2.fromOffset(0, 24)
		tween(element, infoOf(speed), { Position = original, BackgroundTransparency = 0 })
	else
		tween(element, infoOf(speed), { Position = original + UDim2.fromOffset(0, 24), BackgroundTransparency = 1 })
		task.delay(speed or 0.25, function()
			element.Visible = false
			element.Position = original
		end)
	end
end

--[=[
	@within Twinkle
	@param element GuiObject
	@param show boolean
	@param speed number?
]=]
function Twinkle.FrameZoom(element: GuiObject, show: boolean, speed: number?)
	local original = element.Size
	if show then
		element.Visible = true
		element.Size = UDim2.new(original.X.Scale * 0.9, original.X.Offset, original.Y.Scale * 0.9, original.Y.Offset)
		tween(element, infoOf(speed, Enum.EasingStyle.Back), { Size = original })
	else
		tween(element, infoOf(speed), {
			Size = UDim2.new(original.X.Scale * 0.9, original.X.Offset, original.Y.Scale * 0.9, original.Y.Offset),
		})
		task.delay(speed or 0.25, function()
			element.Visible = false
			element.Size = original
		end)
	end
end

--[=[
	@within Twinkle
	@param element GuiObject
	@param speed number?
	@param bouncePercent number?
]=]
function Twinkle.FrameBounce(element: GuiObject, speed: number?, bouncePercent: number?)
	local original = element.Size
	local percent = bouncePercent or 0.08
	local bigger = UDim2.new(
		original.X.Scale * (1 + percent),
		original.X.Offset,
		original.Y.Scale * (1 + percent),
		original.Y.Offset
	)
	local t = tween(element, infoOf(speed or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = bigger })
	t.Completed:Connect(function()
		tween(element, infoOf(speed or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = original })
	end)
end

--[=[
	@within Twinkle
	@param element GuiObject
	@param hoverType string? -- Lift | Bounce | Grow
	@param pressType string? -- Shrink | Punch
	@param scalePercent number?
]=]
function Twinkle.SetButtonStyle(element: GuiObject, hoverType: HoverType?, pressType: PressType?, scalePercent: number?)
	local original = element.Size
	local originalPos = element.Position
	local percent = scalePercent or 0.06
	if element:IsA("GuiButton") then
		element.MouseEnter:Connect(function()
			if hoverType == "Lift" then
				tween(element, infoOf(0.12), { Position = originalPos + UDim2.fromOffset(0, -4) })
			else
				Twinkle.FrameBounce(element, 0.1, percent)
			end
		end)
		element.MouseLeave:Connect(function()
			tween(element, infoOf(0.12), { Position = originalPos, Size = original })
		end)
		element.MouseButton1Down:Connect(function()
			if pressType == "Punch" then
				Twinkle.FrameBounce(element, 0.08, percent * 1.4)
			else
				local smaller = UDim2.new(
					original.X.Scale * (1 - percent),
					original.X.Offset,
					original.Y.Scale * (1 - percent),
					original.Y.Offset
				)
				tween(element, infoOf(0.08), { Size = smaller })
			end
		end)
		element.MouseButton1Up:Connect(function()
			tween(element, infoOf(0.1), { Size = original })
		end)
	end
end

export type Twinkle = typeof(Twinkle)

return Twinkle
