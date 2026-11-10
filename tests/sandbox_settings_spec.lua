package.loaded["OptionScreens/ServerSettingsScreen"] = true
local source = {{name="Vanilla",settings={{name="DayLength"}}}}
ServerSettingsScreen = {getSandboxSettingsTable=function() return source end}
getText=function(key) return key=="Sandbox_ExtractionModePDA" and "PDA services" or key end
local options = {}
getSandboxOptions=function() return {getOptionByName=function(_, name) return options[name] end} end
require "ExtractionModePDA/SandboxSettings"
local pages = ServerSettingsScreen.getSandboxSettingsTable()
assert(#pages==1, "no phantom options before the engine registers this mod")
local keys={"WoundTreatmentCost","ClothingRepairCost","MeleeRepairCost","FirearmRepairCost","VehicleRepairCost"}
for _,key in ipairs(keys) do
    local label=key
    options["ExtractionModePDA."..key]={getTranslatedName=function() return label end,getTooltip=function() return "Help" end,
        getValueAsString=function() return "20" end,getType=function() return "integer" end}
end
pages=ServerSettingsScreen.getSandboxSettingsTable()
assert(#pages==2 and pages[2].name=="PDA services" and #pages[2].settings==5,
    "recover all five registered options from the menu's stale page cache")
for _,setting in ipairs(pages[2].settings) do
    assert(setting.type=="entry" and setting.onlyNumbers and setting.tooltip=="Help" and setting.translatedName)
end
assert(#ServerSettingsScreen.getSandboxSettingsTable()[2].settings==5, "reopening the menu never duplicates controls")
source={{name="Vanilla",settings={{name="DayLength"}}},{name="PDA services",settings={{name="ExtractionModePDA.WoundTreatmentCost"}}}}
pages=ServerSettingsScreen.getSandboxSettingsTable()
assert(#pages==2 and #pages[2].settings==5, "repair a partial page without touching other categories")
print("Sandbox UI: late registration, stale/partial page caches and duplicate prevention passed")
