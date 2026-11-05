local Tracking = {}
local KEY = "ExtractionModePDATrackedQuest"
local LEGACY_KEY = "ViewpointExtractionSupportTrackedQuest"

local function modData(player)
    local saved = player:getModData()
    if saved[KEY] == nil and saved[LEGACY_KEY] ~= nil then saved[KEY] = saved[LEGACY_KEY] end
    saved[LEGACY_KEY] = nil
    return saved
end

local function quests()
    return ExtractionMode and ExtractionMode.Quests
end

function Tracking.available(data)
    local api = quests()
    local result = {}
    if not api or data.state == nil or type(data.quests) ~= "table" then return result end
    for _, definition in ipairs(api.acquiredDefinitions(data.quests)) do
        if not api.isCompleted(data.quests, definition.id) then result[#result + 1] = definition end
    end
    return result
end

function Tracking.get(player, data)
    if not player then return nil end
    local saved = modData(player)
    local id = saved[KEY]
    if not id or data.state == nil or type(data.quests) ~= "table" then return nil end
    for _, definition in ipairs(Tracking.available(data)) do
        if definition.id == id then return definition end
    end
    saved[KEY] = nil
    return nil
end

function Tracking.set(player, data, id)
    if not player then return false end
    if id == nil then modData(player)[KEY] = nil; return true end
    for _, definition in ipairs(Tracking.available(data)) do
        if definition.id == id then
            modData(player)[KEY] = id
            return true
        end
    end
    return false
end

return Tracking
