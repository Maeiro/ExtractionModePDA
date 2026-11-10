require "OptionScreens/ServerSettingsScreen"
if ServerSettingsScreen._empdaSandboxSettings then return end
local keys = {"WoundTreatmentCost", "ClothingRepairCost", "MeleeRepairCost", "FirearmRepairCost", "VehicleRepairCost"}
local original = ServerSettingsScreen.getSandboxSettingsTable

ServerSettingsScreen.getSandboxSettingsTable = function(...)
    local pages = original(...)
    local seen, target = {}, nil
    local title = getText("Sandbox_ExtractionModePDA")
    for _, page in ipairs(pages) do
        if page.name == title then target = page end
        for _, setting in ipairs(page.settings or {}) do
            if type(setting.name) == "string" then
                seen[setting.name] = true
                if setting.name:sub(1, 18) == "ExtractionModePDA." then target = page end
            end
        end
    end
    local options = getSandboxOptions()
    for _, key in ipairs(keys) do
        local name = "ExtractionModePDA." .. key
        local option = options:getOptionByName(name)
        if option and not seen[name] then
            if not target then
                target = {name = title, settings = {}}
                pages[#pages + 1] = target
            end
            target.settings[#target.settings + 1] = {name = name, translatedName = option:getTranslatedName(),
                tooltip = option:getTooltip(), type = "entry", text = option:getValueAsString(),
                onlyNumbers = option:getType() == "integer"}
            seen[name] = true
        end
    end
    return pages
end
ServerSettingsScreen._empdaSandboxSettings = true
