local Supply = require "ExtractionModePDA/HideoutMissionSupply"

local function clientState(playerNum)
    if ExtractionMode and ExtractionMode.Client and ExtractionMode.Client.stateFor then
        return ExtractionMode.Client.stateFor(playerNum or 0) or {}
    end
    return ExtractionMode and ExtractionMode.ClientState or {}
end

local function storySupplySnapshot()
    local player = getSpecificPlayer and getSpecificPlayer(0)
    local hideouts, infection = ExtractionMode and ExtractionMode.Hideouts, ExtractionMode and ExtractionMode.Infection
    if not player or not hideouts or not infection then return nil end
    local home = hideouts.at(player)
    if home == nil or not hideouts.canAccess(home, player) then return nil end
    local ok, inside = pcall(function()
        return hideouts.with(home, function() return infection.playerInsideHideout(player) end)
    end)
    if not ok or inside ~= true then return nil end
    return clientState(0).hideoutUpgradeSupply
end

local function patchQuestPanel()
    local panel = ExtractionMode and ExtractionMode.QuestPanel
    if not panel or type(panel.refreshInventoryCounts) ~= "function" then return false end
    if panel._empdaMissionSupply then return true end
    local original = panel.refreshInventoryCounts
    panel.refreshInventoryCounts = function(self, ...)
        local previous = self._empdaSupplyCounts or {}
        for questId, row in pairs(previous) do
            for index, amount in pairs(row) do
                local counts = self.requirementCounts and self.requirementCounts[questId]
                if counts then counts[index] = math.max(0, (tonumber(counts[index]) or 0) - amount) end
            end
        end
        self._empdaSupplyCounts = nil
        original(self, ...)

        local state = clientState(self.playerNum)
        local definitions = self.acquiredDefinitions and self:acquiredDefinitions() or {}
        local added = Supply.addQuestCounts(self.requirementCounts, definitions, storySupplySnapshot())
        self._empdaSupplyCounts = added
        for _, definition in ipairs(definitions) do
            if not ExtractionMode.Quests.isCompleted(state.quests, definition.id) then
                local available = true
                for index, requirement in ipairs(definition.requirements or {}) do
                    local amount = tonumber(requirement.amount) or 0
                    local count = tonumber((self.requirementCounts[definition.id] or {})[index]) or 0
                    if count < amount then available = false; break end
                end
                self.requirementsAvailable[definition.id] = available
            end
        end
    end
    panel._empdaMissionSupply = true
    return true
end

local function patchStoryAvailability()
    local ok, mail = pcall(require, "PRPGE_MailClient")
    if not ok or type(mail) ~= "table" or type(mail.HaveItems) ~= "function" then return false end
    if mail._empdaHideoutSupply then return true end
    local original = mail.HaveItems
    mail.HaveItems = function(need)
        if original(need) then return true end
        local snapshot = storySupplySnapshot()
        if type(snapshot) ~= "table" or snapshot.enabled ~= true or snapshot.ready ~= true then return false end
        for _, gift in ipairs(need or {}) do
            local carried = tonumber(mail.ItemCount(gift.t, gift.tag, gift.alt)) or 0
            local stored = 0
            if gift.t ~= "Base.Money" and gift.t ~= "Base.MoneyBundle"
                and not (mail.IsMoney and mail.IsMoney(gift.t)) then
                stored = Supply.storyItemCount(snapshot, gift)
            end
            if carried + stored < (tonumber(gift.n) or 1) then return false end
        end
        return true
    end
    mail._empdaHideoutSupply = true
    return true
end

local function waitForQuestPanel()
    local panelPatched = patchQuestPanel()
    local storyPatched = patchStoryAvailability()
    if panelPatched and storyPatched and Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(waitForQuestPanel)
    end
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(waitForQuestPanel) end
if Events and Events.OnTick then Events.OnTick.Add(waitForQuestPanel) end
