--!optimize 2
--!strict
-- Keep Trade — true escrow. Spendable balance drops on Reserve; Commit only
-- credits with receipts. Same-server SaveWait both sides; rollback if a save
-- fails so a crash cannot duplicate. Offline credits are idempotent.

local HttpService = game:GetService("HttpService")

local MAX_TRADES_PER_DAY = 40
local TRADE_COOLDOWN = 8
local MAX_OFFERS = 12
local MAX_AMOUNT = 1e12
local MAX_RECEIPTS = 128
local MAX_RECOVERY = 16
local KINDS = { Currency = true, Stack = true, Instance = true }

local Trade = {}

local function overlay(dest: any, src: any)
	if typeof(dest) ~= "table" or typeof(src) ~= "table" then
		return
	end
	for key in dest do
		dest[key] = nil
	end
	for key, value in src do
		dest[key] = value
	end
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value do
		out[key] = deepCopy(item)
	end
	return out
end

local function tradeBucket(data: any)
	data.Trade = data.Trade or {
		DayKey = "",
		TradesToday = 0,
		LastTradeAt = 0,
		ActiveTradeId = "",
		RecoveryTradeIds = {},
		Reserved = {},
		Receipts = {},
	}
	data.Trade.Reserved = data.Trade.Reserved or {}
	data.Trade.Receipts = data.Trade.Receipts or {}
	data.Trade.RecoveryTradeIds = data.Trade.RecoveryTradeIds or {}
	return data.Trade
end

local function opId(): string
	return HttpService:GenerateGUID(false)
end

local function dayKey(): string
	return os.date("!%Y-%m-%d")
end

local function reserveKey(kind: string, ref: string): string
	return kind .. "|" .. ref
end

local function pruneReceipts(trade: any)
	local receipts = trade.Receipts
	local n = 0
	for _ in receipts do
		n += 1
	end
	if n <= MAX_RECEIPTS then
		return
	end
	local keys = {}
	for key in receipts do
		table.insert(keys, key)
	end
	local drop = n - MAX_RECEIPTS
	for i = 1, drop do
		receipts[keys[i]] = nil
	end
end

local function inventoryItems(data: any): { any }
	data.Inventory = data.Inventory or { Items = {} }
	data.Inventory.Items = data.Inventory.Items or {}
	return data.Inventory.Items
end

local function validAmount(amount: number): boolean
	return typeof(amount) == "number" and amount == amount and amount > 0 and amount <= MAX_AMOUNT and amount % 1 == 0
end

local function validKind(kind: string, ref: string): boolean
	return KINDS[kind] == true and typeof(ref) == "string" and ref ~= ""
end

local function saveWait(profile: any): boolean
	if typeof(profile.SaveWait) == "function" then
		return profile:SaveWait() == true
	end
	profile:Save()
	return true
end

function Trade.Ensure(data: any)
	return tradeBucket(data)
end

function Trade.Begin(profileA: any, profileB: any): string
	if profileA == nil or profileB == nil or profileA == profileB then
		return ""
	end
	if not profileA:IsActive() or not profileB:IsActive() then
		return ""
	end
	local a = tradeBucket(profileA.Data)
	local b = tradeBucket(profileB.Data)
	if a.ActiveTradeId ~= "" or b.ActiveTradeId ~= "" then
		return ""
	end
	local now = os.time()
	local today = dayKey()
	if a.DayKey ~= today then
		a.DayKey = today
		a.TradesToday = 0
	end
	if b.DayKey ~= today then
		b.DayKey = today
		b.TradesToday = 0
	end
	if a.TradesToday >= MAX_TRADES_PER_DAY or b.TradesToday >= MAX_TRADES_PER_DAY then
		return ""
	end
	if now - (a.LastTradeAt or 0) < TRADE_COOLDOWN or now - (b.LastTradeAt or 0) < TRADE_COOLDOWN then
		return ""
	end
	local id = opId()
	a.ActiveTradeId = id
	b.ActiveTradeId = id
	table.insert(a.RecoveryTradeIds, id)
	table.insert(b.RecoveryTradeIds, id)
	while #a.RecoveryTradeIds > MAX_RECOVERY do
		table.remove(a.RecoveryTradeIds, 1)
	end
	while #b.RecoveryTradeIds > MAX_RECOVERY do
		table.remove(b.RecoveryTradeIds, 1)
	end
	return id
end

