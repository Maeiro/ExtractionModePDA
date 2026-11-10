local Safety = require "ExtractionModePDA/GaragePreviewSafety"
local function part(files)
    return {
        getModelCount = function() return #files end,
        getModel = function(_, index) return { getFile = function() return files[index + 1] end } end,
    }
end
local parts = {part({"Body", "Wheel"})}
local script = {
    getPartCount = function() return #parts end,
    getPart = function(_, index) return parts[index + 1] end,
}
local models = {
    Body = { isStatic = function() return true end },
    Wheel = { isStatic = function() return true end },
    Door = { isStatic = function() return false end },
}
local present = true
getScriptManager = function() return {
    getVehicle = function() return present and script or nil end,
    getModelScript = function(_, name) return models[name] end,
} end
assert(not Safety.requiresIllustration("StaticCar"), "static vehicles retain 3D previews")
parts[2] = part({"Unknown", "Door"})
assert(Safety.requiresIllustration("AnimatedVan"), "animated parts must be rejected before rendering")
parts[2] = part({"Unknown"})
assert(Safety.requiresIllustration("UnknownModel"), "unresolved models must avoid the native renderer")
parts = {part({})}
assert(not Safety.requiresIllustration("NoPartModels"))
parts = {{getModelCount = function() return 1 end, getModel = function() return nil end}}
assert(Safety.requiresIllustration("MissingVehicleModel"), "missing vehicle model references must use an illustration")
present = false
assert(not Safety.requiresIllustration("MissingVehicle"), "native missing-script fallback stays available")
print("Garage preview safety checks passed")
