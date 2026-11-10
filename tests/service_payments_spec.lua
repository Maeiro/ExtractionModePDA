local now, spawnedMoney, syncs = 1000, 0, {}
SandboxVars = {ExtractionModePDA = {}}
ExtractionMode = {Util = {nowMs = function() return now end}}
package.loaded["ExtractionMode/Util"] = true
isClient = function() return false end
getGameTime = function() return {getWorldAgeHours = function() return 40 end} end
local function list(items)
    return {size = function() return #items end, get = function(_, i) return items[i + 1] end}
end
local function inventory()
    local inv = {items = {}}
    function inv:AddItem(kind)
        local item = {kind = kind}
        function item:getContainer() return inv end
        self.items[#self.items + 1] = item
        return item
    end
    function inv:Remove(item)
        for i, value in ipairs(self.items) do if value == item then table.remove(self.items, i); return end end
    end
    function inv:getAllTypeRecurse(kind)
        local matches = {}
        for _, item in ipairs(self.items) do if item.kind == kind then matches[#matches + 1] = item end end
        return list(matches)
    end
    function inv:getItems() return list(self.items) end
    return inv
end
instanceof = function(item, kind) return item.class == kind end
instanceItem = function() spawnedMoney = spawnedMoney + 1; return {} end
local function player(cash, balance, bundles)
    local inv = inventory()
    for _ = 1, cash or 0 do inv:AddItem("Base.Money") end
    for _ = 1, bundles or 0 do inv:AddItem("Base.MoneyBundle") end
    local weapon = {class = "HandWeapon", condition = 2}
    function weapon:getCondition() return self.condition end
    function weapon:getConditionMax() return 10 end
    function weapon:setCondition(value)
        if self.fail and value > self.condition then error("setter failed") end
        self.condition = value
    end
    function weapon:isRanged() return false end
    function weapon:getID() return 1 end
    function weapon:getDisplayName() return "Knife" end
    inv.items[#inv.items + 1] = weapon
    return {account = {bal = balance or 0, opened = true, log = {}}, weapon = weapon,
        getInventory = function() return inv end, isEquippedClothing = function() return false end}
end
Cur = assert(loadstring(currencySource))()
package.loaded.PRPGE_Currency = Cur
S = {Enabled = function() return true end, Account = function(p) return p.account end,
    Sync = function(p) syncs[#syncs + 1] = p end}
TS = {Money = function(p) return Cur.Value(p) end, Charge = function(p, amount) return Cur.Charge(p, amount) end}
package.loaded.PRPGE_TradersServer, package.loaded.PRPGE_BankServer = TS, S
package.loaded.PRPGE_BankData = {LOG=24}
log = function(account, kind, amount, extra)
    table.insert(account.log, 1, {k = kind, a = amount, x = extra})
    while #account.log > 40 do table.remove(account.log) end
end
assert(loadstring("function S.Spendable" .. bankChargeSource))()
local definition = {id = "porch_repair", service = "melee", contactId = "porch", requiredTrust = 10,
    offered = {{types = {"Base.Money"}, amount = 20}}}
definition.requirements = definition.offered
Upgrades = {requirementItems = function(p, entry)
    local result = {}
    local items = p:getInventory():getAllTypeRecurse(entry.types[1])
    for i=0,items:size()-1 do result[#result+1]=items:get(i) end
    return result
end, requirementCount = function(p, entry) return p:getInventory():getAllTypeRecurse(entry.types[1]):size() end}
assert(loadstring(consumeSource))()
local barters = {definitions = function() return {definition} end,
    isUnlocked = function(trust, def) return (trust[def.contactId] or 0) >= def.requiredTrust end,
    serviceCost = function(def) return def.offered[1].amount end,
    serviceTier = function() return 1 end,
    requirementsMet = function(p, def) return Upgrades.requirementsMet(p, def) end,
    consumeRequirements = function(p, def) return Upgrades.consumeRequirements(p, def) end}
ExtractionMode.Barters = barters
package.loaded["ExtractionMode/Barters"] = true
local services = assert(loadstring(serviceSource))()
package.loaded["ExtractionMode/BarterServices"] = services
local originalComplete = services.complete
assert(loadstring(paymentSource))()
local prices = require "ExtractionModePDA/ServicePrices"
local trust = {porch = 10}
local function snapshot(p) return services.snapshot({}, p, trust) end
local function quote(p) return snapshot(p).porch_repair[1].quote end
local function complete(p, token) return services.complete({}, p, definition, trust, token or quote(p)) end
local p = player(13, 17)
assert(snapshot(p)._empdaFunds.total == 30)
local old = quote(p)
snapshot(p)
assert(complete(p, old), "native quotes remain usable across an automatic refresh")
assert(p.account.bal == 10 and Cur.Value(p) == 0 and p.weapon.condition == 4, "native bank payment uses cash before bank")
assert(syncs[#syncs] == p)
assert(not complete(p, old) and p.account.bal == 10, "replays cannot debit the account twice")
p = player(0, 19)
assert(not complete(p) and p.weapon.condition == 2 and p.account.bal == 19, "insufficient combined funds have no effect")
p = player(13, 17)
p.weapon.fail = true
assert(not complete(p))
assert(p.account.bal == 17 and Cur.Value(p) == 13 and p.weapon.condition == 2, "native setter failure refunds the original sources")
p = player(0, 100)
old = quote(p)
SandboxVars.ExtractionModePDA.MeleeRepairCost = 50
assert(not complete(p, old) and p.account.bal == 100, "a price change invalidates the old price quote")
assert(snapshot(p)._empdaFunds.prices.melee == 50)
assert(complete(p) and p.account.bal == 50 and p.weapon.condition == 4, "authority charges the configured cost")
p = player(0, 0, 1)
assert(complete(p) and Cur.Value(p) == 50, "native cash bundles and change remain supported")
p = player(0, 100)
p.account.opened = false
assert(snapshot(p)._empdaFunds.total == 0 and not complete(p), "closed accounts are not spendable")
SandboxVars.ExtractionModePDA.MeleeRepairCost = 0
assert(complete(p) and p.account.bal == 100, "zero cost remains a valid free service")
SandboxVars.ExtractionModePDA.MeleeRepairCost = 20
local a, b = player(0, 100), player(0, 100)
old = quote(a)
assert(not complete(b, old) and b.account.bal == 100, "quotes are bound to the authenticated player")
p = player(0, 100)
old = quote(p)
p.weapon.condition = 5
assert(not complete(p, old) and p.account.bal == 100, "native changed-target validation precedes charging")
local enabled = S.Enabled
S.Enabled = function() return false end
p = player(20, 100)
assert(snapshot(p)._empdaFunds.bank == 0 and complete(p) and p.account.bal == 100, "disabled bank permits cash payment only")
S.Enabled = enabled
p = player(0, 100)
old = quote(p)
now = now + 16000
assert(not complete(p, old) and p.account.bal == 100, "native quote expiry is preserved")
SandboxVars.ExtractionModePDA.MeleeRepairCost = 100000
p = player(0, 100000)
assert(complete(p) and p.account.bal == 0 and spawnedMoney == 0, "large costs do not allocate cash refund objects")
assert(prices.get("wound") == 20 and prices.get("clothing") == 10)
SandboxVars.ExtractionModePDA.MeleeRepairCost = -1
assert(prices.get("melee") == 0)
SandboxVars.ExtractionModePDA.MeleeRepairCost = math.huge
assert(prices.get("melee") == 100000)
SandboxVars.ExtractionModePDA.MeleeRepairCost = 0/0
assert(prices.get("melee") == 20)
local purchase={id="purchase",offered={{types={"Base.Money"},amount=25}}}
purchase.requirements=purchase.offered
p=player(5,30)
assert(barters.requirementsMet(p,purchase) and barters.consumeRequirements(p,purchase))
assert(Cur.Value(p)==0 and p.account.bal==10, "all regular Money barters use the native cash-plus-bank payment")
local mixed={id="mixed",offered={{types={"Base.Money"},amount=20},{types={"Base.Bandage"},amount=1}}}
mixed.requirements=mixed.offered
p=player(0,100)
assert(not barters.requirementsMet(p,mixed) and not barters.consumeRequirements(p,mixed) and p.account.bal==100,
    "bank money never replaces a required material")
p:getInventory():AddItem("Base.Bandage")
assert(barters.consumeRequirements(p,mixed) and p.account.bal==80)
assert(p:getInventory():getAllTypeRecurse("Base.Bandage"):size()==0, "native mixed-material consumption remains intact")
p=player(3,97)
p:getInventory():AddItem("Base.Bandage")
local consume=Upgrades.consumeRequirements
Upgrades.consumeRequirements=function() return false end
assert(not barters.consumeRequirements(p,mixed) and p.account.bal==97 and Cur.Value(p)==3,
    "failed material consumption refunds both cash and bank")
Upgrades.consumeRequirements=consume
local summed={offered={{types={"Base.Money"},amount=20},{types={"Base.Money"},amount=20}}}
summed.requirements=summed.offered
p=player(0,30)
assert(not barters.requirementsMet(p,summed) and not barters.consumeRequirements(p,summed) and p.account.bal==30,
    "multiple Money requirements are summed, rather than spending the same balance twice")
local reward={offered={{types={"Base.Cigarettes"},amount=1}},received={{fullType="Base.Money",amount=10}}}
reward.requirements=reward.offered
p=player(0,100)
p:getInventory():AddItem("Base.Cigarettes")
assert(barters.consumeRequirements(p,reward) and p.account.bal==100, "Money rewards remain in the native reward delivery flow")
assert(not prices.supported({service="melee",offered={{types={"Base.Bandage"},amount=1}}}), "material-based custom services stay native")
assert(services.complete ~= originalComplete)
local currentComplete = services.complete
assert(loadstring(paymentSource))()
assert(services.complete == currentComplete, "duplicate loading does not stack payment hooks")
isClient = function() return true end
assert(loadstring(paymentSource))()
assert(services.complete == currentComplete, "clients never install authority payment hooks")
print("Services: native repairs/currency/bank payment, authority prices, refund, stale/replayed/cross-player quotes passed")
