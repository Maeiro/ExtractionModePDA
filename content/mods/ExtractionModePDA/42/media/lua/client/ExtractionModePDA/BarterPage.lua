local Portrait = require "ExtractionModePDA/BarterPortrait"
local Selector = require "ExtractionModePDA/ServiceSelector"
local Barter = {}

function Barter.hide(ui) Portrait.hide(ui) end

function Barter.render(ctx, data)
    local ui, pda, state, widgets = ctx.ui, ctx.pda, ctx.state, ctx.widgets
    local text, modeText = ctx.text, widgets.modeText
    local Layout, api, quests = ExtractionMode.TextLayout, ExtractionMode.Barters, ExtractionMode.Quests
    local definitions = api.unlockedDefinitions(data.contactTrust)
    local contacts, seen, valid = {}, {}, false
    for _, def in ipairs(definitions) do
        if not seen[def.contactId] then contacts[#contacts + 1] = def.contactId; seen[def.contactId] = true end
        if def.contactId == state.contact then valid = true end
    end
    if not valid then state.contact = contacts[1]; ui._empdaExtractionScroll = 0 end
    local function selectContact(contact)
        Selector.clear(ui)
        Portrait.hide(ui)
        state.contact, state.counts = contact, nil
        state.filter, ui._empdaExtractionScroll = nil, 0
    end
    local function fixedButton(x, y, w, label, callback, selected, style)
        local before = #ui._empdaExtractionHits
        widgets.button(ui, pda, x, y, w, label, callback, true, selected, style)
        for i = before + 1, #ui._empdaExtractionHits do ui._empdaExtractionHits[i].navigation = true end
    end
    local top, left, width, bottom = ctx.top, 18, ui.width - 36, ui.height - 18
    local gap, pad, buttonH = 12, 14, widgets.buttonHeight()
    local contactH = math.min(70, math.floor((bottom - top - 2 * pad) / math.max(1, #contacts)))
    local sidebar = width >= 650 and contactH >= 2 * Layout.height(UIFont.Small) + 26
    if sidebar then
        local sideW = math.min(230, math.floor(width * 0.23))
        widgets.panel(ui, pda, left, top, sideW, bottom - top)
        for index, contact in ipairs(contacts) do
            fixedButton(left + 8, top + pad + (index - 1) * contactH, sideW - 16,
                quests.contactDisplayName(contact), function() selectContact(contact) end, contact == state.contact,
                {height = contactH - 6, subtitle = modeText("CurrentTrustSuffix", "Current Trust: %1", tostring((data.contactTrust or {})[contact] or 0))})
        end
        left, width = left + sideW + gap, width - sideW - gap
    else
        local actions = {}
        for _, contact in ipairs(contacts) do
            local id = contact
            actions[#actions + 1] = {label = quests.contactDisplayName(id), action = function() selectContact(id) end,
                selected = id == state.contact}
        end
        local row = widgets.actions(actions, width)
        local before = #ui._empdaExtractionHits
        widgets.drawActions(ui, pda, row, left, top)
        for i = before + 1, #ui._empdaExtractionHits do ui._empdaExtractionHits[i].navigation = true end
        top = top + row.height + gap
    end
    local portraitRect
    if state.contact then
        local modelW = width >= 450 and 116 or 84
        local header = Layout.flow(width - modelW - 3 * pad)
        header:add(quests.contactDisplayName(state.contact), UIFont.Medium)
        local focus = quests.contactFocus and quests.contactFocus(state.contact)
        if focus and focus ~= "" then header:add(focus) end
        header:add(modeText("CurrentTrustSuffix", "Current Trust: %1", tostring((data.contactTrust or {})[state.contact] or 0)))
        local now = getTimestampMs()
        if api.requirementCounts and (not state.walletAt or now - state.walletAt >= 1000) then
            local owner = widgets.player()
            local counts = owner and api.requirementCounts(owner, {{types = {"Base.Money"}, amount = 1}}) or {}
            state.wallet, state.walletAt = tonumber(counts[1]) or 0, now
        end
        if state.wallet then header:add(text("YourMoney", "Your money: %1", tostring(state.wallet))) end
        local nextTrust
        for _, def in ipairs(definitions) do
            if def.contactId == state.contact and def.service then
                local value = api.serviceNextTrust(def, data.contactTrust)
                if value and (not nextTrust or value < nextTrust) then nextTrust = value end
            end
        end
        if nextTrust then header:add(modeText("ServiceNextTrust", "Upgrades at %1 Trust", tostring(nextTrust))) end
        local headerH = math.max(142, header.y + 2 * pad)
        widgets.panel(ui, pda, left, top, width, headerH)
        portraitRect = {x = left + 4, y = top + 4, w = modelW, h = headerH - 8}
        widgets.flow(ui, pda, header, left + modelW + pad, top + pad)
        top = top + headerH + gap
    end
    local filters = {}
    for _, filter in ipairs({{"all", text("AllOffers", "All offers")}, {"items", text("BarterItems", "Items")},
        {"services", text("BarterServices", "Services")}}) do
        local id = filter[1]
        filters[#filters + 1] = {label = filter[2], selected = (state.filter or "all") == id, action = function()
            state.filter, ui._empdaExtractionScroll = id, 0
            Selector.clear(ui)
        end}
    end
    local filterRow = widgets.actions(filters, width)
    local before = #ui._empdaExtractionHits
    widgets.drawActions(ui, pda, filterRow, left, top)
    for i = before + 1, #ui._empdaExtractionHits do ui._empdaExtractionHits[i].navigation = true end
    top = top + filterRow.height + gap
    local body = widgets.beginBody(ui, top, left, width)
    local cards, page = {}, {}
    function page.card(title, build, actions, icon, selector)
        local category = selector and "services" or "items"
        if state.filter and state.filter ~= "all" and state.filter ~= category then return end
        cards[#cards + 1] = {title = title, build = build, actions = actions, icon = icon, selector = selector}
    end
    ctx.build(page, data)
    local columns = math.max(1, math.min(4, math.floor((width + gap) / (240 + gap))))
    local cardW = (width - (columns - 1) * gap) / columns
    local used, y = {}, body.y
    for index = 1, #cards, columns do
        local rowH = 0
        for offset = 0, math.min(columns - 1, #cards - index) do
            local card = cards[index + offset]
            card.flow = Layout.flow(cardW - 2 * pad)
            card.flow:add(card.title, UIFont.Medium)
            if card.build then card.build(card.flow) end
            card.row = widgets.actions(card.actions or {}, cardW - 2 * pad)
            card.height = 2 * pad + 72 + card.flow.y + gap + card.row.height
                + (card.selector and buttonH + 8 or 0)
            rowH = math.max(rowH, card.height)
        end
        for offset = 0, math.min(columns - 1, #cards - index) do
            local card = cards[index + offset]
            local x = left + offset * (cardW + gap)
            widgets.panel(ui, pda, x, y, cardW, rowH)
            if card.icon then ui:drawTextureScaledAspect(card.icon, x + (cardW - 60) / 2, y + pad, 60, 60, 1, 1, 1, 1) end
            widgets.flow(ui, pda, card.flow, x + pad, y + pad + 72)
            local actionY = y + rowH - pad - card.row.height
            local selector = card.selector
            if selector then
                local choices, label = {}, text("SelectServiceTarget", "Select a target...")
                for _, option in ipairs(selector.options) do
                    local name = ExtractionMode.Localization.serviceLabel(option.label, selector.service)
                    choices[#choices + 1] = {id = option.id, label = name}
                    if option.id == selector.selected then label = name end
                end
                local sy = actionY - buttonH - 8
                if sy >= body.top and sy + buttonH <= body.bottom then
                    used[selector.id] = true
                    local combo = Selector.show(ui, pda.P, {id = selector.id, selected = selector.selected, options = choices,
                        placeholder = text("SelectServiceTarget", "Select a target..."), enabled = widgets.inside(data),
                        choose = function(id) state.serviceTarget[selector.id] = id end}, x + pad, sy, cardW - 2 * pad, buttonH)
                    widgets.button(ui, pda, x + pad, sy, cardW - 2 * pad, label .. "  v", function() combo:forceClick() end, not combo.disabled)
                end
            end
            widgets.drawActions(ui, pda, card.row, x + pad, actionY)
        end
        y = y + rowH + gap
    end
    if #cards == 0 then
        local empty = Layout.flow(width - 2 * pad)
        empty:add(text("NoMatchingOffers", "No offers in this category."))
        widgets.flow(ui, pda, empty, left + pad, y + pad)
        y = y + empty.y + 2 * pad
    end
    Selector.hideUnused(ui, used)
    widgets.endBody(ui, pda, body, y)
    -- Native portraits are top-level UI elements, outside the offers' stencil.
    local popupOpen = false
    for _, combo in pairs(ui._empdaServiceSelectors or {}) do
        if combo.expanded then popupOpen = true end
    end
    if portraitRect and portraitRect.y + portraitRect.h <= bottom and not popupOpen then
        if not Portrait.show(ui, state.contact, portraitRect) then
            local color = pda.P.muted or pda.P.text
            ui:drawTextCentre("...", portraitRect.x + portraitRect.w / 2, portraitRect.y + portraitRect.h / 2,
                color[1], color[2], color[3], 1, UIFont.Medium)
        end
    else Portrait.hide(ui) end
end

return Barter
