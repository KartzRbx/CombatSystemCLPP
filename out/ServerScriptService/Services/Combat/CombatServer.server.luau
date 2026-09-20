--!nonstrict
-- Compiled by CL++ — C++ × Luau

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Ward = require(ReplicatedStorage.CluauppLibs.Ward)

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const Hive = require(ReplicatedStorage.CluauppLibs.Hive)
const Janitor = require(ReplicatedStorage.CluauppLibs.Sweep)
const Keep = require(ReplicatedStorage.CluauppLibs.Keep)
const Roster = require(ReplicatedStorage.CluauppLibs.Roster)
const PlayerECS = require(ReplicatedStorage.Shared.Services.Combat.PlayerECS)
const Net = require(ReplicatedStorage.Shared.Net.Net)

local CombatServer = {}
CombatServer.players = game:GetService("Players")
CombatServer.World = PlayerECS.New()
CombatServer.Entities = Roster.new()
CombatServer.NextEntity = 1
CombatServer.HITBOX_OFFSET = -3
CombatServer.ATTACK_INTERVAL = 0.45
CombatServer.COMBO_WINDOW = 1.2
CombatServer.HITBOX_LIFE = 0.18
CombatServer.HITBOX_WIDTH = 5
CombatServer.HITBOX_HEIGHT = 6
CombatServer.HITBOX_DEPTH = 4
CombatServer.HITBOX_FORWARD = -3.2
CombatServer.HITBOX_TRANSPARENCY = 0.55
CombatServer.HITBOX_COLOR_R = 1
CombatServer.HITBOX_COLOR_G = 0.25
CombatServer.HITBOX_COLOR_B = 0.2
CombatServer.MAX_COMBO = 4
CombatServer.MAX_HEALTH = 100
CombatServer.BASE_DAMAGE = 8
CombatServer.COMBO_DAMAGE = 3
CombatServer.ATTACK_RATE = 6
CombatServer.ATTACK_BURST = 10
CombatServer.ATTACK_CHANNEL = "attack"
CombatServer.HITBOX_NAME = "CombatHitbox"

