local GaragePage = {}

local function owns(data, record)
    return record ~= nil and tostring(record.owner or "") == tostring(data.garageOwner or "")
end

local function modelName(record)
    local key = tostring(record.modelKey or "")
    return (key ~= "" and getTextOrNull and getTextOrNull("IGUI_VehicleName" .. key))
        or (key ~= "" and key) or record.scriptName or "—"
end

local function nameOf(record, modeText)
    local name = record.customName == true and record.name
        or record.isTrailer == true and modeText("GarageTrailerName", "Trailer") or modelName(record)
    local ordinal = tonumber(record.nameOrdinal) or 1
    return tostring(name) .. (ordinal > 1 and " " .. ordinal or "")
end

local function find(records, id)
    for _, record in ipairs(records or {}) do
        if tostring(record.id) == id then return record end
    end
end

local function removeControl(ui, field)
    local control = ui[field]
    if not control then return end
    if control.unfocus then control:unfocus() end
    control:setVisible(false)
    ui:removeChild(control)
    ui[field] = nil
end

function GaragePage.hide(ui)
    removeControl(ui, "_empdaGarageName")
    removeControl(ui, "_empdaGarageSurface")
    removeControl(ui, "_empdaGarageScene")
end

local function fullyVisible(page, y, height)
    return y >= page.body.top and y + height <= page.body.bottom
end

local function place(control, x, y, width, height)
    control:setX(x)
    control:setY(y)
    control:setWidth(width)
    control:setHeight(height)
end

local function color(rgb)
    return {r = rgb[1], g = rgb[2], b = rgb[3], a = 1}
end

local function preview(page, record, x, y, width, height)
    local ui, api = page.ui, ExtractionMode.GaragePreview
    if not fullyVisible(page, y, height) or not api or not ISUI3DScene then return end
    if not ui._empdaGarageScene then
        local scene = ISUI3DScene:new(x, y, width, height)
        scene:initialise()
        scene:instantiate()
        scene.javaObject:fromLua1("setDrawGrid", false)
        scene.javaObject:fromLua1("createVehicle", "garageVehicle")
        scene:setView("UserDefined")
        scene.javaObject:fromLua3("setViewRotation", 30, 45, 0)
        scene.javaObject:fromLua1("setZoom", 5)
        scene.background = false
        ui._empdaGarageScene = scene
        local surface = api.attach(ui, scene)
        surface.background = false
        -- The PDA draws over its children. Run the native renderer after the page.
        surface.drawModel = surface.render
        surface.render = ISUIElement.render
        ui._empdaGarageSurface = surface
    end
    local scene, surface = ui._empdaGarageScene, ui._empdaGarageSurface
    local scriptName = tostring(record.scriptName or "")
    if scene.extractionScriptName ~= scriptName then
        api.show(scene, record)
        local result = scene.extractionRender3D and "3D model"
            or scene.extractionIllustration and "2D illustration" or "unavailable"
        print("[Extraction Mode PDA] Native garage preview for " .. scriptName .. ": " .. result)
    end
    place(scene, x, y, width, height)
    place(surface, x, y, width, height)
    surface:setVisible(scene.extractionRender3D == true)
    if scene.extractionRender3D then return end
    local image = scene.extractionIllustration
    if image then
        local scale = math.min(width / math.max(1, image:getWidth()), height / math.max(1, image:getHeight()))
        local w, h = image:getWidth() * scale, image:getHeight() * scale
        ui:drawTextureScaled(image, x + (width - w) / 2, y + (height - h) / 2, w, h, 1, 1, 1, 1)
    elseif scene.extractionPreviewUnavailable then
        ui:drawText(page.modeText("GaragePreviewUnavailable", "Vehicle preview unavailable"),
            x, y, 0.65, 0.8, 0.72, 1, UIFont.Small)
    end
end

function GaragePage.drawModel(ui)
    local scene, surface = ui._empdaGarageScene, ui._empdaGarageSurface
    if not surface or not surface:getIsVisible() then return end
    surface:drawModel()
    if not scene.extractionRender3D then surface:setVisible(false) end
end

