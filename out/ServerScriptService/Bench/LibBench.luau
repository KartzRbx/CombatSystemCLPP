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

export type LibBench = {
	HOT_ITERS: number,
	MID_ITERS: number,
	LIGHT_ITERS: number,
	players: Players,
	SparkHits: number,
	WorkSink: number,
	RunAll: (self: LibBench) -> boolean,
	Report: (self: LibBench, name: string, started: number, ok: boolean) -> boolean,
	OnSparkHit: (self: LibBench) -> boolean,
	OnPromiseFail: (self: LibBench) -> boolean,
	OnLensDraw: (self: LibBench) -> boolean,
	FirstPlayer: (self: LibBench) -> Player,
	BenchRosterPush: (self: LibBench) -> boolean,
	BenchRosterSetGet: (self: LibBench) -> boolean,
	BenchRosterFind: (self: LibBench) -> boolean,
	BenchRosterHas: (self: LibBench) -> boolean,
	BenchRosterClone: (self: LibBench) -> boolean,
	BenchRosterPack: (self: LibBench) -> boolean,
	BenchRosterClear: (self: LibBench) -> boolean,
	BenchRosterSlice: (self: LibBench) -> boolean,
	BenchRosterConcat: (self: LibBench) -> boolean,
	BenchRosterUnique: (self: LibBench) -> boolean,
	BenchRosterReverse: (self: LibBench) -> boolean,
	BenchRosterPopShift: (self: LibBench) -> boolean,
	BenchRosterDeepClone: (self: LibBench) -> boolean,
	BenchRosterKeys: (self: LibBench) -> boolean,
	BenchHiveSetGet: (self: LibBench) -> boolean,
	BenchHiveManyEntities: (self: LibBench) -> boolean,
	BenchHiveRemove: (self: LibBench) -> boolean,
	BenchHiveSnapshot: (self: LibBench) -> boolean,
	BenchSweepAddDestroy: (self: LibBench) -> boolean,
	BenchSweepCleanup: (self: LibBench) -> boolean,
	BenchSparkFire: (self: LibBench) -> boolean,
	BenchSparkOnce: (self: LibBench) -> boolean,
	BenchSparkDisconnect: (self: LibBench) -> boolean,
	BenchWardAllow: (self: LibBench) -> boolean,
	BenchWardPacket: (self: LibBench) -> boolean,
	BenchWardGrace: (self: LibBench) -> boolean,
	BenchAxiomScalar: (self: LibBench) -> boolean,
	BenchAxiomLerp: (self: LibBench) -> boolean,
	BenchAxiomVector: (self: LibBench) -> boolean,
	BenchAxiomEase: (self: LibBench) -> boolean,
	BenchAxiomNoise: (self: LibBench) -> boolean,
	BenchAxiomWrap: (self: LibBench) -> boolean,
	BenchAxiomTrig: (self: LibBench) -> boolean,
	BenchAxiomGeometry: (self: LibBench) -> boolean,
	BenchAxiomColor: (self: LibBench) -> boolean,
	BenchMintCompact: (self: LibBench) -> boolean,
	BenchMintGroup: (self: LibBench) -> boolean,
	BenchMintFrom: (self: LibBench) -> boolean,
	BenchMintScientific: (self: LibBench) -> boolean,
	BenchMintComma: (self: LibBench) -> boolean,
	BenchCoilStep: (self: LibBench) -> boolean,
	BenchCoilVector: (self: LibBench) -> boolean,
	BenchCoilImpulse: (self: LibBench) -> boolean,
	BenchCoilColor: (self: LibBench) -> boolean,
	BenchTraceDisplay: (self: LibBench) -> boolean,
	BenchTraceBuilder: (self: LibBench) -> boolean,
	BenchArrayIndexer: (self: LibBench) -> boolean,
	BenchArrayIndexerRelease: (self: LibBench) -> boolean,
	BenchPromiseResolve: (self: LibBench) -> boolean,
	BenchPromiseReject: (self: LibBench) -> boolean,
	BenchFlareCursor: (self: LibBench) -> boolean,
	BenchFlareWriteTypes: (self: LibBench) -> boolean,
	BenchNetEvent: (self: LibBench) -> boolean,
	BenchNetFunction: (self: LibBench) -> boolean,
	BenchKeepWait: (self: LibBench) -> boolean,
	BenchPartCreateDestroy: (self: LibBench) -> boolean,
	BenchEchoCFrame: (self: LibBench) -> boolean,
	BenchEmberScale: (self: LibBench) -> boolean,
	BenchHelmRegistry: (self: LibBench) -> boolean,
	BenchLensWindow: (self: LibBench) -> boolean,
	BenchGleamSource: (self: LibBench) -> boolean,
	BenchOccludePosition: (self: LibBench) -> boolean,
	BenchGuideStart: (self: LibBench) -> boolean,
}

const function LibBench()
	return {
		HOT_ITERS = 2500,
		MID_ITERS = 400,
		LIGHT_ITERS = 80,
		players = game:GetService("Players"),
		SparkHits = 0,
		WorkSink = 0,
	}
end

return LibBench
