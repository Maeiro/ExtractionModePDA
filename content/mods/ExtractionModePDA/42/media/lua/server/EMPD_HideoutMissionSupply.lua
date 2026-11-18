if isClient and isClient() then return end

local okIndex = pcall(require, "ExtractionMode/HideoutSupplyIndex")
local okQuests = pcall(require, "ExtractionMode/Quests")
local okHideouts = pcall(require, "ExtractionMode/Hideouts")
local okInfection = pcall(require, "ExtractionMode/Infection")
local okSupply, Supply = pcall(require, "ExtractionModePDA/HideoutMissionSupply")
local okTraders, Traders = pcall(require, "PRPGE_TradersServer")
local okTraderData, TraderData = pcall(require, "PRPGE_TradersData")
local okStory, Story = pcall(require, "PRPGE_StoryServer")
local okStoryData, StoryData = pcall(require, "PRPGE_StoryData")
local okMail, Mail = pcall(require, "PRPGE_MailServer")

local em = ExtractionMode or {}
local index = em.HideoutSupplyIndex
local quests = em.Quests
local hideouts = em.Hideouts
local infection = em.Infection
local upgrades = em.Upgrades

if not (okIndex and okQuests and okHideouts and okInfection and okSupply
    and type(index) == "table" and type(index.tick) == "function"
    and type(quests) == "table" and type(quests.definitions) == "function"
    and type(upgrades) == "table" and type(upgrades.definitions) == "function"
    and type(upgrades.itemMatchesRequirement) == "function"
    and type(Traders) == "table" and type(Traders.Progress) == "function"
    and type(Traders.Take) == "function" and type(Traders.TurnIn) == "function") then
    print("[ExtractionModePDA] Hideout mission supplies unavailable: incompatible mod API.")
    return
end
if index._empdaMissionSupply then return end

local function operationItemIsKept(player, item)
    local keep = false
    if player ~= nil and Traders.Hold then pcall(function() keep = Traders.Hold(player, item) == true end) end
    if player == nil then
        pcall(function() keep = keep or item:isEquipped() == true end)
        pcall(function() keep = keep or item:getAttachedSlot() > -1 end)
        pcall(function()
            if instanceof and instanceof(item, "InventoryContainer") then
                local container = item:getItemContainer()
                keep = keep or (container ~= nil and container:isEmpty() == false)
            end
        end)
    end
    pcall(function() keep = keep or item:isFavorite() == true end)
    pcall(function()
        local parent = item:getContainer() and item:getContainer():getContainingItem()
        keep = keep or (parent ~= nil and tostring(parent:getType()):find("KeyRing") ~= nil)
    end)
    pcall(function()
        if item.IsDrainable and item:IsDrainable() and item:getCurrentUsesFloat() < 0.95 then keep = true end
    end)
    return keep
end

local function knownQuestIds()
    local result = {}
    for _, definition in ipairs(quests.definitions()) do result[definition.id] = true end
    return result
end

local function operationDefinition(itemType)
    local types = Supply.operationTypes(itemType, okTraderData and TraderData or nil)
    if #types == 0 then return nil end
    return {
        id = Supply.operationId(itemType),
        requirements = {{types = types, amount = 1, _empdaOperation = true}},
    }
end

local function storyDefinition(gift)
    if type(gift) ~= "table" then return nil end
    if gift.tag then
        return {
            id = Supply.storyTagId(gift.tag),
            requirements = {{_empdaTag = tostring(gift.tag), amount = 1, _empdaOperation = true}},
        }
    end
    local types = Supply.storyItemTypes(gift)
    if #types == 0 then return nil end
    return {
        id = Supply.storyItemId(gift),
        requirements = {{types = types, amount = 1, _empdaOperation = true}},
    }
end

local function playerUsername(player)
    local ok, username = pcall(function() return player:getUsername() end)
    return ok and tostring(username or "") or ""
end

local function operationItemTypes(home)
    local found = {}
    local data = Traders.Data and Traders.Data()
    local users = data and data.users or {}
    local players = em.Util and em.Util.players and em.Util.players() or {}
    for _, player in ipairs(players) do
        local username = playerUsername(player)
        local alive = true
        pcall(function() alive = not player:isDead() end)
        local physicallyHome = alive and hideouts.at(player) == home
        local inside = false
        if physicallyHome then pcall(function() inside = infection.playerInsideHideout(player) end) end
        local user = physicallyHome and inside and users[username] or nil
        if user then
            local function include(missions)
                for _, mission in ipairs(missions or {}) do
                    if mission.item and (mission.kind == "deliver" or mission.kind == "craft" or mission.kind == "recover") then
                        found[tostring(mission.item)] = true
                    end
                end
            end
            include(user.active)
            include(user.mailOffers)
            for _, relation in pairs(user.tr or {}) do
                include(relation.board and relation.board.offers)
            end
        end
    end
    return found
