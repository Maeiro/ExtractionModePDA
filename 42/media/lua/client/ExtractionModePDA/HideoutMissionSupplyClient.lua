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

local offerDraw
local offerColors = {empty = {1, 0.36, 0.30}, partial = {1, 0.83, 0.40}, ready = {0.40, 0.92, 0.55}}

local function patchOfferRenderer(name)
    local ok, page = pcall(require, name)
    if not ok or type(page) ~= "table" or type(page.Render) ~= "function" then return false end
    if page._empdaOfferColors then return true end
    local original = page.Render
    page.Render = function(ui, ...)
        local previousDraw = rawget(ui, "drawTextZoomed")
        local draw = ui.drawTextZoomed
        local previousOffer = offerDraw
        local context = {}
        offerDraw = context
        ui.drawTextZoomed = function(self, text, x, y, zoom, r, g, b, alpha, font)
            local color = context.color
            context.color = nil
            if color then r, g, b = color[1], color[2], color[3] end
            return draw(self, text, x, y, zoom, r, g, b, alpha, font)
        end
        local success, result = pcall(original, ui, ...)
        ui.drawTextZoomed = previousDraw
        offerDraw = previousOffer
        if not success then error(result) end
        return result
    end
    page._empdaOfferColors = true
    return true
end

local function patchTraderOffers()
    local ok, traders = pcall(require, "PRPGE_TradersClient")
    if not ok or type(traders) ~= "table" or type(traders.MissionGoal) ~= "function" then return false end
    if traders._empdaOfferCounts then return true end
    local original = traders.MissionGoal
    traders.MissionGoal = function(mission)
        local goal = original(mission)
        if mission.empdaSupplyLoading == true then
            if offerDraw then offerDraw.color = offerColors.partial end
            local key = "UI_PRPGE_EMPD_SupplyLoading"
            local label = getText and getText(key) or key
            if label == key then label = "Checking hideout items..." end
            return goal .. " (" .. label .. ")"
        end
        local available = tonumber(mission.empdaAvailable)
        if available == nil then return goal end
        if offerDraw then
            offerDraw.color = available <= 0 and offerColors.empty
                or available >= (tonumber(mission.n) or 1) and offerColors.ready or offerColors.partial
        end
        local key = "UI_PRPGE_EMPD_OfferHave"
        local label = getText and getText(key, tostring(available)) or key
        if label == key then label = "You have " .. tostring(available) end
        return goal .. " (" .. label .. ")"
    end
    traders._empdaOfferCounts = true
    return true
end

local function waitForQuestPanel()
    local panelPatched = patchQuestPanel()
    local storyPatched = patchStoryAvailability()
    local traderPatched = patchTraderOffers()
    local operationsPatched = patchOfferRenderer("PRPGE_PDAOperations")
    local boardPatched = patchOfferRenderer("PRPGE_PDATraders")
    if panelPatched and storyPatched and traderPatched and operationsPatched and boardPatched
        and Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(waitForQuestPanel)
    end
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(waitForQuestPanel) end
if Events and Events.OnTick then Events.OnTick.Add(waitForQuestPanel) end
