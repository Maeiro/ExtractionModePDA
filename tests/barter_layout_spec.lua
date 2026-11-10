UIFont = {Small = "small", Medium = "medium"}
local fontHeight = 14
getTimestampMs = function() return 1000 end
getTextManager = function() return {getFontHeight = function() return fontHeight end,
    MeasureStringX = function(_, _, value) return #value * 6 end} end
ExtractionMode = {}
assert(loadstring(layoutSource))()
package.loaded["ISUI/ISComboBox"] = true
local faces = {pool = {foreign = {m = {visible = true}}}}
local placed, calls = nil, 0
function faces.Place(slot, owner, x, y, w, h, character, _, framing)
    calls = calls + 1
    local entry = faces.pool[slot] or {m = {}}
    faces.pool[slot] = entry
    entry.m._owner, entry.m.visible = owner, true
    placed = {x=x, y=y, w=w, h=h, look=character.look, framing=framing}
    return true
end
package.loaded.PRPGE_ContactPortrait = faces
package.loaded.PRPGE_Portrait = {Hide = function(model) model.visible = false end}
local Barter = require "ExtractionModePDA/BarterPage"
local ids = {"dr_layne", "franklin_porch", "silas_mercer", "sgt_major_graves"}
local definitions = {}
for _, id in ipairs(ids) do definitions[#definitions + 1] = {contactId = id} end
ExtractionMode.Barters = {unlockedDefinitions = function() return definitions end}
ExtractionMode.Quests = {contactDisplayName = function(id) return id end, contactFocus = function() return "Supplies" end}
local ui = {width = 1400, height = 900, _empdaExtractionHits = {}}
function ui:drawTextureScaledAspect() end
local state = {serviceTarget = {}}
local positions, controls, viewport, lastBottom
local widgets = {modeText = function(_, fallback) return fallback end, buttonHeight = function() return fontHeight + 18 end,
    panel = function() end, inside = function() return true end,
    flow = function(_, _, flow, x, y)
        if flow.runs[1] and flow.runs[1].text:find("Offer") then
            positions[#positions + 1] = {x=x,y=y,w=flow.width}
        end
    end,
    button = function(_, _, x, y, w, label, callback)
        controls[label] = callback
        ui._empdaExtractionHits[#ui._empdaExtractionHits + 1] = {x=x,y=y,w=w,h=fontHeight+18}
    end,
    actions = function(items) return {items=items, height=fontHeight+18} end,
    drawActions = function(_, _, row)
        for _, action in ipairs(row.items) do controls[action.label] = action.action end
    end,
    beginBody = function(_, top, left, width)
        local scroll = ui._empdaExtractionScroll or 0
        viewport = {x=left,w=width,top=top,bottom=ui.height-18,h=ui.height-18-top,y=top-scroll,scroll=scroll}
        return viewport
    end,
    endBody = function(_, _, _, y) lastBottom=y end}
local ctx = {ui=ui,pda={P={}},state=state,widgets=widgets,top=180,text=function(_, fallback) return fallback end,
    build = function(page)
        for i=1,6 do page.card("Offer " .. i, function(flow) flow:add("A material requirement with a longer name") end) end
    end}
local function render()
    positions,controls = {},{}
    Barter.render(ctx, {contactTrust={}})
    assert(#positions == 6)
    for _, p in ipairs(positions) do
        assert(p.x >= viewport.x and p.x+p.w <= viewport.x+viewport.w, "offer content remains inside its column")
    end
    assert(lastBottom > viewport.top)
end
for _, size in ipairs({{1400,14},{900,14},{480,14},{480,22}}) do
    ui.width,fontHeight=size[1],size[2]
    render()
    assert(placed.x+placed.w <= ui.width-18 and placed.y >= 180, "portrait stays within PDA")
    assert(placed.look.f == true and placed.framing.ext, "Judith has her own appearance and native idle animations")
    if ui.width == 1400 then assert(positions[1].y == positions[2].y and positions[2].x>positions[1].x, "wide PDA uses a card grid") end
end
ui.width,fontHeight=1400,14
render()
local model = faces.pool["extraction-barter"].m
local portraitY, offerY = placed.y, positions[1].y
ui._empdaExtractionScroll=80
render()
assert(placed.y==portraitY and positions[1].y==offerY-80, "only the offers scroll")
controls.franklin_porch()
assert(ui._empdaExtractionScroll==0 and not model.visible, "switching contact resets scrolling and hides the old portrait")
render()
assert(faces.pool["extraction-barter"].m==model and placed.look.f~=true, "reuse one model for different contacts")
controls.Services()
positions,controls={},{}
Barter.render(ctx, {contactTrust={}})
assert(#positions==0, "service filter excludes item offers")
assert(ui._empdaExtractionScroll==0)
Barter.hide(ui)
assert(not model.visible and faces.pool.foreign.m.visible, "closing hides only this integration's portrait")
faces.Place = function() calls=calls+1; error("incompatible renderer") end
local portrait=require "ExtractionModePDA/BarterPortrait"
local rect={x=0,y=0,w=100,h=100}
assert(not portrait.show(ui,"dr_layne",rect))
local attempts=calls
assert(not portrait.show(ui,"dr_layne",rect) and calls==attempts, "renderer failures do not repeat each frame")
print("Barter layout: responsive cards, fixed profile, filters, contact changes and owned portrait lifecycle passed")