function Trade.Reserve(profile: any, kind: string, ref: string, amount: number, tradeId: string, extra: any?): boolean
	if not profile or not profile:IsActive() then
		return false
	end
	if not validKind(kind, ref) or not validAmount(amount) or typeof(tradeId) ~= "string" or tradeId == "" then
		return false
	end
	local trade = tradeBucket(profile.Data)
	if trade.ActiveTradeId ~= tradeId then
		return false
	end
	local key = reserveKey(kind, ref)
	if trade.Reserved[key] ~= nil then
		return false
	end
	local held: any = { TradeId = tradeId, Kind = kind, Ref = ref, Amount = amount }
	if kind == "Currency" then
		profile.Data.Currencies = profile.Data.Currencies or {}
		local have = profile.Data.Currencies[ref] or 0
		if typeof(have) ~= "number" or have < amount then
			return false
		end
		profile.Data.Currencies[ref] = have - amount
	elseif kind == "Stack" then
		local items = inventoryItems(profile.Data)
		local found = false
		for index, stack in items do
			if typeof(stack) == "table" and stack.ItemId == ref then
				if (stack.Amount or 0) < amount or stack.Locked == true then
					return false
				end
				stack.Amount -= amount
				if stack.Amount <= 0 then
					table.remove(items, index)
				end
				found = true
				break
			end
		end
		if not found then
			return false
		end
	elseif kind == "Instance" then
		local uid = if extra then extra.UID else ref
		if typeof(uid) ~= "string" or uid == "" then
			return false
		end
		local list = inventoryItems(profile.Data)
		local found = false
		for index, item in list do
			if typeof(item) == "table" and item.UID == uid then
				if item.Locked == true or (typeof(item.Escrow) == "string" and item.Escrow ~= "" and item.Escrow ~= tradeId) then
					return false
				end
				held.Item = deepCopy(item)
				held.UID = uid
				item.Escrow = tradeId
				table.remove(list, index)
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	trade.Reserved[key] = held
	return true
end

function Trade.ReceiptKey(operationId: string, kind: string, ref: string): string
	return operationId .. "|" .. kind .. "|" .. ref
end

function Trade.AlreadyReceived(profile: any, operationId: string, kind: string, ref: string): boolean
	local trade = tradeBucket(profile.Data)
	return trade.Receipts[Trade.ReceiptKey(operationId, kind, ref)] ~= nil
end

function Trade.Credit(profile: any, kind: string, ref: string, amount: number, operationId: string, extra: any?)
	if not validKind(kind, ref) or not validAmount(amount) or typeof(operationId) ~= "string" or operationId == "" then
		return
	end
	if kind == "Instance" then
		local item = extra and (extra.Item or extra)
		if typeof(item) ~= "table" then
			return
		end
	end
	local trade = tradeBucket(profile.Data)
	local key = Trade.ReceiptKey(operationId, kind, ref)
	if trade.Receipts[key] then
		return
	end
	trade.Receipts[key] = amount
	pruneReceipts(trade)
	if kind == "Currency" then
		profile.Data.Currencies = profile.Data.Currencies or {}
		profile.Data.Currencies[ref] = (profile.Data.Currencies[ref] or 0) + amount
		return
	end
	if kind == "Stack" then
		local items = inventoryItems(profile.Data)
		for _, stack in items do
			if typeof(stack) == "table" and stack.ItemId == ref then
				stack.Amount = (stack.Amount or 0) + amount
				stack.TransferredBy = operationId
				return
			end
		end
		table.insert(items, {
			ItemId = ref,
			Amount = amount,
			Escrow = "",
			TransferredBy = operationId,
		})
		return
	end
	if kind == "Instance" then
		local item = extra and (extra.Item or extra)
		if typeof(item) ~= "table" then
			return
		end
		local copy = deepCopy(item)
		copy.Escrow = nil
		copy.TransferredBy = operationId
		if typeof(copy.UID) ~= "string" or copy.UID == "" then
			copy.UID = operationId
		end
		table.insert(inventoryItems(profile.Data), copy)
	end
end

function Trade.ReleaseEscrow(profile: any, kind: string, ref: string, amount: number, tradeId: string): any?
	local trade = tradeBucket(profile.Data)
	local key = reserveKey(kind, ref)
	local reserved = trade.Reserved[key]
	if not reserved or reserved.TradeId ~= tradeId or reserved.Amount < amount then
		return nil
	end
	local extra = { Item = reserved.Item, UID = reserved.UID }
	reserved.Amount -= amount
	if reserved.Amount <= 0 then
		trade.Reserved[key] = nil
	end
	return extra
end

function Trade.DebitReserved(profile: any, kind: string, ref: string, amount: number, tradeId: string): boolean
	return Trade.ReleaseEscrow(profile, kind, ref, amount, tradeId) ~= nil
end

