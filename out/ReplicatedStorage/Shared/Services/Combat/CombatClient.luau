--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

export type CombatClient = {
	players: Players,
	me: Player,
	ATTACK_INTERVAL: number,
	LOCAL_HITBOX_LIFE: number,
	HITBOX_WIDTH: number,
	HITBOX_HEIGHT: number,
	HITBOX_DEPTH: number,
	HITBOX_FORWARD: number,
	HITBOX_TRANSPARENCY: number,
	HITBOX_COLOR_R: number,
	HITBOX_COLOR_G: number,
	HITBOX_COLOR_B: number,
	MAX_COMBO: number,
	LOCAL_HITBOX_NAME: string,
	ComboStage: number,
	LastHit: number,
	EntityId: number,
	Health: number,
	SetupPlayerCombat: (self: CombatClient) -> boolean,
	BindCharacter: (self: CombatClient) -> boolean,
	BindCombatInput: (self: CombatClient) -> boolean,
	BindCombatNet: (self: CombatClient) -> boolean,
	OnCharacterSpawned: (self: CombatClient, character: Model) -> boolean,
	IsAttackInput: (self: CombatClient, input: InputObject, gameProcessed: boolean) -> boolean,
	OnAttackInput: (self: CombatClient, input: InputObject, gameProcessed: boolean) -> boolean,
	OnCombatHello: (self: CombatClient, entityId: number, health: number) -> boolean,
	OnHitReceived: (self: CombatClient, attacker: Player, victim: Player, damage: number, comboStage: number) -> boolean,
	SendAttack: (self: CombatClient) -> boolean,
	SpawnLocalHitbox: (self: CombatClient) -> boolean,
	ComposeHitboxCFrame: (self: CombatClient, rootPart: BasePart) -> CFrame,
	CreateLocalHitboxPart: (self: CombatClient, rootPart: BasePart) -> Part,
}

const function CombatClient()
	return {
		players = game:GetService("Players"),
		me = nil,
		ATTACK_INTERVAL = 0.45,
		LOCAL_HITBOX_LIFE = 0.16,
		HITBOX_WIDTH = 5,
		HITBOX_HEIGHT = 6,
		HITBOX_DEPTH = 4,
		HITBOX_FORWARD = -3.2,
		HITBOX_TRANSPARENCY = 0.7,
		HITBOX_COLOR_R = 1,
		HITBOX_COLOR_G = 0.45,
		HITBOX_COLOR_B = 0.2,
		MAX_COMBO = 4,
		LOCAL_HITBOX_NAME = "CombatHitboxLocal",
		ComboStage = 0,
		LastHit = 0,
		EntityId = 0,
		Health = 100,
	}
end

return CombatClient
