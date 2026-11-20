local PuzzleRules = {}

function PuzzleRules.initialOccupancy(sectors)
    local occupied = {}
    for index = 1, #sectors do
        occupied[index] = sectors:sub(index, index) == "k"
    end
    return occupied
end

local function isSocketIndex(index, socketCount)
    return math.type(index) == "integer" and index >= 1 and index <= socketCount
end

function PuzzleRules.linkPartners(pairs, socketCount)
    local partners = {}
    for _, pair in ipairs(pairs) do
        local first, second = pair[1], pair[2]
        assert(isSocketIndex(first, socketCount) and isSocketIndex(second, socketCount),
            "Linked sockets must be valid socket indices")
        assert(first ~= second and not partners[first] and not partners[second],
            "Each socket can belong to only one pair")
        partners[first], partners[second] = second, first
    end
    return partners
end

function PuzzleRules.validateSprings(springs, socketCount)
    local seen = {}
    for _, socket in ipairs(springs) do
        assert(isSocketIndex(socket, socketCount), "Spring sockets must be valid socket indices")
        assert(not seen[socket], "Each spring socket must be listed once")
        seen[socket] = true
    end
end

-- A rotation clears set spring pins and preserves any permanent pins.
function PuzzleRules.releaseSprings(occupied, springs)
    if not springs then return occupied end
    local released
    for _, socket in ipairs(springs) do
        if occupied[socket] then
            released = released or { table.unpack(occupied) }
            released[socket] = false
        end
    end
    return released or occupied
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
