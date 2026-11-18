local home, atHome, enabled, ready = {}, true, true, true
local definitions = {}
local storedCounts = {["EMPDA_Operation:Base.Speaker"] = {4}}
local upgradeDefinitions = {}
local invalidations, acceptCalls = 0, 0
local index = {
    enabled = function() return enabled end,
    snapshot = function()
        return {enabled = enabled, ready = ready, counts = ready and storedCounts or {}}
    end,
    tick = function() definitions = ExtractionMode.Upgrades.definitions() end,
    invalidate = function() invalidations = invalidations + 1; ready = false end,
}
local player = {getUsername = function() return "test" end, isDead = function() return false end}
local offer = {item = "Base.Speaker", kind = "deliver", n = 1}
local zeroOffer = {item = "Base.Notebook", kind = "deliver", n = 2}
local killOffer = {kind = "kill", n = 20}
local active = {item = "Base.Speaker", kind = "deliver", n = 2}
local countCalls = 0
local traders = {
    Data = function()
        return {users = {test = {active = {active}, mailOffers = {zeroOffer},
            tr = {doctor = {board = {offers = {offer}}}}}}}
    end,
    Count = function(_, item)
        countCalls = countCalls + 1
        return item == "Base.Speaker" and 3 or 0
    end,
    Snapshot = function()
        return {offers = {offer, zeroOffer, killOffer}, traders = {{board = {offer}}}, active = {active}}
    end,
    Progress = function() return 0 end,
    Take = function() return false end,
    TurnIn = function(p, args)
        return package.loaded.PRPGE_TradersServer.Take(p, args.item, args.amount)
    end,
    Accept = function(_, args)
        acceptCalls = acceptCalls + 1
        return args.reject and "TrFull" or nil
    end,
}
ExtractionMode = {
    HideoutSupplyIndex = index,
    Quests = {definitions = function() return {} end},
    Upgrades = {definitions = function() return upgradeDefinitions end, itemMatchesRequirement = function(item, requirement)
        for _, itemType in ipairs(requirement.types or {}) do if item.itemType == itemType then return true end end
        return false
    end},
    Hideouts = {current = function() return home end, at = function() return atHome and home end,
        canAccess = function() return true end, with = function(_, callback) return callback() end},
    Infection = {playerInsideHideout = function() return atHome end},
    Util = {players = function() return {player} end},
}
for _, name in ipairs({"HideoutSupplyIndex", "Quests", "Hideouts", "Infection"}) do
    package.preload["ExtractionMode/" .. name] = function() return {} end
end
package.preload.PRPGE_TradersServer = function() return traders end
package.preload.PRPGE_TradersData = function() return {} end
local storyMission = {st = "test", state = "active", step = "delivery"}
local storyCalls = 0
local story = {
    Data = function() return {users = {test = {list = {storyMission}}}} end,
    SendStep = function(_, mission, step)
        storyCalls = storyCalls + 1
        mission.step = step
        return true
    end,
}
local storyData = {STORIES = {test = {steps = {
    delivery = {deliver = true, need = {{{t = "Base.Notebook", n = 1}}}},
    nextDelivery = {deliver = true, need = {{{t = "Base.Pen", n = 2}}}},
    dialogue = {},
}}}}
package.preload.PRPGE_StoryServer = function() return story end
package.preload.PRPGE_StoryData = function() return storyData end
dofile(serverSource)
index.tick({})
local found = {}
for _, definition in ipairs(definitions) do found[definition.id] = true end
assert(found["EMPDA_Operation:Base.Notebook"], "mail offers must be scanned before acceptance")
assert(found["EMPDA_Operation:Base.Speaker"], "board offers must be scanned before acceptance")
assert(found["EMPDA_StoryItem:Base.Notebook"], "story deliveries must enter the background scan")
assert(story.SendStep("test", storyMission, "delivery") == true)
assert(story.SendStep("test", storyMission, "delivery") == true)
assert(invalidations == 0 and ready, "repeated delivery notifications must retain the cache")
assert(story.SendStep("test", storyMission, "nextDelivery") == true)
assert(invalidations == 0 and ready, "new delivery requirements must not discard unrelated counts")
index.tick({})
local nextFound = false
for _, definition in ipairs(definitions) do
    if definition.id == "EMPDA_StoryItem:Base.Pen" then nextFound = true end
