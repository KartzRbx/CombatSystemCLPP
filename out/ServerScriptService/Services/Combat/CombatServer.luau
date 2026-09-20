--!nonstrict
-- Compiled by CL++ — C++ × Luau

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Ward = require(ReplicatedStorage.CluauppLibs.Ward)

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const Hive = require(ReplicatedStorage.CluauppLibs.Hive)
const Roster = require(ReplicatedStorage.CluauppLibs.Roster)
const PlayerECS = require(ReplicatedStorage.Shared.Services.Combat.PlayerECS)
const Net = require(ReplicatedStorage.Shared.Net.Net)

export type CombatServer = {
	players: Players,
	World: any,
	Entities: Roster,
	NextEntity: number,
	HITBOX_OFFSET: number,
	ATTACK_INTERVAL: number,
	COMBO_WINDOW: number,
	HITBOX_LIFE: number,
	HITBOX_WIDTH: number,
	HITBOX_HEIGHT: number,
	HITBOX_DEPTH: number,
	HITBOX_FORWARD: number,
	HITBOX_TRANSPARENCY: number,
	HITBOX_COLOR_R: number,
	HITBOX_COLOR_G: number,
	HITBOX_COLOR_B: number,
	MAX_COMBO: number,
	MAX_HEALTH: number,
	BASE_DAMAGE: number,
	COMBO_DAMAGE: number,
	ATTACK_RATE: number,
	ATTACK_BURST: number,
	ATTACK_CHANNEL: string,
	HITBOX_NAME: string,
	BindPlayerSessions: (self: CombatServer) -> boolean,
	BindCombatRemotes: (self: CombatServer) -> boolean,
	RegisterFighter: (self: CombatServer, player: Player) -> boolean,
	UnregisterFighter: (self: CombatServer, player: Player) -> boolean,
	OnCharacterSpawned: (self: CombatServer, player: Player, character: Model) -> boolean,
	OnReady: (self: CombatServer, player: Player) -> boolean,
	OnAttack: (self: CombatServer, player: Player) -> boolean,
	EnsureFighterEntity: (self: CombatServer, player: Player) -> number,
	SeedFighter: (self: CombatServer, fighterEntity: number, player: Player) -> boolean,
	ClearFighter: (self: CombatServer, fighterEntity: number) -> boolean,
	IsFighterAlive: (self: CombatServer, fighterEntity: number) -> boolean,
	CanAcceptAttack: (self: CombatServer, attacker: Player, fighterEntity: number) -> boolean,
	AdvanceCombo: (self: CombatServer, fighterEntity: number, now: number) -> number,
	SpawnHitbox: (self: CombatServer, attacker: Player, attackerEntity: number) -> boolean,
	ComposeHitboxCFrame: (self: CombatServer, rootPart: BasePart) -> CFrame,
	CreateHitboxPart: (self: CombatServer, rootPart: BasePart) -> Part,
	BindHitboxTouched: (self: CombatServer, hitbox: Part, attacker: Player, attackerCharacter: Model, attackerEntity: number, struckPlayers: Roster) -> boolean,
	ScheduleHitboxDestroy: (self: CombatServer, hitbox: Part) -> boolean,
	OnHitboxTouched: (self: CombatServer, hitPart: BasePart, attacker: Player, attackerCharacter: Model, attackerEntity: number, struckPlayers: Roster) -> boolean,
	ResolveVictim: (self: CombatServer, hitPart: BasePart, attackerCharacter: Model) -> Player,
	TryMarkStruck: (self: CombatServer, struckPlayers: Roster, victim: Player) -> boolean,
	ApplyHit: (self: CombatServer, attacker: Player, victim: Player, comboStage: number) -> boolean,
	ComputeDamage: (self: CombatServer, attacker: Player, comboStage: number) -> number,
	ReadBonusDamage: (self: CombatServer, attacker: Player) -> number,
	SyncVictimHumanoid: (self: CombatServer, victim: Player, currentHealth: number) -> boolean,
	BroadcastHit: (self: CombatServer, attacker: Player, victim: Player, damage: number, comboStage: number) -> boolean,
}

const function CombatServer()
	return {
		players = game:GetService("Players"),
		World = PlayerECS.New(),
		Entities = Roster.new(),
		NextEntity = 1,
		HITBOX_OFFSET = -3,
		ATTACK_INTERVAL = 0.45,
		COMBO_WINDOW = 1.2,
		HITBOX_LIFE = 0.18,
		HITBOX_WIDTH = 5,
		HITBOX_HEIGHT = 6,
		HITBOX_DEPTH = 4,
		HITBOX_FORWARD = -3.2,
		HITBOX_TRANSPARENCY = 0.55,
		HITBOX_COLOR_R = 1,
		HITBOX_COLOR_G = 0.25,
		HITBOX_COLOR_B = 0.2,
		MAX_COMBO = 4,
		MAX_HEALTH = 100,
		BASE_DAMAGE = 8,
		COMBO_DAMAGE = 3,
		ATTACK_RATE = 6,
		ATTACK_BURST = 10,
		ATTACK_CHANNEL = "attack",
		HITBOX_NAME = "CombatHitbox",
	}
end

return CombatServer
