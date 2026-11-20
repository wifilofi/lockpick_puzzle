local PuzzleGenerator = require("Scripts.Lockpick.PuzzleGenerator")

local levelData = {
    storage = { name = "Подсобка", sectors = "...k....", moves = { 1, 2, 2 }, nextId = "workshop" },
    workshop = { name = "Мастерская", sectors = "...k...k..", moves = { 1, 2, 3 }, nextId = "relay" },
    relay = { name = "Реле", sectors = "..k.k.....", moves = { 1, 2, 3 }, links = { { 2, 4 } }, nextId = "challenge" },
    challenge = { name = "Испытание", generate = PuzzleGenerator.generate },
}

local function loadLevel(id)
    local level = assert(levelData[id], "Unknown lock: " .. id)
    local puzzle = level.generate and level.generate() or level
    local links = {}
    for index, pair in ipairs(puzzle.links or {}) do
        links[index] = { pair[1], pair[2] }
    end
    return { name = level.name, sectors = puzzle.sectors, moves = { table.unpack(puzzle.moves) }, links = links }
end

local function nextLevelId(id)
    return assert(levelData[id], "Unknown lock: " .. id).nextId
end

return { loadLevel = loadLevel, nextLevelId = nextLevelId }
