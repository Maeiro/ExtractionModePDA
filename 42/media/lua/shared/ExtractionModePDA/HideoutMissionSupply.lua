local Supply = {}

function Supply.isLoading(snapshot, id)
    return type(snapshot) == "table" and snapshot.enabled == true
        and (snapshot.ready ~= true or (id ~= nil and (snapshot.counts or {})[id] == nil))
end

function Supply.questId(questId)
    return "EMPDA_Quest:" .. tostring(questId or "")
end

function Supply.operationId(itemType)
    return "EMPDA_Operation:" .. tostring(itemType or "")
end

function Supply.storyItemTypes(gift)
    local result, seen = {}, {}
    local function add(value)
        value = tostring(value or "")
        if value ~= "" and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    if type(gift) == "table" then
        add(gift.t)
        for _, itemType in ipairs(gift.alt or {}) do add(itemType) end
    end
    table.sort(result)
    return result
end

function Supply.storyItemId(gift)
    return "EMPDA_StoryItem:" .. table.concat(Supply.storyItemTypes(gift), "|")
end

function Supply.storyTagId(tag)
    return "EMPDA_StoryTag:" .. tostring(tag or "")
end

function Supply.operationTypes(itemType, traderData)
    local result, seen = {}, {}
    local function add(value)
        value = tostring(value or "")
        if value ~= "" and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    add(itemType)
    local group
    if traderData and traderData.SameOf then
        pcall(function() group = traderData.SameOf(itemType) end)
    end
    if type(group) == "table" then
        for _, value in ipairs(group) do add(value) end
    end
    table.sort(result)
    return result
end

function Supply.operationCount(snapshot, itemType, traderData)
    if type(snapshot) ~= "table" or snapshot.enabled ~= true or snapshot.ready ~= true then return 0 end
    local types = Supply.operationTypes(itemType, traderData)
    if #types == 0 then return 0 end
    local row = (snapshot.counts or {})[Supply.operationId(itemType)] or {}
    return math.max(0, math.floor(tonumber(row[1]) or 0))
end

function Supply.storyItemCount(snapshot, gift)
    if type(snapshot) ~= "table" or snapshot.enabled ~= true or snapshot.ready ~= true
        or type(gift) ~= "table" then return 0 end
    local id = gift.tag and Supply.storyTagId(gift.tag) or Supply.storyItemId(gift)
    local row = (snapshot.counts or {})[id] or {}
    return math.max(0, math.floor(tonumber(row[1]) or 0))
end

function Supply.addQuestCounts(counts, definitions, snapshot)
    local added = {}
    if type(snapshot) ~= "table" or snapshot.enabled ~= true or snapshot.ready ~= true then return added end
    local indexed = snapshot.counts or {}
    for _, definition in ipairs(definitions or {}) do
        local row = counts and counts[definition.id]
        local world = indexed[Supply.questId(definition.id)]
        if row and world then
            added[definition.id] = {}
            for index in ipairs(definition.requirements or {}) do
                local amount = math.max(0, math.floor(tonumber(world[index]) or 0))
                row[index] = (tonumber(row[index]) or 0) + amount
                added[definition.id][index] = amount
            end
        end
    end
    return added
end

return Supply
