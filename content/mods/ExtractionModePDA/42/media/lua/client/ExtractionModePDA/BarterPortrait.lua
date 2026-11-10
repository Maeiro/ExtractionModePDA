local Portrait = {}
local slot = "extraction-barter"
local faces, renderer, checked, failed
local openedAt, seenAt, currentContact, linkInfo, overlay
local looks = {
    dr_layne = {f = true, hair = "Bun", skin = 1, hc = {0.42, 0.20, 0.10}, tex = {},
        worn = {"Base.Shirt_FormalWhite", "Base.Trousers_Suit", "Base.Shoes_Black", "Base.JacketLong_Doctor"}},
    franklin_porch = {hair = "Short", beard = "Full", skin = 0, hc = {0.36, 0.30, 0.22}, tex = {},
        worn = {"Base.Shirt_Denim", "Base.Trousers_JeanBaggy", "Base.Shoes_BlackBoots"}},
    sgt_major_graves = {f = true, hair = "Bun", skin = 2, hc = {0.24, 0.20, 0.16}, tex = {},
        worn = {"Base.Shirt_FormalWhite", "Base.Trousers_CamoGreen", "Base.Shoes_BlackBoots", "Base.Jacket_ArmyCamoGreen"}},
    silas_mercer = {hair = "Short", beard = "Goatee", skin = 1, hc = {0.12, 0.10, 0.09}, tex = {},
        worn = {"Base.Shirt_FormalWhite", "Base.Trousers_Suit", "Base.Shoes_Black", "Base.Suit_Jacket"}},
    elias_vance = {hair = "Bald", beard = "Full", skin = 0, hc = {0.70, 0.67, 0.63}, tex = {},
        worn = {"Base.Shirt_FormalWhite", "Base.Trousers_Suit", "Base.Shoes_Black", "Base.JacketLong_Doctor"}},
}
local fallback = {hair = "Short", skin = 0,
    worn = {"Base.Shirt_FormalWhite", "Base.Trousers_Suit", "Base.Shoes_Black"}}

local function loadRenderer()
    if checked then return faces ~= nil end
    checked = true
    local okFaces, f = pcall(require, "PRPGE_ContactPortrait")
    local okRenderer, r = pcall(require, "PRPGE_Portrait")
    if okFaces and okRenderer and type(f) == "table" and type(f.Place) == "function"
        and type(f.pool) == "table" and type(r) == "table" and type(r.Hide) == "function" then
        faces, renderer = f, r
    end
    return faces ~= nil
end

function Portrait.hide(ui)
    local entry = faces and faces.pool[slot]
    if entry and entry.m and entry.m._owner == ui then renderer.Hide(entry.m) end
    if overlay and overlay._link == linkInfo then renderer.Hide(overlay) end
    openedAt, seenAt, currentContact, linkInfo = nil, nil, nil, nil
end

function Portrait.show(ui, contact, rect, options)
    if failed or not loadRenderer() then return false end
    options = options or {}
    if options.ready == false then Portrait.hide(ui); return true end
    local now = getTimestampMs() / 1000
    if contact ~= currentContact or not seenAt or now - seenAt > 0.4 then openedAt = now end
    seenAt, currentContact = now, contact
    local ok, shown = pcall(function()
        local dx, dy = 0, 0
        if options.animated ~= false and renderer.LinkShake then dx, dy = renderer.LinkShake(now - openedAt, now) end
        local visible = faces.Place(slot, ui, rect.x + dx, rect.y + dy, rect.w, rect.h,
            {look = looks[contact] or fallback, on = true}, nil, {zoom = 12, yOffset = -0.76, ext = true})
        local entry = faces.pool[slot]
        if options.animated ~= false and renderer.PlaceLink and entry then
            local info = {at = openedAt, label = options.label, scale = options.scale or 1}
            if renderer.PlaceLink(entry.m, ui, rect.x + dx, rect.y + dy, rect.w, rect.h, info) then
                linkInfo = info
                if renderer.LinkOverlay then overlay = renderer.LinkOverlay() end
                visible = visible or now - openedAt < (renderer.LINK or 1.1)
            end
        elseif overlay and overlay._link == linkInfo then
            renderer.Hide(overlay)
        end
        return visible
    end)
    if not ok then
        failed = true
        Portrait.hide(ui)
        print("[ExtractionModePDA] Barter portrait disabled: " .. tostring(shown))
        return false
    end
    return shown == true
end

return Portrait