local function refundReserved(profile: any, reserved: any)
	if reserved.Kind == "Currency" then
		profile.Data.Currencies = profile.Data.Currencies or {}
		profile.Data.Currencies[reserved.Ref] = (profile.Data.Currencies[reserved.Ref] or 0) + reserved.Amount
	elseif reserved.Kind == "Stack" then
		local items = inventoryItems(profile.Data)
		for _, stack in items do
			if typeof(stack) == "table" and stack.ItemId == reserved.Ref then
				stack.Amount = (stack.Amount or 0) + reserved.Amount
				return
			end
		end
		table.insert(items, { ItemId = reserved.Ref, Amount = reserved.Amount, Escrow = "" })
	elseif reserved.Kind == "Instance" and typeof(reserved.Item) == "table" then
		local item = deepCopy(reserved.Item)
		item.Escrow = nil
		table.insert(inventoryItems(profile.Data), item)
	end
end

function Trade.Abort(profile: any, tradeId: string)
	if not profile then
		return
	end
	local trade = tradeBucket(profile.Data)
	if trade.ActiveTradeId ~= tradeId then
		return
	end
	for key, reserved in trade.Reserved do
		if reserved.TradeId == tradeId then
			refundReserved(profile, reserved)
			trade.Reserved[key] = nil
		end
	end
	trade.ActiveTradeId = ""
end

function Trade.AbortIfActive(profile: any)
	if not profile or typeof(profile.Data) ~= "table" then
		return
	end
	local trade = tradeBucket(profile.Data)
	if typeof(trade.ActiveTradeId) == "string" and trade.ActiveTradeId ~= "" then
		Trade.Abort(profile, trade.ActiveTradeId)
	end
end

local function applyOffers(fromProfile: any, toProfile: any, offers: { any }, tradeId: string, operationId: string): boolean
	if typeof(offers) ~= "table" or #offers > MAX_OFFERS then
		return false
	end
	for _, offer in offers do
		if typeof(offer) ~= "table" or not validKind(offer.Kind, offer.Ref) or not validAmount(offer.Amount) then
			return false
		end
		local extra = Trade.ReleaseEscrow(fromProfile, offer.Kind, offer.Ref, offer.Amount, tradeId)
		if extra == nil then
			return false
		end
		Trade.Credit(toProfile, offer.Kind, offer.Ref, offer.Amount, operationId, extra)
	end
	return true
end

function Trade.Commit(store: any, profileA: any, profileB: any, offersA: { any }, offersB: { any }): boolean
	if not profileA or not profileB or not profileA:IsActive() or not profileB:IsActive() then
		return false
	end
	local a = tradeBucket(profileA.Data)
	local b = tradeBucket(profileB.Data)
	local tradeId = a.ActiveTradeId
	if tradeId == "" or tradeId ~= b.ActiveTradeId then
		return false
	end
	local destA = profileA.Data
	local destB = profileB.Data
	local snapA = deepCopy(destA)
	local snapB = deepCopy(destB)
	local operationId = opId()
	if not applyOffers(profileA, profileB, offersA, tradeId, operationId) or not applyOffers(profileB, profileA, offersB, tradeId, operationId) then
		overlay(destA, snapA)
		overlay(destB, snapB)
		return false
	end
	a = tradeBucket(destA)
	b = tradeBucket(destB)
	a.ActiveTradeId = ""
	b.ActiveTradeId = ""
	a.TradesToday += 1
	b.TradesToday += 1
	a.LastTradeAt = os.time()
	b.LastTradeAt = os.time()
	local okA = saveWait(profileA)
	local okB = saveWait(profileB)
	if not okA or not okB then
		overlay(destA, snapA)
		overlay(destB, snapB)
		saveWait(profileA)
		saveWait(profileB)
		return false
	end
	return true
end

function Trade.SendOffline(store: any, key: string, payload: any): boolean
	if typeof(store) ~= "table" or typeof(key) ~= "string" or key == "" or typeof(payload) ~= "table" then
		return false
	end
	if payload.Credit then
		if not validKind(payload.Kind, payload.Ref) or not validAmount(payload.Amount) then
			return false
		end
		if typeof(payload.OperationId) ~= "string" or payload.OperationId == "" then
			payload.OperationId = opId()
		end
	end
	return store:MessageAsync(key, {
		Kind = "Trade",
		Payload = payload,
	})
end

function Trade.HandleMessage(profile: any, message: any, processed: () -> ())
	if typeof(message) ~= "table" or message.Kind ~= "Trade" then
		return
	end
	local body = message.Payload
	if typeof(body) ~= "table" then
		processed()
		return
	end
	if body.Abort then
		if typeof(body.TradeId) == "string" then
			Trade.Abort(profile, body.TradeId)
		end
		processed()
		return
	end
	if body.Credit then
		Trade.Credit(profile, body.Kind, body.Ref, body.Amount, body.OperationId, body.Extra)
		processed()
		return
	end
	processed()
end

return Trade
