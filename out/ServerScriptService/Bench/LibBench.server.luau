--!nonstrict
-- Compiled by CL++ — C++ × Luau

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Ward = require(ReplicatedStorage.CluauppLibs.Ward)
const ArrayIndexer = require(ReplicatedStorage.CluauppLibs.ArrayIndexer)
const Occlude = require(ReplicatedStorage.CluauppLibs.Occlude)

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const Axiom = require(ReplicatedStorage.CluauppLibs.Axiom)
const Coil = require(ReplicatedStorage.CluauppLibs.Coil)
const Echo = require(ReplicatedStorage.CluauppLibs.Echo)
const Ember = require(ReplicatedStorage.CluauppLibs.Ember)
const Flare = require(ReplicatedStorage.CluauppLibs.Flare)
const Gleam = require(ReplicatedStorage.CluauppLibs.Gleam)
const Guide = require(ReplicatedStorage.CluauppLibs.Guide)
const Helm = require(ReplicatedStorage.CluauppLibs.Helm)
const Hive = require(ReplicatedStorage.CluauppLibs.Hive)
const Janitor = require(ReplicatedStorage.CluauppLibs.Sweep)
const Keep = require(ReplicatedStorage.CluauppLibs.Keep)
const Lens = require(ReplicatedStorage.CluauppLibs.Lens)
const Mint = require(ReplicatedStorage.CluauppLibs.Mint)
const Net = require(ReplicatedStorage.CluauppLibs.Net)
const Promise = require(ReplicatedStorage.CluauppLibs.Promise)
const Roster = require(ReplicatedStorage.CluauppLibs.Roster)
const Spark = require(ReplicatedStorage.CluauppLibs.Spark)
const Sweep = require(ReplicatedStorage.CluauppLibs.Sweep)
const Trace = require(ReplicatedStorage.CluauppLibs.Trace)
const PlayerECS = require(ReplicatedStorage.Shared.Services.Combat.PlayerECS)

local LibBench = {}
LibBench.HOT_ITERS = 2500
LibBench.MID_ITERS = 400
LibBench.LIGHT_ITERS = 80
LibBench.players = game:GetService("Players")
LibBench.SparkHits = 0
LibBench.WorkSink = 0

-- LibBench.server.clpp:26
function LibBench:Report(name: string, started: number, ok: boolean): boolean
	if not (self and name) then
		return false
	end

	local elapsed: number = tick() - started
	local elapsedMs: number = elapsed * 1000
	print("[LibBench] " .. name .. " " .. tostring(elapsedMs) .. " ms ok=" .. tostring(ok))
	return ok
end

-- LibBench.server.clpp:37
function LibBench:OnSparkHit(): boolean
	if not (self) then
		return false
	end

	self.SparkHits += 1
	return true
end

-- LibBench.server.clpp:46
function LibBench:OnPromiseFail(): boolean
	if not (self) then
		return false
	end

	self.WorkSink += 1
	return true
end

-- LibBench.server.clpp:55
function LibBench:OnLensDraw(): boolean
	if not (self) then
		return false
	end

	Lens.Text("LibBench")
	Lens.Value("sink", self.WorkSink)
	return true
end

-- LibBench.server.clpp:65
function LibBench:FirstPlayer(): Player
	if not (self) then
		return nil
	end

	local found: Player = nil

	for _, candidate in self.players:GetPlayers() do
		if not found then
			found = candidate
		end
	end

	return found
end

-- LibBench.server.clpp:79
function LibBench:BenchRosterPush(): boolean
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

-- LibBench.server.clpp:94
function LibBench:BenchRosterSetGet(): boolean
	if not (self) then
		return false
	end

	local map: Roster = Roster.new()
	local i: number = 0

	while i < self.HOT_ITERS do
		map:Set(i, i)
		i += 1
	end

	i = 0
	local sum: number = 0

	while i < self.HOT_ITERS do
		sum = sum + map:Get(i)
		i += 1
	end

	self.WorkSink = sum
	return map:Has(self.HOT_ITERS - 1)
end

