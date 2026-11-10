require "ISUI/ISComboBox"
local Selector = {}

function Selector.clear(ui)
    for _, combo in pairs(ui._empdaServiceSelectors or {}) do
        if combo.expanded then combo:hidePopup() end
        combo:setVisible(false)
        ui:removeChild(combo)
    end
    ui._empdaServiceSelectors = nil
end

function Selector.hideUnused(ui, used)
    for id, combo in pairs(ui._empdaServiceSelectors or {}) do
        if not used[id] then
            if combo.expanded then combo:hidePopup(); combo.expanded = false end
            combo:setVisible(false)
        end
    end
end

function Selector.show(ui, palette, descriptor, x, y, width, height)
    ui._empdaServiceSelectors = ui._empdaServiceSelectors or {}
    local combo = ui._empdaServiceSelectors[descriptor.id]
    if not combo then
        combo = ISComboBox:new(x, y, width, height, nil, function(_, box)
            descriptor.choose(box:getOptionData(box.selected))
        end)
        combo:initialise()
        combo:instantiate()
        -- The PDA paints after its children; the page draws this control's face.
        combo.prerender, combo.render = function() end, function() end
        ui:addChild(combo)
        ui._empdaServiceSelectors[descriptor.id] = combo
    end
    combo.onChange = function(_, box) descriptor.choose(box:getOptionData(box.selected)) end
    local keys = {descriptor.placeholder}
    for _, option in ipairs(descriptor.options) do keys[#keys + 1] = tostring(option.id) .. ":" .. option.label end
    local signature = table.concat(keys, "|")
    if combo._empdaOptions ~= signature then
        if combo.expanded then combo:hidePopup(); combo.expanded = false end
        combo:clear()
        combo:addOptionWithData(descriptor.placeholder, nil)
        for _, option in ipairs(descriptor.options) do combo:addOptionWithData(option.label, option.id) end
        combo._empdaOptions = signature
    end
    combo.selected = 1
    for index, option in ipairs(descriptor.options) do
        if option.id == descriptor.selected then combo.selected = index + 1 end
    end
    combo:setX(x); combo:setY(y); combo:setWidth(width); combo:setHeight(height)
    combo.disabled = descriptor.enabled == false or #descriptor.options == 0
    combo:setVisible(true)
    local hover, ink = palette.buttonHover or palette.panel, palette.text or {1, 1, 1}
    combo.backgroundColorMouseOver = {r = hover[1], g = hover[2], b = hover[3], a = 1}
    combo.textColor = {r = ink[1], g = ink[2], b = ink[3], a = 1}
    if combo.popup then
        combo.popup.backgroundColor = {r = palette.panel[1], g = palette.panel[2], b = palette.panel[3], a = 1}
        combo.popup.borderColor = {r = palette.edge[1], g = palette.edge[2], b = palette.edge[3], a = 1}
        combo.popup:setAlwaysOnTop(true)
    end
    return combo
end

return Selector
