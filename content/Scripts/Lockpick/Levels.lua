local levelData = {
    storage = { name = "Подсобка", sectors = "...k....", moves = { 1, 2, 2 } },
}

local function loadLevel(id)
    local level = assert(levelData[id], "Unknown lock: " .. id)
    return { name = level.name, sectors = level.sectors, moves = { table.unpack(level.moves) } }
end

return { loadLevel = loadLevel }