-- LibBench.server.clpp:115
function LibBench:BenchRosterFind(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	local i: number = 0

	while i < self.MID_ITERS do
		list:Push(i)
		i += 1
	end

	local found: number = list:Find(self.MID_ITERS - 1)
	self.WorkSink = found
	return found >= 0
end

-- LibBench.server.clpp:131
function LibBench:BenchRosterHas(): boolean
	if not (self) then
		return false
	end

	local map: Roster = Roster.new()
	map:Set("hp", 100)
	map:Set("atk", 8)
	return map:Has("hp") and map:Has("atk")
end

-- LibBench.server.clpp:142
function LibBench:BenchRosterClone(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	local i: number = 0

	while i < self.MID_ITERS do
		list:Push(i)
		i += 1
	end

	local copy: Roster = list:Clone()
	self.WorkSink = copy:Length()
	return self.WorkSink == self.MID_ITERS
end

-- LibBench.server.clpp:158
function LibBench:BenchRosterPack(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	list:Push(1)
	list:Push(2)
	list:Push(3)
	local packed: buffer = list:Pack()
	local unpacked = Roster.Unpack(packed)

	if not (unpacked) then
		return false
	end

	return true
end

-- LibBench.server.clpp:175
function LibBench:BenchRosterClear(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	local i: number = 0

	while i < self.MID_ITERS do
		list:Push(i)
		i += 1
	end

	list:Clear()
	return list:IsEmpty()
end

-- LibBench.server.clpp:190
function LibBench:BenchRosterSlice(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	local i: number = 0

	while i < self.MID_ITERS do
		list:Push(i)
		i += 1
	end

	local sliced: Roster = list:Slice(1, 8)
	self.WorkSink = sliced:Length()
	return self.WorkSink > 0
end

-- LibBench.server.clpp:206
function LibBench:BenchRosterConcat(): boolean
	if not (self) then
		return false
	end

	local left: Roster = Roster.new()
	local right: Roster = Roster.new()
	left:Push(1)
	right:Push(2)
	local joined: Roster = left:Concat(right)
	self.WorkSink = joined:Length()
	return self.WorkSink >= 2
end

-- LibBench.server.clpp:220
function LibBench:BenchRosterUnique(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	list:Push(1)
	list:Push(1)
	list:Push(2)
	local unique: Roster = list:Unique()
	self.WorkSink = unique:Length()
	return self.WorkSink == 2
end

-- LibBench.server.clpp:234
function LibBench:BenchRosterReverse(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	list:Push(1)
	list:Push(2)
	list:Push(3)
	local reversed: Roster = list:Reverse()
	self.WorkSink = reversed:Length()
	return self.WorkSink == 3
end

-- LibBench.server.clpp:248
function LibBench:BenchRosterPopShift(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	list:Push(1)
	list:Push(2)
	list:Push(3)
	list:Pop()
	list:Shift()
	self.WorkSink = list:Length()
	return self.WorkSink == 1
end

-- LibBench.server.clpp:263
function LibBench:BenchRosterDeepClone(): boolean
	if not (self) then
		return false
	end

	local list: Roster = Roster.new()
	local i: number = 0

	while i < self.LIGHT_ITERS do
		list:Push(i)
		i += 1
	end

	local copy: Roster = list:DeepClone()
	self.WorkSink = copy:Length()
	return self.WorkSink == self.LIGHT_ITERS
end

-- LibBench.server.clpp:279
function LibBench:BenchRosterKeys(): boolean
	if not (self) then
		return false
	end

	local map: Roster = Roster.new()
	map:Set("hp", 100)
	map:Set("atk", 8)
	local keys: Roster = map:Keys()
	local values: Roster = map:Values()
	self.WorkSink = keys:Length() + values:Length()
	return self.WorkSink > 0
end

-- LibBench.server.clpp:293
function LibBench:BenchHiveSetGet(): boolean
	if not (self) then
		return false
	end

	local world = PlayerECS.New()
	local i: number = 1

	while i <= self.HOT_ITERS do
		world:Set(i, PlayerECS.Health, i)
		i += 1
	end

	local sum: number = 0
	i = 1

	while i <= self.HOT_ITERS do
		sum = sum + world:Get(i, PlayerECS.Health)
		i += 1
	end

	self.WorkSink = sum
	return sum > 0
end

-- LibBench.server.clpp:314
function LibBench:BenchHiveManyEntities(): boolean
	if not (self) then
		return false
	end

	local world = PlayerECS.New()
	local i: number = 1

	while i <= self.MID_ITERS do
		world:Set(i, PlayerECS.Fighter, i)
		world:Set(i, PlayerECS.Alive, 1)
		i += 1
	end

	self.WorkSink = i
	return true
end

-- LibBench.server.clpp:330
function LibBench:BenchHiveRemove(): boolean
	if not (self) then
		return false
	end

	local world = PlayerECS.New()
	local i: number = 1

	while i <= self.MID_ITERS do
		world:Set(i, PlayerECS.Combo, 1)
		world:Remove(i, PlayerECS.Combo)
		i += 1
	end

	self.WorkSink = i
	return true
end

-- LibBench.server.clpp:346
function LibBench:BenchHiveSnapshot(): boolean
	if not (self) then
		return false
	end

	local world = PlayerECS.New()
	local i: number = 1

	while i <= self.LIGHT_ITERS do
		world:Set(i, PlayerECS.Health, i)
		i += 1
	end

	local shot: buffer = world:Snapshot(PlayerECS.Health)

	if not (shot) then
		return false
	end

	return true
end

-- LibBench.server.clpp:364
function LibBench:BenchSweepAddDestroy(): boolean
	if not (self) then
		return false
	end

	local sweep: Sweep = Sweep.new()
	local i: number = 0

	while i < self.LIGHT_ITERS do
		local part: Part = Instance.new("Part")
		part.Name = "LibBenchPart"
		sweep:Add(part, "Destroy")
		i += 1
	end

	sweep:Cleanup()
	return true
end

-- LibBench.server.clpp:381
function LibBench:BenchSweepCleanup(): boolean
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

-- LibBench.server.clpp:398
function LibBench:BenchSparkFire(): boolean
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

-- LibBench.server.clpp:417
function LibBench:BenchSparkOnce(): boolean
	if not (self) then
		return false
	end

	self.SparkHits = 0
	local bus: Spark = Spark.new()
	bus:Once(function()
		self:OnSparkHit()
	end)

	bus:Fire()
	bus:Fire()
	bus:Destroy()
	return self.SparkHits == 1
end

-- LibBench.server.clpp:433
function LibBench:BenchSparkDisconnect(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	local bus: Spark = Spark.new()
	__janitor:Add(bus:Connect(function()
		self:OnSparkHit()
	end), "Disconnect")

	bus.DisconnectAll()
	bus:Fire()
	bus:Destroy()
	return true
end

-- LibBench.server.clpp:448
function LibBench:BenchWardAllow(): boolean
	if not (self) then
		return false
	end

	local player: Player = self:FirstPlayer()

	if not (player) then
		return true
	end

	local i: number = 0
	local allowed: number = 0

	while i < self.MID_ITERS do
		if Ward.Allow(player, "libbench", 120, 240) then
			allowed += 1
		end

		i += 1
	end

	self.WorkSink = allowed
	Ward.Clear(player)
	return allowed > 0
end

-- LibBench.server.clpp:471
function LibBench:BenchWardPacket(): boolean
	if not (self) then
		return false
	end

	local player: Player = self:FirstPlayer()

	if not (player) then
		return true
	end

	local ok: boolean = Ward.Packet(player, 64)
	local reject: boolean = not Ward.Packet(player, 999999)
	Ward.Clear(player)
	return ok and reject
end

-- LibBench.server.clpp:487
function LibBench:BenchWardGrace(): boolean
	if not (self) then
		return false
	end

	local player: Player = self:FirstPlayer()

	if not (player) then
		return true
	end

	Ward.Grace(player, 2)
	local strikes: number = Ward.Strikes(player)
	Ward.Clear(player)
	return strikes >= 0
end

-- LibBench.server.clpp:503
function LibBench:BenchAxiomScalar(): boolean
	if not (self) then
		return false
	end

	local acc: number = 0
	local i: number = 0

	while i < self.HOT_ITERS do
		acc = acc + Axiom.Clamp(i, 0, 100)
		acc = acc + Axiom.Map(i, 0, self.HOT_ITERS, 0, 1)
		i += 1
	end

	self.WorkSink = Axiom.Round(acc)
	return Axiom.IsFinite(acc)
end

-- LibBench.server.clpp:519
function LibBench:BenchAxiomLerp(): boolean
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

-- LibBench.server.clpp:534
function LibBench:BenchAxiomVector(): boolean
	if not (self) then
		return false
	end

	local a: Vector3 = Vector3.new(1, 0, 0)
	local b: Vector3 = Vector3.new(0, 1, 0)
	local acc: number = 0
	local i: number = 0

	while i < self.MID_ITERS do
		local mixed: Vector3 = Axiom.LerpVector3(a, b, 0.25)
		acc = acc + Axiom.Distance(a, mixed)
		i += 1
	end

	self.WorkSink = Axiom.Round(acc)
	return acc > 0
end

-- LibBench.server.clpp:552
function LibBench:BenchAxiomEase(): boolean
	if not (self) then
		return false
	end

	local acc: number = 0
	local i: number = 0

	while i < self.MID_ITERS do
		acc = acc + Axiom.InOutQuad(0.35)
		acc = acc + Axiom.OutCubic(0.35)
		i += 1
	end

	self.WorkSink = Axiom.Round(acc * 100)
	return acc > 0
end

-- LibBench.server.clpp:568
function LibBench:BenchAxiomNoise(): boolean
	if not (self) then
		return false
	end

	local acc: number = 0
	local i: number = 0

	while i < self.MID_ITERS do
		acc = acc + Axiom.Value1(i)
		i += 1
	end

	self.WorkSink = Axiom.Round(acc)
	return Axiom.IsFinite(acc)
end

-- LibBench.server.clpp:583
function LibBench:BenchAxiomWrap(): boolean
	if not (self) then
		return false
	end

	local acc: number = 0
	local i: number = 0

	while i < self.HOT_ITERS do
		acc = acc + Axiom.Wrap(i, 0, 10)
		acc = acc + Axiom.Saturate(i * 0.01)
		i += 1
	end

	self.WorkSink = Axiom.Round(acc)
	return Axiom.IsFinite(acc)
end

-- LibBench.server.clpp:599
function LibBench:BenchAxiomTrig(): boolean
	if not (self) then
		return false
	end

	local acc: number = 0
	local i: number = 0

	while i < self.MID_ITERS do
		acc = acc + Axiom.Sin(i)
		acc = acc + Axiom.Cos(i)
		i += 1
	end

	self.WorkSink = Axiom.Round(acc)
	return Axiom.IsFinite(acc)
end

-- LibBench.server.clpp:615
function LibBench:BenchAxiomGeometry(): boolean
	if not (self) then
		return false
	end

	local point: Vector3 = Vector3.new(1, 1, 1)
	local min: Vector3 = Vector3.new(0, 0, 0)
	local max: Vector3 = Vector3.new(2, 2, 2)
	local i: number = 0
	local hits: number = 0

	while i < self.MID_ITERS do
		if Axiom.AabbContains(point, min, max) then
			hits += 1
		end

		if Axiom.SphereContains(point, Vector3.new(0, 0, 0), 4) then
			hits += 1
		end

		i += 1
	end

	self.WorkSink = hits
	return hits > 0
end

-- LibBench.server.clpp:638
function LibBench:BenchAxiomColor(): boolean
	if not (self) then
		return false
	end

	local mixed: Color3 = Axiom.FromHSV(0.5, 1, 1)
	local other: Color3 = Axiom.LerpColor3(mixed, Color3.new(1, 1, 1), 0.25)

	if not (other) then
		return false
	end

	return true
end

-- LibBench.server.clpp:651
function LibBench:BenchMintCompact(): boolean
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

-- LibBench.server.clpp:668
function LibBench:BenchMintGroup(): boolean
	if not (self) then
		return false
	end

	local last: string = Mint.Group(1234567)
	local pct: string = Mint.Percent(0.25)

	if not (last and pct) then
		return false
	end

	return true
end

-- LibBench.server.clpp:681
function LibBench:BenchMintFrom(): boolean
	if not (self) then
		return false
	end

	local value: number = Mint.From("12.5K")
	self.WorkSink = Axiom.Round(value)
	return value > 0
end

-- LibBench.server.clpp:691
function LibBench:BenchMintScientific(): boolean
	if not (self) then
		return false
	end

	local last: string = Mint.Scientific(1234567)

	if not (last) then
		return false
	end

	return true
end

-- LibBench.server.clpp:703
function LibBench:BenchMintComma(): boolean
	if not (self) then
		return false
	end

	local last: string = Mint.Comma(1234567)

	if not (last) then
		return false
	end

	return true
end

-- LibBench.server.clpp:715
function LibBench:BenchCoilStep(): boolean
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

-- LibBench.server.clpp:734
function LibBench:BenchCoilVector(): boolean
	if not (self) then
		return false
	end

	local spring: Coil = Coil.Vector(0.7, 6, Vector3.new(0, 0, 0))
	spring:Set(Vector3.new(10, 2, 0))
	local i: number = 0

	while i < self.LIGHT_ITERS do
		spring.Step(0.016)
		i += 1
	end

	return true
end

-- LibBench.server.clpp:749
function LibBench:BenchCoilImpulse(): boolean
	if not (self) then
		return false
	end

	local spring: Coil = Coil.new(1, 8, 0)
	spring.Impulse(12)
	spring.Step(0.016)
	return true
end

-- LibBench.server.clpp:760
function LibBench:BenchCoilColor(): boolean
	if not (self) then
		return false
	end

	local spring: Coil = Coil.Color(0.8, 6, Color3.new(0, 0, 0))
	spring:Set(Color3.new(1, 0.2, 0.2))
	spring.Step(0.016)
	return true
end

-- LibBench.server.clpp:771
function LibBench:BenchTraceDisplay(): boolean
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

-- LibBench.server.clpp:786
function LibBench:BenchTraceBuilder(): boolean
	if not (self) then
		return false
	end

	local builder: TraceBuilder = Trace.builder()
	builder.MaxDepth(4)
	local dump: string = builder.Display(1)

	if not (dump) then
		return false
	end

	return true
end

-- LibBench.server.clpp:800
function LibBench:BenchArrayIndexer(): boolean
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

-- LibBench.server.clpp:817
function LibBench:BenchArrayIndexerRelease(): boolean
	if not (self) then
		return false
	end

	local indexer: ArrayIndexer = ArrayIndexer.New()
	local i: number = 0

	while i < self.MID_ITERS do
		local id: number = indexer:Acquire()
		indexer:Release(id)
		i += 1
	end

	return true
end

-- LibBench.server.clpp:832
function LibBench:BenchPromiseResolve(): boolean
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

-- LibBench.server.clpp:849
function LibBench:BenchPromiseReject(): boolean
	if not (self) then
		return false
	end

	local job: Promise = Promise.reject("libbench")
	job:Catch(function()
		self:OnPromiseFail()
	end)

	return true
end

-- LibBench.server.clpp:861
function LibBench:BenchFlareCursor(): boolean
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

-- LibBench.server.clpp:878
function LibBench:BenchFlareWriteTypes(): boolean
	if not (self) then
		return false
	end

	local i: number = 0

	while i < self.MID_ITERS do
		local cursor = Flare.cursor(96)
		Flare.writeu8(cursor, 1)
		Flare.writei32(cursor, i)
		Flare.writef32(cursor, 1.5)
		Flare.writebool(cursor, true)
		Flare.writestring(cursor, "x")
		Flare.writeVector3(cursor, Vector3.new(1, 2, 3))
		i += 1
	end

	self.WorkSink = i
	return true
end

-- LibBench.server.clpp:898
function LibBench:BenchNetEvent(): boolean
	if not (self) then
		return false
	end

	local bus: NetEvent = Net.Event("LibBenchPing")

	if not (bus) then
		return false
	end

	return true
end

-- LibBench.server.clpp:910
function LibBench:BenchNetFunction(): boolean
	if not (self) then
		return false
	end

	local remote: NetFunction = Net.Function("LibBenchQuery")

	if not (remote) then
		return false
	end

	return true
end

-- LibBench.server.clpp:922
function LibBench:BenchKeepWait(): boolean
	if not (self) then
		return false
	end

	local player: Player = self:FirstPlayer()

	if not (player) then
		return true
	end

	local data = Keep.Server:Get(player)

	if not (data) then
		return true
	end

	return true
end

-- LibBench.server.clpp:939
function LibBench:BenchPartCreateDestroy(): boolean
	if not (self) then
		return false
	end

	local i: number = 0

	while i < self.LIGHT_ITERS do
		local part: Part = Instance.new("Part")
		part.Name = "LibBenchTemp"
		part:Destroy()
		i += 1
	end

	return true
end

-- LibBench.server.clpp:954
function LibBench:BenchEchoCFrame(): boolean
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

-- LibBench.server.clpp:972
function LibBench:BenchEmberScale(): boolean
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

-- LibBench.server.clpp:988
function LibBench:BenchHelmRegistry(): boolean
	if not (self) then
		return false
	end

	local registry: HelmRegistry = Helm.Registry()

	if not (registry) then
		return false
	end

	return true
end

-- LibBench.server.clpp:1000
function LibBench:BenchLensWindow(): boolean
	if not (self) then
		return false
	end

	Lens.Window("LibBench", function()
		self:OnLensDraw()
	end)

	return true
end

-- LibBench.server.clpp:1011
function LibBench:BenchGleamSource(): boolean
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

-- LibBench.server.clpp:1026
function LibBench:BenchOccludePosition(): boolean
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

-- LibBench.server.clpp:1041
function LibBench:BenchGuideStart(): boolean
	if not (self) then
		return false
	end

	Guide.Start()
	return true
end

-- LibBench.server.clpp:1050
function LibBench:RunAll(): boolean
	if not (self) then
		return false
	end

	local started: number = tick()
	local t: number = 0
	t = tick()
	self:Report("RosterPush", t, self:BenchRosterPush())
	t = tick()
	self:Report("RosterSetGet", t, self:BenchRosterSetGet())
	t = tick()
	self:Report("RosterFind", t, self:BenchRosterFind())
	t = tick()
	self:Report("RosterHas", t, self:BenchRosterHas())
	t = tick()
	self:Report("RosterClone", t, self:BenchRosterClone())
	t = tick()
	self:Report("RosterPack", t, self:BenchRosterPack())
	t = tick()
	self:Report("RosterClear", t, self:BenchRosterClear())
	t = tick()
	self:Report("RosterSlice", t, self:BenchRosterSlice())
	t = tick()
	self:Report("RosterConcat", t, self:BenchRosterConcat())
	t = tick()
	self:Report("RosterUnique", t, self:BenchRosterUnique())
	t = tick()
	self:Report("RosterReverse", t, self:BenchRosterReverse())
	t = tick()
	self:Report("RosterPopShift", t, self:BenchRosterPopShift())
	t = tick()
	self:Report("RosterDeepClone", t, self:BenchRosterDeepClone())
	t = tick()
	self:Report("RosterKeys", t, self:BenchRosterKeys())
	t = tick()
	self:Report("HiveSetGet", t, self:BenchHiveSetGet())
	t = tick()
	self:Report("HiveManyEntities", t, self:BenchHiveManyEntities())
	t = tick()
	self:Report("HiveRemove", t, self:BenchHiveRemove())
	t = tick()
	self:Report("HiveSnapshot", t, self:BenchHiveSnapshot())
	t = tick()
	self:Report("SweepAddDestroy", t, self:BenchSweepAddDestroy())
	t = tick()
	self:Report("SweepCleanup", t, self:BenchSweepCleanup())
	t = tick()
	self:Report("SparkFire", t, self:BenchSparkFire())
	t = tick()
	self:Report("SparkOnce", t, self:BenchSparkOnce())
	t = tick()
	self:Report("SparkDisconnect", t, self:BenchSparkDisconnect())
	t = tick()
	self:Report("WardAllow", t, self:BenchWardAllow())
	t = tick()
	self:Report("WardPacket", t, self:BenchWardPacket())
	t = tick()
	self:Report("WardGrace", t, self:BenchWardGrace())
	t = tick()
	self:Report("AxiomScalar", t, self:BenchAxiomScalar())
	t = tick()
	self:Report("AxiomLerp", t, self:BenchAxiomLerp())
	t = tick()
	self:Report("AxiomVector", t, self:BenchAxiomVector())
	t = tick()
	self:Report("AxiomEase", t, self:BenchAxiomEase())
	t = tick()
	self:Report("AxiomNoise", t, self:BenchAxiomNoise())
	t = tick()
	self:Report("AxiomWrap", t, self:BenchAxiomWrap())
	t = tick()
	self:Report("AxiomTrig", t, self:BenchAxiomTrig())
	t = tick()
	self:Report("AxiomGeometry", t, self:BenchAxiomGeometry())
	t = tick()
	self:Report("AxiomColor", t, self:BenchAxiomColor())
	t = tick()
	self:Report("MintCompact", t, self:BenchMintCompact())
	t = tick()
	self:Report("MintGroup", t, self:BenchMintGroup())
	t = tick()
	self:Report("MintFrom", t, self:BenchMintFrom())
	t = tick()
	self:Report("MintScientific", t, self:BenchMintScientific())
	t = tick()
	self:Report("MintComma", t, self:BenchMintComma())
	t = tick()
	self:Report("CoilStep", t, self:BenchCoilStep())
	t = tick()
	self:Report("CoilVector", t, self:BenchCoilVector())
	t = tick()
	self:Report("CoilImpulse", t, self:BenchCoilImpulse())
	t = tick()
	self:Report("CoilColor", t, self:BenchCoilColor())
	t = tick()
	self:Report("TraceDisplay", t, self:BenchTraceDisplay())
	t = tick()
	self:Report("TraceBuilder", t, self:BenchTraceBuilder())
	t = tick()
	self:Report("ArrayIndexer", t, self:BenchArrayIndexer())
	t = tick()
	self:Report("ArrayIndexerRelease", t, self:BenchArrayIndexerRelease())
	t = tick()
	self:Report("PromiseResolve", t, self:BenchPromiseResolve())
	t = tick()
	self:Report("PromiseReject", t, self:BenchPromiseReject())
	t = tick()
	self:Report("FlareCursor", t, self:BenchFlareCursor())
	t = tick()
	self:Report("FlareWriteTypes", t, self:BenchFlareWriteTypes())
	t = tick()
	self:Report("NetEvent", t, self:BenchNetEvent())
	t = tick()
	self:Report("NetFunction", t, self:BenchNetFunction())
	t = tick()
	self:Report("KeepWait", t, self:BenchKeepWait())
	t = tick()
	self:Report("PartCreateDestroy", t, self:BenchPartCreateDestroy())
	t = tick()
	self:Report("EchoCFrame", t, self:BenchEchoCFrame())
	t = tick()
	self:Report("EmberScale", t, self:BenchEmberScale())
	t = tick()
	self:Report("HelmRegistry", t, self:BenchHelmRegistry())
	t = tick()
	self:Report("LensWindow", t, self:BenchLensWindow())
	t = tick()
	self:Report("GleamSource", t, self:BenchGleamSource())
	t = tick()
	self:Report("OccludePosition", t, self:BenchOccludePosition())
	t = tick()
	self:Report("GuideStart", t, self:BenchGuideStart())
	self:Report("TOTAL", started, true)
	return true
end

-- LibBench.server.clpp:1188
const function init()
	local runService: RunService = game:GetService("RunService")

	if not (runService:IsStudio()) then
		return
	end

	task.spawn(function()
		task.wait(1)
		LibBench:RunAll()
	end)
end

init()
