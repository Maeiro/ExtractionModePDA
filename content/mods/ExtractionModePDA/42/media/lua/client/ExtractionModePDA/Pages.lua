local Tracking = require "ExtractionModePDA/QuestTracking"
local GaragePage = require "ExtractionModePDA/GaragePage"
local Pages = {}
local serviceIcons = {
    wound = "Base.FirstAidKit", clothing = "Base.Needle",
    melee = "Base.HuntingKnife", gun = "Base.Pistol", vehicle = "Base.Wrench",
}
local barterTextures = {}

local function barterTexture(definition)
    local reward = (definition.received or {})[1]
    local fullType = serviceIcons[definition.service]
        or (reward and (reward.fullType or (reward.randomTypes or {})[1]))
    if not fullType then return nil end
    if barterTextures[fullType] == nil then
        local ok, texture = pcall(function()
            local item = instanceItem(fullType)
            return item and item:getTex()
        end)
        barterTextures[fullType] = ok and texture or false
    end
    return barterTextures[fullType] or nil
end

function Pages.new(context, widgets)
    local view = {}
    local text, modeText = context.text, widgets.modeText
    local player, inside, send = widgets.player, widgets.inside, widgets.send
    local pageState, liveUI, livePage, supplyPlayer, heartbeat

    local function current() return context.state(0) end
    local function canBuild(data) return inside(data) and data.canContributeHideout ~= false end
    local function reference(data)
        local config = ExtractionMode.Config
        return data.state == config.STATE_RAID or data.state == config.STATE_EXTRACTING or data.state == config.STATE_BOARDING
    end
    local function oneDecimal(value) return string.format("%.1f", tonumber(value) or 0) end
    local function action(label, callback, enabled, selected)
        return {label = label, action = callback, enabled = enabled, selected = selected}
    end
    local function availablePlayer()
        return player() and widgets.allowed()
    end
    local function invalidate()
        if pageState then pageState.counts = nil end
    end
    local function countsFor(definitions, field, countItems, data)
        local p = player()
        local now = getTimestampMs()
        local cache = pageState.counts
        local keys = {}
        for _, def in ipairs(definitions) do keys[#keys + 1] = def.id end
        local signature = table.concat(keys, "|")
        if cache and cache.player == p and cache.signature == signature and now - cache.at < (reference(data) and 5000 or 1000) then
            return cache.counts
        end
        local flat, counts = {}, {}
        for _, def in ipairs(definitions) do
            for _, requirement in ipairs(def[field] or {}) do flat[#flat + 1] = requirement end
        end
        local values = p and countItems(p, flat) or {}
        local index = 0
        for _, def in ipairs(definitions) do
            local row = {}
            counts[def.id] = row
            for i in ipairs(def[field] or {}) do
                index = index + 1
                row[i] = tonumber(values[index]) or 0
            end
        end
        pageState.counts = {player = p, signature = signature, at = now, counts = counts}
        return counts
    end

    local function requirements(flow, entries, counts, label)
        local met = true
        for index, entry in ipairs(entries or {}) do
            local amount, count = tonumber(entry.amount) or 0, tonumber(counts[index]) or 0
            met = met and count >= amount
            flow:add(label(entry) .. ": " .. math.min(count, amount) .. "/" .. amount)
            if count < amount then flow.runs[#flow.runs].warning = true end
        end
        return met
    end

    local function generatorCard(page, data)
        local generator = data.generator or {}
        local api, upgrades = ExtractionMode.Generator, ExtractionMode.Upgrades
        local fuel, capacity = tonumber(generator.fuel) or 0, tonumber(generator.capacity) or api.capacity()
        local gasoline = widgets.refreshSample(data).gasoline
        local editable = canBuild(data)
        local actions = {}
        if not reference(data) then
            actions[#actions + 1] = action(text("Refuel", "REFUEL"), function()
                if canBuild(current()) then send("AddGeneratorFuel") end
            end, editable and fuel < capacity - 0.0001 and gasoline > 0.0001)
            actions[#actions + 1] = action(generator.running and modeText("StopGenerator", "STOP GENERATOR")
                or modeText("StartGenerator", "START GENERATOR"), function()
                local fresh = current()
                if canBuild(fresh) and (fresh.generator or {}).running == generator.running then
                    send("SetGeneratorRunning", {running = generator.running ~= true})
                end
            end, editable and (generator.running == true or fuel > 0.0001))
            if data.debugEnabled then
                actions[#actions + 1] = action(modeText("DebugFillTank", "FILL GENERATOR (DEBUG)"), function()
                    if canBuild(current()) and current().debugEnabled then send("DebugFillGenerator") end
                end, editable and fuel < capacity)
            end
        end
        local heating = upgrades.isInstalled(data.upgrades, "heating")
        local targetLabel
        if heating then
            local enabled = api.heatingEnabled(data)
            local target = api.heatingTarget(data)
            local core = getCore()
            local celsius = not core.getOptionDisplayAsCelsius or core:getOptionDisplayAsCelsius()
            local degrees = celsius and target or target * 9 / 5 + 32
            local min, max = celsius and 15 or 59, celsius and 30 or 86
            targetLabel = oneDecimal(degrees) .. (celsius and " °C" or " °F")
            if not reference(data) then
                actions[#actions + 1] = action(enabled and modeText("TurnHeatingOff", "TURN HEATING OFF")
                    or modeText("TurnHeatingOn", "TURN HEATING ON"), function()
                    local fresh = current()
                    if canBuild(fresh) and api.heatingEnabled(fresh) == enabled then
                        send("SetHeatingEnabled", {enabled = not enabled})
                    end
                end, editable)
                for _, delta in ipairs({-1, 1}) do
                    local value = math.max(min, math.min(max, math.floor(degrees + 0.5) + delta))
                    actions[#actions + 1] = action((delta < 0 and "−1" or "+1") .. (celsius and " °C" or " °F"), function()
                        local fresh = current()
                        if canBuild(fresh) and api.heatingTarget(fresh) == target then
                            send("SetHeatingTemperature", {temperature = celsius and value or (value - 32) * 5 / 9})
                        end
                    end, editable and (delta < 0 and degrees > min or delta > 0 and degrees < max))
                end
            end
        end
        page.card(modeText("Category_Generator", "GENERATOR"), function(flow)
            flow:add(generator.running and modeText("GeneratorRunning", "RUNNING - UTILITIES ONLINE")
                or modeText("GeneratorStopped", "STOPPED - UTILITIES OFFLINE"))
            flow:add(modeText("GeneratorTank", "Tank: %1 / %2 L    Carried gasoline: %3 L",
                oneDecimal(fuel), oneDecimal(capacity), oneDecimal(gasoline)))
            flow:add(text("FuelHours", "Fuel remaining: %1 in-game hours", oneDecimal(generator.hoursRemaining)))
            if targetLabel then flow:add(text("HeatingTarget", "Heating target: %1", targetLabel)) end
        end, actions)
    end

    local function upgrades(page, data)
        local api = ExtractionMode.Upgrades
        generatorCard(page, data)
        local category = pageState.category or "utilities"
        local tabs = {}
        for _, item in ipairs(api.categories()) do
            local id = item.id
            tabs[#tabs + 1] = action(item.label, function() pageState.category = id; invalidate() end, true, id == category)
        end
        page.card(text("UpgradeTab", "Upgrades"), nil, tabs)
        local definitions = api.definitionsForCategory(category)
        local counts = countsFor(definitions, "requirements", api.requirementCounts, data)
        local supply = data.hideoutUpgradeSupply or {}
        for _, definition in ipairs(definitions) do
            local id = definition.id
            local installed = api.isInstalled(data.upgrades, id)
            local prerequisites = api.prerequisitesMet(data.upgrades, definition)
            local skills = api.upgradeSkillRequirementsMet(player(), definition)
            local materialCounts = {}
            local world = supply.ready and (supply.counts or {})[id] or {}
            local allMaterials = true
            for index, requirement in ipairs(definition.requirements or {}) do
                local carried = counts[id][index] or 0
                if reference(data) and supply.ready then carried = 0 end
                materialCounts[index] = carried + (tonumber(world and world[index]) or 0)
                allMaterials = allMaterials and materialCounts[index] >= (tonumber(requirement.amount) or 0)
            end
            local actions = {}
            if not reference(data) then
                local function upgradeCommand(command, debug)
                    return function()
                        local fresh = current()
                        if not canBuild(fresh) or api.isInstalled(fresh.upgrades, id) ~= installed
                            or (debug and not fresh.debugEnabled) then return end
                        send(command, {upgradeId = id})
                        invalidate()
                    end
                end
                if not installed then
                    actions[#actions + 1] = action(modeText("Install", "INSTALL"), upgradeCommand("InstallUpgrade"),
                        canBuild(data) and prerequisites and skills and (supply.enabled or allMaterials))
                end
                if data.debugEnabled then
                    actions[#actions + 1] = action(installed and modeText("DebugRemoveUpgrade", "REMOVE (DEBUG)")
                        or modeText("DebugCompleteUpgrade", "COMPLETE (DEBUG)"), upgradeCommand(
                        installed and "DebugRemoveUpgrade" or "DebugCompleteUpgrade", true), canBuild(data))
                end
            end
            page.card(api.name(definition), function(flow)
                flow:add(api.description(definition))
                if installed then
                    flow:add(modeText("UpgradeActive", "INSTALLED - Active for the shared hideout"))
                else
                    if not prerequisites then flow:add(modeText("Prerequisite", "Prerequisite: %1",
                        table.concat(api.missingPrerequisiteNames(data.upgrades, definition), ", "))) end
                    requirements(flow, definition.requirements, materialCounts, api.label)
                    for _, skill in ipairs(definition.skillRequirements or {}) do
                        flow:add(api.label(skill) .. ": " .. api.skillLevel(player(), skill) .. "/" .. (skill.level or 0))
                    end
                end
            end, actions)
        end
    end

    local function missions(page, data)
        local api = ExtractionMode.Quests
        local definitions = api.acquiredDefinitions(data.quests)
        local tracked = Tracking.get(player(), data)
        local active, completed = {}, {}
        for _, def in ipairs(definitions) do
            if api.isCompleted(data.quests, def.id) then completed[#completed + 1] = def
            elseif def.id == pageState.focus then table.insert(active, 1, def)
            else active[#active + 1] = def end
        end
        local showCompleted = pageState.completed and not reference(data)
        local counts = countsFor(active, "requirements", api.requirementCounts, data)
        page.card(text("Missions", "Missions"), nil, {
            action(text("ActiveMissions", "Active missions"), function() pageState.completed = false end, true, not showCompleted),
            action(modeText("Completed", "COMPLETED"), function() pageState.completed = true end, not reference(data), showCompleted),
        })
        local rows = showCompleted and completed or active
        if #rows == 0 then page.card(text("NoMissions", "No missions to show.")); return end
        for _, def in ipairs(rows) do
            local id = def.id
            local expanded = pageState.expanded == id
            local isTracked = tracked and tracked.id == id
            local actions = {action(expanded and text("HideDetails", "Hide details") or text("MissionDetails", "Mission details"),
                function() pageState.expanded = not expanded and id or nil end)}
            local canTurnIn = not showCompleted and inside(data) and api.skillRequirementsMet(player(), def)
                and api.objectivesMet(data.questObjectives, def)
            for _, goal in ipairs(def.objectives or {}) do
                if goal.type == "raid_visit" and data.raidVisitSuccessful ~= true then canTurnIn = false end
            end
            for index, item in ipairs(def.requirements or {}) do
                if ((counts[id] or {})[index] or 0) < (tonumber(item.amount) or 0) then canTurnIn = false end
            end
            if not showCompleted then
                actions[#actions + 1] = action(isTracked and text("Untrack", "STOP TRACKING") or text("Track", "TRACK MISSION"),
                    function()
                        if isTracked then Tracking.set(player(), current(), nil)
                        else Tracking.set(player(), current(), id) end
                    end, true, isTracked)
                if not reference(data) then
                    actions[#actions + 1] = action(modeText("TurnIn", "TURN IN"), function()
                        local fresh = current()
                        if inside(fresh) and api.isAcquired(fresh.quests, def) and not api.isCompleted(fresh.quests, id) then
                            send("CompleteQuest", {questId = id}); invalidate()
                        end
                    end, canTurnIn)
                    if data.debugEnabled then
                        actions[#actions + 1] = action(modeText("AutoComplete", "AUTO COMPLETE"), function()
                            local fresh = current()
                            if fresh.debugEnabled and not reference(fresh) and not api.isCompleted(fresh.quests, id) then
                                send("DebugCompleteQuest", {questId = id}); invalidate()
                            end
                        end)
                    end
                end
            end
            page.card(api.name(def), function(flow)
                flow:add(api.contactDisplayName(def.contactId))
                flow:add(api.description(def))
                if not showCompleted then
                    for _, goal in ipairs(def.objectives or {}) do
                        local amount = tonumber(goal.amount) or 0
                        flow:add(api.label(goal) .. ": " .. math.min(amount, api.objectiveCount(data.questObjectives, def, goal)) .. "/" .. amount)
                        if goal.type == "raid_visit" then
                            flow:add(modeText("RaidSuccessObjective", "Raid successfully extracted") .. ": "
                                .. (data.raidVisitSuccessful and "1/1" or "0/1"))
                        end
                    end
                    requirements(flow, def.requirements, counts[id] or {}, api.label)
                    for _, skill in ipairs(def.skillRequirements or {}) do
                        flow:add(api.label(skill) .. ": " .. api.skillLevel(player(), skill) .. "/" .. (skill.level or 0))
                    end
                end
                if expanded then
                    for _, reward in ipairs(def.rewards or {}) do
                        if reward.type == "trust" then
                            flow:add(modeText("TrustReward", "+%1 Trust with %2", tostring(reward.amount or 0),
                                api.contactDisplayName(reward.contactId)))
                        elseif reward.type == "location" then
                            flow:add(modeText("UnlockRaidLocation", "Unlock Raid Location: %1",
                                ExtractionMode.Config.townDisplayName(reward.townKey, tostring(reward.townKey or ""))))
                        elseif reward.type == "campaign" then
                            flow:add(modeText("CompleteCampaign", "Complete the campaign"))
                        elseif reward.type == "item" then
                            flow:add(tostring(reward.amount or 1) .. "x " .. (reward.label and api.label(reward) or tostring(reward.fullType)))
                        end
                    end
                    flow:add(api.flavorText(def, showCompleted))
                end
            end, actions)
        end
    end

    local function barter(page, data)
        if reference(data) then page.card(text("BarterAtHideout", "Barter is available at the hideout.")); return end
        local api, localization = ExtractionMode.Barters, ExtractionMode.Localization
        local definitions = api.unlockedDefinitions(data.contactTrust)
        if #definitions == 0 then page.card(text("NoBarters", "No trades unlocked.")); return end
        local counts = countsFor(definitions, "offered", api.requirementCounts, data)
        local contacts = {}
        for _, def in ipairs(definitions) do
            local contact = def.contactId
            if not contacts[contact] then
                contacts[contact] = true
                local trust = (data.contactTrust or {})[contact] or 0
                page.card(ExtractionMode.Quests.contactDisplayName(contact), function(flow)
                    flow:add(modeText("CurrentTrustSuffix", "Current Trust: %1", tostring(trust)))
                end)
            end
            local id = def.id
            local title, actions = {}, {}
            local options, selected, option = (pageState.serviceOptions or {})[id] or {}, 0, nil
            if def.service then
                title[1] = api.serviceName(def, data.contactTrust)
                for index, candidate in ipairs(options) do
                    if pageState.serviceTarget[id] == candidate.id then selected, option = index, candidate; break end
                end
                local function selectTarget(delta)
                    local target = options[selected + delta]
                    if target then pageState.serviceTarget[id] = target.id end
                end
                actions[#actions + 1] = action("‹", function() selectTarget(-1) end, selected > 1)
                actions[#actions + 1] = action("›", function() selectTarget(1) end, selected < #options)
            else
                for _, item in ipairs(def.received or {}) do title[#title + 1] = (item.amount or 1) .. "x " .. api.label(item) end
            end
            local affordable = inside(data)
            for index, item in ipairs(def.offered or {}) do
                affordable = affordable and (counts[id][index] or 0) >= (tonumber(item.amount) or 0)
            end
            actions[#actions + 1] = action(modeText("Trade", "TRADE"), function()
                if not inside(current()) or not api.isUnlocked(current().contactTrust, def) then return end
                if option then
                    local valid
                    for _, fresh in ipairs((pageState.serviceOptions or {})[id] or {}) do
                        if fresh.id == option.id and fresh.quote == option.quote and fresh.canUse ~= false then valid = true end
                    end
                    if not valid then return end
                    pageState.serviceOptions[id] = nil
                end
                send("CompleteBarter", {barterId = id, quote = option and option.quote})
                invalidate()
            end, affordable and (not def.service or option ~= nil and option.canUse ~= false))
            page.card(table.concat(title, " + "), function(flow)
                requirements(flow, def.offered, counts[id], api.label)
                if def.service then
                    local nextTrust = api.serviceNextTrust(def, data.contactTrust)
                    flow:add(nextTrust and modeText("ServiceNextTrust", "Upgrades at %1 Trust", tostring(nextTrust))
                        or modeText("ServiceMaximum", "Maximum Reached"))
                    if option then
                        flow:add(selected .. "/" .. #options .. "  " .. localization.serviceLabel(option.label, def.service))
                        if option.preview then flow:add(localization.text(option.preview, "service")) end
                    else
                        flow:add(localization.text(#options > 0 and "Select a target..." or "No eligible targets available", "service"))
                    end
                end
            end, actions, barterTexture(def))
        end
    end

    function view.close()
        if supplyPlayer then
            local owner = supplyPlayer
            supplyPlayer, heartbeat = nil, nil
            ExtractionMode.Client.sendCommand(owner, "SetUpgradePanelOpen", {open = false})
        end
        if liveUI and livePage == "garage" then GaragePage.hide(liveUI) end
        liveUI, livePage, pageState = nil, nil, nil
    end

    function view.enter(ui, page, questId)
        view.close()
        liveUI, livePage = ui, page
        pageState = {focus = questId, expanded = questId, serviceTarget = {}}
        if page == "garage" then send("RequestState") end
    end

    function view.wheel(ui, x, y, delta)
        return liveUI == ui and livePage == "garage" and delta ~= 0
            and GaragePage.wheel(pageState, x, y, delta)
    end

    function view.update(ui, page)
        if not availablePlayer() then view.close(); return end
        if liveUI ~= ui or livePage ~= page then view.enter(ui, page) end
        local now = getTimestampMs()
        if page == "upgrades" and (not heartbeat or now - heartbeat >= 5000) then
            supplyPlayer, heartbeat = player(), now
            send("SetUpgradePanelOpen", {open = true})
        elseif page == "barter" and inside(current()) and (not pageState.serviceAt or now - pageState.serviceAt >= 2000) then
            pageState.serviceAt = now
            send("RequestBarterServices")
        end
    end

    function view.receive(module, command, args, target)
        if livePage ~= "barter" or module ~= ExtractionMode.Config.COMMAND_MODULE or command ~= "BarterServices"
            or type(args) ~= "table" or (target and target ~= player())
            or (args._targetPlayerNum and tonumber(args._targetPlayerNum) ~= 0)
            or (args._targetIdentity and args._targetIdentity ~= "" and args._targetIdentity ~= ExtractionMode.Util.username(player())) then return end
        pageState.serviceOptions = type(args.options) == "table" and args.options or {}
        invalidate()
    end

    function view.render(ui, pda, top, section)
        view.update(ui, section)
        if not pageState then return end
        local body = widgets.beginBody(ui, top)
        local data = current()
        if section == "garage" and not data.state then GaragePage.hide(ui) end
        if section == "garage" and data.state then
            local bottom = GaragePage.render({
                ui = ui, state = pageState, body = body, palette = pda.P, text = text, modeText = modeText,
                current = current, send = send, canBuild = canBuild, buttonHeight = widgets.buttonHeight(),
                panel = function(...) return widgets.panel(ui, pda, ...) end,
                flow = function(...) return widgets.flow(ui, pda, ...) end,
                button = function(...) return widgets.button(ui, pda, ...) end,
                hit = function(...) return widgets.hit(ui, ...) end,
            }, data)
            widgets.endBody(ui, pda, body, bottom)
            return
        end
        local pad, y = 16, body.y
        local page = {}
        function page.card(title, build, items, icon)
            local iconSize = icon and 54 or 0
            local offset = icon and iconSize + 14 or 0
            local width = body.w - 2 * pad - offset
            local flow = ExtractionMode.TextLayout.flow(width)
            flow:add(title, UIFont.Medium)
            if build then build(flow) end
            local actions = widgets.actions(items or {}, width)
            local height = 2 * pad + math.max(iconSize, flow.y + actions.height + (actions.height > 0 and 8 or 0))
            widgets.panel(ui, pda, body.x, y, body.w, height)
            local x, contentY = body.x + pad, y + pad
            if icon then
                widgets.panel(ui, pda, x, contentY, iconSize, iconSize)
                ui:drawTextureScaledAspect(icon, x + 4, contentY + 4, iconSize - 8, iconSize - 8, 1, 1, 1, 1)
            end
            widgets.flow(ui, pda, flow, x + offset, contentY)
            widgets.drawActions(ui, pda, actions, x + offset, contentY + flow.y + 8)
            y = y + height + 10
        end
        if not data.state then page.card(text("Waiting", "Waiting for Extraction Mode state..."))
        elseif section == "upgrades" then upgrades(page, data)
        elseif section == "quests" then missions(page, data)
        elseif section == "barter" then barter(page, data) end
        widgets.endBody(ui, pda, body, y)
    end
    return view
end

return Pages
