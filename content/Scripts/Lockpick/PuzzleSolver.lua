local PuzzleRules = require("Scripts.Lockpick.PuzzleRules")

local PuzzleSolver = {}

-- Return a slot in the current hand that leaves a path to victory.
function PuzzleSolver.findWinningCard(occupied, target, attempts, hand, partners, springs)
    local board = PuzzleRules.releaseSprings(occupied, springs)
    for slot, turns in ipairs(hand) do
        local nextTarget = PuzzleRules.targetAfterTurn(target, turns, #occupied)
        local nextOccupied, remaining, outcome = PuzzleRules.strike(board, nextTarget, attempts, partners)
        if outcome == "won" then
            return slot
        end
        if outcome == nil then
            local nextHand = { table.unpack(hand) }
            table.remove(nextHand, slot)
            if PuzzleSolver.findWinningCard(nextOccupied, nextTarget, remaining, nextHand, partners, springs) then
                return slot
            end
        end
    end
    return nil
end

return PuzzleSolver
