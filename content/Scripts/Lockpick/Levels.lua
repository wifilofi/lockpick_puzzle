local PuzzleGenerator = require("Scripts.Lockpick.PuzzleGenerator")

local firstId = "storage"

local levelData = {
    storage = { name = "Подсобка", sectors = "...k....", moves = { 1, 2, 2 }, nextId = "workshop" },
    workshop = { name = "Мастерская", sectors = "...k...k..", moves = { 1, 2, 3 }, nextId = "relay" },
    relay = { name = "Реле", sectors = "..k.k.....", moves = { 1, 2, 3 }, links = { { 2, 4 } }, nextId = "springs" },
    springs = { name = "Пружины", sectors = "...k...k.k", moves = { 2, 3, -3 }, springs = { 3 }, nextId = "challenge" },
    challenge = { name = "Испытание", generate = PuzzleGenerator.generate },
}

local function loadLevel(id)
    local level = assert(levelData[id], "Unknown lock: " .. id)
    local puzzle = level.generate and level.generate() or level
    local links = {}
    for index, pair in ipairs(puzzle.links or {}) do
        links[index] = { pair[1], pair[2] }
    end
    return {
        name = level.name,
        sectors = puzzle.sectors,
        moves = { table.unpack(puzzle.moves) },
        links = links,
        springs = { table.unpack(puzzle.springs or {}) },
    }
end

local function nextLevelId(id)
    return assert(levelData[id], "Unknown lock: " .. id).nextId
end

local function menuLevels()
    local levels = {}
    local id = firstId
    while id do
        local level = levelData[id]
        levels[#levels + 1] = { id = id, name = level.name }
        id = level.nextId
    end
    return levels
end

local function hasLevel(id)
    return levelData[id] ~= nil
end

return {
    firstId = firstId,
    loadLevel = loadLevel,
    nextLevelId = nextLevelId,
    menuLevels = menuLevels,
    hasLevel = hasLevel,
}