end
assert(nextFound, "new story requirements must enter the next background scan")
assert(story.SendStep("test", storyMission, "dialogue") == true)
assert(storyCalls == 4 and invalidations == 0, "native story progression must remain intact")
local snapshot = traders.Snapshot(player)
assert(offer.empdaAvailable == 7, "show uncapped inventory plus hideout count")
assert(zeroOffer.empdaAvailable == 0, "zero must be shown")
assert(killOffer.empdaAvailable == nil, "kill offers must retain their original objective")
assert(active.empdaAvailable == nil, "active progress display must stay unchanged")
assert(countCalls == 2, "duplicate offered items should only be counted once per snapshot")
assert(traders.Accept(player, {}) == nil)
assert(acceptCalls == 1, "acceptance must still run the native operation")
assert(invalidations == 0 and ready, "accepting an indexed offer must preserve the supply cache")
assert(traders.Progress(player, active) == 2, "stored items must remain available immediately after accepting")
assert(traders.Accept(player, {reject = true}) == "TrFull")
assert(invalidations == 0, "rejected acceptance must not discard the cache")
assert(offer.empdaSupplyLoading == false, "indexed offers must not show loading")
assert(zeroOffer.empdaSupplyLoading == true, "new offers missing from the cache must show loading")
ready = false
traders.Snapshot(player)
assert(offer.empdaSupplyLoading == true, "offers must show loading during the first scan")
assert(active.empdaSupplyLoading == true, "active operations must show loading too")
ready = true
atHome = false
traders.Snapshot(player)
assert(offer.empdaAvailable == 3, "outside the hideout only carried items count")
assert(offer.empdaSupplyLoading == false, "leaving the hideout must clear loading")
atHome, enabled = true, false
traders.Snapshot(player)
assert(offer.empdaAvailable == 3, "disabled hideout supply must not add stored items")

local function event() return {Add = function() end, Remove = function() end} end
Events = {OnGameStart = event(), OnTick = event()}
local originalGoal = "Deliver 1 x Speaker"
local client = {MissionGoal = function() return originalGoal end}
package.preload.PRPGE_TradersClient = function() return client end
package.preload.PRPGE_MailClient = function() return {HaveItems = function() return false end} end
local function render(ui, mission)
    ui:drawTextZoomed(client.MissionGoal(mission), 10, 20, 1, 0.8, 0.8, 0.8, 1, "Small")
    ui:drawTextZoomed("Reward", 10, 40, 1, 0.8, 0.8, 0.8, 1, "Small")
    if ui.fail then error("render failure") end
end
local operations, board = {Render = render}, {Render = render}
package.preload.PRPGE_PDAOperations = function() return operations end
package.preload.PRPGE_PDATraders = function() return board end
Events.OnTick.Add = function(callback) callback() end
getText = function(key, value)
    if key == "UI_PRPGE_EMPD_SupplyLoading" then return "Checking hideout items..." end
    return "You have " .. value
end
dofile(clientSource)
assert(client.MissionGoal(offer) == originalGoal .. " (You have 3)")
assert(client.MissionGoal(zeroOffer) == originalGoal .. " (You have 0)")
assert(client.MissionGoal(active) == originalGoal)
assert(client.MissionGoal(killOffer) == originalGoal)
local pending = {n = 2, empdaAvailable = 0, empdaSupplyLoading = true}
assert(client.MissionGoal(pending) == originalGoal .. " (Checking hideout items...)")
local loadingColor
operations.Render({drawTextZoomed = function(_, text, x, y, zoom, r, g, b)
    if text:find("Checking hideout", 1, true) then loadingColor = {r, g, b} end
end}, pending)
assert(loadingColor[1] == 1 and loadingColor[2] == 0.83 and loadingColor[3] == 0.40,
    "pending counts must show yellow instead of a false red zero")
