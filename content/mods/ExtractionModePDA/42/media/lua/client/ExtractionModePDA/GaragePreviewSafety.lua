local Safety = {}

function Safety.requiresIllustration(scriptName)
    local manager = getScriptManager()
    local script = manager:getVehicle(scriptName)
    if not script then return false end
    for index = 0, script:getPartCount() - 1 do
        local part = script:getPart(index)
        for modelIndex = 0, part:getModelCount() - 1 do
            local vehicleModel = part:getModel(modelIndex)
            if not vehicleModel then return true end
            local file = vehicleModel:getFile()
            if not file then return true end
            local model = file and manager:getModelScript(file)
            if not model then return true end
            -- UI3DScene reads animated part transforms before they are ready in B42.21.
            if model and not model:isStatic() then return true end
        end
    end
    return false
end

return Safety
