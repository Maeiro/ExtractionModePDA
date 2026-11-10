local Portrait = {}
local slot = "extraction-barter"
local faces, renderer, checked, failed
local looks = {
    dr_layne = {f = true, hair = "Bun", skin = 1,
        worn = {"Base.Shirt_FormalWhite", "Base.Trousers_Suit", "Base.Shoes_Black", "Base.JacketLong_Doctor"}},
    franklin_porch = {hair = "Short", beard = "Full", skin = 0,
        worn = {"Base.Shirt_Denim", "Base.Trousers_JeanBaggy", "Base.Shoes_BlackBoots"}},
    sgt_major_graves = {f = true, hair = "Bun", skin = 2,
        worn = {"Base.Shirt_FormalWhite", "Base.Trousers_CamoGreen", "Base.Shoes_BlackBoots", "Base.Jacket_ArmyCamoGreen"}},
    silas_mercer = {hair = "Short", beard = "Goatee", skin = 1,
        worn = {"Base.Shirt_FormalWhite", "Base.Trousers_Suit", "Base.Shoes_Black", "Base.Suit_Jacket"}},
    elias_vance = {hair = "Bald", beard = "Full", skin = 0,
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
end

function Portrait.show(ui, contact, rect)
    if failed or not loadRenderer() then return false end
    local ok, shown = pcall(faces.Place, slot, ui, rect.x, rect.y, rect.w, rect.h,
        {look = looks[contact] or fallback, on = true}, nil, {zoom = 12, yOffset = -0.76, ext = true})
    if not ok then
        failed = true
        Portrait.hide(ui)
        print("[ExtractionModePDA] Barter portrait disabled: " .. tostring(shown))
        return false
    end
    return shown == true
end

return Portrait
