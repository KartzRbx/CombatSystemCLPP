--!nonstrict
-- Compiled by CL++ — C++ × Luau

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Occlude = require(ReplicatedStorage.CluauppLibs.Occlude)
const ArrayIndexer = require(ReplicatedStorage.CluauppLibs.ArrayIndexer)

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const Axiom = require(ReplicatedStorage.CluauppLibs.Axiom)
const Bloom = require(ReplicatedStorage.CluauppLibs.Bloom)
const Coil = require(ReplicatedStorage.CluauppLibs.Coil)
const Crest = require(ReplicatedStorage.CluauppLibs.Crest)
const Echo = require(ReplicatedStorage.CluauppLibs.Echo)
const Ember = require(ReplicatedStorage.CluauppLibs.Ember)
const Flare = require(ReplicatedStorage.CluauppLibs.Flare)
const Gleam = require(ReplicatedStorage.CluauppLibs.Gleam)
const Guide = require(ReplicatedStorage.CluauppLibs.Guide)
const Helm = require(ReplicatedStorage.CluauppLibs.Helm)
const Janitor = require(ReplicatedStorage.CluauppLibs.Sweep)
const Keep = require(ReplicatedStorage.CluauppLibs.Keep)
const Lens = require(ReplicatedStorage.CluauppLibs.Lens)
const Mint = require(ReplicatedStorage.CluauppLibs.Mint)
const Net = require(ReplicatedStorage.CluauppLibs.Net)
const Pin = require(ReplicatedStorage.CluauppLibs.Pin)
const Promise = require(ReplicatedStorage.CluauppLibs.Promise)
const Roster = require(ReplicatedStorage.CluauppLibs.Roster)
const Spark = require(ReplicatedStorage.CluauppLibs.Spark)
const Stage = require(ReplicatedStorage.CluauppLibs.Stage)
const Sweep = require(ReplicatedStorage.CluauppLibs.Sweep)
const Trace = require(ReplicatedStorage.CluauppLibs.Trace)

local LibBenchClient = {}
LibBenchClient.HOT_ITERS = 2500
LibBenchClient.MID_ITERS = 400
LibBenchClient.LIGHT_ITERS = 80
LibBenchClient.players = game:GetService("Players")
LibBenchClient.me = nil
LibBenchClient.SparkHits = 0
LibBenchClient.WorkSink = 0

-- LibBenchClient.client.clpp:28
function LibBenchClient:Report(name: string, started: number, ok: boolean): boolean
	if not (self and name) then
		return false
	end

	local elapsed: number = tick() - started
	local elapsedMs: number = elapsed * 1000
	print("[LibBenchClient] " .. name .. " " .. tostring(elapsedMs) .. " ms ok=" .. tostring(ok))
	return ok
end

-- LibBenchClient.client.clpp:39
function LibBenchClient:OnSparkHit(): boolean
	if not (self) then
		return false
	end

	self.SparkHits += 1
	return true
end

-- LibBenchClient.client.clpp:48
function LibBenchClient:OnLensDraw(): boolean
	if not (self) then
		return false
	end

	Lens.Text("LibBenchClient")
	Lens.Value("sink", self.WorkSink)
	return true
end

-- LibBenchClient.client.clpp:58
function LibBenchClient:OnGleamEffect(): boolean
	if not (self) then
		return false
	end

	self.WorkSink += 1
	return true
end

-- LibBenchClient.client.clpp:67
function LibBenchClient:BenchGleamSource(): boolean
	if not (self) then
		return false
	end

	local source: GleamSource = Gleam.Source(0)
	local i: number = 0

	while i < self.HOT_ITERS do
		source:Set(i)
		i += 1
	end

	self.WorkSink = source:Get()
	return self.WorkSink == self.HOT_ITERS - 1
end

-- LibBenchClient.client.clpp:82
function LibBenchClient:BenchGleamCreate(): boolean
	if not (self) then
		return false
	end

	local i: number = 0

	while i < self.LIGHT_ITERS do
		local frame: Frame = Gleam.Frame({ Name = "LibBenchFrame", Size = UDim2.new(0, 8, 0, 8), BackgroundTransparency = 1 })
		frame:Destroy()
		i += 1
	end

	return true
end

-- LibBenchClient.client.clpp:100
function LibBenchClient:BenchGleamMount(): boolean
	if not (self and self.me and self.me.PlayerGui) then
		return false
	end

	local host: ScreenGui = Gleam.ScreenGui({ Name = "LibBenchHost", ResetOnSpawn = false, DisplayOrder = -50 })
	Gleam.Mount(host, self.me.PlayerGui)
	host:Destroy()
	return true
