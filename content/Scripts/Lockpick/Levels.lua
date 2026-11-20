local levelData = {
    storage = { name = "Подсобка", sectors = "...k....", moves = { 1, 2, 2 }, nextId = "workshop" },
    workshop = { name = "Мастерская", sectors = "...k...k..", moves = { 1, 2, 3 } },
}

local function loadLevel(id)
    local level = assert(levelData[id], "Unknown lock: " .. id)
    return { name = level.name, sectors = level.sectors, moves = { table.unpack(level.moves) } }
end

local function nextLevelId(id)
    return assert(levelData[id], "Unknown lock: " .. id).nextId
end

return { loadLevel = loadLevel, nextLevelId = nextLevelId }
