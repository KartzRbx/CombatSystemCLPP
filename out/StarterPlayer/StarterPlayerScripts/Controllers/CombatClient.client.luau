--!nonstrict
-- Compiled by CL++ — C++ × Luau

-- cluaupp: Roster.new / GetService ReplicatedStorage / self.janitor

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Janitor = require(ReplicatedStorage.CluauppLibs.Sweep)
const Net = require(ReplicatedStorage.Shared.Net.Net)

local CombatClient = {}
CombatClient.players = game:GetService("Players")
CombatClient.me = nil
CombatClient.ATTACK_INTERVAL = 0.45
CombatClient.LOCAL_HITBOX_LIFE = 0.16
CombatClient.HITBOX_WIDTH = 5
CombatClient.HITBOX_HEIGHT = 6
CombatClient.HITBOX_DEPTH = 4
CombatClient.HITBOX_FORWARD = -3.2
CombatClient.HITBOX_TRANSPARENCY = 0.7
CombatClient.HITBOX_COLOR_R = 1
CombatClient.HITBOX_COLOR_G = 0.45
CombatClient.HITBOX_COLOR_B = 0.2
CombatClient.MAX_COMBO = 4
CombatClient.LOCAL_HITBOX_NAME = "CombatHitboxLocal"
CombatClient.ComboStage = 0
CombatClient.LastHit = 0
CombatClient.EntityId = 0
CombatClient.Health = 100

-- CombatClient.client.clpp:6
function CombatClient:IsAttackInput(input: InputObject, gameProcessed: boolean): boolean
	if not (not gameProcessed and input) then
		return false
	end

	local isMouse: boolean = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch: boolean = input.UserInputType == Enum.UserInputType.Touch
	return isMouse or isTouch
end

-- CombatClient.client.clpp:16
function CombatClient:OnAttackInput(input: InputObject, gameProcessed: boolean): boolean
	if not (self) then
		return false
	end

	if not (self:IsAttackInput(input, gameProcessed)) then
		return false
	end

	return self:SendAttack()
end

-- CombatClient.client.clpp:27
function CombatClient:OnCombatHello(entityId: number, health: number): boolean
	if not (self) then
		return false
	end

	self.EntityId = entityId
	self.Health = health
	return true
end

-- CombatClient.client.clpp:37
function CombatClient:OnHitReceived(attacker: Player, victim: Player, damage: number, comboStage: number): boolean
	if not (self and attacker and victim == self.me and comboStage >= 0) then
		return false
	end

	self.Health = self.Health - damage

	if self.Health < 0 then
		self.Health = 0
	end

	return true
end

-- CombatClient.client.clpp:49
function CombatClient:SendAttack(): boolean
	if not (self.me) then
		return false
	end

	if not (tick() - self.LastHit >= self.ATTACK_INTERVAL) then
		return false
	end

	self.LastHit = tick()
	self.ComboStage += 1

	if self.ComboStage > self.MAX_COMBO then
		self.ComboStage = 1
	end

	Net.AttackIntent:FireServer()
	self:SpawnLocalHitbox()
	return true
end

-- CombatClient.client.clpp:68
function CombatClient:ComposeHitboxCFrame(rootPart: BasePart): CFrame
	return rootPart.CFrame * CFrame.new(0, 0, self.HITBOX_FORWARD)
end

-- CombatClient.client.clpp:72
function CombatClient:CreateLocalHitboxPart(rootPart: BasePart): Part
	local hitbox: Part = Instance.new("Part")
	hitbox.Parent = workspace
	hitbox.Name = self.LOCAL_HITBOX_NAME
	hitbox.Size = Vector3.new(self.HITBOX_WIDTH, self.HITBOX_HEIGHT, self.HITBOX_DEPTH)
	hitbox.CFrame = self:ComposeHitboxCFrame(rootPart)
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.Massless = true
	hitbox.Transparency = self.HITBOX_TRANSPARENCY
	hitbox.Color = Color3.new(self.HITBOX_COLOR_R, self.HITBOX_COLOR_G, self.HITBOX_COLOR_B)
	hitbox.CastShadow = false
	return hitbox
end

-- CombatClient.client.clpp:87
function CombatClient:SpawnLocalHitbox(): boolean
	if not (self.me and self.me.Character) then
		return false
	end

	local rootPart = self.me.Character:FindFirstChild("HumanoidRootPart", false)

	if not (rootPart) then
		return false
	end

	local hitbox: Part = self:CreateLocalHitboxPart(rootPart)
	task.spawn(function()
		task.wait(self.LOCAL_HITBOX_LIFE)
		hitbox:Destroy()
	end)

	return true
end

-- CombatClient.client.clpp:105
function CombatClient:OnCharacterSpawned(character: Model): boolean
	if not (self and self.me and character) then
		return false
	end

	self.LastHit = 0
	self.ComboStage = 0
	return true
end

-- CombatClient.client.clpp:115
function CombatClient:BindCharacter(): boolean
	if not (self and self.me) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(self.me.CharacterAdded:Connect(function(character: Model)
		self:OnCharacterSpawned(character)
	end), "Disconnect")

	if self.me.Character then
		self:OnCharacterSpawned(self.me.Character)
	end

	return true
end

-- CombatClient.client.clpp:129
function CombatClient:BindCombatInput(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	const inputService: UserInputService = game:GetService("UserInputService")
	__janitor:Add(inputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		self:OnAttackInput(input, gameProcessed)
	end), "Disconnect")

	return true
end

-- CombatClient.client.clpp:141
function CombatClient:BindCombatNet(): boolean
	if not (self) then
		return false
	end

	local __janitor = self.janitor

	if not __janitor then
		__janitor = Janitor.new()
		self.janitor = __janitor
	end

	__janitor:Add(Net.CombatHello:Connect(function(entityId: number, health: number)
		self:OnCombatHello(entityId, health)
	end), "Disconnect")

	__janitor:Add(Net.HitResult:Connect(function(attacker: Player, victim: Player, damage: number, comboStage: number)
		self:OnHitReceived(attacker, victim, damage, comboStage)
	end), "Disconnect")

	return true
end

-- CombatClient.client.clpp:156
function CombatClient:SetupPlayerCombat(): boolean
	if not (self) then
		return false
	end

	self:BindCombatInput()
	self:BindCombatNet()
	self:BindCharacter()
	return true
end

-- CombatClient.client.clpp:167
const function init()
	local combat = CombatClient
	combat.me = combat.players.LocalPlayer
	combat.LastHit = 0
	combat.ComboStage = 0
	combat.EntityId = 0
	combat.Health = 100
	combat:SetupPlayerCombat()
	Net.CombatReady:FireServer()
end

init()
