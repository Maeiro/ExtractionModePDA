UIFont = {Small = "small", Medium = "medium"}
local fontHeight = 14
local clock = 1000
getTimestampMs = function() return clock end
getTexture = function(name) return name end
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
local overlay, linkCalls, shakeCalls = {visible=false}, 0, 0
package.loaded.PRPGE_Portrait = {
    Hide = function(model) model.visible = false end,
    LinkShake = function() shakeCalls=shakeCalls+1; return 0,0 end,
    PlaceLink = function(_, _, _, _, _, _, info)
        overlay._link, overlay.visible = info, true
        linkCalls = linkCalls + 1
        return true
    end,
    LinkOverlay = function() return overlay end,
}
local nativeIcons = 0
package.loaded.PRPGE_TradersClient = {DrawIcon = function() nativeIcons=nativeIcons+1 end}
local Barter = require "ExtractionModePDA/BarterPage"
local ids = {"dr_layne", "franklin_porch", "silas_mercer", "sgt_major_graves"}
local definitions = {}
for _, id in ipairs(ids) do definitions[#definitions + 1] = {contactId = id} end
ExtractionMode.Barters = {unlockedDefinitions = function() return definitions end}
ExtractionMode.Quests = {contactDisplayName = function(id) return id end, contactFocus = function() return "Supplies" end}
local ui = {width = 1400, height = 900, _empdaExtractionHits = {}}
function ui:drawTextureScaledAspect() end
function ui:drawTextureScaled() end
function ui:drawRect() end
function ui:drawRectBorder() end
function ui:drawTextZoomed() end
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
    hit = function(_, rect, callback)
        controls[rect.label] = callback
        ui._empdaExtractionHits[#ui._empdaExtractionHits + 1] = rect
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
local palette = {panel={0,0,0},edge={1,1,1},accent={1,1,1},text={1,1,1},muted={0.5,0.5,0.5},
    screen={0,0,0},well={0,0,0},row={0,0,0},buttonHover={0.1,0.1,0.1}}
local ctx = {ui=ui,pda={P=palette},state=state,widgets=widgets,top=180,text=function(_, fallback) return fallback end,
    build = function(page)
        for i=1,6 do page.card("Offer " .. i, function(flow) flow:add("A material requirement with a longer name") end, nil, "item-texture") end
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
assert(overlay.visible and linkCalls>0 and shakeCalls>0, "camera uses native connection and interference renderers")
assert(nativeIcons>0 and not controls.TALK, "barter reuses native item drawing and exposes no dialogue action")
local openedAt = overlay._link.at
clock=1100
ui._empdaExtractionScroll=80
render()
assert(placed.y==portraitY and positions[1].y==offerY-80, "only the offers scroll")
assert(overlay._link.at==openedAt, "camera connection does not restart every frame")
local animatedCalls = linkCalls
ctx.pda.Animated=function() return false end
render()
assert(not overlay.visible and linkCalls==animatedCalls, "disabled PDA effects hide the camera overlay")
ctx.pda.Animated=nil
render()
controls.franklin_porch()
assert(ui._empdaExtractionScroll==0 and not model.visible and not overlay.visible, "switching contact hides model and camera overlay")
render()
assert(faces.pool["extraction-barter"].m==model and placed.look.f~=true, "reuse one model for different contacts")
controls.Services()
positions,controls={},{}
Barter.render(ctx, {contactTrust={}})
assert(#positions==0, "service filter excludes item offers")
assert(ui._empdaExtractionScroll==0)
Barter.hide(ui)
assert(not model.visible and not overlay.visible and faces.pool.foreign.m.visible, "closing hides only this integration's model and overlay")
state.filter=nil
render()
overlay._link, overlay.visible = {foreign=true}, true
Barter.hide(ui)
assert(overlay.visible, "closing does not hide a camera overlay reused by a native trader")
faces.Place = function() calls=calls+1; error("incompatible renderer") end
local portrait=require "ExtractionModePDA/BarterPortrait"
local rect={x=0,y=0,w=100,h=100}
assert(not portrait.show(ui,"dr_layne",rect))
local attempts=calls
assert(not portrait.show(ui,"dr_layne",rect) and calls==attempts, "renderer failures do not repeat each frame")
local Style=require "ExtractionModePDA/BarterStyle"
local trustAPI={definitions=function() return {
    {contactId="doctor", requiredTrust=20, service="wound"},
    {contactId="doctor", requiredTrust=60},
    {contactId="doctor", requiredTrust=200},
    {contactId="doctor", requiredTrust=500, disabled=true},
    {contactId="other", requiredTrust=1000},
} end, serviceNextTrust=function(_, trust)
    if trust.doctor<40 then return 40 end
    if trust.doctor<70 then return 70 end
end}
local trust=Style.trust(trustAPI,"doctor",30)
assert(trust.maximum==200 and trust.nextTrust==40 and table.concat(trust.thresholds,",")=="20,40,60,70,200",
    "trust meter uses contact trade thresholds and native service upgrades")
trust=Style.trust(trustAPI,"doctor",300)
assert(trust.value==300 and not trust.nextTrust and trust.maximum==200, "trust remains uncapped by the display scale")
ui.width,ui.height,fontHeight,ctx.top=1680,960,18,230
ui._empdaExtractionScroll,state.wallet,state.filter=0,0,nil
local selector=require "ExtractionModePDA/ServiceSelector"
local originalShow=selector.show
selector.show=function() return {disabled=true} end
local Icons=require "ExtractionModePDA/ItemIcons"
ctx.build=function(page)
    for i=1,6 do
        page.card("Offer " .. i,function(flow)
            flow:add("You give")
            Icons.row(flow,"Money: 20/20","money-texture",false,24)
            flow:add("Upgrades at 40 Trust")
        end,{{label="REQUEST SERVICE",action=function() end}},"item-texture",{id=tostring(i),options={}})
    end
end
ui._empdaExtractionHits={}
render()
local firstRow=0
for _,rect in ipairs(ui._empdaExtractionHits) do
    if rect.label=="REQUEST SERVICE" and rect.y<positions[6].y then
        firstRow=firstRow+1
        assert(rect.y+rect.h<=viewport.bottom,"normal PDA fits complete first-row service cards and their actions")
    end
end
assert(firstRow==5)
selector.show=originalShow
print("Barter layout: responsive cards, fixed profile, filters, contact changes and owned portrait lifecycle passed")