local function nameEntry(page, record, x, y, width, height, editable)
    local ui, state = page.ui, page.state
    local id = tostring(record.id)
    local value = record.customName and record.name or modelName(record)
    value = tostring(value or "")
    local entry = ui._empdaGarageName
    if entry and entry.garageId ~= id then
        removeControl(ui, "_empdaGarageName")
        entry = nil
    end
    if not fullyVisible(page, y, height) or not ISTextEntryBox then
        if entry then entry:unfocus(); entry:setVisible(false) end
        return
    end
    if not entry then
        entry = ISTextEntryBox:new(value, x, y, width, height)
        entry:initialise()
        entry:instantiate()
        entry:setMaxTextLength(48)
        entry.garageId, entry.savedName = id, value
        ui:addChild(entry)
        ui._empdaGarageName = entry
    elseif entry.savedName ~= value and not entry:isFocused() then
        entry:setText(value)
        entry.savedName = value
    end
    if state.confirm then entry:unfocus() end
    entry.backgroundColor = color(page.palette.screen)
    entry.borderColor = color(page.palette.edge)
    local ink = page.palette.text
    entry:setTextRGBA(ink[1], ink[2], ink[3], 1)
    place(entry, x, y, width, height)
    entry:setEditable(editable)
    entry:setVisible(true)
end

local gold = {0.96, 0.72, 0.18}
local function drawText(page, value, x, y, width, ink, font)
    font = font or UIFont.Small
    page.ui:drawText(ExtractionMode.TextLayout.fit(value, font, width), x, y, ink[1], ink[2], ink[3], 1, font)
end

