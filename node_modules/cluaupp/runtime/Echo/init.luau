--!native
--!optimize 2
--!strict
-- Echo — character snapshot replication. CFrame packed as f32s.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Echo = {}
Echo.__index = Echo

local HEADER_SIZE = 6
local RECORD_SIZE = 52
local CFRAME_SIZE = 48
local MAX_UNRELIABLE = 900
local FOLDER_NAME = "EchoRemotes"
local SNAPSHOT_NAME = "Snapshot"

local remotes: Folder? = nil
local started = false

local config = {
	Rate = 20,
	Interpolate = 16,
	MaxDistance = 0,
}

local stats = {
	Packets = 0,
	PacketsSent = 0,
	PacketsReceived = 0,
	BytesSent = 0,
	BytesReceived = 0,
	Snapshots = 0,
}

local rules = {
	SkipLocal = true,
}

type Track = {
	target: CFrame,
	current: CFrame?,
	clock: number,
}

type EchoEntity = {
	Player: Player,
	CFrame: CFrame,
	Clock: number,
}

local entities: { [Player]: EchoEntity } = {}
local tracks: { [Player]: Track } = {}
local lastSnapshots: { [Player]: { CFrame: CFrame, Clock: number } } = {}

local function writeCFrameAt(buf: buffer, offset: number, cf: CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	buffer.writef32(buf, offset, x)
	buffer.writef32(buf, offset + 4, y)
	buffer.writef32(buf, offset + 8, z)
	buffer.writef32(buf, offset + 12, r00)
	buffer.writef32(buf, offset + 16, r01)
	buffer.writef32(buf, offset + 20, r02)
	buffer.writef32(buf, offset + 24, r10)
	buffer.writef32(buf, offset + 28, r11)
	buffer.writef32(buf, offset + 32, r12)
	buffer.writef32(buf, offset + 36, r20)
	buffer.writef32(buf, offset + 40, r21)
	buffer.writef32(buf, offset + 44, r22)
end

local function readCFrameAt(buf: buffer, offset: number): CFrame
	return CFrame.new(
		buffer.readf32(buf, offset),
		buffer.readf32(buf, offset + 4),
		buffer.readf32(buf, offset + 8),
		buffer.readf32(buf, offset + 12),
		buffer.readf32(buf, offset + 16),
		buffer.readf32(buf, offset + 20),
		buffer.readf32(buf, offset + 24),
		buffer.readf32(buf, offset + 28),
		buffer.readf32(buf, offset + 32),
		buffer.readf32(buf, offset + 36),
		buffer.readf32(buf, offset + 40),
		buffer.readf32(buf, offset + 44)
	)
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function ensureEntity(player: Player): EchoEntity
	local entity = entities[player]
	if entity then
		return entity
	end
	entity = {
		Player = player,
		CFrame = CFrame.identity,
		Clock = 0,
	}
	entities[player] = entity
	return entity
end

local function folder(): Folder
	if remotes and remotes.Parent then
		return remotes
	end
	if RunService:IsClient() then
		local existing = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		assert(existing:IsA("Folder"), "EchoRemotes must be a Folder")
		remotes = existing
		return existing
	end
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		remotes = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = ReplicatedStorage
	remotes = created
	return created
end

local function snapshotRemote(): UnreliableRemoteEvent
	local parent = folder()
	if RunService:IsClient() then
		local existing = parent:WaitForChild(SNAPSHOT_NAME)
		assert(existing:IsA("UnreliableRemoteEvent"), "Echo Snapshot must be UnreliableRemoteEvent")
		return existing
	end
	local existing = parent:FindFirstChild(SNAPSHOT_NAME)
	if existing and existing:IsA("UnreliableRemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("UnreliableRemoteEvent")
	created.Name = SNAPSHOT_NAME
	created.Parent = parent
	return created
end

function Echo.WriteCFrame(cf: CFrame): buffer
	local buf = buffer.create(CFRAME_SIZE)
	writeCFrameAt(buf, 0, cf)
	return buf
end

function Echo.ReadCFrame(buf: buffer): CFrame
	return readCFrameAt(buf, 0)
end

local function publish(remote: UnreliableRemoteEvent)
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootPart(player)
		if root then
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return
	end
	local clock = workspace:GetServerTimeNow()
	local maxRecords = math.max(1, math.floor((MAX_UNRELIABLE - HEADER_SIZE) / RECORD_SIZE))
	local index = 1
	while index <= #list do
		local count = math.min(#list - index + 1, maxRecords)
		local buf = buffer.create(HEADER_SIZE + count * RECORD_SIZE)
		buffer.writef32(buf, 0, clock)
		buffer.writeu16(buf, 4, count)
		local offset = HEADER_SIZE
		for slot = 0, count - 1 do
			local player = list[index + slot]
			local root = rootPart(player)
			if root then
				buffer.writeu32(buf, offset, player.UserId)
				writeCFrameAt(buf, offset + 4, root.CFrame)
				local entity = ensureEntity(player)
				entity.CFrame = root.CFrame
				entity.Clock = clock
				lastSnapshots[player] = { CFrame = root.CFrame, Clock = clock }
			else
				buffer.writeu32(buf, offset, player.UserId)
				writeCFrameAt(buf, offset + 4, CFrame.identity)
			end
			offset += RECORD_SIZE
		end
		remote:FireAllClients(buf)
		stats.Packets += 1
		stats.PacketsSent += 1
		stats.BytesSent += buffer.len(buf)
		stats.Snapshots += count
		index += count
	end
end

local function applyPacked(packed: buffer)
	if buffer.len(packed) < HEADER_SIZE then
		return
	end
	stats.Packets += 1
	stats.PacketsReceived += 1
	stats.BytesReceived += buffer.len(packed)
	local clock = buffer.readf32(packed, 0)
	local count = buffer.readu16(packed, 4)
	local localPlayer = Players.LocalPlayer
	local localId = if localPlayer then localPlayer.UserId else 0
	local origin: Vector3? = nil
	if config.MaxDistance > 0 and localPlayer then
		local localRoot = rootPart(localPlayer)
		if localRoot then
			origin = localRoot.Position
		end
	end
	local offset = HEADER_SIZE
	for _ = 1, count do
		if offset + RECORD_SIZE > buffer.len(packed) then
			break
		end
		local userId = buffer.readu32(packed, offset)
		local cf = readCFrameAt(packed, offset + 4)
		offset += RECORD_SIZE
		if rules.SkipLocal and userId == localId then
			continue
		end
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			continue
		end
		if rules.SkipLocal and player == localPlayer then
			continue
		end
		if origin and (cf.Position - origin).Magnitude > config.MaxDistance then
			continue
		end
		local entity = ensureEntity(player)
		entity.CFrame = cf
		entity.Clock = clock
		lastSnapshots[player] = { CFrame = cf, Clock = clock }
		local track = tracks[player]
		if track then
			track.target = cf
			track.clock = clock
		else
			tracks[player] = {
				target = cf,
				current = nil,
				clock = clock,
			}
		end
		stats.Snapshots += 1
	end
end

local function interpolate(dt: number)
	local localPlayer = Players.LocalPlayer
	local rate = math.max(config.Interpolate, 0)
	local alpha = if rate <= 0 then 1 else 1 - math.exp(-rate * dt)
	for player, track in tracks do
		if rules.SkipLocal and player == localPlayer then
			continue
		end
		if not player.Parent then
			tracks[player] = nil
			continue
		end
		local root = rootPart(player)
		if not root then
			continue
		end
		local current = track.current or root.CFrame
		local target = track.target
		if (current.Position - target.Position).Magnitude > 40 then
			current = target
		else
			current = current:Lerp(target, alpha)
		end
		track.current = current
		root.CFrame = current
	end
end

function Echo.Start()
	if started then
		return
	end
	started = true
	local remote = snapshotRemote()
	if RunService:IsServer() then
		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			local interval = 1 / math.max(config.Rate, 1)
			if elapsed < interval then
				return
			end
			elapsed = 0
			publish(remote)
		end)
		Players.PlayerRemoving:Connect(function(player)
			entities[player] = nil
			lastSnapshots[player] = nil
		end)
	else
		remote.OnClientEvent:Connect(function(packed: buffer)
			applyPacked(packed)
		end)
		RunService.Heartbeat:Connect(function(dt)
			interpolate(dt)
		end)
		Players.PlayerRemoving:Connect(function(player)
			tracks[player] = nil
			entities[player] = nil
			lastSnapshots[player] = nil
		end)
		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(function()
				local track = tracks[player]
				if track then
					track.current = nil
				end
			end)
		end)
		for _, player in Players:GetPlayers() do
			player.CharacterAdded:Connect(function()
				local track = tracks[player]
				if track then
					track.current = nil
				end
			end)
		end
	end
end

local Holder = {}

function Holder.Get(player: Player): EchoEntity?
	return entities[player]
end

function Holder.All(): { [Player]: EchoEntity }
	return entities
end

function Echo.Holder()
	return Holder
end

local Entity = {}

function Entity.new(player: Player): EchoEntity
	return ensureEntity(player)
end

function Echo.Entity()
	return Entity
end

function Echo.Stats()
	return stats
end

function Echo.Config(patch: any?): typeof(config)
	if typeof(patch) == "table" then
		if typeof(patch.Rate) == "number" then
			config.Rate = patch.Rate
		end
		if typeof(patch.Interpolate) == "number" then
			config.Interpolate = patch.Interpolate
		end
		if typeof(patch.MaxDistance) == "number" then
			config.MaxDistance = patch.MaxDistance
		end
	end
	return config
end

function Echo.ReplicationRules(patch: any?): typeof(rules)
	if typeof(patch) == "table" then
		if patch.SkipLocal ~= nil then
			rules.SkipLocal = patch.SkipLocal == true
		end
	end
	return rules
end

function Echo.Events()
	return folder()
end

function Echo.Snapshots()
	return lastSnapshots
end

function Echo.ServerClock()
	return workspace:GetServerTimeNow()
end

function Echo.Player()
	return Players.LocalPlayer
end

return Echo