end

local function storyDefinitions(home)
    if not (okStory and type(Story.Data) == "function" and okStoryData
        and type(StoryData.STORIES) == "table") then return {} end
    local currency = okTraderData and TraderData.CURRENCY or "Base.Money"
    local users = Story.Data().users or {}
    local result, seen = {}, {}
    local players = em.Util and em.Util.players and em.Util.players() or {}
    for _, player in ipairs(players) do
        local username = playerUsername(player)
        local alive = true
        pcall(function() alive = not player:isDead() end)
        if alive and hideouts.at(player) == home then
            local inside = false
            pcall(function() inside = infection.playerInsideHideout(player) end)
            local user = inside and users[username] or nil
            for _, mission in ipairs(user and user.list or {}) do
                if mission.state == "active" then
                    local story = StoryData.STORIES[mission.st]
                    local step = story and story.steps and story.steps[mission.step]
                    local needs = step and step.deliver and step.need and step.need[1]
                    for _, gift in ipairs(needs or {}) do
                        if gift.t ~= currency and gift.t ~= "Base.MoneyBundle" then
                            local definition = storyDefinition(gift)
                            if definition and not seen[definition.id] then
                                seen[definition.id] = true
                                result[#result + 1] = definition
                            end
                        end
                    end
                end
            end
        end
    end
    return result
end

local function externalDefinitions()
    local result = {}
    for _, definition in ipairs(quests.definitions()) do
        if #(definition.requirements or {}) > 0 then
            result[#result + 1] = {
                id = Supply.questId(definition.id),
                requirements = definition.requirements,
            }
        end
    end

    local home = hideouts.current()
    if home then
        for itemType in pairs(operationItemTypes(home)) do
            local definition = operationDefinition(itemType)
            if definition then result[#result + 1] = definition end
        end
        for _, definition in ipairs(storyDefinitions(home)) do result[#result + 1] = definition end
    end
    return result
end

local originalDefinitions = upgrades.definitions
local originalMatcher = upgrades.itemMatchesRequirement
local originalTick = index.tick
upgrades.itemMatchesRequirement = function(item, requirement)
    if requirement and requirement._empdaTag then
        local tag
        pcall(function() tag = ItemTag[requirement._empdaTag] end)
        local tagged = false
        if tag then pcall(function() tagged = item:hasTag(tag) == true end) end
        if not tagged then return false end
        local fullType
        pcall(function() fullType = tostring(item:getFullType() or "") end)
        if fullType == nil or fullType == "" then return false end
        local matches = originalMatcher(item, {types = {fullType}})
        return matches and (not requirement._empdaOperation or not operationItemIsKept(nil, item))
    end
    local matches = originalMatcher(item, requirement)
    if matches and requirement and requirement._empdaOperation then
        return not operationItemIsKept(nil, item)
    end
    return matches
end

index.tick = function(data)
    upgrades.definitions = function()
        local definitions = {}
        for _, definition in ipairs(originalDefinitions()) do definitions[#definitions + 1] = definition end
        for _, definition in ipairs(externalDefinitions()) do
            definitions[#definitions + 1] = definition
        end
        return definitions
    end
    local ok, changed = pcall(originalTick, data)
    upgrades.definitions = originalDefinitions
    if not ok then error(changed) end
    return changed
end

local missionIds = knownQuestIds()
local originalRequirementsMet = quests.requirementsMet
local originalConsumeRequirements = quests.consumeRequirements

local function homeFor(player)
    local home = hideouts.at(player)
    if home == nil or not hideouts.canAccess(home, player) then return nil end
    local ok, inside = pcall(function()
        return hideouts.with(home, function() return infection.playerInsideHideout(player) end)
    end)
    return ok and inside == true and home or nil
end

local function store()
    local runtime = ExtractionMode and ExtractionMode.RaidRuntime
    return runtime and runtime.getRootStore and runtime.getRootStore() or nil
end

local retainedSupplies = setmetatable({}, {__mode = "k"})
local originalSnapshot, originalInvalidate = index.snapshot, index.invalidate
local function copySnapshot(snapshot)
    local result = {}
    for key, value in pairs(snapshot) do result[key] = value end
    result.counts = {}
    for id, row in pairs(snapshot.counts or {}) do
        result.counts[id] = {}
        for position, count in pairs(row) do result.counts[id][position] = count end
    end
    return result
end

index.snapshot = function()
    local snapshot = originalSnapshot()
    local home = hideouts.current()
    if home then
        if snapshot.ready or snapshot.enabled ~= true then retainedSupplies[home] = nil
        elseif retainedSupplies[home] then return copySnapshot(retainedSupplies[home]) end
    end
    return snapshot
end

index.invalidate = function(...)
    local home = hideouts.current()
    if home then retainedSupplies[home] = nil end
    return originalInvalidate(...)
end

local function consumeMissionSupplies(player, definition)
    local inventory = em.InventoryAccess
    if not inventory or not inventory.items or not inventory.containsItem then
        return index.consumeUpgrade(player, definition, store())
    end
    local before = index.snapshot()
    if before.ready ~= true then return index.consumeUpgrade(player, definition, store()) end
    local playerItems, observed, definitions, known = {}, {}, {}, {}
    for _, item in ipairs(inventory.items(player)) do playerItems[item] = true end
    for _, entry in ipairs(originalDefinitions()) do definitions[#definitions + 1] = entry end
    for _, entry in ipairs(externalDefinitions()) do definitions[#definitions + 1] = entry end
    for _, entry in ipairs(definitions) do known[entry.id] = true end
    for id in pairs(before.counts or {}) do if not known[id] then before.counts[id] = nil end end
    local reliable = true
    local matcher = upgrades.itemMatchesRequirement
    upgrades.itemMatchesRequirement = function(item, requirement)
        local matches = matcher(item, requirement)
        if matches and not playerItems[item] and not observed[item] then
            local captured = pcall(function()
                local entry = {container = item:getContainer(), count = item:getCount(), rows = {}}
                for _, candidate in ipairs(definitions) do
                    if (before.counts or {})[candidate.id] then
                        for position, needed in ipairs(candidate.requirements or {}) do
                            if matcher(item, needed) then entry.rows[#entry.rows + 1] = {candidate.id, position} end
                        end
                    end
                end
                observed[item] = entry
            end)
            reliable = reliable and captured
        end
        return matches
    end
    local ok, consumed, reason = pcall(index.consumeUpgrade, player, definition, store())
    upgrades.itemMatchesRequirement = matcher
    if not ok then error(consumed) end
    if consumed and reliable then
        -- Keep only numeric totals; item references are used during this transaction alone.
        local reconciled = pcall(function()
            for item, entry in pairs(observed) do
                local remaining = inventory.containsItem(entry.container, item) and item:getCount() or 0
                local removed = math.max(0, entry.count - remaining)
                if removed > 0 then
                    local contents = inventory.itemContainer and inventory.itemContainer(item)
                    if contents and not contents:isEmpty() then error("a nonempty container was consumed") end
                    for _, row in ipairs(entry.rows) do
                        before.counts[row[1]][row[2]] = math.max(0, before.counts[row[1]][row[2]] - removed)
                    end
                end
            end
        end)
        if reconciled then
            local home = hideouts.current()
            if home then retainedSupplies[home] = before end
        end
    end
    return consumed, reason
end

local function missionWorldRequirementsMet(player, definition)
    if type(definition) ~= "table" or missionIds[definition.id] ~= true or not index.enabled() then return false end
    local home = homeFor(player)
    if home == nil then return false end
    local snapshot = hideouts.with(home, index.snapshot)
    if snapshot.ready ~= true then return false end
    local carried = quests.requirementCounts(player, definition.requirements or {})
    local world = (snapshot.counts or {})[Supply.questId(definition.id)] or {}
    for position, requirement in ipairs(definition.requirements or {}) do
        local amount = math.max(0, tonumber(requirement.amount) or 0)
        if (tonumber(carried[position]) or 0) + (tonumber(world[position]) or 0) < amount then return false end
    end
    return true
end

quests.requirementsMet = function(player, definition)
    if originalRequirementsMet(player, definition) then return true end
    return missionWorldRequirementsMet(player, definition)
end

quests.consumeRequirements = function(player, definition)
    if originalConsumeRequirements(player, definition) then return true end
    if type(definition) ~= "table" or missionIds[definition.id] ~= true or not index.enabled() then return false end
    local home = homeFor(player)
    if home == nil then return false end
    return hideouts.with(home, function()
        return consumeMissionSupplies(player, definition)
    end)
end

local function hasSelectedItems(ids)
    return type(ids) == "table" and #ids > 0
end

local originalProgress, originalTake, originalTurnIn = Traders.Progress, Traders.Take, Traders.TurnIn
local traderTurnIns = setmetatable({}, {__mode = "k"})
Traders.Progress = function(player, mission)
    local progress = originalProgress(player, mission)
    if not mission.item or not (mission.kind == "deliver" or mission.kind == "craft" or mission.kind == "recover")
        or progress >= (tonumber(mission.n) or 0) or not index.enabled() then return progress end
    local home = homeFor(player)
    if home == nil then return progress end
    local snapshot = hideouts.with(home, index.snapshot)
    local world = Supply.operationCount(snapshot, mission.item, okTraderData and TraderData or nil)
    return math.min(tonumber(mission.n) or progress, progress + world)
end

if type(Traders.Snapshot) == "function" and type(Traders.Count) == "function" then
    local originalSnapshot = Traders.Snapshot
    Traders.Snapshot = function(player)
        local snapshot = originalSnapshot(player)
        local home = index.enabled() and homeFor(player) or nil
        local supplies = home and hideouts.with(home, index.snapshot) or nil
        local counts = {}
        local function annotate(offers)
            for _, mission in ipairs(offers or {}) do
                if mission.item and (mission.kind == "deliver" or mission.kind == "craft" or mission.kind == "recover") then
                    if counts[mission.item] == nil then
                        counts[mission.item] = Traders.Count(player, mission.item)
                            + Supply.operationCount(supplies, mission.item, okTraderData and TraderData or nil)
                    end
                    mission.empdaAvailable = counts[mission.item]
                    mission.empdaSupplyLoading = Supply.isLoading(supplies, Supply.operationId(mission.item))
                end
            end
        end
        annotate(snapshot.offers)
        for _, trader in ipairs(snapshot.traders or {}) do annotate(trader.board) end
        for _, mission in ipairs(snapshot.active or {}) do
            mission.empdaSupplyLoading = mission.item ~= nil
                and Supply.isLoading(supplies, Supply.operationId(mission.item))
        end
        return snapshot
    end
end

Traders.Take = function(player, itemType, amount, ids)
    if originalTake(player, itemType, amount, ids) then return true end
    if not traderTurnIns[player] or hasSelectedItems(ids) or not index.enabled() then return false end
    local home = homeFor(player)
    if home == nil then return false end
    local requirement = {
        types = Supply.operationTypes(itemType, okTraderData and TraderData or nil),
        amount = amount,
        _empdaOperation = true,
    }
    if #requirement.types == 0 then return false end
    local definition = {requirements = {requirement}}
    local currentMatcher = upgrades.itemMatchesRequirement
    upgrades.itemMatchesRequirement = function(item, candidate)
        if operationItemIsKept(player, item) then return false end
        return currentMatcher(item, candidate)
    end
    local ok, consumed = pcall(function()
        return hideouts.with(home, function()
            return consumeMissionSupplies(player, definition)
        end)
    end)
    upgrades.itemMatchesRequirement = currentMatcher
    return ok and consumed == true
end

Traders.TurnIn = function(player, args)
    traderTurnIns[player] = true
    local ok, result, reward = pcall(originalTurnIn, player, args)
    traderTurnIns[player] = nil
    if not ok then error(result) end
    return result, reward
end

if okStory and okMail and type(Story) == "table" and type(Story.Answer) == "function"
    and type(Mail) == "table" and type(Mail.TakeGift) == "function" then
    local answeringStory = setmetatable({}, {__mode = "k"})
    local originalAnswer, originalTakeGift = Story.Answer, Mail.TakeGift
    Story.Answer = function(player, args)
        answeringStory[player] = true
        local ok, result = pcall(originalAnswer, player, args)
        answeringStory[player] = nil
        if not ok then error(result) end
        return result
    end
    Mail.TakeGift = function(player, gifts)
        if originalTakeGift(player, gifts) then return true end
        if not answeringStory[player] or not index.enabled() or type(gifts) ~= "table" then return false end
        local currency = okTraderData and TraderData.CURRENCY or "Base.Money"
        local requirements = {}
        for _, gift in ipairs(gifts) do
            if type(gift) ~= "table" or gift.t == currency or gift.t == "Base.MoneyBundle" then return false end
            local amount = math.floor(tonumber(gift.n) or 0)
            if amount <= 0 then return false end
            if gift.tag then
                requirements[#requirements + 1] = {
                    _empdaTag = tostring(gift.tag), amount = amount, _empdaOperation = true,
                }
            else
                local types = Supply.storyItemTypes(gift)
                if #types == 0 then return false end
                requirements[#requirements + 1] = {types = types, amount = amount, _empdaOperation = true}
            end
        end
        if #requirements == 0 then return false end
        local home = homeFor(player)
        if home == nil then return false end
        local currentMatcher = upgrades.itemMatchesRequirement
        upgrades.itemMatchesRequirement = function(item, candidate)
            if operationItemIsKept(player, item) then return false end
            return currentMatcher(item, candidate)
        end
        local ok, consumed = pcall(function()
            return hideouts.with(home, function()
                return consumeMissionSupplies(player, {requirements = requirements})
            end)
        end)
        upgrades.itemMatchesRequirement = currentMatcher
        return ok and consumed == true
    end
end

index._empdaMissionSupply = true
