--!native
--!optimize 2
--!strict
-- Helm — typed commands. Args pack to buffers. Server is authority.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Ward = require(script.Parent.Ward)

local Helm = {}
Helm.__index = Helm

local registry: { [string]: any } = {}
local types: { [string]: any } = {}
local hooks: { [string]: { (...any) -> any } } = {}

local function packArgs(args: { any }): buffer
	local size = 1
	for _, arg in args do
		local kind = typeof(arg)
		if kind == "number" then
			size += 9
		elseif kind == "string" then
			size += 3 + #arg
		elseif kind == "boolean" then
			size += 2
		elseif kind == "Instance" then
			size += 5
		else
			size += 1
		end
	end
	local buf = buffer.create(size)
	buffer.writeu8(buf, 0, #args)
	local cursor = 1
	for _, arg in args do
		local kind = typeof(arg)
		if kind == "number" then
			buffer.writeu8(buf, cursor, 1)
			cursor += 1
			buffer.writef64(buf, cursor, arg)
			cursor += 8
		elseif kind == "string" then
			buffer.writeu8(buf, cursor, 2)
			cursor += 1
			buffer.writeu16(buf, cursor, #arg)
			cursor += 2
			buffer.writestring(buf, cursor, arg)
			cursor += #arg
		elseif kind == "boolean" then
			buffer.writeu8(buf, cursor, 3)
			cursor += 1
			buffer.writeu8(buf, cursor, if arg then 1 else 0)
			cursor += 1
		elseif kind == "Instance" then
			buffer.writeu8(buf, cursor, 4)
			cursor += 1
			local userId = 0
			if arg:IsA("Player") then
				userId = arg.UserId
			end
			buffer.writeu32(buf, cursor, userId)
			cursor += 4
		else
			buffer.writeu8(buf, cursor, 0)
			cursor += 1
		end
	end
	return buf
end

local function unpackArgs(buf: buffer): { any }
	local count = buffer.readu8(buf, 0)
	local args = table.create(count)
	local cursor = 1
	local length = buffer.len(buf)
	for index = 1, count do
		if cursor >= length then
			break
		end
		local tag = buffer.readu8(buf, cursor)
		cursor += 1
		if tag == 1 then
			args[index] = buffer.readf64(buf, cursor)
			cursor += 8
		elseif tag == 2 then
			local len = buffer.readu16(buf, cursor)
			cursor += 2
			args[index] = buffer.readstring(buf, cursor, len)
			cursor += len
		elseif tag == 3 then
			args[index] = buffer.readu8(buf, cursor) == 1
			cursor += 1
		elseif tag == 4 then
			local userId = buffer.readu32(buf, cursor)
			cursor += 4
			args[index] = Players:GetPlayerByUserId(userId)
		else
			args[index] = nil
		end
	end
	return args
end

local function resolvePlayer(value: any): Player?
	if typeof(value) == "Instance" and value:IsA("Player") then
		return value
	end
	if typeof(value) == "number" then
		return Players:GetPlayerByUserId(value)
	end
	if typeof(value) == "string" then
		local asId = tonumber(value)
		if asId then
			return Players:GetPlayerByUserId(asId)
		end
		local child = Players:FindFirstChild(value)
		if child and child:IsA("Player") then
			return child
		end
	end
	return nil
end

local function transformArg(typeName: string?, value: any): any
	local def = if typeName then types[typeName] else nil
	if def then
		local transform = def.Transform or def.Parse or def
		if typeof(transform) == "function" then
			return transform(value)
		end
	end
	if typeName == "Player" then
		return resolvePlayer(value)
	end
	if typeName == "i32" or typeName == "int" or typeName == "number" or typeName == "f64" then
		local n = tonumber(value)
		if n == nil then
			return value
		end
		if typeName == "i32" or typeName == "int" then
			return math.floor(n)
		end
		return n
	end
	if typeName == "boolean" or typeName == "bool" then
		if typeof(value) == "boolean" then
			return value
		end
		return value == 1 or value == "true"
	end
	if typeName == "string" and value ~= nil then
		return tostring(value)
	end
	return value
end

local function applyTypes(command: any, args: { any }): { any }
	local spec = command.Args
	if typeof(spec) ~= "table" then
		return args
	end
	for index, slot in spec do
		if typeof(slot) == "table" then
			args[index] = transformArg(slot.Type, args[index])
		end
	end
	return args
end

local function hasPermission(player: Player, permission: string?): boolean
	if permission == nil or permission == "" or permission == "None" or permission == "All" then
		return true
	end
	if player:GetAttribute(permission) == true then
		return true
	end
	local tagged = player:GetAttribute("Permission") or player:GetAttribute("Helm")
	if tagged == permission then
		return true
	end
	local rank = player:GetAttribute("HelmRank")
	if typeof(rank) == "number" then
		if permission == "Admin" and rank >= 254 then
			return true
		end
		if (permission == "Mod" or permission == "Moderator") and rank >= 50 then
			return true
		end
	end
	if permission == "Admin" and player.UserId == game.CreatorId then
		return true
	end
	return false
end

local function fireHooks(name: string, ...: any): any
	local list = hooks[name]
	if not list then
		return nil
	end
	for _, fn in list do
		local result = fn(...)
		if result ~= nil then
			return result
		end
	end
	return nil
end

local function mergeCommand(name: string, command: any)
	local existing = registry[name]
	if existing then
		for key, value in command do
			if key ~= "Callback" then
				existing[key] = value
			elseif existing.Callback == nil then
				existing.Callback = value
			end
		end
		existing.Name = name
		return existing
	end
	local copy = table.clone(command)
	copy.Name = name
	registry[name] = copy
	return copy
end

function Helm.Register(schema: any)
	if typeof(schema) ~= "table" then
		return
	end
	for name, command in schema do
		if typeof(name) == "string" and typeof(command) == "table" then
			mergeCommand(name, command)
		end
	end
end

local function runCommand(player: Player, schema: any, name: string, packedArgs: { any }): (boolean, any)
	if RunService:IsServer() and not Ward.Allow(player, "helm", 6, 10) then
		return false, "rate"
	end
	local command = registry[name]
	if typeof(command) ~= "table" then
		command = schema and schema[name]
	end
	if typeof(command) ~= "table" then
		return false, "unknown command"
	end
	if not hasPermission(player, command.Permission) then
		return false, "permission"
	end
	local packed = packArgs(packedArgs)
	local unpacked = applyTypes(command, unpackArgs(packed))
	local block = fireHooks("BeforeRun", player, name, unpacked)
	if block == false or typeof(block) == "string" then
		return false, if typeof(block) == "string" then block else "blocked"
	end
	local callback = command.Callback
	if typeof(callback) ~= "function" then
		if name == "Kick" then
			callback = function(executor: Player, target: Player?, reason: string?)
				if target and typeof(target) == "Instance" and target:IsA("Player") and target ~= executor then
					target:Kick(reason or "Kicked")
				end
			end
		elseif name == "Give" then
			callback = function(executor: Player, target: Player?, amount: number)
				if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > 1e9 then
					return
				end
				fireHooks("Give", executor, target, amount)
			end
		end
	end
	if typeof(callback) == "function" then
		callback(player, table.unpack(unpacked, 1, #unpacked))
	end
	fireHooks("AfterRun", player, name, unpacked)
	return true, packed
end

function Helm.Open(player: Player, schema: any)
	Helm.Register(schema)
	local session = {
		Player = player,
		Schema = schema,
	}
	function session:Run(name: string, ...: any)
		return runCommand(player, schema, name, { ... })
	end
	return session
end

function Helm.Give(player: Player, target: Player, amount: number)
	if not registry.Give then
		Helm.RegisterDefaultCommands()
	end
	return Helm.Open(player, registry):Run("Give", target, amount)
end

function Helm.Kick(player: Player, target: Player, reason: string?)
	if not registry.Kick then
		Helm.RegisterDefaultCommands()
	end
	return Helm.Open(player, registry):Run("Kick", target, reason)
end

function Helm.RegisterDefaultCommands()
	Helm.Register({
		Give = {
			Id = 1,
			Permission = "Admin",
			Args = { { Type = "Player", Name = "target" }, { Type = "i32", Name = "amount" } },
			Callback = function(player: Player, target: Player?, amount: number)
				if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > 1e9 then
					return
				end
				fireHooks("Give", player, target, amount)
			end,
		},
		Kick = {
			Id = 2,
			Permission = "Admin",
			Args = { { Type = "Player", Name = "target" }, { Type = "string", Name = "reason" } },
			Callback = function(player: Player, target: Player?, reason: string?)
				if target and target ~= player then
					target:Kick(reason or "Kicked")
				end
			end,
		},
	})
end

function Helm.RegisterHook(name: string, callback: (...any) -> ())
	local list = hooks[name]
	if not list then
		list = {}
		hooks[name] = list
	end
	table.insert(list, callback)
end

function Helm.RegisterType(name: string, typeDefinition: any)
	types[name] = typeDefinition
end

function Helm.RegisterCommand(commandDefinition: any)
	if typeof(commandDefinition) ~= "table" then
		return
	end
	local name = commandDefinition.Name
	if typeof(name) ~= "string" then
		return
	end
	mergeCommand(name, commandDefinition)
end

function Helm.Registry()
	return registry
end

function Helm.Dispatcher()
	return {
		Run = function(_self: any, player: Player, name: string, ...: any)
			return Helm.Open(player, registry):Run(name, ...)
		end,
	}
end

Helm.RegisterType("Player", {
	Transform = resolvePlayer,
})

return Helm
