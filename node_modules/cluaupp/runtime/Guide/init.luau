--!optimize 2
--!strict
-- Guide — onboarding. Each step owns a Sweep.

local Sweep = require(script.Parent.Sweep)

local Guide = {}
Guide.__index = Guide

export type GuideSweep = Sweep.Sweep

export type GuideStep = ((sweep: GuideSweep) -> ()) | {
	Enter: ((sweep: GuideSweep) -> ())?,
	Exit: ((sweep: GuideSweep) -> ())?,
	Highlight: Instance?,
}

export type GuideConfig = {
	Render: ((step: number, sweep: GuideSweep, spec: any) -> ())?,
	Highlight: ((target: Instance, sweep: GuideSweep) -> ())?,
	OnStep: ((step: number, previous: number?) -> ())?,
	OnComplete: (() -> ())?,
}

export type GuideSession = {
	Start: (self: GuideSession, at: number?) -> (),
	GoTo: (self: GuideSession, step: number) -> boolean,
	Advance: (self: GuideSession) -> boolean,
	Back: (self: GuideSession) -> boolean,
	Complete: (self: GuideSession) -> (),
	GetStep: (self: GuideSession) -> number,
	IsActive: (self: GuideSession) -> boolean,
	Destroy: (self: GuideSession) -> (),
}

local function applyHighlight(target: Instance, sweep: GuideSweep)
	local highlight = Instance.new("Highlight")
	if target:IsA("Model") or target:IsA("BasePart") or target:IsA("Accessory") then
		highlight.Adornee = target
	end
	highlight.FillColor = Color3.fromRGB(255, 210, 70)
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.fromRGB(255, 230, 120)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target
	sweep:Add(highlight)
end

local function enterStep(spec: any, sweep: GuideSweep, index: number, config: GuideConfig?)
	if typeof(spec) == "function" then
		spec(sweep)
	elseif typeof(spec) == "table" then
		local enter = spec.Enter
		if typeof(enter) == "function" then
			enter(sweep)
		end
		local target = spec.Highlight
		if typeof(target) == "Instance" then
			local hook = config and config.Highlight
			if typeof(hook) == "function" then
				hook(target, sweep)
			else
				applyHighlight(target, sweep)
			end
		end
	end
	local render = config and config.Render
	if typeof(render) == "function" then
		render(index, sweep, spec)
	end
end

local function exitStep(spec: any, sweep: GuideSweep?)
	if typeof(spec) == "table" then
		local exit = spec.Exit
		if typeof(exit) == "function" then
			exit(sweep)
		end
	end
	if sweep then
		sweep:Destroy()
	end
end

function Guide.build(steps: { any }, config: GuideConfig?): GuideSession
	local index = 0
	local currentSweep: GuideSweep? = nil
	local currentSpec: any = nil
	local active = false
	local destroyed = false
	local session = {}

	function session:GoTo(step: number): boolean
		if destroyed then
			return false
		end
		local spec = steps[step]
		if spec == nil then
			return false
		end
		if active and step == index then
			return true
		end
		local previous = if active then index else nil
		exitStep(currentSpec, currentSweep)
		currentSweep = nil
		currentSpec = nil
		index = step
		active = true
		local sweep = Sweep.new()
		currentSweep = sweep
		currentSpec = spec
		enterStep(spec, sweep, step, config)
		local onStep = config and config.OnStep
		if typeof(onStep) == "function" then
			onStep(step, previous)
		end
		return true
	end

	function session:Start(at: number?)
		if destroyed then
			return
		end
		active = false
		index = 0
		self:GoTo(at or 1)
	end

	function session:Advance(): boolean
		if destroyed or not active then
			return false
		end
		if steps[index + 1] == nil then
			self:Complete()
			return true
		end
		return self:GoTo(index + 1)
	end

	function session:Back(): boolean
		if destroyed or not active then
			return false
		end
		return self:GoTo(index - 1)
	end

	function session:Complete()
		if destroyed then
			return
		end
		exitStep(currentSpec, currentSweep)
		currentSweep = nil
		currentSpec = nil
		active = false
		local onComplete = config and config.OnComplete
		if typeof(onComplete) == "function" then
			onComplete()
		end
	end

	function session:GetStep(): number
		return index
	end

	function session:IsActive(): boolean
		return active and not destroyed
	end

	function session:Destroy()
		if destroyed then
			return
		end
		self:Complete()
		destroyed = true
		active = false
	end

	return session :: GuideSession
end

Guide.Step = {
	new = function(orderOrEnter: any, enter: any?): any
		if typeof(orderOrEnter) == "function" then
			return { Enter = orderOrEnter }
		end
		if typeof(orderOrEnter) == "number" then
			if typeof(enter) == "function" then
				return { Order = orderOrEnter, Enter = enter }
			end
			if typeof(enter) == "table" then
				local spec = table.clone(enter)
				spec.Order = orderOrEnter
				return spec
			end
			return { Order = orderOrEnter }
		end
		if typeof(orderOrEnter) == "table" then
			return orderOrEnter
		end
		return { orderOrEnter, enter }
	end,
}

function Guide.Start(steps: any?, config: any?): any
	if typeof(steps) == "table" and steps.UserId == nil then
		local session = Guide.build(steps, config)
		session:Start()
		return session
	end
	return Guide
end

return Guide
