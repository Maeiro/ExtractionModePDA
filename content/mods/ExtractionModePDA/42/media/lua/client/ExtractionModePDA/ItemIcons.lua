local Icons = {}
local textures = {}
local books = {
    Welding = "MetalWelding", MetalWelding = "MetalWelding", Electrical = "Electrician", Electricity = "Electrician",
    Carpentry = "Carpentry", Woodwork = "Carpentry", Mechanics = "Mechanic", FirstAid = "FirstAid",
    Cooking = "Cooking", Farming = "Farming", Tailoring = "Tailoring", Maintenance = "Maintenance",
    ["First Aid"] = "FirstAid", Doctor = "FirstAid", Reloading = "Reloading",
}

function Icons.texture(fullType)
    if not fullType then return nil end
    if textures[fullType] == nil then
        local ok, texture = pcall(function()
            local item = instanceItem(fullType)
            return item and item:getTex()
        end)
        textures[fullType] = ok and texture or false
    end
    return textures[fullType] or nil
end

function Icons.requirement(entry)
    return Icons.texture(entry.fullType or (entry.types or {})[1] or (entry.randomTypes or {})[1])
end

function Icons.skill(entry)
    local subject = books[entry.label] or books[tostring(entry.perk)]
    local volume = math.max(1, math.min(5, math.ceil((tonumber(entry.level) or 1) / 2)))
    return Icons.texture(subject and "Base.Book" .. subject .. volume) or Icons.texture("Base.Book")
end

function Icons.row(flow, label, texture, warning)
    if not texture then
        flow:add(label)
        flow.runs[#flow.runs].warning = warning
        return
    end
    local first, top = #flow.runs + 1, flow.y
    flow:add(label, UIFont.Small, nil, math.max(1, flow.width - 42), 42)
    local height = math.max(32, flow.y - top)
    for index = first, #flow.runs do
        flow.runs[index].y = flow.runs[index].y + (height - (flow.y - top)) / 2
        flow.runs[index].warning = warning
    end
    local run = flow.runs[first]
    run.icon, run.iconY, run.iconSize = texture, top + (height - 32) / 2, 32
    flow.y = top + height + 5
end

return Icons