end

-- LibBenchClient.client.clpp:115
function LibBenchClient:BenchGleamSpring(): boolean
	if not (self) then
		return false
	end

	local source: GleamSource = Gleam.Source(0)
	local sprung: GleamSource = Gleam.Spring(source, 20, 1)
	source:Set(10)

	if not (sprung) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:129
function LibBenchClient:BenchBloomPlay(): boolean
	if not (self and self.me and self.me.PlayerGui) then
		return false
	end

	local host: ScreenGui = Gleam.ScreenGui({ Name = "LibBenchBloom", ResetOnSpawn = false, DisplayOrder = -50 })
	local target: Frame = Gleam.Frame({ Name = "BloomTarget", Size = UDim2.new(0, 24, 0, 24), BackgroundColor3 = Color3.new(1, 1, 1) })
	Gleam.Mount(host, self.me.PlayerGui)
	Gleam.Mount(target, host)
	local shine: BloomHandle = Bloom.Play(target, Bloom.Shine)

	if shine then
		shine:Destroy()
	end

	host:Destroy()
	return true
end

-- LibBenchClient.client.clpp:154
function LibBenchClient:BenchBloomFade(): boolean
	if not (self and self.me and self.me.PlayerGui) then
		return false
	end

	local host: ScreenGui = Gleam.ScreenGui({ Name = "LibBenchFade", ResetOnSpawn = false, DisplayOrder = -50 })
	local target: Frame = Gleam.Frame({ Name = "FadeTarget", Size = UDim2.new(0, 24, 0, 24), BackgroundColor3 = Color3.new(1, 1, 1) })
	Gleam.Mount(host, self.me.PlayerGui)
	Gleam.Mount(target, host)
	Bloom.Fade(target, false, 40)
	host:Destroy()
	return true
end

-- LibBenchClient.client.clpp:176
function LibBenchClient:BenchBloomPress(): boolean
	if not (self and self.me and self.me.PlayerGui) then
		return false
	end

	local host: ScreenGui = Gleam.ScreenGui({ Name = "LibBenchPress", ResetOnSpawn = false, DisplayOrder = -50 })
	local button: TextButton = Gleam.TextButton({ Name = "PressTarget", Size = UDim2.new(0, 40, 0, 24), Text = "x" })
	Gleam.Mount(host, self.me.PlayerGui)
	Gleam.Mount(button, host)
	Bloom.Press(button, Bloom.Punch)
	Bloom.Ripple(button)
	host:Destroy()
	return true
end

-- LibBenchClient.client.clpp:199
function LibBenchClient:BenchPinCreate(): boolean
	if not (self) then
		return false
	end

	local part: Part = Instance.new("Part")
	part.Name = "LibBenchPin"
	local gui: Frame = Gleam.Frame({ Name = "PinGui", Size = UDim2.new(0, 40, 0, 16) })
	local pin: Pin = Pin.new(part, gui)

	if not (pin) then
		part:Destroy()
		gui:Destroy()
		return false
	end

	pin:SetText("lib")
	pin:Destroy()
	part:Destroy()
	return true
end

-- LibBenchClient.client.clpp:222
function LibBenchClient:BenchStageAttach(): boolean
	if not (self and self.me and self.me.PlayerGui) then
		return false
	end

	local host: ScreenGui = Gleam.ScreenGui({ Name = "LibBenchStage", ResetOnSpawn = false, DisplayOrder = -50 })
	local frame: Frame = Gleam.Frame({ Name = "StageFrame", Size = UDim2.new(0, 64, 0, 64) })
	local model: Part = Instance.new("Part")
	model.Name = "LibBenchStagePart"
	Gleam.Mount(host, self.me.PlayerGui)
	Gleam.Mount(frame, host)
	local stage: Stage = Stage.Attach(frame, model)

	if not (stage) then
		host:Destroy()
		model:Destroy()
		return false
	end

	stage:Update(0.016)
	stage:Destroy()
	host:Destroy()
	model:Destroy()
	return true
end

-- LibBenchClient.client.clpp:253
function LibBenchClient:BenchCrestCreate(): boolean
	if not (self) then
		return false
	end

	local icon: Crest = Crest.new()

	if not (icon) then
		return false
	end

	icon:setName("LibBench")
	icon:setLabel("LB")
	icon:Destroy()
	return true
