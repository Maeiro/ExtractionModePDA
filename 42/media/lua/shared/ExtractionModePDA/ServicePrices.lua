require "ExtractionMode/Barters"
local barters = ExtractionMode.Barters
if barters._empdaServicePrices then return barters._empdaServicePrices end
local Prices = {}
Prices.settings = {
    wound = {key = "WoundTreatmentCost", default = 20},
    clothing = {key = "ClothingRepairCost", default = 10},
    melee = {key = "MeleeRepairCost", default = 20},
    gun = {key = "FirearmRepairCost", default = 20},
    vehicle = {key = "VehicleRepairCost", default = 20},
}

function Prices.supported(definition)
    if not definition or not Prices.settings[definition.service] then return false end
    local offered = definition.offered or {}
    return #offered == 1 and offered[1].types and #offered[1].types == 1 and offered[1].types[1] == "Base.Money"
end

function Prices.isMoney(entry)
    if not entry then return false end
    return (entry.types and #entry.types == 1 and entry.types[1] == "Base.Money")
        or (not entry.types and entry.fullType == "Base.Money")
end

function Prices.split(offered)
    local cost, materials, hasMoney = 0, {}, false
    for _, entry in ipairs(offered or {}) do
        if Prices.isMoney(entry) then
            hasMoney = true
            cost = cost + math.max(0, math.ceil(tonumber(entry.amount) or 0))
        else materials[#materials + 1] = entry end
    end
    return cost, materials, hasMoney
end

function Prices.get(service, authoritative)
    local setting = Prices.settings[service]
    if not setting then return nil end
    local config = SandboxVars and SandboxVars.ExtractionModePDA or {}
    local value = tonumber(authoritative and authoritative[service] or config[setting.key])
    if not value or value ~= value then value = setting.default end
    return math.floor(math.max(0, math.min(100000, value)))
end

function Prices.offered(definition, authoritative)
    if not Prices.supported(definition) then return definition.offered end
    local entry = {}
    for key, value in pairs(definition.offered[1]) do entry[key] = value end
    entry.amount = Prices.get(definition.service, authoritative)
    return {entry}
end

local originalCost = barters.serviceCost
barters.serviceCost = function(definition)
    if Prices.supported(definition) then return Prices.get(definition.service) end
    return originalCost(definition)
end
barters._empdaServicePrices = Prices

return Prices
