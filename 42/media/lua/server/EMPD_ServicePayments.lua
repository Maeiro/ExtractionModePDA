if isClient and isClient() then return end
local Prices = require "ExtractionModePDA/ServicePrices"
require "ExtractionMode/BarterServices"
local okBank, bank = pcall(require, "PRPGE_BankServer")
local okTraders, traders = pcall(require, "PRPGE_TradersServer")
local okCurrency, currency = pcall(require, "PRPGE_Currency")
local okData, bankData = pcall(require, "PRPGE_BankData")
local historyLimit = okData and type(bankData) == "table" and tonumber(bankData.LOG) or 24
local barters, services = ExtractionMode.Barters, ExtractionMode.BarterServices
if type(services) ~= "table" or type(services.complete) ~= "function" or type(services.snapshot) ~= "function"
    or type(barters.requirementsMet) ~= "function" or type(barters.consumeRequirements) ~= "function" then
    print("[ExtractionModePDA] Service payments unavailable: incompatible Extraction Mode service API.")
    return
end
if services._empdaPayments then return end
local ready = okBank and okTraders and okCurrency and type(bank) == "table" and type(traders) == "table"
    and type(currency) == "table" and type(bank.Spendable) == "function" and type(bank.Sync) == "function"
    and traders._PRPGE_BANK == true and type(traders.Money) == "function" and type(traders.Charge) == "function"
    and type(currency.Value) == "function" and type(currency.Pay) == "function"
local transactions = {}
local quotes = setmetatable({}, {__mode = "k"})
local originalMet, originalConsume, originalCost = barters.requirementsMet, barters.consumeRequirements, barters.serviceCost
local originalComplete, originalSnapshot = services.complete, services.snapshot

barters.serviceCost = function(definition)
    if transactions[definition] then return 0 end
    return originalCost(definition)
end

barters.requirementsMet = function(player, definition)
    local transaction = transactions[definition]
    if transaction then return ready and traders.Money(player) >= transaction.cost end
    if Prices.supported(definition) then return ready and traders.Money(player) >= Prices.get(definition.service) end
    return originalMet(player, definition)
end

barters.consumeRequirements = function(player, definition)
    local transaction = transactions[definition]
    if not transaction then return originalConsume(player, definition) end
    if transaction.charged then return false end
    local cash = currency.Value(player)
    local balance, account = bank.Spendable(player)
    if not traders.Charge(player, transaction.cost) then return false end
    transaction.charged = true
    transaction.cash = math.max(0, cash - currency.Value(player))
    transaction.bank = account and math.max(0, balance - account.bal) or 0
    transaction.account = account
    quotes[player] = nil
    return true
end

local function sync(player)
    local ok, err = pcall(bank.Sync, player)
    if not ok then print("[ExtractionModePDA] Bank display sync failed: " .. tostring(err)) end
end

services.snapshot = function(root, player, trust)
    local result = originalSnapshot(root, player, trust)
    local now, saved = ExtractionMode.Util.nowMs(), quotes[player] or {}
    for token, quote in pairs(saved) do if now - quote.at > 15000 then saved[token] = nil end end
    for _, definition in ipairs(barters.definitions()) do
        if Prices.supported(definition) then
            for _, option in ipairs(result[definition.id] or {}) do
                saved[tostring(option.quote)] = {id = definition.id, cost = Prices.get(definition.service), at = now}
            end
        end
    end
    quotes[player] = saved
    local cash, balance = 0, 0
    if ready then cash, balance = currency.Value(player), bank.Spendable(player) end
    local prices = {}
    for service in pairs(Prices.settings) do prices[service] = Prices.get(service) end
    result._empdaFunds = {cash = cash, bank = balance, total = cash + balance, prices = prices, available = ready == true}
    return result
end

services.complete = function(root, player, definition, trust, token)
    if not Prices.supported(definition) then return originalComplete(root, player, definition, trust, token) end
    if not ready then return false, "PDA service payments are unavailable with this PDA version." end
    local cost = Prices.get(definition.service)
    local quoted = (quotes[player] or {})[tostring(token or "")]
    if not quoted or quoted.id ~= definition.id or quoted.cost ~= cost then
        return false, "Service price or selection changed. Select the target again."
    end
    local payable = {}
    for key, value in pairs(definition) do payable[key] = value end
    local transaction = {cost = cost}
    transactions[payable] = transaction
    -- Native completion still validates the target and applies/rolls back the service.
    -- Its cash-only payment/refund loop is replaced for this one definition instance.
    local ok, completed, message = pcall(originalComplete, root, player, payable, trust, token)
    transactions[payable] = nil
    if ok and not completed and transaction.charged then
        if transaction.cash > 0 then currency.Pay(player, transaction.cash) end
        if transaction.bank > 0 then
            local account = transaction.account
            account.bal = account.bal + transaction.bank
            table.insert(account.log, 1, {k = "dep", a = transaction.bank,
                h = getGameTime():getWorldAgeHours(), x = "Extraction service refund"})
            while #account.log > math.max(1, historyLimit or 24) do table.remove(account.log) end
        end
        message = "Service failed; the payment was refunded to its original sources."
    end
    if transaction.charged then sync(player) end
    if not ok then error(completed) end
    return completed, message
end

if not ready then print("[ExtractionModePDA] Service payments disabled: incompatible Survivor PDA bank API.") end
services._empdaPayments = true
