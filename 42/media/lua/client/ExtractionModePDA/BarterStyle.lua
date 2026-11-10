local Style = {}
local aliases = {dr_layne = "MD", franklin_porch = "MK", silas_mercer = "SH", sgt_major_graves = "VG", elias_vance = "TC"}
local textures = {}
local skin, effects, traders

local function optional(name)
    local ok, value = pcall(require, name)
    return ok and type(value) == "table" and value or {}
end

function Style.color(contact, palette)
    effects = effects or optional("PRPGE_EffectsModel")
    return effects.COLORS and effects.COLORS[aliases[contact]] or palette.accent
end

function Style.emblem(ui, contact, x, y, size, alpha)
    local id = aliases[contact] or "SC"
    if textures[id] == nil then
        textures[id] = getTexture("media/ui/RPGSkillTreeExpanded/PRPGE_Trader_" .. id .. ".png") or false
    end
    if textures[id] then ui:drawTextureScaled(textures[id], x, y, size, size, alpha or 1, 1, 1, 1) end
end

function Style.rounded(ui, x, y, w, h, radius, color, alpha)
    skin = skin or optional("PRPGE_Skin")
    if skin.Rounded then skin.Rounded(ui, x, y, w, h, radius, color, alpha or 1)
    else ui:drawRect(x, y, w, h, alpha or 1, color[1], color[2], color[3]) end
end

function Style.line(ui, pda, label, x, y, width, color, font, centered)
    font = font or UIFont.Small
    local scale = pda.TextScale and pda.TextScale() or 1
    local Layout = ExtractionMode.TextLayout
    label = Layout.fit(tostring(label or ""), font, math.max(1, width / scale))
    if centered then x = x + (width - Layout.width(label, font) * scale) / 2 end
    ui:drawTextZoomed(label, x, y, scale, color[1], color[2], color[3], 1, font)
end

function Style.key(ctx, rect, label, callback, selected, enabled, navigation, color)
    local ui, pda = ctx.ui, ctx.pda
    local p = pda.P
    color = enabled == false and p.muted or color or p.accent
    Style.rounded(ui, rect.x, rect.y, rect.w, rect.h, 6, selected and p.buttonHover or p.screen, 1)
    ui:drawRectBorder(rect.x, rect.y, rect.w, rect.h, enabled == false and 0.2 or selected and 0.95 or 0.35,
        color[1], color[2], color[3])
    if selected then ui:drawRect(rect.x + 4, rect.y + rect.h - 3, rect.w - 8, 2, 1, color[1], color[2], color[3]) end
    local scale = pda.TextScale and pda.TextScale() or 1
    Style.line(ui, pda, label, rect.x + 5, rect.y + (rect.h - ExtractionMode.TextLayout.height(UIFont.Small) * scale) / 2,
        rect.w - 10, enabled == false and p.muted or selected and p.text or color, nil, true)
    if enabled ~= false then
        rect.navigation, rect.label = navigation, label
        ctx.widgets.hit(ui, rect, callback)
    end
end

function Style.item(ui, texture, x, y, size)
    traders = traders or optional("PRPGE_TradersClient")
    if traders.DrawIcon then traders.DrawIcon(ui, texture, x, y, size)
    else ui:drawTextureScaledAspect(texture, x, y, size, size, 1, 1, 1, 1) end
end

function Style.trust(api, contact, value)
    local maximum, thresholds, seen = 100, {}, {}
    local function add(v)
        v = tonumber(v)
        if not v or v <= 0 or seen[v] then return end
        seen[v], thresholds[#thresholds + 1] = true, v
        maximum = math.max(maximum, v)
    end
    for _, def in ipairs(api.definitions and api.definitions() or {}) do
        if def.contactId == contact and def.disabled ~= true then
            add(def.requiredTrust)
            if def.service and api.serviceNextTrust then
                local previous = 0
                for _ = 1, 3 do
                    local nextTrust = api.serviceNextTrust(def, {[contact] = previous})
                    if not nextTrust or nextTrust <= previous then break end
                    add(nextTrust)
                    previous = nextTrust
                end
            end
        end
    end
    table.sort(thresholds)
    local nextTrust
    for _, threshold in ipairs(thresholds) do if threshold > value then nextTrust = threshold; break end end
    return {value = value, maximum = maximum, thresholds = thresholds, nextTrust = nextTrust}
end

function Style.meter(ctx, x, y, w, trust)
    local ui, pda, Layout = ctx.ui, ctx.pda, ExtractionMode.TextLayout
    local p, green = pda.P, {0.40, 0.92, 0.55}
    local scale = pda.TextScale and pda.TextScale() or 1
    local height = Layout.height(UIFont.Small) * scale
    Style.line(ui, pda, ctx.text("TrustValue", "Trust: %1", tostring(trust.value)), x, y, w, green, nil, true)
    local trackY = y + height + 6
    ui:drawRect(x, trackY, w, 10, 1, p.well[1], p.well[2], p.well[3])
    for _, threshold in ipairs(trust.thresholds) do
        local tx = x + w * threshold / trust.maximum
        ui:drawRect(tx, trackY, 1, 10, 0.5, p.muted[1], p.muted[2], p.muted[3])
    end
    local filled = w * math.max(0, math.min(1, trust.value / trust.maximum))
    ui:drawRect(x, trackY + 1, filled, 8, 1, green[1], green[2], green[3])
    ui:drawRect(x, trackY - 3, 2, 16, 1, p.text[1], p.text[2], p.text[3])
    Style.rounded(ui, x + math.max(0, math.min(w - 10, filled - 5)), trackY - 4, 10, 18, 3, green, 1)
    Style.line(ui, pda, "0", x, trackY + 13, w / 2, p.muted)
    local maximum = tostring(trust.maximum)
    local maximumW = Layout.width(maximum) * scale
    Style.line(ui, pda, maximum, x + w - maximumW, trackY + 13, maximumW + 1, p.muted)
    return trackY + 13 + height
end

return Style