local function drawList(page, title, kind, records, x, y, width, height, rowHeight)
    local state, ui, palette = page.state, page.ui, page.palette
    local fontHeight = ExtractionMode.TextLayout.height(UIFont.Small)
    drawText(page, title, x, y, width, gold)
    y = y + fontHeight
    page.panel(x, y, width, height)
    local visible = math.max(1, math.floor((height - 2) / rowHeight))
    local maximum = math.max(0, #records - visible)
    local first = math.max(0, math.min(maximum, state.listScroll[kind] or 0))
    state.listScroll[kind] = first
    state.listRects[kind] = {x = x, y = math.max(y, page.body.top), w = width,
        bottom = math.min(y + height, page.body.bottom), maximum = maximum}
    local scrollbar = maximum > 0 and 6 or 0
    for i = first + 1, math.min(#records, first + visible) do
        local item = records[i]
        local id = tostring(item.id)
        local rowY = y + 1 + (i - first - 1) * rowHeight
        local selected = state.kind == kind and state.selected == id
        local fill = selected and palette.buttonHover or palette.panel
        ui:drawRect(x + 1, rowY, width - scrollbar - 2, rowHeight, 1, fill[1], fill[2], fill[3])
        ui:drawRectBorder(x + 1, rowY, width - scrollbar - 2, rowHeight, 0.35, palette.edge[1], palette.edge[2], palette.edge[3])
        drawText(page, nameOf(item, page.modeText), x + 9, rowY + (rowHeight - fontHeight) / 2 + 2,
            width - scrollbar - 18, palette.text)
        page.hit({x = x + 1, y = rowY, w = width - scrollbar - 2, h = rowHeight}, function()
            state.kind, state.selected, state.confirm = kind, id, nil
            removeControl(ui, "_empdaGarageName")
        end)
    end
    if maximum > 0 then
        local thumb = math.max(12, height * visible / #records)
        local edge = palette.edge
        ui:drawRect(x + width - 5, y + (height - thumb) * first / maximum, 4, thumb, 0.8, edge[1], edge[2], edge[3])
    end
end

function GaragePage.wheel(state, x, y, delta)
    for kind, rect in pairs(state.listRects or {}) do
        if rect.maximum > 0 and x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.bottom then
            local first = state.listScroll[kind] or 0
            local nextRow = math.max(0, math.min(rect.maximum, first + (delta > 0 and 1 or -1)))
            if nextRow == first then return false end
            state.listScroll[kind] = nextRow
            return true
        end
    end
    return false
end

function GaragePage.render(page, data)
    local ui, state, body, palette = page.ui, page.state, page.body, page.palette
    local t, text = page.modeText, page.text
    if ui._empdaGarageSurface then ui._empdaGarageSurface:setVisible(false) end
    state.listRects, state.listScroll = {}, state.listScroll or {}
    local vehicles = data.garageVehicles or {}
    local trailersEnabled = data.garageTrailersEnabled == true
    local trailers = trailersEnabled and (data.garageTrailers or {}) or {}
    if not state.kind or not trailersEnabled and state.kind == "trailer" then
        state.kind = #vehicles == 0 and #trailers > 0 and "trailer" or "vehicle"
    end
    local trailer = state.kind == "trailer"
    local records = trailer and trailers or vehicles
    local record = find(records, state.selected) or records[1]
    local selected = record and tostring(record.id)
    if state.selected and state.selected ~= selected then state.confirm = nil end
    state.selected = selected

    local active, activeTrailer = data.activeHideoutVehicle, data.activeHideoutTrailer
    local editable, pending = page.canBuild(data), data.garageTransition ~= nil
    local busy = active and (active.storing or active.raidReserved)
    local owner, trailerOwner = owns(data, active), owns(data, activeTrailer)
    local driver = active and tostring(active.driverUsername or "") or ""
    local driverOwner = active and tostring(active.driverGarageOwner or "") or ""
    local transfer = owner and not busy and driver ~= "" and driverOwner ~= ""
        and driverOwner ~= tostring(data.garageOwner or "")
    local args = record and (trailer and {trailerId = record.id} or {garageId = record.id})
    local function stillStored(fresh)
        return find(trailer and (fresh.garageTrailers or {}) or fresh.garageVehicles, selected)
    end
    local function command(label, name, payload, enabled, confirm, valid)
        return {label = label, enabled = editable and enabled == true and not state.confirm, action = function()
            local function run()
                local fresh = page.current()
                if page.canBuild(fresh) and (not valid or valid(fresh)) then page.send(name, payload) end
            end
            if confirm then
                state.confirm = {message = confirm, run = run}
                ui._empdaExtractionScroll = 0
            else run() end
        end}
    end
    local function button(item, x, y, width)
        page.button(x, y, width, item.label, item.action, item.enabled)
    end
    local deploy = record ~= nil and not pending and (trailer and active ~= nil and not busy and (not activeTrailer or trailerOwner)
        or not trailer and not record.transactionPending and not busy
            and (not active or owner or (active.inactive and not active.occupied)))
    local delete = record ~= nil and not pending and not (active and active.storing)
        and (trailer and (not activeTrailer or tostring(activeTrailer.trailerId) ~= selected)
            or not trailer and not record.transactionPending)
    local spawnAction = command(trailer and (activeTrailer and t("GarageSwapTrailer", "SWAP TRAILER") or t("GarageSpawnTrailer", "SPAWN TRAILER"))
        or (active and t("GarageSwapVehicle", "SWAP VEHICLE") or t("GarageSpawnVehicle", "SPAWN VEHICLE")),
        trailer and "GarageTrailerDeploy" or "GarageDeploy", args, deploy, nil, stillStored)
    local returnAction = command(t("GarageReturnActive", "RETURN ACTIVE VEHICLE"), "GarageStoreActive", nil, owner and not busy, nil,
        function(fresh)
            local v = fresh.activeHideoutVehicle
            return owns(fresh, v) and v.vehicleId == active.vehicleId and not v.storing and not v.raidReserved
        end)
    local deleteAction = command(trailer and t("GarageDeleteTrailer", "DELETE TRAILER") or t("GarageDeleteStored", "DELETE STORED VEHICLE"),
        trailer and "GarageTrailerDelete" or "GarageDelete", args, delete,
        record and t(trailer and "GarageConfirmDeleteTrailer" or "GarageConfirmDelete",
            "Permanently delete '%1' and its cargo?", nameOf(record, t)), function(fresh)
            local saved = stillStored(fresh)
            return saved and not saved.transactionPending and fresh.garageTransition == nil
                and not (fresh.activeHideoutVehicle and fresh.activeHideoutVehicle.storing)
                and not (trailer and fresh.activeHideoutTrailer and tostring(fresh.activeHideoutTrailer.trailerId) == selected)
        end)
    local returnTrailer = command(t("GarageReturnActiveTrailer", "RETURN ACTIVE TRAILER"),
        "GarageTrailerStoreActive", nil, trailerOwner, nil, function(fresh)
            local v = fresh.activeHideoutTrailer
            return owns(fresh, v) and v.vehicleId == activeTrailer.vehicleId
        end)
    local transferAction = command(t("GarageTransferDriver", "TRANSFER OWNERSHIP TO CURRENT DRIVER"),
        "GarageTransferActiveToDriver", {expectedDriverUsername = driver}, transfer,
        transfer and t("GarageConfirmTransfer", "Transfer ownership of '%1' to current driver %2?", nameOf(active, t), driver),
        function(fresh)
            local v = fresh.activeHideoutVehicle
            return owns(fresh, v) and v.vehicleId == active.vehicleId and v.driverUsername == driver
                and not v.storing and not v.raidReserved
        end)
    local lifts = command(data.garageLiftsHidden and t("GarageShowLifts", "SHOW VEHICLE LIFTS") or t("GarageHideLifts", "HIDE VEHICLE LIFTS"),
        "GarageSetLiftsHidden", {hidden = not data.garageLiftsHidden},
        data.garageDoorUnlocked == true and not (data.garageMapChecked and not data.garageMapPresent))

    local Layout = ExtractionMode.TextLayout
    local x, y, w = body.x, body.y, math.min(700, body.w)
    local pad, gap, small = 14, 12, Layout.height(UIFont.Small)
    local insideW = w - 2 * pad
    local left = x + pad
    local leftW = math.floor((insideW - gap) * 0.39)
    local rightX, rightW = left + leftW + gap, insideW - leftW - gap
    local buttonH = page.buttonHeight
    local header = Layout.flow(insideW)
    local subtitle = Layout.wrap(t("GarageSubtitle", "Stored vehicles are personal. Only one vehicle may be active in the hideout."),
        UIFont.Small, insideW)
    if active then
        local status = active.raidReserved and t("GarageStatusReserved", "Reserved for raid")
            or active.storing and t("GarageStatusReturning", "Returning to garage")
            or active.occupied and t("GarageStatusOccupied", "Occupied")
            or active.inactive and t("GarageStatusInactive", "Inactive") or t("GarageStatusActive", "Active")
        header:add(t("GarageActiveLine", "ACTIVE: %1 | Owner: %2 | %3", nameOf(active, t), tostring(active.owner or "—"), status))
    else
        header:add(pending and t("GarageCompletingReturn", "GARAGE: Completing vehicle return...")
            or t("GarageNoActive", "ACTIVE: None"))
    end
    if not editable then header:add(text("GarageReadOnly", "Garage controls are available at the hideout to its members.")) end
    local titleY = y + 10
    local subtitleY = titleY + Layout.height(UIFont.Medium)
    local headerY = subtitleY + #subtitle * small
    local controlsY = headerY + header.y + 4
    local confirmation = state.confirm
    local confirmationFlow
    if confirmation then
        confirmationFlow = Layout.flow(insideW - 2 * pad)
        confirmationFlow:add(confirmation.message)
    end
    local confirmationH = confirmationFlow and confirmationFlow.y + buttonH + 2 * pad + gap or 0
    local listsY = controlsY + confirmationH
    local previewY = listsY + small
    local previewH = math.max(48, math.min(270, math.floor(rightW * 0.62), body.h - 20))
    local nameY = previewY + previewH + 10
    local showName = record ~= nil and not trailer
    local splitStats = rightW >= 340 and record ~= nil and not trailer
    local statsGap = 10
    local statsW = splitStats and (rightW - statsGap) / 2 or rightW
    local stats = Layout.flow(statsW)
    local condition = splitStats and Layout.flow(statsW) or stats
    if record then
        stats:add(t("GarageModel", "Model: %1", modelName(record)))
        if not trailer then
            stats:add(t("GarageFuelCapacity", "Fuel: %1 / %2 L", string.format("%.1f", tonumber(record.fuel) or 0),
                string.format("%.1f", tonumber(record.fuelCapacity) or 0)))
        end
        condition:add(record.batteryPresent and t("GarageBattery", "Battery: %1%%", string.format("%.1f", tonumber(record.batteryCharge) or 0))
            or t("GarageNoBattery", "Battery: No Battery"))
        if not trailer then
            condition:add(t("GarageEngineCondition", "Engine condition: %1%%", tostring(math.floor(tonumber(record.engineCondition) or 0))))
        end
    end
    local statsY = nameY + (showName and small + buttonH + 8 or 0)
    local actionY = statsY + math.max(stats.y, condition.y) + 6
    local actionsH = 3 * buttonH + 12
    local rightBottom = actionY + actionsH
    local rowHeight = math.max(26, small + 10)
    local listSpace = math.max(rowHeight * 4 + 2 * small + 18, rightBottom - previewY - small)
    local vehicleH = trailersEnabled and math.floor((listSpace - small - 8) * 0.66) or listSpace
    local trailerY = previewY + vehicleH + 8
    local trailerH = math.max(rowHeight + 2, listSpace - vehicleH - small - 8)
    local footerY = previewY + listSpace + 8
    local liftsY = footerY + (trailersEnabled and small or 0)
    local emergency = data.debugEnabled and command(t("GarageEmergencyClear", "EMERGENCY CLEANUP"),
        "GarageEmergencyClearHideout", nil, not active and not activeTrailer,
        text("GarageEmergencyWarning", "Permanently delete physical vehicles, trailers and their cargo in the hideout? Stored garage records are kept."),
        function(fresh) return fresh.debugEnabled and not fresh.activeHideoutVehicle and not fresh.activeHideoutTrailer end)
    local bottom = math.max(rightBottom, liftsY + buttonH) + (emergency and buttonH + 8 or 0) + pad

    page.panel(x, y, w, bottom - y)
    ui:drawTextCentre(Layout.fit(t("GarageTitle", "PERSONAL GARAGE"), UIFont.Medium, insideW),
        x + w / 2, titleY, gold[1], gold[2], gold[3], 1, UIFont.Medium)
    for index, line in ipairs(subtitle) do
        local ink = palette.text
        ui:drawTextCentre(line, x + w / 2, subtitleY + (index - 1) * small, ink[1], ink[2], ink[3], 1, UIFont.Small)
    end
    page.flow(header, left, headerY)
    if confirmationFlow then
        page.panel(left, controlsY, insideW, confirmationH - gap)
        page.flow(confirmationFlow, left + pad, controlsY + pad)
        local confirmY = controlsY + pad + confirmationFlow.y
        local half = (insideW - 2 * pad - 8) / 2
        button({label = text("CancelAction", "Cancel"), action = function() state.confirm = nil end}, left + pad, confirmY, half)
        button({label = text("ConfirmAction", "Confirm action"), enabled = editable, action = function()
            state.confirm = nil
            confirmation.run()
        end}, left + pad + half + 8, confirmY, half)
    end
    drawList(page, t("GarageSavedVehicles", "SAVED VEHICLES"), "vehicle", vehicles, left, listsY, leftW, vehicleH, rowHeight)
    if trailersEnabled then
        drawList(page, t("GarageSavedTrailers", "SAVED TRAILERS"), "trailer", trailers, left, trailerY, leftW, trailerH, rowHeight)
        drawText(page, activeTrailer and t("GarageActiveTrailerLine", "ACTIVE TRAILER: %1 | Owner: %2",
            nameOf(activeTrailer, t), tostring(activeTrailer.owner or "—")) or t("GarageNoActiveTrailer", "ACTIVE TRAILER: None"),
            left, footerY, leftW, palette.muted)
    end
    button(lifts, left, liftsY, leftW)
    ui:drawRect(rightX, previewY, rightW, previewH, 1, 0.08, 0.09, 0.10)
    if record and not state.previewFailed then
        local ok = pcall(preview, page, record, rightX, previewY, rightW, previewH)
        if not ok then
            removeControl(ui, "_empdaGarageSurface")
            removeControl(ui, "_empdaGarageScene")
            state.previewFailed = true
        end
    end
    if not record or state.previewFailed or not (ExtractionMode.GaragePreview and ISUI3DScene) then
        local label = record and t("GaragePreviewUnavailable", "Vehicle preview unavailable")
            or (trailer and t("GarageNoTrailers", "No trailers saved") or t("GarageNoVehicles", "No vehicles saved"))
        ui:drawTextCentre(Layout.fit(label, UIFont.Small, rightW - 12),
            rightX + rightW / 2, previewY + (previewH - small) / 2, palette.muted[1], palette.muted[2], palette.muted[3], 1, UIFont.Small)
    end
    if showName then
        drawText(page, t("GarageVehicleName", "VEHICLE NAME"), rightX, nameY, rightW, gold)
        local saveLabel = t("GarageSaveName", "SAVE NAME")
        local saveW = math.min(rightW / 2, Layout.width(saveLabel) + 24)
        local canRename = editable and not confirmation and ISTextEntryBox ~= nil
        nameEntry(page, record, rightX, nameY + small, rightW - saveW - 8, buttonH, canRename)
        local entry = ui._empdaGarageName
        button({label = saveLabel, enabled = canRename and entry ~= nil, action = function()
            local fresh = page.current()
            if page.canBuild(fresh) and stillStored(fresh) and entry.garageId == selected then
                page.send("GarageRename", {garageId = record.id, name = entry:getText()})
                entry:unfocus()
            end
        end}, rightX + rightW - saveW, nameY + small, saveW)
    else
        removeControl(ui, "_empdaGarageName")
    end
    page.flow(stats, rightX, statsY)
    if splitStats then page.flow(condition, rightX + statsW + statsGap, statsY) end
    local half = (rightW - 8) / 2
    button(spawnAction, rightX, actionY, half)
    button(returnAction, rightX + half + 8, actionY, half)
    local second = actionY + buttonH + 6
    button(deleteAction, rightX, second, trailersEnabled and half or rightW)
    if trailersEnabled then button(returnTrailer, rightX + half + 8, second, half) end
    button(transferAction, rightX, second + buttonH + 6, rightW)
    if emergency then button(emergency, rightX, bottom - pad - buttonH, rightW) end
    return bottom
end

return GaragePage
