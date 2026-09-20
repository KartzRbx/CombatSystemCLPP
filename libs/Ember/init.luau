--!native
--!optimize 2
--!strict
--[=[
	@class Ember
	Emit, play, stop, scale, and clone visual-effect templates (ParticleEmitter,
	Beam, Trail, Sound, Animation). There was no public GitHub for
	lucaschaibub/vfx-util; this is the full Cluaupp system.

	```lua
	Ember.Emit(attachment, 12)
	local clone = Ember.CloneOnto(template, character.HumanoidRootPart)
	Ember.Play(clone)
	task.delay(2, function()
		Ember.DestroyAfter(clone, 0.4)
	end)
	```
]=]
local Sweep = require(script.Parent.Sweep)

local Ember = {}

export type EffectInstance = ParticleEmitter | Beam | Trail | Sound | Fire | Smoke | Sparkles | Animation | AnimationTrack

local tracks: { [Instance]: { AnimationTrack } } = {}

local function isEffect(inst: Instance): boolean
	return inst:IsA("ParticleEmitter")
		or inst:IsA("Beam")
		or inst:IsA("Trail")
		or inst:IsA("Sound")
		or inst:IsA("Fire")
		or inst:IsA("Smoke")
		or inst:IsA("Sparkles")
		or inst:IsA("Animation")
		or inst:IsA("AnimationTrack")
end

local function collect(root: Instance): { Instance }
	local found: { Instance } = {}
	if isEffect(root) then
		table.insert(found, root)
	end
	for _, child in root:GetDescendants() do
		if isEffect(child) then
			table.insert(found, child)
		end
	end
	return found
end

local function scaleSequence(sequence: NumberSequence, factor: number): NumberSequence
	local keys = {}
	for index, keypoint in sequence.Keypoints do
		keys[index] = NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * factor, keypoint.Envelope * factor)
	end
	return NumberSequence.new(keys)
end

local function animatorOf(root: Instance): Animator?
	local current: Instance? = root
	while current do
		if current:IsA("Animator") then
			return current
		end
		if current:IsA("Humanoid") or current:IsA("AnimationController") then
			local existing = current:FindFirstChildOfClass("Animator")
			if existing then
				return existing
			end
			local created = Instance.new("Animator")
			created.Parent = current
			return created
		end
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local existing = humanoid:FindFirstChildOfClass("Animator")
				if existing then
					return existing
				end
				local created = Instance.new("Animator")
				created.Parent = humanoid
				return created
			end
			local controller = current:FindFirstChildOfClass("AnimationController")
			if controller then
				local existing = controller:FindFirstChildOfClass("Animator")
				if existing then
					return existing
				end
				local created = Instance.new("Animator")
				created.Parent = controller
				return created
			end
		end
		current = current.Parent
	end
	return nil
end

local function remember(root: Instance, track: AnimationTrack)
	local list = tracks[root]
	if list == nil then
		list = {}
		tracks[root] = list
	end
	table.insert(list, track)
end

local function ownerOf(root: Instance): any
	local existing = (root :: any)._emberSweep
	if Sweep.Is(existing) then
		return existing
	end
	local sweep = Sweep.new()
	sweep:Add(root)
	sweep:LinkToInstance(root)
	;(root :: any)._emberSweep = sweep
	return sweep
end

local function weldClone(clone: Instance, parent: Instance)
	if clone:IsA("Attachment") then
		if parent:IsA("Attachment") then
			clone.Parent = parent.Parent
			clone.Position = parent.Position
			clone.Orientation = parent.Orientation
		else
			clone.Parent = parent
		end
		return
	end
	local host: BasePart? = nil
	if parent:IsA("BasePart") then
		host = parent
	elseif parent:IsA("Attachment") then
		host = parent.Parent :: BasePart?
	elseif parent:IsA("Model") then
		host = parent.PrimaryPart or parent:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	if clone:IsA("BasePart") and host then
		clone.CFrame = host.CFrame
		clone.Anchored = false
		clone.CanCollide = false
		clone.Massless = true
		clone.Parent = host
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = host
		weld.Part1 = clone
		weld.Parent = clone
		return
	end
	if clone:IsA("Model") and host then
		clone:PivotTo(host.CFrame)
		local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			clone.PrimaryPart = primary
			primary.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = host
			weld.Part1 = primary
			weld.Parent = clone
		end
		clone.Parent = host.Parent or host
		return
	end
	clone.Parent = parent
end

--[=[
	@within Ember
	@param root Instance -- Attachment, Part, or a folder of emitters
	@param count number? -- particles to emit; default 8
]=]
function Ember.Emit(root: Instance, count: number?)
	local amount = count or 8
	for _, inst in collect(root) do
		if inst:IsA("ParticleEmitter") then
			inst:Emit(amount)
		elseif inst:IsA("Sound") then
			inst:Play()
		elseif inst:IsA("Beam") or inst:IsA("Trail") then
			inst.Enabled = true
		elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
			inst.Enabled = true
		elseif inst:IsA("AnimationTrack") then
			inst:Play()
		elseif inst:IsA("Animation") then
			local animator = animatorOf(inst)
			if animator then
				local track = animator:LoadAnimation(inst)
				remember(root, track)
				track:Play()
			end
		end
	end
