local PuzzleRules = {}

function PuzzleRules.initialOccupancy(sectors)
    local occupied = {}
    for index = 1, #sectors do
        occupied[index] = sectors:sub(index, index) == "k"
    end
    return occupied
end

function PuzzleRules.targetAfterTurn(target, turns, socketCount)
    return (target - 1 + turns) % socketCount + 1
end

-- Return the next occupancy, remaining attempts, and any terminal outcome.
-- Each call owns its result so simulations can branch from the same input.
function PuzzleRules.strike(occupied, target, attempts)
    local nextOccupied = { table.unpack(occupied) }
    local remaining = attempts - 1
    if occupied[target] then
        return nextOccupied, remaining, "lost"
    end

    nextOccupied[target] = true
    if remaining == 0 then
        return nextOccupied, remaining, "won"
    end
    return nextOccupied, remaining, nil
end

return PuzzleRules