end

-- LibBenchClient.client.clpp:268
function LibBenchClient:BenchLensInit(): boolean
	if not (self) then
		return false
	end

	Lens:Init()
	return true
end

-- LibBenchClient.client.clpp:277
function LibBenchClient:BenchLensWindow(): boolean
	if not (self) then
		return false
	end

	Lens.Window("LibBenchClient", function()
		self:OnLensDraw()
	end)

	return true
end

-- LibBenchClient.client.clpp:288
function LibBenchClient:BenchEmberScale(): boolean
	if not (self) then
		return false
	end

	local part: Part = Instance.new("Part")
	part.Name = "LibBenchEmber"
	local i: number = 0

	while i < self.LIGHT_ITERS do
		Ember.Scale(part, 1)
		i += 1
	end

	part:Destroy()
	return true
end

-- LibBenchClient.client.clpp:304
function LibBenchClient:BenchEchoCFrame(): boolean
	if not (self) then
		return false
	end

	local i: number = 0

	while i < self.MID_ITERS do
		local packed: buffer = Echo.WriteCFrame(CFrame.new(i, 0, 0))
		local restored: CFrame = Echo.ReadCFrame(packed)

		if not (restored) then
			return false
		end

		i += 1
	end

	self.WorkSink = i
	return true
end

-- LibBenchClient.client.clpp:322
function LibBenchClient:BenchGuideStart(): boolean
	if not (self) then
		return false
	end

	Guide.Start()
	return true
end

-- LibBenchClient.client.clpp:331
function LibBenchClient:BenchOccludePosition(): boolean
	if not (self) then
		return false
	end

	local part: Part = Instance.new("Part")
	part.Name = "LibBenchOcclude"
	local pos: Vector3 = Occlude.Position(part)
	part:Destroy()

	if not (pos) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:346
function LibBenchClient:BenchHelmRegistry(): boolean
	if not (self) then
		return false
	end

	local registry: HelmRegistry = Helm.Registry()

	if not (registry) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:358
function LibBenchClient:BenchMintCompact(): boolean
	if not (self) then
		return false
	end

	local last: string = ""
	local i: number = 0

	while i < self.HOT_ITERS do
		last = Mint.Compact(i * 1000)
		i += 1
	end

	if not (last) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:375
function LibBenchClient:BenchAxiomLerp(): boolean
	if not (self) then
		return false
	end

	local acc: number = 0
	local i: number = 0

	while i < self.HOT_ITERS do
		acc = acc + Axiom.Lerp(0, 10, 0.5)
		i += 1
	end

	self.WorkSink = Axiom.Round(acc)
	return acc > 0
end

-- LibBenchClient.client.clpp:390
function LibBenchClient:BenchCoilStep(): boolean
	if not (self) then
		return false
	end

	local spring: Coil = Coil.new(1, 8, 0)
	spring:Set(10)
	local i: number = 0

	while i < self.MID_ITERS do
		spring.Step(0.016)
		i += 1
	end

	local pos = spring:Get()

	if not (pos) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:409