end

--[=[
	@within Ember
	Enables looping emitters / beams / trails and plays sounds and AnimationTracks.
]=]
function Ember.Play(root: Instance)
	for _, inst in collect(root) do
		if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
			inst.Enabled = true
		elseif inst:IsA("Sound") then
			inst:Play()
		elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
			inst.Enabled = true
		elseif inst:IsA("AnimationTrack") then
			inst:Play()
		elseif inst:IsA("Animation") then
			local animator = animatorOf(inst)
			if animator then
				local track = animator:LoadAnimation(inst)
				remember(root, track)
				track:Play()
			end
		end
	end
end

--[=[
	@within Ember
]=]
function Ember.Stop(root: Instance)
	for _, inst in collect(root) do
		if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
			inst.Enabled = false
		elseif inst:IsA("Sound") then
			inst:Stop()
		elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
			inst.Enabled = false
		elseif inst:IsA("AnimationTrack") then
			inst:Stop()
		end
	end
	local loaded = tracks[root]
	if loaded then
		for _, track in loaded do
			if track.IsPlaying then
				track:Stop()
			end
		end
		tracks[root] = nil
	end
end

--[=[
	@within Ember
	@param template Instance
	@param parent Instance
	@return Instance
	Clones a VFX template onto `parent` (Attachment / BasePart / Model).
]=]
function Ember.CloneOnto(template: Instance, parent: Instance): Instance
	local clone = template:Clone()
	if clone:IsA("Attachment") and parent:IsA("BasePart") then
		clone.Parent = parent
	elseif clone:IsA("Attachment") and parent:IsA("Attachment") then
		clone.Parent = parent.Parent
		clone.Position = parent.Position
		clone.Orientation = parent.Orientation
	elseif clone:IsA("BasePart") and parent:IsA("Model") then
		clone.Parent = parent
	else
		clone.Parent = parent
	end
	return clone
end

--[=[
	@within Ember
	Clones `template` onto a character (named Attachment, HumanoidRootPart, or PrimaryPart).
	Sweep owns the clone and destroys it when the character is destroyed.
]=]
function Ember.Attach(template: Instance, character: Instance, attachmentName: string?): Instance
	local parent: Instance = character
	if attachmentName and attachmentName ~= "" then
		local named = character:FindFirstChild(attachmentName, true)
		if named then
			parent = named
		end
	elseif character:IsA("Model") then
		local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
		if root then
			parent = root
		end
	end
	local clone = template:Clone()
	weldClone(clone, parent)
	if clone.Parent == nil then
		clone.Parent = parent
	end
	local sweep = Sweep.new()
	sweep:Add(clone)
	sweep:LinkToInstance(character)
	;(clone :: any)._emberSweep = sweep
	Ember.Play(clone)
	return clone
end

--[=[
	@within Ember
	Scales NumberSequence / NumberRange particle sizes and related VFX by `factor`.
]=]
function Ember.Scale(root: Instance, factor: number)
	for _, inst in collect(root) do
		if inst:IsA("ParticleEmitter") then
			inst.Size = scaleSequence(inst.Size, factor)
			local spread = inst.SpreadAngle
			inst.SpreadAngle = Vector2.new(spread.X * factor, spread.Y * factor)
			local speed = inst.Speed
			inst.Speed = NumberRange.new(speed.Min * factor, speed.Max * factor)
		elseif inst:IsA("Beam") then
			inst.Width0 *= factor
			inst.Width1 *= factor
		elseif inst:IsA("Trail") then
			inst.WidthScale = scaleSequence(inst.WidthScale, factor)
		elseif inst:IsA("Fire") or inst:IsA("Smoke") then
			inst.Size *= factor
		elseif inst:IsA("Sound") then
			inst.PlaybackSpeed = math.clamp(inst.PlaybackSpeed * factor, 0.1, 4)
		end
	end
end

--[=[
	@within Ember
	Stops effects then destroys the instance after `lifetime` seconds. Sweep owns the delay.
]=]
function Ember.DestroyAfter(root: Instance, lifetime: number?)
	local delayTime = lifetime or 1
	local sweep = ownerOf(root)
	local stopThread = task.delay(delayTime * 0.6, function()
		if root.Parent then
			Ember.Stop(root)
		end
	end)
	local endThread = task.delay(delayTime, function()
		sweep:Destroy()
	end)
	sweep:Add(function()
		pcall(task.cancel, stopThread)
		pcall(task.cancel, endThread)
		tracks[root] = nil
	end, true)
end

--[=[
	@within Ember
	One-shot: clone, emit, destroy.
]=]
function Ember.Burst(template: Instance, parent: Instance, count: number?, lifetime: number?): Instance
	local clone = Ember.CloneOnto(template, parent)
	Ember.Emit(clone, count)
	Ember.DestroyAfter(clone, lifetime or 2)
	return clone
end

export type Ember = typeof(Ember)

return Ember
