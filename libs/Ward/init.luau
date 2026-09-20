--!native
--!optimize 2
--!strict
-- Ward — server anti-cheat primitives. Rate-limit remotes, cap packet size,
-- strike on speed/teleport. Does not write Keep; Keep stays server-only.
-- cluaupp: spawn grace / ignore falls / no Studio kick unless KickInStudio

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Spark = require(script.Parent.Spark)

local DEFAULT_KICK = 8
local DEFAULT_RATE = 40
local DEFAULT_BURST = 80
local MAX_PACKET = 24 * 1024
local MAX_SPEED = 220
local MAX_TELEPORT = 80
local SPAWN_GRACE = 3
local MIN_DT = 1 / 30
local FLOOD_AT = 80

local Ward = {}
Ward.OnStrike = Spark.new()
Ward.KickAt = DEFAULT_KICK
Ward.KickInStudio = false
Ward.FloodAt = FLOOD_AT
Ward.MaxPacketBytes = MAX_PACKET
Ward.MaxSpeed = MAX_SPEED
Ward.MaxTeleport = MAX_TELEPORT

type Bucket = {
	tokens: number,
	last: number,
	maxPerSec: number,
	burst: number,
}

type Record = {
	strikes: number,
	buckets: { [string]: Bucket },
	lastPos: Vector3?,
	graceUntil: number,
	reasons: { [string]: number },
	denied: { [string]: number },
}

local records: { [Player]: Record } = {}
local watching = false

local function rec(player: Player): Record
	local row = records[player]
	if not row then
		row = {
			strikes = 0,
			buckets = {},
			lastPos = nil,
			graceUntil = 0,
			reasons = {},
			denied = {},
		}
		records[player] = row
	end
	return row
end

function Ward.Allow(player: Player, channel: string, maxPerSec: number?, burst: number?): boolean
	if not RunService:IsServer() then
		return true
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then
		return false
	end
	if typeof(channel) ~= "string" or channel == "" then
		return false
	end
	local rate = maxPerSec or DEFAULT_RATE
	local cap = burst or math.max(rate * 2, DEFAULT_BURST)
	local now = os.clock()
	local row = rec(player)
	local bucket = row.buckets[channel]
	if not bucket then
		bucket = {
			tokens = cap,
			last = now,
			maxPerSec = rate,
			burst = cap,
		}
		row.buckets[channel] = bucket
	end
	local elapsed = math.max(now - bucket.last, 0)
	bucket.last = now
	bucket.tokens = math.min(bucket.burst, bucket.tokens + elapsed * bucket.maxPerSec)
	if bucket.tokens < 1 then
		local denied = (row.denied[channel] or 0) + 1
		row.denied[channel] = denied
		if denied >= Ward.FloodAt then
			row.denied[channel] = 0
			Ward.Strike(player, "rate:" .. channel)
		end
		return false
	end
	row.denied[channel] = 0
	bucket.tokens -= 1
	return true
end

function Ward.Packet(player: Player, bytes: number, maxBytes: number?): boolean
	if not RunService:IsServer() then
		return true
	end
	local cap = maxBytes or Ward.MaxPacketBytes
	if typeof(bytes) ~= "number" or bytes ~= bytes or bytes < 0 or bytes > cap then
		Ward.Strike(player, "packet")
		return false
	end
	return true
end

function Ward.Strike(player: Player, reason: string): number
	if not RunService:IsServer() then
		return 0
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then
		return 0
	end
	local row = rec(player)
	row.strikes += 1
	local label = if typeof(reason) == "string" and reason ~= "" then reason else "unknown"
	row.reasons[label] = (row.reasons[label] or 0) + 1
	Ward.OnStrike:Fire(player, label, row.strikes)
	local studio = RunService:IsStudio()
	if row.strikes >= Ward.KickAt and (not studio or Ward.KickInStudio == true) then
		player:Kick("Movement or traffic rejected")
	end
	return row.strikes
end

function Ward.Grace(player: Player, seconds: number)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local hold = if typeof(seconds) == "number" and seconds > 0 then seconds else 1.5
	rec(player).graceUntil = os.clock() + hold
end

function Ward.Clear(player: Player)
	records[player] = nil
end

function Ward.Strikes(player: Player): number
	local row = records[player]
	return if row then row.strikes else 0
end

local function bindSpawnGrace(player: Player)
	Ward.Grace(player, SPAWN_GRACE)
	player.CharacterAdded:Connect(function()
		local row = rec(player)
		row.lastPos = nil
		Ward.Grace(player, SPAWN_GRACE)
	end)
end

function Ward.WatchMovement()
	if watching or not RunService:IsServer() then
		return
	end
	watching = true
	RunService.Heartbeat:Connect(function(dt: number)
		if dt <= 0 then
			return
		end
		local step = math.max(dt, MIN_DT)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				rec(player).lastPos = nil
				continue
			end
			local row = rec(player)
			local pos = root.Position
			if row.lastPos and now >= row.graceUntil then
				local delta = pos - row.lastPos
				local dist = delta.Magnitude
				local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
				local falling = delta.Y < 0 and horizontal < Ward.MaxTeleport
				local speed = dist / step
				if not falling and dist > Ward.MaxTeleport and speed > Ward.MaxSpeed then
					Ward.Strike(player, "speed")
					root.CFrame = CFrame.new(row.lastPos)
					pos = row.lastPos
				end
			end
			row.lastPos = pos
		end
	end)
	for _, player in Players:GetPlayers() do
		bindSpawnGrace(player)
	end
	Players.PlayerAdded:Connect(bindSpawnGrace)
	Players.PlayerRemoving:Connect(Ward.Clear)
end

function Ward.Start()
	Ward.WatchMovement()
end

return Ward
