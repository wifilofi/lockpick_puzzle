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
    self.occupied = {}
    for i = 1, self.socketCount do
        self.occupied[i] = level.sectors:sub(i, i) == "k"
    end
    self.hand = { table.unpack(level.moves) }
    self.queue, self.queueHead = {}, 1
    self.attempts, self.target = #self.hand + 1, 1
    self.angleFrom, self.angleTo = 0, 0
    self.result, self.status = nil, "openingStrike"
    self.phaseMachine:transitionTo(RoundState.STRIKE)
end

function Round:clearCards()
    self.hand, self.queue, self.queueHead = {}, {}, 1
end

function Round:startQueuedTurn()
    if self.queueHead > #self.queue then
        self.queue, self.queueHead = {}, 1
        self.status = "choose"
        self.phaseMachine:transitionTo(RoundState.READY)
        return
    end
    local turns = self.queue[self.queueHead]
    self.queueHead = self.queueHead + 1
    self.target = (self.target - 1 + turns) % self.socketCount + 1
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
    self.queue[#self.queue + 1] = table.remove(self.hand, slot)
    if phase == RoundState.READY then self:startQueuedTurn() end
    return true
end

function Round:impact()
    self.attempts = self.attempts - 1
    if self.occupied[self.target] then
        self:clearCards()
        self.status = "occupied"
        self.phaseMachine:transitionTo(RoundState.SHOCK)
    else
        self.occupied[self.target] = true
        self.phaseMachine:transitionTo(RoundState.RECOIL)
    end
end

function Round:finish(won)
    self.result = won and "won" or "lost"
    self.status = nil
    self.phaseMachine:transitionTo(RoundState.FINISHED)
end

function Round:afterRecoil()
    if self.attempts == 0 then
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

function Round:isAnimating()
    return self.phaseMachine:isTimed()
end

function Round:update(dt)
    return self.phaseMachine:update(dt)
end

return Round