-- CombatServer.server.clpp:7
function CombatServer:BindPlayerSessions(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	for _, player in self.players:GetPlayers() do
		self:RegisterFighter(player)
	end

	__janitor:Add(self.players.PlayerAdded:Connect(function(player: Player)
		self:RegisterFighter(player)
	end), "Disconnect")

	__janitor:Add(self.players.PlayerRemoving:Connect(function(player: Player)
		self:UnregisterFighter(player)
	end), "Disconnect")

	return true
end

-- CombatServer.server.clpp:26
function CombatServer:BindCombatRemotes(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(Net.AttackIntent:Connect(function(player: Player)
		self:OnAttack(player)
	end), "Disconnect")

	__janitor:Add(Net.CombatReady:Connect(function(player: Player)
		self:OnReady(player)
	end), "Disconnect")

	return true
end

-- CombatServer.server.clpp:41
function CombatServer:EnsureFighterEntity(player: Player): number
	if not (self and player) then
		return 0
	end

	local fighterEntity: number = self.Entities:Get(player)

	if not fighterEntity then
		fighterEntity = self.NextEntity
		self.NextEntity += 1
		self.Entities:Set(player, fighterEntity)
	end

	return fighterEntity
end

-- CombatServer.server.clpp:55
function CombatServer:SeedFighter(fighterEntity: number, player: Player): boolean
	if not (self and fighterEntity and player) then
		return false
	end

	self.World:Set(fighterEntity, PlayerECS.Fighter, player.UserId)
	self.World:Set(fighterEntity, PlayerECS.Health, self.MAX_HEALTH)
	self.World:Set(fighterEntity, PlayerECS.Cooldown, 0)
	self.World:Set(fighterEntity, PlayerECS.Combo, 0)
	self.World:Set(fighterEntity, PlayerECS.Alive, 1)
	return true
end

-- CombatServer.server.clpp:68
function CombatServer:ClearFighter(fighterEntity: number): boolean
	if not (self and fighterEntity) then
		return false
	end

	self.World:Remove(fighterEntity, PlayerECS.Fighter)
	self.World:Remove(fighterEntity, PlayerECS.Health)
	self.World:Remove(fighterEntity, PlayerECS.Cooldown)
	self.World:Remove(fighterEntity, PlayerECS.Combo)
	self.World:Remove(fighterEntity, PlayerECS.Alive)
	return true
end

-- CombatServer.server.clpp:81
function CombatServer:IsFighterAlive(fighterEntity: number): boolean
	if not (self and fighterEntity) then
		return false
	end

	local aliveFlag: number = self.World:Get(fighterEntity, PlayerECS.Alive)

	if not aliveFlag then
		return false
	end

	return true
end

-- CombatServer.server.clpp:93
function CombatServer:OnCharacterSpawned(player: Player, character: Model): boolean
	if not (self and player and character) then
		return false
	end

	local fighterEntity: number = self.Entities:Get(player)

	if not (fighterEntity) then
		return false
	end

	self.World:Set(fighterEntity, PlayerECS.Health, self.MAX_HEALTH)
	self.World:Set(fighterEntity, PlayerECS.Alive, 1)
	self.World:Set(fighterEntity, PlayerECS.Combo, 0)
	return true
end

-- CombatServer.server.clpp:109
function CombatServer:RegisterFighter(player: Player): boolean
	if not (self and player) then
		return false
	end

	local __janitor = Janitor.new()
	__janitor:LinkToInstance(player)
	local fighterEntity: number = self:EnsureFighterEntity(player)
	self:SeedFighter(fighterEntity, player)
	__janitor:Add(player.CharacterAdded:Connect(function(character: Model)
		self:OnCharacterSpawned(player, character)
	end), "Disconnect")

	return true
end

-- CombatServer.server.clpp:123
function CombatServer:UnregisterFighter(player: Player): boolean
	if not (self and player) then
		return false
	end

	local fighterEntity: number = self.Entities:Get(player)

	if not (fighterEntity) then
		return false
	end

	self:ClearFighter(fighterEntity)
	self.Entities:Set(player, 0)
	return true
end

-- CombatServer.server.clpp:138
function CombatServer:OnReady(player: Player): boolean
	if not (self and player) then
		return false
	end

	if not self.Entities:Get(player) then
		self:RegisterFighter(player)
	end

	local fighterEntity: number = self.Entities:Get(player)
	local currentHealth: number = self.World:Get(fighterEntity, PlayerECS.Health)
	Net.CombatHello:Fire(player, fighterEntity, currentHealth)
	return true
end

-- CombatServer.server.clpp:153
function CombatServer:CanAcceptAttack(attacker: Player, fighterEntity: number): boolean
	if not (self and attacker and fighterEntity) then
		return false
	end

	if not (Ward.Allow(attacker, self.ATTACK_CHANNEL, self.ATTACK_RATE, self.ATTACK_BURST)) then
		return false
	end

	if not (self:IsFighterAlive(fighterEntity)) then
		return false
	end

	local now: number = tick()
	local lastHit: number = self.World:Get(fighterEntity, PlayerECS.Cooldown)

	if not lastHit then
		lastHit = 0
	end

	return now - lastHit >= self.ATTACK_INTERVAL
end

-- CombatServer.server.clpp:172
function CombatServer:AdvanceCombo(fighterEntity: number, now: number): number
	if not (self and fighterEntity) then
		return 1
	end

	local lastHit: number = self.World:Get(fighterEntity, PlayerECS.Cooldown)

	if not lastHit then
		lastHit = 0
	end

	local comboStage: number = self.World:Get(fighterEntity, PlayerECS.Combo)

	if not comboStage then
		comboStage = 0
	end

	if now - lastHit > self.COMBO_WINDOW then
		comboStage = 0
	end

	comboStage = comboStage + 1

	if comboStage > self.MAX_COMBO then
		comboStage = 1
	end

	self.World:Set(fighterEntity, PlayerECS.Cooldown, now)
	self.World:Set(fighterEntity, PlayerECS.Combo, comboStage)
	return comboStage
end

-- CombatServer.server.clpp:200
function CombatServer:ComposeHitboxCFrame(rootPart: BasePart): CFrame
	return rootPart.CFrame * CFrame.new(0, 0, self.HITBOX_FORWARD)
end

-- CombatServer.server.clpp:204
function CombatServer:CreateHitboxPart(rootPart: BasePart): Part
	local hitbox: Part = Instance.new("Part")
	hitbox.Parent = workspace
	hitbox.Name = self.HITBOX_NAME
	hitbox.Size = Vector3.new(self.HITBOX_WIDTH, self.HITBOX_HEIGHT, self.HITBOX_DEPTH)
	hitbox.CFrame = self:ComposeHitboxCFrame(rootPart)
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = true
	hitbox.Massless = true
	hitbox.Transparency = self.HITBOX_TRANSPARENCY
	hitbox.Color = Color3.new(self.HITBOX_COLOR_R, self.HITBOX_COLOR_G, self.HITBOX_COLOR_B)
	hitbox.CastShadow = false
	return hitbox
end

-- CombatServer.server.clpp:220
function CombatServer:ScheduleHitboxDestroy(hitbox: Part): boolean
	if not (self and hitbox) then
		return false
	end

	task.spawn(function()
		task.wait(self.HITBOX_LIFE)
		hitbox:Destroy()
	end)

	return true
end

-- CombatServer.server.clpp:232
function CombatServer:ResolveVictim(hitPart: BasePart, attackerCharacter: Model): Player
	if not (self and hitPart) then
		return nil
	end

	local hitModel = hitPart.Parent

	if not (hitModel and hitModel ~= attackerCharacter) then
		return nil
	end

	local humanoid = hitModel:FindFirstChildWhichIsA("Humanoid", false)

	if not (humanoid) then
		return nil
	end

	return self.players:GetPlayerFromCharacter(hitModel)
end

-- CombatServer.server.clpp:250
function CombatServer:TryMarkStruck(struckPlayers: Roster, victim: Player): boolean
	if not (self and struckPlayers and victim) then
		return false
	end

	local userId: number = victim.UserId

	if not (not struckPlayers:Get(userId)) then
		return false
	end

	struckPlayers:Set(userId, true)
	return true
end

-- CombatServer.server.clpp:264
function CombatServer:OnHitboxTouched(hitPart: BasePart, attacker: Player, attackerCharacter: Model, attackerEntity: number, struckPlayers: Roster): boolean
	if not (self and hitPart and attacker) then
		return false
	end

	local victim: Player = self:ResolveVictim(hitPart, attackerCharacter)

	if not (victim and victim ~= attacker) then
		return false
	end

	if not (self:TryMarkStruck(struckPlayers, victim)) then
		return false
	end

	local comboStage: number = self.World:Get(attackerEntity, PlayerECS.Combo)
	self:ApplyHit(attacker, victim, comboStage)
	return true
end

-- CombatServer.server.clpp:282
function CombatServer:BindHitboxTouched(hitbox: Part, attacker: Player, attackerCharacter: Model, attackerEntity: number, struckPlayers: Roster): boolean
	if not (self and hitbox and attacker and attackerCharacter and struckPlayers and attackerEntity) then
		return false
	end

	local __janitor = Janitor.new()
	__janitor:LinkToInstance(hitbox)
	__janitor:Add(hitbox.Touched:Connect(function(hitPart: BasePart)
		self:OnHitboxTouched(hitPart, attacker, attackerCharacter, attackerEntity, struckPlayers)
	end), "Disconnect")

	return true
end

-- CombatServer.server.clpp:293
function CombatServer:SpawnHitbox(attacker: Player, attackerEntity: number): boolean
	if not (self and attacker) then
		return false
	end

	local attackerCharacter: Model = attacker.Character

	if not (attackerCharacter) then
		return false
	end

	local rootPart = attackerCharacter:FindFirstChild("HumanoidRootPart", false)

	if not (rootPart) then
		return false
	end

	local struckPlayers: Roster = Roster.new()
	local hitbox: Part = self:CreateHitboxPart(rootPart)
	self:BindHitboxTouched(hitbox, attacker, attackerCharacter, attackerEntity, struckPlayers)
	self:ScheduleHitboxDestroy(hitbox)
	return true
end

-- CombatServer.server.clpp:315
function CombatServer:ReadBonusDamage(attacker: Player): number
	if not (self and attacker) then
		return 0
	end

	local data = Keep.Server:Get(attacker)

	if not (data) then
		return 0
	end

	local bonusDamage: number = data:Get(Keep.Server.Paths.Combat.Damage)

	if not (bonusDamage) then
		return 0
	end

	return bonusDamage
end

-- CombatServer.server.clpp:332
function CombatServer:ComputeDamage(attacker: Player, comboStage: number): number
	if not (self and attacker) then
		return 0
	end

	local bonusDamage: number = self:ReadBonusDamage(attacker)
	return self.BASE_DAMAGE + comboStage * self.COMBO_DAMAGE + bonusDamage
end

-- CombatServer.server.clpp:341
function CombatServer:SyncVictimHumanoid(victim: Player, currentHealth: number): boolean
	if not (self and victim) then
		return false
	end

	local character: Model = victim.Character

	if not (character) then
		return false
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid", false)

	if not (humanoid) then
		return false
	end

	humanoid.Health = currentHealth
	return true
end

-- CombatServer.server.clpp:360
function CombatServer:BroadcastHit(attacker: Player, victim: Player, damage: number, comboStage: number): boolean
	if not (self and attacker and victim) then
		return false
	end

	Net.HitResult.FireAll(attacker, victim, damage, comboStage)
	return true
end

-- CombatServer.server.clpp:369
function CombatServer:ApplyHit(attacker: Player, victim: Player, comboStage: number): boolean
	if not (self and attacker and victim and victim ~= attacker) then
		return false
	end

	local victimEntity: number = self.Entities:Get(victim)

	if not (victimEntity and self:IsFighterAlive(victimEntity)) then
		return false
	end

	local damage: number = self:ComputeDamage(attacker, comboStage)
	local currentHealth: number = self.World:Get(victimEntity, PlayerECS.Health)
	currentHealth = currentHealth - damage

	if currentHealth < 0 then
		currentHealth = 0
	end

	self.World:Set(victimEntity, PlayerECS.Health, currentHealth)
	self:SyncVictimHumanoid(victim, currentHealth)

	if currentHealth <= 0 then
		self.World:Remove(victimEntity, PlayerECS.Alive)
	end

	self:BroadcastHit(attacker, victim, damage, comboStage)
	return true
end

-- CombatServer.server.clpp:397
function CombatServer:OnAttack(player: Player): boolean
	if not (self and player) then
		return false
	end

	local fighterEntity: number = self.Entities:Get(player)

	if not (self:CanAcceptAttack(player, fighterEntity)) then
		return false
	end

	self:AdvanceCombo(fighterEntity, tick())
	self:SpawnHitbox(player, fighterEntity)
	return true
end

-- CombatServer.server.clpp:412
const function init()
	CombatServer:BindPlayerSessions()
	CombatServer:BindCombatRemotes()
end

init()
