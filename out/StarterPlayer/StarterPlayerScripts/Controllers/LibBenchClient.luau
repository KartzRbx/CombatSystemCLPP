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

export type LibBenchClient = {
	HOT_ITERS: number,
	MID_ITERS: number,
	LIGHT_ITERS: number,
	players: Players,
	me: Player,
	SparkHits: number,
	WorkSink: number,
	RunAll: (self: LibBenchClient) -> boolean,
	Report: (self: LibBenchClient, name: string, started: number, ok: boolean) -> boolean,
	OnSparkHit: (self: LibBenchClient) -> boolean,
	OnLensDraw: (self: LibBenchClient) -> boolean,
	OnGleamEffect: (self: LibBenchClient) -> boolean,
	BenchGleamSource: (self: LibBenchClient) -> boolean,
	BenchGleamCreate: (self: LibBenchClient) -> boolean,
	BenchGleamMount: (self: LibBenchClient) -> boolean,
	BenchGleamSpring: (self: LibBenchClient) -> boolean,
	BenchBloomPlay: (self: LibBenchClient) -> boolean,
	BenchBloomFade: (self: LibBenchClient) -> boolean,
	BenchBloomPress: (self: LibBenchClient) -> boolean,
	BenchPinCreate: (self: LibBenchClient) -> boolean,
	BenchStageAttach: (self: LibBenchClient) -> boolean,
	BenchCrestCreate: (self: LibBenchClient) -> boolean,
	BenchLensInit: (self: LibBenchClient) -> boolean,
	BenchLensWindow: (self: LibBenchClient) -> boolean,
	BenchEmberScale: (self: LibBenchClient) -> boolean,
	BenchEchoCFrame: (self: LibBenchClient) -> boolean,
	BenchGuideStart: (self: LibBenchClient) -> boolean,
	BenchOccludePosition: (self: LibBenchClient) -> boolean,
	BenchHelmRegistry: (self: LibBenchClient) -> boolean,
	BenchMintCompact: (self: LibBenchClient) -> boolean,
	BenchAxiomLerp: (self: LibBenchClient) -> boolean,
	BenchCoilStep: (self: LibBenchClient) -> boolean,
	BenchRosterPush: (self: LibBenchClient) -> boolean,
	BenchSparkFire: (self: LibBenchClient) -> boolean,
	BenchSweepCleanup: (self: LibBenchClient) -> boolean,
	BenchPromiseResolve: (self: LibBenchClient) -> boolean,
	BenchFlareCursor: (self: LibBenchClient) -> boolean,
	BenchArrayIndexer: (self: LibBenchClient) -> boolean,
	BenchKeepClient: (self: LibBenchClient) -> boolean,
	BenchNetEvent: (self: LibBenchClient) -> boolean,
	BenchTraceDisplay: (self: LibBenchClient) -> boolean,
}

const function LibBenchClient()
	return {
		HOT_ITERS = 2500,
		MID_ITERS = 400,
		LIGHT_ITERS = 80,
		players = game:GetService("Players"),
		me = nil,
		SparkHits = 0,
		WorkSink = 0,
	}
end

return LibBenchClient
