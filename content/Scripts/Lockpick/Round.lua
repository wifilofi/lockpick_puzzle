local PuzzleRules = require("Scripts.Lockpick.PuzzleRules")
local StateMachine = require("Scripts.Lockpick.StateMachine")
local RoundStates = require("Scripts.Lockpick.RoundStates")

local RoundState = RoundStates.Id

local Round = {}
Round.__index = Round

function Round.new(level, onPhaseChange)
    local self = setmetatable({}, Round)
    self.phaseMachine = StateMachine.new(RoundStates.definitions, self, onPhaseChange)
    self:restart(level)
    return self
end

function Round:restart(level)
    self.name = level.name
    self.socketCount = #level.sectors
    self.linkPairs = level.links or {}
    self.linkPartners = PuzzleRules.linkPartners(self.linkPairs, self.socketCount)
    self.occupied = PuzzleRules.initialOccupancy(level.sectors)
    self.hand = { table.unpack(level.moves) }
    self.history = {}
    self.queue, self.queueHead = {}, 1
    self.attempts, self.target = #self.hand + 1, 1
    self.angleFrom, self.angleTo = 0, 0
    self.result, self.pendingResult, self.status = nil, nil, "openingStrike"
    self.phaseMachine:transitionTo(RoundState.STRIKE)
end

function Round:clearCards()
    self.hand, self.queue, self.queueHead = {}, {}, 1
end

function Round:recordBeforeTurn()
    local hand = { table.unpack(self.hand) }
    -- Reverse the pending selections to recover the hand before this turn.
    for index = #self.queue, self.queueHead, -1 do
        local card = self.queue[index]
        table.insert(hand, card.slot, card.turns)
    end
    self.history[#self.history + 1] = {
        hand = hand,
        occupied = self.occupied, -- Each strike replaces the board with a fresh snapshot.
        attempts = self.attempts,
        target = self.target,
        angle = self.angleTo,
    }
end

function Round:startQueuedTurn()
    if self.queueHead > #self.queue then
        self.queue, self.queueHead = {}, 1
        self.status = "choose"
        self.phaseMachine:transitionTo(RoundState.READY)
        return
    end
    self:recordBeforeTurn()
    local turns = self.queue[self.queueHead].turns
    self.queueHead = self.queueHead + 1
    self.target = PuzzleRules.targetAfterTurn(self.target, turns, self.socketCount)
    self.angleFrom, self.angleTo = self.angleTo, self.angleTo + turns
    self.status = "turning"
    self.phaseMachine:transitionTo(RoundState.TURN)
end

function Round:selectCard(slot)
    local phase = self:currentPhase()
    if phase == RoundState.SHOCK or phase == RoundState.DROP or phase == RoundState.OPEN or phase == RoundState.FINISHED then
        return
    end
    if not self.hand[slot] then return end
    self.queue[#self.queue + 1] = { slot = slot, turns = table.remove(self.hand, slot) }
    if phase == RoundState.READY then self:startQueuedTurn() end
    return true
end

function Round:canUndo()
    return #self.history > 0 and (self:isReady() or self.result == "lost")
end

function Round:undo()
    if not self:canUndo() then return false end
    local previous = table.remove(self.history)
    self.hand, self.occupied = previous.hand, previous.occupied
    self.attempts, self.target = previous.attempts, previous.target
    self.angleFrom, self.angleTo = previous.angle, previous.angle
    self.queue, self.queueHead = {}, 1
    self.result, self.pendingResult, self.status = nil, nil, "choose"
    self.phaseMachine:transitionTo(RoundState.READY)
    return true
end

function Round:impact()
    self.occupied, self.attempts, self.pendingResult =
        PuzzleRules.strike(self.occupied, self.target, self.attempts, self.linkPartners)
    if self.pendingResult == "lost" then
        self:clearCards()
        self.status = "occupied"
        self.phaseMachine:transitionTo(RoundState.SHOCK)
    else
        self.phaseMachine:transitionTo(RoundState.RECOIL)
    end
end

function Round:finish()
    self.result, self.pendingResult, self.status = self.pendingResult, nil, nil
    self.phaseMachine:transitionTo(RoundState.FINISHED)
end

function Round:afterRecoil()
    if self.pendingResult == "won" then
        self:clearCards()
        self.status = "openingDoor"
        self.phaseMachine:transitionTo(RoundState.OPEN)
    else
        self:startQueuedTurn()
    end
end

function Round:currentPhase()
    return self.phaseMachine.currentState
end

function Round:isReady()
    return self:currentPhase() == RoundState.READY
end

function Round:isAnimating()
    return self.phaseMachine:isTimed()
end

function Round:update(dt)
    return self.phaseMachine:update(dt)
end

return Round
