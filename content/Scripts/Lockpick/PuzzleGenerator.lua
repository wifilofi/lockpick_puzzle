local PuzzleRules = require("Scripts.Lockpick.PuzzleRules")

local PuzzleGenerator = {}

local SOCKET_COUNT = 10
local CARD_COUNT = 3

function PuzzleGenerator.generate(random)
    random = random or math.random
    local availableMoves = { 1, 2, 3, 4 }
    local moves = {}
    local safeSockets = { [1] = true }
    local target = 1

    -- Reserve the opening socket and a complete winning route.
    for slot = 1, CARD_COUNT do
        local turns = table.remove(availableMoves, random(#availableMoves))
        moves[slot] = turns
        target = PuzzleRules.targetAfterTurn(target, turns, SOCKET_COUNT)
        safeSockets[target] = true
    end

    -- At least one card must lead to an occupied socket if played first.
    local traps = {}
    for _, turns in ipairs(moves) do
        local firstTarget = PuzzleRules.targetAfterTurn(1, turns, SOCKET_COUNT)
        if not safeSockets[firstTarget] then
            traps[#traps + 1] = firstTarget
        end
    end
    local trap = traps[random(#traps)]

    local availableSockets = {}
    local sectors = {}
    for socket = 1, SOCKET_COUNT do
        sectors[socket] = "."
        if not safeSockets[socket] and socket ~= trap then
            availableSockets[#availableSockets + 1] = socket
        end
    end
    sectors[trap] = "k"
    sectors[availableSockets[random(#availableSockets)]] = "k"

    -- Hide the constructed route by shuffling the visible hand.
    for slot = #moves, 2, -1 do
        local other = random(slot)
        moves[slot], moves[other] = moves[other], moves[slot]
    end
    return { sectors = table.concat(sectors), moves = moves }
end

return PuzzleGenerator
