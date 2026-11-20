local PuzzleGenerator = require("Scripts.Lockpick.PuzzleGenerator")

local levelData = {
    storage = { name = "Подсобка", sectors = "...k....", moves = { 1, 2, 2 }, nextId = "workshop" },
    workshop = { name = "Мастерская", sectors = "...k...k..", moves = { 1, 2, 3 }, nextId = "challenge" },
    challenge = { name = "Испытание", generate = PuzzleGenerator.generate },
}

local function loadLevel(id)
    local level = assert(levelData[id], "Unknown lock: " .. id)
    local puzzle = level.generate and level.generate() or level
    return { name = level.name, sectors = puzzle.sectors, moves = { table.unpack(puzzle.moves) } }
end

local function nextLevelId(id)
    return assert(levelData[id], "Unknown lock: " .. id).nextId
end

return { loadLevel = loadLevel, nextLevelId = nextLevelId }
