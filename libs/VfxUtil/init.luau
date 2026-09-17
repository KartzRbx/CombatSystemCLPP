--!strict
--[=[
	@class VfxUtil
	Emit, play, stop, scale, and clone visual-effect templates (ParticleEmitter,
	Beam, Trail, Sound, Animation). There was no public GitHub for
	lucaschaibub/vfx-util; this is the full Cluaupp system.

	```lua
	VfxUtil.Emit(attachment, 12)
	local clone = VfxUtil.CloneOnto(template, character.HumanoidRootPart)
	VfxUtil.Play(clone)
	task.delay(2, function()
		VfxUtil.DestroyAfter(clone, 0.4)
	end)
	```
]=]
local Debris = game:GetService("Debris")

local VfxUtil = {}

export type EffectInstance = ParticleEmitter | Beam | Trail | Sound | Fire | Smoke | Sparkles

local function isEffect(inst: Instance): boolean
	return inst:IsA("ParticleEmitter")
		or inst:IsA("Beam")
		or inst:IsA("Trail")
		or inst:IsA("Sound")
		or inst:IsA("Fire")
		or inst:IsA("Smoke")
		or inst:IsA("Sparkles")
end

local function collect(root: Instance): { Instance }
	local found = {}
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

--[=[
	@within VfxUtil
	@param root Instance -- Attachment, Part, or a folder of emitters
	@param count number? -- particles to emit; default 8
]=]
function VfxUtil.Emit(root: Instance, count: number?)
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
		end
	end
end

--[=[
	@within VfxUtil
	Enables looping emitters / beams / trails and plays sounds.
]=]
function VfxUtil.Play(root: Instance)
	for _, inst in collect(root) do
		if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
			inst.Enabled = true
		elseif inst:IsA("Sound") then
			inst:Play()
		elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
			inst.Enabled = true
		end
	end
end

--[=[
	@within VfxUtil
]=]
function VfxUtil.Stop(root: Instance)
	for _, inst in collect(root) do
		if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
			inst.Enabled = false
		elseif inst:IsA("Sound") then
			inst:Stop()
		elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
			inst.Enabled = false
		end
	end
end

--[=[
	@within VfxUtil
	@param template Instance
	@param parent Instance
	@return Instance
	Clones a VFX template onto `parent` (Attachment / BasePart / Model).
]=]
function VfxUtil.CloneOnto(template: Instance, parent: Instance): Instance
	local clone = template:Clone()
	if clone:IsA("Attachment") and parent:IsA("BasePart") then
		clone.Parent = parent
	elseif clone:IsA("BasePart") and parent:IsA("Model") then
		clone.Parent = parent
	else
		clone.Parent = parent
	end
	return clone
end

--[=[
	@within VfxUtil
	Scales NumberSequence / NumberRange particle sizes by `factor`.
]=]
function VfxUtil.Scale(root: Instance, factor: number)
	for _, inst in collect(root) do
		if inst:IsA("ParticleEmitter") then
			local size = inst.Size
			local keys = {}
			for index, keypoint in size.Keypoints do
				keys[index] = NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * factor, keypoint.Envelope * factor)
			end
			inst.Size = NumberSequence.new(keys)
			local spread = inst.SpreadAngle
			inst.SpreadAngle = Vector2.new(spread.X * factor, spread.Y * factor)
		elseif inst:IsA("Sound") then
			inst.PlaybackSpeed = math.clamp(inst.PlaybackSpeed * factor, 0.1, 4)
		end
	end
end

--[=[
	@within VfxUtil
	Stops effects then destroys the instance after `lifetime` seconds.
]=]
function VfxUtil.DestroyAfter(root: Instance, lifetime: number?)
	local delayTime = lifetime or 1
	task.delay(delayTime * 0.6, function()
		if root.Parent then
			VfxUtil.Stop(root)
		end
	end)
	Debris:AddItem(root, delayTime)
end

--[=[
	@within VfxUtil
	One-shot: clone, emit, destroy.
]=]
function VfxUtil.Burst(template: Instance, parent: Instance, count: number?, lifetime: number?): Instance
	local clone = VfxUtil.CloneOnto(template, parent)
	VfxUtil.Emit(clone, count)
	VfxUtil.DestroyAfter(clone, lifetime or 2)
	return clone
end

export type VfxUtil = typeof(VfxUtil)

return VfxUtil