getText = function(key, value) return "Você tem " .. value end
assert(client.MissionGoal(offer) == originalGoal .. " (Você tem 3)")
for _, page in ipairs({operations, board}) do
    for _, case in ipairs({{have = 0, color = {1, 0.36, 0.30}},
        {have = 1, color = {1, 0.83, 0.40}}, {have = 2, color = {0.40, 0.92, 0.55}},
        {have = 3, color = {0.40, 0.92, 0.55}}}) do
        local draws = {}
        local draw = function(_, text, x, y, zoom, r, g, b)
            draws[#draws + 1] = {r, g, b}
        end
        local ui = setmetatable({}, {__index = {drawTextZoomed = draw}})
        page.Render(ui, {n = 2, empdaAvailable = case.have})
        for i = 1, 3 do assert(draws[1][i] == case.color[i]) end
        assert(draws[2][1] == 0.8, "the reward must keep its own color")
        assert(rawget(ui, "drawTextZoomed") == nil, "restore inherited drawing method")
        ui.fail = true
        assert(not pcall(page.Render, ui, active))
        assert(rawget(ui, "drawTextZoomed") == nil, "restore the drawing method after errors")
        assert(draws[3][1] == 0.8, "active missions must keep their own color")
    end
end
atHome, enabled, ready = true, true, true
local container = {items = {}}
local function item(itemType, count)
    local value = {itemType = itemType, count = count}
    function value:getContainer() return container end
    function value:getCount() return self.count end
    function value:isFavorite() return false end
    function value:isEquipped() return false end
    function value:getAttachedSlot() return -1 end
    container.items[value] = true
    return value
end
local speaker, notebook = item("Base.Speaker", 4), item("Base.Notebook", 3)
local playerItems = {}
ExtractionMode.InventoryAccess = {
    items = function() return playerItems end,
    containsItem = function(owner, value) return owner.items[value] == true end,
}
storedCounts = {["EMPDA_Operation:Base.Speaker"] = {4}, ["EMPDA_Operation:Base.Notebook"] = {3}}
upgradeDefinitions = {{id = "overlap", requirements = {{types = {"Base.Speaker", "Base.Notebook"}}}}}
storedCounts.overlap = {7}
local failTransaction = false
index.consumeUpgrade = function(p, definition)
    if failTransaction then index.invalidate(); return false end
    for _, requirement in ipairs(definition.requirements) do
        local remaining = requirement.amount
        for _, value in ipairs({speaker, notebook}) do
            if container.items[value] and ExtractionMode.Upgrades.itemMatchesRequirement(value, requirement) then
                local take = math.min(value.count, remaining)
                value.count, remaining = value.count - take, remaining - take
                if value.count == 0 then container.items[value] = nil end
            end
        end
        assert(remaining == 0)
    end
    index.invalidate()
    return true
end
assert(traders.TurnIn(player, {item = "Base.Speaker", amount = 2}))
local after = index.snapshot()
assert(after.ready and after.counts["EMPDA_Operation:Base.Speaker"][1] == 2,
    "subtract the actual consumed stack from the retained count")
assert(after.counts["EMPDA_Operation:Base.Notebook"][1] == 3, "keep unrelated missions ready")
assert(after.counts.overlap[1] == 5, "deduct consumption from every overlapping requirement")
local previousHome = home
home = {}
assert(index.snapshot().ready == false, "retained counts must not leak to another hideout")
home = previousHome
after.counts["EMPDA_Operation:Base.Notebook"][1] = 999
assert(index.snapshot().counts["EMPDA_Operation:Base.Notebook"][1] == 3, "return detached numeric snapshots")
assert(traders.Progress(player, active) == 2, "another mission using the same item remains ready")
assert(traders.TurnIn(player, {item = "Base.Speaker", amount = 2}))
assert(index.snapshot().counts["EMPDA_Operation:Base.Speaker"][1] == 0, "successive turn-ins must not reuse spent items")
assert(traders.TurnIn(player, {item = "Base.Notebook", amount = 1}))
assert(index.snapshot().counts["EMPDA_Operation:Base.Notebook"][1] == 2, "a different mission can be delivered immediately")
assert(index.snapshot().counts.overlap[1] == 2, "overlapping totals must track successive deliveries")
failTransaction = true
assert(not traders.TurnIn(player, {item = "Base.Notebook", amount = 1}))
assert(index.snapshot().ready == false, "failed validation must discard retained counts")
failTransaction, ready = false, true
storedCounts = {["EMPDA_Operation:Base.Notebook"] = {2}}
assert(index.snapshot().counts["EMPDA_Operation:Base.Notebook"][1] == 2, "a completed scan must replace the retained data")
playerItems = {notebook}
assert(traders.TurnIn(player, {item = "Base.Notebook", amount = 1}))
assert(index.snapshot().counts["EMPDA_Operation:Base.Notebook"][1] == 2, "carried materials must not reduce stored totals")
index.invalidate("external change")
assert(index.snapshot().ready == false, "external invalidation must still discard the cache")
ready, playerItems = true, {}
storedCounts = {["EMPDA_Operation:Base.Notebook"] = {1}}
ExtractionMode.InventoryAccess.itemContainer = function() return {isEmpty = function() return false end} end
assert(traders.TurnIn(player, {item = "Base.Notebook", amount = 1}))
assert(index.snapshot().ready == false, "consuming a nonempty container must fall back to a scan")
print("offer_counts_spec: passed")
