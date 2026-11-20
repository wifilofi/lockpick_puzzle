local PuzzleRules = {}

function PuzzleRules.initialOccupancy(sectors)
    local occupied = {}
    for index = 1, #sectors do
        occupied[index] = sectors:sub(index, index) == "k"
    end
    return occupied
end

function PuzzleRules.linkPartners(pairs, socketCount)
    local partners = {}
    for _, pair in ipairs(pairs) do
        local first, second = pair[1], pair[2]
        assert(math.type(first) == "integer" and first >= 1 and first <= socketCount
            and math.type(second) == "integer" and second >= 1 and second <= socketCount,
            "Linked sockets must be valid socket indices")
        assert(first ~= second and not partners[first] and not partners[second],
            "Each socket can belong to only one pair")
        partners[first], partners[second] = second, first
    end
    return partners
end

function PuzzleRules.targetAfterTurn(target, turns, socketCount)
    return (target - 1 + turns) % socketCount + 1
end

-- Return the next occupancy, remaining attempts, and any terminal outcome.
-- Each call owns its result so simulations can branch from the same input.
function PuzzleRules.strike(occupied, target, attempts, partners)
    local nextOccupied = { table.unpack(occupied) }
    local remaining = attempts - 1
    if occupied[target] then
        return nextOccupied, remaining, "lost"
    end

    nextOccupied[target] = true
    local partner = partners and partners[target]
    if partner then nextOccupied[partner] = true end
    if remaining == 0 then
        return nextOccupied, remaining, "won"
    end
    return nextOccupied, remaining, nil
end

return PuzzleRules