function LibBenchClient:BenchRosterPush(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	local i: number = 0

	while i < self.HOT_ITERS do
		list:Push(i)
		i += 1
	end

	self.WorkSink = list:Length()
	return self.WorkSink == self.HOT_ITERS
end

-- LibBenchClient.client.clpp:424
function LibBenchClient:BenchSparkFire(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	self.SparkHits = 0
	local bus: Spark = Spark.new()
	__janitor:Add(bus:Connect(function()
		self:OnSparkHit()
	end), "Disconnect")

	local i: number = 0

	while i < self.HOT_ITERS do
		bus:Fire()
		i += 1
	end

	bus:Destroy()
	return self.SparkHits == self.HOT_ITERS
end

-- LibBenchClient.client.clpp:443
function LibBenchClient:BenchSweepCleanup(): boolean
	if not (self) then
		return false
	end

	local sweep: Sweep = Sweep.new()
	local i: number = 0

	while i < self.MID_ITERS do
		sweep:Add(function()
			return
		end, true)

		i += 1
	end

	sweep:Destroy()
	return true
end

-- LibBenchClient.client.clpp:460
function LibBenchClient:BenchPromiseResolve(): boolean
	if not (self) then
		return false
	end

	local job: Promise = Promise.resolve(1)

	if not (job) then
		return false
	end

	local status: string = job.GetStatus()

	if not (status) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:477
function LibBenchClient:BenchFlareCursor(): boolean
	if not (self) then
		return false
	end

	local i: number = 0
	local last: number = 0

	while i < self.MID_ITERS do
		local cursor = Flare.cursor(32)
		Flare.writei32(cursor, i)
		i += 1
		last = i
	end

	self.WorkSink = last
	return last == self.MID_ITERS
end

-- LibBenchClient.client.clpp:494
function LibBenchClient:BenchArrayIndexer(): boolean
	if not (self) then
		return false
	end

	local indexer: ArrayIndexer = ArrayIndexer.New()
	local i: number = 0

	while i < self.MID_ITERS do
		local id: number = indexer:Acquire()

		if not indexer:Has(id) then
			return false
		end

		i += 1
	end

	return true
end

-- LibBenchClient.client.clpp:511
function LibBenchClient:BenchKeepClient(): boolean
	if not (self) then
		return false
	end

	local data = Keep.Client:Get()

	if not (data) then
		return true
	end

	return true
end

-- LibBenchClient.client.clpp:523
function LibBenchClient:BenchNetEvent(): boolean
	if not (self) then
		return false
	end

	local bus: NetEvent = Net.Event("LibBenchPing")

	if not (bus) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:535
function LibBenchClient:BenchTraceDisplay(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	list:Push("a")
	list:Push(1)
	local dump: string = Trace.Display(list)

	if not (dump) then
		return false
	end

	return true
end

-- LibBenchClient.client.clpp:550
function LibBenchClient:RunAll(): boolean
	if not (self) then
		return false
	end

	local started: number = tick()
	local t: number = 0
	t = tick()
	self:Report("GleamSource", t, self:BenchGleamSource())
	t = tick()
	self:Report("GleamCreate", t, self:BenchGleamCreate())
	t = tick()
	self:Report("GleamMount", t, self:BenchGleamMount())
	t = tick()
	self:Report("GleamSpring", t, self:BenchGleamSpring())
	t = tick()
	self:Report("BloomPlay", t, self:BenchBloomPlay())
	t = tick()
	self:Report("BloomFade", t, self:BenchBloomFade())
	t = tick()
	self:Report("BloomPress", t, self:BenchBloomPress())
	t = tick()
	self:Report("PinCreate", t, self:BenchPinCreate())
	t = tick()
	self:Report("StageAttach", t, self:BenchStageAttach())
	t = tick()
	self:Report("CrestCreate", t, self:BenchCrestCreate())
	t = tick()
	self:Report("LensInit", t, self:BenchLensInit())
	t = tick()
	self:Report("LensWindow", t, self:BenchLensWindow())
	t = tick()
	self:Report("EmberScale", t, self:BenchEmberScale())
	t = tick()
	self:Report("EchoCFrame", t, self:BenchEchoCFrame())
	t = tick()
	self:Report("GuideStart", t, self:BenchGuideStart())
	t = tick()
	self:Report("OccludePosition", t, self:BenchOccludePosition())
	t = tick()
	self:Report("HelmRegistry", t, self:BenchHelmRegistry())
	t = tick()
	self:Report("MintCompact", t, self:BenchMintCompact())
	t = tick()
	self:Report("AxiomLerp", t, self:BenchAxiomLerp())
	t = tick()
	self:Report("CoilStep", t, self:BenchCoilStep())
	t = tick()
	self:Report("RosterPush", t, self:BenchRosterPush())
	t = tick()
	self:Report("SparkFire", t, self:BenchSparkFire())
	t = tick()
	self:Report("SweepCleanup", t, self:BenchSweepCleanup())
	t = tick()
	self:Report("PromiseResolve", t, self:BenchPromiseResolve())
	t = tick()
	self:Report("FlareCursor", t, self:BenchFlareCursor())
	t = tick()
	self:Report("ArrayIndexer", t, self:BenchArrayIndexer())
	t = tick()
	self:Report("KeepClient", t, self:BenchKeepClient())
	t = tick()
	self:Report("NetEvent", t, self:BenchNetEvent())
	t = tick()
	self:Report("TraceDisplay", t, self:BenchTraceDisplay())
	self:Report("TOTAL", started, true)
	return true
end

-- LibBenchClient.client.clpp:620
const function init()
	local runService: RunService = game:GetService("RunService")

	if not (runService:IsStudio()) then
		return
	end

	local bench = LibBenchClient
	bench.me = bench.players.LocalPlayer
	task.spawn(function()
		task.wait(1)
		LibBenchClient:RunAll()
	end)
end

init()
