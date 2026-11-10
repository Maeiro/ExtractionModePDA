UIFont = {Small = "small", Medium = "medium"}
getTextManager = function() return {getFontHeight = function() return 14 end,
    MeasureStringX = function(_, _, value) return #value * 6 end} end
getTimestampMs = function() return 1000 end
local textures = {}
instanceItem = function(fullType)
    textures[fullType] = true
    return {getTex = function() return fullType end}
end
ISComboBox = {}
function ISComboBox:new(x, y, w, h, target, callback)
    return setmetatable({options = {}, selected = 1, target = target, onChange = callback}, {__index = self})
end
function ISComboBox:initialise() end
function ISComboBox:instantiate() end
function ISComboBox:clear() self.options = {} end
function ISComboBox:addOptionWithData(label, id) self.options[#self.options + 1] = {label = label, id = id} end
function ISComboBox:getOptionData(index) return self.options[index].id end
function ISComboBox:setX() end
function ISComboBox:setY() end
function ISComboBox:setWidth() end
function ISComboBox:setHeight() end
function ISComboBox:setVisible(value) self.visible = value end
function ISComboBox:hidePopup() self.hidden = true end
function ISComboBox:forceClick() self.expanded = not self.expanded end
package.loaded["ISUI/ISComboBox"] = true
ExtractionMode = {Config = {STATE_HIDEOUT = "HIDEOUT", STATE_RAID = "RAID", COMMAND_MODULE = "ExtractionMode"}}
assert(loadstring(layoutSource))()
local player = {getModData = function() return {} end}
local data = {state = "HIDEOUT", quests = {}, contactTrust = {}, hideoutUpgradeSupply = {}}
local sent, flows, buttons, titles = {}, {}, {}, {}
ExtractionMode.Client = {sendCommand = function() end}
ExtractionMode.Util = {username = function() return "player" end}
ExtractionMode.Localization = {serviceLabel = function(label) return label end, text = function(label) return label end}
local function label(value) return value.label end
local function counts(_, entries) local c = {}; for i in ipairs(entries) do c[i] = 100 end; return c end
local trades = {
    {id = "heal", contactId = "doctor", service = "wound", offered = {{label = "Money", amount = 20, types = {"Base.Money"}}}},
    {id = "tools", contactId = "mechanic", offered = {}, received = {{label = "Wrench", fullType = "Base.Wrench"}}},
    {id = "alcohol", contactId = "doctor", offered = {{label = "Bleach", amount = 1, types = {"Base.Bleach"}}},
        received = {{label = "Alcohol", fullType = "Base.Disinfectant"}}},
}
ExtractionMode.Barters = {unlockedDefinitions = function() return trades end, requirementCounts = counts, label = label,
    serviceName = function() return "Minor treatment" end, serviceNextTrust = function() return 40 end,
    isUnlocked = function() return true end}
local quest = {id = "food", contactId = "doctor", requirements = {{label = "Food", amount = 5, types = {"Base.TinnedBeans"}}},
    skillRequirements = {{label = "Welding", level = 3}}, objectives = {}}
ExtractionMode.Quests = {acquiredDefinitions = function() return {quest} end, isCompleted = function() return false end,
    contactDisplayName = function(id) return id end, name = function() return "Supplies" end,
    description = function() return "Description" end, label = label, requirementCounts = counts,
    skillRequirementsMet = function() return true end, objectivesMet = function() return true end, skillLevel = function() return 7 end}
local upgrade = {id = "security", requirements = {{label = "Sheet Metal", amount = 4, types = {"Base.SheetMetal"}}},
    skillRequirements = {{label = "Welding", level = 1}}}
ExtractionMode.Upgrades = {categories = function() return {{id = "utilities", label = "Utilities"}} end,
    definitionsForCategory = function() return {upgrade} end, requirementCounts = counts,
    isInstalled = function() return false end, prerequisitesMet = function() return true end,
    upgradeSkillRequirementsMet = function() return true end, name = function() return "Security" end,
    description = function() return "Secure the hideout" end, label = label, skillLevel = function() return 7 end}
ExtractionMode.Generator = {capacity = function() return 40 end}
local ui = {width = 900, height = 1100, _empdaExtractionHits = {}, children = {}}
function ui:addChild(child) self.children[child] = true end
function ui:removeChild(child) self.children[child] = nil end
function ui:drawTextureScaledAspect() end
function ui:setStencilRect() end
function ui:drawTextCentre() end
local palette = {panel = {0,0,0}, edge = {1,1,1}, text = {1,1,1}, muted = {0.5,0.5,0.5}}
local widgets = {player = function() return player end, allowed = function() return true end,
    inside = function(d) return d.state == "HIDEOUT" end,
    send = function(command, args) sent[#sent + 1] = {command, args} end,
    modeText = function(_, fallback) return fallback end, refreshSample = function() return {gasoline = 0} end,
    buttonHeight = function() return 32 end, panel = function() end, flow = function(_, _, f)
        flows[#flows + 1] = f
        titles[#titles + 1] = f.runs[1] and f.runs[1].text
    end,
    actions = function(items) return {items = items, height = #items > 0 and 32 or 0} end,
    drawActions = function(_, _, row)
        for _, item in ipairs(row.items) do buttons[#buttons + 1] = item end
    end,
    button = function(_, _, _, _, _, text, callback, enabled) buttons[#buttons + 1] = {label=text,action=callback,enabled=enabled} end,
    beginBody = function(_, top, left, width) return {x = left or 18,w = width or 864,y = top,top = top,bottom = 1100,h = 1100-top} end,
    endBody = function() end}
local Pages = require "ExtractionModePDA/Pages"
local view = Pages.new({text = function(_, fallback) return fallback end, state = function() return data end}, widgets)
local Icons = require "ExtractionModePDA/ItemIcons"
for _, width in ipairs({250, 1600}) do
    local flow = ExtractionMode.TextLayout.flow(width)
    Icons.row(flow, "Sheet Metal: 3/4", "Base.SheetMetal", true)
    Icons.row(flow, "Welding: 7/1", "Base.BookMetalWelding1", false)
    assert(#flow.runs == 2, "ordinary requirement labels must remain on one line at normal PDA widths")
    for _, run in ipairs(flow.runs) do
        assert(run.x == 42, "requirement text starts immediately beside its icon")
        assert(run.x + ExtractionMode.TextLayout.width(run.text) <= width, "requirement text stays inside the card")
    end
    assert(flow.runs[2].iconY >= flow.runs[1].iconY + 32, "icon rows must not overlap")
end
local function render(page)
    flows, buttons, titles = {}, {}, {}
    view.render(ui, {P=palette}, 0, page)
end
local function hasIcon(icon)
    for _, flow in ipairs(flows) do for _, run in ipairs(flow.runs) do if run.icon == icon then return true end end end
end
render("upgrades")
assert(hasIcon("Base.SheetMetal") and hasIcon("Base.BookMetalWelding1"), "upgrade requirements must show material and skill-book icons")
render("quests")
assert(hasIcon("Base.TinnedBeans") and hasIcon("Base.BookMetalWelding2"), "mission requirements must show item and matching skill-volume icons")
render("barter")
assert(not table.concat(titles,"|"):find("Wrench"), "barter shows only the selected contact's offers")
assert(hasIcon("Base.Money") and hasIcon("Base.Bleach"), "deferred cards retain each offer's own requirements")
local switch
for _, button in ipairs(buttons) do if button.label == "mechanic" then switch = button.action end end
ui._empdaExtractionScroll = 900
switch()
assert(ui._empdaExtractionScroll == 0)
render("barter")
assert(table.concat(titles,"|"):find("Wrench") and not table.concat(titles,"|"):find("Minor treatment"))
for _, button in ipairs(buttons) do if button.label == "doctor" then button.action() end end
view.receive("ExtractionMode", "BarterServices", {options={heal={{id="neck",label="Neck - Cut",quote="first",canUse=true}}}})
render("barter")
local combo = ui._empdaServiceSelectors.heal
assert(combo.options[2].label == "Neck - Cut", "service dropdown uses descriptive labels")
combo.selected = 2; combo.onChange(nil, combo)
render("barter")
local stale
for _, button in ipairs(buttons) do if button.label == "REQUEST SERVICE" then assert(button.enabled); stale = button.action end end
local before = #sent
view.receive("ExtractionMode", "BarterServices", {options={heal={{id="neck",label="Neck - Cut",quote="new",canUse=true}}}})
stale()
assert(#sent == before, "stale service quotes must not be submitted")
render("barter")
for _, button in ipairs(buttons) do if button.label == "REQUEST SERVICE" then button.action() end end
assert(sent[#sent][1] == "CompleteBarter" and sent[#sent][2].quote == "new")
combo.expanded = true
view.close()
assert(combo.hidden and not ui.children[combo], "closing PDA removes service controls and popups")
print("UI pages: icons, skill volumes, trader isolation, scroll reset, named targets, quote validation and cleanup passed")
