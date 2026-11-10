local Portrait = require "ExtractionModePDA/BarterPortrait"
local Selector = require "ExtractionModePDA/ServiceSelector"
local Style = require "ExtractionModePDA/BarterStyle"
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
    local top, left, width, bottom = ctx.top, 18, ui.width - 36, ui.height - 18
    local gap, pad, buttonH = 12, 14, widgets.buttonHeight()
    local scale = pda.TextScale and pda.TextScale() or 1
    local lh = Layout.height(UIFont.Small) * scale
    buttonH = math.max(buttonH, math.ceil(lh + 12))
    local contactH = math.min(lh * 3 + 22, math.floor((bottom - top - 3 * pad - lh) / math.max(1, #contacts)))
    local sidebar = width >= 800 and contactH >= 2 * lh + 18
    if sidebar then
        local sideW = math.min(290, math.floor(width * 0.24))
        widgets.panel(ui, pda, left, top, sideW, bottom - top)
        Style.line(ui, pda, text("BarterContacts", "EXTRACTION CONTACTS"), left + 12, top + 10, sideW - 24, pda.P.accent)
        for index, contact in ipairs(contacts) do
            local id, color = contact, Style.color(contact, pda.P)
            local x, y, h = left + 6, top + 18 + lh + (index - 1) * contactH, contactH - 4
            local selected = contact == state.contact
            local background = selected and pda.P.buttonHover or pda.P.row
            ui:drawRect(x, y, sideW - 12, h, selected and 0.9 or 0.45, background[1], background[2], background[3])
            if selected then ui:drawRect(x, y, 3, h, 1, color[1], color[2], color[3]) end
            local size = h - 6
            Style.emblem(ui, contact, x + 4, y + 3, size)
            local tx, tw = x + size + 10, sideW - size - 26
            local name = quests.contactDisplayName(contact)
            Style.line(ui, pda, name, tx, y + 3, tw, pda.P.text)
            local compact = h < 3 * lh + 12
            if not compact and quests.contactFocus then
                Style.line(ui, pda, quests.contactFocus(contact), tx, y + 5 + lh, tw, color)
            end
            Style.line(ui, pda, text("TrustValue", "Trust: %1", tostring((data.contactTrust or {})[contact] or 0)),
                tx, y + 7 + (compact and lh or 2 * lh), tw, pda.P.accent)
            widgets.hit(ui, {x = x, y = y, w = sideW - 12, h = h, navigation = true, label = name}, function() selectContact(id) end)
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
        local p, color = pda.P, Style.color(state.contact, pda.P)
        local compact = bottom - top < 550 or lh > 18
        local headerH = math.floor(math.max(lh * 6 + 48, math.min((bottom - top) * 0.30, 210)))
        local modelW = math.floor(math.min(240, width * 0.27))
        widgets.panel(ui, pda, left, top, width, bottom - top)
        local face = {x = left + 12, y = top + 12, w = modelW, h = headerH - 12}
        Style.rounded(ui, face.x - 2, face.y - 2, face.w + 4, face.h + 4, 8, color, 0.9)
        ui:drawRect(face.x, face.y, face.w, face.h, 1, p.well[1], p.well[2], p.well[3])
        local captionH = lh + 10
        portraitRect = {x = face.x + 1, y = face.y + 1, w = face.w - 2, h = face.h - captionH - 2}
        ui:drawRect(face.x, face.y + face.h - captionH, face.w, captionH, 0.92, p.panel[1], p.panel[2], p.panel[3])
        local focus = quests.contactFocus and quests.contactFocus(state.contact) or quests.contactDisplayName(state.contact)
        Style.line(ui, pda, focus, face.x + 5, face.y + face.h - captionH + 4, face.w - 10, color, nil, true)
        local tx = face.x + face.w + 16
        local tw, y = left + width - 12 - tx, top + 12
        local titleFont = UIFont.Large or UIFont.Medium
        local titleH = Layout.height(titleFont) * scale
        Style.emblem(ui, state.contact, tx, y, titleH + 6)
        Style.line(ui, pda, quests.contactDisplayName(state.contact), tx + titleH + 14, y + 2, tw - titleH - 14, p.text, titleFont)
        y = y + titleH + 12
        local description = quests.contactDescription and quests.contactDescription(state.contact) or focus
        local lines = Layout.wrap(compact and focus or description or "", UIFont.Small, tw / scale)
        for index = 1, math.min(compact and 1 or 2, #lines) do
            Style.line(ui, pda, lines[index], tx, y, tw, color)
            y = y + lh + 2
        end
        y = y + 12
        local trust = Style.trust(api, state.contact, tonumber((data.contactTrust or {})[state.contact]) or 0)
        y = Style.meter(ctx, tx, y, tw, trust) + 8
        if trust.nextTrust then
            Style.line(ui, pda, text("NextTrustUnlock", "Next unlock at %1 Trust", tostring(trust.nextTrust)), tx, y, tw, p.muted)
            y = y + lh + 5
        end
        if y + 2 * lh < top + headerH then
            local hint = Layout.wrap(text("BarterTrustHint", "Trust unlocks more trades and improves services."), UIFont.Small, tw / scale)
            for index = 1, math.min(2, #hint) do
                Style.line(ui, pda, hint[index], tx, y, tw, p.muted)
                y = y + lh + 2
            end
        end
        top = top + headerH + gap
        local now = getTimestampMs()
        if api.requirementCounts and (not state.walletAt or now - state.walletAt >= 1000) then
            local owner = widgets.player()
            local counts = owner and api.requirementCounts(owner, {{types = {"Base.Money"}, amount = 1}}) or {}
            state.wallet, state.walletAt = tonumber(counts[1]) or 0, now
        end
        local funds = (state.serviceOptions or {})._empdaFunds
        if state.wallet or funds then
            local label = funds and text("ServiceFunds", "Available: %1 (cash: %2 / bank: %3)",
                tostring(funds.total or 0), tostring(funds.cash or 0), tostring(funds.bank or 0))
                or text("YourMoney", "Your money: %1", tostring(state.wallet))
            Style.line(ui, pda, label, left + 4, top, width - 8, {1, 0.83, 0.40}, UIFont.Medium)
            top = top + Layout.height(UIFont.Medium) * scale + 8
        end
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
    local filterW = (width - 2 * 8) / 3
    for index, filter in ipairs(filters) do
        Style.key(ctx, {x = left + (index - 1) * (filterW + 8), y = top, w = filterW, h = buttonH},
            filter.label, filter.action, filter.selected, true, true)
    end
    top = top + buttonH + gap
    local layoutKey = table.concat({ui.width, ui.height, lh, top}, ":")
    if state.layoutKey ~= layoutKey then
        state.layoutKey, ui._empdaExtractionScroll = layoutKey, 0
        Selector.clear(ui)
    end
    local body = widgets.beginBody(ui, top, left, width)
    local cards, page = {}, {}
    function page.card(title, build, actions, icon, selector)
        local category = selector and "services" or "items"
        if state.filter and state.filter ~= "all" and state.filter ~= category then return end
        cards[#cards + 1] = {title = title, build = build, actions = actions, icon = icon, selector = selector}
    end
    ctx.build(page, data)
    local columns = math.max(1, math.min(5, math.floor((width + gap) / (220 + gap))))
    local cardW = (width - (columns - 1) * gap) / columns
    local used, y = {}, body.y
    for index = 1, #cards, columns do
        local rowH = 0
        for offset = 0, math.min(columns - 1, #cards - index) do
            local card = cards[index + offset]
            card.flow = Layout.flow(cardW - 2 * pad)
            card.flow:add(card.title)
            for _, run in ipairs(card.flow.runs) do run.x = math.max(0, (card.flow.width - Layout.width(run.text, run.font)) / 2) end
            if card.build then card.build(card.flow) end
            card.row = {items = card.actions or {}}
            card.row.height = #card.row.items * (buttonH + 8)
            card.height = 2 * pad + 72 + card.flow.y + gap + card.row.height
                + (card.selector and buttonH + 8 or 0)
            rowH = math.max(rowH, card.height)
        end
        for offset = 0, math.min(columns - 1, #cards - index) do
            local card = cards[index + offset]
            local x = left + offset * (cardW + gap)
            Style.rounded(ui, x, y, cardW, rowH, 8, pda.P.row, 0.85)
            ui:drawRectBorder(x, y, cardW, rowH, 0.35, pda.P.accent[1], pda.P.accent[2], pda.P.accent[3])
            if card.icon then Style.item(ui, card.icon, x + (cardW - 64) / 2, y + pad, 64) end
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
                if #choices == 0 then label = text("NoServiceTargets", "No eligible targets") end
                local sy = actionY - buttonH - 8
                if sy >= body.top and sy + buttonH <= body.bottom then
                    used[selector.id] = true
                    local combo = Selector.show(ui, pda.P, {id = selector.id, selected = selector.selected, options = choices,
                        placeholder = text("SelectServiceTarget", "Select a target..."), enabled = widgets.inside(data),
                        choose = function(id) state.serviceTarget[selector.id] = id end}, x + pad, sy, cardW - 2 * pad, buttonH)
                    Style.key(ctx, {x = x + pad, y = sy, w = cardW - 2 * pad, h = buttonH}, label .. "  v",
                        function() combo:forceClick() end, false, not combo.disabled)
                end
            end
            for actionIndex, action in ipairs(card.row.items) do
                Style.key(ctx, {x = x + pad, y = actionY + (actionIndex - 1) * (buttonH + 8), w = cardW - 2 * pad, h = buttonH},
                    action.label, action.action, action.selected, action.enabled)
            end
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
        if not Portrait.show(ui, state.contact, portraitRect, {
            label = text("BarterConnecting", "Connecting to %1...", quests.contactDisplayName(state.contact)),
            scale = pda.TextScale and pda.TextScale() or 1,
            animated = not pda.Animated or pda.Animated(), ready = not pda.ContentReady or pda.ContentReady(ui)}) then
            local size = math.min(112, portraitRect.w - 12, portraitRect.h - 12)
            Style.emblem(ui, state.contact, portraitRect.x + (portraitRect.w - size) / 2, portraitRect.y + (portraitRect.h - size) / 2, size, 0.9)
        end
    else Portrait.hide(ui) end
end

return Barter
